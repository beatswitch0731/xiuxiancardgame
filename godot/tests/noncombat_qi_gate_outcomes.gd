extends "res://tests/noncombat_qi_gate_entry.gd"

func _run() -> void:
	var first: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	var second: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SECOND_FIXTURE))
	var third: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(THIRD_FIXTURE))
	var gate: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(GATE_FIXTURE))
	var args := OS.get_cmdline_user_args()
	var only := String(args[1]) if args.size() == 2 and args[0] == "--case" else ""
	var count := 0
	for row in gate.rows:
		if row.outcome == "defeat" or not only.is_empty() and row.outcome != only:
			continue
		if not _gate_case(first, second, third, row):
			return _fail("qi gate " + row.outcome + "/" + row.warningDirection + ": " + _problem)
		count += 1
		print("QI_GATE_CASE_PASS %s %s" % [row.outcome, row.warningDirection])
	print("NONCOMBAT_QI_GATE_OUTCOMES_PASS cases=%d public=true replay=true" % count)
	quit(0)

func _gate_case(first: Dictionary, second: Dictionary, third: Dictionary,
		row: Dictionary) -> bool:
	var file := "user://tests/qi_gate_outcome_%s_%s_%d.json" % [
		row.outcome, row.warningDirection, Time.get_ticks_usec()]
	var game = Domain.new(Registry.new(), Session.new(file, "slot_2"), "slot_2")
	_quiet_ambient(game)
	if not _open_third_alt(game, first, second, third) or not _reach_gate(game):
		return _bad("elite prefix")
	if game.get_current_card().get("id") != "_warning_ch_qi_100":
		return _bad("gate warning not presented")
	var before: Dictionary = game.state.duplicate(true)
	game = _cold(game, "gate warning")
	if game == null or not game.choose(row.warningDirection, game.issue_choice_token()):
		return _bad("gate warning choice")
	var request: Dictionary = game.battle_request()
	if request.is_empty() or request.sourceCardId != "ch_qi_100" \
			or not _expect(game.state.resources.spiritStone - before.resources.spiritStone,
				row.afterWarning.resources.spiritStone - row.before.resources.spiritStone,
				"gate preparation stones") \
			or not _expect(game.state.attributes.health - before.attributes.health,
				row.afterWarning.attributes.health - row.before.attributes.health,
				"gate preparation health"):
		return _bad("gate pending differs: " + _problem)
	game = _cold(game, "gate pending")
	if game == null or not game.submit_battle_result(_result(request, row.outcome)):
		return _bad("gate terminal rejected: " + game.flow_failure_reason())
	if game.state.phase != "BATTLE_RESULT_PENDING" \
			or not _expect(game.get_current_card(), row.resultCard,
				"gate result card") \
			or not _relative_effects(before, game.state, row.before, row.after,
				"gate outcome"):
		return _bad("gate result differs: " + _problem)
	game = _cold(game, "gate result")
	if game == null:
		return false
	var choice := "left" if row.outcome == "victory" else "down"
	if not game.choose(choice, game.issue_choice_token()):
		return _bad("gate result acknowledgement")
	return _cold(game, "gate acknowledgement") != null

func _relative_effects(before: Dictionary, after: Dictionary,
		source_before: Dictionary, source_after: Dictionary, label: String) -> bool:
	if int(after.turn) - int(before.turn) != int(source_after.turn) - int(source_before.turn) \
			or after.realm != ("foundation" if after.battleResultHistory.back().result.outcome == "victory" else "qi"):
		return _bad(label + "/turn or realm")
	for field in ["maxHealth", "maxDaoHeart"]:
		if not _expect(int(after[field]) - int(before[field]),
				int(source_after[field]) - int(source_before[field]), label + "/" + field):
			return false
	for field in ["resources", "attributes"]:
		for key in source_before[field]:
			if source_before[field][key] is int or source_before[field][key] is float:
				if not _expect(int(after[field].get(key, 0)) - int(before[field].get(key, 0)),
						int(source_after[field][key]) - int(source_before[field][key]),
						label + "/" + field + "/" + key):
					return false
	return true
