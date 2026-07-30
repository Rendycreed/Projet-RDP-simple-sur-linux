# RDP simple pour environnement de bureau Linux

Lanceur graphique pour se connecter en RDP à des serveurs Windows depuis un poste Linux. Fournit une interface simple basée sur `yad` pour choisir un serveur dans une liste pré-configurée (ou saisir un host libre) et lance la connexion via `xfreerdp`.

Projet utilisé en environnement de production professionnel.

## Prérequis

### FreeRDP

Le paquet à installer peut varier selon la distribution et le serveur d'affichage utilisé (X11 ou Wayland).

| Distribution           | Génération | Paquets                       |
|------------------------|------------|-------------------------------|
| Debian 12 (bookworm)   | FreeRDP 2  | `freerdp2-x11`                |
| Debian 13 (trixie)     | FreeRDP 3  | `freerdp3-x11` + `freerdp3-sdl` |
| Ubuntu 24.04+          | FreeRDP 3  | `freerdp3-x11` + `freerdp3-sdl` |
| Ubuntu 22.04           | FreeRDP 2  | `freerdp2-x11`                |
| Arch Linux             | FreeRDP 3  | `freerdp`                     |
| Fedora / RHEL / CentOS | FreeRDP 3  | `freerdp`                     |

`install_rdp.sh` fait ce choix automatiquement (voir *Installation*).

### YAD (interface graphique)

```bash
# Debian / Ubuntu
sudo apt install yad

# Arch Linux
sudo pacman -S yad
```

## Installation

### Installation automatique (recommandé)

Le script `install_rdp.sh` détecte la distribution, installe les dépendances
(client FreeRDP + `yad`) puis déploie le script et son raccourci :

```bash
git clone https://github.com/Rendycreed/Projet-RDP-simple-sur-linux.git
cd Projet-RDP-simple-sur-linux
sudo ./install_rdp.sh
```

Distributions gérées : Debian / Ubuntu (`apt`), Arch (`pacman`), Fedora / RHEL /
CentOS (`dnf`). Sur les autres, installez manuellement un client FreeRDP + `yad`.

**Choix des paquets FreeRDP** — l'installeur lit `VERSION_ID` dans
`/etc/os-release` pour viser la bonne génération (Debian 12 → FreeRDP 2,
Debian 13 et Ubuntu 24.04+ → FreeRDP 3), puis vérifie la disponibilité réelle
des paquets et corrige dans les deux sens :

- FreeRDP 3 absent des dépôts → repli automatique sur `freerdp2-x11`
- FreeRDP 3 présent alors qu'il n'était pas attendu (backports, PPA) → il est
  utilisé en priorité

Le type de session (X11 / Wayland) est aussi détecté — via `loginctl`, car
`sudo` ne transmet pas `XDG_SESSION_TYPE`. En session Wayland sous FreeRDP 2,
l'installeur signale que `xfreerdp` passera par XWayland.

### Installation manuelle

1. Copier le script dans `/opt/rdp/` :
   ```bash
   sudo mkdir -p /opt/rdp
   sudo cp connexion_serveur.sh /opt/rdp/
   sudo chmod +x /opt/rdp/connexion_serveur.sh
   ```

2. Installer le raccourci applicatif :
   ```bash
   sudo cp connexion-serveurs.desktop /usr/share/applications/
   ```

La liste des serveurs se remplit ensuite via le fichier de configuration
(voir la section *Configuration*) ou directement depuis l'interface.

## Désinstallation

```bash
sudo ./uninstall_rdp.sh
```

Le script retire `/opt/rdp/connexion_serveur.sh` et le raccourci
`/usr/share/applications/connexion-serveurs.desktop`, après avoir listé ce qui
va être supprimé et demandé confirmation.

| Option      | Effet                                                            |
|-------------|------------------------------------------------------------------|
| *(aucune)*  | Retire le script et le raccourci, **conserve** la configuration   |
| `--purge`   | Retire aussi `~/.config/rdp-connexion` (liste des serveurs)       |
| `-y`, `--yes` | Ne demande pas de confirmation                                 |
| `-h`, `--help` | Affiche l'aide                                                |

Notes :

- `/opt/rdp` n'est supprimé que s'il est vide.
- Les paquets FreeRDP et `yad` ne sont **jamais** désinstallés : d'autres
  logiciels peuvent en dépendre. La commande pour les retirer est affichée en
  fin de traitement.
- Avec `--purge`, seule la configuration de l'utilisateur qui lance `sudo` est
  supprimée. Les configurations des autres comptes sont signalées mais
  conservées.

## Utilisation

Lancer **Connexions Serveurs** depuis le menu applicatif, ou directement :

```bash
/opt/rdp/connexion_serveur.sh
```

### Mode standard

1. Sélectionner un serveur dans la liste
2. Saisir identifiant et mot de passe
3. Cocher "Multi-écrans" si besoin
4. Cliquer sur **Connexion**

### Mode avancé

Sélectionner **Avancée** dans la liste pour saisir manuellement un host (IP ou nom DNS).

## Fonctionnalités

- Résolution dynamique
- Reconnexion automatique
- Accélération graphique (GFX / RFX) et compression
- Son et micro redirigés
- Presse-papiers partagé
- Clavier français (FR)
- Montage du `$HOME` Linux comme lecteur réseau côté serveur Windows
- Support multi-écrans avec barre flottante

## Configuration

La liste des serveurs est stockée dans un fichier de configuration externe,
créé automatiquement au premier lancement :

```
~/.config/rdp-connexion/serveurs.conf
```

Format : une ligne `NOM=IP` par serveur (les lignes vides et celles commençant
par `#` sont ignorées) :

```
RDP_COMPTA=10.0.0.10
RDP_PROD=10.0.0.11
```

On peut aussi ajouter un serveur directement depuis l'interface : mode
**Avancée**, renseigner le Host + un Nom, puis cocher **Enregistrer ce serveur**.
Il apparaîtra dans le menu au prochain lancement.

## Client FreeRDP

Le script détecte automatiquement le client FreeRDP disponible et adapte la
syntaxe de ses options :

- Session **Wayland** → `sdl-freerdp3`
- Session **X11** → `xfreerdp3`
- Repli → `xfreerdp` (FreeRDP 2, ex. Debian 12)

## État du projet

Version **1.0.0** — version finale stable, utilisée en production.

Les développements suivants sont des évolutions bonus, préparées sur la branche
`develop` puis fusionnées dans `main` avec un nouveau tag (`v1.1.0`, etc.).
