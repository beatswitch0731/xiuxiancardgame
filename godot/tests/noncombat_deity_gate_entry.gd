extends "res://tests/noncombat_foundation_normal_pool.gd"

const RealmGateFlow = preload("res://scripts/noncombat_realm_gate_flow.gd")
const BattleGateway = preload("res://scripts/noncombat_battle_gateway.gd")
const EncounterFlow = preload("res://scripts/noncombat_encounter_flow.gd")
const BattleReturnFlow = preload("res://scripts/noncombat_battle_return_flow.gd")
const StageRouter = preload("res://scripts/combat_stage_router.gd")


func _run() -> void:
	var game = Domain.new(Registry.new(), null, "slot_3")
	if not game.start("spell"):
		return _fail("deity gate fixture could not start")
	var state: Dictionary = game.state.duplicate(true)
	state.realm = "deity"
	state.phase = "FLOW_PENDING"
	state.attributes.cultivation = 100
	state.attributes.karmaBad = 20
	state.resources.spiritStone = 100
	state.turn = 1
	state.runClock.decisionIndex = 1
	state.decisionCheckpoint = {"sourceCardId": "ch_deity_80"}
	state.chapterProgress = {"version": 1, "activeChapterRealm": "deity",
		"triggeredMilestones": {"deity": [20, 40, 60, 80]}}
	state.noncombatFlow = {"scope": "first_session_combat",
		"encounterDirectorState": {"realmProgress": {
			"deity": {"seenCounts": {"ordinary": 2, "relationship": 1,
				"quest": 0, "elite": 1}}}}}
	var flow = RealmGateFlow.new(ContentRepository.new())
	var offered: Dictionary = flow.resume(state)
	if offered.get("currentCardId") != "ch_deity_100" \
			or offered.get("phase") != "COMBAT_HANDOFF":
		return _fail("deity 100-point source gate not scheduled")
	var gateway = BattleGateway.new(Registry.new())
	var encounter = EncounterFlow.new(ContentRepository.new(), gateway)
	var pending: Dictionary = encounter.accept(offered)
	var warning: Dictionary = encounter.warning_card(pending)
	if pending.get("phase") != "WARNING_PENDING" \
			or warning.get("id") != "_warning_ch_deity_100" \
			or not warning.get("description", "").contains("20"):
		return _fail("deity source karma warning missing")
	var prepared: Dictionary = encounter.confirm(pending, "right")
	if prepared.get("phase") != "BATTLE_PENDING" \
			or gateway.build_request(prepared).get("sourceCardId") != "ch_deity_100" \
			or int(prepared.resources.spiritStone) != 80:
		return _fail("deity no-treasure preparation failed")
	var request: Dictionary = gateway.build_request(prepared)
	var resolver = BattlePlanResolver.new(Registry.new())
	var plan: Dictionary = resolver.resolve_persisted(prepared)
	var combat = CombatDomain.new(Registry.new())
	if plan.get("launchAuthorized") != true \
			or not combat.load_persisted_request(request, plan) \
			or combat.state.get("karmaDamageRules", {}).get("perPoints") != 10:
		return _fail("deity battle plan or karma rule failed: " + resolver.last_error)
	var karma_combat = CombatDomain.new(Registry.new())
	if not karma_combat.load_persisted_request(request, plan):
		return _fail("deity karma comparison could not load")
	for trial in [combat, karma_combat]:
		trial.state.phase = "REACTION_OPEN"
		trial.state.enemyIntent = {"type": "attack", "value": 3}
		trial.state.player.hp = 20
		trial.state.player.maxHp = 20
		trial.state.player.block = 0
		trial.state.player.daoHeart = 0
	karma_combat.state.badKarma = 0
	if not combat.choose_reaction("TAKE_HIT", 0.999) \
			or not karma_combat.choose_reaction("TAKE_HIT", 0.999) \
			or int(karma_combat.state.player.hp) - int(combat.state.player.hp) != 2:
		return _fail("deity karma did not add two damage at 20 bad karma")
	var relic_state: Dictionary = state.duplicate(true)
	var treasure_doc: Dictionary = ContentRepository.new().read_module("shops:treasures")
	var weapon_id := ""
	for treasure in treasure_doc.get("treasures", []):
		if treasure is Dictionary and treasure.get("type") == "weapon":
			weapon_id = String(treasure.id)
			break
	if weapon_id.is_empty():
		return _fail("deity relic fixture lacks a source weapon")
	var instance_id := "tr:%s:1" % weapon_id
	relic_state.treasureInstances = {instance_id: {"instanceId": instance_id,
		"definitionId": weapon_id, "lifecycle": "owned",
		"provenance": {"source": "test"}, "acquiredDecision": 1}}
	relic_state.equipment = {"weapon": instance_id, "armor": null,
		"accessory": null, "artifact": null}
	relic_state.resources.treasures = [weapon_id]
	relic_state.treasureInventory = []
	var relic_offered: Dictionary = flow.resume(relic_state)
	var relic_pending: Dictionary = encounter.accept(relic_offered)
	var relic_warning: Dictionary = encounter.warning_card(relic_pending)
	var relic_prepared: Dictionary = encounter.confirm(relic_pending, "left")
	var relic_request: Dictionary = gateway.build_request(relic_prepared)
	if relic_warning.get("choices", {}).get("left", {}).get("effects", {}).get(
			"_consumeTreasure") != true \
			or relic_request.get("sourceCardId") != "ch_deity_100" \
			or relic_prepared.get("flags", {}).get("used_relic_shield") != true \
			or relic_prepared.get("treasureInstances", {}).has(instance_id) \
			or relic_prepared.get("equipment", {}).get("weapon") != null \
			or relic_prepared.get("resources", {}).get("treasures", []).has(weapon_id):
		return _fail("deity equipped relic sacrifice did not settle once")
	var relic_plan: Dictionary = BattlePlanResolver.new(Registry.new()).resolve_persisted(relic_prepared)
	var relic_combat = CombatDomain.new(Registry.new())
	if relic_plan.get("launchAuthorized") != true \
			or not relic_combat.load_persisted_request(relic_request, relic_plan) \
			or int(relic_combat.state.player.block) < 3 \
			or int(relic_combat.state.enemy.atkPower) != 2:
		return _fail("deity relic counter did not reach battle")
	var hard_prepared: Dictionary = encounter.confirm(relic_pending, "right")
	if hard_prepared.get("phase") != "BATTLE_PENDING" \
			or not hard_prepared.get("treasureInstances", {}).has(instance_id) \
			or hard_prepared.get("flags", {}).get("used_relic_shield") == true \
			or gateway.build_request(hard_prepared).get("sourceCardId") != "ch_deity_100":
		return _fail("deity equipped hard fight incorrectly consumed relic")
	var relic_result := {"contractVersion": 2,
		"encounterInstanceId": relic_request.encounterInstanceId,
		"sourceCardId": relic_request.sourceCardId,
		"encounterId": relic_request.encounterId,
		"sourceContentHash": relic_request.sourceContentHash,
		"outcome": "victory",
		"combatReceipt": "combat:" + String(relic_request.encounterInstanceId),
		"postBattleState": {"encounterInstanceId": relic_request.encounterInstanceId,
			"terminal": true, "combatPhase": "VICTORY"}}
	var relic_return = BattleReturnFlow.new(ContentRepository.new(), gateway)
	var relic_won: Dictionary = relic_return.settle(relic_prepared, relic_result)
	if relic_won.get("realm") != "tribulation" \
			or relic_won.get("treasureInstances", {}).has(instance_id):
		return _fail("deity relic victory did not return to tribulation")
	var context: Dictionary = StageRouter.new(Registry.new()).resolve_choice(
		"ch_deity_100", "left", request.pendingResolution.combatCard,
		String(request.encounterInstanceId), request.pendingResolution,
		String(request.path), String(request.realm))
	context["deck"] = plan.deck.duplicate(true)
	var stage: Control = load("res://scenes/duel_stage_deity_gate_2d.tscn").instantiate()
	if not stage.bind_stage_context(context):
		stage.free()
		return _fail("deity source stage did not bind")
	root.add_child(stage)
	if not stage.has_hd2d_assets():
		return _fail("deity stage art unavailable")
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
			return _fail("deity %s result failed: %s" % [outcome, return_flow.last_error])
		var fact_id := "fact:%d:deity_main_debt_claim" % int(returned.get("lifeCount", 0))
		var verdict_id := "fact:%d:deity_main_karma_verdict" % int(returned.get("lifeCount", 0))
		var facts: Dictionary = returned.noncombatFlow.get("spineFacts", {})
		if outcome == "victory":
			if returned.realm != "tribulation" or returned.currentCardId != "breakthrough_reward" \
					or facts.get(fact_id, {}).get("status") != "consumed" \
					or facts.get(verdict_id, {}).get("status") != "active":
				return _fail("deity victory did not promote or settle spine")
			var cold: Dictionary = JSON.parse_string(JSON.stringify(returned))
			var selected: Dictionary = flow.dismiss(cold, "left")
			if selected.get("currentCardId") != "realm_arrival_tribulation":
				return _fail("deity victory did not reach tribulation arrival")
			cold = JSON.parse_string(JSON.stringify(selected))
			if flow.settle_epiphany(cold, "left").get("phase") != "FLOW_PENDING":
				return _fail("tribulation arrival cold recovery failed")
		elif facts.get(fact_id, {}).get("status") != "active" or facts.has(verdict_id):
			return _fail("deity retry incorrectly settled spine")
	print("NONCOMBAT_DEITY_GATE_ENTRY_PASS schedule=true warning=true preparations=3 plan=true battlefield=true karma=true relic=true outcomes=3 spine=true arrival=true")
	quit(0)
