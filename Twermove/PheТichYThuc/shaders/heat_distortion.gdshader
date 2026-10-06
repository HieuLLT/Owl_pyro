// heat_distortion.gdshader
// Ripple distortion around мрак's Heat Core when thermal > 70°C.
// Applied to the ThermalCore Sprite2D as a local ShaderMaterial.

shader_type canvas_item;

uniform float heat_intensity: hint_range(0.0, 1.0) = 0.0;
uniform float ripple_speed: hint_range(0.5, 8.0) = 3.0;
uniform float ripple_scale: hint_range(1.0, 20.0) = 8.0;

void fragment() {
	float t = TIME * ripple_speed;

	// Radial ripple from center
	vec2 centered = UV - vec2(0.5);
	float dist = length(centered);

	float ripple = sin(dist * ripple_scale - t) * heat_intensity * 0.015;
	vec2 offset = normalize(centered + vec2(0.001)) * ripple;

	vec4 col = texture(TEXTURE, UV + offset);
	COLOR = col;
}
