extends SceneTree

const Domain = preload("res://scripts/noncombat_domain.gd")
const Registry = preload("res://scripts/runtime_data_registry.gd")
const RunSession = preload("res://scripts/noncombat_run_session.gd")
const DrawPolicy = preload("res://scripts/noncombat_normal_draw_policy.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var file := "user://tests/story_semantic_legacy_%d.json" % Time.get_ticks_usec()
	var store := RunSession.new(file, "slot_3")
	var game := Domain.new(Registry.new(), store, "slot_3")
	if not game.start("sword") or not game.choose("left", game.issue_choice_token()):
		return _fail("new life did not reach first decision")
	var old: Dictionary = game.state.duplicate(true)
	if not old.has("normalNarrativeAdmission"):
		return _fail("new ordinary narrative rule did not activate")
	old.erase("normalNarrativeAdmission")
	var revision := int(store.load_snapshot().get("revision", -1))
	if not store.commit_snapshot(old, revision).get("ok", false):
		return _fail("legacy-shaped snapshot could not be written")
	var cold := Domain.new(Registry.new(), RunSession.new(file, "slot_3"), "slot_3")
	if not cold.restore() or not _same(cold.state, old):
		return _fail("old ordinary narrative rule did not strictly replay")
	if not cold.choose("left", cold.issue_choice_token()):
		return _fail("old snapshot could not continue")
	var marker: Dictionary = cold.state.get("normalNarrativeAdmission", {})
	if marker.get("version") != 1 or marker.get("ruleSha") \
			!= DrawPolicy.NARRATIVE_LEDGER_JS_SHA \
			or int(marker.get("activationIndex", -1)) != 2:
		return _fail("new rule did not activate at next effective decision")
	var after: Dictionary = cold.state.duplicate(true)
	var again := Domain.new(Registry.new(), RunSession.new(file, "slot_3"), "slot_3")
	if not again.restore() or not _same(again.state, after):
		return _fail("upgraded ordinary narrative save did not strictly replay")
	print("NONCOMBAT_STORY_SEMANTIC_LEGACY_PASS old=true next=true replay=true")
	quit(0)

func _same(left: Dictionary, right: Dictionary) -> bool:
	return JSON.parse_string(JSON.stringify(left)) == JSON.parse_string(
		JSON.stringify(right))

func _fail(message: String) -> void:
	push_error(message)
	quit(1)
