// phantom_dissolve.gdshader
// Bóng Đen Quá Khứ (Phantom): a figure made of broken pixel blocks.
// Works on a ColorRect (uses COLOR as the base tint). `dissolve` 0..1 erases blocks;
// the leading edge glows cyan (the Vestige Needle draining the data).

shader_type canvas_item;

uniform float dissolve : hint_range(0.0, 1.0) = 0.0;
uniform float cells : hint_range(4.0, 32.0) = 10.0;
/** How often whole rows slide sideways (glitch). */
uniform float row_glitch : hint_range(0.0, 1.0) = 0.25;
uniform vec4 edge_color : source_color = vec4(0.0, 0.9, 0.75, 1.0);

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

void fragment() {
	vec2 grid = vec2(cells, cells * 2.0);          // figure is ~2x taller than wide
	vec2 c = floor(UV * grid);

	// Rows occasionally slide sideways
	float step_t = floor(TIME * 8.0);
	float slide = step(1.0 - row_glitch * 0.25, hash21(vec2(step_t, c.y)));
	c.x += slide * floor((hash21(vec2(c.y, step_t)) - 0.5) * 4.0);

	float n = hash21(c);
	if (n < dissolve) {
		discard;
	}

	// Flickering block brightness
	float flick = 0.55 + 0.45 * hash21(c + floor(TIME * 10.0));
	vec3 col = COLOR.rgb * flick;

	// Cyan leading edge while dissolving
	float edge = 1.0 - smoothstep(dissolve, dissolve + 0.12, n);
	col = mix(col, edge_color.rgb, edge * step(0.001, dissolve));

	COLOR = vec4(col, COLOR.a);
}
