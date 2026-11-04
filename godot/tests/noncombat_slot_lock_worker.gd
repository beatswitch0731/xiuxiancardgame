extends SceneTree

const Registry = preload("res://scripts/runtime_data_registry.gd")
const Domain = preload("res://scripts/noncombat_domain.gd")
const RunSession = preload("res://scripts/noncombat_run_session.gd")


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 3:
		push_error("slot lock worker needs mode, run path and barrier path")
		quit(2)
		return
	var mode := String(args[0])
	var path := String(args[1])
	var barrier := String(args[2])
	var store = RunSession.new(path, "slot_1")
	var game = Domain.new(Registry.new(), store, "slot_1")
	if mode == "init":
		var started: bool = game.start("sword")
		print("SLOT_LOCK_INIT ", JSON.stringify({"ok": started,
			"root": ProjectSettings.globalize_path("user://tests")}))
		quit(0 if started else 1)
		return
	if mode == "verify":
		var restored: bool = game.restore()
		print("SLOT_LOCK_VERIFY ", JSON.stringify({"ok": restored,
			"revision": store.load_snapshot().get("revision", -1)}))
		quit(0 if restored else 1)
		return
	if mode in ["recover_left", "recover_right"]:
		var ready := barrier + ".ready." + mode
		var ready_file := FileAccess.open(ready, FileAccess.WRITE)
		if ready_file == null:
			quit(2)
			return
		ready_file.store_string("ready")
		ready_file.close()
		var began := Time.get_ticks_msec()
		while not FileAccess.file_exists(barrier) \
				and Time.get_ticks_msec() - began < 120000:
			OS.delay_msec(10)
		if not FileAccess.file_exists(barrier):
			quit(2)
			return
		var acquired: bool = store._acquire_slot_lock()
		var error: String = store.last_error
		if acquired:
			OS.delay_msec(4000)
			store._release_slot_lock()
		print("SLOT_LOCK_RECOVER ", JSON.stringify({"acquired": acquired,
			"error": error}))
		quit(0)
		return
	if mode not in ["left", "right"] or not game.restore():
		push_error("slot lock worker could not restore its opening")
		quit(1)
		return
	print("SLOT_LOCK_RESTORED ", mode)
	var ready := barrier + ".ready." + mode
	var file := FileAccess.open(ready, FileAccess.WRITE)
	if file == null:
		push_error("slot lock worker could not signal ready")
		quit(1)
		return
	file.store_string("ready")
	file.close()
	print("SLOT_LOCK_READY ", ready)
	var started_wait := Time.get_ticks_msec()
	while not FileAccess.file_exists(barrier) \
			and Time.get_ticks_msec() - started_wait < 120000:
		OS.delay_msec(10)
	if not FileAccess.file_exists(barrier):
		push_error("slot lock barrier timed out")
		quit(1)
		return
	var committed: bool = game.choose(mode, game.issue_choice_token())
	print("SLOT_LOCK_WORKER ", JSON.stringify({"direction": mode,
		"committed": committed, "error": store.last_error}))
	quit(0)
