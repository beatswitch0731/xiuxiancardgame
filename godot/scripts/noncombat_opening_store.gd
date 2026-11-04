extends RefCounted

# Deliberately scoped to the Godot fresh-life opening. This is not a browser
# save-slot importer and must never be labelled as schema-10 compatibility.
const SAVE_VERSION := 1

var path: String


func _init(save_path: String) -> void:
	path = save_path


func load_state() -> Dictionary:
	if not _valid_path() or not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parser := JSON.new()
	if parser.parse(file.get_as_text()) != OK:
		return {}
	var parsed = parser.data
	if not parsed is Dictionary or parsed.get("version") != SAVE_VERSION \
			or not parsed.get("state") is Dictionary:
		return {}
	return parsed["state"]


func save_state(snapshot: Dictionary) -> bool:
	if not _valid_path() or snapshot.is_empty():
		return false
	# A damaged or future-version opening remains recoverable as raw evidence.
	# The UI archives it before offering a fresh run; the store never overwrites it.
	if FileAccess.file_exists(path) and load_state().is_empty():
		return false
	var absolute := ProjectSettings.globalize_path(path)
	if DirAccess.make_dir_recursive_absolute(absolute.get_base_dir()) != OK:
		return false
	var pending_path := path + ".pending"
	var pending := FileAccess.open(pending_path, FileAccess.WRITE)
	if pending == null:
		return false
	var serialized := JSON.stringify({"version": SAVE_VERSION, "state": snapshot})
	var wrote := pending.store_string(serialized)
	pending.flush()
	pending.close()
	if not wrote or FileAccess.get_file_as_string(pending_path) != serialized:
		return false
	return DirAccess.rename_absolute(ProjectSettings.globalize_path(pending_path), absolute) == OK


func has_state_file() -> bool:
	return _valid_path() and FileAccess.file_exists(path)


func archive_unrestorable() -> String:
	if not has_state_file():
		return ""
	var archive := path.trim_suffix(".json") + ".unrestorable.%d.json" % Time.get_ticks_usec()
	if FileAccess.file_exists(archive):
		return ""
	if DirAccess.rename_absolute(ProjectSettings.globalize_path(path),
			ProjectSettings.globalize_path(archive)) != OK:
		return ""
	return archive


func _valid_path() -> bool:
	return path.begins_with("user://") and path.ends_with(".json") \
		and path.get_file() != "" and not ".." in path.split("/")
