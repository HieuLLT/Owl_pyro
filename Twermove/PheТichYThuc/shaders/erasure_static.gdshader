// erasure_static.gdshader
// "Sự Xâm Thực" (The Erasure): a hole in reality made of black/grey TV static,
// with jagged, eroding (dissolve) edges.
//
// Performance notes: no texture lookups, only a few hash() calls per pixel.
// Noise is computed in WORLD space on a coarse grid, so the cost does not grow
// with the size of the node and large ColorRect / Polygon2D / TileMap areas stay cheap.
//
// Edge erosion uses UV distance to the node border -> best on ColorRect / Sprite2D.
// For Polygon2D set its UVs to the 0..1 bounding box (or keep edge_erosion = 0).

shader_type canvas_item;
render_mode blend_mix, unshaded;

group_uniforms look;
uniform vec4 dark_color : source_color = vec4(0.02, 0.02, 0.03, 1.0);
uniform vec4 light_color : source_color = vec4(0.62, 0.62, 0.66, 1.0);
/** Size of a static block in world pixels. */
uniform float block_size : hint_range(1.0, 16.0) = 3.0;
/** Static refresh rate (steps/second). Lower = cheaper looking, more "stuttery". */
uniform float static_fps : hint_range(1.0, 60.0) = 24.0;
/** 0 = mostly black void, 1 = bright white noise. */
uniform float brightness : hint_range(0.0, 1.0) = 0.35;
uniform float opacity : hint_range(0.0, 1.0) = 1.0;

group_uniforms edge;
/** Width of the eroding border, in UV units (0.0 disables). */
uniform float edge_erosion : hint_range(0.0, 0.5) = 0.12;
/** Block size of the jagged edge mask, in world pixels. */
uniform float edge_block : hint_range(2.0, 32.0) = 8.0;
/** How fast the edge eats inward (units/second of "breathing"). */
uniform float edge_speed : hint_range(0.0, 4.0) = 1.2;
/** Static-coloured fringe just inside the dissolved border. */
uniform float fringe : hint_range(0.0, 0.2) = 0.04;

group_uniforms horizontal_roll;
uniform float roll_strength : hint_range(0.0, 1.0) = 0.25;
uniform float roll_speed : hint_range(0.0, 8.0) = 1.5;

varying vec2 world_pos;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	float t = floor(TIME * static_fps);

	// --- TV static on a coarse world-space grid ---
	vec2 cell = floor(world_pos / block_size);
	// Scrolling horizontal roll bands (a bit of "bad signal")
	float roll = step(0.85, fract(world_pos.y / 180.0 - TIME * roll_speed * 0.15));
	cell.x += roll * floor(hash21(vec2(t, floor(world_pos.y / 12.0))) * 6.0) * roll_strength * 4.0;

	float n = hash21(cell + vec2(t * 1.31, t * 0.73));
	// Bias toward dark so it reads as a void with static, not a TV screen
	float v = pow(n, mix(3.0, 0.6, brightness));
	vec3 col = mix(dark_color.rgb, light_color.rgb, v);

	// --- Jagged, eroding edge (dissolve) ---
	float alpha = opacity;
	if (edge_erosion > 0.0) {
		vec2 d = min(UV, 1.0 - UV);              // distance to each border
		float border = min(d.x, d.y);             // 0 at the edge, 0.5 in the centre
		vec2 ecell = floor(world_pos / edge_block);
		float en = hash21(ecell + vec2(floor(TIME * 6.0), 7.0));
		// Threshold sweeps in and out so the border "breathes"
		float breathe = 0.5 + 0.5 * sin(TIME * edge_speed + en * 6.2831);
		float threshold = edge_erosion * (0.35 + 0.65 * breathe) * en * 2.0;
		if (border < threshold) {
			discard;
		}
		// Fringe: bright static right inside the eaten border
		float f = smoothstep(threshold + fringe, threshold, border);
		col = mix(col, light_color.rgb, f * 0.9);
	}

	COLOR = vec4(col, alpha);
}
