extends SceneTree

const Registry = preload("res://scripts/runtime_data_registry.gd")
const Domain = preload("res://scripts/noncombat_domain.gd")
const RunSession = preload("res://scripts/noncombat_run_session.gd")
const Resolver = preload("res://scripts/battle_plan_resolver.gd")
const Combat = preload("res://scripts/combat_domain.gd")
const OpeningScene = preload("res://scenes/noncombat_opening.tscn")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var save_path := "user://tests/whitefox_live_%d.json" % Time.get_ticks_usec()
	var game = Domain.new(Registry.new(), RunSession.new(save_path))
	if not game.start("sword"):
		return _fail("whitefox natural route could not start")
	for _choice in range(5):
		if not game.choose("left", game.issue_choice_token()):
			return _fail("whitefox tutorial route failed")
	if not game.choose("right", game.issue_choice_token()) \
			or not game.choose("left", game.issue_choice_token()) \
			or not game.resume_flow() \
			or not game.choose("left", game.issue_choice_token()) \
			or not game.choose("right", game.issue_choice_token()) \
			or not game.resume_flow() \
			or not game.choose("right", game.issue_choice_token()) \
			or not game.choose("left", game.issue_choice_token()) \
			or game.state.get("currentCardId") != "q_whiteFox_3" \
			or not game.choose("left", game.issue_choice_token()) \
			or not game.choose("left", game.issue_choice_token()):
		return _fail("whitefox third quest did not persist a natural battle")
	var restored = Domain.new(Registry.new(), RunSession.new(save_path))
	if not restored.restore():
		return _fail("whitefox pending request cold restore failed")
	var request: Dictionary = restored.battle_request()
	if request.get("sourceCardId") != "q_whiteFox_3" or request.get("encounterId") != null \
			or request.get("questId") != "white_fox_line":
		return _fail("whitefox request lost its inline quest origin")
	var plan: Dictionary = Resolver.new(Registry.new()).resolve_persisted(restored.state)
	if plan.get("launchAuthorized") != true \
			or plan.get("enemy") != request.get("pendingResolution", {}).get(
				"combatCard", {}).get("enemy") \
			or plan.get("deck") != request.get("playerSnapshot", {}).get(
				"battleLoadout", {}).get("deck"):
		return _fail("whitefox inline battle has no authenticated source plan/current deck")
	var forged_state: Dictionary = restored.state.duplicate(true)
	forged_state["pendingBattle"]["pendingResolution"]["combatCard"]["enemy"]["hp"] += 1
	var forged_plan: Dictionary = plan.duplicate(true)
	forged_plan["enemy"]["hp"] += 1
	if not Resolver.new(Registry.new()).resolve_persisted(forged_state).is_empty() \
			or Resolver.new(Registry.new()).inspect_request(request).get(
				"launchAuthorized") == true \
			or Combat.new(Registry.new()).load_persisted_request(request, forged_plan):
		return _fail("whitefox forged enemy or unauthenticated plan became launchable")
	var combat = Combat.new(Registry.new())
	if not combat.load_persisted_request(request, plan):
		return _fail("whitefox inline battle could not load source rules")
	if combat.state["enemyIntent"].get("type") != "debuff" \
			or combat.state["enemy"].get("intentIndex") != 1:
		return _fail("whitefox first authored hound intent is missing")
	var source_cycle: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(
		"res://tests/fixtures/whitefox_hound_intents_source.json"))
	var sword_cycle: Dictionary = {}
	for row in source_cycle.get("rows", []):
		if row.get("path") == "sword":
			sword_cycle = row
			break
	if sword_cycle.get("states", []).size() != 4:
		return _fail("whitefox sword source intent cycle missing")
	for turn_index in range(1, 4):
		var expected: Dictionary = sword_cycle["states"][turn_index]
		var reaction: Dictionary = sword_cycle["inputs"][turn_index * 2 - 1]
		var roll := float(reaction["resistanceRoll"]) if reaction.get(
			"resistanceRoll") != null else 0.99
		if not combat.end_turn() or not combat.choose_reaction("TAKE_HIT", roll) \
				or combat.state["player"]["hp"] != expected["playerHp"] \
				or combat.state["player"]["block"] != expected["playerBlock"] \
				or int(combat.state["playerStatus"].get("weak", 0)) != expected["playerWeak"] \
				or combat.state["enemyIntent"] != expected["intent"] \
				or combat.state["enemy"].get("intentIndex") != expected["intentIndex"]:
			return _fail("whitefox hound intent cycle differs from source: " + str(expected))
	var story: Control = OpeningScene.instantiate()
	story.save_path = save_path
	root.add_child(story)
	await process_frame
	var launch: Button = story.find_child("LaunchBattle", true, false)
	if launch == null or launch.disabled:
		return _fail("whitefox desktop did not offer the saved battle")
	launch.pressed.emit()
	await process_frame
	var battle: Control = story.active_battle
	var visual: Dictionary = request["pendingResolution"]["combatCard"]["combatPresentation"]
	var field: TextureRect = battle.duel_stage.find_child("SourceBattlefield", true, false) \
		if battle != null and battle.duel_stage != null else null
	var enemy: TextureRect = battle.duel_stage.find_child("SourceEnemy", true, false) \
		if battle != null and battle.duel_stage != null else null
	var registry = Registry.new()
	if battle == null or not battle.stage_assets_ready or field == null or enemy == null \
			or field.texture != registry.texture_for(visual["sceneImage"]) \
			or enemy.texture != registry.texture_for(
				visual["actorCards"]["enemy"]["image"]):
		return _fail("whitefox desktop did not mount authored hound battlefield/actor")
	battle.end_button.pressed.emit()
	await process_frame
	if battle.combat.state.get("phase") != "REACTION_OPEN" \
			or battle.reaction_buttons[0].disabled:
		return _fail("whitefox first hound reaction did not open")
	battle.reaction_buttons[0].pressed.emit()
	if not await _saw_weak_presentation(battle, visual, registry) \
			or not await _wait_presentations(battle) \
			or int(battle.combat.state["playerStatus"].get("weak", 0)) != 1:
		return _fail("whitefox real desktop hound bark lost its authored weak frame/effect")
	var flee: Button = battle.get_node_or_null("FleeBattle")
	if flee == null or flee.disabled or not flee.visible:
		return _fail("whitefox authored flee option unavailable")
	flee.pressed.emit()
	var result: Dictionary = battle.terminal_result()
	var return_button: Button = battle.get_node_or_null("ReturnToStory")
	if result.get("outcome") != "flee" or return_button == null \
			or return_button.disabled or not return_button.visible:
		return _fail("whitefox real battle did not produce a returnable flee receipt")
	return_button.pressed.emit()
	await process_frame
	var settled = Domain.new(Registry.new(), RunSession.new(save_path))
	if story.active_battle != null or not settled.restore() \
			or settled.state.get("questState", {}).get("questOutcomes", {}).get(
				"white_fox_line") == "completed" \
			or settled.submit_battle_result(result):
		return _fail("whitefox flee incorrectly completed quest or repeated its receipt")
	story.queue_free()
	await process_frame
	print("NONCOMBAT_WHITEFOX_LIVE_BATTLE_PASS source_plan=true hound_cycle=true desktop=true source_art=true flee=true replay=true")
	quit(0)


func _wait_presentations(battle: Control) -> bool:
	for _frame in range(150):
		await create_timer(0.05).timeout
		if battle.pending_presentations == 0 and not battle.combat.input_locked:
			return battle.presentation_problem.is_empty()
	return false


func _saw_weak_presentation(battle: Control, visual: Dictionary,
		registry: RefCounted) -> bool:
	var authored_frame = registry.texture_for(
		visual["actorCards"]["enemy"]["intentFrames"]["debuff"])
	var authored_effects := []
	for path in visual["vfx"]["weak"]["frames"]:
		authored_effects.append(registry.texture_for(path))
	for _frame in range(12):
		await create_timer(0.05).timeout
		var enemy: TextureRect = battle.duel_stage.find_child("SourceEnemy", true, false)
		var effect: TextureRect = battle.duel_stage.find_child("SourceWeakVfx", true, false)
		if enemy != null and effect != null and effect.visible \
				and enemy.texture == authored_frame and authored_effects.has(effect.texture):
			return true
	return false


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
