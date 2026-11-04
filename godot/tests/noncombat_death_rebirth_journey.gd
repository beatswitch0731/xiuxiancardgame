extends SceneTree

const Registry = preload("res://scripts/runtime_data_registry.gd")
const Domain = preload("res://scripts/noncombat_domain.gd")
const RunSession = preload("res://scripts/noncombat_run_session.gd")
const ContentRepository = preload("res://scripts/noncombat_content_repository.gd")
const SaveSlots = preload("res://scripts/noncombat_save_slots.gd")
const FIXTURE := "res://tests/fixtures/pill_decision54_death_probe_v2.json"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var slot_root := "user://tests/death_rebirth_%d_%d_%d" % [
		int(Time.get_unix_time_from_system()), OS.get_process_id(), Time.get_ticks_usec()]
	var path: String = SaveSlots.new(slot_root).save_path_for("slot_3")
	var store = RunSession.new(path, "slot_3")
	var directory := ProjectSettings.globalize_path(store.v2_path).get_base_dir()
	if DirAccess.make_dir_recursive_absolute(directory) != OK:
		return _fail("death journey test directory unavailable")
	var file := FileAccess.open(store.v2_path, FileAccess.WRITE)
	if file == null:
		return _fail("death journey fixture cannot be staged")
	file.store_string(FileAccess.get_file_as_string(FIXTURE))
	file.close()
	var loaded: Dictionary = store.load_snapshot()
	if loaded.is_empty():
		return _fail("durable pill probe envelope unreadable: " + store.last_error)
	var game = Domain.new(Registry.new(), store, "slot_3")
	_stabilize_ambient(game)
	if not game.restore() or game.state.get("phase") != "FLOW_PENDING" \
			or int(game.state.get("runClock", {}).get("decisionIndex", -1)) != 54:
		return _fail("durable natural pill checkpoint did not strictly restore: " + store.last_error)
	if not game.resume_flow():
		return _fail("natural pill checkpoint did not draw its next source card")
	var card: Dictionary = game.get_current_card()
	if card.get("id") != "q_love" or card.get("sceneImage") != \
			"assets/cards/events/scene_event_qi_love.png":
		return _fail("next draw was not the original love card and scene")
	var before: Dictionary = game.state.duplicate(true)
	var before_bytes := FileAccess.get_file_as_string(store.v2_path)
	var token := game.issue_choice_token()
	if token <= 0 or not game.choose("right", token):
		return _fail("source executable fatal love choice was blocked")
	if game.state.get("phase") != "DEATH_PENDING" \
			or game.get_current_card().get("id") != "death_dao_collapse" \
			or game.state.get("dead") != true \
			or game.state.get("lifePhase") != "DYING_NARRATIVE" \
			or int(game.state.get("attributes", {}).get("daoHeart", -1)) != 0 \
			or int(game.state.get("attributes", {}).get("cultivation", -1)) != 95 \
			or int(game.state.get("resources", {}).get("lifespan", -1)) != 68 \
			or game.state.get("resources", {}).get("companions") != ["mortal"] \
			or game.state.has("factionCollectionNewActivationIndex") \
			or int(game.state.get("runClock", {}).get("decisionIndex", -1)) != 55:
		return _fail("fatal source choice did not settle exactly once into death narrative")
	var content = ContentRepository.new()
	var art: Dictionary = content.card_scene_image_status("death_dao_collapse")
	if art.get("sceneImage") != "assets/cards/keyframes/scene_key_death_reckoning_v1.png" \
			or art.get("textureLoadable") != true:
		return _fail("authored death scene art was not mounted")
	var dead_reopen = Domain.new(Registry.new(), RunSession.new(path, "slot_3"), "slot_3")
	_stabilize_ambient(dead_reopen)
	if not dead_reopen.restore() or dead_reopen.get_current_card().get("id") != \
			"death_dao_collapse":
		return _fail("death card was lost on strict restart: " + JSON.stringify({
			"store": dead_reopen._store.last_error,
			"savedPhase": game.state.get("phase"),
			"savedDecision": game.state.get("runClock", {}).get("decisionIndex"),
			"factionCutover": game.state.get("factionCollectionNewActivationIndex"),
			"mentorVersion": game.state.get("mentorArcState", {}).get("version")}))
	if dead_reopen.choose("left", token):
		return _fail("stale pre-death token consumed the death card")
	var death_token := dead_reopen.issue_choice_token()
	# The migrated sword/spell avoidance producer can grant knowledge.world.
	# Project a terminal state with that already-earned progress through the
	# same source death-card consumer; the long pill fixture has no knowledge.
	var informed_terminal: Dictionary = dead_reopen.state.duplicate(true)
	informed_terminal["knowledge"] = {"world": 2}
	informed_terminal["clues"] = [{"id": "trial_trace", "source": "encounter",
		"turn": 4, "life": 0}]
	var inherited: Dictionary = dead_reopen._rebirth_flow.new_life(
		informed_terminal, dead_reopen.get_current_card(), "left", "slot_3")
	if inherited.get("knowledge", {}).get("world") != 2 \
			or inherited.get("clues") != [{"id": "trial_trace",
				"source": "legacy", "turn": 0, "life": 1}]:
		return _fail("earned knowledge and clue identity were lost across life reset")
	var right: Dictionary = dead_reopen._rebirth_flow.new_life(
		dead_reopen.state, dead_reopen.get_current_card(), "right", "slot_3")
	if right.get("legacyBonuses", {}).get("startCultivation") != 10 \
			or right.get("legacyBonuses", {}).get("startSpiritStone") != 7 \
			or right.get("legacyBonuses", {}).get("daoHeart", 0) != 0:
		return _fail("source death-card right choice did not map to cultivation inheritance")
	var death_before: Dictionary = dead_reopen.state.duplicate(true)
	var death_bytes := FileAccess.get_file_as_string(store.v2_path)
	dead_reopen._store.fail_promotion_once = true
	if death_token <= 0 or dead_reopen.choose("left", death_token) \
			or dead_reopen.state != death_before \
			or FileAccess.get_file_as_string(store.v2_path) != death_bytes:
		return _fail("failed cross-life promotion changed the death card or active save")
	if not dead_reopen.choose("left", death_token):
		return _fail("authored death-card legacy choice did not reincarnate")
	var new_life: Dictionary = dead_reopen.state
	if new_life.get("phase") != "REBIRTH_PENDING" \
			or dead_reopen.get_current_card().get("id") != "rebirth_boon" \
			or new_life.get("path") != null \
			or new_life.get("lifePhase") != "LEGACY_CHOICE" \
			or new_life.get("runClock", {}).get("lifeId") != "slot_3:life:1" \
			or int(new_life.get("runClock", {}).get("decisionIndex", -1)) != 0 \
			or new_life.get("lifeJournal", []).size() != 1 \
			or int(new_life.get("legacyBonuses", {}).get("daoHeart", -1)) != 1 \
			or int(new_life.get("legacyBonuses", {}).get("startSpiritStone", -1)) != 7 \
			or new_life.get("legacyArchive") != death_before.get("legacyArchive") \
			or new_life.get("legacyFragmentVersion") != death_before.get("legacyFragmentVersion") \
			or new_life.get("legacyRuleSourceSha") != death_before.get("legacyRuleSourceSha") \
			or new_life.get("legacyRngState") != death_before.get("legacyRngState") \
			or int(new_life.get("legacyRunState", {}).get("lifeCount", -1)) != 1 \
			or new_life.has("marketState") \
			or new_life.get("questState") != {"saveVersion": 3,
				"activeQuests": [], "completedQuests": [],
				"closedQuests": ["white_fox_line"],
				"questOutcomes": {"white_fox_line": "failed"}} \
			or new_life.get("worldContinuityActivationIndex") != 0 \
			or new_life.get("worldContinuityState", {}).get("lifeId") != 1 \
			or new_life.get("worldContinuityState", {}).get("npcs", {}).get(
				"bai_ren", {}).get("manifestation") != "PHYSICAL" \
			or new_life.has("normalFlow") \
			or new_life.get("resources", {}).get("companions") != [] \
			or new_life.get("deck") != []:
		return _fail("reincarnation did not reset the life and apply source legacy")
	var right_store = RunSession.new(slot_root + "/right_slot_3_v1.json", "slot_3")
	var right_file := FileAccess.open(right_store.v2_path, FileAccess.WRITE)
	if right_file == null:
		return _fail("right legacy branch save could not be staged")
	right_file.store_string(death_bytes)
	right_file.close()
	var right_game = Domain.new(Registry.new(), right_store, "slot_3")
	_stabilize_ambient(right_game)
	if not right_game.restore() or not right_game.choose(
			"right", right_game.issue_choice_token()):
		return _fail("right death-card choice did not cross the durable life boundary")
	if right_game.state.get("phase") != "REBIRTH_PENDING" \
			or int(right_game.state.get("attributes", {}).get("cultivation", -1)) != 10 \
			or int(right_game.state.get("legacyBonuses", {}).get("startCultivation", -1)) != 10 \
			or int(right_game.state.get("legacyBonuses", {}).get("daoHeart", 0)) != 0 \
			or int(right_game.state.get("legacyBonuses", {}).get("startSpiritStone", -1)) != 7:
		return _fail("right death-card reward did not settle once")
	var right_reopen = Domain.new(Registry.new(), RunSession.new(
		slot_root + "/right_slot_3_v1.json", "slot_3"), "slot_3")
	_stabilize_ambient(right_reopen)
	if not right_reopen.restore():
		return _fail("right death-card inheritance failed strict restore: " + \
			String(right_reopen._store.last_error))
	if right_reopen.state != JSON.parse_string(JSON.stringify(right_game.state)):
		return _fail("right death-card inheritance changed across restart")
	var v1_store = RunSession.new(slot_root + "/v1_slot_3_v1.json", "slot_3")
	var v1_file := FileAccess.open(v1_store.v2_path, FileAccess.WRITE)
	if v1_file == null:
		return _fail("v1 new-life save could not be staged")
	v1_file.store_string(death_bytes)
	v1_file.close()
	var v1_prior = Domain.new(Registry.new(), v1_store, "slot_3")
	_stabilize_ambient(v1_prior)
	if not v1_prior.restore():
		return _fail("v1 previous-life checkpoint could not strictly restore")
	var v1_life: Dictionary = v1_prior._rebirth_flow.new_life(v1_prior.state,
		v1_prior.get_current_card(), "right", "slot_3", 1)
	v1_life.erase("worldContinuityState")
	v1_life.erase("worldContinuityActivationIndex")
	v1_life.erase("worldContinuitySourceSha")
	if v1_life.get("rebirthInheritanceVersion") != 1 \
			or v1_life.has("questState") \
			or v1_store.commit_life_transition(v1_life,
				v1_prior._store_revision, "right").get("ok") != true:
		return _fail("already-written v1 life format could not be staged")
	var v1_reopen = Domain.new(Registry.new(), RunSession.new(
		slot_root + "/v1_slot_3_v1.json", "slot_3"), "slot_3")
	_stabilize_ambient(v1_reopen)
	if not v1_reopen.restore() or v1_reopen.state != \
			JSON.parse_string(JSON.stringify(v1_life)):
		return _fail("already-written v1 new-life save failed strict restart")
	if not v1_reopen.select_rebirth_path("body") \
			or not v1_reopen.choose("down", v1_reopen.issue_choice_token()) \
			or not v1_reopen.cancel_camp_target(v1_reopen.issue_choice_token()):
		return _fail("old v1 new-life save could not enter the original body route")
	var old_advanced: Dictionary = v1_reopen.state.duplicate(true)
	old_advanced.erase("worldContinuityState")
	old_advanced.erase("worldContinuityActivationIndex")
	old_advanced.erase("worldContinuitySourceSha")
	var old_advanced_store = RunSession.new(
		slot_root + "/old_advanced_slot_3_v1.json", "slot_3")
	var old_advanced_envelope: Dictionary = JSON.parse_string(
		FileAccess.get_file_as_string(v1_store.v2_path))
	old_advanced_envelope.state = old_advanced
	var old_advanced_file := FileAccess.open(old_advanced_store.v2_path, FileAccess.WRITE)
	old_advanced_file.store_string(JSON.stringify(old_advanced_envelope))
	old_advanced_file.close()
	var old_advanced_game = Domain.new(Registry.new(), old_advanced_store, "slot_3")
	_stabilize_ambient(old_advanced_game)
	if not old_advanced_game.restore() \
			or old_advanced_game.state != JSON.parse_string(JSON.stringify(old_advanced)):
		return _fail("old advanced second-life save failed markerless strict replay")
	var old_advanced_bytes := FileAccess.get_file_as_string(old_advanced_store.v2_path)
	var changed_manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(
		"res://content/source_manifest.json"))
	for row in changed_manifest.get("data", []):
		if row.get("path") == "data/npcs/core_npcs.json":
			row["sha256"] = "0".repeat(64)
			break
	var changed_manifest_path := slot_root + "/world_drift_manifest.json"
	var changed_manifest_file := FileAccess.open(changed_manifest_path, FileAccess.WRITE)
	changed_manifest_file.store_string(JSON.stringify(changed_manifest))
	changed_manifest_file.close()
	var drift_store = RunSession.new(slot_root + "/old_advanced_slot_3_v1.json", "slot_3")
	var drift_game = Domain.new(Registry.new(), drift_store, "slot_3",
		ContentRepository.new(changed_manifest_path))
	_stabilize_ambient(drift_game)
	if drift_game.restore() or drift_store.last_error != "SOURCE_MISMATCH" \
			or FileAccess.get_file_as_string(old_advanced_store.v2_path) != old_advanced_bytes:
		return _fail("old second-life NPC source drift was not locked atomically")
	for expected_id in ["q_fortune", "ch_qi_20", "q_inherit", "ch_qi_40",
			"ch_qi_60"]:
		if v1_reopen.state.get("phase") == "FLOW_PENDING" \
				and not v1_reopen.resume_flow():
			return _fail("old v1 second-life quest route stopped before " + expected_id)
		if expected_id == "q_inherit" and not _avoid_due_second_life_catalog(v1_reopen):
			return _fail("old v1 second-life due catalog could not be avoided")
		if v1_reopen.state.get("phase") == "FLOW_PENDING" \
				and not v1_reopen.resume_flow():
			return _fail("old v1 second-life quest route stopped after due catalog")
		if v1_reopen.get_current_card().get("id") != expected_id \
				or not v1_reopen.choose("left", v1_reopen.issue_choice_token()):
			return _fail("old v1 second-life route diverged at " + expected_id)
	if not v1_reopen.resume_flow() \
			or v1_reopen.get_current_card().get("id") != "q_whiteFox_quest" \
			or v1_reopen.state.get("worldContinuityState", {}).get("lifeId") != 1 \
			or v1_reopen.state.get("worldContinuityState", {}).get(
				"npcs", {}).get("bai_luoxuan", {}).get("lifeId") != 1:
		return _fail("unclosed white-fox quest did not naturally enter second life")
	var v1_quest_bytes := FileAccess.get_file_as_string(v1_store.v2_path)
	var v1_quest_branch = RunSession.new(
		slot_root + "/v1_quest_branch_slot_3_v1.json", "slot_3")
	var v1_quest_file := FileAccess.open(v1_quest_branch.v2_path, FileAccess.WRITE)
	if v1_quest_file == null:
		return _fail("second-life white-fox branch save could not be staged")
	v1_quest_file.store_string(v1_quest_bytes)
	v1_quest_file.close()
	var v1_quest_pending = Domain.new(Registry.new(), RunSession.new(
		slot_root + "/v1_slot_3_v1.json", "slot_3"), "slot_3")
	_stabilize_ambient(v1_quest_pending)
	if not v1_quest_pending.restore() or v1_quest_pending.state != \
			JSON.parse_string(JSON.stringify(v1_reopen.state)):
		return _fail("pending second-life white-fox entry failed strict restart")
	var v1_quest_token := v1_quest_pending.issue_choice_token()
	v1_quest_pending._store.fail_promotion_once = true
	if v1_quest_pending.choose("left", v1_quest_token) \
			or FileAccess.get_file_as_string(v1_store.v2_path) != v1_quest_bytes \
			or not v1_quest_pending.choose("left", v1_quest_token):
		return _fail("second-life white-fox refusal rollback or choice failed")
	var v1_quest_failed = Domain.new(Registry.new(), RunSession.new(
		slot_root + "/v1_slot_3_v1.json", "slot_3"), "slot_3")
	_stabilize_ambient(v1_quest_failed)
	if not v1_quest_failed.restore() \
			or v1_quest_failed.state.get("questState", {}).get(
				"questOutcomes", {}).get("white_fox_line") != "failed" \
			or v1_quest_failed.state.get("worldContinuityState", {}).get(
				"npcs", {}).get("bai_luoxuan", {}).get("lifecycle") != "DEAD":
		return _fail("failed second-life white-fox outcome did not strictly restart")
	var v1_quest_rescue = Domain.new(Registry.new(), v1_quest_branch, "slot_3")
	_stabilize_ambient(v1_quest_rescue)
	if not v1_quest_rescue.restore() \
			or not v1_quest_rescue.choose("right", v1_quest_rescue.issue_choice_token()) \
			or not v1_quest_rescue.choose("left", v1_quest_rescue.issue_choice_token()) \
			or not v1_quest_rescue.choose("down", v1_quest_rescue.issue_choice_token()):
		return _fail("second-life white-fox rescue and abandonment branch failed")
	var v1_quest_abandoned = Domain.new(Registry.new(), RunSession.new(
		slot_root + "/v1_quest_branch_slot_3_v1.json", "slot_3"), "slot_3")
	_stabilize_ambient(v1_quest_abandoned)
	if not v1_quest_abandoned.restore() \
			or v1_quest_abandoned.state.get("questState", {}).get(
				"questOutcomes", {}).get("white_fox_line") != "abandoned" \
			or not v1_quest_abandoned.state.get("questState", {}).get(
				"completedQuests", []).is_empty():
		return _fail("abandoned second-life white-fox outcome did not strictly restart")
	var v1_paid_store = RunSession.new(
		slot_root + "/v1_quest_paid_slot_3_v1.json", "slot_3")
	var v1_paid_file := FileAccess.open(v1_paid_store.v2_path, FileAccess.WRITE)
	if v1_paid_file == null:
		return _fail("second-life paid white-fox branch save could not be staged")
	v1_paid_file.store_string(v1_quest_bytes)
	v1_paid_file.close()
	var v1_paid = Domain.new(Registry.new(), v1_paid_store, "slot_3")
	_stabilize_ambient(v1_paid)
	if not v1_paid.restore() \
			or not v1_paid.choose("right", v1_paid.issue_choice_token()) \
			or not v1_paid.choose("left", v1_paid.issue_choice_token()) \
			or v1_paid.get_current_card().get("id") != "q_whiteFox_3":
		return _fail("natural second-life white-fox rescue did not reach paid ending")
	var paid_before: Dictionary = v1_paid.state.duplicate(true)
	var paid_bytes := FileAccess.get_file_as_string(v1_paid_store.v2_path)
	var paid_token := v1_paid.issue_choice_token()
	var paid_stones := int(paid_before.get("resources", {}).get("spiritStone", -1))
	if paid_stones < 20:
		return _fail("source predecessor cards did not earn the 20-stone quest price")
	v1_paid._store.fail_promotion_once = true
	if v1_paid.choose("right", paid_token) \
			or v1_paid.state != paid_before \
			or FileAccess.get_file_as_string(v1_paid_store.v2_path) != paid_bytes \
			or not v1_paid.choose("right", paid_token):
		return _fail("second-life paid white-fox choice failed rollback or retry")
	var paid_quest: Dictionary = v1_paid.state.get("questState", {})
	var before_rep: Dictionary = paid_before.get("factionProgress", {}).get(
		"reputations", {})
	var after_rep: Dictionary = v1_paid.state.get("factionProgress", {}).get(
		"reputations", {})
	if v1_paid.state.get("phase") != "FLOW_PENDING" \
			or paid_quest.get("questOutcomes", {}).get("white_fox_line") != "completed" \
			or not paid_quest.get("completedQuests", []).has("white_fox_line") \
			or v1_paid.state.get("flags", {}).get("whiteFoxCompleted") != true \
			or int(v1_paid.state.get("resources", {}).get("spiritStone", -1)) != paid_stones \
			or int(after_rep.get("qingyun_sword", 0)) != int(
				before_rep.get("qingyun_sword", 0)) + 5 \
			or not v1_paid.state.get("karmaSeeds", []).any(func(seed: Variant) -> bool:
				return seed is Dictionary and seed.get("id") == "foxGratitude" \
				and int(seed.get("originLife", -1)) == 1):
		return _fail("natural second-life paid ending lost source reward or identity")
	var v1_paid_reopen = Domain.new(Registry.new(), RunSession.new(
		slot_root + "/v1_quest_paid_slot_3_v1.json", "slot_3"), "slot_3")
	_stabilize_ambient(v1_paid_reopen)
	if not v1_paid_reopen.restore() or v1_paid_reopen.state != \
			JSON.parse_string(JSON.stringify(v1_paid.state)):
		return _fail("paid second-life white-fox completion failed strict restart")
	if FileAccess.get_file_as_string(store.v2_path) == \
			FileAccess.get_file_as_string(right_store.v2_path):
		return _fail("left and right death-card choices shared a save")
	var rebirth_reopen = Domain.new(Registry.new(), RunSession.new(path, "slot_3"), "slot_3")
	_stabilize_ambient(rebirth_reopen)
	if not rebirth_reopen.restore() or rebirth_reopen.get_current_card().get("id") != \
			"rebirth_boon" or rebirth_reopen._flow_card_count != \
			dead_reopen._flow_card_count or rebirth_reopen._normal_starvation != \
			dead_reopen._normal_starvation or dead_reopen._flow_card_count != 0:
		return _fail("unselected rebirth boon was lost on strict restart")
	var scene: PackedScene = load("res://scenes/noncombat_opening.tscn")
	var ui: Control = scene.instantiate()
	ui.save_path = ""
	root.add_child(ui)
	await process_frame
	# This exploratory fixture requires test-only ambient rolls for replay.
	# Mount its strictly restored domain into the real desktop scene, then
	# exercise the actual path button without pretending the fixture is a
	# default-random player save.
	ui.opening = rebirth_reopen
	ui.opening_store = rebirth_reopen._store
	rebirth_reopen.changed.connect(ui._on_opening_changed)
	ui._on_opening_changed({"type": "RESTORED", "cardId": "rebirth_boon"})
	var path_screen: Control = ui.get_node("DesktopMargin/ScreenStack/PathSelection")
	if not path_screen.visible or ui.opening.state.get("path") != null \
			or ui.opening.get_current_card().get("id") != "rebirth_boon":
		return _fail("desktop scene did not offer a new-life path selection: visible=%s phase=%s path=%s card=%s error=%s" % [
			str(path_screen.visible), ui.opening.state.get("phase"),
			str(ui.opening.state.get("path")), ui.opening.get_current_card().get("id"),
			ui.opening_store.last_error])
	var unselected_bytes := FileAccess.get_file_as_string(store.v2_path)
	ui.opening_store.fail_promotion_once = true
	(path_screen.get_node("SourcePathGrid/Path_body") as Button).pressed.emit()
	if ui.opening.state.get("path") != null or not path_screen.visible \
			or FileAccess.get_file_as_string(store.v2_path) != unselected_bytes:
		return _fail("failed new-life path write changed the selected path or active save")
	(path_screen.get_node("SourcePathGrid/Path_body") as Button).pressed.emit()
	await process_frame
	if ui.opening.state.get("path") != "body" \
			or ui.opening.state.get("lifePhase") != "ALIVE" \
			or ui.opening.get_current_card().get("id") != "rebirth_boon" \
			or not ui.story_screen.visible or ui.art_rect.texture == null:
		return _fail("desktop path selection lost the source rebirth boon and original art")
	ui.queue_free()
	await process_frame
	var selected_reopen = Domain.new(Registry.new(), RunSession.new(path, "slot_3"), "slot_3")
	_stabilize_ambient(selected_reopen)
	if not selected_reopen.restore() or selected_reopen.state.get("path") != "body" \
			or selected_reopen.get_current_card().get("id") != "rebirth_boon":
		return _fail("selected new-life path did not strictly restore")
	var selected_bytes := FileAccess.get_file_as_string(store.v2_path)
	var forged_record: Dictionary = store.load_snapshot().duplicate(true)
	forged_record["state"]["lifeJournal"][0]["terminalState"][
		"resources"]["spiritStone"] = 999
	var forged_store = RunSession.new(slot_root + "/forged_slot_3_v1.json", "slot_3")
	var forged_file := FileAccess.open(forged_store.v2_path, FileAccess.WRITE)
	if forged_file == null:
		return _fail("forged new-life save could not be staged")
	forged_file.store_string(JSON.stringify(forged_record))
	forged_file.close()
	if forged_store.load_snapshot().is_empty():
		return _fail("forgery test did not cross the envelope reader")
	var forged_reopen = Domain.new(Registry.new(), forged_store, "slot_3")
	_stabilize_ambient(forged_reopen)
	if forged_reopen.restore() or not forged_reopen.state.is_empty() \
			or FileAccess.get_file_as_string(store.v2_path) != selected_bytes:
		return _fail("forged previous-life terminal state was trusted")
	var boon_token := selected_reopen.issue_choice_token()
	var boon_before: Dictionary = selected_reopen.state.duplicate(true)
	selected_reopen._store.fail_promotion_once = true
	if boon_token <= 0 or selected_reopen.choose("down", boon_token) \
			or selected_reopen.state != boon_before \
			or FileAccess.get_file_as_string(store.v2_path) != selected_bytes:
		return _fail("failed rebirth boon write changed the source card or save")
	var boon_committed: bool = selected_reopen.choose("down", boon_token)
	if not boon_committed \
			or selected_reopen.state.get("phase") != "CAMP_TARGET_PENDING" \
			or selected_reopen.get_current_card().get("id") != "rebirth_boon":
		return _fail("desktop rebirth boon down choice did not open its source target: " \
			+ JSON.stringify({"committed": boon_committed,
				"phase": selected_reopen.state.get("phase"),
				"card": selected_reopen.get_current_card().get("id"),
				"marketError": selected_reopen._market_flow.last_error,
				"tradeError": selected_reopen._trade_route_flow.last_error,
				"wheelError": selected_reopen._destiny_wheel_flow.last_error,
				"rippleError": selected_reopen._ripple_flow.last_error,
				"hintError": selected_reopen._hint_flow.last_error}))
	var boon_reopen = Domain.new(Registry.new(), RunSession.new(path, "slot_3"), "slot_3")
	_stabilize_ambient(boon_reopen)
	if not boon_reopen.restore() or boon_reopen.state != \
			JSON.parse_string(JSON.stringify(selected_reopen.state)):
		return _fail("rebirth boon target did not strictly restore")
	if not boon_reopen.cancel_camp_target(boon_reopen.issue_choice_token()) \
			or boon_reopen.state.get("phase") != "FLOW_PENDING":
		return _fail("rebirth boon removal target could not be cancelled")
	var after_boon = Domain.new(Registry.new(), RunSession.new(path, "slot_3"), "slot_3")
	_stabilize_ambient(after_boon)
	if not after_boon.restore() or not after_boon.resume_flow() \
			or after_boon.get_current_card().is_empty():
		return _fail("second life could not draw its next source card after boon")
	var first_new_card_id: String = String(after_boon.get_current_card().get("id", ""))
	var first_new_reopen = Domain.new(Registry.new(), RunSession.new(path, "slot_3"), "slot_3")
	_stabilize_ambient(first_new_reopen)
	if not first_new_reopen.restore() \
			or first_new_reopen.get_current_card().get("id") != first_new_card_id \
			or first_new_reopen.state.get("runClock", {}).get("lifeId") != "slot_3:life:1":
		return _fail("second-life first normal card was lost on strict restart")
	var first_direction := "left" if first_new_reopen.can_choose_direction("left") else "right"
	if not first_new_reopen.choose(first_direction, first_new_reopen.issue_choice_token()):
		return _fail("second-life first normal card could not be consumed")
	var settled_reopen = Domain.new(Registry.new(), RunSession.new(path, "slot_3"), "slot_3")
	_stabilize_ambient(settled_reopen)
	if not settled_reopen.restore() or settled_reopen.state != \
			JSON.parse_string(JSON.stringify(first_new_reopen.state)):
		return _fail("second-life first normal choice did not strictly restore")
	if first_new_card_id != "q_fortune" \
			or first_direction != "left" \
			or int(settled_reopen.state.get("attributes", {}).get("cultivation", -1)) != 15 \
			or not settled_reopen.resume_flow():
		return _fail("second-life fortune did not reach the first chapter threshold")
	var new_milestone: Dictionary = settled_reopen.get_current_card()
	var milestone_art: Dictionary = content.asset_status(String(
		new_milestone.get("sceneImage", "")))
	if settled_reopen.state.get("phase") != "MILESTONE_PENDING" \
			or new_milestone.get("id") != "ch_qi_20" \
			or new_milestone.get("threshold") != 15 \
			or new_milestone.get("sceneImage") != \
				"assets/cards/events/scene_qi_q_bodyTrial.png" \
			or milestone_art.get("shaVerified") != true \
			or milestone_art.get("textureLoadable") != true:
		return _fail("source first chapter card or original scene was not presented")
	var milestone_reopen = Domain.new(Registry.new(), RunSession.new(path, "slot_3"), "slot_3")
	_stabilize_ambient(milestone_reopen)
	if not milestone_reopen.restore() or milestone_reopen.state != \
			JSON.parse_string(JSON.stringify(settled_reopen.state)):
		return _fail("second-life pending chapter card failed strict restart")
	var milestone_before: Dictionary = milestone_reopen.state.duplicate(true)
	var milestone_bytes := FileAccess.get_file_as_string(store.v2_path)
	var milestone_token := milestone_reopen.issue_choice_token()
	milestone_reopen._store.fail_promotion_once = true
	if milestone_token <= 0 or milestone_reopen.choose("left", milestone_token) \
			or milestone_reopen.state != milestone_before \
			or FileAccess.get_file_as_string(store.v2_path) != milestone_bytes:
		return _fail("failed second-life chapter write changed the card or save")
	if not milestone_reopen.choose("left", milestone_token):
		return _fail("second-life chapter left choice could not commit")
	var new_fact: Dictionary = milestone_reopen.state.get("noncombatFlow", {}).get(
		"spineFacts", {}).get("fact:1:qi_main_call", {})
	var chapter_seeds: Array = milestone_reopen.state.get("karmaSeeds", [])
	if milestone_reopen.state.get("phase") != "FLOW_PENDING" \
			or new_fact.get("lifeCount") != 1 \
			or chapter_seeds.is_empty() \
			or chapter_seeds.back().get("originLife") != 1:
		return _fail("second-life chapter did not produce own-life fact and seed")
	var chapter_settled_reopen = Domain.new(Registry.new(), RunSession.new(path, "slot_3"), "slot_3")
	_stabilize_ambient(chapter_settled_reopen)
	if not chapter_settled_reopen.restore() or chapter_settled_reopen.state != \
			JSON.parse_string(JSON.stringify(milestone_reopen.state)):
		return _fail("second-life settled chapter choice failed strict restart")
	var reached_body_karma := false
	var body_karma_settled := false
	var reached_mentor := false
	var reached_early_vendor := false
	var reached_vendor_wheel := false
	for step in 16:
		if chapter_settled_reopen.state.get("phase") == "FLOW_PENDING" \
				and not chapter_settled_reopen.resume_flow():
			return _fail("second-life karma route stopped before maturity: " +
				JSON.stringify({"step": step,
					"phase": chapter_settled_reopen.state.get("phase"),
					"seeds": chapter_settled_reopen.state.get("karmaSeeds", []),
					"milestoneError": chapter_settled_reopen._milestone_flow.last_error,
					"karmaError": chapter_settled_reopen._karma_flow.last_error,
					"normalError": chapter_settled_reopen._normal_flow_error}))
		var next_card: Dictionary = chapter_settled_reopen.get_current_card()
		print("DEATH_REBIRTH_PROGRESS step=%d phase=%s card=%s" % [step,
			chapter_settled_reopen.state.get("phase"), next_card.get("id")])
		if chapter_settled_reopen.state.get("phase") == "DESTINY_WHEEL_PENDING":
			var wheel_before: Dictionary = chapter_settled_reopen.state.duplicate(true)
			var wheel_index := int(wheel_before.get("runClock", {}).get("decisionIndex", -1))
			var wheel_reopen = Domain.new(Registry.new(), RunSession.new(path, "slot_3"), "slot_3")
			_stabilize_ambient(wheel_reopen)
			if next_card.get("id") != "destiny_wheel" \
					or wheel_before.get("wheelReturn", {}).get("phase") != "FLOW_PENDING" \
					or not wheel_reopen.restore() \
					or wheel_reopen.state != JSON.parse_string(JSON.stringify(wheel_before)) \
					or not wheel_reopen.choose("left", wheel_reopen.issue_choice_token()) \
					or wheel_reopen.state.get("phase") != "FLOW_PENDING" \
					or int(wheel_reopen.state.get("runClock", {}).get("decisionIndex", -2)) != wheel_index:
				return _fail("second-life main-route wheel did not strictly reopen and flip")
			var wheel_done = Domain.new(Registry.new(), RunSession.new(path, "slot_3"), "slot_3")
			_stabilize_ambient(wheel_done)
			if not wheel_done.restore() or wheel_done.state != \
					JSON.parse_string(JSON.stringify(wheel_reopen.state)):
				return _fail("second-life main-route wheel flip failed strict restart")
			chapter_settled_reopen = wheel_done
			continue
		if chapter_settled_reopen.state.get("phase") == "COMBAT_HANDOFF" \
				and chapter_settled_reopen.state.get("pendingCadenceCard") is Dictionary:
			var due_avoided = Domain.new(Registry.new(), RunSession.new(path, "slot_3"), "slot_3")
			_stabilize_ambient(due_avoided)
			var due_index := int(chapter_settled_reopen.state.get("runClock", {}).get(
				"decisionIndex", -1))
			var due_history_size: int = chapter_settled_reopen.state.choiceHistory.size()
			if next_card.get("id") != chapter_settled_reopen.state[
					"pendingCadenceCard"].get("id") \
					or not due_avoided.restore() \
					or due_avoided.state != JSON.parse_string(JSON.stringify(
						chapter_settled_reopen.state)) \
					or not _avoid_due_second_life_catalog(due_avoided):
				return _fail("second-life due catalog did not strictly reopen and avoid")
			var new_choices: Array = due_avoided.state.choiceHistory.slice(due_history_size)
			if new_choices.size() not in [1, 2] \
					or new_choices[0].get("cardId") != next_card.get("id") \
					or new_choices[0].get("direction") != "right" \
					or new_choices.size() == 2 and (
						new_choices[1].get("cardType") != "NARRATIVE_RESULT" \
						or new_choices[1].get("direction") != "left"):
				return _fail("second-life due catalog choice history differs")
			var expected_index := due_index + new_choices.size()
			if int(due_avoided.state.get("runClock", {}).get(
					"decisionIndex", -1)) != expected_index:
				return _fail("second-life due catalog decision clock differs")
			chapter_settled_reopen = due_avoided
			continue
		if chapter_settled_reopen.state.get("phase") == "MENTOR_PENDING":
			if next_card.get("id") != "mentor_bai_ren_stage_INNER_DISCIPLE" \
					and next_card.get("id") != "mentor_bai_ren_stage_TRUSTED":
				return _fail("second-life priority produced an unsupported mentor stage")
			var mentor_pending = Domain.new(Registry.new(), RunSession.new(path, "slot_3"), "slot_3")
			_stabilize_ambient(mentor_pending)
			if not mentor_pending.restore() or mentor_pending.state != \
					JSON.parse_string(JSON.stringify(chapter_settled_reopen.state)):
				return _fail("pending second-life mentor card failed strict restart")
			var mentor_before: Dictionary = mentor_pending.state.duplicate(true)
			var mentor_bytes := FileAccess.get_file_as_string(store.v2_path)
			var mentor_token := mentor_pending.issue_choice_token()
			var mentor_direction := "left" if mentor_pending.can_choose_direction("left") \
				else "right"
			mentor_pending._store.fail_promotion_once = true
			if mentor_pending.choose(mentor_direction, mentor_token) \
					or mentor_pending.state != mentor_before \
					or FileAccess.get_file_as_string(store.v2_path) != mentor_bytes \
					or not mentor_pending.choose(mentor_direction, mentor_token) \
					or mentor_pending.state.get("phase") != "NARRATIVE_RESULT_PENDING" \
					or mentor_pending.state.get("noncombatFlow", {}).get(
						"mentorPromise", {}).get("status") != "pending":
				return _fail("second-life mentor decision rollback or source promise failed")
			var mentor_result = Domain.new(Registry.new(), RunSession.new(path, "slot_3"), "slot_3")
			_stabilize_ambient(mentor_result)
			if not mentor_result.restore() or mentor_result.state != \
					JSON.parse_string(JSON.stringify(mentor_pending.state)) \
					or not mentor_result.choose("left", mentor_result.issue_choice_token()) \
					or mentor_result.state.get("noncombatFlow", {}).get(
						"mentorPromise", {}).get("status") != "resolved":
				return _fail("second-life mentor response failed strict restart or acknowledgement")
			var mentor_done = Domain.new(Registry.new(), RunSession.new(path, "slot_3"), "slot_3")
			_stabilize_ambient(mentor_done)
			if not mentor_done.restore() or mentor_done.state != \
					JSON.parse_string(JSON.stringify(mentor_result.state)):
				return _fail("resolved second-life mentor promise failed strict restart")
			reached_mentor = true
			chapter_settled_reopen = mentor_done
			continue
		if next_card.get("id") == "kx_ch_hoarded_manual":
			if not body_karma_settled or chapter_settled_reopen.state.get("phase") != "KARMA_PENDING":
				return _fail("manual karma arrived before its body karma predecessor")
			var manual_reopen = Domain.new(Registry.new(), RunSession.new(path, "slot_3"), "slot_3")
			_stabilize_ambient(manual_reopen)
			if not manual_reopen.restore() or manual_reopen.state != \
					JSON.parse_string(JSON.stringify(chapter_settled_reopen.state)):
				return _fail("pending second-life manual karma failed strict restart")
			if not manual_reopen.choose("right", manual_reopen.issue_choice_token()) \
					or manual_reopen.state.get("flags", {}).get(
						"karma_result_manual_claimed") != true:
				return _fail("source manual karma choice or authored flag failed")
			var manual_settled_reopen = Domain.new(Registry.new(),
				RunSession.new(path, "slot_3"), "slot_3")
			_stabilize_ambient(manual_settled_reopen)
			if not manual_settled_reopen.restore() or manual_settled_reopen.state != \
					JSON.parse_string(JSON.stringify(manual_reopen.state)):
				return _fail("settled second-life manual karma failed strict restart")
			reached_body_karma = true
			break
		if next_card.get("id") == "k_chapter_body_left":
			if chapter_settled_reopen.state.get("phase") != "KARMA_PENDING":
				return _fail("mature second-life body karma had wrong phase")
			var pending_karma = Domain.new(Registry.new(), RunSession.new(path, "slot_3"), "slot_3")
			_stabilize_ambient(pending_karma)
			if not pending_karma.restore() or pending_karma.state != \
					JSON.parse_string(JSON.stringify(chapter_settled_reopen.state)):
				return _fail("pending second-life body karma failed strict restart")
			var karma_bytes := FileAccess.get_file_as_string(store.v2_path)
			var karma_before: Dictionary = pending_karma.state.duplicate(true)
			var karma_token := pending_karma.issue_choice_token()
			pending_karma._store.fail_promotion_once = true
			if pending_karma.choose("left", karma_token) \
					or pending_karma.state != karma_before \
					or FileAccess.get_file_as_string(store.v2_path) != karma_bytes:
				return _fail("failed second-life karma write mutated save")
			if not pending_karma.choose("left", karma_token) \
					or pending_karma.state.get("karmaSeeds", []).any(
						func(seed: Variant) -> bool: return seed is Dictionary \
							and seed.get("id") == "causal:qi_body_stance"):
				return _fail("second-life karma choice did not settle once")
			var settled_karma = Domain.new(Registry.new(), RunSession.new(path, "slot_3"), "slot_3")
			_stabilize_ambient(settled_karma)
			if not settled_karma.restore() or settled_karma.state != \
					JSON.parse_string(JSON.stringify(pending_karma.state)):
				return _fail("settled second-life karma failed strict restart")
			if not settled_karma.resume_flow():
				return _fail("second-life manual karma continuation could not resume")
			if settled_karma.state.get("phase") == "MARKET_PENDING":
				var market_after_karma = Domain.new(Registry.new(),
					RunSession.new(path, "slot_3"), "slot_3")
				_stabilize_ambient(market_after_karma)
				if not market_after_karma.restore() or market_after_karma.state != \
						JSON.parse_string(JSON.stringify(settled_karma.state)) \
						or not market_after_karma.choose("right",
							market_after_karma.issue_choice_token()):
					return _fail("second-life bazaar interruption after karma failed")
				settled_karma = market_after_karma
				if not settled_karma.resume_flow():
					return _fail("second-life manual karma did not resume after bazaar")
			if settled_karma.state.get("phase") == "NORMAL_PENDING":
				var manual_advance := "left" if settled_karma.can_choose_direction("left") \
					else "right"
				if not settled_karma.choose(manual_advance,
						settled_karma.issue_choice_token()):
					return _fail("second-life ordinary continuation before manual karma failed")
				if settled_karma.state.get("phase") == "DESTINY_WHEEL_PENDING":
					var wheel_before: Dictionary = settled_karma.state.duplicate(true)
					var wheel_reopen = Domain.new(Registry.new(), RunSession.new(path, "slot_3"), "slot_3")
					_stabilize_ambient(wheel_reopen)
					if not wheel_reopen.restore() or wheel_reopen.state != \
							JSON.parse_string(JSON.stringify(wheel_before)) \
							or not wheel_reopen.choose("left", wheel_reopen.issue_choice_token()) \
							or wheel_reopen.state.get("phase") != "FLOW_PENDING" \
							or int(wheel_reopen.state.get("runClock", {}).get(
								"decisionIndex", -1)) != int(wheel_before.get(
								"runClock", {}).get("decisionIndex", -2)):
						return _fail("second-life due wheel could not strictly reopen and flip")
					settled_karma = wheel_reopen
				if settled_karma.state.get("phase") != "FLOW_PENDING" \
						or not settled_karma.resume_flow():
					return _fail("second-life ordinary continuation before manual karma failed")
			body_karma_settled = true
			chapter_settled_reopen = settled_karma
			continue
		if chapter_settled_reopen.state.get("phase") not in [
				"NORMAL_PENDING", "MILESTONE_PENDING", "MARKET_PENDING"]:
			return _fail("unexpected second-life priority before karma: " +
				JSON.stringify({"phase": chapter_settled_reopen.state.get("phase"),
					"card": next_card.get("id")}))
		if chapter_settled_reopen.state.get("phase") == "MARKET_PENDING":
			var market_branch_store = RunSession.new(
				slot_root + "/market_branch_slot_3_v1.json", "slot_3")
			var market_bytes := FileAccess.get_file_as_string(store.v2_path)
			var branch_file := FileAccess.open(market_branch_store.v2_path, FileAccess.WRITE)
			if branch_file == null:
				return _fail("second-life market branch save could not be staged")
			branch_file.store_string(market_bytes)
			branch_file.close()
			var market_reopen = Domain.new(Registry.new(), market_branch_store, "slot_3")
			_stabilize_ambient(market_reopen)
			if not market_reopen.restore() or market_reopen.state != \
					JSON.parse_string(JSON.stringify(chapter_settled_reopen.state)) \
					or not market_reopen.can_choose_direction("left") \
					or not market_reopen.choose("left", market_reopen.issue_choice_token()) \
					or FileAccess.get_file_as_string(store.v2_path) != market_bytes:
				return _fail("second-life market pending or entry failed strict branch")
			var market_open = Domain.new(Registry.new(), RunSession.new(
				slot_root + "/market_branch_slot_3_v1.json", "slot_3"), "slot_3")
			_stabilize_ambient(market_open)
			if not market_open.restore() or market_open.state.get("phase") != "VENDOR_OPEN" \
					or not market_open.perform_vendor_action("ask_luo",
						market_open.issue_choice_token()):
				return _fail("second-life open stall or source Luo inquiry failed restart")
			var market_action = Domain.new(Registry.new(), RunSession.new(
				slot_root + "/market_branch_slot_3_v1.json", "slot_3"), "slot_3")
			_stabilize_ambient(market_action)
			if not market_action.restore() or market_action.state != \
					JSON.parse_string(JSON.stringify(market_open.state)):
				return _fail("second-life stall action failed strict restart")
			var purchase_bytes := FileAccess.get_file_as_string(
				market_branch_store.v2_path)
			var purchase_before: Dictionary = market_action.state.duplicate(true)
			var purchase_token := market_action.issue_choice_token()
			market_action._store.fail_promotion_once = true
			if market_action.purchase_vendor_offer("bazaar_han_healing", purchase_token) \
					or market_action.state != purchase_before \
					or FileAccess.get_file_as_string(market_branch_store.v2_path) != purchase_bytes \
					or not market_action.purchase_vendor_offer("bazaar_han_healing",
						purchase_token):
				return _fail("second-life stall purchase rollback or retry failed")
			var market_purchase = Domain.new(Registry.new(), RunSession.new(
				slot_root + "/market_branch_slot_3_v1.json", "slot_3"), "slot_3")
			_stabilize_ambient(market_purchase)
			if not market_purchase.restore() or market_purchase.state != \
					JSON.parse_string(JSON.stringify(market_action.state)) \
					or not market_purchase.close_vendor(market_purchase.issue_choice_token()):
				return _fail("second-life purchased stall failed strict restart or close")
			var market_result = Domain.new(Registry.new(), RunSession.new(
				slot_root + "/market_branch_slot_3_v1.json", "slot_3"), "slot_3")
			_stabilize_ambient(market_result)
			if not market_result.restore() or market_result.state != \
					JSON.parse_string(JSON.stringify(market_purchase.state)):
				return _fail("second-life stall result failed strict restart")
			var market_tick := int(market_result.state.get("destinyWheelTicks", -1))
			if not reached_early_vendor and market_tick != 9:
				return _fail("second-life first vendor branch shifted from source tick 9")
			var wheel_due: bool = market_tick % 15 == 0
			if wheel_due:
				if market_tick != 15:
					return _fail("second-life vendor wheel shifted from source tick 15")
				if market_result.state.get("phase") != "DESTINY_WHEEL_PENDING" \
						or market_result.state.get("wheelReturn", {}).get("phase") != \
							"VENDOR_RESULT_PENDING":
					return _fail("second-life due wheel did not interrupt vendor result")
				var wheel_index := int(market_result.state.runClock.decisionIndex)
				if not market_result.choose("left", market_result.issue_choice_token()) \
						or int(market_result.state.runClock.decisionIndex) != wheel_index:
					return _fail("second-life stall wheel did not return to vendor result")
				var market_wheel_done = Domain.new(Registry.new(), RunSession.new(
					slot_root + "/market_branch_slot_3_v1.json", "slot_3"), "slot_3")
				_stabilize_ambient(market_wheel_done)
				if not market_wheel_done.restore() or market_wheel_done.state != \
						JSON.parse_string(JSON.stringify(market_result.state)):
					return _fail("second-life vendor wheel flip failed strict restart")
				market_result = market_wheel_done
				reached_vendor_wheel = true
			elif market_result.state.get("phase") != "VENDOR_RESULT_PENDING":
				return _fail("second-life early vendor result unexpectedly interrupted")
			elif market_tick == 9:
				reached_early_vendor = true
			if market_result.state.get("phase") != "VENDOR_RESULT_PENDING" \
					or not market_result.choose("right", market_result.issue_choice_token()):
				return _fail("second-life stall result failed strict restart or dismissal")
			var market_done = Domain.new(Registry.new(), RunSession.new(
				slot_root + "/market_branch_slot_3_v1.json", "slot_3"), "slot_3")
			_stabilize_ambient(market_done)
			if not market_done.restore() or market_done.state != \
					JSON.parse_string(JSON.stringify(market_result.state)) \
					or FileAccess.get_file_as_string(store.v2_path) != market_bytes:
				return _fail("second-life completed stall failed strict restart or touched main route")
		var advance_direction := "right" if chapter_settled_reopen.state.get(
			"phase") == "MARKET_PENDING" else (
			"left" if chapter_settled_reopen.can_choose_direction("left") else "right")
		if not chapter_settled_reopen.choose(advance_direction,
				chapter_settled_reopen.issue_choice_token()):
			return _fail("second-life ordinary or chapter choice could not advance karma clock")
	if not reached_body_karma:
		return _fail("body karma did not mature within sixteen second-life decisions")
	if not reached_mentor:
		return _fail("source mentor progression did not surface in second-life route")
	if not reached_early_vendor or not reached_vendor_wheel:
		return _fail("second-life vendor did not cover source ticks 9 and 15")
	if before == game.state or before_bytes == FileAccess.get_file_as_string(store.v2_path):
		return _fail("fatal decision did not persist")
	print("NONCOMBAT_DEATH_REBIRTH_JOURNEY_PASS death=true art=true legacy=true path=true ui=true rollback=true forged=true replay=true chapter=true karma=true manual=true vendor=true quest=true quest_paid=true mentor=true")
	quit(0)


func _avoid_due_second_life_catalog(game: RefCounted) -> bool:
	var card: Dictionary = game.get_current_card()
	if not (game.state.get("phase") == "COMBAT_HANDOFF" \
		and game.state.get("pendingCadenceCard") is Dictionary \
		and card.get("id") == game.state["pendingCadenceCard"].get("id") \
		and game.state.get("encounterCadence", {}).get("activationIndex") == 1 \
		and game.choose("right", game.issue_choice_token())):
		return false
	if game.state.get("phase") == "NARRATIVE_RESULT_PENDING":
		var result: Dictionary = game.get_current_card()
		if result.get("originCardId") != card.get("id") \
				or result.get("originChoice") != "right" \
				or not game.choose("left", game.issue_choice_token()):
			return false
	return game.state.get("phase") == "FLOW_PENDING"


func _fail(message: String) -> void:
	push_error(message)
	quit(1)


func _stabilize_ambient(game: RefCounted) -> void:
	# The saved exploratory route was played with the same deterministic
	# ambience controls as noncombat_pill_ghost_q_shop_journey.gd.
	game._normal_roll_override = 0.55
	game._market_flow.roll_override = 0.0
	game._destiny_wheel_flow.roll_override = 0.0
	game._ripple_flow.roll_override = 0.999
	game._hint_flow.roll_override = 0.0
