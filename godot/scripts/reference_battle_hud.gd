extends Control

# Read-only battle presentation for the reference demo. Card rules, intent and
# damage continue to come from CombatDomain and RuntimeDataRegistry.
const INK_FONT: Font = preload("res://assets/fonts/LXGWWenKai-Regular.ttf")
const BODY_FONT: Font = preload("res://assets/fonts/NotoSansSC-VF.ttf")
const TEXT := Color("eee8d9")
const MUTED := Color("bdc9c9")
const BRASS := Color("c6a76d")
const BLUE := Color("8cbac2")

var _registry: RefCounted
var _hand: Array = []
var _played: Array[String] = []
var _turn := -1
var _hovered_index := -1
var _phase := ""
var _intent: Dictionary = {}
var _compact := false

var _history_panel: Panel
var _tactics_panel: Panel
var _history_heading: Label
var _history_empty: Label
var _history_rows: Array[Control] = []
var _round_label: Label
var _intent_label: Label
var _card_art: TextureRect
var _card_name: Label
var _card_cost: Label
var _card_description: RichTextLabel
var _phase_label: Label


func _ready() -> void:
	name = "ReferenceBattleHUD"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_history_panel = _panel("PlayedPanel")
	_history_heading = _label(_history_panel, "PlayedHeading", "本回合 · 出牌顺序", 18, TEXT, INK_FONT)
	_history_empty = _label(_history_panel, "PlayedEmpty", "点击手牌后，这里记录出牌顺序", 13, MUTED, BODY_FONT)
	_history_empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	for index in 3:
		var row := Control.new()
		row.name = "Played_%d" % index
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_history_panel.add_child(row)
		var image := TextureRect.new()
		image.name = "CardArt"
		image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		image.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		image.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(image)
		_label(row, "CardName", "", 14, TEXT, BODY_FONT)
		_label(row, "Sequence", "", 13, BRASS, BODY_FONT)
		_history_rows.append(row)
	_tactics_panel = _panel("TacticsPanel")
	_round_label = _label(_tactics_panel, "Round", "战局 · 第 1 回合", 18, TEXT, INK_FONT)
	_intent_label = _label(_tactics_panel, "EnemyIntent", "", 13, MUTED, BODY_FONT)
	_intent_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var rule := ColorRect.new()
	rule.name = "Divider"
	rule.color = Color("695d48")
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tactics_panel.add_child(rule)
	_card_art = TextureRect.new()
	_card_art.name = "TacticalCardArt"
	_card_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_card_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_card_art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_card_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tactics_panel.add_child(_card_art)
	_card_name = _label(_tactics_panel, "TacticalCardName", "", 17, TEXT, INK_FONT)
	_card_cost = _label(_tactics_panel, "TacticalCardCost", "", 13, BLUE, BODY_FONT)
	_card_description = RichTextLabel.new()
	_card_description.name = "TacticalCardDescription"
	_card_description.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card_description.scroll_active = false
	_card_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_card_description.add_theme_font_override("normal_font", BODY_FONT)
	_card_description.add_theme_font_size_override("normal_font_size", 13)
	_card_description.add_theme_color_override("default_color", Color("d9ddd4"))
	_card_description.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	_tactics_panel.add_child(_card_description)
	_phase_label = _label(_tactics_panel, "BattlePhase", "", 13, BRASS, BODY_FONT)
	_layout(get_viewport().get_visible_rect().size)


func set_registry(registry: RefCounted) -> void:
	_registry = registry


func layout_for(view_size: Vector2) -> void:
	_layout(view_size)


func render_source(state: Dictionary) -> void:
	var new_turn := int(state.get("turn", 0))
	if _turn != new_turn:
		_turn = new_turn
		_played.clear()
	_hand = (state.get("hand", []) as Array).duplicate()
	_phase = String(state.get("phase", ""))
	_intent = (state.get("enemyIntent", {}) as Dictionary).duplicate(true)
	_render_history()
	_render_tactics()


func set_hovered_card(index: int, active: bool) -> void:
	_hovered_index = index if active else -1
	_render_tactics()


func record_played_card(card_id: String) -> void:
	if card_id.is_empty():
		return
	_played.append(card_id)
	_render_history()


func _panel(node_name: String) -> Panel:
	var panel := Panel.new()
	panel.name = node_name
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var skin := StyleBoxFlat.new()
	skin.bg_color = Color(0.045, 0.071, 0.085, 0.94)
	skin.border_color = Color("8c7956")
	skin.set_border_width_all(1)
	skin.border_width_left = 3
	skin.set_corner_radius_all(3)
	skin.shadow_color = Color(0.0, 0.0, 0.0, 0.42)
	skin.shadow_size = 8
	skin.shadow_offset = Vector2(0, 3)
	panel.add_theme_stylebox_override("panel", skin)
	add_child(panel)
	return panel


func _label(parent: Node, node_name: String, value: String, font_size: int,
		color: Color, font: Font) -> Label:
	var label := Label.new()
	label.name = node_name
	label.text = value
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label


func _layout(view_size: Vector2) -> void:
	if _history_panel == null:
		return
	var compact := view_size.x < 1120.0
	_compact = compact
	var left_width := 206.0 if compact else 258.0
	var right_width := 198.0 if compact else 276.0
	_history_panel.position = Vector2(16, view_size.y - 265)
	_history_panel.size = Vector2(left_width, 192)
	_history_heading.position = Vector2(13, 9)
	_history_heading.size = Vector2(left_width - 22, 27)
	_history_empty.position = Vector2(13, 56)
	_history_empty.size = Vector2(left_width - 24, 42)
	for index in _history_rows.size():
		var row := _history_rows[index]
		row.position = Vector2(13, 42 + index * 49)
		row.size = Vector2(left_width - 24, 45)
		var image := row.get_node("CardArt") as TextureRect
		image.position = Vector2(23, 2)
		image.size = Vector2(42, 41)
		var name_label := row.get_node("CardName") as Label
		name_label.position = Vector2(73, 7)
		name_label.size = Vector2(left_width - 101, 29)
		name_label.clip_text = true
		var sequence := row.get_node("Sequence") as Label
		sequence.position = Vector2(0, 8)
		sequence.size = Vector2(20, 25)
	_tactics_panel.position = Vector2(view_size.x - right_width - 16,
		view_size.y - (343 if compact else 329))
	_tactics_panel.size = Vector2(right_width, 270 if compact else 256)
	_round_label.position = Vector2(14, 9)
	_round_label.size = Vector2(right_width - 28, 27)
	_intent_label.position = Vector2(14, 42)
	_intent_label.size = Vector2(right_width - 28, 34)
	var rule := _tactics_panel.get_node("Divider") as ColorRect
	rule.position = Vector2(14, 82)
	rule.size = Vector2(right_width - 28, 1)
	_card_art.position = Vector2(14, 92)
	_card_art.size = Vector2(61, 62)
	_card_name.position = Vector2(84, 92)
	_card_name.size = Vector2(right_width - 98, 28)
	_card_name.clip_text = true
	_card_cost.position = Vector2(84, 123)
	_card_cost.size = Vector2(right_width - 98, 24)
	_card_description.position = Vector2(14, 164)
	_card_description.size = Vector2(right_width - 28, 78 if compact else 65)
	_phase_label.position = Vector2(14, 247 if compact else 232)
	_phase_label.size = Vector2(right_width - 28, 20)
	_render_tactics()


func _render_history() -> void:
	if _history_heading == null:
		return
	_history_heading.text = "本回合 · 已出 %d 张" % _played.size()
	_history_empty.visible = _played.is_empty()
	var first_visible := maxi(0, _played.size() - _history_rows.size())
	for index in _history_rows.size():
		var row := _history_rows[index]
		var source_index := first_visible + index
		row.visible = source_index < _played.size()
		if not row.visible or _registry == null:
			continue
		var card_id := _played[source_index]
		var card: Dictionary = _registry.get_battle_card(card_id)
		(row.get_node("CardArt") as TextureRect).texture = _registry.texture_for(
			String(card.get("cardArt", {}).get("image", "")))
		(row.get_node("CardName") as Label).text = String(card.get("name", card_id))
		(row.get_node("Sequence") as Label).text = "%02d" % (source_index + 1)


func _render_tactics() -> void:
	if _round_label == null:
		return
	_round_label.text = "战局 · 第 %d 回合" % maxi(1, _turn)
	var intent_type := String(_intent.get("type", ""))
	var intent_value := int(_intent.get("value", 0))
	var intent_name := "将攻 %d" % intent_value if intent_type == "attack" else (
		"将护 %d" % intent_value if intent_type == "defend" else "敌方蓄势")
	var intent_desc := String(_intent.get("desc", "观察敌方动向"))
	_intent_label.text = intent_desc if _compact else "%s  ·  %s" % [intent_name, intent_desc]
	var card_id := ""
	if _hovered_index >= 0 and _hovered_index < _hand.size():
		card_id = String(_hand[_hovered_index])
	elif not _hand.is_empty():
		card_id = String(_hand[0])
	elif not _played.is_empty():
		card_id = _played.back()
	var card: Dictionary = _registry.get_battle_card(card_id) if _registry != null and card_id != "" else {}
	_card_art.texture = _registry.texture_for(String(card.get("cardArt", {}).get("image", ""))) if not card.is_empty() else null
	_card_name.text = String(card.get("name", "无待选招式"))
	var card_type := String(card.get("type", ""))
	var type_name: String = String({"attack": "攻势", "defense": "护势", "skill": "术式", "power": "心法"}.get(card_type, card_type))
	_card_cost.text = "真元 %d  ·  %s" % [int(card.get("cost", 0)), type_name] if not card.is_empty() else ""
	_card_description.text = String(card.get("description", "选择一张手牌查看招式"))
	_phase_label.text = "敌袭 · 选择反应" if _phase == "REACTION_OPEN" else (
		"出牌阶段" if _phase == "PLAYER_TURN" else "战斗结算中")
