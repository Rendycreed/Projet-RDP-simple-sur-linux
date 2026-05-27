#!/bin/bash

# Version compatible FreeRDP 2 (xfreerdp) — pour Debian 12, Ubuntu avec X11

# --- Liste des serveurs ---
declare -A SERVEURS=(
	["RDP_1"]="0.0.0.0"
	["RDP_2"]="1.1.1.1"
)
# --- Fin de la liste ---

# Génère la liste des serveurs pour yad --list
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

		userv="$host"
		server_choice_display="Avancée ($userv)"

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
		multimon_opt="/multimon /floatbar"
	fi

	# Options son, micro
	sound_opt=""
	if [ "$sound" == "TRUE" ]; then
		sound_opt="/sound"
	fi

	mic_opt=""
	if [ "$mic" == "TRUE" ]; then
		mic_opt="/mic"
	fi

	echo "Tentative de connexion pour ${username} sur le serveur ${server_choice_display} (Argument /v: \"${userv}\")..."

	# Lance la connexion FreeRDP 2 et capture la sortie
	rdp_output=$(xfreerdp /dynamic-resolution /network:auto /sec:nla +auto-reconnect \
	 /gfx /rfx /compression /gdi:hw /cert-ignore \
	 $sound_opt $mic_opt -themes -wallpaper +clipboard /clipboard:use-selection:CLIPBOARD \
	 /kbd:0x0000040C \
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
	elif [ "$rdp_exit" -ne 0 ] && [ "$rdp_exit" -ne 128 ]; then
		yad --error --title="Erreur de connexion" \
			--text="<b>La connexion a échoué (code $rdp_exit).</b>\n\nServeur : $server_choice_display\nUtilisateur : $username" \
			--width=400
		continue
	fi

	# Connexion réussie ou déconnexion normale → on sort de la boucle
	break
done
