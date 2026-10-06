// glitch_displacement.gdshader
// RGB channel separation + horizontal line displacement.
// Driven by glitch_intensity (0.0 = off, 1.0 = full chaos).
// Applied to: SchizophrenicUI GlitchOverlay, enemy detection events.

shader_type canvas_item;

uniform float glitch_intensity: hint_range(0.0, 1.0) = 0.0;
uniform sampler2D noise_texture: hint_default_white;
uniform float time_scale: hint_range(0.1, 10.0) = 3.0;
// Reads the already-rendered screen so it works on a fullscreen ColorRect overlay.
uniform sampler2D screen_tex : hint_screen_texture, repeat_disable, filter_nearest;

void fragment() {
	float t = TIME * time_scale;

	// Noise-driven row displacement
	float row_noise = texture(noise_texture, vec2(UV.y * 8.0, t * 0.5)).r;
	float shift_x = (row_noise - 0.5) * glitch_intensity * 0.04;

	// Only glitch some rows (threshold)
	float glitch_row = step(0.92 - glitch_intensity * 0.4, row_noise);
	shift_x *= glitch_row;

	// Sample RGB at different offsets
	vec4 col;
	col.r = texture(screen_tex, SCREEN_UV + vec2(shift_x * 1.5, 0.0)).r;
	col.g = texture(screen_tex, SCREEN_UV + vec2(shift_x * 0.5, 0.0)).g;
	col.b = texture(screen_tex, SCREEN_UV - vec2(shift_x, 0.0)).b;
	col.a = 1.0;

	COLOR = col;
}
