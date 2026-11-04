extends SceneTree

const Registry = preload("res://scripts/runtime_data_registry.gd")
const Domain = preload("res://scripts/noncombat_domain.gd")
const RunSession = preload("res://scripts/noncombat_run_session.gd")
const BattlePlanResolver = preload("res://scripts/battle_plan_resolver.gd")
const CombatDomain = preload("res://scripts/combat_domain.gd")
const SourceStage = preload("res://scripts/duel_stage_source_2d.gd")
const StageRouter = preload("res://scripts/combat_stage_router.gd")
const OpeningScene = preload("res://scenes/noncombat_opening.tscn")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	for path_id in ["sword", "spell", "body", "pill"]:
		var save_path := "user://tests/mountain_live_%s_%d.json" % [path_id, Time.get_ticks_usec()]
		var game = Domain.new(Registry.new(), RunSession.new(save_path))
		if not game.start(path_id):
			return _fail(path_id + " opening failed")
		for direction in ["right", "right", "left", "left", "left"]:
			if not game.choose(direction, game.issue_choice_token()):
				return _fail(path_id + " teaching route failed")
		# The first fight has separate real desktop evidence; this receipt sets up
		# the second fight's natural story state without claiming a two-fight UI run.
		if not game.submit_battle_result(_first_result(game.battle_request())) \
				or not game.choose("left", game.issue_choice_token()):
			return _fail(path_id + " first reward failed")
		if game.state.phase == "FLOW_PENDING" and not game.resume_flow():
			return _fail(path_id + " continuation failed")
		if game.state.phase == "MILESTONE_PENDING" and not game.choose("left", game.issue_choice_token()):
			return _fail(path_id + " milestone failed")
		if game.state.currentCardId != "q_mountain_shadow_approach" \
				or not game.choose("left", game.issue_choice_token()) \
				or not game.choose("left", game.issue_choice_token()):
			return _fail(path_id + " mountain warning failed")
		var request: Dictionary = game.battle_request()
		var before := FileAccess.get_file_as_bytes(game._store.v2_path)
		var restored = Domain.new(Registry.new(), RunSession.new(save_path))
		if request.get("sourceCardId") != "q_mountain_shadow_approach" \
				or not restored.restore():
			return _fail(path_id + " second request cold restore failed")
		request = restored.battle_request()
		var resolver = BattlePlanResolver.new(Registry.new())
		var plan: Dictionary = resolver.resolve_persisted(restored.state)
		if path_id == "sword":
			var forged: Dictionary = restored.state.duplicate(true)
			forged["pendingBattle"]["pendingResolution"]["combatCard"]["enemy"]["hp"] += 1
			if not BattlePlanResolver.new(Registry.new()).resolve_persisted(forged).is_empty() \
					or BattlePlanResolver.new(Registry.new()).inspect_request(request).get(
						"launchAuthorized") == true:
				return _fail("forged mountain foe or unauthenticated request was launchable")
		if plan.get("launchAuthorized") != true \
				or plan.get("enemy") != request.get("pendingResolution", {}).get("combatCard", {}).get("enemy") \
				or plan.get("deck") != request.get("playerSnapshot", {}).get("battleLoadout", {}).get("deck"):
			var context: Dictionary = StageRouter.new(Registry.new()).resolve_encounter(
				String(request["encounterId"]))
			context["path"] = path_id
			context["deck"] = request["playerSnapshot"]["battleLoadout"]["deck"]
			var missing: Array = []
			var asset_registry = Registry.new()
			for source_path in SourceStage._source_paths(asset_registry, context):
				if asset_registry.texture_for(String(source_path)) == null:
					missing.append(source_path)
			return _fail(path_id + " second battle plan lacks source enemy, current deck, or stage: " +
				resolver.last_error + " available=" + str(plan.get("sceneAvailable")) +
				" authorized=" + str(plan.get("launchAuthorized")) +
				" enemy_eq=" + str(plan.get("enemy") == request.get("pendingResolution", {}).get(
					"combatCard", {}).get("enemy")) +
				" deck_eq=" + str(plan.get("deck") == request.get("playerSnapshot", {}).get(
					"battleLoadout", {}).get("deck")) +
				" scene=" + str(plan.get("stageScene")) + " missing=" + str(missing))
		var combat = CombatDomain.new(Registry.new())
		if not combat.load_persisted_request(request, plan) \
				or combat.state.get("enemy", {}).get("hp") != plan.get("enemy", {}).get("hp"):
			return _fail(path_id + " second battle did not load source enemy")
		if plan.get("enemy", {}).get("planGraph") is Dictionary:
			var graph: Dictionary = plan["enemy"]["planGraph"]
			var first_intent: Dictionary = graph.get("states", {}).get(
				graph.get("initialState", ""), {}).get("intent", {})
			if combat.state.get("enemyIntent", {}).get("value") != first_intent.get("value"):
				return _fail(path_id + " balanced source intent was replaced by template intent")
		var story: Control = OpeningScene.instantiate()
		story.save_path = save_path
		root.add_child(story)
		await process_frame
		var launch: Button = story.find_child("LaunchBattle", true, false)
		if launch == null or launch.disabled:
			return _fail(path_id + " desktop has no second battle launch phase=" +
				str(story.opening.state.get("phase")) + " status=" +
				str(story.status_label.text) + " slot=" +
				str(story.opening.state.get("runClock", {}).get("lifeId")))
		launch.pressed.emit()
		await process_frame
		var battle: Control = story.active_battle
		if battle == null or not battle.stage_assets_ready \
				or battle.combat.state.get("phase") != "PLAYER_TURN" \
				or battle.combat.state.get("enemy", {}).get("hp") != plan.get("enemy", {}).get("hp") \
				or FileAccess.get_file_as_bytes(game._store.v2_path) != before:
			return _fail(path_id + " desktop second battle stage or owner failed")
		var wanted := "defeat" if path_id == "sword" else (
			"victory" if path_id == "pill" else "flee")
		if wanted == "defeat":
			var attack: Button = _find_card(battle.hand_row,
				["sword_probe", "sword_edge", "sword_followthrough"])
			if attack == null:
				return _fail("sword second battle has no opening attack card")
			attack.pressed.emit()
			if not await _wait_presentations(battle):
				return _fail("sword mountain attack did not present")
			battle.end_button.pressed.emit()
			await process_frame
			if battle.combat.state.get("phase") != "REACTION_OPEN":
				return _fail("sword mountain attack did not open reaction")
			battle.reaction_buttons[0].pressed.emit()
			if not await _wait_presentations(battle):
				return _fail("sword mountain defeat did not present")
		elif wanted == "victory":
			var ember: Button = _find_card(battle.hand_row, ["pill_ember"])
			if ember == null:
				return _fail("pill second battle has no opening ember")
			ember.pressed.emit()
			if not await _wait_presentations(battle):
				return _fail("pill mountain victory did not present")
		else:
			var flee: Button = battle.get_node_or_null("FleeBattle")
			if flee == null or not flee.visible or flee.disabled:
				return _fail(path_id + " second battle lacks permitted flee")
			flee.pressed.emit()
		var result: Dictionary = battle.terminal_result()
		if result.get("outcome") != wanted or result.get("sourceCardId") != request.get("sourceCardId"):
			return _fail(path_id + " second battle produced wrong source receipt")
		battle._render()
		var return_button: Button = battle.get_node_or_null("ReturnToStory")
		if return_button == null or not return_button.visible or return_button.disabled:
			return _fail(path_id + " second battle cannot return")
		if path_id == "sword":
			story.opening_store.fail_promotion_once = true
			return_button.pressed.emit()
			await process_frame
			if story.active_battle != battle or story.opening.state.get("phase") != "BATTLE_PENDING" \
					or FileAccess.get_file_as_bytes(game._store.v2_path) != before:
				return _fail("failed mountain result write changed owner or save bytes")
		return_button.pressed.emit()
		await process_frame
		if story.active_battle != null or story.opening.state.get("phase") == "BATTLE_PENDING":
			return _fail(path_id + " second battle did not settle")
		var settled = Domain.new(Registry.new(), RunSession.new(save_path))
		if not settled.restore() or settled.submit_battle_result(result):
			return _fail(path_id + " second battle receipt was not single-use")
		story.queue_free()
		await process_frame
	print("NONCOMBAT_MOUNTAIN_LIVE_BATTLE_PASS paths=4 source_enemy=true current_deck=true desktop=true victory=true defeat=true flee=true atomic=true replay=true")
	quit(0)


func _first_result(request: Dictionary) -> Dictionary:
	return {"contractVersion": 2, "encounterInstanceId": request.encounterInstanceId,
		"sourceCardId": request.sourceCardId, "encounterId": request.encounterId,
		"sourceContentHash": request.sourceContentHash, "outcome": "victory",
		"combatReceipt": "combat:" + String(request.encounterInstanceId),
		"postBattleState": {"encounterInstanceId": request.encounterInstanceId,
			"terminal": true, "combatPhase": "VICTORY"}}


func _find_card(hand: HBoxContainer, priority: Array) -> Button:
	for card_id in priority:
		for child in hand.get_children():
			if child is Button and not child.disabled and \
					child.get_meta("source_card_id", "") == card_id:
				return child as Button
	return null


func _wait_presentations(battle: Control) -> bool:
	for _frame in range(150):
		await create_timer(0.05).timeout
		if battle.pending_presentations == 0 and not battle.combat.input_locked:
			return battle.presentation_problem.is_empty()
	return false


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
