extends "res://tests/noncombat_battle_return.gd"

# N5f acceptance entry. Kept outside the release suite until the new producer
# exists: a second STORY battle does not consume the next catalog patrol slot.
func _run() -> void:
	var file := "user://tests/cadence_entry_%d.json" % Time.get_ticks_usec()
	var game = Domain.new(Registry.new(), Session.new(file, "slot_2"), "slot_2")
	game._ripple_flow.roll_override = 0.999
	game._hint_flow.roll_override = 0.0
	game._market_flow.roll_override = 0.0
	if not game.start("sword"):
		return _fail("cadence opening")
	for direction in ["right", "right", "left", "left", "left"]:
		if not game.choose(direction, game.issue_choice_token()):
			return _fail("cadence teaching entry")
	var victories := 0
	for step in 25:
		if game.state.phase == "BATTLE_PENDING":
			if not game.submit_battle_result(_result(game.battle_request(), "victory")):
				return _fail("cadence preceding victory")
			victories += 1
		elif game.state.phase == "FLOW_PENDING":
			if not game.resume_flow():
				return _fail("cadence continuation failed: " + game.flow_failure_reason())
		elif game.state.phase in ["FIRST_SESSION_ROUTE_PENDING", "WARNING_PENDING",
				"BATTLE_RESULT_PENDING", "MILESTONE_PENDING"]:
			if not game.choose("left", game.issue_choice_token()):
				return _fail("cadence preceding choice: " + str(game.state.currentCardId))
		else:
			break
		if int(game.state.turn) == 11 and game.state.phase == "FLOW_PENDING":
			if not game.resume_flow():
				return _fail("cadence due flow rejected")
			break
	if victories != 2 or game.state.deck.size() != 8 or game.state.turn != 11:
		return _fail("cadence natural prefix did not retain two victories/eight cards")
	if game.state.currentCardId != "encounter_card_enc_patrol_qi_mountain_shadow":
		return _fail("P88 due catalog encounter not produced; actual=" + str(game.state.currentCardId))
	var director: Dictionary = game.state.noncombatFlow.encounterDirectorState
	if director.pending.get("reason") != "cadence" or director.pending.get("scheduledDecision") != 12 \
			or director.realmProgress.qi.seenCounts.ordinary != 2 \
			or director.realmProgress.qi.resolvedIds != ["enc_trial_sword_swift"]:
		return _fail("cadence producer reset historical director progress")
	print("NONCOMBAT_CADENCE_ENTRY_PASS natural=true current_deck=true cumulative=true")
	quit(0)
