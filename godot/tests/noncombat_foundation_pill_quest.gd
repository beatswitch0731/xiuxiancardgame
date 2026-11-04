extends "res://tests/noncombat_foundation_body_quest.gd"

func _run() -> void:
	var game = Domain.new(Registry.new(), null, "slot_2")
	if not game.start("pill"):
		return _fail("pill quest fixture could not start")
	var state: Dictionary = game.state.duplicate(true)
	state.phase = "FLOW_PENDING"
	state.realm = "foundation"
	state.turn = 15
	state.runClock.decisionIndex = 15
	state.attributes.health = 80
	state.attributes.fortune = 60
	state["flags"] = {}
	state["knowledge"] = {}
	state["karmaSeeds"] = []
	state["karmaPromiseFlags"] = {}
	state["noncombatFlow"] = {"scope": "first_session_combat"}
	state["decisionCheckpoint"] = {"sourceCardId": "epiphany_foundation"}
	state.questState = {"saveVersion": 3, "activeQuests": [],
		"completedQuests": [], "closedQuests": [], "questOutcomes": {}}
	var flow = QuestFlow.new(ContentRepository.new())
	var first: Dictionary = flow.resume(state)
	if first.get("currentCardId") != "q_pill_1":
		return _fail("pill quest did not enter at foundation")
	var refused: Dictionary = flow.settle(first, "right")
	if refused.get("questState", {}).get("questOutcomes", {}).get(
			"pill_master") != "abandoned" \
			or refused.get("flags", {}).get("pillMasterCompleted") == true:
		return _fail("pill quest refusal awarded completion")
	var second: Dictionary = flow.settle(first, "left")
	var third: Dictionary = flow.settle(second, "left")
	var fourth: Dictionary = flow.settle(third, "left")
	if second.get("currentCardId") != "q_pill_2" \
			or third.get("currentCardId") != "q_pill_3" \
			or fourth.get("currentCardId") != "q_pill_4" \
			or int(fourth.get("knowledge", {}).get("pill", -1)) != 2 \
			or fourth.get("flags", {}).get("pillMasterFiveBatch") != true \
			or fourth.get("flags", {}).get("pillMasterDestroyed") != true \
			or not fourth.get("karmaSeeds", []).any(
				func(seed: Variant) -> bool: return seed is Dictionary \
					and seed.get("id") == "pillMasterSacrifice"):
		return _fail("pill quest four-card chain or insight/seed missing: " +
			flow.last_error)
	var finished: Dictionary = flow.settle(fourth, "left")
	if finished.get("questState", {}).get("questOutcomes", {}).get(
			"pill_master") != "completed" \
			or finished.get("flags", {}).get("pillMasterCompleted") != true \
			or finished.get("opportunityAcquisitions", {}).get(
				"pill_master_completion_v1", {}).get("profile") != "restraint_vow" \
			or not finished.get("karmaSeeds", []).any(
				func(seed: Variant) -> bool: return seed is Dictionary \
					and seed.get("id") == "pillMasterEcho"):
		return _fail("pill quest completion reward or echo missing: " +
			flow.last_error)
	print("NONCOMBAT_FOUNDATION_PILL_QUEST_PASS entry=true refusal=true insight=true reward=true")
	quit(0)
