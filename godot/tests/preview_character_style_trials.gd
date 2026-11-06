extends SceneTree

const MANIFEST := "res://assets/battle/undercurrent_pixel_v1/character_style_trials_v2/trials.json"
const OUT := "res://output/captures/godot-migration/character-style-trials-v2/"
var battle: Control
var world: Node2D
var manifest: Dictionary
var figures: Array[Node2D] = []
var captions: Array[Label] = []
var panel: PanelContainer
var status: Label
var selected := 4
var height := 66
var last_key := 0
var capturing := false
var size_tag := "1280"
var pose_mode := false
var pose_figure: Node2D
var pose_caption: Label


func _initialize() -> void:
	call_deferred("_start")


func _start() -> void:
	root.size = Vector2i(1024,768) if "--review-1024" in OS.get_cmdline_user_args() else Vector2i(1280,800)
	size_tag = "1024" if root.size.x == 1024 else "1280"
	manifest = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	assert(manifest.candidates.size() == 5)
	battle = load("res://scenes/main.tscn").instantiate()
	root.add_child(battle)
	await create_timer(0.5).timeout
	assert(battle.stage_assets_ready)
	world = battle.duel_stage.get_node("Viewport/World")
	world.get_node("PlayerAnchor").hide()
	world.get_node("EnemyAnchor").hide()
	battle.combat.input_locked = true
	battle._render_hand()
	for control in [battle.end_button,battle.flee_button,battle.return_button,battle.intent_slip,battle.player_info_back,battle.enemy_info_back,battle.player_label,battle.enemy_label,battle.player_health_track,battle.player_health_fill,battle.player_qi_track,battle.player_qi_fill,battle.enemy_health_track,battle.enemy_health_fill,battle.state_info_back,battle.state_slip_anchor]:
		if is_instance_valid(control): control.hide()
	battle.title_label.text = "完整人物美术试验 · 原石室 / 原卡牌"
	for i in 5:
		var figure := Node2D.new()
		figure.name = manifest.candidates[i].id
		figure.z_index = 1
		world.add_child(figure)
		for j in 2:
			var shadow := Polygon2D.new()
			shadow.name = "FootShadow"+str(j)
			shadow.polygon = PackedVector2Array([Vector2(-3,0),Vector2(-2,-0.6),Vector2(2,-0.6),Vector2(4,0),Vector2(2,0.7),Vector2(-2,0.7)])
			shadow.color = Color(0.02,0.03,0.04,0.25)
			figure.add_child(shadow)
		var art := Sprite2D.new()
		art.name = "Art"
		art.centered = false
		art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		figure.add_child(art)
		figures.append(figure)
		var label := Label.new()
		label.text = ["A","B","C","D","E"][i]
		label.add_theme_font_size_override("font_size",10)
		label.modulate = Color(0.9,0.85,0.7)
		label.z_index = 2
		world.add_child(label)
		captions.append(label)
	pose_figure = figures[4].duplicate()
	pose_figure.name = "EThrustKeyPose"
	world.add_child(pose_figure)
	pose_caption = captions[4].duplicate()
	pose_caption.text = "刺击关键姿态"
	world.add_child(pose_caption)
	_make_controls()
	root.size_changed.connect(_layout)
	_layout()
	_refresh()
	if "--capture" in OS.get_cmdline_user_args():
		await _capture()


func _make_controls() -> void:
	panel = PanelContainer.new()
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.025,0.04,0.045,0.95)
	bg.border_color = Color(0.33,0.37,0.34)
	bg.set_border_width_all(1)
	bg.content_margin_left = 12
	bg.content_margin_top = 9
	bg.content_margin_right = 12
	bg.content_margin_bottom = 9
	panel.add_theme_stylebox_override("panel",bg)
	root.add_child(panel)
	var rows := VBoxContainer.new()
	panel.add_child(rows)
	var title := Label.new()
	title.text = "A 紧凑动作 / B 长衣剪影 / C 块色初稿 / D 修长剑客 / E 平面块色"
	title.add_theme_font_size_override("font_size",17)
	rows.add_child(title)
	var buttons := HBoxContainer.new()
	rows.add_child(buttons)
	for item in [["0 全览",KEY_0],["1 A",KEY_1],["2 B",KEY_2],["3 C",KEY_3],["4 D",KEY_4],["5 E",KEY_5],["6 小号",KEY_6],["7 中号",KEY_7],["8 大号",KEY_8],["9 姿态",KEY_9]]:
		var button := Button.new()
		button.text = item[0]
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(_command.bind(item[1]))
		buttons.add_child(button)
	status = Label.new()
	status.add_theme_font_size_override("font_size",14)
	rows.add_child(status)


func _layout() -> void:
	panel.position = Vector2(20,45)
	panel.size.x = root.size.x - 40


func _refresh() -> void:
	for i in figures.size():
		var spec: Dictionary = manifest.candidates[i].profiles[str(height)]
		var art: Sprite2D = figures[i].get_node("Art")
		art.texture = load(spec.texture)
		assert(art.texture != null and art.texture.get_height() == height)
		art.position = -Vector2(spec.pivot[0], spec.pivot[1]).round()
		figures[i].visible = selected < 0 or selected == i
		figures[i].position = Vector2(160+i*80 if selected < 0 else 320,244)
		if pose_mode: figures[i].position.x = 230
		for j in 2:
			figures[i].get_node("FootShadow"+str(j)).position = Vector2(spec.feet[j][0],spec.feet[j][1])
		captions[i].visible = figures[i].visible
		captions[i].position = Vector2(figures[i].position.x-3,157)
	pose_figure.visible = pose_mode
	pose_caption.visible = pose_mode
	if pose_mode:
		var spec: Dictionary = manifest.poses.e_thrust_corrected.profiles[str(height)]
		var art: Sprite2D = pose_figure.get_node("Art")
		art.texture = load(spec.texture)
		assert(art.texture.get_height() == spec.size[1])
		art.position = -Vector2(spec.pivot[0],spec.pivot[1]).round()
		pose_figure.position = Vector2(410,244)
		for j in 2: pose_figure.get_node("FootShadow"+str(j)).position = Vector2(spec.feet[j][0],spec.feet[j][1])
		pose_caption.position = Vector2(380,157)
	status.text = "%s · 人物高度 %d 逻辑像素 · 静态候选，先比较人体与原尺读形" % ["五案同尺" if selected < 0 else manifest.candidates[selected].title,height]
	if pose_mode: status.text = "E 站姿 / 刺击关键姿态 · 按头部尺度校准 · 剑长尚未统一，仅作静态姿态对照"


func _process(_delta: float) -> bool:
	if status == null or capturing: return false
	var key := 0
	for candidate in [KEY_ESCAPE,KEY_0,KEY_1,KEY_2,KEY_3,KEY_4,KEY_5,KEY_6,KEY_7,KEY_8,KEY_9]:
		if Input.is_physical_key_pressed(candidate):
			key = candidate
			break
	if key == 0: last_key = 0
	elif key != last_key:
		last_key = key
		_command(key)
	return false


func _command(key: int) -> void:
	if key == KEY_ESCAPE:
		quit(0)
		return
	if key >= KEY_0 and key <= KEY_5:
		selected = key-KEY_1
		pose_mode = false
	elif key == KEY_6: height = 58
	elif key == KEY_7: height = 66
	elif key == KEY_8: height = 74
	elif key == KEY_9:
		selected = 4
		pose_mode = true
	_refresh()


func _shot(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png(OUT+name+"_"+size_tag+".png") == OK)


func _capture() -> void:
	capturing = true
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var before: Dictionary = battle.combat.state.duplicate(true)
	root.size_changed.emit()
	await process_frame
	for button in battle.hand_row.get_children():
		if button is Button: assert(button.disabled)
	var key := InputEventKey.new()
	key.keycode = KEY_1
	key.pressed = true
	battle.hand_row._unhandled_key_input(key)
	battle.hand_row.card_selected.emit(0)
	assert(battle.combat.state == before and battle.pending_presentations == 0)
	for h in [58,66,74]:
		height = h
		selected = -1
		_refresh()
		await _shot("overview_"+str(h))
	height = 66
	for i in 5:
		selected = i
		_refresh()
		await _shot(manifest.candidates[i].id)
	_command(KEY_9)
	await _shot("e_pose_pair")
	print("CHARACTER_STYLE_TRIALS_PASS candidates=5 heights=3 screenshots=9 size=",size_tag," original_room=true gameplay_locked=true pose_pair=static")
	quit(0)
