extends "res://tests/noncombat_foundation_shop_natural.gd"


func _fixed_roll() -> float:
	return 0.39


func _target_card_id() -> String:
	return "f_trial"


func _verify_shop_natural(game: RefCounted, path: String) -> void:
	if game.state.realm != "foundation" or game.state.phase != "NORMAL_PENDING" \
			or game.get_current_card().get("id") != "f_trial":
		return _fail("natural foundation dungeon card not actionable")
	var entry: Dictionary = game.state.duplicate(true)
	var entry_bytes := FileAccess.get_file_as_bytes(game._store.v2_path)
	var branch = _shop_branch(entry_bytes, path)
	if branch == null or not _same(branch.state, entry):
		return _fail("foundation dungeon entry did not strictly restore")
	var entered: bool = branch.choose("right", branch.issue_choice_token())
	if not entered \
			or branch.get_current_card().get("id") != "realm_elder":
		return _fail("natural foundation dungeon entry failed: entered=%s phase=%s current=%s hp=%s lifespan=%s policy=%s" % [entered, branch.state.phase, branch.get_current_card().get("id"), branch.state.attributes.health, branch.state.resources.lifespan, branch._normal_choice_policy.last_error])
	var active = _shop_branch(FileAccess.get_file_as_bytes(
		branch._store.v2_path), path)
	var same_active: bool = active != null and _same(active.state, branch.state)
	var elder_direction := "left" if same_active and active.can_choose_direction(
		"left") else "right"
	var elder_chosen: bool = same_active and active.can_choose_direction(
		elder_direction) and active.choose(elder_direction,
		active.issue_choice_token())
	if not elder_chosen or active.get_current_card().get("id") != "_dungeon_fork_fork":
		return _fail("foundation dungeon elder/fork did not strictly restore: " + JSON.stringify({
			"restored": active != null, "same": same_active,
			"chosen": elder_chosen, "direction": elder_direction,
			"phase": active.state.phase if active != null else "",
			"card": active.get_current_card().get("id") if active != null else "",
			"policy": active._normal_choice_policy.last_error if active != null else ""}))
	var fork = _shop_branch(FileAccess.get_file_as_bytes(
		active._store.v2_path), path)
	if fork == null or not _same(fork.state, active.state) \
			or not fork.choose("left", fork.issue_choice_token()) \
			or fork.get_current_card().get("id") != "realm_prepare":
		return _fail("foundation dungeon fork did not strictly restore")
	var prepared = _shop_branch(FileAccess.get_file_as_bytes(
		fork._store.v2_path), path)
	if prepared == null:
		return _fail("foundation dungeon prepare cold restore rejected")
	var same_prepare: bool = _same(prepared.state, fork.state)
	var prepare_chosen: bool = prepared.choose("right", prepared.issue_choice_token())
	if not same_prepare or not prepare_chosen \
			or prepared.get_current_card().get("id") != "realm_guardian":
		return _fail("foundation dungeon preparation did not strictly restore: same=%s chosen=%s phase=%s card=%s policy=%s" % [same_prepare, prepare_chosen, prepared.state.phase, prepared.get_current_card().get("id"), prepared._normal_choice_policy.last_error])
	var boss = _shop_branch(FileAccess.get_file_as_bytes(
		prepared._store.v2_path), path)
	if boss == null or not _same(boss.state, prepared.state) \
			or not boss.choose("left", boss.issue_choice_token()) \
			or boss.state.phase != "WARNING_PENDING":
		return _fail("foundation dungeon boss warning did not strictly restore")
	var warning = _shop_branch(FileAccess.get_file_as_bytes(
		boss._store.v2_path), path)
	if warning == null or not _same(warning.state, boss.state) \
			or not warning.choose("left", warning.issue_choice_token()) \
			or warning.state.phase != "BATTLE_PENDING":
		return _fail("foundation dungeon boss battle did not strictly restore")
	var request: Dictionary = warning.battle_request()
	var pending: Dictionary = warning.state.duplicate(true)
	var battle = _shop_branch(FileAccess.get_file_as_bytes(
		warning._store.v2_path), path)
	if battle == null or not _same(battle.state, pending) \
			or request.get("sourceCardId") != "realm_guardian":
		return _fail("foundation dungeon battle request did not strictly restore")
	var pending_bytes := FileAccess.get_file_as_bytes(battle._store.v2_path)
	var result: Dictionary = _result_for(request, "victory")
	var foreign := result.duplicate(true)
	foreign.encounterInstanceId = "foreign:dungeon:boss"
	if battle.submit_battle_result(foreign) or not _same(battle.state, pending):
		return _fail("foundation dungeon accepted foreign boss result")
	battle._store.fail_promotion_once = true
	if battle.submit_battle_result(result) or not _same(battle.state, pending) \
			or FileAccess.get_file_as_bytes(battle._store.v2_path) != pending_bytes:
		return _fail("foundation dungeon failed result write changed pending save")
	if not battle.submit_battle_result(result) \
			or battle.get_current_card().get("id") != "combat_reward" \
			or battle.submit_battle_result(result):
		return _fail("foundation dungeon natural victory result failed")
	var reward = _shop_branch(FileAccess.get_file_as_bytes(
		battle._store.v2_path), path)
	if reward == null or not _same(reward.state, battle.state) \
			or not reward.choose("down", reward.issue_choice_token()) \
			or reward.get_current_card().get("id") != "realm_treasure":
		return _fail("foundation dungeon boss reward did not strictly restore")
	var treasure_bytes := FileAccess.get_file_as_bytes(reward._store.v2_path)
	var right_path := "user://tests/foundation_dungeon_right_%d.json" % Time.get_ticks_usec()
	var right = _shop_branch(treasure_bytes, right_path)
	if right == null or not _same(right.state, reward.state):
		return _fail("foundation dungeon right reward did not strictly restore")
	var stones_before := int(right.state.resources.spiritStone)
	var golden_before := int(right.state.resources.pills.get("golden", 0))
	if not right.choose("right", right.issue_choice_token()) \
			or right.state.dungeonRun != null \
			or int(right.state.resources.spiritStone) - stones_before < 82 \
			or int(right.state.resources.pills.get("golden", 0)) != golden_before + 1 \
			or right.state.dungeonOutcomeReceipts.back().outcome != "success":
		return _fail("foundation dungeon golden pill reward or completion differs")
	var right_cold = _shop_branch(FileAccess.get_file_as_bytes(
		right._store.v2_path), right_path)
	if right_cold == null or not _same(right_cold.state, right.state):
		return _fail("foundation dungeon right reward completion did not strictly restore")
	var treasure = _shop_branch(FileAccess.get_file_as_bytes(
		reward._store.v2_path), path)
	if treasure == null or not _same(treasure.state, reward.state) \
			or not treasure.choose("left", treasure.issue_choice_token()) \
			or treasure.state.dungeonRun != null \
			or treasure.state.dungeonOutcomeReceipts.back().outcome != "success":
		return _fail("foundation dungeon treasure completion did not strictly restore")
	var completed = _shop_branch(FileAccess.get_file_as_bytes(
		treasure._store.v2_path), path)
	if completed == null or not _same(completed.state, treasure.state):
		return _fail("foundation dungeon completed save did not strictly restore")
	for outcome in ["defeat", "flee"]:
		var outcome_path := "user://tests/foundation_dungeon_%s_%d.json" % [
			outcome, Time.get_ticks_usec()]
		var lost = _shop_branch(pending_bytes, outcome_path)
		if lost == null or not _same(lost.state, pending) \
				or not lost.submit_battle_result(_result_for(request, outcome)) \
				or lost.state.dungeonRun != null \
				or lost.state.dungeonOutcomeReceipts.back().outcome != (
					"failure" if outcome == "defeat" else "abandon"):
			return _fail("foundation dungeon %s did not settle source run" % outcome)
		var lost_cold = _shop_branch(FileAccess.get_file_as_bytes(
			lost._store.v2_path), outcome_path)
		if lost_cold == null or not _same(lost_cold.state, lost.state) \
				or not lost_cold.choose("down", lost_cold.issue_choice_token()):
			return _fail("foundation dungeon %s result did not strictly restore" % outcome)
	var desktop_path := "user://tests/foundation_dungeon_desktop_%d.json" % Time.get_ticks_usec()
	var desktop = _shop_branch(pending_bytes, desktop_path)
	if desktop == null or not _same(desktop.state, pending):
		return _fail("foundation dungeon desktop battle save did not restore")
	var story: Control = load("res://scenes/noncombat_opening.tscn").instantiate()
	story.save_path = ""
	root.add_child(story)
	await process_frame
	story.opening = desktop
	story.opening_store = desktop._store
	story.slot_screen.visible = false
	story.name_screen.visible = false
	story.path_screen.visible = false
	story.story_screen.visible = true
	story._set_scene_surface(true)
	story._render()
	var launch: Button = story.find_child("LaunchBattle", true, false)
	if launch == null or launch.disabled:
		return _fail("foundation dungeon desktop battle launch unavailable")
	launch.pressed.emit()
	await process_frame
	var desktop_battle: Control = story.active_battle
	if desktop_battle == null or not desktop_battle.stage_assets_ready:
		return _fail("foundation dungeon desktop guardian stage did not launch")
	var flee: Button = desktop_battle.get_node_or_null("FleeBattle")
	if flee == null or flee.disabled:
		return _fail("foundation dungeon desktop retreat unavailable")
	flee.pressed.emit()
	var desktop_result: Dictionary = desktop_battle.terminal_result()
	var return_button: Button = desktop_battle.get_node_or_null("ReturnToStory")
	if desktop_result.get("outcome") != "flee" or return_button == null \
			or return_button.disabled:
		return _fail("foundation dungeon desktop retreat receipt unavailable")
	return_button.pressed.emit()
	await process_frame
	var desktop_cold = _shop_branch(FileAccess.get_file_as_bytes(
		desktop._store.v2_path), desktop_path)
	if story.active_battle != null or desktop_cold == null \
			or desktop_cold.get_current_card().get("id") != "combat_fled_realm_guardian" \
			or desktop_cold.submit_battle_result(desktop_result):
		return _fail("foundation dungeon desktop retreat did not return once")
	story.queue_free()
	await process_frame
	print("NONCOMBAT_FOUNDATION_DUNGEON_NATURAL_PASS entry=true graph=true battle=true outcomes=3 rewards=2 desktop=true replay=true rollback=true")
	quit(0)
