extends "res://tests/noncombat_cadence_second_entry.gd"


func _run() -> void:
	var first: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	var second: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SECOND_FIXTURE))
	if second.get("publicInput") != true or second.get("rows", []).size() != 4:
		return _fail("second cadence source matrix missing")
	var only := ""
	var args := OS.get_cmdline_user_args()
	if args.size() == 2 and args[0] == "--case":
		only = args[1]
	for source in second.pins:
		var actual := FileAccess.get_sha256(ProjectSettings.globalize_path("res://").path_join("../" + source))
		if actual != second.pins[source]:
			return _fail("second cadence source oracle drift: " + source)
	var count := 0
	for row in second.rows:
		if not only.is_empty() and row.outcome != only:
			continue
		if not _case_second(first, second, row):
			return _fail(row.outcome + ": " + _problem)
		count += 1
		print("CADENCE_SECOND_CASE_PASS " + row.outcome)
	print("NONCOMBAT_CADENCE_SECOND_OUTCOMES_PASS natural=true source=true outcomes=%d replay=true" % count)
	quit(0)


func _case_second(first: Dictionary, second: Dictionary, row: Dictionary) -> bool:
	var file := "user://tests/cadence_second_%s_%d.json" % [row.outcome, Time.get_ticks_usec()]
	var game = Domain.new(Registry.new(), Session.new(file, "slot_2"), "slot_2")
	_quiet_ambient(game)
	if not _open_second(game, first, second):
		return false
	if not _snapshot_second(game.state, row.offered, "second offered"):
		return false
	game = _cold(game, "second offered")
	if game == null:
		return false
	if not game.choose("right" if row.outcome == "avoided" else "left", game.issue_choice_token()):
		return _bad("second cadence offer choice")
	if row.outcome == "avoided":
		if not _snapshot_second(game.state, row.after, "second avoided"):
			return false
		game = _cold(game, "second avoided")
		if game == null or game.state.phase != "NARRATIVE_RESULT_PENDING":
			return _bad("second avoided source response was not persisted")
		var source_card: Dictionary = row.nextCard.duplicate(true)
		var actual_card: Dictionary = game.get_current_card()
		for choice in source_card.get("choices", {}).values():
			if choice is Dictionary:
				choice.erase("_choiceDirection")
		source_card.erase("choiceContractVersion")
		source_card.erase("choiceClassification")
		if not _expect(actual_card, source_card, "second avoided response"):
			return false
		if not game.choose("left", game.issue_choice_token()):
			return _bad("second avoided response acknowledgement")
		game = _cold(game, "second avoided acknowledgement")
		return game != null and game.state.phase == "FLOW_PENDING"
	if not _snapshot_second(game.state, row.afterChoice, "second warning checkpoint") \
			or not _expect(game.get_current_card(), _warning_projection(row.warning), "second warning card"):
		return false
	game = _cold(game, "second warning")
	if game == null or not game.choose("left", game.issue_choice_token()):
		return _bad("second warning preparation")
	var request: Dictionary = game.battle_request()
	if request.is_empty() or request.sourceCardId != second.sourceCardId \
			or not _snapshot_second(game.state, row.afterWarning, "second pending battle"):
		return _bad("second battle request or pending state: " + _problem)
	game = _cold(game, "second pending battle")
	if game == null or not _expect(game.battle_request(), request, "second restored request"):
		return false
	var result := _result(request, row.outcome)
	if not game.submit_battle_result(result):
		return _bad("second terminal rejected: " + game.flow_failure_reason())
	if not _snapshot_second(game.state, row.after, "second terminal") \
			or not _expect(game.get_current_card(), row.resultCard, "second result card") \
			or game.state.battleResultHistory.size() != 3:
		return _bad("second terminal differs: " + _problem)
	game = _cold(game, "second result")
	if game == null or not game.choose(row.acknowledgementDirection, game.issue_choice_token()):
		return _bad("second result acknowledgement")
	game = _cold(game, "second acknowledgement")
	if game == null or not game.resume_flow():
		return _bad("second result continuation")
	if not _snapshot_second(game.state, row.afterAcknowledgement, "second after acknowledgement") \
			or not _expect(_next_projection(game.get_current_card(), row.nextCard),
				_canonical(row.nextCard), "second next card"):
		return false
	return _cold(game, "second next card") != null


func _next_projection(card: Dictionary, source: Dictionary) -> Dictionary:
	var projected: Dictionary = _canonical(card)
	# Godot's mentor presenter mounts the portrait path on the card; the
	# browser mentor card resolves the same portrait outside its source card.
	if String(source.get("id", "")).begins_with("mentor_") and not source.has("sceneImage"):
		projected.erase("sceneImage")
	return projected


func _snapshot_second(actual: Dictionary, source: Dictionary, label: String) -> bool:
	# Browser wheel actions do not enter top-level choiceHistory; Godot keeps
	# them there for strict replay, without advancing the decision clock.
	var projected_actual := actual.duplicate(true)
	projected_actual.choiceHistory = actual.choiceHistory.filter(
		func(entry: Dictionary) -> bool: return entry.get("cardId") != "destiny_wheel")
	var projected := source.duplicate(true)
	for key in source.get("flags", {}):
		if String(key).begins_with("causal:") or String(key).begins_with("choice:") \
				or key in ["quest_white_fox_line_active", "quest_white_fox_line_step"]:
			continue
		if not _expect(actual.get("flags", {}).get(key), source.flags[key], label + "/flag/" + key):
			return false
		projected.flags.erase(key)
	return _snapshot(projected_actual, projected, label)
