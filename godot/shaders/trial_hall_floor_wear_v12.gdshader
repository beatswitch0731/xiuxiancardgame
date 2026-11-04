shader_type spatial;
render_mode cull_disabled;

// A local material study on the existing V6 hall mesh. The scanned stone
// remains the source of fine grain; the mask changes only the walked lane.
uniform sampler2D slate_color : source_color, repeat_enable, filter_linear_mipmap;
uniform sampler2D slate_rough : repeat_enable, filter_linear_mipmap;
uniform sampler2D slate_normal : hint_normal, repeat_enable, filter_linear_mipmap;
uniform sampler2D worn_color : source_color, repeat_enable, filter_linear_mipmap;
uniform sampler2D worn_rough : repeat_enable, filter_linear_mipmap;
uniform sampler2D worn_normal : hint_normal, repeat_enable, filter_linear_mipmap;
uniform vec3 slate_tint : source_color = vec3(0.69, 0.71, 0.72);
uniform vec3 worn_tint : source_color = vec3(0.76, 0.73, 0.67);
uniform float lane_strength : hint_range(0.0, 1.0) = 0.29;

varying vec3 floor_position;

void vertex() {
	floor_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 uv = UV;
	// Low-frequency changes follow where the trainee and wooden dummy stand;
	// they do not add a regular second set of stone joints.
	float grain = texture(slate_color, uv * 0.23 + vec2(0.17, 0.38)).r;
	float edge = abs(floor_position.z + 0.08) + (grain - 0.5) * 0.54;
	float across = 1.0 - smoothstep(1.14, 2.05, edge);
	float along = 1.0 - smoothstep(2.6, 4.55, abs(floor_position.x));
	float wear = lane_strength * across * along;
	vec2 worn_uv = vec2(uv.y * 0.89 + 0.29, uv.x * 1.07 + 0.41);
	vec3 slate = texture(slate_color, uv).rgb * slate_tint;
	vec3 worn = texture(worn_color, worn_uv).rgb * worn_tint;
	ALBEDO = mix(slate, worn, wear);
	ROUGHNESS = clamp(mix(texture(slate_rough, uv).r, texture(worn_rough, worn_uv).r, wear), 0.48, 0.94);
	NORMAL_MAP = mix(texture(slate_normal, uv).rgb, texture(worn_normal, worn_uv).rgb, wear);
	NORMAL_MAP_DEPTH = 0.72;
}
