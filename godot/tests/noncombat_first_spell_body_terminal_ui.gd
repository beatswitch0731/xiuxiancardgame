extends SceneTree

const Registry = preload("res://scripts/runtime_data_registry.gd")
const Domain = preload("res://scripts/noncombat_domain.gd")
const RunSession = preload("res://scripts/noncombat_run_session.gd")
const OpeningScene = preload("res://scenes/noncombat_opening.tscn")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	for path_id in ["spell", "body"]:
		for outcome in ["victory", "defeat"]:
			var result: String = await _case(path_id, outcome)
			if not result.is_empty():
				return _fail(result)
	print("NONCOMBAT_FIRST_SPELL_BODY_TERMINAL_UI_PASS paths=2 victory=true defeat=true return=true receipt=true")
	quit(0)


func _case(path_id: String, wanted: String) -> String:
	var save_path := "user://tests/%s_%s_terminal_%d.json" % [path_id, wanted, Time.get_ticks_usec()]
	var game = Domain.new(Registry.new(), RunSession.new(save_path))
	if not game.start(path_id):
		return path_id + " route failed to start"
	for direction in ["right", "right", "left", "left", "left"]:
		if not game.choose(direction, game.issue_choice_token()):
			return path_id + " route could not reach first battle"
	var request: Dictionary = game.battle_request()
	var story: Control = OpeningScene.instantiate()
	story.save_path = save_path
	root.add_child(story)
	await process_frame
	var launch: Button = story.find_child("LaunchBattle", true, false)
	if launch == null:
		return path_id + " LaunchBattle missing"
	launch.pressed.emit()
	await process_frame
	var battle: Control = story.active_battle
	if battle == null or not battle.stage_assets_ready:
		return path_id + " first battle did not open"
	for _turn in range(8):
		if battle.combat.state.get("phase") in ["VICTORY", "DEFEAT"]:
			break
		if battle.combat.state.get("phase") != "PLAYER_TURN":
			return path_id + " left player turn unexpectedly"
		if wanted == "victory":
			var action_plan: Array = [["spell_ward"], ["spell_spark"], ["spell_cycle"]] \
				if path_id == "spell" else [["body_stance"], ["body_stance", "body_fist", "body_counter"],
					["body_fist", "body_counter"]]
			for priority in action_plan:
				if int(battle.combat.state.get("qi", 0)) <= 0:
					break
				var card_button: Button = _find_card(battle.hand_row, priority)
				if card_button == null:
					break
				card_button.pressed.emit()
				if not await _wait_presentations(battle):
					return path_id + " card animation did not finish: " + battle.presentation_problem
				if battle.combat.state.get("phase") == "VICTORY":
					break
		else:
			var guard_button := _find_card(battle.hand_row,
				["spell_ward"] if path_id == "spell" else ["body_stance"])
			if guard_button == null:
				return path_id + " defeat route could not expose attack intent"
			guard_button.pressed.emit()
			if not await _wait_presentations(battle):
				return path_id + " defeat setup animation did not finish"
		if battle.combat.state.get("phase") in ["VICTORY", "DEFEAT"]:
			break
		if not battle.end_button.visible or battle.end_button.disabled:
			return path_id + " end-turn button unavailable"
		battle.end_button.pressed.emit()
		await process_frame
		if battle.combat.state.get("phase") != "REACTION_OPEN" or battle.reaction_buttons[0].disabled:
			return path_id + " reaction button unavailable"
		var reaction_index := 2 if wanted == "victory" and \
			battle.combat.state.get("enemyIntent", {}).get("type") == "attack" and \
			int(battle.combat.state.get("qi", 0)) >= 1 and \
			not battle.reaction_buttons[2].disabled else 0
		battle.reaction_buttons[reaction_index].pressed.emit()
		if not await _wait_presentations(battle):
			return path_id + " enemy animation did not finish: " + battle.presentation_problem
	if battle.combat.state.get("phase") != wanted.to_upper():
		return path_id + " desktop " + wanted + " failed: phase=" + \
			str(battle.combat.state.get("phase")) + " hp=" + \
			str(battle.combat.state.get("player", {}).get("hp")) + " enemy=" + \
			str(battle.combat.state.get("enemy", {}).get("hp"))
	var result: Dictionary = battle.terminal_result()
	var return_button: Button = battle.get_node_or_null("ReturnToStory")
	if result.get("outcome") != wanted or result.get("encounterInstanceId") != \
			request.get("encounterInstanceId") or return_button == null or \
			not return_button.visible or return_button.disabled:
		return path_id + " terminal result/return button missing"
	return_button.pressed.emit()
	await process_frame
	if story.active_battle != null or story.opening.state.get("phase") == "BATTLE_PENDING":
		return path_id + " terminal did not return to story"
	var restored = Domain.new(Registry.new(), RunSession.new(save_path))
	if not restored.restore() or restored.submit_battle_result(result):
		return path_id + " terminal receipt was not durable/unique"
	story.queue_free()
	for _frame in range(3):
		await process_frame
	return ""


func _find_card(hand: HBoxContainer, priority: Array) -> Button:
	for card_id in priority:
		for child in hand.get_children():
			if child is Button and not child.disabled and \
					child.get_meta("source_card_id", "") == card_id:
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
