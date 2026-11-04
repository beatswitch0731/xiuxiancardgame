extends SceneTree

const Registry = preload("res://scripts/runtime_data_registry.gd")
const Repository = preload("res://scripts/noncombat_content_repository.gd")
const Domain = preload("res://scripts/noncombat_domain.gd")
const StoryThreads = preload("res://scripts/noncombat_story_threads_v2_flow.gd")
const BattleGateway = preload("res://scripts/noncombat_battle_gateway.gd")
const BattlePlan = preload("res://scripts/battle_plan_resolver.gd")
const CombatDomain = preload("res://scripts/combat_domain.gd")
const StageRouter = preload("res://scripts/combat_stage_router.gd")
const RunSession = preload("res://scripts/noncombat_run_session.gd")
const BattleScene = preload("res://scenes/main.tscn")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var game = Domain.new(Registry.new(), null, "slot_2")
	if not game.start("sword"):
		return _fail("last lesson source route could not start")
	var state: Dictionary = game.state.duplicate(true)
	state.realm = "deity"
	state.phase = "FLOW_PENDING"
	state.decisionCheckpoint = {"sourceCardId": "q_last_lesson_entry"}
	state.flags = {}
	state.turn = 12
	state.runClock.decisionIndex = 12
	state.currentLocation = "宗门"
	var prior := state.duplicate(true)
	prior.turn = 11
	prior.runClock.decisionIndex = 11
	var flow = StoryThreads.new(Repository.new())
	var authored_nodes: Array = Repository.new().read_module(
		"threads:last_lesson_threads").threads[0].nodes
	if not flow.tick(prior, state):
		return _fail("last lesson source activation failed: " + flow.last_error)
	var directions := ["left", "right", "right", "right", "left", "right"]
	var source_ids := ["thread_last_lesson_n0", "thread_last_lesson_n1",
		"thread_last_lesson_n2", "thread_last_lesson_n3",
		"thread_last_lesson_n4", "thread_last_lesson_n5"]
	for index in source_ids.size():
		var pending: Dictionary = flow.resume(state)
		if pending.get("currentCardId") != source_ids[index]:
			return _fail("last lesson node %d was not ready at its source interval: %s; error=%s; lesson=%s; location=%s" % [
				index, pending.get("currentCardId"), flow.last_error,
				state.get("storyThreadState", {}).get("threads", {}).get(
					"bairen_last_lesson", {}), state.get("currentLocation")])
		if index == 3 and pending.get("pendingThreadCard", {}).get(
				"_threadVariantId") != "sect_trial_sword_loan":
			return _fail("direct loan did not project source dispute variant")
		if index == 3:
			var fight: Dictionary = flow.thread_combat_card(pending)
			var choice: Dictionary = fight.get("choices", {}).get("left", {})
			if choice.get("triggerCombat") != true or choice.get("enemy", {}).get(
					"id") != "last_lesson_sect_trial_sword" \
					or choice.get("combatPresentation", {}).get("battlefieldId") != \
						"battlefield_last_lesson_market_stone_street_provisional_v1" \
					or fight.get("choices", {}).get("right", {}).has("triggerCombat"):
				return _fail("last lesson left fight source or one-sided combat overlay invalid")
			var battle_state := pending.duplicate(true)
			battle_state["pendingThreadCombatDirection"] = "left"
			var gateway = BattleGateway.new(Registry.new(), Repository.new())
			var offer: Dictionary = gateway.source_offer(battle_state)
			var resolution: Dictionary = gateway.source_resolution_for_offer(battle_state)
			if offer.get("threadId") != "bairen_last_lesson" \
					or offer.get("sourceCardId") != "thread_last_lesson_n3" \
					or resolution.get("choice", {}).get("enemy", {}).get("id") != \
						"last_lesson_sect_trial_sword" \
					or resolution.get("combatCard", {}).get("enemy", {}).get("hp") != 17:
				return _fail("last lesson source battle gateway lost loan variant")
		if index == 2 and not flow.choice_available(pending, "left") \
				or index == 3 and not flow.choice_available(pending, "left"):
			return _fail("last lesson vendor or combat direction was unavailable")
		if index == 3 and not await _test_battle_branch(pending):
			return _fail("last lesson battle handoff or assist card unavailable")
		if index == 5:
			var description := String(pending.get("pendingThreadCard", {}).get(
				"description", ""))
			if not description.contains(String(authored_nodes[5].historyEchoes[0].text)) \
					or description.contains(String(authored_nodes[5].historyEchoes[1].text)):
				return _fail("farewell history echo was not projected")
		state = flow.settle_choice(pending, directions[index])
		if state.is_empty():
			return _fail("last lesson node %d could not settle: %s" % [index, flow.last_error])
		if index == 0 and state.get("currentLocation") != "qingyun_sword_tomb":
			return _fail("summons did not move player to sword tomb")
		if index == 2 and state.get("currentLocation") != "qingyun_trial_sword_terrace":
			return _fail("sect loan did not move player to trial terrace")
		if index == 3 and state.get("currentLocation") != "upper_realm_heaven_gate":
			return _fail("negotiation did not move player to farewell gate")
		if index == 4:
			var master: Dictionary = state.get("worldContinuityState", {}).get(
				"npcs", {}).get("bai_ren", {})
			if master.get("lifecycle") != "ASCENDED" or master.get(
					"manifestation") != "ECHO_ONLY":
				return _fail("master did not ascend at farewell")
	var before_letter := state.duplicate(true)
	before_letter.turn += 7
	before_letter.runClock.decisionIndex += 7
	if flow.resume(before_letter).get("currentCardId") == "thread_last_lesson_n6":
		return _fail("upper letter arrived before authored eight-turn delay")
	state.turn += 8
	state.runClock.decisionIndex += 8
	var letter: Dictionary = flow.resume(state)
	if letter.get("currentCardId") != "thread_last_lesson_n6":
		return _fail("upper letter did not arrive after authored delay")
	var done: Dictionary = flow.settle_choice(letter, "left")
	var thread: Dictionary = done.get("storyThreadState", {}).get("threads", {}).get(
		"bairen_last_lesson", {})
	if not done.get("flags", {}).get("bairen_last_lesson_complete", false) \
			or thread.get("status") != "completed" or thread.get(
				"receipt", {}).get("nodes", []).size() != 7:
		return _fail("last lesson complete flag or seven-node receipt missing")
	print("NONCOMBAT_LAST_LESSON_DIRECT_ROUTE_PASS nodes=7 loan=true negotiation=true battle=true ascended=true letter=true")
	quit(0)


func _test_battle_branch(pending: Dictionary) -> bool:
	var game = Domain.new(Registry.new(), null, "slot_2")
	if not game.start("sword"):
		return false
	game.state = pending.duplicate(true)
	if not game.choose("left", game.issue_choice_token()) \
			or game.state.get("phase") != "WARNING_PENDING" \
			or not game.choose("left", game.issue_choice_token()) \
			or game.state.get("phase") != "BATTLE_PENDING":
		return false
	var request: Dictionary = game.battle_request()
	var plan: Dictionary = BattlePlan.new(Registry.new()).resolve_persisted(game.state)
	if request.get("threadId") != "bairen_last_lesson" \
			or plan.get("sourceCardId") != "thread_last_lesson_n3" \
			or plan.get("enemy", {}).get("id") != "last_lesson_sect_trial_sword" \
			or plan.get("launchAuthorized") != true:
		push_warning("last lesson plan failed: " + str(plan.get("sceneAvailable")) +
			" / " + str(plan.get("launchAuthorized")))
		return false
	var battle_ui: Control = BattleScene.instantiate()
	battle_ui.battle_request = request.duplicate(true)
	battle_ui.battle_plan = plan.duplicate(true)
	root.add_child(battle_ui)
	await process_frame
	var flee_button: Button = battle_ui.get_node_or_null("FleeBattle")
	if battle_ui.duel_stage == null or battle_ui.duel_stage.get_script().resource_path != \
			"res://scripts/duel_stage_last_lesson_2d.gd" \
			or not battle_ui.stage_assets_ready or flee_button == null \
			or not flee_button.visible or flee_button.disabled:
		battle_ui.queue_free()
		await process_frame
		return false
	flee_button.pressed.emit()
	var desktop_result: Dictionary = battle_ui.terminal_result()
	battle_ui.queue_free()
	await process_frame
	if desktop_result.get("outcome") != "flee" \
			or desktop_result.get("sourceCardId") != "thread_last_lesson_n3":
		return false
	var before_result: Dictionary = game.state.duplicate(true)
	var stage_context: Dictionary = StageRouter.new(Registry.new()).resolve_choice(
		"thread_last_lesson_n3", "left", request.pendingResolution.combatCard,
		String(request.encounterInstanceId), request.pendingResolution,
		String(request.path), String(request.realm))
	stage_context["deck"] = plan.deck.duplicate(true)
	var stage: Control = load(String(plan.stageScene)).instantiate()
	if not stage.bind_stage_context(stage_context) \
			or stage.get_script().resource_path != \
				"res://scripts/duel_stage_last_lesson_2d.gd":
		stage.free()
		return false
	stage.free()
	for outcome in ["victory", "defeat"]:
		var probe = Domain.new(Registry.new(), null, "slot_2")
		if not probe.start("sword"):
			return false
		probe.state = before_result.duplicate(true)
		var certified := {"contractVersion": request.contractVersion,
			"encounterInstanceId": request.encounterInstanceId,
			"sourceCardId": request.sourceCardId,
			"encounterId": request.encounterId,
			"sourceContentHash": request.sourceContentHash,
			"outcome": outcome,
			"combatReceipt": "combat:" + request.encounterInstanceId,
			"postBattleState": {"encounterInstanceId": request.encounterInstanceId,
				"terminal": true, "combatPhase": outcome.to_upper()}}
		if not probe.submit_battle_result(certified) \
				or probe.state.get("phase") != "BATTLE_RESULT_PENDING" \
				or probe.state.get("currentLocation") != "upper_realm_heaven_gate" \
				or probe.state.storyThreadState.threads.bairen_last_lesson.choices[3].get(
					"outcomeContext", {}).get("combatOutcome") != outcome:
			push_warning("last lesson certified result failed: " + outcome + " " +
				String(probe._battle_return_flow.last_error))
			return false
		if outcome == "defeat" and (int(probe.state.attributes.health) != 1 \
				or int(probe.state.knowledge.world) != int(
					before_result.knowledge.world) + 1):
			return false
		if not probe.choose("down", probe.issue_choice_token()):
			return false
		var branch_flow = StoryThreads.new(Repository.new())
		var branch_farewell: Dictionary = branch_flow.resume(probe.state)
		var branch_done: Dictionary = branch_flow.settle_choice(
			branch_farewell, "left")
		var branch_echo: Dictionary = branch_flow.resume(branch_done)
		if branch_echo.get("pendingThreadCard", {}).get(
				"_threadVariantId") != "right_" + outcome:
			return false
	var combat = CombatDomain.new(Registry.new())
	if not combat.load_persisted_request(request, plan):
		return false
	var assist_index: int = combat.state.get("hand", []).find(
		"comp_jian_linger_ice_resonance")
	if assist_index < 0 or not combat.play_card(assist_index) \
			or combat.state.get("storyAssistPlayed") != true \
			or int(combat.state.get("playerStatus", {}).get("sword_intent", 0)) != 1 \
			or int(combat.state.get("player", {}).get("block", 0)) < 2 \
			or not combat.flee():
		push_warning("assist/play/flee failed: " + str(assist_index) + " state=" +
			str(combat.state.get("storyAssistPlayed")) + " phase=" +
			str(combat.state.get("phase")))
		return false
	var result := {"contractVersion": request.contractVersion,
		"encounterInstanceId": request.encounterInstanceId,
		"sourceCardId": request.sourceCardId,
		"encounterId": request.encounterId,
		"sourceContentHash": request.sourceContentHash,
		"outcome": "flee", "combatReceipt": "combat:" + request.encounterInstanceId,
		"postBattleState": {"encounterInstanceId": request.encounterInstanceId,
			"terminal": true, "combatPhase": "FLEE",
			"playerHp": combat.state.player.hp, "enemyHp": combat.state.enemy.hp,
			"turn": combat.state.turn}}
	var battle_store = RunSession.new("user://tests/last_lesson_battle_%d.json" %
		Time.get_ticks_usec(), "slot_2")
	var staged: Dictionary = battle_store.commit_snapshot(game.state, -1)
	if staged.get("ok") != true:
		return false
	game._store = battle_store
	game._store_revision = int(staged.revision)
	var before_commit: Dictionary = game.state.duplicate(true)
	var bytes := FileAccess.get_file_as_string(battle_store.v2_path)
	battle_store.fail_promotion_once = true
	if game.submit_battle_result(result) or game.state != before_commit \
			or FileAccess.get_file_as_string(battle_store.v2_path) != bytes:
		return false
	var fortune_before := int(game.state.attributes.fortune)
	if not game.submit_battle_result(result) \
			or game.state.get("phase") != "BATTLE_RESULT_PENDING" \
			or int(game.state.attributes.fortune) != fortune_before - 1 \
			or game.state.get("currentLocation") != "upper_realm_heaven_gate" \
			or game.state.storyThreadState.threads.bairen_last_lesson.choices[3].get(
				"outcomeContext", {}).get("combatOutcome") != "flee" \
			or game.submit_battle_result(result):
		push_warning("battle return failed: " + String(game._battle_return_flow.last_error) +
			" phase=" + String(game.state.get("phase")))
		return false
	if JSON.parse_string(JSON.stringify(battle_store.load_state())) != \
			JSON.parse_string(JSON.stringify(game.state)):
		return false
	if not game.choose("down", game.issue_choice_token()):
		return false
	var resumed_flow = StoryThreads.new(Repository.new())
	var farewell: Dictionary = resumed_flow.resume(game.state)
	if farewell.get("currentCardId") != "thread_last_lesson_n4":
		return false
	var after_farewell: Dictionary = resumed_flow.settle_choice(farewell, "left")
	var echo: Dictionary = resumed_flow.resume(after_farewell)
	return echo.get("pendingThreadCard", {}).get("_threadVariantId") == "right_flee"


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
