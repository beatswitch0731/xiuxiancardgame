extends SceneTree

const Registry = preload("res://scripts/runtime_data_registry.gd")
const Domain = preload("res://scripts/noncombat_domain.gd")
const RunSession = preload("res://scripts/noncombat_run_session.gd")
const OpeningScene = preload("res://scenes/noncombat_opening.tscn")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var save_path := "user://tests/first_pill_defeat_ui_%d.json" % Time.get_ticks_usec()
	var game = Domain.new(Registry.new(), RunSession.new(save_path))
	if not game.start("pill"):
		return _fail("pill route could not start")
	for direction in ["right", "right", "left", "left", "left"]:
		if not game.choose(direction, game.issue_choice_token()):
			return _fail("pill route could not reach first battle")
	var request: Dictionary = game.battle_request()
	var story: Control = OpeningScene.instantiate()
	story.save_path = save_path
	root.add_child(story)
	await process_frame
	var launch: Button = story.find_child("LaunchBattle", true, false)
	if launch == null:
		return _fail("pill LaunchBattle unavailable")
	launch.pressed.emit()
	await process_frame
	var battle: Control = story.active_battle
	if battle == null or not battle.stage_assets_ready:
		return _fail("pill source stage did not open")
	for _turn in range(5):
		if battle.combat.state.get("phase") == "DEFEAT":
			break
		if battle.combat.state.get("phase") != "PLAYER_TURN":
			return _fail("pill defeat route left player turn")
		var ember: Button = _find_card(battle.hand_row, "pill_ember")
		if ember == null or ember.disabled:
			return _fail("pill defeat route could not expose attack intent")
		ember.pressed.emit()
		if not await _wait_presentations(battle):
			return _fail("pill ember presentation did not finish")
		if not battle.end_button.visible or battle.end_button.disabled:
			return _fail("pill end-turn button unavailable")
		battle.end_button.pressed.emit()
		await process_frame
		if battle.combat.state.get("phase") != "REACTION_OPEN" or \
				battle.reaction_buttons[0].disabled:
			return _fail("pill reaction button unavailable")
		battle.reaction_buttons[0].pressed.emit()
		if not await _wait_presentations(battle):
			return _fail("pill enemy presentation did not finish")
	if battle.combat.state.get("phase") != "DEFEAT":
		return _fail("pill UI did not reach defeat: " + str(battle.combat.state.get("phase")))
	var defeat_audio: AudioStreamPlayer = battle.duel_stage.get_node_or_null("SourceActionSfx")
	if defeat_audio == null or defeat_audio.stream == null or defeat_audio.stream.resource_path != \
			"res://content/assets/audio/sfx/combat/heart_beat.mp3":
		return _fail("pill defeat did not play source heartbeat cue")
	var result: Dictionary = battle.terminal_result()
	var return_button: Button = battle.get_node_or_null("ReturnToStory")
	if result.get("outcome") != "defeat" or result.get("encounterInstanceId") != \
			request.get("encounterInstanceId") or return_button == null or \
			not return_button.visible or return_button.disabled:
		return _fail("pill defeat result/return button missing")
	return_button.pressed.emit()
	await process_frame
	if story.active_battle != null or story.opening.state.get("phase") == "BATTLE_PENDING":
		return _fail("pill defeat did not return to story")
	var restored = Domain.new(Registry.new(), RunSession.new(save_path))
	if not restored.restore() or restored.submit_battle_result(result):
		return _fail("pill defeat receipt did not persist exactly once")
	story.queue_free()
	for _frame in range(3):
		await process_frame
	print("NONCOMBAT_FIRST_PILL_DEFEAT_UI_PASS card_button=true defeat=true return=true receipt=true")
	quit(0)


func _find_card(hand: HBoxContainer, card_id: String) -> Button:
	for child in hand.get_children():
		if child is Button and child.get_meta("source_card_id", "") == card_id:
			return child as Button
	return null


func _wait_presentations(battle: Control) -> bool:
	for _frame in range(150):
		await create_timer(0.05).timeout
		if battle.pending_presentations == 0 and not battle.combat.input_locked:
			return battle.presentation_problem.is_empty()
	return false


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
