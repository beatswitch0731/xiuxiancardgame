extends "res://tests/noncombat_normal_runtime.gd"

func _run() -> void:
	var game = Domain.new(Registry.new(), null, "slot_3")
	if not game.start("sword"):
		return _fail("regulated goods source run could not start")
	var due: Dictionary = game.state.duplicate(true)
	due["turn"] = 32
	due["runClock"]["decisionIndex"] = 32
	var flow: Dictionary = game._prepare_normal_flow(due)
	if flow.is_empty():
		return _fail("regulated goods lottery could not initialize")
	flow["randomMode"] = "fixed"
	flow["fixedRoll"] = 0.0
	game.state = game._check_prepriority_encounters(due)
	if game.state.get("phase") != "SHOP_PENDING" \
			or not game.choose("right", game.issue_choice_token()):
		return _fail("regulated goods source venue could not open")
	var preowned = Domain.new(Registry.new(), null, "slot_3")
	if not preowned.start("sword"):
		return _fail("preowned buyback branch could not initialize")
	preowned.state = game.state.duplicate(true)
	preowned.state["itemInventory"] = {"灵茶": 1}
	if not preowned.perform_vendor_action("regulated_buyback:灵茶",
			preowned.issue_choice_token()) \
			or not preowned.purchase_vendor_offer("shop_gift_spirit_tea",
				preowned.issue_choice_token()) \
			or preowned.state["resources"]["spiritStone"] != 9 \
			or preowned.state.get("itemInventory", {}).get("灵茶") != 1:
		return _fail("preowned gift buyback then purchase did not preserve event order")
	var offer_id := "shop_gift_spirit_tea"
	var tea_offer := {}
	for offer in game.vendor_offers():
		if offer.get("id") == offer_id:
			tea_offer = offer
	if not tea_offer.get("supported", false) or not tea_offer.get("enabled", false) \
			or int(tea_offer.get("price", -1)) != 3:
		return _fail("source tea gift was not offered at frozen official price")
	if not game.purchase_vendor_offer(offer_id, game.issue_choice_token()) \
			or game.purchase_vendor_offer(offer_id, game.issue_choice_token()) \
			or game.state.get("itemInventory", {}).get("灵茶") != 1 \
			or game.state["resources"]["spiritStone"] != 7:
		return _fail("official tea gift purchase or duplicate rejection differs")
	var action_id := "regulated_buyback:灵茶"
	var buyback := {}
	for action in game.vendor_actions():
		if action.get("id") == action_id:
			buyback = action
	if not buyback.get("enabled", false) \
			or not game.perform_vendor_action(action_id, game.issue_choice_token()) \
			or game.perform_vendor_action(action_id, game.issue_choice_token()) \
			or game.state.get("itemInventory", {}).has("灵茶") \
			or game.state["resources"]["spiritStone"] != 9 \
			or game.state["marketState"]["activeSession"]["summary"].get(
				"exchangedItems", []).size() != 1:
		return _fail("official buyback failed source inventory, receipt or payout")
	if not game.close_vendor(game.issue_choice_token()) \
			or game.state.get("phase") != "VENDOR_RESULT_PENDING":
		return _fail("regulated goods close did not produce one result")
	if not game.choose("right", game.issue_choice_token()):
		return _fail("regulated goods result could not dismiss")
	var bazaar_state: Dictionary = game.state.duplicate(true)
	bazaar_state["phase"] = "MARKET_PENDING"
	bazaar_state["currentCardId"] = "bazaar_encounter"
	bazaar_state["pendingMarketChoiceCard"] = game._market_flow._bazaar_card(
		"青云山门", "qi")
	bazaar_state["marketCardLocation"] = "青云山门"
	bazaar_state["marketState"]["visitHistory"] = [{"sessionKey": \
		"vendor:%s:34:bazaar_encounter:public_bazaar" % bazaar_state["runClock"]["lifeId"],
		"vendorId": "public_bazaar", "marketType": "public_bazaar",
		"decisionIndex": 34, "seen": true, "outcome": "declined", "missedOffers": []}]
	if game._vendor_flow.open(bazaar_state).is_empty():
		return _fail("archived official gift purchase rejected later bazaar")
	var higher = Domain.new(Registry.new(), null, "slot_3")
	if not higher.start("sword"):
		return _fail("foundation official shop could not initialize")
	var foundation_due: Dictionary = higher.state.duplicate(true)
	foundation_due["realm"] = "foundation"
	foundation_due["turn"] = 32
	foundation_due["runClock"]["decisionIndex"] = 32
	foundation_due["resources"]["spiritStone"] = 300
	var higher_flow: Dictionary = higher._prepare_normal_flow(foundation_due)
	if higher_flow.is_empty():
		return _fail("foundation official shop lottery could not initialize")
	higher_flow["randomMode"] = "fixed"
	higher_flow["fixedRoll"] = 0.0
	higher.state = higher._check_prepriority_encounters(foundation_due)
	if higher.state.get("phase") != "SHOP_PENDING" \
			or higher.get_current_card().get("realm") != "foundation" \
			or not higher.choose("right", higher.issue_choice_token()):
		return _fail("foundation official shop could not open from priority draw")
	var ordinary = Domain.new(Registry.new(), null, "slot_3")
	if not ordinary.start("sword"):
		return _fail("ordinary official goods branch could not initialize")
	ordinary.state = higher.state.duplicate(true)
	var treasure_offer := ""
	var card_offer := ""
	var identify_offer := ""
	for offer in ordinary.vendor_offers():
		if String(offer.get("id", "")).begins_with("shop_treasure_dyn_"):
			treasure_offer = String(offer.id)
		elif String(offer.get("id", "")).begins_with("card_"):
			card_offer = String(offer.id)
		elif offer.get("id") in ["shop_treasure_box", "shop_treasure_mysterious"]:
			identify_offer = String(offer.id)
	if treasure_offer.is_empty() or card_offer.is_empty() or identify_offer.is_empty() \
			or not ordinary.purchase_vendor_offer(treasure_offer,
				ordinary.issue_choice_token()):
		return _fail("foundation official treasure stock could not be bought " + JSON.stringify({
			"treasure": treasure_offer, "card": card_offer,
			"identify": identify_offer, "offers": ordinary.vendor_offers(),
			"reason": ordinary._regulated_vendor.last_error}))
	if int(ordinary.state.get("marketState", {}).get("activeSession", {}).get(
			"summary", {}).get("purchaseCount", 0)) != 1:
		return _fail("owned treasure purchase did not update the live vendor visit")
	var story: Control = load("res://scenes/noncombat_opening.tscn").instantiate()
	story.save_path = ""
	root.add_child(story)
	story._append_vendor_loadout_buttons(ordinary.state)
	var equip_button: Button = story.choice_row.get_node_or_null("VendorLoadout_equip")
	var purchased_id := String(ordinary.state.get("pendingLoadoutDecision", {}).get(
		"instanceId", ""))
	var purchased: Dictionary = ordinary.state.get("treasureInstances", {}).get(
		purchased_id, {})
	if equip_button == null or not equip_button.text.contains(String(
			purchased.get("definitionId", ""))) \
			or equip_button.text.contains("易手残剑"):
		return _fail("ordinary treasure loadout button named a different item")
	story.queue_free()
	var before_deck: int = ordinary.state.deck.size()
	if not ordinary.state.get("pendingLoadoutDecision") is Dictionary \
			or not ordinary.resolve_vendor_loadout("stash", ordinary.issue_choice_token()) \
			or ordinary.state.get("pendingLoadoutDecision") != null \
			or not ordinary.purchase_vendor_offer(card_offer,
				ordinary.issue_choice_token()) \
			or ordinary.state.deck.size() != before_deck + 1:
		return _fail("foundation official treasure loadout or path card purchase failed")
	if not ordinary.purchase_vendor_offer(identify_offer,
			ordinary.issue_choice_token(), "", {"identifyRoll": 0.9,
				"itemRoll": 0.0}) \
			or not ordinary.state.get("shopIdentifyRuleSourceSha") is String \
			or ordinary.state.get("regulatedEventHistory", []).back().get(
				"identifyRoll") != 0.9:
		return _fail("foundation official identification lacked source receipt")
	var golden_pill := {}
	for offer in higher.vendor_offers():
		if offer.get("id") == "shop_pill_golden":
			golden_pill = offer
	if golden_pill.is_empty() or not golden_pill.get("supported", false) \
			or not golden_pill.get("enabled", false):
		return _fail("foundation official shop lost guaranteed golden pill")
	var before_pills := int(higher.state.resources.pills.get("golden", 0))
	var before_stones := int(higher.state.resources.spiritStone)
	if not higher.purchase_vendor_offer("shop_pill_golden",
			higher.issue_choice_token()) \
			or int(higher.state.resources.pills.get("golden", 0)) != before_pills + 1 \
			or int(higher.state.resources.spiritStone) != before_stones - int(golden_pill.price) \
			or not higher.close_vendor(higher.issue_choice_token()):
		return _fail("foundation official golden pill purchase or close failed")
	print("NONCOMBAT_REGULATED_GOODS_PASS gift=true buyback=true reverse_order=true duplicate=true close=true archived=true foundation=true treasure=true card=true box=true")
	quit(0)
