shader_type spatial;
render_mode diffuse_lambert, specular_disabled, cull_disabled;

// Project the browser's existing trial-yard painting back onto a native 3D
// floor. It keeps the painted sword ring aligned while the mesh receives
// dynamic actor, brazier and impact light.
uniform sampler2D source_albedo : source_color, filter_nearest;
uniform vec3 painting_plane = vec3(29.0, 16.3125, -6.1);
uniform float painting_center_y = 0.6;
uniform float contact_glow : hint_range(0.0, 1.0) = 0.0;
varying vec3 floor_world_position;

void vertex() {
	floor_world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 sight = normalize(floor_world_position - CAMERA_POSITION_WORLD);
	float distance_to_painting = (painting_plane.z - CAMERA_POSITION_WORLD.z) / sight.z;
	vec3 painted_point = CAMERA_POSITION_WORLD + sight * distance_to_painting;
	vec2 painting_uv = vec2(
		painted_point.x / painting_plane.x + 0.5,
		0.5 - (painted_point.y - painting_center_y) / painting_plane.y
	);
	vec3 painted_court = texture(source_albedo, clamp(painting_uv, vec2(0.0), vec2(1.0))).rgb;
	vec2 from_contact = floor_world_position.xz - vec2(2.35, 0.45);
	float warm_pool = exp(-dot(from_contact, from_contact) / 4.5) * contact_glow;
	ALBEDO = painted_court * 0.44;
	EMISSION = painted_court * 0.62 + vec3(0.76, 0.42, 0.19) * warm_pool * 0.48;
	ROUGHNESS = 0.85;
}
