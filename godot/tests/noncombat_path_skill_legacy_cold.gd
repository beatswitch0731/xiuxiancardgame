extends SceneTree

const Domain = preload("res://scripts/noncombat_domain.gd")
const Registry = preload("res://scripts/runtime_data_registry.gd")
const Session = preload("res://scripts/noncombat_run_session.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var seed = Domain.new(Registry.new(), null, "slot_1")
	if not seed.start("sword"):
		return _fail("source opening unavailable")
	for direction in ["left", "left", "left", "left", "left"]:
		if not seed.choose(direction, seed.issue_choice_token()):
			return _fail("source opening prefix stopped")
	if seed.state.get("phase") != "COMBAT_HANDOFF":
		return _fail("prefix is not the first trial handoff")
	var old: Dictionary = seed.state.duplicate(true)
	old.erase("pathSkillActivationIndex")
	old.erase("earlyAvoidActivationIndex")
	var path := "user://tests/path_skill_legacy_cold_%d.json" % Time.get_ticks_usec()
	var session = Session.new(path, "slot_1")
	if session.commit_snapshot(old, -1).get("ok") != true:
		return _fail("historical save could not be staged")
	var game = Domain.new(Registry.new(), session, "slot_1")
	if not game.restore() or not _same(game.state, old):
		return _fail("historical first trial did not strictly replay")
	var prior_index := int(game.state.runClock.decisionIndex)
	if not game.choose("left", game.issue_choice_token()) \
			or game.state.get("phase") != "WARNING_PENDING" \
			or int(game.state.runClock.decisionIndex) != prior_index \
			or game.state.has("pathSkillActivationIndex") \
			or game.state.has("earlyAvoidActivationIndex"):
		return _fail("zero-decision warning wrote new passive markers")
	var cold = Domain.new(Registry.new(), session, "slot_1")
	if not cold.restore() or not _same(cold.state, game.state):
		return _fail("historical warning could not strictly cold restore")
	print("NONCOMBAT_PATH_SKILL_LEGACY_COLD_PASS old=true warning=true disk=true")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)


func _same(left: Variant, right: Variant) -> bool:
	return JSON.parse_string(JSON.stringify(left)) == JSON.parse_string(JSON.stringify(right))
