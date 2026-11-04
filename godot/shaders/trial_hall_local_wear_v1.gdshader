shader_type spatial;
render_mode cull_disabled;

// Candidate only. Retain the single scanned slate surface and change its
// response where repeated footwork would abrade the stone. No dark decal.
uniform sampler2D slate_color : source_color, repeat_enable, filter_linear_mipmap;
uniform sampler2D slate_rough : repeat_enable, filter_linear_mipmap;
uniform sampler2D slate_normal : hint_normal, repeat_enable, filter_linear_mipmap;
uniform vec3 slate_tint : source_color = vec3(0.95, 0.98, 1.0);

varying vec3 floor_world;

void vertex() {
	floor_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 uv = UV;
	vec3 stone = texture(slate_color, uv).rgb * slate_tint;
	float source_rough = texture(slate_rough, uv).r;
	vec2 floor_xz = floor_world.xz;
	float left_footwork = length((floor_xz - vec2(-2.3, 0.15)) * vec2(0.82, 1.8));
	float right_footwork = length((floor_xz - vec2(2.3, -0.25)) * vec2(0.82, 1.8));
	float crossing = length((floor_xz - vec2(-0.10, -0.08)) * vec2(0.58, 2.6));
	float chipped_grain = texture(slate_color, uv * 0.49 + vec2(0.13, 0.31)).r;
	float irregular = (chipped_grain - 0.5) * 0.31;
	float foot_mask = 1.0 - smoothstep(0.65, 1.10, min(left_footwork, right_footwork) + irregular);
	float crossing_mask = 1.0 - smoothstep(0.48, 0.78, crossing + irregular);
	float wear = max(foot_mask * 0.36, crossing_mask * 0.15);
	// Keep the same stone hue and normal map. Abrasion reads from roughness and
	// a restrained warm, exposed-mineral change under the existing lamps.
	ALBEDO = stone * (1.0 + vec3(0.065, 0.038, 0.018) * wear);
	ROUGHNESS = clamp(mix(source_rough, 0.73, wear), 0.42, 0.94);
	NORMAL_MAP = texture(slate_normal, uv).rgb;
	NORMAL_MAP_DEPTH = 0.72;
}
