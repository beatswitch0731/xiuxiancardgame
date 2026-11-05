extends SceneTree

# Static pose studies inside the real battle entrypoint, not animation proof.
const ART := "res://assets/battle/undercurrent_pixel_v1/actor_identity_v4_study/poses/"
const OUT := "res://../artifacts/godot-migration/actor-identity-v4/"


func _initialize() -> void:
	call_deferred("_capture")


func _capture() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ART + "pose_manifest.json"))
	root.size = Vector2i(1280, 800)
	var battle: Control = load("res://scenes/main.tscn").instantiate()
	root.add_child(battle)
	Input.warp_mouse(Vector2(10, 10))
	await create_timer(0.8).timeout
	var stage: Node = battle.duel_stage
	if stage == null or not battle.stage_assets_ready:
		push_error("Battle entry did not load")
		quit(1)
		return
	for setup in [
		["idle", "hero_idle", "dummy_idle", Vector2(290, 244)],
		["contact", "hero_thrust", "dummy_hurt", Vector2(377, 244)],
		["guard", "hero_guard", "dummy_windup", Vector2(290, 244)],
	]:
		for actor in [["player", setup[1]], ["enemy", setup[2]]]:
			var sprite: AnimatedSprite2D = stage.get_actor_sprite(actor[0])
			var info: Dictionary = manifest["frames"][actor[1]]
			var frames := SpriteFrames.new()
			frames.add_animation("idle")
			frames.add_frame("idle", load(ART + actor[1] + ".png"))
			frames.set_meta("pivot_x", float(info["pivot"][0]))
			frames.set_meta("pivot_y", float(info["pivot"][1]))
			for marker in ["left_foot", "right_foot"]:
				frames.set_meta(marker + "_idle_0", Vector2(info[marker][0], info[marker][1]))
			sprite.sprite_frames = frames
			# The player's boots are closer to camera; its blade must draw in front.
			sprite.z_index = 2 if actor[0] == "player" else 1
			sprite.play("idle")
			stage.call("_align_feet", sprite)
		stage.get_node("Viewport/World/PlayerAnchor").position = setup[3]
		await process_frame
		await RenderingServer.frame_post_draw
		if root.get_texture().get_image().save_png(OUT + "pose_" + setup[0] + "_1280.png") != OK:
			push_error("Pose screenshot failed")
			quit(1)
			return
	print("ACTOR_V4_POSE_STUDY_CAPTURED idle+contact+guard static_only=true")
	quit(0)
