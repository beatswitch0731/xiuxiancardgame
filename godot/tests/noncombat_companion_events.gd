extends SceneTree

const Events = preload("res://scripts/noncombat_companion_events.gd")
const WorldContinuity = preload("res://scripts/noncombat_world_continuity.gd")
const Registry = preload("res://scripts/runtime_data_registry.gd")
const Domain = preload("res://scripts/noncombat_domain.gd")
const NormalChoicePolicy = preload("res://scripts/noncombat_normal_choice_policy.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var events := Events.new()
	var state := {"active": true, "phase": "FLOW_PENDING",
		"realm": "foundation", "turn": 12,
		"runClock": {"lifeId": "companion:test:0", "decisionIndex": 12,
			"receipts": {}},
		"resources": {"companions": ["bai_luoxuan"], "lifespan": 70},
		"attributes": {"health": 5, "daoHeart": 10, "cultivation": 10,
			"fortune": 50, "karmaGood": 0, "karmaBad": 0},
		"maxHealth": 6, "maxDaoHeart": 12,
		"npcAffection": {"bai_luoxuan": 35},
		"choiceHistory": [], "replayHistory": [], "recentCardTags": [],
		"cardsPlayed": [], "noncombatFlow": {},
		"decisionCheckpoint": {"sourceCardId": "prior"}}
	state["companionProgress"] = events.marker(0, 11)
	if state.companionProgress.is_empty() or not events.valid(state):
		return _fail("source-backed companion state unavailable")
	var selected := {}
	for i in range(1000):
		state.runClock.lifeId = "companion:test:%d" % i
		var result: Dictionary = events.take(state)
		if result.get("phase") == "COMPANION_PENDING":
			selected = result
			break
	if selected.is_empty():
		return _fail("P50 event never selected from a living owned companion")
	var registered := state.duplicate(true)
	registered.worldContinuityState = WorldContinuity.initial(events._content, 0).get("state", {})
	if events.take(registered).get("phase") != "COMPANION_PENDING":
		return _fail("registered current-life companion lost its source event")
	var card: Dictionary = events.card(selected)
	if card.is_empty() or card.get("compId") != "bai_luoxuan" \
			or card.get("id") != "comp_bai_luoxuan_blx_1" \
			or events._content.find("generated_card", card.id).get("data", {}).get("id") != "blx_1" \
			or not events.choice_available(selected, "left"):
		return _fail("pending event does not project its source choice")
	var before_affection := int(selected.npcAffection.bai_luoxuan)
	var before_heart := int(selected.attributes.daoHeart)
	var chosen: Dictionary = events.settle(selected, "left")
	if chosen.is_empty() or chosen.get("phase") != "NARRATIVE_RESULT_PENDING" \
			or chosen.get("cardsPlayed", []).count(card.id) != 1 \
			or int(chosen.runClock.decisionIndex) != 13 \
			or chosen.pendingNarrativeResult.get("originCardId") != card.id \
			or chosen.noncombatFlow.promise.get("sourceCardId") != card.id \
			or int(chosen.npcAffection.bai_luoxuan) != clampi(before_affection \
				+ int(card.choices.left.companionEffects.affectionDelta), -50, 100) \
			or int(chosen.attributes.daoHeart) < before_heart:
		return _fail("companion choice did not settle once")
	if not events.settle(selected, "left").has("runClock"):
		return _fail("same pending source could not replay deterministically")
	var exhausted := chosen.duplicate(true)
	exhausted["turn"] = 24
	exhausted.runClock.decisionIndex = 24
	exhausted.companionProgress.checkedTurn = 23
	exhausted.companionProgress.cooldowns.bai_luoxuan = 0
	var replay: Dictionary = events.take(exhausted)
	if replay.get("phase") == "COMPANION_PENDING" \
			and replay.get("currentCardId") == card.id:
		return _fail("resolved one-time event appeared again")
	var dead := state.duplicate(true)
	dead["worldContinuityState"] = {"npcs": {"bai_luoxuan": {
		"lifecycle": "DEAD", "manifestation": "ECHO_ONLY"}}}
	if events.take(dead).get("phase") == "COMPANION_PENDING":
		return _fail("dead companion appeared physically")
	var absent := state.duplicate(true)
	absent["worldContinuityState"] = {"version": 1, "lifeId": 0,
		"npcs": {}}
	if events.take(absent).get("phase") == "COMPANION_PENDING":
		return _fail("companion missing from the current-life NPC registry appeared")
	var prior_life := state.duplicate(true)
	prior_life["lifeCount"] = 1
	prior_life["worldContinuityState"] = {"version": 1, "lifeId": 0,
		"npcs": {"bai_luoxuan": {"npcId": "bai_luoxuan", "lifeId": 0,
			"lifecycle": "ACTIVE", "manifestation": "PHYSICAL"}}}
	if events.take(prior_life).get("phase") == "COMPANION_PENDING":
		return _fail("previous-life companion appeared in the current life")
	var bond_state := state.duplicate(true)
	bond_state.npcAffection.bai_luoxuan = 54
	var bond_owner: Dictionary = events._definition(
		events._content.read_module("companions:events"), "bai_luoxuan")
	var bond_card: Dictionary = events._build_card(bond_state, bond_owner,
		bond_owner.events[0])
	bond_state.phase = "COMPANION_PENDING"
	bond_state.currentCardId = bond_card.id
	bond_state.pendingCompanionCard = bond_card
	var bonded: Dictionary = events.settle(bond_state, "left")
	if bonded.is_empty() or int(bonded.get("npcBonds", {}).get(
			"bai_luoxuan", 0)) < 2:
		return _fail("NPC affection threshold did not advance its bond")
	var generic := state.duplicate(true)
	generic.resources.companions = ["ds_demoness"]
	generic.npcAffection = {"ds_demoness": 10}
	if not events.register(generic, "ds_demoness", 11) \
			or generic.companionProgress.cooldowns.ds_demoness != 8:
		return _fail("owned source NPC did not register its generic companion state")
	var cooling: Dictionary = events.take(generic)
	if cooling.get("phase") != "FLOW_PENDING" \
			or cooling.companionProgress.cooldowns.ds_demoness != 7:
		return _fail("registration cooldown did not tick on the next turn")
	generic.companionProgress.cooldowns.ds_demoness = 0
	var generic_event := {}
	for i in range(1000):
		generic.runClock.lifeId = "generic:test:%d" % i
		var result: Dictionary = events.take(generic)
		if result.get("phase") == "COMPANION_PENDING":
			generic_event = result
			break
	if generic_event.is_empty() or not String(generic_event.currentCardId).begins_with(
			"comp_ds_demoness_generic_") \
			or events.card(generic_event).is_empty() \
			or events.settle(generic_event, "left").is_empty():
		return _fail("source NPC generic companion event was not playable")
	var generic_card: Dictionary = events.card(generic_event)
	var generic_chosen: Dictionary = events.settle(generic_event, "left")
	var generic_owner: Dictionary = events._definition(
		events._content.read_module("companions:events"), "ds_demoness")
	generic_chosen.turn = 24
	if events._eligible(generic_chosen, "ds_demoness", generic_card.compEvent,
			int(generic_chosen.npcAffection.ds_demoness),
			generic_chosen.companionProgress.states.ds_demoness):
		return _fail("generic event repeated within its 12-decision cooldown")
	generic_chosen.turn = 25
	if generic_owner.is_empty() or not events._eligible(generic_chosen,
			"ds_demoness", generic_card.compEvent,
			int(generic_chosen.npcAffection.ds_demoness),
			generic_chosen.companionProgress.states.ds_demoness):
		return _fail("generic event stayed blocked after cooldown")
	var generic_source: Dictionary = events._content._indexes[
		"generated_card"][generic_card.id]
	var original_source_event: String = generic_source.eventId
	generic_source.eventId = "forged"
	if not events.card(generic_event).is_empty():
		return _fail("generic companion cold card accepted a forged source registry")
	generic_source.eventId = original_source_event
	if events.register(generic, "whiteFox", 11):
		return _fail("unknown raw author ID was falsely registered")
	var data: Dictionary = events._content.read_module("companions:events")
	var covered := 0
	var sacrifice_seen := 0
	for definition in data.companions:
		for event in definition.events:
			if event.get("id") == "jle_8_sword_tomb_old_master":
				continue
			if event.has("sceneImage"):
				var asset: Dictionary = events._content.asset_status(String(event.sceneImage))
				if not asset.get("shaVerified", false) \
						or not asset.get("textureLoadable", false):
					return _fail("authored companion scene image is unavailable")
			var authored := state.duplicate(true)
			authored.realm = event.get("realm", "foundation")
			authored.resources.companions = [definition.id]
			authored.companionProgress.states[definition.id].bond = 5
			authored.npcAffection[definition.id] = 100
			var projected: Dictionary = events._build_card(authored, definition, event)
			authored.phase = "COMPANION_PENDING"
			authored.currentCardId = projected.id
			authored.pendingCompanionCard = projected
			if events.card(authored).is_empty():
				return _fail("authored event did not round-trip: " + String(event.id))
			for direction in projected.choices:
				var settled: Dictionary = events.settle(authored, String(direction))
				if settled.is_empty():
					return _fail("authored event choice did not settle: " + String(event.id))
				var harmful := int(projected.choices[direction].effects.get("health", 0)) < 0 \
					or int(projected.choices[direction].effects.get("daoHeart", 0)) < 0
				if int(settled.resources.lifespan) != int(authored.resources.lifespan) \
						- (1 if harmful else 0):
					return _fail("authored event lifespan cost differs from source")
				if int(projected.choices[direction].companionEffects.affectionDelta) <= -20:
					if not settled.get("karmaSeeds", []).any(func(seed: Variant) -> bool:
						return seed.get("id") == "companionSacrifice"):
						return _fail("betrayal choice did not plant its source karma seed")
					sacrifice_seen += 1
			covered += 1
	if covered != 37 or sacrifice_seen != 2:
		return _fail("noncombat event coverage differs from the source catalog")
	if not _verify_world_passive():
		return
	print("NONCOMBAT_COMPANION_EVENTS_PASS source=true p50=true settle=true once=true death=true choices=37 betrayal=2 generic=true")
	quit(0)


func _verify_world_passive() -> bool:
	var game = Domain.new(Registry.new(), null, "slot_3")
	if not game.start("sword"):
		_fail("source opening unavailable for companion passive")
		return false
	var policy = NormalChoicePolicy.new(game._content)
	var baseline: Dictionary = game.state.duplicate(true)
	baseline.attributes.health = 1
	baseline.resources.companions = []
	if not policy._apply_passive_regen(baseline):
		_fail("baseline passive could not settle")
		return false
	var present: Dictionary = game.state.duplicate(true)
	present.attributes.health = 1
	present.resources.companions = ["bai_luoxuan"]
	var absent: Dictionary = present.duplicate(true)
	absent.worldContinuityState.npcs.erase("bai_luoxuan")
	var old_life: Dictionary = present.duplicate(true)
	old_life.lifeCount = 1
	if not policy._apply_passive_regen(present) \
			or not policy._apply_passive_regen(absent) \
			or not policy._apply_passive_regen(old_life) \
			or int(present.attributes.health) <= int(baseline.attributes.health) \
			or int(absent.attributes.health) != int(baseline.attributes.health) \
			or int(old_life.attributes.health) != int(baseline.attributes.health):
		_fail("missing or previous-life companion granted a physical passive")
		return false
	return true

func _fail(message: String) -> void:
	push_error(message)
	quit(1)
