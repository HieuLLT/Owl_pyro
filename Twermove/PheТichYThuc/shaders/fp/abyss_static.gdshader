// abyss_static.gdshader — the bottomless chasm of The Erasure ("vực thẳm nhiễu hạt").
// A huge plane far below the ruins: near-black, with TV static crawling across it in blocks and
// rare red tearing flashes. Unshaded, so only fog and distance shape it.

shader_type spatial;
render_mode unshaded, cull_disabled;

uniform float cell : hint_range(0.2, 6.0) = 1.4;
uniform float strength : hint_range(0.0, 1.0) = 0.22;

varying vec3 w_pos;

float hash31(vec3 p) {
	p = fract(p * vec3(0.1031, 0.1030, 0.0973));
	p += dot(p, p.yxz + 33.33);
	return fract((p.x + p.y) * p.z);
}

void vertex() {
	w_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float tick = floor(TIME * 14.0);
	vec3 c = vec3(floor(w_pos.x / cell), floor(w_pos.z / cell), tick);
	float n = hash31(c);
	float blocks = step(0.62, n) * (0.4 + 0.6 * hash31(c + 9.0));
	// slow dark swells
	float swell = 0.5 + 0.5 * sin(w_pos.x * 0.07 + TIME * 0.4) * sin(w_pos.z * 0.05 - TIME * 0.3);
	// rare red tear lines
	float tear = step(0.985, hash31(vec3(floor(w_pos.z / (cell * 0.5)), tick, 3.0)));
	vec3 col = vec3(blocks * strength * swell);
	col += vec3(0.8, 0.02, 0.02) * tear * 0.35;
	ALBEDO = col;
}
