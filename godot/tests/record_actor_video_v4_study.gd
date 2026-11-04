extends SceneTree

# Isolated playback of new, genuine Gemini frame sequences inside the room.
# This does not dispatch a card, deal damage, or replace production resources.
const ART := "res://assets/undercurrent_pixel_v1/actor_video_v4_study/"
const OUT := "res://../artifacts/godot-migration/actor-identity-v4/"
var _actors: Dictionary = {}
var _stage: Node
var _caption: Label
var _live := false
var _last_review_key := 0
var _hero_idle_frames: SpriteFrames
var _hero_thrust_frames: SpriteFrames


func _initialize() -> void:
	_live = "--review-live" in OS.get_cmdline_user_args()
	call_deferred("_review")


func _review() -> void:
	root.size = Vector2i(1280, 800)
	var battle: Control = load("res://scenes/main.tscn").instantiate()
	root.add_child(battle)
	Input.warp_mouse(Vector2(10, 10))
	await create_timer(0.8).timeout
	_stage = battle.duel_stage
	if _stage == null or not battle.stage_assets_ready:
		push_error("Actual battle room failed to load")
		quit(1)
		return
	for info in [["player", "hero", 30], ["enemy", "dummy", 36]]:
		var name: String = info[1]
		var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ART + name + "/sequence.json"))
		var frames := SpriteFrames.new()
		frames.remove_animation("default")
		var pivot: Array = manifest["pivot"]
		frames.set_meta("pivot_x", float(pivot[0]))
		frames.set_meta("pivot_y", float(pivot[1]))
		frames.set_meta("source_video_sha256", manifest["sourceVideoSha256"])
		for clip in ["idle", "raw_source"]:
			frames.add_animation(clip)
			frames.set_animation_speed(clip, 24.0)
			frames.set_animation_loop(clip, clip == "idle")
			var count: int = info[2] if clip == "idle" else 240
			for index in count:
				frames.add_frame(clip, load(ART + name + "/frame_%04d.png" % (index + 1)))
				# Raw actions have not passed contact labeling; hide unproven shadows.
				frames.set_meta("grounded_%s_%d" % [clip, index], ["left", "right"] if clip == "idle" else [])
				var left := Vector2(33, 103) if name == "hero" else Vector2(196, 113)
				var right := Vector2(47, 100) if name == "hero" else Vector2(225, 113)
				frames.set_meta("left_foot_%s_%d" % [clip, index], left)
				frames.set_meta("right_foot_%s_%d" % [clip, index], right)
		var sprite: AnimatedSprite2D = _stage.get_actor_sprite(info[0])
		sprite.sprite_frames = frames
		# ActorAnchor shares the pillar depth layer; the sprite stays relative to it.
		sprite.z_index = 0
		sprite.play("idle")
		_stage.call("_align_feet", sprite)
		_actors[name] = sprite
	_hero_idle_frames = _actors["hero"].sprite_frames
	_hero_thrust_frames = load(ART + "hero_local_thrust.tres")
	# The lower card illustrations stay intact. Review mode does not simulate play.
	for button in battle.hand_row.get_children():
		if button is Button:
			button.disabled = true
	battle.end_button.disabled = true
	_caption = Label.new()
	_caption.text = "角色动画检查 · 新角色待机（Gemini 实际抽帧）"
	_caption.position = Vector2(24, 560)
	_caption.add_theme_font_size_override("font_size", 18)
	_caption.add_theme_color_override("font_color", Color("eee6d2"))
	root.add_child(_caption)
	if _live:
		_caption.text += "\n1 双人待机　4 原地伸刺／收剑　2/3 原片诊断　Esc 退出"
		return
	if "--record-thrust" in OS.get_cmdline_user_args():
		await create_timer(0.6).timeout
		_play_review(KEY_4)
		await _actors["hero"].animation_finished
		await create_timer(0.4).timeout
		_play_review(KEY_1)
		await create_timer(2.0).timeout
		print("ACTOR_VIDEO_V4_MODES_RECORDED idle_to_thrust_to_idle=true formal_scene_replaced=false")
		quit(0)
		return
	await create_timer(0.6).timeout
	await RenderingServer.frame_post_draw
	if root.get_texture().get_image().save_png(OUT + "video_idle_in_room_1280.png") != OK:
		push_error("Could not save new actor idle screenshot")
		quit(1)
		return
	# More than three complete loops for both actors, including seams.
	await create_timer(5.4).timeout
	print("ACTOR_VIDEO_V4_ROOM_RECORDED hero_idle=30 dummy_idle=36 loops>=3 formal_scene_replaced=false")
	quit(0)


func _process(_delta: float) -> bool:
	if not _live or _actors.is_empty():
		return false
	if Input.is_physical_key_pressed(KEY_ESCAPE):
		quit(0)
	var pressed := 0
	for key in [KEY_1, KEY_2, KEY_3, KEY_4]:
		if Input.is_physical_key_pressed(key):
			pressed = key
			break
	if pressed == 0:
		_last_review_key = 0
		return false
	if pressed == _last_review_key:
		return false
	_last_review_key = pressed
	_play_review(pressed)
	return false


func _play_review(key: int) -> void:
	var hero: AnimatedSprite2D = _actors["hero"]
	hero.sprite_frames = _hero_thrust_frames if key == KEY_4 else _hero_idle_frames
	for actor in _actors:
		var clip := "raw_source" if (key == KEY_2 and actor == "hero") or (key == KEY_3 and actor == "dummy") else "idle"
		if key == KEY_4 and actor == "hero":
			clip = "local_thrust"
		var sprite: AnimatedSprite2D = _actors[actor]
		sprite.stop()
		sprite.play(clip)
		_stage.call("_align_feet", sprite)
	if key == KEY_1:
		_caption.text = "新角色待机 · 1 待机　4 伸刺／收剑　2/3 原片诊断　Esc 退出"
	elif key == KEY_4:
		_caption.text = "原地伸刺／收剑 · 再按 4 重播，1 返回待机\n此段未连接接敌、受击与伤害"
	else:
		_caption.text = "原片动作诊断：未连接出牌与命中；方向／步距仍需重做"
