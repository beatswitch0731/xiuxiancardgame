extends "res://tests/noncombat_abandoned_village_entry.gd"

func _run() -> void:
	var oracle: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(
		"res://tests/fixtures/abandoned_village_source.json"))
	var base_path := "user://tests/abandoned_village_base_%d.json" % Time.get_ticks_usec()
	var game = Domain.new(Registry.new(), RunSession.new(base_path, "slot_3"), "slot_3")
	_set_zero_rolls(game)
	if not _reach_decision27(game):
		return _fail("natural pre-draw route failed")
	game._normal_roll_override = 0.12
	if not game.resume_flow() or game.get_current_card().get("id") != "q_beggar" \
			or not game.choose("right", game.issue_choice_token()) \
			or not _continue_to(game, "thread_ab_village_1") \
			or not game.choose("right", game.issue_choice_token()) \
			or not _continue_to(game, "thread_ab_village_2") \
			or not game.choose("left", game.issue_choice_token()) \
			or not _continue_to(game, "thread_ab_village_3") \
			or not game.choose("left", game.issue_choice_token()) \
			or not game.choose("left", game.issue_choice_token()):
		return _fail("natural village battle prefix failed")
	var battle: Dictionary = game.state.duplicate(true)
	var request: Dictionary = game.battle_request()
	if request.is_empty() or request.get("threadId") != "abandoned_village":
		return _fail("natural village battle request absent")
	for outcome in ["defeat", "flee", "victory"]:
		var path := "user://tests/abandoned_village_%s_%d.json" % [outcome, Time.get_ticks_usec()]
		var store = RunSession.new(path, "slot_3")
		if store.commit_snapshot(battle, -1).get("ok") != true:
			return _fail("could not fork village battle")
		var branch = Domain.new(Registry.new(), store, "slot_3")
		_set_zero_rolls(branch)
		branch._normal_roll_override = 0.12
		if not branch.restore():
			return _fail("village battle fork failed strict restore: " + outcome)
		var result := {"contractVersion": 2,
			"encounterInstanceId": request.encounterInstanceId,
			"sourceCardId": request.sourceCardId,
			"encounterId": request.encounterId,
			"sourceContentHash": request.sourceContentHash,
			"outcome": outcome,
			"combatReceipt": "combat:" + String(request.encounterInstanceId),
			"postBattleState": {"encounterInstanceId": request.encounterInstanceId,
				"terminal": true, "combatPhase": outcome.to_upper()}}
		var bytes := FileAccess.get_file_as_bytes(store.v2_path)
		store.fail_promotion_once = true
		if branch.submit_battle_result(result) or not _same(branch.state, battle) \
				or FileAccess.get_file_as_bytes(store.v2_path) != bytes \
				or not branch.submit_battle_result(result):
			return _fail("village result rollback or retry failed: " + outcome + " " + branch.flow_failure_reason())
		var current: Dictionary = branch.get_current_card()
		var source_card: Dictionary = oracle["branches"][outcome]["resultCard"]
		for key in ["id", "type", "sceneImage", "combatPresentationId", "title", "choices"]:
			if not _same_value(current.get(key), source_card.get(key)):
				return _fail("village result card differs from browser: " + outcome + "/" + key)
		if outcome == "victory":
			for key in ["visualWorldId", "uiMaterialId", "visualWorldMediaDensity",
					"visualWorldLogicalPixelGrid", "visualSurface", "description"]:
				if not _same_value(current.get(key), source_card.get(key)):
					return _fail("village victory presentation differs from browser: " + key)
		elif outcome == "flee" and current.get("description") != source_card.get("description"):
			return _fail("village flee narrative differs from browser")
		elif outcome == "defeat":
			var injury := int(branch.state.get("battleResultHistory", []).back().get(
				"defeatHealthLoss", -1))
			var expected_description := String(source_card.get("description", "")).replace(
				"减少 2 点", "减少 %d 点" % injury)
			if current.get("description") != expected_description:
				return _fail("village defeat narrative differs from source injury rule")
		var runtime: Dictionary = branch.state["storyThreadState"]["threads"]["abandoned_village"]
		if runtime.get("nodeIndex") != 3 or runtime.get("pendingNodeIndex") != -1 \
				or runtime.get("choices", []).size() != 3 \
				or runtime["choices"][2].get("outcomeContext", {}).get("combatOutcome") != outcome \
				or not _reopen(branch) or branch.submit_battle_result(result):
			return _fail("village outcome did not advance thread once: " + outcome)
		if outcome == "victory" and (int(branch.state.resources.spiritStone) != \
				int(battle.resources.spiritStone) + 3 \
				or int(branch.state.attributes.cultivation) < int(battle.attributes.cultivation)):
			return _fail("village victory paid non-source spoils")
		if outcome == "defeat" and (int(branch.state.attributes.daoHeart) != \
				int(battle.attributes.daoHeart) - 1 \
				or int(branch.state.maxHealth) != int(battle.maxHealth) - (
					1 if int(battle.attributes.health) <= 2 else 0) \
				or int(branch.state.attributes.health) != (1 if int(battle.attributes.health) <= 2 \
					else int(battle.attributes.health) - 2)):
			return _fail("village defeat injury or daoHeart differs from source rule")
		if outcome == "flee" and int(branch.state.resources.lifespan) != int(battle.resources.lifespan) - 1:
			return _fail("village flee did not pay the authored lifespan")
		if not branch.choose("down", branch.issue_choice_token()) \
				or not _continue_to(branch, "thread_ab_village_4") or not _reopen(branch):
			return _fail("village outcome did not reach fourth node: " + outcome)
		var fourth: Dictionary = branch.get_current_card()
		var expected: Dictionary = oracle["branches"][outcome]["fourthCard"]
		for key in ["id", "type", "title", "description", "sceneImage", "choices"]:
			if not _same_value(fourth.get(key), expected.get(key)):
				return _fail("village fourth node differs from browser: " + outcome + "/" + key)
		if not branch.choose("right", branch.issue_choice_token()):
			return _fail("village fourth node did not complete: " + outcome)
		var completed: Dictionary = branch.state["storyThreadState"]["threads"]["abandoned_village"]
		var seeds: Array = branch.state.get("karmaSeeds", []).filter(func(seed: Variant) -> bool:
			return seed is Dictionary and seed.get("id") == "exiled_disciple_echo")
		if completed.get("status") != "completed" \
				or completed.get("receipt", {}).get("nodes", []).size() != 4 \
				or completed["receipt"]["nodes"][2].get("outcomeContext", {}).get("combatOutcome") != outcome \
				or branch.state.get("flags", {}).get("village_mystery_solved") != true \
				or seeds.size() != (1 if outcome == "victory" else 0) \
				or outcome == "victory" and int(seeds[0].get("delay", -1)) != 7 \
				or not _reopen(branch):
			return _fail("village completion receipt or promise differs: " + outcome)
	print("NONCOMBAT_ABANDONED_VILLAGE_OUTCOMES_PASS natural=true outcomes=3 fourth_variants=3 replay=true rollback=true")
	quit(0)
