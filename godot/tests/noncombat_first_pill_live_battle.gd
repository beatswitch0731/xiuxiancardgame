extends SceneTree

const Registry = preload("res://scripts/runtime_data_registry.gd")
const Domain = preload("res://scripts/noncombat_domain.gd")
const RunSession = preload("res://scripts/noncombat_run_session.gd")
const BattlePlanResolver = preload("res://scripts/battle_plan_resolver.gd")
const OpeningScene = preload("res://scenes/noncombat_opening.tscn")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var save_path := "user://tests/first_pill_live_%d.json" % Time.get_ticks_usec()
	var game = Domain.new(Registry.new(), RunSession.new(save_path))
	if not game.start("pill"):
		return _fail("pill opening failed")
	for direction in ["right", "right", "left", "left", "left"]:
		if not game.choose(direction, game.issue_choice_token()):
			return _fail("source pill path did not reach battle")
	var request: Dictionary = game.battle_request()
	var before: String = FileAccess.get_file_as_string(game._store.v2_path)
	var restored = Domain.new(Registry.new(), RunSession.new(save_path))
	if request.get("encounterId") != "enc_trial_pill_poison" or not restored.restore():
		return _fail("pill pending battle could not cold restore")
	var resolver = BattlePlanResolver.new(Registry.new())
	var plan: Dictionary = resolver.resolve_persisted(restored.state)
	if plan.get("launchAuthorized") != true:
		return _fail("source pill battlefield not authorized: " + resolver.last_error + " " + str(plan))
	var story: Control = OpeningScene.instantiate()
	story.save_path = save_path
	root.add_child(story)
	await process_frame
	var launch: Button = story.find_child("LaunchBattle", true, false)
	if launch == null:
		return _fail("desktop pill battle has no LaunchBattle")
	launch.pressed.emit()
	await process_frame
	var battle: Control = story.active_battle
	if battle == null or battle.combat.state.get("phase") != "PLAYER_TURN" \
			or battle.combat.state.get("encounterId") != "enc_trial_pill_poison" \
			or not battle.stage_assets_ready or battle.duel_stage == null \
			or FileAccess.get_file_as_string(game._store.v2_path) != before:
		return _fail("desktop pill battle did not start with source art and saved owner")
	for _frame in range(90):
		if not battle.combat.input_locked:
			break
		await process_frame
	if battle.combat.input_locked:
		return _fail("desktop pill opening did not unlock the player turn")
	var hand: Array = battle.combat.state.get("hand", [])
	var action_index: int = hand.find("pill_recycle")
	if action_index < 0:
		action_index = hand.find("pill_guard")
	if action_index < 0 or not battle.combat.play_card(action_index):
		return _fail("desktop source pill card was rejected index=" + str(action_index) +
			" hand=" + str(battle.combat.state.get("hand")) +
			" locked=" + str(battle.combat.input_locked) +
			" energy=" + str(battle.combat.state.get("energy")))
	for _frame in range(90):
		await process_frame
		if battle.pending_presentations == 0 and not battle.combat.input_locked:
			break
	if battle.pending_presentations != 0 or battle.combat.input_locked \
			or not battle.presentation_problem.is_empty():
		return _fail("pill action presentation did not finish")
	var flee: Button = battle.get_node_or_null("FleeBattle")
	if flee == null or not flee.visible or flee.disabled:
		return _fail("pill battle lacks permitted flee")
	flee.pressed.emit()
	var result: Dictionary = battle.terminal_result()
	if result.get("outcome") != "flee" or result.get("encounterInstanceId") != request.get("encounterInstanceId"):
		return _fail("pill battle did not produce source-owned flee terminal")
	battle._render()
	var return_button: Button = battle.get_node_or_null("ReturnToStory")
	if return_button == null or not return_button.visible or return_button.disabled:
		return _fail("pill flee terminal cannot return to story")
	story.opening_store.fail_promotion_once = true
	return_button.pressed.emit()
	await process_frame
	if story.active_battle != battle or story.opening.state.get("phase") != "BATTLE_PENDING" \
			or FileAccess.get_file_as_string(game._store.v2_path) != before:
		return _fail("failed pill result write did not preserve terminal and save")
	return_button.pressed.emit()
	await process_frame
	if story.active_battle != null or story.opening.state.get("phase") == "BATTLE_PENDING":
		return _fail("pill terminal did not settle into story")
	var settled = Domain.new(Registry.new(), RunSession.new(save_path))
	if not settled.restore() or settled.submit_battle_result(result):
		return _fail("pill terminal receipt did not cold restore exactly once")
	story.queue_free()
	for _frame in range(3):
		await process_frame
	await create_timer(0.1).timeout
	print("NONCOMBAT_FIRST_PILL_LIVE_BATTLE_PASS desktop=true action=true flee=true atomic=true replay=true")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)

