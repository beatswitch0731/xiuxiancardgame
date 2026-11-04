shader_type canvas_item;
render_mode unshaded;

// Reuse the authored status-plaque weave. The card is cut from the same
// blue-black cloth, with only a restrained brass/jade raking light on hover.
uniform sampler2D weave_texture : source_color, filter_linear_mipmap;
uniform vec4 accent_color : source_color = vec4(0.70, 0.57, 0.34, 1.0);
uniform vec2 face_size = vec2(100.0, 150.0);
uniform float hover_strength : hint_range(0.0, 1.0) = 0.0;
uniform float light_x : hint_range(0.0, 1.0) = 0.5;
uniform float available : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	vec2 uv = UV;
	// The middle of the plaque has uninterrupted woven texture. Sampling a
	// narrow upright piece preserves its actual grain instead of stretching a
	// horizontal frame across a portrait card.
	vec2 weave_uv = vec2(0.5 + (uv.x - 0.5) * 0.105, 0.19 + uv.y * 0.63);
	vec3 cloth = texture(weave_texture, weave_uv).rgb;
	vec3 ink = mix(cloth, vec3(0.095, 0.125, 0.135), 0.32);
	ink *= mix(1.26, 0.98, uv.y);

	vec2 edge_px = min(uv, vec2(1.0) - uv) * face_size;
	float edge = min(edge_px.x, edge_px.y);
	float inner_bevel = 1.0 - smoothstep(0.45, 2.3, edge);
	float upper_edge = 1.0 - smoothstep(0.0, 0.10, uv.y);
	float lower_edge = smoothstep(0.90, 1.0, uv.y);
	float upper_left = (1.0 - uv.x) * (1.0 - uv.y);
	ink = mix(ink, accent_color.rgb * 0.66, inner_bevel * (0.33 + 0.18 * upper_left + 0.13 * hover_strength));
	ink += accent_color.rgb * upper_edge * 0.045;
	ink *= 1.0 - lower_edge * 0.11;

	// A broad reflection follows the pointer. It is confined to the card
	// stock, leaving the illustrated scene and glyphs unfiltered.
	float diagonal = uv.x - light_x + (uv.y - 0.5) * 0.16;
	float reflection = pow(max(0.0, 1.0 - abs(diagonal) * 2.2), 5.0);
	ink += accent_color.rgb * reflection * hover_strength * 0.19;
	ink *= mix(0.70, 1.0, available);
	COLOR = vec4(ink, 1.0);
}
