// fp_visor.gdshader — the view through a BROKEN, BLACKENED DIVING HELMET.
// Fullscreen ColorRect over the 3D view:
//  * irregular black rim: the corners of the view are swallowed (soot / dead glass), the edge
//    wobbling with low-frequency noise, never a clean oval
//  * cracks radiating from two impact points: thin pale lines that catch light, with the picture
//    refracted/offset along them
//  * missing shards: some glass cells near the impacts are simply black
//  * faint condensation near the rim that breathes
// `damage` (0..1, from necrosis) grows the black rim and the number of missing shards.

shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, repeat_disable, filter_linear;

uniform float damage : hint_range(0.0, 1.0) = 0.2;
uniform float rim_start : hint_range(0.2, 0.9) = 0.50;
uniform float rim_softness : hint_range(0.02, 0.5) = 0.18;
uniform vec2 impact_a = vec2(0.84, 0.20);
uniform vec2 impact_b = vec2(0.14, 0.80);
uniform float crack_scale : hint_range(3.0, 30.0) = 9.0;
uniform float breath : hint_range(0.0, 1.0) = 0.0;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

vec2 hash22(vec2 p) {
	return vec2(hash21(p), hash21(p + vec2(17.1, 9.7)));
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash21(i), hash21(i + vec2(1, 0)), f.x), mix(hash21(i + vec2(0, 1)), hash21(i + vec2(1, 1)), f.x), f.y);
}

// Voronoi: x = distance to nearest feature, y = distance to second nearest, z = nearest cell id hash
vec3 voronoi(vec2 p) {
	vec2 ip = floor(p);
	vec2 fp = fract(p);
	float d1 = 8.0;
	float d2 = 8.0;
	float id = 0.0;
	for (int j = -1; j <= 1; j++) {
		for (int i = -1; i <= 1; i++) {
			vec2 g = vec2(float(i), float(j));
			vec2 o = hash22(ip + g);
			float d = length(g + o - fp);
			if (d < d1) {
				d2 = d1;
				d1 = d;
				id = hash21(ip + g + 3.1);
			} else if (d < d2) {
				d2 = d;
			}
		}
	}
	return vec3(d1, d2, id);
}

// How strongly a crack field applies at uv: strongest near the impact, fading outward,
// and only along ~60% of the angles (cracks fan out, they do not circle).
float crack_zone(vec2 uv, vec2 impact, float reach) {
	vec2 d = uv - impact;
	d.x *= 1.78;
	float r = length(d);
	float ang = atan(d.y, d.x);
	float fan = smoothstep(0.35, 0.75, vnoise(vec2(ang * 2.2, 3.0 + impact.x * 10.0)));
	return (1.0 - smoothstep(0.05, reach, r)) * mix(0.35, 1.0, fan);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 c = uv - vec2(0.5);
	c.x *= 1.78;

	// Wobbly black rim
	float wob = (vnoise(uv * 3.5 + 7.0) - 0.5) * 0.30 + (vnoise(uv * 11.0) - 0.5) * 0.07;
	float d = length(c * vec2(0.62, 1.0)) + wob;
	float rim = smoothstep(rim_start - damage * 0.12, rim_start - damage * 0.12 + rim_softness, d);

	// Cracks
	float zone = max(crack_zone(uv, impact_a, 0.44), crack_zone(uv, impact_b, 0.30));
	vec2 vp = uv * vec2(1.78, 1.0) * crack_scale;
	vec3 v = voronoi(vp);
	float line = 1.0 - smoothstep(0.0, 0.045, v.y - v.x);        // thin lines on cell borders
	float crack = line * zone;
	float shard_gone = step(1.0 - (0.10 + damage * 0.35), v.z) * smoothstep(0.35, 0.9, zone);

	// Refraction: the picture jumps along cracks
	vec2 off = (hash22(floor(vp) + 5.0) - 0.5) * 0.02 * zone;
	vec3 col = texture(screen_tex, uv + off * (0.4 + crack)).rgb;

	// Condensation near the rim, breathing
	float fog = smoothstep(0.30, 0.65, d) * (0.10 + 0.10 * breath) * (0.6 + 0.4 * vnoise(uv * 6.0 + TIME * 0.05));
	col = mix(col, vec3(0.45, 0.52, 0.55), fog);

	// Cracks catch the red light
	col += vec3(0.75, 0.82, 0.9) * crack * 0.55;
	col *= 1.0 - crack * 0.15;

	// Missing shards, then the black rim
	col = mix(col, vec3(0.0), shard_gone);
	col = mix(col, vec3(0.0), rim);

	COLOR = vec4(col, 1.0);
}
