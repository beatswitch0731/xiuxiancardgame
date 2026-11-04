extends "res://tests/noncombat_cadence_battle.gd"

const SECOND_FIXTURE := "res://tests/fixtures/second_cadence_source.json"

func _run() -> void:
	var first: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	var second: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SECOND_FIXTURE))
	var file := "user://tests/cadence_second_%d.json" % Time.get_ticks_usec()
	var game = Domain.new(Registry.new(), Session.new(file, "slot_2"), "slot_2")
	_quiet_ambient(game)
	if not _open_second(game, first, second):
		return _fail(_problem)
	if _cold(game, "second cadence offered") == null:
		return _fail("second cadence offer failed strict cold restore")
	print("NONCOMBAT_CADENCE_SECOND_ENTRY_PASS natural=true source=true replay=true")
	quit(0)


func _open_second(game: RefCounted, first: Dictionary, second: Dictionary) -> bool:
	# Source seed 123 exposes a rare first wheel card (dao_pill). This LCG
	# seed yields that same card; the wheel choice remains a public input.
	game._destiny_wheel_flow.initial_seed_override = 8898
	if not _open_before_offer(game, first["rows"][0]) or not game.resume_flow() \
			or game.get_current_card().get("id") != CADENCE_ID \
			or not game.choose("right", game.issue_choice_token()):
		return _bad("second cadence public prefix did not avoid first catalog card")
	for input in second.get("route", []):
		if game.state.get("phase") == "FLOW_PENDING" and not game.resume_flow():
			return _bad("second cadence route could not resume: " + game.flow_failure_reason())
		var card: Dictionary = game.get_current_card()
		var expected_id := String(input[0])
		if card.get("id") != expected_id and card.get("type") != expected_id:
			return _bad("second cadence route card differs: expected=%s got=%s/%s" % [
				expected_id, card.get("id"), card.get("type")])
		if expected_id == "DESTINY_WHEEL" and (
				card.get("wheelState", {}).get("deck", []).is_empty() \
				or card.wheelState.deck[0].get("rewardId") != "dao_pill"):
			return _bad("second cadence wheel did not match the source rare pill")
		if not game.choose(String(input[1]), game.issue_choice_token()):
			return _bad("second cadence route choice failed: " + expected_id)
	if game.state.get("phase") == "FLOW_PENDING" and not game.resume_flow():
		return _bad("second cadence offer did not resume")
	var source: Dictionary = second["rows"][0]["sourceCard"]
	if game.state.get("phase") != "COMBAT_HANDOFF" \
			or game.get_current_card().get("id") != second.get("sourceCardId") \
			or not _expect(_canonical(game.get_current_card()),
				_canonical(source), "second cadence source card"):
		return _bad("second cadence producer did not issue source card")
	return true
