shader_type spatial;
render_mode cull_disabled;

// Runs only on three small meshes with UVs identical to the scanned floor.
// Their outer edge reproduces the original material; narrow scratched grains
// read at combat distance without an oval color decal.
uniform sampler2D stone_color : source_color, repeat_enable, filter_linear_mipmap;
uniform sampler2D stone_rough : repeat_enable, filter_linear_mipmap;
uniform sampler2D stone_normal : hint_normal, repeat_enable, filter_linear_mipmap;
uniform vec2 scar_center = vec2(0.0, 0.0);
uniform float scar_seed = 0.0;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world_pos.xz - scar_center;
	vec3 stone = texture(stone_color, UV).rgb;
	float source_rough = texture(stone_rough, UV).g;
	float grain = texture(stone_color, UV * 1.73 + vec2(scar_seed * 0.17, 0.11)).r;
	float broken = smoothstep(0.18, 0.43, grain);
	float window = smoothstep(-0.29, -0.18, p.x) * (1.0 - smoothstep(0.15, 0.29, p.x));
	float line_a = 1.0 - smoothstep(0.019, 0.051, abs(p.y + 0.055 * sin(p.x * 14.0 + scar_seed)));
	float line_b = 1.0 - smoothstep(0.014, 0.039, abs(p.y - 0.071 + 0.028 * sin(p.x * 18.0 + scar_seed * 2.0)));
	float edge_fade = 1.0 - smoothstep(0.27, 0.37, length(p * vec2(1.0, 1.6)));
	float scratch = max(line_a * 0.84, line_b * 0.58) * broken * window * edge_fade;
	ALBEDO = stone * (1.0 - 0.43 * scratch);
	ROUGHNESS = clamp(mix(source_rough, 0.82, scratch * 0.38), 0.04, 1.0);
	NORMAL_MAP = texture(stone_normal, UV).rgb;
	NORMAL_MAP_DEPTH = 0.72;
}
