extends "res://tests/noncombat_qi_gate_outcomes.gd"

func _run() -> void:
	var first: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	var second: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SECOND_FIXTURE))
	var third: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(THIRD_FIXTURE))
	var gate: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(GATE_FIXTURE))
	var args := OS.get_cmdline_user_args()
	var only := String(args[1]) if args.size() == 2 and args[0] == "--case" else ""
	var count := 0
	for row in gate.defeatResponses:
		if not only.is_empty() and row.followUp.direction != only:
			continue
		if not _defeat_case(first, second, third, row):
			return _fail("qi gate defeat " + row.followUp.direction + ": " + _problem)
		count += 1
		print("QI_GATE_DEFEAT_CASE_PASS " + row.followUp.direction)
	print("NONCOMBAT_QI_GATE_DEFEAT_PASS cases=%d source=true replay=true" % count)
	quit(0)

func _defeat_case(first: Dictionary, second: Dictionary, third: Dictionary,
		row: Dictionary) -> bool:
	var file := "user://tests/qi_gate_defeat_%s_%d.json" % [
		row.followUp.direction, Time.get_ticks_usec()]
	var game = Domain.new(Registry.new(), Session.new(file, "slot_2"), "slot_2")
	_quiet_ambient(game)
	if not _open_third_alt(game, first, second, third) or not _reach_gate(game):
		return _bad("elite prefix")
	var before: Dictionary = game.state.duplicate(true)
	if game.get_current_card().get("id") != "_warning_ch_qi_100" \
			or not game.choose("left", game.issue_choice_token()):
		return _bad("gate warning")
	var request: Dictionary = game.battle_request()
	if request.is_empty():
		return _bad("gate pending")
	game = _cold(game, "defeat gate pending")
	if game == null or not game.submit_battle_result(_result(request, "defeat")):
		return _bad("gate defeat terminal rejected: " + game.flow_failure_reason())
	if game.state.phase != "INNER_DEMON_PENDING" \
			or not _expect(game.get_current_card(), row.resultCard, "inner demon card") \
			or not _relative_effects(before, game.state, row.before, row.after,
				"gate defeat"):
		return _bad("gate defeat differs: " + _problem)
	game = _cold(game, "inner demon pending")
	if game == null:
		return _bad("inner demon cold restore: " + _problem)
	if not game.choose(row.followUp.direction, game.issue_choice_token()):
		return _bad("inner demon choice: " + game.flow_failure_reason())
	if game.get_current_card().get("id") != row.followUp.nextCard.id:
		return _bad("inner demon continuation differs: expected %s got %s" % [
			row.followUp.nextCard.id, game.get_current_card().get("id")])
	if not _relative_effects(before, game.state, row.before, row.followUp.after,
			"inner demon response"):
		return false
	if row.followUp.direction == "up" and not _expect(game.get_current_card(),
			row.followUp.nextCard, "gate defeat result card"):
		return false
	return _cold(game, "inner demon response") != null
