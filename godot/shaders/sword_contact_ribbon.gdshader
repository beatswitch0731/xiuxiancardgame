shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_add;

uniform vec4 ribbon_color : source_color = vec4(0.75, 0.86, 0.83, 0.9);
uniform float opacity : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	ALBEDO = ribbon_color.rgb;
	EMISSION = ribbon_color.rgb * 0.8;
	ALPHA = ribbon_color.a * opacity;
}
