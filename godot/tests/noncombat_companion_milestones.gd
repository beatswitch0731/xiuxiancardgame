extends SceneTree

const Events = preload("res://scripts/noncombat_companion_events.gd")
const Karma = preload("res://scripts/noncombat_karma_flow.gd")
const Domain = preload("res://scripts/noncombat_domain.gd")
const Registry = preload("res://scripts/runtime_data_registry.gd")
const RunSession = preload("res://scripts/noncombat_run_session.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var events := Events.new()
	var base := {"active": true, "phase": "FLOW_PENDING", "realm": "foundation",
		"path": "spell",
		"turn": 12, "lifeCount": 0, "flags": {},
		"runClock": {"lifeId": "companion:milestone:life:0",
			"decisionIndex": 12, "receipts": {}},
		"resources": {"companions": ["ds_demoness"], "lifespan": 70},
		"attributes": {"health": 5, "daoHeart": 10, "cultivation": 10,
			"fortune": 50, "karmaGood": 0, "karmaBad": 0, "aura": 0},
		"maxHealth": 6, "maxDaoHeart": 12,
		"npcAffection": {"ds_demoness": 18},
		"choiceHistory": [], "replayHistory": [], "recentCardTags": [],
		"cardsPlayed": [], "noncombatFlow": {}, "karmaSeeds": [],
		"decisionCheckpoint": {"sourceCardId": "prior"}}
	base.companionProgress = events.marker(0, 11)
	if base.companionProgress.has("pendingMilestones"):
		return _fail("existing v1 companion marker shape changed before activation")
	if not events.register(base, "ds_demoness", 11):
		return _fail("source NPC could not register")
	var definition: Dictionary = events._definition(events._content.read_module(
		"companions:events"), "ds_demoness")
	var source_event: Dictionary = definition.events[0]
	var ordinary: Dictionary = events._build_card(base, definition, source_event)
	var legacy: Dictionary = base.duplicate(true)
	legacy.companionProgress.erase("milestoneActivationIndex")
	legacy.phase = "COMPANION_PENDING"
	legacy.pendingCompanionCard = ordinary
	legacy.currentCardId = ordinary.id
	var legacy_choice: Dictionary = events.settle(legacy, "left")
	if legacy_choice.is_empty() \
			or legacy_choice.get("companionProgress", {}).has("pendingMilestones") \
			or legacy_choice.get("flags", {}).has(
				"comp_milestone_ds_demoness_bond_acquaint") \
			or not legacy_choice.get("karmaSeeds", []).is_empty():
		return _fail("pre-milestone companion save gained new facts during replay")
	base.phase = "COMPANION_PENDING"
	base.pendingCompanionCard = ordinary
	base.currentCardId = ordinary.id
	var chosen: Dictionary = events.settle(base, "left")
	if chosen.is_empty() or chosen.get("phase") != "NARRATIVE_RESULT_PENDING" \
			or chosen.companionProgress.pendingMilestones.size() != 1 \
			or chosen.companionProgress.pendingMilestones[0].id != "bond_acquaint" \
			or not chosen.flags.has("comp_milestone_ds_demoness_bond_acquaint") \
			or chosen.karmaSeeds[0].payoffEvent != "kx_companion_bond_acquaint":
		return _fail("event choice did not queue threshold 20 and its payoff")
	chosen.phase = "FLOW_PENDING"
	chosen.currentCardId = ""
	var waiting: Dictionary = events.take(chosen)
	var card: Dictionary = events.card(waiting)
	if waiting.get("phase") != "COMPANION_PENDING" \
			or card.get("type") != "COMPANION_MILESTONE" \
			or card.get("id") != "comp_ds_demoness_milestone_bond_acquaint" \
			or not card.get("title", "").contains("·初见") \
			or not waiting.companionProgress.pendingMilestones.is_empty():
		return _fail("P52 milestone did not take precedence over P50 event")
	var capped: Dictionary = waiting.duplicate(true)
	capped.attributes.daoHeart = capped.maxDaoHeart
	if not events.choice_available(capped, "left") \
			or events.choice_available(capped, "right"):
		return _fail("capped milestone choice ignored the executable other option")
	capped.attributes.fortune = 100
	if not events.choice_available(capped, "left") \
			or events.choice_available(capped, "right"):
		return _fail("fully capped milestone lost the source first-option fallback")
	var prior_affection := int(waiting.npcAffection.ds_demoness)
	var prior_trust := int(waiting.companionProgress.states.ds_demoness.trust)
	var settled: Dictionary = events.settle(waiting, "left")
	if settled.get("phase") != "FLOW_PENDING" \
			or int(settled.npcAffection.ds_demoness) != prior_affection \
			or int(settled.companionProgress.states.ds_demoness.trust) != prior_trust \
			or settled.cardsPlayed.count(card.id) != 1 \
			or int(settled.attributes.fortune) <= int(waiting.attributes.fortune):
		return _fail("milestone choice differs from the browser's numeric-only path: " +
			JSON.stringify({"phase": settled.get("phase"), "affection": settled.get(
				"npcAffection", {}).get("ds_demoness"), "priorAffection": prior_affection,
				"trust": settled.get("companionProgress", {}).get("states", {}).get(
					"ds_demoness", {}).get("trust"), "priorTrust": prior_trust,
				"played": settled.get("cardsPlayed", []).count(card.id),
				"fortune": settled.get("attributes", {}).get("fortune"),
				"priorFortune": waiting.attributes.fortune}))
	var cases := [
		["bond_ultimate", 99, 100, "bloodline", "kx_companion_bond_ultimate"],
		["bond_deep", 79, 80, "bloodline", "kx_companion_bond_deep"],
		["bond_trust", 49, 50, "karma", "kx_companion_bond_trust"],
		["bond_acquaint", 19, 20, "karma", "kx_companion_bond_acquaint"],
		["bond_hostile", -19, -20, "grudge", "kx_companion_bond_hostile"]]
	for entry in cases:
		var sample: Dictionary = base.duplicate(true)
		sample.phase = "FLOW_PENDING"
		sample.erase("pendingCompanionCard")
		sample.currentCardId = ""
		sample.npcAffection.ds_demoness = entry[2]
		if not events._check_milestone(sample, "ds_demoness", "魔女",
				entry[1], entry[2]):
			return _fail("threshold check rejected " + entry[0])
		if sample.companionProgress.pendingMilestones.size() != 1 \
				or sample.companionProgress.pendingMilestones[0].id != entry[0] \
				or sample.karmaSeeds[0].seedType != entry[3] \
				or sample.karmaSeeds[0].payoffEvent != entry[4]:
			return _fail("threshold or karma seed mismatch: " + entry[0])
		if not events._check_milestone(sample, "ds_demoness", "魔女",
				entry[1], entry[2]) \
				or sample.companionProgress.pendingMilestones.size() != 1:
			return _fail("one-time threshold repeated: " + entry[0])
		var pending: Dictionary = events.take(sample)
		if events.card(pending).get("id") != "comp_ds_demoness_milestone_" + entry[0]:
			return _fail("source milestone card did not project: " + entry[0])
	var dead: Dictionary = chosen.duplicate(true)
	dead.worldContinuityState = {"npcs": {"ds_demoness": {
		"lifecycle": "DEAD", "manifestation": "ECHO_ONLY"}}}
	if events.take(dead).get("phase") == "COMPANION_PENDING":
		return _fail("dead companion milestone remained playable")
	var karma := Karma.new(events._content)
	for entry in cases:
		var payoff: Dictionary = base.duplicate(true)
		payoff.phase = "FLOW_PENDING"
		payoff.currentCardId = ""
		payoff.erase("pendingCompanionCard")
		payoff.noncombatFlow = {"scope": "first_session_avoid"}
		payoff.npcAffection.ds_demoness = 30
		payoff.karmaSeeds = [{"id": "companion_milestone_ds_demoness_" + entry[0],
			"delay": 0, "priority": 4, "realm": null, "path": null,
			"payoffEvent": entry[4], "context": {"companionId": "ds_demoness",
				"companionName": "魔女", "milestoneId": entry[0]}}]
		var due: Dictionary = karma.resume(payoff)
		if due.get("phase") != "KARMA_PENDING" \
				or due.get("currentCardId") != entry[4] \
				or not String(due.pendingKarmaCard.title).contains("魔女"):
			return _fail("mature companion seed did not present its source payoff: " + entry[0] +
				" error=" + karma.last_error + " art=" + JSON.stringify(
					karma._content.card_scene_image_status(entry[4])) +
				" due=" + JSON.stringify(due))
		for direction in ["left", "right"]:
			var result: Dictionary = karma.settle(due, direction)
			var source_choice: Dictionary = due.pendingKarmaCard.choices[direction]
			if result.get("phase") != "FLOW_PENDING" \
					or not result.karmaSeeds.is_empty() \
					or not result.cardsPlayed.has(entry[4]) \
					or not result.flags.has(String(
						source_choice.effects._setFlag)) \
					or int(result.npcAffection.ds_demoness) != 30 + int(
						source_choice.companionEffects.affectionDelta):
				return _fail("companion payoff choice did not settle: " + entry[0] + direction)
			for key in ["daoHeart", "fortune", "karmaGood", "karmaBad",
					"cultivation", "health"]:
				var maximum := int(due.maxDaoHeart) if key == "daoHeart" else (
					int(due.maxHealth) if key == "health" else 100)
				var expected := clampi(int(due.attributes.get(key, 0)) + int(
					source_choice.effects.get(key, 0)), 0, maximum)
				if int(result.attributes.get(key, 0)) != expected:
					return _fail("companion payoff numeric mismatch: " + entry[0] +
						direction + "/" + key)
			for key in ["bond", "trust"]:
				var delta_key := "bondDelta" if key == "bond" else "trustDelta"
				var maximum := 5 if key == "bond" else 100
				var expected := clampi(int(due.companionProgress.states.ds_demoness[
					key]) + int(source_choice.companionEffects.get(delta_key, 0)),
					0, maximum)
				if int(result.companionProgress.states.ds_demoness[key]) != expected:
					return _fail("companion payoff relationship mismatch: " + entry[0]
						+ direction + "/" + key)
		var duplicate: Dictionary = payoff.duplicate(true)
		duplicate.cardsPlayed.append(entry[4])
		karma.close_redundant_companion_seeds(duplicate)
		if not duplicate.karmaSeeds.is_empty():
			return _fail("already-played once payoff retained a mature seed")
	var competing: Dictionary = base.duplicate(true)
	competing.phase = "FLOW_PENDING"
	competing.currentCardId = ""
	competing.erase("pendingCompanionCard")
	competing.realm = "qi"
	competing.path = "sword"
	competing.noncombatFlow = {"scope": "first_session_avoid"}
	competing.karmaSeeds = [{"id": "causal:sword_legacy_start", "delay": 0,
		"priority": 5, "path": "sword", "realm": "qi"},
		{"id": "companion_milestone_ds_demoness_bond_acquaint", "delay": 0,
		"priority": 4, "path": null, "realm": null,
		"payoffEvent": "kx_companion_bond_acquaint",
		"context": {"companionId": "ds_demoness",
			"companionName": "魔女", "milestoneId": "bond_acquaint"}}]
	var source_first: Dictionary = karma.resume(competing)
	if source_first.get("currentCardId") != "kx_path_sword_legacy":
		return _fail("higher-priority existing source karma lost to companion seed: "
			+ JSON.stringify({"card": source_first.get("currentCardId"),
				"error": karma.last_error}))
	competing.karmaSeeds[0].priority = 3
	if karma.resume(competing).get("currentCardId") != "kx_companion_bond_acquaint":
		return _fail("higher-priority companion payoff lost to existing karma")
	var game = Domain.new(Registry.new(), null, "slot_1")
	if not game.start("spell"):
		return _fail("domain opening unavailable")
	var domain_state: Dictionary = game.state.duplicate(true)
	domain_state.phase = "FLOW_PENDING"
	domain_state.realm = "foundation"
	domain_state.turn = 12
	domain_state.runClock.decisionIndex = 12
	domain_state.resources.companions = ["ds_demoness"]
	domain_state.npcAffection = {"ds_demoness": 20}
	if not game._companion_events.register(domain_state, "ds_demoness", 11) \
			or not game._companion_events._check_milestone(domain_state,
				"ds_demoness", "魔女", 19, 20):
		return _fail("domain companion milestone setup failed")
	var domain_pending: Dictionary = game._companion_events.take(domain_state)
	var cold_path := "user://tests/companion_milestone_%d_%d.json" % [
		OS.get_process_id(), Time.get_ticks_usec()]
	var cold_store = RunSession.new(cold_path, "slot_1")
	if cold_store.commit_snapshot(domain_pending, -1).get("ok") != true:
		return _fail("milestone pending card did not write to RunSession")
	var disk_snapshot: Dictionary = RunSession.new(cold_path, "slot_1").load_snapshot()
	var disk_state: Dictionary = disk_snapshot.get("state", {})
	if disk_state.get("currentCardId") != domain_pending.currentCardId \
			or Events.new().card(disk_state) != domain_pending.pendingCompanionCard:
		return _fail("milestone pending card did not cold read from RunSession visibly")
	game.state = domain_pending
	game._current_card_id = String(domain_pending.get("currentCardId", ""))
	game._choice_token = 1
	if game.get_current_card().get("type") != "COMPANION_MILESTONE" \
			or not game.choose("left", game.issue_choice_token()) \
			or game.state.get("phase") != "FLOW_PENDING" \
			or not game.state.get("cardsPlayed", []).has(
				"comp_ds_demoness_milestone_bond_acquaint"):
		return _fail("domain could not commit companion milestone choice")
	for replaying in [true, false]:
		var legacy_game = Domain.new(Registry.new(), null, "slot_1")
		if not legacy_game.start("spell"):
			return _fail("legacy companion domain opening unavailable")
		var prior: Dictionary = legacy_game.state.duplicate(true)
		prior.phase = "COMPANION_PENDING"
		prior.realm = "foundation"
		prior.turn = 12
		prior.runClock.decisionIndex = 12
		prior.resources.companions = ["ds_demoness"]
		prior.npcAffection = {"ds_demoness": 18}
		prior.noncombatFlow = {"sourceContentHash": legacy_game._battle_gateway.source_content_hash()}
		prior.decisionCheckpoint = {"sourceCardId": "prior"}
		prior.companionProgress = events.marker(0, 11, -1)
		if not events.register(prior, "ds_demoness", 11):
			return _fail("legacy companion registration failed")
		prior.pendingCompanionCard = events._build_card(prior, definition,
			source_event)
		prior.currentCardId = prior.pendingCompanionCard.id
		legacy_game.state = prior
		legacy_game._current_card_id = String(prior.currentCardId)
		legacy_game._choice_token = 1
		legacy_game._replaying_history = replaying
		if not legacy_game.choose("left", legacy_game.issue_choice_token()):
			return _fail("legacy companion choice could not settle: " +
				JSON.stringify({"replaying": replaying,
					"card": legacy_game.get_current_card().get("id"),
					"flow": legacy_game.flow_failure_reason()}))
		var has_milestone: bool = legacy_game.state.get("flags", {}).has(
			"comp_milestone_ds_demoness_bond_acquaint")
		if has_milestone == replaying \
				or legacy_game.state.companionProgress.has(
					"milestoneActivationIndex") == replaying:
			return _fail("legacy replay and live activation were not separated")
	print("NONCOMBAT_COMPANION_MILESTONES_PASS source=true thresholds=5 queue=true payoff=10 numeric=true death=true domain=true")
	quit(0)

func _fail(message: String) -> void:
	push_error(message)
	quit(1)
