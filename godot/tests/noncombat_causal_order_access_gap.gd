extends "res://tests/noncombat_regulated_replay.gd"

func _run() -> void:
	var path := "user://tests/causal_order_replay_%d.json" % Time.get_ticks_usec()
	var store = RunSession.new(path, "slot_3")
	var game = Domain.new(Registry.new(), store, "slot_3")
	_set_zero_rolls(game)
	if not game.start("sword") or not _reach_bazaar(game) \
			or not game.choose("left", game.issue_choice_token()) \
			or not game.perform_vendor_action("ask_luo", game.issue_choice_token()) \
			or not game.close_vendor(game.issue_choice_token()) \
			or not game.choose("right", game.issue_choice_token()) \
			or not game.resume_flow() \
			or not game.choose("right", game.issue_choice_token()) \
			or not game.resume_flow() \
			or not game.choose("left", game.issue_choice_token()) \
			or not game.choose("left", game.issue_choice_token()) \
			or not game.resume_flow() \
			or not game.choose("right", game.issue_choice_token()) \
			or not game.resume_flow() \
			or not game.choose("left", game.issue_choice_token()):
		return _fail("natural causal order route halted before ordinary draw")
	var first_ordinary_entry := int(game.state.get("runClock", {}).get(
		"decisionIndex", -1)) + 1
	if first_ordinary_entry <= 26:
		return _fail("first ordinary draw can still enter official window: %d" % first_ordinary_entry)
	for n in 22:
		if game.state.get("phase") == "SHOP_PENDING":
			break
		if game.state.get("phase") == "FLOW_PENDING":
			if not game.resume_flow():
				return _fail("natural causal order flow halted")
		else:
			var direction := ""
			for candidate in ["up", "right", "left", "down"]:
				if game.can_choose_direction(candidate):
					direction = candidate
					break
			if direction.is_empty() or not game.choose(direction, game.issue_choice_token()):
				return _fail("natural causal order choice halted")
	if game.state.get("phase") != "SHOP_PENDING" or game.get_current_card().get(
			"id") != "shop_encounter":
		return _fail("natural causal order route missed official venue")
	var fact_id := "fact:0:rumor_rusted_sword_origin"
	var fact: Dictionary = game.state.get("noncombatFlow", {}).get(
		"spineFacts", {}).get(fact_id, {})
	var projected := int(game.state["runClock"]["decisionIndex"]) + 1
	if projected != 33 or fact.get("status") != "closed" \
			or int(fact.get("closedDecisionIndex", -1)) != 27:
		return _fail("source fixed-roll access gap changed: %d / %s" % [
			projected, fact])
	if not game.choose("right", game.issue_choice_token()):
		return _fail("natural expired fact could not open official venue")
	var action_id := "causal_fact:regulated_rusted_sword_order:" + fact_id
	var opening: Dictionary = game.state.duplicate(true)
	if game.perform_vendor_action(action_id, game.issue_choice_token()) \
			or game.state.get("marketState", {}).has("rustedSwordOrders"):
		return _fail("expired natural fact incorrectly registered an order")
	var reloaded = Domain.new(Registry.new(), RunSession.new(path, "slot_3"), "slot_3")
	_set_zero_rolls(reloaded)
	if not reloaded.restore() or not _same(reloaded.state, opening):
		return _fail("natural expired fact failed strict restore")
	print("NONCOMBAT_CAUSAL_ORDER_ACCESS_GAP_PASS fact=22 closed=27 first_ordinary=%d venue=33" % first_ordinary_entry)
	quit(0)
