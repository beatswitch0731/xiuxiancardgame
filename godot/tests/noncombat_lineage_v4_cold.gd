extends SceneTree

const Registry = preload("res://scripts/runtime_data_registry.gd")
const Domain = preload("res://scripts/noncombat_domain.gd")
const RunSession = preload("res://scripts/noncombat_run_session.gd")
const FIXTURE := "res://tests/fixtures/pill_decision54_death_probe_v2.json"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var path := "user://tests/lineage_v4_%d.json" % Time.get_ticks_usec()
	var store = RunSession.new(path, "slot_3")
	var source := FileAccess.open(store.v2_path, FileAccess.WRITE)
	if source == null:
		return _fail("death fixture cannot be staged")
	source.store_string(FileAccess.get_file_as_string(FIXTURE))
	source.close()
	var game = _open(path)
	if game == null or not game.resume_flow() \
			or game.get_current_card().get("id") != "q_love" \
			or not game.choose("right", game.issue_choice_token()) \
			or game.state.get("phase") != "DEATH_PENDING":
		return _fail("source death route stopped before v4 transition")
	var old: Dictionary = game._rebirth_flow.new_life(game.state,
		game.get_current_card(), "left", "slot_3", 4)
	if old.is_empty() or old.get("rebirthInheritanceVersion") != 4 \
			or old.get("lineageEntries", []).size() != 1 \
			or old.lineageEntries[0].get("activeRoute") != null:
		return _fail("v4 historical lineage projection changed")
	var committed: Dictionary = game._store.commit_life_transition(old,
		game._store_revision, "left")
	if committed.get("ok") != true:
		return _fail("v4 life transition did not commit")
	var reopened = _open(path)
	if reopened == null or JSON.parse_string(JSON.stringify(reopened.state)) != \
			JSON.parse_string(JSON.stringify(old)):
		return _fail("v4 life transition failed strict cold replay")
	print("NONCOMBAT_LINEAGE_V4_COLD_PASS archive=true replay=true")
	quit(0)


func _open(path: String) -> RefCounted:
	var game = Domain.new(Registry.new(), RunSession.new(path, "slot_3"), "slot_3")
	game._normal_roll_override = 0.55
	game._market_flow.roll_override = 0.0
	game._destiny_wheel_flow.roll_override = 0.0
	game._ripple_flow.roll_override = 0.999
	game._hint_flow.roll_override = 0.0
	return game if game.restore() else null


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
