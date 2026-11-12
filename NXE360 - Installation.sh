#!/bin/bash
# NXE360 - Installation des scripts du thème (une seule fois)
#   1. copie ce fichier dans /userdata/roms/ports/  (réseau \\BATOCERA\share\roms\ports, FTP ou clé USB)
#   2. Menu > Mettre à jour la liste des jeux, puis lance « NXE360 - Installation » dans Ports
# Pose deux petits lanceurs qui appellent les scripts du thème actif (ils se mettent à jour avec le thème).
# Le détail de l'installation s'affiche à l'écran dès le retour dans EmulationStation (fenêtre puis notifications).
U="${NXE360_USERDATA:-/userdata}"                 # (variable de test uniquement)
ES="$U/system/configs/emulationstation/es_settings.cfg"
API=http://127.0.0.1:1234
setting() { grep -o "name=\"$1\" value=\"[^\"]*\"" "$ES" 2>/dev/null | sed 's/.*value="//;s/"$//'; }
# Rien ne doit rester en marche après l'installateur : lancé depuis Ports, Batocera attendrait la fin de tout ce
# qu'il a démarré, et l'écran de lancement resterait affiché. Sa fenêtre est donc laissée dans un fichier, que
# nxe360_recent.sh affiche une fois revenu dans EmulationStation (événement game-end) ou tout de suite en SSH.
P="$U/system/configs/nxe360"
STUB_SCRIPT="$U/system/scripts/nxe360_recent.sh"
show() {   # $1 = texte de la fenêtre, $2/$3 = notifications (seulement si l'installation a réussi)
    echo "$1"
    mkdir -p "$P"
    printf '%s' "$1" > "$P/install_msg.txt"
    if [ -n "$2" ]; then printf '%s\n%s\n' "$2" "$3" > "$P/install_notes.txt"; else rm -f "$P/install_notes.txt"; fi
    # Lancé depuis Ports (batocera-launch parmi les parents) : on ne lance RIEN maintenant. On pose un petit script
    # à usage unique sur l'événement « game-end » d'EmulationStation : ES le lance lui-même une fois revenu au menu.
    # Lancé en SSH : on affiche tout de suite, détaché, sans aucun descripteur hérité.
    local p=$$ hook="$U/system/configs/emulationstation/scripts/game-end/nxe360_install.sh"
    while [ "$p" -gt 1 ]; do
        if grep -q "batocera-launch" "/proc/$p/cmdline" 2>/dev/null; then
            mkdir -p "${hook%/*}"
            printf '%s\n' '#!/bin/bash' '# NXE360 : à usage unique, posé par « NXE360 - Installation » (il se supprime tout seul)' \
                'rm -f "$0"' "setsid bash \"$STUB_SCRIPT\" installdone </dev/null >/dev/null 2>&1 &" 'exit 0' > "$hook"
            chmod +x "$hook"
            return 0
        fi
        p=$(ps -o ppid= -p "$p" 2>/dev/null | tr -d ' ')
        [ -n "$p" ] || break
    done
    [ -f "$STUB_SCRIPT" ] && ( for f in /proc/$BASHPID/fd/*; do n=${f##*/}; [ "$n" -gt 2 ] 2>/dev/null && eval "exec $n>&-"; done
                              exec setsid bash "$STUB_SCRIPT" installdone </dev/null >/dev/null 2>&1 ) &
}
case "$(setting Language)" in fr*) FR=1 ;; *) FR= ;; esac
t() { [ -n "$FR" ] && printf '%s' "$1" || printf '%s' "$2"; }   # texte français / anglais
stub() {   # $1 = nom du script dans le thème
    cat <<STUB
#!/bin/bash
# NXE360 : lance $1 fourni avec le thème actif (créé par « NXE360 - Installation » ; il se met à jour avec le thème)
t=\$(grep -o 'name="ThemeSet" value="[^"]*"' $ES 2>/dev/null | sed 's/.*value="//;s/"\$//')
s="$U/themes/\$t/$1"
[ -n "\$t" ] && [ -f "\$s" ] || s=\$(ls $U/themes/*/$1 2>/dev/null | head -1)
[ -f "\$s" ] && exec bash "\$s" "\$@"
exit 0
STUB
}

active=$(setting ThemeSet)
T="$U/themes/$active"
[ -n "$active" ] && [ -f "$T/nxe360_recent.sh" ] || T=$(dirname "$(ls "$U"/themes/*/nxe360_recent.sh 2>/dev/null | head -1)")
if [ ! -f "$T/nxe360_recent.sh" ]; then
    show "$(t "NXE360 : thème introuvable.

Installe d'abord le thème NXE360 :
Menu > Mises à jour et téléchargements > Thèmes." "NXE360: theme not found.

Install the NXE360 theme first:
Menu > Updates & downloads > Themes.")"
    exit 1
fi
if [ "${active,,}" != "$(basename "$T" | tr 'A-Z' 'a-z')" ]; then
    mkdir -p "$U/system/scripts"; stub nxe360_recent.sh > "$STUB_SCRIPT" && chmod +x "$STUB_SCRIPT"
    show "$(t "NXE360 n'est pas le thème actif.

1. Réglages de l'interface > Thème > NXE360
2. Relance « NXE360 - Installation » dans Ports." "NXE360 is not the active theme.

1. UI settings > Theme > NXE360
2. Launch « NXE360 - Installation » from Ports again.")"
    exit 1
fi

ok() { printf '[OK] %s\n' "$1"; }
ko() { printf '[X] %s\n' "$1"; }
mkdir -p "$U/system/scripts" "$U/roms/ports"
R=""
if stub nxe360_recent.sh > "$U/system/scripts/nxe360_recent.sh" && chmod +x "$U/system/scripts/nxe360_recent.sh"; then
    R+=$(ok "$(t "Script NXE360 (derniers jeux, escalier, jaquettes, RetroAchievements)" "NXE360 script (recent games, staircase, box art, RetroAchievements)")")$'\n'
else
    R+=$(ko "$(t "Script NXE360 : écriture impossible dans /userdata/system/scripts" "NXE360 script: cannot write to /userdata/system/scripts")")$'\n'
fi
if [ -f "$T/360sona.sh" ] && stub 360sona.sh > "$U/roms/ports/360sona.sh" && chmod +x "$U/roms/ports/360sona.sh"; then
    [ -f "$T/360sona.sh.keys" ] && cp -f "$T/360sona.sh.keys" "$U/roms/ports/360sona.sh.keys"   # manette = souris dans 360sona
    R+=$(ok "$(t "360sona ajouté dans Ports (créateur d'avatar)" "360sona added to Ports (avatar creator)")")$'\n'
fi
python3 -c "import PIL" 2>/dev/null && R+=$(ok "Python + Pillow")$'\n' || R+=$(ko "$(t "Pillow absent : escalier et jaquettes désactivés" "Pillow missing: staircase and box art disabled")")$'\n'
command -v ffmpeg >/dev/null && R+=$(ok "ffmpeg")$'\n' || R+=$(ko "$(t "ffmpeg absent : miniatures des vidéos désactivées" "ffmpeg missing: video thumbnails disabled")")$'\n'

MSG="$(t "NXE360 - INSTALLATION" "NXE360 - SETUP")

$R
$(t "Le thème se prépare maintenant (1 à 2 minutes).
Suis l'avancement dans les notifications ; il se recharge tout seul à la fin." "The theme is now preparing itself (1-2 minutes).
Follow the notifications; it reloads by itself when done.")"

show "$MSG" "$(t "NXE360 : préparation du thème..." "NXE360: preparing the theme...")" "$(t "NXE360 : prêt, rechargement du thème" "NXE360: ready, reloading the theme")"
exit 0
