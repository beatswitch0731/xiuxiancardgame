extends SceneTree

const Importer = preload("res://scripts/noncombat_browser_opening_import.gd")
const RunSession = preload("res://scripts/noncombat_run_session.gd")
const LegacyStore = preload("res://scripts/noncombat_opening_store.gd")
const Domain = preload("res://scripts/noncombat_domain.gd")
const Registry = preload("res://scripts/runtime_data_registry.gd")
const FIXTURE := "../artifacts/godot-migration/noncombat-browser-import/opening-source-saves.json"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(
		ProjectSettings.globalize_path("res://").path_join(FIXTURE).simplify_path()))
	if fixture.get("source") != "live browser":
		return _fail("source browser export missing")
	var early := JSON.stringify(fixture.snapshots[2].storage)
	var next := JSON.stringify(fixture.snapshots[3].storage)
	var root_path := "user://tests/browser_replace_%d_%d" % [
		OS.get_process_id(), Time.get_ticks_usec()]
	var session = RunSession.new(root_path + "/noncombat_opening_v1.json", "slot_1")
	var importer = Importer.new()
	if importer.import_to_empty_slot(early, "slot_1", session).get("ok") != true:
		return _fail("real browser tutorial did not seed occupied slot")
	var before := FileAccess.get_file_as_string(session.v2_path)
	session.fail_promotion_once = true
	var failed: Dictionary = importer.replace_slot(next, "slot_1", session, 0)
	if failed.get("error") != "WRITE_FAILED" or not FileAccess.file_exists(
			String(failed.get("backup", ""))) or FileAccess.get_file_as_string(
			String(failed.get("backup", ""))) != before \
			or FileAccess.get_file_as_string(session.v2_path) != before:
		return _fail("failed replacement changed native bytes or lost backup")
	session.fail_import_verify_once = true
	var rolled_back: Dictionary = importer.replace_slot(next, "slot_1", session, 0)
	if rolled_back.get("error") != "VERIFY_FAILED" \
			or FileAccess.get_file_as_string(session.v2_path) != before \
			or FileAccess.get_file_as_string(String(rolled_back.get("backup", ""))) != before:
		return _fail("post-write verification failure did not restore v2 original")
	var result: Dictionary = importer.replace_slot(next, "slot_1", session, 0)
	if result.get("ok") != true or FileAccess.get_file_as_string(
			String(result.get("backup", ""))) != before:
		return _fail("valid replacement did not preserve original native save")
	var cold = Domain.new(Registry.new(), session, "slot_1")
	var restored: bool = cold.restore()
	var current: Dictionary = cold.get_current_card() if restored else {}
	var saved: Dictionary = session.load_snapshot()
	if not restored or cold.state.get("currentCardId") != fixture.snapshots[3].visibleCardId \
			or saved.get("revision") != 1:
		return _fail("replacement did not cold restore the next browser decision: " +
			JSON.stringify({"restored": restored, "error": session.last_error,
				"card": current.get("id"), "stateCard": cold.state.get("currentCardId"),
				"phase": cold.state.get("phase"),
				"expected": fixture.snapshots[3].visibleCardId,
				"revision": saved.get("revision")}))
	var committed := FileAccess.get_file_as_string(session.v2_path)
	if importer.replace_slot(early, "slot_1", session, 0).get("error") != \
			"REVISION_MISMATCH" or FileAccess.get_file_as_string(session.v2_path) != \
			committed:
		return _fail("stale replacement revision changed a committed save")
	var old_session = RunSession.new(root_path + "/legacy/noncombat_opening_v1.json",
		"slot_1")
	var old_state: Dictionary = importer.prepare(early, "slot_1").get("state", {})
	if old_state.is_empty() or not LegacyStore.new(old_session.legacy_path).save_state(
			old_state):
		return _fail("could not seed an existing Godot v1 save")
	var old_bytes := FileAccess.get_file_as_string(old_session.legacy_path)
	old_session.fail_promotion_once = true
	var old_failed: Dictionary = importer.replace_slot(next, "slot_1", old_session, 0)
	if old_failed.get("error") != "WRITE_FAILED" \
			or FileAccess.get_file_as_string(old_session.legacy_path) != old_bytes \
			or FileAccess.file_exists(old_session.v2_path):
		return _fail("failed v1 replacement did not preserve original bytes")
	old_session.fail_import_verify_once = true
	var old_rolled_back: Dictionary = importer.replace_slot(next, "slot_1", old_session, 0)
	if old_rolled_back.get("error") != "VERIFY_FAILED" \
			or FileAccess.file_exists(old_session.v2_path) \
			or FileAccess.get_file_as_string(old_session.legacy_path) != old_bytes \
			or FileAccess.get_file_as_string(String(old_rolled_back.get(
			"backup", ""))) != old_bytes:
		return _fail("post-write verification failure did not restore v1 original")
	var old_result: Dictionary = importer.replace_slot(next, "slot_1", old_session, 0)
	var old_cold = Domain.new(Registry.new(), old_session, "slot_1")
	if old_result.get("ok") != true or FileAccess.get_file_as_string(
			String(old_result.get("backup", ""))) != old_bytes \
			or not old_cold.restore() or old_cold.state.get("currentCardId") != \
				fixture.snapshots[3].visibleCardId \
			or FileAccess.get_file_as_string(old_session.legacy_path) != old_bytes:
		return _fail("v1 replacement did not back up and preserve legacy original")
	print("NONCOMBAT_BROWSER_REPLACE_PASS backup=true atomic=true cold=true revision=true legacy=true")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
