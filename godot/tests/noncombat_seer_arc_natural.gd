extends "res://tests/noncombat_foundation_shop_natural.gd"

func _fixed_roll() -> float:
	return 0.39

func _iteration_limit() -> int:
	return 240

func _target_card_id() -> String:
	return "_warning_ch_foundation_100"

func _verify_shop_natural(game: RefCounted, path: String) -> void:
	# NarrativeLedger cooldown changes the ordinary-card sequence before this
	# gate; the public route now reaches it with ten revelation points.
	if int(game.state.get("seerArcState", {}).get("revelation", 0)) != 10:
		return _fail("public foundation gate seer progression changed: revelation=%d turn=%d card=%s" % [
			int(game.state.get("seerArcState", {}).get("revelation", 0)),
			int(game.state.get("turn", 0)), String(game.get_current_card().get("id", ""))])
	if not game.choose("right", game.issue_choice_token()):
		return _fail("foundation gate warning choice failed")
	var gate_request: Dictionary = game.battle_request()
	if gate_request.get("sourceCardId") != "ch_foundation_100" \
			or not game.submit_battle_result(_result_for(gate_request, "victory")) \
			or not game.choose("left", game.issue_choice_token()) \
			or not game.choose("left", game.issue_choice_token()):
		return _fail("foundation gate victory did not reach golden")
	for step in 120:
		if game.state.phase == "FLOW_PENDING" and not game.resume_flow():
			return _fail("golden seer route stopped: " + game.flow_failure_reason())
		if game.state.phase == "VENDOR_OPEN":
			if not game.close_vendor(game.issue_choice_token()):
				return _fail("golden vendor close failed")
			continue
		var card: Dictionary = game.get_current_card()
		if card.get("id") == "seer_tianji_laoren_stage_REVELATION":
			return _verify_seer_card(game, path)
		if game.state.phase == "BATTLE_PENDING":
			var request: Dictionary = game.battle_request()
			if request.is_empty() or not game.submit_battle_result(
					_result_for(request, "victory")):
				return _fail("golden battle return failed")
			continue
		var direction := "right" if game.state.phase in ["COMBAT_HANDOFF",
			"MARKET_PENDING", "FIRST_SESSION_ROUTE_PENDING"] else "left"
		if not game.can_choose_direction(direction):
			for fallback in ["left", "right", "down", "up"]:
				if game.can_choose_direction(fallback):
					direction = fallback
					break
		if not game.can_choose_direction(direction) or not game.choose(
				direction, game.issue_choice_token()):
			return _fail("golden seer choice failed at " + String(card.get("id")))
	return _fail("golden public route did not surface seer stage")

func _verify_seer_card(game: RefCounted, path: String) -> void:
	var pending: Dictionary = game.state.duplicate(true)
	if game.state.phase != "SEER_PENDING" \
			or int(game.state.get("seerArcState", {}).get("revelation", 0)) < 20:
		return _fail("public seer progression was not queued")
	var cold = _shop_branch(FileAccess.get_file_as_bytes(game._store.v2_path), path)
	if cold == null or not _same(cold.state, pending) \
			or cold.get_current_card().get("id") != "seer_tianji_laoren_stage_REVELATION":
		return _fail("public seer pending failed strict cold replay")
	if not cold.choose("left", cold.issue_choice_token()):
		return _fail("public seer choice failed")
	var chosen: Dictionary = cold.state.duplicate(true)
	var chosen_cold = _shop_branch(FileAccess.get_file_as_bytes(
		cold._store.v2_path), path)
	if chosen_cold == null or not _same(chosen_cold.state, chosen):
		return _fail("public seer choice failed strict cold replay")
	var response_ok: bool = chosen_cold.choose("left", chosen_cold.issue_choice_token())
	var response_events: Array = chosen_cold.state.get("seerArcState", {}).get(
		"eventsTriggered", [])
	var wheel_due: bool = chosen_cold.state.phase == "DESTINY_WHEEL_PENDING" \
		and chosen_cold.get_current_card().get("id") == "destiny_wheel" \
		and int(chosen_cold.state.get("destinyWheelTicks", 0)) % 10 == 0
	if not response_ok or chosen_cold.state.phase != "FLOW_PENDING" \
			and not wheel_due \
			or response_events.count("seer_tianji_laoren_stage_REVELATION") != 1:
		return _fail("public seer response did not acknowledge once: choose=%s phase=%s card=%s events=%s" % [
			str(response_ok), str(chosen_cold.state.phase),
			str(chosen_cold.state.get("currentCardId", "")), str(response_events)])
	print("NONCOMBAT_SEER_ARC_NATURAL_PASS pending=true chosen=true response=true replay=true")
	quit(0)
