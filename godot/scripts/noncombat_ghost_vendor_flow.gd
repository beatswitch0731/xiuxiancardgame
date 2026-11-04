extends RefCounted

const GhostCatalog = preload("res://scripts/noncombat_ghost_market_catalog.gd")
const MarketFlow = preload("res://scripts/noncombat_market_flow.gd")
const TreasureAcquisition = preload("res://scripts/noncombat_treasure_acquisition.gd")
const CARD_ID := MarketFlow.GHOST_ID
const SHOP_JS_SHA := "937c9db807692305a7c3c09798cd967241e2a87de506c65228aec83bc5b12a46"

var _content: RefCounted
var _market_flow: RefCounted
var _catalog: RefCounted
var _treasures: RefCounted
var last_error := ""

func _init(content: RefCounted, market_flow: RefCounted) -> void:
	_content = content
	_market_flow = market_flow
	_catalog = GhostCatalog.new(content)
	_treasures = TreasureAcquisition.new(content)


func trust_rebirth_archive() -> void:
	_catalog.rebirth_archive_verified = true

func source_valid(state: Dictionary) -> bool:
	if state.get("ghostVendorPins") != _catalog.source_pins():
		return false
	var phase := String(state.get("phase", ""))
	if phase == "VENDOR_OPEN":
		var session: Variant = state.get("marketState", {}).get("activeSession")
		if not session is Dictionary or session.get("vendorId") != "ghost_market" \
				or session.get("status") != "open" \
				or state.get("currentCardId") != "vendor_pending:" + CARD_ID:
			return false
		var plan: Variant = state.get("pendingGhostPlan")
		if not plan is Dictionary or not state.get("pendingMarketChoiceCard") is Dictionary \
				or plan.get("card") != state.get("pendingMarketChoiceCard"):
			return false
		var expected: Dictionary = _expected_session(state)
		if expected.is_empty() or not _project_inspections(state, expected) \
				or not _project_purchases(state, expected):
			return false
		return JSON.parse_string(JSON.stringify(session)) == JSON.parse_string(
			JSON.stringify(expected))
	if phase == "VENDOR_RESULT_PENDING":
		var result: Variant = state.get("pendingVendorResultCard")
		return result is Dictionary and result.get("id") == state.get("currentCardId") \
			and state.get("marketState", {}).get("activeSession", {}).get(
				"resultCard") == result \
			and state.get("decisionCheckpoint", {}).get("sourceCardId") == CARD_ID
	return false

func open(state: Dictionary) -> Dictionary:
	last_error = ""
	if not _market_flow.ghost_entry_available(state):
		last_error = "鬼市夜门、征兆、来源或货单不允许入摊"
		return {}
	var session := _expected_session(state)
	if session.is_empty():
		last_error = "鬼市来源会话无法建立：" + _catalog.last_error
		return {}
	var candidate: Dictionary = state.duplicate(true)
	candidate["marketState"]["totalVisits"] = int(candidate["marketState"].get(
		"totalVisits", 0)) + 1
	candidate["marketState"]["activeSession"] = session
	candidate["ghostVendorPins"] = _catalog.source_pins()
	candidate["phase"] = "VENDOR_OPEN"
	candidate["currentCardId"] = "vendor_pending:" + CARD_ID
	candidate["decisionCheckpoint"] = {"version": 1,
		"cardId": candidate["currentCardId"], "sourceCardId": CARD_ID,
		"turn": candidate["turn"], "decisionIndex": candidate["runClock"]["decisionIndex"],
		"vendorSessionKey": session["sessionKey"]}
	return candidate

func pending_card(state: Dictionary) -> Dictionary:
	if not source_valid(state) or state.get("phase") != "VENDOR_OPEN":
		return {}
	return {"id": "vendor_pending:" + CARD_ID, "title": "鬼市契约进行中",
		"description": "禁物报价与寿契已锁定。请签约或离开；债期将在结算后开始计算。",
		"type": "VENDOR_PENDING", "realm": state.get("realm", "qi"),
		"weight": 0, "once": true, "choices": {}}

func available_actions(state: Dictionary) -> Array:
	if state.get("phase") != "VENDOR_OPEN" or not source_valid(state):
		return []
	var session: Dictionary = state["marketState"]["activeSession"]
	var service := _inspection_service(session)
	if service.is_empty():
		return []
	var cost: Array = service.get("costSpec", [])
	var item_id := String(cost[0].get("key", ""))
	var owned := int(state.get("itemInventory", {}).get(item_id, 0))
	var actions: Array = []
	for offer in session["immutableOffers"]:
		if offer.get("hiddenTrait") is Dictionary and offer["hiddenTrait"].get(
				"status") == "sealed":
			var action_id := String(service["id"]) + ":" + String(offer["id"])
			actions.append({"id": action_id, "label": "验看 " + String(offer.get(
				"name", "封签禁物")), "description": service.get("description", ""),
				"costText": "%s×%d" % [item_id, int(cost[0]["amount"])],
				"enabled": owned >= int(cost[0]["amount"])})
	return actions

func inspect_seal(state: Dictionary, action_id: String) -> Dictionary:
	last_error = ""
	if state.get("phase") != "VENDOR_OPEN" or not source_valid(state):
		last_error = "鬼市封签会话不可用"
		return {}
	var candidate: Dictionary = state.duplicate(true)
	var session: Dictionary = candidate["marketState"]["activeSession"]
	var service := _inspection_service(session)
	if service.is_empty() or not action_id.begins_with(String(service["id"]) + ":") \
			or session.get("actionReceipts", {}).has(action_id):
		last_error = "鬼市验封服务或回执无效"
		return {}
	var offer_id := action_id.substr(String(service["id"]).length() + 1)
	var offer: Dictionary = {}
	for row in session["immutableOffers"]:
		if row.get("id") == offer_id:
			offer = row
			break
	if offer.is_empty() or not offer.get("hiddenTrait") is Dictionary \
			or offer["hiddenTrait"].get("status") != "sealed":
		last_error = "此物没有未验的封签"
		return {}
	var cost: Array = service["costSpec"]
	var item_id := String(cost[0]["key"])
	var amount := int(cost[0]["amount"])
	if not candidate.get("itemInventory") is Dictionary \
			or int(candidate["itemInventory"].get(item_id, 0)) < amount:
		last_error = "商路线索不足"
		return {}
	candidate["itemInventory"][item_id] = int(candidate[
		"itemInventory"][item_id]) - amount
	offer["hiddenTrait"]["status"] = "revealed"
	var revealed := String(offer["hiddenTrait"].get("revealedText", ""))
	var receipt := {"actionId": action_id, "kind": "inspect_hidden_trait",
		"itemId": offer_id, "costSpec": cost.duplicate(true),
		"message": "封签验明：" + (revealed if not revealed.is_empty() \
			else "封签下的来路仍晦暗不明。")}
	session["actionReceipts"][action_id] = receipt
	var summary: Dictionary = session["summary"]
	summary["exchangeCount"] = int(summary.get("exchangeCount", 0)) + 1
	summary["exchangedItems"].append({"itemId": offer_id,
		"direction": "inspect_hidden_trait", "costSpec": cost.duplicate(true)})
	candidate["marketActionHistory"] = candidate.get(
		"marketActionHistory", []).duplicate(true)
	candidate["marketActionHistory"].append({"sessionKey": session["sessionKey"],
		"actionId": action_id})
	_ensure_ghost_event_history(candidate, String(session["sessionKey"]))
	candidate["ghostVendorEventHistory"].append({"sessionKey": session["sessionKey"],
		"kind": "action", "actionId": action_id})
	return candidate

func purchase_oath(state: Dictionary, offer_id: String,
		cost_mode_id: String = "") -> Dictionary:
	if offer_id != "ghost_oath_rusted_sword":
		return _purchase_ordinary(state, offer_id, cost_mode_id)
	last_error = ""
	if state.get("phase") != "VENDOR_OPEN" or not source_valid(state) \
			or offer_id != "ghost_oath_rusted_sword" or not cost_mode_id.is_empty() \
			or state.get("pendingLoadoutDecision") != null:
		last_error = "鬼市契约会话、报价或装配决定不可用"
		return {}
	var session: Dictionary = state["marketState"]["activeSession"]
	var offer: Dictionary = {}
	for item in session.get("immutableOffers", []):
		if item is Dictionary and item.get("id") == offer_id:
			offer = item
			break
	var cost: Array = offer.get("costSpec", [])
	if offer.get("type") != "treasure" or offer.get("effect", {}).get(
			"treasureId") != offer_id or cost.size() != 2 \
			or cost[0].get("kind") != "resource" or cost[0].get("key") != "spiritStone" \
			or cost[1].get("kind") != "resource" or cost[1].get("key") != "lifespan":
		last_error = "夜契来源商品或双成本无效"
		return {}
	var stone := int(cost[0].get("amount", -1))
	var lifespan := int(cost[1].get("amount", -1))
	if stone < 0 or lifespan < 1 or int(state.get("resources", {}).get(
			"spiritStone", 0)) < stone or int(state.get("resources", {}).get(
			"lifespan", 0)) < lifespan:
		last_error = "夜契灵石或寿元不足"
		return {}
	var oath: Dictionary = offer.get("ghostOathContract", {})
	var narrative: Dictionary = offer.get("narrativeProvenance", {})
	var graph: Variant = _content.read_module("narrative:causal_graph")
	var fact_type := String(narrative.get("factTypeId", ""))
	var defined := false
	if graph is Dictionary:
		for entry in graph.get("factTypes", []):
			if entry is Dictionary and entry.get("factTypeId") == fact_type:
				defined = true
				break
	var flow: Dictionary = state.get("noncombatFlow", {})
	var life_text := String(state.get("runClock", {}).get("lifeId", "")).get_slice(
		":", 2)
	var fact_id := "fact:%s:%s" % [life_text, fact_type]
	if not defined or fact_type != "sword_origin_ghost_oath" \
			or oath.get("kind") != "ghost_oath_sword" \
			or not life_text.is_valid_int() or flow.get("spineFacts", {}).has(fact_id) \
			or flow.get("causalGraphSourceSha") != _content.source_sha256(
				"narrative:causal_graph"):
		last_error = "夜契来历定义、状态或来源指纹无效"
		return {}
	var candidate: Dictionary = state.duplicate(true)
	var next_index := int(candidate["runClock"]["decisionIndex"]) + 1
	var session_key := String(session["sessionKey"])
	var token := "treasure:shop:life:%s:decision:%d:session:%s:offer:%s" % [
		candidate["runClock"]["lifeId"], next_index, session_key, offer_id]
	var details: Dictionary = narrative.get("payload", {}).duplicate(true)
	details.merge({"exchangeMode": "ghost_oath",
		"exchangeLabel": oath.get("provenanceLabel", "夜契签下"),
		"contractKind": oath["kind"], "contractLabel": oath.get("label", offer["name"])},
		true)
	if not _treasures.acquire(candidate, offer_id, offer_id, next_index,
			{"source": "ghost_market_purchase", "channel": "ghost_market",
			"transactionId": token, "sourceId": session_key + ":" + offer_id,
			"details": details}):
		last_error = _treasures.last_error
		return {}
	var instance_id := String(candidate.get("treasureCommandReceipts", {}).get(
		token, {}).get("instanceId", ""))
	if instance_id.is_empty() or candidate.get("marketState", {}).has(
			"debts") and not candidate["marketState"]["debts"] is Array:
		last_error = "夜契实例或债务账本不可用"
		return {}
	if not candidate["marketState"].has("debts"):
		# Old Godot saves did not persist debts; activate the ledger with the
		# first authenticated contract, preserving their replayed prefix.
		candidate["marketState"]["debts"] = []
	var debt_id := "ghost_debt:%s:%s:r%d" % [session["sessionId"], offer_id,
		int(session.get("offerRevision", 1))]
	for existing in candidate["marketState"]["debts"]:
		if existing is Dictionary and existing.get("debtId") == debt_id:
			return {}
	var fact_payload: Dictionary = narrative.get("payload", {}).duplicate(true)
	fact_payload.merge({"itemInstanceId": instance_id, "exchangeMode": "ghost_oath",
		"exchangeLabel": details["exchangeLabel"], "source": "ghost_market_purchase",
		"sessionKey": session_key, "offerId": offer_id}, true)
	var facts: Dictionary = candidate["noncombatFlow"].get("spineFacts", {}).duplicate(true)
	facts[fact_id] = {"factInstanceId": fact_id, "factTypeId": fact_type,
		"lifeCount": int(life_text), "status": "active",
		"producerId": narrative.get("producerId"), "payload": fact_payload,
		"createdDecisionIndex": next_index, "terminalClosure": null,
		"closedDecisionIndex": null}
	candidate["noncombatFlow"]["spineFacts"] = facts
	var pressure: Dictionary = oath.get("pressure", {})
	var debt := {"debtId": debt_id, "originSessionId": session["sessionId"],
		"acquiredInstanceId": instance_id,
		"creditorId": session.get("debt", {}).get("creditorId", "faceless_broker"),
		"dueDecisionIndex": int(candidate["runClock"]["decisionIndex"]) + maxi(1,
			int(oath.get("dueDecisionOffset", 3))), "status": "PENDING",
		"defaultConsequence": session.get("debt", {}).get(
			"defaultConsequence", "ghost_market_access_revoked"),
		"settlementCostSpec": oath.get("settlementCostSpec", []).duplicate(true),
		"settlementReceiptId": null, "kind": oath["kind"],
		"contractLabel": oath.get("label", offer["name"]),
		"sourceFactInstanceId": fact_id,
		"pressure": {"chance": float(pressure.get("chance", 1.0 / 3.0)),
			"pityLimit": maxi(1, int(pressure.get("pityLimit", 3))),
			"misses": 0, "processedEncounterIds": [], "receipts": [],
			"lastReceipt": null}}
	candidate["marketState"]["debts"].append(debt)
	candidate["ghostDebtSourcePins"] = _catalog.source_pins()
	candidate["treasureInstances"][instance_id]["provenance"].merge({
		"ghostDebtId": debt_id, "sourceFactInstanceId": fact_id,
		"contractKind": oath["kind"], "contractLabel": debt["contractLabel"]}, true)
	candidate["resources"]["spiritStone"] = int(candidate["resources"][
		"spiritStone"]) - stone
	candidate["resources"]["lifespan"] = int(candidate["resources"][
		"lifespan"]) - lifespan
	var active: Dictionary = candidate["marketState"]["activeSession"]
	var remaining: Array = []
	for item in active["immutableOffers"]:
		if item.get("id") != offer_id:
			remaining.append(item)
	active["immutableOffers"] = remaining
	active["summary"]["purchaseCount"] = int(active["summary"].get(
		"purchaseCount", 0)) + 1
	active["summary"]["spiritStoneSpent"] = int(active["summary"].get(
		"spiritStoneSpent", 0)) + stone
	active["summary"]["purchasedItems"].append({"id": offer_id,
		"name": offer["name"], "costSpec": cost.duplicate(true), "costMode": null})
	if not active["summary"].has("ghostDebtTerms"):
		active["summary"]["ghostDebtTerms"] = []
	active["summary"]["ghostDebtTerms"].append(debt.duplicate(true))
	candidate["pendingLoadoutDecision"] = {"id": "loadout:%s:%s" % [
		session_key, offer_id], "instanceId": instance_id,
		"sourceVendorSessionKey": session_key, "purchaseReceiptToken": token,
		"targetSlot": "weapon", "status": "pending",
		"allowedActions": {"equip": true, "stash": true,
			"viewProvenance": true, "return": false}, "refundPolicy": null,
		"ghostDebtId": debt_id,
		"ghostDebt": {"debtId": debt_id, "dueDecisionIndex": debt[
			"dueDecisionIndex"], "settlementCostSpec": debt[
			"settlementCostSpec"].duplicate(true), "pressure": debt["pressure"].duplicate(true),
			"contractLabel": debt["contractLabel"]}}
	candidate["marketPurchaseHistory"] = candidate.get(
		"marketPurchaseHistory", []).duplicate(true)
	candidate["marketPurchaseHistory"].append({"sessionKey": session_key,
		"offerId": offer_id})
	if candidate.has("ghostVendorEventHistory"):
		candidate["ghostVendorEventHistory"].append({"sessionKey": session_key,
			"kind": "purchase", "offerId": offer_id})
	return candidate

func _purchase_ordinary(state: Dictionary, offer_id: String,
		cost_mode_id: String) -> Dictionary:
	last_error = ""
	if state.get("phase") != "VENDOR_OPEN" or not source_valid(state) \
			or offer_id.is_empty() or not cost_mode_id.is_empty() \
			or state.get("pendingLoadoutDecision") != null:
		last_error = "鬼市普通货物会话或装配决定不可用"
		return {}
	var session: Dictionary = state["marketState"]["activeSession"]
	var offer: Dictionary = {}
	for item in session.get("immutableOffers", []):
		if item is Dictionary and item.get("id") == offer_id:
			offer = item
			break
	var definitions: Variant = _content.read_module("shops:treasures")
	var definition: Dictionary = {}
	if definitions is Dictionary:
		for item in definitions.get("treasures", []):
			if item is Dictionary and item.get("id") == offer_id:
				definition = item
				break
	var cost: Variant = offer.get("costSpec")
	if offer.get("type") != "treasure" or offer.get("_marketItem") != true \
			or offer.get("effect", {}).get("treasureId") != offer_id \
			or definition.get("type") not in TreasureAcquisition.SLOTS \
			or not cost is Array or cost.size() != 2 \
			or cost[0].get("kind") != "resource" \
			or cost[0].get("key") != "spiritStone" \
			or cost[1].get("kind") != "resource" \
			or cost[1].get("key") != "lifespan":
		last_error = "鬼市随机法宝或双成本来源无效"
		return {}
	var stone := int(cost[0].get("amount", -1))
	var lifespan := int(cost[1].get("amount", -1))
	if stone < 1 or lifespan < 1 \
			or int(state.get("resources", {}).get("spiritStone", 0)) < stone \
			or int(state.get("resources", {}).get("lifespan", 0)) < lifespan:
		last_error = "鬼市随机法宝代价不足"
		return {}
	var candidate: Dictionary = state.duplicate(true)
	var next_index := int(candidate["runClock"]["decisionIndex"]) + 1
	var session_key := String(session["sessionKey"])
	var token := "treasure:shop:life:%s:decision:%d:session:%s:offer:%s" % [
		candidate["runClock"]["lifeId"], next_index, session_key, offer_id]
	if not _treasures.acquire(candidate, offer_id, offer_id, next_index,
			{"source": "ghost_market_purchase", "channel": "ghost_market",
			"sessionKey": session_key, "transactionId": token,
			"sourceId": session_key + ":" + offer_id, "details": {}}):
		last_error = _treasures.last_error
		return {}
	var instance_id := String(candidate.get("treasureCommandReceipts", {}).get(
		token, {}).get("instanceId", ""))
	if instance_id.is_empty() or candidate.get("marketState", {}).has(
			"debts") and not candidate["marketState"]["debts"] is Array:
		last_error = "鬼市随机法宝实例或债务账本无效"
		return {}
	if not candidate["marketState"].has("debts"):
		candidate["marketState"]["debts"] = []
	var debt_id := "ghost_debt:%s:%s:r%d" % [session["sessionId"], offer_id,
		int(session.get("offerRevision", 1))]
	for existing in candidate["marketState"]["debts"]:
		if existing is Dictionary and existing.get("debtId") == debt_id:
			return {}
	var debt_rule: Dictionary = session.get("debt", {})
	var offset := maxi(3, int(debt_rule.get("minDueOffset", 3)))
	var debt := {"debtId": debt_id, "originSessionId": session["sessionId"],
		"acquiredInstanceId": instance_id,
		"creditorId": debt_rule.get("creditorId", "faceless_broker"),
		"dueDecisionIndex": int(candidate["runClock"]["decisionIndex"]) + offset,
		"status": "PENDING", "defaultConsequence": debt_rule.get(
			"defaultConsequence", "ghost_market_access_revoked"),
		"settlementCostSpec": [{"kind": "resource", "key": "spiritStone",
			"amount": maxi(1, ceili(stone * 0.5))}],
		"settlementReceiptId": null}
	candidate["marketState"]["debts"].append(debt)
	candidate["ghostDebtSourcePins"] = _catalog.source_pins()
	candidate["resources"]["spiritStone"] = int(candidate["resources"][
		"spiritStone"]) - stone
	candidate["resources"]["lifespan"] = int(candidate["resources"][
		"lifespan"]) - lifespan
	var active: Dictionary = candidate["marketState"]["activeSession"]
	var remaining: Array = []
	for item in active["immutableOffers"]:
		if item.get("id") != offer_id:
			remaining.append(item)
	active["immutableOffers"] = remaining
	active["summary"]["purchaseCount"] = int(active["summary"].get(
		"purchaseCount", 0)) + 1
	active["summary"]["spiritStoneSpent"] = int(active["summary"].get(
		"spiritStoneSpent", 0)) + stone
	active["summary"]["purchasedItems"].append({"id": offer_id,
		"name": offer["name"], "costSpec": cost.duplicate(true), "costMode": null})
	if not active["summary"].has("ghostDebtTerms"):
		active["summary"]["ghostDebtTerms"] = []
	active["summary"]["ghostDebtTerms"].append(debt.duplicate(true))
	candidate["pendingLoadoutDecision"] = {"id": "loadout:%s:%s" % [
		session_key, offer_id], "instanceId": instance_id,
		"sourceVendorSessionKey": session_key, "purchaseReceiptToken": token,
		"targetSlot": definition["type"], "status": "pending",
		"allowedActions": {"equip": true, "stash": true,
			"viewProvenance": true, "return": false}, "refundPolicy": null,
		"ghostDebtId": debt_id,
		"ghostDebt": {"debtId": debt_id, "dueDecisionIndex": debt[
			"dueDecisionIndex"], "settlementCostSpec": debt[
			"settlementCostSpec"].duplicate(true), "pressure": null,
			"contractLabel": null}}
	_ensure_ghost_event_history(candidate, session_key)
	candidate["marketPurchaseHistory"] = candidate.get(
		"marketPurchaseHistory", []).duplicate(true)
	candidate["marketPurchaseHistory"].append({"sessionKey": session_key,
		"offerId": offer_id})
	candidate["ghostVendorEventHistory"].append({"sessionKey": session_key,
		"kind": "purchase", "offerId": offer_id})
	return candidate

func resolve_loadout(state: Dictionary, action: String) -> Dictionary:
	if action not in ["equip", "stash"] or state.get("phase") != "VENDOR_OPEN" \
			or not source_valid(state):
		return {}
	var pending: Variant = state.get("pendingLoadoutDecision")
	if not pending is Dictionary or pending.get("status") != "pending" \
			or pending.get("targetSlot") not in TreasureAcquisition.SLOTS \
			or pending.get("allowedActions", {}).get(action) != true:
		return {}
	var instance_id := String(pending.get("instanceId", ""))
	var debt_id := String(pending.get("ghostDebtId", ""))
	var debts: Array = state.get("marketState", {}).get("debts", [])
	if not debts.any(func(value: Variant) -> bool:
		return value is Dictionary and value.get("debtId") == debt_id \
			and value.get("acquiredInstanceId") == instance_id):
		return {}
	var candidate: Dictionary = state.duplicate(true)
	if action == "equip" and not _treasures.equip_owned(candidate, instance_id,
			String(pending["targetSlot"])):
		return {}
	candidate["pendingLoadoutDecision"] = null
	candidate["loadoutResolutionHistory"] = candidate.get(
		"loadoutResolutionHistory", []).duplicate(true)
	candidate["loadoutResolutionHistory"].append({
		"purchaseReceiptToken": pending["purchaseReceiptToken"], "action": action})
	if candidate.has("ghostVendorEventHistory"):
		candidate["ghostVendorEventHistory"].append({"sessionKey": pending[
			"sourceVendorSessionKey"], "kind": "loadout", "action": action})
	return candidate

func available_offers(state: Dictionary) -> Array:
	if not source_valid(state) or state.get("phase") != "VENDOR_OPEN":
		return []
	var offers: Array = []
	for item in state["marketState"]["activeSession"]["immutableOffers"]:
		var stone := 0
		var lifespan := 0
		for cost in item.get("costSpec", []):
			if cost.get("kind") == "resource" and cost.get("key") == "spiritStone":
				stone += int(cost.get("amount", 0))
			elif cost.get("kind") == "resource" and cost.get("key") == "lifespan":
				lifespan += int(cost.get("amount", 0))
		var supported: bool = item.get("id") == "ghost_oath_rusted_sword"
		if not supported and item.get("type") == "treasure" \
				and item.get("_marketItem") == true:
			var definitions: Variant = _content.read_module("shops:treasures")
			if definitions is Dictionary:
				for definition in definitions.get("treasures", []):
					if definition is Dictionary and definition.get("id") == item.get("id") \
							and definition.get("type") in TreasureAcquisition.SLOTS:
						supported = true
						break
		offers.append({"id": item.get("id"), "name": item.get("name"),
			"price": stone, "lifespan": lifespan, "supported": supported,
			"enabled": supported and state.get("pendingLoadoutDecision") == null \
				and int(state.get("resources", {}).get("spiritStone", 0)) >= stone \
				and int(state.get("resources", {}).get("lifespan", 0)) >= lifespan})
	return offers

func close(state: Dictionary) -> Dictionary:
	last_error = ""
	if state.get("phase") != "VENDOR_OPEN" or not source_valid(state):
		last_error = "鬼市会话与来源不符"
		return {}
	var candidate: Dictionary = state.duplicate(true)
	var market: Dictionary = candidate["marketState"]
	var session: Dictionary = market["activeSession"]
	var bought := int(session.get("summary", {}).get("purchaseCount", -1))
	if bought < 0 or bought > int(session.get("summary", {}).get(
			"openingOfferCount", 0)) \
			or candidate.get("pendingLoadoutDecision") != null:
		last_error = "鬼市交易或装配决定尚未完整，不能离摊"
		return {}
	var next_index := int(candidate["runClock"].get("decisionIndex", -1)) + 1
	var receipt := "decision:%s:choice:%s:%d" % [
		candidate["runClock"].get("lifeId", ""), CARD_ID, next_index]
	if session.get("openedAtDecisionIndex") != next_index \
			or candidate["runClock"]["receipts"].has(receipt):
		return {}
	var missed: Array = []
	for offer in session["immutableOffers"]:
		missed.append({"id": offer.get("id"), "name": offer.get("name")})
	var names: Array[String] = []
	for offer in missed.slice(0, 3):
		names.append(String(offer.get("name", offer.get("id", ""))))
	var missed_text := "错过了 %s%s" % ["、".join(names),
		" 等线索" if missed.size() > 3 else ""] if not names.is_empty() \
		else "没有新的货讯可记"
	var result_id := "vendor_result:%s:%s" % [session["sessionId"], CARD_ID]
	var result_title := "鬼市 · 契约已成" if bought > 0 else "鬼市 · 雾门合拢"
	var result_description := "雾中摊主没有挽留。你拒绝了这次寿契，%s；鬼市在身后合门。" % missed_text
	if bought > 0:
		var debt_terms: Array[String] = []
		for debt in session.get("summary", {}).get("ghostDebtTerms", []):
			if not debt is Dictionary:
				return {}
			var settlement := 0
			for cost in debt.get("settlementCostSpec", []):
				if cost.get("kind") == "resource" and cost.get("key") == "spiritStone":
					settlement += int(cost.get("amount", 0))
			debt_terms.append("第 %d 次决断索取 %d 灵石" % [int(debt.get(
				"dueDecisionIndex", 0)), maxi(1, settlement)])
		result_description = "你签下 %d 份鬼市契约，付出 %d 灵石；%s" % [
			bought, int(session["summary"].get("spiritStoneSpent", 0)),
			"无面人记下%s。" % "；".join(debt_terms) if not debt_terms.is_empty() \
			else "寿元与债期已被无面人记下。"]
	var result_card := {"id": result_id, "title": result_title,
		"description": result_description,
		"type": "VENDOR_RESULT", "realm": candidate.get("realm", "qi"),
		"weight": 0, "once": true,
		"choices": {"right": {"text": "继续行程", "effects": {},
			"action": {"type": "DISMISS_VENDOR_RESULT"}}}}
	market["visitHistory"].append({"visitId": "market_visit:" + String(
		session["sessionKey"]), "sessionKey": session["sessionKey"],
		"vendorId": "ghost_market", "marketType": "ghost",
		"decisionIndex": next_index, "seen": true, "refused": bought == 0,
		"outcome": "traded" if bought > 0 else "declined", "missedOffers": missed})
	while market["visitHistory"].size() > 48:
		market["visitHistory"].pop_front()
	market["activeSession"] = {"version": 2, "status": "result",
		"resultCard": result_card}
	candidate["choiceHistory"].append({"cardId": CARD_ID, "cardType": "MARKET",
		"direction": "left", "turn": next_index - 1,
		"decisionIndex": next_index, "tags": []})
	while candidate["choiceHistory"].size() > 30:
		candidate["choiceHistory"].pop_front()
	candidate["cardsPlayed"].append(CARD_ID)
	candidate["turn"] = next_index
	candidate["runClock"]["decisionIndex"] = next_index
	candidate["runClock"]["receipts"][receipt] = {"token": receipt,
		"decisionIndex": next_index, "sourceCardId": CARD_ID, "kind": "choice"}
	candidate.erase("pendingGhostPlan")
	candidate.erase("pendingMarketChoiceCard")
	candidate["pendingVendorResultCard"] = result_card
	candidate["currentCardId"] = result_id
	candidate["phase"] = "VENDOR_RESULT_PENDING"
	candidate["decisionCheckpoint"] = {"version": 1, "cardId": result_id,
		"sourceCardId": CARD_ID, "turn": next_index,
		"decisionIndex": next_index, "vendorSessionKey": session["sessionKey"]}
	return candidate

func dismiss(state: Dictionary) -> Dictionary:
	if state.get("phase") != "VENDOR_RESULT_PENDING" or not source_valid(state):
		return {}
	var candidate: Dictionary = state.duplicate(true)
	var result: Dictionary = candidate["pendingVendorResultCard"]
	var index := int(candidate["runClock"]["decisionIndex"])
	candidate["choiceHistory"].append({"cardId": result["id"],
		"cardType": "VENDOR_RESULT", "direction": "right", "turn": index,
		"decisionIndex": index + 1, "tags": []})
	while candidate["choiceHistory"].size() > 30:
		candidate["choiceHistory"].pop_front()
	candidate["cardsPlayed"].append(result["id"])
	candidate["marketState"]["activeSession"] = null
	candidate.erase("pendingVendorResultCard")
	candidate.erase("ghostVendorPins")
	candidate["currentCardId"] = ""
	candidate["phase"] = "FLOW_PENDING"
	candidate["decisionCheckpoint"] = {"version": 1, "cardId": null,
		"sourceCardId": result["id"], "turn": index,
		"decisionIndex": index, "flowPending": true}
	return candidate

func _inspection_service(session: Dictionary) -> Dictionary:
	for row in session.get("services", []):
		if not row is Dictionary or row.get("id") != "ghost_inspect_seal" \
				or row.get("kind") != "inspect_hidden_trait":
			continue
		var cost: Variant = row.get("costSpec")
		if cost is Array and cost.size() == 1 and cost[0] is Dictionary \
				and cost[0].get("kind") == "item" \
				and cost[0].get("key") is String \
				and int(cost[0].get("amount", 0)) > 0:
			return row
	return {}

func _project_inspections(state: Dictionary, expected: Dictionary) -> bool:
	var session_key := String(expected.get("sessionKey", ""))
	var service := _inspection_service(expected)
	var actions: Variant = state.get("marketActionHistory", [])
	if not actions is Array:
		return false
	var seen := {}
	for event in actions:
		if not event is Dictionary or not event.get("sessionKey") is String \
				or not event.get("actionId") is String:
			return false
		if event["sessionKey"] != session_key:
			continue
		var action_id := String(event["actionId"])
		if service.is_empty() or not action_id.begins_with(
				String(service["id"]) + ":") or seen.has(action_id):
			return false
		seen[action_id] = true
		var offer_id := action_id.substr(String(service["id"]).length() + 1)
		var offer: Dictionary = {}
		for item in expected["immutableOffers"]:
			if item.get("id") == offer_id:
				offer = item
				break
		if offer.is_empty() or not offer.get("hiddenTrait") is Dictionary \
				or offer["hiddenTrait"].get("status") != "sealed":
			return false
		offer["hiddenTrait"]["status"] = "revealed"
		var cost: Array = service["costSpec"]
		var revealed := String(offer["hiddenTrait"].get("revealedText", ""))
		expected["actionReceipts"][action_id] = {"actionId": action_id,
			"kind": "inspect_hidden_trait", "itemId": offer_id,
			"costSpec": cost.duplicate(true),
			"message": "封签验明：" + (revealed if not revealed.is_empty() \
				else "封签下的来路仍晦暗不明。")}
		expected["summary"]["exchangeCount"] = int(expected[
			"summary"].get("exchangeCount", 0)) + 1
		expected["summary"]["exchangedItems"].append({"itemId": offer_id,
			"direction": "inspect_hidden_trait", "costSpec": cost.duplicate(true)})
	return true

func _ensure_ghost_event_history(candidate: Dictionary, session_key: String) -> void:
	if candidate.has("ghostVendorEventHistory"):
		return
	candidate["ghostVendorEventHistory"] = []
	for event in candidate.get("marketPurchaseHistory", []):
		if event is Dictionary and event.get("sessionKey") == session_key:
			candidate["ghostVendorEventHistory"].append({
				"sessionKey": session_key, "kind": "purchase",
				"offerId": event.get("offerId")})
	for event in candidate.get("loadoutResolutionHistory", []):
		if event is Dictionary and String(event.get(
				"purchaseReceiptToken", "")).contains(":session:" + session_key + ":"):
			candidate["ghostVendorEventHistory"].append({
				"sessionKey": session_key, "kind": "loadout",
				"action": event.get("action")})

func _project_purchases(state: Dictionary, expected: Dictionary) -> bool:
	var key := String(expected.get("sessionKey", ""))
	var matches: Array = []
	for event in state.get("marketPurchaseHistory", []):
		if not event is Dictionary or not event.get("sessionKey") is String \
				or not event.get("offerId") is String:
			return false
		if event["sessionKey"] == key:
			matches.append(event)
	var definitions: Variant = _content.read_module("shops:treasures")
	if not definitions is Dictionary or not definitions.get("treasures") is Array:
		return false
	var valid_pending := false
	for event in matches:
		if event.has("costMode"):
			return false
		var offer_id := String(event["offerId"])
		var offer: Dictionary = {}
		var remaining: Array = []
		for item in expected["immutableOffers"]:
			if item.get("id") == offer_id:
				offer = item
			else:
				remaining.append(item)
		if offer.is_empty():
			return false
		var definition: Dictionary = {}
		for row in definitions["treasures"]:
			if row is Dictionary and row.get("id") == offer_id:
				definition = row
				break
		var oath: bool = offer_id == "ghost_oath_rusted_sword"
		if not oath and (offer.get("_marketItem") != true \
				or definition.get("type") not in TreasureAcquisition.SLOTS):
			return false
		var cost: Variant = offer.get("costSpec")
		if not cost is Array or cost.size() != 2 \
				or cost[0].get("key") != "spiritStone" \
				or cost[1].get("key") != "lifespan":
			return false
		var stone := int(cost[0].get("amount", -1))
		var debt_id := "ghost_debt:%s:%s:r%d" % [expected["sessionId"],
			offer_id, int(expected.get("offerRevision", 1))]
		var debts: Array = state.get("marketState", {}).get("debts", [])
		var found: Array = debts.filter(func(value: Variant) -> bool:
			return value is Dictionary and value.get("debtId") == debt_id)
		if found.size() != 1:
			return false
		var debt: Dictionary = found[0]
		var instance_id := String(debt.get("acquiredInstanceId", ""))
		var instance: Dictionary = state.get("treasureInstances", {}).get(
			instance_id, {})
		var token := "treasure:shop:life:%s:decision:%d:session:%s:offer:%s" % [
			state.get("runClock", {}).get("lifeId", ""),
			int(expected["openedAtDecisionIndex"]), key, offer_id]
		if debt.get("status") != "PENDING" \
				or debt.get("originSessionId") != expected["sessionId"] \
				or instance.get("definitionId") != offer_id \
				or instance.get("transactionId") != token \
				or instance.get("provenance", {}).get("source") != "ghost_market_purchase" \
				or instance.get("provenance", {}).get("sourceId") != key + ":" + offer_id \
				or state.get("treasureCommandReceipts", {}).get(
					token, {}).get("instanceId") != instance_id:
			return false
		if oath:
			var fact_id := String(debt.get("sourceFactInstanceId", ""))
			var fact: Dictionary = state.get("noncombatFlow", {}).get(
				"spineFacts", {}).get(fact_id, {})
			if debt.get("kind") != "ghost_oath_sword" \
					or debt.get("dueDecisionIndex") != int(expected[
						"openedAtDecisionIndex"]) - 1 + maxi(1, int(offer.get(
						"ghostOathContract", {}).get("dueDecisionOffset", 3))) \
					or debt.get("settlementCostSpec") != offer.get(
						"ghostOathContract", {}).get("settlementCostSpec") \
					or instance.get("provenance", {}).get("ghostDebtId") != debt_id \
					or instance.get("provenance", {}).get("sourceFactInstanceId") != fact_id \
					or fact.get("factTypeId") != "sword_origin_ghost_oath" \
					or fact.get("status") != "active" \
					or fact.get("payload", {}).get("itemInstanceId") != instance_id \
					or fact.get("payload", {}).get("sessionKey") != key:
				return false
		else:
			var due_offset := maxi(3, int(expected.get("debt", {}).get(
				"minDueOffset", 3)))
			var settlement: Variant = debt.get("settlementCostSpec")
			if not settlement is Array or settlement.size() != 1 \
					or not settlement[0] is Dictionary:
				return false
			var payment: Dictionary = settlement[0]
			if debt.has("kind") or debt.has("sourceFactInstanceId") \
					or debt.get("dueDecisionIndex") != int(expected[
						"openedAtDecisionIndex"]) - 1 + due_offset \
					or payment.get("kind") != "resource" \
					or payment.get("key") != "spiritStone" \
					or not payment.get("amount") is float \
						and not payment.get("amount") is int \
					or float(payment.get("amount", -1)) != float(
						maxi(1, ceili(stone * 0.5))) \
					or instance.get("provenance", {}).has("ghostDebtId"):
				return false
		var pending: Variant = state.get("pendingLoadoutDecision")
		if pending is Dictionary and pending.get("purchaseReceiptToken") == token:
			if pending.get("instanceId") != instance_id \
					or pending.get("ghostDebtId") != debt_id \
					or pending.get("targetSlot") != definition.get("type"):
				return false
			valid_pending = true
		expected["immutableOffers"] = remaining
		expected["summary"]["purchaseCount"] = int(expected["summary"].get(
			"purchaseCount", 0)) + 1
		expected["summary"]["spiritStoneSpent"] = int(expected["summary"].get(
			"spiritStoneSpent", 0)) + stone
		expected["summary"]["purchasedItems"].append({"id": offer_id,
			"name": offer["name"], "costSpec": cost.duplicate(true),
			"costMode": null})
		if not expected["summary"].has("ghostDebtTerms"):
			expected["summary"]["ghostDebtTerms"] = []
		expected["summary"]["ghostDebtTerms"].append(debt.duplicate(true))
	if state.get("pendingLoadoutDecision") is Dictionary and not valid_pending:
		return false
	return true

func _expected_session(state: Dictionary) -> Dictionary:
	var index := int(state.get("runClock", {}).get("decisionIndex", -1)) + 1
	var key := "vendor:%s:%d:%s:ghost_market" % [state.get("runClock", {}).get(
		"lifeId", ""), index, CARD_ID]
	var plan: Variant = state.get("pendingGhostPlan")
	if not plan is Dictionary:
		return {}
	var session: Dictionary = _catalog.build_session(plan, key, index)
	if session.is_empty():
		return {}
	session["openedAtTurn"] = int(state.get("turn", 0))
	session["direction"] = "left"
	session["card"] = state.get("pendingMarketChoiceCard", {}).duplicate(true)
	session["choice"] = session["card"].get("choices", {}).get("left", {}).duplicate(true)
	var min_markup := 1000000.0
	var max_markup := 0.0
	for item in plan.get("stock", []):
		if item is Dictionary and item.get("ghostMarkup") is float:
			min_markup = minf(min_markup, float(item["ghostMarkup"]))
			max_markup = maxf(max_markup, float(item["ghostMarkup"]))
	var markup_range: Variant = {"min": min_markup, "max": max_markup} \
		if max_markup > 0.0 else null
	var current_route: Dictionary = _catalog._active_route(state)
	if current_route.is_empty():
		return {}
	var current_fortune := int(state.get("attributes", {}).get("fortune", 0))
	# Stock and its prices were drawn on arrival; the header reads entry-time state.
	session["vendorMeta"] = {"market": true,
		"fortuneTier": _catalog._fortune_tier_text(current_fortune),
		"priceMult": plan.get("meta", {}).get(
		"priceMultiplier"), "ghostMarkupRange": markup_range,
		"fortune": current_fortune, "tradeRoute": current_route}
	return session
