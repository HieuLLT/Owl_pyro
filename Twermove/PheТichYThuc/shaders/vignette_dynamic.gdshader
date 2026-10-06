// vignette_dynamic.gdshader
// Fullscreen vignette that tightens as мрак's necrosis increases.
// At necrosis 100%, nearly the entire screen is consumed by darkness.

shader_type canvas_item;

uniform float necrosis_level: hint_range(0.0, 1.0) = 0.0;
uniform float base_strength: hint_range(0.0, 3.0) = 0.6;

void fragment() {
	vec4 col = texture(TEXTURE, UV);

	vec2 center = UV - vec2(0.5);

	// Base vignette + necrosis bonus
	float radius = dot(center, center);
	float vignette_power = base_strength + necrosis_level * 3.5;
	float vignette = 1.0 - radius * vignette_power;

	// Pulsing at high necrosis (breathing darkness)
	float pulse = sin(TIME * 1.2) * 0.04 * necrosis_level;
	vignette -= pulse;

	col.rgb *= clamp(vignette, 0.0, 1.0);
	COLOR = col;
}
