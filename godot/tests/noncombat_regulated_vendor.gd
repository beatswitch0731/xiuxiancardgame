extends "res://tests/noncombat_normal_runtime.gd"

func _run() -> void:
	var game = Domain.new(Registry.new(), null, "slot_3")
	if not game.start("sword"):
		return _fail("regulated source run could not start")
	var due: Dictionary = game.state.duplicate(true)
	due["turn"] = 32
	due["runClock"]["decisionIndex"] = 32
	var flow: Dictionary = game._prepare_normal_flow(due)
	if flow.is_empty():
		return _fail("regulated lottery could not initialize")
	flow["randomMode"] = "fixed"
	flow["fixedRoll"] = 0.0
	var issued: Dictionary = game._check_prepriority_encounters(due)
	if issued.get("phase") != "SHOP_PENDING" or issued.get("currentCardId") \
			!= "shop_encounter" or issued.get("normalFlow", {}).get("shopCooldown") != 6:
		return _fail("P25 hit did not publish source shop card: " + game.flow_failure_reason())
	var skip_game = Domain.new(Registry.new(), null, "slot_3")
	if not skip_game.start("sword"):
		return _fail("official skip route could not initialize")
	skip_game.state = issued.duplicate(true)
	if not skip_game.choose("left", skip_game.issue_choice_token()):
		return _fail("official skip choice did not settle")
	var skipped_flow: Dictionary = skip_game.state["normalFlow"].duplicate(true)
	if not skip_game._sample_discarded_shop(skip_game.state.duplicate(true), skipped_flow,
			{}, {}) or skipped_flow.get("pendingShopDiscarded", {}).get("pillPrices", {}).get(
			"shop_pill_foundation") != 5:
		return _fail("skipped shop lost hidden prefetch pill price for next encounter")
	game.state = issued
	if game.get_current_card().get("choices", {}).get("right", {}).get(
		"action", {}).get("vendorId") != "regulated_market":
		return _fail("shop card lost official vendor action")
	if not game.choose("right", game.issue_choice_token()) \
			or game.state.get("phase") != "VENDOR_OPEN":
		return _fail("official venue did not open source quote")
	var session: Dictionary = game.state["marketState"]["activeSession"]
	if session.get("vendorId") != "regulated_market" or session.get("marketType") \
			!= "regulated" or session.get("interactionBudget", {}).get("limit") != 0 \
			or session.get("immutableOffers", []).size() != 6 \
			or game.state["normalFlow"].get("shopEntries", []).size() != 1:
		return _fail("official session reused bazaar or regenerated stock")
	var offers: Array = game.vendor_offers()
	if offers.size() != 6 or offers[0].get("id") != "shop_pill_foundation" \
			or not offers[0].get("enabled") \
			or offers[2].get("id") != "shop_treasure_dyn_玄铁甲" \
			or not offers[2].get("supported") or not offers[2].get("enabled"):
		return _fail("source catalog admission differs")
	if game.purchase_vendor_offer("shop_treasure_dyn_absent", game.issue_choice_token()) \
			or not game.purchase_vendor_offer("shop_pill_foundation", game.issue_choice_token()) \
			or game.purchase_vendor_offer("shop_pill_foundation", game.issue_choice_token()) \
			or game.state.get("resources", {}).get("pills", {}).get("foundation") != 1 \
			or game.state.get("resources", {}).get("spiritStone") != 5:
		return _fail("official purchase or duplicate rejection differs")
	game.state["attributes"]["health"] = 1
	game.state["modifiers"] = {"hpRegen": 1}
	game.state["karmaSeeds"] = [{"id": "regulated_close_seed", "delay": 3}]
	if not game.close_vendor(game.issue_choice_token()) \
			or game.get_current_card().get("type") != "VENDOR_RESULT" \
			or not String(game.state.get("currentCardId", "")).contains(String(session["sessionKey"])) \
			or game.state.get("runClock", {}).get("decisionIndex") != 33 \
			or game.state["attributes"]["health"] != 2 \
			or game.state.get("karmaSeeds", [])[0].get("delay") != 2 \
			or game.state.get("marketState", {}).get("visitHistory", []).back().get(
				"vendorId") != "regulated_market":
		return _fail("official close missed regen, seed tick, or one source decision")
	if not game.choose("right", game.issue_choice_token()) \
			or game.state.get("phase") != "FLOW_PENDING":
		return _fail("official result did not dismiss")
	var repeated_state: Dictionary = game.state.duplicate(true)
	var repeated_flow: Dictionary = repeated_state["normalFlow"].duplicate(true)
	var repeated_row := {}
	if not game._sample_discarded_shop(repeated_state, repeated_flow, {}, repeated_row) \
			or repeated_flow.get("pendingShopDiscarded", {}).get("pillPrices", {}).get(
				"shop_pill_foundation") != 4 \
			or repeated_flow.get("pendingShopDiscarded", {}).get("pillPrices", {}).get(
				"shop_pill_healing") != 1:
		return _fail("second source shop prefetch reset persistent pill prices")
	var bazaar_state: Dictionary = game.state.duplicate(true)
	bazaar_state["phase"] = "MARKET_PENDING"
	bazaar_state["currentCardId"] = "bazaar_encounter"
	bazaar_state["pendingMarketChoiceCard"] = game._market_flow._bazaar_card(
		"青云山门", "qi")
	bazaar_state["marketCardLocation"] = "青云山门"
	var bazaar: Dictionary = game._vendor_flow.open(bazaar_state)
	if bazaar.is_empty() or game._vendor_flow.available_offers(bazaar).is_empty():
		return _fail("later public bazaar rejected authentic regulated purchase history: opened=%s error=%s" % [
			not bazaar.is_empty(), game._vendor_flow.last_error])
	var archived: Dictionary = bazaar_state.duplicate(true)
	archived["marketState"]["visitHistory"] = [{"sessionKey": "vendor:%s:34:bazaar_encounter:public_bazaar" % archived["runClock"]["lifeId"],
		"vendorId": "public_bazaar", "marketType": "public_bazaar", "decisionIndex": 34,
		"seen": true, "outcome": "declined", "missedOffers": []}]
	if game._vendor_flow.open(archived).is_empty():
		return _fail("later public bazaar rejected an archived genuine official purchase")
	var full_history: Dictionary = game.state.duplicate(true)
	full_history["phase"] = "VENDOR_OPEN"
	full_history["currentCardId"] = "vendor_pending:shop_encounter"
	full_history["marketState"]["activeSession"] = session.duplicate(true)
	full_history["runClock"]["decisionIndex"] = 32
	full_history["turn"] = 32
	full_history["runClock"]["receipts"].erase("decision:%s:choice:shop_encounter:33" % full_history["runClock"]["lifeId"])
	full_history["marketState"]["visitHistory"] = []
	for n in 48:
		full_history["marketState"]["visitHistory"].append({"sessionKey": "old:%d" % n,
			"vendorId": "public_bazaar", "decisionIndex": n + 1})
	var bounded: Dictionary = game._regulated_vendor.close(full_history)
	if bounded.get("marketState", {}).get("visitHistory", []).size() != 48:
		return _fail("official close did not bound player visit memory to 48: %s / %s" % [
			bounded.get("phase", "empty"), game._regulated_vendor.last_error])
	print("NONCOMBAT_REGULATED_VENDOR_PASS hit=true stock=true purchase=true close=true regen=true seed=true archived=true later_bazaar=true")
	quit(0)
