extends SceneTree

const ArcFlow = preload("res://scripts/noncombat_companion_arc_flow.gd")
const Events = preload("res://scripts/noncombat_companion_events.gd")
const Domain = preload("res://scripts/noncombat_domain.gd")
const Registry = preload("res://scripts/runtime_data_registry.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var flow = ArcFlow.new()
	var prior := {"phase": "FLOW_PENDING", "turn": 0, "realm": "qi",
		"path": "sword",
		"lifeCount": 0, "resources": {"companions": ["bai_luoxuan"],
			"lifespan": 80}, "npcAffection": {"bai_luoxuan": 10},
		"npcBonds": {}, "runClock": {"lifeId": "slot_1:life:0",
			"decisionIndex": 0, "receipts": {}},
		"attributes": {"cultivation": 0, "daoHeart": 2,
			"health": 5, "fortune": 50, "karmaGood": 0,
			"karmaBad": 0, "aura": 0},
		"maxHealth": 6, "maxDaoHeart": 3, "choiceHistory": [],
		"replayHistory": [], "recentCardTags": [], "cardsPlayed": [],
		"karmaSeeds": [], "flags": {}, "noncombatFlow": {},
		"decisionCheckpoint": {"sourceCardId": "before"}}
	prior.companionProgress = Events.new().marker(0, 0)
	prior.companionArcState = flow.marker(0, 0)
	if prior.companionProgress.is_empty() or prior.companionArcState.is_empty():
		return _fail("companion arc source unavailable: " + flow.last_error)
	var candidate: Dictionary = prior.duplicate(true)
	candidate.npcAffection.bai_luoxuan = 45
	candidate.turn = 1
	candidate.runClock.decisionIndex = 1
	if not flow.advance(prior, candidate):
		return _fail("companion stage advance failed: " + flow.last_error)
	if candidate.companionArcState.pendingEvents.size() != 2:
		return _fail("crossed stages were not queued")
	var already_soup: Dictionary = candidate.duplicate(true)
	already_soup.cardsPlayed.append("sd_fd_bai_luo_soup")
	var after_semantic: Dictionary = flow.take(already_soup, "event")
	if flow.card(after_semantic).get("id") != \
			"arc_bai_luoxuan_stage_KNOWING" \
			or after_semantic.companionArcState.pendingEvents.size() != 1:
		return _fail("authored acquaintance semantic was repeated")
	var pending := flow.take(candidate, "event")
	var card := flow.card(pending)
	if card.get("id") != "arc_bai_luoxuan_stage_ACQUAINTANCE" \
			or card.get("title") != "白落霜·参汤" \
			or not String(card.get("sceneImage", "")).begins_with("assets/"):
		return _fail("first source card or portrait failed: " + flow.last_error +
			" pending=" + str(pending.get("phase")) + " card=" + str(card))
	var settled := flow.settle(pending, "left")
	if settled.get("phase") != "NARRATIVE_RESULT_PENDING" \
			or settled.get("npcAffection", {}).get("bai_luoxuan") != 53 \
			or settled.get("companionArcState", {}).get(
				"pendingEvents", []).size() != 1 \
			or settled.get("pendingNarrativeResult", {}).get(
				"originCardId") != card.id:
		return _fail("first source choice failed: " + flow.last_error)
	var five := ["bai_luoxuan", "jian_linger", "jiuwei_suyue",
		"mu_qinglan", "yin_xue"]
	for owner in five:
		var before: Dictionary = prior.duplicate(true)
		before.resources.companions = [owner]
		before.npcAffection = {owner: 0}
		before.companionArcState = flow.marker(0, 0)
		var raised: Dictionary = before.duplicate(true)
		raised.npcAffection[owner] = 95
		raised.companionProgress.states[owner].bond = 4
		raised.realm = "deity"
		if not flow.advance(before, raised) \
				or raised.companionArcState.pendingEvents.size() != 5 \
				or raised.companionArcState.pendingClimaxes.size() != 3 \
				or not flow.take(raised, "climax").is_empty():
			return _fail("five-owner stage/climax queue failed: " + owner)
		if owner == "jian_linger":
			var repaired_source: Dictionary = flow._project(owner,
				"arc_jian_linger_secret_reveal", "deity")
			if repaired_source.get("choices", {}).get("right", {}).get("text") \
					!= "也分享一个自己的秘密" \
					or repaired_source.choices.right.effects.daoHeart != 15 \
					or repaired_source.choices.right.companionEffects.trustDelta != 15:
				return _fail("browser generic fallback lost personalized relationship effects")
			raised.companionArcState.pendingEvents.clear()
			var secret_pending: Dictionary = flow.take(raised, "climax")
			var secret_prior_trust := int(secret_pending.companionProgress.states[
				owner].trust)
			var secret_chosen: Dictionary = flow.settle(secret_pending, "right")
			if secret_chosen.get("phase") != "NARRATIVE_RESULT_PENDING" \
					or int(secret_chosen.companionProgress.states[owner].trust) \
						!= secret_prior_trust + 15:
				return _fail("repaired browser right choice could not settle")
			var trib_ready: Dictionary = raised.duplicate(true)
			trib_ready.companionArcState.pendingClimaxes = [{"compId": owner,
				"cardId": "arc_jian_linger_tribulation"}]
			var trib_pending: Dictionary = flow.take(trib_ready, "climax")
			var trib_card: Dictionary = flow.card(trib_pending)
			var trib_chosen: Dictionary = flow.settle(trib_pending, "right")
			if trib_card.get("choices", {}).get("right", {}).get(
					"effects", {}).get("health") != -2 \
					or trib_chosen.get("phase") != "NARRATIVE_RESULT_PENDING" \
					or trib_chosen.resources.lifespan != trib_pending.resources.lifespan:
				return _fail("tribulation damage incorrectly changed lifespan")
	var wisdom_before: Dictionary = prior.duplicate(true)
	wisdom_before.resources.companions = ["yin_xue"]
	wisdom_before.npcAffection = {"yin_xue": 0}
	wisdom_before.companionArcState = flow.marker(0, 0)
	var wisdom_ready: Dictionary = wisdom_before.duplicate(true)
	wisdom_ready.npcAffection.yin_xue = 20
	if not flow.advance(wisdom_before, wisdom_ready):
		return _fail("wisdom source stage did not advance")
	var wisdom_pending: Dictionary = flow.take(wisdom_ready, "event")
	var wisdom_choice: Dictionary = flow.card(wisdom_pending).choices.right
	var wisdom_settled: Dictionary = flow.settle(wisdom_pending, "right")
	if wisdom_settled.get("knowledge", {}).get("wisdom") != \
			int(wisdom_choice.effects.wisdom):
		return _fail("browser wisdom effect was lost")
	var absent: Dictionary = candidate.duplicate(true)
	absent.worldContinuityState = {"version": 1, "lifeId": 0, "npcs": {}}
	var withheld: Dictionary = flow.take(absent, "event")
	if withheld.get("phase") == "COMPANION_ARC_PENDING" \
			or not withheld.get("companionArcState", {}).get(
				"pendingEvents", []).is_empty():
		return _fail("missing physical NPC still produced an arc card")
	var game = Domain.new(Registry.new(), null, "slot_1")
	if not game.start("sword"):
		return _fail("domain start failed")
	for step in 5:
		if not game.choose("left", game.issue_choice_token()):
			return _fail("domain tutorial failed")
	for action in ["right", "left"]:
		if not game.choose(action, game.issue_choice_token()):
			return _fail("domain first-session route failed")
	if not game.resume_flow():
		return _fail("domain first flow initialization failed: " +
			game.flow_failure_reason())
	var domain_prior: Dictionary = game.state.duplicate(true)
	var domain_ready: Dictionary = domain_prior.duplicate(true)
	domain_ready.phase = "FLOW_PENDING"
	domain_ready.currentCardId = ""
	domain_ready.noncombatFlow.sourceContentHash = \
		game._battle_gateway.source_content_hash()
	domain_ready.resources.companions = ["bai_luoxuan"]
	domain_ready.npcAffection = {"bai_luoxuan": 55}
	domain_ready.companionArcState = flow.marker(0, 0)
	if domain_ready.get("companionProgress") == null:
		domain_ready.companionProgress = Events.new().marker(0, 0)
	domain_ready.companionProgress.states.bai_luoxuan.bond = 2
	var low: Dictionary = domain_ready.duplicate(true)
	low.npcAffection.bai_luoxuan = 10
	low.companionProgress.states.bai_luoxuan.bond = 0
	if not flow.advance(low, domain_ready):
		return _fail("domain arc queue setup failed")
	var direct: Dictionary = flow.take(domain_ready, "event")
	game.state = direct
	game._current_card_id = card.id
	var domain_card: Dictionary = game.get_current_card()
	var chosen: bool = game.choose("left", game.issue_choice_token()) \
		if domain_card.get("id") == card.id else false
	if domain_card.get("id") != card.id \
			or not chosen \
			or game.state.get("phase") != "NARRATIVE_RESULT_PENDING" \
			or game.state.get("companionArcState", {}).get(
				"pendingEvents", []).size() != 2 \
			or game.state.get("companionArcState", {}).get(
				"pendingClimaxes", []).size() != 1 \
			or game.state.companionArcState.states.bai_luoxuan.stageIndex != 3:
		return _fail("domain arc choice failed: " +
			JSON.stringify({"card": domain_card.get("id"),
				"chosen": chosen, "phase": game.state.get("phase"),
				"pending": game.state.get("companionArcState", {}).get(
					"pendingEvents", []).size(),
				"directPhase": direct.get("phase"),
				"arcError": flow.last_error,
				"reason": game.flow_failure_reason()}))
	print("NONCOMBAT_COMPANION_ARC_FLOW_PASS owners=5 stages=5 climaxes=3 " +
		"semantic=true physical=true fallback=true wisdom=true domain=true")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
