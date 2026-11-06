extends SceneTree

# V4 candidate is mounted only in this SceneTree process. The game assets and
# shipped actor SpriteFrames remain untouched until the art gates pass.
const OUTPUT := "res://output/captures/godot-migration/actor-v4-keyframe-review/"
const HERO := "res://art_source/actor_v4_keyframes/yelingyun_single_keypose_review_v1.png"
const DUMMY := "res://art_source/actor_v4_keyframes/quick_sword_dummy_single_keypose_review_v1.png"
const HERO_CONTACT := "res://art_source/actor_v4_keyframes/yelingyun_contact_scale_v3_single_keypose_review_v1.png"
const DUMMY_HIT := "res://art_source/actor_v4_keyframes/quick_sword_dummy_hit_single_keypose_review_v1.png"
var _output_directory := OUTPUT


func _initialize() -> void:
	call_deferred("_capture")


func _capture() -> void:
	var game: Control = load("res://scenes/main.tscn").instantiate()
	var v7 := "--trial-v7-candidate" in OS.get_cmdline_user_args()
	game.trial_v7_candidate_preview = v7
	game.trial_v6_candidate_preview = not v7
	if v7:
		_output_directory = "res://output/captures/godot-migration/qingyun-v7-actor-v4-review/"
	root.add_child(game)
	var stage: Node = game.duel_stage
	for tick in 32:
		await process_frame
	await RenderingServer.frame_post_draw
	if not _save("01-existing-actors.png"):
		quit(1)
		return
	if not _set_idle(stage.get_actor_model("player"), HERO, Vector2i(256, 320), 308):
		quit(1)
		return
	if not _set_idle(stage.get_actor_model("enemy"), DUMMY, Vector2i(320, 352), 340):
		quit(1)
		return
	for tick in 12:
		await process_frame
	await RenderingServer.frame_post_draw
	if not _save("02-v4-paired-idle-candidate.png"):
		quit(1)
		return
	for yaw in [-20.0, 20.0]:
		stage.set_diagnostic_yaw(yaw)
		for tick in 5:
			await process_frame
		await RenderingServer.frame_post_draw
		if not _save("03-v4-yaw-%s.png" % ("left" if yaw < 0 else "right")):
			quit(1)
			return
	stage.set_diagnostic_yaw(0.0)
	if not _set_action_key(stage.get_actor_model("player"), HERO_CONTACT, "sword_probe", 512, 320, 308, Vector2(472, 147)):
		quit(1)
		return
	if not _set_action_key(stage.get_actor_model("enemy"), DUMMY_HIT, "hurt", 320, 352, 340, Vector2(-1, -1)):
		quit(1)
		return
	var contacts: Array[String] = []
	stage.contact_frame.connect(func(side: String) -> void: contacts.append(side))
	(game.hand_row.get_child(0) as Button).pressed.emit()
	for tick in 120:
		if "player" in contacts:
			break
		await process_frame
	if not "player" in contacts:
		push_error("V4 source-timed contact never reached")
		quit(1)
		return
	var hero: Node3D = stage.get_actor_model("player")
	var enemy: Node3D = stage.get_actor_model("enemy")
	var camera: Camera3D = stage.get_node("Viewport/World/CameraRig/Camera") as Camera3D
	var tip: Vector2 = camera.unproject_position(hero.get_sword_tip().global_position)
	var chest: Vector2 = camera.unproject_position(enemy.get_chest_hit().global_position)
	print("ACTOR_V4_CONTACT_DISTANCE_PX %.2f tip=%s chest=%s" % [tip.distance_to(chest), tip, chest])
	await RenderingServer.frame_post_draw
	if not _save("04-v4-paired-contact-candidate.png"):
		quit(1)
		return
	await process_frame
	await RenderingServer.frame_post_draw
	if not _save("05-v4-next-frame-source-mix-failure.png"):
		quit(1)
		return
	print("ACTOR_V4_REVIEW_CAPTURE_COMPLETE isolated_keyposes=true runtime_replaced=false adjacent_frame_gate=false")
	quit(0)


func _set_idle(actor: Node3D, path: String, size: Vector2i, foot_y: int) -> bool:
	var image := Image.load_from_file(ProjectSettings.globalize_path(path))
	if image == null or image.is_empty() or image.get_size() != size:
		push_error("Missing reviewed pose or wrong canvas: " + path)
		return false
	var sprite: AnimatedSprite3D = actor.call("get_sprite") as AnimatedSprite3D
	var frames := sprite.sprite_frames.duplicate(true) as SpriteFrames
	frames.remove_animation("idle")
	frames.add_animation("idle")
	frames.set_animation_loop("idle", true)
	frames.set_animation_speed("idle", 1.0)
	frames.add_frame("idle", ImageTexture.create_from_image(image))
	frames.set_meta("canvas_width_idle_0", size.x)
	frames.set_meta("canvas_height_idle_0", size.y)
	frames.set_meta("foot_idle_0", float(foot_y) / size.y)
	frames.set_meta("scale_idle", 1.0)
	frames.set_meta("authored_idle_breath", true)
	sprite.sprite_frames = frames
	sprite.play("idle")
	sprite.frame = 0
	actor.call("_align_feet")
	return true


func _set_action_key(actor: Node3D, path: String, clip: String, width: int,
		height: int, foot_y: int, blade_tip: Vector2) -> bool:
	var image := Image.load_from_file(ProjectSettings.globalize_path(path))
	if image == null or image.is_empty() or image.get_size() != Vector2i(width, height):
		push_error("Missing V4 action key or wrong canvas: " + path)
		return false
	var sprite: AnimatedSprite3D = actor.call("get_sprite") as AnimatedSprite3D
	var frames := sprite.sprite_frames.duplicate(true) as SpriteFrames
	var key := int(frames.get_meta("impact_frame_sword_probe", -1)) if clip == "sword_probe" else 0
	if key < 0 or key >= frames.get_frame_count(clip):
		push_error("Missing V4 target frame: " + clip)
		return false
	frames.set_frame(clip, key, ImageTexture.create_from_image(image),
		frames.get_frame_duration(clip, key))
	frames.set_meta("canvas_width_%s_%d" % [clip, key], width)
	frames.set_meta("canvas_height_%s_%d" % [clip, key], height)
	frames.set_meta("foot_%s_%d" % [clip, key], float(foot_y) / height)
	frames.set_meta("scale_" + clip, 1.0)
	if blade_tip.x >= 0:
		frames.set_meta("blade_tip_%s_%d" % [clip, key], blade_tip)
	sprite.sprite_frames = frames
	return true


func _save(name: String) -> bool:
	var directory := ProjectSettings.globalize_path(_output_directory)
	DirAccess.make_dir_recursive_absolute(directory)
	var image := root.get_viewport().get_texture().get_image()
	return image != null and not image.is_empty() and image.save_png(directory.path_join(name)) == OK
