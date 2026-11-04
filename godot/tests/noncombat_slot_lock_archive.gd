extends SceneTree

const Registry = preload("res://scripts/runtime_data_registry.gd")
const Domain = preload("res://scripts/noncombat_domain.gd")
const RunSession = preload("res://scripts/noncombat_run_session.gd")


func _initialize() -> void:
	var path := "user://tests/slot_lock_archive_%d.json" % Time.get_ticks_usec()
	var owner = RunSession.new(path, "slot_1")
	var game = Domain.new(Registry.new(), owner, "slot_1")
	if not game.start("sword"):
		return _fail("opening did not start")
	var original := FileAccess.get_file_as_bytes(owner.v2_path)
	if not owner._acquire_slot_lock():
		return _fail("owner could not hold its slot")
	var blocked = RunSession.new(path, "slot_1")
	var loaded: Dictionary = blocked.load_snapshot()
	var archived: String = blocked.archive_unrestorable()
	owner._release_slot_lock()
	if not loaded.is_empty() or blocked.last_error != "SLOT_BUSY" \
			or not archived.is_empty() or FileAccess.get_file_as_bytes(owner.v2_path) != original:
		return _fail("a busy slot was archived or changed")
	var invalid := FileAccess.open(owner.v2_path, FileAccess.WRITE)
	if invalid == null:
		return _fail("could not stage a damaged snapshot")
	invalid.store_string("{")
	invalid.close()
	var damaged = RunSession.new(path, "slot_1")
	if not damaged.load_snapshot().is_empty() or damaged.last_error != "UNREADABLE_V2":
		return _fail("damaged snapshot did not record failure identity")
	var repaired := FileAccess.open(owner.v2_path, FileAccess.WRITE)
	if repaired == null:
		return _fail("could not replace the damaged snapshot")
	repaired.store_buffer(original)
	repaired.close()
	if not damaged.archive_unrestorable().is_empty() \
			or damaged.last_error != "SLOT_CHANGED" \
			or FileAccess.get_file_as_bytes(owner.v2_path) != original:
		return _fail("stale damage report archived a newer valid snapshot")
	var cold = Domain.new(Registry.new(), RunSession.new(path, "slot_1"), "slot_1")
	if not cold.restore():
		return _fail("protected snapshot did not cold restore")
	print("NONCOMBAT_SLOT_LOCK_ARCHIVE_PASS busy=true changed=true cold=true")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
