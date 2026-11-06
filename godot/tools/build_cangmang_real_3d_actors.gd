extends SceneTree

# Run with: godot --headless --path godot --script res://tools/build_cangmang_real_3d_actors.gd
# Scenes self-author editable, lit volume meshes and an AnimationPlayer at load.
func _initialize() -> void:
	call_deferred("_main")


func _main() -> void:
	if OS.get_cmdline_user_args().has("bake") and not _bake_scenes():
		quit(8)
		return
	_check_scenes()


func _bake_scenes() -> bool:
	for scene_path in ["res://scenes/yelingyun_s1_real_3d.tscn",
		"res://scenes/quick_sword_dummy_real_3d.tscn"]:
		var actor: Node3D = load(scene_path).instantiate()
		root.add_child(actor)
		actor.rebuild_model()
		_assign_owner_recursive(actor, actor)
		var packed := PackedScene.new()
		var packed_error := packed.pack(actor)
		if packed_error != OK:
			push_error("REAL_3D_ACTOR_PACK_FAILED path=%s error=%d" % [scene_path, packed_error])
			return false
		var save_error := ResourceSaver.save(packed, scene_path)
		if save_error != OK:
			push_error("REAL_3D_ACTOR_SAVE_FAILED path=%s error=%d" % [scene_path, save_error])
			return false
		print("REAL_3D_ACTOR_BAKED scene=%s meshes=%d" % [scene_path, actor.mesh_count()])
		actor.queue_free()
	return true


func _assign_owner_recursive(node: Node, scene_root: Node) -> void:
	for child in node.get_children():
		child.owner = scene_root
		_assign_owner_recursive(child, scene_root)


func _check_scenes() -> void:
	for scene_path in [
		"res://scenes/yelingyun_s1_real_3d.tscn",
		"res://scenes/quick_sword_dummy_real_3d.tscn"
	]:
		var packed: PackedScene = load(scene_path)
		if packed == null:
			push_error("REAL_3D_ACTOR_SCENE_MISSING " + scene_path)
			quit(2)
			return
		var actor: Node3D = packed.instantiate()
		root.add_child(actor)
		for clip in ["idle", "sword_probe", "sword_followthrough", "sword_guard",
			"attack", "hurt", "reaction", "guard", "defeat"]:
			if not actor.has_action(clip):
				push_error("REAL_3D_ACTOR_CLIP_MISSING " + scene_path + " " + clip)
				quit(3)
				return
		if actor.mesh_count() < 30:
			push_error("REAL_3D_ACTOR_MESH_COUNT_LOW " + scene_path)
			quit(4)
			return
		if actor.get_sword_tip() == null or actor.get_chest_hit() == null:
			push_error("REAL_3D_ACTOR_CONTACT_MARKER_MISSING " + scene_path)
			quit(4)
			return
		if not actor.play_action("sword_probe"):
			push_error("REAL_3D_ACTOR_ACTION_FAILED " + scene_path)
			quit(5)
			return
		print("REAL_3D_ACTOR_READY kind=%s meshes=%d probe_contact=%.2f scene=%s" % [
			actor.fighter_kind, actor.mesh_count(), actor.get_contact_time("sword_probe"), scene_path])
		actor.queue_free()
	if not _check_contact_geometry():
		quit(6)
		return
	if OS.get_cmdline_user_args().has("stageprobe"):
		_stage_probe()
	elif OS.get_cmdline_user_args().has("preview"):
		_preview()
	else:
		quit(0)


func _check_contact_geometry() -> bool:
	var hero: Node3D = load("res://scenes/yelingyun_s1_real_3d.tscn").instantiate()
	var dummy: Node3D = load("res://scenes/quick_sword_dummy_real_3d.tscn").instantiate()
	root.add_child(hero)
	root.add_child(dummy)
	hero.rotation.y = 0.0
	dummy.rotation.y = PI
	hero.position.x = .40
	dummy.position.x = 2.3
	hero.play_action("sword_probe")
	hero.get_animation_player().seek(.31, true)
	var hero_distance: float = hero.get_sword_tip().global_position.distance_to(dummy.get_chest_hit().global_position)
	print("REAL_3D_CONTACT_POINTS hero_tip=%s dummy_chest=%s" % [hero.get_sword_tip().global_position, dummy.get_chest_hit().global_position])
	hero.position.x = -2.3
	dummy.position.x = -.20
	hero.play_action("idle")
	dummy.play_action("attack")
	dummy.get_animation_player().seek(.38, true)
	var dummy_distance: float = dummy.get_sword_tip().global_position.distance_to(hero.get_chest_hit().global_position)
	print("REAL_3D_CONTACT_POINTS dummy_tip=%s hero_chest=%s" % [dummy.get_sword_tip().global_position, hero.get_chest_hit().global_position])
	print("REAL_3D_CONTACT_DISTANCE hero=%.3f dummy=%.3f with 2.70/2.50-unit lunges" % [hero_distance, dummy_distance])
	var hit_credible := hero_distance <= .45 and dummy_distance <= .45
	if not hit_credible:
		push_error("REAL_3D_CONTACT_GEOMETRY_MISSED")
	hero.queue_free()
	dummy.queue_free()
	return hit_credible


func _stage_probe() -> void:
	var stage: Control = load("res://scenes/duel_stage_real_3d.tscn").instantiate()
	root.add_child(stage)
	var hero: Node3D = stage.get_actor_model("player")
	var dummy: Node3D = stage.get_actor_model("enemy")
	hero.action_finished.connect(func(clip: String) -> void: print("REAL_3D_STAGE_HERO_ACTION_FINISHED ", clip))
	dummy.action_finished.connect(func(clip: String) -> void: print("REAL_3D_STAGE_DUMMY_ACTION_FINISHED ", clip))
	stage.presentation_finished.connect(func(kind: String) -> void: print("REAL_3D_STAGE_PRESENTATION_FINISHED ", kind))
	stage.presentation_started.connect(func(kind: String, side: String, clip: String) -> void:
		print("REAL_3D_STAGE_PRESENTATION_STARTED %s %s %s" % [kind, side, clip]))
	hero.contact_key.connect(func(clip: String) -> void:
		var tip: Vector3 = hero.get_sword_tip().global_position
		var chest: Vector3 = dummy.get_chest_hit().global_position
		print("REAL_3D_ACTOR_CONTACT_KEY clip=%s tip=%s chest=%s distance=%.3f anim_pos=%.3f" % [
			clip, tip, chest, tip.distance_to(chest),
			hero.get_animation_player().current_animation_position]))
	stage.present_action({"type": "CARD_PLAY", "cardId": "sword_probe",
		"effects": [{"type": "damage", "hpLoss": 1}]})
	await stage.contact_frame
	var tip: Vector3 = hero.get_sword_tip().global_position
	var chest: Vector3 = dummy.get_chest_hit().global_position
	print("REAL_3D_LIVE_STAGE_HERO_CONTACT tip=%s chest=%s distance=%.3f anim=%s pos=%.3f" % [
		tip, chest, tip.distance_to(chest), hero.get_animation_player().current_animation,
		hero.get_animation_player().current_animation_position])
	await stage.presentation_finished
	dummy.contact_key.connect(func(clip: String) -> void:
		var enemy_tip: Vector3 = dummy.get_sword_tip().global_position
		var hero_chest: Vector3 = hero.get_chest_hit().global_position
		print("REAL_3D_DUMMY_CONTACT_KEY clip=%s tip=%s chest=%s distance=%.3f anim_pos=%.3f" % [
			clip, enemy_tip, hero_chest, enemy_tip.distance_to(hero_chest),
			dummy.get_animation_player().current_animation_position]))
	stage.present_action({"type": "ENEMY_ACTION", "reactionId": "TAKE_HIT",
		"intent": {"type": "attack"}, "hpLoss": 1})
	await stage.contact_frame
	var enemy_tip: Vector3 = dummy.get_sword_tip().global_position
	var hero_chest: Vector3 = hero.get_chest_hit().global_position
	print("REAL_3D_LIVE_STAGE_DUMMY_CONTACT tip=%s chest=%s distance=%.3f anim=%s pos=%.3f" % [
		enemy_tip, hero_chest, enemy_tip.distance_to(hero_chest),
		dummy.get_animation_player().current_animation,
		dummy.get_animation_player().current_animation_position])
	quit(0)


func _preview() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 800)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var world := Node3D.new()
	viewport.add_child(world)
	var camera := Camera3D.new()
	camera.position = Vector3(0, 2.7, 8.0)
	camera.fov = 38.0
	world.add_child(camera)
	camera.look_at(Vector3(0, .92, 0))
	camera.current = true
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-.7, -.4, 0)
	sun.light_energy = 1.25
	world.add_child(sun)
	var key := OmniLight3D.new()
	key.position = Vector3(-2.5, 3.5, 4.0)
	key.light_color = Color("c8d6d2")
	key.light_energy = 2.1
	key.omni_range = 12.0
	world.add_child(key)
	var warm := OmniLight3D.new()
	warm.position = Vector3(3.0, 2.7, 3.0)
	warm.light_color = Color("d6bd9e")
	warm.light_energy = 1.1
	warm.omni_range = 10.0
	world.add_child(warm)
	var floor_mesh := PlaneMesh.new()
	floor_mesh.size = Vector2(11, 6)
	var floor := MeshInstance3D.new()
	floor.mesh = floor_mesh
	var floor_material := StandardMaterial3D.new()
	floor_material.albedo_color = Color("4b5d62")
	floor.material_override = floor_material
	world.add_child(floor)
	for scene_path in ["res://scenes/yelingyun_s1_real_3d.tscn",
		"res://scenes/quick_sword_dummy_real_3d.tscn"]:
		var actor: Node3D = load(scene_path).instantiate()
		world.add_child(actor)
		actor.position.x = -1.25 if actor.fighter_kind == "hero" else 1.25
		if actor.fighter_kind == "dummy":
			actor.rotation.y = PI + .62
		else:
			actor.rotation.y = -.62
		if OS.get_cmdline_user_args().has("attack"):
			var clip := "sword_probe" if actor.fighter_kind == "hero" else "attack"
			actor.play_action(clip)
			actor.get_animation_player().seek(actor.get_contact_time(clip), true)
	_save_preview.call_deferred(viewport)


func _save_preview(viewport: SubViewport) -> void:
	await process_frame
	await process_frame
	await process_frame
	var file_name := "real-3d-actor-attack-preview.png" if OS.get_cmdline_user_args().has("attack") else "real-3d-actor-preview.png"
	var path := ProjectSettings.globalize_path("res://output/captures/godot-migration/source-first-fight/" + file_name)
	var image := viewport.get_texture().get_image()
	if image == null:
		push_error("REAL_3D_ACTOR_PREVIEW_NEEDS_RENDERING_BACKEND")
		quit(7)
		return
	var error := image.save_png(path)
	print("REAL_3D_ACTOR_PREVIEW path=%s error=%d size=%dx%d" % [path, error, image.get_width(), image.get_height()])
	quit(0 if error == OK else 6)
