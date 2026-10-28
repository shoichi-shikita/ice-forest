shader_type canvas_item;
render_mode unshaded;
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform float vignette_strength : hint_range(0.0, 1.0) = 0.92;
uniform float distortion : hint_range(0.0, 0.1) = 0.025;
uniform float chromatic_aberration : hint_range(0.0, 0.006) = 0.0012;
uniform float grain_strength : hint_range(0.0, 0.05) = 0.014;
float hash21(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}
vec2 safe_uv(vec2 uv) {
    vec2 pixel = 1.0 / vec2(textureSize(screen_texture, 0));
    return clamp(uv, pixel * 0.5, vec2(1.0) - pixel * 0.5);
}
void fragment() {
    vec2 p = SCREEN_UV * 2.0 - 1.0;
    float radius2 = dot(p, p);
    // 僅かなバレル歪み。オーバースキャンで画面外の縁を隠す。
    vec2 uv = vec2(0.5) + 0.5 * p * (1.0 + distortion * radius2)
        / (1.0 + 2.0 * distortion);
    vec2 shift = p * radius2 * chromatic_aberration;
    vec3 color;
    color.r = texture(screen_texture, safe_uv(uv + shift)).r;
    color.g = texture(screen_texture, safe_uv(uv)).g;
    color.b = texture(screen_texture, safe_uv(uv - shift)).b;
    float edge = smoothstep(0.30, 1.25, length(p));
    color *= 1.0 - vignette_strength * edge;
    float luma = dot(color, vec3(0.2126, 0.7152, 0.0722));
    float grain = hash21(FRAGCOORD.xy + vec2(floor(TIME * 24.0), 17.0)) - 0.5;
    float grain_mask = smoothstep(0.0, 0.025, luma);
    color += vec3(grain * grain_strength * grain_mask * (1.0 - 0.5 * luma));
    COLOR = vec4(clamp(color, vec3(0.0), vec3(1.0)), 1.0);
}

