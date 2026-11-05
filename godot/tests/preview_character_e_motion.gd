extends SceneTree
## Review of actual video frames only. No procedural character motion or damage.

const SEQUENCE := "res://assets/battle/undercurrent_pixel_v1/character_e_motion_v1/sequence.json"
const TRIALS := "res://assets/battle/undercurrent_pixel_v1/character_style_trials_v2/trials.json"
const OUT := "res://../artifacts/godot-migration/character-e-motion-v1/"
var sequence: Dictionary
var reference: Dictionary
var atlas: Texture2D
var reference_texture: Texture2D
var battle: Control
var world: Node2D
var motion_art: Sprite2D
var static_art: Sprite2D
var status_label: Label
var panel: PanelContainer
var frame_size: Vector2i
var frame_count := 0
var columns := 0
var fps := 0.0
var frame_index := 0
var playback_seconds := 0.0
var playing := true
var automated := false
var ready_to_play := false
var last_key := 0
var checks := 0

func _initialize() -> void:
	call_deferred("_start")

func _fail(message: String) -> bool:
	push_error("CHARACTER_E_MOTION_FAIL: " + message)
	quit(1)
	return false

func _load_inputs() -> bool:
	if not FileAccess.file_exists(SEQUENCE):
		return _fail("Missing actual-video sequence: " + SEQUENCE)
	var document: Variant = JSON.parse_string(FileAccess.get_file_as_string(SEQUENCE))
	if not document is Dictionary or document.get("status") != "review_only":
		return _fail("Sequence must be a review_only manifest")
	sequence = document
	for field in ["fps", "atlas", "frameSize", "columns", "frameCount", "pivot", "frames"]:
		if not sequence.has(field):
			return _fail("Sequence field missing: " + field)
	if not sequence.frameSize is Array or sequence.frameSize.size() != 2 or not sequence.pivot is Array or sequence.pivot.size() != 2:
		return _fail("frameSize and pivot must each contain two coordinates")
	fps = float(sequence.fps)
	columns = int(sequence.columns)
	frame_count = int(sequence.frameCount)
	frame_size = Vector2i(int(sequence.frameSize[0]), int(sequence.frameSize[1]))
	if fps <= 0 or columns <= 0 or frame_count <= 0 or frame_size.x <= 0 or frame_size.y <= 0:
		return _fail("Sequence dimensions, count, columns and fps must be positive")
	if not sequence.frames is Array or sequence.frames.size() != frame_count:
		return _fail("frames must describe every actual atlas frame")
	var last_source := -1
	var last_time := -1.0
	for index in frame_count:
		var row: Variant = sequence.frames[index]
		if not row is Dictionary or int(row.get("index", -1)) != index or not row.has("sourceFrame") or not row.has("sourceTime"):
			return _fail("Frame provenance missing at index " + str(index))
		if int(row.sourceFrame) <= last_source or float(row.sourceTime) < 0 or float(row.sourceTime) <= last_time:
			return _fail("Actual source frames and timestamps must increase")
		last_source = int(row.sourceFrame)
		last_time = float(row.sourceTime)
	var atlas_path := String(sequence.atlas)
	if not ResourceLoader.exists(atlas_path):
		return _fail("Missing/import-unavailable actual frame atlas: " + atlas_path)
	atlas = load(atlas_path)
	if atlas == null:
		return _fail("Actual frame atlas cannot be loaded")
	var rows := ceili(float(frame_count) / columns)
	if atlas.get_width() < columns * frame_size.x or atlas.get_height() < rows * frame_size.y:
		return _fail("Atlas dimensions do not contain all declared frames")
	var trials: Variant = JSON.parse_string(FileAccess.get_file_as_string(TRIALS))
	if not trials is Dictionary:
		return _fail("Accepted E reference manifest unavailable")
	for candidate in trials.get("candidates", []):
		if candidate.get("id") == "e_flat":
			reference = candidate.get("profiles", {}).get("66", {})
	if reference.is_empty() or not ResourceLoader.exists(String(reference.get("texture", ""))):
		return _fail("Accepted E66 texture/profile unavailable")
	reference_texture = load(reference.texture)
	return reference_texture != null or _fail("Accepted E66 texture cannot be loaded")

func _start() -> void:
	if not _load_inputs():
		return
	var args := OS.get_cmdline_user_args()
	if "--record" in args and "--write-movie" not in OS.get_cmdline_args():
		_fail("Use preview_motion.cmd --record, or launch Godot with --write-movie and the sequence fps")
		return
	if ("--capture" in args or "--record" in args) and DisplayServer.get_name() == "headless":
		_fail("Capture/record needs a rendering display; use --validate for headless checks")
		return
	root.size = Vector2i(1024, 768) if "--review-1024" in args else Vector2i(1280, 800)
	battle = load("res://scenes/main.tscn").instantiate()
	root.add_child(battle)
	if battle.combat == null or not battle.stage_assets_ready:
		_fail("Original battle room failed to initialize")
		return
	# Lock the real authority before the first asynchronous wait or user input.
	battle.combat.input_locked = true
	battle._render_hand()
	world = battle.duel_stage.get_node("Viewport/World")
	world.get_node("PlayerAnchor").hide()
	world.get_node("EnemyAnchor").hide()
	for control in [battle.end_button, battle.flee_button, battle.return_button, battle.intent_slip, battle.player_info_back, battle.enemy_info_back, battle.player_label, battle.enemy_label, battle.player_health_track, battle.player_health_fill, battle.player_qi_track, battle.player_qi_fill, battle.enemy_health_track, battle.enemy_health_fill, battle.state_info_back, battle.state_slip_anchor]:
		if is_instance_valid(control):
			control.hide()
	battle.title_label.text = "E 完整人物 · 实际视频帧研究 / 原石室与原卡牌"
	static_art = _figure("AcceptedStaticE", Vector2(248, 244), reference_texture, Vector2(reference.pivot[0], reference.pivot[1]))
	motion_art = _figure("ActualVideoE", Vector2(392, 244), atlas, Vector2(sequence.pivot[0], sequence.pivot[1]))
	motion_art.region_enabled = true
	_caption("已选 E · 静态参照", Vector2(211, 157))
	_caption("实际视频抽帧", Vector2(359, 157))
	_make_controls()
	root.size_changed.connect(_layout)
	_layout()
	_show_frame(0)
	if not await _check_input_isolation():
		return
	ready_to_play = true
	if "--validate" in args:
		_validate_playback()
	elif "--capture" in args:
		await _capture()
	elif "--record" in args:
		await _record()
	else:
		print("CHARACTER_E_MOTION_READY frames=%d fps=%s original_room=true gameplay_locked=true" % [frame_count, fps])

func _figure(figure_name: String, foot: Vector2, texture: Texture2D, pivot: Vector2) -> Sprite2D:
	var figure := Node2D.new()
	figure.name = figure_name
	figure.position = foot
	figure.z_index = 1
	world.add_child(figure)
	var art := Sprite2D.new()
	art.name = "Art"
	art.centered = false
	art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	art.texture = texture
	art.position = -pivot
	figure.add_child(art)
	return art

func _caption(text: String, position: Vector2) -> void:
	var label := Label.new()
	label.text = text
	label.position = position
	label.add_theme_font_size_override("font_size", 10)
	label.modulate = Color(0.9, 0.85, 0.7)
	world.add_child(label)

func _make_controls() -> void:
	panel = PanelContainer.new()
	var background := StyleBoxFlat.new()
	background.bg_color = Color(0.025, 0.04, 0.045, 0.95)
	background.content_margin_left = 12
	background.content_margin_top = 9
	background.content_margin_right = 12
	background.content_margin_bottom = 9
	panel.add_theme_stylebox_override("panel", background)
	root.add_child(panel)
	var rows := VBoxContainer.new()
	panel.add_child(rows)
	var title := Label.new()
	title.text = "呼吸待机 → 同手原地刺击 → 收势 · 动画研究，不结算伤害"
	title.add_theme_font_size_override("font_size", 17)
	rows.add_child(title)
	var buttons := HBoxContainer.new()
	rows.add_child(buttons)
	for item in [["空格 播放/暂停", KEY_SPACE], ["R 重放", KEY_R], ["← 上一帧", KEY_LEFT], ["→ 下一帧", KEY_RIGHT]]:
		var button := Button.new()
		button.text = item[0]
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(_command.bind(item[1]))
		buttons.add_child(button)
	status_label = Label.new()
	status_label.add_theme_font_size_override("font_size", 14)
	rows.add_child(status_label)

func _layout() -> void:
	panel.position = Vector2(20, 45)
	panel.size.x = root.size.x - 40

func _show_frame(index: int) -> void:
	frame_index = clampi(index, 0, frame_count - 1)
	var column := frame_index % columns
	var row := floori(float(frame_index) / columns)
	motion_art.region_rect = Rect2(Vector2(column * frame_size.x, row * frame_size.y), Vector2(frame_size))
	_refresh_status()

func _refresh_status() -> void:
	var source: Dictionary = sequence.frames[frame_index]
	status_label.text = "%s · 帧 %d/%d · 原视频帧 %d · 原视频 %.3fs · 播放 %.3fs / %.3fs" % ["播放" if playing else "暂停", frame_index + 1, frame_count, int(source.sourceFrame), float(source.sourceTime), frame_index / fps, (frame_count - 1) / fps]

func _command(key: int) -> void:
	if automated or not ready_to_play:
		return
	if key == KEY_ESCAPE:
		quit(0)
	elif key == KEY_SPACE:
		playing = not playing
		if playing and frame_index == frame_count - 1:
			playback_seconds = 0.0
			_show_frame(0)
	elif key == KEY_R:
		playback_seconds = 0.0
		playing = true
		_show_frame(0)
	elif key == KEY_LEFT or key == KEY_RIGHT:
		playing = false
		_show_frame(frame_index + (-1 if key == KEY_LEFT else 1))
		playback_seconds = frame_index / fps
	_refresh_status()

func _process(delta: float) -> bool:
	if not ready_to_play or automated:
		return false
	var key := 0
	for candidate in [KEY_ESCAPE, KEY_SPACE, KEY_R, KEY_LEFT, KEY_RIGHT]:
		if Input.is_physical_key_pressed(candidate):
			key = candidate
			break
	if key == 0:
		last_key = 0
	elif key != last_key:
		last_key = key
		_command(key)
	if playing:
		playback_seconds += delta
		if playback_seconds >= frame_count / fps:
			playing = false
		_show_frame(mini(floori(playback_seconds * fps), frame_count - 1))
	return false

func _check(condition: bool, message: String) -> bool:
	checks += 1
	return condition or _fail(message)

func _check_input_isolation() -> bool:
	var before: Dictionary = battle.combat.state.duplicate(true)
	var initial_size := root.size
	for test_size in [initial_size + Vector2i(16, 0), initial_size]:
		root.size = test_size
		root.size_changed.emit()
		await process_frame
		if not _check(battle.combat.input_locked, "Resize must preserve combat input lock"):
			return false
		for button in battle.hand_row.get_children():
			if button is Button and not _check(button.disabled, "Resize must leave every original card disabled"):
				return false
		var key := InputEventKey.new()
		key.keycode = KEY_1
		key.pressed = true
		battle.hand_row._unhandled_key_input(key)
		battle.hand_row.card_selected.emit(0)
		if not _check(battle.combat.state == before and battle.pending_presentations == 0, "Resize/card_selected must not mutate combat or queue damage presentation"):
			return false
	return true

func _validate_playback() -> void:
	var before: Dictionary = battle.combat.state.duplicate(true)
	var static_transform := static_art.global_transform
	for index in frame_count:
		_show_frame(index)
		if not _check(Rect2(Vector2.ZERO, atlas.get_size()).encloses(motion_art.region_rect), "Selected frame region must lie inside actual atlas"):
			return
	_show_frame(0)
	playing = true
	_command(KEY_SPACE)
	if not _check(not playing and frame_index == 0, "Space pauses without replacing the frame"):
		return
	_command(KEY_RIGHT)
	if not _check(not playing and frame_index == mini(1, frame_count - 1), "Right advances exactly one real frame and pauses"):
		return
	_command(KEY_LEFT)
	if not _check(frame_index == 0, "Left returns to the actual first frame"):
		return
	_show_frame(frame_count - 1)
	_command(KEY_R)
	if not _check(playing and frame_index == 0 and playback_seconds == 0.0, "R restarts actual sequence from zero"):
		return
	if not _check(static_art.global_transform == static_transform and battle.combat.state == before and battle.pending_presentations == 0, "Playback controls preserve reference artwork and gameplay state"):
		return
	print("CHARACTER_E_MOTION_CONTRACT_PASS checks=%d frames=%d fps=%s real_atlas=true original_room=true gameplay_locked=true" % [checks, frame_count, fps])
	quit(0)

func _capture() -> void:
	automated = true
	playing = false
	var selected: Array[int] = [0, floori((frame_count - 1) * 0.25), floori((frame_count - 1) * 0.5), floori((frame_count - 1) * 0.75), frame_count - 1]
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-frames="):
			selected.clear()
			for value in argument.trim_prefix("--capture-frames=").split(","):
				if not value.is_valid_int() or int(value) < 0 or int(value) >= frame_count:
					_fail("Capture frame index is outside actual sequence: " + value)
					return
				selected.append(int(value))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var captured: Array[Dictionary] = []
	var seen: Array[int] = []
	for index in selected:
		if index in seen:
			continue
		seen.append(index)
		_show_frame(index)
		await process_frame
		await RenderingServer.frame_post_draw
		var output := OUT + "frame_%04d_%d.png" % [index, root.size.x]
		if root.get_texture().get_image().save_png(output) != OK:
			_fail("Cannot save review screenshot: " + output)
			return
		captured.append({"screenshot": output, "frame": sequence.frames[index]})
	var evidence := FileAccess.open(OUT + "capture_frames_%d.json" % root.size.x, FileAccess.WRITE)
	if evidence == null:
		_fail("Cannot save screenshot/source-frame mapping")
		return
	evidence.store_string(JSON.stringify({"sequence": SEQUENCE, "status": "review_only", "captures": captured}, "\t"))
	print("CHARACTER_E_MOTION_CAPTURE_PASS screenshots=%d actual_frames=%s gameplay_locked=true" % [captured.size(), seen])
	quit(0)

func _record() -> void:
	automated = true
	playing = false
	# MovieMaker records the rendered viewport. Each source atlas frame is held
	# for one output frame; preview_motion.cmd sets output fps from the manifest.
	for index in frame_count:
		_show_frame(index)
		await RenderingServer.frame_post_draw
	print("CHARACTER_E_MOTION_RECORD_PASS source_frames=%d fps=%s gameplay_locked=true" % [frame_count, fps])
	quit(0)
