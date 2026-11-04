extends "res://tests/noncombat_bazaar_vendor.gd"


func _run() -> void:
	var game = Domain.new(Registry.new(), null, "slot_3")
	game._market_flow.roll_override = 0.0
	game._destiny_wheel_flow.roll_override = 0.0
	game._ripple_flow.roll_override = 0.0
	if not game.start("sword") or not _reach_bazaar(game) \
			or not game.choose("left", game.issue_choice_token()) \
			or not game.perform_vendor_action("ask_luo", game.issue_choice_token()) \
			or not game.close_vendor(game.issue_choice_token()) \
			or not game.choose("right", game.issue_choice_token()) \
			or not game.resume_flow() or game.state.get("phase") != "RIPPLE_PENDING":
		return _fail("source ripple choice was unreachable")
	var candidate: Dictionary = game.state.duplicate(true)
	candidate.path = "body"
	candidate.realm = "golden"
	candidate.attributes.health = 4
	var replay = Domain.new(Registry.new(), null, "slot_3")
	if not replay.start("sword"):
		return _fail("legacy replay opening failed")
	replay.state = candidate.duplicate(true)
	replay._current_card_id = String(candidate.currentCardId)
	replay._passive_regen_extension_activation_index = int(
		candidate.runClock.decisionIndex) + 2
	if not replay.choose("right", replay.issue_choice_token()) \
			or int(replay.state.attributes.health) != 4:
		return _fail("legacy ripple replay gained new turn regeneration")
	game.state = candidate
	if not game.choose("right", game.issue_choice_token()):
		return _fail("ripple choice rejected: " + game.flow_failure_reason())
	if int(game.state.attributes.health) != 5:
		return _fail("ripple choice skipped body turn regeneration: %s" %
			game.state.attributes.health)
	print("NONCOMBAT_PATH_SKILL_RIPPLE_REGEN_PASS health=4>5 legacy=4")
	quit(0)
