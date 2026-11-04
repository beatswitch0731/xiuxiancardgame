shader_type spatial;
render_mode specular_schlick_ggx, cull_back;

uniform vec4 base_tint : source_color = vec4(0.40, 0.49, 0.53, 1.0);
uniform float wetness : hint_range(0.0, 1.0) = 0.35;

varying vec3 world_position;

float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float value_noise(vec2 p) {
	vec2 cell = floor(p);
	vec2 fraction = fract(p);
	fraction = fraction * fraction * (3.0 - 2.0 * fraction);
	float a = hash21(cell);
	float b = hash21(cell + vec2(1.0, 0.0));
	float c = hash21(cell + vec2(0.0, 1.0));
	float d = hash21(cell + vec2(1.0, 1.0));
	return mix(mix(a, b, fraction.x), mix(c, d, fraction.x), fraction.y);
}

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float broad = value_noise(world_position.xz * 0.78);
	float grain = value_noise(world_position.xz * 9.0 + world_position.y * 2.7);
	float wear = clamp((broad * 0.60 + grain * 0.40), 0.0, 1.0);
	// Restricted tonal steps keep the native material compatible with the
	// source game's pixel palette, while the relief remains fully 3D.
	float tone = floor((0.80 + wear * 0.37) * 11.0) / 11.0;
	float rain_dark = mix(1.0, 0.88, wetness);
	ALBEDO = base_tint.rgb * tone * rain_dark;
	ROUGHNESS = mix(0.76, 0.28, wetness) + (grain - 0.5) * 0.14;
	METALLIC = wetness * 0.07;
	SPECULAR = mix(0.35, 0.56, wetness);
}
