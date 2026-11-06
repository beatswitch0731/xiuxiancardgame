extends SceneTree

const Registry = preload("res://scripts/runtime_data_registry.gd")
const Domain = preload("res://scripts/noncombat_domain.gd")
const RunSession = preload("res://scripts/noncombat_run_session.gd")
const OpeningScene = preload("res://scenes/noncombat_opening.tscn")
const OUT := "res://output/captures/godot-migration/first-body-battle/"


func _initialize() -> void:
	call_deferred("_capture")


func _capture() -> void:
	var save_path := "user://tests/first_body_capture_%d.json" % Time.get_ticks_usec()
	var game = Domain.new(Registry.new(), RunSession.new(save_path))
	if not game.start("body"):
		return _fail("body route start failed")
	for direction in ["right", "right", "left", "left", "left"]:
		if not game.choose(direction, game.issue_choice_token()):
			return _fail("body route did not reach battle")
	root.size = Vector2i(1280, 800)
	var story: Control = OpeningScene.instantiate()
	story.save_path = save_path
	root.add_child(story)
	for _frame in range(6):
		await process_frame
	var launch: Button = story.find_child("LaunchBattle", true, false)
	if launch == null:
		return _fail("body battle launch unavailable")
	launch.pressed.emit()
	for _frame in range(6):
		await process_frame
	if story.active_battle == null or not story.active_battle.stage_assets_ready:
		return _fail("body source stage did not load")
	if not await _save("body_1280_idle.png"):
		return _fail("1280 screenshot failed")
	root.size = Vector2i(1920, 1080)
	for _frame in range(5):
		await process_frame
	if not await _save("body_1920_idle.png"):
		return _fail("1920 screenshot failed")
	root.size = Vector2i(1280, 800)
	for _frame in range(4):
		await process_frame
	var battle: Control = story.active_battle
	var contacts: Array[String] = []
	battle.duel_stage.contact_frame.connect(func(side: String) -> void:
		contacts.append(side))
	var index: int = battle.combat.state.get("hand", []).find("body_fist")
	if index < 0 or not battle.combat.play_card(index):
		return _fail("body source attack could not start")
	for _frame in range(80):
		if "player" in contacts:
			break
		await create_timer(0.02).timeout
	if not "player" in contacts or not await _save("body_1280_contact.png"):
		return _fail("body contact frame not captured")
	print("FIRST_BODY_BATTLE_CAPTURE_PASS resolutions=2 source_stage=true contact=true")
	quit(0)


func _save(filename: String) -> bool:
	for _frame in range(3):
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
