// arm_compass.gdshader — the necrotic arm in the lower-left of the first-person view.
// Grey dead flesh with black root-veins; the compass light under the skin glows a faint
// steady blue, and turns erratic red as `interference` rises (the compass is deceiving you).

shader_type spatial;
render_mode cull_back;

uniform vec4 flesh_color : source_color = vec4(0.42, 0.44, 0.46, 1.0);
uniform vec4 blue_light : source_color = vec4(0.1, 0.55, 1.0, 1.0);
uniform vec4 red_light : source_color = vec4(1.0, 0.08, 0.05, 1.0);
/** 0 = honest blue, 1 = lying red. */
uniform float interference : hint_range(0.0, 1.0) = 0.0;
/** Overall glow strength (raised by the Vestige Needle toggle). */
uniform float glow : hint_range(0.0, 3.0) = 0.6;
/** Heartbeat kick, 0..1, pushed from FPController. */
uniform float beat : hint_range(0.0, 1.0) = 0.0;

varying vec3 obj_pos;

float hash11(float x) {
	return fract(sin(x * 127.1) * 43758.5453);
}

void vertex() {
	obj_pos = VERTEX;
}

void fragment() {
	// Black root veins crawling over the skin
	float vein_a = abs(sin(obj_pos.y * 38.0 + sin(obj_pos.x * 22.0) * 2.5));
	float vein_b = abs(sin(obj_pos.x * 31.0 - obj_pos.z * 27.0 + obj_pos.y * 9.0));
	float vein = 1.0 - smoothstep(0.0, 0.12, min(vein_a, vein_b));
	vec3 skin = mix(flesh_color.rgb, vec3(0.02), vein * 0.85);
	ALBEDO = skin;
	ROUGHNESS = 0.85;

	// Erratic flicker: stepped random per ~14 fps tick, stronger with interference
	float tick = floor(TIME * 14.0);
	float flick = mix(1.0, 0.25 + 0.9 * hash11(tick), interference);
	vec3 lc = mix(blue_light.rgb, red_light.rgb, smoothstep(0.15, 0.85, interference + 0.15 * (hash11(tick + 3.0) - 0.5)));
	// Light lives in the veins and glows a bit everywhere
	float under = vein * 1.4 + 0.12;
	EMISSION = lc * under * glow * flick * (1.0 + beat * 1.5) + skin * 0.14;   // faint self-glow so the arm never vanishes in the dark
}
