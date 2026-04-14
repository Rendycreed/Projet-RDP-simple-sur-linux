#!/bin/bash

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

# Variables pour la commande finale
username=""
pwd=""
userv=""
server_choice_display="$server_choice"

# --- Vérification du choix ---

if [ "$server_choice" == "Avancée" ]; then
	# --- Mode Avancé ---
	cfg_adv=$(yad --form \
		--title="Connexion Avancée" \
		--text="Entrer les détails de connexion" \
		--field="Identifiant:" \
		--field="Mot de passe:H" \
		--field="Host (ex: 10.0.0.1):" \
		--field="Multi-écrans:CHK" \
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

	userv="$host"
	server_choice_display="Avancée ($userv)"

else
	# --- Mode Standard ---
	cfg_std=$(yad --form \
		--title="Connexion - $server_choice" \
		--text="Serveur: $server_choice" \
		--field="Nom d'utilisateur:" \
		--field="Mot de passe:H" \
		--field="Multi-écrans:CHK" \
		--button="Annuler:1" \
		--button="Connexion:0" \
		--width=350)

	if [ "$?" -eq 1 ]; then
		exit
	fi

	username=$(echo "$cfg_std" | cut -d "|" -f1)
	pwd=$(echo "$cfg_std" | cut -d "|" -f2)
	multiscreen=$(echo "$cfg_std" | cut -d "|" -f3)

	userv=${SERVEURS[$server_choice]}
fi


# --- Lancement de la connexion ---

if [ -z "$username" ] || [ -z "$userv" ]; then
	yad --error --text="Le nom d'utilisateur et le serveur/host ne peuvent pas être vides."
	exit 1
fi

# Option multi-écrans avec barre flottante
multimon_opt=""
if [ "$multiscreen" == "TRUE" ]; then
	multimon_opt="/multimon /floatbar"
fi

echo "Tentative de connexion pour ${username} sur le serveur ${server_choice_display} (Argument /v: \"${userv}\")..."

# Lance la connexion FreeRDP
xfreerdp /dynamic-resolution /network:auto /sec:nla +auto-reconnect \
 /gfx /rfx /compression /gdi:hw /cert-ignore \
 /sound /mic -themes -wallpaper +clipboard /clipboard:use-selection:CLIPBOARD \
 /kbd:0x0000040C \
 /drive:Linux,/home/$USER \
 $multimon_opt \
 /u:"$username" /p:"$pwd" /v:"$userv"
