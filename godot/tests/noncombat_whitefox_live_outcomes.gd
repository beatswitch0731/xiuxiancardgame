extends SceneTree

const Registry = preload("res://scripts/runtime_data_registry.gd")
const Domain = preload("res://scripts/noncombat_domain.gd")
const RunSession = preload("res://scripts/noncombat_run_session.gd")
const OpeningScene = preload("res://scenes/noncombat_opening.tscn")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	for path_id in ["pill", "sword"]:
		var wanted := "victory" if path_id == "pill" else "defeat"
		var save_path := "user://tests/whitefox_live_%s_%d.json" % [
			wanted, Time.get_ticks_usec()]
		var game = Domain.new(Registry.new(), RunSession.new(save_path))
		if not game.start(path_id):
			return _fail(path_id + " whitefox route could not start")
		for _choice in range(5):
			if not game.choose("left", game.issue_choice_token()):
				return _fail(path_id + " tutorial route failed")
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
			return _fail(path_id + " natural whitefox pending battle failed")
		var request: Dictionary = game.battle_request()
		var saved: PackedByteArray = FileAccess.get_file_as_bytes(game._store.v2_path)
		var story: Control = OpeningScene.instantiate()
		story.save_path = save_path
		root.add_child(story)
		await process_frame
		var launch: Button = story.find_child("LaunchBattle", true, false)
		if launch == null or launch.disabled:
			return _fail(path_id + " source hound battle was not launchable")
		launch.pressed.emit()
		await process_frame
		var battle: Control = story.active_battle
		if battle == null or not battle.stage_assets_ready \
				or battle.combat.state.get("phase") != "PLAYER_TURN" \
				or FileAccess.get_file_as_bytes(game._store.v2_path) != saved:
			return _fail(path_id + " hound desktop stage changed pending owner")
		var terminal := await _win_with_pill_buttons(battle) if wanted == "victory" else (
			await _lose_with_turn_buttons(battle))
		if not terminal:
			return _fail(path_id + " hound real UI battle did not reach " + wanted)
		var result: Dictionary = battle.terminal_result()
		if result.get("outcome") != wanted or result.get("encounterId") != null \
				or result.get("sourceCardId") != request.get("sourceCardId"):
			return _fail(path_id + " real hound terminal receipt lost its source owner")
		battle._render()
		var return_button: Button = battle.get_node_or_null("ReturnToStory")
		if return_button == null or return_button.disabled or not return_button.visible:
			return _fail(path_id + " real terminal could not return to story")
		if wanted == "victory":
			story.opening_store.fail_promotion_once = true
			return_button.pressed.emit()
			await process_frame
			if story.active_battle != battle or story.opening.state.get("phase") != "BATTLE_PENDING" \
					or FileAccess.get_file_as_bytes(game._store.v2_path) != saved:
				return _fail("whitefox victory failed-save changed quest or pending bytes")
		return_button.pressed.emit()
		await process_frame
		var settled = Domain.new(Registry.new(), RunSession.new(save_path))
		if story.active_battle != null or not settled.restore() \
				or settled.submit_battle_result(result) \
				or (settled.state.get("questState", {}).get("questOutcomes", {}).get(
					"white_fox_line") == "completed") != (wanted == "victory"):
			return _fail(path_id + " real battle result did not settle quest once")
		story.queue_free()
		await process_frame
	print("NONCOMBAT_WHITEFOX_LIVE_OUTCOMES_PASS victory=true defeat=true desktop=true atomic=true replay=true")
	quit(0)


func _win_with_pill_buttons(battle: Control) -> bool:
	for _step in range(70):
		var phase := String(battle.combat.state.get("phase", ""))
		if phase == "VICTORY":
			return true
		if phase != "PLAYER_TURN":
			return false
		var card := _find_card(battle.hand_row,
			["pill_ember", "pill_catalyst", "pill_guard", "pill_recycle"])
		if card != null:
			card.pressed.emit()
			if not await _wait_presentations(battle):
				return false
			continue
		battle.end_button.pressed.emit()
		await process_frame
		if battle.combat.state.get("phase") != "REACTION_OPEN":
			return false
		var guard: Button = battle.reaction_buttons[2]
		var reaction: Button = guard if not guard.disabled else battle.reaction_buttons[0]
		reaction.pressed.emit()
		if not await _wait_presentations(battle):
			return false
	return false


func _lose_with_turn_buttons(battle: Control) -> bool:
	for _step in range(16):
		var phase := String(battle.combat.state.get("phase", ""))
		if phase == "DEFEAT":
			return true
		if phase != "PLAYER_TURN":
			return false
		battle.end_button.pressed.emit()
		await process_frame
		if battle.combat.state.get("phase") != "REACTION_OPEN":
			return false
		battle.reaction_buttons[0].pressed.emit()
		if not await _wait_presentations(battle):
			return false
	return false


func _find_card(hand: HBoxContainer, priority: Array) -> Button:
	for card_id in priority:
		for child in hand.get_children():
			if child is Button and not child.disabled \
					and child.get_meta("source_card_id", "") == card_id:
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
