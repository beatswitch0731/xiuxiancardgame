extends SceneTree

const Slots = preload("res://scripts/noncombat_save_slots.gd")
const FIXTURE := "res://tests/fixtures/artifacts/godot-migration/noncombat-browser-import/opening-source-saves.json"
const BATTLE_FIXTURE := "res://tests/fixtures/artifacts/godot-migration/m0-2026-10-15/slots-synthetic-raw.json"
const MID_FIXTURE := "res://tests/fixtures/artifacts/godot-migration/noncombat-browser-import/mid-source-save-sword-long.json"
const EXTENDED_FIXTURE := "res://tests/fixtures/artifacts/godot-migration/noncombat-browser-import/mid-source-save-sword-extended.json"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var root_path := "user://tests/browser_import_ui_%d_%d" % [
		OS.get_process_id(), Time.get_ticks_usec()]
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(
		_source_path(FIXTURE)))
	var export_text := JSON.stringify(fixture.snapshots[2].storage)
	var export_path := root_path + "/browser_export.json"
	if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(
			root_path)) != OK:
		return _fail("could not prepare browser import UI directory")
	var export_file := FileAccess.open(export_path, FileAccess.WRITE)
	export_file.store_string(export_text)
	export_file.close()
	var ui: Control = load("res://scenes/noncombat_opening.tscn").instantiate()
	ui.slot_root_path = root_path
	root.add_child(ui)
	await process_frame
	var slots: Control = ui.get_node("DesktopMargin/ScreenStack/SlotSelection")
	if not slots.visible or slots.get_node_or_null("ImportBrowserTutorial") == null \
			or ui.browser_save_picker == null:
		return _fail("desktop slot screen has no browser import entry")
	ui._on_browser_save_file_selected(ProjectSettings.globalize_path(export_path))
	await process_frame
	var action: Button = ui.browser_import_list.find_child("Import_slot_1", true, false)
	if action.disabled or not ui.browser_import_dialog.visible:
		return _fail("real browser tutorial save was not previewed as importable")
	action.pressed.emit()
	await process_frame
	var info: Dictionary = Slots.new(root_path).inspect_slot("slot_1")
	if not info.get("occupied") or info.get("turn") != 2 \
			or not ui.slot_status_label.text.contains("已导入") \
			or FileAccess.get_file_as_string(root_path + "/browser_save_export_v1.json") \
				!= export_text:
		return _fail("desktop import failed to stage source and create a playable slot")
	var original_bytes := FileAccess.get_file_as_string(
		root_path + "/noncombat_opening_v2.json")
	ui._on_browser_save_file_selected(ProjectSettings.globalize_path(export_path))
	await process_frame
	var replace_action: Button = ui.browser_import_list.find_child(
		"Import_slot_1", true, false)
	if replace_action == null or replace_action.disabled \
			or replace_action.text != "备份并替换":
		return _fail("occupied native slot did not offer an explicit backup action")
	replace_action.pressed.emit()
	await process_frame
	if not ui.browser_replace_confirm.visible or FileAccess.get_file_as_string(
			root_path + "/noncombat_opening_v2.json") != original_bytes:
		return _fail("replacement confirmation changed the original save")
	ui.browser_replace_confirm.confirmed.emit()
	ui.browser_replace_confirm.hide()
	await process_frame
	var preserved := false
	for filename in DirAccess.get_files_at(root_path):
		if filename.begins_with("noncombat_opening_v2.json.prebrowserimport.") \
				and FileAccess.get_file_as_string(root_path + "/" + filename) == \
				original_bytes:
			preserved = true
	if not preserved or not ui.slot_status_label.text.contains("原档备份"):
		return _fail("desktop replacement did not retain an exact original save")
	(slots.get_node("Slot_slot_1") as Button).pressed.emit()
	await process_frame
	if ui.opening.get_current_card().get("id") != "q_start_sword" \
			or ui.opening.state.get("attributes", {}).get("cultivation") != 13:
		return _fail("desktop import did not resume the browser tutorial decision")
	var native_bytes := FileAccess.get_file_as_string(ui.opening_store.v2_path)
	var native_path: String = ui.opening_store.v2_path
	(ui.get_node("DesktopMargin/ScreenStack/StoryScreen/ReturnToSlots") as Button).pressed.emit()
	var middle: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(
		_source_path(MID_FIXTURE)))
	var middle_text := JSON.stringify(middle.snapshots[7].storage)
	var middle_export := root_path + "/browser_middle_export.json"
	var middle_file := FileAccess.open(middle_export, FileAccess.WRITE)
	middle_file.store_string(middle_text)
	middle_file.close()
	ui.queue_free()
	await process_frame
	ui = load("res://scenes/noncombat_opening.tscn").instantiate()
	ui.slot_root_path = root_path + "/middle"
	root.add_child(ui)
	await process_frame
	slots = ui.get_node("DesktopMargin/ScreenStack/SlotSelection")
	ui._on_browser_save_file_selected(ProjectSettings.globalize_path(middle_export))
	await process_frame
	var middle_action: Button = ui.browser_import_list.find_child("Import_slot_1", true, false)
	if middle_action == null or middle_action.disabled:
		return _fail("real browser first-trial save was not previewed as importable")
	middle_action.pressed.emit()
	await process_frame
	(slots.get_node("Slot_slot_1") as Button).pressed.emit()
	await process_frame
	if ui.opening.state.get("runClock", {}).get("decisionIndex") != 7 \
			or ui.opening.get_current_card().get("id") != middle.snapshots[7].visibleCardId \
			or ui.opening.state.get("questState", {}).get("activeQuests", []).size() != 1 \
			or FileAccess.get_file_as_string(native_path) != native_bytes:
		return _fail("desktop import did not resume the browser active white-fox quest")
	var middle_native_bytes := FileAccess.get_file_as_string(ui.opening_store.v2_path)
	(ui.get_node("DesktopMargin/ScreenStack/StoryScreen/ReturnToSlots") as Button).pressed.emit()
	var battle_export := root_path + "/browser_battle_export.json"
	var battle_file := FileAccess.open(battle_export, FileAccess.WRITE)
	battle_file.store_string(FileAccess.get_file_as_string(_source_path(
		BATTLE_FIXTURE)))
	battle_file.close()
	ui._on_browser_save_file_selected(ProjectSettings.globalize_path(battle_export))
	await process_frame
	if not ui.browser_import_list.find_child("Import_slot_3", true, false).disabled \
			or FileAccess.get_file_as_string(ui.opening_store.v2_path) != middle_native_bytes:
		return _fail("battle-in-progress preview changed an existing native slot")
	ui.queue_free()
	await process_frame
	var extended: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(
		_source_path(EXTENDED_FIXTURE)))
	var extended_text := JSON.stringify(extended.snapshots[14].storage)
	var extended_export := root_path + "/browser_extended_export.json"
	var extended_file := FileAccess.open(extended_export, FileAccess.WRITE)
	extended_file.store_string(extended_text)
	extended_file.close()
	ui = load("res://scenes/noncombat_opening.tscn").instantiate()
	ui.slot_root_path = root_path + "/extended"
	root.add_child(ui)
	await process_frame
	slots = ui.get_node("DesktopMargin/ScreenStack/SlotSelection")
	ui._on_browser_save_file_selected(ProjectSettings.globalize_path(extended_export))
	await process_frame
	var extended_action: Button = ui.browser_import_list.find_child(
		"Import_slot_1", true, false)
	if extended_action == null or extended_action.disabled:
		return _fail("real browser chapter karma save was not previewed as importable")
	extended_action.pressed.emit()
	await process_frame
	(slots.get_node("Slot_slot_1") as Button).pressed.emit()
	await process_frame
	if ui.opening.state.get("runClock", {}).get("decisionIndex") != 14 \
			or ui.opening.get_current_card().get("id") != extended.snapshots[14].visibleCardId \
			or ui.opening.state.get("legacyArchive", {}).get(
				"fragmentsBySet", {}).get("pill_way") != 1 \
			or FileAccess.get_file_as_string(root_path + "/extended/browser_save_export_v1.json") \
				!= extended_text:
		return _fail("desktop import did not resume the browser chapter karma decision")
	ui.queue_free()
	print("NONCOMBAT_BROWSER_IMPORT_UI_PASS tutorial=true active_quest=true chapter_karma=true resume=true battle_blocked=true replace_backup=true")
	quit(0)


func _source_path(relative: String) -> String:
	# 内化后常量是 res:// 虚拟路径，不能再 path_join 到绝对根上；
	# 相对路径（历史写法）仍需拼绝对根才能被 FileAccess 打开。
	if relative.begins_with("res://"):
		return relative
	return ProjectSettings.globalize_path("res://").path_join(relative).simplify_path()


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
