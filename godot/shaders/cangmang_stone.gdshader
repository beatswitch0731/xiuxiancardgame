shader_type spatial;
render_mode diffuse_toon, specular_disabled, cull_disabled;

uniform sampler2D stone_albedo : source_color, filter_nearest, repeat_enable;
uniform float tile_count = 8.0;
uniform vec3 stone_tint : source_color = vec3(0.72, 0.72, 0.72);

varying float world_depth;

void vertex() {
	world_depth = (MODEL_MATRIX * vec4(VERTEX, 1.0)).z;
}

void fragment() {
	// A two-pixel hard cluster lets the source-painted courtyard show through
	// near the rear of the true 3D floor without a soft blur or straight seam.
	float fade = smoothstep(-6.3, -4.25, world_depth);
	float gx = floor(FRAGCOORD.x / 2.0);
	float gy = floor(FRAGCOORD.y / 2.0);
	float threshold = mod(gx + 2.0 * gy, 4.0) / 4.0;
	if (fade < threshold) {
		discard;
	}
	ALBEDO = texture(stone_albedo, UV * tile_count).rgb * stone_tint;
}
