<div align="center">

# NXE360

### The Xbox 360 NXE dashboard, rebuilt for Batocera

*Le tableau de bord Xbox 360 NXE, recréé pour Batocera*

[![Batocera](https://img.shields.io/badge/Batocera-EmulationStation-107C10?style=for-the-badge)](https://batocera.org)
[![License: CC BY-NC-SA 4.0](https://img.shields.io/badge/License-CC%20BY--NC--SA%204.0-lightgrey?style=for-the-badge)](LICENSE)
[![Free](https://img.shields.io/badge/Price-Free-107C10?style=for-the-badge)](#license)

<!-- Capture d'écran : ajoute docs/screenshot.jpg puis enlève les balises de commentaire de la ligne suivante -->
<!-- <img src="docs/screenshot.jpg" alt="NXE360" width="900"> -->

**[English](#english)** · **[Français](#français)**

</div>

---

## English

### Highlights

| | |
|---|---|
| **NXE green cards** | Six cards on screen, large selected card, floor reflections, "camera" zoom between systems |
| **Staircase** | Cards shrink step by step, exactly like the original dashboard (with the installed scripts) |
| **Profile card** | RetroAchievements username, points as a gamerscore, animated avatar, last 4 games played |
| **Living card** | Light sheen across the selected card, rotating info line (games, favorites, last played) |
| **Featured game** *(option)* | After 3 s on a system, the last game played appears with its disc and name |
| **Marketplace-style game lists** | *Carousel* view: large box art with the next games shrinking away · *Grid* view: big tiles with video |
| **Xbox LIVE style notifications** | RetroAchievements "signed in / signed out" toast |
| **Controllers** | Connected pads at the top right, with battery level for wireless ones |
| **Xbox 360 menus** | Light panel, green selection, Xenon font |
| **Your own avatar** | Create it on 360sona and get an animated, transparent avatar in the theme |
| **Extras** | 600+ wallpapers, navigation sounds, CRT effect, system loop on/off, English & French |

### Installation

1. **Install the theme** — *Menu → Updates & Downloads → Themes → NXE360*
2. **Select it** — *UI Settings → Theme → NXE360*
3. **Enable the extra features** *(once)*
   1. Copy `NXE360 - Installation.sh` from `\\BATOCERA\share\themes\NXE360\` to `\\BATOCERA\share\roms\ports\` (network share, FTP or USB stick)
   2. *Menu → Update Gamelists*
   3. Launch **NXE360 - Installation** from **Ports** — the theme prepares itself for 1–2 minutes, then reloads

   > Over SSH: `bash "/userdata/themes/NXE360/NXE360 - Installation.sh"`

All options (language, video, loop, CRT, wallpaper…) are in **Theme Configuration**.
To create your avatar, launch **360sona** from **Ports**.

### What the installation adds

The theme works on its own. The included scripts add: recent games and RetroAchievements points on the profile card, staircase images, sign-in notifications, featured game names, the Marketplace-style game queue, the system loop option and left/right card sounds.

- **Always up to date** — the scripts live inside the theme folder and are updated with it.
- **Your avatars are safe** — they are backed up outside the theme and restored after each theme update.
- **Privacy** — the script uses the RetroAchievements account already set up in Batocera, talks only to retroachievements.org, and never asks for a password.

### Requirements

| | Recommended |
|---|---|
| Batocera | Recent version (tested on the October 2026 development build) |
| Display | 16:9 — 1080p or 4K (other ratios are stretched) |
| Scraping | Box art, images and videos for the best result |
| Small devices | On a Raspberry Pi or handheld, turn off the CRT effect if the UI slows down |

---

## Français

### Points forts

| | |
|---|---|
| **Cartes vertes NXE** | Six cartes à l'écran, la carte sélectionnée en grand, reflets sur le sol, zoom « caméra » entre les systèmes |
| **Escalier** | Les cartes rétrécissent de marche en marche, comme sur le tableau de bord d'origine (avec les scripts installés) |
| **Carte profil** | Pseudo RetroAchievements, points façon gamerscore, avatar animé, 4 derniers jeux joués |
| **Carte vivante** | Reflet lumineux sur la carte sélectionnée, ligne d'infos (jeux, favoris, dernière partie) |
| **Jeu à la une** *(option)* | Au bout de 3 s sur un système, le dernier jeu lancé apparaît avec son disque et son nom |
| **Listes de jeux façon Marketplace** | Vue *Carousel* : grande jaquette et les jeux suivants qui rétrécissent · vue *Grille* : grandes tuiles avec vidéo |
| **Notifications façon Xbox LIVE** | « Connecté / déconnecté » à RetroAchievements |
| **Manettes** | Manettes connectées en haut à droite, avec la batterie des manettes sans fil |
| **Menus Xbox 360** | Panneau clair, sélection verte, police Xenon |
| **Ton avatar** | Crée-le sur 360sona et retrouve-le animé et détouré dans le thème |
| **En plus** | Plus de 600 fonds d'écran, sons de navigation, effet cathodique, boucle des systèmes, français et anglais |

### Installation

1. **Installe le thème** — *Menu → Mises à jour et téléchargements → Thèmes → NXE360*
2. **Choisis-le** — *Réglages de l'interface → Thème → NXE360*
3. **Active les fonctions en plus** *(une seule fois)*
   1. Copie `NXE360 - Installation.sh` de `\\BATOCERA\share\themes\NXE360\` vers `\\BATOCERA\share\roms\ports\` (réseau, FTP ou clé USB)
   2. *Menu → Mettre à jour la liste des jeux*
   3. Lance **NXE360 - Installation** dans **Ports** — le thème se prépare 1 à 2 minutes, puis se recharge

   > En SSH : `bash "/userdata/themes/NXE360/NXE360 - Installation.sh"`

Toutes les options (langue, vidéo, boucle, effet cathodique, fond d'écran…) sont dans la **Configuration du thème**.
Pour créer ton avatar, lance **360sona** dans **Ports**.

### Ce que l'installation ajoute

Le thème fonctionne seul. Les scripts fournis ajoutent : les derniers jeux et les points RetroAchievements de la carte profil, l'escalier, les notifications de connexion, le nom du jeu à la une, la file de jaquettes façon Marketplace, l'option de boucle des systèmes et les sons gauche/droite.

- **Toujours à jour** — les scripts sont dans le dossier du thème et se mettent à jour avec lui.
- **Tes avatars sont protégés** — ils sont sauvegardés hors du thème et remis après chaque mise à jour.
- **Vie privée** — le script utilise le compte RetroAchievements déjà réglé dans Batocera, ne parle qu'à retroachievements.org et ne demande jamais de mot de passe.

### Configuration conseillée

| | Conseillé |
|---|---|
| Batocera | Version récente (testé sur la version de développement d'octobre 2026) |
| Écran | 16:9 — 1080p ou 4K (les autres formats sont étirés) |
| Scraping | Jaquettes, images et vidéos pour le meilleur rendu |
| Petites machines | Sur Raspberry Pi ou console portable, coupe l'effet cathodique si l'interface ralentit |

---

## License

**NXE360** by **Blunpai** — [CC BY-NC-SA 4.0](LICENSE).
Free to use, share and modify with credit to Blunpai, for non-commercial use, under the same license.
*Libre d'utilisation, de partage et de modification en créditant Blunpai, sans usage commercial, sous la même licence.*

<sub>Xbox, Xbox 360 and the NXE design are trademarks and works of Microsoft. NXE360 is a free fan project, not affiliated with or endorsed by Microsoft. Sounds, fonts, wallpapers and game artwork belong to their respective owners.</sub>
