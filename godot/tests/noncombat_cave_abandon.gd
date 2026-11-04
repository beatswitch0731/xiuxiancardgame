extends "res://tests/noncombat_cave_entry.gd"

func _run() -> void:
	var path := "user://tests/cave_abandon_%d.json" % Time.get_ticks_usec()
	var game = Domain.new(Registry.new(), RunSession.new(path, "slot_3"), "slot_3")
	_set_zero_rolls(game)
	if not _reach_decision27(game):
		return _fail("abandon route did not reach the cave draw")
	game._normal_roll_override = CAVE_ROLL
	if not game.resume_flow() or game.get_current_card().get("id") != "q_cave" \
			or not game.choose("right", game.issue_choice_token()) or not _reopen(game):
		return _fail("abandon route did not enter and restore the cave")
	var before: Dictionary = game.state.duplicate(true)
	var token: int = game.issue_choice_token()
	var ui: Control = load("res://scenes/noncombat_opening.tscn").instantiate()
	ui.save_path = ""
	root.add_child(ui)
	await process_frame
	ui.opening = game
	ui._render()
	var exit_button: Button = ui.choice_row.get_node_or_null("DungeonExit")
	if exit_button == null or exit_button.disabled:
		return _fail("desktop cave exit action was not visible")
	exit_button.pressed.emit()
	await process_frame
	var after: Dictionary = game.state
	var oracle: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(
		"res://tests/fixtures/cave_mist_source.json"))
	var source: Dictionary = oracle.get("abandoned", {})
	var receipt: Dictionary = after.get("dungeonOutcomeReceipts", [])[0]
	var source_receipt: Dictionary = source.get("dungeonOutcomeReceipts", [])[0]
	if after.get("phase") != "FLOW_PENDING" \
			or after.get("dungeonRun") != null or after.get("dungeon") != null \
			or after.get("runClock", {}).get("decisionIndex") != before.get(
				"runClock", {}).get("decisionIndex") \
			or not _same(after.get("attributes"), before.get("attributes")) \
			or not _same(after.get("resources"), before.get("resources")) \
			or after.get("dungeonActionHistory", []).size() != 1 \
			or receipt.get("outcome") != source_receipt.get("outcome") \
			or receipt.get("sourceCardId") != source_receipt.get("sourceCardId") \
			or receipt.get("sourceDecisionIndex") != before.get(
				"dungeonRun", {}).get("sourceDecisionIndex") \
			or receipt.get("settledDecisionIndex") != before.get(
				"runClock", {}).get("decisionIndex") \
			or after.get("storyThreadState", {}).get("threads", {}).get(
				"mist_valley", {}).get("status") == "active":
		return _fail("abandon receipt, clock, or mist gate differs from browser")
	if game.abandon_dungeon(token):
		return _fail("abandon duplicated")
	if not _reopen(game):
		return _fail("abandon failed strict cold restore")
	if not game.resume_flow() or not _reopen(game):
		return _fail("abandoned run did not continue after cold restore")
	print("NONCOMBAT_CAVE_ABANDON_PASS receipt=true clock=true mist_gate=true replay=true ui=true")
	quit(0)
