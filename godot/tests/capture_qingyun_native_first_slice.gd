extends SceneTree

const OUT := "res://output/captures/godot-migration/qingyun-native-first-slice/"


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
		_fail("Native first-fight stage did not load")
		return
	if await _save("idle_1280.png") != OK:
		quit(1)
		return
	var world: SubViewport = battle.duel_stage.get_node("Viewport")
	var native_error := world.get_texture().get_image().save_png(OUT + "world_native_1x.png")
	if native_error != OK:
		_fail("Native 1x world screenshot failed")
		return
	root.size = Vector2i(1024, 768)
	await create_timer(0.2).timeout
	if await _save("idle_1024.png") != OK:
		quit(1)
		return
	root.size = Vector2i(1280, 800)
	await create_timer(0.2).timeout
	var stage: Node = battle.duel_stage
	var anchor: Node2D = stage.get_node("Viewport/World/PlayerAnchor")
	var home := anchor.position
	anchor.position = Vector2(165, 244)
	await create_timer(0.1).timeout
	if await _save("near_torch_diagnostic_1280.png") != OK:
		quit(1)
		return
	anchor.position = Vector2(126, 320)
	await create_timer(0.1).timeout
	if await _save("pillar_occlusion_diagnostic_1280.png") != OK:
		quit(1)
		return
	anchor.position = home
	var contacts: Array[String] = []
	stage.contact_frame.connect(func(side: String) -> void: contacts.append(side))
	(battle.hand_row.get_child(0) as Button).pressed.emit()
	for _sample in 100:
		if "player" in contacts:
			break
		await create_timer(0.01).timeout
	if not "player" in contacts or await _save("contact_1280.png") != OK:
		_fail("Native sword probe did not reach capture contact")
		return
	print("QINGYUN_NATIVE_CAPTURE_PASS idle=1280+1024 torch+occlusion=diagnostic contact=1280")
	quit(0)


func _save(name: String) -> Error:
	await process_frame
	await RenderingServer.frame_post_draw
	var error := root.get_texture().get_image().save_png(OUT + name)
	if error != OK:
		push_error("Native screenshot failed: " + name)
	return error


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
