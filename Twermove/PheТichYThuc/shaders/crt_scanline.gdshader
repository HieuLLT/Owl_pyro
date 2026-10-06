// crt_scanline.gdshader
// Subtle CRT scanline overlay — applied to the root CanvasLayer.
// Evokes the feeling of viewing мрак's world through a failing monitor.

shader_type canvas_item;

uniform float intensity: hint_range(0.0, 1.0) = 0.12;
uniform float scanline_count: hint_range(80.0, 500.0) = 220.0;
uniform float vignette_strength: hint_range(0.0, 2.0) = 0.35;

void fragment() {
	vec4 col = texture(TEXTURE, UV);

	// Scanline pattern
	float scanline = sin(UV.y * scanline_count * PI) * 0.5 + 0.5;
	col.rgb *= mix(1.0, scanline, intensity);

	// Subtle vignette baked in
	vec2 center = UV - vec2(0.5);
	float vignette = 1.0 - dot(center, center) * vignette_strength;
	col.rgb *= clamp(vignette, 0.0, 1.0);

	COLOR = col;
}
