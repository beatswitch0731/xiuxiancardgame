extends "res://tests/noncombat_sword_tomb_entry.gd"

func _run() -> void:
	var oracle: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(
		"res://tests/fixtures/sword_tomb_source.json"))
	var path := "user://tests/sword_tomb_outcomes_%d.json" % Time.get_ticks_usec()
	var game = Domain.new(Registry.new(), RunSession.new(path, "slot_3"), "slot_3")
	_set_zero_rolls(game)
	if not _reach_decision27(game):
		return _fail("natural sword tomb pre-draw route failed")
	game._normal_roll_override = 0.46
	if not game.resume_flow() or game.get_current_card().get("id") != "q_swordTomb" \
			or not game.choose("left", game.issue_choice_token()) \
			or not _continue_to(game, "thread_sword_tomb_1") \
			or not game.choose("left", game.issue_choice_token()) \
			or not _continue_to(game, "thread_sword_tomb_2"):
		return _fail("natural sword tomb battle prefix failed")
	var second: Dictionary = game.state.duplicate(true)
	for battle_direction in ["left", "right"]:
		var battle = _fork(second, "battle_" + battle_direction)
		if battle == null or not battle.choose(battle_direction, battle.issue_choice_token()) \
				or not battle.choose("left", battle.issue_choice_token()):
			return _fail("sword tomb battle warning failed: " + battle_direction)
		var request: Dictionary = battle.battle_request()
		if request.get("sourceCardId") != "thread_sword_tomb_2" \
				or request.get("direction") != battle_direction \
				or request.get("threadId") != "sword_tomb_trial":
			return _fail("sword tomb battle request failed: " + battle_direction)
		var battle_state: Dictionary = battle.state.duplicate(true)
		for outcome in ["victory", "defeat", "flee"]:
			var key: String = battle_direction + "_" + outcome
			print("SWORD_TOMB_CASE " + key)
			var expected: Dictionary = oracle["battleBranches"][key]
			var branch = _fork(battle_state, key)
			if branch == null:
				return _fail("sword tomb outcome fork failed: " + key)
			var result := {"contractVersion": 2,
				"encounterInstanceId": request.encounterInstanceId,
				"sourceCardId": request.sourceCardId,
				"encounterId": request.encounterId,
				"sourceContentHash": request.sourceContentHash,
				"outcome": outcome,
				"combatReceipt": "combat:" + String(request.encounterInstanceId),
				"postBattleState": {"encounterInstanceId": request.encounterInstanceId,
					"terminal": true, "combatPhase": outcome.to_upper()}}
			if key == "left_victory":
				var bytes := FileAccess.get_file_as_bytes(branch._store.v2_path)
				branch._store.fail_promotion_once = true
				if branch.submit_battle_result(result) or not _same_value(
						branch.state, battle_state) \
						or FileAccess.get_file_as_bytes(branch._store.v2_path) != bytes:
					return _fail("sword tomb result write failure was not atomic")
			if not branch.submit_battle_result(result):
				return _fail("sword tomb result rejected: " + key + " " + branch.flow_failure_reason())
			var result_card: Dictionary = branch.get_current_card()
			for field in ["id", "type", "title", "sceneImage", "combatPresentationId"]:
				if not _same_value(result_card.get(field), expected["resultCard"].get(field)):
					return _fail("sword tomb result card differs from browser: " + key + "/" + field)
			if outcome == "victory":
				for field in ["visualWorldId", "uiMaterialId", "visualWorldMediaDensity",
						"visualWorldLogicalPixelGrid", "visualSurface"]:
					if not _same_value(result_card.get(field), expected["resultCard"].get(field)):
						return _fail("sword tomb victory media differs from browser: " + key + "/" + field)
				if String(result_card.get("description", "")).get_slice("【本次结算】", 0) != \
						String(expected["resultCard"].get("description", "")).get_slice(
							"【本次结算】", 0):
					return _fail("sword tomb victory prose differs from browser: " + key)
			elif outcome == "defeat":
				var injury := int(branch.state.get("battleResultHistory", []).back().get(
					"defeatHealthLoss", -1))
				var expected_prose := String(expected["resultCard"].get("description", "")).replace(
					"减少 2 点", "减少 %d 点" % injury)
				if result_card.get("description") != expected_prose:
					return _fail("sword tomb defeat prose differs from source injury rule: " + key)
			elif result_card.get("description") != expected["resultCard"].get("description"):
				return _fail("sword tomb flee prose differs from browser: " + key)
			if not _same_value(result_card.get("choices", {}).get("down"),
					expected["resultCard"].get("choices", {}).get("down")):
				return _fail("sword tomb result continuation differs from browser: " + key)
			var runtime: Dictionary = branch.state["storyThreadState"]["threads"]["sword_tomb_trial"]
			if runtime.get("nodeIndex") != 2 or runtime.get("choices", []).size() != 2 \
					or runtime["choices"][1].get("outcomeContext", {}).get(
						"combatOutcome") != outcome \
					or branch.state.get("flags", {}).get("sword_trial_passed", false) != (
						outcome == "victory") \
					or not _reopen(branch) or branch.submit_battle_result(result):
				return _fail("sword tomb outcome did not advance once: " + key)
			if not branch.choose("down", branch.issue_choice_token()) \
					or not _continue_to(branch, "thread_sword_tomb_3") \
					or not _reopen(branch):
				return _fail("sword tomb outcome did not reach third node: " + key)
			var third: Dictionary = branch.get_current_card()
			for field in ["id", "title", "description", "sceneImage", "choices"]:
				if not _same_value(third.get(field), expected["thirdCard"].get(field)):
					return _fail("sword tomb final card differs from browser: " + key + "/" + field)
			var third_state: Dictionary = branch.state.duplicate(true)
			for ending_direction in ["left", "right"]:
				var ending = _fork(third_state, key + "_" + ending_direction)
				if ending == null or not ending.choose(ending_direction,
						ending.issue_choice_token()):
					return _fail("sword tomb final choice failed: " + key + "/" + ending_direction)
				var complete: Dictionary = ending.state["storyThreadState"]["threads"]["sword_tomb_trial"]
				var ancient: Array = ending.state.get("treasureInstances", {}).values().filter(
					func(item: Variant) -> bool: return item is Dictionary and item.get(
						"definitionId") == "剑心古剑")
				var seeds: Array = ending.state.get("karmaSeeds", []).filter(
					func(item: Variant) -> bool: return item is Dictionary and item.get(
						"id") == "sword_spirit_memory")
				var awarded: bool = outcome == "victory" and ending_direction == "left"
				if complete.get("status") != "completed" \
						or complete.get("receipt", {}).get("nodes", []).size() != 3 \
						or complete["receipt"]["nodes"][1].get(
							"outcomeContext", {}).get("combatOutcome") != outcome \
						or ancient.size() != (1 if awarded else 0) \
						or seeds.size() != (1 if awarded else 0) \
						or awarded and (ancient[0].get("provenance", {}).get(
							"sourceId") != "thread_sword_tomb_3" \
							or int(seeds[0].get("delay", -1)) != 7 \
							or seeds[0].get("originThread") != "sword_tomb_trial") \
						or not _reopen(ending):
					return _fail("sword tomb completion differs from browser: " + key + "/" + ending_direction)
	print("NONCOMBAT_SWORD_TOMB_OUTCOMES_PASS natural=true branches=6 endings=12 replay=true rollback=true")
	quit(0)


func _fork(snapshot: Dictionary, label: String) -> RefCounted:
	var path := "user://tests/sword_tomb_%s_%d.json" % [label, Time.get_ticks_usec()]
	var store = RunSession.new(path, "slot_3")
	if store.commit_snapshot(snapshot, -1).get("ok") != true:
		return null
	var branch = Domain.new(Registry.new(), store, "slot_3")
	_set_zero_rolls(branch)
	branch._normal_roll_override = 0.46
	return branch if branch.restore() else null
