// EVA-style emergency hex background
// Clean embedded bitmap-font version: all tweakable values are grouped at the top.
// Uniforms expected by Drift examples: v_coords, size, u_camera, u_time.
//
// Text method:
// This uses an embedded 14x18 bitmap font for EMERGENCY. That is the "encoded bitmap
// font inside the shader" approach from GLSL text-rendering tutorials. It does not
// need sampler2D / font texture support, so it should work in your current Drift setup.

precision highp float;

varying vec2 v_coords;
uniform vec2 size;
uniform vec2 u_camera;
uniform float u_time;

// ============================================================
// TWEAKABLE VALUES
// ============================================================

// --- Camera / world anchoring ---
const float CAMERA_SIGN = 1.0; // set to -1.0 if the pattern pans the wrong way

// --- Hex grid ---
const float CELL_R  = 70.2; // grid pitch / spacing
const float FILL_R  = 69.0; // filled hex radius; lower = bigger black gaps
const float EDGE_AA = 1.2;  // anti-aliasing around hex edge

// --- Colors ---
const vec3 BG_COLOR   = vec3(0.002, 0.000, 0.000);
const vec3 OFF_COLOR  = vec3(0.010, 0.001, 0.001);
const vec3 ON_COLOR   = vec3(0.990, 0.030, 0.000);
const vec3 MARK_COLOR = vec3(0.000, 0.000, 0.000);
const vec3 GLOW_COLOR = vec3(0.140, 0.000, 0.000);

// --- Glow ---
const float GLOW_WIDTH    = 12.0;
const float GLOW_STRENGTH = 1.0;

// --- Binary activation density ---
const float ON_THRESHOLD     = 0.42; // lower = more red hexes
const float THRESHOLD_JITTER = 0.10; // higher = rougher/chaotic wave edges

// --- Animation speed ---
const float ANIM_SPEED = 0.38; // lower = slower waves

// --- Wave 1 ---
const vec2  WAVE1_DIR    = vec2(0.92, 0.36);
const float WAVE1_FREQ   = 0.18;
const float WAVE1_SPEED  = 0.90;
const float WAVE1_WEIGHT = 0.34;

// --- Wave 2 ---
const vec2  WAVE2_CELL_SCALE = vec2(0.90, 1.05);
const vec2  WAVE2_MOVE       = vec2(0.52, -0.30);
const float WAVE2_FREQ       = 0.28;
const float WAVE2_SPEED      = 0.55;
const float WAVE2_WEIGHT     = 0.18;

// --- Large noise field ---
const float LARGE_NOISE_SCALE  = 0.10;
const vec2  LARGE_NOISE_SPEED  = vec2(0.065, -0.050);
const float LARGE_NOISE_WEIGHT = 0.30;

// --- Edge chaos noise ---
const float EDGE_NOISE_SCALE   = 0.25;
const vec2  EDGE_NOISE_SPEED   = vec2(-0.095, 0.085);
const vec2  EDGE_NOISE_OFFSET  = vec2(11.3, 11.3);
const float EDGE_NOISE_WEIGHT  = 0.18;

// --- Text visibility ---
const float TEXT_ENABLE = 1.0;

// --- Text size / placement ---
const float TEXT_BOX_W    = 1.60; // bigger = wider word
const float TEXT_BOX_H    = 0.25; // bigger = taller word
const float TEXT_Y_OFFSET = 0.00; // positive = move text up

// --- Embedded bitmap font controls ---
const float FONT_COLS        = 14.0; // fixed: glyph pixels wide
const float FONT_ROWS        = 18.0; // fixed: glyph pixels tall
const float LETTER_GAP       = 2.0;  // in glyph-pixel units; lower = tighter letters
const float FONT_PIXEL_FILL  = 1.0;  // lower = thinner glyph pixels, higher = bolder blocks
const float FONT_PIXEL_AA    = 0.08; // lower = sharper text, higher = softer text

// --- Triangle visibility ---
const float TRIANGLE_ENABLE = 1.0;

// --- Triangle size / placement ---
const float TRIANGLE_W  = 0.5; // horizontal size
const float TRIANGLE_H  = 0.35; // vertical size
const float TRIANGLE_Y  = 0.43;  // distance from center
const float TRIANGLE_AA = 0.010;

// --- Optional texture ---
const float SCAN_STRENGTH  = 0.010;
const float SCAN_SPEED     = 8.0;
const float GRAIN_STRENGTH = 0.003;
const float GRAIN_SCALE    = 0.5;
const float GRAIN_RATE     = 8.0;

// ============================================================
// NOISE
// ============================================================

float hash21(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);

    float a = hash21(i);
    float b = hash21(i + vec2(1.0, 0.0));
    float c = hash21(i + vec2(0.0, 1.0));
    float d = hash21(i + vec2(1.0, 1.0));

    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p) {
    float v = 0.0;
    float a = 0.5;
    mat2 r = mat2(0.80, 0.60, -0.60, 0.80);

    for (int i = 0; i < 4; i++) {
        v += a * noise(p);
        p = r * p * 2.02;
        a *= 0.5;
    }

    return v;
}

// ============================================================
// HEX GRID
// ============================================================

vec2 axialFromWorld(vec2 p) {
    return vec2(
        (2.0 / 3.0 * p.x) / CELL_R,
        (-1.0 / 3.0 * p.x + 0.57735026919 * p.y) / CELL_R
    );
}

vec2 worldFromAxial(vec2 h) {
    return vec2(
        CELL_R * 1.5 * h.x,
        CELL_R * 1.73205080757 * (h.y + 0.5 * h.x)
    );
}

vec2 roundAxial(vec2 h) {
    float q = h.x;
    float r = h.y;
    float s = -q - r;

    float rq = floor(q + 0.5);
    float rr = floor(r + 0.5);
    float rs = floor(s + 0.5);

    float qd = abs(rq - q);
    float rd = abs(rr - r);
    float sd = abs(rs - s);

    if (qd > rd && qd > sd) {
        rq = -rr - rs;
    } else if (rd > sd) {
        rr = -rq - rs;
    }

    return vec2(rq, rr);
}

float sdHexFlat(vec2 p, float radius) {
    vec2 q = abs(p);
    return max(q.x * 0.86602540378 + q.y * 0.5, q.y) - radius * 0.86602540378;
}

// Returns exactly 0.0 or 1.0.
float cellActivation(vec2 cell) {
    float t = u_time * ANIM_SPEED;

    float wave1 = 0.5 + 0.5 * sin(dot(cell, WAVE1_DIR) * WAVE1_FREQ - t * WAVE1_SPEED);

    float wave2 = 0.5 + 0.5 * sin(
        length(cell * WAVE2_CELL_SCALE + t * WAVE2_MOVE) * WAVE2_FREQ - t * WAVE2_SPEED
    );

    float nLarge = fbm(cell * LARGE_NOISE_SCALE + t * LARGE_NOISE_SPEED);
    float nEdge  = fbm(cell * EDGE_NOISE_SCALE + t * EDGE_NOISE_SPEED + EDGE_NOISE_OFFSET);

    float field =
        wave1  * WAVE1_WEIGHT +
        wave2  * WAVE2_WEIGHT +
        nLarge * LARGE_NOISE_WEIGHT +
        nEdge  * EDGE_NOISE_WEIGHT;

    float jitter = (hash21(cell) - 0.5) * THRESHOLD_JITTER;

    return step(ON_THRESHOLD + jitter, field);
}

// ============================================================
// EMBEDDED 14x18 BITMAP FONT FOR "EMERGENCY"
// ============================================================

float rowE(float r) {
    if (r < 0.5) return 16383.0;
    if (r < 1.5) return 16383.0;
    if (r < 2.5) return 12288.0;
    if (r < 3.5) return 12288.0;
    if (r < 4.5) return 12288.0;
    if (r < 5.5) return 12288.0;
    if (r < 6.5) return 12288.0;
    if (r < 7.5) return 16380.0;
    if (r < 8.5) return 16380.0;
    if (r < 9.5) return 16380.0;
    if (r < 10.5) return 12288.0;
    if (r < 11.5) return 12288.0;
    if (r < 12.5) return 12288.0;
    if (r < 13.5) return 12288.0;
    if (r < 14.5) return 12288.0;
    if (r < 15.5) return 16383.0;
    if (r < 16.5) return 16383.0;
    return 16383.0;
}

float rowM(float r) {
    if (r < 0.5) return 12291.0;
    if (r < 1.5) return 14343.0;
    if (r < 2.5) return 15375.0;
    if (r < 3.5) return 15903.0;
    if (r < 4.5) return 16191.0;
    if (r < 5.5) return 15351.0;
    if (r < 6.5) return 14823.0;
    if (r < 7.5) return 14535.0;
    if (r < 8.5) return 14343.0;
    if (r < 9.5) return 14343.0;
    if (r < 10.5) return 14343.0;
    if (r < 11.5) return 14343.0;
    if (r < 12.5) return 14343.0;
    if (r < 13.5) return 14343.0;
    if (r < 14.5) return 14343.0;
    if (r < 15.5) return 14343.0;
    if (r < 16.5) return 14343.0;
    return 14343.0;
}

float rowR(float r) {
    if (r < 0.5) return 16380.0;
    if (r < 1.5) return 16382.0;
    if (r < 2.5) return 12302.0;
    if (r < 3.5) return 12295.0;
    if (r < 4.5) return 12295.0;
    if (r < 5.5) return 12302.0;
    if (r < 6.5) return 16382.0;
    if (r < 7.5) return 16380.0;
    if (r < 8.5) return 12528.0;
    if (r < 9.5) return 12408.0;
    if (r < 10.5) return 12348.0;
    if (r < 11.5) return 12318.0;
    if (r < 12.5) return 12303.0;
    if (r < 13.5) return 12295.0;
    if (r < 14.5) return 12291.0;
    if (r < 15.5) return 12291.0;
    if (r < 16.5) return 12291.0;
    return 12291.0;
}

float rowG(float r) {
    if (r < 0.5) return 8190.0;
    if (r < 1.5) return 16383.0;
    if (r < 2.5) return 14339.0;
    if (r < 3.5) return 12288.0;
    if (r < 4.5) return 12288.0;
    if (r < 5.5) return 12288.0;
    if (r < 6.5) return 12288.0;
    if (r < 7.5) return 12543.0;
    if (r < 8.5) return 12543.0;
    if (r < 9.5) return 12295.0;
    if (r < 10.5) return 12295.0;
    if (r < 11.5) return 12295.0;
    if (r < 12.5) return 12295.0;
    if (r < 13.5) return 12295.0;
    if (r < 14.5) return 14343.0;
    if (r < 15.5) return 16383.0;
    if (r < 16.5) return 8190.0;
    return 4092.0;
}

float rowN(float r) {
    if (r < 0.5) return 12291.0;
    if (r < 1.5) return 14339.0;
    if (r < 2.5) return 15363.0;
    if (r < 3.5) return 15875.0;
    if (r < 4.5) return 16131.0;
    if (r < 5.5) return 14211.0;
    if (r < 6.5) return 13251.0;
    if (r < 7.5) return 12771.0;
    if (r < 8.5) return 12531.0;
    if (r < 9.5) return 12411.0;
    if (r < 10.5) return 12351.0;
    if (r < 11.5) return 12319.0;
    if (r < 12.5) return 12303.0;
    if (r < 13.5) return 12295.0;
    if (r < 14.5) return 12291.0;
    if (r < 15.5) return 12291.0;
    if (r < 16.5) return 12291.0;
    return 12291.0;
}

float rowC(float r) {
    if (r < 0.5) return 8190.0;
    if (r < 1.5) return 16383.0;
    if (r < 2.5) return 14339.0;
    if (r < 3.5) return 12288.0;
    if (r < 4.5) return 12288.0;
    if (r < 5.5) return 12288.0;
    if (r < 6.5) return 12288.0;
    if (r < 7.5) return 12288.0;
    if (r < 8.5) return 12288.0;
    if (r < 9.5) return 12288.0;
    if (r < 10.5) return 12288.0;
    if (r < 11.5) return 12288.0;
    if (r < 12.5) return 12288.0;
    if (r < 13.5) return 12288.0;
    if (r < 14.5) return 14339.0;
    if (r < 15.5) return 16383.0;
    if (r < 16.5) return 8190.0;
    return 4092.0;
}

float rowY(float r) {
    if (r < 0.5) return 12291.0;
    if (r < 1.5) return 14343.0;
    if (r < 2.5) return 7182.0;
    if (r < 3.5) return 3612.0;
    if (r < 4.5) return 1848.0;
    if (r < 5.5) return 1008.0;
    if (r < 6.5) return 480.0;
    if (r < 7.5) return 192.0;
    if (r < 8.5) return 192.0;
    if (r < 9.5) return 192.0;
    if (r < 10.5) return 192.0;
    if (r < 11.5) return 192.0;
    if (r < 12.5) return 192.0;
    if (r < 13.5) return 192.0;
    if (r < 14.5) return 192.0;
    if (r < 15.5) return 192.0;
    if (r < 16.5) return 192.0;
    return 192.0;
}

float letterId(float i) {
    // E M E R G E N C Y
    if (i < 0.5) return 0.0;
    if (i < 1.5) return 1.0;
    if (i < 2.5) return 0.0;
    if (i < 3.5) return 2.0;
    if (i < 4.5) return 3.0;
    if (i < 5.5) return 0.0;
    if (i < 6.5) return 4.0;
    if (i < 7.5) return 5.0;
    return 6.0;
}

float glyphRow(float id, float row) {
    if (id < 0.5) return rowE(row);
    if (id < 1.5) return rowM(row);
    if (id < 2.5) return rowR(row);
    if (id < 3.5) return rowG(row);
    if (id < 4.5) return rowN(row);
    if (id < 5.5) return rowC(row);
    return rowY(row);
}

float bitFromRow(float rowValue, float col) {
    // col 0 is leftmost. Row values are FONT_COLS-bit masks.
    float bitIndex = FONT_COLS - 1.0 - col;
    return floor(mod(rowValue / pow(2.0, bitIndex), 2.0));
}

float emergencyText(vec2 lp) {
    if (TEXT_ENABLE < 0.5) return 0.0;

    float totalW = 9.0 * FONT_COLS + 8.0 * LETTER_GAP;
    float cellW = FONT_COLS + LETTER_GAP;

    float x = (lp.x / TEXT_BOX_W + 0.5) * totalW;
    // Drift/screen-space y grows downward here, so use + instead of - to keep glyphs upright.
    float y = (0.5 + (lp.y - TEXT_Y_OFFSET) / TEXT_BOX_H) * FONT_ROWS;

    if (x < 0.0 || x >= totalW || y < 0.0 || y >= FONT_ROWS) return 0.0;

    float letterIndex = floor(x / cellW);
    if (letterIndex > 8.5) return 0.0;

    float localX = mod(x, cellW);
    if (localX >= FONT_COLS) return 0.0;

    float col = floor(localX);
    float row = floor(y);

    float id = letterId(letterIndex);
    float rowValue = glyphRow(id, row);
    float bit = bitFromRow(rowValue, col);

    // Anti-aliased square pixel. Keeps the embedded font clean instead of distorted.
    vec2 f = fract(vec2(localX, y));
    float edge = 0.5 * FONT_PIXEL_FILL;
    float px = 1.0 - smoothstep(edge, edge + FONT_PIXEL_AA, max(abs(f.x - 0.5), abs(f.y - 0.5)));

    return bit * px;
}

// ============================================================
// TRIANGLES
// ============================================================

float triMask(vec2 lp, vec2 c, float w, float h, float up) {
    vec2 p = lp - c;
    float y = (p.y + h * 0.5) / h;
    float hw = mix(y, 1.0 - y, up) * w * 0.5;
    float d = min(min(p.y + h * 0.5, h * 0.5 - p.y), hw - abs(p.x));
    return smoothstep(0.0, TRIANGLE_AA, d);
}

float emergencyMark(vec2 lp) {
    float text = emergencyText(lp);

    float upArrow = 0.0;
    float dnArrow = 0.0;

    if (TRIANGLE_ENABLE > 0.5) {
        upArrow = triMask(lp, vec2(0.0,  TRIANGLE_Y), TRIANGLE_W, TRIANGLE_H, 1.0);
        dnArrow = triMask(lp, vec2(0.0, -TRIANGLE_Y), TRIANGLE_W, TRIANGLE_H, 0.0);
    }

    return max(text, max(upArrow, dnArrow));
}

// ============================================================
// MAIN
// ============================================================

void main() {
    vec2 screen = v_coords * size;
    vec2 world = screen + u_camera * CAMERA_SIGN;

    vec2 axial = axialFromWorld(world);
    vec2 cell = roundAxial(axial);
    vec2 center = worldFromAxial(cell);
    vec2 local = world - center;

    float d = sdHexFlat(local, FILL_R);
    float inside = 1.0 - smoothstep(-EDGE_AA, EDGE_AA, d);

    float bit = cellActivation(cell);

    vec3 fill = mix(OFF_COLOR, ON_COLOR, bit);
    vec3 col = mix(BG_COLOR, fill, inside);

    float glow = (1.0 - smoothstep(0.0, GLOW_WIDTH, max(d, 0.0))) * bit;
    col += GLOW_COLOR * GLOW_STRENGTH * glow * (1.0 - inside);

    float mark = emergencyMark(local / FILL_R) * bit * inside;
    col = mix(col, MARK_COLOR, mark);

    float scan = 1.0 - SCAN_STRENGTH + SCAN_STRENGTH * sin((screen.y + u_time * SCAN_SPEED) * 3.14159265);
    float grain = (hash21(floor(screen * GRAIN_SCALE) + floor(u_time * GRAIN_RATE)) - 0.5) * GRAIN_STRENGTH;
    col = max(col * scan + grain, vec3(0.0));

    gl_FragColor = vec4(col, 1.0);
}
