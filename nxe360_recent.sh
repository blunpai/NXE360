#!/bin/bash
# ============================================================================
#  NXE360 - script du thème NXE360 pour Batocera
#  Auteur : Blunpai  -  Version : 1.1
#  Licence : Creative Commons BY-NC-SA 4.0 (voir LICENCE.txt dans le dossier du thème)
#            partage et modifications autorisés en créditant Blunpai, sans usage commercial,
#            même licence pour toute version modifiée.
# ============================================================================
#  NXE360 - « Derniers jeux » de la carte profil (carte Xbox 360, sinon Favoris)
# ----------------------------------------------------------------------------
#  Prépare pour le thème NXE360 :
#    - les images des 4 derniers jeux joués : art/recent/1.png ... 4.png (carrés 256x256)
#      image de fond du jeu (fanart), sinon capture d'écran, écran titre ou jaquette, recadrée pour
#      remplir tout le carré ; sinon le logo sur fond vert ; sinon « manette + nom du jeu » sur fond vert
#    - tes points RetroAchievements : art/recent/ra_points.dat
#      (fichier vide dont la TAILLE = tes points : c'est la seule chose qu'un thème sait lire)
#      Connexion avec le compte déjà enregistré dans Batocera (pas de clé d'API à fournir).
#      RA_POINTS ci-dessous : total (hardcore + softcore), hardcore, softcore ou auto (hardcore, sinon softcore).
#    - la notification « connecté à RetroAchievements » au démarrage d'ES et à la connexion (art/recent/toast.on)
#    - ton pseudo RetroAchievements gardé en cache : art/recent/ra_user.xml
#      -> pseudo et points restent affichés quand RetroAchievements est désactivé
#    - une petite surveillance en arrière-plan : quand tu actives / désactives RetroAchievements
#      (ou changes de compte) dans le menu, EmulationStation recharge tout seul la liste
#      pour que la carte Favoris passe à Connecté / Déconnecté sans rien faire.
#      Elle démarre avec EmulationStation grâce au petit fichier
#      /userdata/system/configs/emulationstation/scripts/start/nxe360_watch.sh, créé automatiquement.
#      WATCH="off" ci-dessous pour ne pas l'utiliser.
#    - l'option « Escalier » du thème (Configuration du thème > Escalier : Activé) : prépare, dans art/stair/, les
#      images des cartes qui rétrécissent de marche en marche. Désactivée par défaut. Elle dessine avec Pillow
#      (Python Imaging Library) : sans elle l'option reste sans effet. Elle se met à jour toute seule grâce à la
#      surveillance ci-dessus. Pour la lancer à la main : nxe360_recent.sh stairs (journal : nxe360_recent.log).
#      Les images de TOUTES les variantes sont prêtes à l'avance (chaque langue, avec / sans boucle, vidéo des cartes
#      activée / désactivée), même quand l'escalier est désactivé, et l'avatar de la carte Favoris est affiché par le
#      thème : changer une option dans la configuration du thème est immédiat, sans attente ni second rechargement.
#    - l'option « Boucle des systèmes » du thème (Désactivée par défaut) : EmulationStation fait toujours le tour de la
#      liste des systèmes (après la dernière carte, la première). Option désactivée : au bout de la liste, le carrousel
#      revient tout seul sur la carte du bout (petit rebond), comme sur le NXE, et l'escalier s'arrête à la dernière carte.
#      Le script crée pour cela /userdata/system/configs/emulationstation/scripts/system-selected/nxe360_noloop.sh
#      (ES le lance à chaque système sélectionné) ; il a besoin de la surveillance (WATCH="on").
#    - la « file de jaquettes » de la vue Carousel (comme les jeux du Marketplace NXE) : dans art/gstack/, pour chaque jeu,
#      des liens vers les jaquettes des 11 jeux suivants (rien n'est recopié ; petite copie réduite si le disque ne sait
#      pas faire de liens). Même ordre que la liste d'EmulationStation (tri par nom ou par dernière partie) ; avec un autre
#      tri, ou les dossiers affichés, le système n'a pas de file. Mise à jour par la surveillance quand une liste change.
#
#  INSTALLATION (une seule fois) : ce script est livré DANS le dossier du thème (il se met à jour avec lui).
#    1. copier « NXE360 - Installation.sh » (dossier du thème) dans /userdata/roms/ports/
#    2. Menu > Mettre à jour la liste des jeux, puis lancer « NXE360 - Installation » dans Ports
#    (ou en SSH : bash "/userdata/themes/NXE360/NXE360 - Installation.sh")
#    L'installation pose seulement de petits lanceurs (/userdata/system/scripts/nxe360_recent.sh et
#    /userdata/roms/ports/360sona.sh) qui appellent les scripts du thème actif.
#
#  Ensuite c'est automatique : Batocera l'appelle au début et à la fin de
#  chaque jeu ($1 = gameStart / gameStop, $2 = système, $5 = chemin de la ROM),
#  et la surveillance RetroAchievements démarre avec EmulationStation ($1 = watch).
#  Il ne fait RIEN si le thème actif n'est pas un thème NXE360 (le nom du dossier n'a pas d'importance).
#
#  MISE À JOUR : avec le thème (store Batocera). Le store efface tout le dossier du thème avant de remettre le nouveau :
#  le script remet alors tout seul les avatars 360sona (copie de secours dans /userdata/system/configs/nxe360/avatar)
#  et refait les images (derniers jeux, escalier, file de jaquettes).
# ============================================================================

THEME_NAME=""                                      # vide = détection automatique (n'importe quel nom de dossier : NXE360, NXE360v2...)
RA_POINTS="total"
WATCH="on"                                         # on / off : rechargement auto quand RetroAchievements change
STAIRS_MAX_WIDTH=3840                              # escalier : largeur maxi (en pixels) des images ; l'écran réel jusqu'à cette limite (3840 = 4K).
                                                   # Plus bas (ex. 1920) = dessin plus rapide et fichiers plus petits, mais image moins nette sur un écran 4K
# programmes à ne pas compter comme « jeux joués » (noms de fichiers, séparés par |)
EXCLUDE="360sona"
USERDATA="${NXE360_USERDATA:-/userdata}"          # (variable de test uniquement)
ES_SETTINGS="$USERDATA/system/configs/emulationstation/es_settings.cfg"
DATA_DIR="$USERDATA/system/configs/nxe360"
SELF="$(readlink -f "$0")"
ES_START_DIR="$USERDATA/system/configs/emulationstation/scripts/start"
LAUNCHER="$ES_START_DIR/nxe360_watch.sh"
ES_SEL_DIR="$USERDATA/system/configs/emulationstation/scripts/system-selected"
NOLOOP_HOOK="$ES_SEL_DIR/nxe360_noloop.sh"        # carrousel sans boucle (option « Boucle des systèmes : désactivée »)
NOLOOP_RUN="/var/run/nxe360"                       # en mémoire vive : rien n'est écrit sur le disque à chaque carte
NAVSOUND_HOOK="$ES_SEL_DIR/nxe360_navsound.sh"    # ancien fichier séparé des sons (supprimé : tout est dans nxe360_noloop.sh)
ES_SCRIPTS="$USERDATA/system/configs/emulationstation/scripts"
NAVGAME_HOOK="$ES_SCRIPTS/game-selected/nxe360_nav.sh"         # liste des jeux affichée : back.wav au retour vers les cartes
NAVSAVER_START="$ES_SCRIPTS/screensaver-start/nxe360_nav.sh"   # l'économiseur d'écran choisit des jeux : ne compte pas
NAVSAVER_STOP="$ES_SCRIPTS/screensaver-stop/nxe360_nav.sh"

# --- 1) seulement si le thème NXE360 est le thème actif -----------------------
active=$(grep -o 'name="ThemeSet" value="[^"]*"' "$ES_SETTINGS" 2>/dev/null | sed 's/.*value="//;s/"$//')
if [ -n "$THEME_NAME" ]; then
    [ "${active,,}" = "${THEME_NAME,,}" ] || exit 0
fi
[ -n "$active" ] || exit 0
THEME_DIR="$USERDATA/themes/$active"
[ -d "$THEME_DIR" ] || exit 0
# le thème actif est-il bien un NXE360 (quel que soit le nom de son dossier) ?
[ -f "$THEME_DIR/art/icon_nxe_0.png" ] && grep -q "nxe360_recent.sh" "$THEME_DIR/theme.xml" 2>/dev/null || exit 0

case "$1" in
    gameStart) action="start" ;;
    gameStop)  action="stop"  ;;
    refresh|"") action="refresh" ;;
    watch)     action="watch" ;;
    stairs)    action="stairs" ;;     # images de l'escalier (lancé par la surveillance)
    *) exit 0 ;;
esac

mkdir -p "$DATA_DIR" "$THEME_DIR/art/recent"

# avatars 360sona : copie de secours hors du thème (une mise à jour depuis le store efface tout le dossier du thème)
avatar_sync() {
    local a="$THEME_DIR/art/avatar" b="$DATA_DIR/avatar" f n
    [ -d "$a" ] || return 0
    mkdir -p "$b"
    if [ ! -e "$a/.nxe360_ok" ]; then                      # dossier du thème neuf (installation ou mise à jour) : avatars remis
        for f in "$b"/*; do
            n=${f##*/}
            [ -f "$f" ] && [ ! -e "$a/$n" ] && { ln -f "$f" "$a/$n" 2>/dev/null || cp -f "$f" "$a/$n"; }
        done
        : > "$a/.nxe360_ok"
    fi
    for f in "$b"/*; do [ -f "$f" ] && [ ! -e "$a/${f##*/}" ] && rm -f "$f"; done   # avatar retiré du thème : retiré de la copie
    for f in "$a"/*; do
        n=${f##*/}
        case "$n" in default*) continue ;; esac
        [ -f "$f" ] && ! [ "$f" -ef "$b/$n" ] && { ln -f "$f" "$b/$n" 2>/dev/null || cp -f "$f" "$b/$n"; }
    done
}
[ "$action" = "start" ] || [ "$action" = "stairs" ] || avatar_sync

# --- surveillance RetroAchievements (démarre avec EmulationStation) -----------
install_hook() {                                            # (ré)écrit un petit script lancé par ES seulement s'il a changé
    local f=$1; shift
    [ "$(cat "$f" 2>/dev/null)" = "$("$@")" ] && return
    mkdir -p "$(dirname "$f")"
    "$@" > "$f"
    chmod +x "$f"
}
watch_running() {
    local pid
    pid=$(cat "$DATA_DIR/watch.pid" 2>/dev/null)
    [ -n "$pid" ] && grep -qa "watch" "/proc/$pid/cmdline" 2>/dev/null
}
script_stamp() { stat -c %Y "$SELF" 2>/dev/null; }          # date du fichier script (en secondes)
watch_stop() {                                              # arrête la surveillance (seulement si le numéro enregistré est bien celui d'une surveillance)
    local pid i
    watch_running || return 0
    pid=$(cat "$DATA_DIR/watch.pid" 2>/dev/null)
    kill "$pid" 2>/dev/null
    for i in {1..20}; do
        kill -0 "$pid" 2>/dev/null || break
        sleep 0.25
    done
}
# Une surveillance lancée avec une ancienne version du script en garde le code en mémoire : quand le fichier a été remplacé,
# on la relance avec la nouvelle version (au démarrage d'ES, à « refresh » ou à la fin d'un jeu ; pas pendant qu'un jeu démarre).
if [ "$WATCH" = "on" ] && [ "$action" != "start" ] && [ "$action" != "stairs" ]; then
    stamp=$(script_stamp)
    if [ -n "$stamp" ] && watch_running && [ "$(cat "$DATA_DIR/watch.ver" 2>/dev/null)" != "$stamp" ]; then
        watch_stop
    fi
fi
if [ "$action" != "watch" ] && [ "$action" != "stairs" ]; then
    if [ "$WATCH" = "on" ]; then
        launcher_text() {
            echo '#!/bin/bash'
            echo '# NXE360 : au démarrage d EmulationStation, lance la surveillance RetroAchievements'
            echo '# (créé automatiquement par nxe360_recent.sh ; pour l arrêter : WATCH="off" dans ce script)'
            echo "S=\"$SELF\""
            echo "mkdir -p \"$NOLOOP_RUN\"; rm -f \"$NOLOOP_RUN\"/noloop.prev \"$NOLOOP_RUN\"/noloop.skip \"$NOLOOP_RUN\"/nav.prev \"$NOLOOP_RUN\"/nav.bounce \"$NOLOOP_RUN\"/nav.ingame \"$NOLOOP_RUN\"/nav.saver    # nouvelle session : carrousel remis à zéro"
            echo "rm -f \"$THEME_DIR/art/recent/toast.on\" \"$THEME_DIR/art/recent/toast.lost\" \"$NOLOOP_RUN/watch.alive\"    # pas de vieille notification au démarrage"
            echo '[ -f "$S" ] || exit 0                 # (lancé avec bash : marche même si le script a perdu ses droits d exécution)'
            echo 'if command -v setsid >/dev/null 2>&1; then'
            echo '    setsid bash "$S" watch </dev/null >/dev/null 2>&1 &'
            echo 'else'
            echo '    nohup bash "$S" watch </dev/null >/dev/null 2>&1 &'
            echo 'fi'
            echo 'exit 0'
        }
        install_hook "$LAUNCHER" launcher_text
        watch_running || { $(command -v setsid || echo nohup) bash "$SELF" watch </dev/null >/dev/null 2>&1 & }   # pas encore lancée
    else
        rm -f "$LAUNCHER"
        watch_stop
    fi
fi

# --- carrousel des systèmes sans boucle : petit script lancé par ES à chaque système sélectionné -----------
# (il ne fait rien tant que la surveillance ne lui donne pas la liste : option « Boucle des systèmes » activée, thème
#  NXE360 inactif, surveillance arrêtée...)
noloop_text() {
cat <<'HOOKEOF'
#!/bin/bash
# NXE360 : cartes système (créé automatiquement par nxe360_recent.sh, ne pas modifier).
# EmulationStation lance ce fichier à chaque système sélectionné ($1 = nom du système). Un seul fichier (un seul programme
# lancé par carte, le plus vite possible) qui fait, dans l'ordre :
#  1) carrousel SANS boucle : quand on vient de passer de la dernière carte à la première (ou l'inverse), il renvoie aussitôt
#     la touche inverse (rien si l'option « Boucle des systèmes » est activée ou si la surveillance ne tourne pas) ;
#  2) sons du dossier sounds/ du thème : back.wav au retour de la liste des jeux, panel-left.wav / panel-right.wav selon le
#     sens (rien si les sons de navigation sont coupés).
R=/var/run/nxe360
[ -d "$R" ] || mkdir -p "$R" 2>/dev/null
new=$1
bounce() {
    prev=
    { read -r prev < "$R/noloop.prev"; } 2>/dev/null
    printf '%s\n' "$new" > "$R/noloop.prev"                 # noté même avant que la liste soit prête (1re carte au démarrage)
    { IFS=$'\t' read -r first last stamp < "$R/noloop.list"; } 2>/dev/null || return
    printf -v now '%(%s)T' -1
    [ -n "$stamp" ] && [ $((now - stamp)) -lt 30 ] || return
    if [ -f "$R/noloop.skip" ]; then
        skip=
        read -r skip < "$R/noloop.skip"
        rm -f "$R/noloop.skip"
        [ "$skip" = "$new" ] && return                        # c'est le retour demandé juste avant
    fi
    if [ "$prev" = "$last" ] && [ "$new" = "$first" ]; then
        key=left back=$last
    elif [ "$prev" = "$first" ] && [ "$new" = "$last" ]; then
        key=right back=$first
    else
        return
    fi
    printf '%s\n' "$back" > "$R/noloop.skip"
    if ! { printf 'POST /input HTTP/1.0\r\nHost: 127.0.0.1\r\nContent-Type: text/plain\r\nContent-Length: %d\r\n\r\n%s' "${#key}" "$key" >&3
           read -r -t 2 _ <&3; } 3<>/dev/tcp/127.0.0.1/1234 2>/dev/null; then
        curl -s -m 2 -d "$key" http://127.0.0.1:1234/input >/dev/null 2>&1
    fi
    return
}
bounce
prev=
{ read -r prev < "$R/nav.prev"; } 2>/dev/null
printf '%s\n' "$new" > "$R/nav.prev"                    # noté même avant que la liste soit prête (1re carte au démarrage)
{ IFS= read -r stamp; IFS= read -r theme; IFS= read -r settings; IFS=$'\t' read -r -a names; } < "$R/nav.list" 2>/dev/null || exit 0
printf -v now '%(%s)T' -1
[ -n "$stamp" ] && [ $((now - stamp)) -lt 30 ] || exit 0
play() {
    [ -f "$1" ] || exit 0
    grep -q 'name="EnableSounds" value="false"' "$settings" 2>/dev/null && exit 0
    if command -v aplay >/dev/null 2>&1; then exec aplay -q "$1" </dev/null >/dev/null 2>&1
    elif command -v pw-play >/dev/null 2>&1; then exec pw-play "$1" </dev/null >/dev/null 2>&1
    elif command -v paplay >/dev/null 2>&1; then exec paplay "$1" </dev/null >/dev/null 2>&1
    fi
    exit 0
}
if mv "$R/nav.ingame" "$R/nav.ingame.$$" 2>/dev/null; then  # on sort d'une liste de jeux (un seul des deux appels d'ES gagne)
    rm -f "$R/nav.ingame.$$" "$R/nav.bounce"
    play "$theme/sounds/back.wav"
fi
[ -n "$prev" ] && [ "$prev" != "$new" ] || exit 0
n=${#names[@]} pi=-1 ni=-1
for i in "${!names[@]}"; do
    [ "${names[i]}" = "$prev" ] && pi=$i
    [ "${names[i]}" = "$new" ] && ni=$i
done
[ $pi -ge 0 ] && [ $ni -ge 0 ] || exit 0
d=$((ni - pi)) wrap=0
if [ $((d * 2)) -gt $n ]; then d=$((d - n)) wrap=1
elif [ $((-d * 2)) -gt $n ]; then d=$((d + n)) wrap=1
fi
if [ $wrap = 1 ] && [ -f "$R/noloop.list" ]; then          # sans boucle : le retour automatique au bout reste muet
    b=
    { read -r b < "$R/nav.bounce"; } 2>/dev/null
    rm -f "$R/nav.bounce"
    [ "$b" = "$new" ] && exit 0
    printf '%s\n' "$prev" > "$R/nav.bounce"
fi
if [ $d -gt 0 ]; then play "$theme/sounds/panel-right.wav"; else play "$theme/sounds/panel-left.wav"; fi
HOOKEOF
}
# --- son du carrousel selon le sens : panel-left.wav vers la gauche, panel-right.wav vers la droite -------------
# (EmulationStation n'a qu'un seul son de défilement pour les deux sens : ce petit script joue le bon à chaque carte)
# petits scripts compagnons : liste des jeux affichée (pour back.wav), économiseur d'écran (ses jeux ne comptent pas)
navgame_text() {
cat <<'HOOKEOF'
#!/bin/bash
# NXE360 : on est dans une liste de jeux (créé automatiquement par nxe360_recent.sh, ne pas modifier).
R=/var/run/nxe360
[ -f "$R/nav.list" ] && [ ! -f "$R/nav.saver" ] && : > "$R/nav.ingame"
exit 0
HOOKEOF
}
navsaver_text() {
cat <<HOOKEOF
#!/bin/bash
# NXE360 : économiseur d'écran $1 (créé automatiquement par nxe360_recent.sh, ne pas modifier).
R=/var/run/nxe360
HOOKEOF
if [ "$1" = "start" ]; then
    echo '[ -d "$R" ] && : > "$R/nav.saver"'
    echo 'rm -f "$R/nav.ingame"'
else
    echo 'rm -f "$R/nav.saver"'
fi
echo 'exit 0'
}
if [ "$action" != "stairs" ]; then
    rm -f "$NAVSOUND_HOOK"                  # ancienne version : les sons sont maintenant dans nxe360_noloop.sh
    if [ "$WATCH" = "on" ]; then
        install_hook "$NAVGAME_HOOK" navgame_text
        install_hook "$NAVSAVER_START" navsaver_text start
        install_hook "$NAVSAVER_STOP" navsaver_text stop
        install_hook "$NOLOOP_HOOK" noloop_text
    else
        rm -f "$NOLOOP_HOOK" "$NAVGAME_HOOK" "$NAVSAVER_START" "$NAVSAVER_STOP" "$THEME_DIR/art/recent/navsound.on"
    fi
fi

# --- 2) le travail (Python 3, présent dans Batocera) --------------------------
RA_POINTS="$RA_POINTS" NXE360_EXCLUDE="$EXCLUDE" NXE360_SELF="$SELF" NXE360_STAIRS_MAXW="$STAIRS_MAX_WIDTH" python3 - "$action" "$2" "$5" "$USERDATA" "$THEME_DIR" "$DATA_DIR" >>"$DATA_DIR/nxe360_recent.log" 2>&1 <<'PYEOF'
import glob, json, os, re, shutil, subprocess, sys, time
import urllib.parse, urllib.request
import xml.etree.ElementTree as ET

action, system, rom, userdata, theme_dir, data_dir = sys.argv[1:7]
ROMS = os.path.join(userdata, "roms")
HISTORY = os.path.join(data_dir, "recent.txt")
OUT = os.path.join(theme_dir, "art", "recent")
SLOTS, CANVAS, LOGO = 4, 256, 220          # 4 vignettes, image 256x256, logo dans 220x220

def log(msg):
    print(time.strftime("%Y-%m-%d %H:%M:%S"), action, msg, flush=True)

CONF = os.path.join(userdata, "system", "batocera.conf")
ES_SETTINGS = os.path.join(userdata, "system", "configs", "emulationstation", "es_settings.cfg")

def norm(p):
    return os.path.normpath(p)

def _rm(*paths):
    """Supprime des fichiers, sans erreur s'ils n'existent pas."""
    for p in paths:
        try:
            os.remove(p)
        except OSError:
            pass

def _vars_xml(comment, pairs):
    """Petit fichier de variables lu par le thème (même format pour tous les fichiers écrits par le script)."""
    return ('<?xml version="1.0" encoding="UTF-8"?>\n'
            f'<!-- NXE360 : {comment} -->\n'
            '<theme>\n    <formatVersion>7</formatVersion>\n    <variables>\n'
            + "".join(f'        <{k}>{v}</{k}>\n' for k, v in pairs) +
            '    </variables>\n</theme>\n')

def _write_if_changed(dst, content):
    """Écrit dst (atomique) seulement si son contenu change. Renvoie True s'il a été écrit."""
    try:
        with open(dst, encoding="utf-8") as f:
            if f.read() == content:
                return False
    except OSError:
        pass
    try:
        os.makedirs(os.path.dirname(dst), exist_ok=True)
        _write_atomic(dst, content)
    except OSError:
        return False
    return True

def system_root(sysname, rompath):
    """Dossier du système (/userdata/roms/<système>) qui contient gamelist.xml."""
    cand = os.path.join(ROMS, sysname) if sysname else ""
    if cand and os.path.isdir(cand) and norm(rompath).startswith(norm(cand) + os.sep):
        return cand
    rel = os.path.relpath(rompath, ROMS)
    if not rel.startswith(".."):
        return os.path.join(ROMS, rel.split(os.sep)[0])
    return os.path.dirname(rompath)

def read_history():
    items = []
    try:
        with open(HISTORY, encoding="utf-8") as f:
            for line in f:
                line = line.rstrip("\n")
                if "\t" in line:
                    s, r = line.split("\t", 1)
                    items.append((s, r))
    except FileNotFoundError:
        pass
    return items

def write_history(items):
    seen, out = set(), []
    for s, r in items:
        key = norm(r)
        if key in seen:
            continue
        seen.add(key)
        out.append((s, r))
    tmp = HISTORY + ".tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        for s, r in out[:30]:
            f.write(f"{s}\t{r}\n")
    os.replace(tmp, HISTORY)
    return out

def seed_from_gamelists():
    """Première fois : on part des dates « dernière partie » enregistrées par Batocera."""
    found = []
    for gl in glob.glob(os.path.join(ROMS, "*", "gamelist.xml")):
        root = os.path.dirname(gl)
        try:
            for g in ET.parse(gl).getroot().iter("game"):
                lp, p = (g.findtext("lastplayed") or "").strip(), (g.findtext("path") or "").strip()
                if lp and p:
                    found.append((lp, os.path.basename(root), norm(os.path.join(root, p))))
        except Exception as e:
            log(f"gamelist illisible {gl} : {e}")
    found.sort(reverse=True)
    return [(s, r) for _, s, r in found[:20]]

_parsed = {}

def clean_name(stem):
    """« Super Mario World (USA) [!] » -> « Super Mario World »."""
    n = re.sub(r"\s*[\(\[][^\)\]]*[\)\]]", "", stem).replace("_", " ").strip()
    return n or stem

ART_TAGS = ("fanart", "image", "titleshot", "thumbnail")          # images qui remplissent le carré
LOGO_TAGS = ("marquee", "wheel")                                   # logos (fond transparent)
ART_FILES = ("fanart", "image", "titleshot", "thumb")
LOGO_FILES = ("marquee", "wheel")

def find_media(sysname, rompath):
    """Image du jeu pour la vignette. Renvoie (fichier ou None, "art" | "logo", nom du jeu)."""
    root = system_root(sysname, rompath)
    found = {}
    name = ""
    gl = os.path.join(root, "gamelist.xml")
    if os.path.isfile(gl):
        try:
            target = norm(rompath)
            if gl not in _parsed:                       # chaque gamelist n'est lu qu'une fois
                _parsed[gl] = ET.parse(gl).getroot()
            for g in _parsed[gl].iter("game"):
                p = (g.findtext("path") or "").strip()
                if not p or norm(os.path.join(root, p)) != target:
                    continue
                name = (g.findtext("name") or "").strip()
                for tag in ART_TAGS + LOGO_TAGS:
                    v = (g.findtext(tag) or "").strip()
                    if v and os.path.isfile(norm(os.path.join(root, v))):
                        found.setdefault(tag, norm(os.path.join(root, v)))
                break
        except Exception as e:
            log(f"gamelist illisible {gl} : {e}")
    stem = os.path.splitext(os.path.basename(rompath))[0]
    name = name or clean_name(stem)
    for kind, tags, suffixes, exts in (("art", ART_TAGS, ART_FILES, ("jpg", "png", "jpeg")),
                                       ("logo", LOGO_TAGS, LOGO_FILES, ("png", "jpg", "jpeg"))):
        for tag in tags:
            if tag in found:
                return found[tag], kind, name
        for suffix in suffixes:
            for ext in exts:
                f = os.path.join(root, "images", f"{stem}-{suffix}.{ext}")
                if os.path.isfile(f):
                    return f, kind, name
    return None, "", name

TILE = "0x355A0B"                      # vert foncé NXE (fond des vignettes logo / sans image)

def render(src, dst, kind="art"):
    """art  : image recadrée pour remplir tout le carré 256x256 (pas de bandes, pas de fond noir)
       logo : logo centré sur un carré vert foncé"""
    tmp = dst + ".tmp.png"
    if kind == "art":
        cmd = ["ffmpeg", "-y", "-v", "error", "-i", src, "-vf",
               f"scale={CANVAS}:{CANVAS}:force_original_aspect_ratio=increase:flags=lanczos,"
               f"crop={CANVAS}:{CANVAS},format=rgb24", "-frames:v", "1", tmp]
    else:
        cmd = ["ffmpeg", "-y", "-v", "error", "-f", "lavfi", "-i", f"color=c={TILE}:s={CANVAS}x{CANVAS}",
               "-i", src, "-filter_complex",
               f"[1:v]scale={LOGO}:{LOGO}:force_original_aspect_ratio=decrease:flags=lanczos[l];"
               f"[0:v][l]overlay=(W-w)/2:(H-h)/2:format=auto,format=rgb24", "-frames:v", "1", tmp]
    ok = False
    if shutil.which("ffmpeg"):
        r = subprocess.run(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)
        ok = r.returncode == 0 and os.path.isfile(tmp)
        if not ok:
            log(f"ffmpeg a échoué sur {src} : {r.stderr.decode(errors='ignore').strip()}")
    if not ok:
        shutil.copyfile(src, tmp)          # secours : copie telle quelle
    os.replace(tmp, dst)

def wrap(name, width=12, maxlines=2):
    """Coupe le nom en 2 lignes au plus ; la dernière ligne est remplie puis terminée par « … » si besoin."""
    words, lines = name.split(), []
    while words and len(lines) < maxlines - 1:
        cur = words.pop(0)
        while words and len(cur) + 1 + len(words[0]) <= width:
            cur += " " + words.pop(0)
        lines.append(cur[:width + 2] + ("…" if len(cur) > width + 2 else ""))
    if words:
        rest = " ".join(words)
        lines.append(rest if len(rest) <= width + 1 else rest[:width].rstrip() + "…")
    return lines

ICON = os.path.join(theme_dir, "art", "icon_nxe_0.png")                 # manette NXE du thème
FONT = os.environ.get("NXE360_FONT") or next((f for f in (os.path.join(theme_dir, "fonts", "xenonclatin.ttf"),
                                                          os.path.join(theme_dir, "fonts", "Conv.ttf")) if os.path.isfile(f)),
                                                os.path.join(theme_dir, "fonts", "Conv.ttf"))

def placeholder(name, dst):
    """Pas d'image pour ce jeu : petite manette NXE + nom du jeu sur fond vert (256x256)."""
    tmp = dst + ".tmp.png"
    lines = wrap(name, width=10)
    # a) Python Imaging Library, si présente
    try:
        from PIL import Image, ImageDraw, ImageFont
        im = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 255))
        top, bot = (74, 112, 14), (34, 56, 7)            # dégradé vert NXE, plus clair en haut
        for yy in range(CANVAS):
            t = yy / (CANVAS - 1)
            im.paste(tuple(int(a + (b - a) * t) for a, b in zip(top, bot)) + (255,), (0, yy, CANVAS, yy + 1))
        if os.path.isfile(ICON):
            ic = Image.open(ICON).convert("RGBA")
            box = ic.getchannel("A").point(lambda v: 255 if v > 8 else 0).getbbox()
            if box:
                ic = ic.crop(box)                       # on enlève les marges vides de l'icône
            ic.thumbnail((170, 96))
            im.alpha_composite(ic, ((CANVAS - ic.width) // 2, 22 + (96 - ic.height) // 2))
        d = ImageDraw.Draw(im)
        try:
            size = 40
            ft = ImageFont.truetype(FONT, size)
            while size > 22 and max(d.textlength(l, font=ft) for l in lines) > CANVAS - 20:
                size -= 2                               # nom trop large : on réduit la police
                ft = ImageFont.truetype(FONT, size)
        except Exception:
            ft = ImageFont.load_default()
        y = 128 if len(lines) > 1 else 150
        for l in lines:
            w = d.textlength(l, font=ft)
            x = (CANVAS - w) / 2
            d.text((x + 2, y + 2), l, font=ft, fill=(0, 0, 0, 110))
            d.text((x, y), l, font=ft, fill=(255, 255, 255, 240))
            y += 46
        im.save(tmp)
        os.replace(tmp, dst)
        return "pil"
    except ImportError:
        pass
    except Exception as e:
        log(f"vignette PIL impossible : {e}")
    # b) ffmpeg : icône + texte (drawtext), puis icône seule si drawtext n'est pas disponible
    if shutil.which("ffmpeg") and os.path.isfile(ICON):
        txts = []
        for i, l in enumerate(lines):
            tf = os.path.join(data_dir, f"line{i}.txt")
            with open(tf, "w", encoding="utf-8") as f:
                f.write(l)
            txts.append(tf)
        # icône du thème (manette, déjà sans marges)
        base = (f"[1:v]scale=170:96:force_original_aspect_ratio=decrease[ic];"
                f"[0:v][ic]overlay=(W-w)/2:22+(96-h)/2:format=auto")
        y0 = 128 if len(lines) > 1 else 150
        dt = "".join(f",drawtext=fontfile='{FONT}':textfile='{tf}':fontcolor=white@0.94:fontsize=40:"
                     f"x=(w-text_w)/2:y={y0 + 46 * i}:shadowcolor=black@0.45:shadowx=2:shadowy=2"
                     for i, tf in enumerate(txts))
        for graph, how in ((base + dt, "ffmpeg"), (base, "ffmpeg-icone")):
            r = subprocess.run(["ffmpeg", "-y", "-v", "error", "-f", "lavfi", "-i",
                                f"color=c={TILE}:s={CANVAS}x{CANVAS},format=rgba", "-i", ICON,
                                "-filter_complex", graph, "-frames:v", "1", tmp],
                               stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)
            if r.returncode == 0 and os.path.isfile(tmp):
                os.replace(tmp, dst)
                return how
        log(f"ffmpeg : vignette impossible ({r.stderr.decode(errors='ignore').strip()})")
    # c) dernier recours : la manette seule
    if os.path.isfile(ICON):
        render(ICON, dst, "logo")
        return "icone"
    return None

def read_conf():
    """Lignes global.retroachievements* de batocera.conf."""
    conf = {}
    try:
        with open(CONF, encoding="utf-8", errors="ignore") as f:
            for line in f:
                line = line.strip()
                if line.startswith("global.retroachievements") and "=" in line:
                    k, v = line.split("=", 1)
                    conf[k.strip()] = v.strip()
    except FileNotFoundError:
        pass
    return conf

def cache_user(conf):
    """Garde le pseudo RetroAchievements pour le thème (art/recent/ra_user.xml), même si RA est désactivé."""
    user = re.sub(r"[^A-Za-z0-9_.-]", "", conf.get("global.retroachievements.username", ""))
    if not user:
        return
    shown = user[0].upper() + user[1:]  # affichage : 1re lettre en majuscule ; l'URL de l'avatar garde le pseudo tel quel
    if _write_if_changed(os.path.join(OUT, "ra_user.xml"),
                         _vars_xml("pseudo RetroAchievements gardé en cache (créé par nxe360_recent.sh)",
                                   (("raCachedUser", user), ("raDisplayUser", shown)))):
        log(f"pseudo RetroAchievements gardé en cache : {user}")

def update_ra_points():
    """Points RetroAchievements avec le compte enregistré dans Batocera (batocera.conf)."""
    dst = os.path.join(OUT, "ra_points.dat")
    conf = read_conf()
    cache_user(conf)
    user = conf.get("global.retroachievements.username", "")
    if conf.get("global.retroachievements", "0") != "1" or not user:
        # RetroAchievements désactivé : on garde le dernier score connu (affiché même déconnecté)
        log("RetroAchievements désactivé : pseudo et points gardés en cache")
        return
    token, password = conf.get("global.retroachievements.token", ""), conf.get("global.retroachievements.password", "")
    if not token and not password:
        log("RetroAchievements : ni jeton ni mot de passe dans batocera.conf")
        return
    data = None
    for r in ("login2", "login"):
        form = {"r": r, "u": user}
        form.update({"t": token} if token else {"p": password})
        try:
            req = urllib.request.Request("https://retroachievements.org/dorequest.php",
                                         data=urllib.parse.urlencode(form).encode(),
                                         headers={"User-Agent": "NXE360-theme/1.0 (Batocera)"})
            with urllib.request.urlopen(req, timeout=8) as resp:
                data = json.loads(resp.read().decode("utf-8", "ignore"))
            if data.get("Success"):
                break
        except Exception as e:
            log(f"RetroAchievements injoignable ({r}) : {e}")
            data = None
    if not data or not data.get("Success"):
        log(f"RetroAchievements : connexion refusée ({(data or {}).get('Error', 'pas de réponse')}) - points inchangés")
        return
    hard, soft = int(data.get("Score") or 0), int(data.get("SoftcoreScore") or 0)
    mode = os.environ.get("RA_POINTS", "auto")
    pts = {"hardcore": hard, "softcore": soft, "total": hard + soft}.get(mode, hard if hard > 0 else soft)
    tmp = dst + ".tmp"
    with open(tmp, "wb") as f:
        f.truncate(max(0, pts))             # fichier « creux » : ne prend pas de place sur le disque
    os.replace(tmp, dst)
    log(f"RetroAchievements : {pts} points (hardcore {hard}, softcore {soft}, mode {mode})")
    pads_layout()

PADS_RIGHT, PADS_Y, PADS_W, PADS_H, PADS_GAP = 0.8672, 0.1420, 0.2500, 0.0300, 0.0100

def pads_layout():
    """Place des manettes connectées (en haut à droite) : juste à gauche des points RetroAchievements, d'après leur
    largeur réelle à l'écran (même police et même taille que le thème). Écrit art/recent/pads.xml ; renvoie True s'il a
    changé (le thème le relit au prochain rechargement)."""
    pts_file = os.path.join(OUT, "ra_points.dat")
    text = ""
    if os.path.isfile(pts_file):
        text = "%d Ⓖ" % os.path.getsize(pts_file)
    tw = 0.0
    if text:
        try:
            from PIL import ImageFont
            W, H = screen_size()
            font = ImageFont.truetype(os.path.join(theme_dir, "fonts", "xenonclatin.ttf"), max(8, int(round(0.0357 * H))))
            tw = font.getlength(text) / float(W)
        except Exception:
            tw = 0.075                       # pas de Python Imaging Library / police : place pour 4-5 chiffres
    right = PADS_RIGHT - tw - PADS_GAP
    x0 = max(0.0, right - PADS_W)
    if not _write_if_changed(os.path.join(OUT, "pads.xml"),
                             _vars_xml("place des manettes connectées (écrit par nxe360_recent.sh, ne pas modifier)",
                                       (("padsPos", f"{x0:.4f} {PADS_Y:.4f}"), ("padsSize", f"{right - x0:.4f} {PADS_H:.4f}")))):
        return False
    log(f"manettes : placées juste à gauche des points ({text or 'pas de points'})")
    return True

EXCLUDE = os.environ.get("NXE360_EXCLUDE", "")

def excluded(rompath):
    return bool(EXCLUDE) and re.search(EXCLUDE, os.path.basename(rompath), re.I) is not None

# ---------------------------------------------------------------------------------
#  Surveillance : quand RetroAchievements est activé / désactivé (ou le compte change),
#  on met à jour pseudo + points puis on demande à EmulationStation de recharger la liste.
#  Sans ça, la carte garde l'ancien état jusqu'à « mettre à jour les listes de jeux » :
#  EmulationStation ne recalcule le contenu des cartes qu'au chargement de la liste.
# ---------------------------------------------------------------------------------
ES_API = "http://127.0.0.1:1234"           # serveur local d'EmulationStation (toujours actif)
_opener = urllib.request.build_opener(urllib.request.ProxyHandler({}))

def es_status(path):
    try:
        with _opener.open(ES_API + path, timeout=10) as r:
            return r.status
    except Exception:
        return None

def theme_active():
    v = es_setting("ThemeSet", None)        # illisible ou absent : on considère le thème actif
    return v is None or v.lower() == os.path.basename(os.path.normpath(theme_dir)).lower()

def ra_state(conf):
    return (conf.get("global.retroachievements", "0") == "1", conf.get("global.retroachievements.username", ""))

def mtime(p):
    try:
        return os.stat(p).st_mtime_ns
    except OSError:
        return 0

# ---------------------------------------------------------------------------------
#  ESCALIER  (option « Escalier : activé » de la configuration du thème)
#
#  EmulationStation ne sait pas rétrécir les cartes une à une comme le NXE. Ce bloc prépare donc, pour chaque
#  système, UNE image (art/stair/g<N>/<système>.png) qui montre les cartes suivantes déjà rétrécies, marche
#  après marche. Le thème (subsets/escalier/on.xml) l'affiche derrière le carrousel et n'affiche plus les cartes
#  voisines du carrousel ; la carte sélectionnée reste la vraie carte du carrousel.
#  Comme sur le NXE : la grande carte + 5 marches = 6 cartes à l'écran ; chaque marche passe sous la précédente
#  (tailles STAIR_WM et bords STAIR_RX, mesurés sur une capture du NXE).
#
#  - dessin : Pillow (Python Imaging Library) uniquement, sinon l'option reste sans effet (carrousel d'origine)
#  - rien n'est publié tant que TOUTES les images ne sont pas prêtes (art/stair/ready.xml écrit en dernier)
#  - chaque publication = un nouveau dossier g<N> (ES garde les images en mémoire par chemin) ; les images
#    inchangées sont reprises de la publication précédente (liens durs, sinon copies)
#  - tout est recalculé seulement si quelque chose a changé (empreinte de chaque image dans manifest.json)
# ---------------------------------------------------------------------------------
import bisect, math, struct
STAIR_DIR = os.path.join(theme_dir, "art", "stair")
STAIR_LOCK = os.path.join(data_dir, "stairs.lock")
STAIR_VERSION = 5                                   # à augmenter quand le dessin change : tout est refait
STAIR_STEPS = 5                                     # marches préparées (celles qui sortent de l'écran sont ignorées) : avec la grande carte, 6 cartes
STAIR_WM = (None, 1.0, 0.817, 0.675, 0.578, 0.505)  # taille de chaque marche / carte voisine d'origine (mesuré sur le NXE)
STAIR_RX = (None, 1.0, 1.6254, 2.0016, 2.2862, 2.5048)  # bord droit de chaque marche, compté depuis le bord gauche de la 1re, en largeurs de
                                                        # la 1re (mesuré sur le NXE) : chaque marche passe SOUS la précédente, la plus proche est devant
STAIR_FAV = "auto-favorites"                        # système qui porte la carte profil (choisi à chaque passage : profile_theme)
PROFILE_PREF = "xbox360"                            # la carte profil va sur la carte Xbox 360 quand ce système est présent

def profile_theme(systems):
    """Système qui porte la carte profil : Xbox 360 s'il est dans la liste (il est près du début, alors qu'ES range les
    collections - donc Favoris - à la fin), sinon Favoris."""
    return PROFILE_PREF if any(s.get("theme") == PROFILE_PREF for s in systems or []) else "auto-favorites"

def profile_sync(systems):
    """Écrit art/recent/profile.xml : profileTheme (système qui porte la carte profil), loopFirst / loopLast (premier et
    dernier système de la liste : sans boucle, le thème ne montre jamais la carte de l'autre bout pendant le rebond).
    Renvoie True s'il a changé (ES doit recharger)."""
    if not systems:
        return False
    th = profile_theme(systems)
    if not _write_if_changed(os.path.join(OUT, "profile.xml"),
                             _vars_xml("carte profil et bouts de la liste des systèmes (créé par nxe360_recent.sh, ne pas modifier)",
                                       (("profileTheme", th), ("loopFirst", systems[0]["name"]), ("loopLast", systems[-1]["name"])))):
        return False
    log(f"carte profil portée par : {'Xbox 360' if th == PROFILE_PREF else 'Favoris'}")
    return True
SELF_PATH = os.environ.get("NXE360_SELF", "")
# codes de sortie de « stairs » : 0 rien à faire, 10 images publiées ou retirées (ES doit recharger), 11 images mises à jour
# sur place, 2 ES pas prêt, 3 ES occupé (jeu en cours), 1 impossible (Pillow absent, erreur...)

def es_setting(name, default=""):
    """Valeur d'un réglage d'EmulationStation (es_settings.cfg)."""
    try:
        with open(ES_SETTINGS, encoding="utf-8", errors="ignore") as f:
            m = re.search(r'name="' + re.escape(name) + r'"\s+value="([^"]*)"', f.read())
    except OSError:
        return default
    return m.group(1) if m else default

def stairs_enabled():
    return es_setting("subset.stairs", "off") == "on"

_LOOP_THEME = {}

def loop_enabled():
    """Option « Boucle des systèmes » du thème. Activée : carrousel d'origine (après la dernière carte, la première).
    Désactivée (par défaut) : la liste a un début et une fin, comme sur le NXE (voir NoLoop). Un theme.xml qui n'a pas
    encore cette option garde le carrousel d'origine."""
    p = os.path.join(theme_dir, "theme.xml")
    m = mtime(p)
    if _LOOP_THEME.get("m") != m:
        try:
            with open(p, encoding="utf-8", errors="ignore") as f:
                has = 'subset="loop"' in f.read()
        except OSError:
            has = False
        _LOOP_THEME.update(m=m, has=has)
    return (not _LOOP_THEME["has"]) or es_setting("subset.loop", "off") == "on"

def stat_sig(path):
    """(taille, date) d'un fichier : change dès qu'il est remplacé ou modifié."""
    try:
        st = os.stat(path)
        return (st.st_size, st.st_mtime_ns)
    except OSError:
        return None

def stair_vars(conf=None, pick=None):
    """Variables du thème comme ES les voit : bloc <variables> de theme.xml, pseudo gardé en cache, puis les fichiers
    des options du thème (langue, vidéo des cartes, avatar, animation de l'avatar). pick = {option: fichier} impose un
    choix (variantes de l'escalier : chaque langue, chaque réglage de la vidéo des cartes)."""
    v = {}
    try:
        root = ET.parse(os.path.join(theme_dir, "theme.xml")).getroot()
    except Exception as e:
        log(f"escalier : theme.xml illisible ({e})")
        return v

    def add(el):
        for e in el:
            if isinstance(e.tag, str):
                v[e.tag] = (e.text or "").strip()

    def add_file(rel):
        try:
            r = ET.parse(os.path.join(theme_dir, rel)).getroot()
        except Exception:
            return
        for vs in r.findall("variables"):
            add(vs)

    for vs in root.findall("variables"):
        add(vs)
    conf = conf if conf is not None else read_conf()
    user = conf.get("global.retroachievements.username", "") if conf.get("global.retroachievements", "0") == "1" else ""
    for k in ("raCachedUser", "raDisplayUser"):
        v[k] = v.get(k, "").replace("${cheevos.username}", user)
    add_file(os.path.join("art", "recent", "ra_user.xml"))            # pseudo gardé en cache (prioritaire)
    by_id = {}
    for inc in root.findall("include"):
        sid = inc.get("subset")
        if sid:
            by_id.setdefault(sid, []).append((inc.get("name", ""), (inc.text or "").strip()))
    for sid in ("language", "cardvideo", "avatar", "animation"):
        lst = by_id.get(sid) or []
        if lst:
            if pick and pick.get(sid):
                add_file(pick[sid])
                continue
            want = es_setting("subset." + sid)
            add_file(next((p for n, p in lst if n == want), lst[0][1]))
    return v

STAIR_OPTIONS = ("language", "cardvideo", "loop")   # options du thème qui changent les images : une variante par choix

def stair_choices():
    """Choix possibles des options du thème qui changent les images de l'escalier (includes subset= de theme.xml) :
    ({option: [(nom, fichier, jeton), ...]}, {option: jeton du choix actuel}). Le jeton est le nom du fichier sans
    extension (fr, en, video_on, video_off, on, off) : c'est la valeur des variables stairLang / stairVideo / stairLoop
    du thème, qui choisit ainsi tout seul la bonne variante (changement d'option immédiat, sans attendre le script)."""
    out, cur = {}, {}
    try:
        root = ET.parse(os.path.join(theme_dir, "theme.xml")).getroot()
    except Exception:
        return out, cur
    for inc in root.findall("include"):
        sid = inc.get("subset")
        if sid in STAIR_OPTIONS:
            path = (inc.text or "").strip()
            out.setdefault(sid, []).append((inc.get("name", ""), path, os.path.splitext(os.path.basename(path))[0]))
    for sid, lst in out.items():
        want = es_setting("subset." + sid)
        cur[sid] = next((t for n, p, t in lst if n == want), lst[0][2])
    return out, cur

def stair_geometry():
    """Réglages du carrousel des systèmes (theme.xml, SANS l'option Escalier), en fractions de l'écran."""
    g = {"pos": (0.07502, 0.16727), "size": (1.46517, 0.78), "logoSize": (0.26134, 0.34268), "logoScale": 1.3437,
         "logoPos": (0.03610, -1.0), "spacing": 1.0035, "count": 6}
    try:
        root = ET.parse(os.path.join(theme_dir, "theme.xml")).getroot()
        car = None
        for view in root.findall("view"):
            if view.get("name") == "system":
                for c in view.findall("carousel"):
                    if c.get("name") == "systemcarousel":
                        car = c
        if car is not None:
            def nums(tag, n):
                e = car.find(tag)
                try:
                    a = [float(x) for x in (e.text or "").split()]
                    return a if len(a) == n else None
                except (AttributeError, ValueError):
                    return None
            for tag, key, n in (("pos", "pos", 2), ("size", "size", 2), ("logoSize", "logoSize", 2), ("logoPos", "logoPos", 2)):
                a = nums(tag, n)
                if a:
                    g[key] = tuple(a)
            for tag, key in (("logoScale", "logoScale"), ("scaledLogoSpacing", "spacing"), ("maxLogoCount", "count")):
                a = nums(tag, 1)
                if a:
                    g[key] = a[0]
    except Exception as e:
        log(f"escalier : réglages du carrousel illisibles, valeurs par défaut ({e})")
    g["count"] = max(1, int(round(g["count"])))
    return g

def _stair_box(geo, csize):
    """Carte sélectionnée du modèle (logoSize x logoScale, posée en logoPos dans le carrousel de theme.xml) : (gauche, haut,
    largeur, hauteur) en fractions de l'écran, ou None si un réglage est illisible."""
    try:
        cw, ch = (float(v) for v in csize.split())
        cx, cy = geo["pos"]
        lw, lh = geo["logoSize"]
        lpx, lpy = geo["logoPos"]
        scale = geo["logoScale"]
        wb, hb = lw * scale, lh * scale
        if wb <= 0 or hb <= 0:
            return None
    except (KeyError, ValueError, TypeError):
        return None
    x0 = cx + lpx + lw / 2.0 if lpx >= 0 else cx + (cw - lw) / 2.0        # centre de la carte sélectionnée (écran)
    y0 = cy + (lpy if lpy >= 0 else (ch - lh) / 2.0) + lh / 2.0
    return x0 - wb / 2.0, y0 - hb / 2.0, wb, hb

def stair_extra(geo, csize, boxes, systems, steps):
    """Variables de plus pour le thème (script à jour) :
       - stairVar = v2 : toutes les variantes sont prêtes (art/stair/g<N>/<connecté>.<langue>.<boucle>.<vidéo>/), le thème
         choisit lui-même celle des options en cours ;
       - l'avatar de la carte Favoris dans l'escalier, affiché par le thème : sa place à chaque marche k (stairAv<k>Pos /
         stairAv<k>Size, repère de la carte sélectionnée) et le système dont l'escalier montre la carte Favoris à la marche k,
         sans boucle (stairFavN<k>) et avec (stairFavL<k>) ; « - » = aucun."""
    out = [("stairVar", "v2")]
    n = len(systems)
    fav = next((i for i, s in enumerate(systems) if s["theme"] == STAIR_FAV), -1)
    box = _stair_box(geo, csize)
    bx = {b[0]: b for b in boxes}
    for k in range(1, STAIR_STEPS + 1):
        ok = fav >= 0 and box is not None and k in bx and k <= steps
        nn = systems[fav - k]["name"] if ok and fav - k >= 0 else "-"
        ll = systems[(fav - k) % n]["name"] if ok else "-"
        p = z = "0 0"
        if ok:
            _, x, y, w, h = bx[k]
            left, top, wb, hb = box
            p = f"{_fmt((x + 0.7650 * w - left) / wb)} {_fmt((y + 0.4896 * h - top) / hb)}"
            z = f"{_fmt(1.3897 * w / wb)} {_fmt(1.8842 * h / hb)}"
        out += [(f"stairFavN{k}", nn), (f"stairFavL{k}", ll), (f"stairAv{k}Pos", p), (f"stairAv{k}Size", z)]
    return out

def stair_local(geo, pos, size, csize):
    """Position et taille de l'image des marches DANS LE REPÈRE DE LA CARTE (en fractions de la carte sélectionnée).
    Le thème accroche l'image des marches de chaque système à sa carte (effet caméra : quand on change de carte, le moteur
    déplace, zoome et fond l'image avec la carte). Il lui faut donc la place de l'image par rapport à la carte, pas à l'écran.
    La carte du modèle mesure logoSize x logoScale ; sélectionnée, elle est posée en logoPos (carrousel de theme.xml, pos).
    Renvoie (« x y », « largeur hauteur »), ou None si un réglage est illisible."""
    box = _stair_box(geo, csize)
    try:
        px, py = (float(v) for v in pos.split())
        sw, sh = (float(v) for v in size.split())
    except ValueError:
        return None
    if box is None:
        return None
    left, top, wb, hb = box
    return f"{_fmt((px - left) / wb)} {_fmt((py - top) / hb)}", f"{_fmt(sw / wb)} {_fmt(sh / hb)}"

def stair_systems():
    """Systèmes affichés par le carrousel, dans l'ordre d'ES (API locale). None si ES ne répond pas."""
    try:
        with _opener.open(ES_API + "/systems", timeout=10) as r:
            data = json.loads(r.read().decode("utf-8", "ignore"))
    except Exception:
        return None
    out = []
    for s in data if isinstance(data, list) else []:
        if not isinstance(s, dict) or not s.get("name"):
            continue
        if str(s.get("visible", "true")).lower() != "true":
            continue
        out.append({"name": str(s["name"]), "fullname": str(s.get("fullname") or s["name"]),
                    "manufacturer": str(s.get("manufacturer") or ""), "theme": str(s.get("theme") or s["name"])})
    return out

def has_ip():
    """Équivalent de {global:network} : une carte réseau (eth, wlan...) a-t-elle une adresse IP ?"""
    try:
        import socket, fcntl, struct
        for n in os.listdir("/sys/class/net"):
            if not n.startswith(("eth", "wlan", "mlan", "en", "wl", "p2p", "usb")):
                continue
            try:
                s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
                try:
                    ip = socket.inet_ntoa(fcntl.ioctl(s.fileno(), 0x8915, struct.pack("256s", n[:15].encode()))[20:24])
                finally:
                    s.close()
                if ip and ip != "0.0.0.0":
                    return True
            except OSError:
                continue
    except Exception:
        pass
    return False

def screen_size():
    """Taille de l'écran d'ES (les images sont dessinées au pixel près), plafonnée à STAIRS_MAX_WIDTH de large."""
    w = h = 0
    forced = os.environ.get("NXE360_SCREEN", "")
    m = re.search(r"(\d{3,5})\s*x\s*(\d{3,5})", forced)
    if not m and shutil.which("batocera-resolution"):
        try:
            out = subprocess.run(["batocera-resolution", "currentResolution"], stdout=subprocess.PIPE,
                                 stderr=subprocess.DEVNULL, timeout=5).stdout.decode(errors="ignore")
            m = re.search(r"(\d{3,5})\s*x\s*(\d{3,5})", out)
        except Exception:
            m = None
    if m:
        w, h = int(m.group(1)), int(m.group(2))
    else:
        try:
            with open("/sys/class/graphics/fb0/virtual_size") as f:
                w, h = [int(x) for x in f.read().strip().split(",")[:2]]
        except Exception:
            w = h = 0
    if not (w > 0 and h > 0):
        w, h = 1920, 1080
    try:
        cap = int(os.environ.get("NXE360_STAIRS_MAXW") or 3840)
    except ValueError:
        cap = 3840
    cap = max(640, min(cap, 7680))
    if w > cap:
        h, w = int(round(h * float(cap) / w)), cap
    return w, h

def _fmt(x):
    return ("%.6f" % x).rstrip("0").rstrip(".") if x != int(x) else str(int(x))


class StairArt:
    """Dessine une carte du carrousel (comme le modèle de carte de theme.xml) et assemble les marches."""

    def __init__(self, W, H, tv, geo, font_path, systems, conf):
        from PIL import Image, ImageDraw, ImageFont, ImageOps, ImageChops
        self.Image, self.ImageDraw, self.ImageFont, self.ImageOps, self.ImageChops = Image, ImageDraw, ImageFont, ImageOps, ImageChops
        rs = getattr(Image, "Resampling", Image)
        self.LANCZOS, self.BILINEAR = rs.LANCZOS, rs.BILINEAR
        self.W, self.H, self.tv, self.geo, self.font_path = W, H, tv, geo, font_path
        self.art = os.path.join(theme_dir, "art")
        self.conf = conf
        # --- géométrie (fractions de l'écran) ---
        Cx, Cy = geo["pos"]
        Cw, Ch = geo["size"]
        Lw, Lh = geo["logoSize"]
        S = geo["logoScale"]
        sp = Cw / geo["count"]                                  # écart de deux cartes voisines
        d = sp * (S - 1.0) / 2.0 * geo["spacing"]               # décalage des voisines du carrousel d'origine
        self.S, self.Lw, self.Lh = S, Lw, Lh
        self.sp1 = sp + d                                       # écart « carte qui arrive » -> grande carte avec l'escalier
        self.car_w, self.car_h = geo["count"] * self.sp1, Ch    # nouvelle taille du carrousel (stairCarouselSize)
        self.cy = Cy + Ch / 2.0
        self.x1 = Cx + geo["logoPos"][0] + self.sp1             # 1re marche = emplacement de la 1re voisine
        self.Cy, self.Ch = Cy, Ch
        # carte du modèle (taille du modèle = logoSize x logoScale), en pixels
        self.TW = max(8, int(round(Lw * S * W)))
        self.TH = max(8, int(round(Lh * S * H)))
        self.s1 = 1.0 / S                                       # échelle d'une carte voisine (le moteur ajoute les reflets sans en tenir compte)
        self.padL, self.padR = int(0.15 * self.TW), int(0.75 * self.TW)
        self.padT, self.padB = int(0.55 * self.TH), int(0.60 * self.TH)
        self.fonts, self.stretched, self.fitted = {}, {}, {}
        # polices du texte : celle du thème, puis les polices de secours d'ES (voir ES_FALLBACK_FONTS) ; DejaVu n'est qu'un
        # dernier recours, quand ES n'a aucune de ses polices (autre système que Batocera)
        self.es_fonts = [p for p in (es_resource(n) for n in ES_FALLBACK_FONTS) if p]
        self.fallbacks = [f for f in ("/usr/share/fonts/dejavu/DejaVuSans.ttf", "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
                                      "/usr/share/fonts/TTF/DejaVuSans.ttf") if os.path.isfile(f)]
        self.bad_fonts, self.font_note, self._chain = {}, "", None
        self.notes, self.noisy = [], False                      # remarques sur les polices (voir note())
        # moteur de texte « basique » de Pillow : il donne, comme ES, la largeur de chaque lettre arrondie au pixel (le moteur
        # Raqm, utilisé par défaut quand il est installé, donne des largeurs fractionnaires : le texte ne serait plus de la même largeur)
        lay = getattr(ImageFont, "Layout", None)
        self.BASIC = lay.BASIC if lay is not None else getattr(ImageFont, "LAYOUT_BASIC", 0)
        # marges transparentes de l'image de carte (mesurées : les marches se touchent par leurs bords VISIBLES)
        self.ml = self.mr = 0.0
        try:
            card = Image.open(os.path.join(self.art, "card_green_nxe.png")).convert("RGBA")
            bb = card.getchannel("A").point(lambda v: 255 if v > 8 else 0).getbbox()
            if bb:
                self.ml, self.mr = bb[0] / card.width, 1.0 - bb[2] / card.width
        except Exception:
            pass
        # marches visibles à l'écran : [(k, x, y, w, h)] en fractions de l'écran. Comme sur le NXE, chaque marche passe SOUS la
        # précédente : de la marche k on ne voit que ce qui dépasse à droite de la marche k-1. Le bord droit visible de chaque
        # marche vient de STAIR_RX ; la 1re marche reste à l'emplacement exact de la 1re carte voisine du carrousel.
        self.boxes = []
        w1 = Lw * STAIR_WM[1]
        v1 = self.x1 + w1 * self.ml                             # bord gauche visible de la 1re marche
        u = w1 * (1.0 - self.ml - self.mr)                      # sa largeur visible
        prev_right = v1
        for k in range(1, STAIR_STEPS + 1):
            if prev_right >= 1.0 - 1.0 / W:                     # la marche k commence hors de l'écran
                break
            wk, hk = Lw * STAIR_WM[k], Lh * STAIR_WM[k]
            right = v1 + u * STAIR_RX[k]                        # bord droit visible de la marche k
            self.boxes.append((k, right - wk * (1.0 - self.mr), self.cy - hk / 2.0, wk, hk))
            prev_right = right
        # zone de l'image (pixels d'écran) : de la 1re marche au bord droit, sur toute la hauteur du carrousel
        self.X0 = max(0, int(self.x1 * W))
        self.Y0 = max(0, int(round(Cy * H)))
        self.RW = max(1, W - self.X0)
        self.RH = max(1, min(H - self.Y0, int(round(Ch * H))))
        # --- éléments variables ---
        self.set_variant(tv)
        self.recent_ok = os.path.isfile(os.path.join(self.art, "recent", "1.png"))
        # (l'avatar de la carte Favoris n'est pas dans l'image : le thème l'affiche lui-même par-dessus l'escalier)

    def set_variant(self, tv):
        """Variables d'une variante (langue, vidéo des cartes) : textes de la carte Favoris, images des cartes."""
        self.tv = tv
        self.user = " ".join(w[:1].upper() + w[1:] for w in (tv.get("raDisplayUser", "") or "").split(" "))
        self.suffix = tv.get("raPointsSuffix", "")

    # ---------- outils ----------
    def font(self, frac):
        px = max(2, int(min(self.W, self.H) * frac))
        f = self.fonts.get(px)
        if f is None:
            f = self.fonts[px] = _StairFont(self, px)
        return f

    def load_font(self, path, px):
        """Police lue par Pillow, ou None (la raison est écrite une seule fois dans le journal)."""
        if not path:
            return None
        try:
            return self.ImageFont.truetype(path, px, layout_engine=self.BASIC)
        except Exception as e:
            if path not in self.bad_fonts:
                self.bad_fonts[path] = repr(e)
                try:
                    with open(path, "rb") as f:
                        head = f.read(8)
                    info = "%d octets, début %s" % (os.path.getsize(path), " ".join("%02x" % b for b in head))
                    if head[:4] == b"xttf":
                        info += " : police de console Xbox 360, que ni ES ni Pillow ne savent lire"
                except OSError as e2:
                    info = "fichier illisible : %r" % (e2,)
                self.note(f"escalier : police illisible par Pillow : {path} ({e!r} ; {info})")
            return None

    def note(self, msg):
        """Remarque sur les polices : écrite dans le journal seulement quand des images sont vraiment dessinées. Un passage
        où il n'y a rien à faire reste silencieux (sinon la même ligne reviendrait dans le journal toutes les quelques minutes)."""
        if self.noisy:
            log(msg)
        else:
            self.notes.append(msg)

    def flush_notes(self):
        self.noisy = True
        for m in self.notes:
            log(m)
        self.notes = []

    def font_chain(self):
        """Polices du texte dans l'ordre d'ES : celle du thème (si Pillow sait la lire), puis ses polices de secours.
        DejaVu ne sert que si ES n'a aucune de ses polices de secours (autre système que Batocera)."""
        if self._chain is None:
            chain = []
            if self.load_font(self.font_path, 16) is not None:
                chain.append(_Face(self.font_path, True))
            chain += [_Face(p) for p in (self.es_fonts or self.fallbacks)]
            self._chain = chain
        return self._chain

    def stretch(self, path, w, h):
        key = (path, w, h)
        im = self.stretched.get(key)
        if im is None:
            im = self.Image.open(path).convert("RGBA").resize((max(1, w), max(1, h)), self.LANCZOS)
            self.stretched[key] = im
        return im

    def fit(self, path, mw, mh):
        """Image qui tient dans mw x mh (maxSize : réduite OU agrandie), proportions gardées."""
        key = (path, int(mw), int(mh))
        im = self.fitted.get(key)
        if im is None:
            src = self.Image.open(path).convert("RGBA")
            r = min(mw / src.width, mh / src.height)
            im = src.resize((max(1, int(round(src.width * r))), max(1, int(round(src.height * r)))), self.LANCZOS)
            if len(self.fitted) > 24:
                self.fitted.clear()
            self.fitted[key] = im
        return im

    def cover(self, path, w, h):
        """Image qui remplit tout w x h (minSize), recadrée au centre."""
        src = self.Image.open(path).convert("RGBA")
        r = max(w / src.width, h / src.height)
        nw, nh = max(w, int(round(src.width * r))), max(h, int(round(src.height * r)))
        src = src.resize((nw, nh), self.LANCZOS)
        l, t = (nw - w) // 2, (nh - h) // 2
        return src.crop((l, t, l + w, t + h))

    def put(self, L, im, x, y):
        """Pose im (RGBA) sur la couche L à (x, y) en pixels du modèle (le coin du modèle est en (padL, padT))."""
        X, Y = int(round(x)) + self.padL, int(round(y)) + self.padT
        if X < 0 or Y < 0:                                       # hors couche : on recadre
            cx, cy = max(0, -X), max(0, -Y)
            if cx >= im.width or cy >= im.height:
                return
            im = im.crop((cx, cy, im.width, im.height))
            X, Y = X + cx, Y + cy
        if X >= L.width or Y >= L.height:
            return
        if X + im.width > L.width or Y + im.height > L.height:
            im = im.crop((0, 0, min(im.width, L.width - X), min(im.height, L.height - Y)))
        L.alpha_composite(im, (X, Y))

    def blit_mask(self, L, mask, x, y, rgba, k=1.0):
        a = (rgba[3] / 255.0) * k
        if a <= 0:
            return
        m = mask if a >= 0.999 else mask.point(lambda v, a=a: int(v * a + 0.5))
        col = self.Image.new("RGBA", mask.size, tuple(rgba[:3]) + (0,))
        col.putalpha(m)
        self.put(L, col, x, y)

    # ---------- texte (mêmes règles que le moteur d'ES) ----------
    def text(self, L, txt, fsize, box, rgba, valign="center", glow=False, reflect=False):
        """box = (x, y, largeur, hauteur) en fractions du modèle de carte."""
        if not txt:
            return
        f = self.font(fsize)
        bx, by, bw, bh = box[0] * self.TW, box[1] * self.TH, box[2] * self.TW, box[3] * self.TH
        sx, sy = int(bw), int(bh)
        lh = f.max_h * 1.5
        if sy > lh * 1.8 and not reflect:                         # grande zone : plusieurs lignes possibles (le reflet, lui, reprend
            lines = f.wrap(txt, sx).split("\n")                  # le texte visible de la carte : une seule ligne)
        else:                                                      # une seule ligne, terminée par « ... » si trop longue
            txt = txt.split("\n")[0]
            if sx and f.width(txt) > sx + 1:
                ab, cur = f.width("..."), ""
                for i in range(1, len(txt) + 1):
                    if f.width(txt[:i]) + ab > sx:
                        break
                    cur = txt[:i]
                txt = cur + "..."
            lines = [txt]
        B, max_y, text_h = f.block(lines)
        off_y = 0.0 if valign == "top" else (bh - text_h) / 2.0
        ox, oy = int(round(bx)) - f.PADX, int(round(by + off_y))
        if glow:
            for dx, dy in ((-1, -1), (0, -1), (1, -1), (1, 0), (1, 1), (0, 1), (-1, 1), (-1, 0), (-1, -1)):
                self.blit_mask(L, B, ox + dx + 1, oy + dy + 1, (0, 0, 0, 0x22))
        self.blit_mask(L, B, ox, oy, rgba)
        if reflect:
            # reflet : copie retournée, de plus en plus transparente en s'éloignant. Le moteur ajoute les décalages
            # du reflet sans les réduire avec la carte : on les convertit à l'échelle d'une carte voisine.
            c = (off_y + text_h + bh) / self.s1
            grad = self.Image.new("L", (1, B.height))
            grad.putdata([int(255 * min(1.0, (v + 0.5) / max(1.0, float(max_y)))) for v in range(B.height)])
            m = self.ImageChops.multiply(B, grad.resize(B.size))
            m = self.ImageOps.flip(m)
            self.blit_mask(L, m, ox, int(round(by + c - B.height)), rgba, 0.35)

    # ---------- une carte ----------
    def theme_icon(self, theme):
        p = os.path.join(self.art, "icons", theme + ".png")
        if os.path.isfile(p):
            return p
        p = os.path.join(self.art, "icon_nxe_1.png" if theme in ("recordings", "records") else "icon_nxe_0.png")
        return p if os.path.isfile(p) else None

    def fingerprint(self, s):
        """Tout ce qui change le dessin de la carte du système s (sert à savoir s'il faut refaire les images)."""
        fp = [s["name"], s["fullname"], s["manufacturer"], s["theme"]]
        if s["theme"] == STAIR_FAV:
            fp += [self.recent_ok, stat_sig(os.path.join(self.art, "recent", "ra_points.dat"))]
            fp += [stat_sig(os.path.join(self.art, "recent", f"{i}.png")) for i in range(1, 5)]
            fp += self.variant_fingerprint()
        else:
            ic = self.theme_icon(s["theme"])
            fp += [ic, stat_sig(ic or ""), None, None, False]   # 3 anciens champs (image fixe de carte) : gardés pour ne pas refaire tout l'escalier
        return fp

    def global_fingerprint(self):
        """Ce qui est commun à toutes les variantes (dessin, polices, images des cartes, compte RetroAchievements)."""
        fp = [STAIR_VERSION, self.W, self.H, STAIR_WM, STAIR_RX, STAIR_STEPS, self.geo, self.font_path, stat_sig(self.font_path)]
        fp += [[p, stat_sig(p)] for p in self.es_fonts]                        # polices de secours d'ES (elles dessinent le texte)
        fp += [stat_sig(os.path.join(self.art, n)) for n in ("card_green_nxe.png", "card_inner_shadow.png", "card_reflection.png",
                                                              "icon_nxe_0.png", "icon_nxe_1.png", "avatar_shadow.png")]
        fp += [self.user]                                        # changer de compte = nouvelle publication
        return fp

    def variant_fingerprint(self):
        """Textes de la carte Favoris de la variante (langue) et réglage de la vidéo des cartes."""
        t = self.tv
        return [t.get(k, "") for k in ("favOnline", "favOffline", "favService", "favGamesLabel", "favRecentLabel", "raGuest",
                                       "raPointsSuffix", "cardvideo")]

    def render_card(self, s, online=False):
        """Couche RGBA du modèle de carte d'une carte NON sélectionnée (dans l'ordre des éléments de theme.xml).
        online : texte « connecté » ou « déconnecté » de la carte Favoris."""
        Image = self.Image
        TW, TH, a = self.TW, self.TH, self.art
        L = Image.new("RGBA", (TW + self.padL + self.padR, TH + self.padT + self.padB), (0, 0, 0, 0))
        fav = s["theme"] == STAIR_FAV
        t = self.tv
        white, sub = (255, 255, 255, 255), (255, 255, 255, 0xA0)
        status = t.get("favOnline", "Online") if online else t.get("favOffline", "Offline")
        # reflets sur le sol : carte, puis texte (titre, sous-titre)
        self.put(L, self.stretch(os.path.join(a, "card_reflection.png"), TW, int(round(0.13082 * TH))), 0, TH)
        self.text(L, status if fav else s["fullname"], 0.0357, (0.0629, 0.7760, 0.8523, 0.2148), white, "top", reflect=True)
        self.text(L, t.get("favService", "RetroAchievements") if fav else s["manufacturer"], 0.0314,
                  (0.0629, 0.8704, 0.8523, 0.0885), sub, "top", reflect=True)
        # la carte et son ombre intérieure
        self.put(L, self.stretch(os.path.join(a, "card_green_nxe.png"), TW, TH), 0, 0)
        shadow = self.stretch(os.path.join(a, "card_inner_shadow.png"), TW, TH)
        self.put(L, shadow, 0, 0)
        if not fav:
            ic = self.theme_icon(s["theme"])
            if ic:
                try:
                    im = self.fit(ic, 0.38 * TW, 0.434 * TH)
                    x, y = 0.4927 * TW - im.width / 2.0, 0.4399 * TH - im.height / 2.0
                    self.put(L, im, x, y)
                    refl = self.ImageOps.flip(im)            # reflet de l'icône : 22 % puis transparent
                    g = Image.new("L", (1, refl.height))
                    g.putdata([int(255 * 0.22 * (1.0 - (v + 0.5) / refl.height)) for v in range(refl.height)])
                    refl.putalpha(self.ImageChops.multiply(refl.getchannel("A"), g.resize(refl.size)))
                    self.put(L, refl, x, y + im.height)
                except Exception as e:                       # icône illisible : la carte reste dessinée sans elle
                    log(f"escalier : icône illisible {ic} ({e!r})")
            self.text(L, s["fullname"], 0.0357, (0.0629, 0.7953, 0.8523, 0.0800), white, glow=True)
            self.text(L, s["manufacturer"], 0.0314, (0.0629, 0.8876, 0.8523, 0.0700), sub, glow=True)
        else:
            self.text(L, self.user or t.get("raGuest", "Guest"), 0.0357, (0.0629, 0.1110, 0.8523, 0.0800), white, glow=True)
            pts = stat_sig(os.path.join(a, "recent", "ra_points.dat"))
            if pts:
                self.text(L, f"{pts[0]} {self.suffix}".strip(), 0.0314, (0.0629, 0.2182, 0.8523, 0.0700),
                          (255, 255, 255, 0xE6), glow=True)
            self.text(L, status, 0.0357, (0.0629, 0.7953, 0.8523, 0.0800), white, glow=True)
            self.text(L, t.get("favService", "RetroAchievements"), 0.0314, (0.0629, 0.8876, 0.8523, 0.0700), sub, glow=True)
        if fav:
            label = t.get("favRecentLabel", "Recent games") if self.recent_ok else t.get("favGamesLabel", "Favorite games")
            self.text(L, label, 0.0236, (0.0629, 0.4503, 0.8523, 0.0760), (255, 255, 255, 0xD8), glow=True)
            tw_, th_ = int(round(0.1190 * TW)), int(round(0.1590 * TH))
            for i, fx in enumerate((0.0629, 0.1970, 0.3311, 0.4652), 1):
                x, y = fx * TW, 0.5390 * TH
                tile = Image.new("RGBA", (tw_, th_), (0, 0, 0, 0x2E))
                self.put(L, tile, x, y)
                p = os.path.join(a, "recent", f"{i}.png")
                if os.path.isfile(p):
                    try:
                        self.put(L, self.cover(p, tw_, th_), x, y)
                    except Exception as e:                       # vignette en cours d'écriture / illisible : case vide
                        log(f"escalier : vignette illisible {p} ({e!r})")
                frame = Image.new("RGBA", (tw_, th_), (0, 0, 0, 0))
                self.ImageDraw.Draw(frame).rectangle([0, 0, tw_ - 1, th_ - 1], outline=(0, 0, 0, 0x8C), width=2)
                self.put(L, frame, x, y)
            sh = os.path.join(a, "avatar_shadow.png")
            try:
                if os.path.isfile(sh):
                    w, h = int(round(0.3101 * TW)), int(round(0.0692 * TH))
                    self.put(L, self.stretch(sh, w, h), 0.7610 * TW - w / 2.0, 1.1373 * TH - h / 2.0)
            except Exception as e:                               # ombre illisible : carte sans ombre d'avatar
                log(f"escalier : avatar illisible ({e!r})")
        bb = L.getchannel("A").getbbox()
        return (L.crop(bb), bb[0] - self.padL, bb[1] - self.padT) if bb else None

    # ---------- une image de marches ----------
    def compose(self, cards):
        """cards = [(k, (couche, dx, dy) ou None)] -> image RGBA de la zone des marches."""
        Image = self.Image
        out = Image.new("RGBA", (self.RW, self.RH), (0, 0, 0, 0))
        boxes = {b[0]: b for b in self.boxes}
        for k, card in sorted(cards, key=lambda c: -c[0]):       # de la plus lointaine à la plus proche : la plus proche est devant (comme sur le NXE)
            if card is None or k not in boxes:
                continue
            _, x, y, w, h = boxes[k]
            layer, dx, dy = card
            f = (w * self.W) / float(self.TW)                    # réduction de la carte du modèle -> marche
            # coin du modèle en pixels d'écran, relatif à la zone de l'image
            ax = x * self.W - self.X0 + dx * f
            ay = y * self.H - self.Y0 + dy * f
            x0, y0 = int(math.ceil(ax)), int(math.ceil(ay))
            x1, y1 = int(math.floor(ax + layer.width * f)), int(math.floor(ay + layer.height * f))
            x0c, y0c, x1c, y1c = max(0, x0), max(0, y0), min(self.RW, x1), min(self.RH, y1)
            if x1c <= x0c or y1c <= y0c:
                continue
            box = ((x0c - ax) / f, (y0c - ay) / f, (x1c - ax) / f, (y1c - ay) / f)
            box = (max(0.0, box[0]), max(0.0, box[1]), min(float(layer.width), box[2]), min(float(layer.height), box[3]))
            part = layer.resize((x1c - x0c, y1c - y0c), self.LANCZOS, box=box)
            out.alpha_composite(part, (x0c, y0c))
        return out


# ---------------------------------------------------------------------------------------------------------------------
#  Polices du texte. EmulationStation (Font::getFaceForChar) dessine chaque lettre avec la 1re police de cette chaîne qui la
#  possède : la police du thème, puis ses polices de secours ci-dessous, dans cet ordre. Quand la police du thème est
#  illisible (celle de la Xbox 360, « xenonclatin.ttf », est un fichier de console que FreeType - donc ES comme Pillow - ne sait
#  pas ouvrir), tout le texte vient des polices de secours : les lettres de PyeojinGothic-Medium, l'espace de fontawesome-webfont...
#  Le script refait le même choix lettre par lettre : le texte de l'escalier est alors celui des vraies cartes.
# ---------------------------------------------------------------------------------------------------------------------
ES_FALLBACK_FONTS = ("fontawesome-webfont.ttf", "DroidSansFallbackFull.ttf", "PyeojinGothic-Medium.ttf",
                     "Vazirmatn-Regular.ttf", "Rubik-Regular.ttf")


def es_resource(name):
    """Chemin d'une ressource d'ES, cherchée dans l'ordre d'ES : dossier « resources » du thème, puis ceux d'ES."""
    for d in (os.path.join(theme_dir, "resources"), os.path.join(userdata, "system", "configs", "emulationstation", "resources"),
              "/usr/share/emulationstation/resources"):
        p = os.path.join(d, name)
        if os.path.isfile(p):
            return p
    return None


class _Cmap:
    """Lettres qu'une police possède (table « cmap » d'un fichier TrueType / OpenType, lue sans rien installer) : c'est le
    FT_Get_Char_Index() != 0 qu'ES utilise pour savoir si une police a une lettre. ok = False : table illisible (on ne sait pas)."""
    UNICODE = ((3, 10), (0, 6), (0, 4), (3, 1), (0, 3), (0, 2), (0, 1), (0, 0))     # sous-tables Unicode, de la plus complète à la moins

    def __init__(self, path):
        self.ok = False
        try:
            data = self._table(path)
            subs = {}
            for i in range(struct.unpack(">H", data[2:4])[0]):
                pid, eid, off = struct.unpack(">HHI", data[4 + 8 * i:12 + 8 * i])
                subs[(pid, eid)] = off
            for key in self.UNICODE:
                if key in subs and self._load(data, subs[key]):
                    self.ok = True
                    break
        except Exception:
            self.ok = False

    @staticmethod
    def _table(path):
        with open(path, "rb") as f:
            head = f.read(12)
            if head[:4] not in (b"\x00\x01\x00\x00", b"true", b"OTTO"):
                raise ValueError("pas une police TrueType / OpenType")
            for _ in range(struct.unpack(">H", head[4:6])[0]):
                tag, _sum, off, size = struct.unpack(">4sIII", f.read(16))
                if tag == b"cmap":
                    f.seek(off)
                    return f.read(size)
        raise ValueError("pas de table cmap")

    def _load(self, data, off):
        self.fmt = struct.unpack_from(">H", data, off)[0]
        if self.fmt == 4:                                         # segments (la plupart des polices)
            sc = struct.unpack_from(">H", data, off + 6)[0] // 2
            base = off + 14
            self.end = struct.unpack_from(">%dH" % sc, data, base)
            self.start = struct.unpack_from(">%dH" % sc, data, base + 2 + 2 * sc)
            self.delta = struct.unpack_from(">%dH" % sc, data, base + 2 + 4 * sc)
            self.roff = struct.unpack_from(">%dH" % sc, data, base + 2 + 6 * sc)
            self.rpos, self.data = base + 2 + 6 * sc, data
        elif self.fmt in (12, 13):                                # groupes (lettres au-delà de U+FFFF aussi)
            n = struct.unpack_from(">I", data, off + 12)[0]
            g = struct.unpack_from(">%dI" % (3 * n), data, off + 16)
            self.gs, self.ge, self.gg = g[0::3], g[1::3], g[2::3]
        elif self.fmt == 6:
            first, count = struct.unpack_from(">HH", data, off + 6)
            self.first, self.ids = first, struct.unpack_from(">%dH" % count, data, off + 10)
        elif self.fmt == 0:
            self.first, self.ids = 0, data[off + 6:off + 262]
        else:
            return False
        return True

    def has(self, c):
        f = self.fmt
        if f == 4:
            if c > 0xFFFF:
                return False
            i = bisect.bisect_left(self.end, c)
            if i >= len(self.end) or self.start[i] > c:
                return False
            ro = self.roff[i]
            if ro == 0:
                return ((c + self.delta[i]) & 0xFFFF) != 0
            if ro == 0xFFFF:
                return False
            pos = self.rpos + 2 * i + ro + 2 * (c - self.start[i])
            if pos + 2 > len(self.data):
                return False
            g = struct.unpack_from(">H", self.data, pos)[0]
            return g != 0 and ((g + self.delta[i]) & 0xFFFF) != 0
        if f in (12, 13):
            i = bisect.bisect_left(self.ge, c)
            if i >= len(self.ge) or self.gs[i] > c:
                return False
            return (self.gg[i] + (c - self.gs[i] if f == 12 else 0)) != 0
        i = c - self.first
        return 0 <= i < len(self.ids) and self.ids[i] != 0


class _Face:
    """Une police de la chaîne d'ES : son chemin et les lettres qu'elle possède."""

    def __init__(self, path, is_theme=False):
        self.path, self.is_theme = path, is_theme
        self.cmap = _Cmap(path)
        self.no_korean = os.path.basename(path).startswith("DroidSansFallbackFull")   # ES ne s'en sert pas pour le coréen (elle le dessine mal)

    def has(self, code):
        """True / False, ou None quand la table des lettres n'a pas pu être lue."""
        if self.no_korean and (0x3131 <= code <= 0x3163 or 0xAC00 <= code <= 0xD7A3):
            return False
        return self.cmap.has(code) if self.cmap.ok else None


class _StairFont:
    """Police + mesures comme le moteur d'ES : hauteur de ligne = plus haute lettre ASCII x 1,5, avance de chaque lettre ;
    chaque lettre est dessinée avec la 1re police de la chaîne d'ES qui la possède."""
    PADX = 3

    def __init__(self, art, px):
        self.art, self.px = art, px
        self.chain = art.font_chain()
        self.fts, self.notdef, self.default = {}, {}, None       # polices Pillow (à cette taille), « carrés » de lettre absente, police intégrée
        if not any(self.pil(fc) for fc in self.chain):           # rien de lisible : petite police intégrée à Pillow
            try:
                self.default = art.ImageFont.load_default(px)    # Pillow >= 10.1
            except Exception:
                raise OSError("aucune police utilisable par Pillow")
        if not art.font_note and not self.theme_ok():
            names = [os.path.splitext(os.path.basename(fc.path))[0] for fc in self.chain if self.pil(fc)]
            art.font_note = ", ".join(names) or "la police intégrée à Pillow"
            if names and art.es_fonts:
                art.note(f"escalier : la police du thème n'a pas pu être utilisée ; texte dessiné comme le fait ES, avec ses polices de secours ({art.font_note})")
            else:
                art.note(f"escalier : la police du thème n'a pas pu être utilisée, texte dessiné avec {art.font_note}")
        self.cache, self.max_h = {}, 0
        for c in range(32, 128):
            self.glyph(chr(c))
        self.max_h = self.max_h or px
        g = self.glyph("S")
        self.ytop = g[3] if g[1] is not None else px * 0.7           # hauteur de « S » au-dessus de la ligne de base

    def pil(self, fc):
        """Police Pillow de cette police de la chaîne à la taille courante, ou None si Pillow ne sait pas l'ouvrir."""
        if fc not in self.fts:
            self.fts[fc] = self.art.load_font(fc.path, self.px)
        return self.fts[fc]

    def theme_ok(self):
        return bool(self.chain) and self.chain[0].is_theme and self.pil(self.chain[0]) is not None

    def _render(self, ft, ch):
        n = self.px * 3 + 8
        im = self.art.Image.new("L", (n, n), 0)
        self.art.ImageDraw.Draw(im).text((self.px + 4, self.px * 2 + 4), ch, font=ft, fill=255, anchor="ls")
        return im

    def missing(self, fc, ch):
        """Pillow dessine-t-il, à la place de cette lettre, le « carré » des lettres absentes ? (si la table des lettres est illisible)"""
        nd = self.notdef.get(fc)
        if nd is None:
            nd = self.notdef[fc] = self._render(self.pil(fc), "￾").tobytes()
        return self._render(self.pil(fc), ch).tobytes() == nd

    def pick(self, ch):
        """Police qui dessine cette lettre : la 1re de la chaîne qui la possède (comme ES), sinon None."""
        code = ord(ch)
        for fc in self.chain:
            if self.pil(fc) is None:
                continue                                         # police illisible : ES l'ignore aussi
            has = fc.has(code)
            if has is None:                                      # table des lettres illisible : on se fie au dessin de Pillow
                has = not self.missing(fc, ch)
            if has:
                return fc
        return None

    def glyph(self, ch):
        g = self.cache.get(ch)
        if g is not None:
            return g
        fc = self.pick(ch)
        if fc is not None:
            ft = self.pil(fc)
        elif self.default is not None:
            ft = self.default
        else:                                                    # aucune police de la chaîne n'a cette lettre : ES prend celle du thème
            ft = self.pil(self.chain[0]) if self.theme_ok() else None      # (son « carré »), et sans police du thème il ne dessine rien
        if ft is None:
            g = (0.0, None, 0, 0)
        else:
            im = self._render(ft, ch)
            bb = im.getbbox()
            adv = ft.getlength(ch)
            if bb is None:
                g = (adv, None, 0, 0)
            else:
                g = (adv, im.crop(bb), bb[0] - (self.px + 4), (self.px * 2 + 4) - bb[1])
                if 32 <= ord(ch) < 128:
                    self.max_h = max(self.max_h, bb[3] - bb[1])
        self.cache[ch] = g
        return g


    def width(self, s):
        return sum(self.glyph(c)[0] for c in s)

    def wrap(self, text, maxw):
        """Même découpage en lignes que Font::wrapText d'ES."""
        out = ""
        while text:
            cursor, lw, last_ws, last_cursor = 0, 0.0, 0, 0
            while lw < maxw and cursor < len(text):
                last_cursor = cursor
                c = text[cursor]
                cursor += 1
                lw = 0.0 if c in "\n\r" else lw + self.glyph(c)[0]
                if c in " \n\t\v\f\r":
                    last_ws = cursor
            if cursor == len(text):
                out += text
                text = ""
            else:
                cut = last_ws if last_ws != 0 else last_cursor
                if cut == 0:
                    break
                out += text[:cut] + "\n"
                text = text[cut:]
        return out

    def block(self, lines):
        """Masque L du texte, en coordonnées locales d'ES (ligne de base à (hauteur de ligne + hauteur de S) / 2)."""
        lh = self.max_h * 1.5
        wmax = max([self.width(l) for l in lines] + [1.0])
        B = self.art.Image.new("L", (int(wmax) + self.px + 2 * self.PADX, int(lh * len(lines)) + 4), 0)
        max_y = 0
        for j, line in enumerate(lines):
            x, y = 0.0, (lh + self.ytop) / 2.0 + j * lh
            for ch in line:
                adv, m, bx, by = self.glyph(ch)
                if m is not None:
                    gx, gy = int(round(x + bx)) + self.PADX, int(round(y - by))
                    B.paste(255, (gx, gy, gx + m.width, gy + m.height), m)
                    max_y = max(max_y, gy + m.height)
                x += adv
        return B, max_y, lh


STAIR_VARIANTS = ("on", "off")      # carte Favoris « connecté » / « déconnecté » : les deux sont préparées, le thème choisit
STAIR_ONLINE_RE = re.compile(r"<stairOnline>[^<]*</stairOnline>")

class _StairBusy(Exception):
    pass

class _StairFail(Exception):
    pass

def _stair_lock():
    import fcntl
    os.makedirs(data_dir, exist_ok=True)
    lk = open(STAIR_LOCK, "w")
    try:
        fcntl.flock(lk, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except OSError:
        return None
    return lk

def _save_manifest(gen, prev, gh, files, W, H):
    _write_atomic(os.path.join(STAIR_DIR, "manifest.json"),
                  json.dumps({"gen": gen, "prev": prev, "global": gh, "files": files, "size": [W, H]}, indent=1))

def _stair_manifest():
    try:
        with open(os.path.join(STAIR_DIR, "manifest.json"), encoding="utf-8") as f:
            m = json.load(f)
        return m if isinstance(m, dict) else {}
    except (OSError, ValueError):
        return {}

def _write_atomic(path, content):
    tmp = path + ".tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        f.write(content)
    os.replace(tmp, path)

def _replace_link(src, dst):
    """dst devient un lien dur vers src (sinon une copie), de façon atomique : ES ne voit jamais un fichier à moitié écrit."""
    tmp = dst + ".tmp.lnk"
    _rm(tmp)
    try:
        os.link(src, tmp)
    except OSError:
        shutil.copyfile(src, tmp)
    os.replace(tmp, dst)

def stair_online(conf=None):
    """Comme {global:cheevos} && {global:network} dans le thème : RetroAchievements activé ET une adresse IP."""
    conf = conf if conf is not None else read_conf()
    return conf.get("global.retroachievements", "0") == "1" and has_ip()

def _ready_xml(gen, pos, size, csize, online, geo=None, extra=()):
    """Variables lues par le thème. stairCam = on : effet caméra (l'image des marches est accrochée à chaque carte, voir
    stairLocalPos / stairLocalSize) ; off : ancien fonctionnement (image fixe derrière le carrousel), si la place de l'image
    par rapport à la carte ne peut pas être calculée."""
    local = stair_local(geo, pos, size, csize) if geo else None
    cam = ((("stairLocalPos", local[0]), ("stairLocalSize", local[1]), ("stairCam", "on")) + tuple(extra)) if local else ()
    return _vars_xml("images de l'escalier prêtes (écrit par nxe360_recent.sh, ne pas modifier)",
                     (("stairGen", gen), ("stairPos", pos), ("stairSize", size), ("stairCarouselSize", csize)) + cam
                     + (("stairOnline", "on" if online else "off"),))

def stairs_sync_variant():
    """Version de la carte Favoris (connecté / déconnecté) que le thème lira au prochain rechargement : à appeler juste
    avant de recharger ES (il lit alors {global:network} lui aussi). Renvoie True si elle a changé."""
    p = os.path.join(STAIR_DIR, "ready.xml")
    try:
        with open(p, encoding="utf-8") as f:
            txt = f.read()
    except OSError:
        return False
    new = STAIR_ONLINE_RE.sub("<stairOnline>%s</stairOnline>" % ("on" if stair_online() else "off"), txt)
    if new == txt:
        return False
    try:
        _write_atomic(p, new)
    except OSError:
        return False
    return True

def _stair_failed(structural, reuse, gdir, ready, cur, man, done, want, gh, W, H):
    """Échec du dessin : on ne publie jamais d'images incomplètes.
         - nouvelle publication : son dossier est supprimé ; si les images déjà publiées ne correspondent plus aux réglages
           (reuse faux), ready.xml est retiré : le thème reprend son carrousel normal au prochain rechargement (code 10 :
           ES doit recharger) ;
         - mise à jour sur place : les images déjà remplacées restent, les autres seront retentées.
       Renvoie 1 (impossible) ou 10."""
    if structural:
        shutil.rmtree(gdir, ignore_errors=True)
        if not reuse:
            try:
                os.remove(ready)
            except OSError:
                return 1
            log("escalier : images précédentes retirées (elles ne correspondent plus aux réglages), le carrousel normal revient")
            return 10
        return 1
    try:
        _save_manifest(cur, man.get("prev", ""), gh, {k: v for k, v in done.items() if k in want}, W, H)
    except OSError:
        pass
    return 1

def stairs_run():
    """Prépare / met à jour les images de l'escalier, TOUTES variantes comprises : connecté / déconnecté, chaque langue,
    avec et sans boucle, vidéo des cartes activée ou non (dossiers art/stair/g<N>/<connecté>.<langue>.<boucle>.<vidéo>/).
    Le thème choisit lui-même la variante des options en cours : changer une option dans la configuration du thème est
    donc immédiat. Les images identiques d'une variante à l'autre sont des liens (pas de place perdue). Elles sont tenues
    prêtes même quand l'option Escalier est coupée : l'activer est immédiat aussi.
    Codes de sortie : 0 rien à faire, 10 nouvelle publication ou images retirées (ES doit recharger le thème), 11 images
    mises à jour sur place (rien à recharger : elles apparaîtront au prochain rechargement), 2 ES pas prêt, 3 ES occupé,
    1 impossible."""
    global STAIR_FAV
    lk = _stair_lock()
    if lk is None:
        return 0                                                 # déjà en cours
    try:
        os.nice(19)                                              # jamais au détriment du jeu ni de l'interface
    except OSError:
        pass
    if shutil.which("ionice"):
        subprocess.run(["ionice", "-c", "3", "-p", str(os.getpid())], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    try:
        from PIL import Image  # noqa: F401
    except ImportError:
        log("escalier : Python Imaging Library (Pillow) absente, l'option reste sans effet")
        return 1
    systems = stair_systems()
    if not systems:
        return 2
    STAIR_FAV = profile_theme(systems)                           # carte profil : Xbox 360 si présent, sinon Favoris
    conf = read_conf()
    choices, cur_tok = stair_choices()

    def toks(sid):
        return [t for _, _, t in choices.get(sid) or []] or ["x"]

    def path_of(sid, tok):
        return next((pp for _, pp, t in choices.get(sid) or [] if t == tok), None)
    langs, loops, videos = toks("language"), toks("loop"), toks("cardvideo")
    cur_combo = (cur_tok.get("language", langs[0]), cur_tok.get("loop", loops[0]), cur_tok.get("cardvideo", videos[0]))
    tvs = {(lg, vd): stair_vars(conf, pick={"language": path_of("language", lg), "cardvideo": path_of("cardvideo", vd)})
           for lg in langs for vd in videos}
    tv = tvs[(cur_combo[0], cur_combo[2])]
    geo = stair_geometry()
    W, H = screen_size()
    font = os.path.normpath(os.path.join(theme_dir, tv.get("mainFont", "./fonts/xenonclatin.ttf")))
    if not os.path.isfile(font):
        font = FONT
    art = None
    try:
        art = StairArt(W, H, tv, geo, font, systems, conf)
        art.font(0.0357)                                         # une police utilisable ? (celle du thème, sinon une police de secours)
    except Exception as e:
        if art is not None:
            art.flush_notes()
        log(f"escalier : préparation impossible ({e!r})")
        return 1
    import hashlib

    def sha(x):
        return hashlib.sha1(json.dumps(x, sort_keys=True, default=str).encode()).hexdigest()
    n = len(systems)
    steps = min(len(art.boxes), n - 1)                           # jamais la même carte deux fois
    gh = sha([art.global_fingerprint(), steps])                  # réglages communs à toutes les images
    cfp = {}                                                     # empreinte de chaque carte, pour chaque (langue, vidéo)
    for (lg, vd), t in tvs.items():
        art.set_variant(t)
        for sy in systems:
            cfp[(sy["name"], lg, vd)] = art.fingerprint(sy)
    art.set_variant(tv)

    def shown(i, lp):                                            # marches du système i : les cartes suivantes
        return [k for k in range(1, steps + 1) if lp != "off" or i + k < n]   # boucle désactivée : rien après la dernière carte
    variants = [(o, lg, lp, vd) for o in STAIR_VARIANTS for lg in langs for lp in loops for vd in videos]

    def vdir(v):
        return "%s.%s.%s.%s" % v

    def spec(i, v):                                              # tout ce qui change l'image du système i dans la variante v
        o, lg, lp, vd = v
        cards = []
        for k in shown(i, lp):
            sy = systems[(i + k) % n]
            cards.append([cfp[(sy["name"], lg, vd)], o if sy["theme"] == STAIR_FAV else None])
        return sha([steps, cards])
    want, where = {}, {}                                         # clé « dossier/système » -> empreinte ; clé -> (i, variante)
    for v in variants:
        for i, sy in enumerate(systems):
            key = vdir(v) + "/" + sy["name"]
            want[key], where[key] = spec(i, v), (i, v)
    cur_dirs = {vdir((o,) + cur_combo) for o in STAIR_VARIANTS}  # variante des options en cours : dessinée en premier
    man = _stair_manifest()
    cur = man.get("gen", "")
    have = man.get("files", {}) if isinstance(man.get("files"), dict) else {}
    cdir = os.path.join(STAIR_DIR, cur) if cur else ""
    ready = os.path.join(STAIR_DIR, "ready.xml")
    pos = f"{_fmt(art.X0 / W)} {_fmt(art.Y0 / H)}"
    size = f"{_fmt(art.RW / W)} {_fmt(art.RH / H)}"
    csize = f"{_fmt(art.car_w)} {_fmt(art.car_h)}"
    extra = stair_extra(geo, csize, art.boxes, systems, steps)

    def present(gdir, key):
        return bool(gdir) and os.path.isfile(os.path.join(gdir, key + ".png"))

    def legacy_links(gdir):
        """Dossiers on/ et off/ (theme.xml plus ancien, qui ne connaît pas les variantes) : liens vers la variante des
        options en cours."""
        for o in STAIR_VARIANTS:
            os.makedirs(os.path.join(gdir, o), exist_ok=True)
            for sy in systems:
                src = os.path.join(gdir, vdir((o,) + cur_combo), sy["name"] + ".png")
                dst = os.path.join(gdir, o, sy["name"] + ".png")
                try:
                    if os.path.isfile(src) and not (os.path.exists(dst) and os.path.samefile(src, dst)):
                        _replace_link(src, dst)
                except OSError:
                    pass
    try:
        with open(ready, encoding="utf-8") as f:
            ready_ok = bool(cur) and STAIR_ONLINE_RE.sub("", f.read()) == \
                STAIR_ONLINE_RE.sub("", _ready_xml(cur, pos, size, csize, True, geo, extra))
    except OSError:
        ready_ok = False
    reuse = bool(cur) and man.get("global") == gh                # mêmes réglages communs : les images inchangées sont reprises
    todo = [k for k in want if not reuse or have.get(k) != want[k] or not present(cdir, k)]
    structural = (not reuse) or (not ready_ok) or bool(set(want) - set(have))   # nouvelle publication = ES doit recharger
    if not todo and not structural:
        _rm(*(os.path.join(cdir, k + ".png") for k in set(have) - set(want)))   # système ou variante disparu : ses images
        if set(have) != set(want):
            _save_manifest(cur, man.get("prev", ""), gh, want, W, H)
        legacy_links(cdir)
        return 0                                                 # tout est à jour
    if es_status("/isIdle") != 200:
        return 3                                                 # jeu en cours : on attend son retour
    art.flush_notes()                                            # des images vont être dessinées : remarques sur les polices dans le journal
    t0 = time.time()
    if structural:
        gen = "g%d" % ((int(cur[1:]) if cur[1:].isdigit() else 0) + 1)
        gdir = os.path.join(STAIR_DIR, gen)
        shutil.rmtree(gdir, ignore_errors=True)
        done = {}
    else:
        gen, gdir, done = cur, cdir, dict(have)                  # mise à jour sur place : chaque fichier est remplacé d'un coup
    for v in variants:
        os.makedirs(os.path.join(gdir, vdir(v)), exist_ok=True)
    src_of = {}                                                  # empreinte -> fichier qui a déjà ce contenu (liens)
    if reuse and cdir:
        for k, sp in have.items():
            if sp not in src_of and present(cdir, k):
                src_of[sp] = os.path.join(cdir, k + ".png")
    layers = {}

    def card(idx, online, lg, vd):
        sy = systems[idx % n]
        fav = sy["theme"] == STAIR_FAV
        key = (sy["name"], lg if fav else None, None if fav else vd, online if fav else None)
        if key not in layers:
            if len(layers) > 64:
                layers.pop(next(iter(layers)))
            art.set_variant(tvs[(lg, vd)])
            try:
                layers[key] = art.render_card(sy, online)
            except Exception as e:                               # une carte impossible à dessiner ne bloque pas les autres
                log(f"escalier : carte « {sy['name']} » non dessinée ({e!r})")
                layers[key] = None
        return layers[key]

    def save(img, path):
        img.save(path + ".tmp.png", "PNG", compress_level=4)
        os.replace(path + ".tmp.png", path)
    made = linked = 0
    order = sorted(want, key=lambda k: (k.split("/")[0] not in cur_dirs, where[k][0], k))
    try:
        for k in order:
            dst = os.path.join(gdir, k + ".png")
            sp = want[k]
            if k not in todo:
                if structural:                                   # image inchangée : reprise de la publication précédente
                    _replace_link(os.path.join(cdir, k + ".png"), dst)
                done[k] = sp
                continue
            src = src_of.get(sp)
            if src and os.path.isfile(src) and os.path.abspath(src) != os.path.abspath(dst):
                _replace_link(src, dst)                          # même contenu qu'une autre variante : simple lien
                linked += 1
            else:
                if es_status("/isIdle") != 200:
                    raise _StairBusy()
                i, (o, lg, lp, vd) = where[k]
                cards = [(kk, card(i + kk, o == "on", lg, vd)) for kk in shown(i, lp)]
                if any(c is None for _, c in cards):             # jamais d'image avec un « trou » : dans ce cas on ne publie rien
                    raise _StairFail()
                img = art.compose(cards) if cards else art.Image.new("RGBA", (art.RW, art.RH), (0, 0, 0, 0))
                save(img, dst)
                made += 1
                time.sleep(0.02)                                 # laisse respirer le processeur
            if not structural:                                   # fichier remplacé : son ancien contenu n'est plus là
                src_of = {x: y for x, y in src_of.items() if os.path.abspath(y) != os.path.abspath(dst)}
            src_of[sp] = dst
            done[k] = sp
    except _StairBusy:
        log("escalier : jeu lancé pendant le dessin, on reprendra après")
        if structural:
            shutil.rmtree(gdir, ignore_errors=True)
        else:
            _save_manifest(cur, man.get("prev", ""), gh, {k: v for k, v in done.items() if k in want}, W, H)
        return 3
    except _StairFail:
        log("escalier : au moins une carte n'a pas pu être dessinée, les images ne sont pas publiées")
        return _stair_failed(structural, reuse, gdir, ready, cur, man, done, want, gh, W, H)
    except Exception as e:
        import traceback
        log(f"escalier : erreur pendant le dessin ({e!r}) : {traceback.format_exc().strip().splitlines()[-3:]}")
        return _stair_failed(structural, reuse, gdir, ready, cur, man, done, want, gh, W, H)
    legacy_links(gdir)
    note = f" ; police de secours : {art.font_note}" if art.font_note else ""
    if not structural:
        _rm(*(os.path.join(gdir, k + ".png") for k in set(done) - set(want)))   # système ou variante disparu : ses images
        _save_manifest(cur, man.get("prev", ""), gh, want, W, H)
        log(f"escalier : {made} image(s) mise(s) à jour sur place, {linked} lien(s) ({gen}, {time.time() - t0:.1f} s{note})")
        return 11
    # publication : manifeste, puis ready.xml (en dernier : c'est lui qui active les images dans le thème)
    _save_manifest(gen, cur, gh, want, W, H)
    _write_atomic(ready, _ready_xml(gen, pos, size, csize, stair_online(conf), geo, extra))
    for d in glob.glob(os.path.join(STAIR_DIR, "g*")):           # on garde la publication actuelle et la précédente
        if os.path.basename(d) not in (gen, cur):
            shutil.rmtree(d, ignore_errors=True)
    log(f"escalier : publication {gen} : {made} image(s) dessinée(s), {linked} lien(s), {len(want) - made - linked} reprise(s) "
        f"({len(variants)} variantes, {W}x{H}, {steps} marche(s), {time.time() - t0:.1f} s{note})")
    return 10


NOLOOP_DIR = "/var/run/nxe360"                   # en mémoire vive (le petit script lit / écrit ici à chaque carte)
NOLOOP_LIST = os.path.join(NOLOOP_DIR, "noloop.list")


class NoLoop:
    """Carrousel des systèmes SANS boucle (option « Boucle des systèmes : désactivée », par défaut). ES ne sait pas s'arrêter
    au bout de la liste : le petit script scripts/system-selected/nxe360_noloop.sh, lancé par ES à chaque système sélectionné,
    renvoie aussitôt la touche inverse quand on passe de la dernière carte à la première (ou l'inverse). La surveillance lui
    donne le premier et le dernier système (noloop.list) avec l'heure : quand elle ne tourne plus (liste vieille de plus de
    30 s), il ne fait rien."""
    STAMP, SYSTEMS = 5, 30                                       # heure toutes les 5 s, liste des systèmes toutes les 30 s

    def __init__(self):
        self.next = self.sys_next = 0.0
        self.names, self.settings_m = None, None
        try:
            os.makedirs(NOLOOP_DIR, exist_ok=True)
        except OSError:
            pass
        _rm(os.path.join(NOLOOP_DIR, "noloop.skip"))            # noloop.prev est gardé : remis à zéro au démarrage d'ES (lanceur)

    def tick(self):
        now = time.time()
        m = mtime(ES_SETTINGS)
        if now < self.next and m == self.settings_m:             # option changée : pris en compte tout de suite
            return
        self.next = now + self.STAMP
        if loop_enabled():
            self.settings_m = m
            self.stop()
            return
        if self.names is None or now >= self.sys_next or m != self.settings_m:
            self.settings_m, self.sys_next = m, now + self.SYSTEMS
            sy = stair_systems()                                 # None : ES ne répond pas (on garde la liste connue)
            if sy is not None:
                self.names = (sy[0]["name"], sy[-1]["name"]) if len(sy) >= 3 else ()
            elif self.names is None:
                self.sys_next = now + self.STAMP                 # pas encore de liste : on réessaie bientôt
        if not self.names:
            self.stop()
            return
        try:
            _write_atomic(NOLOOP_LIST, "%s\t%s\t%d\n" % (self.names[0], self.names[1], int(now)))
        except OSError:
            pass

    def stop(self):
        _rm(NOLOOP_LIST)


NAV_LIST = os.path.join(NOLOOP_DIR, "nav.list")
NAV_FLAG = os.path.join(OUT, "navsound.on")


class NavSound:
    """Son du carrousel selon le sens. ES n'a qu'un son de défilement (scrollSound) pour les deux sens : le thème le retire
    quand art/recent/navsound.on existe, et le petit script scripts/system-selected/nxe360_noloop.sh joue panel-left.wav
    ou panel-right.wav. Il lui faut la liste des systèmes dans l'ordre d'ES (nav.list, avec l'heure)."""
    STAMP, SYSTEMS = 5, 30

    def __init__(self):
        self.next = self.sys_next = 0.0
        self.names = None
        try:
            os.makedirs(NOLOOP_DIR, exist_ok=True)
        except OSError:
            pass
        _rm(os.path.join(NOLOOP_DIR, "nav.bounce"))             # nav.prev / nav.ingame gardés (remis à zéro au démarrage d'ES)
        self.flag_new = not os.path.exists(NAV_FLAG)              # 1re fois : le thème doit être relu pour couper son son
        if self.flag_new:
            try:
                os.makedirs(OUT, exist_ok=True)
                with open(NAV_FLAG, "w") as f:
                    f.write("1")
            except OSError:
                self.flag_new = False

    def tick(self):
        now = time.time()
        if now < self.next:
            return
        self.next = now + self.STAMP
        if self.names is None or now >= self.sys_next:
            sy = stair_systems()
            if sy is not None:
                self.names, self.sys_next = [x["name"] for x in sy], now + self.SYSTEMS
        if not self.names:
            return
        try:
            _write_atomic(NAV_LIST, "%d\n%s\n%s\n%s\n" % (int(now), theme_dir, ES_SETTINGS, "\t".join(self.names)))
        except OSError:
            pass

    def stop(self):
        _rm(NAV_LIST)


class StairWatch:
    """Dans la boucle de la surveillance : lance « stairs » (dans un processus à part) quand quelque chose change, et dit
    quand ES doit recharger le thème (nouvelle publication d'images, ES libre)."""
    CHECK, SETTLE, PERIOD, SYSTEMS_EVERY = 1, 2, 300, 30

    def __init__(self):
        self.proc = None
        self.reload_due = False
        self.want, self.not_before = True, time.time() + 15      # laisse ES finir de démarrer
        self.next_check, self.last_run, self.period = 0.0, 0.0, self.PERIOD
        self.sig, self.sys_hash, self.sys_next = None, None, 0.0
        art = os.path.join(theme_dir, "art")
        # ce qui peut changer l'image d'une marche (les fichiers de notification de art/recent n'y sont pas : inutile)
        self.watch = [ES_SETTINGS, os.path.join(theme_dir, "theme.xml")] + \
                     [os.path.join(art, d) for d in ("", "icons")] + \
                     [os.path.join(art, "recent", n) for n in ("ra_points.dat", "ra_user.xml", "1.png", "2.png", "3.png", "4.png")]

    def _spawn(self, now):
        self.want, self.last_run = False, now
        if not (SELF_PATH and os.path.isfile(SELF_PATH)):
            return
        try:
            self.proc = subprocess.Popen(["bash", SELF_PATH, "stairs"], stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL,
                                         stderr=subprocess.DEVNULL, start_new_session=True)
        except OSError as e:
            log(f"escalier : lancement impossible ({e})")

    def poll(self):
        """Prend connaissance de la fin du calcul en cours (code de sortie de « stairs »)."""
        if self.proc is None:
            return
        rc = self.proc.poll()
        if rc is None:
            return
        self.proc = None
        if rc == 10:
            self.reload_due = stairs_enabled()                   # escalier coupé : rien d'affiché, rien à recharger
        elif rc in (2, 3):                                       # ES pas encore prêt / jeu en cours : on réessaie
            self.want, self.not_before = True, time.time() + 15
        elif rc == 1:                                            # Pillow absente, police introuvable... : on ne harcèle pas
            self.period = 3600

    def tick(self, busy=False):
        """À appeler à chaque tour de boucle. Renvoie True quand ES doit recharger maintenant."""
        now = time.time()
        self.poll()
        if self.proc is not None:
            return False
        if self.reload_due:
            if busy or es_status("/isIdle") != 200:
                return False
            self.reload_due = False
            return True
        if now < self.next_check:
            return False
        self.next_check = now + self.CHECK
        if now >= self.sys_next:                                 # liste des systèmes (nouveau dossier de jeux, système masqué...)
            self.sys_next = now + self.SYSTEMS_EVERY
            lst = stair_systems()
            if lst is not None:
                self.sys_hash = tuple((s["name"], s["fullname"], s["manufacturer"], s["theme"]) for s in lst)
                if profile_sync(lst):                            # la carte profil change de système : le thème doit le relire
                    self.reload_due = True
        sig = tuple(mtime(p) for p in self.watch) + (self.sys_hash,)
        if sig != self.sig:
            self.sig, self.want, self.period = sig, True, self.PERIOD
            self.not_before = max(self.not_before, now + self.SETTLE)     # on attend la fin des modifications
        elif now - self.last_run > self.period:
            self.want = True                                     # contrôle de sécurité (fichier remplacé sur place...)
        if self.want and self.proc is None and now >= self.not_before:
            self._spawn(now)
        return False

def recording_previews():
    """Aperçu (image fixe) de chaque vidéo du système « recordings » : images/<nom>-image.jpg, puis
    déclaration dans <dossier>/gamelist.xml (<image> + <video>) : sans cela EmulationStation n'affiche pas
    l'aperçu des vidéos non sélectionnées dans la vue « Video ». N'ajoute que ce qui manque, ne touche
    jamais aux entrées existantes. Renvoie le nombre de changements (0 = rien à recharger)."""
    if not shutil.which("ffmpeg"):
        return 0
    changed = 0
    dirs = {os.path.realpath(d) for d in (os.path.join(userdata, "recordings"), os.path.join(ROMS, "recordings"))
            if os.path.isdir(d)}
    for d in dirs:
        vids = [v for v in sorted(glob.glob(os.path.join(d, "*")))
                if os.path.isfile(v) and os.path.splitext(v)[1].lower() in (".mp4", ".mkv", ".avi", ".webm", ".mov")]
        if not vids:
            continue
        for v in vids:
            stem = os.path.splitext(os.path.basename(v))[0]
            if glob.glob(os.path.join(d, "images", glob.escape(stem) + "-image.*")):
                continue                    # aperçu déjà là
            os.makedirs(os.path.join(d, "images"), exist_ok=True)
            j = os.path.join(d, "images", stem + "-image.jpg")
            tmp = j + ".tmp.jpg"
            for ss in ("2", "0"):           # image à 2 s, sinon la première
                r = subprocess.run(["ffmpeg", "-y", "-v", "error", "-ss", ss, "-i", v, "-frames:v", "1",
                                    "-vf", "scale=640:-2", "-q:v", "3", tmp],
                                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
                if r.returncode == 0 and os.path.isfile(tmp) and os.path.getsize(tmp) > 0:
                    os.replace(tmp, j)
                    changed += 1
                    break
        # déclaration dans gamelist.xml
        gl = os.path.join(d, "gamelist.xml")
        try:
            tree = ET.parse(gl) if os.path.isfile(gl) else ET.ElementTree(ET.Element("gameList"))
        except ET.ParseError:
            log("gamelist.xml des enregistrements illisible : laissé tel quel")
            continue
        root = tree.getroot()
        known = {}
        for g in root.findall("game"):
            p = g.findtext("path") or ""
            known[os.path.basename(p)] = g
        added = 0
        for v in vids:
            base = os.path.basename(v)
            stem = os.path.splitext(base)[0]
            img = os.path.join(d, "images", stem + "-image.jpg")
            g = known.get(base)
            if g is None:
                g = ET.SubElement(root, "game")
                ET.SubElement(g, "path").text = "./" + base
                ET.SubElement(g, "name").text = stem
                known[base] = g
                added += 1
            if g.find("video") is None:
                ET.SubElement(g, "video").text = "./" + base
                added += 1
            if g.find("image") is None and os.path.isfile(img):
                ET.SubElement(g, "image").text = "./images/" + stem + "-image.jpg"
                added += 1
        if added:
            try:
                ET.indent(tree)
                tmp = gl + ".tmp"
                tree.write(tmp, encoding="utf-8", xml_declaration=True)
                os.replace(tmp, gl)
                changed += added
                log(f"gamelist des enregistrements : {added} entrée(s) ajoutée(s)")
            except OSError as e:
                log(f"gamelist des enregistrements non écrit : {e}")
    if changed:
        log(f"enregistrements : {changed} changement(s) (aperçus / gamelist)")
    return changed

def wait_es():
    for _ in range(90):                     # attend qu'EmulationStation réponde (jusqu'à 3 min)
        if es_status("/isIdle") is not None:
            return
        time.sleep(2)

def reload_es(wait=0):
    time.sleep(wait)                        # le temps de sortir du menu (0 pour le nettoyage de la notification)
    down = 0
    for _ in range(300):                    # jusqu'à ~15 min (jeu lancé, indexation RetroAchievements...)
        st = es_status("/isIdle")           # 200 = libre, 201 = occupé
        if st == 200:
            break
        down = down + 1 if st is None else 0
        if down >= 5:
            log("EmulationStation injoignable : il prendra le changement au prochain démarrage")
            return
        time.sleep(3)
    else:
        log("EmulationStation occupé trop longtemps : liste non rechargée")
        return
    try:
        stairs_sync_variant()               # carte Favoris de l'escalier : version connecté / déconnecté du moment
    except Exception as e:
        log(f"escalier : version connecté / déconnecté non mise à jour ({e!r})")
    if es_status("/reloadgames") is None:
        log("EmulationStation injoignable : liste non rechargée")
    else:
        log("EmulationStation recharge la liste : carte profil à jour")

# --- « jeu à la une » sur la carte sélectionnée (mode vidéo) ---------------------------------------
# Au bout de 3 s sur une carte, le thème affiche art/spot/<thème du système>.jpg par-dessus la vidéo : l'image d'un jeu
# du système, une icône disque et le nom du jeu (comme la tuile « disque » du NXE). Le jeu choisi : le dernier lancé
# du système (s'il a une image), sinon un jeu au hasard qui en a une (gardé ensuite tant qu'il existe).
SPOT_W, SPOT_H = 1280, 970                  # proportions de la partie visible de la grande carte (0,3265 x 0,4404 de l'écran)
SPOT_COLLECTIONS = ("auto-allgames", "auto-lastplayed", "auto-neverplayed", "auto-multiplayer", "auto-retroachievements",
                    "auto-arcade", "auto-at2players", "auto-at4players", "collections", "all")

def spot_games(sysdir):
    """Jeux d'un système qui ont une image : (nom, image, dernière partie AAAAMMJJTHHMMSS, favori)."""
    out = []
    gl = os.path.join(sysdir, "gamelist.xml")
    if not os.path.isfile(gl):
        return out
    try:
        root = ET.parse(gl).getroot()
    except Exception as e:
        log(f"jeu à la une : gamelist illisible {gl} : {e}")
        return out
    for g in root.iter("game"):
        if (g.findtext("hidden") or "").strip().lower() == "true":
            continue
        img = None
        for tag in ("fanart", "image", "thumbnail"):
            v = (g.findtext(tag) or "").strip()
            if v:
                f = norm(os.path.join(sysdir, v))
                if os.path.isfile(f):
                    img = f
                    break
        if not img:
            continue
        name = (g.findtext("name") or "").strip()
        if not name:
            name = os.path.splitext(os.path.basename((g.findtext("path") or "").strip()))[0]
        name = re.sub(r"\s*[\(\[][^\)\]]*[\)\]]", "", name).strip() or name      # sans « (Europe) », « [!] »...
        out.append((name, img, (g.findtext("lastplayed") or "").strip(),
                    (g.findtext("favorite") or "").strip().lower() == "true"))
    return out

def _spot_font(size):
    from PIL import ImageFont
    for f in (os.path.join(theme_dir, "fonts", "xenonclatin.ttf"), "/usr/share/fonts/dejavu/DejaVuSans.ttf",
              "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"):
        try:
            return ImageFont.truetype(f, size)
        except Exception:
            continue
    return ImageFont.load_default()

def _spot_render(src, name, dst):
    """Image du jeu recadrée à la carte + icône disque (place de l'icône du système) + nom du jeu (place du titre)."""
    from PIL import Image, ImageDraw, ImageFilter
    W, H = SPOT_W, SPOT_H
    im = Image.open(src).convert("RGB")
    k = max(W / im.width, H / im.height)
    nw, nh = max(W, int(round(im.width * k))), max(H, int(round(im.height * k)))
    im = im.resize((nw, nh), Image.LANCZOS).crop(((nw - W) // 2, (nh - H) // 2, (nw - W) // 2 + W, (nh - H) // 2 + H))
    im = im.convert("RGBA")
    # léger voile sombre en bas (lisibilité du nom), comme le dégradé de la carte verte
    grad = Image.new("L", (1, H))
    for y in range(H):
        t = max(0.0, (y / H - 0.50) / 0.50)
        grad.putpixel((0, y), int(185 * t * t))
    shade = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    shade.putalpha(grad.resize((W, H)))
    im.alpha_composite(shade)
    # icône disque, même place et même taille que l'icône du système sur la carte
    disc_p = os.path.join(theme_dir, "art", "disc_icon.png")
    if os.path.isfile(disc_p):
        disc = Image.open(disc_p).convert("RGBA")
        dh = int(H * 0.44)
        disc = disc.resize((dh, dh), Image.LANCZOS)
        im.alpha_composite(disc, (int(W * 0.4922 - dh / 2), int(H * 0.4371 - dh / 2)))
    # nom du jeu : place et taille du titre de la carte (en bas à gauche)
    x0, ytop, maxw = int(W * 0.0299), int(H * 0.8087), int(W * 0.94)
    size = int(H * 0.081)
    font = _spot_font(size)
    d = ImageDraw.Draw(im)
    text = name
    while size > int(H * 0.055) and d.textlength(text, font=font) > maxw:
        size -= 2
        font = _spot_font(size)
    while d.textlength(text, font=font) > maxw and len(text) > 1:
        text = text[:-2].rstrip() + "…"
    glow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    ImageDraw.Draw(glow).text((x0 + 2, ytop + 2), text, font=font, fill=(0, 0, 0, 150))
    im.alpha_composite(glow.filter(ImageFilter.GaussianBlur(3)))
    ImageDraw.Draw(im).text((x0, ytop), text, font=font, fill=(255, 255, 255, 255))
    tmp = dst + ".tmp.jpg"
    im.convert("RGB").save(tmp, "JPEG", quality=90)
    os.replace(tmp, dst)

def spot_cards(only=None):
    """Prépare art/spot/<thème>.jpg pour chaque système (ou seulement `only` + les collections). Renvoie le nombre
    d'images changées (0 si rien à faire ou Python Imaging Library absente)."""
    try:
        import PIL  # noqa: F401
    except ImportError:
        log("jeu à la une : Python Imaging Library absente")
        return 0
    import random
    out = os.path.join(theme_dir, "art", "spot")
    try:
        os.makedirs(out, exist_ok=True)
    except OSError:
        return 0
    sy = stair_systems()
    themes = {x["name"]: x["theme"] for x in sy} if sy else {}
    allg, targets = [], []
    for sysdir in sorted(glob.glob(os.path.join(ROMS, "*"))):
        if not os.path.isdir(sysdir):
            continue
        name = os.path.basename(sysdir)
        games = spot_games(sysdir)
        allg += games
        if only is None or name == only:
            targets.append((themes.get(name, name), games))
    targets += [(c, allg) for c in SPOT_COLLECTIONS]
    targets.append(("auto-favorites", [g for g in allg if g[3]]))
    changed = 0
    for theme, games in targets:
        if not games or not re.match(r"^[A-Za-z0-9_.+-]+$", theme):
            continue
        dst, srcf = os.path.join(out, theme + ".jpg"), os.path.join(out, theme + ".src")
        played = [g for g in games if g[2]]
        pick = max(played, key=lambda g: g[2]) if played else None
        if pick is None:                                   # jamais joué : on garde le jeu déjà choisi s'il existe encore
            try:
                with open(srcf, encoding="utf-8") as f:
                    prev_img = f.read().split("\t")[0]
                pick = next((g for g in games if g[1] == prev_img), None)
            except OSError:
                pick = None
        if pick is None:
            pick = random.choice(games)
        try:
            sig = "%s\t%s\t%d" % (pick[1], pick[0], int(os.path.getmtime(pick[1])))
        except OSError:
            continue
        try:
            with open(srcf, encoding="utf-8") as f:
                if f.read() == sig and os.path.isfile(dst):
                    continue
        except OSError:
            pass
        try:
            _spot_render(pick[1], pick[0], dst)
            with open(srcf, "w", encoding="utf-8") as f:
                f.write(sig)
            changed += 1
        except Exception as e:
            log(f"jeu à la une : image impossible pour {theme} ({pick[1]}) : {e!r}")
    if changed:
        log(f"jeu à la une : {changed} image(s) mise(s) à jour")
    return changed

# --- « file de jaquettes » de la vue Carousel (façon « Jeux » du Marketplace NXE) ---------------------------
# Pour chaque jeu : art/gstack/<système>/<fichier du jeu sans extension>/1.png ... 11.png = jaquettes des 11 jeux qui le
# suivent dans la liste. Ce sont des liens vers les images déjà scrapées (rien n'est recopié) ; si le disque ne sait pas
# faire de liens (exFAT...), petite copie réduite. Le thème les affiche de plus en plus petites vers la droite.
# L'ordre est celui d'EmulationStation (liste lue par son API locale) : tri par nom ou par dernière partie, favoris en
# premier si l'option est activée, jeux masqués exclus. Autre tri, ou dossiers affichés : pas de file pour ce système.
GS_SLOTS, GS_LOOP_MIN = 11, 14              # la grille du thème a 13 colonnes : elle ne boucle qu'au-delà
GS_SORTS = {0: ("name", False), 1: ("name", True), 6: ("lastplayed", False), 7: ("lastplayed", True)}
GS_MEDIA = ("boxart", "thumbnail", "image")  # même ordre que la grille du thème (imageSource boxart)
GS_MEDIA_SYS = ("imageviewer", "recordings", "library")   # captures, vidéos... : l'image, c'est le fichier (comme ES)

def _es_json(path):
    with _opener.open(ES_API + path, timeout=60) as r:
        return json.loads(r.read().decode("utf-8", "ignore"))

def _gs_flag(sysname, key, default):
    v = es_setting(f"{sysname}.{key}", "")            # réglage propre au système ("1" / "0"), sinon réglage général
    if v in ("1", "0"):
        return v == "1"
    return es_setting(key, "true" if default else "false").lower() == "true"

def gstack_order(sysname, games, collection):
    """Jeux dans l'ordre affiché par EmulationStation, ou None si ce tri n'est pas reproduit."""
    try:
        sort_key, desc = GS_SORTS[int(es_setting(f"{sysname}.sort", "7" if sysname == "recent" else "0"))]
    except (KeyError, ValueError):
        return None
    fv = es_setting(f"{sysname}.FolderViewMode", "")
    if (fv if fv not in ("", "auto") else es_setting("FolderViewMode", "never")) != "never":
        return None
    hidden = _gs_flag(sysname, "ShowHiddenFiles", False)
    hext = set() if collection else {e for e in es_setting(f"{sysname}.HiddenExt", "").lower().split(";") if e}
    out = [g for g in games if g.get("path") and (hidden or str(g.get("hidden", "")).lower() != "true")
           and os.path.splitext(g["path"])[1][1:].lower() not in hext]
    if sort_key == "name":
        # shortcut: articles « A, AN, THE » seulement (option « ignorer les articles »), ES prend ceux de sa langue
        arts = ("A ", "AN ", "THE ") if _gs_flag(sysname, "IgnoreLeadingArticles", False) else ()
        def k(g):
            n = (g.get("sortname") or g.get("name") or "").strip().upper()
            for a in arts:
                if n.startswith(a):
                    return n[len(a):].strip()
            return n
    else:
        k = lambda g: g.get("lastplayed") or ""
    out.sort(key=k, reverse=desc)
    if sysname not in ("favorites", "recent") and _gs_flag(sysname, "FavoritesFirst", False):
        out.sort(key=lambda g: str(g.get("favorite", "")).lower() != "true")   # tri stable : favoris devant
    return out

def gstack_run():
    """Prépare art/gstack/ pour tous les systèmes affichés. Renvoie le nombre de jeux mis à jour (-1 : ES injoignable)."""
    import fcntl
    try:
        lock = open(os.path.join(data_dir, "gstack.lock"), "w")
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except OSError:
        return 0                                       # déjà en cours
    try:
        systems = _es_json("/systems")
    except Exception:
        return -1
    out_root = os.path.join(theme_dir, "art", "gstack")
    sys_dirs = lambda: {d for d in (os.listdir(out_root) if os.path.isdir(out_root) else []) if not d.startswith(".")}
    before = sys_dirs()
    def es_res(name):
        """Image des ressources d'EmulationStation ("" si introuvable)."""
        return next((f for f in (os.path.join(userdata, "system", ".emulationstation", "resources", name),
                                 "/usr/share/emulationstation/resources/" + name) if os.path.isfile(f)), "")
    none = es_res("cartridge.svg")   # jeu sans image : la cartouche d'ES (case k.svg du thème) ; introuvable : case vide
    thumbs, used_thumbs = os.path.join(out_root, ".miniatures"), set()
    noms, used_noms = os.path.join(out_root, ".noms"), set()

    def name_overlay(title):
        """Nom du jeu écrit comme EmulationStation l'écrit sur sa cartouche (blanc, centré, sa police), sur fond transparent
        au format de la cartouche : le thème le pose par-dessus (case k_nom.png). Une image par nom, gardée en cache."""
        import hashlib
        from PIL import Image, ImageDraw, ImageFont
        if not none or not title:
            return ""
        dst = os.path.join(noms, hashlib.md5(title.encode("utf-8")).hexdigest()[:16] + ".png")
        used_noms.add(os.path.basename(dst))
        if os.path.isfile(dst):
            return dst
        try:                                       # format de la cartouche (attributs width / height du SVG)
            m = re.search(r'<svg[^>]*?\swidth="([\d.]+)[^>]*?\sheight="([\d.]+)', open(none, errors="ignore").read(4000))
            ar = float(m.group(1)) / float(m.group(2)) if m else 1.0
        except (OSError, ValueError, ZeroDivisionError):
            ar = 1.0
        w = 400
        h = max(1, round(w / ar))
        fp = es_res("ubuntu_condensed.ttf") or es_res("opensans_hebrew_condensed_regular.ttf") or FONT
        f = ImageFont.truetype(fp, round(0.114 * w))      # taille du nom d'ES par rapport à la cartouche sélectionnée
        lines, cur = [], ""
        for word in title.split():                        # retour à la ligne sur 80 % de la largeur, 3 lignes au plus
            t = (cur + " " + word).strip()
            if cur and f.getlength(t) > 0.8 * w:
                lines.append(cur)
                cur = word
            else:
                cur = t
        lines = (lines + [cur])[:3]
        im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        d = ImageDraw.Draw(im)
        lh = f.size * 1.15
        y = 0.55 * h - lh * len(lines) / 2
        for ln in lines:
            d.text((w / 2, y + lh / 2), ln, font=f, fill=(255, 255, 255, 255), anchor="mm",
                   stroke_width=2, stroke_fill=(0, 0, 0, 40))
            y += lh
        os.makedirs(noms, exist_ok=True)
        im.save(dst)
        return dst

    def media_cover(p):
        """Captures, vidéos, musiques, PDF : la même image qu'EmulationStation."""
        ext = os.path.splitext(p)[1].lower()
        image = ext in (".jpg", ".jpeg", ".png", ".bmp", ".gif")
        if ext in (".mp3", ".wav", ".ogg", ".flac"):
            return es_res("mp3.jpg") or none
        if ext == ".pdf":
            return es_res("pdf.jpg") or none
        if not (image or ext in (".mp4", ".mkv", ".avi", ".webm")) or not os.path.isfile(p):
            return none
        # miniature (petite JPG) : la capture entière (1080p, plusieurs Mo) mettait trop de temps à charger à chaque
        # déplacement, d'où le scintillement ; vidéo : une image extraite par ffmpeg
        dst = os.path.join(thumbs, re.sub(r"[^\w.-]", "_", os.path.relpath(p, userdata)) + ".jpg")
        used_thumbs.add(os.path.basename(dst))
        if (mtime(dst) or 0) >= (mtime(p) or 0):
            return dst
        os.makedirs(thumbs, exist_ok=True)
        if image:
            try:
                from PIL import Image
                im = Image.open(p)
                im.thumbnail((1000, 400), Image.LANCZOS)     # 400 de haut : la plus grande carte de la file fait 354 en 1080p
                im.convert("RGB").save(dst, "JPEG", quality=85)
                return dst
            except Exception:
                return p                               # pas de miniature : la capture entière
        for ss in ("1", "0"):
            try:
                subprocess.run(["ffmpeg", "-y", "-v", "error", "-ss", ss, "-i", p, "-frames:v", "1",
                                "-vf", "scale=480:-2", dst], timeout=30, capture_output=True)
            except Exception:
                break
            if os.path.isfile(dst) and os.path.getsize(dst):
                return dst
        return none
    W, H = screen_size()
    gl_cache, changed, seen = {}, 0, set()

    def local_media(path):
        """Images du jeu d'après le gamelist.xml de son système (premier dossier parent qui en a un)."""
        sysdir = os.path.dirname(norm(path))
        while not os.path.isfile(os.path.join(sysdir, "gamelist.xml")) and os.path.dirname(sysdir) != sysdir:
            sysdir = os.path.dirname(sysdir)
        if sysdir not in gl_cache:
            m = {}
            try:
                for g in ET.parse(os.path.join(sysdir, "gamelist.xml")).getroot().iter("game"):
                    p = (g.findtext("path") or "").strip()
                    if p:
                        m[norm(os.path.join(sysdir, p))] = {t: norm(os.path.join(sysdir, v)) for t in GS_MEDIA
                                                            for v in [(g.findtext(t) or "").strip()] if v}
            except Exception:
                pass
            gl_cache[sysdir] = m
        return gl_cache[sysdir].get(norm(path), {})

    def cover(g):
        for t in GS_MEDIA:
            f = local_media(g["path"]).get(t)
            if f and os.path.isfile(f):
                return f
        if any(t in g for t in GS_MEDIA) and g.get("id"):     # image trouvée par ES ailleurs que dans gamelist.xml
            try:
                d = _es_json("/systems/%s/games/%s?localpaths=true" % (
                    urllib.parse.quote(g.get("systemName") or ""), urllib.parse.quote(str(g["id"]))))
                for t in GS_MEDIA:
                    f = d.get(t)
                    if f and os.path.isfile(f):
                        return f
            except Exception:
                pass
        return none

    def put(src, dst, k):
        """Lien vers l'image ; copie réduite (taille de la case k) si le disque ne sait pas faire de liens."""
        try:
            os.symlink(src, dst)
            return
        except OSError:
            pass
        if src.endswith(".svg"):
            shutil.copyfile(src, dst)
            return
        from PIL import Image
        sh = 0.80 * 0.4404 * H / (1 + 0.12 * (k - 1))
        im = Image.open(src)
        im.thumbnail((max(1, round(0.70 * sh)), max(1, round(sh))), Image.LANCZOS)
        if im.mode in ("RGBA", "LA", "P"):
            im.convert("RGBA").save(dst, "PNG")
        else:
            im.convert("RGB").save(dst, "JPEG", quality=88)   # nom en .png : ES reconnaît le format au contenu

    failed = False
    for s in systems if isinstance(systems, list) else []:
        name = str(s.get("name") or "") if isinstance(s, dict) else ""
        if not name or str(s.get("visible", "true")).lower() != "true" or "/" in name:
            continue
        try:
            games = gstack_order(name, _es_json("/systems/%s/games" % urllib.parse.quote(name)),
                                 str(s.get("collection", "")).lower() == "true")
        except Exception as e:
            log(f"file de jaquettes : liste de {name} illisible ({e!r})")
            seen.add(name)                             # on garde l'existant
            failed = True                              # ES occupé (rechargement) : refait dans 10 s
            continue
        if not games or len(games) < 2:
            continue
        seen.add(name)
        sdir = os.path.join(out_root, name)
        n, keep, errs = len(games), set(), 0
        covers = [media_cover(g["path"]) if name in GS_MEDIA_SYS else cover(g) for g in games]
        ovls = [name_overlay(str(g.get("name") or "")) if c == none and name not in GS_MEDIA_SYS else ""
                for g, c in zip(games, covers)]
        for i, g in enumerate(games):
            # shortcut: deux jeux du même nom de fichier (sous-dossiers, collections) partagent leur file : le dernier gagne
            stem = os.path.splitext(os.path.basename(g["path"].rstrip("/")))[0]
            if not stem or stem.startswith("."):
                continue
            idx = [(i + k) % n for k in range(1, GS_SLOTS + 1)] if n >= GS_LOOP_MIN else list(range(i + 1, min(n, i + 1 + GS_SLOTS)))
            sig = "\n".join("%s\t%d\t%s" % (covers[j], int(mtime(covers[j]) or 0), ovls[j]) for j in idx)
            gdir = os.path.join(sdir, stem)
            keep.add(stem)
            try:
                with open(os.path.join(gdir, "links.txt"), encoding="utf-8") as f:
                    if f.read() == sig:
                        continue
            except OSError:
                pass
            try:
                os.makedirs(gdir, exist_ok=True)
                _rm(*(os.path.join(gdir, f"{k}{e}") for k in range(1, GS_SLOTS + 1) for e in (".png", ".svg", "_nom.png")))
                for k, j in enumerate(idx, 1):
                    if covers[j]:                      # cartouche d'ES en .svg (ES reconnaît le SVG à l'extension)
                        put(covers[j], os.path.join(gdir, f"{k}.svg" if covers[j].endswith(".svg") else f"{k}.png"), k)
                    if ovls[j]:                        # jeu sans image : son nom par-dessus la cartouche
                        put(ovls[j], os.path.join(gdir, f"{k}_nom.png"), k)
                _write_atomic(os.path.join(gdir, "links.txt"), sig)
                changed += 1
            except Exception as e:
                errs += 1
                if errs == 1:                          # une seule ligne par système dans le journal
                    log(f"file de jaquettes : {name}/{stem} impossible ({e!r})")
        for old in os.listdir(sdir) if os.path.isdir(sdir) else []:     # jeux disparus
            if old not in keep:
                shutil.rmtree(os.path.join(sdir, old), ignore_errors=True)
    for d, used in ((thumbs, used_thumbs), (noms, used_noms)):          # images de vidéos et noms qui ne servent plus
        for old in os.listdir(d) if os.path.isdir(d) else []:
            if old not in used:
                _rm(os.path.join(d, old))
    for old in os.listdir(out_root) if os.path.isdir(out_root) else []:  # systèmes disparus ou tri non reproduit
        if old not in seen and not old.startswith("."):
            shutil.rmtree(os.path.join(out_root, old), ignore_errors=True)
    if changed:
        log(f"file de jaquettes : {changed} jeu(x) mis à jour")
    if sys_dirs() != before:   # le thème choisit file ou jaquettes de la grille selon art/gstack/<système> : ES doit le relire
        reload_es(0)
    return -1 if failed else changed

def gstack_sig():
    """Change quand une liste de jeux ou un réglage d'ES change (gamelist.xml, es_settings.cfg)."""
    return tuple(mtime(f) for f in [ES_SETTINGS] + sorted(glob.glob(os.path.join(ROMS, "*", "gamelist.xml"))))

# --- notification « connecté » du thème (toast_nxe) -----------------------------
# Le thème affiche la notification tant que le fichier art/recent/toast.on existe ET que
# RetroAchievements + le réseau sont actifs. Le script le crée au démarrage d'EmulationStation
# (ou quand RetroAchievements vient d'être activé), puis le retire quelques secondes plus tard
# pour qu'elle ne revienne pas à chaque défilement.
TOAST = os.path.join(OUT, "toast.on")           # « connecté à RetroAchievements »
TOAST_LOST = os.path.join(OUT, "toast.lost")    # « déconnecté de RetroAchievements »
TOAST_SECONDS = 2.0                             # l'animation du thème dure 1,9 s ; puis rechargement de nettoyage immédiat

def toast_on(kind="on"):
    toast_off()
    try:
        os.makedirs(OUT, exist_ok=True)
        with open(TOAST if kind == "on" else TOAST_LOST, "w") as f:
            f.write("1")
    except OSError:
        pass

def toast_off():
    _rm(TOAST, TOAST_LOST)

def link_up():
    """Câble / Wi-Fi : une carte réseau (hors loopback) est-elle active ? Lecture instantanée du noyau :
    débrancher le câble ou couper le Wi-Fi est vu tout de suite."""
    try:
        for n in os.listdir("/sys/class/net"):
            if n == "lo":
                continue
            with open(f"/sys/class/net/{n}/operstate") as f:
                if f.read().strip() in ("up", "unknown"):
                    return True
    except OSError:
        return True                         # impossible à lire : on s'en remet au test internet
    return False

NET = {"ok": True}

def net_ok(timeout=2):
    """Internet joignable ? Connexion TCP rapide vers des serveurs publics (par adresse IP : pas de DNS,
    et aucune charge sur le site de RetroAchievements). Réseau coupé = échec immédiat."""
    import socket
    for host in ("1.1.1.1", "8.8.8.8"):
        try:
            socket.create_connection((host, 443), timeout).close()
            return True
        except OSError:
            continue
    return False

def net_probe_loop():
    """Test internet en continu dans un fil à part (1 s d'écart) : une box sans internet est vue en ~1-2 s."""
    while True:
        NET["ok"] = net_ok(1)
        time.sleep(1)

if action == "watch":
    import fcntl
    lock = open(os.path.join(data_dir, "watch.lock"), "w")
    try:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except OSError:
        sys.exit(0)                         # déjà lancée
    with open(os.path.join(data_dir, "watch.pid"), "w") as f:
        f.write(str(os.getpid()))
    ALIVE = "/var/run/nxe360/watch.alive"      # le thème n'affiche la notification que si la surveillance tourne
    try:
        os.makedirs(os.path.dirname(ALIVE), exist_ok=True)
        with open(ALIVE, "w") as f:
            f.write(str(os.getpid()))
    except OSError:
        pass
    import atexit
    atexit.register(_rm, ALIVE)
    import signal
    signal.signal(signal.SIGTERM, lambda *_: sys.exit(0))   # arrêt demandé : on passe quand même par _alive_off
    try:                                    # version du script que cette surveillance exécute (la shell la compare au fichier)
        with open(os.path.join(data_dir, "watch.ver"), "w") as f:
            f.write(str(os.stat(SELF_PATH).st_mtime_ns // 1000000000))
    except OSError:
        pass
    conf = read_conf()
    toast_until = 0
    import threading
    NET["ok"] = net_ok()
    threading.Thread(target=net_probe_loop, daemon=True).start()
    net_state = link_up() and NET["ok"]
    last = ra_state(conf)
    conn = bool(last[0] and last[1] and net_state)     # connecté = RA activé + compte + internet
    toast_boot = conn
    toast_off()
    cache_user(conf)
    last_m, tick = mtime(CONF), 0
    nl = NoLoop()                           # carrousel des systèmes sans boucle (option du thème)
    nl.tick()
    sw = StairWatch()                       # escalier : images préparées en arrière-plan (option du thème)
    SPOT = {"done": False, "changed": 0}
    def _spot_bg():                         # « jeu à la une » : images préparées en arrière-plan au démarrage
        wait_es()
        try:
            SPOT["changed"] = spot_cards(None)
        except Exception as e:
            log(f"jeu à la une : {e!r}")
        try:
            if pads_layout():
                SPOT["changed"] += 1
        except Exception as e:
            log(f"manettes : {e!r}")
        SPOT["done"] = True
        GS["sig"] = None                    # file de jaquettes : préparée par la boucle ci-dessous (dans les 10 s)
    GS = {"sig": "attente", "thread": None}   # "attente" : jusqu'à la fin des images « jeu à la une » ; None : à faire
    def _gs_bg():                           # file de jaquettes de la vue Carousel (pas besoin de recharger ES)
        sig, GS["sig"] = gstack_sig(), None     # reste None (à refaire) si ES est injoignable ou en cas d'erreur
        try:
            if gstack_run() >= 0:
                GS["sig"] = sig
        except Exception as e:
            log(f"file de jaquettes : {e!r}")
    threading.Thread(target=_spot_bg, daemon=True).start()
    nav = NavSound()                        # son du carrousel selon le sens (panel-left / panel-right)
    nav.tick()
    if nav.flag_new:
        sw.reload_due = True                # le thème doit être relu une fois pour couper son son de défilement unique
    if stairs_sync_variant() and stairs_enabled():
        sw.reload_due = True                # connecté / déconnecté a changé depuis la dernière session : rechargement dès qu'ES est prêt
    rec_changed = recording_previews()      # aperçus des enregistrements manquants (une fois par démarrage)
    log(f"surveillance RetroAchievements lancée ({'activé' if last[0] else 'désactivé'}, "
        f"internet {'ok' if net_state else 'coupé'})")
    if rec_changed and not toast_boot:
        wait_es()
        reload_es()
        sw.reload_due = False               # ce rechargement a aussi mis à jour l'escalier
    if toast_boot:
        # Les animations du thème se jouent à la création de l'écran, pendant le chargement d'ES : on les
        # relance une fois EmulationStation prêt, avec la notification demandée.
        wait_es()
        toast_on("on")
        log("notification « connecté » demandée au démarrage")
        reload_es()
        sw.reload_due = False
        toast_until = time.time() + TOAST_SECONDS
    while True:
        time.sleep(0.2)                     # tour rapide : câble / Wi-Fi vu à l'instant, fin de notification guettée de près
        nl.tick()
        nav.tick()
        if SPOT["done"]:
            SPOT["done"] = False
            if SPOT["changed"]:
                sw.reload_due = True        # nouvelles images « jeu à la une » : le thème les relit dès qu'ES est libre
        if toast_until:
            if time.time() > toast_until:
                toast_off()
                toast_until = 0
                # le thème garde le contenu de la notification jusqu'au prochain rechargement : on le recharge
                # une dernière fois, fichier supprimé, tout de suite, pour qu'elle ne revienne plus au défilement
                sw.poll()
                reload_es(0)
                sw.reload_due = False       # ce rechargement a aussi pris les éventuelles nouvelles images de l'escalier
            continue
        tick += 1
        if tick % 50 == 0 and GS["sig"] != "attente" and not (GS["thread"] and GS["thread"].is_alive()) \
                and gstack_sig() != GS["sig"]:   # une liste de jeux ou un réglage a changé (toutes les 10 s)
            GS["thread"] = threading.Thread(target=_gs_bg, daemon=True)
            GS["thread"].start()
        if tick % 150 == 0 and os.path.isdir(os.path.join(theme_dir, "art", "avatar")) \
                and not os.path.exists(os.path.join(theme_dir, "art", "avatar", ".nxe360_ok")) \
                and os.path.isfile(os.path.join(theme_dir, "theme.xml")) and SELF_PATH and os.path.isfile(SELF_PATH):
            log("dossier du thème remplacé (mise à jour) : avatars remis et images refaites")
            subprocess.Popen(["bash", SELF_PATH, "refresh"], stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL,
                             stderr=subprocess.DEVNULL, start_new_session=True)
        if tick % 150 == 0 and not theme_active():
            toast_off()
            nl.stop()
            nav.stop()
            log("thème NXE360 plus actif : surveillance arrêtée")
            break
        ra_changed = net_changed = False
        m = mtime(CONF)
        if m != last_m:
            time.sleep(1)                   # batocera.conf peut être en cours d'écriture
            last_m = mtime(CONF)
            st = ra_state(read_conf())
            if st != last:
                last = st
                ra_changed = True
                log(f"RetroAchievements {'activé' if st[0] else 'désactivé'} ({st[1] or 'sans compte'}) : mise à jour")
                update_ra_points()
        n = link_up() and NET["ok"]         # câble/Wi-Fi (instantané) ET internet joignable (sonde en continu)
        if n != net_state:
            net_state, net_changed = n, True
            log(f"internet {'rétabli' if n else 'coupé'}")
        if not (ra_changed or net_changed):
            if sw.tick():                   # escalier : nouvelles images publiées, ES libre -> il recharge le thème
                reload_es(0)
            continue
        new_conn = bool(last[0] and last[1] and net_state)
        kind = "on" if (new_conn and not conn) else "lost" if (conn and not new_conn) else None
        conn = new_conn
        if kind:                            # notification affichée après le rechargement
            toast_on(kind)
            log("notification « connecté » demandée" if kind == "on" else "notification « déconnecté » demandée")
        sw.poll()
        reload_es(0)
        sw.reload_due = False
        if kind:
            toast_until = time.time() + TOAST_SECONDS
        else:
            toast_off()
    sys.exit(0)

if action == "stairs":
    sys.exit(stairs_run())

history = read_history()
if action in ("start", "stop") and rom and not excluded(rom):
    history.insert(0, (system, rom))
if not history:
    history = seed_from_gamelists()
history = write_history(history)

if action == "start":
    sys.exit(0)                            # au lancement du jeu on note seulement le jeu

slot = 0
for s, r in history:
    if slot >= SLOTS:
        break
    if not os.path.exists(r) or excluded(r):
        continue
    media, kind, name = find_media(s, r)
    slot += 1
    dst = os.path.join(OUT, f"{slot}.png")
    if media:
        render(media, dst, kind)
        log(f"{slot} : {os.path.basename(r)} <- {kind} {media}")
    else:
        how = placeholder(name, dst)
        log(f"{slot} : {os.path.basename(r)} : pas d'image, vignette « {name} » ({how})")

_rm(*(os.path.join(OUT, f"{k}.png") for k in range(slot + 1, SLOTS + 1)))   # moins de 4 jeux : on vide les cases restantes

recording_previews()
# fonds des cartes : tous à « refresh » ; à la fin d'un jeu, seulement son système (+ les collections)
spot_cards(None if action == "refresh" else (system or None))
update_ra_points()
if action == "refresh":
    try:
        gstack_run()
    except Exception as e:
        log(f"file de jaquettes : {e!r}")
    _sy = stair_systems()
    _profile = profile_sync(_sy) if _sy else False               # carte profil : Xbox 360 si présent, sinon Favoris
    if (stairs_run() == 10 and stairs_enabled()) or _profile:
        reload_es(0)                            # nouvelles images de l'escalier : ES recharge le thème pour les afficher
PYEOF
PYRC=$?

# journal limité à 300 lignes
# (réécrit le même fichier : la surveillance, qui écrit dedans en continu, continue d'y écrire)
if [ "$action" != "watch" ] && [ "$action" != "stairs" ]; then
    t=$(tail -n 300 "$DATA_DIR/nxe360_recent.log" 2>/dev/null) && printf '%s\n' "$t" > "$DATA_DIR/nxe360_recent.log"
fi
# « stairs » renvoie le code de la préparation des images : 0 rien à faire, 10 images publiées ou retirées, 11 mises à jour sur place,
# 2 EmulationStation pas prêt, 3 occupé (jeu en cours), 1 impossible
[ "$action" = "stairs" ] && exit "$PYRC"
exit 0
