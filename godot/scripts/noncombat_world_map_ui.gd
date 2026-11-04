extends Control

const GameSkin = preload("res://scripts/game_ui_skin.gd")
const Registry = preload("res://scripts/runtime_data_registry.gd")

signal closed

var _projection: Dictionary = {}
var _selected_id := ""
var _canvas: Control
var _detail: RichTextLabel
var _heading: Label
var _pulse_label: Label
var _close_button: Button
var _registry: RefCounted


func _ready() -> void:
	_registry = Registry.new()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.04, 0.06, 0.96)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var frame := PanelContainer.new()
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.offset_left = 32
	frame.offset_top = 24
	frame.offset_right = -32
	frame.offset_bottom = -24
	frame.add_theme_stylebox_override("panel", GameSkin.plaque(0.96))
	add_child(frame)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	frame.add_child(column)
	var header := HBoxContainer.new()
	column.add_child(header)
	_heading = Label.new()
	_heading.add_theme_font_size_override("font_size", 26)
	_heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_heading)
	var locate := Button.new()
	locate.text = "定位主角"
	locate.custom_minimum_size = Vector2(112, 42)
	GameSkin.apply_action_button(locate, GameSkin.JADE)
	locate.pressed.connect(func() -> void: _select_node(String(_projection.get(
		"currentNodeId", "sect"))))
	header.add_child(locate)
	_close_button = Button.new()
	_close_button.name = "CloseWorldMap"
	_close_button.text = "返回剧情  Esc"
	_close_button.custom_minimum_size = Vector2(154, 42)
	GameSkin.apply_action_button(_close_button, GameSkin.BRASS)
	_close_button.pressed.connect(_close)
	header.add_child(_close_button)
	var guidance := Label.new()
	guidance.text = "点选地点查看命线与商路；行路由剧情决定。"
	guidance.add_theme_color_override("font_color", GameSkin.MUTED_PAPER)
	column.add_child(guidance)
	_pulse_label = Label.new()
	_pulse_label.name = "WorldPulseHeadline"
	_pulse_label.add_theme_color_override("font_color", GameSkin.PAPER)
	column.add_child(_pulse_label)
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 18)
	column.add_child(body)
	_canvas = Control.new()
	_canvas.name = "WorldMapCanvas"
	_canvas.custom_minimum_size = Vector2(580, 420)
	_canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(_canvas)
	_canvas.resized.connect(_render_canvas)
	var detail_panel := PanelContainer.new()
	detail_panel.custom_minimum_size = Vector2(315, 0)
	detail_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(detail_panel)
	_detail = RichTextLabel.new()
	_detail.name = "WorldMapDetail"
	_detail.bbcode_enabled = true
	_detail.scroll_active = true
	_detail.fit_content = false
	_detail.add_theme_font_size_override("normal_font_size", 17)
	_detail.add_theme_color_override("default_color", GameSkin.PAPER)
	detail_panel.add_child(_detail)
	call_deferred("_render_canvas")


func open_map(projection: Dictionary) -> void:
	_projection = projection.duplicate(true)
	_selected_id = String(_projection.get("currentNodeId", "sect"))
	_heading.text = "%s  ·  第 %s 回" % [String(_projection.get("title", "山河命卷")),
		str(_projection.get("turn", 0))]
	_pulse_label.text = String(_projection.get("worldPulse", {}).get("headline",
		"山河气脉尚稳"))
	_render_canvas()
	_render_detail()
	visible = true
	_close_button.grab_focus()


func _unhandled_key_input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed \
			and not event.echo and (event.keycode == KEY_ESCAPE or event.keycode == KEY_M):
		_close()
		get_viewport().set_input_as_handled()


func _close() -> void:
	visible = false
	closed.emit()


func _render_canvas() -> void:
	if _canvas == null or _projection.is_empty():
		return
	for child in _canvas.get_children():
		child.queue_free()
	var nodes_by_id := {}
	for node in _projection.get("nodes", []):
		nodes_by_id[node.id] = node
	var map_rect := Rect2(Vector2(24, 36), _canvas.size - Vector2(48, 72))
	for route in _projection.get("routes", []):
		if not nodes_by_id.has(route.get("from")) \
				or not nodes_by_id.has(route.get("to")):
			continue
		var a := _point(nodes_by_id[route["from"]], map_rect)
		var b := _point(nodes_by_id[route["to"]], map_rect)
		var normal := (b - a).orthogonal().normalized()
		var control := (a + b) / 2.0 + normal * float(route.get("curve", 0))
		var line := Line2D.new()
		line.width = 2.0 if route.get("type") == "trade" else 1.4
		line.default_color = Color(0.52, 0.45, 0.30, 0.45) if route.get(
			"locked") else Color(0.72, 0.62, 0.43, 0.80)
		for step in 13:
			var t := float(step) / 12.0
			line.add_point(a * (1.0 - t) * (1.0 - t) + control * 2.0 * t *
				(1.0 - t) + b * t * t)
		_canvas.add_child(line)
	for node in _projection.get("nodes", []):
		var marker := Button.new()
		marker.name = "MapNode_" + String(node.id)
		marker.text = String(node.get("displayName", "雾中地"))
		marker.tooltip_text = "主角当前位置" if node.get("current") else String(
			node.get("name", "尚未发现的地域"))
		marker.custom_minimum_size = Vector2(70, 31)
		marker.position = _point(node, map_rect) - Vector2(35, 15)
		GameSkin.apply_action_button(marker, GameSkin.BRASS if node.get(
			"current") else GameSkin.JADE)
		marker.add_theme_font_size_override("font_size", 14)
		marker.modulate = Color(1.0, 0.87, 0.62) if node.get("current") else Color(
			0.64, 0.67, 0.68) if not node.get("discovered") else Color.WHITE
		marker.pressed.connect(_select_node.bind(String(node.id)))
		_canvas.add_child(marker)
	var character_offsets := [Vector2(28, -39), Vector2(-44, -39),
		Vector2(28, 6), Vector2(-44, 6)]
	var counts := {}
	for npc in _projection.get("characters", []):
		var node_id := String(npc.get("nodeId", ""))
		if not nodes_by_id.has(node_id):
			continue
		var portrait: Texture2D = _registry.texture_for(String(npc.get("portrait", "")))
		if portrait == null:
			continue
		var slot := int(counts.get(node_id, 0))
		counts[node_id] = slot + 1
		var actor := TextureButton.new()
		actor.name = "MapCharacter_" + String(npc.id)
		actor.texture_normal = portrait
		actor.ignore_texture_size = true
		actor.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		actor.custom_minimum_size = Vector2(36, 36)
		actor.position = _point(nodes_by_id[node_id], map_rect) + \
			character_offsets[slot % character_offsets.size()]
		actor.tooltip_text = "%s · %s" % [String(npc.get("name", npc.id)),
			String(npc.get("location", ""))]
		actor.pressed.connect(_select_node.bind(node_id))
		_canvas.add_child(actor)


func _point(node: Dictionary, rect: Rect2) -> Vector2:
	return rect.position + Vector2(float(node.get("x", 0)) / 100.0 * rect.size.x,
		float(node.get("y", 0)) / 100.0 * rect.size.y)


func _select_node(node_id: String) -> void:
	_selected_id = node_id
	_render_detail()


func _render_detail() -> void:
	if _detail == null or _projection.is_empty():
		return
	var node: Dictionary = {}
	for item in _projection.get("nodes", []):
		if item.get("id") == _selected_id:
			node = item
			break
	if node.is_empty():
		return
	var lines := ["[font_size=25]%s[/font_size]" % String(node.get("name", "雾中地")),
		"[color=#d9bd86]%s[/color]" % ("主角所在地" if node.get("current") else
			"已亲历" if node.get("visited") else "尚未亲历"),
		"", String(node.get("summary", "")), "", "[b]地标[/b]"]
	for landmark in node.get("landmarks", []) if node.get("discovered") else []:
		lines.append("· " + String(landmark))
	for faction in node.get("factionDetails", []):
		lines.append("· %s · 声望 %s（%s）" % [String(faction.get("name", "")),
			str(faction.get("reputation", 0)), String(faction.get("level", ""))])
		for sub in faction.get("subfactions", []):
			lines.append("  %s · 声望 %s（%s）" % [String(sub.get("name", "")),
				str(sub.get("reputation", 0)), String(sub.get("level", ""))])
		if not String(faction.get("undercurrentName", "")).is_empty():
			lines.append("  %s · 第 %s 阶段" % [String(faction.undercurrentName),
				str(faction.get("undercurrentStage", 0))])
			lines.append("  " + String(faction.get("undercurrentText", "")))
	if not node.get("discovered"):
		lines.append("尚未显形")
	lines.append("")
	lines.append("[b]此刻人物[/b]")
	var npc_count := 0
	for npc in _projection.get("characters", []):
		if npc.get("nodeId") == _selected_id:
			lines.append("· %s · %s · %s" % [String(npc.get("name", "")),
				String(npc.get("location", "")), String(npc.get("emotion", "平静"))])
			npc_count += 1
	if npc_count == 0:
		lines.append("此刻没有已知角色驻留")
	lines.append("")
	lines.append("[b]剧情命线[/b]")
	for chronicle in _projection.get("chronicles", []):
		if chronicle.get("node") == _selected_id:
			lines.append("· %s [%s]" % [String(chronicle.get("title", "")),
				_state_label(String(chronicle.get("state", "")))])
	lines.append("")
	lines.append("[b]相连道路[/b]")
	for route in _projection.get("routes", []):
		if route.get("from") == _selected_id or route.get("to") == _selected_id:
			lines.append("· %s · %s" % [String(route.get("name", route.get("id", ""))),
				_state_label(String(route.get("condition", "")))])
	if node.get("current") and not String(_projection.get(
			"currentCardTitle", "")).is_empty():
		lines.append("")
		lines.append("当前剧情：" + String(_projection.currentCardTitle))
	_detail.text = "\n".join(lines)


func _state_label(value: String) -> String:
	return {"active": "正在发生", "available": "可追踪", "resolved": "已留史",
		"locked": "尚未显形", "danger": "凶险", "prosperous": "繁荣",
		"open": "通达"}.get(value, value)
