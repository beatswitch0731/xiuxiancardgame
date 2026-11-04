extends "res://tests/noncombat_normal_runtime.gd"

func _run() -> void:
	var game = Domain.new(Registry.new(), null, "slot_3")
	if not game.start("sword"):
		return _fail("q_market source run could not start")
	var due: Dictionary = game.state.duplicate(true)
	due["turn"] = 23
	due["runClock"]["decisionIndex"] = 23
	var flow: Dictionary = game._prepare_normal_flow(due)
	if flow.is_empty():
		return _fail("q_market ordinary flow could not initialize")
	flow["randomMode"] = "fixed"
	flow["fixedRoll"] = 0.0
	var pool: Dictionary = game._normal_draw_policy.buckets(due)
	var authored_in_pool := false
	for bucket in pool.values():
		for item in bucket:
			if item.get("id") == "q_market":
				authored_in_pool = true
	if not authored_in_pool:
		return _fail("authored q_market was absent from the ordinary qi draw pool")
	due["phase"] = "SHOP_PENDING"
	due["noncombatFlow"] = {"sourceContentHash": game._battle_gateway.source_content_hash(),
		"karmaClockVersion": 1}
	due["currentCardId"] = "q_market"
	due["decisionCheckpoint"] = {"version": 1, "cardId": "q_market",
		"turn": 23, "decisionIndex": 23}
	game.state = due
	var source_art: Dictionary = game._content.asset_status(
		"assets/cards/events/scene_qi_q_market.png")
	if game.get_current_card().get("id") != "q_market" \
			or game.get_current_card().get("sceneImage") != \
				"assets/cards/events/scene_qi_q_market.png" \
			or not source_art.get("shaVerified", false) \
			or not source_art.get("textureLoadable", false) \
			or not game.can_choose_direction("left") \
			or not game.can_choose_direction("right") \
			or not game.can_choose_direction("down"):
		return _fail("source q_market art/card/three directions are not reachable")
	for variant in [
		["public_truth", "将十七人名册公示归档"],
		["rescue_first", "封存副册，先救矿洞活人"]]:
		var variant_state: Dictionary = due.duplicate(true)
		variant_state["noncombatFlow"]["spineFacts"] = {
			"fact:0:sect_register_resolution": {
				"factInstanceId": "fact:0:sect_register_resolution",
				"factTypeId": "sect_register_resolution", "status": "active",
				"createdDecisionIndex": 23, "payload": {"resolution": variant[0]}}}
		var variant_services: Array = game._regulated_vendor._materialize_causal_services(
			variant_state, 24)
		if variant_services.size() != 1 or variant_services[0].get(
				"label") != variant[1]:
			return _fail("authored sect-register causal presentation lost its variant")
	var old_market: Dictionary = due.duplicate(true)
	old_market["phase"] = "SHOP_PENDING"
	old_market["currentCardId"] = "shop_encounter"
	old_market["marketState"] = {"activeSession": null}
	old_market["noncombatFlow"]["spineFacts"] = {
		"fact:0:rumor_rusted_sword_origin": {
			"factInstanceId": "fact:0:rumor_rusted_sword_origin",
			"factTypeId": "rumor_rusted_sword_origin", "status": "active",
			"createdDecisionIndex": 10, "payload": {}}}
	old_market["runClock"]["decisionIndex"] = 14
	old_market["turn"] = 14
	game._regulated_vendor.causal_activation_index = 16
	var old_open: Dictionary = game._regulated_vendor.open(old_market,
		[{"id": "shop_pill_foundation", "name": "筑基丹", "price": 10}])
	if old_open.is_empty() or old_open.has("regulatedCausalServiceVersion") \
			or old_open.get("noncombatFlow", {}).get("spineFacts", {}).get(
				"fact:0:rumor_rusted_sword_origin", {}).get("status") != "active":
		return _fail("old official session was rewritten before causal activation")
	var next_market: Dictionary = old_market.duplicate(true)
	next_market["runClock"]["decisionIndex"] = 15
	next_market["turn"] = 15
	var new_open: Dictionary = game._regulated_vendor.open(next_market,
		[{"id": "shop_pill_foundation", "name": "筑基丹", "price": 10}])
	if new_open.is_empty() or new_open.get("regulatedCausalActivationIndex") != 16 \
			or new_open.get("noncombatFlow", {}).get("spineFacts", {}).get(
				"fact:0:rumor_rusted_sword_origin", {}).get("closedDecisionIndex") != 16:
		return _fail("new official session did not close fact at activation")
	game._regulated_vendor.causal_activation_index = 0
	var skipped = Domain.new(Registry.new(), null, "slot_3")
	if not skipped.start("sword"):
		return _fail("q_market skip branch could not initialize")
	skipped.state = due.duplicate(true)
	var right_ok: bool = skipped.choose("right", skipped.issue_choice_token())
	if not right_ok \
			or skipped.state.get("phase") != "NARRATIVE_RESULT_PENDING" \
			or skipped.get_current_card().get("description") != String(
				game.get_current_card().get("choices", {}).get("right", {}).get(
					"narrativeBlock", "")) \
			or skipped.state.get("flags", {}).get("choice:q_market:right") != true \
			or skipped.state.get("choiceHistory", []).back().get("cardId") != "q_market" \
			or skipped.state.get("choiceHistory", []).back().get("direction") != "right":
		return _fail("q_market caravan-sign branch lost authored response or world flag")
	if not skipped.choose("left", skipped.issue_choice_token()) \
			or skipped.state.get("phase") != "FLOW_PENDING":
		return _fail("q_market caravan response did not resolve")
	var resolved_promise: Dictionary = skipped.state.get("noncombatFlow", {}).get(
		"qMarketPromise", {}).duplicate(true)
	var repeated = Domain.new(Registry.new(), null, "slot_3")
	if not repeated.start("sword"):
		return _fail("q_market repeat branch could not initialize")
	repeated.state = skipped.state.duplicate(true)
	repeated.state["phase"] = "SHOP_PENDING"
	repeated.state["currentCardId"] = "q_market"
	if not repeated.choose("right", repeated.issue_choice_token()) \
			or repeated.state.get("phase") != "FLOW_PENDING" \
			or repeated.state.get("noncombatFlow", {}).get(
				"qMarketPromise", {}) != resolved_promise \
			or repeated.state.has("pendingNarrativeResult"):
		return _fail("same-life repeat q_market created a duplicate response")
	var departed = Domain.new(Registry.new(), null, "slot_3")
	if not departed.start("sword"):
		return _fail("q_market leave branch could not initialize")
	departed.state = due.duplicate(true)
	if not departed.choose("down", departed.issue_choice_token()) \
			or departed.state.get("choiceHistory", []).back().get("direction") != "down" \
			or departed.state.get("flags", {}).get("choice:q_market:down") != true:
		return _fail("q_market leave branch did not settle source card")
	var left = Domain.new(Registry.new(), null, "slot_3")
	if not left.start("sword"):
		return _fail("q_market entry branch could not initialize")
	left.state = due.duplicate(true)
	if not left.choose("left", left.issue_choice_token()) \
			or left.state.get("phase") != "VENDOR_OPEN" \
			or left.state.get("marketState", {}).get("activeSession", {}).get(
				"entryCardId") != "q_market" \
			or left.state.get("marketState", {}).get("activeSession", {}).get(
				"direction") != "left":
		return _fail("q_market regulated entry did not retain authored card identity")
	if not left.purchase_vendor_offer("shop_gift_spirit_tea",
			left.issue_choice_token()) \
			or not left.close_vendor(left.issue_choice_token()) \
			or left.state.get("choiceHistory", []).back().get("cardId") != "q_market" \
			or left.state.get("flags", {}).has("choice:q_market:left"):
		return _fail("q_market regulated purchase/exit did not retain authored card identity")
	if not left.choose("right", left.issue_choice_token()):
		return _fail("q_market result card could not dismiss")
	var bazaar_state: Dictionary = left.state.duplicate(true)
	bazaar_state["phase"] = "MARKET_PENDING"
	bazaar_state["currentCardId"] = "bazaar_encounter"
	bazaar_state["pendingMarketChoiceCard"] = left._market_flow._bazaar_card(
		"青云山门", "qi")
	bazaar_state["marketCardLocation"] = "青云山门"
	if left._vendor_flow.open(bazaar_state).is_empty():
		return _fail("q_market archived gift purchase blocked a later public bazaar: " +
			left._vendor_flow.last_error)
	print("NONCOMBAT_Q_MARKET_PASS choices=true source_card=true entry=true result=true")
	quit(0)
