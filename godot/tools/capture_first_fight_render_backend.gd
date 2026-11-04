extends SceneTree

# Same authored scene, actors and camera under two desktop rendering backends.
# This is a visual diagnostic. It never changes the project renderer or art.
const GAME := preload("res://scenes/main.tscn")


func _initialize() -> void:
	call_deferred("_capture")


func _capture() -> void:
	var backend := RenderingServer.get_current_rendering_method()
	var driver := RenderingServer.get_current_rendering_driver_name()
	var lighting_study := "--lighting-study" in OS.get_cmdline_user_args()
	var art_study := "--art-study" in OS.get_cmdline_user_args()
	var temple_study := "--temple-study" in OS.get_cmdline_user_args()
	var temple_open := "--temple-open" in OS.get_cmdline_user_args()
	var temple_steps := "--temple-steps" in OS.get_cmdline_user_args()
	var vista_study := "--vista-study" in OS.get_cmdline_user_args()
	var clear_bank := "--clear-bank" in OS.get_cmdline_user_args()
	var vista_crisp := "--vista-crisp" in OS.get_cmdline_user_args()
	var warm_study := "--warm-study" in OS.get_cmdline_user_args()
	var lamp_debug := "--lamp-debug" in OS.get_cmdline_user_args()
	var v6_light_pass := ""
	var floor_study := ""
	var actor_study := ""
	var pose_study := ""
	var hover_card := -1
	var reaction_phase := "--reaction-phase" in OS.get_cmdline_user_args()
	var ui_study := ""
	var material_study := ""
	var hand_count := -1
	var candidate := "trial_v7"
	var yaw := 0.0
	var temple_pose := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--candidate="):
			candidate = arg.trim_prefix("--candidate=")
		elif arg.begins_with("--yaw="):
			yaw = clampf(float(arg.trim_prefix("--yaw=")), -35.0, 35.0)
		elif arg.begins_with("--temple-pose="):
			temple_pose = arg.trim_prefix("--temple-pose=")
		elif arg.begins_with("--v6-light-pass="):
			v6_light_pass = arg.trim_prefix("--v6-light-pass=")
		elif arg.begins_with("--floor-study="):
			floor_study = arg.trim_prefix("--floor-study=")
		elif arg.begins_with("--actor-study="):
			actor_study = arg.trim_prefix("--actor-study=")
		elif arg.begins_with("--pose-study="):
			pose_study = arg.trim_prefix("--pose-study=")
		elif arg.begins_with("--hover-card="):
			hover_card = int(arg.trim_prefix("--hover-card="))
		elif arg.begins_with("--ui-study="):
			ui_study = arg.trim_prefix("--ui-study=")
		elif arg.begins_with("--material-study="):
			material_study = arg.trim_prefix("--material-study=")
		elif arg.begins_with("--hand-count="):
			hand_count = clampi(int(arg.trim_prefix("--hand-count=")), 0, 5)
	if candidate not in ["default", "breath_v17", "trial_v17", "trial_v16", "trial_v15", "trial_v14", "trial_v13", "trial_v11", "trial_v10", "trial_v9", "trial_v8", "trial_v7", "trial_v6", "trial_v5", "outdoor_v3"]:
		push_error("Unknown first-fight art candidate: " + candidate)
		quit(1)
		return
	var suffix := "-lighting-study" if lighting_study else ("-art-study" if art_study else ("-temple-open" if temple_study and temple_open else ("-temple-study" if temple_study else "")))
	if vista_study:
		suffix += "-vista"
	if clear_bank:
		suffix += "-clear-bank"
	if temple_steps:
		suffix += "-steps"
	if vista_crisp:
		suffix += "-crisp"
	if warm_study:
		suffix += "-warm"
	if not temple_pose.is_empty():
		suffix += "-pose-" + temple_pose.replace(",", "-").replace(".", "p")
	if not v6_light_pass.is_empty():
		suffix += "-" + v6_light_pass
	if not floor_study.is_empty():
		suffix += "-floor-" + floor_study
	if not actor_study.is_empty():
		suffix += "-actor-" + actor_study
	if not pose_study.is_empty():
		suffix += "-pose-" + pose_study
	if hover_card >= 0:
		suffix += "-hover%d" % hover_card
	if reaction_phase:
		suffix += "-reaction"
	if not ui_study.is_empty():
		suffix += "-ui-" + ui_study.validate_filename()
	if not material_study.is_empty():
		suffix += "-material-" + material_study.validate_filename()
	if hand_count >= 0:
		suffix += "-hand%d" % hand_count
	var output := "res://../artifacts/godot-migration/first-fight-backend-qa/%s-%s-yaw%d%s.png" % [candidate, backend, roundi(yaw), suffix]
	var game: Control = GAME.instantiate()
	game.trial_v7_candidate_preview = candidate == "trial_v7"
	game.trial_v6_candidate_preview = candidate == "trial_v6"
	game.trial_v8_candidate_preview = candidate == "trial_v8"
	game.trial_v9_candidate_preview = candidate == "trial_v9"
	game.trial_v10_candidate_preview = candidate == "trial_v10"
	game.trial_v11_candidate_preview = candidate == "trial_v11"
	game.trial_v13_candidate_preview = candidate == "trial_v13"
	game.trial_v14_candidate_preview = candidate == "trial_v14"
	game.trial_v15_candidate_preview = candidate == "trial_v15"
	game.trial_v16_candidate_preview = candidate == "trial_v16"
	game.trial_v17_candidate_preview = candidate == "trial_v17"
	game.breath_v17_candidate_preview = candidate == "breath_v17"
	game.trial_v5_candidate_preview = candidate == "trial_v5"
	game.outdoor_candidate_preview = candidate == "outdoor_v3"
	root.add_child(game)
	if reaction_phase:
		game.end_button.pressed.emit()
		if String(game.combat.state["phase"]) != "REACTION_OPEN":
			push_error("First-fight reaction phase did not open for capture")
			quit(1)
			return
	if material_study == "nearest-mipmap":
		_apply_material_filter_study(game.duel_stage)
	if hand_count >= 0:
		var source_hand: Array = game.combat.state["hand"]
		game.combat.state["hand"] = source_hand.slice(0, mini(hand_count, source_hand.size()))
		game._render_hand()
		game._layout_card_table()
	if hover_card >= 0 and hover_card < game.hand_row.get_child_count():
		game.hand_row.call("_set_hover", game.hand_row.get_child(hover_card), true)
	if not temple_pose.is_empty() and candidate == "trial_v8":
		var parts := temple_pose.split(",")
		if parts.size() != 4:
			push_error("Temple pose needs x,y,z,scale")
			quit(1)
			return
		var temple := game.duel_stage.get_world_model().find_child("QingyunTempleCC0Candidate", true, false) as Node3D
		if temple == null:
			push_error("V8 candidate temple missing")
			quit(1)
			return
		temple.position = Vector3(float(parts[0]), float(parts[1]), float(parts[2]))
		temple.scale = Vector3.ONE * float(parts[3])
	game.duel_stage.set_diagnostic_yaw(yaw)
	if lighting_study:
		_apply_lighting_study(game.duel_stage)
	if not v6_light_pass.is_empty() and candidate in ["default", "trial_v6", "trial_v14"]:
		_apply_v6_light_pass(game.duel_stage, v6_light_pass)
	if floor_study == "v12" and candidate in ["default", "trial_v6"]:
		if not _apply_v12_floor_study(game.duel_stage):
			quit(1)
			return
	if floor_study == "local-wear-v1" and candidate in ["default", "trial_v6"]:
		if not _apply_local_wear_study(game.duel_stage):
			quit(1)
			return
	if floor_study == "denser-slate" and candidate in ["default", "trial_v6"]:
		if not _apply_denser_slate_study(game.duel_stage):
			quit(1)
			return
	if floor_study == "wear-debug" and candidate == "trial_v16":
		var bright := StandardMaterial3D.new()
		bright.albedo_color = Color.RED
		bright.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		for wear_name in ["Sword_trial_west_pivot_wear", "Sword_trial_east_pivot_wear", "Sword_trial_crossing_wear"]:
			var wear_mesh := game.duel_stage.get_world_model().find_child(wear_name, true, false) as MeshInstance3D
			if wear_mesh != null:
				wear_mesh.set_surface_override_material(0, bright)
	if actor_study == "cast-shadow" and candidate in ["default", "trial_v6"]:
		for side in ["player", "enemy"]:
			var actor_sprite := game.duel_stage.get_actor_sprite(side) as AnimatedSprite3D
			actor_sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_DOUBLE_SIDED
	if actor_study in ["actor-bounce-none", "actor-bounce-soft", "actor-bounce-mid", "actor-bounce-high"] and candidate == "default":
		# Reuse the production lights so a study never stacks a second fill on top.
		var bounce_gain := 0.0
		if actor_study == "actor-bounce-soft":
			bounce_gain = 0.8
		elif actor_study == "actor-bounce-mid":
			bounce_gain = 1.4
		elif actor_study == "actor-bounce-high":
			bounce_gain = 2.0
		for side in ["player", "enemy"]:
			var light := game.duel_stage.get_node_or_null("Viewport/World/ActorReflectedFill_" + side) as OmniLight3D
			if light == null:
				push_error("Tutorial actor fill missing for study: " + side)
				quit(1)
				return
			light.light_energy = bounce_gain if side == "player" else bounce_gain * 1.28
	if actor_study == "front-sort" and candidate == "trial_v16":
		var front_hero := game.duel_stage.get_actor_sprite("player") as AnimatedSprite3D
		var back_dummy := game.duel_stage.get_actor_sprite("enemy") as AnimatedSprite3D
		front_hero.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
		back_dummy.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
		front_hero.render_priority = 1
		back_dummy.render_priority = 0
	if actor_study == "stance-idle" and candidate in ["default", "trial_v6"]:
		for side in ["player", "enemy"]:
			var fighter: Node3D = game.duel_stage.get_actor_model(side)
			var stance_sprite := game.duel_stage.get_actor_sprite(side) as AnimatedSprite3D
			var stance_frames := stance_sprite.sprite_frames.duplicate(true) as SpriteFrames
			stance_frames.clear("idle")
			stance_frames.add_frame("idle", stance_frames.get_frame_texture("attack", 0), 1.0)
			stance_frames.set_meta("scale_idle", stance_frames.get_meta("scale_attack"))
			stance_frames.set_meta("foot_idle_0", stance_frames.get_meta("foot_attack_0"))
			stance_sprite.sprite_frames = stance_frames
			fighter.play_action("idle")
	if actor_study in ["density-512-idle", "density-512-detail", "density-512-micro", "density-512-ink"] and candidate == "default":
		# Review the original high-resolution key art at a higher effective
		# pixel density. This only changes isolated stills; action clips stay old.
		for side in ["player", "enemy"]:
			var fighter: Node3D = game.duel_stage.get_actor_model(side)
			var sprite := game.duel_stage.get_actor_sprite(side) as AnimatedSprite3D
			var frames := sprite.sprite_frames.duplicate(true) as SpriteFrames
			var body_height := 450.0 if side == "player" else 420.0
			var hero_file := "yelingyun_idle_512.png"
			if actor_study == "density-512-detail":
				hero_file = "yelingyun_identity_detail_512.png"
			elif actor_study == "density-512-micro":
				hero_file = "yelingyun_micro_pixel_512.png"
			elif actor_study == "density-512-ink":
				hero_file = "yelingyun_pen_ink_512.png"
			var dummy_file := "quick_sword_dummy_pen_ink_512.png" if actor_study == "density-512-ink" \
				else "quick_sword_dummy_idle_512.png"
			var image_path := "res://assets/actor_candidates/density_v1/" + hero_file if side == "player" \
				else "res://assets/actor_candidates/density_v1/" + dummy_file
			var review_texture := load(image_path) as Texture2D
			if review_texture == null:
				push_error("Density review texture missing: " + image_path)
				quit(1)
				return
			var old_body_pixels := float(frames.get_meta("static_body_height")) * float(frames.get_meta("canvas_height_idle_0"))
			var old_scale := float(frames.get_meta("scale_idle"))
			frames.clear("idle")
			frames.add_frame("idle", review_texture, 1.0)
			frames.set_meta("scale_idle", old_scale * old_body_pixels / body_height)
			frames.set_meta("foot_idle_0", 486.0 / 512.0)
			frames.set_meta("canvas_width_idle_0", 512)
			frames.set_meta("canvas_height_idle_0", 512)
			sprite.sprite_frames = frames
			fighter.play_action("idle")
	if pose_study == "contact":
		var player_actor: Node3D = game.duel_stage.get_actor_model("player")
		var enemy_actor: Node3D = game.duel_stage.get_actor_model("enemy")
		player_actor.play_action("sword_probe")
		enemy_actor.play_action("hurt")
		var player_sprite := game.duel_stage.get_actor_sprite("player") as AnimatedSprite3D
		var enemy_sprite := game.duel_stage.get_actor_sprite("enemy") as AnimatedSprite3D
		player_sprite.stop()
		enemy_sprite.stop()
		player_sprite.frame = 3
		enemy_sprite.frame = 1
	if pose_study.begins_with("idle-frame-") and candidate in ["default", "trial_v16", "breath_v17"]:
		for side in ["player", "enemy"]:
			var idle_sprite := game.duel_stage.get_actor_sprite(side) as AnimatedSprite3D
			idle_sprite.stop()
			var frame_index := int(pose_study.trim_prefix("idle-frame-"))
			if frame_index >= idle_sprite.sprite_frames.get_frame_count("idle"):
				push_error("Idle review frame does not exist: " + pose_study)
				quit(1)
				return
			idle_sprite.frame = frame_index
	if art_study and candidate == "trial_v5":
		_apply_v5_art_study(game.duel_stage)
	if temple_study and candidate == "trial_v5":
		_apply_temple_study(game.duel_stage, temple_open, temple_steps)
	if vista_study and candidate == "trial_v5":
		_apply_vista_study(game.duel_stage)
	if clear_bank and candidate == "trial_v5":
		_apply_clear_bank(game.duel_stage)
	if vista_crisp and candidate == "trial_v8":
		var vista := game.duel_stage.get_world_model().find_child("SM_FarVista_OnlyMountainsAndSky", true, false) as MeshInstance3D
		if vista != null:
			var matte := vista.get_surface_override_material(0) as StandardMaterial3D
			if matte != null:
				matte.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if warm_study and candidate == "trial_v8":
		_apply_v8_warm_study(game.duel_stage)
	if lamp_debug:
		var camera := game.duel_stage.get_node("Viewport/World/CameraRig/Camera") as Camera3D
		for node in game.duel_stage.get_node("Viewport/World").find_children("*", "Node3D", true, false):
			if "lantern" in node.name.to_lower() or "lamp" in node.name.to_lower() \
					or "sconce" in node.name.to_lower():
				print("LAMP_DEBUG name=", node.name, " world=", node.global_position,
					" screen=", camera.unproject_position(node.global_position), " visible=", node.visible)
	if pose_study == "runtime-contact":
		var contacts: Array[String] = []
		game.duel_stage.contact_frame.connect(func(side: String) -> void: contacts.append(side))
		(game.hand_row.get_child(0) as Button).pressed.emit()
		for tick in 180:
			if "player" in contacts:
				break
			await process_frame
		if not "player" in contacts:
			push_error("Runtime first-card contact was not reached")
			quit(1)
			return
		var camera := game.duel_stage.get_node("Viewport/World/CameraRig/Camera") as Camera3D
		var tip: Vector3 = game.duel_stage.get_actor_model("player").get_sword_tip().global_position
		var chest: Vector3 = game.duel_stage.get_actor_model("enemy").get_chest_hit().global_position
		var hurt_chest: Vector3 = game.duel_stage.get_actor_model("enemy").get_chest_point_for("hurt", 0, camera)
		print("RUNTIME_CONTACT_ALIGNMENT tip=", camera.unproject_position(tip),
			" static_chest=", camera.unproject_position(chest),
			" hurt_chest=", camera.unproject_position(hurt_chest),
			" hurt_world_gap=", tip.distance_to(hurt_chest))
	else:
		for tick in 35:
			await process_frame
	await RenderingServer.frame_post_draw
	var screen := root.get_viewport().get_texture().get_image()
	if screen == null or screen.is_empty():
		push_error("No rendered first-fight frame from " + backend)
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output).get_base_dir())
	var err := screen.save_png(ProjectSettings.globalize_path(output))
	if err != OK:
		push_error("Could not save first-fight backend capture: " + str(err))
		quit(1)
		return
	print("FIRST_FIGHT_BACKEND_CAPTURE candidate=", candidate, " yaw=", yaw, " backend=", backend, " driver=", driver,
		" lighting_study=", lighting_study,
		" world=", game.duel_stage.get_world_model().name,
		" player=", game.duel_stage.get_actor_model("player").name,
		" enemy=", game.duel_stage.get_actor_model("enemy").name,
		" output=", output)
	quit(0)


func _apply_v12_floor_study(stage: Node) -> bool:
	var floor_mesh := stage.get_world_model().find_child("Hall_scanned_slate_floor", true, false) as MeshInstance3D
	if floor_mesh == null:
		push_error("V12 floor study could not find the V6 scanned floor")
		return false
	var material := ShaderMaterial.new()
	material.shader = load("res://shaders/trial_hall_floor_wear_v12.gdshader") as Shader
	var source := "res://art_source/cangmang_trial_hall_v6/vendor_polyhaven/"
	for parameter in [
		["slate_color", "large_grey_tiles_diffuse_2k.jpg"],
		["slate_rough", "large_grey_tiles_rough_2k.jpg"],
		["slate_normal", "large_grey_tiles_nor_gl_2k.jpg"],
		["worn_color", "stone_tiles_diffuse_2k.jpg"],
		["worn_rough", "stone_tiles_rough_2k.jpg"],
		["worn_normal", "stone_tiles_nor_gl_2k.jpg"],
	]:
		var path := ProjectSettings.globalize_path(source + String(parameter[1]))
		var source_image := Image.load_from_file(path)
		if source_image == null or source_image.is_empty():
			push_error("V12 floor study texture missing: " + String(parameter[1]))
			return false
		var tex := ImageTexture.create_from_image(source_image)
		material.set_shader_parameter(String(parameter[0]), tex)
	floor_mesh.set_surface_override_material(0, material)
	return true


func _apply_local_wear_study(stage: Node) -> bool:
	var floor_mesh := stage.get_world_model().find_child("Hall_scanned_slate_floor", true, false) as MeshInstance3D
	if floor_mesh == null:
		push_error("Local wear study could not find V6 scanned floor")
		return false
	var material := ShaderMaterial.new()
	material.shader = load("res://shaders/trial_hall_local_wear_v1.gdshader") as Shader
	var source := "res://art_source/cangmang_trial_hall_v6/vendor_polyhaven/"
	for parameter in [
		["slate_color", "large_grey_tiles_diffuse_2k.jpg"],
		["slate_rough", "large_grey_tiles_rough_2k.jpg"],
		["slate_normal", "large_grey_tiles_nor_gl_2k.jpg"],
	]:
		var source_image := Image.load_from_file(ProjectSettings.globalize_path(source + String(parameter[1])))
		if source_image == null or source_image.is_empty():
			push_error("Local wear study texture missing: " + String(parameter[1]))
			return false
		material.set_shader_parameter(String(parameter[0]), ImageTexture.create_from_image(source_image))
	floor_mesh.set_surface_override_material(0, material)
	return true


func _apply_material_filter_study(stage: Node) -> void:
	for mesh in stage.get_world_model().find_children("*", "MeshInstance3D", true, false):
		var instance := mesh as MeshInstance3D
		if instance.mesh == null:
			continue
		for surface_index in instance.mesh.get_surface_count():
			var original := instance.mesh.surface_get_material(surface_index) as StandardMaterial3D
			if original == null:
				continue
			var material := original.duplicate() as StandardMaterial3D
			material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
			instance.set_surface_override_material(surface_index, material)


func _apply_denser_slate_study(stage: Node) -> bool:
	var floor_mesh := stage.get_world_model().find_child("Hall_scanned_slate_floor", true, false) as MeshInstance3D
	if floor_mesh == null or floor_mesh.mesh == null:
		push_error("Denser slate study could not find V6 floor mesh")
		return false
	var material := floor_mesh.mesh.surface_get_material(0).duplicate() as StandardMaterial3D
	if material == null:
		push_error("Denser slate study requires original PBR material")
		return false
	material.uv1_scale = Vector3(1.28, 1.28, 1.0)
	floor_mesh.set_surface_override_material(0, material)
	return true


func _apply_v6_light_pass(stage: Node, pass_name: String) -> void:
	var world := stage.get_node("Viewport/World") as Node3D
	var bounce := world.get_node("CombatStoneBounce") as OmniLight3D
	var chandelier := world.get_node("ChandelierPhysicalPool") as OmniLight3D
	match pass_name:
		"no-bounce":
			bounce.light_energy = 0.0
		"soft-bounce":
			bounce.light_energy = 0.65
			chandelier.light_energy = 3.4
		"chandelier-bounce":
			bounce.light_energy = 0.35
			chandelier.light_energy = 5.15
			chandelier.omni_range = 11.7
		"sconce-shadow":
			bounce.light_energy = 0.65
			for name in ["WestStoneSconce", "EastStoneSconce"]:
				var lamp := world.get_node(name) as OmniLight3D
				lamp.light_energy = 1.6
				lamp.omni_range = 4.7
				lamp.shadow_enabled = true
				lamp.shadow_blur = 2.5
		"v14-physical-sconces":
			bounce.light_energy = 1.15
			bounce.light_color = Color("d8c9b2")
			for name in ["WestStoneSconce", "EastStoneSconce"]:
				var lamp := world.get_node(name) as OmniLight3D
				lamp.position.z = -6.25
				lamp.light_energy = 2.8
				lamp.omni_range = 6.6
				lamp.shadow_enabled = true
				lamp.shadow_blur = 2.0
		"actor-warm-key":
			var hero_key := world.get_node("HeroFill") as OmniLight3D
			hero_key.light_color = Color("e7ceab")
			hero_key.light_energy = 1.43
			var dummy_rim := world.get_node("DummyRim") as OmniLight3D
			dummy_rim.light_energy = 0.64
		"amber-window":
			var window_light := SpotLight3D.new()
			window_light.name = "AmberClerestoryStudy"
			world.add_child(window_light)
			window_light.position = Vector3(1.90, 5.72, -7.05)
			window_light.look_at(Vector3(0.6, 0.0, 0.25))
			window_light.light_color = Color("f3d4a3")
			window_light.light_energy = 4.1
			window_light.spot_range = 14.0
			window_light.spot_angle = 35.0
			window_light.shadow_enabled = true
			window_light.shadow_blur = 2.0
		"north-window":
			var north_light := SpotLight3D.new()
			north_light.name = "NorthClerestoryStudy"
			world.add_child(north_light)
			north_light.position = Vector3(-7.90, 5.72, -7.05)
			north_light.look_at(Vector3(-2.25, 0.0, 0.18))
			north_light.light_color = Color("d2d9d5")
			north_light.light_energy = 8.0
			north_light.spot_range = 14.0
			north_light.spot_angle = 40.0
			north_light.shadow_enabled = true
			north_light.shadow_blur = 2.0
		_:
			push_error("Unknown V6 lighting study: " + pass_name)


func _apply_lighting_study(stage: Node) -> void:
	# Isolated in-memory value study. All fixtures already exist in the V7 scene.
	var world := stage.get_node("Viewport/World") as Node3D
	var environment := (world.get_node("WorldEnvironment") as WorldEnvironment).environment
	environment.ambient_light_color = Color("81959d")
	environment.ambient_light_energy = 0.27
	environment.ssao_enabled = true
	environment.ssao_intensity = 1.25
	environment.ssao_radius = 1.10
	for name in ["WestStoneSconce", "EastStoneSconce"]:
		var lamp := world.get_node(name) as OmniLight3D
		lamp.light_energy = 2.35
		lamp.omni_range = 4.65
		lamp.shadow_enabled = true
	var chandelier := world.get_node("ChandelierPhysicalPool") as OmniLight3D
	chandelier.light_energy = 1.80
	chandelier.omni_range = 5.5
	chandelier.shadow_enabled = true
	(world.get_node("CombatStoneBounce") as OmniLight3D).light_energy = 0.18
	(world.get_node("HeroFill") as OmniLight3D).light_energy = 0.76
	(world.get_node("DummyRim") as OmniLight3D).light_energy = 0.36
	var key := world.get_node("V7NorthClerestoryCoolKey") as SpotLight3D
	key.light_energy = 1.28
	key.shadow_enabled = true
	var far_bounce := world.get_node("V7FarWindowBounce") as OmniLight3D
	far_bounce.light_energy = 0.70


func _apply_v5_art_study(stage: Node) -> void:
	var world := stage.get_node("Viewport/World") as Node3D
	var environment := (world.get_node("WorldEnvironment") as WorldEnvironment).environment
	environment.ambient_light_color = Color("829aa4")
	environment.ambient_light_energy = 0.34
	environment.fog_light_color = Color("617984")
	environment.fog_depth_begin = 12.0
	environment.fog_depth_end = 43.0
	environment.fog_density = 0.44
	environment.ssao_intensity = 0.85
	var sky := world.get_node("RainSkyDirection") as DirectionalLight3D
	sky.light_energy = 0.29
	sky.light_color = Color("acc2ce")
	sky.shadow_enabled = false
	var sun := DirectionalLight3D.new()
	sun.name = "RainClearingSun"
	sun.rotation_degrees = Vector3(-42.0, -58.0, 0.0)
	sun.light_color = Color("ffe2b9")
	sun.light_energy = 0.95
	sun.shadow_enabled = true
	sun.shadow_blur = 3.0
	world.add_child(sun)
	(world.get_node("HeroFill") as OmniLight3D).light_energy = 0.64
	(world.get_node("DummyRim") as OmniLight3D).light_energy = 0.42
	for name in ["ShelterLantern", "GateLantern"]:
		var lamp := world.get_node(name) as OmniLight3D
		lamp.light_energy = 1.25
		lamp.omni_range = 4.2
		lamp.shadow_enabled = false


func _apply_temple_study(stage: Node, open_layout: bool, keep_steps: bool) -> void:
	var source := load("res://assets/hd2d/qingyun_temple_v8/chinese_temple_cc0.glb") as PackedScene
	if source == null:
		push_error("Missing imported CC0 Qingyun temple candidate")
		return
	var temple := source.instantiate() as Node3D
	temple.name = "QingyunTempleCC0Candidate"
	temple.position = Vector3(3.2, 1.82, -12.8) if keep_steps else (Vector3(1.5, -0.25, -16.5) if open_layout else Vector3(2.0, -0.25, -19.0))
	temple.scale = Vector3.ONE * (0.30 if keep_steps else (0.38 if open_layout else 0.42))
	stage.get_world_model().add_child(temple)
	if open_layout:
		for node in stage.get_world_model().find_children("*", "Node3D", true, false):
			if node.name.begins_with("SM_SectGate_") or node.name.begins_with("SM_V5_Gatehouse_") \
					or (not keep_steps and node.name.begins_with("SM_GateApproach_")) \
					or (not keep_steps and node.name.begins_with("SM_Approach_")):
				node.visible = false
	var fill := OmniLight3D.new()
	fill.name = "QingyunTempleFacadeStudyFill"
	fill.position = Vector3(2.0, 5.6, -10.0)
	fill.light_color = Color("b8c9d0")
	fill.light_energy = 1.55
	fill.omni_range = 13.0
	fill.shadow_enabled = false
	stage.get_node("Viewport/World").add_child(fill)


func _apply_vista_study(stage: Node) -> void:
	var plane := stage.get_world_model().find_child("SM_FarVista_OnlyMountainsAndSky", true, false) as MeshInstance3D
	if plane == null:
		push_error("V5 mountain vista mesh missing")
		return
	var original := plane.mesh.surface_get_material(0)
	print("VISTA_ORIGINAL_MATERIAL ", original.get_class() if original != null else "null")
	if not original is StandardMaterial3D:
		return
	var material := original.duplicate() as StandardMaterial3D
	var img := Image.load_from_file(ProjectSettings.globalize_path("res://assets/hd2d/qingyun_temple_v8/far_mountains_v1.png"))
	if img == null:
		push_error("Generated Qingyun distant mountain matte missing")
		return
	material.albedo_texture = ImageTexture.create_from_image(img)
	plane.set_surface_override_material(0, material)


func _apply_clear_bank(stage: Node) -> void:
	for node in stage.get_world_model().find_children("*", "Node3D", true, false):
		if node.name.begins_with("SM_PineSlope_") or node.name.begins_with("SM_V5_MiddlePine_") \
				or node.name.begins_with("SM_RealPine_"):
			node.visible = false


func _apply_v8_warm_study(stage: Node) -> void:
	var world := stage.get_node("Viewport/World") as Node3D
	var environment := (world.get_node("WorldEnvironment") as WorldEnvironment).environment
	environment.ambient_light_energy = 0.40
	var sky := world.get_node("RainSkyDirection") as DirectionalLight3D
	sky.light_energy = 0.52
	var shelter := world.get_node("ShelterLantern") as OmniLight3D
	shelter.light_energy = 5.0
	shelter.omni_range = 7.0
	(world.get_node("GateLantern") as OmniLight3D).light_energy = 0.0
	var threshold := OmniLight3D.new()
	threshold.name = "TempleThresholdWarmStudy"
	threshold.position = Vector3(3.2, 3.2, -10.1)
	threshold.light_color = Color("ffcf95")
	threshold.light_energy = 3.1
	threshold.omni_range = 5.2
	threshold.shadow_enabled = true
	world.add_child(threshold)
