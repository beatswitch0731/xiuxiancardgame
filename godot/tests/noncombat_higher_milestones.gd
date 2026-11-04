extends "res://tests/noncombat_foundation_normal_pool.gd"

const MilestoneFlow = preload("res://scripts/noncombat_milestone_flow.gd")


func _run() -> void:
	var source := {"golden": [20, 45, 65, 85],
		"nascent": [25, 50, 70, 90],
		"deity": [30, 55, 75, 95],
		"tribulation": [20, 38, 55, 72]}
	var aliases := {"golden": [20, 40, 60, 80],
		"nascent": [20, 40, 60, 80],
		"deity": [20, 40, 60, 80],
		"tribulation": [20, 40, 60, 80]}
	var flow = MilestoneFlow.new(ContentRepository.new())
	for realm in source:
		var game = Domain.new(Registry.new(), null, "slot_3")
		if not game.start("spell"):
			return _fail("higher chapter fixture could not start")
		var state: Dictionary = game.state.duplicate(true)
		state.phase = "FLOW_PENDING"
		state.realm = realm
		state.attributes.cultivation = 100
		state["noncombatFlow"] = {"scope": "first_session_combat"}
		state["decisionCheckpoint"] = {"sourceCardId": "realm_arrival_" + realm}
		for index in 4:
			var threshold: int = source[realm][index]
			var expected_id := "ch_%s_%d" % [realm, aliases[realm][index]]
			var pending: Dictionary = flow.resume(state) if state.phase == "FLOW_PENDING" else state
			if pending.get("phase") != "MILESTONE_PENDING" \
					or pending.get("currentCardId") != expected_id:
				return _fail("higher chapter did not schedule " + expected_id)
			var card: Dictionary = pending.get("pendingMilestoneCard", {})
			if card.get("threshold") != threshold \
					or card.get("bossJourneyStage", {}).get("canonicalThreshold") != aliases[realm][index] \
					or Registry.new().texture_for(String(card.get("sceneImage", ""))) == null:
				return _fail("higher chapter source projection invalid: " + expected_id)
			state = flow.settle(pending, "left")
			if state.is_empty() or not state.get("cardsPlayed", []).has(expected_id):
				return _fail("higher chapter did not settle: " + expected_id)
	print("NONCOMBAT_HIGHER_MILESTONES_PASS realms=4 milestones=16 source=true")
	quit(0)
