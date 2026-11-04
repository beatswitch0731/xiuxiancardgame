extends SceneTree

const Registry = preload("res://scripts/runtime_data_registry.gd")
const Domain = preload("res://scripts/noncombat_domain.gd")
const FactionEvents = preload("res://scripts/noncombat_faction_events.gd")
const BattlePlanResolver = preload("res://scripts/battle_plan_resolver.gd")
const CombatDomain = preload("res://scripts/combat_domain.gd")
const StageRouter = preload("res://scripts/combat_stage_router.gd")
const FactionStageScene = preload("res://scenes/duel_stage_faction_wumeng_2d.tscn")
const BattleScene = preload("res://scenes/main.tscn")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	for outcome in ["victory", "defeat", "flee"]:
		var game = Domain.new(Registry.new())
		if not game.start("body") or not game.choose(
				"right", game.issue_choice_token()):
			return _fail("could not prepare faction battle baseline")
		var prepared: Dictionary = game.state.duplicate(true)
		prepared.realm = "foundation"
		prepared.currentLocation = "宗门"
		prepared.phase = "FACTION_PENDING"
		prepared.currentCardId = "faction_wumeng_gatekeeper_call"
		prepared.pendingFactionCard = FactionEvents.new().source_card(prepared,
			"faction_wumeng_gatekeeper_call")
		prepared.decisionCheckpoint = {"version": 1,
			"cardId": prepared.currentCardId,
			"sourceCardId": "tutorial_1", "turn": prepared.turn,
			"decisionIndex": prepared.runClock.decisionIndex}
		game.state = prepared
		game._current_card_id = prepared.currentCardId
		if game.get_current_card().get("id") != prepared.currentCardId \
				or not game.can_choose_direction("left") \
				or not game.choose("left", game.issue_choice_token()) \
				or game.state.get("phase") != "WARNING_PENDING":
			return _fail("faction invitation did not reach combat warning: " + outcome)
		if not game.choose("left", game.issue_choice_token()) \
				or game.state.get("phase") != "BATTLE_PENDING" \
				or game.state.get("currentLocation") != "武盟雷峰":
			return _fail("faction warning did not commit authored battle entry")
		var request: Dictionary = game.battle_request()
		if request.get("sourceCardId") != prepared.currentCardId \
				or request.get("encounterId") != "enc_faction_wumeng_elite":
			return _fail("faction battle request did not retain source authority")
		var registry = Registry.new()
		var plan: Dictionary = BattlePlanResolver.new(registry).resolve_persisted(game.state)
		if plan.get("launchAuthorized") != true \
				or plan.get("stageScene") != "res://scenes/duel_stage_faction_wumeng_2d.tscn":
			return _fail("faction battle plan cannot launch: " + outcome)
		var combat = CombatDomain.new(registry)
		if not combat.load_persisted_request(request, plan) \
				or combat.state.get("enemy", {}).get("planRuntime", {}).get(
					"planId") != "wumeng_gatekeeper_adaptation_v1":
			return _fail("faction battle rules did not load: " + outcome)
		var context: Dictionary = StageRouter.new(registry).resolve_choice(
			request.sourceCardId, request.direction,
			request.pendingResolution.combatCard, request.encounterInstanceId,
			request.pendingResolution, request.path, request.realm)
		context.path = plan.path
		context.deck = plan.deck
		var stage = FactionStageScene.instantiate()
		if not stage.bind_stage_context(context):
			stage.free()
			return _fail("faction 2D stage did not bind: " + outcome)
		stage.free()
		if outcome == "victory":
			var battle_ui: Control = BattleScene.instantiate()
			battle_ui.battle_request = request.duplicate(true)
			battle_ui.battle_plan = plan.duplicate(true)
			root.add_child(battle_ui)
			await process_frame
			var flee_button: Button = battle_ui.get_node_or_null("FleeBattle")
			if battle_ui.duel_stage == null \
					or battle_ui.duel_stage.get_script().resource_path != \
						"res://scripts/duel_stage_source_2d.gd" \
					or not battle_ui.stage_assets_ready or flee_button == null \
					or not flee_button.visible or flee_button.disabled:
				battle_ui.queue_free()
				await process_frame
				return _fail("faction desktop battle scene did not launch")
			flee_button.pressed.emit()
			var desktop_result: Dictionary = battle_ui.terminal_result()
			battle_ui.queue_free()
			await process_frame
			if desktop_result.get("outcome") != "flee" \
					or desktop_result.get("sourceCardId") != request.sourceCardId:
				return _fail("faction desktop flee did not produce source result")
		var result := {"contractVersion": request.contractVersion,
			"encounterInstanceId": request.encounterInstanceId,
			"sourceCardId": request.sourceCardId,
			"encounterId": request.encounterId,
			"sourceContentHash": request.sourceContentHash,
			"outcome": outcome,
			"combatReceipt": "combat:" + request.encounterInstanceId,
			"postBattleState": {"encounterInstanceId": request.encounterInstanceId,
				"terminal": true, "combatPhase": outcome.to_upper()}}
		if not game.submit_battle_result(result) \
				or game.state.get("phase") != "BATTLE_RESULT_PENDING":
			return _fail("faction battle outcome did not settle: " + outcome +
				" / " + game.flow_failure_reason())
		var expected_rep: int = {"victory": 6, "defeat": -2, "flee": -4}[outcome]
		if int(game.state.factionProgress.reputations.wumeng_alliance) != expected_rep \
				or int(game.state.get("modifiers", {}).get("rawPower", 0)) != (1 if outcome == "victory" else 0) \
				or game.get_current_card().is_empty():
			return _fail("faction outcome reputation, raw power, or authored result missing")
		if not game.choose("down", game.issue_choice_token()) \
				or game.state.has("pendingFactionCard"):
			return _fail("faction result did not release source invitation")
	print("NONCOMBAT_FACTION_COMBAT_PASS warning=true plan=true rules=true desktop_flee=true outcomes=3 return=true")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
