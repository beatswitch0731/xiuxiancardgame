extends "res://tests/noncombat_qi_gate_outcomes.gd"

func _run() -> void:
	var first: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	var second: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SECOND_FIXTURE))
	var third: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(THIRD_FIXTURE))
	var gate: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(GATE_FIXTURE))
	var file := "user://tests/qi_gate_arrival_%d.json" % Time.get_ticks_usec()
	var game = Domain.new(Registry.new(), Session.new(file, "slot_2"), "slot_2")
	_quiet_ambient(game)
	if not _open_third_alt(game, first, second, third) or not _reach_gate(game):
		return _fail("elite prefix: " + _problem)
	if game.get_current_card().get("id") != "_warning_ch_qi_100" \
			or not game.choose("left", game.issue_choice_token()):
		return _fail("gate warning")
	var request: Dictionary = game.battle_request()
	if not game.submit_battle_result(_result(request, "victory")):
		return _fail("gate victory: " + game.flow_failure_reason())
	if game.get_current_card().get("id") != "breakthrough_reward" \
			or not game.choose("left", game.issue_choice_token()):
		return _fail("breakthrough reward")
	game = _cold(game, "foundation arrival")
	if game == null:
		return _fail("foundation arrival continuation: " + _problem)
	if not _expect(_canonical(game.get_current_card()),
			_canonical(gate.victoryResponses[0].followUp.nextCard),
			"foundation epiphany card"):
		return _fail(_problem)
	if not game.choose("left", game.issue_choice_token()):
		return _fail("foundation epiphany choice")
	game = _cold(game, "foundation epiphany choice")
	if game == null:
		return _fail("foundation epiphany cold restore: " + _problem)
	if not _expect(game.state.deck,
			gate.arrivalResponses[0].followUp.arrival.after.deck,
			"foundation awakening deck"):
		return _fail(_problem)
	if game.state.phase != "FLOW_PENDING" or not game.resume_flow():
		return _fail("foundation next draw: " + game.flow_failure_reason())
	if game.get_current_card().is_empty():
		return _fail("foundation next card unavailable")
	if _cold(game, "foundation next draw") == null:
		return _fail("foundation next draw cold restore: " + _problem)
	print("NONCOMBAT_QI_GATE_ARRIVAL_PASS public=true reward=true replay=true")
	quit(0)
