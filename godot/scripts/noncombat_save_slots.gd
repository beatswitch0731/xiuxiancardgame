extends RefCounted

# The browser owns the slot IDs and Chinese labels. Each legacy v1 path stays
# readable; RunSession writes a separate v2 file. Validated browser schema-10
# early saves are imported through BrowserOpeningImport.
const SLOT_IDS := ["slot_1", "slot_2", "slot_3"]
const SLOT_LABELS := {
	"slot_1": "一号玉简", "slot_2": "二号玉简", "slot_3": "三号玉简",
}
const SAVE_FILES := {
	"slot_1": "noncombat_opening_v1.json", # Existing Godot single-save path.
	"slot_2": "noncombat_opening_slot_2_v1.json",
	"slot_3": "noncombat_opening_slot_3_v1.json",
}
const ACTIVE_FILE := "noncombat_active_slot_v1.json"
const RunSession = preload("res://scripts/noncombat_run_session.gd")

var root_dir: String
var last_archived_index := ""


func _init(save_root: String = "user://") -> void:
	root_dir = save_root if save_root == "user://" else save_root.trim_suffix("/")


func save_path_for(slot_id: String) -> String:
	if not slot_id in SLOT_IDS:
		return ""
	return _join(SAVE_FILES[slot_id])


func active_slot() -> String:
	var parsed: Dictionary = _read_active_index()
	if parsed is Dictionary and parsed.get("version") == 1 \
			and parsed.get("activeSlot") in SLOT_IDS:
		return String(parsed["activeSlot"])
	return "slot_1"


func active_index_corrupted() -> bool:
	var path := _join(ACTIVE_FILE)
	if not FileAccess.file_exists(path):
		return false
	var parsed: Dictionary = _read_active_index()
	return parsed.get("version") != 1 \
		or not parsed.get("activeSlot") in SLOT_IDS


func select_slot(slot_id: String) -> bool:
	if not slot_id in SLOT_IDS:
		return false
	var path := _join(ACTIVE_FILE)
	last_archived_index = ""
	# A damaged selection file is preserved; never erase unknown prior data.
	if active_index_corrupted():
		var archive := path.trim_suffix(".json") + ".unrestorable.%d.json" % Time.get_ticks_usec()
		if FileAccess.file_exists(archive) or DirAccess.rename_absolute(
				ProjectSettings.globalize_path(path),
				ProjectSettings.globalize_path(archive)) != OK:
			return false
		last_archived_index = archive
	var absolute := ProjectSettings.globalize_path(path)
	if DirAccess.make_dir_recursive_absolute(absolute.get_base_dir()) != OK:
		return false
	var pending_path := path + ".pending"
	var pending := FileAccess.open(pending_path, FileAccess.WRITE)
	if pending == null:
		return false
	var serialized := JSON.stringify({"version": 1, "activeSlot": slot_id})
	var wrote := pending.store_string(serialized)
	pending.flush()
	pending.close()
	if not wrote or FileAccess.get_file_as_string(pending_path) != serialized:
		return false
	return DirAccess.rename_absolute(ProjectSettings.globalize_path(pending_path), absolute) == OK


func inspect_slot(slot_id: String) -> Dictionary:
	if not slot_id in SLOT_IDS:
		return {}
	var path := save_path_for(slot_id)
	var session = RunSession.new(path, slot_id)
	var occupied: bool = session.has_state_file()
	var snapshot: Dictionary = session.load_state() if occupied else {}
	return {
		"slotId": slot_id,
		"label": SLOT_LABELS[slot_id],
		"active": FileAccess.file_exists(_join(ACTIVE_FILE)) \
			and not active_index_corrupted() and active_slot() == slot_id,
		"occupied": occupied,
		"corrupted": occupied and snapshot.is_empty(),
		"error": session.last_error,
		"path": snapshot.get("path", ""),
		"playerName": snapshot.get("playerName", "叶凌云") if not snapshot.is_empty() else "",
		"turn": snapshot.get("turn", 0),
		"phase": snapshot.get("phase", ""),
	}


func _join(filename: String) -> String:
	return root_dir + filename if root_dir == "user://" else root_dir + "/" + filename


func _read_active_index() -> Dictionary:
	var path := _join(ACTIVE_FILE)
	if not FileAccess.file_exists(path):
		return {}
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string(path)) != OK or not parser.data is Dictionary:
		return {}
	return parser.data
