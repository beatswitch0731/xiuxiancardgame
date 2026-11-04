extends "res://tests/noncombat_body_karma_due.gd"

const OpeningScene = preload("res://scenes/noncombat_opening.tscn")


func _run() -> void:
	var path := "user://tests/foundation_body_natural_%d.json" % Time.get_ticks_usec()
	var game = Domain.new(Registry.new(), RunSession.new(path, "slot_3"), "slot_3")
	_stabilize_ambient(game)
	game._normal_roll_override = 0.55
	if not game.start("body"):
		return _fail("body foundation natural opening failed")
	for direction in ["left", "left", "left", "left", "left", "left", "left"]:
		if not game.choose(direction, game.issue_choice_token()):
			return _fail("body foundation first battle prefix failed at " + direction)
	var first_request: Dictionary = game.battle_request()
	if first_request.get("encounterId") != "enc_trial_body_iron" \
			or not game.submit_battle_result(_result_for(first_request, "victory")) \
			or not game.choose("left", game.issue_choice_token()):
		return _fail("body foundation first teaching victory did not return to story")
	for index in 60:
		if game.state.phase == "FLOW_PENDING" and not game.resume_flow():
			return _fail("body foundation flow stopped at " + str(index))
		var card: Dictionary = game.get_current_card()
		if card.get("id") == "kx_ch_sword_sect_path" \
				and (game.can_choose_direction("left") \
					or not game.can_choose_direction("right")):
			return _fail("cross-path sword reward was presented as an executable body choice")
		if card.get("id") == "q_body_1":
			await _finish_body_quest(game, path)
			return
		if card.get("id") == "_warning_ch_qi_100":
			if not game.choose("left", game.issue_choice_token()):
				return _fail("body foundation gate preparation failed")
			var gate_request: Dictionary = game.battle_request()
			if gate_request.get("sourceCardId") != "ch_qi_100" \
					or not game.submit_battle_result(_result_for(gate_request, "victory")) \
					or not game.choose("left", game.issue_choice_token()) \
					or game.get_current_card().get("id") != "epiphany_foundation" \
					or not game.choose("left", game.issue_choice_token()) \
					or not game.resume_flow() \
					or game.get_current_card().get("id") != "q_body_1":
				return _fail("body foundation gate did not continue into body quest: "
					+ JSON.stringify({"phase": game.state.get("phase"),
						"card": game.get_current_card().get("id"),
						"realm": game.state.get("realm")}))
			await _finish_body_quest(game, path)
			return
		var direction := "right" if game.state.phase in [
			"COMBAT_HANDOFF", "MARKET_PENDING", "FIRST_SESSION_ROUTE_PENDING"] \
			or card.get("id") == "kx_ch_sword_sect_path" else "left"
		if not game.can_choose_direction(direction):
			for fallback in ["right", "down", "up"]:
				if game.can_choose_direction(fallback):
					direction = fallback
					break
		if not game.can_choose_direction(direction) or not game.choose(
				direction, game.issue_choice_token()):
			return _fail("body foundation could not choose %s on %s/%s %s" % [
				direction, game.state.phase, card.get("id"), JSON.stringify({
					"choices": card.get("choices"), "attributes": game.state.attributes,
					"resources": game.state.resources,
					"error": game.flow_failure_reason()})])
	return _fail("body foundation did not surface within 60 decisions")


func _finish_body_quest(game: RefCounted, path: String) -> void:
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(
		"res://content/data/quests/body_tribulation.json"))
	var entry_before: Dictionary = game.state.duplicate(true)
	var entry_bytes := FileAccess.get_file_as_bytes(game._store.v2_path)
	var refused_path := "user://tests/foundation_body_refused_%d.json" % Time.get_ticks_usec()
	var refused = _branch_body(entry_bytes, refused_path)
	if refused == null or not refused.choose("right", refused.issue_choice_token()) \
			or refused.state.questState.questOutcomes.get("body_tribulation") != "abandoned" \
			or refused.state.questState.completedQuests.has("body_tribulation") \
			or refused.state.flags.get("bodyTribulationCompleted") == true:
		return _fail("natural body refusal did not close without completion reward")
	var refused_cold = _branch_body(FileAccess.get_file_as_bytes(
		refused._store.v2_path), "user://tests/foundation_body_refused_cold_%d.json" % Time.get_ticks_usec())
	if refused_cold == null or not _same(refused_cold.state, refused.state):
		return _fail("natural body refusal failed strict restore")
	var burn = _branch_body(entry_bytes,
		"user://tests/foundation_body_burn_%d.json" % Time.get_ticks_usec())
	if burn == null:
		return _fail("natural body low-health choice could not branch")
	burn.state.attributes.health = 1
	var max_health := int(burn.state.maxHealth)
	var max_heart := int(burn.state.maxDaoHeart)
	if not burn.choose("left", burn.issue_choice_token()) \
			or int(burn.state.attributes.health) != 1 \
			or int(burn.state.maxHealth) != max_health - 1 \
			or int(burn.state.maxDaoHeart) != max_heart - 1 \
			or burn.state.get("phase") == "DEATH_PENDING":
		return _fail("natural body low-health choice missed source burn-blood survival")
	var exhausted = _branch_body(entry_bytes,
		"user://tests/foundation_body_exhausted_%d.json" % Time.get_ticks_usec())
	if exhausted == null:
		return _fail("natural body exhausted-cap choice could not branch")
	exhausted.state.maxHealth = 1
	exhausted.state.maxDaoHeart = 1
	exhausted.state.attributes.health = 1
	if not exhausted.choose("left", exhausted.issue_choice_token()) \
			or exhausted.state.get("phase") != "DEATH_PENDING" \
			or exhausted.get_current_card().get("id") != "death_blood_loss":
		return _fail("natural body exhausted-cap choice missed blood-loss death")
	var fatal = _branch_body(entry_bytes,
		"user://tests/foundation_body_fatal_%d.json" % Time.get_ticks_usec())
	if fatal == null:
		return _fail("natural body low-heart choice could not branch")
	fatal.state.attributes.daoHeart = 1
	if not fatal.choose("right", fatal.issue_choice_token()) \
			or fatal.state.get("phase") != "DEATH_PENDING" \
			or fatal.get_current_card().get("id") != "death_dao_collapse":
		return _fail("natural body low-heart refusal missed source death narrative")
	game._store.fail_promotion_once = true
	if game.choose("left", game.issue_choice_token()) \
			or not _same(game.state, entry_before) \
			or FileAccess.get_file_as_bytes(game._store.v2_path) != entry_bytes:
		return _fail("natural body quest failed write changed the entry checkpoint")
	if not game.choose("left", game.issue_choice_token()) \
			or game.get_current_card().get("id") != "q_body_2" \
			or not game.choose("right", game.issue_choice_token()) \
			or game.get_current_card().get("id") != "q_body_3":
		return _fail("natural body task first two choices did not reach waterfall")
	var deep_path := "user://tests/foundation_body_deep_%d.json" % Time.get_ticks_usec()
	var deep = _branch_body(FileAccess.get_file_as_bytes(game._store.v2_path), deep_path)
	if deep == null or not deep.choose("left", deep.issue_choice_token()) \
			or deep.get_current_card().get("id") != "q_body_4" \
			or deep.state.flags.get("bodyWaterfallPersevered") != true:
		return _fail("natural body perseverance did not reach the fourth card")
	var deep_before: Dictionary = deep.state.duplicate(true)
	var low_finale = _branch_body(FileAccess.get_file_as_bytes(deep._store.v2_path),
		"user://tests/foundation_body_low_finale_%d.json" % Time.get_ticks_usec())
	if low_finale == null:
		return _fail("natural body low-health finale could not branch")
	low_finale.state.attributes.health = 1
	var finale_cap := int(low_finale.state.maxHealth)
	if not low_finale.choose("left", low_finale.issue_choice_token()) \
			or int(low_finale.state.attributes.health) != 2 \
			or int(low_finale.state.maxHealth) != finale_cap \
			or low_finale.state.get("phase") == "DEATH_PENDING":
		return _fail("body finale survival was checked before completion reward")
	var story: Control = OpeningScene.instantiate()
	story.save_path = ""
	root.add_child(story)
	await process_frame
	story.opening = deep
	story.slot_screen.visible = false
	story.name_screen.visible = false
	story.path_screen.visible = false
	story.story_screen.visible = true
	story._set_scene_surface(true)
	story._render()
	if "--capture-foundation-body" in OS.get_cmdline_user_args():
		for resolution in [Vector2i(1280, 800), Vector2i(1920, 1080)]:
			if not await _capture_body_story(story, "choice", resolution):
				return _fail("natural body finale choices overflow the desktop screen")
	var left_button: Button = story.find_child("Choice_left", true, false)
	if left_button == null or left_button.disabled \
			or not left_button.text.contains("赤身承劫：") \
			or not left_button.text.contains("天劫锻骨"):
		return _fail("natural body finale desktop button omitted source weighted preview")
	var has_deep_seed := false
	for seed in deep_before.get("karmaSeeds", []):
		if seed is Dictionary and seed.get("id") == "bodyTrialStarted":
			has_deep_seed = seed.get("delay") == 6
	if int(deep_before.attributes.karmaBad) <= 5 \
			or int(deep_before.knowledge.get("body", 0)) < 2 \
			or not has_deep_seed:
		return _fail("natural body finale did not meet the weighted source conditions")
	deep.changed.connect(story._on_opening_changed)
	left_button.pressed.emit()
	await process_frame
	var deep_reward: Dictionary = deep.state.get("opportunityAcquisitions", {}).get(
		"body_tribulation_completion_v1", {})
	var reward_id := String(deep_reward.get("rewardId", ""))
	var reward_owned: bool = deep.state.deck.has(reward_id) if deep_reward.get(
		"rewardType") == "card" else deep.state.resources.treasures.has(reward_id)
	if deep.state.questState.questOutcomes.get("body_tribulation") != "completed" \
			or deep_reward.get("mode") != "weighted" \
			or reward_id.is_empty() or not reward_owned \
			or not deep_reward.get("candidates", []).any(func(row: Variant) -> bool:
				return row is Dictionary and row.get("rewardId") == reward_id) \
			or not _body_seed_delay(deep.state, "bodyTrialDeep", 9):
		return _fail("natural body perseverance did not settle source weighted outcome: "
			+ JSON.stringify({"phase": deep.state.get("phase"),
				"card": deep.get_current_card().get("id"),
				"attributes": deep.state.get("attributes"),
				"knowledge": deep.state.get("knowledge"),
				"flags": deep.state.get("flags"),
				"opportunity": deep.state.get("opportunityAcquisitions"),
				"deck": deep.state.get("deck"),
				"error": deep.flow_failure_reason()}))
	if not story.reward_settlement_label.visible \
			or not story.reward_settlement_label.text.contains(
				String(deep_reward.get("rewardName", ""))):
		return _fail("natural body finale desktop receipt omitted earned reward")
	if "--capture-foundation-body" in OS.get_cmdline_user_args() \
			and not await _capture_body_story(story, "receipt", Vector2i(1280, 800)):
		return _fail("natural body finale receipt overflowed the desktop screen")
	story.queue_free()
	var deep_cold = _branch_body(FileAccess.get_file_as_bytes(
		deep._store.v2_path), "user://tests/foundation_body_deep_cold_%d.json" % Time.get_ticks_usec())
	if deep_cold == null or not _same(deep_cold.state, deep.state):
		return _fail("natural body weighted legacy failed strict restore")
	if not game.choose("right", game.issue_choice_token()) \
			or game.get_current_card().get("id") != "q_body_4" \
			or game.get_current_card().get("description") != \
				source.cards[3].stateVariants[0].description:
		return _fail("natural body quest did not reach the withdrawal variant")
	var fourth: Dictionary = game.state.duplicate(true)
	var cold = Domain.new(Registry.new(), RunSession.new(path, "slot_3"), "slot_3")
	_stabilize_ambient(cold)
	cold._normal_roll_override = 0.55
	if not cold.restore() or not _same(cold.state, fourth):
		return _fail("natural body fourth-card checkpoint failed strict restore: "
			+ cold._store.last_error)
	if not cold.choose("right", cold.issue_choice_token()):
		return _fail("natural body quest guarded ending failed: "
			+ cold.flow_failure_reason())
	var final_state: Dictionary = cold.state.duplicate(true)
	var reward: Dictionary = final_state.get("opportunityAcquisitions", {}).get(
		"body_tribulation_completion_v1", {})
	if final_state.get("questState", {}).get("questOutcomes", {}).get(
			"body_tribulation") != "completed" \
			or reward.get("profile") != "qi_guarded" \
			or not final_state.get("questState", {}).get(
				"completedQuests", []).has("body_tribulation") \
			or final_state.get("flags", {}).get("bodyTribulationCompleted") != true \
			or final_state.get("karmaSeeds", []).any(func(seed: Variant) -> bool:
				return seed is Dictionary and seed.get("id") == "bodyTrialDeep"):
		return _fail("natural body quest completion lost source reward or variant")
	var final_cold = Domain.new(Registry.new(), RunSession.new(path, "slot_3"), "slot_3")
	_stabilize_ambient(final_cold)
	final_cold._normal_roll_override = 0.55
	if not final_cold.restore() or not _same(final_cold.state, final_state):
		return _fail("natural body quest completion failed strict restore: "
			+ final_cold._store.last_error)
	print("NONCOMBAT_FOUNDATION_BODY_NATURAL_PASS entry=true refusal=true weighted=true variant=true reward=true rollback=true replay=true")
	quit(0)


func _branch_body(bytes: PackedByteArray, path: String) -> RefCounted:
	var store = RunSession.new(path, "slot_3")
	var file := FileAccess.open(store.v2_path, FileAccess.WRITE)
	if file == null:
		return null
	file.store_buffer(bytes)
	file.close()
	var branch = Domain.new(Registry.new(), store, "slot_3")
	_stabilize_ambient(branch)
	branch._normal_roll_override = 0.55
	return branch if branch.restore() else null


func _body_seed_delay(state: Dictionary, seed_id: String, delay: int) -> bool:
	for seed in state.get("karmaSeeds", []):
		if seed is Dictionary and seed.get("id") == seed_id \
				and seed.get("delay") == delay:
			return true
	return false


func _capture_body_story(story: Control, label: String,
		resolution: Vector2i) -> bool:
	DisplayServer.window_set_size(resolution)
	root.size = resolution
	story._render()
	for _frame in range(3):
		await process_frame
	var choices: Rect2 = story.choice_row.get_global_rect()
	if label == "choice" and (choices.position.x < 12.0 \
			or choices.end.x > float(resolution.x) - 12.0 \
			or choices.end.y > float(resolution.y) - 12.0):
		return false
	await RenderingServer.frame_post_draw
	var directory := ProjectSettings.globalize_path(
		"res://../artifacts/godot-migration/foundation-body-completion")
	if DirAccess.make_dir_recursive_absolute(directory) != OK:
		return false
	var output := directory.path_join("%s_%sx%s.png" % [
		label, resolution.x, resolution.y])
	if root.get_texture().get_image().save_png(output) != OK:
		return false
	print("FOUNDATION_BODY_CAPTURE " + output)
	return true


func _result_for(request: Dictionary, outcome: String) -> Dictionary:
	return {"contractVersion": 2, "encounterInstanceId": request.encounterInstanceId,
		"sourceCardId": request.sourceCardId, "encounterId": request.encounterId,
		"sourceContentHash": request.sourceContentHash, "outcome": outcome,
		"combatReceipt": "combat:" + String(request.encounterInstanceId),
		"postBattleState": {"encounterInstanceId": request.encounterInstanceId,
			"terminal": true, "combatPhase": outcome.to_upper()}}
