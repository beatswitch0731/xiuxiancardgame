shader_type canvas_item;

// FX HitFlash -- 受击/特效瞬间的整体提亮闪白。
// 用法：宿主在受击帧把 flash_strength 置 1.0，随后 1~2 帧内衰减到 0。
// 通道所有权：本 shader 只管"这一帧颜色"，不参与 hit-stop / shake。

uniform float flash_strength : hint_range(0.0, 1.0) = 0.0;
uniform vec4 flash_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	COLOR = vec4(mix(tex.rgb, flash_color.rgb, flash_strength), tex.a);
}
