extends "res://tests/noncombat_foundation_normal_pool.gd"

const BattleGateway = preload("res://scripts/noncombat_battle_gateway.gd")
const EncounterFlow = preload("res://scripts/noncombat_encounter_flow.gd")
const BattleReturnFlow = preload("res://scripts/noncombat_battle_return_flow.gd")
const StageRouter = preload("res://scripts/combat_stage_router.gd")


func _run() -> void:
	var game = Domain.new(Registry.new(), null, "slot_3")
	if not game.start("body"):
		return _fail("bandit fixture could not start")
	var state: Dictionary = game.state.duplicate(true)
	state.realm = "golden"
	state.phase = "NORMAL_PENDING"
	state.currentCardId = "ds_female_bandit"
	state.turn = 1
	state.runClock.decisionIndex = 1
	state.resources.spiritStone = 30
	var card: Dictionary = ChoicePolicy.new(ContentRepository.new()).source_card(
		"ds_female_bandit", state)
	if card.is_empty() or not ChoicePolicy.new(ContentRepository.new()).choice_available(
			state, card, "left"):
		return _fail("source bandit challenge unavailable: " + JSON.stringify(
			card.get("choices", {}).get("left", {})))
	game.state = state.duplicate(true)
	if not game.choose("left", game.issue_choice_token()) \
			or game.state.get("phase") != "WARNING_PENDING":
		return _fail("bandit source choice did not reach warning in domain")
	var gateway = BattleGateway.new(Registry.new())
	var offer: Dictionary = gateway.offer_from_state(state)
	var resolution: Dictionary = gateway.source_resolution_for_offer(state)
	if offer.get("sourceCardId") != "ds_female_bandit" \
			or resolution.get("combatCard", {}).get("enemy", {}).get(
				"id") != "tiger_queen_golden":
		return _fail("bandit combat offer or resolution missing: " + gateway.source_error)
	var encounter = EncounterFlow.new(ContentRepository.new(), gateway)
	var pending: Dictionary = encounter.accept(state)
	var prepared: Dictionary = encounter.confirm(pending, "left")
	var request: Dictionary = gateway.build_request(prepared)
	if pending.get("phase") != "WARNING_PENDING" \
			or prepared.get("phase") != "BATTLE_PENDING" \
			or request.get("sourceCardId") != "ds_female_bandit":
		return _fail("bandit warning or request failed: " + gateway.source_error)
	var resolver = BattlePlanResolver.new(Registry.new())
	var plan: Dictionary = resolver.resolve_persisted(prepared)
	if plan.get("launchAuthorized") != true:
		return _fail("bandit battle plan unavailable: " + resolver.last_error)
	var combat = CombatDomain.new(Registry.new())
	if not combat.load_persisted_request(request, plan) \
			or combat.state.get("enemyIntent", {}).get("type") != "debuff":
		return _fail("bandit source combat did not load tiger roar")
	var context: Dictionary = StageRouter.new(Registry.new()).resolve_choice(
		"ds_female_bandit", "left", request.pendingResolution.combatCard,
		String(request.encounterInstanceId), request.pendingResolution,
		String(request.path), String(request.realm))
	context["deck"] = plan.deck.duplicate(true)
	var stage: Control = load("res://scenes/duel_stage_bandit_2d.tscn").instantiate()
	if not stage.bind_stage_context(context):
		return _fail("bandit source stage did not bind")
	root.add_child(stage)
	if not stage.has_hd2d_assets():
		return _fail("bandit source stage lacks mounted art")
	stage.queue_free()
	for outcome in ["victory", "defeat", "flee"]:
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
		var returned: Dictionary = return_flow.settle(prepared, result)
		if returned.is_empty():
			return _fail("bandit %s result failed: %s" % [outcome,
				String(return_flow.last_error)])
		if outcome == "victory":
			if not returned.get("deck", []).has("tiger_break_stance") \
					or returned.get("skillAcquisitions", {}).get(
						"tiger_break_stance", {}).get("mode") != "guaranteed":
				return _fail("bandit victory did not grant source skill")
		elif outcome == "defeat":
			if int(returned.attributes.health) != int(prepared.attributes.health) - 2 \
					or int(returned.attributes.daoHeart) != int(prepared.attributes.daoHeart) - 1:
				return _fail("bandit defeat costs differ from source")
		elif int(returned.resources.lifespan) != int(prepared.resources.lifespan) - 1:
			return _fail("bandit retreat did not spend lifespan")
	print("NONCOMBAT_BANDIT_ENTRY_PASS warning=true request=true plan=true combat=true stage=true outcomes=3 skill=true")
	quit(0)
