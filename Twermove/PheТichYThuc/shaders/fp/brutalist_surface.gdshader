// brutalist_surface.gdshader — world-space triplanar concrete / rust / mesh.
// No UVs needed, so plain BoxMesh slabs of any size tile cleanly.
// Also the victim of The Erasure: pixels near (erase_center, erase_radius) are eaten away,
// leaving a ragged, static-lit edge and the black void behind. Driven by ErasureVoid3D.gd.

shader_type spatial;
render_mode cull_back;

uniform sampler2D albedo_tex : source_color, repeat_enable, filter_linear_mipmap;
uniform vec4 tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float uv_scale : hint_range(0.05, 2.0) = 0.35;
uniform float roughness_val : hint_range(0.0, 1.0) = 0.92;
uniform float metallic_val : hint_range(0.0, 1.0) = 0.0;

group_uniforms erasure;
uniform vec3 erase_center = vec3(0.0, -1000.0, 0.0);
uniform float erase_radius = 0.0;
uniform vec4 edge_color : source_color = vec4(0.9, 0.05, 0.05, 1.0);

varying vec3 w_pos;
varying vec3 w_nrm;

float hash31(vec3 p) {
	p = fract(p * vec3(0.1031, 0.1030, 0.0973));
	p += dot(p, p.yxz + 33.33);
	return fract((p.x + p.y) * p.z);
}

float vnoise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = mix(mix(hash31(i), hash31(i + vec3(1, 0, 0)), f.x),
	              mix(hash31(i + vec3(0, 1, 0)), hash31(i + vec3(1, 1, 0)), f.x), f.y);
	float b = mix(mix(hash31(i + vec3(0, 0, 1)), hash31(i + vec3(1, 0, 1)), f.x),
	              mix(hash31(i + vec3(0, 1, 1)), hash31(i + vec3(1, 1, 1)), f.x), f.y);
	return mix(a, b, f.z);
}

void vertex() {
	w_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	w_nrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	// Triplanar sampling
	vec3 n = pow(abs(w_nrm), vec3(4.0));
	n /= (n.x + n.y + n.z);
	vec3 col = texture(albedo_tex, w_pos.zy * uv_scale).rgb * n.x
	         + texture(albedo_tex, w_pos.xz * uv_scale).rgb * n.y
	         + texture(albedo_tex, w_pos.xy * uv_scale).rgb * n.z;
	ALBEDO = col * tint.rgb;
	ROUGHNESS = roughness_val;
	METALLIC = metallic_val;

	// The Erasure eats space
	if (erase_radius > 0.01) {
		float d = distance(w_pos, erase_center);
		float jag = (vnoise(w_pos * 5.0 + floor(TIME * 10.0)) - 0.5) * 0.9;
		float edge = erase_radius + jag;
		if (d < edge) {
			discard;
		}
		float band = 1.0 - smoothstep(0.0, 0.35, d - edge);
		float stat = step(0.5, hash31(floor(w_pos * 24.0) + floor(TIME * 24.0)));
		EMISSION = mix(edge_color.rgb, vec3(1.0), stat) * band * 1.4;
	}
}
