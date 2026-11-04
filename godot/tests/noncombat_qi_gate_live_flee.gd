extends "res://tests/noncombat_qi_gate_entry.gd"


func _run() -> void:
	var first: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	var second: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SECOND_FIXTURE))
	var third: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(THIRD_FIXTURE))
	var gate: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(GATE_FIXTURE))
	var flee_row: Dictionary = {}
	for row in gate.rows:
		if row.outcome == "flee" and row.warningDirection == "left":
			flee_row = row
			break
	if flee_row.is_empty():
		return _fail("source qi gate flee row missing")
	var file := "user://tests/qi_gate_live_flee_%d.json" % Time.get_ticks_usec()
	var game = Domain.new(Registry.new(), Session.new(file, "slot_2"), "slot_2")
	_quiet_ambient(game)
	if not _open_third_alt(game, first, second, third) or not _reach_gate(game):
		return _fail("qi gate natural flee prefix failed: " + _problem)
	if not game.choose("left", game.issue_choice_token()):
		return _fail("qi gate flee preparation failed")
	var pending = _cold(game, "qi gate flee pending")
	if pending == null:
		return _fail("qi gate flee pending cold restore failed: " + _problem)
	var story: Control = OpeningScene.instantiate()
	story.save_path = ""
	root.add_child(story)
	await process_frame
	story.opening = game
	story.slot_screen.visible = false
	story.name_screen.visible = false
	story.path_screen.visible = false
	story.story_screen.visible = true
	story._set_scene_surface(true)
	story._render()
	await process_frame
	var launch: Button = story.find_child("LaunchBattle", true, false)
	if launch == null or launch.disabled:
		return _fail("qi gate natural flee launch unavailable")
	launch.pressed.emit()
	await process_frame
	var battle: Control = story.active_battle
	if story.ambient_particles.visible or story.ambient_particles.is_processing():
		return _fail("source ambience kept drawing behind the live battle")
	var flee_button: Button = battle.get_node_or_null("FleeBattle") if battle else null
	if flee_button == null or not flee_button.visible or flee_button.disabled:
		return _fail("qi gate source flee button unavailable")
	flee_button.pressed.emit()
	await process_frame
	if battle.combat.state.get("phase") != "FLEE":
		return _fail("qi gate flee did not close live combat")
	var return_button: Button = battle.get_node_or_null("ReturnToStory")
	if return_button == null or not return_button.visible or return_button.disabled:
		return _fail("qi gate flee return button unavailable")
	return_button.pressed.emit()
	await process_frame
	if game.state.get("phase") != "BATTLE_RESULT_PENDING" \
			or game.state.get("realm") != "qi" \
			or game.get_current_card().get("id") != flee_row.resultCard.id \
			or not story.ambient_particles.visible \
			or not story.ambient_particles.is_processing():
		return _fail("qi gate flee did not return its source result card")
	if _cold(game, "qi gate flee result") == null:
		return _fail("qi gate flee result cold restore failed: " + _problem)
	var acknowledgement: Button = story.find_child("Choice_down", true, false)
	if acknowledgement == null or acknowledgement.disabled:
		return _fail("qi gate flee acknowledgement unavailable")
	acknowledgement.pressed.emit()
	await process_frame
	if game.state.get("phase") == "BATTLE_RESULT_PENDING" \
			or _cold(game, "qi gate flee acknowledged") == null:
		return _fail("qi gate flee acknowledgement did not persist")
	story.queue_free()
	await process_frame
	print("NONCOMBAT_QI_GATE_LIVE_FLEE_PASS public=true desktop=true replay=true")
	quit(0)
