extends "res://tests/noncombat_regulated_replay.gd"

# Read-only route probe: defer the first Luo inquiry and watch later natural
# bazaar/official openings. It never inserts an authored card or edits a clock.
func _run() -> void:
	var path := "user://tests/causal_reachable_%d.json" % Time.get_ticks_usec()
	var game = Domain.new(Registry.new(), RunSession.new(path, "slot_3"), "slot_3")
	_set_zero_rolls(game)
	if not game.start("sword") or not _reach_bazaar(game) \
			or not game.choose("right", game.issue_choice_token()):
		return _fail("late-inquiry route could not skip first bazaar")
	var fact_id := "fact:0:rumor_rusted_sword_origin"
	var events: Array[String] = []
	for step in 80:
		var phase := String(game.state.get("phase", ""))
		var card_id := String(game.get_current_card().get("id", ""))
		var index := int(game.state.get("runClock", {}).get("decisionIndex", -1))
		var fact: Dictionary = game.state.get("noncombatFlow", {}).get(
			"spineFacts", {}).get(fact_id, {})
		if phase == "FLOW_PENDING":
			if not game.resume_flow():
				events.append("stopped:resume:%d:%s" % [index, game.flow_failure_reason()])
				break
			continue
		if phase == "MARKET_PENDING" and card_id == "bazaar_encounter":
			events.append("bazaar:%d" % index)
			if fact.is_empty():
				if not game.choose("left", game.issue_choice_token()) \
						or not game.perform_vendor_action("ask_luo",
							game.issue_choice_token()):
					return _fail("later natural bazaar could not produce source fact")
				events.append("asked:%d" % int(game.state.get("noncombatFlow", {}).get(
					"spineFacts", {}).get(fact_id, {}).get("createdDecisionIndex", -1)))
				game._normal_roll_override = 0.20
				if not game.close_vendor(game.issue_choice_token()):
					return _fail("later natural bazaar could not close")
			else:
				if not game.choose("right", game.issue_choice_token()):
					return _fail("later natural bazaar could not skip")
			continue
		if phase == "SHOP_PENDING":
			var projected := index + 1
			events.append("shop:%s:%d:fact:%s" % [card_id, projected,
				fact.get("status", "missing")])
			if fact.get("status") == "active" and projected >= int(
					fact.get("createdDecisionIndex", -100)) + 1 \
					and projected <= int(fact.get("createdDecisionIndex", -100)) + 4:
				var pending: Dictionary = game.state.duplicate(true)
				var load_pending = Domain.new(Registry.new(), RunSession.new(
					path, "slot_3"), "slot_3")
				_set_zero_rolls(load_pending)
				if not load_pending.restore() or not _same(load_pending.state, pending):
					return _fail("reachable q_market failed strict pending restore")
				var direction := "left" if card_id == "q_market" else "right"
				if not game.choose(direction, game.issue_choice_token()):
					return _fail("reachable source fact could not enter official venue")
				var open_state: Dictionary = game.state.duplicate(true)
				var action_id := "causal_fact:regulated_rusted_sword_order:" + fact_id
				var offered: Array = game.vendor_actions().filter(func(row: Variant) -> bool:
					return row is Dictionary and row.get("id") == action_id)
				if offered.size() != 1 or offered[0].get("costText") != "12 灵石" \
						or offered[0].get("enabled") != true \
						or not open_state.get("marketState", {}).get(
							"activeSession", {}).get("services", []).any(func(row: Variant) -> bool:
							return row is Dictionary and row.get("actionId") == action_id \
								and row.get("available") == true):
					return _fail("reachable official quote lost live source service")
				var load_open = Domain.new(Registry.new(), RunSession.new(path, "slot_3"), "slot_3")
				_set_zero_rolls(load_open)
				if not load_open.restore() or not _same(load_open.state, open_state):
					return _fail("reachable live quote failed strict restore")
				print("NONCOMBAT_CAUSAL_REACHABILITY_FOUND " + " ".join(events)
					+ " pending_replay=true open_replay=true")
				quit(0)
				return
		if phase == "VENDOR_OPEN":
			if not game.close_vendor(game.issue_choice_token()):
				return _fail("natural venue could not close")
			continue
		if phase == "BATTLE_PENDING":
			events.append("stopped:battle:%d" % index)
			break
		var direction := ""
		for candidate in ["right", "left", "down", "up"]:
			if game.can_choose_direction(candidate):
				direction = candidate
				break
		if direction.is_empty() or not game.choose(direction, game.issue_choice_token()):
			events.append("stopped:choice:%d:%s:%s" % [index, phase, card_id])
			break
	return _fail("natural legal order window was not found: " + " ".join(events))
