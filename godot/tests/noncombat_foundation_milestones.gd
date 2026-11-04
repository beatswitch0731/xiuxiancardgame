extends "res://tests/noncombat_foundation_normal_pool.gd"

const MilestoneFlow = preload("res://scripts/noncombat_milestone_flow.gd")


func _run() -> void:
	var game = Domain.new(Registry.new(), null, "slot_3")
	if not game.start("spell"):
		return _fail("foundation milestone fixture could not start")
	var state: Dictionary = game.state.duplicate(true)
	state.phase = "FLOW_PENDING"
	state.realm = "foundation"
	state.attributes.cultivation = 100
	state["noncombatFlow"] = {"scope": "first_session_combat"}
	state["decisionCheckpoint"] = {"sourceCardId": "epiphany_foundation"}
	var flow = MilestoneFlow.new(ContentRepository.new())
	for threshold in [20, 40, 60, 80]:
		var card_id := "ch_foundation_%d" % threshold
		var pending: Dictionary = flow.resume(state) if state.phase == "FLOW_PENDING" else state
		if pending.get("currentCardId") != card_id \
				or pending.get("phase") != "MILESTONE_PENDING":
			return _fail("foundation milestone %d was not scheduled" % threshold)
		var card: Dictionary = pending.get("pendingMilestoneCard", {})
		if card.get("id") != card_id or card.get("realm") != "foundation" \
				or String(card.get("sceneImage", "")).is_empty() \
				or Registry.new().texture_for(String(card.sceneImage)) == null \
				or card.get("bossJourneyStage", {}).get("canonicalThreshold") != threshold:
			return _fail("foundation milestone %d source projection invalid" % threshold)
		if threshold == 20 and card.get("_pathVariant", {}).get("path") != "spell":
			return _fail("foundation first milestone lost spell source variant")
		if threshold == 80:
			var marker: String = String(card.get("narrativeSpine", {}).get(
				"presentation", {}).get("echo", {}).get("marker", ""))
			if marker.is_empty() or not String(card.description).contains(marker):
				return _fail("foundation mirror milestone lost earlier chapter echo")
		state = flow.settle(pending, "left")
		if state.is_empty() or not state.get("cardsPlayed", []).has(card_id):
			return _fail("foundation milestone %d did not settle" % threshold)
	if state.get("chapterProgress", {}).get("triggeredMilestones", {}).get(
			"foundation", []) != [20, 40, 60, 80]:
		return _fail("foundation milestone progress differs")
	print("NONCOMBAT_FOUNDATION_MILESTONES_PASS milestones=4 source=true spine=true")
	quit(0)
