// Evangelion-inspired red/orange hex fractal background.
precision highp float;

varying vec2 v_coords;
uniform vec2 size;
uniform vec2 u_camera;

const float PI = 3.14159265358979323846;

mat2 rot(float a) {
    float s = sin(a);
    float c = cos(a);
    return mat2(c, -s, s, c);
}

float hexSDF(vec2 p) {
    vec2 q = abs(p);
    return max(dot(q, normalize(vec2(1.0, 1.7320508))), q.x) - 1.0;
}

float hexGridLine(vec2 p, float scale, float thickness) {
    vec2 q = p * scale;
    vec2 gv = q;
    gv.x /= 1.7320508;
    gv.y -= floor(gv.x) * 0.5;
    vec2 cell = fract(gv) - 0.5;
    cell.x *= 1.7320508;

    float d = hexSDF(cell * 2.0);
    return 1.0 - smoothstep(-thickness, thickness, d);
}

float ringPulse(vec2 p, float scale, float width) {
    float r = length(p * scale);
    float w = abs(fract(r) - 0.5);
    return smoothstep(width, 0.0, w);
}

void main() {
    vec2 canvas = (v_coords * size + u_camera);
    vec2 uv = canvas / min(size.x, size.y);

    // Warp to create a subtle fractal-like drift without animation.
    vec2 w = uv;
    w = rot(0.21) * w;
    w += 0.08 * vec2(sin(uv.y * 7.0), cos(uv.x * 7.0));

    float g1 = hexGridLine(w, 9.0, 0.05);
    float g2 = hexGridLine(rot(PI / 6.0) * w * 1.8, 7.0, 0.042);
    float g3 = hexGridLine(rot(-PI / 6.0) * w * 3.2, 6.0, 0.035);

    float rings = ringPulse(w + vec2(0.13, -0.09), 3.6, 0.14) * 0.38;
    float hexEnergy = clamp(g1 * 0.65 + g2 * 0.5 + g3 * 0.42 + rings, 0.0, 1.0);

    vec3 deep = vec3(0.09, 0.01, 0.01);
    vec3 base = vec3(0.22, 0.03, 0.01);
    vec3 hot = vec3(0.98, 0.31, 0.05);
    vec3 ember = vec3(1.0, 0.58, 0.15);

    float vignette = smoothstep(1.35, 0.25, length(uv));
    vec3 col = mix(deep, base, vignette);
    col = mix(col, hot, hexEnergy * 0.78);
    col += ember * pow(hexEnergy, 3.0) * 0.26;

    gl_FragColor = vec4(clamp(col, 0.0, 1.0), 1.0);
}
