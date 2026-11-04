extends RefCounted

# Candidate-only port of MarketSystem.collectDueLicensedSwordDeliveries and
# markLicensedSwordDeliveryQueued. The presentation/claim consumer is separate.
const TreasureAcquisition = preload("res://scripts/noncombat_treasure_acquisition.gd")
const NormalChoicePolicy = preload("res://scripts/noncombat_normal_choice_policy.gd")
const MilestoneFlow = preload("res://scripts/noncombat_milestone_flow.gd")
const DEFINITION_ID := "licensed_rusted_sword"
const PROVENANCE_ID := "sword_origin_licensed"
const DELAY := 3

var _content: RefCounted
var _treasures: RefCounted
var _choice_policy: RefCounted

func _init(content: RefCounted) -> void:
	_content = content
	_treasures = TreasureAcquisition.new(content)
	_choice_policy = NormalChoicePolicy.new(content)

func settle(prior: Dictionary, candidate: Dictionary, can_queue: bool = true) -> bool:
	var market_value: Variant = candidate.get("marketState")
	if not market_value is Dictionary:
		# The old opening has no market ledger yet. A delivery pointer cannot
		# exist there, including in a restored or externally staged snapshot.
		return not candidate.has("pendingLicensedDeliveryOrderId")
	var orders_value: Variant = market_value.get("rustedSwordOrders", [])
	if not orders_value is Array:
		return false
	var orders: Array = orders_value
	if orders.is_empty():
		return not candidate.has("pendingLicensedDeliveryOrderId")
	var prior_index := int(prior.get("runClock", {}).get("decisionIndex", -1))
	var index := int(candidate.get("runClock", {}).get("decisionIndex", -1))
	if index < 0 or index < prior_index:
		return false
	var seen := {}
	var pending_id: String = String(candidate.get("pendingLicensedDeliveryOrderId", ""))
	var pending_found := pending_id.is_empty()
	for order_value in orders:
		if not order_value is Dictionary:
			return false
		var order: Dictionary = order_value
		var order_id := String(order.get("orderId", ""))
		var fact_id := String(order.get("factInstanceId", ""))
		var consumer_id := String(order.get("consumerId", ""))
		var registered := int(order.get("registeredCoreDecisionIndex", -1))
		if fact_id.is_empty() or consumer_id != "regulated_rusted_sword_order" \
				or order_id != "licensed_rusted_sword:%s:%s" % [fact_id, consumer_id] \
				or seen.has(order_id) or order.get("definitionId") != DEFINITION_ID \
				or order.get("provenanceFactTypeId") != PROVENANCE_ID \
				or registered < 0 or int(order.get("coreDecisionDelay", -1)) != DELAY \
				or int(order.get("dueCoreDecisionIndex", -1)) != registered + DELAY \
				or not order.get("deliveryQueued") is bool \
				or order.get("status") not in ["REGISTERED", "READY", "CLAIMED"]:
			return false
		seen[order_id] = true
		if order.get("status") == "REGISTERED" and (order["deliveryQueued"] \
				or order.get("deliveryReceiptId") != null):
			return false
		if order.get("status") == "READY" and order.get("deliveryReceiptId") \
				!= "licensed_rusted_sword_due:" + order_id:
			return false
		if order_id == pending_id:
			if order.get("status") != "READY" or order.get("deliveryQueued") != true:
				return false
			pending_found = true
	if not pending_found:
		return false
	if index <= prior_index or not can_queue:
		return true
	# A due order is marked READY at the authoritative core decision, even if
	# another authored interrupt has priority over showing the delivery card.
	for order_value in orders:
		var order: Dictionary = order_value
		if order["status"] == "REGISTERED" and index >= int(order["dueCoreDecisionIndex"]):
			order["status"] = "READY"
			order["deliveryReceiptId"] = "licensed_rusted_sword_due:" + String(order["orderId"])
	if pending_id.is_empty():
		for order_value in orders:
			var order: Dictionary = order_value
			if order["status"] == "READY" and order["deliveryQueued"] == false:
				order["deliveryQueued"] = true
				candidate["pendingLicensedDeliveryOrderId"] = order["orderId"]
				break
	return true


func delivery_card(state: Dictionary) -> Dictionary:
	var order: Dictionary = _pending_order(state)
	if order.is_empty():
		return {}
	var order_id: String = order["orderId"]
	var label := String(order.get("orderLabel", "坊市净炼残剑"))
	return {"id": "regulated_rusted_sword_delivery:" + order_id,
		"title": "坊市 · 官坊正货已到",
		"description": "三次决断已过，坊市差役送来一只覆着官印的窄匣。你曾用流转号登记的【%s】已经净炼完毕；回执、灵石定金与器物来路在同一册上，可以当面验收。" % label,
		"type": "REGULATED_RUSTED_SWORD_DELIVERY",
		"realm": state.get("realm", "qi"), "weight": 0, "once": true,
		"choices": {"left": {"text": "验印收讫", "effects": {},
			"action": {"type": "CLAIM_LICENSED_RUSTED_SWORD",
				"orderId": order_id},
			"desc": "领取净炼残剑，并立刻决定是否穿戴。"}}}


func resume(state: Dictionary) -> Dictionary:
	if state.get("phase") != "FLOW_PENDING":
		return {}
	var card := delivery_card(state)
	if card.is_empty():
		return {}
	var candidate: Dictionary = state.duplicate(true)
	candidate["pendingLicensedDeliveryCard"] = card
	candidate["phase"] = "LICENSED_DELIVERY_PENDING"
	candidate["currentCardId"] = card["id"]
	candidate["decisionCheckpoint"] = {"version": 1, "cardId": card["id"],
		"sourceCardId": state.get("decisionCheckpoint", {}).get("sourceCardId"),
		"turn": state["turn"], "decisionIndex": state["runClock"]["decisionIndex"],
		"flowSource": "interrupt:regulated_delivery"}
	return candidate


func claim(state: Dictionary) -> Dictionary:
	if state.get("phase") != "LICENSED_DELIVERY_PENDING":
		return {}
	var order := _pending_order(state)
	var card := delivery_card(state)
	if order.is_empty() or card.is_empty() or card.get("id") != state.get(
			"currentCardId") or card != state.get("pendingLicensedDeliveryCard") \
			or state.get("pendingLoadoutDecision") != null:
		return {}
	var flow: Dictionary = state.get("noncombatFlow", {})
	if flow.get("causalGraphSourceSha") != _content.source_sha256(
			"narrative:causal_graph") or not _provenance_defined():
		return {}
	var life_text := String(state.get("runClock", {}).get("lifeId", "")).get_slice(":", 2)
	if not life_text.is_valid_int():
		return {}
	var fact_id := "fact:%s:%s" % [life_text, PROVENANCE_ID]
	if flow.get("spineFacts", {}).has(fact_id):
		return {}
	var next_index := int(state.get("runClock", {}).get("decisionIndex", -1)) + 1
	var receipt := "decision:%s:choice:%s:%d" % [state["runClock"]["lifeId"],
		card["id"], next_index]
	if next_index <= 0 or state["runClock"]["receipts"].has(receipt):
		return {}
	var candidate: Dictionary = state.duplicate(true)
	if not _choice_policy._apply_passive_regen(candidate):
		return {}
	var order_id: String = order["orderId"]
	var acquisition_token := "licensed_rusted_sword_delivery:" + order_id
	if not _treasures.acquire(candidate, DEFINITION_ID, order_id, next_index,
			{"source": "regulated_rusted_sword_order", "channel": "regulated_market",
			"transactionId": acquisition_token, "sourceId": order_id,
			"details": {"rootFactInstanceId": order["factInstanceId"]}}):
		return {}
	var instance_id := String(candidate.get("treasureCommandReceipts", {}).get(
		acquisition_token, {}).get("instanceId", ""))
	if instance_id.is_empty():
		return {}
	var facts: Dictionary = candidate["noncombatFlow"]["spineFacts"]
	facts[fact_id] = {"factInstanceId": fact_id, "factTypeId": PROVENANCE_ID,
		"lifeCount": int(life_text), "status": "active",
		"producerId": "licensed_rusted_sword_delivery",
		"payload": {"orderId": order_id, "itemInstanceId": instance_id,
			"rootFactInstanceId": order["factInstanceId"],
			"acquisitionPath": "regulated_order"},
		"createdDecisionIndex": next_index, "terminalClosure": null,
		"closedDecisionIndex": null}
	var claimed: Dictionary = _find_order(candidate, order_id)
	if claimed.is_empty() or claimed.get("status") != "READY":
		return {}
	claimed["status"] = "CLAIMED"
	claimed["deliveryQueued"] = false
	claimed["instanceId"] = instance_id
	claimed["provenanceFactInstanceId"] = fact_id
	claimed["claimedDecisionIndex"] = next_index
	claimed["claimReceiptId"] = "licensed_rusted_sword_claim:" + order_id
	candidate.erase("pendingLicensedDeliveryOrderId")
	candidate.erase("pendingLicensedDeliveryCard")
	candidate["pendingLoadoutDecision"] = {"id": "loadout:regulated-order:" + order_id,
		"instanceId": instance_id,
		"sourceVendorSessionKey": "regulated_order:" + order_id,
		"purchaseReceiptToken": acquisition_token,
		"targetSlot": "weapon", "status": "pending",
		"allowedActions": {"equip": true, "stash": true,
			"viewProvenance": true, "return": false}, "refundPolicy": null}
	candidate["choiceHistory"].append({"cardId": card["id"],
		"cardType": card["type"], "direction": "left",
		"turn": next_index - 1, "decisionIndex": next_index, "tags": []})
	while candidate["choiceHistory"].size() > 30:
		candidate["choiceHistory"].pop_front()
	candidate["cardsPlayed"].append(card["id"])
	candidate["turn"] = next_index
	candidate["runClock"]["decisionIndex"] = next_index
	candidate["runClock"]["receipts"][receipt] = {"token": receipt,
		"decisionIndex": next_index, "sourceCardId": card["id"], "kind": "choice"}
	MilestoneFlow.tick_seeds(candidate)
	candidate["phase"] = "LICENSED_LOADOUT_PENDING"
	candidate["currentCardId"] = "licensed_loadout:" + order_id
	candidate["decisionCheckpoint"] = {"version": 1,
		"cardId": candidate["currentCardId"], "sourceCardId": card["id"],
		"turn": next_index, "decisionIndex": next_index}
	return candidate


func loadout_card(state: Dictionary) -> Dictionary:
	if state.get("phase") != "LICENSED_LOADOUT_PENDING":
		return {}
	var pending: Variant = state.get("pendingLoadoutDecision")
	if not pending is Dictionary or pending.get("status") != "pending":
		return {}
	return {"id": state.get("currentCardId"), "type": "TREASURE_LOADOUT",
		"title": "坊市 · 正货入手",
		"description": "官坊正货与来历回执已写入纳戒。决定立即穿戴，或先收入纳戒。",
		"realm": state.get("realm", "qi"), "choices": {}}


func resolve_loadout(state: Dictionary, action: String) -> Dictionary:
	if action not in ["equip", "stash"] or loadout_card(state).is_empty():
		return {}
	var pending: Dictionary = state["pendingLoadoutDecision"]
	var order_id := String(pending.get("sourceVendorSessionKey", "")).trim_prefix(
		"regulated_order:")
	var order := _find_order(state, order_id)
	var instance_id := String(pending.get("instanceId", ""))
	var token := String(pending.get("purchaseReceiptToken", ""))
	var fact: Dictionary = state.get("noncombatFlow", {}).get("spineFacts", {}).get(
		order.get("provenanceFactInstanceId", ""), {})
	if order.get("status") != "CLAIMED" or order.get("instanceId") != instance_id \
			or token != "licensed_rusted_sword_delivery:" + order_id \
			or pending.get("id") != "loadout:regulated-order:" + order_id \
			or pending.get("allowedActions", {}).get(action) != true \
			or state.get("treasureCommandReceipts", {}).get(token, {}).get(
				"instanceId") != instance_id \
			or state.get("treasureInstances", {}).get(instance_id, {}).get(
				"definitionId") != DEFINITION_ID \
			or fact.get("payload", {}).get("itemInstanceId") != instance_id:
		return {}
	var candidate: Dictionary = state.duplicate(true)
	if action == "equip" and not _treasures.equip_owned(candidate, instance_id,
			"weapon"):
		return {}
	candidate["pendingLoadoutDecision"] = null
	candidate["loadoutResolutionHistory"] = candidate.get(
		"loadoutResolutionHistory", []).duplicate(true)
	candidate["loadoutResolutionHistory"].append({"purchaseReceiptToken": token,
		"action": action})
	candidate["phase"] = "FLOW_PENDING"
	candidate["currentCardId"] = ""
	candidate["decisionCheckpoint"] = {"version": 1, "cardId": null,
		"sourceCardId": "licensed_loadout:" + order_id,
		"turn": candidate["turn"],
		"decisionIndex": candidate["runClock"]["decisionIndex"],
		"flowPending": true}
	return candidate


func _pending_order(state: Dictionary) -> Dictionary:
	var order_id := String(state.get("pendingLicensedDeliveryOrderId", ""))
	var order := _find_order(state, order_id)
	var index := int(state.get("runClock", {}).get("decisionIndex", -1))
	if order_id.is_empty() or order.get("status") != "READY" \
			or order.get("deliveryQueued") != true \
			or order.get("definitionId") != DEFINITION_ID \
			or order.get("deliveryReceiptId") != "licensed_rusted_sword_due:" + order_id \
			or index < int(order.get("dueCoreDecisionIndex", 2147483647)):
		return {}
	return order


func _find_order(state: Dictionary, order_id: String) -> Dictionary:
	if order_id.is_empty():
		return {}
	for value in state.get("marketState", {}).get("rustedSwordOrders", []):
		if value is Dictionary and value.get("orderId") == order_id:
			return value
	return {}


func _provenance_defined() -> bool:
	var document: Variant = _content.read_module("narrative:causal_graph")
	if not document is Dictionary or document.get("version") != 1:
		return false
	for row in document.get("factTypes", []):
		if row is Dictionary and row.get("factTypeId") == PROVENANCE_ID:
			return true
	return false
