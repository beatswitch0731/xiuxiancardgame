extends "res://tests/noncombat_q_fellow_live_battle.gd"


func _run() -> void:
	var path := "user://tests/q_fellow_victory_ui_%d.json" % Time.get_ticks_usec()
	seed(1)
	var game = Domain.new(Registry.new(), RunSession.new(path))
	game._normal_roll_override = 0.0
	if not _reach_decision27(game) and game.state.is_empty():
		return _fail("q_fellow seeded victory path could not start")
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
	if not reached_fellow or not game.choose("right", game.issue_choice_token()) \
			or not game.choose("left", game.issue_choice_token()) \
			or game.state.get("phase") != "BATTLE_PENDING":
		return _fail("q_fellow seeded victory path did not persist its fight")
	var request: Dictionary = game.battle_request()
	var saved: PackedByteArray = FileAccess.get_file_as_bytes(game._store.v2_path)
	var story: Control = OpeningScene.instantiate()
	story.save_path = path
	root.add_child(story)
	await process_frame
	var launch: Button = story.find_child("LaunchBattle", true, false)
	if launch == null or launch.disabled or not _same(story.opening.state, game.state):
		return _fail("q_fellow victory pending save did not cold boot at desktop")
	launch.pressed.emit()
	await process_frame
	var battle: Control = story.active_battle
	if battle == null or not battle.stage_assets_ready \
			or FileAccess.get_file_as_bytes(game._store.v2_path) != saved:
		return _fail("q_fellow victory desktop changed the pending owner")
	if "--capture-fellow" in OS.get_cmdline_user_args() \
			and not await _capture_opening_frames():
		return _fail("q_fellow Windows opening frames could not be saved")
	for _step in range(60):
		var phase := String(battle.combat.state.get("phase", ""))
		if phase == "VICTORY":
			break
		if phase != "PLAYER_TURN":
			return _fail("q_fellow victory route stopped at " + phase)
		var card := _find_card(battle.hand_row, ["sword_intent", "sword_probe",
			"sword_edge", "draw_sword", "sword_followthrough"])
		if card != null:
			card.pressed.emit()
			if not await _wait_presentations(battle):
				return _fail("q_fellow victory attack lacked its mounted presentation")
			continue
		battle.end_button.pressed.emit()
		await process_frame
		if battle.combat.state.get("phase") != "REACTION_OPEN":
			return _fail("q_fellow victory route did not open enemy reaction")
		var intent: Dictionary = battle.combat.state.get("enemyIntent", {})
		var guard: Button = battle.reaction_buttons[2]
		var reaction: Button = guard if intent.get("type") == "attack" \
			and not guard.disabled else battle.reaction_buttons[0]
		reaction.pressed.emit()
		if not await _wait_presentations(battle):
			return _fail("q_fellow victory reaction lacked source action")
	if battle.combat.state.get("phase") != "VICTORY":
		return _fail("q_fellow live sword cards did not defeat the source sparring foe")
	var result: Dictionary = battle.terminal_result()
	if result.get("outcome") != "victory" or result.get("encounterId") != null \
			or result.get("sourceCardId") != request.get("sourceCardId"):
		return _fail("q_fellow victory receipt lost its inline source owner")
	battle._render()
	var return_button: Button = battle.get_node_or_null("ReturnToStory")
	if return_button == null or return_button.disabled or not return_button.visible:
		return _fail("q_fellow victory had no return to story")
	story.opening_store.fail_promotion_once = true
	return_button.pressed.emit()
	await process_frame
	if story.active_battle != battle or story.opening.state.get("phase") != "BATTLE_PENDING" \
			or FileAccess.get_file_as_bytes(game._store.v2_path) != saved:
		return _fail("q_fellow failed victory save changed the pending owner")
	return_button.pressed.emit()
	await process_frame
	var settled = Domain.new(Registry.new(), RunSession.new(path))
	if story.active_battle != null or not settled.restore() \
			or settled.get_current_card().get("id") != "combat_reward" \
			or settled.submit_battle_result(result):
		return _fail("q_fellow victory did not settle once after cold restart")
	story.queue_free()
	await process_frame
	print("NONCOMBAT_Q_FELLOW_LIVE_VICTORY_PASS desktop=true victory=true rollback=true replay=true")
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
		"res://../artifacts/godot-migration/q-fellow-live-battle/")
	if DirAccess.make_dir_recursive_absolute(directory) != OK:
		return false
	for size in [Vector2i(1280, 800), Vector2i(1920, 1080)]:
		root.size = size
		for _frame in range(6):
			await process_frame
		var image: Image = root.get_texture().get_image()
		if image == null or image.is_empty() or image.save_png(
				directory.path_join("q_fellow_%d_idle.png" % size.x)) != OK:
			return false
	return true
