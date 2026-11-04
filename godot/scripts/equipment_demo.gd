extends Control

const Domain = preload("res://scripts/equipment_demo_domain.gd")
const Actor = preload("res://scripts/equipment_demo_actor.gd")
const Registry = preload("res://scripts/runtime_data_registry.gd")
const Router = preload("res://scripts/combat_stage_router.gd")
const Stage = preload("res://scenes/duel_stage_hd2d.tscn")
const FONT = preload("res://assets/fonts/NotoSansSC-VF.ttf")
const TITLE_FONT = preload("res://assets/fonts/LXGWWenKai-Regular.ttf")
const GOLD := Color("dec696")
const INK := Color("171b20")
const PALE := Color("f0e6d2")
const SLOT_ITEMS := {
	"weapon": ["", "问道剑", "brokenSword"],
	"armor": ["", "玄铁甲", "灵纹法袍"],
	"accessory": ["", "灵泉葫芦"],
	"artifact": ["", "青云剑匣"],
}
const ITEM_NAMES := {"": "卸下", "问道剑": "问道剑", "brokenSword": "剑冢残剑",
	"玄铁甲": "玄铁甲", "灵纹法袍": "灵纹法袍", "灵泉葫芦": "灵泉葫芦", "青云剑匣": "青云剑匣"}
const ITEM_EFFECTS := {
	"": "空槽",
	"问道剑": "攻击 +3 · 会心 +5",
	"brokenSword": "攻击 +1",
	"玄铁甲": "受到攻击时减伤 1",
	"灵纹法袍": "减伤 2 · 回合真元 +1*",
	"灵泉葫芦": "回合末护体值 +1*",
	"青云剑匣": "每三张剑式 · 飞剑出匣",
}

var domain: RefCounted
var actor: Node3D
var stage: SubViewportContainer
var buttons: Dictionary = {}
var selectors: Dictionary = {}
var presentation_events: Array[Dictionary] = []
var busy := false
var _summaries: Dictionary = {}
var _status: Label
var _enemy_status: Label
var _hp_bar: ProgressBar
var _qi_bar: ProgressBar
var _enemy_hp_bar: ProgressBar
var _hp_number: Label
var _qi_number: Label
var _enemy_hp_number: Label
var _pose: Label
var _log: Label
var _message: Label
var _notes: PanelContainer
var _notes_text: Label
var _notes_close: Button
var _title: Label
var _subtitle: Label
var _player_panel: PanelContainer
var _enemy_panel: PanelContainer
var _log_panel: PanelContainer
var _dock: PanelContainer
var _toast: PanelContainer
var _source_button: Button
var _pending: Array[Dictionary] = []
var _queued_state: Dictionary = {}
var _fx_clock := -1.0
var _last_sequence := 0
var _floating: Array[Dictionary] = []
var _flights: Array[Dictionary] = []
var _camera: Camera3D
var _enemy: Node3D

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = _theme()
	var data := Registry.new()
	var encounter: Dictionary = data.get_first_encounter()
	stage = Stage.instantiate()
	stage.use_trial_v17_candidate = true
	if not stage.bind_stage_context(Router.new(data).resolve_encounter(String(encounter.id))):
		push_error("换装试剑无法载入现有演武厅")
		return
	stage.use_demo_composition()
	add_child(stage)
	stage.get_actor_model("player").visible = false
	stage.get_actor_anchor("enemy").position.x += 0.16
	_camera = stage.get_node("Viewport/World/CameraRig/Camera")
	_enemy = stage.get_actor_model("enemy")
	actor = Actor.new()
	actor.camera = _camera
	actor.home_offset = Vector3(-0.25, 0.0, 0.0)
	actor.visual_scale = 1.055
	stage.get_actor_anchor("player").add_child(actor)
	actor.frame_changed.connect(_on_frame_changed)
	actor.contact.connect(_on_contact)
	actor.action_finished.connect(_on_action_finished)
	_build_ui()
	resized.connect(_layout_ui)
	_layout_ui()
	domain = Domain.new()
	domain.changed.connect(_on_domain_changed)
	for slot in ["weapon", "armor", "accessory", "artifact"]:
		domain.equip(slot, {"weapon": "问道剑", "armor": "玄铁甲", "accessory": "灵泉葫芦", "artifact": "青云剑匣"}[slot])
	domain.reset()
	_refresh(domain.snapshot())
	if not actor.ready_assets:
		_message.text = "素材尚未就绪：请检查控制台中的缺失文件。"
		_set_busy(true)
	else:
		_message.text = "选择装备，再出剑或格挡；木人每回合攻击 3。"

func _theme() -> Theme:
	var result := Theme.new()
	result.default_font = FONT
	result.default_font_size = 16
	for type in ["Label", "Button", "OptionButton"]:
		result.set_color("font_color", type, PALE)
	for type in ["Button", "OptionButton"]:
		result.set_stylebox("normal", type, _box(Color("242b2e"), Color("83745b"), 7))
		result.set_stylebox("hover", type, _box(Color("3a4446"), GOLD, 7))
		result.set_stylebox("pressed", type, _box(Color("514b3c"), GOLD, 7))
		result.set_stylebox("disabled", type, _box(Color("202528"), Color("4d5350"), 7))
		result.set_color("font_disabled_color", type, Color("a5a79e"))
		result.set_stylebox("focus", type, _box(Color(0, 0, 0, 0), GOLD, 6))
	return result

func _box(fill: Color, border: Color, padding: int = 14) -> StyleBoxFlat:
	var result := StyleBoxFlat.new()
	result.bg_color = fill
	result.border_color = border
	result.set_border_width_all(1)
	result.set_corner_radius_all(3)
	result.content_margin_left = padding
	result.content_margin_right = padding
	result.content_margin_top = 8
	result.content_margin_bottom = 8
	return result

func _label(text: String, size: int = 16, color: Color = Color("e8e1d1")) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label

func _panel(fill: Color = Color(0.045, 0.056, 0.061, 0.94), border: Color = Color("806c4e")) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _box(fill, border))
	return panel

func _meter(fill_color: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(96, 12)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var track := StyleBoxFlat.new()
	track.bg_color = Color("252c30")
	track.border_color = Color("5d584c")
	track.set_border_width_all(1)
	track.set_corner_radius_all(2)
	var fill := StyleBoxFlat.new()
	fill.bg_color = fill_color
	fill.set_corner_radius_all(2)
	bar.add_theme_stylebox_override("background", track)
	bar.add_theme_stylebox_override("fill", fill)
	return bar

func _meter_row(parent: VBoxContainer, title: String, tint: Color) -> Dictionary:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)
	var name := _label(title, 13, Color("d2c4a8"))
	name.custom_minimum_size.x = 36
	row.add_child(name)
	var bar := _meter(tint)
	row.add_child(bar)
	var amount := _label("", 13, PALE)
	amount.custom_minimum_size.x = 55
	amount.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(amount)
	return {"bar": bar, "number": amount}

func _build_ui() -> void:
	_title = _label("叶凌云 · 试剑", 25, GOLD)
	_title.add_theme_font_override("font", TITLE_FONT)
	add_child(_title)
	_subtitle = _label("演武厅  /  装备试炼", 13, Color("d1c4ab"))
	add_child(_subtitle)
	_source_button = Button.new()
	_source_button.text = "装备规则"
	_source_button.size = Vector2(112, 36)
	_source_button.pressed.connect(_toggle_notes)
	add_child(_source_button)

	_player_panel = _panel()
	_player_panel.size = Vector2(286, 112)
	add_child(_player_panel)
	var player_rows := VBoxContainer.new()
	player_rows.add_theme_constant_override("separation", 4)
	_player_panel.add_child(player_rows)
	var player_heading := HBoxContainer.new()
	player_rows.add_child(player_heading)
	player_heading.add_child(_label("叶凌云", 17, GOLD))
	var heading_space := Control.new()
	heading_space.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	player_heading.add_child(heading_space)
	player_heading.add_child(_label("试剑者", 12, Color("b7b6a9")))
	var hp := _meter_row(player_rows, "气血", Color("bd6257"))
	_hp_bar = hp.bar
	_hp_number = hp.number
	var qi := _meter_row(player_rows, "真元", Color("6babb7"))
	_qi_bar = qi.bar
	_qi_number = qi.number
	_status = _label("", 13, Color("d8c28f"))
	player_rows.add_child(_status)

	_enemy_panel = _panel()
	_enemy_panel.size = Vector2(286, 102)
	add_child(_enemy_panel)
	var enemy_rows := VBoxContainer.new()
	enemy_rows.add_theme_constant_override("separation", 5)
	_enemy_panel.add_child(enemy_rows)
	enemy_rows.add_child(_label("演武木人", 17, GOLD))
	var enemy_hp := _meter_row(enemy_rows, "耐久", Color("a7845d"))
	_enemy_hp_bar = enemy_hp.bar
	_enemy_hp_number = enemy_hp.number
	_enemy_status = _label("", 13, Color("d3c9b1"))
	enemy_rows.add_child(_enemy_status)

	_log_panel = _panel(Color(0.045, 0.056, 0.061, 0.88), Color("71634d"))
	_log_panel.size = Vector2(286, 94)
	add_child(_log_panel)
	_log = _label("", 13, Color("e2d9c6"))
	_log.custom_minimum_size = Vector2(258, 75)
	_log.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_log_panel.add_child(_log)

	_dock = _panel(Color(0.045, 0.057, 0.063, 0.96), Color("95805c"))
	add_child(_dock)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 7)
	_dock.add_child(rows)
	var equipment_row := HBoxContainer.new()
	equipment_row.add_theme_constant_override("separation", 18)
	rows.add_child(equipment_row)
	var slot_names := {"weapon": "佩剑", "armor": "衣甲", "accessory": "随身", "artifact": "法宝"}
	for slot in ["weapon", "armor", "accessory", "artifact"]:
		var column := VBoxContainer.new()
		column.add_theme_constant_override("separation", 3)
		column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		equipment_row.add_child(column)
		column.add_child(_label(slot_names[slot], 14, GOLD))
		var selector := OptionButton.new()
		selector.name = "Equip_" + slot
		selector.custom_minimum_size = Vector2(160, 33)
		selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		for id in SLOT_ITEMS[slot]:
			selector.add_item(ITEM_NAMES[id])
		selector.item_selected.connect(_select_equipment.bind(slot))
		column.add_child(selector)
		selectors[slot] = selector
		var summary := _label("", 13, Color("d4ceb9"))
		column.add_child(summary)
		_summaries[slot] = summary
	var action_row := HBoxContainer.new()
	action_row.add_theme_constant_override("separation", 9)
	rows.add_child(action_row)
	for entry in [
		["attack", "突刺  1 真元", 142], ["guard", "格挡  2 真元", 142],
		["end_turn", "结束回合", 118], ["idle", "待机", 76],
		["reset", "重置演练", 108], ["pause", "暂停动作", 104], ["slow", "慢放 ×0.5", 108],
	]:
		if entry[0] == "reset":
			var action_spacer := Control.new()
			action_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			action_row.add_child(action_spacer)
		var button := Button.new()
		button.name = "Action_" + entry[0]
		button.text = entry[1]
		button.custom_minimum_size = Vector2(entry[2], 38)
		button.pressed.connect(_command.bind(String(entry[0])))
		if entry[0] in ["attack", "guard"]:
			var tint := Color("66512e") if entry[0] == "attack" else Color("284c53")
			button.add_theme_stylebox_override("normal", _box(tint, GOLD, 8))
			button.add_theme_color_override("font_color", Color("fff0d3"))
		action_row.add_child(button)
		buttons[entry[0]] = button
	rows.add_child(_label("1 突刺   ·   2 格挡   ·   空格 结束回合", 12, Color("b6b7aa")))

	_toast = _panel(Color(0.065, 0.074, 0.073, 0.91), Color("837553"))
	add_child(_toast)
	var toast_row := HBoxContainer.new()
	toast_row.add_theme_constant_override("separation", 14)
	_toast.add_child(toast_row)
	_pose = _label("待机", 13, GOLD)
	_pose.custom_minimum_size.x = 120
	toast_row.add_child(_pose)
	_message = _label("", 14, PALE)
	_message.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_message.clip_text = true
	toast_row.add_child(_message)

	_notes = _panel(Color(0.035, 0.045, 0.05, 0.98), GOLD)
	_notes.size = Vector2(680, 340)
	_notes.visible = false
	add_child(_notes)
	_notes_text = _label("", 15, PALE)
	_notes_text.custom_minimum_size = Vector2(650, 310)
	_notes_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_notes.add_child(_notes_text)
	_notes_close = Button.new()
	_notes_close.text = "关闭"
	_notes_close.size = Vector2(58, 30)
	_notes_close.visible = false
	_notes_close.pressed.connect(_toggle_notes)
	add_child(_notes_close)

func _toggle_notes() -> void:
	_notes.visible = not _notes.visible
	_notes_close.visible = _notes.visible

func _layout_ui() -> void:
	if _dock == null:
		return
	var width := size.x
	var height := size.y
	var edge := clampf(width * 0.02, 16.0, 30.0)
	_title.position = Vector2(edge, 15)
	_subtitle.position = Vector2(edge + 2, 53)
	_source_button.position = Vector2(width - edge - 112, 20)
	_player_panel.position = Vector2(edge, 88)
	_enemy_panel.position = Vector2(width - edge - _enemy_panel.size.x, 88)
	_log_panel.position = Vector2(width - edge - _log_panel.size.x, 202)
	_log_panel.visible = width >= 1160.0
	var dock_width := minf(width - edge * 2.0, 1240.0)
	_dock.size = Vector2(dock_width, 174)
	_dock.position = Vector2((width - dock_width) * 0.5, height - 190)
	var toast_width := minf(width - edge * 2.0, 730.0)
	_toast.size = Vector2(toast_width, 38)
	_toast.position = Vector2((width - toast_width) * 0.5, _dock.position.y - 46)
	_notes.position = Vector2((width - _notes.size.x) * 0.5, maxf(86.0, (height - _notes.size.y) * 0.5))
	_notes_close.position = _notes.position + Vector2(_notes.size.x - 70, 8)

func _select_equipment(index: int, slot: String) -> void:
	if busy:
		return
	domain.equip(slot, String(SLOT_ITEMS[slot][index]))

func _command(command: String) -> void:
	if domain == null:
		return
	if command == "pause":
		actor.set_playback_paused(not actor.playback_paused)
		buttons.pause.text = "继续动作" if actor.playback_paused else "暂停动作"
		_sync_enemy_clock()
		return
	if command == "slow":
		actor.speed_scale = 0.5 if actor.speed_scale == 1.0 else 1.0
		buttons.slow.text = "正常 ×1.0" if actor.speed_scale == 0.5 else "慢放 ×0.5"
		_sync_enemy_clock()
		return
	if command == "reset":
		_pending.clear()
		_queued_state.clear()
		_fx_clock = -1.0
		for effect in _floating:
			effect.node.queue_free()
		for flight in _flights:
			flight.node.queue_free()
		_floating.clear()
		_flights.clear()
		actor.play_clip("idle")
		_enemy.play_action("idle")
		_set_busy(false)
		domain.reset()
		return
	if busy:
		return
	if command == "idle":
		actor.play_clip("idle")
		return
	var accepted := false
	match command:
		"attack": accepted = domain.attack()
		"guard": accepted = domain.guard()
		"end_turn": accepted = domain.end_turn()
	if not accepted:
		_message.text = domain.last_error

func _sync_enemy_clock() -> void:
	var playback: float = 0.0 if actor.playback_paused else float(actor.speed_scale)
	_enemy.get_sprite().speed_scale = playback
	_enemy.get_animation_player().speed_scale = playback

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if _notes.visible:
			if event.keycode == KEY_ESCAPE:
				_toggle_notes()
			return
		if event.keycode == KEY_1:
			_command("attack")
		elif event.keycode == KEY_2:
			_command("guard")
		elif event.keycode == KEY_SPACE:
			_command("end_turn")

func _on_domain_changed(event: Dictionary) -> void:
	var sequence := int(event.sequence)
	if sequence <= _last_sequence:
		return
	_last_sequence = sequence
	actor.set_equipment(event.snapshot.equipment)
	if event.kind in ["EQUIP", "RESET"]:
		_queued_state.clear()
		_refresh(event.snapshot)
		_message.text = "已换装，可直接试招。" if event.kind == "EQUIP" else "演练已重置，保留当前装备。"
		return
	_queued_state = event.snapshot
	_pending.clear()
	for effect in event.events:
		_pending.append(effect)
	_set_busy(true)
	actor.play_clip("thrust" if event.action == "attack" else "guard")
	_message.text = "试锋一点 · 突刺" if event.action == "attack" else "剑罡护脉 · 格挡"
	if event.action == "hurt":
		_message.text = "木人回击 · 衣甲减伤 → 护盾吸收 → 回合恢复"
		_fx_clock = 0.0
		if _enemy.has_method("play_action"):
			_enemy.play_action("attack")
	else:
		_fx_clock = -1.0

func _refresh(state: Dictionary) -> void:
	_hp_bar.max_value = state.maxHp
	_hp_bar.value = state.hp
	_hp_number.text = "%d / %d" % [state.hp, state.maxHp]
	_qi_bar.max_value = state.maxQi
	_qi_bar.value = state.qi
	_qi_number.text = "%d / %d" % [state.qi, state.maxQi]
	_status.text = "护盾 %d    ·    剑匣 %d / 3" % [state.block, state.artifactCounter]
	_enemy_hp_bar.max_value = state.enemyMaxHp
	_enemy_hp_bar.value = state.enemyHp
	_enemy_hp_number.text = "%d / %d" % [state.enemyHp, state.enemyMaxHp]
	_enemy_status.text = "第 %d 回合    ·    破绽 %d    ·    木人攻击 3" % [state.turn, state.opening]
	for slot in selectors:
		var id := String(state.equipment.get(slot, ""))
		selectors[slot].select(SLOT_ITEMS[slot].find(id))
		_summaries[slot].text = ITEM_EFFECTS.get(id, "")
	var history: Array = state.log
	var lines := PackedStringArray()
	for i in range(maxi(0, history.size() - 2), history.size()):
		lines.append(String(history[i]))
	_log.text = "近期战报\n" + "\n".join(lines)
	_notes_text.text = "装备规则与来源\n\n" + "\n\n".join(PackedStringArray(state.sourceNotes))

func _set_busy(value: bool) -> void:
	busy = value
	for slot in selectors:
		selectors[slot].disabled = value
	for id in ["idle", "attack", "guard", "end_turn"]:
		buttons[id].disabled = value

func _on_frame_changed(clip: String, frame: int) -> void:
	if _pose != null:
		_pose.text = "%s · 姿态 %d / %d  %s" % [{"idle": "待机", "thrust": "突刺", "guard": "格挡"}.get(clip, clip), frame + 1, actor.frame_count(), "×0.5" if actor.speed_scale < 1.0 else ""]

func _on_contact(_clip: String) -> void:
	if _fx_clock < 0.0:
		_present_pending()

func _on_action_finished(_clip: String) -> void:
	_present_pending()
	_set_busy(false)
	if _enemy.has_method("play_action"):
		_enemy.play_action("idle")

func _present_pending() -> void:
	if not _queued_state.is_empty():
		_refresh(_queued_state)
		_queued_state.clear()
	var effects := _pending.duplicate()
	_pending.clear()
	for effect in effects:
		presentation_events.append(effect.duplicate(true))
		match String(effect.kind):
			"ARTIFACT_TRIGGER": _launch_sword_box()
			"DAMAGE":
				if effect.get("cause") != "artifact":
					_float_text("−%d" % effect.amount, _enemy_point(), Color("f2dca5"))
					if _enemy.has_method("play_action"):
						_enemy.play_action("hurt")
			"BLOCK": _float_text("护盾 +%d" % effect.amount, actor.global_position + Vector3(0.4, 2.7, 0), Color("9ad8ec"))
			"INCOMING": _float_text("−%d  减伤%d" % [effect.amount, effect.armorReduced], actor.global_position + Vector3(0.4, 2.7, 0), Color("f1be9e"))
			"HEAL":
				actor.pulse_gourd()
				_float_text("葫芦 +%d" % effect.amount, actor.global_position + Vector3(-0.2, 2.2, 0), Color("b8d9a1"))
			"QI": _float_text("真元 +%d" % effect.amount, actor.global_position + Vector3(0.8, 3.1, 0), Color("a4d6e0"))
	_fx_clock = -1.0

func _enemy_point() -> Vector3:
	return stage.get_actor_anchor("enemy").global_position + Vector3(0, 2.15, 0)

func _float_text(text: String, point: Vector3, color: Color) -> void:
	var label := Label3D.new()
	label.text = text
	label.font = FONT
	label.font_size = 45
	label.pixel_size = 0.008
	label.modulate = color
	label.outline_size = 8
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	stage.get_node("Viewport/World").add_child(label)
	label.global_position = point
	_floating.append({"node": label, "time": 0.0, "start": point})

func _launch_sword_box() -> void:
	var texture: Texture2D = actor.prop_texture("问道剑")
	if texture == null:
		return
	var flying := Sprite3D.new()
	flying.texture = texture
	flying.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	flying.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	flying.pixel_size = 0.014
	flying.modulate = Color("b3ecf1")
	flying.shaded = false
	flying.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	stage.get_node("Viewport/World").add_child(flying)
	var start: Vector3 = actor.get_socket_world("back")
	flying.global_position = start
	var damage := 0
	for effect in presentation_events.slice(maxi(0, presentation_events.size() - 12)):
		if effect.kind == "DAMAGE" and effect.get("cause") == "artifact":
			damage = int(effect.amount)
	# Read the resolved pending event when this trigger precedes its damage row.
	for effect in domain.snapshot().events:
		if effect.kind == "DAMAGE" and effect.get("cause") == "artifact":
			damage = int(effect.amount)
	_flights.append({"node": flying, "time": 0.0, "start": start, "target": _enemy_point(), "damage": damage, "hit": false})

func _process(delta: float) -> void:
	if actor == null or actor.playback_paused:
		return
	var dt: float = delta * float(actor.speed_scale)
	if _fx_clock >= 0.0:
		_fx_clock += dt
		if _fx_clock >= 0.38:
			_present_pending()
	for i in range(_floating.size() - 1, -1, -1):
		var effect: Dictionary = _floating[i]
		effect.time += dt
		effect.node.global_position = effect.start + Vector3.UP * float(effect.time) * 0.48
		effect.node.modulate.a = minf(1.0, (1.25 - float(effect.time)) * 2.5)
		if effect.time >= 1.25:
			effect.node.queue_free()
			_floating.remove_at(i)
	for i in range(_flights.size() - 1, -1, -1):
		var flight: Dictionary = _flights[i]
		flight.time += dt
		var progress := clampf(float(flight.time) / 0.4, 0.0, 2.0)
		var travel := progress if progress < 1.0 else 2.0 - progress
		flight.node.global_position = (flight.start as Vector3).lerp(flight.target, travel) + Vector3.UP * sin(travel * PI) * 0.5
		if progress >= 1.0 and not flight.hit:
			flight.hit = true
			_float_text("飞剑 −%d" % flight.damage, flight.target + Vector3.UP * 0.4, Color("a2e5ed"))
		if progress >= 2.0:
			flight.node.queue_free()
			_flights.remove_at(i)
