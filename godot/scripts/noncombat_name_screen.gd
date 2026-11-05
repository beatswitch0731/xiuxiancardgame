class_name NoncombatNameScreen
extends VBoxContainer

## 取名屏（B：从 noncombat_opening_ui.gd 的 _build_name_screen 抽出）。
##
## 三条兼容铁律（与 S3 抽 slot 屏一致）：
##   1. 节点身份不变——本节点 name = "NameCreation"，子节点名逐字一致
##      （SourceLogo / SourceNameInput / NameCharacterCount / ConfirmName /
##      ReturnToSlots），tests 里的 DesktopMargin/ScreenStack/NameCreation/...
##      路径因此保持不变。
##   2. 父脚本成员名不变——装配处把 name_input / count_label / status_label
##      赋给父脚本原来的 name_input / name_count_label / name_status_label。
##   3. 业务校验留在父脚本（_confirm_name），本类只负责"画"与转发点击。

const GameSkin = preload("res://scripts/game_ui_skin.gd")
const NAME_MAX_LENGTH := 4
const LOGO_PATH := "assets/icons/xianxia_minimal_logo.png"

signal confirm_requested
signal return_requested

var name_input: LineEdit
var count_label: Label
var status_label: Label

var _texture_provider: Callable
var _show_back_button := true


## texture_provider: func(path: String) -> Texture2D，由父脚本注入 _art_texture。
## show_back_button 对应原来的 `save_slots != null`。
func setup(texture_provider: Callable, show_back_button: bool) -> void:
	_texture_provider = texture_provider
	_show_back_button = show_back_button
	name = "NameCreation"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	alignment = BoxContainer.ALIGNMENT_CENTER
	add_theme_constant_override("separation", 14)
	_build()


func _build() -> void:
	var logo := TextureRect.new()
	logo.name = "SourceLogo"
	logo.texture = _art(LOGO_PATH)
	logo.custom_minimum_size = Vector2(104, 104)
	logo.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	add_child(logo)
	var title := _ink_label("一念仙途", 47)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title)
	var subtitle := _ink_label("一念入道 · 执掌因果", 21)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(subtitle)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(430, 250)
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.095, 0.078, 0.071, 0.94)
	panel_style.border_color = Color("d9b168")
	panel_style.set_border_width_all(1)
	panel_style.set_corner_radius_all(8)
	panel_style.set_content_margin_all(20)
	panel.add_theme_stylebox_override("panel", panel_style)
	add_child(panel)
	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 14)
	panel.add_child(inner)
	var heading := _label("玉册题名 · 开启仙途", 26)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	inner.add_child(heading)
	var hint := _label("仙途漫漫，请于道册题写尊号（四字以内）", 16)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	inner.add_child(hint)
	name_input = LineEdit.new()
	name_input.name = "SourceNameInput"
	name_input.max_length = NAME_MAX_LENGTH
	name_input.placeholder_text = "叶凌云"
	name_input.alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_input.add_theme_font_size_override("font_size", 24)
	GameSkin.apply_text_input(name_input)
	name_input.text_submitted.connect(func(_text: String) -> void:
		confirm_requested.emit())
	inner.add_child(name_input)
	count_label = _label("0/%d" % NAME_MAX_LENGTH, 14)
	count_label.name = "NameCharacterCount"
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	inner.add_child(count_label)
	# 实时字数：迁移前是父脚本的内联 lambda 写父成员，这里改为写自身成员
	name_input.text_changed.connect(func(value: String) -> void:
		count_label.text = "%d/%d" % [value.length(), NAME_MAX_LENGTH])
	var confirm := Button.new()
	confirm.name = "ConfirmName"
	confirm.text = "朱 · 凝神定名 · 踏入仙途"
	confirm.custom_minimum_size.y = 50
	GameSkin.apply_action_button(confirm, GameSkin.WARM_RED)
	confirm.pressed.connect(func() -> void: confirm_requested.emit())
	inner.add_child(confirm)
	status_label = _ink_label("", 15)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(status_label)
	var back := Button.new()
	back.name = "ReturnToSlots"
	back.text = "返回玉简"
	back.visible = _show_back_button
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	GameSkin.apply_paper_button(back, GameSkin.BRASS)
	back.pressed.connect(func() -> void: return_requested.emit())
	add_child(back)


func _art(path: String) -> Texture2D:
	if _texture_provider.is_valid():
		var texture: Variant = _texture_provider.call(path)
		if texture is Texture2D:
			return texture
	return null


func _label(value: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color("e9e1cf"))
	return label


func _ink_label(value: String, font_size: int) -> Label:
	var label := _label(value, font_size)
	label.add_theme_color_override("font_color", Color("1a1612"))
	return label
