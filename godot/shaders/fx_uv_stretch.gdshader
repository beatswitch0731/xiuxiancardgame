shader_type canvas_item;

// FX UVStretch -- 沿攻击方向拉伸 UV + 尾部衰减（travel 模板的方向速度感）。
// 方向由 uniform 传入（弧度），旋转/镜像由宿主节点变换配合。
// stretch=0 时退化为原样绘制。

uniform float direction : hint_range(-3.1416, 3.1416) = 0.0;
uniform float stretch : hint_range(0.0, 1.0) = 0.0;
uniform float tail_fade : hint_range(0.0, 1.0) = 0.6;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	if (stretch <= 0.001) {
		COLOR = tex;
		return;
	}
	// 把 UV 旋转到"方向 = +x"的空间
	float c = cos(-direction);
	float s = sin(-direction);
	vec2 centered = UV - vec2(0.5);
	vec2 local = vec2(centered.x * c - centered.y * s,
		centered.x * s + centered.y * c) + vec2(0.5);
	// 沿方向拉伸采样：前缘保持、尾部向外拉伸
	vec2 sampled = local;
	sampled.x = 0.5 + (local.x - 0.5) / (1.0 + stretch * 1.5);
	vec4 stretched = texture(TEXTURE, clamp(sampled, vec2(0.0), vec2(1.0)));
	// 尾部（沿 -x）alpha 衰减，制造速度拖尾
	float tail = 1.0 - tail_fade * stretch * clamp((0.5 - local.x) * 2.0, 0.0, 1.0);
	vec3 mixed = mix(tex.rgb, stretched.rgb, stretch);
	float alpha = max(tex.a, stretched.a * tail);
	COLOR = vec4(mixed, alpha);
}
