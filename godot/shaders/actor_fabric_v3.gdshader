shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform sampler2D fabric_albedo : source_color, filter_linear_mipmap, repeat_enable;
uniform vec4 dye : source_color = vec4(0.24, 0.29, 0.33, 1.0);
uniform float grain_strength : hint_range(0.0, 0.3) = 0.12;

void fragment() {
	vec3 weave = texture(fabric_albedo, UV).rgb;
	float value = dot(weave, vec3(0.2126, 0.7152, 0.0722));
	float fiber = clamp(value / 0.065, 0.65, 1.35);
	ALBEDO = dye.rgb * mix(1.0, fiber, grain_strength);
	ROUGHNESS = 0.9;
	SPECULAR = 0.2;
}
