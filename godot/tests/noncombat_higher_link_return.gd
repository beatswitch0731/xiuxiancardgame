extends "res://tests/noncombat_higher_catalog.gd"

const FactionEvents = preload("res://scripts/noncombat_faction_events.gd")


func _run() -> void:
	var content = ContentRepository.new()
	var catalog = CatalogEncounter.new(content)
	var gateway = BattleGateway.new(Registry.new())
	var cadence = CadenceFlow.new(content, gateway)
	var encounter_flow = EncounterFlow.new(content, gateway)
	var factions = FactionEvents.new(content)
	var game = Domain.new(Registry.new(), null, "slot_3")
	if not game.start("sword"):
		return _fail("higher linked return fixture could not start")
	var checked := 0
	for sample in [
		{"id": "enc_faction_tianshu_elite", "realm": "golden", "outcome": "victory"},
		{"id": "enc_faction_tianshu_elite", "realm": "golden", "outcome": "flee"},
		{"id": "enc_hidden_chaos_reversal", "realm": "deity", "outcome": "flee"},
		{"id": "enc_hidden_heaven_censor", "realm": "deity", "outcome": "victory"},
		{"id": "enc_quota_golden_lost_elixir", "realm": "golden", "outcome": "victory"},
	]:
		var state: Dictionary = game.state.duplicate(true)
		state.realm = sample.realm
		state.phase = "COMBAT_HANDOFF"
		state.turn = 1
		state.runClock.decisionIndex = 1
		state.encounterCadence = cadence.marker(1, 1)
		state.factionEventState = factions.marker(0)
		state.factionProgress = factions.baseline_progress()
		if sample.id in ["enc_hidden_chaos_reversal", "enc_hidden_heaven_censor"]:
			state["flags"] = {"causal:ancient_truth": true}
		state.noncombatFlow = {"scope": "first_session_combat",
			"encounterDirectorState": cadence.initial_state(0)}
		state.noncombatFlow.encounterDirectorState.firstTeachingStatus = "resolved"
		var source: Dictionary = catalog.card(state, "encounter_card_" + sample.id)
		if source.is_empty():
			return _fail("higher linked card missing: " + sample.id)
		state.currentCardId = source.id
		state.pendingCadenceCard = source
		state.noncombatFlow.encounterDirectorState.pending = {
			"cardId": source.id, "encounterId": source.encounterId,
			"encounterKind": source.encounterKind, "role": source.encounterRole,
			"realm": sample.realm, "path": state.path, "reason": "cadence",
			"scheduledDecision": 2, "presented": true, "accepted": false}
		var accepted: Dictionary = encounter_flow.accept(state)
		var prepared: Dictionary = encounter_flow.confirm(accepted, "left")
		var request: Dictionary = gateway.build_request(prepared)
		if accepted.get("phase") != "WARNING_PENDING" \
				or prepared.get("phase") != "BATTLE_PENDING" or request.is_empty():
			return _fail("higher linked battle handoff failed: " + sample.id \
				+ " accepted=" + str(accepted.get("phase")) + " prepared=" \
				+ str(prepared.get("phase")) + " offer=" + str(gateway.offer_from_state(state)) \
				+ " resolution=" + str(gateway.source_resolution_for_offer(state).get("sourceCardId")) \
				+ " gateway=" + gateway.source_error)
		var result := {"contractVersion": 2,
			"encounterInstanceId": request.encounterInstanceId,
			"sourceCardId": request.sourceCardId,
			"encounterId": request.encounterId,
			"sourceContentHash": request.sourceContentHash,
			"outcome": sample.outcome,
			"combatReceipt": "combat:" + String(request.encounterInstanceId),
			"postBattleState": {"encounterInstanceId": request.encounterInstanceId,
				"terminal": true, "combatPhase": String(sample.outcome).to_upper()}}
		var flow = BattleReturnFlow.new(content, gateway)
		var settled: Dictionary = flow.settle(prepared, result)
		if settled.get("phase") != "BATTLE_RESULT_PENDING":
			return _fail("higher linked battle return failed: " + sample.id + "/" \
				+ sample.outcome + " " + flow.last_error)
		if sample.id == "enc_faction_tianshu_elite":
			var delta := 6 if sample.outcome == "victory" else -4
			if int(settled.factionProgress.reputations.tianshu_academy) != clampi(
					int(state.factionProgress.reputations.tianshu_academy) + delta, -100, 100):
				return _fail("higher linked faction return mismatch")
			if sample.outcome == "victory" and not settled.karmaSeeds.any(
					func(seed: Variant) -> bool:
						return seed is Dictionary and seed.get("id") == "combatGlory"):
				return _fail("higher linked combat glory missing")
		if sample.id == "enc_hidden_chaos_reversal" and not settled.karmaSeeds.any(
				func(seed: Variant) -> bool:
					return seed is Dictionary and seed.get("id") == "chaos_following"):
			return _fail("higher linked flee karma missing")
		if sample.id == "enc_hidden_heaven_censor" and not settled.karmaSeeds.any(
				func(seed: Variant) -> bool:
					return seed is Dictionary and seed.get("id") == "heaven_censor_grudge"):
			return _fail("higher direct karma missing")
		if sample.id == "enc_quota_golden_lost_elixir" and int(settled.get(
				"knowledge", {}).get("world", 0)) != int(state.get(
					"knowledge", {}).get("world", 0)) + 2:
			return _fail("higher knowledge battle return mismatch")
		checked += 1
	print("NONCOMBAT_HIGHER_LINK_RETURN_PASS results=", checked,
		" faction=true karma=true knowledge=true")
	quit(0)
