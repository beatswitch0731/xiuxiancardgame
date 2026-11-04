extends RefCounted

const Inspector = preload("res://scripts/noncombat_browser_save_inspector.gd")
const STAGING_FILE := "browser_save_export_v1.json"

var root_dir: String
var fail_promotion_once := false


func _init(save_root: String = "user://") -> void:
	root_dir = save_root if save_root == "user://" else save_root.trim_suffix("/")


func stage_text(raw_text: String) -> Dictionary:
	var preview: Dictionary = Inspector.new().inspect_text(raw_text)
	if preview.get("ok") != true:
		return {"ok": false, "error": String(preview.get("error", "INVALID_BROWSER_SAVE")),
			"preview": preview}
	var path := _staging_path()
	if path.is_empty():
		return {"ok": false, "error": "INVALID_PATH"}
	var absolute := ProjectSettings.globalize_path(path)
	if DirAccess.make_dir_recursive_absolute(absolute.get_base_dir()) != OK:
		return {"ok": false, "error": "DIRECTORY_FAILED"}
	var pending := absolute + ".pending"
	var file := FileAccess.open(pending, FileAccess.WRITE)
	if file == null:
		return {"ok": false, "error": "WRITE_FAILED"}
	var wrote := file.store_string(raw_text)
	file.flush()
	file.close()
	if not wrote or FileAccess.get_file_as_string(pending) != raw_text:
		return {"ok": false, "error": "WRITE_FAILED"}
	var backup := ""
	if FileAccess.file_exists(path):
		backup = absolute + ".backup.%d.%d.%d.json" % [
			int(Time.get_unix_time_from_system()), OS.get_process_id(), Time.get_ticks_usec()]
		if FileAccess.file_exists(backup) or DirAccess.copy_absolute(absolute, backup) != OK \
				or FileAccess.get_file_as_string(backup) != FileAccess.get_file_as_string(path):
			return {"ok": false, "error": "BACKUP_FAILED"}
	if fail_promotion_once:
		fail_promotion_once = false
		return {"ok": false, "error": "PROMOTION_FAILED", "backup": backup}
	if DirAccess.rename_absolute(pending, absolute) != OK:
		return {"ok": false, "error": "PROMOTION_FAILED", "backup": backup}
	return {"ok": true, "sourceSha256": raw_text.sha256_text(),
		"backup": backup, "preview": preview}


func inspect_staged() -> Dictionary:
	var path := _staging_path()
	if path.is_empty() or not FileAccess.file_exists(path):
		return {"ok": false, "error": "NO_STAGED_EXPORT"}
	return Inspector.new().inspect_text(FileAccess.get_file_as_string(path))


func _staging_path() -> String:
	if not root_dir.begins_with("user://") \
			or ".." in root_dir.trim_prefix("user://").split("/"):
		return ""
	return root_dir.path_join(STAGING_FILE)
