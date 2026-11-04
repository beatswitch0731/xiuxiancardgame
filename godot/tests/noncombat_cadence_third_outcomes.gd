extends "res://tests/noncombat_cadence_third_entry.gd"


func _run() -> void:
	var first: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	var second: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SECOND_FIXTURE))
	var third: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(THIRD_FIXTURE))
	if third.get("rows", []).size() != 4:
		return _fail("third cadence source matrix missing")
	for source in third.pins:
		var actual := FileAccess.get_sha256(ProjectSettings.globalize_path("res://").path_join("../" + source))
		if actual != third.pins[source]:
			return _fail("third cadence source oracle drift: " + source)
	var count := 0
	var args := OS.get_cmdline_user_args()
	var only := args[1] if args.size() == 2 and args[0] == "--case" else ""
	for row in third.rows:
		if not only.is_empty() and row.outcome != only:
			continue
		if not _case_third(first, second, third, row):
			return _fail(row.outcome + ": " + _problem)
		count += 1
		print("CADENCE_THIRD_CASE_PASS " + row.outcome)
	print("NONCOMBAT_CADENCE_THIRD_OUTCOMES_PASS contracts=%d source_route=true replay=true" % count)
	quit(0)


func _case_third(first: Dictionary, second: Dictionary, third: Dictionary,
		row: Dictionary) -> bool:
	var file := "user://tests/cadence_third_source_%s_%d.json" % [row.outcome, Time.get_ticks_usec()]
	var game = Domain.new(Registry.new(), Session.new(file, "slot_2"), "slot_2")
	_quiet_ambient(game)
	if not _open_third(game, first, second, third):
		return false
	var offered: Dictionary = game.state.duplicate(true)
	game = _cold(game, "third source offer")
	if game == null or not game.choose("right" if row.outcome == "avoided" else "left",
			game.issue_choice_token()):
		return _bad("third source offer choice")
	if row.outcome == "avoided":
		if not _relative_effects(offered, game.state, row.offered, row.after,
				"third source avoided") \
				or not _director_settlement(game.state.noncombatFlow.encounterDirectorState,
					row.after.director) \
				or game.state.phase != "FLOW_PENDING":
			return _bad("third source avoidance differs: " + _problem)
		return _cold(game, "third source avoided") != null
	if not _expect(game.get_current_card(), _warning_projection(row.warning),
			"third source warning"):
		return false
	game = _cold(game, "third source warning")
	if game == null or not game.choose("left", game.issue_choice_token()):
		return _bad("third source warning preparation")
	var request: Dictionary = game.battle_request()
	if request.is_empty() or request.sourceCardId != third.sourceCardId \
			or not _expect(request.playerSnapshot.battleLoadout.deck,
				row.battle.masterDeck, "third source current deck"):
		return _bad("third source battle request differs: " + _problem)
	game = _cold(game, "third source pending battle")
	if game == null or not _expect(game.battle_request(), request, "third source restored request"):
		return false
	if not game.submit_battle_result(_result(request, row.outcome)):
		return _bad("third source terminal rejected: " + game.flow_failure_reason())
	if not _relative_effects(offered, game.state, row.offered, row.after,
			"third source terminal") \
			or not _director_settlement(game.state.noncombatFlow.encounterDirectorState,
				row.after.director) \
			or not _expect(game.get_current_card(), row.resultCard,
				"third source result card"):
		return false
	game = _cold(game, "third source result")
	if game == null or not game.choose(row.acknowledgementDirection,
			game.issue_choice_token()):
		return _bad("third source result acknowledgement")
	return _cold(game, "third source acknowledgement") != null


func _relative_effects(before: Dictionary, after: Dictionary,
		source_before: Dictionary, source_after: Dictionary, label: String) -> bool:
	if int(after.turn) - int(before.turn) != int(source_after.turn) - int(source_before.turn):
		return _bad(label + "/decision tick")
	for field in ["attributes", "resources"]:
		for key in source_before[field]:
			if source_before[field][key] is int or source_before[field][key] is float:
				var expected: float = float(source_after[field][key]) - float(source_before[field][key])
				var actual: float = float(after[field][key]) - float(before[field][key])
				if not _expect(actual, expected, label + "/" + field + "/" + key):
					return false
	for key in ["maxHealth", "maxDaoHeart"]:
		if not _expect(int(after[key]) - int(before[key]),
				int(source_after[key]) - int(source_before[key]), label + "/" + key):
			return false
	return _expect(after.deck, before.deck, label + "/deck unchanged")


func _director_settlement(actual: Dictionary, source: Dictionary) -> bool:
	var event: Dictionary = actual.get("history", []).back().duplicate(true)
	var source_event: Dictionary = source.get("history", []).back().duplicate(true)
	var offset := int(event.get("decision", -1)) - int(source_event.get("decision", -1))
	event.erase("decision")
	source_event.erase("decision")
	return _expect(event, source_event, "third source terminal event") \
		and _expect(actual.get("realmProgress"), source.get("realmProgress"),
			"third source quota") \
		and _expect(int(actual.get("nextDueDecision", -1)) -
			int(source.get("nextDueDecision", -1)), offset,
			"third source next due offset") \
		and _expect(int(actual.get("cooldownUntilDecision", -1)) -
			int(source.get("cooldownUntilDecision", -1)), offset,
			"third source cooldown offset")
