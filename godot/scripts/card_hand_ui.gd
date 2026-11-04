extends HBoxContainer

# Port of the active browser hand in DeckCombatUI.buildCardViewModel/render.
# Authority stays in battle_cards.json and RuntimeDataRegistry; this class only
# renders the current hand and reports the selected hand index.
signal card_selected(index: int)
signal card_hovered(index: int, active: bool)

const CARD_HEIGHT := 156.0
const CARD_WIDTH := 104.0
const CARD_GAP := -6
const INK := Color("1d2422")
const PAPER := Color("f5eed8")
const GOLD := Color("d0b778")
const DEEP_INK := Color("292c27")
const INK_FONT = preload("res://assets/fonts/LXGWWenKai-Regular.ttf")
const BODY_FONT = preload("res://assets/fonts/NotoSansSC-VF.ttf")
const INSPECT_FOLIO = preload("res://assets/ui/hud_materials/card_inspect_folio_v1.png")
const PLAQUE_WEAVE = preload("res://assets/ui/hud_materials/status_plaque_v1.png")
const CARD_CLOTH_SHADER = preload("res://shaders/card_cloth_foil.gdshader")

var _registry: RefCounted
var _hand: Array = []
var _qi := 0
var _phase := ""
var _locked := false
var _commit_revision := 0
var _echo_layer: CanvasLayer
var _echo: Control


func _ready() -> void:
	name = "ActualHand"
	add_theme_constant_override("separation", CARD_GAP)
	alignment = BoxContainer.ALIGNMENT_CENTER
	mouse_filter = Control.MOUSE_FILTER_PASS
	resized.connect(_refresh_layout)
	get_viewport().size_changed.connect(_position_committed)
	set_process(true)


func _process(delta: float) -> void:
	for card in get_children():
		if card is Button:
			var target := float(card.get_meta("tilt_target", 0.0)) if bool(card.get_meta("hovered", false)) else _rest_rotation(int(card.get_meta("hand_index", 0)))
			card.rotation = lerpf(card.rotation, target, minf(1.0, delta * 13.0))
			var stock := card.get_node("CardSurface") as ColorRect
			var material := stock.material as ShaderMaterial
			var last_strength := float(card.get_meta("material_hover", 0.0))
			var next_strength := move_toward(last_strength,
				0.42 if card.disabled and bool(card.get_meta("hovered", false)) else (1.0 if bool(card.get_meta("hovered", false)) else 0.0), delta * 6.0)
			if not is_equal_approx(last_strength, next_strength):
				card.set_meta("material_hover", next_strength)
				material.set_shader_parameter("hover_strength", next_strength)


func show_committed(registry: RefCounted, card_id: String) -> void:
	# Presentation only. The combat domain has already accepted this card.
	var card: Dictionary = registry.get_battle_card(card_id)
	if card.is_empty():
		push_error("Missing committed source card: " + card_id)
		return
	var art_path := String(card.get("cardArt", {}).get("image", ""))
	var source_art: Texture2D = registry.texture_for(art_path)
	if source_art == null:
		push_error("Missing committed source art: " + art_path)
		return
	_commit_revision += 1
	var revision := _commit_revision
	if _echo != null and is_instance_valid(_echo):
		_echo_layer.remove_child(_echo)
		_echo.queue_free()
	if _echo_layer == null:
		_echo_layer = CanvasLayer.new()
		_echo_layer.name = "CommittedLayer"
		_echo_layer.layer = 10
		add_child(_echo_layer)
	_echo = Control.new()
	_echo.name = "CommittedNotation"
	_echo.size = Vector2(252, 64)
	_echo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_echo.modulate.a = 0.0
	_echo.set_meta("source_card_id", card_id)
	_echo.set_meta("source_art", art_path)
	_echo_layer.add_child(_echo)
	_position_committed()
	var backdrop := Panel.new()
	backdrop.name = "NotationBackdrop"
	backdrop.position = Vector2.ZERO
	backdrop.size = _echo.size
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var frame := StyleBoxFlat.new()
	frame.bg_color = Color(0.13, 0.21, 0.17, 0.91)
	frame.border_color = Color("cddcbb")
	frame.border_width_left = 2
	frame.set_corner_radius_all(5)
	backdrop.add_theme_stylebox_override("panel", frame)
	_echo.add_child(backdrop)
	var image := TextureRect.new()
	image.name = "SourceCardArt"
	image.texture = source_art
	image.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	image.position = Vector2(5, 5)
	image.size = Vector2(74, 54)
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_echo.add_child(image)
	var kicker := _label("CommitKicker", "出手", 12, Color("d4dfbf"))
	kicker.add_theme_font_override("font", get_theme_default_font())
	kicker.position = Vector2(88, 7)
	kicker.size = Vector2(155, 19)
	_echo.add_child(kicker)
	var title := _label("SourceCardName", String(card.get("name", card_id)), 18, Color("fbf5dd"))
	title.add_theme_font_override("font", get_theme_default_font())
	title.position = Vector2(88, 27)
	title.size = Vector2(155, 29)
	title.clip_text = true
	_echo.add_child(title)
	create_tween().tween_property(_echo, "modulate:a", 1.0, 0.08)
	get_tree().create_timer(0.43).timeout.connect(_fade_committed.bind(revision))


func _position_committed() -> void:
	if _echo == null or not is_instance_valid(_echo):
		return
	var viewport_size := get_viewport().get_visible_rect().size
	_echo.position = Vector2(24, maxf(96.0, viewport_size.y - 340.0))


func _fade_committed(revision: int) -> void:
	if revision != _commit_revision or _echo == null or not is_instance_valid(_echo):
		return
	var old_echo := _echo
	var old_echo_ref: WeakRef = weakref(old_echo)
	var tween := create_tween()
	tween.tween_property(old_echo, "modulate:a", 0.0, 0.22)
	tween.finished.connect(func() -> void:
		var faded_echo := old_echo_ref.get_ref() as Control
		if faded_echo != null:
			faded_echo.queue_free()
		if _echo == faded_echo:
			_echo = null)


func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo or event.alt_pressed or event.ctrl_pressed or event.meta_pressed:
		return
	var index := int(event.keycode) - int(KEY_1)
	if index < 0 or index >= mini(_hand.size(), 5):
		return
	var card := get_child(index) as Button
	if card == null or card.disabled:
		return
	card_selected.emit(index)
	get_viewport().set_input_as_handled()


func render_hand(registry: RefCounted, hand: Array, qi: int, phase: String, input_locked: bool) -> void:
	_registry = registry
	_hand = hand.duplicate()
	_qi = qi
	_phase = phase
	_locked = input_locked
	for child in get_children():
		if child is Button:
			remove_child(child)
			child.queue_free()
	if _registry == null:
		return
	var width := _card_width()
	for index in range(_hand.size()):
		var card_id := String(_hand[index])
		var card: Dictionary = _registry.get_battle_card(card_id)
		if card.is_empty():
			push_error("Missing source battle card: " + card_id)
			continue
		var card_view := _build_card(card, card_id, index, width)
		card_view.z_index = _resting_z(index)
		add_child(card_view)


func _card_width() -> float:
	var count := maxi(_hand.size(), 1)
	return minf(CARD_WIDTH, maxf(84.0, (size.x - CARD_GAP * (count - 1)) / count))


func _refresh_layout() -> void:
	var width := _card_width()
	for child in get_children():
		if child is Button:
			child.custom_minimum_size = Vector2(width, _fan_height(int(child.get_meta("hand_index", 0))))
			_layout_card(child, width)


func _build_card(card: Dictionary, card_id: String, index: int, width: float) -> Button:
	var button := Button.new()
	button.name = "Card_%d_%s" % [index, card_id]
	button.text = ""
	button.clip_contents = false
	button.custom_minimum_size = Vector2(width, _fan_height(index))
	button.pivot_offset = Vector2(width * 0.5, _fan_height(index))
	button.size_flags_vertical = Control.SIZE_SHRINK_END
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.set_meta("hovered", false)
	button.set_meta("tilt_target", 0.0)
	button.set_meta("source_card_id", card_id)
	button.set_meta("hand_index", index)
	var art_path := String(card.get("cardArt", {}).get("image", ""))
	button.set_meta("source_art", art_path)
	var available := not _locked and _phase == "PLAYER_TURN" and _qi >= int(card.get("cost", 0))
	button.disabled = not available
	var accent := _card_accent(card)
	button.add_theme_stylebox_override("normal", _card_style(accent))
	button.add_theme_stylebox_override("hover", _card_style(Color("f8d88f")))
	button.add_theme_stylebox_override("focus", _card_style(Color("f8d88f")))
	button.add_theme_stylebox_override("pressed", _card_style(Color("f8d88f")))
	button.add_theme_stylebox_override("disabled", _card_style(Color("75847a"), Color("0d1513")))
	button.pressed.connect(func() -> void: card_selected.emit(index))
	button.mouse_entered.connect(_set_hover.bind(button, true))
	button.mouse_exited.connect(_set_hover.bind(button, false))
	button.focus_entered.connect(_set_hover.bind(button, true))
	button.focus_exited.connect(_set_hover.bind(button, false))
	button.gui_input.connect(_on_card_pointer.bind(button))

	var stock := ColorRect.new()
	stock.name = "CardSurface"
	stock.color = Color.WHITE
	stock.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var stock_material := ShaderMaterial.new()
	stock_material.shader = CARD_CLOTH_SHADER
	stock_material.set_shader_parameter("weave_texture", PLAQUE_WEAVE)
	stock_material.set_shader_parameter("accent_color", accent)
	stock_material.set_shader_parameter("hover_strength", 0.0)
	stock_material.set_shader_parameter("light_x", 0.5)
	stock_material.set_shader_parameter("available", 1.0 if available else 0.0)
	stock.material = stock_material
	button.add_child(stock)

	var foil := ColorRect.new()
	foil.name = "FoilRim"
	foil.color = accent.darkened(0.12)
	foil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(foil)
	var title_rule := ColorRect.new()
	title_rule.name = "TitleRule"
	title_rule.color = Color(accent.r, accent.g, accent.b, 0.53)
	title_rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(title_rule)

	var art_well := Panel.new()
	art_well.name = "ArtWell"
	art_well.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var art_frame := StyleBoxFlat.new()
	art_frame.bg_color = Color("081014")
	art_frame.border_color = accent.darkened(0.27)
	art_frame.set_border_width_all(1)
	art_frame.shadow_color = Color(0.0, 0.0, 0.0, 0.55)
	art_frame.shadow_size = 2
	art_frame.shadow_offset = Vector2(0, 2)
	art_well.add_theme_stylebox_override("panel", art_frame)
	button.add_child(art_well)

	var art := TextureRect.new()
	art.name = "SourceCardArt"
	art.texture = _registry.texture_for(art_path)
	if art.texture == null:
		push_error("Missing source card art: " + art_path)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	# Preserve the authored pixel clusters when a 1024px export is reduced to
	# the compact hand. Mipmaps handle the reduction; nearest sampling keeps
	# neighboring palette colors from smearing together on screen.
	art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	art.modulate = Color.WHITE if available else Color(0.69, 0.72, 0.72)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(art)

	var name_label := _label("CardName", String(card.get("name", card_id)), 14, PAPER)
	button.add_child(name_label)
	var cost := _label("CardCost", str(int(card.get("cost", 0))), 14, Color("fff1c5"))
	cost.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cost.add_theme_stylebox_override("normal", _badge_style(accent))
	button.add_child(cost)
	var category := _label("CardCategory", _card_category(card), 11, Color("dad7c6"))
	button.add_child(category)
	var effects_back := ColorRect.new()
	effects_back.name = "EffectsBack"
	effects_back.color = Color("192a2f")
	effects_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(effects_back)
	var effects := _label("SourceEffects", _effect_summary(card), 12, Color("fff1cd"))
	effects.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	button.add_child(effects)
	var number := _label("HandNumber", str(index + 1), 11, Color("d4d8c6"))
	number.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	button.add_child(number)
	var hover_detail := Panel.new()
	hover_detail.name = "HoverDetail"
	hover_detail.visible = false
	hover_detail.top_level = true
	hover_detail.z_index = 100
	hover_detail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hover_detail.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	button.add_child(hover_detail)
	var folio := TextureRect.new()
	folio.name = "PaperFolio"
	folio.texture = INSPECT_FOLIO
	folio.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	folio.stretch_mode = TextureRect.STRETCH_SCALE
	folio.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	folio.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hover_detail.add_child(folio)
	folio.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var hover_title := _label("Name", String(card.get("name", card_id)), 18, DEEP_INK)
	hover_title.add_theme_font_override("font", INK_FONT)
	hover_detail.add_child(hover_title)
	var hover_text := RichTextLabel.new()
	hover_text.name = "FullEffect"
	hover_text.text = String(card.get("description", ""))
	hover_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hover_text.scroll_active = false
	hover_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hover_text.add_theme_font_size_override("normal_font_size", 15)
	hover_text.add_theme_font_override("normal_font", BODY_FONT)
	hover_text.add_theme_color_override("default_color", DEEP_INK)
	hover_text.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	hover_detail.add_child(hover_text)
	if bool(card.get("exhaust", false)):
		var exhaust := _label("Exhaust", "仅此一式", 9, Color("ffd28d"))
		button.add_child(exhaust)
	_layout_card(button, width)
	return button


func _layout_card(button: Button, width: float) -> void:
	button.pivot_offset = Vector2(width * 0.5, _fan_height(int(button.get_meta("hand_index", 0))))
	var stock := button.get_node("CardSurface") as ColorRect
	stock.position = Vector2(2, 2)
	stock.size = Vector2(width - 4, CARD_HEIGHT - 6)
	(stock.material as ShaderMaterial).set_shader_parameter("face_size", stock.size)
	var foil := button.get_node("FoilRim") as ColorRect
	foil.position = Vector2(6, 2)
	foil.size = Vector2(width - 12, 1)
	var title_rule := button.get_node("TitleRule") as ColorRect
	title_rule.position = Vector2(7, 25)
	title_rule.size = Vector2(width - 14, 1)
	var name_label := button.get_node("CardName") as Label
	name_label.position = Vector2(26, 5)
	name_label.size = Vector2(width - 31, 19)
	var cost := button.get_node("CardCost") as Label
	cost.position = Vector2(4, 4)
	cost.size = Vector2(20, 20)
	var art_well := button.get_node("ArtWell") as Panel
	art_well.position = Vector2(4, 27)
	art_well.size = Vector2(width - 8, 86)
	var art := button.get_node("SourceCardArt") as TextureRect
	art.position = Vector2(6, 29)
	art.size = Vector2(width - 12, 82)
	var effects_back := button.get_node("EffectsBack") as ColorRect
	effects_back.position = Vector2(4, 115)
	effects_back.size = Vector2(width - 8, 20)
	var effects := button.get_node("SourceEffects") as Label
	effects.position = Vector2(6, 115)
	effects.size = Vector2(width - 12, 20)
	var category := button.get_node("CardCategory") as Label
	category.position = Vector2(7, 136)
	category.size = Vector2(39, 16)
	var number := button.get_node("HandNumber") as Label
	number.position = Vector2(width - 19, 136)
	number.size = Vector2(14, 16)
	var hover_detail := button.get_node("HoverDetail") as Panel
	var viewport_width := get_viewport().get_visible_rect().size.x
	var inspect_width := maxf(220.0, minf(284.0, viewport_width - 776.0))
	var hover_text := hover_detail.get_node("FullEffect") as RichTextLabel
	var font: Font = hover_text.get_theme_font("normal_font")
	var text_height := font.get_multiline_string_size(hover_text.text,
		HORIZONTAL_ALIGNMENT_LEFT, inspect_width - 30.0, 15).y
	hover_detail.position = Vector2((viewport_width - inspect_width) * 0.5, 78)
	hover_detail.size = Vector2(inspect_width, clampf(52.0 + text_height, 78.0, 172.0))
	var hover_title := hover_detail.get_node("Name") as Label
	hover_title.position = Vector2(23, 7)
	hover_title.size = Vector2(inspect_width - 38, 25)
	hover_text.position = Vector2(15, 36)
	hover_text.size = Vector2(inspect_width - 30, 100)
	var exhaust := button.get_node_or_null("Exhaust") as Label
	if exhaust:
		exhaust.position = Vector2(29, 136)
		exhaust.size = Vector2(56, 16)


func _set_hover(button: Button, active: bool) -> void:
	if not is_instance_valid(button):
		return
	if not active and (button.has_focus() or button.get_global_rect().has_point(get_global_mouse_position())):
		return
	if bool(button.get_meta("hovered", false)) == active:
		return
	button.set_meta("hovered", active)
	card_hovered.emit(int(button.get_meta("hand_index", 0)), active)
	button.z_index = 20 if active else _resting_z(int(button.get_meta("hand_index", 0)))
	(button.get_node("HoverDetail") as Panel).visible = active
	if button.has_meta("hover_tween"):
		var prior: Tween = button.get_meta("hover_tween") as Tween
		if prior != null and prior.is_running():
			prior.kill()
	var tween := create_tween()
	button.set_meta("hover_tween", tween)
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(button, "scale", Vector2(1.12, 1.12) if active else Vector2.ONE, 0.18)
	tween.tween_property(button, "position:y", -7.0 if active else 0.0, 0.18)


func _on_card_pointer(event: InputEvent, button: Button) -> void:
	if event is InputEventMouseMotion and bool(button.get_meta("hovered", false)):
		var lateral := clampf(event.position.x / maxf(1.0, button.size.x), 0.0, 1.0)
		button.set_meta("tilt_target", deg_to_rad((lateral - 0.5) * 2.0))
		((button.get_node("CardSurface") as ColorRect).material as ShaderMaterial).set_shader_parameter("light_x", lateral)


func _label(node_name: String, value: String, font_size: int, color: Color) -> Label:
	var item := Label.new()
	item.name = node_name
	item.text = value
	item.mouse_filter = Control.MOUSE_FILTER_IGNORE
	item.add_theme_font_override("font", BODY_FONT)
	item.add_theme_font_size_override("font_size", font_size)
	item.add_theme_color_override("font_color", color)
	item.add_theme_color_override("font_shadow_color", Color.TRANSPARENT)
	item.add_theme_constant_override("shadow_offset_x", 0)
	item.add_theme_constant_override("shadow_offset_y", 0)
	return item


func _card_style(border: Color, fill: Color = INK) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border.darkened(0.19)
	style.set_border_width_all(1)
	style.border_width_bottom = 3
	style.set_corner_radius_all(3)
	style.shadow_color = Color(0.005, 0.014, 0.016, 0.8)
	style.shadow_size = 5
	style.shadow_offset = Vector2(0, 3)
	return style


func _badge_style(accent: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("162b31")
	style.border_color = accent.darkened(0.12)
	style.set_border_width_all(1)
	style.set_corner_radius_all(15)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.58)
	style.shadow_size = 2
	style.shadow_offset = Vector2(0, 1)
	return style


func _card_category(card: Dictionary) -> String:
	match String(card.get("type", "")):
		"attack": return "剑式"
		"skill": return "心法"
		"power": return "势"
		_: return "术"


func _card_accent(card: Dictionary) -> Color:
	match String(card.get("type", "")):
		"skill": return Color("91b9ad")
		"power": return Color("b88b83")
		_: return GOLD


func _resting_z(index: int) -> int:
	return maxi(0, 10 - absi(index * 2 - (_hand.size() - 1)))


func _rest_rotation(index: int) -> float:
	# The shallow arc comes from height, while unrotated cards keep 12px Chinese
	# glyphs on integer pixels. Pointer tilt is still applied during hover.
	return 0.0


func _fan_height(index: int) -> float:
	return CARD_HEIGHT


func _display_value(value: Variant) -> String:
	if value is float and is_equal_approx(value, roundf(value)):
		return str(int(roundf(value)))
	return str(value)


func _effect_summary(card: Dictionary) -> String:
	var names := {
		"damage": "伤害", "block": "护盾", "heal": "疗愈", "gain_qi": "回元",
		"draw": "抽牌", "weak": "虚弱", "vulnerable": "破绽", "opening": "破绽",
		"sword_intent": "剑意", "spell_seal": "法印", "poison": "丹毒"
	}
	var parts: Array[String] = []
	for effect in card.get("effects", []):
		if not effect is Dictionary:
			continue
		var kind := String(effect.get("type", ""))
		var status_id := String(effect.get("statusId", effect.get("statusType", "")))
		var label := String(names.get(status_id if kind == "status" else kind, "效果"))
		parts.append("%s%s" % [label, _display_value(effect.get("value", ""))])
	return " · ".join(parts)
