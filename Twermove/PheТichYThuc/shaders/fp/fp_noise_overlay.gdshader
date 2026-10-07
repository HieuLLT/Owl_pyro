// fp_noise_overlay.gdshader — fullscreen ColorRect (OVER the 3D view).
//  * white-noise static creeping in from the screen edges
//  * `intrusion` 0..1: the Red voice tears the picture — horizontal tearing, RGB split,
//    full-screen static bursts
//  * `necrosis` 0..1 raises the baseline noise and desaturates the picture
// Uses hint_screen_texture, so it works in the Compatibility renderer.

shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, repeat_disable, filter_nearest;

uniform float edge_noise : hint_range(0.0, 1.0) = 0.22;
uniform float edge_size : hint_range(0.05, 1.0) = 0.55;
uniform float intrusion : hint_range(0.0, 1.0) = 0.0;
uniform float necrosis : hint_range(0.0, 1.0) = 0.0;
uniform float noise_fps : hint_range(4.0, 60.0) = 24.0;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

void fragment() {
	float tick = floor(TIME * noise_fps);
	vec2 uv = SCREEN_UV;

	// Horizontal tearing bands, only while intruding
	float band = floor(uv.y * 24.0);
	float tear_on = step(0.75, hash21(vec2(band, tick))) * intrusion;
	uv.x += (hash21(vec2(band, tick + 7.0)) - 0.5) * 0.12 * tear_on;

	// RGB split
	float split = (0.002 + 0.012 * intrusion) * (1.0 + necrosis);
	vec3 col = vec3(
		texture(screen_tex, uv + vec2(split, 0.0)).r,
		texture(screen_tex, uv).g,
		texture(screen_tex, uv - vec2(split, 0.0)).b);

	// Desaturate with necrosis
	float g = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(col, vec3(g), necrosis * 0.6);

	// Edge-weighted white noise
	vec2 c = SCREEN_UV - vec2(0.5);
	float edge = smoothstep(0.5 - edge_size * 0.5, 0.5, length(c * vec2(1.0, 1.15)));
	float n = hash21(floor(SCREEN_UV * vec2(320.0, 180.0)) + vec2(tick, tick * 1.37));
	float amount = clamp(edge * (edge_noise + necrosis * 0.35) + intrusion * 0.45, 0.0, 1.0);
	col = mix(col, vec3(n), amount * 0.55);

	COLOR = vec4(col, 1.0);
}
