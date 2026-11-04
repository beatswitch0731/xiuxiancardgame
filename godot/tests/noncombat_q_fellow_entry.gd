extends "res://tests/noncombat_normal_runtime.gd"

func _run() -> void:
	var path := "user://tests/q_fellow_entry_%d.json" % Time.get_ticks_usec()
	var store = RunSession.new(path, "slot_3")
	var game = Domain.new(Registry.new(), store, "slot_3")
	_set_zero_rolls(game)
	if not _reach_decision27(game) or game.state.get("phase") != "FLOW_PENDING" \
			or int(game.state.get("runClock", {}).get("decisionIndex", -1)) != 27:
		return _fail("natural source prefix did not reach ordinary draw at decision 27")
	var before: Dictionary = game.state.duplicate(true)
	var bytes := FileAccess.get_file_as_bytes(store.v2_path)
	game._normal_roll_override = 0.18
	if not game.resume_flow():
		if not _same(game.state, before) \
				or FileAccess.get_file_as_bytes(store.v2_path) != bytes:
			return _fail("unsupported q_fellow draw mutated the old checkpoint")
		return _fail("q_fellow ordinary combat choice has no source-backed consumer")
	var card: Dictionary = game.get_current_card()
	print("Q_FELLOW_ENTRY_DIAG phase=", game.state.get("phase"), " card=", card.get("id"),
		" scene=", card.get("sceneImage"), " enemy=", card.get("enemy", {}).get("templateId"),
		" right=", game.can_choose_direction("right"), " gateway=", game._battle_gateway.source_error)
	if game.state.get("phase") != "NORMAL_PENDING" or card.get("id") != "q_fellow" \
			or card.get("sceneImage") != "assets/cards/events/scene_qi_q_fellow.png" \
			or card.get("enemy", {}).get("templateId") != "sect_sparring_qi" \
			or not game.can_choose_direction("right"):
		return _fail("q_fellow natural draw or right combat admission differs")
	if not game.choose("right", game.issue_choice_token()) \
			or game.state.get("phase") != "WARNING_PENDING" \
			or game.get_current_card().get("id") != "_warning_q_fellow" \
			or game.state.get("pendingWarning", {}).get("pendingResolution", {}).get("direction") != "right" \
			or int(game.state.get("runClock", {}).get("decisionIndex", -1)) != 27:
		return _fail("q_fellow right did not persist its delayed warning")
	var oracle: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(
		"res://tests/fixtures/q_fellow_combat_source.json"))
	var warning: Dictionary = game.get_current_card()
	for key in ["id", "type", "title", "description", "sceneImage", "choices"]:
		if JSON.parse_string(JSON.stringify(warning.get(key))) != JSON.parse_string(
				JSON.stringify(oracle.get("warning", {}).get(key))):
			print("Q_FELLOW_WARNING_DIFF ", key, " godot=", JSON.stringify(warning.get(key)),
				" browser=", JSON.stringify(oracle.get("warning", {}).get(key)))
			return _fail("q_fellow warning differs from browser: " + key)
	var warning_reload = Domain.new(Registry.new(), RunSession.new(path, "slot_3"), "slot_3")
	_set_zero_rolls(warning_reload)
	if not warning_reload.restore() or not _same(warning_reload.state, game.state) \
			or not _same(warning_reload.get_current_card(), warning):
		return _fail("q_fellow warning cold restore")
	game = warning_reload
	if not game.choose("left", game.issue_choice_token()) \
			or game.state.get("phase") != "BATTLE_PENDING":
		return _fail("q_fellow warning did not enter battle")
	var request: Dictionary = game.battle_request()
	if request.get("sourceCardId") != "q_fellow" or request.get("direction") != "right" \
			or request.get("encounterId") != null \
			or request.get("pendingResolution", {}).get("combatCard", {}).get("enemy", {}).get("templateId") != "sect_sparring_qi":
		return _fail("q_fellow battle request lost its inline source")
	var source_pending: Dictionary = oracle.get("pending", {})
	if JSON.parse_string(JSON.stringify(request.pendingResolution.choice)) != JSON.parse_string(
			JSON.stringify(source_pending.get("choice"))) \
			or JSON.parse_string(JSON.stringify(request.pendingResolution.combatCard.enemy)) != JSON.parse_string(
			JSON.stringify(source_pending.get("combatCard", {}).get("enemy"))) \
			or JSON.parse_string(JSON.stringify(request.pendingResolution.sourceCard.combatRewards)) != JSON.parse_string(
			JSON.stringify(source_pending.get("sourceCard", {}).get("combatRewards"))) \
			or request.playerSnapshot.battleLoadout.deck != game.state.deck:
		return _fail("q_fellow pending choice, top-level enemy or current deck differs from browser")
	var result := {"contractVersion": 2,
		"encounterInstanceId": request.encounterInstanceId,
		"sourceCardId": request.sourceCardId, "encounterId": request.encounterId,
		"sourceContentHash": request.sourceContentHash, "outcome": "flee",
		"combatReceipt": "combat:" + String(request.encounterInstanceId),
		"postBattleState": {"encounterInstanceId": request.encounterInstanceId,
			"terminal": true, "combatPhase": "FLEE"}}
	if not game.submit_battle_result(result):
		return _fail("q_fellow flee result failed: " + game.flow_failure_reason())
	if game.state.get("phase") != "BATTLE_RESULT_PENDING" \
			or game.get_current_card().get("id") != "combat_fled_q_fellow":
		return _fail("q_fellow flee result card missing")
	print("NONCOMBAT_Q_FELLOW_ENTRY_PASS natural=true top_level_enemy=true warning=true battle=true flee=true")
	quit(0)
