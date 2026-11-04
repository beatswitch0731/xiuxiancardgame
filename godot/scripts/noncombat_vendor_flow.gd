extends RefCounted

# Browser authorities: GameLogic ENTER_VENDOR / vendor close / result dismissal,
# MarketSystem.createVendorSession and ShopSystem.executeVendorAction.
const LegacyFragmentFlow = preload("res://scripts/noncombat_legacy_fragment_flow.gd")
const MarketFlow = preload("res://scripts/noncombat_market_flow.gd")
const TreasureAcquisition = preload("res://scripts/noncombat_treasure_acquisition.gd")
const GAME_JS_SHA := "73d5038d1427433134a644e314d9d501d772c0ba79f67f61f9a46c3e4f8e093b"
const SHOP_JS_SHA := "937c9db807692305a7c3c09798cd967241e2a87de506c65228aec83bc5b12a46"
const BAZAAR_ID := "bazaar_encounter"
const PROFILE_MODULE := "markets:vendor_profiles"

var last_error := ""
var _content: RefCounted
var _treasures: RefCounted

func _init(content: RefCounted) -> void:
	_content = content
	_treasures = TreasureAcquisition.new(content)

func source_valid(state: Dictionary) -> bool:
	return state.get("marketVendorGameSourceSha") == GAME_JS_SHA \
		and state.get("marketVendorShopSourceSha") == SHOP_JS_SHA \
		and state.get("marketProfileSourceSha") == _content.source_sha256(PROFILE_MODULE)

func open(state: Dictionary) -> Dictionary:
	last_error = ""
	if state.get("phase") != "MARKET_PENDING" or state.get("currentCardId") != BAZAAR_ID \
			or state.get("marketRuleSourceSha") == null:
		return {}
	var profile := _profile()
	if profile.is_empty():
		return {}
	if not _history_projection(state, profile).get("valid", false):
		last_error = "集市来往记录与摊主关系不符"
		return {}
	var card: Dictionary = state.get("pendingMarketChoiceCard", {})
	if card.get("id") != BAZAAR_ID or card.get("choices", {}).get(
			"left", {}).get("action", {}).get("type") != "ENTER_VENDOR":
		return {}
	var candidate: Dictionary = state.duplicate(true)
	var market: Dictionary = candidate["marketState"]
	if market.get("activeSession") != null:
		return {}
	var next_index := int(candidate["runClock"]["decisionIndex"]) + 1
	var session_key := "vendor:%s:%d:%s:public_bazaar" % [
		candidate["runClock"]["lifeId"], next_index, BAZAAR_ID]
	var relations: Dictionary = market.get("vendorRelations", {})
	var stalls: Array = []
	var offers: Array = []
	for raw in profile.get("stalls", []):
		if not raw is Dictionary:
			return {}
		var stall: Dictionary = raw.duplicate(true)
		var relation := maxi(0, int(relations.get(stall.get("id", ""), 0)))
		var rule: Dictionary = stall.get("relationship", {})
		var unlocked := relation >= maxi(1, int(rule.get("threshold", 1)))
		var hint: Variant = rule.get("hint") if unlocked else null
		stall["relation"] = relation
		stall["relationshipUnlocked"] = unlocked
		stall["relationHint"] = hint
		var stock: Array = []
		for raw_offer in stall.get("offers", []):
			var offer: Dictionary = raw_offer.duplicate(true)
			if unlocked and not offer.has("costSpec") and offer.has("price"):
				offer["price"] = maxi(1, int(floor(float(offer["price"]) *
					maxf(0.1, float(rule.get("priceMultiplier", 1.0))))))
				offer["relationHint"] = hint
			stock.append(offer)
		if unlocked and rule.get("specialOffer") is Dictionary:
			var special: Dictionary = rule["specialOffer"].duplicate(true)
			special["relationHint"] = hint
			special["relationUnlocked"] = true
			stock.append(special)
		stall["offers"] = stock
		stalls.append(stall)
		for stock_offer in stock:
			var item: Dictionary = stock_offer.duplicate(true)
			item["stallId"] = stall["id"]
			item["stallName"] = stall["name"]
			item["relationHint"] = item.get("relationHint", hint)
			offers.append(item)
	var budget := maxi(0, int(profile.get("interactionBudget", 0)))
	var session := {"version": 2, "status": "open", "sessionId": session_key,
		"sessionKey": session_key, "vendorId": "public_bazaar",
		"marketType": "public_bazaar", "entryCardId": BAZAAR_ID,
		"openedAtDecisionIndex": next_index, "offerRevision": 1,
		"immutableOffers": offers, "actionReceipts": {},
		"interactionBudget": {"limit": budget, "remaining": budget},
		"stalls": stalls, "services": [], "riskRules": {}, "debt": null,
		"presentationProfile": profile.get("presentationProfile", {}).duplicate(true),
		"exitContract": profile.get("exitContract", ""),
		"summary": {"openingOfferCount": offers.size(), "purchaseCount": 0,
			"spiritStoneSpent": 0, "purchasedItems": [], "exchangedItems": []},
		"openedAtTurn": int(candidate["turn"]), "direction": "left", "card": card.duplicate(true),
		"choice": card["choices"]["left"].duplicate(true)}
	market["vendorRelations"] = relations
	market["activeSession"] = session
	candidate["marketVendorGameSourceSha"] = GAME_JS_SHA
	candidate["marketVendorShopSourceSha"] = SHOP_JS_SHA
	candidate["phase"] = "VENDOR_OPEN"
	candidate["currentCardId"] = "vendor_pending:" + BAZAAR_ID
	candidate["decisionCheckpoint"] = {"version": 1,
		"cardId": candidate["currentCardId"], "sourceCardId": BAZAAR_ID,
		"turn": candidate["turn"], "decisionIndex": candidate["runClock"]["decisionIndex"],
		"vendorSessionKey": session_key}
	return candidate

func pending_card(state: Dictionary) -> Dictionary:
	if state.get("phase") != "VENDOR_OPEN" or not source_valid(state):
		return {}
	return {"id": "vendor_pending:" + BAZAAR_ID,
		"title": "集市来往进行中",
		"description": "三处摊位与本次可交谈次数已锁定。交易或记名后，再继续行程。",
		"type": "VENDOR_PENDING", "choices": {}}

func available_actions(state: Dictionary) -> Array:
	if state.get("phase") != "VENDOR_OPEN" or not _authentic_open_session(state):
		return []
	var session: Dictionary = state.get("marketState", {}).get("activeSession", {})
	if session.get("status") != "open":
		return []
	var actions: Array = []
	for stall in session.get("stalls", []):
		var authored: Array = stall.get("actions", []) if stall.has("actions") else [stall.get("action")]
		for action in authored:
			if not action is Dictionary:
				continue
			var asks_origin: bool = action.get("id") == "ask_luo" \
				and stall.get("id") == "luo_trader"
			if not asks_origin and (action.get("causalFact") != null \
					or not action.get("costSpec", []).is_empty()):
				continue
			actions.append({"id": action.get("id"), "label": action.get("label"),
				"stallName": stall.get("name"),
				"enabled": int(session.get("interactionBudget", {}).get("remaining", 0)) > 0
					and not session.get("actionReceipts", {}).has(action.get("id"))
					and (not asks_origin or _ask_luo_can_start(state, action))})
	return actions

func available_offers(state: Dictionary) -> Array:
	if state.get("phase") != "VENDOR_OPEN" or not _authentic_open_session(state):
		return []
	var result: Array = []
	for offer in state.get("marketState", {}).get("activeSession", {}).get("immutableOffers", []):
		var supported := _supported_offer(offer)
		var sword_mode: bool = offer.get("id") == "bazaar_luo_traded_rusted_sword" \
			and offer.get("type") == "treasure" and offer.get("stallId") == "luo_trader"
		var favor_ready := int(state.get("marketState", {}).get("vendorRelations", {}).get(
			"luo_trader", 0)) >= 1
		if sword_mode:
			supported = true
		var price := _sword_favor_cost(offer) if sword_mode else int(offer.get("price", -1))
		result.append({"id": offer.get("id"), "name": offer.get("name"),
			"price": price, "stallName": offer.get("stallName"),
			"supported": supported,
			"costMode": "favor" if sword_mode else "",
			"enabled": supported and (not sword_mode or favor_ready) and price >= 0 \
				and int(state.get("resources", {}).get("spiritStone", 0)) >= price})
	return result

func purchase_offer(state: Dictionary, offer_id: String,
		cost_mode_id: String = "") -> Dictionary:
	last_error = ""
	if state.get("phase") != "VENDOR_OPEN" or not _authentic_open_session(state):
		return {}
	var candidate: Dictionary = state.duplicate(true)
	var session: Dictionary = candidate["marketState"]["activeSession"]
	var offer: Dictionary = {}
	for item in session["immutableOffers"]:
		if item.get("id") == offer_id:
			offer = item
			break
	var sword_mode: bool = offer.get("id") == "bazaar_luo_traded_rusted_sword" \
		and offer.get("type") == "treasure" and offer.get("stallId") == "luo_trader"
	if (not sword_mode and (not _supported_offer(offer) or not cost_mode_id.is_empty())) \
			or (sword_mode and cost_mode_id != "favor"):
		return {}
	var price := _sword_favor_cost(offer) if sword_mode else int(offer.get("price", -1))
	if price < 0 or int(candidate["resources"].get("spiritStone", 0)) < price:
		return {}
	if sword_mode and not _purchase_favor_sword(candidate, session, offer, price):
		return {}
	if sword_mode:
		session = candidate["marketState"]["activeSession"]
	candidate["resources"]["spiritStone"] = int(candidate["resources"]["spiritStone"]) - price
	if offer.get("type") == "pill":
		var heal := int(offer.get("effect", {}).get("healHp", 0))
		candidate["attributes"]["health"] = mini(
			LegacyFragmentFlow.actual_max_health(candidate),
			int(candidate["attributes"].get("health", 0)) + heal)
	elif offer.get("type") == "story_item":
		var item_id := String(offer.get("effect", {}).get("itemId", ""))
		var quantity := maxi(1, int(offer.get("effect", {}).get("quantity", 1)))
		if not candidate.get("itemInventory", {}) is Dictionary:
			return {}
		var inventory: Dictionary = candidate.get("itemInventory", {}).duplicate(true)
		inventory[item_id] = maxi(0, int(inventory.get(item_id, 0))) + quantity
		candidate["itemInventory"] = inventory
	var remaining: Array = []
	for item in session["immutableOffers"]:
		if item.get("id") != offer_id:
			remaining.append(item)
	session["immutableOffers"] = remaining
	var summary: Dictionary = session["summary"]
	summary["purchaseCount"] = int(summary.get("purchaseCount", 0)) + 1
	summary["spiritStoneSpent"] = int(summary.get("spiritStoneSpent", 0)) + price
	var item_receipt := {"id": offer_id, "name": offer["name"],
		"costSpec": [{"kind": "resource", "key": "spiritStone", "amount": price}]}
	if sword_mode:
		item_receipt["costMode"] = cost_mode_id
	summary["purchasedItems"].append(item_receipt)
	if not candidate.has("marketPurchaseHistory"):
		candidate["marketPurchaseHistory"] = []
	var history_event := {"sessionKey": session["sessionKey"], "offerId": offer_id}
	if sword_mode:
		history_event["costMode"] = cost_mode_id
	candidate["marketPurchaseHistory"].append(history_event)
	return candidate

func resolve_loadout(state: Dictionary, action: String) -> Dictionary:
	if not source_valid(state) or action not in ["equip", "stash"]:
		return {}
	var pending_value: Variant = state.get("pendingLoadoutDecision")
	if not pending_value is Dictionary:
		return {}
	var pending: Dictionary = pending_value
	if pending.get("status") != "pending" or pending.get("allowedActions", {}).get(
			action) != true or pending.get("targetSlot") != "weapon":
		return {}
	var token := String(pending.get("purchaseReceiptToken", ""))
	var instance_id := String(pending.get("instanceId", ""))
	var receipt: Dictionary = state.get("treasureCommandReceipts", {}).get(token, {})
	var instance: Dictionary = state.get("treasureInstances", {}).get(instance_id, {})
	var life_text := String(state.get("runClock", {}).get("lifeId", "")).get_slice(":", 2)
	if not life_text.is_valid_int():
		return {}
	var fact: Dictionary = state.get("noncombatFlow", {}).get("spineFacts", {}).get(
		"fact:%s:sword_origin_traded" % life_text, {})
	if receipt.get("instanceId") != instance_id \
			or instance.get("definitionId") != "traded_rusted_sword" \
			or instance.get("provenance", {}).get("source") != "public_bazaar_trade" \
			or fact.get("payload", {}).get("itemInstanceId") != instance_id \
			or not String(pending.get("id", "")).begins_with("loadout:vendor:"):
		return {}
	var candidate: Dictionary = state.duplicate(true)
	if action == "equip" and not _treasures.equip_owned(candidate, instance_id, "weapon"):
		return {}
	candidate["pendingLoadoutDecision"] = null
	if not candidate.has("loadoutResolutionHistory"):
		candidate["loadoutResolutionHistory"] = []
	candidate["loadoutResolutionHistory"].append({"purchaseReceiptToken": token,
		"action": action})
	return candidate

func interact(state: Dictionary, action_id: String) -> Dictionary:
	last_error = ""
	if state.get("phase") != "VENDOR_OPEN" or not _authentic_open_session(state):
		return {}
	var candidate: Dictionary = state.duplicate(true)
	var market: Dictionary = candidate["marketState"]
	var session: Dictionary = market.get("activeSession", {})
	if session.get("status") != "open" or int(session.get("interactionBudget", {}).get(
			"remaining", 0)) <= 0 or session.get("actionReceipts", {}).has(action_id):
		return {}
	for stall in session.get("stalls", []):
		var authored: Array = stall.get("actions", []) if stall.has("actions") else [stall.get("action")]
		for action in authored:
			if not action is Dictionary or action.get("id") != action_id:
				continue
			var asks_origin: bool = action_id == "ask_luo" \
				and stall.get("id") == "luo_trader"
			if asks_origin:
				if not _ask_luo_can_start(state, action):
					return {}
			elif action.get("causalFact") != null or not action.get("costSpec", []).is_empty():
				return {}
			var cost_spec: Array = action.get("costSpec", []).duplicate(true) if asks_origin else []
			var fact_id: Variant = null
			if asks_origin:
				var fact_source: Dictionary = action["causalFact"]
				var life_text := String(candidate["runClock"]["lifeId"]).get_slice(":", 2)
				fact_id = "fact:%s:%s" % [life_text, fact_source["factTypeId"]]
				var flow: Dictionary = candidate["noncombatFlow"]
				var facts: Dictionary = flow.get("spineFacts", {}).duplicate(true)
				facts[fact_id] = {"factInstanceId": fact_id,
					"factTypeId": fact_source["factTypeId"], "lifeCount": int(life_text),
					"status": "active", "producerId": fact_source["producerId"],
					"payload": fact_source.get("payload", {}).duplicate(true),
					"createdDecisionIndex": int(session["openedAtDecisionIndex"]),
					"terminalClosure": null, "closedDecisionIndex": null}
				flow["spineFacts"] = facts
				candidate["resources"]["spiritStone"] = int(
					candidate["resources"]["spiritStone"]) - int(cost_spec[0]["amount"])
			var delta := int(action.get("relationDelta", 0))
			var relations: Dictionary = market["vendorRelations"]
			relations[stall["id"]] = int(relations.get(stall["id"], 0)) + delta
			session["interactionBudget"]["remaining"] = int(
				session["interactionBudget"]["remaining"]) - 1
			var receipt := {"actionId": action_id, "kind": "stall_interaction",
				"stallId": stall["id"], "relationDelta": delta, "costSpec": cost_spec,
				"factInstanceId": fact_id, "message": action.get("receiptText", "摊主记下了这次来往。")}
			session["actionReceipts"][action_id] = receipt
			var summary: Dictionary = session["summary"]
			summary["interactionCount"] = int(summary.get("interactionCount", 0)) + 1
			summary["exchangedItems"].append({"stallId": stall["id"],
				"direction": "interaction", "relationDelta": delta,
				"costSpec": cost_spec.duplicate(true), "factInstanceId": fact_id})
			if not candidate.has("marketActionHistory"):
				candidate["marketActionHistory"] = []
			candidate["marketActionHistory"].append({"sessionKey": session["sessionKey"],
				"actionId": action_id})
			return candidate
	return {}

func close(state: Dictionary) -> Dictionary:
	last_error = ""
	if state.get("phase") != "VENDOR_OPEN" or not _authentic_open_session(state):
		return {}
	var candidate: Dictionary = state.duplicate(true)
	var market: Dictionary = candidate["marketState"]
	var session: Dictionary = market.get("activeSession", {})
	if session.get("status") != "open" or session.get("entryCardId") != BAZAAR_ID \
			or session.get("vendorId") != "public_bazaar":
		return {}
	var next_index := int(candidate["runClock"]["decisionIndex"]) + 1
	if session.get("openedAtDecisionIndex") != next_index or session.get("sessionKey") != \
			"vendor:%s:%d:%s:public_bazaar" % [candidate["runClock"]["lifeId"],
			next_index, BAZAAR_ID]:
		return {}
	var receipt := "decision:%s:choice:%s:%d" % [candidate["runClock"]["lifeId"],
		BAZAAR_ID, next_index]
	if candidate["runClock"]["receipts"].has(receipt):
		return {}
	var summary: Dictionary = session["summary"]
	var missed: Array = []
	for offer in session["immutableOffers"]:
		missed.append({"id": offer["id"], "name": offer["name"],
			"stallId": offer.get("stallId")})
	var visit := {"visitId": "market_visit:" + String(session["sessionKey"]),
		"sessionKey": session["sessionKey"], "vendorId": "public_bazaar",
		"marketType": "public_bazaar", "decisionIndex": next_index,
		"seen": true, "refused": true,
		"outcome": "interacted" if int(summary.get("interactionCount", 0)) > 0 else "declined",
		"missedOffers": missed}
	market["visitHistory"].append(visit)
	while market["visitHistory"].size() > 48:
		var forgotten: Dictionary = market["visitHistory"].pop_front()
		var retained_actions: Array = []
		var baseline: Dictionary = market.get("vendorRelationBaseline", {}).duplicate(true)
		var profile := _profile()
		for old_action in candidate.get("marketActionHistory", []):
			if old_action.get("sessionKey") == forgotten.get("sessionKey"):
				# Ghost inspections change inventory and require their own replay
				# ledger. Only public bazaar actions may fold into relations.
				if forgotten.get("vendorId") == "ghost_market" \
						and forgotten.get("marketType") == "ghost":
					retained_actions.append(old_action)
					continue
				var source: Dictionary = _source_action(profile, String(old_action.get("actionId", "")))
				var stall_id := String(source.get("stallId", ""))
				if stall_id.is_empty():
					return {}
				baseline[stall_id] = int(baseline.get(stall_id, 0)) + int(
					source.get("action", {}).get("relationDelta", 0))
			else:
				retained_actions.append(old_action)
		market["vendorRelationBaseline"] = baseline
		candidate["marketActionHistory"] = retained_actions
		# A purchased item changed currency and health. Keep its replay input
		# until the whole run has a checkpoint for those economic effects.
	var names: Array = []
	for offer in missed.slice(0, 3):
		names.append(offer["name"])
	var missed_text := "错过了 %s 等线索" % "、".join(names)
	var interacted := int(summary.get("interactionCount", 0))
	var bought := int(summary.get("purchaseCount", 0))
	visit["refused"] = bought == 0
	visit["outcome"] = "traded" if bought > 0 else (
		"interacted" if interacted > 0 else "declined")
	var description := "你完成 %d 笔交易，并与 %d 位摊主留下来往。花费 %d 灵石；%s摊主会记得。" % [
		bought, interacted, int(summary.get("spiritStoneSpent", 0)),
		"%s，" % missed_text if bought == 0 else ""] if bought > 0 or interacted > 0 else \
		"三处摊位各有来路。你没有出手，也未留下新的口信；%s。" % missed_text
	var result_id := "vendor_result:%d:%s" % [market["visitHistory"].size(), BAZAAR_ID]
	var result_card := {"id": result_id,
		"title": "集市 · 摊主记名" if bought > 0 or interacted > 0 else "集市 · 此行收尾",
		"description": description, "type": "VENDOR_RESULT",
		"realm": candidate.get("realm", "qi"), "weight": 0, "once": true,
		"choices": {"right": {"text": "继续行程", "effects": {},
			"action": {"type": "DISMISS_VENDOR_RESULT"}}}}
	market["activeSession"] = {"version": 2, "status": "result", "resultCard": result_card}
	candidate["choiceHistory"].append({"cardId": BAZAAR_ID, "cardType": "BAZAAR",
		"direction": "left", "turn": next_index - 1,
		"decisionIndex": next_index, "tags": []})
	while candidate["choiceHistory"].size() > 30:
		candidate["choiceHistory"].pop_front()
	candidate["cardsPlayed"].append(BAZAAR_ID)
	candidate["turn"] = next_index
	candidate["runClock"]["decisionIndex"] = next_index
	candidate["runClock"]["receipts"][receipt] = {"token": receipt,
		"decisionIndex": next_index, "sourceCardId": BAZAAR_ID, "kind": "choice"}
	candidate.erase("pendingMarketChoiceCard")
	candidate.erase("marketCardLocation")
	candidate["pendingVendorResultCard"] = result_card
	candidate["currentCardId"] = result_id
	candidate["phase"] = "VENDOR_RESULT_PENDING"
	candidate["decisionCheckpoint"] = {"version": 1, "cardId": result_id,
		"sourceCardId": BAZAAR_ID, "turn": next_index,
		"decisionIndex": next_index, "vendorSessionKey": session["sessionKey"]}
	return candidate

func dismiss(state: Dictionary) -> Dictionary:
	if state.get("phase") != "VENDOR_RESULT_PENDING" or not source_valid(state):
		return {}
	var candidate: Dictionary = state.duplicate(true)
	var market: Dictionary = candidate["marketState"]
	var result: Dictionary = market.get("activeSession", {}).get("resultCard", {})
	if result.is_empty() or candidate.get("currentCardId") != result.get("id") \
			or candidate.get("pendingVendorResultCard") != result:
		return {}
	var index := int(candidate["runClock"]["decisionIndex"])
	candidate["choiceHistory"].append({"cardId": result["id"],
		"cardType": "VENDOR_RESULT", "direction": "right", "turn": index,
		"decisionIndex": index + 1, "tags": []})
	while candidate["choiceHistory"].size() > 30:
		candidate["choiceHistory"].pop_front()
	candidate["cardsPlayed"].append(result["id"])
	market["activeSession"] = null
	candidate.erase("pendingVendorResultCard")
	candidate["currentCardId"] = ""
	candidate["phase"] = "FLOW_PENDING"
	candidate["decisionCheckpoint"] = {"version": 1, "cardId": null,
		"sourceCardId": result["id"], "turn": index,
		"decisionIndex": index, "flowPending": true}
	return candidate

func _profile() -> Dictionary:
	var source: Variant = _content.read_module(PROFILE_MODULE)
	if not source is Dictionary:
		last_error = "坊市摊主来源不可用"
		return {}
	for vendor in source.get("vendors", []):
		if vendor is Dictionary and vendor.get("id") == "public_bazaar":
			return vendor
	last_error = "公开集市摊主配置缺失"
	return {}

func _source_action(profile: Dictionary, action_id: String) -> Dictionary:
	for stall in profile.get("stalls", []):
		var actions: Array = stall.get("actions", []) if stall.has("actions") else [stall.get("action")]
		for action in actions:
			if action is Dictionary and action.get("id") == action_id:
				return {"stallId": stall.get("id"), "action": action}
	return {}

func _supported_offer(offer: Dictionary) -> bool:
	if offer.has("costSpec") or offer.has("costModes"):
		return false
	if offer.get("stallId") == "han_peddler" and offer.get("type") == "pill":
		return int(offer.get("effect", {}).get("healHp", 0)) > 0
	return offer.get("stallId") == "luo_trader" and offer.get("type") == "story_item" \
		and not String(offer.get("effect", {}).get("itemId", "")).is_empty() \
		and int(offer.get("effect", {}).get("quantity", 1)) > 0

func _ask_luo_contract_valid(state: Dictionary, action: Dictionary) -> bool:
	if action.get("id") != "ask_luo":
		return false
	var cost: Array = action.get("costSpec", [])
	var source: Dictionary = action.get("causalFact", {})
	if cost.size() != 1 or not cost[0] is Dictionary \
			or cost[0].get("kind") != "resource" \
			or cost[0].get("key") != "spiritStone" \
			or int(cost[0].get("amount", -1)) <= 0 \
			or source.get("factTypeId") != "rumor_rusted_sword_origin" \
			or source.get("producerId") != "bazaar_xu_rusted_origin" \
			or not source.get("payload") is Dictionary:
		return false
	var flow: Dictionary = state.get("noncombatFlow", {})
	var pin := String(flow.get("causalGraphSourceSha", ""))
	if pin.length() != 64 or pin != _content.source_sha256("narrative:causal_graph"):
		return false
	var graph: Variant = _content.read_module("narrative:causal_graph")
	if not graph is Dictionary:
		return false
	for entry in graph.get("factTypes", []):
		if entry is Dictionary and entry.get("factTypeId") == source["factTypeId"]:
			return true
	return false

func _ask_luo_fact_id(state: Dictionary, action: Dictionary) -> String:
	var life_text := String(state.get("runClock", {}).get("lifeId", "")).get_slice(":", 2)
	if not life_text.is_valid_int():
		return ""
	return "fact:%s:%s" % [life_text, action.get("causalFact", {}).get("factTypeId", "")]

func _ask_luo_can_start(state: Dictionary, action: Dictionary) -> bool:
	if not _ask_luo_contract_valid(state, action):
		return false
	var fact_id := _ask_luo_fact_id(state, action)
	return not fact_id.is_empty() \
		and not state.get("noncombatFlow", {}).get("spineFacts", {}).has(fact_id) \
		and int(state.get("resources", {}).get("spiritStone", 0)) >= int(
			action["costSpec"][0]["amount"])

func _ask_luo_record_valid(state: Dictionary, action: Dictionary,
		session_key: String) -> bool:
	if not _ask_luo_contract_valid(state, action):
		return false
	var fact_id := _ask_luo_fact_id(state, action)
	var fact: Dictionary = state.get("noncombatFlow", {}).get("spineFacts", {}).get(
		fact_id, {})
	var life_text := String(state.get("runClock", {}).get("lifeId", "")).get_slice(":", 2)
	var decision_text := session_key.get_slice(":", 4)
	return decision_text.is_valid_int() and not fact_id.is_empty() \
		and fact.get("factInstanceId") == fact_id \
		and fact.get("factTypeId") == action["causalFact"]["factTypeId"] \
		and fact.get("producerId") == action["causalFact"]["producerId"] \
		and int(fact.get("lifeCount", -1)) == int(life_text) \
		and int(fact.get("createdDecisionIndex", -1)) == int(decision_text) \
		and JSON.stringify(fact.get("payload", {})) == JSON.stringify(
			action["causalFact"].get("payload", {}))

func _sword_favor_cost(offer: Dictionary) -> int:
	for mode in offer.get("costModes", []):
		if not mode is Dictionary or mode.get("id") != "favor":
			continue
		var spec: Array = mode.get("costSpec", [])
		if spec.size() == 1 and spec[0] is Dictionary \
				and spec[0].get("kind") == "resource" \
				and spec[0].get("key") == "spiritStone":
			return int(spec[0].get("amount", -1))
	return -1

func _purchase_favor_sword(candidate: Dictionary, session: Dictionary,
		offer: Dictionary, price: int) -> bool:
	var favor: Dictionary = {}
	for mode in offer.get("costModes", []):
		if mode is Dictionary and mode.get("id") == "favor":
			favor = mode
			break
	var relation_rule: Dictionary = favor.get("requiresVendorRelation", {})
	var cost: Array = favor.get("costSpec", [])
	if relation_rule.get("stallId") != "luo_trader" \
			or int(candidate.get("marketState", {}).get("vendorRelations", {}).get(
				"luo_trader", 0)) < int(relation_rule.get("minimum", 1)) \
			or cost.size() != 1 or cost[0].get("kind") != "resource" \
			or cost[0].get("key") != "spiritStone" \
			or int(cost[0].get("amount", -1)) != price \
			or candidate.get("pendingLoadoutDecision") != null:
		return false
	var narrative: Dictionary = offer.get("narrativeProvenance", {})
	var fact_type := String(narrative.get("factTypeId", ""))
	var graph: Variant = _content.read_module("narrative:causal_graph")
	var defined := false
	if graph is Dictionary:
		for entry in graph.get("factTypes", []):
			if entry.get("factTypeId") == fact_type:
				defined = true
				break
	var flow: Dictionary = candidate.get("noncombatFlow", {})
	var causal_pin := String(flow.get("causalGraphSourceSha", ""))
	if causal_pin.length() != 64 \
			or causal_pin != _content.source_sha256("narrative:causal_graph"):
		return false
	var facts: Dictionary = flow.get("spineFacts", {})
	var life_text := String(candidate.get("runClock", {}).get("lifeId", "")).get_slice(
		":", 2)
	var fact_id := "fact:%s:%s" % [life_text, fact_type]
	if not defined or fact_type != "sword_origin_traded" or facts.has(fact_id) \
			or not life_text.is_valid_int():
		return false
	var definition_id := String(offer.get("effect", {}).get("treasureId", ""))
	var catalog: Variant = _content.read_module("shops:treasures")
	var definition: Dictionary = {}
	if catalog is Dictionary:
		for entry in catalog.get("treasures", []):
			if entry.get("id") == definition_id:
				definition = entry
				break
	if definition.get("type") != "weapon":
		return false
	var next_index := int(candidate["runClock"]["decisionIndex"]) + 1
	var session_key := String(session["sessionKey"])
	var offer_id := String(offer["id"])
	var token := "treasure:shop:life:%s:decision:%d:session:%s:offer:%s" % [
		candidate["runClock"]["lifeId"], next_index, session_key, offer_id]
	var provenance: Dictionary = narrative.get("payload", {}).duplicate(true)
	provenance["exchangeMode"] = "favor"
	provenance["exchangeLabel"] = favor.get("provenanceLabel", favor.get("label"))
	if not _treasures.acquire(candidate, definition_id, offer_id, next_index,
			{"source": "public_bazaar_trade", "channel": "public_bazaar",
			"transactionId": token, "sourceId": session_key + ":" + offer_id,
			"details": provenance}):
		return false
	var acquisition: Dictionary = candidate.get("treasureCommandReceipts", {}).get(token, {})
	var instance_id := String(acquisition.get("instanceId", ""))
	if instance_id.is_empty():
		return false
	var payload: Dictionary = narrative.get("payload", {}).duplicate(true)
	payload.merge({"itemInstanceId": instance_id, "exchangeMode": "favor",
		"exchangeLabel": provenance["exchangeLabel"],
		"source": "public_bazaar_trade", "sessionKey": session_key,
		"offerId": offer_id}, true)
	facts = facts.duplicate(true)
	facts[fact_id] = {"factInstanceId": fact_id, "factTypeId": fact_type,
		"lifeCount": int(life_text), "status": "active",
		"producerId": narrative.get("producerId"), "payload": payload,
		"createdDecisionIndex": next_index, "terminalClosure": null,
		"closedDecisionIndex": null}
	flow["spineFacts"] = facts
	candidate["noncombatFlow"] = flow
	candidate["pendingLoadoutDecision"] = {"id": "loadout:%s:%s" % [session_key, offer_id],
		"instanceId": instance_id, "sourceVendorSessionKey": session_key,
		"purchaseReceiptToken": token, "targetSlot": "weapon", "status": "pending",
		"allowedActions": {"equip": true, "stash": true,
			"viewProvenance": true, "return": false}, "refundPolicy": null}
	return true

func _history_projection(state: Dictionary, profile: Dictionary) -> Dictionary:
	var history: Variant = state.get("marketActionHistory", [])
	var market: Dictionary = state.get("marketState", {})
	var relations: Variant = market.get("vendorRelations", {})
	if not history is Array or not relations is Dictionary:
		return {"valid": false}
	var baseline: Variant = market.get("vendorRelationBaseline", {})
	if not baseline is Dictionary:
		return {"valid": false}
	var allowed_stalls := {}
	for stall in profile.get("stalls", []):
		allowed_stalls[stall.get("id")] = true
	for stall_id in baseline:
		if not allowed_stalls.has(stall_id) or int(baseline[stall_id]) < 0:
			return {"valid": false}
	var visits := {}
	for visit in market.get("visitHistory", []):
		if not visit is Dictionary or not visit.get("sessionKey") is String:
			return {"valid": false}
		var visit_key := String(visit["sessionKey"])
		if visits.has(visit_key):
			return {"valid": false}
		visits[visit_key] = visit
	var current_key := ""
	if state.get("phase") == "VENDOR_OPEN" \
			and market.get("activeSession", {}).get("status") == "open":
		current_key = "vendor:%s:%d:%s:public_bazaar" % [
			state.get("runClock", {}).get("lifeId", ""),
			int(state.get("runClock", {}).get("decisionIndex", -1)) + 1, BAZAAR_ID]
	var expected: Dictionary = baseline.duplicate(true)
	var seen := {}
	var by_session := {}
	var ghost_actions := {}
	var ghost_events: Variant = state.get("ghostVendorEventHistory", [])
	if not ghost_events is Array:
		return {"valid": false}
	for ghost_event in ghost_events:
		if not ghost_event is Dictionary:
			return {"valid": false}
		if ghost_event.get("kind") != "action":
			continue
		var ghost_key := String(ghost_event.get("sessionKey", "")) + "|" + String(
			ghost_event.get("actionId", ""))
		if ghost_actions.has(ghost_key):
			return {"valid": false}
		ghost_actions[ghost_key] = true
	var budget := maxi(0, int(profile.get("interactionBudget", 0)))
	for event in history:
		if not event is Dictionary or not event.get("sessionKey") is String \
				or not event.get("actionId") is String:
			return {"valid": false}
		var key := String(event["sessionKey"])
		var action_id := String(event["actionId"])
		if key.ends_with(":%s:ghost_market" % MarketFlow.GHOST_ID):
			var ghost_prefix := "vendor:%s:" % String(state.get(
				"runClock", {}).get("lifeId", ""))
			var ghost_index_text := key.trim_prefix(ghost_prefix).trim_suffix(
				":%s:ghost_market" % MarketFlow.GHOST_ID)
			var ghost_record := key + "|" + action_id
			if not key.begins_with(ghost_prefix) \
					or not ghost_index_text.is_valid_int() \
					or int(ghost_index_text) < 0 \
					or int(ghost_index_text) > int(state.get("runClock", {}).get(
						"decisionIndex", -1)) \
					or not action_id.begins_with("ghost_inspect_seal:") \
					or action_id.trim_prefix("ghost_inspect_seal:").is_empty() \
					or not ghost_actions.has(ghost_record):
				return {"valid": false}
			var ghost_visit: Dictionary = visits.get(key, {})
			if not ghost_visit.is_empty():
				if ghost_visit.get("vendorId") != "ghost_market" \
						or ghost_visit.get("marketType") != "ghost" \
						or ghost_visit.get("seen") != true \
						or ghost_visit.get("outcome") not in ["declined", "traded"] \
						or int(ghost_visit.get("decisionIndex", -1)) != int(ghost_index_text):
					return {"valid": false}
			else:
				# The 48-visit window may evict old ghost visits. Their action
				# record remains necessary to replay the spent route-note item.
				if market.get("visitHistory", []).size() < 48:
					return {"valid": false}
				var oldest_visit := 2147483647
				for visit_row in market["visitHistory"]:
					oldest_visit = mini(oldest_visit, int(visit_row.get(
						"decisionIndex", 2147483647)))
				if int(ghost_index_text) >= oldest_visit:
					return {"valid": false}
			ghost_actions.erase(ghost_record)
			continue
		if key != current_key:
			var visit: Dictionary = visits.get(key, {})
			if visit.is_empty() or visit.get("vendorId") != "public_bazaar" \
					or visit.get("marketType") != "public_bazaar" \
					or visit.get("seen") != true \
					or visit.get("outcome") not in ["interacted", "traded"] \
					or key != "vendor:%s:%d:%s:public_bazaar" % [
						state.get("runClock", {}).get("lifeId", ""),
						int(visit.get("decisionIndex", -1)), BAZAAR_ID]:
				return {"valid": false}
		elif market.get("activeSession", {}).get("sessionKey") != key:
			return {"valid": false}
		var source := _source_action(profile, action_id)
		var action: Dictionary = source.get("action", {})
		if action.is_empty():
			return {"valid": false}
		if action_id == "ask_luo":
			if source.get("stallId") != "luo_trader" \
					or not _ask_luo_record_valid(state, action, key):
				return {"valid": false}
		elif action.get("causalFact") != null \
				or not action.get("costSpec", []).is_empty():
			return {"valid": false}
		var unique := key + ":" + action_id
		if seen.has(unique):
			return {"valid": false}
		seen[unique] = true
		if not by_session.has(key):
			by_session[key] = []
		by_session[key].append({"actionId": action_id, "stallId": source["stallId"],
			"action": action})
		if by_session[key].size() > budget:
			return {"valid": false}
		var stall_id := String(source["stallId"])
		expected[stall_id] = int(expected.get(stall_id, 0)) + int(action.get("relationDelta", 0))
	if not ghost_actions.is_empty():
		return {"valid": false}
	if JSON.parse_string(JSON.stringify(expected)) != \
			JSON.parse_string(JSON.stringify(relations)):
		return {"valid": false}
	return {"valid": true, "relations": expected, "bySession": by_session}

func _authentic_open_session(state: Dictionary) -> bool:
	if not source_valid(state):
		return false
	var profile := _profile()
	if profile.is_empty():
		return false
	var projection := _history_projection(state, profile)
	if not projection.get("valid", false):
		return false
	var session: Dictionary = state.get("marketState", {}).get("activeSession", {})
	var next_index := int(state.get("runClock", {}).get("decisionIndex", -1)) + 1
	var expected_key := "vendor:%s:%d:%s:public_bazaar" % [
		state.get("runClock", {}).get("lifeId", ""), next_index, BAZAAR_ID]
	if session.get("status") != "open" or session.get("sessionKey") != expected_key:
		return false
	var current_events: Array = projection.get("bySession", {}).get(expected_key, [])
	var previous_history: Array = []
	for event in state.get("marketActionHistory", []):
		if event.get("sessionKey") != expected_key:
			previous_history.append(event)
	var before_relations: Dictionary = projection["relations"].duplicate(true)
	for event in current_events:
		var stall_id := String(event["stallId"])
		before_relations[stall_id] = int(before_relations.get(stall_id, 0)) - int(
			event["action"].get("relationDelta", 0))
		if before_relations[stall_id] == 0:
			before_relations.erase(stall_id)
	var base: Dictionary = state.duplicate(true)
	base["phase"] = "MARKET_PENDING"
	base["currentCardId"] = BAZAAR_ID
	base["marketState"]["activeSession"] = null
	base["marketState"]["vendorRelations"] = before_relations
	if previous_history.is_empty():
		base.erase("marketActionHistory")
	else:
		base["marketActionHistory"] = previous_history
	var projected: Dictionary = open(base)
	if projected.is_empty():
		return false
	var source_session: Dictionary = projected["marketState"]["activeSession"]
	var receipts := {}
	var summary: Dictionary = source_session["summary"]
	if not current_events.is_empty():
		summary["interactionCount"] = current_events.size()
	for event in current_events:
		var action: Dictionary = event["action"]
		var action_id := String(event["actionId"])
		var stall_id := String(event["stallId"])
		var delta := int(action.get("relationDelta", 0))
		var asks_origin: bool = action_id == "ask_luo" and stall_id == "luo_trader"
		var cost_spec: Array = action.get("costSpec", []).duplicate(true) if asks_origin else []
		var fact_id: Variant = _ask_luo_fact_id(state, action) if asks_origin else null
		receipts[action_id] = {"actionId": action_id, "kind": "stall_interaction",
			"stallId": stall_id, "relationDelta": delta, "costSpec": cost_spec,
			"factInstanceId": fact_id,
			"message": action.get("receiptText", "摊主记下了这次来往。")}
		summary["exchangedItems"].append({"stallId": stall_id,
			"direction": "interaction", "relationDelta": delta,
			"costSpec": cost_spec.duplicate(true), "factInstanceId": fact_id})
	source_session["actionReceipts"] = receipts
	source_session["interactionBudget"]["remaining"] = int(
		source_session["interactionBudget"]["limit"]) - current_events.size()
	var purchase_history: Variant = state.get("marketPurchaseHistory", [])
	if not purchase_history is Array:
		return false
	var purchase_seen := {}
	for event in purchase_history:
		if not event is Dictionary or not event.get("sessionKey") is String \
				or not event.get("offerId") is String:
			return false
		var key := String(event["sessionKey"])
		var offer_id := String(event["offerId"])
		var mode := String(event.get("costMode", ""))
		var purchase_unique := key + ":" + offer_id
		if purchase_seen.has(purchase_unique):
			return false
		purchase_seen[purchase_unique] = true
		if key != expected_key:
			var visit: Dictionary = {}
			for row in state.get("marketState", {}).get("visitHistory", []):
				if row.get("sessionKey") == key:
					visit = row
					break
			# Official-market purchases are replayed by their own consumer. A
			# later public bazaar must preserve those receipts without treating
			# them as missing public-stall offers.
			if visit.get("vendorId") == "regulated_market" \
					and visit.get("marketType") == "regulated":
				var official_card := "q_market" if key.ends_with(
					":q_market:regulated_market") else "shop_encounter"
				if visit.get("outcome") != "traded" or key != \
						"vendor:%s:%d:%s:regulated_market" % [
							state.get("runClock", {}).get("lifeId", ""),
							int(visit.get("decisionIndex", -1)), official_card] \
						or visit.get("missedOffers", []).any(func(missed: Variant) -> bool:
							return missed is Dictionary and missed.get("id") == offer_id):
					return false
				continue
			if visit.is_empty():
				if not _archived_purchase_valid(state, profile, key, offer_id, mode) \
						and not _archived_regulated_purchase_valid(state, key, offer_id, mode):
					return false
			elif visit.get("outcome") != "traded" or key != \
					"vendor:%s:%d:%s:public_bazaar" % [
						state.get("runClock", {}).get("lifeId", ""),
						int(visit.get("decisionIndex", -1)), BAZAAR_ID]:
				return false
			continue
		var offer: Dictionary = {}
		for item in source_session["immutableOffers"]:
			if item.get("id") == offer_id:
				offer = item
				break
		var sword: bool = offer.get("id") == "bazaar_luo_traded_rusted_sword" \
			and offer.get("type") == "treasure" and offer.get("stallId") == "luo_trader"
		if sword and (mode != "favor" or int(projection.get("relations", {}).get(
				"luo_trader", 0)) < 1):
			return false
		if (not sword and not _supported_offer(offer)) or (not sword and not mode.is_empty()):
			return false
		var price := _sword_favor_cost(offer) if sword else int(offer.get("price", -1))
		if price < 0:
			return false
		var remaining: Array = []
		for item in source_session["immutableOffers"]:
			if item.get("id") != offer_id:
				remaining.append(item)
		source_session["immutableOffers"] = remaining
		summary["purchaseCount"] = int(summary.get("purchaseCount", 0)) + 1
		summary["spiritStoneSpent"] = int(summary.get("spiritStoneSpent", 0)) + price
		var receipt := {"id": offer_id, "name": offer["name"],
			"costSpec": [{"kind": "resource", "key": "spiritStone", "amount": price}]}
		if sword:
			receipt["costMode"] = mode
		summary["purchasedItems"].append(receipt)
	return JSON.parse_string(JSON.stringify(session)) == \
		JSON.parse_string(JSON.stringify(source_session))

func _archived_purchase_valid(state: Dictionary, profile: Dictionary,
		key: String, offer_id: String, mode: String) -> bool:
	var visits: Array = state.get("marketState", {}).get("visitHistory", [])
	if visits.is_empty():
		return false
	var first_index := int(visits.front().get("decisionIndex", -1))
	var prefix := "vendor:%s:" % state.get("runClock", {}).get("lifeId", "")
	var suffix := ":%s:public_bazaar" % BAZAAR_ID
	if not key.begins_with(prefix) or not key.ends_with(suffix):
		return false
	var number := key.substr(prefix.length(), key.length() - prefix.length() - suffix.length())
	if not number.is_valid_int() or int(number) <= 0 or int(number) >= first_index:
		return false
	for stall in profile.get("stalls", []):
		if stall.get("id") not in ["han_peddler", "luo_trader"]:
			continue
		var authored: Array = stall.get("offers", []).duplicate(true)
		if stall.get("relationship", {}).get("specialOffer") is Dictionary:
			authored.append(stall["relationship"]["specialOffer"])
		for raw in authored:
			var offer: Dictionary = raw.duplicate(true)
			offer["stallId"] = stall["id"]
			var sword: bool = offer.get("id") == "bazaar_luo_traded_rusted_sword" \
				and offer.get("type") == "treasure" and offer.get("stallId") == "luo_trader"
			if offer.get("id") == offer_id and (sword and mode == "favor" \
					or _supported_offer(offer) and mode.is_empty()):
				return true
	return false

func _archived_regulated_purchase_valid(state: Dictionary, key: String,
		offer_id: String, mode: String) -> bool:
	if not mode.is_empty():
		return false
	var authentic_item := offer_id in ["shop_pill_foundation", "shop_pill_healing"]
	var items: Variant = _content.read_module("shops:shop_items")
	if items is Dictionary:
		for item in items.get("items", []):
			if item is Dictionary and item.get("id") == offer_id \
					and item.get("type") == "gift" and item.get("realm") == "qi":
				authentic_item = true
	if not authentic_item:
		return false
	var visits: Array = state.get("marketState", {}).get("visitHistory", [])
	if visits.is_empty():
		return false
	var prefix := "vendor:%s:" % state.get("runClock", {}).get("lifeId", "")
	var suffix := ":q_market:regulated_market" if key.ends_with(
		":q_market:regulated_market") else ":shop_encounter:regulated_market"
	if not key.begins_with(prefix) or not key.ends_with(suffix):
		return false
	var number := key.substr(prefix.length(), key.length() - prefix.length() - suffix.length())
	if not number.is_valid_int() or int(number) <= 0 \
			or int(number) >= int(visits.front().get("decisionIndex", -1)):
		return false
	for entry in state.get("normalFlow", {}).get("shopEntries", []):
		if not entry is Dictionary or int(entry.get("decisionIndex", -1)) != int(number):
			continue
		for quote in entry.get("quote", []):
			if quote is Dictionary and quote.get("id") == offer_id \
					and int(quote.get("price", -1)) > 0:
				return true
	return false
