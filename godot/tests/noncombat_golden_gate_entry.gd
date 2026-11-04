extends "res://tests/noncombat_foundation_normal_pool.gd"

const RealmGateFlow = preload("res://scripts/noncombat_realm_gate_flow.gd")
const BattleGateway = preload("res://scripts/noncombat_battle_gateway.gd")
const EncounterFlow = preload("res://scripts/noncombat_encounter_flow.gd")
const BattleReturnFlow = preload("res://scripts/noncombat_battle_return_flow.gd")
const StageRouter = preload("res://scripts/combat_stage_router.gd")


func _run() -> void:
	var game = Domain.new(Registry.new(), null, "slot_3")
	if not game.start("spell"):
		return _fail("golden gate fixture could not start")
	var state: Dictionary = game.state.duplicate(true)
	state.phase = "FLOW_PENDING"
	state.realm = "golden"
	state.attributes.cultivation = 100
	state.runClock.decisionIndex = 1
	state.turn = 1
	state.resources.spiritStone = 60
	state["decisionCheckpoint"] = {"sourceCardId": "ch_golden_80"}
	state["chapterProgress"] = {"version": 1, "activeChapterRealm": "golden",
		"triggeredMilestones": {"golden": [20, 45, 65, 85]}}
	state["noncombatFlow"] = {"scope": "first_session_combat",
		"encounterDirectorState": {"realmProgress": {
		"golden": {"seenCounts": {"ordinary": 2, "relationship": 1,
			"quest": 0, "elite": 1}}}}}
	state["flags"] = {"breakthrough_boost:golden": 0.2}
	var flow = RealmGateFlow.new(ContentRepository.new())
	var unqualified: Dictionary = state.duplicate(true)
	unqualified["noncombatFlow"]["encounterDirectorState"]["realmProgress"].erase("golden")
	if not flow.resume(unqualified).is_empty() or not flow.last_error.is_empty():
		return _fail("new golden realm without encounter quota was treated as source failure")
	var source: Dictionary = flow.source_card(state)
	if source.get("id") != "ch_golden_100" \
			or source.get("combatRules", {}).get("turnCycle", {}).get(
				"yin", {}).get("piercing") != true:
		return _fail("golden terminal source card unavailable")
	var offered: Dictionary = flow.resume(state)
	if offered.get("currentCardId") != "ch_golden_100" \
			or offered.get("phase") != "COMBAT_HANDOFF" \
			or offered.get("pendingRealmGateCard", {}).get("id") != "ch_golden_100" \
			or not is_equal_approx(float(offered.get("flags", {}).get(
				"breakthrough_boost:golden", 0.0)), 0.2):
		return _fail("golden terminal chapter was not scheduled with its boost")
	var warned: Dictionary = offered.duplicate(true)
	warned.phase = "WARNING_PENDING"
	var bare: Dictionary = flow.warning_card(warned)
	if bare.get("id") != "_warning_ch_golden_100" \
			or bare.get("choices", {}).size() != 2 \
			or bare.get("choices", {}).get("left", {}).get(
				"costCheck", {}).get("spiritStone") != 25:
		return _fail("golden bare warning differs from source")
	warned.resources.pills.nascent = 1
	var with_pill: Dictionary = flow.warning_card(warned)
	if with_pill.get("choices", {}).size() != 3 \
			or with_pill.get("choices", {}).get("left", {}).get(
				"effects", {}).get("_consumePill") != "nascent" \
			or with_pill.get("choices", {}).get("right", {}).get(
				"effects", {}).get("_setFlag") != "used_lightning_array":
		return _fail("golden pill and array warning differ from source")
	var gateway = BattleGateway.new(Registry.new())
	var encounter = EncounterFlow.new(ContentRepository.new(), gateway)
	for row in [{"pill": 0, "direction": "left", "cost": 25,
			"flag": "used_lightning_array"},
			{"pill": 0, "direction": "right", "cost": 0, "flag": ""},
			{"pill": 1, "direction": "left", "cost": 0,
				"flag": "used_nascent_pill"},
			{"pill": 1, "direction": "right", "cost": 25,
				"flag": "used_lightning_array"},
			{"pill": 1, "direction": "up", "cost": 0, "flag": ""}]:
		var branch: Dictionary = offered.duplicate(true)
		if row.pill == 1:
			branch.resources.pills.nascent = 1
		var offer: Dictionary = gateway.offer_from_state(branch)
		var resolution: Dictionary = gateway.source_resolution_for_offer(branch)
		var pending: Dictionary = encounter.accept(branch)
		var prepared: Dictionary = encounter.confirm(pending, row.direction)
		var request: Dictionary = gateway.build_request(prepared)
		if pending.get("phase") != "WARNING_PENDING" \
				or prepared.get("phase") != "BATTLE_PENDING" \
				or request.get("sourceCardId") != "ch_golden_100" \
				or int(prepared.resources.spiritStone) != 60 - row.cost \
				or int(prepared.resources.pills.get("nascent", 0)) != row.pill - (
					1 if row.flag == "used_nascent_pill" else 0) \
				or row.flag != "" and prepared.get("flags", {}).get(row.flag) != true:
			return _fail("golden gate warning preparation/request failed: "
				+ JSON.stringify({"row": row, "offer": offer.get("sourceCardId"),
					"resolution": resolution.get("sourceCardId"),
					"pending": pending.get("phase"),
					"prepared": prepared.get("phase"), "request": request.get("sourceCardId"),
					"stone": prepared.get("resources", {}).get("spiritStone"),
					"pills": prepared.get("resources", {}).get("pills"),
					"flags": prepared.get("flags"),
					"gatewayError": gateway.source_error}))
		if row.direction == "left":
			var resolver = BattlePlanResolver.new(Registry.new())
			var plan: Dictionary = resolver.resolve_persisted(prepared)
			var combat = CombatDomain.new(Registry.new())
			if plan.get("launchAuthorized") != true \
					or plan.get("isBoss") != true \
					or not combat.load_persisted_request(request, plan) \
					or combat.state.get("enemyIntent", {}).get("turnCyclePhaseId") != "yang" \
					or int(combat.state.player.block) < (8 if row.flag == "used_lightning_array" else 0):
				return _fail("golden source battlefield or yang opening failed: "
					+ String(resolver.last_error))
			if not combat.end_turn() or not combat.choose_reaction("EVADE", 0.999) \
					or combat.state.enemyIntent.get("turnCyclePhaseId") != "yin" \
					or combat.state.enemyIntent.get("piercing") != true:
				return _fail("golden gate did not advance from yang to piercing yin")
			combat.state.player.block = 20
			var hp_before := int(combat.state.player.hp)
			if not combat.end_turn() or not combat.choose_reaction("TAKE_HIT", 0.999) \
					or (int(combat.state.player.hp) == hp_before) != (
						row.flag == "used_nascent_pill") \
					or combat.state.enemyIntent.get("turnCyclePhaseId") != "yang":
				return _fail("golden gate yin piercing or pill counter differs")
			var context: Dictionary = StageRouter.new(Registry.new()).resolve_choice(
				"ch_golden_100", "left", request.pendingResolution.combatCard,
				String(request.encounterInstanceId), request.pendingResolution,
				String(request.path), String(request.realm))
			context["deck"] = plan.deck.duplicate(true)
			var stage: Control = load("res://scenes/duel_stage_golden_gate_2d.tscn").instantiate()
			if not stage.bind_stage_context(context):
				stage.free()
				return _fail("golden source battlefield stage did not bind")
			root.add_child(stage)
			if not stage.has_hd2d_assets():
				return _fail("golden source battlefield lacks mounted art")
			stage.queue_free()
	for outcome in ["victory", "defeat", "flee"]:
		var pending: Dictionary = encounter.accept(offered)
		var before: Dictionary = encounter.confirm(pending, "right")
		var request: Dictionary = gateway.build_request(before)
		var result := {"contractVersion": 2,
			"encounterInstanceId": request.encounterInstanceId,
			"sourceCardId": request.sourceCardId,
			"encounterId": request.encounterId,
			"sourceContentHash": request.sourceContentHash,
			"outcome": outcome,
			"combatReceipt": "combat:" + String(request.encounterInstanceId),
			"postBattleState": {"encounterInstanceId": request.encounterInstanceId,
				"terminal": true, "combatPhase": outcome.to_upper()}}
		var return_flow = BattleReturnFlow.new(ContentRepository.new(), gateway)
		var returned: Dictionary = return_flow.settle(before, result)
		if returned.is_empty():
			return _fail("golden gate %s result failed: %s" % [outcome,
				String(return_flow.last_error)])
		if outcome == "victory":
			if returned.realm != "nascent" or returned.phase != "BATTLE_RESULT_PENDING" \
					or returned.currentCardId != "breakthrough_reward" \
					or int(returned.maxHealth) != int(before.maxHealth) + 2 \
					or int(returned.maxDaoHeart) != int(before.maxDaoHeart) + 2 \
					or returned.get("flags", {}).has("breakthrough_boost:golden"):
				return _fail("golden victory did not promote or consume source boost")
			var cold: Dictionary = JSON.parse_string(JSON.stringify(returned))
			var selected: Dictionary = flow.dismiss(cold, "left")
			if selected.get("currentCardId") != "realm_arrival_nascent" \
					or selected.get("phase") != "REALM_ARRIVAL_PENDING":
				return _fail("golden victory inheritance did not reach nascent arrival")
			cold = JSON.parse_string(JSON.stringify(selected))
			var arrived: Dictionary = flow.settle_epiphany(cold, "left")
			if arrived.get("phase") != "FLOW_PENDING" \
					or arrived.get("flags", {}).get("realm_upgrade_nascent_foundation") != true:
				return _fail("nascent arrival did not settle after cold recovery")
		elif outcome == "defeat":
			if returned.get("phase") != "INNER_DEMON_PENDING" \
					or returned.get("pendingConsequence", {}).get("sourceCardId") != "ch_golden_100" \
					or returned.get("flags", {}).has("breakthrough_boost:golden"):
				return _fail("golden defeat did not consume boost and create inner demon")
		else:
			if returned.get("currentCardId") != "combat_fled_ch_golden_100" \
					or not is_equal_approx(float(returned.get("flags", {}).get(
						"breakthrough_boost:golden", 0.0)), 0.2):
				return _fail("golden retreat should preserve boost")
	print("NONCOMBAT_GOLDEN_GATE_ENTRY_PASS source=true quota=true warnings=2 preparations=5 battlefield=true outcomes=3 arrival=true boost=true")
	quit(0)
