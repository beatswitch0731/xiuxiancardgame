extends SceneTree

# In-memory art review of the actual battle camera; never saves or mounts a
# candidate into the runtime's original SpriteFrames resource.
const OUTPUT := "res://../artifacts/godot-migration/actor-v3-keypose-review/"
const IDLE := "res://art_source/actor_v3_sprite/yelingyun_new_master_v2_256x320_review.png"
const CONTACT := "res://art_source/actor_v3_sprite/yelingyun_sword_contact_v1_512x320_review.png"
const DUMMY_HIT := "res://art_source/actor_v3_sprite/quick_sword_dummy_hit_v1_320x352_review.png"
const DENSITY_ROOT := "res://art_source/actor_v3_sprite/diagnostic_pixel_density/"


func _initialize() -> void:
	call_deferred("_capture")


func _capture() -> void:
	var game: Control = load("res://scenes/main.tscn").instantiate()
	game.trial_v6_candidate_preview = true
	root.add_child(game)
	var stage: Node = game.duel_stage
	for tick in 32:
		await process_frame
	await RenderingServer.frame_post_draw
	if not _save("01-current-actor.png"):
		quit(1)
		return
	var actor: Node3D = stage.get_actor_model("player")
	if not _set_review_pose(actor, IDLE, 256, 320):
		quit(1)
		return
	for tick in 6:
		await process_frame
	await RenderingServer.frame_post_draw
	if not _save("02-idle-study.png"):
		quit(1)
		return
	if not _set_review_pose(actor, CONTACT, 512, 320):
		quit(1)
		return
	for tick in 6:
		await process_frame
	await RenderingServer.frame_post_draw
	if not _save("03-contact-keypose-study.png"):
		quit(1)
		return
	if not _replace_contact_frame(actor):
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
		push_error("Reviewed contact frame never reached the source action clock")
		quit(1)
		return
	await RenderingServer.frame_post_draw
	if not _save("04-contact-keypose-at-source-time.png"):
		quit(1)
		return
	if not _replace_dummy_hit_frame(stage.get_actor_model("enemy")):
		quit(1)
		return
	await RenderingServer.frame_post_draw
	if not _save("05-paired-keyposes-at-contact.png"):
		quit(1)
		return
	paused = true
	var foot_decals: Array[Decal] = []
	for child in stage.get_node("Viewport/World").get_children():
		if child is Decal and "FootContact" in child.name:
			foot_decals.append(child as Decal)
	if foot_decals.size() != 4:
		push_error("Expected two ground contact decals per actor, got %d" % foot_decals.size())
		quit(1)
		return
	for mark in foot_decals:
		mark.visible = false
	for tick in 2:
		await process_frame
	await RenderingServer.frame_post_draw
	if not _save("05a-without-foot-decals-control.png"):
		quit(1)
		return
	for mark in foot_decals:
		mark.visible = true
	for tick in 2:
		await process_frame
	await RenderingServer.frame_post_draw
	if not _save("05b-with-foot-decals-control.png"):
		quit(1)
		return
	_set_cool_light_review(stage)
	for tick in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	if not _save("06-cool-key-light-study.png"):
		quit(1)
		return
	var hero_sprite := stage.get_actor_sprite("player") as AnimatedSprite3D
	var dummy_sprite := stage.get_actor_sprite("enemy") as AnimatedSprite3D
	print("ACTOR_RENDER_BASELINE hero_filter=%d dummy_filter=%d hero_shaded=%s dummy_shaded=%s hero_alpha_cut=%d dummy_alpha_cut=%d hero_shadow=%d dummy_shadow=%d msaa=%d" % [
		hero_sprite.texture_filter, dummy_sprite.texture_filter,
		hero_sprite.shaded, dummy_sprite.shaded,
		hero_sprite.alpha_cut, dummy_sprite.alpha_cut,
		hero_sprite.cast_shadow, dummy_sprite.cast_shadow,
		(stage.get_node("Viewport") as SubViewport).msaa_3d])
	# A controlled capture isolates cutout edge treatment and 3D MSAA.
	# It is diagnostic, not an approved sprite replacement or runtime change.
	for sprite in [hero_sprite, dummy_sprite]:
		sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
		sprite.alpha_scissor_threshold = 0.5
	(stage.get_node("Viewport") as SubViewport).msaa_3d = Viewport.MSAA_DISABLED
	for tick in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	if not _save("07-hard-cutout-no-msaa-diagnostic.png"):
		quit(1)
		return
	for sprite in [hero_sprite, dummy_sprite]:
		sprite.shaded = false
	for tick in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	if not _save("08-unshaded-control-diagnostic.png"):
		quit(1)
		return
	for sprite in [hero_sprite, dummy_sprite]:
		sprite.shaded = true
		sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_OPAQUE_PREPASS
	(stage.get_node("Viewport") as SubViewport).msaa_3d = Viewport.MSAA_4X
	var hero_key := int(hero_sprite.sprite_frames.get_meta("impact_frame_sword_probe", -1))
	if hero_key < 0 or not _set_density_control(actor, "sword_probe", hero_key,
			DENSITY_ROOT + "yelingyun_sword_contact_v1_512x320_review.png",
			231.75, Vector2(364.5, 90.0)):
		quit(1)
		return
	if not _set_density_control(stage.get_actor_model("enemy"), "hurt", 0,
			DENSITY_ROOT + "quick_sword_dummy_hit_v1_320x352_review.png",
			255.0, Vector2(-1.0, -1.0)):
		quit(1)
		return
	for tick in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	if not _save("09-one-screen-pixel-control-diagnostic.png"):
		quit(1)
		return
	var camera := stage.get_node("Viewport/World/CameraRig/Camera") as Camera3D
	var source_world_pixel: float = hero_sprite.pixel_size * hero_sprite.global_basis.x.length()
	var a := camera.unproject_position(hero_sprite.global_position)
	var b := camera.unproject_position(hero_sprite.global_position + camera.global_basis.x * source_world_pixel)
	print("ACTOR_PIXEL_DENSITY baseline_screen_per_source_pixel=%.3f density_control_screen_per_source_pixel=%.3f" % [a.distance_to(b) * 0.75, a.distance_to(b)])
	paused = false
	print("ACTOR_V3_KEYPOSE_REVIEW_CAPTURED current_idle_contact_source_time_paired_coollight_edge_density_controls=true runtime_unchanged=true")
	quit(0)


func _set_review_pose(actor: Node3D, path: String, width: int, height: int) -> bool:
	var image := Image.load_from_file(ProjectSettings.globalize_path(path))
	if image == null or image.is_empty() or image.get_size() != Vector2i(width, height):
		push_error("Missing or incorrectly sized review pose: " + path)
		return false
	var sprite: AnimatedSprite3D = actor.call("get_sprite") as AnimatedSprite3D
	var frames := sprite.sprite_frames.duplicate(true) as SpriteFrames
	if frames.has_animation("idle"):
		frames.remove_animation("idle")
	frames.add_animation("idle")
	frames.set_animation_speed("idle", 1.0)
	frames.set_animation_loop("idle", true)
	frames.add_frame("idle", ImageTexture.create_from_image(image))
	frames.set_meta("canvas_width_idle_0", width)
	frames.set_meta("canvas_height_idle_0", height)
	frames.set_meta("foot_idle_0", 309.0 / height)
	frames.set_meta("scale_idle", 1.0)
	frames.set_meta("authored_idle_breath", true)
	sprite.sprite_frames = frames
	sprite.play("idle")
	sprite.frame = 0
	actor.call("_align_feet")
	return true


func _replace_contact_frame(actor: Node3D) -> bool:
	var image := Image.load_from_file(ProjectSettings.globalize_path(CONTACT))
	if image == null or image.is_empty():
		return false
	var sprite: AnimatedSprite3D = actor.call("get_sprite") as AnimatedSprite3D
	var frames := sprite.sprite_frames.duplicate(true) as SpriteFrames
	var key_frame := int(frames.get_meta("impact_frame_sword_probe", -1))
	if key_frame < 0 or key_frame >= frames.get_frame_count("sword_probe"):
		push_error("Missing source sword contact frame")
		return false
	frames.set_frame("sword_probe", key_frame, ImageTexture.create_from_image(image),
		frames.get_frame_duration("sword_probe", key_frame))
	frames.set_meta("canvas_width_sword_probe_%d" % key_frame, 512)
	frames.set_meta("canvas_height_sword_probe_%d" % key_frame, 320)
	frames.set_meta("foot_sword_probe_%d" % key_frame, 309.0 / 320.0)
	frames.set_meta("blade_tip_sword_probe_%d" % key_frame, Vector2(486.0, 120.0))
	frames.set_meta("scale_sword_probe", 1.0)
	sprite.sprite_frames = frames
	return true


func _replace_dummy_hit_frame(actor: Node3D) -> bool:
	var image := Image.load_from_file(ProjectSettings.globalize_path(DUMMY_HIT))
	if image == null or image.get_size() != Vector2i(320, 352):
		push_error("Missing normalized wooden dummy hit pose")
		return false
	var sprite: AnimatedSprite3D = actor.call("get_sprite") as AnimatedSprite3D
	var frames := sprite.sprite_frames.duplicate(true) as SpriteFrames
	frames.set_frame("hurt", 0, ImageTexture.create_from_image(image),
		frames.get_frame_duration("hurt", 0))
	frames.set_meta("canvas_width_hurt_0", 320)
	frames.set_meta("canvas_height_hurt_0", 352)
	frames.set_meta("foot_hurt_0", 340.0 / 352.0)
	frames.set_meta("scale_hurt", 1.0)
	sprite.sprite_frames = frames
	sprite.play("hurt")
	sprite.frame = 0
	actor.call("_align_feet")
	return true


func _set_density_control(actor: Node3D, clip: String, frame: int, path: String,
		feet_y: float, blade_tip: Vector2) -> bool:
	var image := Image.load_from_file(ProjectSettings.globalize_path(path))
	if image == null or image.is_empty():
		push_error("Missing pixel-density diagnostic image: " + path)
		return false
	var sprite: AnimatedSprite3D = actor.call("get_sprite") as AnimatedSprite3D
	var frames := sprite.sprite_frames.duplicate(true) as SpriteFrames
	frames.set_frame(clip, frame, ImageTexture.create_from_image(image),
		frames.get_frame_duration(clip, frame))
	frames.set_meta("canvas_width_%s_%d" % [clip, frame], image.get_width())
	frames.set_meta("canvas_height_%s_%d" % [clip, frame], image.get_height())
	frames.set_meta("foot_%s_%d" % [clip, frame], feet_y / image.get_height())
	frames.set_meta("scale_" + clip, 4.0 / 3.0)
	if blade_tip.x >= 0.0:
		frames.set_meta("blade_tip_%s_%d" % [clip, frame], blade_tip)
	sprite.sprite_frames = frames
	sprite.play(clip)
	sprite.frame = frame
	actor.call("_align_feet")
	return true


func _set_cool_light_review(stage: Node) -> void:
	# Camera-only light study: retain physical sources, reduce the current
	# even orange wash, and let stone read under a cooler ambient fill.
	var world_environment := stage.get_node("Viewport/World/WorldEnvironment") as WorldEnvironment
	var environment := world_environment.environment
	environment.ambient_light_color = Color("a7b7c0")
	environment.ambient_light_energy = 0.63
	environment.ssao_intensity = 0.68
	for sconce_name in ["WestStoneSconce", "EastStoneSconce"]:
		var sconce := stage.get_node("Viewport/World/" + sconce_name) as OmniLight3D
		sconce.light_color = Color("ffdcaf")
		sconce.light_energy = 1.65
		sconce.omni_range = 5.6
	var chandelier := stage.get_node("Viewport/World/ChandelierPhysicalPool") as OmniLight3D
	chandelier.light_color = Color("f6d4a8")
	chandelier.light_energy = 3.1
	chandelier.omni_range = 7.0
	var bounce := stage.get_node("Viewport/World/CombatStoneBounce") as OmniLight3D
	bounce.light_energy = 0.45
	bounce.omni_range = 4.8


func _save(name: String) -> bool:
	var directory := ProjectSettings.globalize_path(OUTPUT)
	DirAccess.make_dir_recursive_absolute(directory)
	var frame := root.get_viewport().get_texture().get_image()
	return frame != null and not frame.is_empty() and frame.save_png(directory.path_join(name)) == OK
