extends SceneTree

const Registry = preload("res://scripts/runtime_data_registry.gd")
const Domain = preload("res://scripts/noncombat_domain.gd")
const RunSession = preload("res://scripts/noncombat_run_session.gd")
const OpeningScene = preload("res://scenes/noncombat_opening.tscn")
const OUT := "res://output/captures/godot-migration/whitefox-live-battle/"


func _initialize() -> void:
	call_deferred("_capture")


func _capture() -> void:
	var save_path := "user://tests/whitefox_capture_%d.json" % Time.get_ticks_usec()
	var game = Domain.new(Registry.new(), RunSession.new(save_path))
	if not game.start("sword"):
		return _fail("whitefox capture could not start")
	for _choice in range(5):
		if not game.choose("left", game.issue_choice_token()):
			return _fail("whitefox capture tutorial route failed")
	if not game.choose("right", game.issue_choice_token()) \
			or not game.choose("left", game.issue_choice_token()) \
			or not game.resume_flow() \
			or not game.choose("left", game.issue_choice_token()) \
			or not game.choose("right", game.issue_choice_token()) \
			or not game.resume_flow() \
			or not game.choose("right", game.issue_choice_token()) \
			or not game.choose("left", game.issue_choice_token()) \
			or game.state.get("currentCardId") != "q_whiteFox_3" \
			or not game.choose("left", game.issue_choice_token()) \
			or not game.choose("left", game.issue_choice_token()):
		return _fail("whitefox capture natural pending battle failed")
	root.size = Vector2i(1280, 800)
	var story: Control = OpeningScene.instantiate()
	story.save_path = save_path
	root.add_child(story)
	for _frame in range(6):
		await process_frame
	var launch: Button = story.find_child("LaunchBattle", true, false)
	if launch == null or launch.disabled:
		return _fail("whitefox capture launch button missing")
	launch.pressed.emit()
	for _frame in range(6):
		await process_frame
	var battle: Control = story.active_battle
	if battle == null or not battle.stage_assets_ready:
		return _fail("whitefox capture stage did not load")
	if not await _save("whitefox_1280_idle.png"):
		return _fail("whitefox 1280 screenshot failed")
	root.size = Vector2i(1920, 1080)
	for _frame in range(6):
		await process_frame
	if not await _save("whitefox_1920_idle.png"):
		return _fail("whitefox 1920 screenshot failed")
	root.size = Vector2i(1280, 800)
	for _frame in range(4):
		await process_frame
	battle.end_button.pressed.emit()
	await process_frame
	if battle.combat.state.get("phase") != "REACTION_OPEN":
		return _fail("whitefox capture reaction did not open")
	battle.reaction_buttons[0].pressed.emit()
	var weak: TextureRect = battle.duel_stage.find_child("SourceWeakVfx", true, false)
	var captured := false
	for _frame in range(30):
		await create_timer(0.02).timeout
		if weak != null and weak.visible:
			captured = await _save("whitefox_1280_weak.png")
			break
	if not captured:
		return _fail("whitefox weak frame was not captured")
	story.queue_free()
	await process_frame
	print("WHITEFOX_BATTLE_CAPTURE_PASS idle=2 weak=1 desktop=true")
	quit(0)


func _save(filename: String) -> bool:
	await process_frame
	var image: Image = root.get_texture().get_image()
	if image == null or image.is_empty():
		return false
	var directory := ProjectSettings.globalize_path(OUT)
	DirAccess.make_dir_recursive_absolute(directory)
	return image.save_png(directory.path_join(filename)) == OK


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
