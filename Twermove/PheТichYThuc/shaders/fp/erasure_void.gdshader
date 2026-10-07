// erasure_void.gdshader — the black hole itself ("Sự Xâm Thực").
// Put on a sphere mesh. Pure black body whose silhouette is shredded by moving noise,
// ringed by TV static at the rim. Cull is disabled so you see it from inside too.

shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_opaque;

uniform float shred : hint_range(0.0, 1.0) = 0.35;
uniform vec4 rim_color : source_color = vec4(0.95, 0.1, 0.1, 1.0);
uniform float rim_width : hint_range(0.02, 0.6) = 0.22;

varying vec3 w_pos;
varying vec3 obj_pos;

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
	obj_pos = VERTEX;
	w_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	// Jittery, hungry surface
	float j = vnoise(VERTEX * 3.0 + floor(TIME * 8.0)) - 0.5;
	VERTEX += NORMAL * j * shred * 0.5;
}

void fragment() {
	float n = vnoise(obj_pos * 4.0 + vec3(0.0, TIME * 1.5, 0.0));
	// Fresnel-ish rim from view angle
	float rim = pow(1.0 - clamp(abs(dot(normalize(NORMAL), normalize(VIEW))), 0.0, 1.0), 2.0);
	if (n < shred * rim * 0.9) {
		discard;
	}
	float stat = step(0.5, hash31(floor(w_pos * 28.0) + floor(TIME * 30.0)));
	float band = smoothstep(1.0 - rim_width * 3.0, 1.0, rim);
	vec3 c = mix(vec3(0.0), mix(rim_color.rgb, vec3(1.0), stat), band);
	ALBEDO = c;
}
