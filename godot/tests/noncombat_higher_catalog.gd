extends "res://tests/noncombat_foundation_catalog.gd"


func _run() -> void:
	var game = Domain.new(Registry.new(), null, "slot_3")
	if not game.start("sword"):
		return _fail("higher realm catalog fixture could not start")
	var catalog = CatalogEncounter.new(ContentRepository.new())
	var gateway = BattleGateway.new(Registry.new())
	var cadence = CadenceFlow.new(ContentRepository.new(), gateway)
	for realm in ["golden", "nascent", "deity", "tribulation"]:
		var state: Dictionary = game.state.duplicate(true)
		state.phase = "FLOW_PENDING"
		state.realm = realm
		state.turn = 1
		state.runClock.decisionIndex = 1
		state.encounterCadence = cadence.marker(1, 1)
		state.noncombatFlow = {"scope": "first_session_combat"}
		state.noncombatFlow.encounterDirectorState = cadence.initial_state(0)
		state.noncombatFlow.encounterDirectorState.firstTeachingStatus = "resolved"
		state.noncombatFlow.encounterDirectorState.nextDueDecision = 2
		var candidates: Array = catalog.candidates(state)
		if not candidates.any(func(row: Variant) -> bool:
			return row is Dictionary and row.get("realm") == realm \
				and row.get("encounterRole") == "ordinary"):
			return _fail("higher realm ordinary quota catalog absent: " + realm)
		var offered: Dictionary = cadence.resume(state)
		if offered.get("phase") != "COMBAT_HANDOFF" or not String(
				offered.get("currentCardId", "")).begins_with("encounter_card_"):
			return _fail("higher realm cadence offer failed: " + realm + " " + cadence.last_error \
				+ " gateway=" + gateway.source_error + " card=" + str(offered.get("currentCardId")))
		var encounter = EncounterFlow.new(ContentRepository.new(), gateway)
		var accepted: Dictionary = encounter.accept(offered)
		var prepared: Dictionary = encounter.confirm(accepted, "left")
		var request: Dictionary = gateway.build_request(prepared)
		if accepted.get("phase") != "WARNING_PENDING" \
				or prepared.get("phase") != "BATTLE_PENDING" \
				or request.get("sourceCardId") != offered.currentCardId:
			return _fail("higher realm battle request failed: " + realm)
		var resolver = BattlePlanResolver.new(Registry.new())
		var plan: Dictionary = resolver.resolve_persisted(prepared)
		var combat = CombatDomain.new(Registry.new())
		if plan.get("launchAuthorized") != true \
				or not combat.load_persisted_request(request, plan):
			return _fail("higher realm combat plan failed: " + realm + " " + resolver.last_error \
				+ " launch=" + str(plan.get("launchAuthorized")) + " scene=" + str(plan.get(
					"sceneAvailable")))
		var context: Dictionary = load("res://scripts/combat_stage_router.gd").new(
			Registry.new()).resolve_choice(String(request.sourceCardId), "left",
			request.pendingResolution.combatCard, String(request.encounterInstanceId),
			request.pendingResolution, String(request.path), String(request.realm))
		context.deck = plan.deck.duplicate(true)
		var stage: Control = load(String(plan.stageScene)).instantiate()
		if not stage.bind_stage_context(context):
			stage.free()
			return _fail("higher realm stage bind failed: " + realm)
		root.add_child(stage)
		if not stage.has_hd2d_assets():
			stage.queue_free()
			return _fail("higher realm stage art failed: " + realm)
		stage.queue_free()
		var result := {"contractVersion": 2,
			"encounterInstanceId": request.encounterInstanceId,
			"sourceCardId": request.sourceCardId,
			"encounterId": request.encounterId,
			"sourceContentHash": request.sourceContentHash,
			"outcome": "victory",
			"combatReceipt": "combat:" + String(request.encounterInstanceId),
			"postBattleState": {"encounterInstanceId": request.encounterInstanceId,
				"terminal": true, "combatPhase": "VICTORY"}}
		var settled: Dictionary = BattleReturnFlow.new(ContentRepository.new(),
			gateway).settle(prepared, result)
		if settled.get("phase") != "BATTLE_RESULT_PENDING" or int(settled.get(
				"noncombatFlow", {}).get("encounterDirectorState", {}).get(
					"realmProgress", {}).get(realm, {}).get("counts", {}).get(
						offered.pendingCadenceCard.encounterRole, 0)) != 1:
			return _fail("higher realm battle result failed: " + realm)
		state.encounterCadence = cadence.marker(1)
		if not cadence.resume(state).is_empty():
			return _fail("legacy higher realm cadence appeared before upgrade: " + realm)
	for spec in [{"realm": "deity", "path": "sword",
			"id": "enc_quota_deity_heaven_envoy", "effect": "tianji"},
			{"realm": "nascent", "path": "pill",
			"id": "enc_trial_pill_spirit", "effect": "pills"}]:
		var state: Dictionary = game.state.duplicate(true)
		state.phase = "COMBAT_HANDOFF"
		state.realm = spec.realm
		state.path = spec.path
		state.turn = 1
		state.runClock.decisionIndex = 1
		state.encounterCadence = cadence.marker(1, 1)
		state.noncombatFlow = {"scope": "first_session_combat",
			"encounterDirectorState": cadence.initial_state(0)}
		state.noncombatFlow.encounterDirectorState.firstTeachingStatus = "resolved"
		state.attributes.tianji = 2
		var source: Dictionary = catalog.card(state, "encounter_card_" + String(spec.id))
		if source.is_empty():
			return _fail("higher realm avoidance source absent: " + String(spec.id))
		state.currentCardId = source.id
		state.pendingCadenceCard = source
		state.noncombatFlow.encounterDirectorState.pending = {
			"cardId": source.id, "encounterId": source.encounterId,
			"encounterKind": source.encounterKind, "role": source.encounterRole,
			"realm": spec.realm, "path": spec.path, "reason": "cadence",
			"scheduledDecision": 2, "presented": true, "accepted": false}
		var after: Dictionary = cadence.avoid(state)
		if after.is_empty() or spec.effect == "tianji" and int(
				after.get("attributes", {}).get("tianji", -1)) != 1 or spec.effect == "pills" \
				and int(after.get("resources", {}).get("pills", {}).get(
					source.choices.right.effects.pills, 0)) != 1:
			return _fail("higher realm avoidance failed: " + String(spec.id) + " " + cadence.last_error)
	print("NONCOMBAT_HIGHER_CATALOG_PASS realms=4 offers=4 requests=4 combat=4 stages=4 results=4 legacyDelayed=true avoidEffects=2")
	quit(0)
