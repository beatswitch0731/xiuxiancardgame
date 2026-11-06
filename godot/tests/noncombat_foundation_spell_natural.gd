extends "res://tests/noncombat_foundation_body_natural.gd"


func _run() -> void:
	var path := "user://tests/foundation_spell_natural_%d.json" % Time.get_ticks_usec()
	var game = Domain.new(Registry.new(), RunSession.new(path, "slot_3"), "slot_3")
	_stabilize_ambient(game)
	game._normal_roll_override = 0.55
	if not game.start("spell"):
		return _fail("spell foundation natural opening failed")
	for direction in ["left", "left", "left", "left", "left", "left", "left"]:
		if not game.choose(direction, game.issue_choice_token()):
			return _fail("spell foundation first battle prefix failed")
	var first_request: Dictionary = game.battle_request()
	if first_request.get("encounterId") != "enc_trial_spell_seal" \
			or not game.submit_battle_result(_result_for(first_request, "victory")) \
			or not game.choose("left", game.issue_choice_token()):
		return _fail("spell foundation first teaching victory did not return to story")
	for index in 100:
		if game.state.phase == "FLOW_PENDING" and not game.resume_flow():
			return _fail("spell foundation flow stopped at %d: %s" % [index,
				JSON.stringify({"normal": game._normal_flow_error,
					"phase": game.state.phase, "realm": game.state.realm,
					"card": game.get_current_card().get("id"),
					"cultivation": game.state.attributes.cultivation,
					"daoHeart": game.state.attributes.daoHeart,
					"spiritStone": game.state.resources.spiritStone,
					"failure": game.flow_failure_reason()})])
		var card: Dictionary = game.get_current_card()
		if card.get("id") == "q_spell_1":
			await _finish_spell_quest(game, path)
			return
		if card.get("id") == "_warning_ch_qi_100":
			if not game.choose("left", game.issue_choice_token()):
				return _fail("spell foundation gate preparation failed")
			var gate_request: Dictionary = game.battle_request()
			if gate_request.get("sourceCardId") != "ch_qi_100" \
					or not game.submit_battle_result(_result_for(gate_request, "victory")) \
					or not game.choose("left", game.issue_choice_token()) \
					or game.get_current_card().get("id") != "epiphany_foundation" \
					or not game.choose("left", game.issue_choice_token()):
				return _fail("spell foundation gate did not enter foundation: "
					+ JSON.stringify({"phase": game.state.get("phase"),
						"card": game.get_current_card().get("id"),
						"cultivation": game.state.attributes.cultivation}))
			continue
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
			return _fail("spell foundation could not choose %s on %s/%s %s" % [
				direction, game.state.phase, card.get("id"), JSON.stringify({
					"attributes": game.state.attributes,
					"error": game.flow_failure_reason()})])
	return _fail("spell foundation did not surface within 100 decisions")


func _finish_spell_quest(game: RefCounted, path: String) -> void:
	if game.get_current_card().get("id") != "q_spell_1" \
			or game.state.get("realm") != "foundation" \
			or int(game.state.attributes.cultivation) < 25:
		return _fail("natural spell quest entry lost source eligibility")
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(
		"res://content/data/quests/spell_codex.json"))
	var entry_bytes := FileAccess.get_file_as_bytes(game._store.v2_path)
	var refused = _branch_body(entry_bytes,
		"user://tests/foundation_spell_refused_%d.json" % Time.get_ticks_usec())
	if refused == null or not refused.choose("right", refused.issue_choice_token()) \
			or refused.state.questState.questOutcomes.get("spell_codex") != "abandoned" \
			or refused.state.flags.get("spellCodexCompleted") == true:
		return _fail("natural spell refusal did not close without completion reward")
	if not game.choose("left", game.issue_choice_token()) \
			or game.get_current_card().get("id") != "q_spell_2":
		return _fail("natural spell task did not reach sealed voice")
	var study = _branch_body(FileAccess.get_file_as_bytes(game._store.v2_path),
		"user://tests/foundation_spell_study_%d.json" % Time.get_ticks_usec())
	if study == null or not study.choose("left", study.issue_choice_token()) \
			or study.get_current_card().get("id") != "q_spell_3" \
			or not study.choose("right", study.issue_choice_token()) \
			or study.get_current_card().get("id") != "q_spell_4" \
			or study.get_current_card().get("description") != \
				source.cards[3].stateVariants[0].description \
			or not study.choose("right", study.issue_choice_token()) \
			or study.state.questState.questOutcomes.get("spell_codex") != "failed" \
			or study.state.flags.get("spellCodexCompleted") == true \
			or study.state.get("opportunityAcquisitions", {}).has(
				"spell_codex_completion_v1"):
		return _fail("natural spell contract failure gave completion reward or lost variant")
	var failed_cold = _branch_body(FileAccess.get_file_as_bytes(study._store.v2_path),
		"user://tests/foundation_spell_failed_cold_%d.json" % Time.get_ticks_usec())
	if failed_cold == null or not _same(failed_cold.state, study.state):
		return _fail("natural spell failed ending did not strictly restore")
	if not game.choose("right", game.issue_choice_token()) \
			or game.get_current_card().get("id") != "q_spell_3" \
			or game.get_current_card().get("description") != \
				source.cards[2].stateVariants[0].description \
			or not game.choose("left", game.issue_choice_token()) \
			or game.get_current_card().get("id") != "q_spell_4":
		return _fail("natural spell history/refusal route did not reach fourth card")
	var before: Dictionary = game.state.duplicate(true)
	var cold = Domain.new(Registry.new(), RunSession.new(path, "slot_3"), "slot_3")
	_stabilize_ambient(cold)
	cold._normal_roll_override = 0.55
	if not cold.restore() or not _same(cold.state, before):
		return _fail("natural spell fourth-card checkpoint failed strict restore: "
			+ cold._store.last_error)
	var story: Control = OpeningScene.instantiate()
	story.save_path = ""
	root.add_child(story)
	await process_frame
	story.opening = cold
	story.slot_screen.visible = false
	story.name_screen.visible = false
	story.path_screen.visible = false
	story.story_screen.visible = true
	story._set_scene_surface(true)
	story._render()
	if "--capture-foundation-spell" in OS.get_cmdline_user_args():
		for resolution in [Vector2i(1280, 800), Vector2i(1920, 1080)]:
			if not await _capture_spell_story(story, "choice", resolution):
				return _fail("natural spell finale choices overflow desktop screen")
	var left_button: Button = story.find_child("Choice_left", true, false)
	if left_button == null or left_button.disabled \
			or not left_button.text.contains("守封之誓"):
		return _fail("natural spell finale desktop choice omitted source preview")
	cold.changed.connect(story._on_opening_changed)
	left_button.pressed.emit()
	await process_frame
	var reward: Dictionary = cold.state.get("opportunityAcquisitions", {}).get(
		"spell_codex_completion_v1", {})
	var reward_id := String(reward.get("rewardId", ""))
	var owned: bool = cold.state.deck.has(reward_id) if reward.get(
		"rewardType") == "card" else cold.state.resources.treasures.has(reward_id)
	if cold.state.questState.questOutcomes.get("spell_codex") != "completed" \
			or cold.state.flags.get("spellCodexCompleted") != true \
			or reward.get("profile") != "seal_keeper" or not owned \
			or not _body_seed_delay(cold.state, "spellCodexEcho", 11) \
			or not _body_seed_delay(cold.state, "spellCodexDisclosure", 11) \
			or not story.reward_settlement_label.visible \
			or not story.reward_settlement_label.text.contains(
				String(reward.get("rewardName", ""))):
		return _fail("natural spell finale desktop button lost completion reward: "
			+ JSON.stringify({"reward": reward, "phase": cold.state.phase,
				"flags": cold.state.flags, "error": cold.flow_failure_reason()}))
	if "--capture-foundation-spell" in OS.get_cmdline_user_args() \
			and not await _capture_spell_story(story, "receipt", Vector2i(1280, 800)):
		return _fail("natural spell finale receipt overflowed desktop screen")
	story.queue_free()
	var final_state: Dictionary = cold.state.duplicate(true)
	var final_cold = Domain.new(Registry.new(), RunSession.new(path, "slot_3"), "slot_3")
	_stabilize_ambient(final_cold)
	final_cold._normal_roll_override = 0.55
	if not final_cold.restore() or not _same(final_cold.state, final_state):
		return _fail("natural spell completion failed strict restore: "
			+ final_cold._store.last_error)
	print("NONCOMBAT_FOUNDATION_SPELL_NATURAL_PASS entry=true variant=true failed=true reward=true ui=true replay=true")
	quit(0)


func _capture_spell_story(story: Control, label: String,
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
		"res://output/captures/godot-migration/foundation-spell-completion")
	if DirAccess.make_dir_recursive_absolute(directory) != OK:
		return false
	var output := directory.path_join("%s_%sx%s.png" % [
		label, resolution.x, resolution.y])
	if root.get_texture().get_image().save_png(output) != OK:
		return false
	print("FOUNDATION_SPELL_CAPTURE " + output)
	return true
