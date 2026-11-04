extends "res://tests/noncombat_foundation_sword_trial_contract.gd"


func _run() -> void:
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(
		"res://content/data/quests/sword_legacy.json"))
	for direction in ["left", "right"]:
		for outcome in ["victory", "defeat", "flee"]:
			var path := "user://tests/foundation_sword_outcome_%s_%s_%d.json" % [
				direction, outcome, Time.get_ticks_usec()]
			var store = Session.new(path, "slot_2")
			var copied := FileAccess.open(store.v2_path, FileAccess.WRITE)
			copied.store_buffer(FileAccess.get_file_as_bytes(FIXTURE))
			copied.close()
			var game = Domain.new(Registry.new(), store, "slot_2")
			_quiet(game)
			if not game.restore() or not game.choose(direction, game.issue_choice_token()) \
					or not game.choose("left", game.issue_choice_token()):
				return _fail("trial did not reach a durable request: " + direction)
			var request: Dictionary = game.battle_request()
			var before: Dictionary = game.state.duplicate(true)
			var result := _result(request, outcome)
			if direction == "left" and outcome == "victory":
				var raw := FileAccess.get_file_as_bytes(store.v2_path)
				game._store.fail_promotion_once = true
				if game.submit_battle_result(result) or not _same(game.state, before) \
						or FileAccess.get_file_as_bytes(store.v2_path) != raw:
					return _fail("trial failed write changed state or save")
			if not game.submit_battle_result(result):
				return _fail("trial result was not settled: %s/%s %s" % [
					direction, outcome, game.flow_failure_reason()])
			var wanted_step := 3 if outcome == "victory" else 2
			var wanted_flag := "sword_legacy_trial_heart" if direction == "left" else "sword_legacy_trial_iron"
			var choice: Dictionary = source.cards[2].choices[direction]
			var sword_seed: Dictionary = {}
			for seed in game.state.karmaSeeds:
				if seed is Dictionary and seed.get("id") == choice.karmaSeed.id:
					sword_seed = seed
					break
			if game.state.questState.activeQuests[0].step != wanted_step \
					or game.state.flags.get(wanted_flag, false) != (outcome == "victory") \
					or sword_seed.is_empty() == (outcome == "victory") \
					or outcome == "victory" and (int(sword_seed.get("delay", -1)) != 6 \
						or int(sword_seed.get("originTurn", -1)) != int(game.state.turn)) \
					or game.state.questState.completedQuests.has("sword_legacy") \
					or game.state.attributes.health < 1:
				return _fail("trial result paid an incorrect task outcome: %s/%s" % [
					direction, outcome])
			var reopen = Domain.new(Registry.new(), Session.new(path, "slot_2"), "slot_2")
			_quiet(reopen)
			if not reopen.restore() or not _same(reopen.state, game.state):
				return _fail("trial result failed strict cold restore: %s/%s" % [direction, outcome])
			if game.submit_battle_result(result):
				return _fail("trial accepted duplicate terminal result")
			var acknowledged: bool = game.choose("down", game.issue_choice_token())
			var continued: bool = _continue_to_sword_quest(game) if acknowledged else false
			if not acknowledged or not continued \
					or game.get_current_card().get("id") != (
						"q_sword_4" if outcome == "victory" else "q_sword_3"):
				return _fail("trial result did not resume the authored quest: %s/%s %s" % [
						direction, outcome, JSON.stringify({"ack": acknowledged,
						"continued": continued, "phase": game.state.get("phase"),
						"card": game.get_current_card().get("id"),
						"flow": game.flow_failure_reason(),
						"quest": game._quest_flow.last_error})])
			if outcome == "victory" and direction == "right" \
					and game.get_current_card().get("description") != source.cards[3].stateVariants[0].description:
				return _fail("iron victory did not project the final quest variant")
			var resumed = Domain.new(Registry.new(), Session.new(path, "slot_2"), "slot_2")
			_quiet(resumed)
			if not resumed.restore() or not _same(resumed.state, game.state):
				return _fail("trial continuation did not strictly reload: %s/%s" % [
						direction, outcome])
	print("NONCOMBAT_FOUNDATION_SWORD_TRIAL_OUTCOMES_PASS directions=2 outcomes=3 replay=true rollback=true")
	quit(0)


func _continue_to_sword_quest(game: RefCounted) -> bool:
	for _step in range(20):
		if game.state.get("phase") == "QUEST_PENDING" and game.get_current_card().get(
				"id") in ["q_sword_3", "q_sword_4"]:
			return true
		if game.state.get("phase") == "FLOW_PENDING":
			if not game.resume_flow():
				return false
		elif game.state.get("phase") == "COMBAT_HANDOFF" and game.state.get(
				"pendingCadenceCard") is Dictionary:
			if not game.choose("right", game.issue_choice_token()):
				return false
		elif game.state.get("phase") == "NARRATIVE_RESULT_PENDING" and game.state.get(
				"noncombatFlow", {}).get("cadencePromise") is Dictionary:
			if not game.choose("left", game.issue_choice_token()):
				return false
		elif game.state.get("phase") == "MILESTONE_PENDING" and game.get_current_card().get(
				"id") in ["ch_foundation_20", "ch_foundation_40",
				"ch_foundation_60", "ch_foundation_80"]:
			if not game.choose("left", game.issue_choice_token()):
				return false
		elif game.state.get("phase") == "DESTINY_WHEEL_PENDING" and game.get_current_card().get(
				"id") == "destiny_wheel":
			if not game.choose("left", game.issue_choice_token()):
				return false
		else:
			return false
	return false


func _quiet(game: RefCounted) -> void:
	game._ripple_flow.roll_override = 0.999
	game._hint_flow.roll_override = 0.0
	game._market_flow.roll_override = 0.0


func _result(request: Dictionary, outcome: String) -> Dictionary:
	return {"contractVersion": 2, "encounterInstanceId": request.encounterInstanceId,
		"sourceCardId": request.sourceCardId, "encounterId": request.encounterId,
		"sourceContentHash": request.sourceContentHash, "outcome": outcome,
		"combatReceipt": "combat:" + String(request.encounterInstanceId),
		"postBattleState": {"encounterInstanceId": request.encounterInstanceId,
			"terminal": true, "combatPhase": outcome.to_upper()}}
