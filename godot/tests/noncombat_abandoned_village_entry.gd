extends "res://tests/noncombat_normal_runtime.gd"

func _run() -> void:
	var path := "user://tests/abandoned_village_entry_%d.json" % Time.get_ticks_usec()
	var game = Domain.new(Registry.new(), RunSession.new(path, "slot_3"), "slot_3")
	_set_zero_rolls(game)
	if not _reach_decision27(game):
		return _fail("natural pre-draw route failed")
	game._normal_roll_override = 0.12
	if not game.resume_flow() or game.get_current_card().get("id") != "q_beggar":
		return _fail("ordinary pool did not draw q_beggar")
	var before_stones := int(game.state.resources.spiritStone)
	if not game.choose("right", game.issue_choice_token()) \
			or int(game.state.resources.spiritStone) != before_stones - 10:
		return _fail("natural beggar gift did not settle")
	if not _continue_to(game, "thread_ab_village_1"):
		return _fail("beggar gift did not activate the first abandoned village node")
	var first: Dictionary = game.get_current_card()
	var source: Dictionary = game._content.read_module("threads:qi_threads")["threads"][0]
	if first.get("sceneImage") != source["nodes"][0]["card"]["sceneImage"] \
			or not _reopen(game):
		return _fail("first village node lost source scene or strict pending replay")
	var knowledge_before := int(game.state.get("knowledge", {}).get("world", 0))
	if not game.choose("right", game.issue_choice_token()) \
			or int(game.state.get("knowledge", {}).get("world", 0)) != knowledge_before + 10 \
			or game.state.get("storyThreadState", {}).get("threads", {}).get(
				"abandoned_village", {}).get("choices", [])[0].get("threadDirection") != "cautious" \
			or not _reopen(game):
		return _fail("first village choice or cold replay diverged")
	if not _continue_to(game, "thread_ab_village_2"):
		return _fail("second village node did not arrive")
	var second: Dictionary = game.get_current_card()
	if second.get("sceneImage") != source["nodes"][1]["card"]["sceneImage"] \
			or not _reopen(game):
		return _fail("second village node lost source scene or strict replay")
	if not game.choose("left", game.issue_choice_token()) \
			or game.state.get("storyThreadState", {}).get("threads", {}).get(
				"abandoned_village", {}).get("choices", [])[1].get("threadDirection") != "justice" \
			or not _reopen(game):
		return _fail("second village choice or cold replay diverged")
	if not _continue_to(game, "thread_ab_village_3"):
		return _fail("third village combat node did not arrive")
	var oracle: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(
		"res://tests/fixtures/abandoned_village_source.json"))
	var third: Dictionary = game.get_current_card()
	for key in ["id", "type", "title", "description", "sceneImage", "enemy", "choices"]:
		if not _same_value(third.get(key), oracle["entry"]["thirdCard"].get(key)):
			return _fail("third village combat card differs from browser: " + key)
	var ui: Control = load("res://scenes/noncombat_opening.tscn").instantiate()
	ui.save_path = ""
	root.add_child(ui)
	await process_frame
	ui.opening = game
	ui._render()
	var right_button: Button = ui.get_node(
		"DesktopMargin/ScreenStack/StoryScreen/SourceChoices/Choice_right")
	var shown: bool = ui.art_rect.texture != null \
		and ui.body_label.text == third["description"] \
		and right_button.text.begins_with(third["choices"]["right"]["text"]) \
		and not right_button.disabled
	root.remove_child(ui)
	ui.queue_free()
	if not shown:
		return _fail("desktop village combat card lost source art or right choice")
	if not _right_branch(game):
		return _fail("third village right combat direction did not preserve its source contract")
	if not _reopen(game) or not game.choose("left", game.issue_choice_token()):
		return _fail("third village left choice did not freeze combat warning")
	var warning: Dictionary = game.get_current_card()
	for key in ["id", "type", "title", "description", "sceneImage", "choices"]:
		if not _same_value(warning.get(key), oracle["entry"]["warningCard"].get(key)):
			return _fail("third village warning differs from browser: " + key)
	if not _reopen(game) or not game.choose("left", game.issue_choice_token()):
		return _fail("third village warning did not enter battle")
	var request: Dictionary = game.battle_request()
	if request.get("sourceCardId") != "thread_ab_village_3" \
			or request.get("threadId") != "abandoned_village" \
			or request.get("direction") != "left" or request.get("encounterId") != null \
			or not _same_value(request.get("pendingResolution", {}).get("choice"),
				oracle["entry"]["pendingResolution"]["choice"]) \
			or not _reopen(game):
		return _fail("third village pending contract lost source direction or cold replay")
	print("NONCOMBAT_ABANDONED_VILLAGE_ENTRY_PASS natural=true nodes=3 warning=true battle=true replay=true")
	quit(0)


func _continue_to(game: RefCounted, target: String) -> bool:
	for step in 20:
		if game.state.get("phase") == "FLOW_PENDING" and not game.resume_flow():
			return false
		if game.get_current_card().get("id") == target:
			return true
		if game.state.get("phase") == "BATTLE_PENDING":
			var request: Dictionary = game.battle_request()
			var result := {"contractVersion": 2,
				"encounterInstanceId": request.get("encounterInstanceId"),
				"sourceCardId": request.get("sourceCardId"),
				"encounterId": request.get("encounterId"),
				"sourceContentHash": request.get("sourceContentHash"),
				"outcome": "victory",
				"combatReceipt": "combat:" + String(request.get("encounterInstanceId", "")),
				"postBattleState": {"encounterInstanceId": request.get("encounterInstanceId"),
					"terminal": true, "combatPhase": "VICTORY"}}
			if not game.submit_battle_result(result):
				return false
			continue
		if game.state.get("phase") == "BATTLE_RESULT_PENDING":
			if not game.choose("down", game.issue_choice_token()):
				return false
			continue
		if game.state.get("phase") == "VENDOR_OPEN":
			if not game.close_vendor(game.issue_choice_token()):
				return false
			continue
		var direction := "left" if game.can_choose_direction("left") else "right"
		if game.get_current_card().get("id") == "q_shop" and game.can_choose_direction("down"):
			direction = "down"
		elif game.get_current_card().get("id") == "q_market" and game.can_choose_direction("right"):
			direction = "right"
		elif game.state.get("phase") == "MARKET_PENDING" and game.can_choose_direction("right"):
			direction = "right"
		if not game.choose(direction, game.issue_choice_token()):
			return false
	return false


func _reopen(game: RefCounted) -> bool:
	var loaded = Domain.new(Registry.new(), RunSession.new(game._store.legacy_path, "slot_3"), "slot_3")
	_set_zero_rolls(loaded)
	loaded._normal_roll_override = 0.12
	return loaded.restore() and _same(loaded.state, game.state) \
		and _same(loaded.get_current_card(), game.get_current_card())


func _same_value(left: Variant, right: Variant) -> bool:
	return JSON.parse_string(JSON.stringify(left)) == JSON.parse_string(JSON.stringify(right))


func _right_branch(game: RefCounted) -> bool:
	var path := "user://tests/abandoned_village_right_%d.json" % Time.get_ticks_usec()
	var store = RunSession.new(path, "slot_3")
	if store.commit_snapshot(game.state, -1).get("ok") != true:
		return false
	var branch = Domain.new(Registry.new(), store, "slot_3")
	_set_zero_rolls(branch)
	branch._normal_roll_override = 0.12
	if not branch.restore() or not branch.choose("right", branch.issue_choice_token()):
		return false
	var choice: Dictionary = game.get_current_card()["choices"]["right"]
	var warning: Dictionary = branch.get_current_card()
	if warning.get("title") != choice.get("combatPresentation", {}).get("warningTitle") \
			or warning.get("sceneImage") != choice.get("sceneImage") \
			or not _reopen(branch) or not branch.choose("left", branch.issue_choice_token()):
		return false
	var request: Dictionary = branch.battle_request()
	if request.get("sourceCardId") != "thread_ab_village_3" \
			or request.get("direction") != "right" \
			or request.get("battlefieldId") != choice.get("combatPresentation", {}).get("battlefieldId") \
			or not _reopen(branch):
		return false
	var result := {"contractVersion": 2,
		"encounterInstanceId": request.encounterInstanceId,
		"sourceCardId": request.sourceCardId, "encounterId": request.encounterId,
		"sourceContentHash": request.sourceContentHash, "outcome": "victory",
		"combatReceipt": "combat:" + String(request.encounterInstanceId),
		"postBattleState": {"encounterInstanceId": request.encounterInstanceId,
			"terminal": true, "combatPhase": "VICTORY"}}
	if not branch.submit_battle_result(result):
		return false
	var runtime: Dictionary = branch.state["storyThreadState"]["threads"]["abandoned_village"]
	return runtime.get("nodeIndex") == 3 and runtime.get("choices", []).size() == 3 \
		and runtime["choices"][2].get("threadDirection") == "redeem" \
		and runtime["choices"][2].get("outcomeContext", {}).get("combatOutcome") == "victory" \
		and _reopen(branch)
