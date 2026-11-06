extends SceneTree

# Isolated motion study. The formal first fight keeps its accepted scene
# resource while this recording tests the real Gemini frames in that room.
const VIDEO_FRAMES := "res://assets/battle/undercurrent_pixel_v1/actor_gemini_video_v1/yelingyun_gemini_probe_v1.tres"
const IDLE_SCREENSHOT := "res://tests/fixtures/artifacts/godot-migration/qingyun-gemini-video-probe/gemini_idle_study_1280.png"


func _initialize() -> void:
	call_deferred("_record")


func _record() -> void:
	root.size = Vector2i(1280, 800)
	var battle: Control = load("res://scenes/main.tscn").instantiate()
	root.add_child(battle)
	Input.warp_mouse(Vector2(10, 10))
	await create_timer(1.0).timeout
	if battle.duel_stage == null or not battle.stage_assets_ready:
		_fail("Qingyun stage did not load")
		return
	var actor: AnimatedSprite2D = battle.duel_stage.get_actor_sprite("player")
	var frames: SpriteFrames = load(VIDEO_FRAMES)
	if actor == null or frames == null or frames.get_meta("source_video_sha256", "") == "":
		_fail("Archived Gemini frames or source provenance are missing")
		return
	actor.sprite_frames = frames
	actor.play("idle")
	battle.duel_stage.call("_align_feet", actor)
	await RenderingServer.frame_post_draw
	if root.get_texture().get_image().save_png(IDLE_SCREENSHOT) != OK:
		_fail("Gemini idle study screenshot failed")
		return
	await create_timer(1.2).timeout
	(battle.hand_row.get_child(0) as Button).pressed.emit()
	for _sample in 120:
		if battle.pending_presentations == 0 and not battle.combat.input_locked:
			break
		await create_timer(0.02).timeout
	if not battle.enemy_label.text.contains("6/7"):
		_fail("Gemini study card did not settle")
		return
	await create_timer(0.8).timeout
	print("QINGYUN_GEMINI_VIDEO_STUDY_RECORDED visual_motion_status=REJECTED_foot_slide")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
