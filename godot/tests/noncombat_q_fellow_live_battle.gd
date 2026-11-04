extends "res://tests/noncombat_q_fellow_entry.gd"

const OpeningScene = preload("res://scenes/noncombat_opening.tscn")


func _run() -> void:
	var path := "user://tests/q_fellow_desktop_%d.json" % Time.get_ticks_usec()
	seed(1)
	var game = Domain.new(Registry.new(), RunSession.new(path))
	game._normal_roll_override = 0.0
	if not _reach_decision27(game) and game.state.is_empty():
		return _fail("q_fellow seeded desktop prefix could not start")
	var reached_fellow := false
	for _step in range(50):
		if game.state.get("phase") == "FLOW_PENDING":
			game._normal_roll_override = 0.18
			if not game.resume_flow():
				break
		elif game.state.get("phase") == "NORMAL_PENDING" \
				and game.get_current_card().get("id") == "q_fellow":
			reached_fellow = true
			break
		elif game.state.get("phase") in ["MARKET_PENDING", "COMBAT_HANDOFF"]:
			if not game.choose("right", game.issue_choice_token()):
				break
		elif game.state.get("phase") in ["DESTINY_WHEEL_PENDING", "MILESTONE_PENDING",
			"KARMA_PENDING", "MENTOR_PENDING", "NARRATIVE_RESULT_PENDING",
			"HINT_PENDING", "RIPPLE_PENDING", "NORMAL_PENDING"]:
			var direction := "left" if game.can_choose_direction("left") else "right"
			if not game.choose(direction, game.issue_choice_token()):
				break
		else:
			break
	if not reached_fellow:
		return _fail("q_fellow seeded desktop path stopped at " +
			JSON.stringify({"phase": game.state.get("phase"),
				"card": game.get_current_card().get("id"),
				"index": game.state.get("runClock", {}).get("decisionIndex")}))
	if not game.choose("right", game.issue_choice_token()) \
			or not game.choose("left", game.issue_choice_token()) \
			or game.state.get("phase") != "BATTLE_PENDING":
		return _fail("q_fellow desktop route did not save a natural battle")
	var request: Dictionary = game.battle_request()
	var saved: PackedByteArray = FileAccess.get_file_as_bytes(game._store.v2_path)
	var flee_path := "user://tests/q_fellow_desktop_flee_%d.json" % Time.get_ticks_usec()
	var flee_store = RunSession.new(flee_path)
	var flee_file := FileAccess.open(flee_store.v2_path, FileAccess.WRITE)
	if flee_file == null:
		return _fail("q_fellow pending battle could not branch for real desktop flee")
	flee_file.store_buffer(saved)
	flee_file.close()
	var story: Control = OpeningScene.instantiate()
	story.save_path = path
	root.add_child(story)
	await process_frame
	if not _same(story.opening.state, game.state):
		return _fail("q_fellow desktop did not automatically restore source pending save")
	var launch: Button = story.find_child("LaunchBattle", true, false)
	if launch == null or launch.disabled:
		return _fail("q_fellow restored desktop state did not offer its battle: " +
			story.status_label.text)
	launch.pressed.emit()
	await process_frame
	var battle: Control = story.active_battle
	var visual: Dictionary = request.get("pendingResolution", {}).get(
		"combatCard", {}).get("combatPresentation", {})
	var field: TextureRect = battle.duel_stage.find_child("SourceBattlefield", true, false) \
		if battle != null and battle.duel_stage != null else null
	var enemy: TextureRect = battle.duel_stage.find_child("SourceEnemy", true, false) \
		if battle != null and battle.duel_stage != null else null
	var registry = Registry.new()
	if battle == null or not battle.stage_assets_ready or field == null or enemy == null \
			or field.texture != registry.texture_for(visual.get("sceneImage", "")) \
			or enemy.texture != registry.texture_for(visual.get(
				"actorCards", {}).get("enemy", {}).get("image", "")) \
			or FileAccess.get_file_as_bytes(game._store.v2_path) != saved:
		return _fail("q_fellow desktop did not mount source terrace and opponent")
	for _turn in range(4):
		if battle.combat.state.get("phase") == "DEFEAT":
			break
		if battle.combat.state.get("phase") != "PLAYER_TURN":
			return _fail("q_fellow desktop turn stopped before its opponent acted")
		battle.end_button.pressed.emit()
		await process_frame
		if battle.combat.state.get("phase") != "REACTION_OPEN" \
				or battle.reaction_buttons[0].disabled:
			return _fail("q_fellow desktop reaction did not open")
		var acting_intent: Dictionary = battle.combat.state.get("enemyIntent", {}).duplicate(true)
		battle.reaction_buttons[0].pressed.emit()
		if acting_intent.get("type") == "attack" and not await _saw_attack_frame(
				battle, registry.texture_for(visual.get("actorCards", {}).get(
					"enemy", {}).get("intentFrames", {}).get("attack", ""))):
			return _fail("q_fellow desktop enemy attack lost its authored frame")
		if not await _wait_presentations(battle):
			return _fail("q_fellow desktop opponent action lacked its mounted frame")
	if battle.combat.state.get("phase") != "DEFEAT":
		return _fail("q_fellow desktop no-card route did not reach real defeat")
	var result: Dictionary = battle.terminal_result()
	if result.get("outcome") != "defeat" or result.get("encounterId") != null \
			or result.get("sourceCardId") != "q_fellow":
		return _fail("q_fellow desktop defeat receipt lost its inline owner")
	battle._render()
	var return_button: Button = battle.get_node_or_null("ReturnToStory")
	if return_button == null or return_button.disabled or not return_button.visible:
		return _fail("q_fellow desktop terminal could not return to story")
	return_button.pressed.emit()
	await process_frame
	var settled = Domain.new(Registry.new(), RunSession.new(path))
	if story.active_battle != null or not settled.restore() \
			or settled.get_current_card().get("id") != "combat_defeat_q_fellow" \
			or settled.submit_battle_result(result) \
			or FileAccess.get_file_as_bytes(game._store.v2_path) == saved:
		return _fail("q_fellow desktop defeat did not settle and cold restore once")
	story.queue_free()
	await process_frame
	var flee_story: Control = OpeningScene.instantiate()
	flee_story.save_path = flee_path
	root.add_child(flee_story)
	await process_frame
	if not _same(flee_story.opening.state, game.state):
		return _fail("q_fellow desktop flee branch did not automatically restore same owner")
	var flee_launch: Button = flee_story.find_child("LaunchBattle", true, false)
	if flee_launch == null or flee_launch.disabled:
		return _fail("q_fellow flee branch did not offer its saved fight")
	flee_launch.pressed.emit()
	await process_frame
	var flee_battle: Control = flee_story.active_battle
	var flee_button: Button = flee_battle.get_node_or_null("FleeBattle") if flee_battle != null else null
	if flee_battle == null or not flee_battle.stage_assets_ready \
			or flee_button == null or flee_button.disabled or not flee_button.visible:
		return _fail("q_fellow real desktop fight did not allow authored retreat")
	flee_button.pressed.emit()
	var flee_result: Dictionary = flee_battle.terminal_result()
	var flee_return: Button = flee_battle.get_node_or_null("ReturnToStory")
	if flee_result.get("outcome") != "flee" or flee_return == null \
			or flee_return.disabled or not flee_return.visible:
		return _fail("q_fellow retreat did not produce a returnable receipt")
	flee_return.pressed.emit()
	await process_frame
	var flee_settled = Domain.new(Registry.new(), flee_store)
	if flee_story.active_battle != null or not flee_settled.restore() \
			or flee_settled.get_current_card().get("id") != "combat_fled_q_fellow" \
			or flee_settled.submit_battle_result(flee_result):
		return _fail("q_fellow real retreat did not strictly settle once")
	flee_story.queue_free()
	await process_frame
	print("NONCOMBAT_Q_FELLOW_LIVE_BATTLE_PASS desktop=true source_art=true defeat=true flee=true replay=true")
	quit(0)


func _wait_presentations(battle: Control) -> bool:
	for _frame in range(150):
		await create_timer(0.05).timeout
		if battle.pending_presentations == 0 and not battle.combat.input_locked:
			return battle.presentation_problem.is_empty()
	return false


func _saw_attack_frame(battle: Control, authored_frame: Texture2D) -> bool:
	if authored_frame == null:
		return false
	for _frame in range(40):
		await create_timer(0.02).timeout
		var enemy: TextureRect = battle.duel_stage.find_child("SourceEnemy", true, false)
		if enemy != null and enemy.texture == authored_frame:
			return true
	return false
