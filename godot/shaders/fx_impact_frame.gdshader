shader_type canvas_item;

// FX ImpactFrame -- 打击帧：全屏反色/白闪 1~2 帧（仅重击与终结技触发）。
// 挂在全屏 ColorRect 上（mouse_filter = IGNORE），由宿主控制可见帧数。
// invert=1 反色（Genshin 式视觉重置）；invert=0 时走纯色遮罩。

uniform float intensity : hint_range(0.0, 1.0) = 0.0;
uniform float invert : hint_range(0.0, 1.0) = 1.0;
uniform vec4 flash_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;

void fragment() {
	vec3 screen = texture(screen_tex, SCREEN_UV).rgb;
	vec3 inverted = vec3(1.0) - screen;
	vec3 flashed = mix(screen, inverted, invert);
	COLOR = vec4(mix(screen, flashed, intensity), intensity * 0.85);
	// flash_color 叠加一层纯色（invert=0 的用途）
	COLOR.rgb = mix(COLOR.rgb, flash_color.rgb, (1.0 - invert) * intensity);
}
