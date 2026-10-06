// mrak_glitch_body.gdshader
// Glitch-core body for мрак (Sprite2D / ColorRect / AnimatedSprite2D).
//  1) Static pixelation hiding the head (top of the sprite)
//  2) Dim cyan heartbeat pulse of the rusted mechanical heart
//  3) Occasional horizontal tearing
// All tunables are uniforms -> editable in the Inspector (Shader Parameters).
// Driven from Mrak.gd: necrosis, pin, heartbeat_bpm.

shader_type canvas_item;

group_uniforms head_static;
/** Fraction of sprite height (from top) covered by static. */
uniform float head_height : hint_range(0.0, 1.0) = 0.28;
/** Size of the static blocks, in cells across the sprite. */
uniform float pixel_cells : hint_range(4.0, 64.0) = 14.0;
/** Static refresh rate (steps per second). */
uniform float static_fps : hint_range(1.0, 30.0) = 12.0;
/** 0 = head fully hidden, 1 = static fades to see-through. */
uniform float head_transparency : hint_range(0.0, 1.0) = 0.15;

group_uniforms heartbeat;
uniform vec4 pulse_color : source_color = vec4(0.0, 0.9, 0.75, 1.0);
uniform float heartbeat_bpm : hint_range(30.0, 200.0) = 60.0;
/** Brightness added at the peak of a beat. */
uniform float pulse_strength : hint_range(0.0, 1.0) = 0.35;
/** Chest centre in UV space, and radius of the glow. */
uniform vec2 heart_pos = vec2(0.5, 0.45);
uniform float heart_radius : hint_range(0.05, 1.0) = 0.35;

group_uniforms tearing;
/** Seconds between tear windows. */
uniform float tear_interval : hint_range(0.5, 10.0) = 3.5;
/** Fraction of the interval during which the tear is visible. */
uniform float tear_duty : hint_range(0.01, 0.5) = 0.08;
uniform float tear_offset : hint_range(0.0, 0.3) = 0.08;
uniform float tear_bands : hint_range(2.0, 40.0) = 12.0;

group_uniforms decay;
/** 0..1, set from GameManager.necrosis / 100. Scales static + tearing. */
uniform float necrosis : hint_range(0.0, 1.0) = 0.0;
/** 0..1, battery. Low battery makes the pulse flicker. */
uniform float pin_level : hint_range(0.0, 1.0) = 1.0;
/** Desaturate towards grey as necrosis rises. */
uniform float desaturate : hint_range(0.0, 1.0) = 0.6;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

void fragment() {
	vec2 uv = UV;

	// --- 3) Horizontal tearing (time-gated, banded) ---
	float cycle = TIME / tear_interval;
	float phase = fract(cycle);
	float tear_on = step(phase, tear_duty + necrosis * 0.15);
	float band = floor(uv.y * tear_bands);
	float band_rand = hash21(vec2(band, floor(cycle)));
	float shift = (band_rand - 0.5) * 2.0 * tear_offset * tear_on * step(0.55, band_rand);
	uv.x += shift;

	// COLOR already holds vertex tint * texture at UV (works for ColorRect and Sprite2D).
	// Re-sample at the shifted uv and keep the tint.
	vec4 t_here = texture(TEXTURE, UV);
	vec4 t_shift = texture(TEXTURE, uv);
	vec4 tint = COLOR / max(t_here, vec4(0.001));
	vec4 col = t_shift * tint;
	col.a = t_shift.a * clamp(COLOR.a / max(t_here.a, 0.001), 0.0, 1.0);

	// Slight desaturation with necrosis
	float grey = dot(col.rgb, vec3(0.299, 0.587, 0.114));
	col.rgb = mix(col.rgb, vec3(grey), desaturate * necrosis);

	// --- 2) Heartbeat pulse ("lub-dub") ---
	float beat_t = fract(TIME * heartbeat_bpm / 60.0);
	float lub = exp(-pow((beat_t - 0.05) * 18.0, 2.0));
	float dub = exp(-pow((beat_t - 0.28) * 18.0, 2.0)) * 0.6;
	float beat = lub + dub;
	// Low battery -> unstable flicker
	float flicker = mix(step(0.35, hash21(vec2(floor(TIME * 20.0), 3.0))), 1.0, smoothstep(0.1, 0.4, pin_level));
	float glow = smoothstep(heart_radius, 0.0, distance(UV, heart_pos));
	col.rgb += pulse_color.rgb * beat * pulse_strength * glow * flicker * col.a;

	// --- 1) Static pixelation over the head ---
	float head_mask = 1.0 - smoothstep(head_height * 0.8, head_height, UV.y);
	if (head_mask > 0.0) {
		vec2 cell = floor(UV * pixel_cells);
		float step_t = floor(TIME * static_fps);
		float n = hash21(cell + vec2(step_t, step_t * 1.7));
		vec3 noise_col = vec3(mix(0.05, 0.85, n));
		// Slightly more noise as necrosis grows
		float amount = clamp(head_mask * (0.85 + necrosis * 0.15), 0.0, 1.0);
		col.rgb = mix(col.rgb, noise_col, amount);
		col.a *= mix(1.0, head_transparency + (1.0 - head_transparency) * n, amount * head_transparency);
	}

	COLOR = col;
}
