extends SceneTree

const AllyFlow = preload("res://scripts/noncombat_ally_arc_flow.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var flow = AllyFlow.new()
	var prior := {"phase": "FLOW_PENDING", "turn": 0,
		"realm": "qi", "lifeCount": 0,
		"runClock": {"lifeId": "slot_1:life:0", "decisionIndex": 0,
			"receipts": {}},
		"attributes": {"cultivation": 20, "daoHeart": 2,
			"health": 5, "fortune": 50, "karmaGood": 0,
			"karmaBad": 0, "aura": 0},
		"maxHealth": 6, "maxDaoHeart": 3,
		"choiceHistory": [], "replayHistory": [], "recentCardTags": [],
		"cardsPlayed": [], "karmaSeeds": [],
		"noncombatFlow": {"sourceContentHash": "test"},
		"decisionCheckpoint": {"sourceCardId": "before"}}
	prior["allyArcState"] = flow.marker(0)
	if prior.allyArcState.is_empty():
		return _fail("ally arc source unavailable")
	var candidate: Dictionary = prior.duplicate(true)
	candidate["turn"] = 1
	candidate["runClock"]["decisionIndex"] = 1
	candidate["attributes"]["karmaBad"] = 40
	candidate["choiceHistory"].append({"cardId": "test_blood",
		"direction": "left", "decisionIndex": 1, "tags": ["blood"]})
	if not flow.advance(prior, candidate) \
			or candidate.allyArcState.alignment != 23 \
			or candidate.allyArcState.pendingStages != ["RECOGNITION"]:
		return _fail("bad-karma and blood-tag source progression failed")
	var pending: Dictionary = flow.take(candidate, "event")
	var card: Dictionary = flow.card(pending)
	if pending.get("phase") != "ALLY_PENDING" \
			or card.get("id") != "ally_xuesha_laozu_stage_RECOGNITION" \
			or card.get("title") != "盟友·剑灵之死" \
			or card.get("choices", {}).get("left", {}).get(
				"effects", {}).get("karmaGood") != 10:
		return _fail("authored ally stage or portrait did not project")
	var settled: Dictionary = flow.settle(pending, "left")
	if settled.get("phase") != "NARRATIVE_RESULT_PENDING" \
			or settled.get("attributes", {}).get("karmaGood") != 10 \
			or settled.get("allyArcState", {}).get("eventsTriggered") != [
				"ally_xuesha_laozu_stage_RECOGNITION"] \
			or settled.get("runClock", {}).get("decisionIndex") != 2 \
			or not String(settled.get("currentCardId", "")).begins_with(
				"promise_result_"):
		return _fail("ally choice or immediate relationship response failed: " +
			flow.last_error)
	if not flow.settle(settled, "left").is_empty():
		return _fail("ally choice settled twice")
	var high := prior.duplicate(true)
	high["realm"] = "deity"
	high["turn"] = 1
	high["runClock"]["decisionIndex"] = 1
	high["attributes"]["karmaBad"] = 100
	high["choiceHistory"].append({"cardId": "victory",
		"direction": "left", "decisionIndex": 1,
		"tags": ["blood"], "combatOutcome": "victory"})
	if not flow.advance(prior, high) \
			or high.allyArcState.pendingStages != [
				"RECOGNITION", "TRUST", "COMRADE", "LEGACY"] \
			or high.allyArcState.pendingClimaxes != [
				"revelation", "tribulation", "destiny"] \
			or not flow.take(high, "climax").is_empty():
		return _fail("multi-threshold ally queue or climax ordering failed: " +
			str(high.allyArcState))
	var no_clock := prior.duplicate(true)
	no_clock["attributes"]["karmaBad"] = 5
	if not flow.advance(prior, no_clock) or no_clock.allyArcState.alignment != 3:
		return _fail("no-clock bad-karma attribute event was lost")
	high["allyArcState"]["pendingStages"] = []
	var climax: Dictionary = flow.take(high, "climax")
	if flow.card(climax).get("semanticKey") != \
			"card:ally_xuesha_laozu_revelation":
		return _fail("source climax semantic identity changed")
	print("NONCOMBAT_ALLY_ARC_FLOW_PASS stage=true promise=true thresholds=true")
	quit(0)

func _fail(message: String) -> void:
	push_error(message)
	quit(1)
