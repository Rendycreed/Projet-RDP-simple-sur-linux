#!/bin/bash

# --- Fichier de configuration des serveurs ---
CONFIG_DIR="$HOME/.config/rdp-connexion"
CONFIG_FILE="$CONFIG_DIR/serveurs.conf"

# Crée le dossier + le fichier de config au premier lancement
if [ ! -f "$CONFIG_FILE" ]; then
	mkdir -p "$CONFIG_DIR"
	{
		echo "# Liste des serveurs RDP - une ligne par serveur"
		echo "# Format : NOM=IP   (exemple : RDP_COMPTA=10.0.0.10)"
		echo "# Les lignes vides et celles commençant par # sont ignorées."
	} > "$CONFIG_FILE"
fi

# --- Chargement des serveurs depuis le fichier de config ---
declare -A SERVEURS=()
while IFS='=' read -r nom ip; do
	# Ignore les lignes vides et les commentaires
	[ -z "$nom" ] && continue
	case "$nom" in \#*) continue ;; esac
	# Retire les espaces éventuels autour du nom et de l'IP
	nom="${nom// /}"
	ip="${ip// /}"
	[ -z "$ip" ] && continue
	SERVEURS["$nom"]="$ip"
done < "$CONFIG_FILE"

# --- Fonction : enregistre un serveur dans le fichier de config ---
enregistrer_serveur() {
	local nom="$1" ip="$2"
	# Nettoyage : espaces -> underscore, on retire les '='
	nom="${nom// /_}"
	nom="${nom//=/}"
	if [ -z "$nom" ] || [ -z "$ip" ]; then
		return 1
	fi
	# Serveur déjà présent : proposer de remplacer
	if [ -n "${SERVEURS[$nom]}" ]; then
		yad --question --title="Serveur existant" \
			--text="Un serveur nommé <b>$nom</b> existe déjà (${SERVEURS[$nom]}).\nLe remplacer par <b>$ip</b> ?" \
			--button="Non:1" --button="Oui:0"
		if [ "$?" -ne 0 ]; then
			return 1
		fi
		# Supprime l'ancienne ligne avant de réécrire
		sed -i "/^[[:space:]]*$nom[[:space:]]*=/d" "$CONFIG_FILE"
	fi
	echo "$nom=$ip" >> "$CONFIG_FILE"
	SERVEURS["$nom"]="$ip"
	yad --info --title="Serveur enregistré" \
		--text="Le serveur <b>$nom</b> ($ip) a été ajouté.\nIl apparaîtra dans le menu au prochain lancement." \
		--width=350
}

# --- Détection du client FreeRDP et de sa syntaxe d'options ---
# Wayland -> sdl-freerdp3 ; X11 -> xfreerdp3 ; repli -> xfreerdp (FreeRDP 2)
session="${XDG_SESSION_TYPE:-}"
if [ -z "$session" ] && [ -n "$WAYLAND_DISPLAY" ]; then
	session="wayland"
fi

# Ordre de préférence des clients selon la session
if [ "$session" = "wayland" ]; then
	RDP_CANDIDATS="sdl-freerdp3 sdl-freerdp xfreerdp3 xfreerdp"
else
	RDP_CANDIDATS="xfreerdp3 xfreerdp sdl-freerdp3 sdl-freerdp"
fi

RDP_BIN=""
for c in $RDP_CANDIDATS; do
	if command -v "$c" >/dev/null 2>&1; then
		RDP_BIN="$c"
		break
	fi
done

if [ -z "$RDP_BIN" ]; then
	yad --error --title="FreeRDP introuvable" \
		--text="Aucun client FreeRDP trouvé (sdl-freerdp3, xfreerdp3 ou xfreerdp).\nInstallez le paquet <b>freerdp3</b> (ou freerdp2)."
	exit 1
fi

# Génération de FreeRDP : les binaires suffixés "3" sont en v3. Pour un binaire
# non suffixé (xfreerdp/sdl-freerdp), la génération varie selon la distro
# (v2 sur Debian/Ubuntu, v3 sur Fedora/Arch) -> on lit la version réelle.
case "$RDP_BIN" in
	*3)
		RDP_GEN="3" ;;
	*)
		rdp_ver=$("$RDP_BIN" --version 2>/dev/null | grep -oiE "version [0-9]+" | grep -oE "[0-9]+" | head -n1)
		if [ "$rdp_ver" = "2" ]; then RDP_GEN="2"; else RDP_GEN="3"; fi ;;
esac

# Syntaxe des options selon la génération de FreeRDP (2 ou 3)
if [ "$RDP_GEN" = "2" ]; then
	CERT_OPT="/cert-ignore"
	KBD_OPT="/kbd:0x0000040C"
	MIC_FLAG="/mic"
	EXTRA_OPT="/compression"
else
	CERT_OPT="/cert:ignore"
	KBD_OPT="/kbd:layout:0x0000040C"
	MIC_FLAG="/microphone"
	EXTRA_OPT=""
fi

# Le presse-papier par sélection X11 ne s'applique pas au client SDL (Wayland)
CLIP_OPT="+clipboard"
if [ "$RDP_BIN" != "sdl-freerdp3" ]; then
	CLIP_OPT="+clipboard /clipboard:use-selection:CLIPBOARD"
fi

# Génère la liste des serveurs pour yad --list (triée)
mapfile -t SERVEUR_LIST < <(printf '%s\n' "${!SERVEURS[@]}" | sort)

# --- FENÊTRE 1: Choix du serveur ---
server_choice=$(yad --list \
	--title="Connexion TSE" \
	--text="Choisir un serveur (↑↓ puis Entrée)" \
	--column="Serveur" \
	--height=400 \
	--width=300 \
	--button="Annuler:1" \
	--button="OK:0" \
	"${SERVEUR_LIST[@]}" "Avancée")

# Quitte si Annuler ou vide
if [ "$?" -eq 1 ] || [ -z "$server_choice" ]; then
	exit
fi

# yad ajoute un | à la fin, on le retire
server_choice="${server_choice%|}"

# Variables conservées entre les tentatives (pré-remplissage du formulaire)
username=""
host=""
save_name=""
multiscreen="FALSE"
sound="FALSE"
mic="FALSE"

# --- Boucle : formulaire de connexion + tentative ---
while true; do
	pwd=""
	userv=""
	server_choice_display="$server_choice"

	# Cases à cocher pré-remplies : "TRUE" ou "FALSE"
	multi_default="$multiscreen"
	sound_default="$sound"
	mic_default="$mic"

	# Par défaut, pas d'enregistrement de serveur (réinitialisé à chaque tour)
	save_srv="FALSE"

	if [ "$server_choice" == "Avancée" ]; then
		# --- Mode Avancé ---
		cfg_adv=$(yad --form \
			--title="Connexion Avancée" \
			--text="Entrer les détails de connexion" \
			--field="Identifiant:" "$username" \
			--field="Mot de passe:H" "" \
			--field="Host (ex: 10.0.0.1):" "$host" \
			--field="Multi-écrans:CHK" "$multi_default" \
			--field="Son:CHK" "$sound_default" \
			--field="Micro:CHK" "$mic_default" \
			--field="Nom (pour enregistrer):" "$save_name" \
			--field="Enregistrer ce serveur:CHK" "FALSE" \
			--button="Annuler:1" \
			--button="Connexion:0" \
			--width=350)

		if [ "$?" -eq 1 ]; then
			exit
		fi

		username=$(echo "$cfg_adv" | cut -d "|" -f1)
		pwd=$(echo "$cfg_adv" | cut -d "|" -f2)
		host=$(echo "$cfg_adv" | cut -d "|" -f3)
		multiscreen=$(echo "$cfg_adv" | cut -d "|" -f4)
		sound=$(echo "$cfg_adv" | cut -d "|" -f5)
		mic=$(echo "$cfg_adv" | cut -d "|" -f6)
		save_name=$(echo "$cfg_adv" | cut -d "|" -f7)
		save_srv=$(echo "$cfg_adv" | cut -d "|" -f8)

		userv="$host"
		server_choice_display="Avancée ($userv)"

		# Enregistrement du serveur si demandé
		if [ "$save_srv" == "TRUE" ]; then
			if [ -n "$save_name" ] && [ -n "$host" ]; then
				enregistrer_serveur "$save_name" "$host"
			else
				yad --error --text="Pour enregistrer un serveur, renseignez un <b>Nom</b> et un <b>Host</b>."
			fi
		fi

	else
		# --- Mode Standard ---
		cfg_std=$(yad --form \
			--title="Connexion - $server_choice" \
			--text="Serveur: $server_choice" \
			--field="Nom d'utilisateur:" "$username" \
			--field="Mot de passe:H" "" \
			--field="Multi-écrans:CHK" "$multi_default" \
			--field="Son:CHK" "$sound_default" \
			--field="Micro:CHK" "$mic_default" \
			--button="Annuler:1" \
			--button="Connexion:0" \
			--width=350)

		if [ "$?" -eq 1 ]; then
			exit
		fi

		username=$(echo "$cfg_std" | cut -d "|" -f1)
		pwd=$(echo "$cfg_std" | cut -d "|" -f2)
		multiscreen=$(echo "$cfg_std" | cut -d "|" -f3)
		sound=$(echo "$cfg_std" | cut -d "|" -f4)
		mic=$(echo "$cfg_std" | cut -d "|" -f5)

		userv=${SERVEURS[$server_choice]}
	fi

	# --- Vérification des champs ---
	if [ -z "$username" ] || [ -z "$userv" ]; then
		yad --error --text="Le nom d'utilisateur et le serveur/host ne peuvent pas être vides."
		continue
	fi

	# Option multi-écrans avec barre flottante
	multimon_opt=""
	if [ "$multiscreen" == "TRUE" ]; then
		multimon_opt="/multimon /monitors:0,1 /floatbar"
	fi

	# Options son, micro
	sound_opt=""
	if [ "$sound" == "TRUE" ]; then
		sound_opt="/sound"
	fi

	mic_opt=""
	if [ "$mic" == "TRUE" ]; then
		mic_opt="$MIC_FLAG"
	fi

	echo "Tentative de connexion pour ${username} sur le serveur ${server_choice_display} (client: $RDP_BIN, /v: \"${userv}\")..."

	# Lance la connexion FreeRDP (binaire + syntaxe adaptés) et capture la sortie
	rdp_output=$($RDP_BIN /dynamic-resolution /network:auto /sec:nla +auto-reconnect \
	 /gfx /rfx /gdi:hw $CERT_OPT $EXTRA_OPT \
	 $sound_opt $mic_opt -themes -wallpaper $CLIP_OPT \
	 $KBD_OPT \
	 /drive:Linux,/home/$USER \
	 $multimon_opt \
	 /u:"$username" /p:"$pwd" /v:"$userv" 2>&1)
	rdp_exit=$?

	echo "$rdp_output"

	# Détection d'une erreur d'authentification (mauvais ID ou MDP)
	if echo "$rdp_output" | grep -qiE "LOGON_FAILURE|AUTHENTICATION_FAILED|ACCOUNT_DISABLED|ACCOUNT_LOCKED_OUT|ACCOUNT_RESTRICTION|PASSWORD_EXPIRED|PASSWORD_MUST_CHANGE|INVALID_LOGON_HOURS|INVALID_WORKSTATION|LOGON_TYPE_NOT_GRANTED|0xc000006d|0xc000006a"; then
		yad --error --title="Échec de connexion" \
			--text="<b>Identifiant ou mot de passe incorrect.</b>\n\nServeur : $server_choice_display\nUtilisateur : $username\n\nVeuillez vérifier vos identifiants et réessayer." \
			--width=400
		continue
	elif [ "$rdp_exit" -gt 128 ]; then
		# Codes 1-128 = terminaisons normales de FreeRDP (déconnexion, logoff,
		# fermeture de session par l'utilisateur, ex: code 12). Seuls les codes
		# >= 129 sont de vraies erreurs de connexion/protocole.
		yad --error --title="Erreur de connexion" \
			--text="<b>La connexion a échoué (code $rdp_exit).</b>\n\nServeur : $server_choice_display\nUtilisateur : $username" \
			--width=400
		continue
	fi

	# Connexion réussie ou déconnexion normale → on sort de la boucle
	break
done
