extends "res://tests/noncombat_cadence_third_alt_entry.gd"

const GATE_FIXTURE := "res://tests/fixtures/qi_gate_source.json"
const OpeningScene = preload("res://scenes/noncombat_opening.tscn")
const CombatDomain = preload("res://scripts/combat_domain.gd")

func _run() -> void:
	var first: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	var second: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SECOND_FIXTURE))
	var third: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(THIRD_FIXTURE))
	var gate: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(GATE_FIXTURE))
	var file := "user://tests/qi_gate_%d.json" % Time.get_ticks_usec()
	var game = Domain.new(Registry.new(), Session.new(file, "slot_2"), "slot_2")
	_quiet_ambient(game)
	if not _open_third_alt(game, first, second, third):
		return _fail(_problem)
	if not _reach_gate(game):
		return _fail(_problem)
	var warning: Dictionary = game.get_current_card()
	if warning.get("id") != gate.rows[0].warning.id:
		return _fail("realm gate expected %s got %s" % [
			gate.rows[0].warning.id, warning.get("id")])
	if game.state.phase != "WARNING_PENDING":
		return _fail("realm gate did not enter warning phase")
	for key in ["id", "title", "description", "type", "choices", "sceneImage"]:
		if not _expect(_canonical(warning.get(key)), _canonical(gate.rows[0].warning.get(key)),
				"realm gate warning " + key):
			return _fail(_problem)
	if _cold(game, "qi gate warning") == null:
		return _fail("realm gate warning failed strict cold restore: " + _problem)
	var before: Dictionary = game.state.duplicate(true)
	if not game.choose("left", game.issue_choice_token()):
		return _fail("realm gate free preparation failed")
	var request: Dictionary = game.battle_request()
	if game.state.phase != "BATTLE_PENDING" \
			or request.get("sourceCardId") != gate.sourceCardId \
			or request.get("playerSnapshot", {}).get("battleLoadout", {}).get("deck") \
				!= before.get("deck") \
			or game.state.get("resources") != before.get("resources"):
		return _fail("realm gate did not issue current-deck free battle request")
	if _cold(game, "qi gate pending") == null:
		return _fail("realm gate pending failed strict cold restore: " + _problem)
	var story: Control = OpeningScene.instantiate()
	story.save_path = ""
	root.add_child(story)
	await process_frame
	story.opening = game
	story.slot_screen.visible = false
	story.name_screen.visible = false
	story.path_screen.visible = false
	story.story_screen.visible = true
	story._set_scene_surface(true)
	story._render()
	await process_frame
	var launch: Button = story.find_child("LaunchBattle", true, false)
	if launch == null or launch.disabled:
		var resolver = preload("res://scripts/battle_plan_resolver.gd").new(Registry.new())
		var plan: Dictionary = resolver.resolve_persisted(game.state)
		return _fail("realm gate desktop battle launch unavailable: " + JSON.stringify({
			"phase": game.state.get("phase"), "status": story.status_label.text,
			"plan": plan.get("launchAuthorized"), "scene": plan.get("stageScene"),
			"error": resolver.last_error, "launch": launch != null}))
	launch.pressed.emit()
	await process_frame
	if story.active_battle == null \
			or story.active_battle.battle_plan.get("enemy") != request.get(
				"pendingResolution", {}).get("combatCard", {}).get("enemy") \
			or story.active_battle.battle_plan.get("stageScene") != \
				"res://scenes/duel_stage_qi_gate_2d.tscn" \
			or story.opening_audio.bgm_player.stream == null \
			or not story.opening_audio.bgm_player.stream.resource_path.ends_with(
				"bgm/03_boss_tribulation/bgm_03_boss_tribulation.wav"):
		return _fail("realm gate desktop battle missed the source boss BGM")
	var rule_problem := _rule_parity_probe(request, story.active_battle.battle_plan)
	if not rule_problem.is_empty():
		return _fail(rule_problem)
	var battle: Control = story.active_battle
	for turn_number in 3:
		var release_deadline := Time.get_ticks_msec() + 5000
		while battle.combat.input_locked and Time.get_ticks_msec() < release_deadline:
			await process_frame
		if battle.end_button.disabled:
			return _fail("realm gate end-turn button unavailable on turn %d" % (turn_number + 1))
		battle.end_button.pressed.emit()
		await process_frame
		if battle.combat.state.get("phase") != "REACTION_OPEN" \
				or battle.reaction_buttons[0].disabled:
			return _fail("realm gate could not resolve natural enemy turn %d: %s" % [
				turn_number + 1, JSON.stringify({"phase": battle.combat.state.get("phase"),
					"locked": battle.combat.input_locked,
					"intent": battle.combat.state.get("enemyIntent", {})})])
		battle.reaction_buttons[0].pressed.emit()
		await process_frame
		if turn_number < 2 and battle.combat.state.get("phase") != "PLAYER_TURN":
			return _fail("realm gate ended before the three-turn survival condition")
	if battle.combat.state.get("phase") != "VICTORY" \
			or int(battle.combat.state.get("enemy", {}).get("hp", 0)) != 5:
		return _fail("realm gate did not award survival victory with enemy alive")
	var terminal: Dictionary = battle.terminal_result()
	var return_button: Button = battle.get_node_or_null("ReturnToStory")
	var return_deadline := Time.get_ticks_msec() + 5000
	while return_button != null and return_button.disabled \
			and Time.get_ticks_msec() < return_deadline:
		await process_frame
	if return_button == null or not return_button.visible or return_button.disabled:
		return _fail("realm gate return button unavailable after survival victory")
	return_button.pressed.emit()
	await process_frame
	if game.state.get("phase") != "BATTLE_RESULT_PENDING" \
			or game.state.get("realm") != "foundation" \
			or story.active_battle != null:
		return _fail("realm gate survival result did not return through source settlement")
	if _cold(game, "qi gate survival result") == null:
		return _fail("realm gate survival result failed strict cold restore: " + _problem)
	if game.get_current_card().get("id") != gate.rows[0].resultCard.id:
		return _fail("realm gate source result card did not appear in story")
	var result_choice: Button = story.find_child("Choice_left", true, false)
	if result_choice == null or result_choice.disabled:
		return _fail("realm gate result confirmation button unavailable")
	result_choice.pressed.emit()
	await process_frame
	if game.state.get("phase") == "BATTLE_RESULT_PENDING" \
			or _cold(game, "qi gate result confirmation") == null:
		return _fail("realm gate player result confirmation did not persist")
	story.queue_free()
	await process_frame
	print("NONCOMBAT_QI_GATE_ENTRY_PASS public=true quota=true warning=true pending=true survival=true counter=true plan_order=true return=true replay=true")
	quit(0)


func _rule_parity_probe(request: Dictionary, plan: Dictionary) -> String:
	var raw_damage := -1
	var guarded_damage := -1
	for pill_used in [false, true]:
		var probe_request: Dictionary = request.duplicate(true)
		probe_request["playerSnapshot"]["flags"]["used_foundation_pill"] = pill_used
		var combat = CombatDomain.new(Registry.new())
		if not combat.load_persisted_request(probe_request, plan):
			return "realm gate source rule probe failed to load"
		var runtime: Dictionary = combat.state["enemy"]["planRuntime"]
		if not pill_used:
			var memory: Dictionary = runtime["turnMemory"]
			memory["cardsPlayed"] = 2
			memory["qiRemaining"] = 0
			memory["consecutiveCount"] = 2
			combat._for_card_plan_transition()
			if runtime.get("currentState") != "PUNISH" \
					or runtime.get("lastTransition", {}).get("sourceCardId") != "ch_qi_100":
				return "realm gate repeated card did not take source priority over overcommit"
		runtime["currentState"] = "PRESSURE"
		combat._refresh_intent()
		combat.state["player"]["block"] = 0
		combat.state["player"]["defMod"] = 0
		combat.state["player"]["daoHeart"] = 0
		combat.state["player"]["hp"] = 10
		combat.state["player"]["maxHp"] = 10
		var before_hp := int(combat.state["player"]["hp"])
		if not combat.end_turn() or not combat.take_hit(1.0):
			return "realm gate source counter attack could not resolve"
		var damage := before_hp - int(combat.state["player"]["hp"])
		if pill_used:
			guarded_damage = damage
		else:
			raw_damage = damage
	if raw_damage != 4 or guarded_damage != 2:
		return "realm gate foundation pill damage differs: %d/%d" % [raw_damage, guarded_damage]
	return ""


func _reach_gate(game: RefCounted) -> bool:
	if not game.choose("right", game.issue_choice_token()):
		return _bad("elite avoidance failed")
	for i in 3:
		if game.state.phase == "FLOW_PENDING" and not game.resume_flow():
			return _bad("realm gate did not resume")
		var card_id := String(game.get_current_card().get("id", ""))
		if card_id == "_warning_ch_qi_100":
			return true
		if card_id != "em_heaven_gaze" or not game.choose("right", game.issue_choice_token()):
			return _bad("realm gate prefix differs: " + card_id)
	return _bad("realm gate did not surface")
