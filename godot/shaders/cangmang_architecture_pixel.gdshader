shader_type spatial;
render_mode diffuse_toon, specular_disabled;

uniform vec4 base_color : source_color = vec4(0.22, 0.27, 0.29, 1.0);
uniform vec2 cells = vec2(12.0, 6.0);
uniform float seam_strength : hint_range(0.0, 0.5) = 0.2;
uniform bool timber_grain = false;

float cell_hash(vec2 cell) {
	return fract(sin(dot(cell, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 cell = floor(UV * cells);
	float grain = cell_hash(cell);
	float variation = mix(0.83, 1.11, grain);
	float seam = 0.0;
	if (timber_grain) {
		seam = step(fract(UV.x * cells.x), 0.075) * 0.62;
		variation *= mix(0.94, 1.04, cell_hash(vec2(cell.y, cell.x + 17.0)));
	} else {
		float stagger = mod(cell.y, 2.0) * 0.5;
		seam = max(step(fract(UV.y * cells.y), 0.075),
			step(fract(UV.x * cells.x + stagger), 0.055));
	}
	ALBEDO = base_color.rgb * variation * (1.0 - seam * seam_strength);
	ROUGHNESS = 1.0;
}
