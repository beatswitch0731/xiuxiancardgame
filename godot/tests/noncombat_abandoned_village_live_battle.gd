extends "res://tests/noncombat_abandoned_village_entry.gd"

const OpeningScene = preload("res://scenes/noncombat_opening.tscn")


func _run() -> void:
	var left_path := "user://tests/village_desktop_left_%d.json" % Time.get_ticks_usec()
	seed(1)
	var game = Domain.new(Registry.new(), RunSession.new(left_path))
	game._normal_roll_override = 0.0
	if not _reach_decision27(game) and game.state.is_empty():
		return _fail("village seeded desktop prefix could not start")
	var reached_beggar := false
	for _step in range(50):
		if game.state.get("phase") == "FLOW_PENDING":
			game._normal_roll_override = 0.12
			if not game.resume_flow():
				break
		elif game.state.get("phase") == "NORMAL_PENDING" \
				and game.get_current_card().get("id") == "q_beggar":
			reached_beggar = true
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
	if not reached_beggar:
		return _fail("village seeded desktop path stopped at " + JSON.stringify({
			"phase": game.state.get("phase"), "card": game.get_current_card().get("id")}))
	if not game.choose("right", game.issue_choice_token()):
		return _fail("seeded beggar gift failed")
	for node in ["thread_ab_village_1", "thread_ab_village_2", "thread_ab_village_3"]:
		if not _continue_to(game, node):
			return _fail("seeded village stopped before " + node + " at " +
				JSON.stringify({"phase": game.state.get("phase"),
					"card": game.get_current_card().get("id"),
					"index": game.state.get("runClock", {}).get("decisionIndex")}))
		if node != "thread_ab_village_3" and not game.choose(
				"right" if node == "thread_ab_village_1" else "left",
				game.issue_choice_token()):
			return _fail("seeded village choice failed at " + node)
	var right_path := "user://tests/village_desktop_right_%d.json" % Time.get_ticks_usec()
	var right_store = RunSession.new(right_path)
	var third_bytes := FileAccess.get_file_as_bytes(game._store.v2_path)
	var right_file := FileAccess.open(right_store.v2_path, FileAccess.WRITE)
	if right_file == null:
		return _fail("village third node could not branch")
	right_file.store_buffer(third_bytes)
	right_file.close()
	var right_game = Domain.new(Registry.new(), right_store)
	if not right_game.restore() \
			or not right_game.choose("right", right_game.issue_choice_token()) \
			or not right_game.choose("left", right_game.issue_choice_token()) \
			or right_game.state.get("phase") != "BATTLE_PENDING":
		return _fail("village right branch did not cold restore its real pending battle")
	if not game.choose("left", game.issue_choice_token()) \
			or not game.choose("left", game.issue_choice_token()) \
			or game.state.get("phase") != "BATTLE_PENDING":
		return _fail("village left branch did not persist its real pending battle")
	var request: Dictionary = game.battle_request()
	var pending_bytes := FileAccess.get_file_as_bytes(game._store.v2_path)
	var story: Control = OpeningScene.instantiate()
	story.save_path = left_path
	root.add_child(story)
	await process_frame
	if not _same(story.opening.state, game.state):
		return _fail("village desktop did not automatically restore left battle")
	var launch: Button = story.find_child("LaunchBattle", true, false)
	if launch == null or launch.disabled:
		return _fail("village left desktop battle launch unavailable")
	launch.pressed.emit()
	await process_frame
	var battle: Control = story.active_battle
	var visual: Dictionary = request.get("pendingResolution", {}).get(
		"combatCard", {}).get("combatPresentation", {})
	var registry = Registry.new()
	if not _source_stage_ready(battle, registry, visual) \
			or FileAccess.get_file_as_bytes(game._store.v2_path) != pending_bytes:
		return _fail("village desktop left stage lost authored field or opponent")
	for _turn in range(5):
		if battle.combat.state.get("phase") == "DEFEAT":
			break
		if battle.combat.state.get("phase") != "PLAYER_TURN":
			return _fail("village desktop turn did not reach the opponent")
		battle.end_button.pressed.emit()
		await process_frame
		if battle.combat.state.get("phase") != "REACTION_OPEN" \
				or battle.reaction_buttons[0].disabled:
			return _fail("village desktop reaction did not open")
		var intent: Dictionary = battle.combat.state.get("enemyIntent", {}).duplicate(true)
		battle.reaction_buttons[0].pressed.emit()
		var frame_name := "debuff" if intent.get("type") == "debuff" else "attack"
		if intent.get("type") == "attack" and not await _saw_enemy_frame(
				battle, registry.texture_for(visual.get("actorCards", {}).get(
					"enemy", {}).get("intentFrames", {}).get(frame_name, ""))):
			return _fail("village desktop enemy action lost its authored frame")
		if intent.get("type") == "debuff" and not await _saw_vfx_frame(
				battle, registry.texture_for(visual.get("vfx", {}).get("weak", {}).get(
					"frames", [""])[0]), registry.texture_for(visual.get(
					"actorCards", {}).get("enemy", {}).get("intentFrames", {}).get(
						"debuff", ""))):
			return _fail("village desktop enemy weak effect lost its source frames")
		if not await _wait_presentations(battle):
			return _fail("village desktop enemy presentation did not finish")
	if battle.combat.state.get("phase") != "DEFEAT":
		return _fail("village left no-card route did not reach real defeat")
	var result: Dictionary = battle.terminal_result()
	if result.get("outcome") != "defeat" or result.get("sourceCardId") != \
			"thread_ab_village_3" or result.get("encounterId") != null:
		return _fail("village defeat receipt lost its source owner")
	battle._render()
	var return_button: Button = battle.get_node_or_null("ReturnToStory")
	if return_button == null or return_button.disabled:
		return _fail("village defeated battle could not return")
	return_button.pressed.emit()
	await process_frame
	var settled = Domain.new(Registry.new(), RunSession.new(left_path))
	if story.active_battle != null or not settled.restore() \
			or settled.get_current_card().get("id") != "combat_defeat_thread_ab_village_3" \
			or settled.submit_battle_result(result):
		return _fail("village left defeat did not settle and cold restore once")
	story.queue_free()
	await process_frame
	var flee_story: Control = OpeningScene.instantiate()
	flee_story.save_path = right_path
	root.add_child(flee_story)
	await process_frame
	if not _same(flee_story.opening.state, right_game.state):
		return _fail("village right desktop battle did not automatically cold restore")
	var flee_launch: Button = flee_story.find_child("LaunchBattle", true, false)
	if flee_launch == null or flee_launch.disabled:
		return _fail("village right desktop launch unavailable")
	flee_launch.pressed.emit()
	await process_frame
	var flee_battle: Control = flee_story.active_battle
	var right_visual: Dictionary = right_game.battle_request().get(
		"pendingResolution", {}).get("combatCard", {}).get("combatPresentation", {})
	if not _source_stage_ready(flee_battle, registry, right_visual):
		return _fail("village desktop right stage did not mount its source battlefield")
	flee_battle.end_button.pressed.emit()
	await process_frame
	if flee_battle.combat.state.get("phase") != "REACTION_OPEN" \
			or flee_battle.combat.state.get("enemyIntent", {}).get("type") != "debuff":
		return _fail("village right branch did not expose the source weak intent")
	flee_battle.reaction_buttons[0].pressed.emit()
	if not await _saw_vfx_frame(flee_battle, registry.texture_for(
			right_visual.get("vfx", {}).get("weak", {}).get("frames", [""])[0]),
			registry.texture_for(right_visual.get("actorCards", {}).get("enemy", {}).get(
				"intentFrames", {}).get("debuff", ""))) \
			or not await _wait_presentations(flee_battle) \
			or flee_battle.combat.state.get("playerStatus", {}).get("weak") != 1:
		return _fail("village right branch lost its own source weak effect")
	var flee_button: Button = flee_battle.get_node_or_null("FleeBattle")
	if flee_button == null or flee_button.disabled:
		return _fail("village right battle retreat unavailable")
	flee_button.pressed.emit()
	var flee_result: Dictionary = flee_battle.terminal_result()
	var flee_return: Button = flee_battle.get_node_or_null("ReturnToStory")
	if flee_result.get("outcome") != "flee" or flee_return == null or flee_return.disabled:
		return _fail("village right retreat did not yield a returnable receipt")
	flee_return.pressed.emit()
	await process_frame
	var flee_settled = Domain.new(Registry.new(), right_store)
	if flee_story.active_battle != null or not flee_settled.restore() \
			or flee_settled.get_current_card().get("id") != "combat_fled_thread_ab_village_3" \
			or flee_settled.submit_battle_result(flee_result):
		return _fail("village right retreat did not settle and cold restore once")
	flee_story.queue_free()
	await process_frame
	print("NONCOMBAT_ABANDONED_VILLAGE_LIVE_BATTLE_PASS desktop=true branches=2 defeat=true flee=true replay=true")
	quit(0)


func _source_stage_ready(battle: Control, registry: RefCounted,
		visual: Dictionary) -> bool:
	if battle == null or not battle.stage_assets_ready or battle.duel_stage == null:
		return false
	var field: TextureRect = battle.duel_stage.find_child("SourceBattlefield", true, false)
	var enemy: TextureRect = battle.duel_stage.find_child("SourceEnemy", true, false)
	return field != null and enemy != null \
		and field.texture == registry.texture_for(visual.get("sceneImage", "")) \
		and enemy.texture == registry.texture_for(visual.get(
			"actorCards", {}).get("enemy", {}).get("image", ""))


func _continue_to(game: RefCounted, target: String) -> bool:
	for _step in range(40):
		if game.state.get("phase") == "FLOW_PENDING" and not game.resume_flow():
			return false
		if game.get_current_card().get("id") == target:
			return true
		if game.state.get("phase") == "BATTLE_PENDING":
			var request: Dictionary = game.battle_request()
			var result := {"contractVersion": 2,
				"encounterInstanceId": request.get("encounterInstanceId"),
				"sourceCardId": request.get("sourceCardId"),
				"encounterId": request.get("encounterId"),
				"sourceContentHash": request.get("sourceContentHash"),
				"outcome": "victory",
				"combatReceipt": "combat:" + String(request.get("encounterInstanceId", "")),
				"postBattleState": {"encounterInstanceId": request.get("encounterInstanceId"),
					"terminal": true, "combatPhase": "VICTORY"}}
			if not game.submit_battle_result(result):
				return false
			continue
		if game.state.get("phase") == "VENDOR_OPEN":
			if not game.close_vendor(game.issue_choice_token()):
				return false
			continue
		var direction := ""
		if game.get_current_card().get("id") == "q_shop" and game.can_choose_direction("down"):
			direction = "down"
		elif game.state.get("phase") == "CAMP_PENDING" and game.can_choose_direction("up"):
			direction = "up"
		elif game.state.get("phase") in ["MARKET_PENDING", "COMBAT_HANDOFF"] \
				and game.can_choose_direction("right"):
			direction = "right"
		else:
			for candidate in ["left", "right", "down", "up"]:
				if game.can_choose_direction(candidate):
					direction = candidate
					break
		if direction.is_empty() or not game.choose(direction, game.issue_choice_token()):
			return false
	return false


func _wait_presentations(battle: Control) -> bool:
	for _frame in range(150):
		await create_timer(0.05).timeout
		if battle.pending_presentations == 0 and not battle.combat.input_locked:
			return battle.presentation_problem.is_empty()
	return false


func _saw_enemy_frame(battle: Control, authored_frame: Texture2D) -> bool:
	if authored_frame == null:
		return false
	for _frame in range(40):
		await create_timer(0.02).timeout
		var enemy: TextureRect = battle.duel_stage.find_child("SourceEnemy", true, false)
		if enemy != null and enemy.texture == authored_frame:
			return true
	return false


func _saw_vfx_frame(battle: Control, authored_frame: Texture2D,
		actor_frame: Texture2D) -> bool:
	if authored_frame == null or actor_frame == null:
		return false
	for _frame in range(65):
		await create_timer(0.02).timeout
		var effect: TextureRect = battle.duel_stage.find_child("SourceVfx", true, false)
		var enemy: TextureRect = battle.duel_stage.find_child("SourceEnemy", true, false)
		if effect != null and enemy != null and effect.visible \
				and effect.texture == authored_frame and enemy.texture == actor_frame:
			return true
	return false
