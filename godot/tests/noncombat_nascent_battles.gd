extends "res://tests/noncombat_foundation_normal_pool.gd"

const BattleGateway = preload("res://scripts/noncombat_battle_gateway.gd")
const EncounterFlow = preload("res://scripts/noncombat_encounter_flow.gd")
const BattleReturnFlow = preload("res://scripts/noncombat_battle_return_flow.gd")
const QuestFlow = preload("res://scripts/noncombat_quest_flow.gd")
const StageRouter = preload("res://scripts/combat_stage_router.gd")

func _run() -> void:
	var count := 0
	for source_id in ["n_hunt", "ar_boss"]:
		var game = Domain.new(Registry.new(), null, "slot_3")
		if not game.start("spell"):
			return _fail("nascent battle fixture could not start")
		game.state.realm = "nascent"
		game.state.factionProgress = QuestFlow.new(ContentRepository.new())._initial_faction_progress(
			ContentRepository.new().read_module("world:factions"))
		game.state.maxHealth = 100
		game.state.attributes.health = 80
		game.state.phase = "NORMAL_PENDING"
		game.state.currentCardId = "n_ancient_ruins" if source_id == "ar_boss" else source_id
		if source_id == "n_hunt":
			game.state.turn = 1
			game.state.runClock.decisionIndex = 1
		if source_id == "ar_boss":
			for direction in ["left", "left", "right", "right"]:
				if not game.choose(direction, game.issue_choice_token()):
					return _fail("ruins battle route failed at " + String(game.state.currentCardId))
		if game.get_current_card().get("id") != source_id \
				or not game.can_choose_direction("left"):
			return _fail("nascent combat source unavailable: " + source_id)
		var state: Dictionary = game.state.duplicate(true)
		var gateway = BattleGateway.new(Registry.new())
		var offer: Dictionary = gateway.offer_from_state(state)
		var resolution: Dictionary = gateway.source_resolution_for_offer(state)
		if offer.get("sourceCardId") != source_id \
				or resolution.get("combatCard", {}).get("enemy", {}).get("templateId") \
				!= ("nascent_soul_hunter" if source_id == "n_hunt" else "tomb_guardian_nascent"):
			var overlay: Dictionary = ContentRepository.new().read_module(
				"combat:migrated_presentations").get("presentations", {}).get(source_id + ":left", {})
			return _fail("nascent offer or source resolution missing: " +
				JSON.stringify({"source": source_id, "error": gateway.source_error,
					"offer": offer.get("sourceCardId"),
					"resolution": resolution.get("sourceCardId"),
					"sourceArt": game._content.asset_status(String(state.get("currentCardId"))),
					"battleArt": game._content.asset_status(String(overlay.get("sceneImage", ""))),
					"actorArt": game._content.asset_status(String(overlay.get("actorCards", {}).get("enemy", {}).get("image", "")))}))
		var encounter = EncounterFlow.new(ContentRepository.new(), gateway)
		var pending: Dictionary = encounter.accept(state)
		var prepared: Dictionary = encounter.confirm(pending, "left")
		var request: Dictionary = gateway.build_request(prepared)
		if pending.get("phase") != "WARNING_PENDING" \
				or prepared.get("phase") != "BATTLE_PENDING" \
				or request.get("sourceCardId") != source_id:
			return _fail("nascent warning or request failed: " + source_id + " " +
				JSON.stringify({"pending": pending.get("phase"),
					"prepared": prepared.get("phase"), "request": request.get("sourceCardId"),
					"gatewayError": gateway.source_error,
					"warning": encounter.warning_card(pending).get("id")}))
		var resolver = BattlePlanResolver.new(Registry.new())
		var plan: Dictionary = resolver.resolve_persisted(prepared)
		if plan.get("launchAuthorized") != true:
			return _fail("nascent battle plan unavailable: " + source_id + " " + resolver.last_error)
		var combat = CombatDomain.new(Registry.new())
		if not combat.load_persisted_request(request, plan) \
				or combat.state.get("enemyIntent", {}).is_empty():
			return _fail("nascent battle rules did not load: " + source_id)
		var context: Dictionary = StageRouter.new(Registry.new()).resolve_choice(
			source_id, "left", request.pendingResolution.combatCard,
			String(request.encounterInstanceId), request.pendingResolution,
			String(request.path), String(request.realm))
		context["deck"] = plan.deck.duplicate(true)
		var stage: Control = load(String(plan.stageScene)).instantiate()
		if not stage.bind_stage_context(context):
			return _fail("nascent source stage did not bind: " + source_id)
		root.add_child(stage)
		if not stage.has_hd2d_assets():
			return _fail("nascent source stage lacks mounted art: " + source_id)
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
				return _fail("nascent %s %s failed: %s" % [source_id, outcome,
					String(return_flow.last_error)])
			if returned.get("phase") != "BATTLE_RESULT_PENDING" \
					or source_id == "ar_boss" and outcome != "victory" \
					and returned.get("dungeonRun") != null:
				return _fail("nascent combat result state invalid: " + source_id + "/" + outcome)
			if not returned.get("noncombatFlow") is Dictionary:
				returned["noncombatFlow"] = {}
			returned.noncombatFlow["sourceContentHash"] = gateway.source_content_hash()
			var result_card: Dictionary = return_flow.card(returned)
			if result_card.is_empty() or result_card.get("id") != returned.currentCardId:
				return _fail("nascent result card source mismatch: " + source_id + "/" + outcome + " " +
					JSON.stringify({"error": return_flow.last_error, "sourceError": return_flow.source_error,
						"result": result_card.get("id"), "pending": returned.currentCardId,
						"flowHash": returned.get("noncombatFlow", {}).get("sourceContentHash")}))
			if outcome == "victory":
				if source_id == "n_hunt" and (returned.get("flags", {}).get("combatGlory") != true \
						or returned.get("factionProgress", {}).get("reputations", {}).get(
							"xuesha_sect") >= prepared.get("factionProgress", {}).get(
								"reputations", {}).get("xuesha_sect", 0)):
					return _fail("hunter victory did not write faction and glory consequences")
				if source_id == "ar_boss":
					var done: Dictionary = return_flow.dismiss(returned, "down")
					if done.is_empty() or done.get("dungeonRun") != null \
							or done.get("dungeonOutcomeReceipts", []).back().get("outcome") != "success":
						return _fail("ruins boss victory did not complete after reward")
			elif source_id == "n_hunt" and outcome == "defeat" and returned.get(
				"factionProgress", {}).get("reputations", {}).get("qingyun_sword") \
				>= prepared.get("factionProgress", {}).get("reputations", {}).get(
					"qingyun_sword", 0):
				return _fail("hunter defeat did not reduce faction standing")
			count += 1
	print("NONCOMBAT_NASCENT_BATTLES_PASS sources=2 outcomes=" + str(count))
	quit(0)
