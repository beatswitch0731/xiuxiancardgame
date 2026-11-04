extends "res://tests/noncombat_cadence_second_entry.gd"

const THIRD_FIXTURE := "res://tests/fixtures/third_cadence_source.json"
const THIRD_NPC_FIXTURE := "res://tests/fixtures/npc_first_source.json"


func _quiet_ambient(game: RefCounted) -> void:
	super._quiet_ambient(game)
	var npc: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(THIRD_NPC_FIXTURE))
	game._npc_encounter_flow.roll_override_sequence = npc.rows[0].rolls.map(
		func(row: Dictionary) -> float: return float(row.value))


func _run() -> void:
	var first: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	var second: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SECOND_FIXTURE))
	var third: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(THIRD_FIXTURE))
	var npc: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(THIRD_NPC_FIXTURE))
	for source in npc.pins:
		var actual := FileAccess.get_sha256(ProjectSettings.globalize_path("res://").path_join(
			"../" + source))
		if actual != npc.pins[source]:
			return _fail("third cadence NPC source oracle drift: " + source)
	var file := "user://tests/cadence_third_%d.json" % Time.get_ticks_usec()
	var game = Domain.new(Registry.new(), Session.new(file, "slot_2"), "slot_2")
	_quiet_ambient(game)
	if not _open_third(game, first, second, third):
		return _fail(_problem)
	if _cold(game, "third cadence offered") == null:
		return _fail("third cadence offer failed strict cold restore")
	print("NONCOMBAT_CADENCE_THIRD_ENTRY_PASS public=true source_rng_replay=true source=true replay=true")
	quit(0)


func _open_third(game: RefCounted, first: Dictionary, second: Dictionary,
		third: Dictionary) -> bool:
	if not _open_second(game, first, second):
		return false
	if not game.choose("right", game.issue_choice_token()):
		return _bad("third cadence prefix did not avoid second catalog card")
	for input in third.get("postRoute", []):
		if game.state.get("phase") == "FLOW_PENDING" and not game.resume_flow():
			return _bad("third cadence route could not resume: " + game.flow_failure_reason())
		var card: Dictionary = game.get_current_card()
		var expected_id := String(input[0])
		if card.get("id") != expected_id and card.get("type") != expected_id:
			return _bad("third cadence route card differs: expected=%s got=%s/%s" % [
				expected_id, card.get("id"), card.get("type")])
		if not game.choose(String(input[1]), game.issue_choice_token()):
			return _bad("third cadence route choice failed: " + expected_id)
	if game.state.get("phase") == "FLOW_PENDING" and not game.resume_flow():
		return _bad("third cadence offer did not resume")
	var source: Dictionary = third["rows"][0]["sourceCard"]
	if game.state.get("phase") != "COMBAT_HANDOFF" \
			or game.get_current_card().get("id") != third.get("sourceCardId") \
			or not _expect(_canonical(game.get_current_card()),
				_canonical(source), "third cadence source card"):
		return _bad("third cadence producer did not issue source card")
	return true
