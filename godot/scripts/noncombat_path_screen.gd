class_name NoncombatPathScreen
extends VBoxContainer

## 择道屏（B：从 noncombat_opening_ui.gd 的 _build_path_screen 抽出）。
##
## 三条兼容铁律（与 S3/S6 一致）：
##   1. 节点身份不变——本节点 name = "PathSelection"，子节点名逐字一致
##      （SourcePathGrid / Path_sword|spell|body|pill / SourcePathIcon /
##      ReturnToSlots），tests 里的路径因此不变。
##   2. 父脚本成员名不变——装配处把 status_label 赋给 path_status_label。
##   3. 数据由父脚本传入（_source_paths() 的结果），本类不碰 content_repository。

const GameSkin = preload("res://scripts/game_ui_skin.gd")

## 四路卡的书法副题与描述，来源是 index.html 的 path-floating-grid；
## 机制仍以 data/config/paths.json 为准（由 paths 参数传入）。
const SOURCE_CAPTIONS := {
	"sword": ["凌霄", "霜剑斩空 · 极致杀伐", "一剑破万法，凭凌厉剑意断绝因果、一击致命"],
	"spell": ["碧霄", "雷法通玄 · 五行变化", "诸术兼修，引天地雷霆与五行灵气运筹帷幄"],
	"body": ["沉金", "肉身成圣 · 气血不灭", "锻淬金身，凭浩瀚血气化作坚强防壁震慑强敌"],
	"pill": ["青木", "以丹入道 · 草木蕴灵", "灵丹妙药，炼天地草木菁华转化为修行大机缘"],
}
const ACCENTS := {
	"sword": Color("2a5a5b"),
	"spell": Color("5c425e"),
	"body": Color("c86f3b"),
	"pill": Color("375945"),
}

signal path_selected(path_id: String)
signal return_requested

var status_label: Label

var _texture_provider: Callable
var _paths: Dictionary
var _show_back_button := true


func setup(texture_provider: Callable, paths: Dictionary,
		show_back_button: bool) -> void:
	_texture_provider = texture_provider
	_paths = paths
	_show_back_button = show_back_button
	_build()


## 基础属性在 _init 里设好，父脚本 add_child 时节点已有正确名字与铺满锚点。
## 注意：_build() 必须在节点**已入树**后调用（父脚本先 add_child 再 setup），
## 否则卡片内部的绝对定位在入树时会被重算，而重设又发生在入树前 → 失效。
func _init() -> void:
	name = "PathSelection"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	alignment = BoxContainer.ALIGNMENT_CENTER
	add_theme_constant_override("separation", 15)


func _build() -> void:
	var heading := _ink_label("择道立誓 · 传承功法", 34)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(heading)
	var instruction := _ink_label("修仙之道，各有所长；一经选择，宿命启程", 19)
	instruction.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(instruction)
	status_label = _ink_label("", 15)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(status_label)
	var grid := HBoxContainer.new()
	grid.name = "SourcePathGrid"
	grid.alignment = BoxContainer.ALIGNMENT_CENTER
	grid.add_theme_constant_override("separation", 16)
	add_child(grid)
	for path_id in _paths:
		var path: Dictionary = _paths[path_id]
		var card := _build_path_card(String(path_id), path)
		grid.add_child(card)
		# 关键：TextureRect/Label 在入树时会按内容重算最小尺寸，覆盖上面的
		# 绝对定位。必须在 add_child 之后重设一次，否则文字会横向溢出卡片。
		_apply_card_sizes(card)
	var back := Button.new()
	back.name = "ReturnToSlots"
	back.text = "返回玉简"
	back.visible = _show_back_button
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	GameSkin.apply_paper_button(back, GameSkin.BRASS)
	back.pressed.connect(func() -> void: return_requested.emit())
	add_child(back)


func _build_path_card(path_id: String, path: Dictionary) -> Button:
	var caption: Array = SOURCE_CAPTIONS.get(path_id, [path_id, "", ""])
	var accent: Color = ACCENTS.get(path_id, GameSkin.BRASS)
	var button := Button.new()
	button.name = "Path_" + path_id
	button.custom_minimum_size = Vector2(218, 335)
	GameSkin.apply_path_card(button, accent)
	button.tooltip_text = "%s：%s" % [path.get("name", path_id), caption[1]]
	var icon := TextureRect.new()
	icon.name = "SourcePathIcon"
	icon.texture = _art("assets/icons/%s_ink.png" % path_id)
	icon.position = Vector2(29, 18)
	icon.size = Vector2(160, 160)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(icon)
	var title := _ink_label("%s · %s" % [path.get("name", path_id), caption[0]], 22)
	title.position = Vector2(8, 187)
	title.size = Vector2(202, 34)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(title)
	var calligraphy := _ink_label(String(caption[1]), 17)
	calligraphy.position = Vector2(8, 230)
	calligraphy.size = Vector2(202, 30)
	calligraphy.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	calligraphy.add_theme_color_override("font_color", accent)
	calligraphy.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(calligraphy)
	var desc := _ink_label(String(caption[2]), 13)
	desc.position = Vector2(13, 270)
	desc.size = Vector2(192, 52)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(desc)
	button.pressed.connect(func() -> void: path_selected.emit(path_id))
	return button


## 入树后重设绝对尺寸（迁移前的注释已说明这个必要性）。
func _apply_card_sizes(card: Button) -> void:
	var icon := card.get_node_or_null("SourcePathIcon") as TextureRect
	if icon != null:
		icon.size = Vector2(160, 160)
	var index := 0
	for child in card.get_children():
		if child is Label:
			match index:
				0:
					child.size = Vector2(202, 34)   # title
				1:
					child.size = Vector2(202, 30)   # calligraphy
				2:
					child.size = Vector2(192, 52)   # description
			index += 1


func _art(path: String) -> Texture2D:
	if _texture_provider.is_valid():
		var texture: Variant = _texture_provider.call(path)
		if texture is Texture2D:
			return texture
	return null


func _ink_label(value: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color("1a1612"))
	return label
