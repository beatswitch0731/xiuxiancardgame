extends SceneTree

const Registry = preload("res://scripts/runtime_data_registry.gd")
const Domain = preload("res://scripts/noncombat_domain.gd")
const RunSession = preload("res://scripts/noncombat_run_session.gd")
const OpeningScene = preload("res://scenes/noncombat_opening.tscn")
const OUT := "res://../artifacts/godot-migration/mountain-live-battle/"


func _initialize() -> void:
	call_deferred("_capture")


func _capture() -> void:
	var save_path := "user://tests/mountain_capture_%d.json" % Time.get_ticks_usec()
	var game = Domain.new(Registry.new(), RunSession.new(save_path))
	if not game.start("sword"):
		return _fail("mountain capture opening failed")
	for direction in ["right", "right", "left", "left", "left"]:
		if not game.choose(direction, game.issue_choice_token()):
			return _fail("mountain capture first battle route failed")
	var first: Dictionary = game.battle_request()
	var result := {"contractVersion": 2, "encounterInstanceId": first.encounterInstanceId,
		"sourceCardId": first.sourceCardId, "encounterId": first.encounterId,
		"sourceContentHash": first.sourceContentHash, "outcome": "victory",
		"combatReceipt": "combat:" + String(first.encounterInstanceId),
		"postBattleState": {"encounterInstanceId": first.encounterInstanceId,
			"terminal": true, "combatPhase": "VICTORY"}}
	if not game.submit_battle_result(result) or not game.choose("left", game.issue_choice_token()):
		return _fail("mountain capture first reward failed")
	if game.state.phase == "FLOW_PENDING" and not game.resume_flow():
		return _fail("mountain capture flow failed")
	if game.state.phase == "MILESTONE_PENDING" and not game.choose("left", game.issue_choice_token()):
		return _fail("mountain capture milestone failed")
	if game.state.currentCardId != "q_mountain_shadow_approach" \
			or not game.choose("left", game.issue_choice_token()) \
			or not game.choose("left", game.issue_choice_token()):
		return _fail("mountain capture warning failed")
	root.size = Vector2i(1280, 800)
	var story: Control = OpeningScene.instantiate()
	story.save_path = save_path
	root.add_child(story)
	for _frame in range(6):
		await process_frame
	var launch: Button = story.find_child("LaunchBattle", true, false)
	if launch == null:
		return _fail("mountain capture launch unavailable")
	launch.pressed.emit()
	for _frame in range(6):
		await process_frame
	if story.active_battle == null or not story.active_battle.stage_assets_ready:
		return _fail("mountain capture source stage did not load")
	if not await _save("mountain_1280_idle.png"):
		return _fail("1280 screenshot failed")
	root.size = Vector2i(1920, 1080)
	for _frame in range(5):
		await process_frame
	if not await _save("mountain_1920_idle.png"):
		return _fail("1920 screenshot failed")
	root.size = Vector2i(1280, 800)
	for _frame in range(4):
		await process_frame
	var battle: Control = story.active_battle
	var contacts: Array[String] = []
	battle.duel_stage.contact_frame.connect(func(side: String) -> void:
		contacts.append(side))
	var attack: Button = null
	for child in battle.hand_row.get_children():
		if child is Button and not child.disabled and child.get_meta("source_card_id", "") in [
				"sword_probe", "sword_edge", "sword_followthrough"]:
			attack = child
			break
	if attack == null:
		return _fail("mountain capture no attack card")
	attack.pressed.emit()
	for _frame in range(80):
		if "player" in contacts:
			break
		await create_timer(0.02).timeout
	if not "player" in contacts or not await _save("mountain_1280_contact.png"):
		return _fail("mountain contact frame not captured")
	story.queue_free()
	await process_frame
	for path_id in ["spell", "body", "pill"]:
		if not await _capture_other_path(path_id):
			return _fail(path_id + " mountain source identity capture failed")
	print("MOUNTAIN_BATTLE_CAPTURE_PASS paths=4 resolutions=2 source_stage=true contact=true")
	quit(0)


func _capture_other_path(path_id: String) -> bool:
	var save_path := "user://tests/mountain_capture_%s_%d.json" % [path_id,
		Time.get_ticks_usec()]
	var game = Domain.new(Registry.new(), RunSession.new(save_path))
	if not game.start(path_id):
		return false
	for direction in ["right", "right", "left", "left", "left"]:
		if not game.choose(direction, game.issue_choice_token()):
			return false
	var first: Dictionary = game.battle_request()
	var result := {"contractVersion": 2, "encounterInstanceId": first.encounterInstanceId,
		"sourceCardId": first.sourceCardId, "encounterId": first.encounterId,
		"sourceContentHash": first.sourceContentHash, "outcome": "victory",
		"combatReceipt": "combat:" + String(first.encounterInstanceId),
		"postBattleState": {"encounterInstanceId": first.encounterInstanceId,
			"terminal": true, "combatPhase": "VICTORY"}}
	if not game.submit_battle_result(result) or not game.choose("left", game.issue_choice_token()):
		return false
	if game.state.phase == "FLOW_PENDING" and not game.resume_flow():
		return false
	if game.state.phase == "MILESTONE_PENDING" \
			and not game.choose("left", game.issue_choice_token()):
		return false
	if game.state.currentCardId != "q_mountain_shadow_approach" \
			or not game.choose("left", game.issue_choice_token()) \
			or not game.choose("left", game.issue_choice_token()):
		return false
	root.size = Vector2i(1280, 800)
	var story: Control = OpeningScene.instantiate()
	story.save_path = save_path
	root.add_child(story)
	for _frame in range(6):
		await process_frame
	var launch: Button = story.find_child("LaunchBattle", true, false)
	if launch == null or launch.disabled:
		return false
	launch.pressed.emit()
	for _frame in range(6):
		await process_frame
	if story.active_battle == null or not story.active_battle.stage_assets_ready \
			or story.active_battle.combat.state.get("pathCombatState", {}).get(
				"archetypeId", "") == "":
		return false
	if not await _save("mountain_%s_1280_idle.png" % path_id):
		return false
	root.size = Vector2i(1920, 1080)
	for _frame in range(5):
		await process_frame
	if not await _save("mountain_%s_1920_idle.png" % path_id):
		return false
	story.queue_free()
	await process_frame
	return true


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
