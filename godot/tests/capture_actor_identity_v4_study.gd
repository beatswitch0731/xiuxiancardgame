extends SceneTree

# A real-entry visual study only. It never rewrites the formal SpriteFrames.
const ROOT := "res://assets/battle/undercurrent_pixel_v1/actor_identity_v4_study/"
const OUT := "res://output/captures/godot-migration/actor-identity-v4/"


func _initialize() -> void:
	call_deferred("_capture")


func _capture() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	root.size = Vector2i(1280, 800)
	var battle: Control = load("res://scenes/main.tscn").instantiate()
	root.add_child(battle)
	Input.warp_mouse(Vector2(10, 10))
	await create_timer(0.8).timeout
	if battle.duel_stage == null or not battle.stage_assets_ready:
		_fail("Formal battle did not load for identity study")
		return
	for variant in ["box", "nearest"]:
		for spec in [
			["player", "hero", 40.0, Vector2(34, 70), Vector2(47, 70)],
			["enemy", "dummy", 80.0, Vector2(73, 70), Vector2(92, 70)],
		]:
			var sprite: AnimatedSprite2D = battle.duel_stage.get_actor_sprite(spec[0])
			var texture: Texture2D = load(ROOT + spec[1] + "_idle_" + variant + ".png")
			if sprite == null or texture == null:
				_fail("Missing generated identity texture: " + str(spec[1]))
				return
			var frames := SpriteFrames.new()
			frames.add_animation("idle")
			frames.add_frame("idle", texture)
			frames.set_meta("pivot_x", spec[2])
			frames.set_meta("pivot_y", 70.0)
			frames.set_meta("left_foot_idle_0", spec[3])
			frames.set_meta("right_foot_idle_0", spec[4])
			sprite.sprite_frames = frames
			sprite.play("idle")
			battle.duel_stage.call("_align_feet", sprite)
		await process_frame
		await RenderingServer.frame_post_draw
		var path: String = OUT + "godot_idle_" + variant + "_1280.png"
		if root.get_texture().get_image().save_png(path) != OK:
			_fail("Cannot save study screenshot: " + path)
			return
	print("ACTOR_IDENTITY_V4_STUDY_CAPTURED box+nearest; formal_scene_unchanged=true")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
