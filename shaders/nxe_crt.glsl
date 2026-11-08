// NXE360 - effet cathodique (écran CRT) pour tout l'écran d'EmulationStation
// Auteur : Blunpai - Licence CC BY-NC-SA 4.0 (voir LICENCE.txt)
// Écran légèrement bombé, lignes de balayage, grille RGB, halo lumineux, coins assombris, léger décalage des couleurs
// sur les bords. Réglages : variables crt* des options du thème (Désactivé / Léger / Fort).

#if defined(VERTEX)

#if __VERSION__ >= 130
#define COMPAT_VARYING out
#define COMPAT_ATTRIBUTE in
#define COMPAT_TEXTURE texture
#else
#define COMPAT_VARYING varying
#define COMPAT_ATTRIBUTE attribute
#define COMPAT_TEXTURE texture2D
#endif

#ifdef GL_ES
#define COMPAT_PRECISION mediump
#else
#define COMPAT_PRECISION
#endif

COMPAT_ATTRIBUTE vec4 VertexCoord;
COMPAT_ATTRIBUTE vec4 COLOR;
COMPAT_ATTRIBUTE vec4 TexCoord;
COMPAT_VARYING vec4 COL0;
COMPAT_VARYING vec4 TEX0;

uniform mat4 MVPMatrix;

void main()
{
    gl_Position = MVPMatrix * VertexCoord;
    COL0 = COLOR;
    TEX0.xy = TexCoord.xy;
}

#elif defined(FRAGMENT)

#if __VERSION__ >= 130
#define COMPAT_VARYING in
#define COMPAT_TEXTURE texture
#ifdef GL_ES
out mediump vec4 FragColor;
#else
out vec4 FragColor;
#endif
#else
#define COMPAT_VARYING varying
#define FragColor gl_FragColor
#define COMPAT_TEXTURE texture2D
#endif

#ifdef GL_ES
#ifdef GL_FRAGMENT_PRECISION_HIGH
precision highp float;
#define COMPAT_PRECISION highp
#else
precision mediump float;
#define COMPAT_PRECISION mediump
#endif
#else
#define COMPAT_PRECISION
#endif

uniform COMPAT_PRECISION int FrameCount;
uniform COMPAT_PRECISION vec2 OutputSize;
uniform COMPAT_PRECISION vec2 TextureSize;
uniform sampler2D Texture;
COMPAT_VARYING vec4 TEX0;

// réglages (propriétés de l'élément screenshader du thème)
uniform COMPAT_PRECISION float CURVATURE;   // bombé de l'écran (0 = plat)
uniform COMPAT_PRECISION float SCANLINE;    // force des lignes de balayage (0 à 1)
uniform COMPAT_PRECISION float LINES;       // nombre de lignes sur la hauteur de l'écran (quelle que soit la résolution)
uniform COMPAT_PRECISION float MASK;        // force de la grille RGB (0 à 1)
uniform COMPAT_PRECISION float VIGNETTE;    // assombrissement des coins
uniform COMPAT_PRECISION float GLOW;        // halo autour des zones claires
uniform COMPAT_PRECISION float ABERRATION;  // décalage rouge / bleu sur les bords
uniform COMPAT_PRECISION float BRIGHTNESS;  // compense l'assombrissement des lignes et de la grille
uniform COMPAT_PRECISION float ROLL;        // bande claire qui défile lentement (0 = aucune)

vec2 curve(vec2 uv)
{
    uv = uv * 2.0 - 1.0;
    vec2 off = abs(uv.yx) * CURVATURE;
    uv = uv + uv * off * off;
    return uv * 0.5 + 0.5;
}

vec3 tex(vec2 uv)
{
    return COMPAT_TEXTURE(Texture, uv).rgb;
}

void main()
{
    vec2 uv = curve(TEX0.xy);
    if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0)
    {
        FragColor = vec4(0.0, 0.0, 0.0, 1.0);
        return;
    }

    vec2 px = 1.0 / TextureSize;
    float k = TextureSize.y / 1080.0;                 // mêmes effets visuels en 720p, 1080p ou 4K

    // couleurs légèrement décalées vers les bords
    vec2 d = (uv - 0.5) * ABERRATION * 3.0 * k * px;
    vec3 col = vec3(tex(uv + d).r, tex(uv).g, tex(uv - d).b);

    // halo : moyenne de quelques points autour, ajoutée aux zones claires
    vec2 r = 2.5 * k * px;
    vec3 g = tex(uv + vec2(r.x, 0.0)) + tex(uv - vec2(r.x, 0.0)) + tex(uv + vec2(0.0, r.y)) + tex(uv - vec2(0.0, r.y))
           + tex(uv + r) + tex(uv - r) + tex(uv + vec2(r.x, -r.y)) + tex(uv + vec2(-r.x, r.y));
    g /= 8.0;
    col += g * g * GLOW;

    // lignes de balayage : les zones claires « débordent » sur les lignes, comme un vrai tube
    float lum = dot(col, vec3(0.299, 0.587, 0.114));
    float y = uv.y * LINES;
    float s = 0.5 + 0.5 * cos(6.2831853 * y);
    col *= mix(1.0, s, SCANLINE * (1.0 - 0.6 * clamp(lum, 0.0, 1.0)));

    // grille RGB (luminophores), 3 pixels d'écran
    float m = mod(floor(gl_FragCoord.x / max(1.0, floor(k + 0.5))), 3.0);
    vec3 mask = vec3(1.0 - MASK);
    if (m < 0.5) mask.r = 1.0;
    else if (m < 1.5) mask.g = 1.0;
    else mask.b = 1.0;
    col *= mask;

    col *= BRIGHTNESS;

    // bande claire qui défile lentement
    col *= 1.0 + ROLL * 0.035 * sin(6.2831853 * (uv.y - float(FrameCount) * 0.0015));

    // coins assombris + bords arrondis du tube
    vec2 q = uv * (1.0 - uv.yx);
    col *= pow(clamp(q.x * q.y * 16.0, 0.0, 1.0), VIGNETTE);
    vec2 c = abs(uv - 0.5) * 2.0;
    vec2 e = max(c - vec2(0.96, 0.94), 0.0) / vec2(0.04, 0.06);
    col *= 1.0 - smoothstep(0.75, 1.0, length(e));

    FragColor = vec4(clamp(col, 0.0, 1.0), 1.0);
}
#endif
