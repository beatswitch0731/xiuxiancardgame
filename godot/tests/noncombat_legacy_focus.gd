extends SceneTree

const Registry = preload("res://scripts/runtime_data_registry.gd")
const Domain = preload("res://scripts/noncombat_domain.gd")
const Session = preload("res://scripts/noncombat_run_session.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var path := "user://tests/legacy_focus_%d.json" % Time.get_ticks_usec()
	var game = Domain.new(Registry.new(), Session.new(path, "slot_3"), "slot_3")
	game._legacy_fragment_flow.roll_override = 0.0
	if not game.start("sword") or not game.choose("left", game.issue_choice_token()) \
			or game.legacy_focus_options().size() != 6:
		return _fail("source fragment sets unavailable")
	var prior: Dictionary = game.state.duplicate(true)
	var bytes := FileAccess.get_file_as_string(game._store.v2_path)
	game._store.fail_promotion_once = true
	if game.set_legacy_focus("sword_heart") or game.state != prior \
			or FileAccess.get_file_as_string(game._store.v2_path) != bytes:
		return _fail("failed focus write leaked into run")
	if not game.set_legacy_focus("sword_heart") \
			or game.set_legacy_focus("sword_heart") \
			or game.set_legacy_focus("unknown"):
		return _fail("focus target validation or retry failed")
	game = _cold(path, 0.0)
	if game == null or game.state.legacyRunState.focusedSetId != "sword_heart":
		return _fail("focus target did not survive strict cold read")
	var count := int(game.state.legacyArchive.fragmentsBySet.sword_heart)
	if not game.choose("left", game.issue_choice_token()) \
			or int(game.state.legacyArchive.fragmentsBySet.sword_heart) != count + 1:
		return _fail("tracked target did not affect actual ordinary drop")
	game = _cold(path, 0.0)
	if game == null or not game.set_legacy_focus("") \
			or game.set_legacy_focus(""):
		return _fail("focus clear failed")
	game = _cold(path, 0.0)
	if game == null or game.state.legacyRunState.focusedSetId != null \
			or game.state.get("legacyFocusActions", []).size() != 2:
		return _fail("cleared focus did not survive strict cold read")
	print("NONCOMBAT_LEGACY_FOCUS_PASS focus=true weighted_drop=true rollback=true replay=true")
	quit(0)


func _cold(path: String, roll: float) -> RefCounted:
	var game = Domain.new(Registry.new(), Session.new(path, "slot_3"), "slot_3")
	game._legacy_fragment_flow.roll_override = roll
	return game if game.restore() else null


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
