// pixel_dissolve.gdshader
// мрак dissolves into scattered pixels on death.
// progress: 0.0 = intact, 1.0 = fully dissolved.
// Applied to мрак's AnimatedSprite2D on death.

shader_type canvas_item;

uniform float progress: hint_range(0.0, 1.0) = 0.0;
uniform sampler2D noise_texture: hint_default_white;
uniform vec4 dissolve_color: source_color = vec4(0.0, 1.0, 0.8, 1.0); // Cyan core color

void fragment() {
	vec4 col = texture(TEXTURE, UV);

	float noise = texture(noise_texture, UV).r;

	// Threshold-based pixel drop
	if (noise < progress) {
		discard;  // Pixel removed — dissolved
	}

	// Edge glow as pixel dissolves
	float edge = smoothstep(progress, progress + 0.08, noise);
	col.rgb = mix(dissolve_color.rgb, col.rgb, edge);

	// Scatter effect: remaining pixels shift slightly
	float scatter = (1.0 - edge) * progress * 0.03;
	col = texture(TEXTURE, UV + vec2(scatter, scatter * 0.5));

	COLOR = col;
}
