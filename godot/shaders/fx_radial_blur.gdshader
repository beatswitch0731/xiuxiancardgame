shader_type canvas_item;

// FX RadialBlur -- 冲击瞬间沿中心向外模糊（impact 模板增强）。
// 用法：strength 从峰值（0.5~0.8）在 3~4 帧内衰减到 0。
// 采样 6 次，开销可控；strength=0 时退化为原样绘制。

uniform vec2 blur_center = vec2(0.5, 0.5);
uniform float strength : hint_range(0.0, 1.0) = 0.0;
uniform float radius : hint_range(0.0, 0.6) = 0.25;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	if (strength <= 0.001) {
		COLOR = tex;
		return;
	}
	vec2 dir = UV - blur_center;
	float dist = length(dir);
	// 中心附近最强，边缘衰减
	float falloff = clamp(1.0 - dist / max(radius, 0.001), 0.0, 1.0);
	vec3 acc = tex.rgb;
	float acc_a = tex.a;
	for (int i = 1; i <= 5; i++) {
		float t = float(i) / 5.0;
		vec2 offset = dir * strength * falloff * t * 0.12;
		vec4 s = texture(TEXTURE, UV + offset);
		acc += s.rgb;
		acc_a += s.a;
	}
	vec3 blurred = acc / 6.0;
	float blurred_a = acc_a / 6.0;
	COLOR = vec4(mix(tex.rgb, blurred, strength * falloff),
		mix(tex.a, blurred_a, strength * falloff));
}
