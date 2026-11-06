extends SceneTree

const BattleScene = preload("res://scenes/reference_battle_demo.tscn")
const OUT := "res://output/captures/godot-migration/reference-battle-frontend/"


func _initialize() -> void:
	call_deferred("_capture")


func _capture() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	root.size = Vector2i(1280, 800)
	var battle: Control = BattleScene.instantiate()
	root.add_child(battle)
	Input.warp_mouse(Vector2(20, 20))
	await create_timer(1.0).timeout
	if battle.duel_stage == null or not battle.stage_assets_ready:
		push_error("Reference battle stage did not load")
		quit(1)
		return
	if await _save("battle_1280_idle.png") != OK:
		quit(1)
		return
	root.size = Vector2i(1024, 768)
	await create_timer(0.2).timeout
	if await _save("battle_1024_idle.png") != OK:
		quit(1)
		return
	root.size = Vector2i(1280, 800)
	await create_timer(0.2).timeout
	var contacts: Array[String] = []
	battle.duel_stage.contact_frame.connect(func(side: String) -> void: contacts.append(side))
	(battle.hand_row.get_child(0) as Button).pressed.emit()
	for _sample in 100:
		if "player" in contacts:
			break
		await create_timer(0.02).timeout
	if not "player" in contacts:
		push_error("Reference battle attack did not reach contact")
		quit(1)
		return
	if await _save("battle_1280_contact.png") != OK:
		quit(1)
		return
	print("REFERENCE_BATTLE_FRONTEND_CAPTURE_PASS")
	quit(0)


func _save(name: String) -> Error:
	await process_frame
	await RenderingServer.frame_post_draw
	var error := root.get_texture().get_image().save_png(OUT + name)
	if error != OK:
		push_error("Reference battle screenshot failed: " + name)
	return error
