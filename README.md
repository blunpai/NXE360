# NXE360

**Thème EmulationStation pour Batocera, façon tableau de bord Xbox 360 NXE (New Xbox Experience).**
*EmulationStation theme for Batocera, styled after the Xbox 360 NXE dashboard. English below.*

Auteur : **Blunpai** · Licence : [CC BY-NC-SA 4.0](LICENSE) · Gratuit, projet de fan

---

## 🇫🇷 Français

### Fonctionnalités

- **Cartes vertes NXE** : 6 cartes à l'écran, la carte sélectionnée en grand, reflets sur le sol, zoom « caméra » quand on change de système.
- **Escalier** (option) : les cartes rétrécissent de marche en marche, comme sur le NXE.
- **Carte profil** : pseudo RetroAchievements, points (façon gamerscore), avatar et les 4 derniers jeux joués.
- **Carte vivante** : reflet lumineux qui balaie la carte, ligne d'infos sous la carte (nombre de jeux, favoris, dernière partie).
- **Jeu à la une** (option « Vidéo ») : au bout de 3 s sur un système, l'image du dernier jeu lancé apparaît avec une icône disque et son nom.
- **Notification RetroAchievements** « connecté / déconnecté » en bas de l'écran, comme « signed in to Xbox LIVE ».
- **Manettes connectées** en haut à droite, avec le pourcentage de batterie des manettes sans fil.
- **Boucle des systèmes** (option) : désactivée, la liste a un début et une fin, comme sur le NXE.
- **Effet cathodique** (option) : écran bombé, lignes de balayage, grille RGB (Léger / Fort / Désactivé).
- **Sons de navigation** (dossier `sounds/`), **fonds d'écran** au choix, **français / anglais**.

### Installation

1. Dans EmulationStation : **Menu → Mises à jour et téléchargements → Thèmes → NXE360**.
2. Réglages de l'interface → Thème → **NXE360**.
3. Pour les fonctions du script (voir plus bas), une seule fois :
   - copie le fichier **`NXE360 - Installation.sh`** du dossier du thème (`\\BATOCERA\share\themes\NXE360\`) dans `\\BATOCERA\share\roms\ports\` (réseau, FTP ou clé USB) ;
   - **Menu → Mettre à jour la liste des jeux** ;
   - lance **NXE360 - Installation** dans **Ports**. Le thème se prépare 1 à 2 minutes puis se recharge tout seul.
   - (en SSH, à la place : `bash "/userdata/themes/NXE360/NXE360 - Installation.sh"`)
4. Les options (langue, escalier, vidéo, boucle, effet cathodique, fond d'écran…) sont dans la **configuration du thème**.

Les scripts sont dans le dossier du thème : une mise à jour du thème les met à jour aussi, et tes avatars 360sona sont gardés.
Pour créer ton avatar : lance **360sona** dans Ports.

### Le script `nxe360_recent.sh`

Le thème fonctionne sans lui, mais le script ajoute : les derniers jeux et les points RetroAchievements de la carte profil, les images de l'escalier, la notification de connexion, le jeu à la une (avec son nom), la boucle des systèmes désactivée et les sons gauche/droite des cartes.
Il utilise le compte RetroAchievements déjà enregistré dans Batocera : il n'envoie rien ailleurs qu'à retroachievements.org, et aucun mot de passe n'est à saisir.

### Configuration conseillée

- Batocera récent (testé sur la version de développement d'octobre 2026).
- Écran 16:9 (1080p ou 4K). Les autres formats fonctionnent, mais l'image est étirée.
- Sur une petite machine (Raspberry Pi…), désactive l'effet cathodique si l'interface ralentit.

---

## 🇬🇧 English

### Features

- **NXE green cards**: 6 cards on screen, big selected card, floor reflections, "camera" zoom when changing system.
- **Staircase** (option): cards shrink step by step, like the NXE.
- **Profile card**: RetroAchievements username, points (gamerscore style), avatar and the last 4 games played.
- **Living card**: light sheen sweeping the card, rotating info line (games, favorites, last played).
- **Featured game** ("Video" option): after 3 s on a system, the last played game appears with a disc icon and its name.
- **RetroAchievements notification** (signed in / signed out), like "signed in to Xbox LIVE".
- **Connected controllers** at the top right, with battery level for wireless pads.
- **System loop** (option): when off, the list has a start and an end, like the NXE.
- **CRT effect** (option): curved screen, scanlines, RGB mask (Light / Strong / Off).
- **Navigation sounds** (`sounds/` folder), selectable **wallpapers**, **French / English**.

### Installation

1. In EmulationStation: **Menu → Updates & downloads → Themes → NXE360**.
2. UI settings → Theme → **NXE360**.
3. For the script features (see below), once:
   - copy **`NXE360 - Installation.sh`** from the theme folder (`\\BATOCERA\share\themes\NXE360\`) to `\\BATOCERA\share\roms\ports\` (network, FTP or USB stick);
   - **Menu → Update games lists**;
   - launch **NXE360 - Installation** from **Ports**. The theme prepares itself for 1-2 minutes, then reloads.
   - (over SSH instead: `bash "/userdata/themes/NXE360/NXE360 - Installation.sh"`)
4. Options (language, staircase, video, loop, CRT effect, wallpaper…) are in the **theme configuration**.

The scripts live in the theme folder: updating the theme updates them too, and your 360sona avatars are kept.
To create your avatar: launch **360sona** from Ports.

### The `nxe360_recent.sh` script

The theme works without it, but the script adds: recent games and RetroAchievements points on the profile card, staircase images, sign-in notification, featured game (with its name), system loop off and left/right card sounds.
It uses the RetroAchievements account already saved in Batocera: it only talks to retroachievements.org, and no password has to be entered.

---

## Licence / License

**CC BY-NC-SA 4.0**: tu peux utiliser, partager et modifier ce thème gratuitement, en créditant Blunpai, sans usage commercial, et en gardant la même licence pour les versions modifiées. Voir [LICENSE](LICENSE).
*Free to use, share and modify, crediting Blunpai, non-commercial, same license for modified versions.*

Xbox, Xbox 360 et le design NXE sont des marques et créations de Microsoft. Ce thème est un projet de fan gratuit, sans lien avec Microsoft. Les sons, polices, fonds d'écran et visuels de jeux appartiennent à leurs propriétaires respectifs.
*Xbox, Xbox 360 and the NXE design are trademarks/works of Microsoft. This is a free fan project, not affiliated with Microsoft.*
