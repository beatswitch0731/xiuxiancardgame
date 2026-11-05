class_name NoncombatSlotScreen
extends VBoxContainer

## 存档槽选择屏（S3：从 noncombat_opening_ui.gd 的 _build_slot_screen 抽出）。
##
## 只负责「画」。三条兼容铁律：
##   1. 节点身份不变——本节点 name 固定为 "SlotSelection"，子节点名与抽取前
##      逐字一致（Slot_slot_1..3 / ImportBrowserTutorial / ToggleAllAudioSlots /
##      OpenExperienceSettingsSlots / OpenHeavenlyGallerySlots），因为
##      tests/noncombat_save_slot_ui.gd 等硬编码了
##      DesktopMargin/ScreenStack/SlotSelection/Slot_slot_1 这条路径。
##   2. 对话框不搬——BrowserSavePicker / BrowserImportPreview /
##      BrowserReplaceConfirm 仍由父脚本 add_child(self) 持有。
##   3. 父脚本成员名不变——父脚本在装配处把 status_label / audio_button
##      赋值给原来的 slot_status_label / slot_audio_button。

const GameSkin = preload("res://scripts/game_ui_skin.gd")
const SaveSlots = preload("res://scripts/noncombat_save_slots.gd")

signal slot_pressed(slot_id: String)
signal import_requested
signal audio_toggled
signal experience_requested
signal gallery_requested

var status_label: Label
var audio_button: Button


func _init() -> void:
	name = "SlotSelection"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	alignment = BoxContainer.ALIGNMENT_CENTER
	add_theme_constant_override("separation", 15)
	_build()


func _build() -> void:
	var heading := _ink_label("选择独立存档", 36)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(heading)
	status_label = _ink_label("", 16)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(status_label)
	for slot_id in SaveSlots.SLOT_IDS:
		var button := Button.new()
		button.name = "Slot_" + slot_id
		button.custom_minimum_size = Vector2(560, 70)
		button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		GameSkin.apply_paper_button(button, GameSkin.BRASS)
		# 必须放在 apply_paper_button 之后：它内部会把字号设成 16
		button.add_theme_font_size_override("font_size", 19)
		button.pressed.connect(func() -> void: slot_pressed.emit(slot_id))
		add_child(button)
	add_child(_function_button("ImportBrowserTutorial", "导入网页版早期存档",
		320, 48, import_requested))
	audio_button = _function_button("ToggleAllAudioSlots", "", 220, 44,
		audio_toggled)
	add_child(audio_button)
	add_child(_function_button("OpenExperienceSettingsSlots", "体验设置",
		220, 44, experience_requested))
	add_child(_function_button("OpenHeavenlyGallerySlots", "天道万物志",
		220, 44, gallery_requested))


func _function_button(node_name: String, label_text: String,
		width: int, height: int, emitter: Signal) -> Button:
	var button := Button.new()
	button.name = node_name
	button.text = label_text
	button.custom_minimum_size = Vector2(width, height)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	GameSkin.apply_paper_button(button, GameSkin.JADE)
	button.pressed.connect(func() -> void: emitter.emit())
	return button


func _ink_label(value: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color("1a1612"))
	return label
