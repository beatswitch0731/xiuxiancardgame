extends RefCounted

# The only durable writer for the Godot opening while the full RunSession is
# being built. Existing v1 files are read-only migration inputs; v2 lives in a
# separate slot-specific file and adds a commit revision distinct from turn.
const SAVE_VERSION := 2
const LegacyStore = preload("res://scripts/noncombat_opening_store.gd")
const SOURCE_MANIFEST := "res://content/source_manifest.json"
const RULE_SOURCE_PATHS := ["data/config/paths.json", "data/config/realms.json",
	"data/cards/qi.json", "data/progression/first_session_cohesion.json",
	"data/combat/encounters.json"]
const RULESET_VERSION := 1
const SLOT_LOCK_WAIT_MSEC := 2000

var legacy_path: String
var v2_path: String
var slot_id: String
var last_error := ""
var fail_promotion_once := false # Fault-injection seam for the failed-rename regression.
var fail_import_verify_once := false # Fault-injection seam for post-write rollback.
var _legacy_store: RefCounted
var _manifest_path: String
var _fingerprint_error := "SOURCE_UNAVAILABLE"
var _slot_lock_token := ""
var _last_loaded_path := ""
var _last_loaded_sha := ""


func _init(source_path: String, source_slot_id: String = "slot_1",
		manifest_path: String = SOURCE_MANIFEST) -> void:
	legacy_path = source_path
	slot_id = source_slot_id
	_manifest_path = manifest_path
	var stem := source_path.trim_suffix(".json")
	if stem.ends_with("_v1"):
		stem = stem.trim_suffix("_v1")
	v2_path = stem + "_v2.json"
	_legacy_store = LegacyStore.new(source_path)


func load_state() -> Dictionary:
	var snapshot := load_snapshot()
	return snapshot.get("state", {}).duplicate(true)


func load_snapshot() -> Dictionary:
	if not _acquire_slot_lock():
		return {}
	var result := _load_snapshot_unlocked()
	_release_slot_lock()
	return result


func _load_snapshot_unlocked() -> Dictionary:
	last_error = ""
	_last_loaded_path = ""
	_last_loaded_sha = ""
	if not _valid_path(v2_path) or not _valid_path(legacy_path) \
			or not slot_id in ["slot_1", "slot_2", "slot_3"]:
		last_error = "INVALID_PATH_OR_SLOT"
		return {}
	var pending_path := v2_path + ".pending"
	if FileAccess.file_exists(pending_path):
		# Rename is the commit point. A pending file may be a failed rename,
		# including one truncated by a crash. Preserve its raw bytes and load
		# the last stable revision instead of promoting or interpreting it.
		if _archive_file(pending_path, ".uncommitted").is_empty():
			last_error = "PENDING_ARCHIVE_FAILED"
			return {}
	if FileAccess.file_exists(v2_path):
		_last_loaded_path = v2_path
		_last_loaded_sha = FileAccess.get_sha256(v2_path)
		var active := _read_v2(v2_path)
		if active.is_empty():
			if last_error.is_empty():
				last_error = "UNREADABLE_V2"
			return {}
		return active
	if not FileAccess.file_exists(legacy_path):
		return {}
	_last_loaded_path = legacy_path
	_last_loaded_sha = FileAccess.get_sha256(legacy_path)
	var legacy: Dictionary = _legacy_store.load_state()
	if legacy.is_empty() or not _valid_run_identity(legacy):
		last_error = "UNREADABLE_V1"
		return {}
	return {"version": 1, "revision": 0, "state": legacy.duplicate(true),
		"legacy": true}


func commit_snapshot(candidate: Dictionary, expected_revision: int) -> Dictionary:
	return _commit_snapshot(candidate, expected_revision, "")


func commit_browser_import(candidate: Dictionary, expected_revision: int) -> Dictionary:
	if not _acquire_slot_lock():
		return {"ok": false, "error": last_error}
	var result := _commit_browser_import_unlocked(candidate, expected_revision)
	_release_slot_lock()
	return result


func _commit_browser_import_unlocked(candidate: Dictionary,
		expected_revision: int) -> Dictionary:
	var before := _load_snapshot_unlocked()
	if before.is_empty() or not last_error.is_empty() or not _valid_run_identity(candidate) \
			or int(before.get("revision", -1)) != expected_revision:
		return {"ok": false, "error": last_error if not last_error.is_empty() else
			"REVISION_MISMATCH"}
	var fingerprint := _rules_fingerprint()
	if fingerprint.length() != 64:
		return {"ok": false, "error": _fingerprint_error}
	var original_path := v2_path if FileAccess.file_exists(v2_path) else legacy_path
	var original_absolute := ProjectSettings.globalize_path(original_path)
	var backup_path := original_path + ".prebrowserimport.%d.%d.%d.json" % [
		int(Time.get_unix_time_from_system()), OS.get_process_id(), Time.get_ticks_usec()]
	var backup_absolute := ProjectSettings.globalize_path(backup_path)
	if FileAccess.file_exists(backup_path) \
			or DirAccess.copy_absolute(original_absolute, backup_absolute) != OK \
			or FileAccess.get_sha256(original_path) != FileAccess.get_sha256(backup_path):
		return {"ok": false, "error": "BACKUP_FAILED"}
	var revision := expected_revision + 1
	var envelope := {"version": SAVE_VERSION, "revision": revision,
		"slotId": slot_id, "sourceFingerprint": fingerprint,
		"state": candidate.duplicate(true)}
	if not _write_atomic(envelope):
		return {"ok": false, "error": "WRITE_FAILED", "backup": backup_path}
	var after := _load_snapshot_unlocked()
	var verified: bool = after.get("revision") == revision \
		and _same_json(after.get("state"), candidate)
	if fail_import_verify_once:
		fail_import_verify_once = false
		verified = false
	if not verified:
		var rollback_ok := false
		if original_path == v2_path:
			var rollback_pending := v2_path + ".pending"
			rollback_ok = DirAccess.copy_absolute(backup_absolute,
				ProjectSettings.globalize_path(rollback_pending)) == OK \
				and _promote_pending(rollback_pending)
		else:
			rollback_ok = not _archive_file(v2_path, ".failedimport").is_empty()
		return {"ok": false, "error": "VERIFY_FAILED" if rollback_ok else
			"ROLLBACK_FAILED", "backup": backup_path}
	return {"ok": true, "revision": revision, "backup": backup_path}


func commit_life_transition(candidate: Dictionary, expected_revision: int,
		death_direction: String) -> Dictionary:
	# A new life resets its clock. Only the settled death-card handoff may cross
	# this identity boundary; ordinary choice commits retain their old guard.
	if death_direction not in ["left", "right"]:
		return {"ok": false, "error": "INVALID_LIFE_TRANSITION"}
	return _commit_snapshot(candidate, expected_revision, death_direction)


func _commit_snapshot(candidate: Dictionary, expected_revision: int,
		death_direction: String) -> Dictionary:
	if not _acquire_slot_lock():
		return {"ok": false, "error": last_error}
	var result := _commit_snapshot_unlocked(candidate, expected_revision, death_direction)
	_release_slot_lock()
	return result


func _commit_snapshot_unlocked(candidate: Dictionary, expected_revision: int,
		death_direction: String) -> Dictionary:
	var before := _load_snapshot_unlocked()
	if not last_error.is_empty() or candidate.is_empty() \
			or not _valid_run_identity(candidate):
		return {"ok": false, "error": last_error if not last_error.is_empty() else "INVALID_CANDIDATE"}
	if before.is_empty() and expected_revision != -1:
		return {"ok": false, "error": "REVISION_MISMATCH"}
	if not before.is_empty() and int(before["revision"]) != expected_revision:
		return {"ok": false, "error": "REVISION_MISMATCH"}
	if not before.is_empty():
		var prior: Dictionary = before["state"]
		if death_direction.is_empty():
			if candidate["runClock"]["lifeId"] != prior["runClock"]["lifeId"] \
					or int(candidate["runClock"].get("decisionIndex", -1)) < \
						int(prior["runClock"].get("decisionIndex", -1)) \
					or not _same_json(candidate.get("lifeJournal", []),
						prior.get("lifeJournal", [])):
				return {"ok": false, "error": "RUN_IDENTITY_CHANGED"}
		elif not _valid_life_transition(prior, candidate, death_direction):
			return {"ok": false, "error": "INVALID_LIFE_TRANSITION"}
	elif not death_direction.is_empty():
		return {"ok": false, "error": "INVALID_LIFE_TRANSITION"}
	var fingerprint := _rules_fingerprint()
	if fingerprint.length() != 64:
		return {"ok": false, "error": _fingerprint_error}
	var next_revision := expected_revision + 1
	var envelope := {"version": SAVE_VERSION, "revision": next_revision,
		"slotId": slot_id, "sourceFingerprint": fingerprint,
		"state": candidate.duplicate(true)}
	if not _write_atomic(envelope):
		return {"ok": false, "error": "WRITE_FAILED"}
	return {"ok": true, "revision": next_revision}


func _valid_life_transition(prior: Dictionary, candidate: Dictionary,
		death_direction: String) -> bool:
	var previous_life := _life_number(String(prior.get("runClock", {}).get("lifeId", "")))
	var next_life := _life_number(String(candidate.get("runClock", {}).get("lifeId", "")))
	if previous_life < 0 or next_life != previous_life + 1 \
			or prior.get("phase") != "DEATH_PENDING" \
			or prior.get("dead") != true \
			or prior.get("lifePhase") != "DYING_NARRATIVE" \
			or not String(prior.get("currentCardId", "")).begins_with("death_") \
			or prior.get("currentCardId") != prior.get("deathCauseId") \
			or not prior.get("lifeCount") is int and not prior.get("lifeCount") is float \
			or int(prior.get("lifeCount", -1)) != previous_life \
			or candidate.get("lifeCount") != next_life \
			or candidate.get("phase") != "REBIRTH_PENDING" \
			or candidate.get("currentCardId") != "rebirth_boon" \
			or candidate.get("lifePhase") != "LEGACY_CHOICE" \
			or candidate.get("dead") != false \
			or candidate.get("path") != null \
			or candidate.get("turn") != 0 \
			or candidate.get("choiceHistory") != [] \
			or candidate.get("replayHistory") != []:
		return false
	var clock: Dictionary = candidate["runClock"]
	if clock.get("decisionIndex") != 0 or clock.get("receipts") != {}:
		return false
	var prior_journal: Variant = prior.get("lifeJournal", [])
	var next_journal: Variant = candidate.get("lifeJournal")
	if not prior_journal is Array or not next_journal is Array \
			or next_journal.size() != prior_journal.size() + 1 \
			or not _same_json(next_journal.slice(0, prior_journal.size()),
				prior_journal):
		return false
	var closure: Variant = next_journal.back()
	if not closure is Dictionary or closure.get("deathDirection") != death_direction \
			or not closure.get("terminalState") is Dictionary:
		return false
	var archived: Dictionary = prior.duplicate(true)
	archived.erase("lifeJournal")
	return _same_json(closure["terminalState"], archived)


func _life_number(life_id: String) -> int:
	var prefix := slot_id + ":life:"
	if not life_id.begins_with(prefix):
		return -1
	var suffix := life_id.trim_prefix(prefix)
	if not suffix.is_valid_int() or suffix != str(int(suffix)):
		return -1
	return int(suffix)


func _same_json(left: Variant, right: Variant) -> bool:
	return JSON.parse_string(JSON.stringify(left)) == JSON.parse_string(JSON.stringify(right))


func has_state_file() -> bool:
	return FileAccess.file_exists(v2_path) or FileAccess.file_exists(v2_path + ".pending") \
		or _legacy_store.has_state_file()


func mark_source_mismatch() -> void:
	# The opening's five-file fingerprint cannot cover a warning that was
	# committed later against additional encounter/presentation rules.
	last_error = "SOURCE_MISMATCH"


func mark_source_unavailable() -> void:
	last_error = "SOURCE_UNAVAILABLE"


func archive_unrestorable() -> String:
	# Source drift and a recoverable interrupted transaction are not corrupt saves.
	if last_error in ["SOURCE_MISMATCH", "SOURCE_UNAVAILABLE", "FUTURE_VERSION", "PENDING_TRANSACTION",
			"PENDING_ARCHIVE_FAILED", "SLOT_BUSY", "SLOT_LOCK_FAILED"]:
		return ""
	var failed_path := _last_loaded_path
	var failed_sha := _last_loaded_sha
	if failed_path.is_empty() or failed_sha.is_empty() or not _acquire_slot_lock():
		return ""
	var archived := _archive_unrestorable_locked(failed_path, failed_sha)
	_release_slot_lock()
	return archived


func _archive_unrestorable_locked(failed_path: String, failed_sha: String) -> String:
	if not FileAccess.file_exists(failed_path) \
			or FileAccess.get_sha256(failed_path) != failed_sha:
		last_error = "SLOT_CHANGED"
		return ""
	# Archiving v2 while a v1 ancestor remains would silently resume an older
	# decision on the next launch. Keep both files for explicit recovery.
	if _legacy_store.has_state_file() and (FileAccess.file_exists(v2_path) \
			or FileAccess.file_exists(v2_path + ".pending")):
		return ""
	if failed_path == v2_path:
		return _archive_file(v2_path, ".unrestorable")
	if failed_path == legacy_path:
		return _legacy_store.archive_unrestorable()
	return ""


func _read_v2(source_path: String) -> Dictionary:
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string(source_path)) != OK:
		last_error = "UNREADABLE_V2"
		return {}
	var parsed: Variant = parser.data
	if parsed is Dictionary and _valid_revision(parsed.get("version")) \
			and int(parsed["version"]) > SAVE_VERSION:
		last_error = "FUTURE_VERSION"
		return {}
	if not parsed is Dictionary or parsed.get("version") != SAVE_VERSION \
			or not _valid_revision(parsed.get("revision")) \
			or parsed.get("slotId") != slot_id or not parsed.get("state") is Dictionary \
			or not _valid_run_identity(parsed["state"]):
		last_error = "UNREADABLE_V2"
		return {}
	var current_fingerprint := _rules_fingerprint()
	if current_fingerprint.is_empty():
		last_error = _fingerprint_error
		return {}
	if parsed.get("sourceFingerprint") != current_fingerprint:
		last_error = "SOURCE_MISMATCH"
		return {}
	return parsed


func _valid_run_identity(snapshot: Dictionary) -> bool:
	var clock: Variant = snapshot.get("runClock")
	return clock is Dictionary and clock.get("lifeId") is String \
		and String(clock["lifeId"]).begins_with(slot_id + ":life:") \
		and _valid_revision(clock.get("decisionIndex"))


func _rules_fingerprint() -> String:
	_fingerprint_error = "SOURCE_UNAVAILABLE"
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string(_manifest_path)) != OK \
			or not parser.data is Dictionary:
		return ""
	var manifest: Dictionary = parser.data
	var source_meta := {}
	for row in manifest.get("data", []):
		if row is Dictionary:
			source_meta[row.get("path", "")] = row.get("sha256", "")
	var basis := "opening-rules:%d\n" % RULESET_VERSION
	for path in RULE_SOURCE_PATHS:
		var source_sha := String(source_meta.get(path, ""))
		var source_path: String = "res://content/" + String(path)
		if source_sha.length() != 64 or not FileAccess.file_exists(source_path):
			return ""
		if FileAccess.get_sha256(source_path) != source_sha:
			_fingerprint_error = "SOURCE_MISMATCH"
			return ""
		basis += path + ":" + source_sha + "\n"
	return basis.sha256_text()


func _valid_revision(value: Variant) -> bool:
	return (value is int or value is float) and float(value) >= 0.0 \
		and float(value) == float(int(value))


func _valid_path(path: String) -> bool:
	return path.begins_with("user://") and path.ends_with(".json") \
		and path.get_file() != "" and not ".." in path.split("/")


func _acquire_slot_lock() -> bool:
	last_error = ""
	if not _valid_path(v2_path) or not _valid_path(legacy_path) \
			or slot_id not in ["slot_1", "slot_2", "slot_3"]:
		last_error = "INVALID_PATH_OR_SLOT"
		return false
	var lock_path := ProjectSettings.globalize_path(v2_path + ".lock")
	if DirAccess.make_dir_recursive_absolute(lock_path.get_base_dir()) != OK:
		last_error = "SLOT_LOCK_FAILED"
		return false
	# Prepare the owner before publishing the lock. A crash during preparation
	# leaves only a candidate directory, which cannot block the slot.
	var token := "%d:%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	var candidate_path := lock_path + ".candidate." + token.sha256_text()
	if DirAccess.make_dir_absolute(candidate_path) != OK:
		last_error = "SLOT_LOCK_FAILED"
		return false
	var candidate_owner := candidate_path.path_join("owner")
	var owner := FileAccess.open(candidate_owner, FileAccess.WRITE)
	if owner == null or not owner.store_string(token):
		if owner != null:
			owner.close()
		DirAccess.remove_absolute(candidate_owner)
		DirAccess.remove_absolute(candidate_path)
		last_error = "SLOT_LOCK_FAILED"
		return false
	owner.flush()
	owner.close()
	var started := Time.get_ticks_msec()
	while Time.get_ticks_msec() - started < SLOT_LOCK_WAIT_MSEC:
		if DirAccess.rename_absolute(candidate_path, lock_path) == OK:
			_slot_lock_token = token
			return true
		OS.delay_msec(20)
	if _recover_orphaned_slot_lock(lock_path):
		started = Time.get_ticks_msec()
		while Time.get_ticks_msec() - started < SLOT_LOCK_WAIT_MSEC:
			if DirAccess.rename_absolute(candidate_path, lock_path) == OK:
				_slot_lock_token = token
				return true
			OS.delay_msec(20)
	DirAccess.remove_absolute(candidate_owner)
	DirAccess.remove_absolute(candidate_path)
	last_error = "SLOT_BUSY" if DirAccess.dir_exists_absolute(lock_path) else \
		"SLOT_LOCK_FAILED"
	return false


func _recover_orphaned_slot_lock(lock_path: String) -> bool:
	if OS.get_name() != "Windows":
		return false
	var owner_path := lock_path.path_join("owner")
	if not FileAccess.file_exists(owner_path):
		return false
	var observed := FileAccess.get_file_as_string(owner_path).strip_edges()
	var parts := observed.split(":")
	if parts.size() != 2 or not parts[0].is_valid_int() \
			or not parts[1].is_valid_int() or int(parts[0]) < 1 \
			or not _process_confirmed_gone(int(parts[0])):
		return false
	# The stable destination prevents two recovery contenders from renaming a
	# newly acquired live lock after the first contender moves this orphan.
	var tombstone := lock_path + ".recovered." + observed.sha256_text()
	if DirAccess.dir_exists_absolute(tombstone) \
			or FileAccess.file_exists(tombstone) \
			or DirAccess.rename_absolute(lock_path, tombstone) != OK:
		return false
	return FileAccess.get_file_as_string(tombstone.path_join("owner")) == observed


func _process_confirmed_gone(process_id: int) -> bool:
	var output: Array = []
	if OS.execute("tasklist.exe", ["/FI", "PID eq %d" % process_id,
			"/FO", "CSV", "/NH"], output, true) != 0 or output.is_empty():
		return false
	var listing := String(output[0])
	return not listing.is_empty() and not listing.contains('","%d","' % process_id)


func _release_slot_lock() -> void:
	if _slot_lock_token.is_empty():
		return
	var lock_path := ProjectSettings.globalize_path(v2_path + ".lock")
	var owner_path := lock_path.path_join("owner")
	if FileAccess.get_file_as_string(owner_path) == _slot_lock_token:
		DirAccess.remove_absolute(owner_path)
		DirAccess.remove_absolute(lock_path)
	_slot_lock_token = ""


func _write_atomic(envelope: Dictionary) -> bool:
	if not _valid_path(v2_path):
		return false
	var absolute := ProjectSettings.globalize_path(v2_path)
	if DirAccess.make_dir_recursive_absolute(absolute.get_base_dir()) != OK:
		return false
	var pending_path := v2_path + ".pending"
	var file := FileAccess.open(pending_path, FileAccess.WRITE)
	if file == null:
		return false
	var serialized := JSON.stringify(envelope)
	var wrote := file.store_string(serialized)
	file.flush()
	file.close()
	if not wrote or FileAccess.get_file_as_string(pending_path) != serialized:
		return false
	return _promote_pending(pending_path)


func _promote_pending(pending_path: String) -> bool:
	if fail_promotion_once:
		fail_promotion_once = false
		return false
	return DirAccess.rename_absolute(ProjectSettings.globalize_path(pending_path),
		ProjectSettings.globalize_path(v2_path)) == OK


func _archive_file(source_path: String, suffix: String) -> String:
	var archive := source_path + suffix + ".%d.json" % Time.get_ticks_usec()
	if FileAccess.file_exists(archive) or DirAccess.rename_absolute(
			ProjectSettings.globalize_path(source_path),
			ProjectSettings.globalize_path(archive)) != OK:
		return ""
	return archive
