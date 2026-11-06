extends SceneTree

# Read-only visual comparison. Replaces the world in memory for screenshots;
# the production battle scene and source-derived combat rules stay untouched.
const OUTPUT := "res://output/captures/godot-migration/hd2d-world-v2/"
const MODEL := preload("res://assets/battle/hd2d/world_v2/cangmang_court_v2.glb")


func _initialize() -> void:
	call_deferred("_capture")


func _capture() -> void:
	var game: Control = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	var stage: Node = game.duel_stage
	var world_root: Node3D = stage.get_node("Viewport/World")
	var previous: Node3D = stage.get_world_model()
	previous.queue_free()
	var candidate: Node3D = MODEL.instantiate()
	candidate.name = "CangmangCourtV2Candidate"
	world_root.add_child(candidate)
	stage.set("_world", candidate)
	# P2 uses more environment per fighter. Test a smaller actor scale without
	# changing the production scenes or the authored sword-contact timing.
	for side in ["player", "enemy"]:
		var fighter: Node3D = stage.get_actor_model(side)
		fighter.scale = Vector3.ONE * 0.72
	var probe_sample: Node3D = load("res://scenes/yelingyun_s1_hd2d.tscn").instantiate()
	probe_sample.name = "CandidateScaledTipSampler"
	world_root.add_child(probe_sample)
	probe_sample.visible = false
	probe_sample.scale = Vector3.ONE * 0.72
	probe_sample.play_action("sword_probe")
	probe_sample.get_animation_player().seek(probe_sample.get_contact_time("sword_probe"), true)
	var tips: Dictionary = stage.get("_sampled_contact_tips")
	tips["player:sword_probe"] = probe_sample.get_sword_tip().global_position
	probe_sample.queue_free()
	var battle_view: SubViewport = stage.get_node("Viewport")
	battle_view.msaa_3d = Viewport.MSAA_4X
	var paver := candidate.find_child("SM_Court_PBR_RectangularStone_16x12", true, false) as MeshInstance3D
	if paver != null:
		var source_mat := paver.get_active_material(0) as StandardMaterial3D
		if source_mat != null:
			var stone_mat: StandardMaterial3D = source_mat.duplicate()
			stone_mat.albedo_color = Color("83949b")
			stone_mat.roughness = 0.69
			paver.material_override = stone_mat
	var mountains: Node3D = world_root.get_node("DistantMountains")
	mountains.visible = false
	var env_node: WorldEnvironment = world_root.get_node("WorldEnvironment")
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("18242c")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("8e9ea8")
	env.ambient_light_energy = 0.43
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env_node.environment = env
	var cool_fill: OmniLight3D = world_root.get_node("HeroFill")
	cool_fill.light_energy = 0.75
	var dummy_rim: OmniLight3D = world_root.get_node("DummyRim")
	dummy_rim.light_energy = 0.95
	for x in [-5.75, 0.0, 5.75]:
		var wall_light := OmniLight3D.new()
		wall_light.name = "PhysicalHallLantern_%s" % str(x)
		wall_light.position = Vector3(x, 3.05, -4.8)
		wall_light.light_color = Color("ffb566")
		wall_light.light_energy = 3.4
		wall_light.omni_range = 5.2
		wall_light.shadow_enabled = true
		world_root.add_child(wall_light)
	var battle_key := SpotLight3D.new()
	battle_key.name = "WarmBattleContactPool"
	battle_key.position = Vector3(1.8, 5.1, 1.5)
	battle_key.light_color = Color("ffbf77")
	battle_key.light_energy = 4.2
	battle_key.spot_range = 8.0
	battle_key.spot_angle = 37.0
	battle_key.shadow_enabled = true
	world_root.add_child(battle_key)
	battle_key.look_at(Vector3(1.2, 0, -0.2), Vector3.UP)
	for frame in 28:
		await process_frame
	await RenderingServer.frame_post_draw
	if not _save("godot-opening.png"):
		quit(1)
		return
	var contacts: Array[String] = []
	stage.contact_frame.connect(func(side: String) -> void: contacts.append(side))
	(game.hand_row.get_child(0) as Button).pressed.emit()
	for frame in 120:
		if "player" in contacts:
			break
		await process_frame
	if not "player" in contacts:
		push_error("Candidate screenshot did not reach source sword contact")
		quit(1)
		return
	await RenderingServer.frame_post_draw
	if not _save("godot-contact.png"):
		quit(1)
		return
	print("CANGMANG_V2_CANDIDATE_CAPTURE_PASS meshes=", candidate.get_child_count())
	quit(0)


func _save(name: String) -> bool:
	var directory := ProjectSettings.globalize_path(OUTPUT)
	DirAccess.make_dir_recursive_absolute(directory)
	var image := root.get_viewport().get_texture().get_image()
	return image != null and not image.is_empty() and image.save_png(directory.path_join(name)) == OK
