shader_type canvas_item;

// FX Dissolve -- 消散（defeat 模板）：噪声阈值裁切 + 边缘发光带。
// 用法：dissolve_progress 从 0.0 推到 1.0，1.0 = 完全消失。
// noise_tex 用 NoiseTexture2D（FastNoiseLite 程序生成，无需外部文件）。

uniform float dissolve_progress : hint_range(0.0, 1.0) = 0.0;
uniform sampler2D noise_tex : repeat_enable;
uniform float edge_width : hint_range(0.0, 0.2) = 0.06;
uniform vec4 edge_color : source_color = vec4(1.0, 0.85, 0.55, 1.0);

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	float n = texture(noise_tex, UV).r;
	float threshold = dissolve_progress * (1.0 + edge_width);
	// 像素的噪声值低于阈值 → 已消散
	if (tex.a > 0.0 && n < threshold - edge_width) {
		COLOR = vec4(tex.rgb, 0.0);
		return;
	}
	// 边缘带：阈值附近 → 发光
	float edge = smoothstep(threshold - edge_width, threshold, n);
	COLOR = vec4(mix(tex.rgb, edge_color.rgb, edge), tex.a);
}
