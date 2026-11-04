extends "res://tests/noncombat_qi_gate_arrival.gd"

func _run() -> void:
	var first: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	var second: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SECOND_FIXTURE))
	var third: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(THIRD_FIXTURE))
	var file := "user://tests/scene_layer_natural_%d.json" % Time.get_ticks_usec()
	var game = Domain.new(Registry.new(), Session.new(file, "slot_2"), "slot_2")
	_quiet_ambient(game)
	if not _open_third_alt(game, first, second, third) or not _reach_gate(game) \
			or not game.choose("left", game.issue_choice_token()):
		return _fail("public qi gate route failed: " + _problem)
	var gate_request: Dictionary = game.battle_request()
	if gate_request.get("sourceCardId") != "ch_qi_100" \
			or not game.submit_battle_result(_result(gate_request, "victory")) \
			or not game.choose("left", game.issue_choice_token()) \
			or game.get_current_card().get("id") != "epiphany_foundation" \
			or not game.choose("left", game.issue_choice_token()) \
			or game.state.get("realm") != "foundation" \
			or game.state.get("currentLocation") != "宗门":
		return _fail("public foundation arrival did not return to the sect")
	for step in 200:
		if game.state.phase == "REBIRTH_PENDING":
			if not game.select_rebirth_path("sword") \
					or not game.choose("down", game.issue_choice_token()):
				return _fail("source rebirth route stopped at %d" % step)
			continue
		if game.state.phase == "CAMP_TARGET_PENDING":
			if not game.cancel_camp_target(game.issue_choice_token()):
				return _fail("source camp target cancellation stopped at %d" % step)
			continue
		if game.state.phase == "VENDOR_OPEN":
			if not game.close_vendor(game.issue_choice_token()):
				return _fail("source vendor close stopped at %d" % step)
			continue
		if game.state.phase == "FLOW_PENDING" and not game.resume_flow():
			return _fail("source flow stopped at %d: %s" % [step,
				game.flow_failure_reason()])
		if game.state.phase == "BATTLE_PENDING":
			var next_battle: Dictionary = game.battle_request()
			if next_battle.is_empty() or not game.submit_battle_result(
					_result(next_battle, "victory")):
				return _fail("source battle return stopped at %d" % step)
			continue
		var card: Dictionary = game.get_current_card()
		if card.get("id") == "loc_sect_deep":
			if game.state.get("realm") != "foundation" \
					or game.state.get("currentLocation") != "宗门" \
					or int(game.state.get("locationStates", {}).get(
						"宗门", {}).get("visits", 0)) != 8:
				return _fail("deep sect card appeared outside eighth visit")
			var pending: Dictionary = game.state.duplicate(true)
			var cold = _cold(game, "deep sect pending")
			if cold == null or not _same(cold.state, pending) \
					or not cold.choose("left", cold.issue_choice_token()) \
					or not cold.state.get("clues", []).any(func(row: Variant) -> bool:
						return row is Dictionary and row.get("id") == "sect_alchemy_secret"):
				return _fail("deep sect source clue or cold pending failed: " + _problem)
			var resolved: Dictionary = cold.state.duplicate(true)
			var resolved_cold = _cold(cold, "deep sect chosen")
			if resolved_cold == null or not _same(resolved_cold.state, resolved):
				return _fail("deep sect chosen strict disk replay failed: " + _problem)
			print("NONCOMBAT_SCENE_LAYER_NATURAL_PASS visit=8 clue=true disk=true")
			quit(0)
			return
		var direction := "right" if game.state.phase in ["COMBAT_HANDOFF",
			"MARKET_PENDING", "FIRST_SESSION_ROUTE_PENDING", "NARRATIVE_RESULT_PENDING"] \
			or card.get("id") == "faction_wumeng_gatekeeper_call" \
			else "left"
		if card.get("id") in ["q_sword_1", "ch_foundation_20"]:
			direction = "right"
		if not game.can_choose_direction(direction):
			for fallback in ["left", "right", "down", "up"]:
				if game.can_choose_direction(fallback):
					direction = fallback
					break
		if not game.can_choose_direction(direction) or not game.choose(
				direction, game.issue_choice_token()):
			return _fail("source continuation stopped at %d %s/%s: %s" % [
				step, game.state.phase, card.get("id"), game.flow_failure_reason()])
	return _fail("deep sect card did not surface within 200 source choices; location=%s sectVisits=%d" % [
		game.state.get("currentLocation"), int(game.state.get("locationStates", {}).get(
			"宗门", {}).get("visits", 0))])
