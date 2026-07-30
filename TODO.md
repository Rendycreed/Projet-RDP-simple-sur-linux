# Phase de développement — branche `develop`

Plan des modifications prévues sur cette phase.

---

> Statut : points 1 et 2 **FAITS** → livrés dans la **v1.0.0** (tag sur `main`).
> Bonus faits en cours de route : liste des serveurs externalisée en fichier de
> config + enregistrement depuis l'interface, unification des scripts
> x11/wayland (détection FreeRDP au runtime), fix du faux message d'erreur à la
> déconnexion (code 12).
>
> Points 3 et 4 **FAITS** après la v1.0.0 : évolutions bonus, à fusionner dans
> `main` sous le tag `v1.1.0`.

## 1. Modifier `connexion_serveur.sh` — son/micro optionnels  ✅ FAIT

**Objectif** : rendre le son et le micro optionnels via cases à cocher dans le formulaire yad. Par défaut **décochés**.

### Modifs dans le **mode standard** (formulaire `cfg_std`)

Ajouter 2 champs après `Multi-écrans:CHK` :
```bash
--field="Son:CHK" \
--field="Micro:CHK" \
```

Adapter le parsing des champs (on passe de 3 à 5 champs) :
```bash
username=$(echo "$cfg_std" | cut -d "|" -f1)
pwd=$(echo "$cfg_std" | cut -d "|" -f2)
multiscreen=$(echo "$cfg_std" | cut -d "|" -f3)
sound=$(echo "$cfg_std" | cut -d "|" -f4)
mic=$(echo "$cfg_std" | cut -d "|" -f5)
```

### Modifs dans le **mode avancé** (formulaire `cfg_adv`)

Idem : ajouter `Son:CHK` et `Micro:CHK`, adapter le parsing (f5 et f6).

### Modifs de la commande `xfreerdp`

Retirer `/sound` et `/mic` des options en dur, les rendre conditionnels :
```bash
sound_opt=""
if [ "$sound" == "TRUE" ]; then
    sound_opt="/sound"
fi

mic_opt=""
if [ "$mic" == "TRUE" ]; then
    mic_opt="/mic"
fi
```

Puis dans l'appel `xfreerdp`, remplacer `/sound /mic` par `$sound_opt $mic_opt`.

---

## 2. Créer `install_rdp.sh` — installeur multi-distro  ✅ FAIT

**Objectif** : script d'installation CLI qui détecte la distro et installe les dépendances + le projet.

### Fonctionnalités

- **Détection auto** de la distro via `/etc/os-release` (variable `$ID` et `$ID_LIKE`)
- **Détection du serveur d'affichage** via `$XDG_SESSION_TYPE` (`x11` ou `wayland`) pour choisir le bon paquet FreeRDP
- **Installation des paquets** avec le bon gestionnaire (apt/pacman/dnf)
- **Installation du projet** :
  - Script → `/opt/rdp/connexion_serveur.sh` (avec chmod +x)
  - Raccourci → `/usr/share/applications/connexion-serveurs.desktop`
- **Sortie CLI** : messages colorés (info / OK / erreur), pas de GUI
- **Vérifications** :
  - Script lancé en root (sudo) — sinon demander de relancer
  - Distro supportée — sinon message d'erreur clair

### Distros à supporter

| Famille   | Distros                        | Gestionnaire | Paquet FreeRDP            | Paquet YAD |
|-----------|--------------------------------|--------------|---------------------------|------------|
| Debian    | Debian 12, Debian 13, Ubuntu   | `apt`        | `freerdp2-x11` / `freerdp3-x11` / `freerdp3-wayland` | `yad`      |
| Arch      | Arch Linux                     | `pacman`     | `freerdp`                 | `yad`      |
| Red Hat   | RHEL, CentOS, Fedora           | `dnf`        | `freerdp`                 | `yad`      |

### Structure du script (pseudo-code)

```
1. Vérifier root
2. Lire /etc/os-release → $ID
3. Lire $XDG_SESSION_TYPE → x11 ou wayland
4. Switch sur $ID :
   - debian|ubuntu → apt install
   - arch          → pacman -S
   - fedora|rhel|centos → dnf install
   - *             → erreur "distro non supportée"
5. Copier connexion_serveur.sh dans /opt/rdp/
6. Copier connexion-serveurs.desktop dans /usr/share/applications/
7. Message final : "Installation terminée, lancer via le menu applications"
```

### Mode d'emploi utilisateur

```bash
git clone https://github.com/Rendycreed/Projet-RDP-simple-sur-linux.git
cd Projet-RDP-simple-sur-linux
sudo ./install_rdp.sh
```

---

## 3. Créer `uninstall_rdp.sh` — désinstalleur  ✅ FAIT (post-v1.0)

**Objectif** : retirer proprement ce qu'a posé `install_rdp.sh`.

- Supprime `/opt/rdp/connexion_serveur.sh` et le `.desktop`, rafraîchit la base
  des applications. `/opt/rdp` retiré seulement s'il est vide.
- Inventaire affiché + confirmation avant toute suppression (`-y` pour passer outre).
- `--purge` supprime en plus `~/.config/rdp-connexion` de l'utilisateur appelant
  (récupéré via `$SUDO_USER` + `getent passwd`, car `$HOME` vaut `/root` sous sudo).
  Les configs des autres comptes sont listées mais conservées.
- Les paquets (FreeRDP, yad) ne sont jamais désinstallés : d'autres logiciels
  peuvent en dépendre. La commande de retrait est affichée en fin de traitement.

## 4. Distinction Debian 12 / 13 dans `install_rdp.sh`  ✅ FAIT (post-v1.0)

**Objectif** : choisir la bonne génération de FreeRDP selon la version de la distro.

- Lecture de `VERSION_ID` : Debian ≤ 12 → FreeRDP 2 attendu, Debian 13+ et
  Ubuntu 24.04+ → FreeRDP 3 attendu.
- Arbitrage par la disponibilité réelle des paquets (`apt-cache show`), **dans
  les deux sens** : repli v3 → v2 si absente, mais aussi bascule v2 → v3 si
  freerdp3 est présent alors qu'il n'était pas attendu (backports, PPA).
- Erreur claire si aucun client FreeRDP n'est disponible dans les dépôts.
- Détection du serveur d'affichage via `loginctl` (`sudo` ne transmet pas
  `XDG_SESSION_TYPE`), repli sur le socket `/run/user/$SUDO_UID/wayland-*`.
  En Wayland + FreeRDP 2, avertit que `xfreerdp` passera par XWayland.

Testé en simulation sur : Debian 12, Debian 12 + backports, Debian 13,
Ubuntu 22.04, Ubuntu 24.04, et le cas « aucun paquet freerdp ».

---

## 5. Correction de bug — Ubuntu 24.04  ✅ FAIT (post-v1.0)

**Symptôme constaté en test réel** (Ubuntu 24.04, clone de `main`/v1.0.0) :
`sudo ./install_rdp.sh` s'arrête sur `Unable to locate package freerdp3-sdl`,
puis plus rien — `/opt/rdp` n'est pas créé, aucun raccourci.

**Cause** : la v1.0.0 testait la disponibilité de `freerdp3-x11` puis installait
`freerdp3-x11 freerdp3-sdl yad` sans vérifier `freerdp3-sdl`. Ubuntu 24.04
fournit `freerdp3-x11` mais pas `freerdp3-sdl` (paquet présent seulement sur
Debian 13 / Ubuntu 24.10+). `apt` échoue, le `set -e` interrompt le script avant
les étapes de copie, sans message.

**Corrections** :
- vérification paquet par paquet (déjà apportée par le point 4)
- test de disponibilité basé sur le `Candidate` de `apt-cache policy` plutôt que
  sur `apt-cache show`, qui réussit aussi pour un paquet seulement référencé
- message d'erreur explicite si `apt` / `pacman` / `dnf` échoue, au lieu d'une
  mort silencieuse par `set -e`
- contrôle final de la présence d'un binaire FreeRDP et de `yad`

## 6. Points ouverts / à discuter

- **Tests réels** : sur quelles distros tester en vrai ? (Debian 13 MJ-PORT
  confirmé ; Debian 12, Ubuntu, Arch, Fedora restent en simulation)
- **Version LTSP** : reporter le fix code 12 sur la version séparée si la base
  n'est pas la même.
