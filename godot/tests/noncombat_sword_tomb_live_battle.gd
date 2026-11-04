extends "res://tests/noncombat_sword_tomb_entry.gd"

const OpeningScene = preload("res://scenes/noncombat_opening.tscn")


func _run() -> void:
	var path := "user://tests/sword_tomb_desktop_%d.json" % Time.get_ticks_usec()
	seed(1)
	var game = Domain.new(Registry.new(), RunSession.new(path))
	game._normal_roll_override = 0.0
	if not _reach_decision27(game) and game.state.is_empty():
		return _fail("sword tomb seeded desktop prefix could not start")
	var reached_tomb := false
	for _step in range(55):
		if game.state.get("phase") == "FLOW_PENDING":
			game._normal_roll_override = 0.46
			if not game.resume_flow():
				break
		elif game.state.get("phase") == "NORMAL_PENDING" \
				and game.get_current_card().get("id") == "q_swordTomb":
			reached_tomb = true
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
	if not reached_tomb:
		return _fail("sword tomb seeded desktop path stopped at " + JSON.stringify({
			"phase": game.state.get("phase"), "card": game.get_current_card().get("id")}))
	if not game.choose("left", game.issue_choice_token()) \
			or not _continue_to(game, "thread_sword_tomb_1") \
			or not game.choose("left", game.issue_choice_token()) \
			or not _continue_to(game, "thread_sword_tomb_2"):
		return _fail("seeded sword tomb did not reach its combat node")
	var second_bytes := FileAccess.get_file_as_bytes(game._store.v2_path)
	if not game.choose("left", game.issue_choice_token()) \
			or not game.choose("left", game.issue_choice_token()) \
			or game.state.get("phase") != "BATTLE_PENDING":
		return _fail("seeded sword tomb did not persist its left pending battle")
	var request: Dictionary = game.battle_request()
	var pending_bytes := FileAccess.get_file_as_bytes(game._store.v2_path)
	var story: Control = OpeningScene.instantiate()
	story.save_path = path
	root.add_child(story)
	await process_frame
	if not _same_value(story.opening.state, game.state):
		return _fail("sword tomb desktop did not automatically restore battle")
	var launch: Button = story.find_child("LaunchBattle", true, false)
	if launch == null or launch.disabled:
		return _fail("sword tomb desktop launch unavailable")
	launch.pressed.emit()
	await process_frame
	var battle: Control = story.active_battle
	var visual: Dictionary = request.get("pendingResolution", {}).get(
		"combatCard", {}).get("combatPresentation", {})
	var registry = Registry.new()
	if battle == null or not battle.stage_assets_ready or battle.duel_stage == null \
			or battle.duel_stage.get_script().resource_path != \
				"res://scripts/duel_stage_sword_tomb_2d.gd" \
			or FileAccess.get_file_as_bytes(game._store.v2_path) != pending_bytes:
		return _fail("sword tomb desktop did not mount an authenticated source stage")
	var field: TextureRect = battle.duel_stage.find_child("SourceBattlefield", true, false)
	var enemy: TextureRect = battle.duel_stage.find_child("SourceEnemy", true, false)
	if field == null or enemy == null \
			or field.texture != registry.texture_for(visual.get("sceneImage", "")) \
			or enemy.texture != registry.texture_for(visual.get(
				"actorCards", {}).get("enemy", {}).get("image", "")) \
			or battle.combat.state.get("enemyIntent", {}).get("type") != "buff":
		return _fail("sword tomb desktop field, enemy or opening intent differed")
	var left_actions: Array = []
	battle.duel_stage.action_started.connect(func(side: String, clip: String) -> void:
		left_actions.append({"side": side, "clip": clip}))
	battle.end_button.pressed.emit()
	await process_frame
	if battle.combat.state.get("phase") != "REACTION_OPEN" \
			or battle.reaction_buttons[0].disabled:
		return _fail("sword tomb desktop reaction did not open")
	battle.reaction_buttons[0].pressed.emit()
	if not await _saw_enemy_frame(battle, registry.texture_for(visual.get(
			"actorCards", {}).get("enemy", {}).get("intentFrames", {}).get("buff", ""))) \
			or not await _wait_presentations(battle) \
			or not left_actions.has({"side": "enemy", "clip": "buff"}) \
			or battle.combat.state.get("enemyStatus", {}).get("sword_intent") != 1:
		return _fail("sword tomb desktop buff lost its authored action frame or rule")
	var flee_button: Button = battle.get_node_or_null("FleeBattle")
	if flee_button == null or flee_button.disabled:
		return _fail("sword tomb desktop retreat unavailable")
	flee_button.pressed.emit()
	var result: Dictionary = battle.terminal_result()
	var return_button: Button = battle.get_node_or_null("ReturnToStory")
	if result.get("outcome") != "flee" or return_button == null \
			or return_button.disabled:
		return _fail("sword tomb retreat did not yield a returnable result")
	return_button.pressed.emit()
	await process_frame
	var settled = Domain.new(Registry.new(), RunSession.new(path))
	if story.active_battle != null or not settled.restore() \
			or settled.get_current_card().get("id") != "combat_fled_thread_sword_tomb_2" \
			or settled.submit_battle_result(result):
		return _fail("sword tomb desktop retreat did not cold settle exactly once")
	story.queue_free()
	await process_frame
	var right_path := "user://tests/sword_tomb_desktop_right_%d.json" % Time.get_ticks_usec()
	var right_store = RunSession.new(right_path)
	var right_file := FileAccess.open(right_store.v2_path, FileAccess.WRITE)
	if right_file == null:
		return _fail("sword tomb right branch could not fork")
	right_file.store_buffer(second_bytes)
	right_file.close()
	var right_game = Domain.new(Registry.new(), right_store)
	if not right_game.restore() \
			or not right_game.choose("right", right_game.issue_choice_token()) \
			or not right_game.choose("left", right_game.issue_choice_token()) \
			or right_game.state.get("phase") != "BATTLE_PENDING":
		return _fail("sword tomb right branch did not persist a real battle")
	var right_story: Control = OpeningScene.instantiate()
	right_story.save_path = right_path
	root.add_child(right_story)
	await process_frame
	if not _same_value(right_story.opening.state, right_game.state):
		return _fail("sword tomb right desktop did not cold restore")
	var right_launch: Button = right_story.find_child("LaunchBattle", true, false)
	if right_launch == null or right_launch.disabled:
		return _fail("sword tomb right desktop launch unavailable")
	right_launch.pressed.emit()
	await process_frame
	var right_battle: Control = right_story.active_battle
	var right_visual: Dictionary = right_game.battle_request().get(
		"pendingResolution", {}).get("combatCard", {}).get("combatPresentation", {})
	if right_battle == null or not right_battle.stage_assets_ready \
			or right_battle.duel_stage.get_script().resource_path != \
				"res://scripts/duel_stage_sword_tomb_2d.gd":
		return _fail("sword tomb right desktop mounted the wrong stage")
	var right_actions: Array = []
	right_battle.duel_stage.action_started.connect(func(side: String, clip: String) -> void:
		right_actions.append({"side": side, "clip": clip}))
	for _turn in range(6):
		if right_battle.combat.state.get("phase") == "DEFEAT":
			break
		if right_battle.combat.state.get("phase") != "PLAYER_TURN":
			return _fail("sword tomb right no-card turn did not reach the foe")
		var intent: Dictionary = right_battle.combat.state.get("enemyIntent", {})
		right_battle.end_button.pressed.emit()
		await process_frame
		if right_battle.combat.state.get("phase") != "REACTION_OPEN" \
				or right_battle.reaction_buttons[0].disabled:
			return _fail("sword tomb right reaction did not open")
		right_battle.reaction_buttons[0].pressed.emit()
		if not await _saw_enemy_frame(right_battle, registry.texture_for(
				right_visual.get("actorCards", {}).get("enemy", {}).get(
					"intentFrames", {}).get(intent.get("type", ""), ""))) \
				or not await _wait_presentations(right_battle) \
				or not right_actions.has({"side": "enemy",
					"clip": intent.get("type", "")}):
			return _fail("sword tomb right enemy action lost its authored frame")
	if right_battle.combat.state.get("phase") != "DEFEAT":
		return _fail("sword tomb right no-card route did not reach real defeat")
	var right_result: Dictionary = right_battle.terminal_result()
	var right_return: Button = right_battle.get_node_or_null("ReturnToStory")
	if right_result.get("outcome") != "defeat" or right_return == null \
			or right_return.disabled:
		return _fail("sword tomb right defeat did not yield a returnable result")
	right_return.pressed.emit()
	await process_frame
	var right_settled = Domain.new(Registry.new(), right_store)
	if right_story.active_battle != null or not right_settled.restore() \
			or right_settled.get_current_card().get("id") != \
				"combat_defeat_thread_sword_tomb_2" \
			or right_settled.submit_battle_result(right_result):
		return _fail("sword tomb right defeat did not cold settle exactly once")
	right_story.queue_free()
	await process_frame
	print("NONCOMBAT_SWORD_TOMB_LIVE_BATTLE_PASS desktop=true flee=true defeat=true buff=true replay=true")
	quit(0)


func _saw_enemy_frame(battle: Control, authored_frame: Texture2D) -> bool:
	if authored_frame == null:
		return false
	for _frame in range(40):
		await create_timer(0.02).timeout
		var enemy: TextureRect = battle.duel_stage.find_child("SourceEnemy", true, false)
		if enemy != null and enemy.texture == authored_frame:
			return true
	return false


func _wait_presentations(battle: Control) -> bool:
	for _frame in range(150):
		await create_timer(0.05).timeout
		if battle.pending_presentations == 0 and not battle.combat.input_locked:
			return battle.presentation_problem.is_empty()
	return false
