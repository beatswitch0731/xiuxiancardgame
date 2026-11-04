extends "res://tests/noncombat_normal_runtime.gd"

func _run() -> void:
	var oracle: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(
		"res://tests/fixtures/q_fellow_combat_source.json"))
	for outcome in ["victory", "defeat", "flee"]:
		var file := "user://tests/q_fellow_%s_%d.json" % [outcome, Time.get_ticks_usec()]
		var store = RunSession.new(file, "slot_3")
		var game = Domain.new(Registry.new(), store, "slot_3")
		_set_zero_rolls(game)
		if not _reach_decision27(game):
			return _fail("source prefix: " + outcome)
		game._normal_roll_override = 0.18
		if not game.resume_flow() or game.get_current_card().get("id") != "q_fellow" \
				or not game.choose("right", game.issue_choice_token()) \
				or not game.choose("left", game.issue_choice_token()):
			return _fail("natural combat entry: " + outcome)
		var request: Dictionary = game.battle_request()
		if request.is_empty():
			return _fail("request: " + outcome)
		var restored = Domain.new(Registry.new(), RunSession.new(file, "slot_3"), "slot_3")
		_set_zero_rolls(restored)
		var reopened: bool = restored.restore()
		if not reopened or not _same(restored.state, game.state):
			print("Q_FELLOW_RESTORE_DIAG reopened=", reopened,
				" error=", restored._store.last_error,
				" phase=", game.state.get("phase"),
				" gatewayRequest=", not restored._battle_gateway.build_request(game.state).is_empty())
			return _fail("pending cold restore: " + outcome)
		game = restored
		var before: Dictionary = game.state.duplicate(true)
		var result := {"contractVersion": 2, "encounterInstanceId": request.encounterInstanceId,
			"sourceCardId": request.sourceCardId, "encounterId": request.encounterId,
			"sourceContentHash": request.sourceContentHash, "outcome": outcome,
			"combatReceipt": "combat:" + String(request.encounterInstanceId),
			"postBattleState": {"encounterInstanceId": request.encounterInstanceId,
				"terminal": true, "combatPhase": outcome.to_upper()}}
		var foreign: Dictionary = result.duplicate(true)
		foreign["encounterInstanceId"] = "foreign:owner"
		if game.submit_battle_result(foreign) or not _same(game.state, before):
			return _fail("foreign battle owner accepted: " + outcome)
		var bytes := FileAccess.get_file_as_bytes(game._store.v2_path)
		game._store.fail_promotion_once = true
		if game.submit_battle_result(result) or not _same(game.state, before) \
				or FileAccess.get_file_as_bytes(game._store.v2_path) != bytes:
			return _fail("failed settlement was not atomic: " + outcome)
		if not game.submit_battle_result(result):
			return _fail("settlement: " + outcome + " / " + game.flow_failure_reason())
		var expected_id := "combat_reward" if outcome == "victory" else \
			("combat_defeat_q_fellow" if outcome == "defeat" else "combat_fled_q_fellow")
		if game.state.get("phase") != "BATTLE_RESULT_PENDING" \
				or game.get_current_card().get("id") != expected_id \
				or int(game.state.turn) != int(before.turn) + 1 \
				or game.state.choiceHistory.back().direction != "right":
			return _fail("result/clock/source direction: " + outcome)
		var browser_card: Dictionary = oracle.get("branches", {}).get(outcome, {}).get("resultCard", {})
		var godot_card: Dictionary = game.get_current_card()
		for key in ["id", "type", "title", "sceneImage", "combatPresentationId"]:
			if JSON.parse_string(JSON.stringify(godot_card.get(key))) != JSON.parse_string(
					JSON.stringify(browser_card.get(key))):
				return _fail("result presentation differs from browser: " + outcome + "/" + key)
		if outcome != "victory" and (JSON.parse_string(JSON.stringify(godot_card.get("description"))) \
				!= JSON.parse_string(JSON.stringify(browser_card.get("description"))) \
				or JSON.parse_string(JSON.stringify(godot_card.get("choices"))) \
				!= JSON.parse_string(JSON.stringify(browser_card.get("choices")))):
			return _fail("loss/flee card differs from browser: " + outcome)
		if game.submit_battle_result(result) or game.state.runClock.decisionIndex != before.runClock.decisionIndex + 1:
			return _fail("duplicate result accepted: " + outcome)
		var after: Dictionary = game.state.duplicate(true)
		var rep := int(after.get("factionProgress", {}).get("reputations", {}).get("qingyun_sword", -999))
		if outcome == "victory":
			var glory: Array = after.karmaSeeds.filter(func(seed: Dictionary) -> bool:
				return seed.get("id") == "combatGlory")
			if int(after.attributes.karmaBad) - int(before.attributes.karmaBad) != 5 \
					or int(after.resources.spiritStone) - int(before.resources.spiritStone) != 6 \
					or int(after.attributes.cultivation) < int(before.attributes.cultivation) \
					or rep != 7 or glory.size() != 1 or int(glory[0].delay) != 8:
				return _fail("victory source rewards, reputation or karma")
		elif outcome == "defeat":
			if int(after.attributes.daoHeart) != int(before.attributes.daoHeart) - 1 \
					or int(after.maxHealth) != int(before.maxHealth) - 1 \
					or int(after.maxDaoHeart) != int(before.maxDaoHeart) - 1 \
					or int(after.attributes.health) != 1 or rep != 8 \
					or after.karmaSeeds.size() != before.karmaSeeds.size():
				return _fail("defeat injury, burn blood or reputation")
		else:
			if int(after.attributes.daoHeart) != int(before.attributes.daoHeart) - 1 \
					or int(after.resources.lifespan) != int(before.resources.lifespan) \
					or rep != 10 or after.karmaSeeds.size() != before.karmaSeeds.size():
				return _fail("flee effects or reputation")
		var settled = Domain.new(Registry.new(), RunSession.new(file, "slot_3"), "slot_3")
		_set_zero_rolls(settled)
		if not settled.restore() or not _same(settled.state, after) \
				or settled.get_current_card().get("id") != expected_id:
			return _fail("result cold restore: " + outcome)
		game = settled
		if not game.choose("down", game.issue_choice_token()) \
				or game.state.get("phase") != "FLOW_PENDING":
			return _fail("result acknowledgement: " + outcome)
		if not game.resume_flow():
			return _fail("result continuation: " + outcome)
		print("Q_FELLOW_OUTCOME_PASS " + outcome)
	print("NONCOMBAT_Q_FELLOW_OUTCOMES_PASS natural=true outcomes=3 replay=true")
	quit(0)
