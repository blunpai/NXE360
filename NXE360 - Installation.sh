#!/bin/bash
# NXE360 - Installation des scripts du thème (une seule fois)
#   1. copie ce fichier dans /userdata/roms/ports/  (réseau \\BATOCERA\share\roms\ports, FTP ou clé USB)
#   2. Menu > Mettre à jour la liste des jeux, puis lance « NXE360 - Installation » dans Ports
# Pose deux petits lanceurs qui appellent les scripts du thème actif (ils se mettent à jour avec le thème).
# Le détail de l'installation s'affiche à l'écran (fenêtre puis notifications d'EmulationStation).
U="${NXE360_USERDATA:-/userdata}"                 # (variable de test uniquement)
ES="$U/system/configs/emulationstation/es_settings.cfg"
API=http://127.0.0.1:1234
setting() { grep -o "name=\"$1\" value=\"[^\"]*\"" "$ES" 2>/dev/null | sed 's/.*value="//;s/"$//'; }
notify() { curl -s -m 3 -X POST --data-binary "$1" "$API/notify" >/dev/null 2>&1; }
# Pendant un port, EmulationStation est caché derrière l'écran de lancement : ce qu'on lui envoie serait perdu.
# wait_es attend donc le retour dans EmulationStation (plus aucun jeu en cours), au plus 60 secondes.
wait_es() {
    local i
    for i in $(seq 60); do
        [ "$(curl -s -m 2 -o /dev/null -w "%{http_code}" "$API/runningGame")" = 201 ] && break
        sleep 1
    done
    sleep 2
}
# fenêtre d'erreur : affichée en arrière-plan, une fois revenu dans EmulationStation (et écrite pour un lancement en SSH)
msgbox() {
    echo "$1"
    export -f wait_es; export API MSG="$1"
    setsid bash -c 'wait_es; curl -s -m 3 -X POST --data-binary "$MSG" "$API/messagebox"' </dev/null >/dev/null 2>&1 &
}
case "$(setting Language)" in fr*) FR=1 ;; *) FR= ;; esac
t() { [ -n "$FR" ] && printf '%s' "$1" || printf '%s' "$2"; }   # texte français / anglais

active=$(setting ThemeSet)
T="$U/themes/$active"
[ -n "$active" ] && [ -f "$T/nxe360_recent.sh" ] || T=$(dirname "$(ls "$U"/themes/*/nxe360_recent.sh 2>/dev/null | head -1)")
if [ ! -f "$T/nxe360_recent.sh" ]; then
    msgbox "$(t "NXE360 : thème introuvable.

Installe d'abord le thème NXE360 :
Menu > Mises à jour et téléchargements > Thèmes." "NXE360: theme not found.

Install the NXE360 theme first:
Menu > Updates & downloads > Themes.")"
    exit 1
fi
if [ "${active,,}" != "$(basename "$T" | tr 'A-Z' 'a-z')" ]; then
    msgbox "$(t "NXE360 n'est pas le thème actif.

1. Réglages de l'interface > Thème > NXE360
2. Relance « NXE360 - Installation » dans Ports." "NXE360 is not the active theme.

1. UI settings > Theme > NXE360
2. Launch « NXE360 - Installation » from Ports again.")"
    exit 1
fi

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

# La suite tourne en arrière-plan : elle attend le retour dans EmulationStation, puis affiche la fenêtre et l'avancement.
echo "$MSG"
export -f wait_es
export MSG API U
export N1="$(t "NXE360 : préparation du thème..." "NXE360: preparing the theme...")"
export N2="$(t "NXE360 : prêt, rechargement du thème" "NXE360: ready, reloading the theme")"
setsid bash -c '
    wait_es
    curl -s -m 3 -X POST --data-binary "$MSG" "$API/messagebox"
    curl -s -m 3 -X POST --data-binary "$N1" "$API/notify"
    bash "$U/system/scripts/nxe360_recent.sh" refresh
    curl -s -m 3 -X POST --data-binary "$N2" "$API/notify"
    sleep 3
    curl -s -m 5 "$API/reloadgames"
' </dev/null >/dev/null 2>&1 &
exit 0
