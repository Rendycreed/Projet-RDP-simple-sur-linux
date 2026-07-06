# Phase de développement — branche `develop`

Plan des modifications prévues sur cette phase.

---

> Statut : points 1 et 2 **FAITS**. Bonus faits en cours de route : liste des
> serveurs externalisée en fichier de config + enregistrement depuis l'interface,
> unification des scripts x11/wayland (détection FreeRDP au runtime), fix du
> faux message d'erreur à la déconnexion (code 12).

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

## 3. Points ouverts / à discuter

- **Debian 12 vs 13** : `/etc/os-release` donne la version, on adapte le paquet FreeRDP en fonction ?
- **Désinstalleur** `uninstall_rdp.sh` à prévoir ? (peut venir dans une phase suivante)
- **Tests** : sur quelles distros on peut tester en réel ? (Debian 13 MJ-PORT confirmé, autres ?)
