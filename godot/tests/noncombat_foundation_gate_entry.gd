extends "res://tests/noncombat_foundation_normal_pool.gd"

const RealmGateFlow = preload("res://scripts/noncombat_realm_gate_flow.gd")
const BattleGateway = preload("res://scripts/noncombat_battle_gateway.gd")
const EncounterFlow = preload("res://scripts/noncombat_encounter_flow.gd")
const StageRouter = preload("res://scripts/combat_stage_router.gd")
const BattleReturnFlow = preload("res://scripts/noncombat_battle_return_flow.gd")
const CatalogEncounter = preload("res://scripts/noncombat_catalog_encounter.gd")


func _run() -> void:
	var game = Domain.new(Registry.new(), null, "slot_3")
	if not game.start("spell"):
		return _fail("foundation gate fixture could not start")
	var state: Dictionary = game.state.duplicate(true)
	state.phase = "FLOW_PENDING"
	state.realm = "foundation"
	state.attributes.cultivation = 100
	state.runClock.decisionIndex = 1
	state.turn = 1
	state.resources.spiritStone = 10
	var candidates: Array = CatalogEncounter.new(ContentRepository.new()).candidates(state)
	if not candidates.any(func(row: Variant) -> bool:
		return row.get("id") == "encounter_card_enc_quota_foundation_vein_wolf"):
		return _fail("foundation ordinary quota source was not in cadence catalog")
	state["decisionCheckpoint"] = {"sourceCardId": "ch_foundation_80"}
	state["chapterProgress"] = {"version": 1, "activeChapterRealm": "foundation",
		"triggeredMilestones": {"foundation": [20, 40, 60, 80]}}
	state["noncombatFlow"] = {"scope": "first_session_combat",
		"encounterDirectorState": {"realmProgress": {"foundation": {
			"seenCounts": {"ordinary": 2, "relationship": 1, "quest": 0,
				"elite": 1}}}}}
	var flow = RealmGateFlow.new(ContentRepository.new())
	var offered: Dictionary = flow.resume(state)
	if offered.get("currentCardId") != "ch_foundation_100" \
			or offered.get("phase") != "COMBAT_HANDOFF" \
			or offered.get("pendingRealmGateCard", {}).get("id") != "ch_foundation_100":
		return _fail("foundation terminal chapter was not scheduled")
	var warning_state: Dictionary = offered.duplicate(true)
	warning_state.phase = "WARNING_PENDING"
	var bare: Dictionary = flow.warning_card(warning_state)
	if bare.get("id") != "_warning_ch_foundation_100" \
			or bare.get("choices", {}).size() != 2 \
			or bare.get("choices", {}).get("right", {}).get("costCheck", {}).get(
				"spiritStone") != 5:
		return _fail("foundation bare warning differs from source")
	warning_state.resources.pills.golden = 1
	var with_pill: Dictionary = flow.warning_card(warning_state)
	if with_pill.get("choices", {}).size() != 3 \
			or with_pill.get("choices", {}).get("left", {}).get("effects", {}).get(
				"_consumePill") != "golden":
		return _fail("foundation pill warning differs from source")
	var gateway = BattleGateway.new(Registry.new())
	var encounter = EncounterFlow.new(ContentRepository.new(), gateway)
	var accepted: Dictionary = encounter.accept(offered)
	if accepted.get("phase") != "WARNING_PENDING" \
			or encounter.warning_card(accepted).get("id") != "_warning_ch_foundation_100":
		return _fail("foundation warning could not enter encounter checkpoint")
	var prepared: Dictionary = encounter.confirm(accepted, "right")
	if prepared.get("phase") != "BATTLE_PENDING" \
			or int(prepared.get("resources", {}).get("spiritStone", -1)) != 5 \
			or gateway.build_request(prepared).get("sourceCardId") != "ch_foundation_100":
		return _fail("foundation warning did not create authenticated request")
	var plan: Dictionary = BattlePlanResolver.new(Registry.new()).resolve_persisted(prepared)
	if plan.get("launchAuthorized") != true:
		return _fail("foundation gate source battle plan is unavailable")
	var combat = CombatDomain.new(Registry.new())
	var expected_hp := maxi(6, 11 - int(prepared.attributes.daoHeart))
	if not combat.load_persisted_request(gateway.build_request(prepared), plan) \
			or int(combat.state.get("enemy", {}).get("hp", 0)) != expected_hp:
		return _fail("foundation gate bare heart mirror did not load at source HP")
	var pill_offer: Dictionary = offered.duplicate(true)
	pill_offer.resources.pills.golden = 1
	var pill_warning: Dictionary = encounter.accept(pill_offer)
	var pill_battle: Dictionary = encounter.confirm(pill_warning, "left")
	var pill_request: Dictionary = gateway.build_request(pill_battle)
	var pill_plan: Dictionary = BattlePlanResolver.new(Registry.new()).resolve_persisted(
		pill_battle)
	var pill_combat = CombatDomain.new(Registry.new())
	if pill_request.get("sourceCardId") != "ch_foundation_100" \
			or int(pill_battle.resources.pills.get("golden", 0)) != 0 \
			or pill_plan.get("launchAuthorized") != true \
			or pill_plan.get("isBoss") != true \
			or not pill_combat.load_persisted_request(pill_request, pill_plan) \
			or int(pill_combat.state.enemy.hp) != maxi(2, expected_hp - 2) \
			or int(pill_combat.state.player.block) < 2:
		return _fail("foundation golden pill counter did not reach source combat")
	var context: Dictionary = StageRouter.new(Registry.new()).resolve_choice(
		"ch_foundation_100", "left", pill_request.pendingResolution.combatCard,
		String(pill_request.encounterInstanceId), pill_request.pendingResolution,
		String(pill_request.path), String(pill_request.realm))
	context["deck"] = pill_plan.deck.duplicate(true)
	var stage: Control = load("res://scenes/duel_stage_foundation_gate_2d.tscn").instantiate()
	if not stage.bind_stage_context(context):
		stage.free()
		return _fail("foundation heart mirror source stage did not bind")
	root.add_child(stage)
	if not stage.has_hd2d_assets():
		return _fail("foundation heart mirror source stage lacks assets")
	stage.queue_free()
	for outcome in ["victory", "defeat", "flee"]:
		var before: Dictionary = pill_battle if outcome == "victory" else prepared
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
		var returned: Dictionary = BattleReturnFlow.new(ContentRepository.new(),
			gateway).settle(before, result)
		if returned.is_empty():
			return _fail("foundation gate %s result did not settle" % outcome)
		if outcome == "victory":
			if returned.realm != "golden" or returned.phase != "BATTLE_RESULT_PENDING" \
					or returned.currentCardId != "breakthrough_reward" \
					or int(returned.maxHealth) != int(before.maxHealth) + 2 \
					or int(returned.maxDaoHeart) != int(before.maxDaoHeart) + 2:
				return _fail("foundation victory did not promote with source max stats")
			var selected: Dictionary = flow.dismiss(returned, "left")
			if selected.get("currentCardId") != "realm_arrival_golden" \
					or selected.get("phase") != "REALM_ARRIVAL_PENDING":
				return _fail("foundation victory inheritance did not reach golden arrival")
			var arrived: Dictionary = flow.settle_epiphany(selected, "left")
			if arrived.get("phase") != "FLOW_PENDING" \
					or arrived.get("flags", {}).get("realm_upgrade_golden_foundation") != true:
				return _fail("golden arrival choice did not settle")
		elif outcome == "defeat":
			if returned.get("phase") != "INNER_DEMON_PENDING" \
					or returned.get("pendingConsequence", {}).get("sourceCardId") != "ch_foundation_100":
				return _fail("foundation defeat did not create source inner demon")
		elif returned.get("currentCardId") != "combat_fled_ch_foundation_100":
			return _fail("foundation retreat result card missing")
	print("NONCOMBAT_FOUNDATION_GATE_ENTRY_PASS source=true quota=true offer=true warning=true request=true plan=true combat=true counter=true stage=true outcomes=3 arrival=true")
	quit(0)
