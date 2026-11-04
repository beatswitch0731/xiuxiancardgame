extends SceneTree

# Real-entry regression: the first source card is presented by pixel-frame
# actors inside a spatial 3D battlefield, and visible damage waits for contact.


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var game: Control = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	var stage: Node = game.duel_stage
	if stage == null or not stage.has_method("get_actor_sprite"):
		_fail("main entry has no HD-2D sprite actors")
		return
	var hero := stage.get_actor_sprite("player") as AnimatedSprite3D
	var dummy := stage.get_actor_sprite("enemy") as AnimatedSprite3D
	var world := stage.get_world_model() as Node3D
	if hero == null or dummy == null or world == null or _mesh_count(world) < 24:
		_fail("pixel actors and spatial battlefield are not mounted together")
		return
	if hero.sprite_frames == null or dummy.sprite_frames == null \
			or hero.sprite_frames.get_frame_count("sword_probe") != 6 \
			or dummy.sprite_frames.get_frame_count("attack") != 4:
		_fail("source-authored action frames were not loaded")
		return
	var breath_candidate := "--breath-v17-candidate" in OS.get_cmdline_user_args()
	var expected_idle_phases := 4 if breath_candidate else 1
	for sprite in [hero, dummy]:
		if sprite.sprite_frames.get_frame_count("idle") != expected_idle_phases:
			_fail("opening idle phases do not match the approved default or isolated candidate")
			return
		if not breath_candidate:
			if bool(sprite.sprite_frames.get_meta("source_pixel_breath_study", false)):
				_fail("rejected breath study leaked into the default opening")
				return
			continue
		if not bool(sprite.sprite_frames.get_meta("frameronin_verified_atlas", false)):
			_fail("candidate idle is not mounted from the reviewed FrameRonin atlas")
			return
		var foot := float(sprite.sprite_frames.get_meta("foot_idle_0", -1.0))
		for frame_index in 4:
			var cell := sprite.sprite_frames.get_frame_texture("idle", frame_index) as AtlasTexture
			var expected := Rect2((frame_index % 2) * 320, floori(frame_index / 2.0) * 320, 320, 320)
			if cell == null or cell.region != expected or not cell.filter_clip:
				_fail("FrameRonin idle cell order or clipping is invalid")
				return
			if frame_index == 0:
				continue
			if absf(float(sprite.sprite_frames.get_meta("foot_idle_%d" % frame_index, -1.0)) - foot) > 0.0001:
				_fail("idle phases changed the actor's ground anchor")
				return
	if absf(float(hero.sprite_frames.get_meta("duration_ms_sword_probe", 0.0)) - 526.0) > 0.5 \
			or int(hero.sprite_frames.get_meta("impact_frame_sword_probe", -1)) != 3:
		_fail("source sword timing or impact frame changed")
		return
	if not hero.texture_filter == BaseMaterial3D.TEXTURE_FILTER_NEAREST \
			or hero.no_depth_test or dummy.no_depth_test:
		_fail("pixel edges or spatial occlusion contract is broken")
		return
	var first := game.hand_row.get_child(0) as Button
	if first == null or first.get_meta("source_card_id") != "sword_probe":
		_fail("source card hand missing")
		return
	var contacts: Array[String] = []
	stage.contact_frame.connect(func(side: String) -> void: contacts.append(side))
	first.pressed.emit()
	if not game.combat.input_locked or not game.enemy_label.text.contains("7/7"):
		_fail("damage was exposed before visual contact")
		return
	for sample in 75:
		if "player" in contacts:
			break
		await create_timer(0.02).timeout
	if not "player" in contacts or not game.enemy_label.text.contains("6/7"):
		_fail("first source card did not display damage at sprite contact")
		return
	print("HD2D_STAGE_CONTRACT_PASS world_meshes=", _mesh_count(world),
		" source_hero_frames=6 source_dummy_frames=4 idle_phases=", expected_idle_phases,
		" contact=true")
	quit(0)


func _mesh_count(node: Node) -> int:
	var total := 1 if node is MeshInstance3D and (node as MeshInstance3D).mesh != null else 0
	for child in node.get_children():
		total += _mesh_count(child)
	return total


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
