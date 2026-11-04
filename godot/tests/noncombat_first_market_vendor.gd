extends SceneTree

const Repository = preload("res://scripts/noncombat_content_repository.gd")
const Vendor = preload("res://scripts/noncombat_regulated_vendor_flow.gd")
const Catalog = preload("res://scripts/noncombat_regulated_shop_catalog.gd")


func _initialize() -> void:
	var content := Repository.new()
	var vendor := Vendor.new(content)
	var catalog := Catalog.new(content)
	var market := _source_card(content, "locations:locations", "loc_market_first")
	var close_effects: Dictionary = market["choices"]["left"]["vendorCloseEffects"]
	for purchase in [false, true]:
		var prior := _state("loc_market_first", "FIRST_SESSION_ROUTE_PENDING")
		var baseline := prior.duplicate(true)
		var offers := catalog.generate(prior, func() -> float: return 0.0)
		var opened := vendor.open(prior, offers, market)
		if opened.is_empty():
			return _fail("source first market did not open its left vendor action")
		var session: Dictionary = opened["marketState"]["activeSession"]
		var session_key := "vendor:first_market:life:0:7:loc_market_first:regulated_market"
		if session.get("sessionKey") != session_key or session.get("entryCardId") != market["id"] \
				or session.get("direction") != "left" or session.get("card") != market \
				or session.get("choice") != market["choices"]["left"] \
				or opened["attributes"] != prior["attributes"] \
				or opened["runClock"] != prior["runClock"] \
				or opened["choiceHistory"] != prior["choiceHistory"] \
				or opened["karmaSeeds"] != prior["karmaSeeds"] \
				or not vendor.open(opened, offers, market).is_empty():
			return _fail("vendor opening paid the delayed effect or lost source/session identity")
		var restored: Dictionary = JSON.parse_string(JSON.stringify(opened))
		var restored_vendor := Vendor.new(Repository.new())
		if restored_vendor.pending_card(restored).get("id") != "vendor_pending:loc_market_first" \
				or restored_vendor.available_offers(restored) != vendor.available_offers(opened):
			return _fail("restored source-market session lost its immutable offer view")
		var before_close := restored
		if purchase:
			before_close = restored_vendor.purchase(restored, "shop_pill_foundation")
			var price := 0
			for offer in offers:
				if offer.get("id") == "shop_pill_foundation":
					price = int(offer["price"])
			if before_close.is_empty() \
					or before_close["resources"]["spiritStone"] != prior["resources"]["spiritStone"] - price \
					or before_close["resources"]["pills"].get("foundation") != 1 \
					or before_close["attributes"]["fortune"] != prior["attributes"]["fortune"] \
					or not restored_vendor.purchase(before_close, "shop_pill_foundation").is_empty():
				return _fail("first market purchase spent twice, paid entry reward, or lost acquired pill")
		var closed := restored_vendor.close(before_close)
		var receipt := "decision:first_market:life:0:choice:loc_market_first:7"
		if closed.is_empty() or closed.get("phase") != "VENDOR_RESULT_PENDING" \
				or closed["attributes"]["fortune"] != prior["attributes"]["fortune"] + close_effects["fortune"] \
				or closed["attributes"]["health"] != prior["attributes"]["health"] + 1 \
				or closed["resources"]["lifespan"] != prior["resources"]["lifespan"] \
				or closed["runClock"]["decisionIndex"] != 7 \
				or closed["runClock"]["receipts"].get(receipt, {}).get("sourceCardId") != market["id"] \
				or closed["karmaSeeds"][0]["delay"] != 2 \
				or closed.get("recentCardTags") != market["tags"] \
				or closed["choiceHistory"].back() != {"cardId": market["id"], "cardType": market["type"],
					"direction": "left", "turn": 6, "decisionIndex": 7, "tags": market["tags"]}:
			return _fail("first-market close missed its source reward, LOCATION history, clock, regen or tags")
		var visit: Dictionary = closed["marketState"]["visitHistory"].back()
		if visit.get("sessionKey") != session_key \
				or visit.get("outcome") != ("traded" if purchase else "declined") \
				or closed.has("qMarketChoiceVersion") or closed.get("flags", {}).has("choice:q_market:left") \
				or not restored_vendor.close(closed).is_empty():
			return _fail("source close duplicated or inherited unrelated q_market state")
		var closed_restore: Dictionary = JSON.parse_string(JSON.stringify(closed))
		var dismissed := restored_vendor.dismiss(closed_restore)
		if dismissed.get("phase") != "FLOW_PENDING" \
				or dismissed["runClock"] != closed_restore["runClock"] \
				or dismissed["attributes"] != closed_restore["attributes"] \
				or dismissed["marketState"]["activeSession"] != null \
				or not restored_vendor.dismiss(dismissed).is_empty() or prior != baseline:
			return _fail("source result restoration/dismissal duplicated settlement or mutated its input")
		var forged := opened.duplicate(true)
		forged["marketState"]["activeSession"]["choice"]["vendorCloseEffects"]["fortune"] = 99
		if not vendor.close(forged).is_empty():
			return _fail("frozen first-market reward could be replaced before close")
		var stale := opened.duplicate(true)
		stale["marketState"]["activeSession"]["entrySourceSha"] = "changed"
		if vendor.source_valid(stale) or not vendor.close(stale).is_empty():
			return _fail("first-market source fingerprint was ignored after restoring the session")
		var repeated := opened.duplicate(true)
		repeated["runClock"]["receipts"][receipt] = {"token": receipt}
		if not vendor.close(repeated).is_empty():
			return _fail("source-market close accepted a duplicate decision receipt")
		var forged_result := closed_restore.duplicate(true)
		forged_result["decisionCheckpoint"]["vendorSessionKey"] = "other_session"
		if not vendor.dismiss(forged_result).is_empty():
			return _fail("source result accepted a different vendor session key")
	# The extension must retain the existing authored and procedural entries.
	for card_id in ["q_market", Catalog.CARD_ID]:
		var state := _state(card_id, "SHOP_PENDING")
		var authored := _source_card(content, "cards:qi", card_id) if card_id == "q_market" else {}
		var opened := vendor.open(state, catalog.generate(state, func() -> float: return 0.0), authored)
		if opened.is_empty() or vendor.close(opened).is_empty():
			return _fail("existing regulated merchant entry regressed: " + card_id)
	var capped := _state("loc_market_first", "FIRST_SESSION_ROUTE_PENDING")
	capped["attributes"]["fortune"] = 99
	var capped_close := vendor.close(vendor.open(capped,
		catalog.generate(capped, func() -> float: return 0.0), market))
	if capped_close.get("attributes", {}).get("fortune") != 100:
		return _fail("first-market source reward bypassed the fortune cap")
	print("NONCOMBAT_FIRST_MARKET_VENDOR_PASS source_reward=true deferred=true purchase=true reload=true duplicate=true old_entries=2")
	quit(0)


func _source_card(content: RefCounted, module_id: String, card_id: String) -> Dictionary:
	var document: Dictionary = content.read_module(module_id)
	for raw in document["cards"]:
		if raw["id"] == card_id:
			return raw
	return {}


func _state(card_id: String, phase: String) -> Dictionary:
	return {"realm": "qi", "path": "sword", "phase": phase, "turn": 6,
		"lifeCount": 0, "currentCardId": card_id, "currentLocation": "坊市",
		"maxHealth": 6, "maxDaoHeart": 3,
		"attributes": {"fortune": 50, "health": 4, "daoHeart": 2},
		"resources": {"spiritStone": 50, "lifespan": 80, "companions": [], "pills": {}},
		"modifiers": {"hpRegen": 1},
		"runClock": {"lifeId": "first_market:life:0", "decisionIndex": 6, "receipts": {}},
		"choiceHistory": [], "replayHistory": [], "recentCardTags": [], "cardsPlayed": [],
		"karmaSeeds": [{"id": "vendor_seed", "delay": 3}], "pendingKarmaSeeds": [],
		"marketState": {"activeSession": null, "visitHistory": []}, "normalFlow": {},
		"noncombatFlow": {"version": 1, "scope": "first_session_combat", "karmaClockVersion": 1}}


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
