extends "res://tests/noncombat_mist_valley_entry.gd"

func _run() -> void:
	var path := "user://tests/mist_outcomes_%d.json" % Time.get_ticks_usec()
	var game = Domain.new(Registry.new(), RunSession.new(path, "slot_3"), "slot_3")
	_set_zero_rolls(game)
	if not _reach_decision27(game):
		return _fail("mist endings route did not reach cave draw")
	game._normal_roll_override = CAVE_ROLL
	if not game.resume_flow() or game.get_current_card().get("id") != "q_cave" \
			or not game.choose("right", game.issue_choice_token()):
		return _fail("mist endings route did not enter cave")
	for id in ["cave_spirit", "cave_beast", "cave_reward"]:
		if game.state.get("phase") == "DESTINY_WHEEL_PENDING" and not game.choose(
				"left", game.issue_choice_token()):
			return _fail("cave destiny wheel failed")
		if game.get_current_card().get("id") != id \
				or not game.choose("left", game.issue_choice_token()):
			return _fail("cave completion failed: " + id)
	if not _advance_to(game, "thread_mist_valley_1") or not _reopen(game):
		return _fail("mist endings first node unreachable or unrestorable")
	var first_state: Dictionary = game.state.duplicate(true)
	var oracle: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(
		"res://tests/fixtures/cave_mist_source.json"))
	for first_direction in ["left", "right"]:
		var first = _fork(first_state, "first_" + first_direction)
		if first == null or not first.choose(first_direction,
				first.issue_choice_token()) or not _reopen(first):
			return _fail("first mist branch failed or did not replay: " + first_direction)
		var first_record: Dictionary = first.state.get("storyThreadState", {}).get(
			"threads", {}).get("mist_valley", {})
		if first_record.get("choices", []).size() != 1 \
				or first_record["choices"][0].get("direction") != first_direction \
				or first_record["choices"][0].get("threadDirection") != (
					"knowledge" if first_direction == "left" else "material"):
			return _fail("first mist branch history differs from browser")
		if not _advance_to(first, "thread_mist_valley_2"):
			return _fail("second mist node unreachable: " + first_direction)
		var second: Dictionary = first.get_current_card()
		var source_second: Dictionary = oracle["mist"]["branches"][
			first_direction + "_left"]["secondCard"]
		for key in ["id", "title", "description", "type", "sceneImage"]:
			if not _same(second.get(key), source_second.get(key)):
				return _fail("second mist variant differs from browser: " + first_direction + "/" + key)
		if not _reopen(first):
			return _fail("second mist node failed strict replay: " + first_direction)
		var second_state: Dictionary = first.state.duplicate(true)
		for final_direction in ["left", "right"]:
			var ending = _fork(second_state,
				first_direction + "_" + final_direction)
			if ending == null or not ending.choose(final_direction,
					ending.issue_choice_token()):
				return _fail("mist ending choice failed: " + first_direction + "/" + final_direction)
			var runtime: Dictionary = ending.state.get("storyThreadState", {}).get(
				"threads", {}).get("mist_valley", {})
			var receipt: Dictionary = runtime.get("receipt", {})
			var source_receipt: Dictionary = oracle["mist"]["branches"][
				first_direction + "_" + final_direction]["receipt"]
			if runtime.get("status") != "completed" or receipt.get("status") != "completed" \
					or receipt.get("nodes", []).size() != 2 \
					or receipt["nodes"][0].get("direction") != first_direction \
					or receipt["nodes"][1].get("direction") != final_direction \
					or receipt["nodes"][0].get("threadDirection") != source_receipt[
						"nodes"][0]["threadDirection"] \
					or ending.state.get("flags", {}).get("yuanming_legacy_found") != true:
				return _fail("mist completion receipt or world fact differs from browser")
			var seed: Dictionary = {}
			for row in ending.state.get("karmaSeeds", []):
				if row.get("id") == "yuanming_karma_mark":
					seed = row
					break
			var source_seed: Dictionary = {}
			for row in oracle["mist"]["branches"][
					first_direction + "_" + final_direction]["complete"]["karmaSeeds"]:
				if row.get("id") == "yuanming_karma_mark":
					source_seed = row
					break
			for key in ["id", "seedType", "realm", "path", "priority", "originThread",
					"originCard", "description", "consumed"]:
				if not _same(seed.get(key), source_seed.get(key)):
					return _fail("mist completion seed differs from browser: " + key)
			if seed.get("originTurn") != ending.state["runClock"]["decisionIndex"] \
					or seed.get("delay") != source_seed.get("delay") \
					or not _reopen(ending):
				return _fail("mist seed clock or ending replay failed")
	print("NONCOMBAT_MIST_VALLEY_OUTCOMES_PASS branches=4 variants=2 replay=true")
	quit(0)


func _fork(snapshot: Dictionary, label: String) -> RefCounted:
	var path := "user://tests/mist_%s_%d.json" % [label, Time.get_ticks_usec()]
	var store = RunSession.new(path, "slot_3")
	if store.commit_snapshot(snapshot, -1).get("ok") != true:
		return null
	var branch = Domain.new(Registry.new(), store, "slot_3")
	_set_zero_rolls(branch)
	branch._normal_roll_override = CAVE_ROLL
	return branch if branch.restore() else null


func _advance_to(game: RefCounted, target: String) -> bool:
	for step in 25:
		if game.state.get("phase") == "FLOW_PENDING" and not game.resume_flow():
			return false
		var card: Dictionary = game.get_current_card()
		if card.get("id") == target:
			return true
		match String(game.state.get("phase", "")):
			"WARNING_PENDING":
				var direction := "right" if game.can_choose_direction("right") else "left"
				if not game.choose(direction, game.issue_choice_token()):
					return false
			"BATTLE_PENDING":
				var request: Dictionary = game.battle_request()
				var result := {"contractVersion": 2,
					"encounterInstanceId": request.get("encounterInstanceId"),
					"sourceCardId": request.get("sourceCardId"),
					"encounterId": request.get("encounterId"),
					"sourceContentHash": request.get("sourceContentHash"),
					"outcome": "flee",
					"combatReceipt": "combat:" + String(request.get("encounterInstanceId", "")),
					"postBattleState": {"encounterInstanceId": request.get("encounterInstanceId"),
						"terminal": true, "combatPhase": "FLEE"}}
				if not game.submit_battle_result(result):
					return false
			"BATTLE_RESULT_PENDING":
				if not game.choose("down", game.issue_choice_token()):
					return false
			"VENDOR_OPEN":
				if not game.close_vendor(game.issue_choice_token()):
					return false
			_:
				var direction := ""
				for possible in ["left", "right", "down"]:
					if game.can_choose_direction(possible):
						direction = possible
						break
				if direction.is_empty() or not game.choose(direction,
						game.issue_choice_token()):
					return false
	return false
