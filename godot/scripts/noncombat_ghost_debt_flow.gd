extends RefCounted

# Browser authorities: MarketSystem.collectDueDebtEvents and
# GameLogic._buildGhostDebtDueCard/_resolveGhostDebtAction.
const GhostCatalog = preload("res://scripts/noncombat_ghost_market_catalog.gd")
const FACT_TYPE := "sword_origin_ghost_oath"
const CONSUMER_ID := "ghost_oath_debt_settlement"

var _content: RefCounted
var _catalog: RefCounted
var last_error := ""

func _init(content: RefCounted) -> void:
	_content = content
	_catalog = GhostCatalog.new(content)

func settle(prior: Dictionary, candidate: Dictionary, can_queue: bool = true) -> bool:
	last_error = ""
	var market: Variant = candidate.get("marketState")
	if not market is Dictionary:
		return not candidate.has("pendingGhostDebtId")
	var debts: Variant = market.get("debts", [])
	if not debts is Array or candidate.has("pendingGhostDebtId") \
			and not candidate.get("pendingGhostDebtId") is String:
		last_error = "鬼市债务账本或待发指针无效"
		return false
	if debts.is_empty():
		return not candidate.has("pendingGhostDebtId")
	if candidate.get("ghostDebtSourcePins") != _catalog.source_pins():
		last_error = "鬼市债务来源指纹不符"
		return false
	var index := int(candidate.get("runClock", {}).get("decisionIndex", -1))
	var prior_index := int(prior.get("runClock", {}).get("decisionIndex", -1))
	if index < 0 or index < prior_index:
		return false
	var seen := {}
	for value in debts:
		if not value is Dictionary or not value.get("debtId") is String \
				or seen.has(value.get("debtId")) \
				or value.get("kind") not in [null, "ghost_oath_sword"] \
				or value.get("status") not in ["PENDING", "DUE", "SETTLED", "DEFAULTED"] \
				or int(value.get("dueDecisionIndex", -1)) < 0:
			last_error = "鬼市债务无效"
			return false
		if value.get("kind") == null and (value.has("sourceFactInstanceId") \
				or not _ordinary_debt_source_valid(candidate, value)):
			last_error = "鬼市普通债务来源无效"
			return false
		seen[value["debtId"]] = true
	if candidate.has("pendingGhostDebtId"):
		var existing: Dictionary = _debt(candidate, String(candidate["pendingGhostDebtId"]))
		if existing.get("status") != "DUE" or existing.get("pursuitQueued") != true:
			return false
	if index <= prior_index:
		return true
	if not can_queue:
		return true
	for value in debts:
		var debt: Dictionary = value
		if debt["status"] != "PENDING" or index < int(debt["dueDecisionIndex"]):
			continue
		debt["status"] = "DUE"
		debt["dueReceiptId"] = "debt_due:" + String(debt["debtId"])
		if not candidate.has("pendingGhostDebtId"):
			debt["pursuitQueued"] = true
			candidate["pendingGhostDebtId"] = debt["debtId"]
	return true

func due_card(state: Dictionary) -> Dictionary:
	var debt_id := String(state.get("pendingGhostDebtId", ""))
	var debt := _debt(state, debt_id)
	if debt.get("status") != "DUE" or debt.get("pursuitQueued") != true \
			or state.get("ghostDebtSourcePins") != _catalog.source_pins():
		return {}
	var instance_id := String(debt.get("acquiredInstanceId", ""))
	var fact_id := String(debt.get("sourceFactInstanceId", ""))
	var instance: Dictionary = state.get("treasureInstances", {}).get(instance_id, {})
	var fact: Dictionary = state.get("noncombatFlow", {}).get(
		"spineFacts", {}).get(fact_id, {})
	var oath: bool = debt.get("kind") == "ghost_oath_sword"
	if oath and (instance.get("definitionId") != "ghost_oath_rusted_sword" \
			or instance.get("provenance", {}).get("ghostDebtId") != debt_id \
			or fact.get("factTypeId") != FACT_TYPE or fact.get("status") != "active" \
			or fact.get("payload", {}).get("itemInstanceId") != instance_id):
		return {}
	if not oath and not _ordinary_debt_source_valid(state, debt):
		return {}
	var settlement := 0
	for cost in debt.get("settlementCostSpec", []):
		if cost.get("kind") != "resource" or cost.get("key") != "spiritStone":
			return {}
		settlement += int(cost.get("amount", 0))
	if settlement <= 0:
		return {}
	return {"id": "ghost_debt_due:" + debt_id,
		"title": "鬼市 · 无面人索债",
		"description": "雾里有人扣响门环。%s以寿元签下的契约已经到期；留名还须补上 %d 灵石，拒约则永失鬼市门路。" % [
			debt.get("contractLabel", "夜契残剑") if oath else "鬼市契约", settlement],
		"type": "GHOST_DEBT_DUE", "realm": state.get("realm", "qi"),
		"weight": 0, "once": true, "causalFactInstanceId": fact_id if oath else null,
		"causalConsumerId": CONSUMER_ID if oath else null,
		"choices": {"left": {"text": "按约留名（%d 灵石）" % settlement,
			"effects": {}, "action": {"type": "SETTLE_GHOST_DEBT",
				"debtId": debt_id, "outcome": "settled"},
			"desc": "补足 %d 灵石；无面人收下回执，鬼市仍认得你的名字。" % settlement},
			"right": {"text": "拒不应约", "effects": {},
				"action": {"type": "SETTLE_GHOST_DEBT", "debtId": debt_id,
					"outcome": "defaulted"},
				"desc": "此后鬼市之门将不再为你开启。"}}}

func resume(state: Dictionary) -> Dictionary:
	if state.get("phase") != "FLOW_PENDING" or not state.has("pendingGhostDebtId"):
		return {}
	var card := due_card(state)
	if card.is_empty():
		last_error = "鬼市索债待发来源不符"
		return {}
	var candidate: Dictionary = state.duplicate(true)
	candidate["pendingGhostDebtCard"] = card
	candidate["phase"] = "GHOST_DEBT_PENDING"
	candidate["currentCardId"] = card["id"]
	candidate["decisionCheckpoint"] = {"version": 1, "cardId": card["id"],
		"sourceCardId": state.get("decisionCheckpoint", {}).get("sourceCardId"),
		"turn": state["turn"], "decisionIndex": state["runClock"]["decisionIndex"],
		"flowSource": "interrupt:ghost_debt"}
	return candidate

func choice_available(state: Dictionary, direction: String) -> bool:
	if state.get("phase") != "GHOST_DEBT_PENDING" or direction not in ["left", "right"]:
		return false
	var card := due_card(state)
	if card.is_empty() or JSON.parse_string(JSON.stringify(card)) != \
			JSON.parse_string(JSON.stringify(state.get("pendingGhostDebtCard"))) \
			or card.get("id") != state.get("currentCardId"):
		return false
	if direction == "right":
		return true
	var debt := _debt(state, String(state["pendingGhostDebtId"]))
	var amount := int(debt.get("settlementCostSpec", [])[0].get("amount", -1))
	return amount > 0 and int(state.get("resources", {}).get("spiritStone", 0)) >= amount

func settle_choice(state: Dictionary, direction: String) -> Dictionary:
	if not choice_available(state, direction):
		return {}
	var candidate: Dictionary = state.duplicate(true)
	var debt_id := String(candidate["pendingGhostDebtId"])
	var debt := _debt(candidate, debt_id)
	var fact_id := String(debt.get("sourceFactInstanceId", ""))
	var index := int(candidate["runClock"]["decisionIndex"]) + 1
	var card_id := "ghost_debt_due:" + debt_id
	var receipt := "decision:%s:choice:%s:%d" % [
		candidate["runClock"]["lifeId"], card_id, index]
	if candidate["runClock"]["receipts"].has(receipt):
		return {}
	var flow: Dictionary = candidate["noncombatFlow"]
	var oath: bool = debt.get("kind") == "ghost_oath_sword"
	var fact: Dictionary = flow["spineFacts"].get(fact_id, {}) if oath else {}
	var consumption_key := fact_id + ":" + CONSUMER_ID
	if oath and (fact.get("status") != "active" or flow.get(
			"spineConsumptions", {}).has(consumption_key)):
		return {}
	var outcome := "SETTLED" if direction == "left" else "DEFAULTED"
	var amount := int(debt["settlementCostSpec"][0]["amount"])
	if direction == "left":
		candidate["resources"]["spiritStone"] = int(candidate[
			"resources"]["spiritStone"]) - amount
		debt["settlementPaid"] = debt["settlementCostSpec"].duplicate(true)
	debt["status"] = outcome
	debt["settlementReceiptId"] = "debt_settlement:%s:%s" % [
		debt_id, outcome.to_lower()]
	debt["pursuitQueued"] = false
	if outcome == "DEFAULTED" and debt.get("defaultConsequence") == \
			"ghost_market_access_revoked":
		candidate["marketState"]["ghostMarketAccess"] = "revoked"
	if oath:
		flow["spineConsumptions"] = flow.get("spineConsumptions", {}).duplicate(true)
		flow["spineConsumptions"][consumption_key] = {
			"factInstanceId": fact_id, "factTypeId": FACT_TYPE,
			"consumerId": CONSUMER_ID, "consumedDecisionIndex": index,
			"receipt": {"debtId": debt_id, "outcome": outcome.to_lower(),
				"acquiredInstanceId": debt["acquiredInstanceId"]}}
		fact["status"] = "consumed"
		fact["consumedDecisionIndex"] = index
		fact["consumedBy"] = CONSUMER_ID
	candidate["choiceHistory"].append({"cardId": card_id,
		"cardType": "GHOST_DEBT_DUE", "direction": direction,
		"turn": index - 1, "decisionIndex": index, "tags": []})
	while candidate["choiceHistory"].size() > 30:
		candidate["choiceHistory"].pop_front()
	candidate["cardsPlayed"].append(card_id)
	candidate["turn"] = index
	candidate["runClock"]["decisionIndex"] = index
	candidate["runClock"]["receipts"][receipt] = {"token": receipt,
		"decisionIndex": index, "sourceCardId": card_id, "kind": "choice"}
	candidate.erase("pendingGhostDebtId")
	candidate.erase("pendingGhostDebtCard")
	for remaining in candidate["marketState"]["debts"]:
		if remaining is Dictionary and remaining.get("status") == "DUE" \
				and remaining.get("pursuitQueued") != true:
			remaining["pursuitQueued"] = true
			candidate["pendingGhostDebtId"] = remaining["debtId"]
			break
	candidate["phase"] = "FLOW_PENDING"
	candidate["currentCardId"] = ""
	candidate["decisionCheckpoint"] = {"version": 1, "cardId": null,
		"sourceCardId": card_id, "turn": index, "decisionIndex": index,
		"flowPending": true}
	return candidate

func _debt(state: Dictionary, debt_id: String) -> Dictionary:
	for value in state.get("marketState", {}).get("debts", []):
		if value is Dictionary and value.get("debtId") == debt_id:
			return value
	return {}

func _ordinary_debt_source_valid(state: Dictionary, debt: Dictionary) -> bool:
	var instance_id := String(debt.get("acquiredInstanceId", ""))
	var instance: Dictionary = state.get("treasureInstances", {}).get(instance_id, {})
	var definition_id := String(instance.get("definitionId", ""))
	var origin := String(debt.get("originSessionId", ""))
	var provenance: Dictionary = instance.get("provenance", {})
	var token := String(instance.get("transactionId", ""))
	if instance_id.is_empty() or definition_id.is_empty() \
			or definition_id == "ghost_oath_rusted_sword" or origin.is_empty() \
			or provenance.get("source") != "ghost_market_purchase" \
			or provenance.get("channel") != "ghost_market" \
			or provenance.get("sourceId") != origin + ":" + definition_id \
			or state.get("treasureCommandReceipts", {}).get(
				token, {}).get("instanceId") != instance_id:
		return false
	var catalog: Variant = _content.read_module("shops:treasures")
	if not catalog is Dictionary:
		return false
	var owned_definition := false
	for row in catalog.get("treasures", []):
		if row is Dictionary and row.get("id") == definition_id \
				and row.get("type") in ["weapon", "armor", "accessory", "artifact"]:
			owned_definition = true
			break
	return owned_definition
