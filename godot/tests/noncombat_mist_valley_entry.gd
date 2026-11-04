extends "res://tests/noncombat_cave_entry.gd"

func _run() -> void:
	var path := "user://tests/mist_valley_%d.json" % Time.get_ticks_usec()
	var game = Domain.new(Registry.new(), RunSession.new(path, "slot_3"), "slot_3")
	_set_zero_rolls(game)
	if not _reach_decision27(game):
		return _fail("mist route did not reach ordinary cave draw")
	game._normal_roll_override = CAVE_ROLL
	if not game.resume_flow() or game.get_current_card().get("id") != "q_cave" \
			or not game.choose("right", game.issue_choice_token()):
		return _fail("mist route did not enter authored cave")
	for id in ["cave_spirit", "cave_beast", "cave_reward"]:
		if game.state.get("phase") == "DESTINY_WHEEL_PENDING":
			if not game.choose("left", game.issue_choice_token()):
				return _fail("intervening destiny wheel was not resolved")
		if game.get_current_card().get("id") != id \
				or not game.choose("left", game.issue_choice_token()):
			return _fail("mist route did not complete cave node: " + id)
	if game.state.get("storyThreadState", {}).get("threads", {}).get(
			"mist_valley", {}).get("status") != "active":
		return _fail("mist did not activate on cave success receipt")
	var first: Dictionary = {}
	for step in 20:
		if game.state.get("phase") == "FLOW_PENDING" and not game.resume_flow():
			return _fail("mist route could not resume: " + game.flow_failure_reason())
		first = game.get_current_card()
		if first.get("id") == "thread_mist_valley_1":
			break
		match String(game.state.get("phase", "")):
			"WARNING_PENDING":
				var direction := "right" if game.can_choose_direction("right") \
					else "left"
				if not game.choose(direction, game.issue_choice_token()):
					return _fail("mist route could not confirm warning")
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
					return _fail("mist route could not settle intervening battle")
			"BATTLE_RESULT_PENDING":
				if not game.choose("down", game.issue_choice_token()):
					return _fail("mist route could not dismiss battle result")
			"VENDOR_OPEN":
				if not game.close_vendor(game.issue_choice_token()):
					return _fail("mist route could not close vendor")
			_:
				var direction := ""
				for candidate in ["left", "right", "down"]:
					if game.can_choose_direction(candidate):
						direction = candidate
						break
				if direction.is_empty() or not game.choose(direction,
						game.issue_choice_token()):
					return _fail("mist route stopped before first node: %s/%s" % [
						game.state.get("phase"), first.get("id")])
	if first.get("id") != "thread_mist_valley_1":
		return _fail("successful cave did not reach first mist node")
	var source_threads: Array = game._content.read_module("threads:qi_threads")["threads"]
	var definition: Dictionary = {}
	for thread in source_threads:
		if thread.get("threadId") == "mist_valley":
			definition = thread
			break
	for key in ["id", "semanticKey", "title", "description", "type", "choices", "sceneImage"]:
		var expected: Variant = definition.get("nodes", [])[0].get("card", {}).get(key)
		if key == "choices":
			var actual: Dictionary = first.get("choices", {}).duplicate(true)
			for choice in actual.values():
				choice.erase("_threadDirection")
			if not _same(actual, expected):
				return _fail("first mist node choices differ from source")
		elif not _same(first.get(key), expected):
			return _fail("first mist node differs from source: " + key)
	if not _reopen(game):
		return _fail("first mist node failed strict cold restore")
	print("NONCOMBAT_MIST_VALLEY_ENTRY_PASS cave=true receipt=true first_node=true replay=true")
	quit(0)
