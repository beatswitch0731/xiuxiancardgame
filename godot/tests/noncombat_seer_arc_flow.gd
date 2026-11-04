extends SceneTree

const SeerFlow = preload("res://scripts/noncombat_seer_arc_flow.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var flow = SeerFlow.new()
	var prior := {"phase": "FLOW_PENDING", "turn": 0,
		"realm": "qi", "lifeCount": 0,
		"runClock": {"lifeId": "slot_1:life:0", "decisionIndex": 0,
			"receipts": {}},
		"attributes": {"cultivation": 20, "daoHeart": 0,
			"health": 5, "fortune": 50, "karmaGood": 0,
			"karmaBad": 0, "aura": 0},
		"maxHealth": 6, "maxDaoHeart": 3,
		"choiceHistory": [], "replayHistory": [], "recentCardTags": [],
		"cardsPlayed": [], "karmaSeeds": [],
		"noncombatFlow": {"sourceContentHash": "test"},
		"decisionCheckpoint": {"sourceCardId": "before"}}
	prior["seerArcState"] = flow.marker(0)
	if prior.seerArcState.is_empty():
		return _fail("seer source unavailable")
	var candidate: Dictionary = prior.duplicate(true)
	candidate["turn"] = 1
	candidate["runClock"]["decisionIndex"] = 1
	candidate["attributes"]["daoHeart"] = 100
	candidate["choiceHistory"].append({"cardId": "test_secret",
		"direction": "left", "decisionIndex": 1, "tags": ["secret"]})
	if not flow.advance(prior, candidate) \
			or candidate.seerArcState.revelation != 23 \
			or candidate.seerArcState.pendingStages != ["REVELATION"]:
		return _fail("dao-heart and secret-tag progression failed")
	var pending: Dictionary = flow.take(candidate, "event")
	var card: Dictionary = flow.card(pending)
	if pending.get("phase") != "SEER_PENDING" \
			or card.get("id") != "seer_tianji_laoren_stage_REVELATION" \
			or card.get("choices", {}).get("left", {}).get(
				"effects", {}).get("daoHeart") != 20:
		return _fail("authored seer stage or portrait did not project")
	var settled: Dictionary = flow.settle(pending, "left")
	if settled.get("phase") != "NARRATIVE_RESULT_PENDING" \
			or settled.get("attributes", {}).get("fortune") != 60 \
			or settled.get("seerArcState", {}).get("eventsTriggered") != [
				"seer_tianji_laoren_stage_REVELATION"] \
			or settled.get("runClock", {}).get("decisionIndex") != 2 \
			or not String(settled.get("currentCardId", "")).begins_with(
				"promise_result_"):
		return _fail("seer choice or response failed: " + flow.last_error)
	if not flow.settle(settled, "left").is_empty():
		return _fail("seer choice settled twice")
	var no_clock := prior.duplicate(true)
	no_clock["attributes"]["daoHeart"] = 5
	if not flow.advance(prior, no_clock) or no_clock.seerArcState.revelation != 1:
		return _fail("no-clock dao-heart attribute event was lost")
	var high := prior.duplicate(true)
	high["seerArcState"]["revelation"] = 80
	high["realm"] = "deity"
	high["turn"] = 1
	high["runClock"]["decisionIndex"] = 1
	high["attributes"]["daoHeart"] = 100
	if not flow.advance(prior, high) \
			or high.seerArcState.pendingStages != [
				"REVELATION", "UNVEILING", "SACRIFICE", "FINAL_PROPHECY"] \
			or high.seerArcState.pendingClimaxes != [
				"revelation", "tribulation", "destiny"] \
			or not flow.take(high, "climax").is_empty():
		return _fail("multi-threshold seer queue or climax ordering failed")
	high["seerArcState"]["pendingStages"] = []
	var climax: Dictionary = flow.take(high, "climax")
	if flow.card(climax).get("semanticKey") != \
			"card:seer_tianji_laoren_revelation":
		return _fail("seer climax semantic identity changed")
	print("NONCOMBAT_SEER_ARC_FLOW_PASS stage=true promise=true thresholds=true")
	quit(0)

func _fail(message: String) -> void:
	push_error(message)
	quit(1)
