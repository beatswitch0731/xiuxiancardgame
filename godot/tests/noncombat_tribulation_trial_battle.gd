extends "res://tests/noncombat_foundation_normal_pool.gd"

const StageRouter = preload("res://scripts/combat_stage_router.gd")


func _run() -> void:
	for outcome in ["victory", "defeat", "flee"]:
		var game = Domain.new(Registry.new(), null, "slot_3")
		if not game.start("spell"):
			return _fail("trial fixture did not start")
		game.state.realm = "tribulation"
		game.state.phase = "NORMAL_PENDING"
		game.state.currentCardId = "t_immortal_test"
		game.state.maxHealth = 100
		game.state.attributes.health = 80
		game.state.maxDaoHeart = 100
		game.state.attributes.daoHeart = 50
		game.state["noncombatFlow"] = {"sourceContentHash": game._battle_gateway.source_content_hash()}
		if not game.choose("left", game.issue_choice_token()) \
				or game.get_current_card().get("id") != "it_entrance" \
				or not game.choose("left", game.issue_choice_token()) \
				or game.get_current_card().get("id") != "it_combat" \
				or not game.can_choose_direction("left"):
			return _fail("trial combat node did not open: " + outcome)
		var before: Dictionary = game.state.duplicate(true)
		var orphan: Dictionary = before.duplicate(true)
		orphan.dungeonRun = null
		if not game._battle_gateway.offer_from_state(orphan).is_empty():
			return _fail("orphan trial combat node accepted without its dungeon run")
		if not game.choose("left", game.issue_choice_token()) \
				or game.state.get("phase") != "WARNING_PENDING" \
				or game.get_current_card().get("id") != "_warning_it_combat":
			return _fail("trial warning did not confirm: " + outcome)
		var warning_cold: Dictionary = JSON.parse_string(JSON.stringify(game.state))
		if game._encounter_flow.warning_card(warning_cold).get("id") != "_warning_it_combat" \
				or not game.choose("left", game.issue_choice_token()):
			return _fail("trial warning cold recovery failed: " + outcome)
		var request: Dictionary = game.battle_request()
		var resolver = BattlePlanResolver.new(Registry.new())
		var plan: Dictionary = resolver.resolve_persisted(game.state)
		var pending_cold: Dictionary = JSON.parse_string(JSON.stringify(game.state))
		if request.get("sourceCardId") != "it_combat" \
				or plan.get("launchAuthorized") != true \
				or game._battle_gateway.build_request(pending_cold).get("sourceCardId") != "it_combat":
			return _fail("trial battle request unavailable: " + resolver.last_error)
		var combat = CombatDomain.new(Registry.new())
		if not combat.load_persisted_request(request, plan) \
				or combat.state.get("enemyIntent", {}).is_empty():
			return _fail("trial combat rules did not load")
		var context: Dictionary = StageRouter.new(Registry.new()).resolve_choice(
			"it_combat", "left", request.pendingResolution.combatCard,
			String(request.encounterInstanceId), request.pendingResolution,
			String(request.path), String(request.realm))
		context["deck"] = plan.deck.duplicate(true)
		var stage: Control = load(String(plan.stageScene)).instantiate()
		if not stage.bind_stage_context(context):
			return _fail("trial battle stage did not bind")
		root.add_child(stage)
		if not stage.has_hd2d_assets():
			return _fail("trial battle stage lacks art")
		stage.queue_free()
		var result := {"contractVersion": 2,
			"encounterInstanceId": request.encounterInstanceId,
			"sourceCardId": request.sourceCardId,
			"encounterId": request.encounterId,
			"sourceContentHash": request.sourceContentHash,
			"outcome": outcome,
			"combatReceipt": "combat:" + String(request.encounterInstanceId),
			"postBattleState": {"encounterInstanceId": request.encounterInstanceId,
				"terminal": true, "combatPhase": outcome.to_upper()}}
		if not game.submit_battle_result(result) \
				or game.state.get("phase") != "BATTLE_RESULT_PENDING" \
				or game.submit_battle_result(result):
			return _fail("trial result was not committed exactly once: " + outcome)
		var result_cold: Dictionary = JSON.parse_string(JSON.stringify(game.state))
		if game._battle_return_flow.card(result_cold).get("id") != game.state.currentCardId:
			return _fail("trial result card cold recovery failed: " + outcome)
		if outcome == "victory":
			if game.state.resources.pills.get("渡劫丹", 0) != before.resources.pills.get("渡劫丹", 0) + 1 \
					or int(game.state.resources.spiritStone) < int(before.resources.spiritStone) + 50 \
					or game.state.get("dungeonRun", {}).get("dungeonId") != "immortal_trial":
				return _fail("trial victory rewards or run state invalid")
			var reward_token := game.issue_choice_token()
			if not game.choose("down", reward_token):
				return _fail("trial reward dismiss failed: " + JSON.stringify({
					"token": reward_token, "card": game.get_current_card().get("id"),
					"flowError": game._battle_return_flow.last_error,
					"sourceError": game._battle_return_flow.source_error,
					"phase": game.state.phase, "current": game.state.currentCardId}))
			if game.get_current_card().get("id") != "it_reward":
				return _fail("trial reward node missing: " + JSON.stringify({
					"phase": game.state.phase, "card": game.state.currentCardId,
					"node": game.state.get("dungeonNodeIndex")}))
			if not game.choose("left", game.issue_choice_token()):
				return _fail("trial treasure choice failed")
			if game.get_current_card().get("id") != "it_blessing":
				return _fail("trial blessing node missing")
			if not game.choose("right", game.issue_choice_token()) \
					or game.state.get("dungeonOutcomeReceipts", []).back().get("outcome") != "success":
				return _fail("trial final node did not complete")
		else:
			if game.state.get("dungeonRun") != null \
					or game.state.get("dungeonOutcomeReceipts", []).back().get("outcome") != (
						"failure" if outcome == "defeat" else "abandon"):
				return _fail("trial loss did not close its run: " + outcome)
			if outcome == "defeat" and (int(game.state.attributes.health) != int(before.attributes.health) - 3 \
						or int(game.state.attributes.daoHeart) != int(before.attributes.daoHeart) - 2):
				return _fail("trial defeat effects mismatch")
			if outcome == "flee" and int(game.state.resources.lifespan) != int(before.resources.lifespan) - 1:
				return _fail("trial flee effect mismatch")
			if not game.choose("down", game.issue_choice_token()):
				return _fail("trial nonvictory result could not dismiss")
	print("NONCOMBAT_TRIBULATION_TRIAL_BATTLE_PASS outcomes=3")
	quit(0)
