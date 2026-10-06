// crt_scanline.gdshader
// Subtle CRT scanline overlay — for a fullscreen ColorRect (SchizophrenicUI/CRTOverlay).
// Evokes the feeling of viewing мрак's world through a failing monitor.
// Outputs a black overlay: dark scanline bands + a soft baked-in vignette (alpha only),
// so it needs no texture and never washes the screen white.

shader_type canvas_item;

uniform float intensity: hint_range(0.0, 1.0) = 0.12;
uniform float scanline_count: hint_range(80.0, 500.0) = 220.0;
uniform float vignette_strength: hint_range(0.0, 2.0) = 0.35;
/** Slow vertical drift of the bands (0 = static). */
uniform float roll_speed: hint_range(0.0, 1.0) = 0.03;

void fragment() {
	// Scanline pattern: 0 = bright line, 1 = dark gap
	float scan = sin((UV.y + TIME * roll_speed) * scanline_count * PI) * 0.5 + 0.5;
	float scan_alpha = (1.0 - scan) * intensity;

	// Baked vignette
	vec2 center = UV - vec2(0.5);
	float vig_alpha = clamp(dot(center, center) * vignette_strength, 0.0, 1.0);

	COLOR = vec4(0.0, 0.0, 0.0, clamp(scan_alpha + vig_alpha, 0.0, 1.0));
}
