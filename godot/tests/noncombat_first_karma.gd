extends SceneTree

const Registry = preload("res://scripts/runtime_data_registry.gd")
const Domain = preload("res://scripts/noncombat_domain.gd")
const RunSession = preload("res://scripts/noncombat_run_session.gd")

class KarmaDriftContent extends "res://scripts/noncombat_content_repository.gd":
	func source_sha256(module_id: String) -> String:
		return "f".repeat(64) if module_id == "cards:karma_expansion" else super.source_sha256(module_id)

class MissingGatewayContent extends "res://scripts/noncombat_content_repository.gd":
	func module_path(module_id: String) -> String:
		return "" if module_id == "combat:encounter_director" else super.module_path(module_id)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var path := "user://tests/first_karma_%d.json" % Time.get_ticks_usec()
	var game = Domain.new(Registry.new(), RunSession.new(path, "slot_3"), "slot_3")
	if not game.start("sword"):
		return _fail("start")
	for i in 5:
		if not game.choose("left", game.issue_choice_token()):
			return _fail("tutorial")
	if not game.choose("right", game.issue_choice_token()) \
			or not game.choose("left", game.issue_choice_token()) \
			or not game.resume_flow() \
			or not game.choose("left", game.issue_choice_token()) \
			or not game.choose("right", game.issue_choice_token()) \
			or not game.resume_flow() \
			or not game.choose("right", game.issue_choice_token()) \
			or not game.choose("left", game.issue_choice_token()) \
			or not game.choose("down", game.issue_choice_token()) \
			or not game.resume_flow() \
			or game.get_current_card().get("id") != "ch_qi_60" \
			or not game.choose("left", game.issue_choice_token()):
		return _fail("source route to first karma")
	if not _check_pre_karma_mentor_save(game):
		return _fail("pre-karma mentor save did not restore unchanged")
	var view: Control = load("res://scenes/noncombat_opening.tscn").instantiate()
	view.save_path = ""
	root.add_child(view)
	await process_frame
	view.opening = game
	game.changed.connect(view._on_opening_changed)
	if not game.resume_flow():
		return _fail("first karma scheduling")
	if game.get_current_card().get("id") != "kx_path_sword_legacy":
		return _fail("due karma was bypassed by mentor")
	if game.state.get("noncombatFlow", {}).get("karmaArbitrationVersion") != 1:
		return _fail("new karma ordering was not versioned")
	await process_frame
	if view.opening_audio.bgm_player.stream == null \
			or not view.opening_audio.bgm_player.stream.resource_path.ends_with(
				"bgm/04_mystery_causality/bgm_04_mystery_causality.wav") \
			or view.opening_audio.sfx_player.stream == null \
			or not view.opening_audio.sfx_player.stream.resource_path.ends_with(
				"sfx/world/karma_trigger.mp3"):
		return _fail("due karma desktop presentation missed source music or cue")
	var left_button: Button = view.choice_row.get_node_or_null("Choice_left")
	var right_button: Button = view.choice_row.get_node_or_null("Choice_right")
	if view.art_rect.texture == null or left_button == null or right_button == null \
			or left_button.disabled or right_button.disabled:
		return _fail("karma desktop art or deck admission")
	root.remove_child(view)
	view.queue_free()
	if not _check_karma_left(game):
		return _fail("karma left did not acquire source deck card")
	var before: Dictionary = game.state.duplicate(true)
	if game.issue_choice_token() <= 0:
		return _fail("karma choice token unavailable")
	var presented = Domain.new(Registry.new(), RunSession.new(path, "slot_3"), "slot_3")
	if not presented.restore() or presented.get_current_card().get("id") != "kx_path_sword_legacy":
		return _fail("karma presentation did not reload")
	var drift_store = RunSession.new(path, "slot_3")
	var drift = Domain.new(Registry.new(), drift_store, "slot_3", KarmaDriftContent.new())
	if drift.restore() or drift_store.last_error != "SOURCE_MISMATCH":
		return _fail("karma source drift accepted")
	var missing_store = RunSession.new(path, "slot_3")
	var missing = Domain.new(Registry.new(), missing_store, "slot_3", MissingGatewayContent.new())
	if missing.restore() or missing_store.last_error != "SOURCE_UNAVAILABLE":
		return _fail("missing gateway source was misclassified")
	var token: int = game.issue_choice_token()
	game._store.fail_promotion_once = true
	if game.choose("right", token) or game.state != before:
		return _fail("failed karma write leaked state")
	if not game.choose("right", token) or game.choose("right", token):
		return _fail("karma right choice did not settle once")
	if int(game.state["attributes"]["fortune"]) != 71 \
			or not game.state["flags"].get("karma_result_sword_legacy_tempered", false) \
			or game.state["karmaSeeds"].any(func(seed: Variant) -> bool:
				return seed is Dictionary and seed.get("id") == "causal:sword_legacy_start") \
			or int(game.state["resources"]["lifespan"]) != 78 \
			or game.state.get("phase") != "FLOW_PENDING":
		return _fail("karma settlement differs from browser")
	var settled = Domain.new(Registry.new(), RunSession.new(path, "slot_3"), "slot_3")
	if not settled.restore() or not settled.resume_flow() \
			or settled.get_current_card().get("id") != "mentor_bai_ren_stage_INNER_DISCIPLE":
		return _fail("settled karma did not reload then continue to mentor")
	print("NONCOMBAT_FIRST_KARMA_PASS priority=true right=true replay=true")
	quit(0)

func _check_karma_left(game: RefCounted) -> bool:
	var path := "user://tests/first_karma_left_%d.json" % Time.get_ticks_usec()
	var store = RunSession.new(path, "slot_3")
	var bytes := FileAccess.get_file_as_string(game._store.v2_path)
	var file := FileAccess.open(store.v2_path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(bytes)
	file.close()
	var left = Domain.new(Registry.new(), store, "slot_3")
	if not left.restore():
		return false
	var pending: Dictionary = left.state.duplicate(true)
	var token: int = left.issue_choice_token()
	left._store.fail_promotion_once = true
	if left.choose("left", token) or JSON.parse_string(JSON.stringify(left.state)) != \
			JSON.parse_string(JSON.stringify(pending)) \
			or FileAccess.get_file_as_string(store.v2_path) != bytes:
		return false
	if not left.choose("left", token):
		return false
	var deck: Array = left.state.get("deck", [])
	var progression: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(
		"res://content/data/combat/deck_progression.json"))
	var starter: Array = progression.get("paths", {}).get("sword", {}).get("starterDeck", [])
	var acquisition: Dictionary = left.state.get("skillAcquisitions", {}).get("sword_intent", {})
	if deck != starter + ["sword_intent"] \
			or left.state.get("starterDeckPath") != "sword" \
			or acquisition.get("cardName") != "凝剑诀" \
			or acquisition.get("sourceId") != "kx_path_sword_legacy" \
			or acquisition.get("sourceType") != "legacy_deck_effect" \
			or acquisition.get("mode") != "legacy" \
			or int(left.state.get("attributes", {}).get("health", -1)) != 2 \
			or int(left.state.get("attributes", {}).get("cultivation", -1)) != 67 \
			or int(left.state.get("resources", {}).get("lifespan", -1)) != 77 \
			or not left.state.get("flags", {}).get("karma_result_sword_legacy_claimed", false):
		return false
	var reopened = Domain.new(Registry.new(), RunSession.new(path, "slot_3"), "slot_3")
	if not reopened.restore() or reopened.state.get("deck", []) != deck \
			or not _check_pre_starter_deck_karma_save(store):
		return false
	return not reopened.choose("left", reopened.issue_choice_token()) \
		and reopened.resume_flow() \
		and reopened.get_current_card().get("id") == "mentor_bai_ren_stage_INNER_DISCIPLE"

func _check_pre_starter_deck_karma_save(current_store: RefCounted) -> bool:
	var envelope: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(current_store.v2_path))
	for key in ["deckStateVersion", "deckProgressionSourceSha", "battleCardSourceSha"]:
		envelope["state"].erase(key)
	var path := "user://tests/first_karma_left_pre_n8c_%d.json" % Time.get_ticks_usec()
	var store = RunSession.new(path, "slot_3")
	var bytes := JSON.stringify(envelope)
	var file := FileAccess.open(store.v2_path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(bytes)
	file.close()
	var restored = Domain.new(Registry.new(), store, "slot_3")
	return restored.restore() and restored.state.get("deck", []) == \
		envelope["state"].get("deck", []) \
		and FileAccess.get_file_as_string(store.v2_path) == bytes

func _check_pre_karma_mentor_save(game: RefCounted) -> bool:
	# Recreate the pre-N8a karma order after the current NPC collection lane.
	var faction_collected: Dictionary = game._faction_events.collect(game.state)
	if faction_collected.is_empty() or not game._faction_events.last_error.is_empty():
		return false
	var collected: Dictionary = game._npc_encounter_flow.collect(faction_collected)
	if collected.is_empty() or not game._npc_encounter_flow.last_error.is_empty():
		return false
	var legacy: Dictionary = game._mentor_flow.resume(collected)
	if legacy.get("phase") != "MENTOR_PENDING" \
			or legacy.get("noncombatFlow", {}).has("karmaArbitrationVersion"):
		print("legacy candidate phase=", legacy.get("phase"), " reason=", game._mentor_flow.last_error)
		return false
	var path := "user://tests/first_karma_pre_n8a_%d.json" % Time.get_ticks_usec()
	var store = RunSession.new(path, "slot_3")
	var envelope: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(game._store.v2_path))
	envelope["state"] = legacy
	var bytes := JSON.stringify(envelope)
	var file := FileAccess.open(store.v2_path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(bytes)
	file.close()
	var restored = Domain.new(Registry.new(), store, "slot_3")
	if not restored.restore() or FileAccess.get_file_as_string(store.v2_path) != bytes \
			or restored.get_current_card().get("id") != "mentor_bai_ren_stage_INNER_DISCIPLE":
		print("legacy restore error=", store.last_error, " phase=", restored.state.get("phase"), " card=", restored.get_current_card().get("id"))
		return false
	if not restored.choose("left", restored.issue_choice_token()):
		print("legacy choice failed")
		return false
	var chosen: Dictionary = restored.state.duplicate(true)
	var chosen_bytes := FileAccess.get_file_as_string(store.v2_path)
	var reloaded = Domain.new(Registry.new(), RunSession.new(path, "slot_3"), "slot_3")
	var replayed := reloaded.restore()
	if not replayed:
		print("legacy chosen restore error=", reloaded._store.last_error)
	var same_state: bool = JSON.parse_string(JSON.stringify(reloaded.state)) == \
		JSON.parse_string(JSON.stringify(chosen))
	var same_bytes := FileAccess.get_file_as_string(store.v2_path) == chosen_bytes
	if not same_state or not same_bytes:
		print("legacy replay parity state=", same_state, " bytes=", same_bytes)
	return replayed and same_state and same_bytes

func _fail(reason: String) -> void:
	push_error(reason)
	quit(1)
