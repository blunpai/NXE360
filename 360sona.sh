#!/bin/bash
# Tout le script est dans main() : bash le lit en entier AVANT de l'exécuter,
# donc remplacer ce fichier pendant qu'il tourne ne provoque plus d'erreur.
main() {
# Ports Batocera : TOUT EN UN SEUL FICHIER
#   1) ouvre 360sona.com -> crée ton avatar, puis START + SELECT ensemble (ou F9) : le .glb est exporté et le
#      navigateur se ferme tout seul (l'export à la main puis Alt+F4 marche toujours)
#   2) convertit le .glb en GIF animé transparent EN LOCAL (avec support des animations universelles)
#   Manette (fichier 360sona.sh.keys) : stick gauche = souris, A = clic, B = clic droit, X = Entrée, Y = Échap,
#   croix = flèches, L1/R1 = page haut/bas, HOTKEY + B = quitter sans exporter.
#   3) écrit export.gif + export.png dans le thème, dans art/avatar/
URL1="https://360sona.com/"
APP="org.chromium.Chromium"
DL_DIRS=(/userdata/saves/flatpak/data/Downloads /userdata/system)   # dossiers où chercher le .glb exporté
THEME_ROOT="$(dirname "$(readlink -f "$0")")"   # ce script est livré dans le dossier du thème
[ -f "$THEME_ROOT/theme.xml" ] || THEME_ROOT="/userdata/themes/NXE360"
THEME_ART="$THEME_ROOT/art/avatar"
SUB_DIR="$THEME_ROOT/subsets/avatar"
MAXSLOTS=8                 # nombre d'avatars enregistrés (Avatar 1 à Avatar 8)
MAXANIM=26                 # nombre d'animations prévues dans le thème (Animation 1 à 26)
WORK="/userdata/saves/glb2gif_work"
PORT=8765
LOG="/userdata/360sona_log.txt"
exec > "$LOG" 2>&1
echo "== $(date)"
MARK=$(mktemp); touch "$MARK"
SPID=""; PAD_PID=""; WATCH_PID=""; EXPORT_JS=""; EXPORT_PY=""
# Nettoyage garanti à la sortie (fin normale, erreur ou interruption) : serveur et navigateur arrêtés, fichiers temporaires supprimés
cleanup() {
  [ -n "$SPID" ] && kill "$SPID" 2>/dev/null
  [ -n "$PAD_PID$WATCH_PID" ] && kill $PAD_PID $WATCH_PID 2>/dev/null   # lecture manette + guet du .glb
  flatpak kill "$APP" 2>/dev/null
  rm -f "$MARK" "$EXPORT_JS" "$EXPORT_PY"
  [ -n "$WORK" ] && rm -rf "$WORK"
}
trap cleanup EXIT

# Dossier des avatars
mkdir -p "$THEME_ART" "$SUB_DIR"

# Fichiers de subset « avatar » et « animation » (réécrits à chaque lancement)
make_subset() {   # $1 = nom du fichier xml, $2 = variable, $3 = valeur
  cat > "$SUB_DIR/$1.xml" << XML
<theme>
    <formatVersion>7</formatVersion>
    <variables>
        <$2>$3</$2>
    </variables>
</theme>
XML
}
make_subset export avatarSlot export
make_subset default avatarSlot default
for i in $(seq 1 $MAXSLOTS); do make_subset "slot_$i" avatarSlot "slot_$i"; done
make_subset anim_00 avatarAnim _a00
for i in $(seq 1 $MAXANIM); do n=$(printf '%02d' "$i"); make_subset "anim_$n" avatarAnim "_a$n"; done

if ! flatpak info "$APP" >/dev/null 2>&1; then
  REMOTE=$(flatpak remotes --columns=name 2>/dev/null | head -1)
  echo "Installation de $APP depuis '$REMOTE' (patiente quelques minutes)..."
  flatpak install -y --system "$REMOTE" "$APP" || { echo "ECHEC installation"; sleep 5; exit 1; }
fi

# --- Étape 1 : 360sona ---
# Export direct à la manette : START + SELECT appuyés ensemble (ou la touche F9) exportent le modèle 3D sans passer
# par le bouton d'export (le cube). Le script lit lui-même la manette, puis demande à Chromium, par son port de
# pilotage local, de cliquer les boutons à ta place. (Chromium récent refuse les extensions en ligne de commande.)
DBG_PORT=9223
EXPORT_JS="$(mktemp)"; EXPORT_PY="$(mktemp)"
cat > "$EXPORT_JS" <<'JS'
// NXE360 : clique le bouton d'export 3D (le cube) puis « Export », et affiche un message vert en bas de l'écran.
(async () => {
  if (window.__nxeBusy) return;
  window.__nxeBusy = true;
  // texte du bouton ; pour un bouton-icône (le cube « Export a 3D model »), son nom caché ou son infobulle
  const txt = (e) => (e.innerText || e.textContent || e.getAttribute('aria-label') || e.getAttribute('title')
    || e.getAttribute('data-tooltip') || e.getAttribute('data-title') || '').trim().replace(/\s+/g, ' ');
  const visible = (e) => { const r = e.getBoundingClientRect(); return r.width > 0 && r.height > 0 && getComputedStyle(e).visibility !== 'hidden'; };
  const BTN = 'button, [role="button"], input[type="button"], input[type="submit"]';
  // élément visible dont le texte correspond ; le texte le plus court gagne (le bouton, pas son conteneur)
  const find = (re, sel) => [...document.querySelectorAll(sel)]
    .filter((e) => visible(e) && re.test(txt(e) || e.value || '')).sort((a, b) => txt(a).length - txt(b).length)[0];
  const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
  const say = (m) => {
    let box = document.getElementById('nxe360-msg');
    if (!box) {
      box = document.createElement('div'); box.id = 'nxe360-msg';
      box.style.cssText = 'position:fixed;left:50%;bottom:8%;transform:translateX(-50%);z-index:2147483647;' +
        'background:#107C10;color:#fff;font:600 22px sans-serif;padding:14px 26px;border-radius:8px;pointer-events:none';
      document.documentElement.appendChild(box);
    }
    box.textContent = m; box.style.display = 'block';
    clearTimeout(window.__nxeT); window.__nxeT = setTimeout(() => { box.style.display = 'none'; }, 6000);
  };
  try {
    say('Export du modèle 3D...');
    const FINAL = /^export$/i, OPEN = /export.{0,12}3d|3d model|mod[eè]le 3d/i;
    let go = find(FINAL, BTN);                     // un vrai bouton, pas un simple titre « Export »
    if (!go) {                                     // panneau d'export fermé : on l'ouvre d'abord (le cube)
      const open = find(OPEN, BTN + ', [role="tab"], a, summary, label, li, div, span');
      if (!open) { say('Bouton d\'export introuvable : exporte à la main'); return; }
      open.click();
      for (let i = 0; i < 30 && !(go = find(FINAL, BTN)); i++) await sleep(100);
    }
    if (!go) { say('Bouton « Export » introuvable : exporte à la main'); return; }
    // réglages du panneau (bouton, case à cocher ou liste déroulante selon le site) :
    //   For = Blender, Props = In the hand (sinon l'objet tenu est aussi posé à côté de l'avatar, sans texture),
    //   Animations = toutes (Select all)
    const pick = async (re) => {
      const opt = [...document.querySelectorAll('select option')].find((o) => re.test(txt(o)));
      if (opt) {
        opt.parentElement.value = opt.value;
        opt.parentElement.dispatchEvent(new Event('change', { bubbles: true }));
      } else {
        const e = find(re, BTN + ', [role="radio"], [role="option"], [role="tab"], label, li, span, div');
        if (e) e.click();
      }
      await sleep(200);                            // le panneau peut se redessiner après un choix
    };
    await pick(/^blender$/i);
    await pick(/^in the hand$/i);
    await pick(/^select all$/i);                   // toutes les animations (sinon l'avatar ne fait que tourner sur lui-même)
    go = find(FINAL, BTN) || go;                   // le panneau peut se redessiner après le choix
    go.click();
    say('Modèle exporté : la conversion démarre...');
  } finally { window.__nxeBusy = false; }
})();
JS
cat > "$EXPORT_PY" <<'PY'
# NXE360 : START + SELECT sur une manette, ou F9 au clavier -> lance export.js dans la page 360sona de Chromium.
import base64, json, os, select, socket, struct, sys, time, urllib.request
PORT, JS = int(sys.argv[1]), open(sys.argv[2]).read()

def page_ws():
    """Adresse de pilotage de l'onglet 360sona (None si Chromium n'est pas prêt)."""
    try:
        direct = urllib.request.build_opener(urllib.request.ProxyHandler({}))      # jamais par un proxy
        tabs = json.load(direct.open(f"http://127.0.0.1:{PORT}/json", timeout=2))
    except Exception:
        return None
    tabs = [t for t in tabs if t.get("type") == "page" and t.get("webSocketDebuggerUrl")]
    for t in tabs:
        if "360sona" in t.get("url", ""):
            return t["webSocketDebuggerUrl"]
    return tabs[0]["webSocketDebuggerUrl"] if tabs else None

def run_js(ws_url):
    """Un seul message WebSocket (Runtime.evaluate) ; pas de bibliothèque WebSocket sur Batocera."""
    host, path = ws_url[len("ws://"):].split("/", 1)
    name, port = host.split(":")
    s = socket.create_connection((name, int(port)), timeout=5)
    key = base64.b64encode(os.urandom(16)).decode()
    s.sendall((f"GET /{path} HTTP/1.1\r\nHost: {host}\r\nUpgrade: websocket\r\nConnection: Upgrade\r\n"
               f"Sec-WebSocket-Key: {key}\r\nSec-WebSocket-Version: 13\r\n\r\n").encode())
    if b" 101 " not in s.recv(4096):
        raise OSError("poignée de main WebSocket refusée")
    data = json.dumps({"id": 1, "method": "Runtime.evaluate", "params": {"expression": JS}}).encode()
    mask = os.urandom(4)
    n = len(data)
    head = b"\x81" + (bytes([0x80 | n]) if n < 126 else b"\xfe" + struct.pack(">H", n) if n < 65536
                      else b"\xff" + struct.pack(">Q", n))
    s.sendall(head + mask + bytes(b ^ mask[i % 4] for i, b in enumerate(data)))
    s.settimeout(3)
    try:
        s.recv(4096)                                # la réponse (on attend juste qu'elle soit partie)
    except OSError:
        pass
    s.close()

def export():
    ws = page_ws()
    if not ws:
        print("export : Chromium injoignable", flush=True); return
    try:
        run_js(ws); print("export : demandé à la page", flush=True)
    except Exception as e:
        print("export : échec", repr(e), flush=True)

if os.environ.get("NXE360_TEST_EXPORT"):            # (test uniquement : pas de manette, un seul export)
    export(); sys.exit(0)

try:
    import evdev
    from evdev import ecodes as E
except Exception as e:
    print("lecture manette impossible (python-evdev absent) :", repr(e), flush=True); sys.exit(0)

devs, held, fired, scan, seen_browser = {}, {}, False, 0.0, False
while True:
    now = time.time()
    if now - scan > 3:                              # manettes/claviers branchés en cours de route + fin du navigateur
        scan = now
        alive = page_ws() is not None
        seen_browser = seen_browser or alive
        if seen_browser and not alive:
            break                                   # navigateur fermé : terminé
        for p in evdev.list_devices():
            if p not in devs:
                try:
                    d = evdev.InputDevice(p)
                    keys = d.capabilities().get(E.EV_KEY, [])
                    if (E.BTN_START in keys and E.BTN_SELECT in keys) or E.KEY_F9 in keys:
                        devs[p], held[p] = d, set()
                    else:
                        d.close()
                except Exception:
                    pass
    try:
        ready, _, _ = select.select(list(devs.values()), [], [], 0.2)
    except Exception:
        ready = []
    for d in ready:
        try:
            for ev in d.read():
                if ev.type != E.EV_KEY:
                    continue
                if ev.code == E.KEY_F9 and ev.value == 1:
                    export()
                (held[d.path].add if ev.value else held[d.path].discard)(ev.code)
        except BlockingIOError:                     # rien à lire finalement
            pass
        except Exception:                           # manette débranchée
            devs.pop(d.path, None); held.pop(d.path, None)
    combo = any(E.BTN_START in h and E.BTN_SELECT in h for h in held.values())
    if combo and not fired:                         # dès que les deux boutons sont enfoncés ; une fois par appui
        export()
    fired = combo
PY

# Le port de pilotage n'est accepté par Chromium qu'avec un profil à part : il est créé une fois, en copie du profil
# habituel (tes avatars enregistrés sur 360sona et ta connexion y sont repris).
PROFILE=""
for d in "$HOME/.var/app/$APP/config/chromium" "/userdata/saves/flatpak/data/.var/app/$APP/config/chromium"; do
  if [ -d "$d" ]; then
    PROFILE="${d}-nxe360"
    if [ ! -d "$PROFILE" ]; then                  # copie complète ou rien : jamais de profil à moitié copié
      rm -rf "$PROFILE.tmp"
      cp -a "$d" "$PROFILE.tmp" && rm -f "$PROFILE.tmp"/Singleton* && mv "$PROFILE.tmp" "$PROFILE" || rm -rf "$PROFILE.tmp"
    fi
    break
  fi
done
[ -n "$PROFILE" ] || PROFILE="${DL_DIRS[0]}/.nxe360_profile"
python3 "$EXPORT_PY" "$DBG_PORT" "$EXPORT_JS" &
PAD_PID=$!

# Dès qu'un .glb complet arrive dans Téléchargements, on ferme le navigateur : la conversion démarre toute seule.
(
  last=""
  while sleep 1; do
    f=$(find "${DL_DIRS[@]}" -type f -iname '*.glb' -path '*ownload*' -newer "$MARK" 2>/dev/null | head -1)
    [ -n "$f" ] || continue
    sz=$(stat -c %s "$f" 2>/dev/null)
    if [ -n "$sz" ] && [ "$sz" = "$last" ] && [ "$sz" -gt 0 ]; then     # taille stable = téléchargement fini
      sleep 1; flatpak kill "$APP" 2>/dev/null; break
    fi
    last=$sz
  done
) &
WATCH_PID=$!

# --hide-crash-restore-bubble : le navigateur est fermé d'office après l'export, sans ça il proposerait au lancement
# suivant de « restaurer les pages »
CHROME_ARGS=(--kiosk --no-sandbox --hide-crash-restore-bubble --remote-debugging-port=$DBG_PORT --user-data-dir="$PROFILE")
OZONE=wayland
flatpak run "$APP" "${CHROME_ARGS[@]}" --ozone-platform=$OZONE "$URL1"
if [ $? -ne 0 ] && [ -z "$(find "${DL_DIRS[@]}" -type f -iname '*.glb' -path '*ownload*' -newer "$MARK" 2>/dev/null | head -1)" ]; then
  echo "Wayland a échoué, essai en X11..."
  OZONE=x11
  flatpak run "$APP" "${CHROME_ARGS[@]}" --ozone-platform=$OZONE "$URL1"
fi
kill $WATCH_PID $PAD_PID 2>/dev/null; WATCH_PID=""; PAD_PID=""
rm -f "$EXPORT_JS" "$EXPORT_PY"

GLB=$(find "${DL_DIRS[@]}" -type f -iname '*.glb' -path '*ownload*' -newer "$MARK" -printf '%T@ %p\n' 2>/dev/null \
      | sort -n | tail -1 | cut -d' ' -f2-)
rm -f "$MARK"
if [ -z "$GLB" ]; then
  echo "Aucun .glb téléchargé : fin (rien à convertir)."
  exit 0
fi
echo "GLB trouvé : $GLB ($(du -h "$GLB" | cut -f1), modifié le $(date -r "$GLB" '+%d/%m %H:%M:%S'))   [avec toutes les animations : ~4-5 Mo ; sans animation : bien moins]"
echo "Autres .glb présents : $(find "${DL_DIRS[@]}" -type f -iname '*.glb' -path '*ownload*' 2>/dev/null | wc -l)"

# --- Étape 2 : conversion locale ---
rm -f "$THEME_ART"/export_a*.gif "$THEME_ART/export.png"   # pas de restes d'un ancien avatar
rm -rf "$WORK"; mkdir -p "$WORK"
cp "$GLB" "$WORK/model.glb"
# Si un fichier d'animations universelles maître existe, on le copie dans le dossier de travail
[ -f "$THEME_ART/master_animations.glb" ] && cp "$THEME_ART/master_animations.glb" "$WORK/master_animations.glb"

cat > "$WORK/server.py" << 'PYEOF'
import http.server, sys, os, urllib.parse, time, re
WORK, ART, PORT = sys.argv[1], sys.argv[2], int(sys.argv[3])
done = {"fin": False, "err": False}
class H(http.server.SimpleHTTPRequestHandler):
    def log_message(self, *a): pass
    def do_POST(self):
        q = urllib.parse.urlparse(self.path)
        n = int(self.headers.get("Content-Length", 0))
        body = self.rfile.read(n)
        if q.path == "/upload":
            name = urllib.parse.parse_qs(q.query).get("name", [""])[0]
            if re.fullmatch(r"(export(_a[0-9]{2})?\.(gif|png)|master_animations\.glb)", name):
                os.makedirs(ART, exist_ok=True)
                dst = os.path.join(ART, name)
                with open(dst + ".tmp", "wb") as f:      # nouveau fichier puis remplacement : les copies (liens durs) des anciens emplacements restent intactes
                    f.write(body)
                os.replace(dst + ".tmp", dst)
                print("Reçu", name, len(body), "octets", flush=True)
        elif q.path == "/done":
            done["fin"] = True
        elif q.path == "/log":
            print(body.decode(errors="replace"), flush=True)
        elif q.path == "/error":
            print("ERREUR dans la page :", body.decode(errors="replace"), flush=True)
            done["err"] = True
        self.send_response(200)
        self.send_header("Content-Length", "0")
        self.end_headers()
os.chdir(WORK)
httpd = http.server.HTTPServer(("127.0.0.1", PORT), H)
httpd.timeout = 1
t0 = time.time()
while not (done["fin"] or done["err"]) and time.time() - t0 < 3600:
    httpd.handle_request()
print("Serveur terminé", flush=True)
sys.exit(0 if done["fin"] else 1)   # code de sortie = conversion réussie ou non (lu par le script shell)
PYEOF

cat > "$WORK/index.html" << 'HTMLEOF'
<!doctype html>
<meta charset="utf-8">
<title>GLB vers GIF</title>
<body style="margin:0;background:#222;color:#fff;font:24px sans-serif;display:flex;align-items:center;justify-content:center;height:100vh">
<div id="msg">Chargement…</div>
<script type="importmap">
{"imports":{"three":"https://cdn.jsdelivr.net/npm/three@0.160.0/build/three.module.js","three/addons/":"https://cdn.jsdelivr.net/npm/three@0.160.0/examples/jsm/"}}
</script>
<script type="module">
import * as THREE from 'three';
import { GLTFLoader } from 'three/addons/loaders/GLTFLoader.js';
import * as SkeletonUtils from 'three/addons/utils/SkeletonUtils.js';
import { GIFEncoder, quantize } from 'https://cdn.jsdelivr.net/npm/gifenc@1.0.3/dist/gifenc.esm.js';

// --- Réglages de rendu (tous modifiables ici) ---
const TARGET_FPS = 20;      // images/s visées
const MIN_FPS = 20;         // images/s minimum (plancher)
const SS = 3;               // sur-échantillonnage : on rend en 3x puis on réduit -> contours beaucoup plus propres
const MAX_FRAMES = 900;     // nombre maximum d'images par GIF
const RES_MAX = 1600;       // résolution maximale d'un GIF (px)
const PROP_COVER = 0.96;    // prop : le cadre contient au moins 96 % des images (un objet qui s'envole brièvement ne doit pas rendre l'avatar minuscule ; 1.0 = tout contenir)
const PROP_MAX_GROW = 1.5;  // prop : cadre au plus PROP_MAX_GROW x le cadre commun -> l'avatar garde au moins 1/1.5 de sa taille normale, posé sur l'ombre (ce qui dépasse est coupé ; 1.0 = comme les autres animations)
const FRAME_F = 1.5;        // le cadre est 1.5x plus large que l'avatar seul (zone d'affichage du thème : maxSize 0.45 0.75)
const MAX_GROW = 1.0;       // cadre commun maximum = MAX_GROW x cadre de la 1re animation (1.0 = avatar à la taille d'origine ; 1.2 = 17 % plus petit mais moins de risque de coupe)
const PIX_BUDGET = 200e6;   // images x pixels par GIF (~800 Mo décodés) : ES limite la mémoire vidéo à 1 Go, au-delà l'animation scintille en gris
const CLIP_SLOW = 1.0;      // 1.0 = vitesse d'origine
const LOOP_MS = 2500;       // durée de la rotation de secours (avatar sans animation)
const SUPERSAMPLE = 1.0;
const AVATAR_H = 0.50, AVATAR_W = 0.30;   // part de l'écran occupée par l'avatar (sert à choisir la résolution du GIF)
const q = new URLSearchParams(location.search);
const RAM_MB = +q.get('ram') || 4096;
const CORES = +q.get('cores') || navigator.hardwareConcurrency || 4;
let GPU = 'inconnu', SOFT = false, MAXTEX = 4096;   
try {
  const g = document.createElement('canvas').getContext('webgl');
  const e = g.getExtension('WEBGL_debug_renderer_info');
  GPU = e ? g.getParameter(e.UNMASKED_RENDERER_WEBGL) : g.getParameter(g.RENDERER);
  SOFT = /swiftshader|llvmpipe|softpipe|software/i.test(GPU);
  MAXTEX = Math.min(g.getParameter(g.MAX_TEXTURE_SIZE), g.getParameter(g.MAX_RENDERBUFFER_SIZE));
} catch (e) { SOFT = true; }
const dpr = window.devicePixelRatio || 1;
const SYS_W = +q.get('w') || 0, SYS_H = +q.get('h') || 0;   
const SW = SYS_W || screen.width * dpr, SH = SYS_H || screen.height * dpr;
const target = Math.min(AVATAR_H * SH, AVATAR_W * SW) * SUPERSAMPLE;
let S = Math.min(RES_MAX, Math.max(256, Math.ceil(target * 1.5 / 64) * 64));
const N = 100;
fetch('/log', { method: 'POST', body: 'GIF ' + S + 'x' + S + ' à ' + TARGET_FPS + ' images/s (palette globale, délais exacts)\n  GPU : ' + GPU + (SOFT ? '  <<< RENDU LOGICIEL (processeur) : export très lent !' : '  (accélération matérielle OK)') + ' | texture max ' + MAXTEX + ' px (rendu max possible : ' + Math.floor(MAXTEX / SS) + ' px avec SS ' + SS + ')' });

// Palette GLOBALE (une seule pour toute l'animation = plus de scintillement de couleurs)
// 255 couleurs + 1 index réservé à la transparence (alpha < 128)
function buildPalette(frames) {
  let total = 0;
  for (const d of frames) total += d.length / 4;
  const step = Math.max(1, Math.floor(total / 400000));   // échantillonnage
  const buf = new Uint8Array(Math.ceil(total / step) * 4 + 4);
  let m = 0, k = 0;
  for (const d of frames) {
    for (let i = 0; i < d.length; i += 4) {
      if (d[i + 3] >= 128 && (k++ % step) === 0) {
        buf[m++] = d[i]; buf[m++] = d[i + 1]; buf[m++] = d[i + 2]; buf[m++] = 255;
      }
    }
  }
  const pal = m ? quantize(buf.subarray(0, m), 255, { format: 'rgb565' }) : [[0, 0, 0]];
  while (pal.length < 255) pal.push([0, 0, 0]);
  pal.push([0, 0, 0]);          // index 255 = transparent
  return pal;
}
// Table de correspondance couleur (rgb565) -> index de palette, construite une fois par animation (et pas par image).
// Seuls les pixels visibles sont traités ; index 255 = transparent (jamais attribué à une vraie couleur).
function makeLut() { return new Int16Array(65536).fill(-1); }
function toIndex(data, pal, lut) {
  const n = data.length / 4;
  const index = new Uint8Array(n).fill(255);
  for (let i = 0; i < n; i++) {
    const o = i * 4;
    if (data[o + 3] < 128) continue;
    const r = data[o], g = data[o + 1], b = data[o + 2];
    const key = ((r & 0xF8) << 8) | ((g & 0xFC) << 3) | (b >> 3);
    let v = lut[key];
    if (v < 0) {
      let best = 1e9; v = 0;
      for (let k = 0; k < 255; k++) {
        const dr = r - pal[k][0], dg = g - pal[k][1], db = b - pal[k][2];
        const dd = dr * dr + dg * dg + db * db;
        if (dd < best) { best = dd; v = k; }
      }
      lut[key] = v;
    }
    index[i] = v;
  }
  return index;
}
// Contour lisse : un GIF n'a que "transparent / opaque". On floute légèrement le masque (alpha) puis on le recoupe à 50 % :
// les marches d'escalier du contour deviennent des courbes lisses (position du bord inchangée).
// Les pixels qui deviennent opaques (trous minuscules rebouchés) reprennent la couleur de leurs voisins opaques (pas de liseré noir).
const EDGE_SMOOTH = true;
function smoothAlpha(d, w) {
  const n = w * w;
  if (!smoothAlpha.a || smoothAlpha.a.length !== n) { smoothAlpha.a = new Uint8Array(n); smoothAlpha.t = new Uint8Array(n); smoothAlpha.b = new Uint8Array(n); }
  const a = smoothAlpha.a, t = smoothAlpha.t, b = smoothAlpha.b;
  // rectangle qui contient l'avatar (le reste est transparent : rien à faire)
  let bx0 = w, bx1 = -1, by0 = w, by1 = -1;
  for (let y = 0; y < w; y++) for (let x = 0, i = y * w; x < w; x++, i++) {
    const v = d[i * 4 + 3]; a[i] = v;
    if (v) { if (x < bx0) bx0 = x; if (x > bx1) bx1 = x; if (y < by0) by0 = y; if (y > by1) by1 = y; }
  }
  if (bx1 < 0) return;
  const cl = (v) => Math.max(0, Math.min(w - 1, v));
  const rx0 = cl(bx0 - 2), rx1 = cl(bx1 + 2), ry0 = cl(by0 - 2), ry1 = cl(by1 + 2);   // zone de calcul
  const qx0 = cl(bx0 - 1), qx1 = cl(bx1 + 1), qy0 = cl(by0 - 1), qy1 = cl(by1 + 1);   // zone modifiée
  for (let y = ry0; y <= ry1; y++) for (let x = rx0; x <= rx1; x++) {
    const i = y * w + x, l = x > 0 ? a[i - 1] : a[i], r = x < w - 1 ? a[i + 1] : a[i];
    t[i] = (l + 2 * a[i] + r) >> 2;
  }
  for (let y = qy0; y <= qy1; y++) for (let x = qx0; x <= qx1; x++) {
    const i = y * w + x, u = y > 0 ? t[i - w] : t[i], v = y < w - 1 ? t[i + w] : t[i];
    b[i] = (u + 2 * t[i] + v) >> 2;
  }
  for (let y = qy0; y <= qy1; y++) for (let x = qx0; x <= qx1; x++) {
    const i = y * w + x, was = a[i] >= 128, now = b[i] >= 128;
    if (now && !was) {
      let r = 0, g = 0, bl = 0, c = 0;
      for (let dy = -1; dy <= 1; dy++) for (let dx = -1; dx <= 1; dx++) {
        const xx = x + dx, yy = y + dy;
        if (xx < 0 || yy < 0 || xx >= w || yy >= w) continue;
        const j = yy * w + xx;
        if (a[j] >= 128) { r += d[j * 4]; g += d[j * 4 + 1]; bl += d[j * 4 + 2]; c++; }
      }
      if (c) { d[i * 4] = r / c; d[i * 4 + 1] = g / c; d[i * 4 + 2] = bl / c; }
    }
    d[i * 4 + 3] = now ? 255 : 0;
  }
}
// Délais GIF en centièmes de seconde : on répartit les arrondis pour garder la vitesse exacte
function delaysFor(n, totalMs) {
  const out = []; let prev = 0;
  for (let i = 1; i <= n; i++) {
    const cs = Math.round(totalMs * i / n / 10);
    out.push(Math.max(2, cs - prev) * 10); prev = cs;
  }
  return out;
}
// Rend l'image complète W x W à partir de la seule zone rendue (le reste est transparent) : le rendu ne calcule que la zone où se trouve l'avatar.
function place(sub, ox, oy, ow, oh, W) {
  if (ox === 0 && oy === 0 && ow === W && oh === W) return sub;
  const full = new Uint8ClampedArray(W * W * 4);
  for (let y = 0; y < oh; y++) full.set(sub.subarray(y * ow * 4, (y + 1) * ow * 4), ((oy + y) * W + ox) * 4);
  return full;
}
// ---- Encodage EN PARALLÈLE : lissage des contours + palette + GIF se font dans des « workers » (autres cœurs) pendant que
// le GPU rend l'animation suivante. Résultat strictement identique, simplement sans temps mort. Repli automatique sur l'ancien mode si impossible.
const POOL = (CORES >= 8 && RAM_MB >= 12000) ? 2 : 1;
let workers = null;
const waiting = new Map();   // id de travail -> { resolve, reject }
let jobSeq = 0;
const jobsDone = [];
function workerMain() {
  const jobs = new Map();
  self.onmessage = (ev) => {
    const m = ev.data;
    try {
      if (m.t === 'ping') { self.postMessage({ t: 'pong' }); return; }
      if (m.t === 'frame') {
        let j = jobs.get(m.id); if (!j) { j = { frames: [], err: null }; jobs.set(m.id, j); }
        try {
          const d = place(new Uint8ClampedArray(m.buf), m.ox, m.oy, m.ow, m.oh, m.W);
          if (m.smooth) smoothAlpha(d, m.W);
          j.frames.push(d);
        } catch (e) { j.err = String(e); }
      } else if (m.t === 'finish') {
        const j = jobs.get(m.id); jobs.delete(m.id);
        if (!j || j.err) throw new Error(j ? j.err : 'aucune image reçue');
        const frames = j.frames, pal = buildPalette(frames), lut = makeLut(), gif = GIFEncoder();
        for (let i = 0; i < frames.length; i++) {
          gif.writeFrame(toIndex(frames[i], pal, lut), m.W, m.W, i === 0
            ? { palette: pal, delay: m.delays[i], transparent: true, transparentIndex: 255, dispose: 2 }
            : { delay: m.delays[i], transparent: true, transparentIndex: 255, dispose: 2 });
        }
        gif.finish();
        const out = gif.bytes().slice();
        self.postMessage({ t: 'done', id: m.id, bytes: out }, [out.buffer]);
      }
    } catch (e) { self.postMessage({ t: 'err', id: m.id, e: String(e) }); }
  };
}
async function startWorkers() {
  try {
    const src = "import { GIFEncoder, quantize } from 'https://cdn.jsdelivr.net/npm/gifenc@1.0.3/dist/gifenc.esm.js';\n"
      + [buildPalette, makeLut, toIndex, smoothAlpha, place].map(f => f.toString()).join('\n')
      + "\n(" + workerMain.toString() + ")();";
    const url = URL.createObjectURL(new Blob([src], { type: 'text/javascript' }));
    const ws = [];
    for (let k = 0; k < POOL; k++) {
      const w = new Worker(url, { type: 'module' });
      w.onmessage = (ev) => {
        const m = ev.data, p = waiting.get(m.id);
        if (m.t === 'done' && p) { waiting.delete(m.id); p.resolve(m.bytes); }
        else if (m.t === 'err' && p) { waiting.delete(m.id); p.reject(new Error('encodage : ' + m.e)); }
      };
      ws.push(w);
    }
    await Promise.all(ws.map(w => new Promise((res, rej) => {
      const t = setTimeout(() => rej(new Error('pas de réponse')), 20000);
      w.addEventListener('message', function h(ev) { if (ev.data && ev.data.t === 'pong') { clearTimeout(t); w.removeEventListener('message', h); res(); } });
      w.onerror = (e) => { clearTimeout(t); rej(new Error(e.message || 'erreur')); };
      w.postMessage({ t: 'ping' });
    })));
    for (const w of ws) w.onerror = (e) => { for (const [, p] of waiting) p.reject(new Error('worker : ' + (e.message || 'erreur'))); waiting.clear(); };
    workers = ws;
    fetch('/log', { method: 'POST', body: 'Encodage en parallèle : ' + POOL + ' processus (rendu et encodage GIF se chevauchent)' });
  } catch (e) {
    workers = null;
    fetch('/log', { method: 'POST', body: 'Encodage en parallèle indisponible (' + e + ') : mode classique' });
  }
}
const msg = document.getElementById('msg');
try {
  // Ajout de logarithmicDepthBuffer pour éliminer le clignotement des props et textures superposées
  const renderer = new THREE.WebGLRenderer({ alpha: true, antialias: SS < 3, preserveDrawingBuffer: true, logarithmicDepthBuffer: true });
  renderer.setPixelRatio(1);
  renderer.setSize(S, S);
  renderer.setClearColor(0x000000, 0);
  const ANISO = Math.min(16, renderer.capabilities.getMaxAnisotropy());
  const scene = new THREE.Scene();
  scene.add(new THREE.HemisphereLight(0xffffff, 0x888888, 1.6));
  const dl = new THREE.DirectionalLight(0xffffff, 2.0);
  dl.position.set(2, 3, 4);
  scene.add(dl);

  msg.textContent = 'Lecture du modèle…';
  const gltf = await new GLTFLoader().loadAsync('model.glb');
  const model = gltf.scene;

  // Matériaux : un GIF n'a que de la transparence "tout ou rien". Les matériaux semi-transparents
  // (alpha blend) rendent l'avatar fantôme et scintillent (tri des faces à chaque image).
  // On les transforme en matériaux opaques "découpés" (alphaTest) : stable et plein.
  const solLog = new Set();   // diagnostic : ce que solidify() retire ou découpe
  function solidify(root) {
    const ghosts = [];
    root.traverse((c) => {
      if (!(c.isMesh || c.isSkinnedMesh) || !c.material) return;
      c.frustumCulled = false;                      // un corps animé ne doit jamais être coupé par le culling
      const mats = [].concat(c.material);
      // Ombre / sol / halo : matériau translucide SANS texture (ou nommé ainsi) = fantôme gris à faible opacité
      // Le nom seul ne suffit PAS (« Halo 4 Marine Armor » est une armure, pas un halo !) : une matière OPAQUE avec texture n'est jamais un fantôme.
      const nameGhost = /shadow|ombre|ground|floor|halo|glow/i.test(c.name + ' ' + mats.map(m => m.name).join(' '));
      const ghost = (nameGhost && mats.every(m => !m.map || m.transparent || m.opacity < 1))
        || mats.every(m => (m.transparent || m.opacity < 1) && !m.map);
      if (ghost) { ghosts.push(c); solLog.add('RETIRÉ (fantôme) : ' + (c.name || '(sans nom)') + ' [matériau ' + mats.map(m => (m.name || '?') + (m.map ? '+tex' : ' sans texture') + (m.transparent ? ' transp.' : '') + ' op.' + m.opacity.toFixed(2)).join(', ') + ']'); return; }
      for (const mt of mats) {
        // textures plus nettes vues de biais (armures, plis, reflets) : filtrage anisotrope au maximum du GPU
        for (const k of ['map', 'normalMap', 'roughnessMap', 'metalnessMap', 'emissiveMap', 'aoMap']) if (mt[k]) mt[k].anisotropy = ANISO;
        const hasMap = !!mt.map;
        if (hasMap && (mt.transparent || mt.alphaTest > 0)) solLog.add((mt.alphaTest > 0 ? 'DÉCOUPÉ (MASK) : ' : 'DÉCOUPÉ (BLEND, seuil 0.4) : ') + (c.name || '?') + ' / ' + (mt.name || '?'));
        if (!hasMap && !mt.color) solLog.add('SANS TEXTURE ni couleur : ' + (c.name || '?'));
        // IMPORTANT : on ne découpe QUE les matières réellement en transparence dans le fichier (BLEND = transparent,
        // MASK = alphaTest). Une matière OPAQUE dont l'image contient un canal alpha « parasite » ne doit surtout pas
        // être découpée (sinon des zones de texture disparaissent).
        const wasMask = mt.alphaTest > 0, wasBlend = mt.transparent;
        mt.transparent = false;
        mt.depthWrite = true;
        mt.depthTest = true;
        mt.opacity = 1;
        mt.alphaTest = (hasMap && (wasMask || wasBlend)) ? (wasMask ? mt.alphaTest : 0.4) : 0;
        mt.alphaToCoverage = false;
        mt.needsUpdate = true;
      }
    });
    for (const g of ghosts) g.parent && g.parent.remove(g);
  }
  // Diagnostic (journal seulement, ne change rien au rendu) : maillages de la tête / des yeux et leurs matériaux AVANT traitement
  try {
    const dl = [];
    model.traverse(o => {
      if (!o.isMesh || /^carryable/i.test(o.name)) return;
      const ms = [].concat(o.material || []);
      const morph = o.morphTargetDictionary ? Object.keys(o.morphTargetDictionary) : [];
      dl.push((o.name || '(sans nom)') + (o.isSkinnedMesh ? ' [skin]' : '') + ' ' + (o.geometry.attributes.position ? o.geometry.attributes.position.count : '?') + ' pts, renderOrder ' + o.renderOrder
        + ' | matériaux : ' + ms.map(m => (m.name || '?') + (m.map && m.map.image ? ' tex ' + m.map.image.width + 'x' + m.map.image.height : ' sans tex') + (m.transparent ? ' TRANSP' : '') + (m.alphaTest > 0 ? ' alphaTest ' + m.alphaTest : '') + ' op.' + m.opacity.toFixed(2) + ' face ' + m.side + (m.depthWrite === false ? ' depthWrite=off' : '')).join(' ; ')
        + (morph.length ? ' | morph targets : ' + morph.slice(0, 12).join(', ') : ''));
    });
    fetch('/log', { method: 'POST', body: 'Diagnostic visage - maillages du modèle (' + dl.length + ') :\n  ' + dl.slice(0, 40).join('\n  ') });
  } catch (e) { /* diagnostic facultatif */ }
  solidify(model);

  const pivot = new THREE.Group();
  pivot.add(model);
  scene.add(pivot);
  const box = new THREE.Box3().setFromObject(model);
  const size = box.getSize(new THREE.Vector3());
  model.position.sub(box.getCenter(new THREE.Vector3()));
  const R = Math.max(size.x, size.y, size.z);
  const cam = new THREE.PerspectiveCamera(30, 1, R / 50, R * 30);
  cam.position.set(0, 0, R * 2.2);
  cam.lookAt(0, 0, 0);

  // --- Animations universelles + props (accessoires) ---
  let clips = gltf.animations || [];
  let propSource = null;       // scène du fichier maître : on y récupère les modèles 3D des props
  let masterLoaded = false;
  let masterAnims = [];
  try {
    const masterGltf = await new GLTFLoader().loadAsync('master_animations.glb');
    propSource = masterGltf.scene;
    masterLoaded = true;
    masterAnims = masterGltf.animations || [];
    // Export SANS aucune animation : on prend les animations universelles du maître, mais JAMAIS son prop
    // (c'est celui d'un autre avatar : il serait collé sur celui-ci).
    if (!clips.length) clips = (masterGltf.animations || []).filter(c => !/^prop/i.test(c.name));
  } catch (e) { console.log('Pas de fichier maître.'); }
  const ownAnims = (gltf.animations || []).length;
  // On ne remplace le maître que par un export contenant plusieurs animations (ou s'il n'existe pas encore)
  const isProp = c => /^prop/i.test(c.name);   // l'animation d'un objet s'appelle « Prop: … » sur 360sona
  const ownUni = (gltf.animations || []).filter(c => !isProp(c)).length, masterUni = masterAnims.filter(c => !isProp(c)).length;
  // (un export partiel, ex. le prop seul, ne remplace jamais le maître : il perdrait les animations universelles)
  if ((ownAnims > 1 && ownUni >= masterUni) || (ownAnims > 0 && !masterLoaded)) {
    await fetch('/upload?name=master_animations.glb', { method: 'POST', body: await (await fetch('model.glb')).blob() });
    propSource = gltf.scene;
  }
  if (!ownAnims && clips.length) msg.textContent = 'Animations universelles chargées';
  // Numérotation stable : les animations de props (ex. « Prop: DS2 Snowboard ») passent en dernier,
  // pour que a01 = Hello there!, a02 = Applause… pour tous les avatars, avec ou sans prop.
  // Export partiel (ex. seulement le prop coché sur 360sona) : on COMPLÈTE avec les animations universelles du fichier maître,
  // pour que ce nouvel avatar ait quand même ses 25 animations + son prop. (Les props des AUTRES avatars du maître ne sont pas repris.)
  if (masterLoaded && ownAnims > 0) {
    const own = gltf.animations;
    const uni = masterAnims.filter(c => !isProp(c));
    const ownByName = new Map(own.map(c => [c.name, c]));
    const uniNames = new Set(uni.map(c => c.name));
    const completed = uni.filter(c => !ownByName.has(c.name)).length;
    clips = uni.map(c => ownByName.get(c.name) || c)
      .concat(own.filter(c => !isProp(c) && !uniNames.has(c.name)), own.filter(isProp));
    if (completed) fetch('/log', { method: 'POST', body: 'Animations complétées depuis le fichier maître : ' + completed + ' (le fichier exporté en contenait ' + ownAnims + ')' });
  }
  clips = clips.filter(c => !isProp(c)).concat(clips.filter(isProp));
  try {   // Diagnostic : l'animation pilote-t-elle des « morph targets » (clignement, expressions) ?
    const mt = [];
    for (const t of (clips[0] ? clips[0].tracks : [])) if (/morph/i.test(t.name)) mt.push(t.name + ' (' + t.times.length + ' clés, valeur au départ ' + (+t.values[0]).toFixed(2) + ')');
    fetch('/log', { method: 'POST', body: 'Diagnostic visage - pistes d\'expression de « ' + (clips[0] ? clips[0].name : '?') + ' » : ' + (mt.length ? '\n  ' + mt.slice(0, 20).join('\n  ') : 'aucune') });
  } catch (e) { /* diagnostic facultatif */ }

  const nodeNames = new Set();
  model.traverse(o => { if (o.name) nodeNames.add(o.name); });
  const findIn = (root, name) => { let r = null; root.traverse(o => { if (!r && o.name === name) r = o; }); return r; };

  // Pour une animation : trouve les noeuds animés absents de l'avatar (= props) et clone leur modèle 3D
  function attachProps(clip, added, notFound) {
    if (!propSource || propSource === gltf.scene) return;
    const wanted = new Set();
    for (const t of clip.tracks) {
      const nm = THREE.PropertyBinding.parseTrackName(t.name).nodeName;
      if (nm && !nodeNames.has(nm)) wanted.add(nm);
    }
    for (const nm of wanted) {
      if (added.some(a => findIn(a, nm))) continue;
      const src = findIn(propSource, nm);
      if (!src) { notFound.add(nm); continue; }
      // remonte jusqu'au plus haut ancêtre absent de l'avatar : on le clone en entier (groupes intermédiaires conservés)
      let top = src;
      while (top.parent && top.parent !== propSource && !nodeNames.has(top.parent.name)) top = top.parent;
      let host = model;
      if (top.parent && top.parent !== propSource && nodeNames.has(top.parent.name)) host = findIn(model, top.parent.name) || model;
      const copy = SkeletonUtils.clone(top);
      solidify(copy);
      host.add(copy);
      added.push(copy);
    }
  }
  // Props propres à l'avatar (ex. snowboard) : on les retire pour toute animation qui ne les anime pas
  const HIDE_IDLE_PROPS = true;
  const trackNodes = clips.map(c => new Set(c.tracks.map(t => THREE.PropertyBinding.parseTrackName(t.name).nodeName).filter(Boolean)));
  const animatedSomewhere = new Set();
  trackNodes.forEach(st => st.forEach(n => animatedSomewhere.add(n)));
  function hideIdle(clip) {
    const hidden = [];
    const idx = clips.indexOf(clip);
    if (!HIDE_IDLE_PROPS || idx < 0) return hidden;
    const cur = trackNodes[idx];
    const todo = [];
    model.traverse(o => {
      if (o === model || !o.name || cur.has(o.name) || !animatedSomewhere.has(o.name)) return;
      let hasMesh = false, isAvatar = false;
      o.traverse(m => {
        if (m.isMesh) hasMesh = true;
        if (m.isSkinnedMesh && m.skeleton.bones.some(b => cur.has(b.name))) isAvatar = true;
      });
      if (hasMesh && !isAvatar) todo.push(o);
    });
    // Maillages de prop « skinnés » sur leur propre petit squelette (os animés uniquement par l'animation du prop)
    // ou simples maillages dont aucun os/noeud n'est animé par cette animation alors qu'un autre l'anime.
    const meshes = [];
    model.traverse(m => {
      if (!m.isMesh || todo.some(t => t === m || t.getObjectById(m.id))) return;
      if (m.isSkinnedMesh) {
        const bn = m.skeleton.bones;
        if (bn.length && !bn.some(b => cur.has(b.name)) && bn.some(b => animatedSomewhere.has(b.name))) meshes.push(m);
      } else if (m.name && !cur.has(m.name) && animatedSomewhere.has(m.name)) meshes.push(m);
    });
    for (const o of todo.concat(meshes)) if (o.parent) { hidden.push({ o, parent: o.parent }); o.parent.remove(o); }
    return hidden;
  }
  const unhide = (hidden) => { for (const h of hidden) h.parent.add(h.o); hidden.length = 0; };
  const unattach = (added) => { for (const o of added) o.parent && o.parent.remove(o); added.length = 0; };

  // --- Cadrage AJUSTÉ À LA LIMITE, animation par animation ---
  // Pour chaque animation on mesure l'avatar (props compris) sur ~48 images et on cadre au plus juste, marge de 5 %.
  //  • mouvement faible  : caméra fixe, cadrée sur l'étendue réelle de l'animation ;
  //  • avatar qui voyage / saute haut : la caméra SUIT le bassin (lissé) et le zoom est réglé sur la taille réelle de
  //    l'avatar autour de lui -> il reste entier et le plus grand possible.
  const nFrames = (clip) => {
    const nat = Math.round(clip.duration * TARGET_FPS);               // images à la vitesse maximale
    const bud = Math.floor(PIX_BUDGET / (S * S));                     // images possibles à la résolution maximale
    const lo = Math.ceil(clip.duration * MIN_FPS);                    // plancher d'images/s
    return Math.max(12, Math.min(MAX_FRAMES, Math.max(lo, Math.min(nat, bud))));
  };
  const FOLLOW_AT = 1.5;      // déplacement du bassin (en hauteurs d'avatar) à partir duquel la caméra suit
  const SLIDE_D = 0.6;        // entrée / sortie de scène : décalage max de l'avatar dans le cadre (en hauteurs d'avatar)
  const SMOOTH = 8;           // lissage du suivi (images)
  let refHAvatar = 1;         // hauteur de l'avatar (pour les logs)
  let groundY = 0;            // hauteur du sol (pieds de l'avatar au repos)
  const GROUND_AT = 0.82;     // position verticale des pieds dans le cadre (0 = haut, 1 = bas), identique pour toutes les animations
  let camPlan = null;         // Map animation -> plan de caméra
  {
    msg.textContent = 'Mesure du cadrage…';
    const v = new THREE.Vector3(), tv = new THREE.Vector3();
    model.updateMatrixWorld(true);
    // « Le corps » = le plus gros maillage skinné. On suit le CENTRE de sa peau (120 points), pas une boîte
    // englobante ni un os : un prop, un décor ou un os qui ne bouge pas ne peuvent plus fausser le cadrage.
    const skins = [];
    model.traverse(o => { if (o.isSkinnedMesh) skins.push(o); });
    // Le corps = le maillage skinné dont les os sont animés par le plus d'animations (un vélo, une planche... ne
    // sont animés que par l'animation du prop) ; à égalité, le plus gros.
    const usedBy = (m) => trackNodes.reduce((c, st) => c + (m.skeleton.bones.some(b => st.has(b.name)) ? 1 : 0), 0);
    const score = new Map(skins.map(m => [m, usedBy(m)]));
    // LE CORPS = TOUS les maillages skinnés animés par le plus grand nombre d'animations (peau + vêtements + armure...),
    // pas un seul morceau : choisir une seule pièce (casque, botte...) donnait une « hauteur d'avatar » fausse -> cadre énorme,
    // avatar minuscule et pieds à côté de l'ombre.
    const maxScore = skins.reduce((m, x) => Math.max(m, score.get(x)), 0);
    // les pièces de prop (nommées « carryable_… » sur 360sona) ne sont jamais le corps
    let bodies = skins.filter(x => score.get(x) === maxScore && !/^carryable/i.test(x.name));
    if (!bodies.length) bodies = skins.filter(x => score.get(x) === maxScore);
    const totalV = bodies.reduce((c, m) => c + m.geometry.attributes.position.count, 0) || 1;
    const samples = [];   // 120 points répartis sur toutes les pièces du corps
    for (const m of bodies) {
      const cnt = m.geometry.attributes.position.count, k = Math.max(4, Math.round(120 * cnt / totalV));
      for (let j = 0; j < k; j++) samples.push([m, Math.floor(j * cnt / k)]);
    }
    const centroid = (out) => {
      out.set(0, 0, 0);
      if (!samples.length) return out;
      for (const m of bodies) m.skeleton.update();   // sans ça, getVertexPosition lit les os de la dernière image rendue (pose périmée)
      for (const [m, vi] of samples) { m.getVertexPosition(vi, tv); tv.applyMatrix4(m.matrixWorld); out.add(tv); }
      return out.multiplyScalar(1 / samples.length);
    };
    // taille de référence (hauteur de l'avatar au repos) = boîte de TOUT le corps
    let refH = 1;
    if (bodies.length) {
      const rb = new THREE.Box3();
      for (const m of bodies) {
        m.skeleton.update();
        const cnt = m.geometry.attributes.position.count;
        for (let k = 0; k < cnt; k += 4) { m.getVertexPosition(k, tv); tv.applyMatrix4(m.matrixWorld); rb.expandByPoint(tv); }
      }
      refH = rb.getSize(new THREE.Vector3()).y || 1;
      groundY = rb.min.y;
    } else {
      const fb = new THREE.Box3().setFromObject(model);
      refH = fb.getSize(new THREE.Vector3()).y || 1;
      groundY = fb.min.y;
    }
    refHAvatar = refH;
    fetch('/log', { method: 'POST', body: 'Corps de l\'avatar : ' + bodies.length + ' pièce(s) animée(s) par ' + maxScore + ' animation(s) : ' + bodies.map(m => (m.name || '?') + ' (' + m.geometry.attributes.position.count + ' pts)').join(', ') });
    // Cadrage large de départ (le recadrage fin se fait ensuite sur les pixels) : champ = 3.2 x la hauteur de l'avatar
    const side0 = 3.2 * refH;
    const dist0 = side0 / 2 / Math.tan(THREE.MathUtils.degToRad(cam.fov / 2)) + 0.5 * refH;
    const plans = new Map();
    const logs = [], hlogs = [];
    for (const clip of clips) {
      const hid = hideIdle(clip), added = [], nf = new Set();
      attachProps(clip, added, nf);
      const mx = new THREE.AnimationMixer(model);
      mx.clipAction(clip).reset().play();
      const n = nFrames(clip);
      const cen = new Float32Array(n * 3);
      for (let i = 0; i < n; i++) {
        mx.setTime(clip.duration * i / n);
        model.updateMatrixWorld(true);
        centroid(v);
        cen[i * 3] = v.x; cen[i * 3 + 1] = v.y; cen[i * 3 + 2] = v.z;
      }
      mx.stopAllAction(); mx.uncacheRoot(model);
      if (hid.length) hlogs.push('  objets masqués pendant « ' + clip.name + ' » : ' + hid.map(h => h.o.name || '(sans nom)').join(', '));
      unattach(added); unhide(hid);
      // centre lissé (moyenne glissante)
      const sm = new Float32Array(n * 3);
      let mean = [0, 0, 0];
      for (let i = 0; i < n; i++) {
        let c = 0, sx = 0, sy = 0, sz = 0;
        for (let j = Math.max(0, i - SMOOTH); j <= Math.min(n - 1, i + SMOOTH); j++) { sx += cen[j * 3]; sy += cen[j * 3 + 1]; sz += cen[j * 3 + 2]; c++; }
        sm[i * 3] = sx / c; sm[i * 3 + 1] = sy / c; sm[i * 3 + 2] = sz / c;
        mean[0] += cen[i * 3] / n; mean[1] += cen[i * 3 + 1] / n; mean[2] += cen[i * 3 + 2] / n;
      }
      const rmin = [1e9, 1e9, 1e9], rmax = [-1e9, -1e9, -1e9];
      for (let i = 0; i < n; i++) for (let a = 0; a < 3; a++) { rmin[a] = Math.min(rmin[a], sm[i * 3 + a]); rmax[a] = Math.max(rmax[a], sm[i * 3 + a]); }
      const travel = Math.max(rmax[0] - rmin[0], rmax[2] - rmin[2]);   // déplacement HORIZONTAL seulement : les sauts / rebonds ne font pas suivre la caméra
      const follow = travel > FOLLOW_AT * refH;
      // « Enter stage left » / « Exit stage right » : la caméra suit, mais l'avatar GLISSE dans le cadre
      // (entrée : de la bordure vers le centre ; sortie : du centre vers la bordure) -> on voit qu'il entre / sort.
      let slide = null;
      if (follow && /^(enter|exit)/i.test(clip.name)) {
        const dir = Math.sign(sm[(n - 1) * 3] - sm[0]) || 1;
        slide = { mode: /^enter/i.test(clip.name) ? 'enter' : 'exit', dir, n, D: SLIDE_D * refH };
      }
      plans.set(clip, { follow, slide, c: follow ? new THREE.Vector3(0, mean[1], 0) : new THREE.Vector3(mean[0], mean[1], mean[2]), sm, dist: dist0 });
      logs.push((travel / refH).toFixed(1) + (follow ? '*' : ''));
    }
    camPlan = plans;
    if (solLog.size) fetch('/log', { method: 'POST', body: 'Matériaux (modèle + props) :\n  ' + [...solLog].join('\n  ') });
    fetch('/log', { method: 'POST', body: 'Cadrage : hauteur avatar ' + refH.toFixed(2) + ' | déplacement horizontal du centre (en hauteurs d\'avatar) par animation : ' + logs.join(' / ') + '  (* = caméra qui suit l\'avatar)' + (hlogs.length ? '\n' + hlogs.join('\n') : '\n  aucun objet de prop à masquer') });
  }
  const aim = (clip, i) => {
    const pl = camPlan && camPlan.get(clip);
    if (!pl) return;
    const c = pl.c.clone();
    if (pl.follow) {
      let off = 0;
      if (pl.slide) {
        const sl = pl.slide, t = i / Math.max(1, sl.n - 1);
        const ss = (u) => { u = Math.min(1, Math.max(0, u)); return u * u * (3 - 2 * u); };
        off = sl.mode === 'enter' ? -sl.dir * sl.D * (1 - ss(t / 0.8)) : sl.dir * sl.D * ss((t - 0.2) / 0.8);
      }
      c.x += pl.sm[i * 3] - off; c.z += pl.sm[i * 3 + 2];
    }   // suit en horizontal ; la hauteur reste fixe (le sol ne bouge pas : plus d'effet flottant)
    cam.near = pl.dist / 100; cam.far = pl.dist * 20; cam.updateProjectionMatrix();
    cam.position.set(c.x, c.y, c.z + pl.dist);
    cam.lookAt(c.x, c.y, c.z);
  };

  const MULTI = clips.length > 1;
  let W = S, RW = S;   // W = taille du GIF, RW = taille de rendu (W x SS)
  const sizeFor = (n) => Math.max(384, Math.min(S, Math.floor(Math.sqrt(PIX_BUDGET / n) / 16) * 16));
  
  fetch('/log', { method: 'POST', body: clips.length
    ? 'Animations trouvées : ' + clips.length + ' (GIF jusqu\'à ' + W + 'x' + W + ' à ' + TARGET_FPS + ' FPS)\n  ' + clips.map((c, i) => 'Animation ' + (i + 1) + ' = ' + c.name + ' (' + c.duration.toFixed(1) + ' s, ' + Math.round(c.duration * TARGET_FPS) + ' frames)').join('\n  ')
    : 'Aucune animation dans le fichier' + (masterLoaded ? ' ET le fichier maître n\'en contient pas non plus : rotation à 360°. Refais un export sur 360sona avec TOUTES les animations' : ' ET pas de fichier maître : rotation à 360°. Refais un export sur 360sona avec TOUTES les animations (le fichier exporté ne les contenait pas)') });

  const cv = document.createElement('canvas');
  cv.width = cv.height = W;
  const ctx = cv.getContext('2d', { willReadFrequently: true });
  // Mesure PAR LES PIXELS : on rend d'abord chaque animation en petit (caméra dézoomée x1.5),
  // on relève le rectangle réellement occupé par l'avatar, puis on re-rend à la bonne taille, cadré au pixel près.
  const P1 = 384;
  const cv1 = document.createElement('canvas');
  cv1.width = cv1.height = P1;
  const ctx1 = cv1.getContext('2d', { willReadFrequently: true });
  const PAD = 1.04;           // marge autour de l'avatar (4 %)
  // k = champ mesuré en multiples du cadre de base (1.5 = valeur normale). Un prop qui sort du champ mesuré serait sous-estimé
  // (zone = tout le champ) : pour un prop, measurePixels est donc relancée avec un champ plus large tant que la zone touche un bord.
  function measurePixels(clip, mixer, n, k = 1.5) {
    renderer.setSize(P1, P1);
    let x0 = 1e9, y0 = 1e9, x1 = -1, y1 = -1, b0 = -1;   // b0 = bas de l'avatar (pixel le plus bas) à la 1re image
    const per = [], isP = isProp(clip);   // isP : étendue de chaque image (pour ignorer les images extrêmes)
    const stepM = isProp(clip) ? 1 : 3;   // prop : toutes les images mesurées (un objet rapide ne doit pas passer entre deux mesures)
    for (let i = 0; i < n; i += stepM) {
      mixer.setTime(clip.duration * i / n);
      aim(clip, i);
      cam.setViewOffset(P1, P1, -(k - 1) / 2 * P1, -(k - 1) / 2 * P1, k * P1, k * P1);
      renderer.render(scene, cam);
      ctx1.clearRect(0, 0, P1, P1);
      ctx1.drawImage(renderer.domElement, 0, 0, P1, P1, 0, 0, P1, P1);
      const d = ctx1.getImageData(0, 0, P1, P1).data;
      let a0 = 1e9, c0 = 1e9, a1 = -1, c1 = -1;
      for (let y = 0; y < P1; y++) {
        const row = y * P1 * 4;
        for (let x = 0; x < P1; x++) {
          if (d[row + x * 4 + 3] >= 128) {
            if (x < x0) x0 = x; if (x > x1) x1 = x; if (y < y0) y0 = y; if (y > y1) y1 = y;
            if (x < a0) a0 = x; if (x > a1) a1 = x; if (y < c0) c0 = y; if (y > c1) c1 = y;
            if (i === 0 && y > b0) b0 = y;
          }
        }
      }
      if (isP && a1 >= 0) per.push([a0, a1, c0, c1]);
    }
    renderer.setSize(RW, RW);
    cam.clearViewOffset();
    if (x1 < 0) return null;
    // pixels du rendu dézoomé -> coordonnées du plein cadre (P1 x P1)
    const off = -(k - 1) / 2 * P1;
    // prop : on ignore les images les plus extrêmes (PROP_COVER) : l'étendue retenue est celle de 96 % des images
    let rx0 = x0, rx1 = x1, ry0 = y0, ry1 = y1;
    if (isP && per.length >= 25 && PROP_COVER < 1) {
      const tr = Math.floor(per.length * (1 - PROP_COVER) / 2), col = j => per.map(p => p[j]).sort((a, b) => a - b);
      rx0 = col(0)[tr]; rx1 = col(1)[per.length - 1 - tr]; ry0 = col(2)[tr]; ry1 = col(3)[per.length - 1 - tr];
    }
    const touch = rx0 <= 0 || ry0 <= 0 || rx1 >= P1 - 1 || ry1 >= P1 - 1;
    const fx0 = off + rx0 * k, fx1 = off + (rx1 + 1) * k, fy0 = off + ry0 * k, fy1 = off + (ry1 + 1) * k;
    const perF = per.map(p => [off + p[0] * k, off + (p[1] + 1) * k, off + p[2] * k, off + (p[3] + 1) * k]);
    const full = { w: (x1 + 1 - x0) * k, h: (y1 + 1 - y0) * k };
    const side = Math.max(fx1 - fx0, fy1 - fy0) * PAD;
    return { x: (fx0 + fx1) / 2 - side / 2, y: (fy0 + fy1) / 2 - side / 2, side, fx0, fx1, fy0, fy1, foot0: b0 < 0 ? null : off + (b0 + 1) * k, touch, k, perF, full };
  }
  const up = (name, body, type) => fetch('/upload?name=' + name, { method: 'POST', body: new Blob([body], { type }) });

  let refSide = 0;     // cadre de référence (taille d'avatar commune à TOUTES les animations)
  const winCache = new Map();
  let groundCal = false;      // le sol est recalé UNE fois sur les vrais pixels (pieds de la 1re animation)
  const needOf = new Map();   // cadre nécessaire par animation (1re passe)
  let globalSide = 0;  // cadre commun = le plus grand cadre nécessaire parmi toutes les animations
  let live = null;   // état à remettre en ordre si une animation échoue (prop attaché, pièces masquées, mixeur)
  async function safeRender(clip, label, needOnly = false) {
    try { return await renderOne(clip, label, needOnly); }
    catch (e) {
      const l = live; live = null;
      try {
        if (l) { if (l.mixer) { l.mixer.stopAllAction(); l.mixer.uncacheRoot(model); } unattach(l.added); unhide(l.hid); }
        cam.clearViewOffset(); cam.updateProjectionMatrix();
      } catch (_) { /* nettoyage au mieux */ }
      throw e;
    }
  }
  async function renderOne(clip, label, needOnly = false) {
    let n, delays, mixer = null;
    const added = [], notFound = new Set();
    const hid = clip ? hideIdle(clip) : [];
    live = { hid, added, mixer: null };
    if (hid.length && !needOnly) fetch('/log', { method: 'POST', body: '  ' + clip.name + ' : objets masqués (non animés ici) = ' + hid.map(h => h.o.name).join(', ') });
    if (clip) {
      n = nFrames(clip);
      delays = delaysFor(n, clip.duration * 1000 * CLIP_SLOW);
      attachProps(clip, added, notFound);
      mixer = new THREE.AnimationMixer(model);     // mixeur neuf = pas de liaison périmée avec un ancien prop
      mixer.clipAction(clip).reset().play();
      live.mixer = mixer;
      if ((added.length || notFound.size) && !needOnly) fetch('/log', { method: 'POST', body: '  ' + clip.name + ' : props ajoutés = ' + (added.map(a => a.name).join(', ') || 'aucun') + (notFound.size ? ' | introuvables = ' + [...notFound].join(', ') : '') });
    } else {
      n = Math.min(N, 100);
      delays = delaysFor(n, LOOP_MS);
    }
    W = clip ? sizeFor(n) : S;
    RW = Math.min(W * SS, MAXTEX);
    renderer.setSize(RW, RW);
    cv.width = cv.height = W;
    if (clip && !needOnly) fetch('/log', { method: 'POST', body: '  ' + clip.name + ' : GIF ' + W + 'x' + W + ', ' + n + ' images (' + (n / clip.duration).toFixed(0) + ' images/s)' });
    const frames = [];
    let png = null;
    let win = null, box = null;
    if (clip) {
      msg.textContent = label + ' : mesure du cadrage…';
      // la mesure faite à la 1re passe est réutilisée à la 2e (inutile de la refaire)
      win = winCache.get(clip);
      if (!win) {
        win = measurePixels(clip, mixer, n);
        if (isProp(clip)) for (let k = 3; win && win.touch && k <= 24; k *= 2) { const w2 = measurePixels(clip, mixer, n, k); if (w2) win = w2; else break; }
        if (win) winCache.set(clip, win);
      }
      if (win) {
        // Même échelle d'avatar pour tous : cadre normal = cadre serré x FRAME_F ; prop = cadre centré sur l'avatar,
        // au moins aussi large que celui de la 1re animation (même taille d'avatar), plus large si l'objet l'exige.
        const pl = camPlan.get(clip), slidePlan = pl.slide;
        // position du sol dans le cadre de mesure (P1 x P1) : les pieds restent au même endroit dans TOUS les GIF
        const tanH = Math.tan(THREE.MathUtils.degToRad(cam.fov / 2));
        // Calage du sol sur les PIXELS : on regarde où sont réellement les pieds à la 1re image de la 1re animation normale
        // (avatar debout) et on en déduit la vraie hauteur du sol. Le modèle 3D seul se trompait de plusieurs % -> avatar à côté de l'ombre.
        if (!groundCal && !slidePlan && !isProp(clip) && win.foot0 != null) {
          const old = groundY;
          groundY = pl.c.y + (P1 / 2 - win.foot0) * (pl.dist * tanH) / (P1 / 2);
          groundCal = true;
          fetch('/log', { method: 'POST', body: 'Sol recalé sur les pieds réels (' + clip.name + ') : écart corrigé = ' + ((groundY - old) / refHAvatar * 100).toFixed(1) + ' % de la hauteur de l\'avatar' });
        }
        const gpx = P1 / 2 - ((groundY - pl.c.y) / (pl.dist * tanH)) * (P1 / 2);
        const needV = Math.max((gpx - win.fy0) / GROUND_AT, (win.fy1 - gpx) / (1 - GROUND_AT)) * PAD;
        const c0 = P1 / 2;
        const needH = 2 * Math.max(c0 - win.fx0, win.fx1 - c0) * PAD;
        // Prop : le cadre s'adapte à l'animation du prop (avatar + objet). Largeur = largeur réellement occupée (cadre décalé sur le centre
        // de la zone, plus centré sur l'axe du corps), hauteur = du sol au point le plus haut. Marge PAD seulement : rien n'est coupé.
        const needP = Math.max((win.fx1 - win.fx0) * PAD, (win.fy1 - win.fy0) / GROUND_AT * PAD);   // indépendant du « sol » : la zone occupée suffit
        if (needOnly) {
          // 1re passe : on note seulement la taille de cadre dont CETTE animation a besoin (entrée/sortie : aucune, l'avatar sort du cadre exprès)
          if (mixer) { mixer.stopAllAction(); mixer.uncacheRoot(model); }
          cam.clearViewOffset(); cam.updateProjectionMatrix();
          unattach(added); unhide(hid);
          return slidePlan ? 0 : (isProp(clip) ? needP : Math.max(win.side * FRAME_F, needV, needH));
        }
        // 2e passe : TOUTES les animations ont exactement le même cadre -> l'avatar a exactement la même taille partout
        // le prop garde le cadre dont son objet a besoin (jamais coupé) ; les autres animations ont le cadre commun
        const side = isProp(clip) ? Math.min(Math.max(globalSide, needOf.get(clip) || 0), PROP_MAX_GROW * globalSide) : globalSide;
        const cx = c0;   // cadre centré sur le CORPS (prop compris : l'avatar démarre sur l'ombre) (axe de la caméra), pas sur la boîte de l'animation : un bras levé ne décale plus l'avatar hors de l'ombre
        const winK = win.k, winTouch = win.touch, winPer = win.perF || [], winFull = win.full || { w: 0, h: 0 };
        box = { fx0: win.fx0, fx1: win.fx1, fy0: win.fy0, fy1: win.fy1 };   // zone occupée par l'avatar pendant toute l'animation (mesurée)
        win = { x: cx - side / 2, y: gpx - GROUND_AT * side, side };   // les pieds sur la ligne du sol, comme toutes les animations
        if (isProp(clip) && winPer.length) {
          const wl = win.x, wr = win.x + side, wt = win.y, wb = win.y + side;
          const out = winPer.filter(p => p[0] < wl - 1 || p[1] > wr + 1 || p[2] < wt - 1 || p[3] > wb + 1).length;
          fetch('/log', { method: 'POST', body: '  ' + clip.name + ' : ' + out + ' image(s) sur ' + winPer.length + ' dépassent le cadre (étendue totale mesurée = ' + Math.round(winFull.w) + ' x ' + Math.round(winFull.h) + ' px)' });
        }
        if (isProp(clip)) fetch('/log', { method: 'POST', body: '  ' + clip.name + ' : zone occupée par l\'avatar + objet = ' + Math.round(box.fx1 - box.fx0) + ' x ' + Math.round(box.fy1 - box.fy0) + ' px de mesure (champ mesuré x' + (winK || 1.5) + (winTouch ? ', bord atteint !' : '') + '), cadre = ' + Math.round(side) + ' px (cadre normal = ' + Math.round(globalSide) + ' px)' });
        fetch('/log', { method: 'POST', body: '  ' + clip.name + ' : cadre = ' + (win.side / (refSide * FRAME_F)).toFixed(2) + ' x le cadre de la 1re animation (1.00 = même taille d\'avatar)' });
      }
    }
    if (needOnly) {   // mesure impossible (rien de visible) : on ne rend rien
      if (mixer) { mixer.stopAllAction(); mixer.uncacheRoot(model); }
      cam.clearViewOffset(); cam.updateProjectionMatrix();
      unattach(added); unhide(hid);
      return 0;
    }
    // Zone à rendre : seulement le rectangle où se trouve l'avatar (+ grosse marge), le reste du cadre est transparent.
    // Même caméra, même échelle, mêmes pixels : le résultat est identique, mais on calcule ~2x moins de pixels.
    let ox = 0, oy = 0, ow = W, oh = W;
    if (clip && win && box && !isProp(clip)) {   // le prop (objet qui peut bouger vite) est toujours rendu en plein cadre
      const mg = 0.08 * W + 8, toX = (fx) => (fx - win.x) / win.side * W, toY = (fy) => (fy - win.y) / win.side * W;
      const x0 = Math.max(0, Math.floor(toX(box.fx0) - mg)), x1 = Math.min(W, Math.ceil(toX(box.fx1) + mg));
      const y0 = Math.max(0, Math.floor(toY(box.fy0) - mg)), y1 = Math.min(W, Math.ceil(toY(box.fy1) + mg));
      if (x1 - x0 > 32 && y1 - y0 > 32 && (x1 - x0) * (y1 - y0) < 0.85 * W * W) { ox = x0; oy = y0; ow = x1 - x0; oh = y1 - y0; }
    }
    const pw = Math.max(1, Math.round(ow * RW / W)), ph = Math.max(1, Math.round(oh * RW / W));
    renderer.setSize(pw, ph);
    if (clip && win) fetch('/log', { method: 'POST', body: '  ' + clip.name + ' : zone rendue = ' + Math.round(100 * ow * oh / (W * W)) + ' % du cadre' });
    const useW = !!workers;
    const jid = ++jobSeq, wk = useW ? workers[jid % workers.length] : null;
    // mémoire bornée : au plus POOL animations en cours d'encodage pendant qu'on en rend une nouvelle
    if (useW && jobsDone.length > POOL) await jobsDone[jobsDone.length - POOL - 1].catch(() => {});
    for (let i = 0; i < n; i++) {
      if (clip) mixer.setTime(clip.duration * i / n);
      if (clip) { aim(clip, i); if (win) cam.setViewOffset(P1, P1, win.x + ox / W * win.side, win.y + oy / W * win.side, ow / W * win.side, oh / W * win.side); }
      else pivot.rotation.y = 2 * Math.PI * i / n;
      renderer.render(scene, cam);
      ctx.clearRect(ox, oy, ow, oh);
      ctx.imageSmoothingEnabled = true;
      ctx.imageSmoothingQuality = 'high';
      ctx.drawImage(renderer.domElement, 0, 0, pw, ph, ox, oy, ow, oh);
      const { data } = ctx.getImageData(ox, oy, ow, oh);
      if (i === 0 && (!clip || isProp(clip) || clip === clips[0])) png = await new Promise(r => cv.toBlob(r, 'image/png'));
      if (useW) wk.postMessage({ t: 'frame', id: jid, W, ox, oy, ow, oh, smooth: EDGE_SMOOTH, buf: data.buffer }, [data.buffer]);
      else { const full = place(new Uint8ClampedArray(data), ox, oy, ow, oh, W); if (EDGE_SMOOTH) smoothAlpha(full, W); frames.push(full); }
      msg.textContent = label + ' : image ' + (i + 1) + ' / ' + n;
      if (i % 5 === 0) await new Promise(r => setTimeout(r, 1));
    }
    if (mixer) { mixer.stopAllAction(); mixer.uncacheRoot(model); }
    cam.clearViewOffset(); cam.updateProjectionMatrix();
    unattach(added);
    unhide(hid);
    if (useW) {
      msg.textContent = label + ' : envoyé à l\'encodage';
      const p = new Promise((resolve, reject) => waiting.set(jid, { resolve, reject }));
      p.catch(() => {});
      jobsDone.push(p);
      wk.postMessage({ t: 'finish', id: jid, W, delays });
      return { bytesP: p, png };
    }
    msg.textContent = label + ' : encodage…';
    await new Promise(r => setTimeout(r, 1));
    const pal = buildPalette(frames);
    const lut = makeLut();
    const gif = GIFEncoder();
    for (let i = 0; i < n; i++) {
      gif.writeFrame(toIndex(frames[i], pal, lut), W, W, i === 0
        ? { palette: pal, delay: delays[i], transparent: true, transparentIndex: 255, dispose: 2 }
        : { delay: delays[i], transparent: true, transparentIndex: 255, dispose: 2 });
    }
    gif.finish();
    return { bytesP: Promise.resolve(gif.bytes()), png };
  }

  const uploads = [];
  const tStart = performance.now();
  await startWorkers();
  const failed = [];   // animations qui ont échoué : on continue avec les autres plutôt que de tout abandonner
  const failLog = (what, e) => { failed.push(what); fetch('/log', { method: 'POST', body: 'ÉCHEC « ' + what + ' » : ' + e + ' (les autres animations continuent)' }); };
  if (!clips.length) {
    const r = await safeRender(null, 'Rotation');
    await up('export.gif', await r.bytesP, 'image/gif');
    await up('export.png', r.png, 'image/png');
  } else {
    // Le prop (animation propre à l'avatar) n'a pas de numéro : c'est l'animation PAR DÉFAUT (export.gif).
    // Les animations universelles gardent toujours les mêmes numéros : a01 = Hello there!, a02 = Applause…
    const propClip = clips.find(isProp);
    const others = clips.filter(c => !isProp(c));
    // 1re passe : cadre nécessaire à chaque animation ; le plus grand devient le cadre COMMUN (même taille d'avatar partout, rien n'est coupé)
    const needs = [], nds = [];
    const skip = new Set();
    needOf.clear();
    for (let k = 0; k < clips.length; k++) {
      msg.textContent = 'Mesure globale ' + (k + 1) + '/' + clips.length + '…';
      let nd = 0;
      try { nd = await safeRender(clips[k], 'Mesure', true); }
      catch (e) { skip.add(clips[k]); failLog(clips[k].name + ' (mesure)', e); }
      needs.push(clips[k].name + ' ' + nd.toFixed(0));
      nds.push(nd || 0);
      needOf.set(clips[k], nd || 0);
      globalSide = Math.max(globalSide, nd || 0);
    }
    // Taille d'avatar = celle de la 1re animation (« Hello there! »), comme avant : le cadre commun ne dépasse pas MAX_GROW x ce cadre.
    // Les animations très amples (sauts…) peuvent alors dépasser un peu en haut du cadre, mais l'avatar garde la même taille partout.
    const capSide = nds[0] > 0 ? nds[0] * MAX_GROW : globalSide;
    if (globalSide > capSide) fetch('/log', { method: 'POST', body: 'Cadre commun limité à ' + capSide.toFixed(0) + ' px (au lieu de ' + globalSide.toFixed(0) + ') pour garder l\'avatar grand. Animations plus amples que le cadre : ' + clips.filter((c, i) => !isProp(c) && nds[i] > capSide * 1.03).map(c => c.name).join(', ') });
    globalSide = Math.min(globalSide, capSide);
    refSide = globalSide / FRAME_F;
    fetch('/log', { method: 'POST', body: 'Cadre commun à toutes les animations (même taille d\'avatar partout) : ' + globalSide.toFixed(0) + ' px de mesure | besoin par animation : ' + needs.join(' / ') });
    let fallback = null;       // 1re animation réussie : sert d'animation par défaut si le prop manque ou échoue
    let haveDefault = false;
    for (let k = 0; k < others.length; k++) {
      if (skip.has(others[k])) continue;
      const tag = 'a' + String(k + 1).padStart(2, '0');   // la numérotation reste celle de l'animation, même si une autre a échoué
      try {
        const r = await safeRender(others[k], 'Animation ' + (k + 1) + '/' + others.length + ' (' + others[k].name + ')');
        uploads.push(r.bytesP.then(b => up('export_' + tag + '.gif', b, 'image/gif')));
        if (!fallback) fallback = r;
      } catch (e) { failLog(others[k].name, e); }
    }
    if (propClip && !skip.has(propClip)) {   // le prop en dernier (même échelle d'avatar que la 1re animation) = animation par défaut
      try {
        const r = await safeRender(propClip, 'Animation par défaut (' + propClip.name + ')');
        uploads.push(r.bytesP.then(b => up('export.gif', b, 'image/gif')));
        if (r.png) await up('export.png', r.png, 'image/png');
        haveDefault = true;
      } catch (e) { failLog(propClip.name, e); }
    }
    if (!haveDefault && fallback) {
      uploads.push(fallback.bytesP.then(b => up('export.gif', b, 'image/gif')));
      if (fallback.png) await up('export.png', fallback.png, 'image/png');
    }
    if (!fallback && !haveDefault) throw new Error('aucune animation n\'a pu être produite (' + failed.join(', ') + ')');
  }
  msg.textContent = 'Fin des encodages…';
  await Promise.all(uploads);
  if (failed.length) fetch('/log', { method: 'POST', body: 'ATTENTION : ' + failed.length + ' animation(s) en échec : ' + failed.join(', ') });
  fetch('/log', { method: 'POST', body: 'Durée de la conversion (rendu + encodage) : ' + ((performance.now() - tStart) / 1000).toFixed(0) + ' s' });
  await fetch('/done', { method: 'POST', body: 'ok' });
  msg.textContent = 'Terminé ✔';
} catch (e) {
  msg.textContent = 'Erreur : ' + e;
  fetch('/error', { method: 'POST', body: String(e) });
}
</script>
HTMLEOF

echo "Étape 2 : conversion locale"
python3 "$WORK/server.py" "$WORK" "$THEME_ART" "$PORT" &
SPID=$!
sleep 1
# Résolution du SYSTÈME Batocera
detect_res() {
  local key r f m
  for key in es.resolution global.videomode; do
    r=$(batocera-settings-get "$key" 2>/dev/null | grep -oE '^[0-9]+x[0-9]+')
    if [ -n "$r" ]; then echo "Résolution système : $r (réglage $key)" >&2; echo "$r"; return; fi
  done
  for f in /sys/class/drm/card*-*/status; do
    [ "$(cat "$f" 2>/dev/null)" = "connected" ] || continue
    m=$(head -1 "$(dirname "$f")/modes" 2>/dev/null | grep -oE '^[0-9]+x[0-9]+')
    if [ -n "$m" ]; then echo "Résolution système : $m (mode préféré de l'écran branché)" >&2; echo "$m"; return; fi
  done
  echo "Résolution système introuvable : on utilise celle de la fenêtre" >&2
}
SYS_RES=$(detect_res)
SYS_W=${SYS_RES%x*}; SYS_H=${SYS_RES#*x}
[ -z "$SYS_RES" ] && SYS_W="" && SYS_H=""
RAM_MB=$(awk '/MemTotal/{print int($2/1024)}' /proc/meminfo)
CORES=$(nproc)
echo "Machine : ${RAM_MB} Mo de RAM, ${CORES} coeurs"
flatpak run "$APP" --kiosk --no-sandbox --ozone-platform=$OZONE "http://127.0.0.1:$PORT/index.html?ram=$RAM_MB&cores=$CORES&w=$SYS_W&h=$SYS_H" &
BPID=$!
wait $SPID
CONV_RC=$?        # 0 = la page a signalé « terminé » ; autre = erreur ou délai dépassé
sleep 1
flatpak kill "$APP" 2>/dev/null
wait $BPID 2>/dev/null

# Sauvegarde de cette création dans le prochain emplacement libre (seulement si la conversion est allée au bout :
# sinon un ancien export.gif serait enregistré à la place du nouvel avatar)
if [ "$CONV_RC" -ne 0 ]; then
  echo "Conversion non aboutie (code $CONV_RC) : rien n'est enregistré, le GLB est conservé pour réessayer : $GLB"
elif [ -f "$THEME_ART/export.gif" ]; then
  SLOT=""
  for i in $(seq 1 $MAXSLOTS); do
    [ -f "$THEME_ART/slot_$i.gif" ] || { SLOT=$i; break; }
  done
  if [ -z "$SLOT" ]; then
    # tous les emplacements sont pris : on remplace le plus ANCIEN (uniquement slot_N.gif, pas les slot_N_aNN.gif)
    SLOT=$(for i in $(seq 1 $MAXSLOTS); do f="$THEME_ART/slot_$i.gif"; [ -f "$f" ] && echo "$(stat -c %Y "$f") $i"; done | sort -n | head -1 | cut -d' ' -f2)
  fi
  [ -n "$SLOT" ] || SLOT=1
  lnk() { ln -f "$1" "$2" 2>/dev/null || cp -f "$1" "$2"; }   # lien dur = instantané et sans doubler l'espace disque
  lnk "$THEME_ART/export.gif" "$THEME_ART/slot_$SLOT.gif"
  [ -f "$THEME_ART/export.png" ] && lnk "$THEME_ART/export.png" "$THEME_ART/slot_$SLOT.png"
  rm -f "$THEME_ART"/slot_${SLOT}_a*.gif
  for f in "$THEME_ART"/export_a*.gif; do
    [ -f "$f" ] || continue
    b=${f##*/}; lnk "$f" "$THEME_ART/slot_${SLOT}${b#export}"
  done
  if [ -f "$THEME_ART/slot_$SLOT.gif" ]; then
    echo "Avatar enregistré : Avatar $SLOT (slot_$SLOT.gif)"
    # Conversion réussie ET enregistrée : le .glb téléchargé ne sert plus, on le supprime
    rm -f -- "$GLB" && echo "GLB supprimé : $GLB"
  else
    echo "Enregistrement impossible dans slot_$SLOT.gif : le GLB est conservé : $GLB"
  fi
fi
ls -l "$THEME_ART" 2>&1 | head -40
echo "Terminé."
}
main "$@"; exit $?
