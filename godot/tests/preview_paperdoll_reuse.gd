extends SceneTree

const Actor = preload("res://scripts/paperdoll_actor_study.gd")
const OUT := "res://output/captures/godot-migration/paperdoll-v1/"
var actors: Array[Node2D] = []
var stage: Node
var battle: Control
var caption: Label
var status: Label
var panel: PanelContainer
var study_paused := false
var back_view := false
var last_key := 0
var size_tag := "1280"
var recording := false


func _initialize() -> void:
	call_deferred("_start")


func _start() -> void:
	root.size = Vector2i(1024, 768) if "--review-1024" in OS.get_cmdline_user_args() else Vector2i(1280, 800)
	size_tag = "1024" if root.size.x == 1024 else "1280"
	battle = load("res://scenes/main.tscn").instantiate()
	root.add_child(battle)
	await create_timer(0.5).timeout
	stage = battle.duel_stage
	if stage == null or not battle.stage_assets_ready:
		push_error("Original battle stage failed to load")
		quit(1)
		return
	var world: Node2D = stage.get_node("Viewport/World")
	world.get_node("PlayerAnchor").hide()
	world.get_node("EnemyAnchor").hide()
	for info in [["BaseSample", Vector2(230, 244), "base", "traded_rusted_sword"], ["ArmorSample", Vector2(410, 244), "玄铁甲", "licensed_rusted_sword"]]:
		var actor := Actor.new()
		actor.name = info[0]
		actor.position = info[1]
		actor.z_index = 1
		world.add_child(actor)
		if not actor.configure() or not actor.set_loadout(info[2], info[3], "灵泉葫芦"):
			push_error("Paperdoll assets failed to assemble")
			quit(1)
			return
		for foot_x in [-5, 5]:
			var shadow := Polygon2D.new()
			shadow.color = Color(0.03, 0.04, 0.05, 0.3)
			shadow.polygon = PackedVector2Array([Vector2(-4,0),Vector2(-2,-1),Vector2(3,-1),Vector2(5,0),Vector2(3,1),Vector2(-3,1)])
			shadow.position = Vector2(foot_x,0)
			actor.add_child(shadow)
			actor.move_child(shadow,0)
		actors.append(actor)
	# The real hand is rebuilt on resize. Lock its authority, not one set of buttons.
	battle.combat.input_locked = true
	battle._render_hand()
	for control in [battle.end_button,battle.flee_button,battle.return_button,battle.intent_slip,battle.player_info_back,battle.enemy_info_back,battle.player_label,battle.enemy_label,battle.player_health_track,battle.player_health_fill,battle.player_qi_track,battle.player_qi_fill,battle.enemy_health_track,battle.enemy_health_fill,battle.state_info_back,battle.state_slip_anchor]:
		if is_instance_valid(control): control.hide()
	battle.title_label.text = "分件换装试作 · 原石室 / 原卡牌材质"
	_make_controls()
	root.size_changed.connect(_layout)
	_layout()
	if "--check-isolation" in OS.get_cmdline_user_args():
		await _check_isolation()
	elif "--capture" in OS.get_cmdline_user_args():
		await _capture_set()
	elif "--record" in OS.get_cmdline_user_args():
		await _record()


func _make_controls() -> void:
	panel = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035,0.055,0.067,0.94)
	style.border_color = Color(0.38,0.40,0.34)
	style.set_border_width_all(1)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel",style)
	root.add_child(panel)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation",7)
	panel.add_child(rows)
	caption = Label.new()
	caption.text = "同一身份、同一动作库：左侧基础服，右侧玄铁甲"
	caption.add_theme_font_size_override("font_size",19)
	rows.add_child(caption)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation",7)
	rows.add_child(buttons)
	for data in [["1 换甲",KEY_1],["2 换剑",KEY_2],["3 腰挂",KEY_3],["4 前/后",KEY_4],["空格 试锋",KEY_SPACE],["H 受击",KEY_H],["P 暂停",KEY_P],["R 待机",KEY_R]]:
		var button := Button.new()
		button.text = data[0]
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(_command.bind(data[1]))
		buttons.add_child(button)
	status = Label.new()
	status.add_theme_font_size_override("font_size",14)
	rows.add_child(status)


func _layout() -> void:
	panel.position = Vector2(20,48)
	panel.size.x = root.size.x-40


func _process(_delta: float) -> bool:
	if actors.is_empty() or status == null: return false
	var state: Dictionary = actors[0].get_debug_state()
	status.text = "左：%s / %s / %s  ·  %s %.2fs  ·  原地动作研究，不结算伤害" % ["布衣" if state.outfit=="base" else "玄铁甲","易手残剑" if state.weapon=="traded_rusted_sword" else "净炼残剑","葫芦" if not state.accessory.is_empty() else "无腰挂",{"idle":"待机","thrust":"试锋","hurt":"受击"}[state.action],state.time]
	if not study_paused:
		for actor in actors:
			var s: Dictionary = actor.get_debug_state()
			if (s.action=="thrust" and s.time>=0.899) or (s.action=="hurt" and s.time>=0.649): actor.play_action("idle")
	if recording: return false
	var pressed := 0
	for key in [KEY_ESCAPE,KEY_1,KEY_2,KEY_3,KEY_4,KEY_SPACE,KEY_H,KEY_P,KEY_R]:
		if Input.is_physical_key_pressed(key):
			pressed = key
			break
	if pressed==0: last_key=0
	elif pressed!=last_key:
		last_key=pressed
		_command(pressed)
	return false


func _command(key: int) -> void:
	var state: Dictionary = actors[0].get_debug_state()
	match key:
		KEY_ESCAPE: quit(0)
		KEY_1:
			actors[0].set_loadout("玄铁甲" if state.outfit=="base" else "base",state.weapon,state.accessory)
			if not recording: caption.text="左侧可切换装束 · 右侧玄铁甲作为动作对照"
		KEY_2: actors[0].set_loadout(state.outfit,"licensed_rusted_sword" if state.weapon=="traded_rusted_sword" else "traded_rusted_sword",state.accessory)
		KEY_3: actors[0].set_loadout(state.outfit,state.weapon,"灵泉葫芦" if state.accessory.is_empty() else "")
		KEY_4:
			back_view=not back_view
			for actor in actors: actor.set_view("back" if back_view else "front")
		KEY_P: _pause(not study_paused)
		KEY_SPACE: _play("thrust")
		KEY_H: _play("hurt")
		KEY_R: _play("idle")


func _pause(value: bool) -> void:
	study_paused=value
	for actor in actors: actor.set_process(not value)


func _play(action: String) -> void:
	_pause(false)
	for actor in actors: actor.play_action(action)


func _pose(action: String, time: float) -> void:
	_pause(true)
	for actor in actors:
		actor.play_action(action)
		actor.seek_action(time)


func _shot(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var file := OUT+name+"_"+size_tag+".png"
	if root.get_texture().get_image().save_png(file)!=OK:
		push_error("Could not capture "+file)
		quit(1)


func _check_isolation() -> void:
	recording = true
	var before: Dictionary = battle.combat.state.duplicate(true)
	root.size = Vector2i(1024,768)
	# Headless windows do not emit a native resize event, so send the same signal.
	root.size_changed.emit()
	await process_frame
	var all_disabled := true
	for button in battle.hand_row.get_children():
		if button is Button: all_disabled = all_disabled and button.disabled
	var key := InputEventKey.new()
	key.keycode = KEY_1
	key.pressed = true
	battle.hand_row._unhandled_key_input(key)
	# Exercise the actual click consumer too, even though the UI should be disabled.
	battle.hand_row.card_selected.emit(0)
	await process_frame
	var unchanged: bool = before == battle.combat.state
	var passed: bool = all_disabled and unchanged and battle.pending_presentations == 0
	print("PAPERDOLL_ISOLATION ","PASS" if passed else "FAIL"," cards_disabled=",all_disabled," state_unchanged=",unchanged," pending_presentations=",battle.pending_presentations)
	quit(0 if passed else 1)


func _capture_set() -> void:
	recording=true
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	for view in ["front","back"]:
		for actor in actors: actor.set_view(view)
		_pose("idle",0.0)
		await _shot("idle_"+view)
		_pose("thrust",0.4)
		await _shot("thrust_"+view)
		_pose("hurt",0.18)
		await _shot("hurt_"+view)
	for actor in actors: actor.set_view("front")
	_pose("thrust",0.32)
	var before: Dictionary = actors[0].get_debug_state()
	actors[0].set_loadout("玄铁甲","licensed_rusted_sword","")
	var after: Dictionary = actors[0].get_debug_state()
	assert(before.time==after.time and before.root_position==after.root_position)
	caption.text="预备阶段暂停换甲、换剑、卸腰挂：脚点与动作进度保留"
	await _shot("midaction_swap")
	# Each root shares the room pillar Y sort layer. Individual parts stay z=0.
	_pose("idle",0.0)
	for i in 2:
		var pillar: Node2D=stage.get_node("Viewport/World/"+("QingyunForeground" if i==0 else "QingyunForegroundRight"))
		actors[i].position=pillar.position+Vector2(8 if i==0 else -8,-10 if i==0 else 3)
	caption.text="世界遮挡检查：左侧柱后 / 右侧柱前，整个人物含武器统一排序"
	await _shot("pillar_order")
	print("PAPERDOLL_ROOM_CAPTURE_PASS size=",size_tag," views=2 original_room=true original_cards=true shared_actors=2 static_poses=8")
	quit(0)


func _record() -> void:
	recording=true
	await create_timer(2.5).timeout
	_play("thrust")
	await create_timer(1.4).timeout
	_play("hurt")
	await create_timer(1.0).timeout
	_command(KEY_4)
	await create_timer(1.0).timeout
	_play("thrust")
	await create_timer(1.2).timeout
	_pose("thrust",0.32)
	caption.text="暂停在同一姿态换装：骨骼、脚点和动作时间保持"
	await create_timer(0.6).timeout
	_command(KEY_1)
	_command(KEY_2)
	_command(KEY_3)
	await create_timer(1.2).timeout
	_pause(false)
	await create_timer(1.0).timeout
	_command(KEY_4)
	_play("idle")
	caption.text="同一角色分件 / 共用动作库 · 两视图换装研究"
	await create_timer(2.4).timeout
	print("PAPERDOLL_MOVIE_COMPLETE shared_animation=true full_approach=false gameplay_damage=false")
	quit(0)
