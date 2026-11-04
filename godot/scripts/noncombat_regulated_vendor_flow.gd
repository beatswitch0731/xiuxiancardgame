extends RefCounted

const Catalog = preload("res://scripts/noncombat_regulated_shop_catalog.gd")
const LegacyFragmentFlow = preload("res://scripts/noncombat_legacy_fragment_flow.gd")
const PathSkillFlow = preload("res://scripts/noncombat_path_skill_flow.gd")
const NormalChoicePolicy = preload("res://scripts/noncombat_normal_choice_policy.gd")
const MilestoneFlow = preload("res://scripts/noncombat_milestone_flow.gd")
const TreasureAcquisition = preload("res://scripts/noncombat_treasure_acquisition.gd")
const DeckAcquisition = preload("res://scripts/noncombat_deck_acquisition.gd")
const VENDOR_ID := "regulated_market"
const PROFILE_MODULE := "markets:vendor_profiles"
const FIRST_MARKET_ID := "loc_market_first"
const FIRST_MARKET_MODULE := "locations:locations"
const IDENTIFY_JS_SHA := "7552c41cbb707c642c1b66d434c084c33241227ada146ff9322ba707a53a72dc"

var _content: RefCounted
var _catalog: RefCounted
var _choice_policy: RefCounted
var _treasures: RefCounted
var _deck: RefCounted
var last_error := ""
var causal_activation_index := 0

func _init(content: RefCounted) -> void:
	_content = content
	_catalog = Catalog.new(content)
	_choice_policy = NormalChoicePolicy.new(content)
	_treasures = TreasureAcquisition.new(content)
	_deck = DeckAcquisition.new(content)

func source_valid(state: Dictionary) -> bool:
	var session: Variant = state.get("marketState", {}).get("activeSession")
	if session is Dictionary and session.get("entryCardId") == FIRST_MARKET_ID:
		var entry_sha: String = _content.source_sha256(FIRST_MARKET_MODULE)
		if entry_sha.length() != 64 or session.get("entrySourceSha") != entry_sha:
			return false
	return state.get("regulatedProfileSourceSha") == _content.source_sha256(PROFILE_MODULE) \
		and state.get("regulatedCatalogPins") == _catalog.source_pins() \
		and (not state.has("regulatedCausalServiceVersion") or (
			state.get("regulatedCausalServiceVersion") == 1 \
			and (state.get("regulatedCausalActivationIndex") is float \
				or state.get("regulatedCausalActivationIndex") is int) \
			and state.get("regulatedCausalGraphSourceSha") == _content.source_sha256(
				"narrative:causal_graph")))

func open(state: Dictionary, offers: Array, authored_card: Dictionary = {}) -> Dictionary:
	last_error = ""
	var card_id := String(authored_card.get("id", "")) if not authored_card.is_empty() else Catalog.CARD_ID
	var card: Dictionary = authored_card if not authored_card.is_empty() else _catalog.card(state)
	var first_market := card_id == FIRST_MARKET_ID
	var direction := "left" if card_id in ["q_market", FIRST_MARKET_ID] else "right"
	var expected_phase := "FIRST_SESSION_ROUTE_PENDING" if first_market else "SHOP_PENDING"
	if card_id not in [Catalog.CARD_ID, "q_market", FIRST_MARKET_ID] \
			or not authored_card.is_empty() and card_id not in ["q_market", FIRST_MARKET_ID] \
			or state.get("phase") != expected_phase or state.get("currentCardId") != card_id \
			or card.get("id") != card_id or card.get("choices", {}).get(
				direction, {}).get("action", {}).get("vendorId") != VENDOR_ID \
			or offers.is_empty() \
			or state.get("marketState", {}).get("activeSession") != null:
		return {}
	if first_market and (state.get("realm") != "qi" or card != _first_market_card()):
		return {}
	var profile := _profile()
	if profile.is_empty() or int(profile.get("interactionBudget", -1)) != 0:
		return {}
	var next := state.duplicate(true)
	var index := int(next["runClock"]["decisionIndex"]) + 1
	var causal_services: Array = []
	if index >= causal_activation_index:
		causal_services = _materialize_causal_services(next, index)
		if last_error != "":
			return {}
		next["regulatedCausalServiceVersion"] = 1
		if not next.has("regulatedCausalActivationIndex"):
			next["regulatedCausalActivationIndex"] = index
		next["regulatedCausalGraphSourceSha"] = _content.source_sha256(
			"narrative:causal_graph")
	var key := _session_key(next, index, card_id)
	var session := {"version": 2, "status": "open", "sessionId": key,
		"sessionKey": key, "vendorId": VENDOR_ID, "marketType": "regulated",
		"entryCardId": card_id, "openedAtDecisionIndex": index,
		"offerRevision": 1, "immutableOffers": offers.duplicate(true),
		"actionReceipts": {}, "interactionBudget": {"limit": 0, "remaining": 0},
		"stalls": [], "services": profile.get("services", []).duplicate(true) \
			+ causal_services,
		"riskRules": {}, "debt": null,
		"presentationProfile": profile.get("presentationProfile", {}).duplicate(true),
		"exitContract": profile.get("exitContract", ""),
		"summary": {"openingOfferCount": offers.size(), "purchaseCount": 0,
			"spiritStoneSpent": 0, "purchasedItems": [], "exchangedItems": []},
		"openedAtTurn": int(next["turn"]), "direction": direction,
		"card": card.duplicate(true),
		"choice": card["choices"][direction].duplicate(true)}
	if first_market:
		session["entrySourceSha"] = _content.source_sha256(FIRST_MARKET_MODULE)
	next["marketState"]["activeSession"] = session
	next["regulatedProfileSourceSha"] = _content.source_sha256(PROFILE_MODULE)
	next["regulatedCatalogPins"] = _catalog.source_pins()
	next["phase"] = "VENDOR_OPEN"
	next["currentCardId"] = "vendor_pending:" + card_id
	next["decisionCheckpoint"] = {"version": 1,
		"cardId": next["currentCardId"], "sourceCardId": card_id,
		"turn": next["turn"], "decisionIndex": next["runClock"]["decisionIndex"],
		"vendorSessionKey": key}
	return next

func pending_card(state: Dictionary) -> Dictionary:
	if not _open_valid(state):
		return {}
	var card_id := String(state["marketState"]["activeSession"]["entryCardId"])
	return {"id": "vendor_pending:" + card_id,
		"title": "官坊交易进行中", "type": "VENDOR_PENDING",
		"description": "明码报价与回购服务已锁定。请完成交易或离开，结算后再继续行程。",
		"realm": state.get("realm", "qi"), "weight": 0, "once": true,
		"choices": {}}

func available_offers(state: Dictionary) -> Array:
	if not _open_valid(state):
		return []
	var result: Array = []
	for offer in state["marketState"]["activeSession"]["immutableOffers"]:
		var supported := _supported(offer, state)
		var price := int(offer.get("price", -1))
		result.append({"id": offer.get("id"), "name": offer.get("name"),
			"price": price, "stallName": "万宝楼", "supported": supported,
			"enabled": supported and price >= 0 and int(state.get("resources", {}).get(
				"spiritStone", 0)) >= price})
	return result

func available_actions(state: Dictionary) -> Array:
	if not _open_valid(state):
		return []
	return available_actions_session(state)

func available_actions_session(state: Dictionary) -> Array:
	var session: Dictionary = state["marketState"]["activeSession"]
	var result: Array = []
	for service_entry in session.get("services", []):
		if not service_entry is Dictionary or service_entry.get("kind") not in [
				"causal_fact_consumer", "causal_fact_closed"]:
			continue
		var cost_spec: Array = service_entry.get("costSpec", []).duplicate(true)
		var cost_text := ""
		if cost_spec.size() == 1 and cost_spec[0] is Dictionary \
				and cost_spec[0].get("kind") == "resource" \
				and cost_spec[0].get("key") == "spiritStone":
			cost_text = "%d 灵石" % int(cost_spec[0].get("amount", 0))
		var order_enabled: bool = service_entry.get("kind") == "causal_fact_consumer" \
			and service_entry.get("consumerId") == "regulated_rusted_sword_order" \
			and service_entry.get("delivery", {}).get("definitionId") \
				== "licensed_rusted_sword" \
			and cost_spec.size() == 1 and cost_spec[0] is Dictionary \
			and int(state.get("resources", {}).get("spiritStone", 0)) \
				>= int(cost_spec[0].get("amount", 2147483647)) \
			and not session.get("actionReceipts", {}).has(
				service_entry.get("actionId"))
		result.append({"id": service_entry.get("actionId"),
			"label": service_entry.get("label", "登记凭据"),
			"description": service_entry.get("description", ""),
			"stallName": "万宝楼 · 流转号", "costSpec": cost_spec,
			"costText": cost_text, "enabled": order_enabled,
			"disabledReason": service_entry.get("terminalClosure",
				"灵石不足或订货凭据已结清")})
	var service: Dictionary = _buyback_service(session)
	if service.is_empty():
		return result
	var inventory: Variant = state.get("itemInventory", {})
	if not inventory is Dictionary:
		return result
	for raw in _shop_items():
		if not raw is Dictionary or raw.get("type") not in service.get("acceptedKinds", []):
			continue
		var item_id := String(raw.get("effect", {}).get("giftItemId", raw.get("id", "")))
		if item_id.is_empty() or int(inventory.get(item_id, 0)) <= 0:
			continue
		var action_id := "regulated_buyback:" + item_id
		result.append({"id": action_id, "label": "回购 " + String(raw.get("name", item_id)),
			"stallName": "合规回购台", "payout": int(service.get("payout", 0)),
			"enabled": not session.get("actionReceipts", {}).has(action_id)})
	return result


func _materialize_causal_services(next: Dictionary, decision_index: int) -> Array:
	var document: Variant = _content.read_module("narrative:causal_graph")
	if not document is Dictionary or document.get("version") != 1:
		last_error = "因果来源不可用"
		return []
	var facts: Variant = next.get("noncombatFlow", {}).get("spineFacts", {})
	if not facts is Dictionary:
		last_error = "流转号事实账本不可用"
		return []
	var result: Array = []
	for fact_id in facts:
		var fact: Variant = facts[fact_id]
		if not fact is Dictionary or fact.get("factInstanceId") != fact_id:
			last_error = "流转号事实无效"
			return []
		for definition in document.get("factTypes", []):
			if not definition is Dictionary or definition.get("factTypeId") != fact.get(
					"factTypeId"):
				continue
			for consumer in definition.get("consumers", []):
				if not consumer is Dictionary or consumer.get("mode") == "observe" \
						or consumer.get("vendorId") != VENDOR_ID:
					continue
				var created := int(fact.get("createdDecisionIndex", -1))
				var first := created + int(consumer.get("earliestDecisionOffset", 0))
				var last := created + int(consumer.get("latestDecisionOffset", -1))
				if created < 0 or first > last:
					last_error = "流转号期限无效"
					return []
				if fact.get("status") == "active" and decision_index > last:
					fact["status"] = "closed"
					fact["closedDecisionIndex"] = decision_index
					fact["terminalClosure"] = consumer.get("terminalClosure",
						"这条线索已无从追查。")
				if fact.get("status") == "active" and decision_index >= first \
						and decision_index <= last:
					var presentation := _causal_presentation(consumer, fact)
					result.append({"id": consumer["consumerId"],
						"kind": "causal_fact_consumer",
						"actionId": "causal_fact:%s:%s" % [consumer["consumerId"],
							fact_id], "factInstanceId": fact_id,
						"factTypeId": fact["factTypeId"],
						"consumerId": consumer["consumerId"],
						"label": presentation["label"],
						"description": presentation["description"],
						"receiptText": presentation["receiptText"],
						"costSpec": consumer.get("costSpec", []).duplicate(true),
						"delivery": consumer.get("delivery", {}).duplicate(true),
						"available": true})
				elif fact.get("status") == "closed":
					result.append({"id": "%s:closed:%s" % [
						consumer["consumerId"], fact_id],
						"kind": "causal_fact_closed",
						"actionId": "causal_fact_closed:%s:%s" % [
							consumer["consumerId"], fact_id],
						"factInstanceId": fact_id,
						"consumerId": consumer["consumerId"],
						"label": "流转号已逾期",
						"description": fact.get("terminalClosure", consumer.get(
							"terminalClosure", "")),
						"terminalClosure": fact.get("terminalClosure", consumer.get(
							"terminalClosure", "")), "available": false})
	return result


func _causal_presentation(consumer: Dictionary, fact: Dictionary) -> Dictionary:
	var result := {"label": consumer.get("label", ""),
		"description": consumer.get("description", ""),
		"receiptText": consumer.get("receiptText", "")}
	var rule: Variant = consumer.get("presentationByPayload", {})
	if not rule is Dictionary:
		return result
	var payload_key: String = String(rule.get("payloadKey", ""))
	var payload: Variant = fact.get("payload", {})
	if payload_key.is_empty() or not payload is Dictionary:
		return result
	var variant_key: Variant = payload.get(payload_key)
	if not variant_key is String:
		return result
	var variant: Variant = rule.get("variants", {}).get(variant_key, {})
	if not variant is Dictionary:
		return result
	for field in ["label", "description", "receiptText"]:
		if variant.get(field) is String and not String(variant[field]).is_empty():
			result[field] = variant[field]
	return result

func interact(state: Dictionary, action_id: String) -> Dictionary:
	if not _open_valid(state):
		return {}
	return interact_session(state, action_id)

func interact_session(state: Dictionary, action_id: String) -> Dictionary:
	if action_id.begins_with("causal_fact:"):
		return _register_causal_order(state, action_id)
	if not action_id.begins_with("regulated_buyback:"):
		return {}
	var next: Dictionary = state.duplicate(true)
	var session: Dictionary = next["marketState"]["activeSession"]
	var service: Dictionary = _buyback_service(session)
	var item_id := action_id.trim_prefix("regulated_buyback:")
	if service.is_empty() or session["actionReceipts"].has(action_id) \
			or not next.get("itemInventory") is Dictionary:
		return {}
	var source: Dictionary = {}
	for raw in _shop_items():
		if raw is Dictionary and String(raw.get("effect", {}).get("giftItemId",
				raw.get("id", ""))) == item_id and raw.get("type") in service.get(
				"acceptedKinds", []):
			source = raw
			break
	var inventory: Dictionary = next["itemInventory"]
	var payout := int(service.get("payout", -1))
	if source.is_empty() or payout < 0 or int(inventory.get(item_id, 0)) < 1:
		return {}
	if int(inventory[item_id]) == 1:
		inventory.erase(item_id)
	else:
		inventory[item_id] = int(inventory[item_id]) - 1
	next["resources"]["spiritStone"] = int(next["resources"]["spiritStone"]) + payout
	session["actionReceipts"][action_id] = {"actionId": action_id, "kind": "buyback",
		"itemId": item_id, "payout": payout,
		"message": "回购 %s，入账 %d 灵石。" % [source.get("name", item_id), payout]}
	var summary: Dictionary = session["summary"]
	summary["exchangeCount"] = int(summary.get("exchangeCount", 0)) + 1
	summary["exchangedItems"].append({"itemId": item_id,
		"direction": "buyback", "payout": payout})
	_ensure_regulated_history(next)
	next["regulatedEventHistory"].append({"sessionKey": session["sessionKey"],
		"kind": "action", "actionId": action_id})
	return next

func _register_causal_order(state: Dictionary, action_id: String) -> Dictionary:
	var next: Dictionary = state.duplicate(true)
	var session: Dictionary = next["marketState"]["activeSession"]
	if session.get("actionReceipts", {}).has(action_id):
		return {}
	var service: Dictionary = {}
	for row in session.get("services", []):
		if row is Dictionary and row.get("kind") == "causal_fact_consumer" \
				and row.get("actionId") == action_id:
			service = row
			break
	if service.is_empty():
		return {}
	# A frozen quote must still equal the source rule and this life's fact.
	var probe: Dictionary = state.duplicate(true)
	var source_services: Array = _materialize_causal_services(probe,
		int(session.get("openedAtDecisionIndex", -1)))
	var source_match := false
	for row in source_services:
		if row is Dictionary and row.get("actionId") == action_id and row == service:
			source_match = true
			break
	if not source_match:
		return {}
	var cost_spec: Array = service.get("costSpec", [])
	var delivery: Dictionary = service.get("delivery", {})
	if cost_spec.size() != 1 or not cost_spec[0] is Dictionary \
			or cost_spec[0].get("kind") != "resource" \
			or cost_spec[0].get("key") != "spiritStone" \
			or not (cost_spec[0].get("amount") is int \
				or cost_spec[0].get("amount") is float) \
			or delivery.get("definitionId") != "licensed_rusted_sword" \
			or int(delivery.get("coreDecisionDelay", -1)) != 3 \
			or delivery.get("provenanceFactTypeId") != "sword_origin_licensed":
		return {}
	var price := int(cost_spec[0]["amount"])
	if price < 1 or float(cost_spec[0]["amount"]) != float(price) \
			or int(next.get("resources", {}).get("spiritStone", -1)) < price:
		return {}
	var fact_id := String(service.get("factInstanceId", ""))
	var consumer_id := String(service.get("consumerId", ""))
	var flow: Dictionary = next.get("noncombatFlow", {})
	var facts: Dictionary = flow.get("spineFacts", {})
	var fact: Dictionary = facts.get(fact_id, {})
	var consumptions: Dictionary = flow.get("spineConsumptions", {})
	var consumption_key := fact_id + ":" + consumer_id
	var settle_index := int(session.get("openedAtDecisionIndex", -1))
	var first := int(fact.get("createdDecisionIndex", -100)) + 1
	var last := int(fact.get("createdDecisionIndex", -100)) + 4
	var order_id := "licensed_rusted_sword:%s:%s" % [fact_id, consumer_id]
	var market: Dictionary = next["marketState"]
	var orders: Array = market.get("rustedSwordOrders", [])
	if fact.get("status") != "active" or fact.get("factInstanceId") != fact_id \
			or fact.get("factTypeId") != service.get("factTypeId") \
			or settle_index < first or settle_index > last \
			or consumptions.has(consumption_key):
		return {}
	for existing in orders:
		if existing is Dictionary and existing.get("orderId") == order_id:
			return {}
	next["resources"]["spiritStone"] = int(next["resources"]["spiritStone"]) - price
	consumptions[consumption_key] = {"factInstanceId": fact_id,
		"factTypeId": fact["factTypeId"], "consumerId": consumer_id,
		"consumedDecisionIndex": settle_index,
		"receipt": {"actionId": action_id, "orderStatus": "registered",
			"vendorId": VENDOR_ID}}
	fact["status"] = "consumed"
	fact["consumedDecisionIndex"] = settle_index
	fact["consumedBy"] = consumer_id
	var order := {"orderId": order_id, "factInstanceId": fact_id,
		"consumerId": consumer_id, "definitionId": delivery["definitionId"],
		"provenanceFactTypeId": delivery["provenanceFactTypeId"],
		"orderLabel": delivery.get("orderLabel", "坊市净炼残剑"),
		"paidCostSpec": cost_spec.duplicate(true),
		"registeredCoreDecisionIndex": settle_index,
		"coreDecisionDelay": 3, "dueCoreDecisionIndex": settle_index + 3,
		"status": "REGISTERED", "deliveryQueued": false,
		"instanceId": null, "provenanceFactInstanceId": null}
	orders.append(order)
	market["rustedSwordOrders"] = orders
	var receipt := {"actionId": action_id, "kind": "causal_fact_consumer",
		"factInstanceId": fact_id, "consumerId": consumer_id,
		"costSpec": cost_spec.duplicate(true), "orderStatus": "registered",
		"orderId": order_id, "dueCoreDecisionIndex": settle_index + 3,
		"message": service.get("receiptText", "凭据核验通过，订购已记入账册。")}
	session["actionReceipts"][action_id] = receipt
	var summary: Dictionary = session["summary"]
	summary["exchangeCount"] = int(summary.get("exchangeCount", 0)) + 1
	if not summary.has("exchangedItems"):
		summary["exchangedItems"] = []
	summary["exchangedItems"].append({"factInstanceId": fact_id,
		"direction": "causal_order", "costSpec": cost_spec.duplicate(true),
		"orderId": order_id, "dueCoreDecisionIndex": settle_index + 3})
	_ensure_regulated_history(next)
	next["regulatedEventHistory"].append({"sessionKey": session["sessionKey"],
		"kind": "action", "actionId": action_id})
	return next

func _identify_roll(supplied: Dictionary, key: String) -> float:
	var raw: Variant = supplied[key] if supplied.has(key) else randf()
	if not (raw is int or raw is float) or float(raw) < 0.0 \
			or float(raw) >= 1.0:
		return -1.0
	return float(raw)


func _identify_purchase(next: Dictionary, offer: Dictionary,
		supplied: Dictionary) -> Dictionary:
	var document: Variant = _content.read_module("shops:treasures")
	if not document is Dictionary:
		return {}
	var by_realm := {"qi": [], "foundation": [], "golden": [], "nascent": []}
	for raw in document.get("treasures", []):
		if not raw is Dictionary or not raw.get("id") is String:
			return {}
		var realm := String(raw.get("realm", "qi"))
		by_realm[realm if realm in ["qi", "foundation", "golden"] else "nascent"].append(raw.id)
	# TreasureSystem loads the same definitions into EquipmentSystem. EffectService
	# iterates both registries, so its second pass adds every tierless item to qi.
	for raw in document.get("treasures", []):
		var tier := String(raw.get("tier", ""))
		var bucket := "nascent" if tier in ["天阶", "玄阶"] else \
			"golden" if tier == "地阶" else \
			"foundation" if tier == "灵阶" else "qi"
		by_realm[bucket].append(raw.id)
	if by_realm.qi.is_empty():
		by_realm = {"qi": ["玄铁甲", "灵泉葫芦"],
			"foundation": ["避尘珠", "剑心佩"],
			"golden": ["避尘珠", "剑心佩"],
			"nascent": ["避尘珠", "剑心佩"]}
	var is_box: bool = offer.get("effect", {}).get("_identifyTreasure") == "box"
	var identify_roll := _identify_roll(supplied, "identifyRoll")
	if identify_roll < 0.0:
		return {}
	var fortune := float(next.get("attributes", {}).get("fortune", 0))
	var heart := float(next.get("attributes", {}).get("daoHeart", 0))
	var score := identify_roll * (120.0 if is_box else 100.0) \
		+ fortune * (2.5 if is_box else 2.0) \
		+ heart * (2.5 if is_box else 1.5)
	var outcome := {"identifyRoll": identify_roll}
	next["shopIdentifyRuleSourceSha"] = IDENTIFY_JS_SHA
	if is_box and score < 35.0:
		var rewards: Array = _deck.battle_reward_offers(next)
		if not rewards.is_empty():
			var card_id := String(rewards[0].get("cardId", ""))
			var acquired: Dictionary = _deck.acquire_battle_reward(next, card_id,
				"treasure_box_backlash", "treasure_box_backlash_reward",
				"treasure_box")
			if acquired.is_empty():
				return {}
			next.merge(acquired, true)
		return outcome
	var bucket := ""
	if is_box:
		bucket = "foundation" if score < 70.0 else \
			"golden" if score < 105.0 else "nascent"
	else:
		if score < 40.0:
			next.resources.spiritStone = int(next.resources.spiritStone) + 2
			return outcome
		bucket = "qi" if score < 75.0 else \
			"foundation" if score < 95.0 else "golden"
	var candidates: Array = by_realm[bucket]
	if candidates.is_empty():
		candidates = ["玄铁甲", "灵泉葫芦"] if bucket == "qi" else \
			["剑心佩"] if bucket == "golden" and not is_box else \
			["避尘珠", "剑心佩"] if bucket == "foundation" else ["避尘珠"]
	var item_roll := _identify_roll(supplied, "itemRoll")
	if item_roll < 0.0 or candidates.is_empty():
		return {}
	var definition_id := String(candidates[int(floor(item_roll * candidates.size()))])
	var session_key := String(next.marketState.activeSession.sessionKey)
	var source_id := session_key + ":" + String(offer.id)
	var decision_index := int(next.runClock.decisionIndex) + 1
	var token := "treasure:identify:life:%s:decision:%d:source:%s:item:%s" % [
		next.runClock.lifeId, decision_index, source_id, definition_id]
	if not _treasures.acquire(next, definition_id, String(offer.id), decision_index,
			{"source": "shop_identify", "channel": null,
			"sessionKey": session_key, "offerId": offer.id,
			"transactionId": token, "sourceId": source_id, "details": {}}):
		last_error = _treasures.last_error
		return {}
	outcome["itemRoll"] = item_roll
	return outcome

func purchase(state: Dictionary, offer_id: String, cost_mode: String = "",
		identify_rolls: Dictionary = {}) -> Dictionary:
	if not _open_valid(state) or not cost_mode.is_empty():
		return {}
	var next: Dictionary = state.duplicate(true)
	var session: Dictionary = next["marketState"]["activeSession"]
	var offer := {}
	for raw in session["immutableOffers"]:
		if raw.get("id") == offer_id:
			offer = raw
			break
	if not _supported(offer, next):
		return {}
	var price := int(offer.get("price", -1))
	var effect: Dictionary = offer.get("effect", {})
	if price < 1 or int(next["resources"].get("spiritStone", 0)) < price \
			or effect.has("treasureId") and next.get("pendingLoadoutDecision") != null \
			or not identify_rolls.is_empty() and not effect.has("_identifyTreasure"):
		return {}
	next["resources"]["spiritStone"] = int(next["resources"]["spiritStone"]) - price
	var identify_outcome := {}
	if offer.get("type") == "card":
		var card_id := String(effect.get("deckCard", {}).get("cardId", ""))
		var acquired: Dictionary = _deck.acquire_shop_card(next, card_id, offer_id)
		if acquired.is_empty():
			last_error = _deck.last_error
			return {}
		next = acquired
		session = next["marketState"]["activeSession"]
	elif effect.has("_identifyTreasure"):
		identify_outcome = _identify_purchase(next, offer, identify_rolls)
		if identify_outcome.is_empty():
			return {}
		session = next["marketState"]["activeSession"]
	elif effect.has("treasureId"):
		var session_key := String(session["sessionKey"])
		var decision_index := int(next["runClock"]["decisionIndex"]) + 1
		var definition_id := String(effect["treasureId"])
		var token := "treasure:shop:life:%s:decision:%d:session:%s:offer:%s" % [
			next["runClock"]["lifeId"], decision_index, session_key, offer_id]
		if not _treasures.acquire(next, definition_id, offer_id, decision_index,
				{"source": "shop_purchase", "channel": VENDOR_ID,
				"sessionKey": session_key, "offerId": offer_id,
				"transactionId": token,
				"sourceId": session_key + ":" + offer_id, "details": {}}):
			last_error = _treasures.last_error
			return {}
		# Acquisition replaces nested dictionaries; the prior session reference
		# no longer belongs to the returned candidate.
		session = next["marketState"]["activeSession"]
		var instance_id := String(next.get("treasureCommandReceipts", {}).get(
			token, {}).get("instanceId", ""))
		var definitions: Variant = _content.read_module("shops:treasures")
		var slot := ""
		for raw in definitions.get("treasures", []) if definitions is Dictionary else []:
			if raw is Dictionary and raw.get("id") == definition_id:
				slot = String(raw.get("type", ""))
				break
		if instance_id.is_empty() or slot not in TreasureAcquisition.SLOTS:
			return {}
		next["pendingLoadoutDecision"] = {"id": "loadout:%s:%s" % [
			session_key, offer_id], "instanceId": instance_id,
			"sourceVendorSessionKey": session_key, "purchaseReceiptToken": token,
			"targetSlot": slot, "status": "pending",
			"allowedActions": {"equip": true, "stash": true,
				"viewProvenance": true, "return": false}, "refundPolicy": null}
	elif effect.has("pillId"):
		var pills: Dictionary = next["resources"].get("pills", {}).duplicate(true)
		var pill_id := String(effect["pillId"])
		pills[pill_id] = int(pills.get(pill_id, 0)) + 1
		next["resources"]["pills"] = pills
	elif effect.has("healHp"):
		var health_cap := _actual_health_cap(next)
		if health_cap < 1:
			return {}
		next["attributes"]["health"] = mini(health_cap,
			int(next["attributes"].get("health", 0)) + int(effect["healHp"]))
	elif effect.has("healDaoHeart"):
		next["attributes"]["daoHeart"] = mini(
			LegacyFragmentFlow.actual_max_dao_heart(next),
			int(next["attributes"].get("daoHeart", 0)) + int(effect["healDaoHeart"]))
	elif effect.has("tempCultivation"):
		next["attributes"]["cultivation"] = int(next["attributes"].get(
			"cultivation", 0)) + int(effect["tempCultivation"])
	elif offer.get("type") in ["gift", "material"]:
		var item_id := String(effect.get("giftItemId", ""))
		var inventory: Dictionary = next.get("itemInventory", {}).duplicate(true)
		inventory[item_id] = int(inventory.get(item_id, 0)) + int(
			effect.get("quantity", 1))
		next["itemInventory"] = inventory
	else:
		return {}
	var remaining: Array = []
	for raw in session["immutableOffers"]:
		if raw.get("id") != offer_id:
			remaining.append(raw)
	session["immutableOffers"] = remaining
	var summary: Dictionary = session["summary"]
	summary["purchaseCount"] = int(summary["purchaseCount"]) + 1
	summary["spiritStoneSpent"] = int(summary["spiritStoneSpent"]) + price
	summary["purchasedItems"].append({"id": offer_id, "name": offer["name"],
		"costSpec": [{"kind": "resource", "key": "spiritStone", "amount": price}]})
	_ensure_regulated_history(next)
	next["marketPurchaseHistory"] = next.get("marketPurchaseHistory", []).duplicate(true)
	next["marketPurchaseHistory"].append({"sessionKey": session["sessionKey"],
		"offerId": offer_id})
	next["regulatedEventHistory"].append({"sessionKey": session["sessionKey"],
		"kind": "purchase", "offerId": offer_id})
	if not identify_outcome.is_empty():
		next["regulatedEventHistory"].back().merge(identify_outcome, true)
	return next

func resolve_loadout(state: Dictionary, action: String) -> Dictionary:
	if action not in ["equip", "stash"] or not source_valid(state):
		return {}
	var pending: Variant = state.get("pendingLoadoutDecision")
	if not pending is Dictionary or pending.get("status") != "pending" \
			or pending.get("allowedActions", {}).get(action) != true \
			or pending.get("targetSlot") not in TreasureAcquisition.SLOTS:
		return {}
	var session_key := String(pending.get("sourceVendorSessionKey", ""))
	if not session_key.begins_with("vendor:%s:" % state.get("runClock", {}).get(
			"lifeId", "")) or not session_key.ends_with(":regulated_market") \
			or state.get("phase") == "VENDOR_OPEN" and state.get(
				"marketState", {}).get("activeSession", {}).get("sessionKey") != session_key:
		return {}
	var token := String(pending.get("purchaseReceiptToken", ""))
	var instance_id := String(pending.get("instanceId", ""))
	var receipt: Dictionary = state.get("treasureCommandReceipts", {}).get(token, {})
	var instance: Dictionary = state.get("treasureInstances", {}).get(instance_id, {})
	var offer_id := String(pending.get("id", "")).get_slice(
		":", String(pending.get("id", "")).get_slice_count(":") - 1)
	if receipt.get("instanceId") != instance_id \
			or instance.get("provenance", {}).get("source") != "shop_purchase" \
			or instance.get("provenance", {}).get("sourceId") != session_key + ":" + offer_id:
		return {}
	var next := state.duplicate(true)
	if action == "equip" and not _treasures.equip_owned(next, instance_id,
			String(pending["targetSlot"])):
		return {}
	next["pendingLoadoutDecision"] = null
	next["loadoutResolutionHistory"] = next.get("loadoutResolutionHistory", []).duplicate(true)
	next["loadoutResolutionHistory"].append({"purchaseReceiptToken": token,
		"action": action})
	_ensure_regulated_history(next)
	next["regulatedEventHistory"].append({"sessionKey": session_key,
		"kind": "loadout", "action": action, "phase": state.get("phase"),
		"decisionIndex": int(state.get("runClock", {}).get("decisionIndex", -1))})
	return next

func close(state: Dictionary) -> Dictionary:
	if not _open_valid(state):
		return {}
	var next: Dictionary = state.duplicate(true)
	var market: Dictionary = next["marketState"]
	var session: Dictionary = market["activeSession"]
	var card_id := String(session["entryCardId"])
	var direction := String(session["direction"])
	var index := int(next["runClock"]["decisionIndex"]) + 1
	var receipt := "decision:%s:choice:%s:%d" % [next["runClock"]["lifeId"],
		card_id, index]
	if next["runClock"]["receipts"].has(receipt):
		return {}
	# GameLogic._finalizeTurnAfterVendor applies source vendorCloseEffects
	# inside the authenticated close, before passive restoration and history.
	if card_id == FIRST_MARKET_ID:
		var effects: Dictionary = session["choice"].get("vendorCloseEffects", {})
		if effects.keys() != ["fortune"] or not _choice_policy._integer(effects["fortune"]):
			return {}
		next["attributes"]["fortune"] = clampi(int(next["attributes"].get("fortune", 0)) \
			+ int(effects["fortune"]), 0, 100)
	# The browser settles passive restoration in the delayed close decision,
	# before recording its visit and committing the top-level clock.
	if not _choice_policy._apply_passive_regen(next):
		last_error = _choice_policy.last_error
		return {}
	var summary: Dictionary = session["summary"]
	var missed: Array = []
	for offer in session["immutableOffers"]:
		missed.append({"id": offer["id"], "name": offer["name"], "stallId": null})
	var bought := int(summary.get("purchaseCount", 0))
	market["visitHistory"].append({"visitId": "market_visit:" + String(session["sessionKey"]),
		"sessionKey": session["sessionKey"], "vendorId": VENDOR_ID,
		"marketType": "regulated", "decisionIndex": index, "seen": true,
		"refused": bought == 0, "outcome": "traded" if bought > 0 else "declined",
		"missedOffers": missed})
	while market["visitHistory"].size() > 48:
		market["visitHistory"].pop_front()
	# A bounded visit list repeats its length after 48 entries. Use the durable
	# session key so result IDs stay unique across a long life and strict replay.
	var result_id := "vendor_result:%s:%s" % [session["sessionKey"], card_id]
	var offered := int(summary.get("openingOfferCount", 0))
	var description := "官坊货架暂空；盖印的回购收据仍在你手中。" if offered == 0 \
		else ("官坊记录了 %d 笔明码交易，共花费 %d 灵石。" % [bought,
			int(summary.get("spiritStoneSpent", 0))] if bought > 0 \
		else "你核对了官坊的明码报价，最终没有出手。")
	var result := {"id": result_id,
		"title": "官坊 · 交易落定" if bought > 0 else "官坊 · 此行收尾",
		"description": description,
		"type": "VENDOR_RESULT", "realm": next.get("realm", "qi"),
		"weight": 0, "once": true,
		"choices": {"right": {"text": "继续行程", "effects": {},
			"action": {"type": "DISMISS_VENDOR_RESULT"}}}}
	market["activeSession"] = {"version": 2, "status": "result", "resultCard": result}
	if card_id == FIRST_MARKET_ID:
		market["activeSession"].merge({"entryCardId": card_id,
			"entrySourceSha": session["entrySourceSha"], "sessionKey": session["sessionKey"]})
	var entry_card: Dictionary = session.get("card", {})
	var tags: Array = entry_card.get("tags", [])
	next["choiceHistory"].append({"cardId": card_id, "cardType": entry_card.get("type"),
		"direction": direction, "turn": index - 1, "decisionIndex": index,
		"tags": tags.duplicate(true)})
	while next["choiceHistory"].size() > 30:
		next["choiceHistory"].pop_front()
	next["cardsPlayed"].append(card_id)
	if card_id in ["q_market", FIRST_MARKET_ID]:
		for tag in tags:
			next["recentCardTags"].append(tag)
		while next["recentCardTags"].size() > 20:
			next["recentCardTags"].pop_front()
	next["turn"] = index
	next["runClock"]["decisionIndex"] = index
	MilestoneFlow.tick_seeds(next)
	next["runClock"]["receipts"][receipt] = {"token": receipt,
		"decisionIndex": index, "sourceCardId": card_id, "kind": "choice"}
	next["pendingVendorResultCard"] = result
	next["currentCardId"] = result_id
	next["phase"] = "VENDOR_RESULT_PENDING"
	if card_id == Catalog.CARD_ID:
		next["normalFlow"].erase("pendingShopDiscarded")
	next["decisionCheckpoint"] = {"version": 1, "cardId": result_id,
		"sourceCardId": card_id, "turn": index,
		"decisionIndex": index, "vendorSessionKey": session["sessionKey"]}
	return next

func dismiss(state: Dictionary) -> Dictionary:
	if state.get("phase") != "VENDOR_RESULT_PENDING" or not source_valid(state):
		return {}
	var next: Dictionary = state.duplicate(true)
	var result: Dictionary = next.get("pendingVendorResultCard", {})
	if result.is_empty() or result.get("id") != next.get("currentCardId") \
			or next.get("marketState", {}).get("activeSession", {}).get("resultCard") != result:
		return {}
	var index := int(next["runClock"]["decisionIndex"])
	var session: Dictionary = next["marketState"]["activeSession"]
	if session.get("entryCardId") == FIRST_MARKET_ID:
		var key := _session_key(next, index, FIRST_MARKET_ID)
		if session.get("sessionKey") != key \
				or next.get("decisionCheckpoint", {}).get("vendorSessionKey") != key \
				or next.get("decisionCheckpoint", {}).get("sourceCardId") != FIRST_MARKET_ID \
				or result.get("id") != "vendor_result:%s:%s" % [key, FIRST_MARKET_ID]:
			return {}
	next["choiceHistory"].append({"cardId": result["id"],
		"cardType": "VENDOR_RESULT", "direction": "right", "turn": index,
		"decisionIndex": index + 1, "tags": []})
	while next["choiceHistory"].size() > 30:
		next["choiceHistory"].pop_front()
	next["cardsPlayed"].append(result["id"])
	next["marketState"]["activeSession"] = null
	next.erase("pendingVendorResultCard")
	next["phase"] = "FLOW_PENDING"
	next["currentCardId"] = ""
	next["decisionCheckpoint"] = {"version": 1, "cardId": null,
		"sourceCardId": result["id"], "turn": index,
		"decisionIndex": index, "flowPending": true}
	return next

func _supported(offer: Dictionary, state: Dictionary) -> bool:
	var realm_index := Catalog.REALM_ORDER.find(String(state.get("realm", "")))
	if realm_index < 0 or int(offer.get("price", -1)) < 1:
		return false
	var effect: Dictionary = offer.get("effect", {})
	if offer.get("type") == "card":
		var deck_doc: Variant = _content.read_module("combat:deck_progression")
		var card_doc: Variant = _content.read_module("cards:battle_cards")
		if not deck_doc is Dictionary or not card_doc is Dictionary:
			return false
		var expected: Dictionary = _catalog._path_offer(state, deck_doc,
			card_doc, String(state.realm))
		return not expected.is_empty() and offer.get("id") == expected.get("id") \
			and effect == expected.get("effect") and offer.get("path") == expected.get("path") \
			and offer.get("realm") == expected.get("realm")
	if offer.get("type") == "treasure":
		if effect.has("_identifyTreasure"):
			return offer.get("id") in ["shop_treasure_box",
				"shop_treasure_mysterious"] and effect.get("_identifyTreasure") == (
				"box" if offer.get("id") == "shop_treasure_box" else "antique") \
				and offer.get("realm") == state.get("realm")
		var definition_id := String(effect.get("treasureId", ""))
		if offer.get("id") != "shop_treasure_dyn_" + definition_id:
			return false
		var document: Variant = _content.read_module("shops:treasures")
		if not document is Dictionary:
			return false
		for raw in document.get("treasures", []):
			if raw is Dictionary and raw.get("id") == definition_id \
					and raw.get("type") in TreasureAcquisition.SLOTS \
					and raw.get("name") == offer.get("name") \
					and raw.get("realm", "qi") == offer.get("realm") \
					and raw.get("storyOnly") != true \
					and Catalog.REALM_ORDER.find(String(raw.get("realm", "qi"))) <= realm_index:
				return true
		return false
	if offer.get("type") not in ["pill", "gift", "material"]:
		return false
	for raw in _shop_items():
		if not raw is Dictionary or raw.get("id") != offer.get("id") \
				or raw.get("type") != offer.get("type") \
				or raw.get("effect") != offer.get("effect") \
				or Catalog.REALM_ORDER.find(String(raw.get("realm", ""))) < 0 \
				or Catalog.REALM_ORDER.find(String(raw.get("realm", ""))) > realm_index:
			continue
		effect = raw.get("effect", {})
		if raw.get("type") in ["gift", "material"]:
			return effect.get("giftItemId") is String \
				and int(effect.get("quantity", 0)) > 0
		return effect.get("pillId") is String \
			or int(effect.get("healHp", 0)) > 0 \
			or int(effect.get("healDaoHeart", 0)) > 0 \
			or int(effect.get("tempCultivation", 0)) > 0
	return false

func _actual_health_cap(state: Dictionary) -> int:
	var skill = PathSkillFlow.new(_content)
	var cap := skill.actual_max_health(state)
	if not skill.last_error.is_empty():
		last_error = skill.last_error
		return -1
	return cap

func _open_valid(state: Dictionary) -> bool:
	if state.get("phase") != "VENDOR_OPEN" or not source_valid(state):
		return false
	var session: Dictionary = state.get("marketState", {}).get("activeSession", {})
	var index := int(state.get("runClock", {}).get("decisionIndex", -1)) + 1
	if session.get("entryCardId") == FIRST_MARKET_ID:
		var source := _first_market_card()
		if source.is_empty() or session.get("card") != source \
				or session.get("choice") != source["choices"]["left"] \
				or state.get("currentCardId") != "vendor_pending:" + FIRST_MARKET_ID:
			return false
	return session.get("status") == "open" and session.get("vendorId") == VENDOR_ID \
		and session.get("marketType") == "regulated" \
		and session.get("entryCardId") in [Catalog.CARD_ID, "q_market", FIRST_MARKET_ID] \
		and session.get("direction") == ("left" if session.get(
			"entryCardId") in ["q_market", FIRST_MARKET_ID] else "right") \
		and session.get("sessionKey") == _session_key(state, index,
			String(session.get("entryCardId", ""))) \
		and int(session.get("openedAtDecisionIndex", -1)) == index \
		and session.get("interactionBudget", {}).get("remaining") == 0

func _first_market_card() -> Dictionary:
	if String(_content.source_sha256(FIRST_MARKET_MODULE)).length() != 64:
		return {}
	var document: Variant = _content.read_module(FIRST_MARKET_MODULE)
	if document is Dictionary:
		for raw in document.get("cards", []):
			if raw is Dictionary and raw.get("id") == FIRST_MARKET_ID:
				return raw
	return {}

func _session_key(state: Dictionary, index: int, card_id: String) -> String:
	return "vendor:%s:%d:%s:%s" % [state.get("runClock", {}).get("lifeId", ""),
		index, card_id, VENDOR_ID]

func _profile() -> Dictionary:
	var source: Variant = _content.read_module(PROFILE_MODULE)
	if source is Dictionary:
		for row in source.get("vendors", []):
			if row is Dictionary and row.get("id") == VENDOR_ID \
					and row.get("marketType") == "regulated":
				return row
	last_error = "官坊档案不可用"
	return {}

func _shop_items() -> Array:
	var document: Variant = _content.read_module("shops:shop_items")
	return document.get("items", []) if document is Dictionary else []

func _buyback_service(session: Dictionary) -> Dictionary:
	for service in session.get("services", []):
		if service is Dictionary and service.get("id") == "regulated_buyback" \
				and service.get("kind") == "buyback":
			return service
	return {}

func _ensure_regulated_history(next: Dictionary) -> void:
	if next.has("regulatedEventHistory"):
		next["regulatedEventHistory"] = next["regulatedEventHistory"].duplicate(true)
		return
	var history: Array = []
	for purchase in next.get("marketPurchaseHistory", []):
		if purchase is Dictionary and (String(purchase.get("sessionKey", "")).ends_with(
				":shop_encounter:regulated_market") or String(purchase.get(
					"sessionKey", "")).ends_with(":q_market:regulated_market") \
				or String(purchase.get("sessionKey", "")).ends_with(
					":" + FIRST_MARKET_ID + ":regulated_market")):
			history.append({"sessionKey": purchase["sessionKey"],
				"kind": "purchase", "offerId": purchase.get("offerId", "")})
	next["regulatedEventHistory"] = history
