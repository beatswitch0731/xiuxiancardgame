extends "res://tests/noncombat_mentor_arc.gd"

func _run() -> void:
	seed(14)
	var path := "user://tests/ally_arc_natural_%d.json" % Time.get_ticks_usec()
	var game = Domain.new(Registry.new(), RunSession.new(path, "slot_3"), "slot_3")
	game._market_flow.roll_override = 0.0
	game._destiny_wheel_flow.roll_override = 0.0
	game._ripple_flow.roll_override = 0.0
	game._hint_flow.roll_override = 0.0
	if not game.start("sword"):
		return _fail("public sword start failed")
	for step in 5:
		if not game.choose("left", game.issue_choice_token()):
			return _fail("public tutorial failed")
	for action in ["right", "left"]:
		if not game.choose(action, game.issue_choice_token()):
			return _fail("public encounter prefix failed")
	if not game.resume_flow() or not game.choose("left", game.issue_choice_token()) \
			or not game.choose("right", game.issue_choice_token()) \
			or not game.resume_flow() \
			or game.get_current_card().get("id") != "q_whiteFox_quest" \
			or not game.choose("left", game.issue_choice_token()):
		return _fail("public bad-karma fox choice failed")
	for step in 60:
		if game.state.phase == "FLOW_PENDING" and not game.resume_flow():
			return _fail("public arc route stopped: " + game.flow_failure_reason())
		if game.state.phase == "VENDOR_OPEN":
			if not game.close_vendor(game.issue_choice_token()):
				return _fail("public vendor close failed")
			continue
		var card: Dictionary = game.get_current_card()
		if card.get("type") == "ALLY_ARC":
			if card.get("id") != "ally_xuesha_laozu_stage_RECOGNITION" \
					or int(game.state.get("allyArcState", {}).get("alignment", 0)) != 23:
				return _fail("public karma route surfaced the wrong ally stage")
			var pending: Dictionary = game.state.duplicate(true)
			var cold = Domain.new(Registry.new(), RunSession.new(path, "slot_3"), "slot_3")
			cold._market_flow.roll_override = 0.0
			cold._destiny_wheel_flow.roll_override = 0.0
			cold._ripple_flow.roll_override = 0.0
			cold._hint_flow.roll_override = 0.0
			if not cold.restore() or not _same(cold.state, pending) \
					or cold.get_current_card().get("id") != card.id:
				return _fail("pending ally card failed strict cold replay")
			if not cold.choose("left", cold.issue_choice_token()):
				return _fail("public ally choice failed")
			var chosen: Dictionary = cold.state.duplicate(true)
			var chosen_cold = Domain.new(Registry.new(), RunSession.new(path, "slot_3"), "slot_3")
			chosen_cold._market_flow.roll_override = 0.0
			chosen_cold._destiny_wheel_flow.roll_override = 0.0
			chosen_cold._ripple_flow.roll_override = 0.0
			chosen_cold._hint_flow.roll_override = 0.0
			if not chosen_cold.restore() or not _same(chosen_cold.state, chosen):
				return _fail("chosen ally card failed strict cold replay")
			if not chosen_cold.choose("left", chosen_cold.issue_choice_token()) \
					or chosen_cold.state.phase != "FLOW_PENDING" \
					or chosen_cold.state.get("allyArcState", {}).get(
						"eventsTriggered", []).count(card.id) != 1:
				return _fail("public ally response did not acknowledge once")
			print("NONCOMBAT_ALLY_ARC_NATURAL_PASS card=", card.id,
				" pending=true chosen=true response=true replay=true")
			quit(0)
			return
		var direction := "right" if card.get("id") == "kx_ch_hoarded_manual" \
			or String(card.get("id", "")).begins_with("karma_ripple:") \
				and int(game.state.get("allyArcState", {}).get("alignment", 0)) >= 15 \
			or game.state.phase in ["COMBAT_HANDOFF", "WARNING_PENDING",
				"MARKET_PENDING", "FIRST_SESSION_ROUTE_PENDING"] else "left"
		if not game.can_choose_direction(direction):
			for fallback in ["left", "right", "down", "up"]:
				if game.can_choose_direction(fallback):
					direction = fallback
					break
		if not game.can_choose_direction(direction) or not game.choose(
				direction, game.issue_choice_token()):
			return _fail("public continuation failed at %s/%s" % [
				String(card.get("id")), direction])
	return _fail("public route did not surface an ally card")
