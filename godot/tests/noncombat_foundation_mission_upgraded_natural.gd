extends "res://tests/noncombat_foundation_mission_natural.gd"

const CombatDomain = preload("res://scripts/combat_domain.gd")


func _camp_upgrade_index() -> int:
	return 0


func _fixed_roll() -> float:
	return -1.0


func _normal_seed() -> int:
	return 764850


func _iteration_limit() -> int:
	return 400


func _target_ready(game: RefCounted) -> bool:
	return String(game.state.deck[0]).ends_with("+")


func _battle_outcome_for_request(request: Dictionary) -> String:
	return "flee" if request.get("sourceCardId") == "ch_foundation_100" else "victory"


func _fight_fellow_before_camp() -> bool:
	return true


func _verify_shop_natural(game: RefCounted, path: String) -> void:
	if game.state.realm != "foundation" or game.state.phase != "NORMAL_PENDING" \
			or game.get_current_card().get("id") != "f_mission" \
			or not String(game.state.deck[0]).ends_with("+") \
			or not game.state.get("deckOperations", []).any(
				func(record: Variant) -> bool: return record is Dictionary \
					and record.get("operation") == "upgrade" \
					and record.get("toCardId") == game.state.deck[0]):
		return _fail("natural camp upgrade did not reach beast mission")
	var entry: Dictionary = game.state.duplicate(true)
	var cold = _shop_branch(FileAccess.get_file_as_bytes(game._store.v2_path), path)
	if cold == null or not _same(cold.state, entry) \
			or not cold.choose("right", cold.issue_choice_token()) \
			or not cold.choose("left", cold.issue_choice_token()) \
			or cold.state.phase != "BATTLE_PENDING":
		return _fail("natural upgraded mission could not strictly enter battle")
	var request: Dictionary = cold.battle_request()
	var plan: Dictionary = BattlePlanResolver.new(Registry.new()).resolve_persisted(
		cold.state)
	if plan.get("launchAuthorized") != true \
			or plan.get("deck", [])[0] != entry.deck[0] \
			or request.get("playerSnapshot", {}).get("battleLoadout", {}).get(
				"deck", [])[0] != entry.deck[0]:
		return _fail("natural upgraded mission plan lost camp card")
	var battle_cold = _shop_branch(FileAccess.get_file_as_bytes(
		cold._store.v2_path), path)
	if battle_cold == null or not _same(battle_cold.state, cold.state):
		return _fail("natural upgraded mission battle could not strictly restore")
	var combat = CombatDomain.new(Registry.new())
	if not combat.load_persisted_request(request, plan) \
			or not (combat.state.hand.has(entry.deck[0]) \
				or combat.state.drawPile.has(entry.deck[0])):
		return _fail("natural upgraded mission battle could not load upgraded card")
	var context: Dictionary = StageRouter.new(Registry.new()).resolve_choice(
		"f_mission", "right", request.get("pendingResolution", {}).get(
			"combatCard", {}), String(request.encounterInstanceId),
		request.get("pendingResolution", {}), String(request.path), String(request.realm))
	context["deck"] = plan.deck.duplicate(true)
	var stage: Control = load("res://scenes/duel_stage_mission_2d.tscn").instantiate()
	if context.is_empty() or not stage.bind_stage_context(context):
		return _fail("natural upgraded mission stage could not bind")
	root.add_child(stage)
	if not stage.has_hd2d_assets():
		return _fail("natural upgraded mission stage lacks source assets")
	stage.queue_free()
	await process_frame
	var pending_bytes := FileAccess.get_file_as_bytes(cold._store.v2_path)
	var story: Control = load("res://scenes/noncombat_opening.tscn").instantiate()
	story.save_path = ""
	root.add_child(story)
	await process_frame
	story.opening = battle_cold
	story.opening_store = battle_cold._store
	story.slot_screen.visible = false
	story.name_screen.visible = false
	story.path_screen.visible = false
	story.story_screen.visible = true
	story._set_scene_surface(true)
	story._render()
	var launch: Button = story.find_child("LaunchBattle", true, false)
	if launch == null or launch.disabled or not _same(story.opening.state,
			battle_cold.state):
		return _fail("natural upgraded mission did not boot in desktop story")
	launch.pressed.emit()
	await process_frame
	var battle: Control = story.active_battle
	if battle == null or not battle.stage_assets_ready \
			or not (battle.combat.state.hand.has(entry.deck[0]) \
				or battle.combat.state.drawPile.has(entry.deck[0])) \
			or FileAccess.get_file_as_bytes(cold._store.v2_path) != pending_bytes:
		return _fail("natural upgraded mission did not mount playable desktop battle")
	var flee: Button = battle.get_node_or_null("FleeBattle")
	if flee == null or flee.disabled:
		return _fail("natural upgraded mission cannot retreat")
	flee.pressed.emit()
	var result: Dictionary = battle.terminal_result()
	var return_button: Button = battle.get_node_or_null("ReturnToStory")
	if result.get("outcome") != "flee" or return_button == null \
			or return_button.disabled:
		return _fail("natural upgraded mission retreat lacked terminal receipt")
	return_button.pressed.emit()
	await process_frame
	var returned = _shop_branch(FileAccess.get_file_as_bytes(
		cold._store.v2_path), path)
	if story.active_battle != null or returned == null \
			or returned.get_current_card().get("id") != "combat_fled_f_mission" \
			or returned.submit_battle_result(result):
		return _fail("natural upgraded mission retreat did not return once")
	story.queue_free()
	await process_frame
	print("NONCOMBAT_FOUNDATION_MISSION_UPGRADED_NATURAL_PASS camp=true replay=true battle=true stage=true desktop=true retreat=true")
	quit(0)
