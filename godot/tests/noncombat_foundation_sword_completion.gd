extends "res://tests/noncombat_foundation_sword_trial_outcomes.gd"

const OpeningScene = preload("res://scenes/noncombat_opening.tscn")
const LegacyFragmentFlow = preload("res://scripts/noncombat_legacy_fragment_flow.gd")

func _run() -> void:
	var path := "user://tests/foundation_sword_completion_%d.json" % Time.get_ticks_usec()
	var store = Session.new(path, "slot_2")
	var file := FileAccess.open(store.v2_path, FileAccess.WRITE)
	file.store_buffer(FileAccess.get_file_as_bytes(FIXTURE))
	file.close()
	var game = Domain.new(Registry.new(), store, "slot_2")
	_quiet(game)
	if not game.restore() or not game.choose("left", game.issue_choice_token()) \
			or not game.choose("left", game.issue_choice_token()) \
			or not game.submit_battle_result(_result(game.battle_request(), "victory")) \
			or not game.choose("down", game.issue_choice_token()):
		return _fail("natural sword trial victory did not reach final quest: " +
			JSON.stringify({"card": game.get_current_card().get("id"),
				"phase": game.state.get("phase"),
				"quest": game.state.get("questState", {}),
				"error": game.flow_failure_reason()}))
	for _step in 12:
		if game.get_current_card().get("id") == "q_sword_4":
			break
		if game.state.phase == "FLOW_PENDING":
			if not game.resume_flow():
				return _fail("sword finale could not resume after trial victory")
		elif game.state.phase == "COMBAT_HANDOFF" and String(
				game.get_current_card().get("id", "")).begins_with("encounter_card_"):
			if not game.choose("right", game.issue_choice_token()):
				return _fail("sword finale cadence encounter could not be avoided")
		elif game.state.phase == "NARRATIVE_RESULT_PENDING":
			if not game.choose("left", game.issue_choice_token()):
				return _fail("sword finale cadence result could not be dismissed")
		elif game.state.phase == "MILESTONE_PENDING":
			if not game.choose("left", game.issue_choice_token()):
				return _fail("sword finale milestone could not be settled")
		elif game.state.phase == "DESTINY_WHEEL_PENDING":
			if not game.choose("left", game.issue_choice_token()):
				return _fail("sword finale wheel interrupt could not return")
		else:
			return _fail("sword finale resumed to unexpected phase " +
					String(game.state.phase))
	if game.get_current_card().get("id") != "q_sword_4":
		return _fail("sword finale was starved after bounded cadence preemption")
	if not game.can_choose_direction("left") or not game.can_choose_direction("right"):
		return _fail("sword finale opportunity choices are unavailable")
	var before: Dictionary = game.state.duplicate(true)
	var story: Control = OpeningScene.instantiate()
	story.save_path = ""
	root.add_child(story)
	await process_frame
	story.opening = game
	story.slot_screen.visible = false
	story.name_screen.visible = false
	story.path_screen.visible = false
	story.story_screen.visible = true
	story._set_scene_surface(true)
	story._render()
	if "--capture-foundation-sword" in OS.get_cmdline_user_args():
		for resolution in [Vector2i(1280, 800), Vector2i(1920, 1080)]:
			if not await _capture_story(story, "choice", resolution):
				return _fail("sword finale choices overflow the desktop screen")
	var left_button: Button = story.find_child("Choice_left", true, false)
	var right_button: Button = story.find_child("Choice_right", true, false)
	if left_button == null or right_button == null \
			or not left_button.text.contains("无剑之境：") \
			or not right_button.text.contains("余锋之境：") \
			or not left_button.text.contains("万剑归宗"):
		return _fail("sword finale desktop choices did not show source pool preview")
	if int(before.knowledge.get("sword", 0)) < 2 \
			or int(before.attributes.daoHeart) < 3:
		return _fail("natural quest did not earn special opportunity conditions")
	var q4_bytes := FileAccess.get_file_as_bytes(store.v2_path)
	var special_state: Dictionary = before.duplicate(true)
	special_state.attributes.karmaBad = 0
	var special: Dictionary = game._quest_flow.opportunity_flow.resolve(special_state,
		"sword_legacy_completion_v1", "empty_hand", "q_sword_4",
		int(before.runClock.decisionIndex) + 1)
	if special.get("opportunityAcquisitions", {}).get(
			"sword_legacy_completion_v1", {}).get("mode") != "special" \
			or not special.get("deck", []).has("legacy_sword_heart_art") \
			or not game._quest_flow.opportunity_flow.format_preview(special_state,
				"sword_legacy_completion_v1", "empty_hand", "q_sword_4").contains(
				"特殊机缘已显：万剑归宗"):
		return _fail("source special conditions did not beat weighted draw")
	game._quest_flow.opportunity_flow.roll_override = 0.0
	game._store.fail_promotion_once = true
	if game.choose("left", game.issue_choice_token()) \
			or not _same(game.state, before) \
			or FileAccess.get_file_as_bytes(store.v2_path) != q4_bytes:
		return _fail("sword finale failed write changed state or bytes")
	story._render()
	game.changed.connect(story._on_opening_changed)
	var commit_button: Button = story.find_child("Choice_left", true, false)
	if commit_button == null or commit_button.disabled:
		return _fail("sword finale desktop choice became unavailable")
	commit_button.pressed.emit()
	await process_frame
	if game.state.get("opportunityAcquisitions", {}).is_empty():
		return _fail("sword finale desktop button did not commit the opportunity")
	var acquisition: Dictionary = game.state.get("opportunityAcquisitions", {}).get(
		"sword_legacy_completion_v1", {})
	if acquisition.get("mode") != "weighted" \
			or acquisition.get("rewardId") != "legacy_sword_heart_art" \
			or not game.state.deck.has("legacy_sword_heart_art") \
			or not _completion_reward_ok(before, game.state, "left") \
			or not game.state.questState.completedQuests.has("sword_legacy") \
			or game.state.flags.get("swordLegacyCompleted") != true:
		return _fail("sword finale did not atomically award and complete the source quest: "
			+ JSON.stringify({"acquisition": acquisition, "deck": game.state.deck,
				"completed": game.state.questState.completedQuests,
				"flag": game.state.flags.get("swordLegacyCompleted"),
				"phase": game.state.get("phase")}))
	if not story.reward_settlement_label.visible \
			or not story.reward_settlement_label.text.contains(
				"技能入组【%s】" % acquisition.get("rewardName", "")):
		return _fail("sword finale desktop receipt omitted committed card reward")
	if "--capture-foundation-sword" in OS.get_cmdline_user_args() \
			and not await _capture_story(story, "receipt", Vector2i(1280, 800)):
		return _fail("sword finale receipt overflowed the desktop screen")
	story.queue_free()
	var reopened = Domain.new(Registry.new(), Session.new(path, "slot_2"), "slot_2")
	_quiet(reopened)
	reopened._quest_flow.opportunity_flow.roll_override = 0.0
	if not reopened.restore() or not _same(reopened.state, game.state):
		return _fail("sword finale failed strict cold restore")
	var cold_story: Control = OpeningScene.instantiate()
	cold_story.save_path = ""
	root.add_child(cold_story)
	await process_frame
	cold_story.opening = reopened
	cold_story.slot_screen.visible = false
	cold_story.name_screen.visible = false
	cold_story.path_screen.visible = false
	cold_story.story_screen.visible = true
	cold_story._set_scene_surface(true)
	cold_story._render()
	if not cold_story.reward_settlement_label.visible \
			or not cold_story.reward_settlement_label.text.contains(
				String(acquisition.get("rewardName", ""))):
		return _fail("cold sword finale desktop receipt lost the committed reward")
	cold_story.queue_free()
	if game._quest_flow.opportunity_flow.preview(game.state,
			"sword_legacy_completion_v1", "empty_hand", "q_sword_4").get(
			"reason") != "already_resolved" \
			or game._quest_flow.opportunity_flow.preview(before,
				"sword_legacy_completion_v1", "empty_hand", "not_q_sword_4").get(
				"reason") != "source_mismatch":
		return _fail("sword finale opportunity source or once-per-life guard failed")
	var right_path := "user://tests/foundation_sword_completion_right_%d.json" % Time.get_ticks_usec()
	var right_store = Session.new(right_path, "slot_2")
	var right_file := FileAccess.open(right_store.v2_path, FileAccess.WRITE)
	right_file.store_buffer(q4_bytes)
	right_file.close()
	var right = Domain.new(Registry.new(), right_store, "slot_2")
	_quiet(right)
	right._quest_flow.opportunity_flow.roll_override = 0.999
	if not right.restore() or not right.choose("right", right.issue_choice_token()):
		return _fail("sword finale kept-intent reward failed to settle")
	var right_reward: Dictionary = right.state.get("opportunityAcquisitions", {}).get(
		"sword_legacy_completion_v1", {})
	if right_reward.get("rewardType") != "treasure" \
			or not right.state.resources.treasures.has(right_reward.get("rewardId")) \
			or not _completion_reward_ok(before, right.state, "right") \
			or right.state.flags.get("sword_legacy_stolen") != true \
			or not right.state.questState.completedQuests.has("sword_legacy"):
		return _fail("sword finale kept-intent did not award a source treasure")
	var right_reopen = Domain.new(Registry.new(), Session.new(right_path, "slot_2"), "slot_2")
	_quiet(right_reopen)
	right_reopen._quest_flow.opportunity_flow.roll_override = 0.999
	if not right_reopen.restore() or not _same(right_reopen.state, right.state):
		return _fail("kept-intent treasure failed strict cold restore")
	var native_path := "user://tests/foundation_sword_completion_native_%d.json" % Time.get_ticks_usec()
	var native_store = Session.new(native_path, "slot_2")
	var native_file := FileAccess.open(native_store.v2_path, FileAccess.WRITE)
	native_file.store_buffer(q4_bytes)
	native_file.close()
	var native = Domain.new(Registry.new(), native_store, "slot_2")
	_quiet(native)
	if not native.restore() or not native.choose("right", native.issue_choice_token()) \
			or int(native.state.get("opportunityRngState", {}).get("initialSeed", 0)) <= 0:
		return _fail("native opportunity roll did not settle and persist its seed")
	var native_reopen = Domain.new(Registry.new(), Session.new(native_path, "slot_2"), "slot_2")
	_quiet(native_reopen)
	if not native_reopen.restore() or not _same(native_reopen.state, native.state):
		return _fail("native opportunity roll did not strictly replay")
	print("NONCOMBAT_FOUNDATION_SWORD_COMPLETION_PASS special=true weighted=true treasure=true rollback=true replay=true rng=true")
	quit(0)


func _capture_story(story: Control, label: String,
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
		"res://output/captures/godot-migration/foundation-sword-completion")
	if DirAccess.make_dir_recursive_absolute(directory) != OK:
		return false
	var output := directory.path_join("%s_%sx%s.png" % [
		label, resolution.x, resolution.y])
	if root.get_texture().get_image().save_png(output) != OK:
		return false
	print("FOUNDATION_SWORD_CAPTURE " + output)
	return true


func _completion_reward_ok(prior: Dictionary, after: Dictionary,
		direction: String) -> bool:
	var echo: Dictionary = {}
	var choice_seed: Dictionary = {}
	for seed in after.get("karmaSeeds", []):
		if seed is Dictionary and seed.get("id") == "swordLegacyEcho":
			echo = seed
		if seed is Dictionary and seed.get("id") == (
			"swordLegacyTrial" if direction == "left" else "swordLegacyTheft"):
			choice_seed = seed
	var factions: Dictionary = after.get("factionProgress", {}).get("reputations", {})
	var old_factions: Dictionary = prior.get("factionProgress", {}).get("reputations", {})
	return int(after.attributes.cultivation) == mini(100,
		int(prior.attributes.cultivation) + (35 if direction == "left" else 38)) \
		and int(after.attributes.fortune) == mini(100,
		int(prior.attributes.fortune) + (13 if direction == "left" else 5)) \
		and int(after.attributes.daoHeart) == mini(
			LegacyFragmentFlow.actual_max_dao_heart(after),
			int(prior.attributes.daoHeart) + 2) \
		and int(echo.get("delay", -1)) == 13 \
		and echo.get("originQuest") == "sword_legacy" \
		and echo.get("originOutcome") == "completed" \
		and int(choice_seed.get("delay", -1)) == (11 if direction == "left" else 9) \
		and choice_seed.get("originCard") == "q_sword_4" \
		and choice_seed.get("originChoice") == direction \
		and factions.has("qingyun_sword") and factions.has("wumeng_alliance") \
		and int(factions.qingyun_sword) == clampi(int(old_factions.get(
			"qingyun_sword", 0)) + 20, -100, 100) \
		and int(factions.wumeng_alliance) == clampi(int(old_factions.get(
			"wumeng_alliance", 0)) - 5, -100, 100)
