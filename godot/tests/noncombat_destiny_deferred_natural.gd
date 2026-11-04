extends "res://tests/noncombat_qi_gate_arrival.gd"

const MAX_CHOICES := 230

func _run() -> void:
	var first: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	var second: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SECOND_FIXTURE))
	var third: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(THIRD_FIXTURE))
	var file := "user://tests/destiny_deferred_natural_%d.json" % Time.get_ticks_usec()
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
	var hidden_trigger := -1
	for step in MAX_CHOICES:
		if game.state.has("pendingDestinyWheel") \
				and game.state.get("phase") != "DESTINY_WHEEL_PENDING":
			hidden_trigger = int(game.state.pendingDestinyWheel.triggerDecisionIndex)
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
		if card.get("id") == "destiny_wheel" and hidden_trigger >= 0 \
				and game.state.get("pendingDestinyWheel", {}).get(
					"triggerDecisionIndex") == hidden_trigger:
			if game.state.get("wheelReturn", {}).get(
					"phase") != "FLOW_PENDING":
				return _fail("dungeon-covered wheel lost its pending state or flow return")
			var pending: Dictionary = game.state.duplicate(true)
			var cold = _cold(game, "deferred wheel pending")
			if cold == null or not _same(cold.state, pending) \
					or not cold.choose("left", cold.issue_choice_token()) \
					or cold.state.has("pendingDestinyWheel"):
				return _fail("deferred wheel pending or flip failed: " + _problem)
			var resolved: Dictionary = cold.state.duplicate(true)
			var resolved_cold = _cold(cold, "deferred wheel flipped")
			if resolved_cold == null or not _same(resolved_cold.state, resolved):
				return _fail("deferred wheel flip failed strict disk replay: " + _problem)
			print("NONCOMBAT_DESTINY_DEFERRED_NATURAL_PASS hidden=true shown=true flip=true disk=true")
			quit(0)
			return
		var direction := "right" if game.state.phase in ["COMBAT_HANDOFF",
			"MARKET_PENDING", "FIRST_SESSION_ROUTE_PENDING", "NARRATIVE_RESULT_PENDING"] \
			or card.get("id") == "ir_truth" else "left"
		if not game.can_choose_direction(direction):
			for fallback in ["left", "right", "down", "up"]:
				if game.can_choose_direction(fallback):
					direction = fallback
					break
		if not game.can_choose_direction(direction) or not game.choose(
				direction, game.issue_choice_token()):
			return _fail("source continuation stopped at %d %s/%s: %s" % [
				step, game.state.phase, card.get("id"), game.flow_failure_reason()])
	return _fail("covered wheel did not surface within %d source choices; hidden=%d phase=%s card=%s decision=%d" % [
		MAX_CHOICES,
		hidden_trigger, game.state.get("phase"), game.state.get("currentCardId"),
		int(game.state.get("runClock", {}).get("decisionIndex", -1))])
