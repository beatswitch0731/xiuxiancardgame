extends "res://tests/noncombat_foundation_normal_pool.gd"

const RealmGateFlow = preload("res://scripts/noncombat_realm_gate_flow.gd")
const BattleGateway = preload("res://scripts/noncombat_battle_gateway.gd")
const EncounterFlow = preload("res://scripts/noncombat_encounter_flow.gd")
const BattleReturnFlow = preload("res://scripts/noncombat_battle_return_flow.gd")
const StageRouter = preload("res://scripts/combat_stage_router.gd")


func _run() -> void:
	var game = Domain.new(Registry.new(), null, "slot_3")
	if not game.start("spell"):
		return _fail("nascent gate fixture could not start")
	var state: Dictionary = game.state.duplicate(true)
	state.realm = "nascent"
	state.phase = "FLOW_PENDING"
	state.attributes.cultivation = 100
	state.runClock.decisionIndex = 1
	state.turn = 1
	state.resources.spiritStone = 100
	state.decisionCheckpoint = {"sourceCardId": "ch_nascent_80"}
	state.chapterProgress = {"version": 1, "activeChapterRealm": "nascent",
		"triggeredMilestones": {"nascent": [25, 50, 70, 90]}}
	state.noncombatFlow = {"scope": "first_session_combat",
		"encounterDirectorState": {"realmProgress": {
			"nascent": {"seenCounts": {"ordinary": 2, "relationship": 1,
				"quest": 0, "elite": 1}}}}}
	var flow = RealmGateFlow.new(ContentRepository.new())
	var card: Dictionary = flow.source_card(state)
	var offered: Dictionary = flow.resume(state)
	if card.get("id") != "ch_nascent_100" \
			or offered.get("currentCardId") != "ch_nascent_100" \
			or offered.get("phase") != "COMBAT_HANDOFF":
		return _fail("nascent 100-point source gate not scheduled")
	var gateway = BattleGateway.new(Registry.new())
	var encounter = EncounterFlow.new(ContentRepository.new(), gateway)
	for with_pill in [false, true]:
		var branch: Dictionary = offered.duplicate(true)
		if with_pill:
			branch.resources.pills.deity = 1
		var offer: Dictionary = gateway.offer_from_state(branch)
		var pending: Dictionary = encounter.accept(branch)
		var warning: Dictionary = encounter.warning_card(pending)
		if offer.get("sourceCardId") != "ch_nascent_100" \
				or pending.get("phase") != "WARNING_PENDING" \
				or warning.get("id") != "_warning_ch_nascent_100" \
				or not warning.get("choices", {}).has("left") \
				or not warning.get("choices", {}).has("right"):
			return _fail("nascent gate warning unavailable")
		for direction in ["left", "right"]:
			var prepared: Dictionary = encounter.confirm(pending, direction)
			var request: Dictionary = gateway.build_request(prepared)
			var expected_cost := 15 if not with_pill and direction == "right" else 0
			if prepared.get("phase") != "BATTLE_PENDING" \
					or request.get("sourceCardId") != "ch_nascent_100" \
					or int(prepared.get("resources", {}).get("spiritStone", 0)) != 100 - expected_cost \
					or with_pill and direction == "left" and (
						prepared.get("flags", {}).get("used_deity_pill") != true \
						or int(prepared.get("resources", {}).get("pills", {}).get("deity", 0)) != 0):
				return _fail("nascent gate preparation or request failed: " +
					JSON.stringify({"pill": with_pill, "direction": direction,
						"phase": prepared.get("phase"), "request": request.get("sourceCardId")}))
			if direction == "left":
				var resolver = BattlePlanResolver.new(Registry.new())
				var plan: Dictionary = resolver.resolve_persisted(prepared)
				var combat = CombatDomain.new(Registry.new())
				if plan.get("launchAuthorized") != true \
						or not combat.load_persisted_request(request, plan):
					return _fail("nascent gate plan or combat failed: " + resolver.last_error)
				if combat.state.get("deityPillBacklashCounter") != with_pill \
						or combat.state.get("enemyIntent", {}).is_empty():
					return _fail("nascent gate counter or intent failed")
				var attack_id := ""
				for card_id in plan.deck:
					var battle_card: Dictionary = Registry.new().get_battle_card(String(card_id))
					if battle_card.get("type") == "attack" \
							and int(battle_card.get("cost", 0)) <= int(combat.state.qi):
						attack_id = String(card_id)
						break
				if attack_id.is_empty():
					return _fail("nascent deck has no affordable attack card")
				combat.state.hand = [attack_id]
				var hp_before := int(combat.state.player.hp)
				if not combat.play_card(0) \
						or int(combat.state.player.hp) != hp_before - (0 if with_pill else 1):
					return _fail("nascent attack backlash differs from source counter")
				if not with_pill:
					var lethal = CombatDomain.new(Registry.new())
					if not lethal.load_persisted_request(request, plan):
						return _fail("nascent lethal fixture could not load")
					lethal.state.hand = [attack_id]
					lethal.state.player.hp = 1
					if not lethal.play_card(0) or lethal.state.get("outcome") != "defeat":
						return _fail("nascent lethal backlash did not stop card")
				var context: Dictionary = StageRouter.new(Registry.new()).resolve_choice(
					"ch_nascent_100", "left", request.pendingResolution.combatCard,
					String(request.encounterInstanceId), request.pendingResolution,
					String(request.path), String(request.realm))
				context["deck"] = plan.deck.duplicate(true)
				var stage: Control = load("res://scenes/duel_stage_nascent_gate_2d.tscn").instantiate()
				if not stage.bind_stage_context(context):
					stage.free()
					return _fail("nascent gate stage bind failed")
				root.add_child(stage)
				if not stage.has_hd2d_assets():
					return _fail("nascent gate stage art unavailable")
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
			return _fail("nascent gate result failed: " + outcome + " " + return_flow.last_error)
		var fact_id := "fact:%d:nascent_main_fate_claim" % int(returned.get("lifeCount", 0))
		var verdict_id := "fact:%d:nascent_main_void_verdict" % int(returned.get("lifeCount", 0))
		var facts: Dictionary = returned.noncombatFlow.get("spineFacts", {})
		if outcome == "victory":
			var broken: Dictionary = before.duplicate(true)
			broken.noncombatFlow.spineFacts[fact_id].status = "consumed"
			if not return_flow.settle(broken, result).is_empty():
				return _fail("nascent victory accepted missing active fate claim")
			broken = before.duplicate(true)
			broken.noncombatFlow.spineFacts[verdict_id] = facts[verdict_id].duplicate(true)
			if not return_flow.settle(broken, result).is_empty():
				return _fail("nascent victory duplicated void verdict")
			if returned.realm != "deity" or returned.currentCardId != "breakthrough_reward" \
					or facts.get(fact_id, {}).get("status") != "consumed" \
					or facts.get(verdict_id, {}).get("status") != "active":
				return _fail("nascent victory did not promote and settle spine")
			var cold: Dictionary = JSON.parse_string(JSON.stringify(returned))
			var selected: Dictionary = flow.dismiss(cold, "left")
			if selected.get("currentCardId") != "realm_arrival_deity":
				return _fail("nascent victory did not reach deity arrival")
			cold = JSON.parse_string(JSON.stringify(selected))
			var arrived: Dictionary = flow.settle_epiphany(cold, "left")
			if arrived.get("phase") != "FLOW_PENDING":
				return _fail("deity arrival cold restoration failed")
		else:
			if facts.get(fact_id, {}).get("status") != "active" or facts.has(verdict_id):
				return _fail("nascent retry incorrectly settled spine")
	print("NONCOMBAT_NASCENT_GATE_ENTRY_PASS source=true schedule=true warnings=2 preparations=4 battlefield=true outcomes=3 spine=true arrival=true")
	quit(0)
