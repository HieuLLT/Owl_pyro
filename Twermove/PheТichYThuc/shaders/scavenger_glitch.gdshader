// scavenger_glitch.gdshader
// Xác Máy Đói Khát (Scavengers): twitchy, jerky machine corpses.
//  * stepped "stutter" displacement (the body judders in discrete jumps)
//  * rust-grey tint with flickering static speckles
//  * `alert` 0..1 (set from Crawler.gd state): 0 = dormant, 1 = hunting (red heat + faster stutter)
// Works on ColorRect / Sprite2D / AnimatedSprite2D (uses COLOR as the base).

shader_type canvas_item;

group_uniforms stutter;
uniform float stutter_fps : hint_range(2.0, 30.0) = 9.0;
uniform float stutter_amount : hint_range(0.0, 0.2) = 0.04;

group_uniforms look;
uniform vec4 rust_color : source_color = vec4(0.55, 0.28, 0.16, 1.0);
uniform float rust_mix : hint_range(0.0, 1.0) = 0.35;
uniform float speckle : hint_range(0.0, 1.0) = 0.25;
uniform float speckle_cells : hint_range(4.0, 48.0) = 18.0;

group_uniforms state;
uniform float alert : hint_range(0.0, 1.0) = 0.0;
uniform vec4 alert_color : source_color = vec4(0.95, 0.08, 0.05, 1.0);

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

void fragment() {
	float fps = stutter_fps * (1.0 + alert * 1.8);
	float tick = floor(TIME * fps);

	// Discrete jerk: most ticks stay still, some jump
	float jump = step(0.55, hash21(vec2(tick, 1.0)));
	vec2 off = (vec2(hash21(vec2(tick, 2.0)), hash21(vec2(tick, 3.0))) - 0.5) * 2.0 * stutter_amount * jump;

	vec4 t_here = texture(TEXTURE, UV);
	vec4 t_off = texture(TEXTURE, UV + off);
	vec4 tint = COLOR / max(t_here, vec4(0.001));
	vec4 col = t_off * tint;
	col.a = t_off.a * clamp(COLOR.a / max(t_here.a, 0.001), 0.0, 1.0);

	// Rust
	col.rgb = mix(col.rgb, col.rgb * rust_color.rgb * 1.6, rust_mix);

	// Static speckles
	vec2 cell = floor(UV * speckle_cells);
	float s = step(1.0 - speckle * 0.35, hash21(cell + vec2(tick, tick * 1.7)));
	col.rgb = mix(col.rgb, vec3(0.85), s * 0.6);

	// Hunting: red heat pulses through the body
	float pulse = 0.5 + 0.5 * sin(TIME * 14.0);
	col.rgb = mix(col.rgb, alert_color.rgb, alert * (0.35 + 0.3 * pulse));

	COLOR = col;
}
