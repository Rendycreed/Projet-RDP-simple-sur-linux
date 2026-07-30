#!/bin/bash
#
# install_rdp.sh - Installeur de "Connexions Serveurs" (RDP simple)
#
# Installe les dépendances (client FreeRDP + yad), déploie le script dans
# /opt/rdp et enregistre le raccourci dans le menu des applications.
# La distribution est détectée automatiquement (apt / pacman / dnf).
#
# Usage :  sudo ./install_rdp.sh
#

set -e

# --- Affichage coloré (désactivé si sortie non interactive) ---
if [ -t 1 ]; then
	C_INFO="\033[1;34m"; C_OK="\033[1;32m"; C_ERR="\033[1;31m"; C_RST="\033[0m"
else
	C_INFO=""; C_OK=""; C_ERR=""; C_RST=""
fi
info() { echo -e "${C_INFO}[*]${C_RST} $*"; }
ok()   { echo -e "${C_OK}[OK]${C_RST} $*"; }
err()  { echo -e "${C_ERR}[ERREUR]${C_RST} $*" >&2; }

# --- Emplacements ---
INSTALL_DIR="/opt/rdp"
DESKTOP_DIR="/usr/share/applications"
SCRIPT_NAME="connexion_serveur.sh"
DESKTOP_NAME="connexion-serveurs.desktop"

# Dossier source (où se trouve cet installeur)
SRC_DIR="$(cd "$(dirname "$0")" && pwd)"

# --- 1. Vérification root ---
if [ "$(id -u)" -ne 0 ]; then
	err "Ce script doit être lancé en root. Relancez :  sudo $0"
	exit 1
fi

# --- 2. Vérification des fichiers source ---
if [ ! -f "$SRC_DIR/$SCRIPT_NAME" ]; then
	err "Fichier introuvable : $SRC_DIR/$SCRIPT_NAME"
	exit 1
fi

# --- 3. Détection de la distribution ---
if [ ! -r /etc/os-release ]; then
	err "/etc/os-release introuvable : distribution non identifiable."
	exit 1
fi
. /etc/os-release
DISTRO="$ID"
LIKE="$ID_LIKE"
info "Distribution détectée : ${PRETTY_NAME:-$DISTRO}"

# Teste si $1 correspond à l'ID ou à une famille de ID_LIKE
matches() {
	case " $DISTRO $LIKE " in
		*" $1 "*) return 0 ;;
	esac
	return 1
}

# --- 4. Détection du serveur d'affichage (X11 / Wayland) ---
# sudo ne transmet pas XDG_SESSION_TYPE : on interroge la session de
# l'utilisateur appelant via loginctl, puis on se rabat sur le socket Wayland.
detecter_session() {
	if [ -n "$XDG_SESSION_TYPE" ]; then
		echo "$XDG_SESSION_TYPE"
		return
	fi
	if [ -n "$SUDO_USER" ] && command -v loginctl >/dev/null 2>&1; then
		local sid stype
		sid=$(loginctl list-sessions --no-legend 2>/dev/null \
			| awk -v u="$SUDO_USER" '$3 == u { print $1; exit }')
		if [ -n "$sid" ]; then
			stype=$(loginctl show-session "$sid" -p Type --value 2>/dev/null)
			if [ -n "$stype" ]; then
				echo "$stype"
				return
			fi
		fi
	fi
	if [ -n "$SUDO_UID" ] && ls /run/user/"$SUDO_UID"/wayland-* >/dev/null 2>&1; then
		echo "wayland"
		return
	fi
	echo "inconnu"
}
SESSION_TYPE="$(detecter_session)"
info "Serveur d'affichage détecté : $SESSION_TYPE"

# --- 5. Installation des dépendances ---
if matches debian || matches ubuntu; then
	info "Gestionnaire : apt"
	apt-get update

	# Le paquet existe-t-il dans les dépôts configurés ?
	apt_dispo() { apt-cache show "$1" 2>/dev/null | grep -q '^Package:'; }

	# Choix de la génération de FreeRDP selon la version de la distribution :
	#   Debian 12 (bookworm) -> FreeRDP 2 (pas de paquet freerdp3 dans les dépôts)
	#   Debian 13 (trixie) et Ubuntu 24.04+ -> FreeRDP 3
	# Cette préférence est ensuite arbitrée par la disponibilité réelle des
	# paquets, dans les deux sens : repli sur la v2 si la v3 est absente, mais
	# aussi passage à la v3 si elle est présente (backports, dérivées, PPA).
	MAJOR="${VERSION_ID%%.*}"
	GEN_CIBLE=3
	if [ "$DISTRO" = "debian" ] && [ -n "$MAJOR" ]; then
		if [ "$MAJOR" -le 12 ] 2>/dev/null; then
			info "Debian $VERSION_ID (${VERSION_CODENAME:-?}) -> FreeRDP 2 attendu"
			GEN_CIBLE=2
		else
			info "Debian $VERSION_ID (${VERSION_CODENAME:-?}) -> FreeRDP 3 attendu"
		fi
	fi
	if apt_dispo freerdp3-x11; then
		if [ "$GEN_CIBLE" -eq 2 ]; then
			info "FreeRDP 3 finalement disponible (backports ?) -> on l'utilise"
			GEN_CIBLE=3
		fi
	elif [ "$GEN_CIBLE" -eq 3 ]; then
		info "FreeRDP 3 indisponible dans les dépôts -> repli sur FreeRDP 2"
		GEN_CIBLE=2
	fi

	# Liste des paquets : yad + les clients FreeRDP réellement disponibles.
	PKGS="yad"
	if [ "$GEN_CIBLE" -eq 3 ]; then
		# freerdp3-x11 -> xfreerdp3 (session X11)
		# freerdp3-sdl -> sdl-freerdp3 (session Wayland, client préféré)
		for p in freerdp3-x11 freerdp3-sdl; do
			if apt_dispo "$p"; then
				PKGS="$PKGS $p"
			fi
		done
	else
		if apt_dispo freerdp2-x11; then
			PKGS="$PKGS freerdp2-x11"
		fi
		if [ "$SESSION_TYPE" = "wayland" ]; then
			info "FreeRDP 2 ne fournit pas de client SDL : xfreerdp passera par XWayland."
		fi
	fi

	if [ "$PKGS" = "yad" ]; then
		err "Aucun paquet client FreeRDP trouvé dans les dépôts de $DISTRO $VERSION_ID."
		err "Installez un client FreeRDP manuellement, puis relancez."
		exit 1
	fi

	info "Installation : $PKGS"
	apt-get install -y $PKGS

elif matches arch; then
	info "Gestionnaire : pacman"
	PKGS="freerdp yad"
	info "Installation : $PKGS"
	pacman -Sy --needed --noconfirm $PKGS

elif matches fedora || matches rhel || matches centos; then
	info "Gestionnaire : dnf"
	PKGS="freerdp yad"
	info "Installation : $PKGS"
	dnf install -y $PKGS

else
	err "Distribution non supportée : $DISTRO (ID_LIKE=${LIKE:-aucun})"
	err "Installez manuellement un client FreeRDP (v3 de préférence) + yad, puis relancez."
	exit 1
fi
ok "Dépendances installées."

# --- 6. Déploiement du script ---
info "Installation du script dans $INSTALL_DIR"
install -d "$INSTALL_DIR"
install -m 755 "$SRC_DIR/$SCRIPT_NAME" "$INSTALL_DIR/$SCRIPT_NAME"
ok "Script installé : $INSTALL_DIR/$SCRIPT_NAME"

# --- 7. Raccourci .desktop ---
info "Installation du raccourci dans $DESKTOP_DIR"
if [ -f "$SRC_DIR/$DESKTOP_NAME" ]; then
	install -m 644 "$SRC_DIR/$DESKTOP_NAME" "$DESKTOP_DIR/$DESKTOP_NAME"
else
	cat > "$DESKTOP_DIR/$DESKTOP_NAME" <<EOF
[Desktop Entry]
Type=Application
Name=Connexions Serveurs
Comment=Lancer les connexions RDP aux serveurs
Exec=$INSTALL_DIR/$SCRIPT_NAME
Icon=preferences-desktop-remote-desktop
Terminal=false
Categories=Network;RemoteAccess;
EOF
fi
# Garantit que l'Exec pointe vers l'emplacement d'installation réel
sed -i "s|^Exec=.*|Exec=$INSTALL_DIR/$SCRIPT_NAME|" "$DESKTOP_DIR/$DESKTOP_NAME"
# Rafraîchit la base des applications si l'outil est présent
if command -v update-desktop-database >/dev/null 2>&1; then
	update-desktop-database "$DESKTOP_DIR" >/dev/null 2>&1 || true
fi
ok "Raccourci installé : $DESKTOP_DIR/$DESKTOP_NAME"

# --- 8. Fin ---
echo
ok "Installation terminée."
info "Lancez « Connexions Serveurs » depuis le menu des applications,"
info "ou directement :  $INSTALL_DIR/$SCRIPT_NAME"
info "Pour désinstaller :  sudo ./uninstall_rdp.sh"
