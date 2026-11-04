extends "res://tests/noncombat_qi_gate_arrival.gd"

func _run() -> void:
	var first: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	var second: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SECOND_FIXTURE))
	var third: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(THIRD_FIXTURE))
	var file := "user://tests/choice_echo_public_seed_%d.json" % Time.get_ticks_usec()
	var game = Domain.new(Registry.new(), Session.new(file, "slot_2"), "slot_2")
	_quiet_ambient(game)
	if not _open_third_alt(game, first, second, third) or not _reach_gate(game) \
			or not game.choose("left", game.issue_choice_token()):
		return _fail("public qi gate prefix failed: " + _problem)
	var request: Dictionary = game.battle_request()
	if request.is_empty() or not game.submit_battle_result(_result(request, "victory")) \
			or not game.choose("left", game.issue_choice_token()) \
			or game.get_current_card().get("id") != "epiphany_foundation" \
			or not game.choose("left", game.issue_choice_token()):
		return _fail("public foundation entry failed")
	if game.state.get("choiceEchoes", []).is_empty():
		return _fail("public mentor route planted no echo")
	for step in 80:
		if game.state.phase == "FLOW_PENDING" and not game.resume_flow():
			return _fail("source flow stopped at %d: %s" % [step,
				game.flow_failure_reason()])
		if game.state.phase == "BATTLE_PENDING":
			var battle: Dictionary = game.battle_request()
			if battle.is_empty() or not game.submit_battle_result(_result(battle, "victory")):
				return _fail("source battle return stopped at %d" % step)
			continue
		var card: Dictionary = game.get_current_card()
		var first_echo: Dictionary = game.state.get("choiceEchoes", [])[0]
		if int(game.state.get("turn", 0)) >= int(first_echo.get("turn", 0)) + 15 \
				and game.state.get("currentLocation") != first_echo.get(
					"echoConditions", {}).get("location"):
			if first_echo.get("triggered") != false:
				return _fail("generic echo ignored its source location condition")
			var saved: Dictionary = game.state.duplicate(true)
			var cold_seed = _cold(game, "due seed at another location")
			if cold_seed == null or not _same(cold_seed.state, saved):
				return _fail("public echo seed did not strictly reload: " + _problem)
			print("NONCOMBAT_CHOICE_ECHO_PUBLIC_SEED_PASS turn=%d location_guard=true disk=true" % [
				int(saved.turn)])
			quit(0)
			return
		if card.get("type") == "CHOICE_ECHO":
			if game.state.phase != "CHOICE_ECHO_PENDING" \
					or card.get("npcId") != "bai_ren" \
					or not game.state.get("choiceEchoes", []).any(func(row: Variant) -> bool:
						return row is Dictionary and row.get("triggered") == true):
				return _fail("source echo card did not match planted mentor seed")
			var pending: Dictionary = game.state.duplicate(true)
			var cold = _cold(game, "echo pending")
			if cold == null or not _same(cold.state, pending) \
					or not cold.choose("left", cold.issue_choice_token()):
				return _fail("echo pending cold replay or choice failed: " + _problem)
			var settled: Dictionary = cold.state.duplicate(true)
			var settled_cold = _cold(cold, "echo chosen")
			if settled_cold == null or not _same(settled_cold.state, settled):
				return _fail("echo choice strict disk replay failed: " + _problem)
			print("NONCOMBAT_CHOICE_ECHO_NATURAL_PASS turn=%d disk=true" % [
				int(settled.turn)])
			quit(0)
			return
		var direction := "right" if game.state.phase in ["COMBAT_HANDOFF",
			"MARKET_PENDING", "FIRST_SESSION_ROUTE_PENDING", "NARRATIVE_RESULT_PENDING"] \
			else "left"
		if not game.can_choose_direction(direction):
			for fallback in ["left", "right", "down", "up"]:
				if game.can_choose_direction(fallback):
					direction = fallback
					break
		if not game.can_choose_direction(direction) or not game.choose(
				direction, game.issue_choice_token()):
			return _fail("source continuation stopped at %d %s/%s: %s; turn=%s location=%s echoes=%s" % [
				step, game.state.phase, card.get("id"), game.flow_failure_reason(),
				game.state.get("turn"), game.state.get("currentLocation"),
				game.state.get("choiceEchoes")])
	return _fail("planted echo did not reach due check within 80 public choices: %s" % [
		game.state.get("choiceEchoes")])
