extends SceneTree

const Registry = preload("res://scripts/runtime_data_registry.gd")
const Domain = preload("res://scripts/noncombat_domain.gd")
const RunSession = preload("res://scripts/noncombat_run_session.gd")
const OpeningScene = preload("res://scenes/noncombat_opening.tscn")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var save_path := "user://tests/two_battle_pill_%d.json" % Time.get_ticks_usec()
	var game = Domain.new(Registry.new(), RunSession.new(save_path))
	if not game.start("pill"):
		return _fail("pill opening failed")
	for direction in ["right", "right", "left", "left", "left"]:
		if not game.choose(direction, game.issue_choice_token()):
			return _fail("pill route did not reach first persisted battle")
	var first_request: Dictionary = game.battle_request()
	var story: Control = OpeningScene.instantiate()
	story.save_path = save_path
	root.add_child(story)
	await process_frame
	var first = await _launch(story)
	if first == null or first.combat.state.get("encounterId") != first_request.get("encounterId"):
		return _fail("first desktop encounter did not use its saved owner")
	if not await _win_first_pill(first):
		return _fail("first pill encounter did not finish through its real buttons")
	var first_result: Dictionary = first.terminal_result()
	if first_result.get("outcome") != "victory" or not await _return(story, first):
		return _fail("first victory did not return to story")
	if not await _choose(story, "left"):
		return _fail("first battle reward choice was unavailable")
	for _frame in range(10):
		await process_frame
		if story.opening.state.get("phase") != "FLOW_PENDING":
			break
	if story.opening.state.get("phase") == "MILESTONE_PENDING" \
				and not await _choose(story, "left"):
		return _fail("postbattle milestone choice was unavailable")
	if story.opening.state.get("currentCardId") != "q_mountain_shadow_approach" \
			or not await _choose(story, "left") or not await _choose(story, "left"):
		return _fail("story UI did not offer mountain challenge and warning")
	var second_request: Dictionary = story.opening.battle_request()
	if second_request.get("sourceCardId") != "q_mountain_shadow_approach" \
			or second_request.get("encounterInstanceId") == first_request.get("encounterInstanceId"):
		return _fail("second battle did not own a distinct mountain request")
	var second = await _launch(story)
	if second == null or second.combat.state.get("encounterId") != \
			"enc_patrol_qi_mountain_shadow":
		return _fail("second desktop encounter did not open its source stage")
	var ember: Button = _find_card(second.hand_row, "pill_ember")
	if ember == null or ember.disabled:
		return _fail("current mountain deck did not expose pill ember")
	ember.pressed.emit()
	if not await _wait_presentations(second) or second.combat.state.get("phase") != "VICTORY":
		return _fail("second desktop card did not defeat balanced mountain foe")
	var second_result: Dictionary = second.terminal_result()
	if second_result.get("outcome") != "victory" or not await _return(story, second):
		return _fail("second victory did not return to story")
	var restored = Domain.new(Registry.new(), RunSession.new(save_path))
	if not restored.restore() or restored.state.get("phase") == "BATTLE_PENDING" \
			or restored.submit_battle_result(first_result) \
			or restored.submit_battle_result(second_result):
		return _fail("two battle outcomes were not durable and single use")
	story.queue_free()
	await process_frame
	print("NONCOMBAT_TWO_BATTLE_PILL_UI_PASS first=true story_choices=true mountain=true victories=2 durable=true")
	quit(0)


func _launch(story: Control) -> Control:
	var launch: Button = story.choice_row.get_node_or_null("LaunchBattle")
	if launch == null or launch.disabled:
		return null
	launch.pressed.emit()
	await process_frame
	var battle: Control = story.active_battle
	return battle if battle != null and battle.stage_assets_ready else null


func _return(story: Control, battle: Control) -> bool:
	var button: Button = battle.get_node_or_null("ReturnToStory")
	if button == null or button.disabled or not button.visible:
		return false
	button.pressed.emit()
	await process_frame
	return story.active_battle == null and story.opening.state.get("phase") != "BATTLE_PENDING"


func _choose(story: Control, direction: String) -> bool:
	var button: Button = story.choice_row.get_node_or_null("Choice_" + direction)
	if button == null or button.disabled:
		return false
	var before := int(story.opening.state.get("turn", -1))
	button.pressed.emit()
	await process_frame
	return int(story.opening.state.get("turn", -1)) != before \
		or story.opening.state.get("phase") in ["WARNING_PENDING", "BATTLE_PENDING"]


func _win_first_pill(battle: Control) -> bool:
	for _turn in range(5):
		if battle.combat.state.get("phase") == "VICTORY":
			break
		if battle.combat.state.get("phase") != "PLAYER_TURN":
			return false
		for card_id in ["pill_recycle", "pill_catalyst", "pill_ember", "pill_ember",
				"pill_ember", "pill_guard"]:
			var button: Button = _find_card(battle.hand_row, card_id)
			if button == null or button.disabled:
				continue
			if card_id == "pill_ember" and int(battle.combat.state["enemy"]["hp"]) <= 2:
				continue
			button.pressed.emit()
			if not await _wait_presentations(battle):
				return false
			if battle.combat.state.get("phase") == "VICTORY":
				break
		if battle.combat.state.get("phase") == "VICTORY":
			break
		if battle.end_button.disabled:
			return false
		battle.end_button.pressed.emit()
		await process_frame
		if battle.combat.state.get("phase") != "REACTION_OPEN" \
				or battle.reaction_buttons[0].disabled:
			return false
		battle.reaction_buttons[0].pressed.emit()
		if not await _wait_presentations(battle):
			return false
	return battle.combat.state.get("phase") == "VICTORY"


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
