extends "res://tests/noncombat_sword_tomb_live_battle.gd"


func _run() -> void:
	var path := "user://tests/sword_tomb_victory_ui_%d.json" % Time.get_ticks_usec()
	seed(1)
	var game = Domain.new(Registry.new(), RunSession.new(path))
	game._normal_roll_override = 0.0
	if not _reach_decision27(game) and game.state.is_empty():
		return _fail("sword tomb victory seeded prefix could not start")
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
	if not reached_tomb or not game.choose("left", game.issue_choice_token()) \
			or not _continue_to(game, "thread_sword_tomb_1") \
			or not game.choose("left", game.issue_choice_token()) \
			or not _continue_to(game, "thread_sword_tomb_2") \
			or not game.choose("left", game.issue_choice_token()) \
			or not game.choose("left", game.issue_choice_token()) \
			or game.state.get("phase") != "BATTLE_PENDING":
		return _fail("sword tomb victory did not persist its real battle")
	var request: Dictionary = game.battle_request()
	var saved: PackedByteArray = FileAccess.get_file_as_bytes(game._store.v2_path)
	var story: Control = OpeningScene.instantiate()
	story.save_path = path
	root.add_child(story)
	await process_frame
	var launch: Button = story.find_child("LaunchBattle", true, false)
	if launch == null or launch.disabled or not _same_value(story.opening.state, game.state):
		return _fail("sword tomb victory pending save did not cold boot at desktop")
	launch.pressed.emit()
	await process_frame
	var battle: Control = story.active_battle
	if battle == null or not battle.stage_assets_ready or battle.duel_stage == null \
			or battle.duel_stage.get_script().resource_path != \
				"res://scripts/duel_stage_sword_tomb_2d.gd" \
			or FileAccess.get_file_as_bytes(game._store.v2_path) != saved:
		return _fail("sword tomb victory desktop stage changed its pending owner")
	if "--capture-sword-tomb" in OS.get_cmdline_user_args() \
			and not await _capture_opening_frames():
		return _fail("sword tomb Windows opening frames could not be saved")
	var combat_trace: Array = []
	for _step in range(90):
		var phase := String(battle.combat.state.get("phase", ""))
		if phase == "VICTORY":
			break
		if phase != "PLAYER_TURN":
			return _fail("sword tomb victory desktop stopped at " + phase + " " +
				JSON.stringify(combat_trace))
		combat_trace.append({"turn": battle.combat.state.get("turn"),
			"hp": battle.combat.state.get("player", {}).get("hp"),
			"enemyHp": battle.combat.state.get("enemy", {}).get("hp"),
			"intent": battle.combat.state.get("enemyIntent", {}).get("type"),
			"hand": battle.combat.state.get("hand", []).duplicate(),
			"qi": battle.combat.state.get("qi")})
		var priority := ["sword_intent", "sword_probe", "sword_edge",
			"draw_sword", "sword_followthrough", "sword_guard", "sword_sheath_guard"]
		if battle.combat.state.get("enemyIntent", {}).get("type") == "attack" \
				and int(battle.combat.state.get("player", {}).get("block", 0)) < 2:
			priority = ["sword_guard", "sword_sheath_guard"] + priority
		var reserve_evasion: bool = battle.combat.state.get(
			"enemyIntent", {}).get("type") == "attack" \
			and int(battle.combat.state.get("player", {}).get("hp", 0)) <= 2
		var card := null if reserve_evasion else _find_card(battle.hand_row, priority)
		if card != null:
			card.pressed.emit()
			if not await _wait_presentations(battle):
				return _fail("sword tomb victory card lacked source presentation")
			continue
		battle.end_button.pressed.emit()
		await process_frame
		if battle.combat.state.get("phase") != "REACTION_OPEN":
			return _fail("sword tomb victory did not open enemy reaction")
		var intent: Dictionary = battle.combat.state.get("enemyIntent", {})
		var guard: Button = battle.reaction_buttons[2]
		var evade: Button = battle.reaction_buttons[3]
		var reaction: Button = evade if intent.get("type") == "attack" \
			and int(battle.combat.state.get("player", {}).get("hp", 0)) <= 2 \
			and not evade.disabled else (guard if intent.get("type") == "attack" \
			and not guard.disabled else battle.reaction_buttons[0])
		reaction.pressed.emit()
		if not await _wait_presentations(battle):
			return _fail("sword tomb victory reaction lacked source action")
	if battle.combat.state.get("phase") != "VICTORY":
		return _fail("sword tomb player cards did not defeat source avatar: " +
			JSON.stringify(combat_trace))
	var result: Dictionary = battle.terminal_result()
	if result.get("outcome") != "victory" or result.get("encounterId") != null \
			or result.get("sourceCardId") != request.get("sourceCardId"):
		return _fail("sword tomb victory result lost its inline owner")
	var return_button: Button = battle.get_node_or_null("ReturnToStory")
	if return_button == null or return_button.disabled or not return_button.visible:
		return _fail("sword tomb victory had no return to story")
	story.opening_store.fail_promotion_once = true
	return_button.pressed.emit()
	await process_frame
	if story.active_battle != battle or story.opening.state.get("phase") != "BATTLE_PENDING" \
			or FileAccess.get_file_as_bytes(game._store.v2_path) != saved:
		return _fail("sword tomb failed victory write changed pending owner")
	return_button.pressed.emit()
	await process_frame
	var settled = Domain.new(Registry.new(), RunSession.new(path))
	if not settled.restore():
		return _fail("sword tomb victory save did not cold restore")
	var thread: Dictionary = settled.state.get("storyThreadState", {}).get(
		"threads", {}).get("sword_tomb_trial", {})
	if story.active_battle != null or settled.get_current_card().get("id") != "combat_reward" \
			or thread.get("choices", []).size() != 2 \
			or thread.get("choices", [])[1].get("outcomeContext", {}).get(
				"combatOutcome") != "victory" \
			or settled.submit_battle_result(result):
		return _fail("sword tomb victory did not settle once after cold restart")
	story.queue_free()
	await process_frame
	print("NONCOMBAT_SWORD_TOMB_LIVE_VICTORY_PASS desktop=true victory=true rollback=true replay=true")
	quit(0)


func _find_card(hand: HBoxContainer, priority: Array) -> Button:
	for card_id in priority:
		for child in hand.get_children():
			if child is Button and not child.disabled \
					and child.get_meta("source_card_id", "") == card_id:
				return child as Button
	return null


func _capture_opening_frames() -> bool:
	var directory := ProjectSettings.globalize_path(
		"res://../artifacts/godot-migration/sword-tomb-live-battle/")
	if DirAccess.make_dir_recursive_absolute(directory) != OK:
		return false
	for size in [Vector2i(1280, 800), Vector2i(1920, 1080)]:
		root.size = size
		for _frame in range(6):
			await process_frame
		var image: Image = root.get_texture().get_image()
		if image == null or image.is_empty() or image.save_png(
				directory.path_join("sword_tomb_%d_idle.png" % size.x)) != OK:
			return false
	return true
