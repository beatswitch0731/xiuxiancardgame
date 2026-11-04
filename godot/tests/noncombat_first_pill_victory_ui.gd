extends SceneTree

const Registry = preload("res://scripts/runtime_data_registry.gd")
const Domain = preload("res://scripts/noncombat_domain.gd")
const RunSession = preload("res://scripts/noncombat_run_session.gd")
const OpeningScene = preload("res://scenes/noncombat_opening.tscn")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var save_path := "user://tests/first_pill_victory_ui_%d.json" % Time.get_ticks_usec()
	var game = Domain.new(Registry.new(), RunSession.new(save_path))
	if not game.start("pill"):
		return _fail("pill route start failed")
	for direction in ["right", "right", "left", "left", "left"]:
		if not game.choose(direction, game.issue_choice_token()):
			return _fail("pill route did not reach source battle")
	var request: Dictionary = game.battle_request()
	var story: Control = OpeningScene.instantiate()
	story.save_path = save_path
	root.add_child(story)
	await process_frame
	var launch: Button = story.find_child("LaunchBattle", true, false)
	if launch == null:
		return _fail("pill source battle cannot launch")
	launch.pressed.emit()
	await process_frame
	var battle: Control = story.active_battle
	if battle == null or not battle.stage_assets_ready:
		return _fail("pill desktop battle did not load")
	var poison_win := false
	for _turn in range(5):
		if battle.combat.state.get("phase") == "VICTORY":
			break
		if battle.combat.state.get("phase") != "PLAYER_TURN":
			return _fail("pill battle left player turn unexpectedly")
		for card_id in ["pill_recycle", "pill_catalyst", "pill_ember", "pill_ember", "pill_ember", "pill_guard"]:
			var card_button: Button = _find_card(battle.hand_row, card_id)
			if card_button == null or card_button.disabled or \
					int(battle.combat.state.get("qi", 0)) < _cost(card_id):
				continue
			if card_id == "pill_ember" and int(battle.combat.state.get("enemy", {}).get("hp", 0)) <= 2:
				continue
			card_button.pressed.emit()
			if not await _wait_presentations(battle):
				return _fail("pill card presentation failed: " + card_id + " problem=" +
					battle.presentation_problem + " pending=" + str(battle.pending_presentations))
			if battle.combat.state.get("phase") == "VICTORY":
				break
		if battle.combat.state.get("phase") == "VICTORY":
			break
		if not battle.end_button.visible or battle.end_button.disabled:
			return _fail("pill end-turn button did not become available")
		battle.end_button.pressed.emit()
		await process_frame
		if battle.combat.state.get("phase") != "REACTION_OPEN" \
				or battle.reaction_buttons[0].disabled:
			return _fail("pill reaction button did not open")
		battle.reaction_buttons[0].pressed.emit()
		poison_win = battle.combat.state.get("phase") == "VICTORY"
		if not await _wait_presentations(battle):
			return _fail("pill enemy presentation did not finish")
		if battle.combat.state.get("phase") == "DEFEAT":
			return _fail("pill victory route lost before poison tick")
	if battle.combat.state.get("phase") != "VICTORY" or not poison_win:
		return _fail("pill desktop route did not win from poison")
	var terminal_audio: AudioStreamPlayer = battle.duel_stage.get_node_or_null("SourceActionSfx")
	if terminal_audio == null or terminal_audio.stream == null or \
			terminal_audio.stream.resource_path != \
			"res://content/assets/audio/sfx/world/get_treasure.mp3":
		return _fail("pill poison victory did not trigger source victory cue")
	var result: Dictionary = battle.terminal_result()
	var return_button: Button = battle.get_node_or_null("ReturnToStory")
	if result.get("outcome") != "victory" \
			or result.get("encounterInstanceId") != request.get("encounterInstanceId") \
			or return_button == null or not return_button.visible or return_button.disabled:
		return _fail("pill victory was not exposed in desktop UI")
	return_button.pressed.emit()
	await process_frame
	if story.active_battle != null or story.opening.state.get("phase") == "BATTLE_PENDING":
		return _fail("pill desktop victory did not return to story")
	var restored = Domain.new(Registry.new(), RunSession.new(save_path))
	if not restored.restore() or restored.submit_battle_result(result):
		return _fail("pill victory receipt did not persist exactly once")
	story.queue_free()
	for _frame in range(3):
		await process_frame
	print("NONCOMBAT_FIRST_PILL_VICTORY_UI_PASS terminal=true poison=", poison_win,
		" return=true receipt=true")
	quit(0)


func _cost(card_id: String) -> int:
	for card in Registry.new().read_json("data/cards/battle_cards.json").get("battle_cards", []):
		if card is Dictionary and card.get("id") == card_id:
			return int(card.get("cost", 0))
	return 99


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
