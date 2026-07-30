#!/bin/bash
#
# uninstall_rdp.sh - Désinstalleur de "Connexions Serveurs" (RDP simple)
#
# Retire le script de /opt/rdp et le raccourci du menu des applications.
# La configuration utilisateur (~/.config/rdp-connexion) est CONSERVÉE par
# défaut : utiliser --purge pour la supprimer également.
# Les paquets (FreeRDP, yad) ne sont jamais désinstallés : d'autres logiciels
# peuvent en dépendre.
#
# Usage :  sudo ./uninstall_rdp.sh [--purge] [--yes]
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

# --- Emplacements (doivent correspondre à install_rdp.sh) ---
INSTALL_DIR="/opt/rdp"
DESKTOP_DIR="/usr/share/applications"
SCRIPT_NAME="connexion_serveur.sh"
DESKTOP_NAME="connexion-serveurs.desktop"
CONFIG_SUBDIR=".config/rdp-connexion"

# --- 1. Options ---
PURGE=0
ASSUME_YES=0
while [ $# -gt 0 ]; do
	case "$1" in
		--purge)     PURGE=1 ;;
		-y|--yes)    ASSUME_YES=1 ;;
		-h|--help)
			echo "Usage : sudo $0 [--purge] [--yes]"
			echo
			echo "  --purge    Supprime aussi la configuration utilisateur (~/$CONFIG_SUBDIR)"
			echo "  -y, --yes  Ne pas demander de confirmation"
			echo "  -h, --help Affiche cette aide"
			exit 0 ;;
		*)
			err "Option inconnue : $1  (voir --help)"
			exit 1 ;;
	esac
	shift
done

# --- 2. Vérification root ---
if [ "$(id -u)" -ne 0 ]; then
	err "Ce script doit être lancé en root. Relancez :  sudo $0 $*"
	exit 1
fi

# --- 3. Détermination de l'utilisateur d'origine (pour --purge) ---
# En sudo, $HOME pointe sur /root : on récupère le vrai utilisateur appelant.
TARGET_USER="${SUDO_USER:-}"
TARGET_HOME=""
if [ -n "$TARGET_USER" ]; then
	TARGET_HOME=$(getent passwd "$TARGET_USER" | cut -d: -f6)
fi

# --- 4. Inventaire de ce qui va être supprimé ---
A_SUPPRIMER=()
[ -e "$INSTALL_DIR/$SCRIPT_NAME" ]  && A_SUPPRIMER+=("$INSTALL_DIR/$SCRIPT_NAME")
[ -e "$DESKTOP_DIR/$DESKTOP_NAME" ] && A_SUPPRIMER+=("$DESKTOP_DIR/$DESKTOP_NAME")
if [ "$PURGE" -eq 1 ] && [ -n "$TARGET_HOME" ] && [ -d "$TARGET_HOME/$CONFIG_SUBDIR" ]; then
	A_SUPPRIMER+=("$TARGET_HOME/$CONFIG_SUBDIR")
fi

if [ "${#A_SUPPRIMER[@]}" -eq 0 ]; then
	info "Rien à désinstaller : aucun fichier de « Connexions Serveurs » trouvé."
	if [ "$PURGE" -eq 0 ] && [ -n "$TARGET_HOME" ] && [ -d "$TARGET_HOME/$CONFIG_SUBDIR" ]; then
		info "La configuration $TARGET_HOME/$CONFIG_SUBDIR existe toujours (--purge pour la retirer)."
	fi
	exit 0
fi

echo
info "Éléments qui vont être supprimés :"
for f in "${A_SUPPRIMER[@]}"; do
	echo "    - $f"
done
echo

# --- 5. Confirmation ---
if [ "$ASSUME_YES" -eq 0 ]; then
	read -r -p "Confirmer la désinstallation ? [o/N] " reponse
	case "$reponse" in
		o|O|oui|OUI|y|Y|yes) ;;
		*) info "Désinstallation annulée." ; exit 0 ;;
	esac
fi

# --- 6. Suppression du script ---
if [ -e "$INSTALL_DIR/$SCRIPT_NAME" ]; then
	rm -f "$INSTALL_DIR/$SCRIPT_NAME"
	ok "Script supprimé : $INSTALL_DIR/$SCRIPT_NAME"
	# Le dossier n'est retiré que s'il est vide (il peut contenir d'autres outils)
	if [ -d "$INSTALL_DIR" ] && [ -z "$(ls -A "$INSTALL_DIR")" ]; then
		rmdir "$INSTALL_DIR"
		ok "Dossier vide supprimé : $INSTALL_DIR"
	elif [ -d "$INSTALL_DIR" ]; then
		info "$INSTALL_DIR n'est pas vide : conservé."
	fi
fi

# --- 7. Suppression du raccourci ---
if [ -e "$DESKTOP_DIR/$DESKTOP_NAME" ]; then
	rm -f "$DESKTOP_DIR/$DESKTOP_NAME"
	if command -v update-desktop-database >/dev/null 2>&1; then
		update-desktop-database "$DESKTOP_DIR" >/dev/null 2>&1 || true
	fi
	ok "Raccourci supprimé : $DESKTOP_DIR/$DESKTOP_NAME"
fi

# --- 8. Configuration utilisateur ---
if [ "$PURGE" -eq 1 ]; then
	if [ -n "$TARGET_HOME" ] && [ -d "$TARGET_HOME/$CONFIG_SUBDIR" ]; then
		rm -rf "${TARGET_HOME:?}/$CONFIG_SUBDIR"
		ok "Configuration supprimée : $TARGET_HOME/$CONFIG_SUBDIR"
	fi
	# Les autres comptes gardent leur config : on se contente de les signaler.
	AUTRES=()
	for d in /home/*/"$CONFIG_SUBDIR"; do
		[ -d "$d" ] || continue
		AUTRES+=("$d")
	done
	if [ "${#AUTRES[@]}" -gt 0 ]; then
		echo
		info "Configurations d'autres utilisateurs conservées (à retirer manuellement) :"
		for d in "${AUTRES[@]}"; do
			echo "    - $d"
		done
	fi
else
	if [ -n "$TARGET_HOME" ] && [ -d "$TARGET_HOME/$CONFIG_SUBDIR" ]; then
		info "Configuration conservée : $TARGET_HOME/$CONFIG_SUBDIR"
		info "Pour la supprimer aussi :  sudo $0 --purge"
	fi
fi

# --- 9. Fin ---
echo
ok "Désinstallation terminée."
info "Les paquets FreeRDP et yad n'ont pas été touchés (d'autres logiciels"
info "peuvent en dépendre). Pour les retirer, par exemple sous Debian/Ubuntu :"
info "    sudo apt remove freerdp3-x11 freerdp3-sdl yad     # ou freerdp2-x11"
