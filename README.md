# RDP simple pour environnement de bureau Linux

Lanceur graphique pour se connecter en RDP à des serveurs Windows depuis un poste Linux. Fournit une interface simple basée sur `yad` pour choisir un serveur dans une liste pré-configurée (ou saisir un host libre) et lance la connexion via `xfreerdp`.

Projet utilisé en environnement de production professionnel.

## Prérequis

### FreeRDP

Le paquet à installer peut varier selon la distribution et le serveur d'affichage utilisé (X11 ou Wayland).

| Distribution         | Paquet                        |
|----------------------|-------------------------------|
| Debian 12            | `freerdp2-x11`                |
| Debian 13 / Ubuntu   | `freerdp3-x11` ou `freerdp3-wayland` |
| Arch Linux           | `freerdp`                     |

### YAD (interface graphique)

```bash
# Debian / Ubuntu
sudo apt install yad

# Arch Linux
sudo pacman -S yad
```

## Installation

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

3. Éditer le script pour renseigner la liste des serveurs (section `SERVEURS` en haut du fichier).

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

Projet en développement, fonctionnel et déjà utilisé en production.
