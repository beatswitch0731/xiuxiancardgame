extends "res://tests/noncombat_foundation_normal_pool.gd"


func _run() -> void:
	for route in ["left", "right"]:
		var game = Domain.new(Registry.new(), null, "slot_3")
		if not game.start("pill"):
			return _fail("foundation dungeon fixture could not start")
		game.state.realm = "foundation"
		game.state.phase = "NORMAL_PENDING"
		game.state.currentCardId = "f_trial"
		game.state.runClock.decisionIndex = 1
		game.state.turn = 1
		game.state["noncombatFlow"] = {"sourceContentHash": game._battle_gateway.source_content_hash()}
		game.state["normalFlow"] = game._prepare_normal_flow(game.state)
		if game.state.normalFlow.is_empty():
			return _fail("foundation dungeon ordinary draw cursor unavailable")
		var health := int(game.state.attributes.health)
		var lifespan := int(game.state.resources.lifespan)
		if not game.can_choose_direction("right") \
				or not game.choose("right", game.issue_choice_token()) \
				or game.state.phase != "NORMAL_PENDING" \
				or game.state.dungeonNodeId != "echo" \
				or game.get_current_card().get("id") != "realm_elder" \
				or int(game.state.attributes.health) != health - 2 \
				or int(game.state.resources.lifespan) != lifespan - 1:
			return _fail("foundation dungeon source entry failed")
		var run_id := String(game.state.dungeonRun.sessionId)
		if not game.choose("left", game.issue_choice_token()) \
				or game.get_current_card().get("id") != "_dungeon_fork_fork" \
				or game.state.dungeonPath != ["echo", "fork"]:
			return _fail("foundation dungeon elder did not reach source fork")
		var knowledge_before := int(game.state.get("knowledge", {}).get("world", 0))
		var health_before := int(game.state.attributes.health)
		if not game.choose(route, game.issue_choice_token()):
			return _fail("foundation dungeon fork choice failed: " + route)
		if route == "left":
			if game.get_current_card().get("id") != "realm_prepare" \
					or game.state.dungeonPath != ["echo", "fork", "prepare"] \
					or int(game.state.get("knowledge", {}).get("world", 0)) \
					!= knowledge_before + 1 \
					or not game.choose("right", game.issue_choice_token()) \
					or not game.state.deck.has("mana_potion"):
				return _fail("foundation dungeon deduction/preparation rewards differ")
		elif int(game.state.attributes.health) != health_before - 1 \
				or game.state.dungeonPath != ["echo", "fork", "boss"]:
			return _fail("foundation dungeon force route differs")
		if game.get_current_card().get("id") != "realm_guardian" \
				or game.state.dungeonRun.sessionId != run_id:
			return _fail("foundation dungeon boss node lost owner: " + route)
		var boss_state: Dictionary = game.state.duplicate(true)
		var abandoned: bool = game.abandon_dungeon(game.issue_choice_token())
		if not abandoned \
				or game.state.phase != "FLOW_PENDING" \
				or game.state.dungeon != null \
				or game.state.dungeonOutcomeReceipts.back().get("outcome") != "abandon" \
				or game.state.dungeonOutcomeReceipts.back().get("sessionId") != run_id:
			return _fail("foundation dungeon abandon did not settle source owner")
		if route == "right":
			game.state = boss_state
			game._current_card_id = "realm_guardian"
			game._choice_token += 1
			if not game.can_choose_direction("left") \
					or not game.choose("left", game.issue_choice_token()) \
					or game.state.phase != "WARNING_PENDING" \
					or game.get_current_card().get("id") != "_warning_realm_guardian" \
					or not game.choose("left", game.issue_choice_token()) \
					or game.state.phase != "BATTLE_PENDING" \
					or game.battle_request().get("sourceCardId") != "realm_guardian":
				return _fail("foundation dungeon boss warning/request failed: " + JSON.stringify({
					"phase": game.state.phase, "request": game.battle_request(),
					"health": game.state.attributes.health,
					"maxHealth": game.state.get("maxHealth"),
					"deck": game.state.get("deck"),
					"starterDeckPath": game.state.get("starterDeckPath"),
					"flow": game.flow_failure_reason()}))
			var plan: Dictionary = BattlePlanResolver.new(Registry.new()).resolve_persisted(
				game.state)
			if plan.get("launchAuthorized") != true:
				return _fail("foundation dungeon boss plan not loadable: " + str(plan))
			var request: Dictionary = game.battle_request()
			var context: Dictionary = load("res://scripts/combat_stage_router.gd").new(
				Registry.new()).resolve_choice("realm_guardian", "left",
				request.pendingResolution.combatCard,
				String(request.encounterInstanceId), request.pendingResolution,
				String(request.path), String(request.realm))
			context["deck"] = plan.deck.duplicate(true)
			var stage: Control = load(
				"res://scenes/duel_stage_guardian_2d.tscn").instantiate()
			if not stage.bind_stage_context(context):
				stage.free()
				return _fail("foundation dungeon guardian stage did not bind")
			root.add_child(stage)
			if not stage.has_hd2d_assets():
				return _fail("foundation dungeon guardian stage assets missing")
			if not stage.show_boss_phase(2) or not stage.show_boss_phase(3):
				return _fail("foundation dungeon guardian phase images missing")
			stage.queue_free()
			var combat = load("res://scripts/combat_domain.gd").new(Registry.new())
			if not combat.load_persisted_request(game.battle_request(), plan) \
					or combat.state.get("bossPhaseIndex") != 0 \
					or int(combat.state.enemy.hp) != 5:
				return _fail("foundation dungeon three-phase battle did not load")
			for phase_index in [1, 2, 3]:
				combat.state.enemy.hp = 1
				combat.state.enemy.block = 0
				combat.state.hand = ["pill_ember"]
				combat.state.qi = 3
				if not combat.play_card(0):
					return _fail("foundation dungeon phase strike failed: " + str(phase_index))
				if phase_index < 3 and (combat.state.bossPhaseIndex != phase_index \
						or int(combat.state.enemy.hp) != (7 if phase_index == 1 else 9) \
						or combat.state.phase != "PLAYER_TURN"):
					return _fail("foundation dungeon phase transition failed: " + str(combat.state))
			if combat.state.phase != "VICTORY":
				return _fail("foundation dungeon boss did not finish after phase three")
			var pending: Dictionary = game.state.duplicate(true)
			for outcome in ["victory", "defeat", "flee"]:
				var branch = Domain.new(Registry.new(), null, "slot_3")
				if not branch.start("pill"):
					return _fail("foundation dungeon result branch could not start")
				branch.state = pending.duplicate(true)
				branch._current_card_id = "realm_guardian"
				var branch_request: Dictionary = branch.battle_request()
				var result := {"contractVersion": 2,
					"encounterInstanceId": branch_request.encounterInstanceId,
					"sourceCardId": "realm_guardian", "encounterId": null,
					"sourceContentHash": branch_request.sourceContentHash,
					"outcome": outcome,
					"combatReceipt": "combat:" + String(branch_request.encounterInstanceId),
					"postBattleState": {"encounterInstanceId": branch_request.encounterInstanceId,
						"terminal": true, "combatPhase": outcome.to_upper()}}
				if not branch.submit_battle_result(result):
					return _fail("foundation dungeon boss result failed: %s/%s" % [outcome, branch.flow_failure_reason()])
				if outcome == "victory":
					var victory_card_id := String(branch.get_current_card().get("id", ""))
					var dismissed := branch.choose("down", branch.issue_choice_token())
					if victory_card_id != "combat_reward" or not dismissed \
							or branch.get_current_card().get("id") != "realm_treasure":
						return _fail("foundation dungeon victory did not reach treasure")
					var reward_chosen := branch.choose("left", branch.issue_choice_token())
					if not reward_chosen \
							or branch.state.phase != "FLOW_PENDING" \
							or branch.state.dungeonRun != null \
							or branch.state.dungeonOutcomeReceipts.back().outcome != "success":
						return _fail("foundation dungeon treasure choice did not complete run")
				elif branch.state.dungeonRun != null \
						or branch.state.dungeonOutcomeReceipts.back().outcome != (
							"failure" if outcome == "defeat" else "abandon"):
					return _fail("foundation dungeon nonvictory did not settle run")
	print("NONCOMBAT_FOUNDATION_DUNGEON_ENTRY_PASS entry=true fork=true prepare=true boss_node=true abandon=true")
	quit(0)
