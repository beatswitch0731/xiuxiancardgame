extends SceneTree

const Staging = preload("res://scripts/noncombat_browser_save_staging.gd")
const SOURCE_DIR := "../artifacts/godot-migration/m0-2026-10-15/"


func _initialize() -> void:
	var root := "user://browser_staging_test_%d_%d_%d" % [
		int(Time.get_unix_time_from_system()), OS.get_process_id(), Time.get_ticks_usec()]
	var absolute := ProjectSettings.globalize_path(root)
	var sentinel := absolute.path_join("noncombat_opening_v2.json")
	if DirAccess.make_dir_recursive_absolute(absolute) != OK:
		return _fail("could not create isolated import test directory")
	var sentinel_file := FileAccess.open(sentinel, FileAccess.WRITE)
	sentinel_file.store_string("native slot unchanged")
	sentinel_file.close()
	var stager = Staging.new(root)
	var raw := FileAccess.get_file_as_string(_source_path("slots-synthetic-raw.json"))
	var first: Dictionary = stager.stage_text(raw)
	var staged := absolute.path_join(Staging.STAGING_FILE)
	if first.get("ok") != true or first.get("backup") != "" \
			or FileAccess.get_file_as_string(staged) != raw \
			or stager.inspect_staged().get("slots", []).size() != 3:
		return _fail("first browser export did not stage all three raw slots")
	var invalid: Dictionary = JSON.parse_string(raw)
	var slot: Dictionary = JSON.parse_string(invalid["xiuxian_unlocks_slot_3"])
	slot["saveVersion"] = 99
	invalid["xiuxian_unlocks_slot_3"] = JSON.stringify(slot)
	if stager.stage_text(JSON.stringify(invalid)).get("ok") != false \
			or FileAccess.get_file_as_string(staged) != raw:
		return _fail("invalid browser export replaced valid staged bytes")
	var storage_state := FileAccess.get_file_as_string(_source_path(
		"slots-browser-state.json"))
	stager.fail_promotion_once = true
	var failed: Dictionary = stager.stage_text(storage_state)
	if failed.get("error") != "PROMOTION_FAILED" \
			or FileAccess.get_file_as_string(staged) != raw \
			or FileAccess.get_file_as_string(String(failed.get("backup", ""))) != raw:
		return _fail("failed promotion lost the prior export or its backup")
	var second: Dictionary = stager.stage_text(storage_state)
	if second.get("ok") != true or second.get("sourceSha256") != \
			storage_state.sha256_text() \
			or second.get("backup") == failed.get("backup") \
			or FileAccess.get_file_as_string(String(failed.get("backup", ""))) != raw \
			or FileAccess.get_file_as_string(String(second.get("backup", ""))) != raw \
			or FileAccess.get_file_as_string(staged) != storage_state \
			or stager.inspect_staged().get("activeSlot") != "slot_3" \
			or FileAccess.get_file_as_string(sentinel) != "native slot unchanged":
		return _fail("new staged export changed the active game slot or lost old bytes")
	print("NONCOMBAT_BROWSER_SAVE_STAGING_PASS slots=3 backup=true rollback=true native_unchanged=true")
	quit(0)


func _source_path(filename: String) -> String:
	return ProjectSettings.globalize_path("res://").path_join(
		SOURCE_DIR + filename).simplify_path()


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
