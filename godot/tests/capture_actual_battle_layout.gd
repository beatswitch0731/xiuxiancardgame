extends SceneTree

const BattleScene = preload("res://scenes/main.tscn")
const OUT := "res://art_direction/candidates/actual_battle_layout_20261023/evidence/"

func _initialize() -> void:
	call_deferred("_capture")

func _capture() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	root.size = Vector2i(1280, 800)
	var battle: Control = BattleScene.instantiate()
	root.add_child(battle)
	await create_timer(1.0).timeout
	if battle.duel_stage == null or not battle.stage_assets_ready:
		push_error("Actual combat stage did not load")
		quit(1)
		return
	await _save("actual_battle_1280_idle.png")
	root.size = Vector2i(1024, 768)
	await _save("actual_battle_1024_idle.png")
	root.size = Vector2i(1280, 800)
	await process_frame
	var contacts: Array[String] = []
	battle.duel_stage.contact_frame.connect(func(side: String) -> void:
		contacts.append(side))
	var first_card := battle.hand_row.get_child(0) as Button
	first_card.pressed.emit()
	for frame in 100:
		if "player" in contacts:
			break
		await create_timer(0.02).timeout
	if not "player" in contacts:
		push_error("Actual combat attack did not reach its contact frame")
		quit(1)
		return
	await _save("actual_battle_1280_contact.png")
	print("ACTUAL_BATTLE_LAYOUT_CAPTURE_PASS")
	quit(0)

func _save(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var error := root.get_texture().get_image().save_png(OUT + name)
	if error != OK:
		push_error("Actual battle capture failed: " + name)
