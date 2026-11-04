extends SceneTree

const Registry = preload("res://scripts/runtime_data_registry.gd")
const Domain = preload("res://scripts/noncombat_domain.gd")
const LegacyStore = preload("res://scripts/noncombat_opening_store.gd")


func _initialize() -> void:
	var session_script = load("res://scripts/noncombat_run_session.gd")
	if session_script == null:
		_fail("single-writer Godot run session is absent")
		return
	var root_path := "user://tests/run_session_%d" % Time.get_ticks_usec()
	var legacy_path := root_path + "_slot_1_v1.json"
	var session = session_script.new(legacy_path, "slot_1")
	var first = Domain.new(Registry.new(), session, "slot_1")
	if not first.start("sword") or session.load_snapshot().get("revision") != 0 \
			or FileAccess.file_exists(legacy_path):
		_fail("a new run did not start in the independent version-two file")
		return
	var second = Domain.new(Registry.new(), session_script.new(legacy_path, "slot_1"), "slot_1")
	if not second.restore():
		_fail("second view could not restore the first committed snapshot")
		return
	var opening_envelope: Dictionary = JSON.parse_string(
		FileAccess.get_file_as_string(session.v2_path))
	for variant in ["legacy_without_admission", "future_admission"]:
		var variant_store = session_script.new(root_path + "_" + variant +
			"_v1.json", "slot_1")
		var envelope: Dictionary = opening_envelope.duplicate(true)
		if variant == "legacy_without_admission":
			envelope.state.erase("normalNarrativeAdmission")
		else:
			envelope.state.normalNarrativeAdmission.activationIndex = 2
		var source_bytes := JSON.stringify(envelope)
		var variant_file := FileAccess.open(variant_store.v2_path, FileAccess.WRITE)
		variant_file.store_string(source_bytes)
		variant_file.close()
		var variant_game = Domain.new(Registry.new(), variant_store, "slot_1")
		var restored: bool = variant_game.restore()
		if restored != (variant == "legacy_without_admission") \
				or FileAccess.get_file_as_string(variant_store.v2_path) != source_bytes:
			_fail("opening admission variant was not restored or rejected atomically: "
				+ variant)
			return
	var stale_state: Dictionary = second.state.duplicate(true)
	if not first.choose("right", first.issue_choice_token()):
		_fail("first view could not commit its source decision")
		return
	var committed_bytes := FileAccess.get_file_as_string(session.v2_path)
	var source_manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(
		"res://content/source_manifest.json"))
	var media_only_manifest: Dictionary = source_manifest.duplicate(true)
	media_only_manifest["art"][0]["sha256"] = "0".repeat(64)
	var fixture_manifest_path := root_path + "_manifest.json"
	var fixture_file := FileAccess.open(fixture_manifest_path, FileAccess.WRITE)
	fixture_file.store_string(JSON.stringify(media_only_manifest))
	fixture_file.close()
	var media_changed = session_script.new(legacy_path, "slot_1", fixture_manifest_path)
	if media_changed.load_snapshot().get("revision") != 1:
		_fail("an unrelated art manifest edit locked an unchanged opening run")
		return
	var rule_changed_manifest: Dictionary = source_manifest.duplicate(true)
	for item in rule_changed_manifest["data"]:
		if item["path"] == "data/cards/qi.json":
			item["sha256"] = "0".repeat(64)
			break
	fixture_file = FileAccess.open(fixture_manifest_path, FileAccess.WRITE)
	fixture_file.store_string(JSON.stringify(rule_changed_manifest))
	fixture_file.close()
	var rules_changed = session_script.new(legacy_path, "slot_1", fixture_manifest_path)
	if not rules_changed.load_snapshot().is_empty() \
			or rules_changed.last_error != "SOURCE_MISMATCH" \
			or FileAccess.get_file_as_string(session.v2_path) != committed_bytes:
		_fail("opening rule source drift did not lock and preserve the old run")
		return
	if second.choose("left", second.issue_choice_token()) \
			or not _same(second.state, stale_state) \
			or FileAccess.get_file_as_string(session.v2_path) != committed_bytes \
			or session.load_snapshot().get("revision") != 1:
		_fail("stale second view overwrote a newer decision or advanced its memory")
		return
	var reopened = Domain.new(Registry.new(), session_script.new(legacy_path, "slot_1"), "slot_1")
	if not reopened.restore() or reopened.state.get("currentCardId") != "tutorial_4":
		_fail("committed v2 decision did not survive restart")
		return
	var before_failed: Dictionary = reopened.state.duplicate(true)
	var failed_session = reopened._store
	failed_session.v2_path = "user://"
	if reopened.choose("left", reopened.issue_choice_token()) \
			or not _same(reopened.state, before_failed) \
			or FileAccess.get_file_as_string(session.v2_path) != committed_bytes:
		_fail("failed version-two disk write changed the state or old file")
		return
	var rename_session = session_script.new(legacy_path, "slot_1")
	var rename_game = Domain.new(Registry.new(), rename_session, "slot_1")
	if not rename_game.restore():
		_fail("could not restore before the rename failure injection")
		return
	rename_session.fail_promotion_once = true
	var before_rename_failure: Dictionary = rename_game.state.duplicate(true)
	if rename_game.choose("left", rename_game.issue_choice_token()) \
			or not _same(rename_game.state, before_rename_failure) \
			or FileAccess.get_file_as_string(session.v2_path) != committed_bytes \
			or not FileAccess.file_exists(session.v2_path + ".pending"):
		_fail("failed rename reported success or changed the stable run")
		return
	var rename_restarted = session_script.new(legacy_path, "slot_1")
	if rename_restarted.load_snapshot().get("revision") != 1 \
			or FileAccess.file_exists(session.v2_path + ".pending") \
			or FileAccess.get_file_as_string(session.v2_path) != committed_bytes \
			or not rename_game.choose("left", rename_game.issue_choice_token()) \
			or rename_restarted.load_snapshot().get("revision") != 2:
		_fail("failed rename was committed on restart or blocked a clean retry")
		return
	var interrupted: Dictionary = JSON.parse_string(committed_bytes)
	interrupted["revision"] = 3
	var pending_file := FileAccess.open(session.v2_path + ".pending", FileAccess.WRITE)
	pending_file.store_string(JSON.stringify(interrupted))
	pending_file.close()
	var recovered = session_script.new(legacy_path, "slot_1")
	if recovered.load_snapshot().get("revision") != 2 \
			or FileAccess.file_exists(session.v2_path + ".pending") \
			or FileAccess.get_file_as_string(session.v2_path) == JSON.stringify(interrupted):
		_fail("uncommitted pending snapshot was promoted after restart")
		return
	var truncated_bytes := "{incomplete"
	var truncated_pending := FileAccess.open(session.v2_path + ".pending", FileAccess.WRITE)
	truncated_pending.store_string(truncated_bytes)
	truncated_pending.close()
	var truncated_session = session_script.new(legacy_path, "slot_1")
	if truncated_session.load_snapshot().get("revision") != 2 \
			or not _archived_pending_has_bytes(session.v2_path, truncated_bytes):
		_fail("truncated pending locked or changed a valid stable save")
		return
	var damaged_stable_pending: Dictionary = recovered.load_snapshot()
	damaged_stable_pending["revision"] = 3
	var collision_pending := FileAccess.open(session.v2_path + ".pending", FileAccess.WRITE)
	collision_pending.store_string(JSON.stringify(damaged_stable_pending))
	collision_pending.close()
	var collision_stable := FileAccess.open(session.v2_path, FileAccess.WRITE)
	collision_stable.store_string("{damaged-stable")
	collision_stable.close()
	var collision_session = session_script.new(legacy_path, "slot_1")
	if not collision_session.load_snapshot().is_empty() \
			or collision_session.archive_unrestorable().is_empty() \
			or collision_session.has_state_file():
		_fail("damaged stable plus valid pending left a hidden save blocking a new run")
		return
	var after_collision = Domain.new(Registry.new(), collision_session, "slot_1")
	if not after_collision.start("sword"):
		_fail("new run could not start after both invalid active files were isolated")
		return
	var legacy_only_path := root_path + "_legacy_v1.json"
	var legacy_store = LegacyStore.new(legacy_only_path)
	var old_game = Domain.new(Registry.new(), legacy_store, "slot_1")
	if not old_game.start("spell"):
		_fail("could not seed an existing Godot v1 opening")
		return
	var old_bytes := FileAccess.get_file_as_string(legacy_only_path)
	var upgraded_session = session_script.new(legacy_only_path, "slot_1")
	var legacy_pending := FileAccess.open(upgraded_session.v2_path + ".pending", FileAccess.WRITE)
	legacy_pending.store_string(truncated_bytes)
	legacy_pending.close()
	if upgraded_session.load_snapshot().get("version") != 1 \
			or not _archived_pending_has_bytes(upgraded_session.v2_path, truncated_bytes):
		_fail("truncated pending locked a valid legacy save")
		return
	var upgraded = Domain.new(Registry.new(), upgraded_session, "slot_1")
	if not upgraded.restore() or not upgraded.choose("right", upgraded.issue_choice_token()) \
			or FileAccess.get_file_as_string(legacy_only_path) != old_bytes \
			or upgraded_session.load_snapshot().get("revision") != 1:
		_fail("existing Godot v1 save was overwritten or not safely upgraded")
		return
	var forged: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(upgraded_session.v2_path))
	forged["sourceFingerprint"] = "0".repeat(64)
	var changed_file := FileAccess.open(upgraded_session.v2_path, FileAccess.WRITE)
	changed_file.store_string(JSON.stringify(forged))
	changed_file.close()
	var mismatched = session_script.new(legacy_only_path, "slot_1")
	if not mismatched.load_snapshot().is_empty() \
			or mismatched.archive_unrestorable() != "" \
			or not FileAccess.file_exists(upgraded_session.v2_path) \
			or FileAccess.get_file_as_string(legacy_only_path) != old_bytes:
		_fail("source-mismatched v2 snapshot was silently replaced with an older v1 life")
		return
	forged["version"] = 99
	var future_bytes := JSON.stringify(forged)
	var future_file := FileAccess.open(upgraded_session.v2_path, FileAccess.WRITE)
	future_file.store_string(future_bytes)
	future_file.close()
	var future = session_script.new(legacy_only_path, "slot_1")
	if not future.load_snapshot().is_empty() or future.last_error != "FUTURE_VERSION" \
			or future.archive_unrestorable() != "" \
			or FileAccess.get_file_as_string(upgraded_session.v2_path) != future_bytes:
		_fail("future version was replaced, archived, or silently loaded as v1")
		return
	var damaged_v2_bytes := "{damaged"
	var damaged_v2_file := FileAccess.open(upgraded_session.v2_path, FileAccess.WRITE)
	damaged_v2_file.store_string(damaged_v2_bytes)
	damaged_v2_file.close()
	var damaged_with_legacy = session_script.new(legacy_only_path, "slot_1")
	if not damaged_with_legacy.load_snapshot().is_empty() \
			or damaged_with_legacy.archive_unrestorable() != "" \
			or FileAccess.get_file_as_string(upgraded_session.v2_path) != damaged_v2_bytes \
			or FileAccess.get_file_as_string(legacy_only_path) != old_bytes:
		_fail("damaged v2 with a legacy ancestor was archived into an implicit rollback")
		return
	var empty_path := root_path + "_empty_v1.json"
	var empty_session = session_script.new(empty_path, "slot_1")
	var empty_pending := FileAccess.open(empty_session.v2_path + ".pending", FileAccess.WRITE)
	empty_pending.store_string(truncated_bytes)
	empty_pending.close()
	if not empty_session.load_snapshot().is_empty() or not empty_session.last_error.is_empty() \
			or empty_session.has_state_file() \
			or not _archived_pending_has_bytes(empty_session.v2_path, truncated_bytes):
		_fail("truncated pending with no stable save blocked a fresh run or lost raw bytes")
		return
	print("NONCOMBAT_RUN_SESSION_PASS revision=2 stale_rejected=true legacy_preserved=true pending_quarantined=true source_locked=true")
	quit(0)


func _same(left: Dictionary, right: Dictionary) -> bool:
	return JSON.parse_string(JSON.stringify(left)) == JSON.parse_string(JSON.stringify(right))


func _archived_pending_has_bytes(stable_path: String, expected: String) -> bool:
	var directory := DirAccess.open(stable_path.get_base_dir())
	if directory == null:
		return false
	var prefix := stable_path.get_file() + ".pending.uncommitted."
	for filename in directory.get_files():
		if filename.begins_with(prefix) and FileAccess.get_file_as_string(
				stable_path.get_base_dir().path_join(filename)) == expected:
			return true
	return false


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
