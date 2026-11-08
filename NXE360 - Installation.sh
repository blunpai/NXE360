#!/bin/bash
# NXE360 - Installation des scripts du thème (une seule fois)
#   1. copie ce fichier dans /userdata/roms/ports/  (réseau \\BATOCERA\share\roms\ports, FTP ou clé USB)
#   2. Menu > Mettre à jour la liste des jeux, puis lance « NXE360 - Installation » dans Ports
# Pose deux petits lanceurs qui appellent les scripts du thème actif (ils se mettent à jour avec le thème).
U="${NXE360_USERDATA:-/userdata}"                 # (variable de test uniquement)
ES="$U/system/configs/emulationstation/es_settings.cfg"
notify() { curl -s -m 3 -X POST --data-binary "$1" http://127.0.0.1:1234/notify >/dev/null 2>&1; }

active=$(grep -o 'name="ThemeSet" value="[^"]*"' "$ES" 2>/dev/null | sed 's/.*value="//;s/"$//')
T="$U/themes/$active"
[ -n "$active" ] && [ -f "$T/nxe360_recent.sh" ] || T=$(dirname "$(ls "$U"/themes/*/nxe360_recent.sh 2>/dev/null | head -1)")
if [ ! -f "$T/nxe360_recent.sh" ]; then
    notify "NXE360 : thème introuvable. Installe d'abord le thème NXE360."
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
mkdir -p "$U/system/scripts" "$U/roms/ports"
stub nxe360_recent.sh > "$U/system/scripts/nxe360_recent.sh" && chmod +x "$U/system/scripts/nxe360_recent.sh"
[ -f "$T/360sona.sh" ] && stub 360sona.sh > "$U/roms/ports/360sona.sh" && chmod +x "$U/roms/ports/360sona.sh"

# première préparation en arrière-plan (derniers jeux, escalier, file de jaquettes...) puis liste des jeux rechargée
setsid bash -c "bash '$U/system/scripts/nxe360_recent.sh' refresh; sleep 2; curl -s -m 5 http://127.0.0.1:1234/reloadgames" </dev/null >/dev/null 2>&1 &
notify "NXE360 installé. Le thème se prépare (1 à 2 minutes), puis se recharge tout seul."
exit 0
