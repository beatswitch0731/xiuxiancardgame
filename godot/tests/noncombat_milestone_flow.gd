extends SceneTree

const Registry = preload("res://scripts/runtime_data_registry.gd")
const Domain = preload("res://scripts/noncombat_domain.gd")
const RunSession = preload("res://scripts/noncombat_run_session.gd")
const ContentRepository = preload("res://scripts/noncombat_content_repository.gd")
const MilestoneFlow = preload("res://scripts/noncombat_milestone_flow.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var cases := [
		["sword", "assets/cards/events/scene_qi_q_start_sword.png", 5, "daoHeart", 1],
		["spell", "assets/cards/events/scene_qi_q_spellTome.png", 5, "fortune", 2],
		["body", "assets/cards/events/scene_qi_q_bodyTrial.png", 4, "health", 2],
		["pill", "assets/cards/events/scene_qi_q_pillRecipe.png", 4, "spiritStone", 5],
	]
	for case in cases:
		var path_id: String = case[0]
		var save_path := "user://tests/milestone_%s_%d_v1.json" % [path_id, Time.get_ticks_usec()]
		var game = Domain.new(Registry.new(), RunSession.new(save_path, "slot_3"), "slot_3")
		if not game.start(path_id):
			_fail("opening failed: " + path_id)
			return
		for step in 5:
			if not game.choose("left", game.issue_choice_token()):
				_fail("source offer unreachable: " + path_id + " step=" + str(step))
				return
		if not game.choose("right", game.issue_choice_token()) \
					or not game.choose("left", game.issue_choice_token()) \
					or game.state.get("phase") != "FLOW_PENDING":
			_fail("response acknowledgement did not reach scheduler boundary: " + path_id)
			return
		if not game.has_method("resume_flow") or not game.resume_flow():
			_fail("source chapter milestone was not scheduled: " + path_id)
			return
		var first: Dictionary = game.get_current_card()
		if game.state.get("phase") != "MILESTONE_PENDING" \
				or first.get("id") != "ch_qi_20" or first.get("threshold") != 15 \
				or first.get("sceneImage") != case[1] \
				or Registry.new().texture_for(String(first.get("sceneImage", ""))) == null \
				or first.get("_pathVariant", {}).get("path") != path_id \
				or game.state.get("chapterProgress", {}).get("triggeredMilestones", {}).get("qi") != [15] \
				or int(game.state["runClock"]["decisionIndex"]) != 7:
			_fail("first source milestone projection/clock differs: " + path_id)
			return
		var before: Dictionary = game.state.duplicate(true)
		var committed_bytes := FileAccess.get_file_as_string(game._store.v2_path)
		var reloaded = Domain.new(Registry.new(), RunSession.new(save_path, "slot_3"), "slot_3")
		if not reloaded.restore() or not _same(reloaded.state, before) \
				or reloaded.get_current_card().get("id") != first["id"]:
			_fail("milestone did not reload from the true source: " + path_id)
			return
		var token := reloaded.issue_choice_token()
		if path_id == "sword":
			reloaded._store.fail_promotion_once = true
			if reloaded.choose("left", token) or not _same(reloaded.state, before) \
					or FileAccess.get_file_as_string(reloaded._store.v2_path) != committed_bytes:
				_fail("failed milestone write changed state")
				return
		if not reloaded.choose("left", token):
			_fail("source milestone left choice failed: " + path_id)
			return
		var after: Dictionary = reloaded.state
		var attr_key: String = case[3]
		var source_before := int(before["resources"].get(attr_key, 0)) if attr_key == "spiritStone" \
			else int(before["attributes"].get(attr_key, 0))
		var source_after := int(after["resources"].get(attr_key, 0)) if attr_key == "spiritStone" \
			else int(after["attributes"].get(attr_key, 0))
		var expected := mini(int(after.get("maxHealth", 100)), source_before + int(case[4])) \
			if attr_key == "health" else mini(int(after.get("maxDaoHeart", 100)),
				source_before + int(case[4])) if attr_key == "daoHeart" \
				else source_before + int(case[4])
		if int(after["attributes"]["cultivation"]) != int(before["attributes"]["cultivation"]) + int(case[2]) \
				or source_after != expected or after.get("phase") != "MILESTONE_PENDING" \
				or reloaded.get_current_card().get("id") != "ch_qi_40" \
				or Registry.new().texture_for(String(reloaded.get_current_card().get("sceneImage", ""))) == null \
				or after.get("chapterProgress", {}).get("triggeredMilestones", {}).get("qi") != [15, 30] \
				or after["choiceHistory"].back().get("cardId") != "ch_qi_20" \
				or int(after["runClock"]["decisionIndex"]) != 8:
			_fail("milestone choice or chained chapter beat differs: %s %s" % [path_id,
				str({"phase": after.get("phase"), "card": reloaded.get_current_card().get("id"),
					"cultivation": after["attributes"]["cultivation"],
					"expectedCultivation": int(before["attributes"]["cultivation"]) + int(case[2]),
					"sourceAfter": source_after, "sourceExpected": expected,
					"triggered": after.get("chapterProgress", {}).get("triggeredMilestones", {}).get("qi"),
					"decision": after["runClock"]["decisionIndex"]})])
			return
		var seeds: Array = after.get("karmaSeeds", [])
		if seeds.size() != 2 or int(seeds[0].get("delay", -1)) != 4 \
				or int(seeds[1].get("delay", -1)) != 7 \
				or seeds[1].get("id") != first["choices"]["left"]["karmaSeed"]["id"]:
			_fail("chapter seed/decision clock differs: " + path_id)
			return
		var facts: Dictionary = after.get("noncombatFlow", {}).get("spineFacts", {})
		if facts.get("fact:0:qi_main_call", {}).get("status") != "active":
			_fail("first authored chapter fact was not saved: " + path_id)
			return
		var second_before: Dictionary = after.duplicate(true)
		var second_token := reloaded.issue_choice_token()
		if path_id == "sword":
			var bad_manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(
				"res://content/source_manifest.json"))
			for row in bad_manifest.get("data", []):
				if row is Dictionary and row.get("path") == "data/cards/chapter_milestones.json":
					row["sha256"] = "0".repeat(64)
					break
			var bad_path := "user://tests/milestone_bad_source_%d.json" % Time.get_ticks_usec()
			var bad_file := FileAccess.open(bad_path, FileAccess.WRITE)
			bad_file.store_string(JSON.stringify(bad_manifest))
			bad_file.close()
			var original_flow: RefCounted = reloaded._milestone_flow
			reloaded._milestone_flow = MilestoneFlow.new(ContentRepository.new(bad_path))
			var before_bad_bytes := FileAccess.get_file_as_string(reloaded._store.v2_path)
			if reloaded.choose("right", second_token) \
					or not _same(reloaded.state, second_before) \
					or FileAccess.get_file_as_string(reloaded._store.v2_path) != before_bad_bytes:
				_fail("changed chapter source allowed a milestone decision")
				return
			reloaded._milestone_flow = original_flow
			DirAccess.remove_absolute(ProjectSettings.globalize_path(bad_path))
		if not reloaded.choose("right", second_token):
			_fail("second authored chapter beat did not settle: " + path_id)
			return
		var final_state: Dictionary = reloaded.state
		var settled_facts: Dictionary = final_state.get("noncombatFlow", {}).get("spineFacts", {})
		if final_state.get("phase") != "FLOW_PENDING" \
				or final_state.get("currentCardId") != "" \
				or int(final_state["runClock"]["decisionIndex"]) != 9 \
				or int(final_state["attributes"]["cultivation"]) != int(second_before["attributes"]["cultivation"]) + 3 \
				or int(final_state["attributes"]["karmaGood"]) != int(second_before["attributes"]["karmaGood"]) + 2 \
				or int(final_state["attributes"]["fortune"]) != int(second_before["attributes"]["fortune"]) + 1 \
				or settled_facts.get("fact:0:qi_main_call", {}).get("status") != "consumed" \
				or settled_facts.get("fact:0:qi_main_pressure", {}).get("status") != "active" \
				or not final_state.get("noncombatFlow", {}).get("spineConsumptions", {}).has(
					"fact:0:qi_main_call:qi_main_call_to_pressure"):
			_fail("second chapter choice lost effects or causal predecessor: " + path_id)
			return
		var final_seeds: Array = final_state.get("karmaSeeds", [])
		if final_seeds.size() != 3 or int(final_seeds[0].get("delay", -1)) != 3 \
				or int(final_seeds[1].get("delay", -1)) != 6 \
				or int(final_seeds[2].get("delay", -1)) != 7 \
				or final_seeds[2].get("id") != "causal:shared_opportunity":
			_fail("second chapter seed cadence differs from live browser: " + path_id)
			return
		var final_reload = Domain.new(Registry.new(), RunSession.new(save_path, "slot_3"), "slot_3")
		if not final_reload.restore() or not _same(final_reload.state, final_state) \
				or final_reload.choose("right", second_token):
			_fail("two chapter decisions failed strict reload/duplicate check: " + path_id)
			return
	if not _check_legacy_avoid_saves():
		return
	if not _check_frozen_legacy_fixtures():
		return
	if not _check_cross_choices_against_browser():
		return
	print("NONCOMBAT_MILESTONE_FLOW_PASS paths=4 chapter=15_to_30 cross_choices=8 frozen_legacy=2_guarded source_art=true")
	quit(0)


func _check_legacy_avoid_saves() -> bool:
	for variant in ["early", "promise"]:
		for save_phase in ["NARRATIVE_RESULT_PENDING", "FLOW_PENDING"]:
			if not _check_legacy_avoid_save(variant, save_phase):
				return false
	return true


func _check_legacy_avoid_save(variant: String, save_phase: String) -> bool:
	var save_path := "user://tests/milestone_legacy_%s_%s_%d.json" % [
		variant, save_phase, Time.get_ticks_usec()]
	var old = Domain.new(Registry.new(), RunSession.new(save_path, "slot_3"), "slot_3")
	if not old.start("sword"):
		_fail("legacy setup failed")
		return false
	for step in 5:
		if not old.choose("left", old.issue_choice_token()):
			_fail("legacy opening setup failed: " + str(step))
			return false
	old._legacy_karma_replay = true
	old._avoid_flow.legacy_replay = true
	old._avoid_flow.legacy_schema_replay = variant == "early"
	old._legacy_lifespan_replay = true
	old._avoid_flow.legacy_lifespan_replay = true
	if not old.choose("right", old.issue_choice_token()):
		_fail("legacy avoid setup failed")
		return false
	if save_phase == "FLOW_PENDING" and not old.choose("left", old.issue_choice_token()):
		_fail("legacy result setup failed")
		return false
	var saved: Dictionary = old.state.duplicate(true)
	if saved.get("noncombatFlow", {}).has("karmaClockVersion") \
			or saved.get("noncombatFlow", {}).has("lifespanCostVersion"):
		_fail("legacy fixture is already decision-versioned")
		return false
	if saved.get("noncombatFlow", {}).has("promise") == (variant == "early"):
		_fail("legacy fixture has wrong response schema")
		return false
	var restored = Domain.new(Registry.new(), RunSession.new(save_path, "slot_3"), "slot_3")
	if not restored.restore() or not _same(restored.state, saved):
		_fail("legacy N3b snapshot did not restore: " + save_phase)
		return false
	if save_phase == "NARRATIVE_RESULT_PENDING" \
			and not restored.choose("left", restored.issue_choice_token()):
		_fail("legacy result could not advance")
		return false
	if not restored.resume_flow() or restored.get_current_card().get("id") != "ch_qi_20" \
			or int(restored.state.get("karmaSeeds", [])[0].get("delay", -1)) != 5 \
			or int(restored.state.get("noncombatFlow", {}).get("karmaClockVersion", -1)) != 1 \
			or (variant == "early" and restored.state.get("noncombatFlow", {}).get("legacySchemaVersion") != 0):
		_fail("legacy N3b upgrade lost decision ticks: %s %s" % [variant, save_phase])
		return false
	var upgraded = Domain.new(Registry.new(), RunSession.new(save_path, "slot_3"), "slot_3")
	if not upgraded.restore() or not _same(upgraded.state, restored.state):
		_fail("upgraded legacy snapshot failed strict replay: %s %s" % [variant, save_phase])
		return false
	return true


func _check_frozen_legacy_fixtures() -> bool:
	for stem in ["n3b_early_result_pending", "n3b_early_flow_pending"]:
		var fixture := "res://tests/fixtures/%s_v2.json" % stem
		var bytes := FileAccess.get_file_as_bytes(fixture)
		if bytes.is_empty():
			_fail("frozen original N3b snapshot unavailable: " + stem)
			return false
		var save_path := "user://tests/%s_replay_%d.json" % [stem, Time.get_ticks_usec()]
		var store = RunSession.new(save_path, "slot_3")
		var target = FileAccess.open(store.v2_path, FileAccess.WRITE)
		if target == null:
			_fail("cannot stage original N3b snapshot")
			return false
		target.store_buffer(bytes)
		target.close()
		var restored = Domain.new(Registry.new(), store, "slot_3")
		var frozen_state: Dictionary = JSON.parse_string(bytes.get_string_from_utf8())["state"]
		var frozen_hash: String = frozen_state.get("noncombatFlow", {}).get(
			"sourceContentHash", "")
		if frozen_hash != restored._battle_gateway.source_content_hash():
			if restored.restore() or store.last_error != "SOURCE_MISMATCH" \
					or FileAccess.get_file_as_bytes(store.v2_path) != bytes \
					or not store.archive_unrestorable().is_empty():
				_fail("source-drifted N3b fixture was not preserved: " + stem)
				return false
			continue
		if not restored.restore() or FileAccess.get_file_as_bytes(store.v2_path) != bytes:
			_fail("original N3b bytes did not restore unchanged: " + stem)
			return false
		if stem == "n3b_early_result_pending" \
				and not restored.choose("left", restored.issue_choice_token()):
			_fail("original N3b pending result did not acknowledge")
			return false
		if not restored.resume_flow() or restored.get_current_card().get("id") != "ch_qi_20" \
				or int(restored.state.get("karmaSeeds", [])[0].get("delay", -1)) != 5:
			_fail("original N3b snapshot did not reach first milestone: " + stem)
			return false
		var reopened = Domain.new(Registry.new(), RunSession.new(save_path, "slot_3"), "slot_3")
		if not reopened.restore() or not _same(reopened.state, restored.state):
			_fail("upgraded original N3b snapshot failed strict replay: " + stem)
			return false
	return true


func _check_cross_choices_against_browser() -> bool:
	var source: Variant = JSON.parse_string(FileAccess.get_file_as_string(
		"res://tests/fixtures/n4a_cross_browser_expected.json"))
	if not source is Dictionary:
		_fail("cross-choice browser evidence missing")
		return false
	for path_id in ["sword", "spell", "body", "pill"]:
		var expected: Dictionary = source.get("paths", {}).get(path_id, {})
		if expected.is_empty():
			_fail("browser evidence missing path: " + path_id)
			return false
		var save_path := "user://tests/milestone_cross_%s_%d.json" % [
			path_id, Time.get_ticks_usec()]
		var game = Domain.new(Registry.new(), RunSession.new(save_path, "slot_3"), "slot_3")
		if not game.start(path_id):
			_fail("cross-choice opening failed: " + path_id)
			return false
		for step in 5:
			if not game.choose("left", game.issue_choice_token()):
				_fail("cross-choice tutorial failed: " + path_id)
				return false
		if not game.choose("right", game.issue_choice_token()) \
					or not game.choose("left", game.issue_choice_token()) \
					or not game.resume_flow():
			_fail("cross-choice chapter entry failed: " + path_id)
			return false
		if not game.choose("right", game.issue_choice_token()) \
					or not _matches_browser(game, expected["afterFirstRight"], true):
			_fail("first milestone right differs from live browser: %s resources=%s expected=%s" % [
				path_id, str(game.state.get("resources", {})),
				str(expected["afterFirstRight"].get("resources", {}))])
			return false
		if not game.choose("left", game.issue_choice_token()) \
					or not _matches_browser(game, expected["afterSecondLeft"], false):
			_fail("second milestone left differs from live browser: " + path_id)
			return false
	return true


func _matches_browser(game: RefCounted, expected: Dictionary, has_next_card: bool) -> bool:
	var seeds: Array = []
	for seed in game.state.get("karmaSeeds", []):
		seeds.append({"id": seed.get("id"), "delay": seed.get("delay")})
	return _same(game.state.get("attributes", {}), expected.get("attributes", {})) \
		and (not expected.has("resources") or _same(game.state.get("resources", {}),
			expected.get("resources", {}))) \
		and JSON.parse_string(JSON.stringify(seeds)) == \
			JSON.parse_string(JSON.stringify(expected.get("karmaSeeds", []))) \
		and JSON.parse_string(JSON.stringify(game.state.get("chapterProgress", {}).get(
			"triggeredMilestones", {}).get("qi", []))) == \
			JSON.parse_string(JSON.stringify(expected.get("triggeredMilestones", []))) \
		and ((game.get_current_card().get("id") == expected.get("nextCardId")) \
			if has_next_card else game.state.get("phase") == "FLOW_PENDING")


func _same(left: Dictionary, right: Dictionary) -> bool:
	return JSON.parse_string(JSON.stringify(left)) == JSON.parse_string(JSON.stringify(right))


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
