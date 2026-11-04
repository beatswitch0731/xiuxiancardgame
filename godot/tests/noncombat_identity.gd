extends SceneTree

const Registry = preload("res://scripts/runtime_data_registry.gd")
const Domain = preload("res://scripts/noncombat_domain.gd")
const Store = preload("res://scripts/noncombat_opening_store.gd")


func _initialize() -> void:
	var path := "user://tests/noncombat_identity_%d.json" % Time.get_ticks_usec()
	var game = Domain.new(Registry.new(), Store.new(path))
	if not game.start("sword", "沈砚") or game.state.get("playerName") != "沈砚":
		_fail("web authored player name was not saved with the opening")
		return
	if not game.choose("right", game.issue_choice_token()):
		_fail("named run could not make a source tutorial choice")
		return
	var restored = Domain.new(Registry.new(), Store.new(path))
	if not restored.restore() or restored.state.get("playerName") != "沈砚":
		_fail("player name disappeared after the first decision and reload")
		return
	var default_game = Domain.new(Registry.new())
	if not default_game.start("body", "  ") or default_game.state.get("playerName") != "叶凌云":
		_fail("blank source name did not use the browser default")
		return
	var invalid = Domain.new(Registry.new())
	if invalid.start("pill", "甲乙丙丁戊") or not invalid.state.is_empty():
		_fail("the source four-character name input limit was bypassed")
		return
	var legacy_path := "user://tests/noncombat_identity_legacy_%d.json" % Time.get_ticks_usec()
	var legacy_store = Store.new(legacy_path)
	var old_game = Domain.new(Registry.new(), legacy_store)
	if not old_game.start("spell"):
		_fail("could not seed a previous Godot opening")
		return
	var old_snapshot: Dictionary = old_game.state.duplicate(true)
	old_snapshot.erase("playerName")
	if not legacy_store.save_state(old_snapshot):
		_fail("could not simulate an earlier name-free Godot v1 save")
		return
	var reopened_legacy = Domain.new(Registry.new(), legacy_store)
	if not reopened_legacy.restore() or not reopened_legacy.choose(
			"right", reopened_legacy.issue_choice_token()) \
			or reopened_legacy.state.get("playerName") != "叶凌云":
		_fail("name-free existing Godot save was lost or not upgraded on choice")
		return
	print("NONCOMBAT_IDENTITY_PASS custom=沈砚 default=叶凌云 limit=4 restore=true legacy=true")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
