extends "res://tests/noncombat_mentor_arc.gd"

func _run() -> void:
	seed(12345)
	var file := "user://tests/choice_echo_natural_%d.json" % Time.get_ticks_usec()
	var game = Domain.new(Registry.new(), RunSession.new(file, "slot_3"), "slot_3")
	game._market_flow.roll_override = 0.0
	game._destiny_wheel_flow.roll_override = 0.0
	game._ripple_flow.roll_override = 0.0
	game._hint_flow.roll_override = 0.0
	if not _reach_third_chosen(game, "sword") or not game.resume_flow() \
			or game.get_current_card().get("id") != "mentor_bai_ren_stage_INNER_DISCIPLE" \
			or not game.choose("left", game.issue_choice_token()) \
			or not game.choose("left", game.issue_choice_token()):
		return _fail("public mentor seed prefix failed")
	var seed_echo: Dictionary = game.state.get("choiceEchoes", [])[0]
	if seed_echo.get("context", {}).get("location") != game.state.get(
			"currentLocation"):
		return _fail("mentor seed location differed from current location")
	for step in 70:
		if game.state.phase == "FLOW_PENDING" and not game.resume_flow():
			return _fail("source flow stopped at %d: %s" % [step,
				game.flow_failure_reason()])
		if game.state.phase == "VENDOR_OPEN":
			if not game.close_vendor(game.issue_choice_token()):
				return _fail("public vendor would not close")
			continue
		var card: Dictionary = game.get_current_card()
		if card.get("type") == "CHOICE_ECHO":
			var pending: Dictionary = game.state.duplicate(true)
			var cold = Domain.new(Registry.new(), RunSession.new(file, "slot_3"), "slot_3")
			cold._market_flow.roll_override = 0.0
			cold._destiny_wheel_flow.roll_override = 0.0
			cold._ripple_flow.roll_override = 0.0
			cold._hint_flow.roll_override = 0.0
			if not cold.restore() or not _same(cold.state, pending) \
					or not cold.choose("left", cold.issue_choice_token()):
				return _fail("due public echo pending cold replay failed")
			var chosen: Dictionary = cold.state.duplicate(true)
			var chosen_cold = Domain.new(Registry.new(), RunSession.new(file, "slot_3"), "slot_3")
			chosen_cold._market_flow.roll_override = 0.0
			chosen_cold._destiny_wheel_flow.roll_override = 0.0
			chosen_cold._ripple_flow.roll_override = 0.0
			chosen_cold._hint_flow.roll_override = 0.0
			if not chosen_cold.restore() or not _same(chosen_cold.state, chosen):
				return _fail("due public echo chosen cold replay failed")
			print("NONCOMBAT_CHOICE_ECHO_NATURAL_PASS turn=%d disk=true" % [
				int(chosen.turn)])
			quit(0)
			return
		var direction := "right" if card.get("id") == "q_mountain_shadow_approach" \
			or game.state.phase in ["COMBAT_HANDOFF", "MARKET_PENDING",
				"FIRST_SESSION_ROUTE_PENDING", "NARRATIVE_RESULT_PENDING"] else "left"
		if not game.can_choose_direction(direction):
			for fallback in ["left", "right", "down", "up"]:
				if game.can_choose_direction(fallback):
					direction = fallback
					break
		if not game.can_choose_direction(direction) or not game.choose(
				direction, game.issue_choice_token()):
			return _fail("public continuation stopped at %d %s/%s turn=%d location=%s" % [
					step, game.state.phase, card.get("id"), int(game.state.turn),
					String(game.state.get("currentLocation", ""))])
	return _fail("public echo did not surface within 70 source choices")
