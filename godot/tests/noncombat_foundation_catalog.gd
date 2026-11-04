extends "res://tests/noncombat_foundation_normal_pool.gd"

const CatalogEncounter = preload("res://scripts/noncombat_catalog_encounter.gd")
const CadenceFlow = preload("res://scripts/noncombat_cadence_flow.gd")
const EncounterFlow = preload("res://scripts/noncombat_encounter_flow.gd")
const BattleGateway = preload("res://scripts/noncombat_battle_gateway.gd")
const BattleReturnFlow = preload("res://scripts/noncombat_battle_return_flow.gd")


func _run() -> void:
	var game = Domain.new(Registry.new(), null, "slot_3")
	if not game.start("spell"):
		return _fail("foundation catalog fixture could not start")
	var state: Dictionary = game.state.duplicate(true)
	state.phase = "FLOW_PENDING"
	state.realm = "foundation"
	state.turn = 1
	state.runClock.decisionIndex = 1
	var gateway = BattleGateway.new(Registry.new())
	var cadence = CadenceFlow.new(ContentRepository.new(), gateway)
	state.encounterCadence = cadence.marker(1)
	state["noncombatFlow"] = {"scope": "first_session_combat"}
	state.noncombatFlow.encounterDirectorState = cadence.initial_state(int(state.get("lifeCount", 0)))
	state.noncombatFlow.encounterDirectorState.firstTeachingStatus = "resolved"
	state.noncombatFlow.encounterDirectorState.nextDueDecision = 2
	var catalog = CatalogEncounter.new(ContentRepository.new())
	var candidates: Array = catalog.candidates(state)
	if not candidates.any(func(row: Variant) -> bool:
		return row.get("realm") == "foundation" and row.get("encounterRole") == "ordinary"):
		return _fail("foundation ordinary quota catalog absent")
	var offered: Dictionary = cadence.resume(state)
	if offered.get("phase") != "COMBAT_HANDOFF" or not String(
			offered.get("currentCardId", "")).begins_with("encounter_card_"):
		return _fail("foundation catalog cadence did not offer: " + cadence.last_error)
	var encounter = EncounterFlow.new(ContentRepository.new(), gateway)
	var accepted: Dictionary = encounter.accept(offered)
	var prepared: Dictionary = encounter.confirm(accepted, "left")
	var request: Dictionary = gateway.build_request(prepared)
	if accepted.get("phase") != "WARNING_PENDING" or prepared.get("phase") != "BATTLE_PENDING" \
			or request.get("sourceCardId") != offered.currentCardId:
		return _fail("foundation catalog offer did not form request: " + gateway.source_error)
	var resolver = BattlePlanResolver.new(Registry.new())
	var plan: Dictionary = resolver.resolve_persisted(prepared)
	if plan.get("launchAuthorized") != true:
		return _fail("foundation catalog battle plan unavailable: " + resolver.last_error)
	var combat = CombatDomain.new(Registry.new())
	if not combat.load_persisted_request(request, plan):
		return _fail("foundation catalog combat could not load: " + JSON.stringify({
			"id": request.get("encounterId"), "enemy": plan.get("enemy"),
			"realm": request.get("realm"), "base": request.get("baseDecisionIndex")}))
	var stage: Control = load("res://scenes/duel_stage_foundation_catalog_2d.tscn").instantiate()
	var context: Dictionary = load("res://scripts/combat_stage_router.gd").new(
		Registry.new()).resolve_choice(String(request.sourceCardId), "left",
		request.pendingResolution.combatCard, String(request.encounterInstanceId),
		request.pendingResolution, String(request.path), String(request.realm))
	context.deck = plan.deck.duplicate(true)
	if not stage.bind_stage_context(context):
		stage.free()
		return _fail("foundation catalog stage did not bind")
	root.add_child(stage)
	if not stage.has_hd2d_assets():
		return _fail("foundation catalog source stage lacks art")
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
	if settled.is_empty() or settled.get("phase") != "BATTLE_RESULT_PENDING" \
			or settled.get("noncombatFlow", {}).get("encounterDirectorState", {}).get(
				"realmProgress", {}).get("foundation", {}).get(
				"counts", {}).get("ordinary", 0) != 1:
		return _fail("foundation catalog victory did not settle director quota")
	print("NONCOMBAT_FOUNDATION_CATALOG_PASS schedule=true request=true combat=true stage=true result=true")
	quit(0)
