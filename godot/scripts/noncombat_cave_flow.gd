extends RefCounted

# The authored qi cave is a linear three-card sequence. The source card and
# dungeon catalog own the text, choices and order; RunSession owns the run.
const MODULE := "cards:qi"
const DUNGEON_ID := "ancientCave"
const NODE_IDS := ["cave_spirit", "cave_beast", "cave_reward"]
var last_error := ""
var _content: RefCounted

func _init(content: RefCounted) -> void:
	_content = content


func _catalog() -> Dictionary:
	last_error = ""
	var document: Variant = _content.read_module(MODULE)
	if not document is Dictionary:
		last_error = "古洞来源数据不可用"
		return {}
	var dungeon: Variant = document.get("dungeons", {}).get(DUNGEON_ID)
	var cards: Variant = document.get("dungeonCards")
	if not dungeon is Dictionary or not cards is Dictionary \
			or not dungeon.get("nodes") is Array \
			or dungeon["nodes"].size() != NODE_IDS.size():
		last_error = "古洞节点来源不符"
		return {}
	for index in NODE_IDS.size():
		if dungeon["nodes"][index].get("card") != NODE_IDS[index] \
				or not cards.get(NODE_IDS[index]) is Dictionary:
			last_error = "古洞节点来源不符"
			return {}
	return document


func node_card(state: Dictionary) -> Dictionary:
	var run: Variant = state.get("dungeonRun")
	if not run is Dictionary or run.get("status") != "active" \
			or run.get("dungeonId") != DUNGEON_ID \
			or state.get("dungeon") != DUNGEON_ID:
		return {}
	var index := int(state.get("dungeonNodeIndex", -1))
	if index < 0 or index >= NODE_IDS.size() \
			or state.get("currentCardId") != NODE_IDS[index]:
		return {}
	var document := _catalog()
	if document.is_empty():
		return {}
	var card: Dictionary = document["dungeonCards"][NODE_IDS[index]].duplicate(true)
	var image: Dictionary = _content.asset_status(String(card.get("sceneImage", "")))
	if not image.get("shaVerified", false) or not image.get("textureLoadable", false):
		last_error = "古洞节点原图不可用"
		return {}
	return card


func enter(candidate: Dictionary, source: Dictionary, decision: int) -> bool:
	if source.get("id") != "q_cave" or source.get("choices", {}).get(
			"right", {}).get("dungeon") != DUNGEON_ID \
			or candidate.get("dungeonRun") != null or _catalog().is_empty():
		return false
	var life_id := String(candidate.get("runClock", {}).get("lifeId", ""))
	var session_id := "dungeon:%s:%d:%s" % [life_id, decision, DUNGEON_ID]
	candidate["dungeon"] = DUNGEON_ID
	candidate["dungeonNodeIndex"] = 0
	candidate["dungeonNodeId"] = null
	candidate["dungeonPath"] = []
	candidate["dungeonRun"] = {"sessionId": session_id,
		"dungeonId": DUNGEON_ID, "realm": candidate.get("realm"),
		"sourceCardId": source["id"], "sourceDecisionIndex": decision,
		"enteredAtTurn": decision - 1, "status": "active"}
	if not candidate.has("dungeonOutcomeReceipts"):
		candidate["dungeonOutcomeReceipts"] = []
	candidate["phase"] = "NORMAL_PENDING"
	candidate["currentCardId"] = NODE_IDS[0]
	candidate["decisionCheckpoint"] = {"version": 1, "cardId": NODE_IDS[0],
		"sourceCardId": source["id"], "turn": decision,
		"decisionIndex": decision, "flowSource": "dungeon", "dungeonId": DUNGEON_ID}
	return not node_card(candidate).is_empty()


func advance(candidate: Dictionary, source_id: String, decision: int,
		cult_roll: float, stone_roll: float) -> bool:
	var current := node_card(candidate)
	if current.is_empty() or current.get("id") != source_id:
		return false
	if int(candidate.get("attributes", {}).get("health", 0)) <= 0 \
			or int(candidate.get("attributes", {}).get("daoHeart", 0)) <= 0 \
			or int(candidate.get("resources", {}).get("lifespan", 0)) <= 0:
		return complete(candidate, "failure", decision)
	var index := int(candidate.get("dungeonNodeIndex", -1)) + 1
	if index >= NODE_IDS.size():
		if cult_roll < 0.0 or cult_roll >= 1.0 or stone_roll < 0.0 or stone_roll >= 1.0:
			return false
		var cultivation := 3 + floori(cult_roll * 3.0)
		var stone := 2 + floori(stone_roll * 3.0)
		candidate["attributes"]["cultivation"] = mini(100,
			int(candidate["attributes"].get("cultivation", 0)) + cultivation)
		candidate["resources"]["spiritStone"] = int(candidate["resources"].get(
			"spiritStone", 0)) + stone
		return complete(candidate, "success", decision)
	candidate["dungeonNodeIndex"] = index
	candidate["phase"] = "NORMAL_PENDING"
	candidate["currentCardId"] = NODE_IDS[index]
	candidate["decisionCheckpoint"] = {"version": 1, "cardId": NODE_IDS[index],
		"sourceCardId": source_id, "turn": decision,
		"decisionIndex": decision, "flowSource": "dungeon", "dungeonId": DUNGEON_ID}
	return not node_card(candidate).is_empty()


func complete(candidate: Dictionary, outcome: String, decision: int) -> bool:
	var run: Variant = candidate.get("dungeonRun")
	if not run is Dictionary or run.get("status") != "active" \
			or run.get("dungeonId") != DUNGEON_ID \
			or outcome not in ["success", "failure", "abandon"]:
		return false
	var receipt := {"lifeId": candidate.get("runClock", {}).get("lifeId"),
		"sessionId": run["sessionId"], "dungeonId": DUNGEON_ID,
		"sourceCardId": run["sourceCardId"],
		"sourceDecisionIndex": run["sourceDecisionIndex"],
		"outcome": outcome, "settledDecisionIndex": decision}
	var receipts: Array = candidate.get("dungeonOutcomeReceipts", [])
	for prior in receipts:
		if prior.get("sessionId") == run["sessionId"]:
			return false
	receipts.append(receipt)
	while receipts.size() > 32:
		receipts.pop_front()
	candidate["dungeonOutcomeReceipts"] = receipts
	candidate["dungeon"] = null
	candidate["dungeonNodeIndex"] = 0
	candidate["dungeonNodeId"] = null
	candidate["dungeonPath"] = []
	candidate["dungeonRun"] = null
	candidate["phase"] = "FLOW_PENDING"
	candidate["currentCardId"] = ""
	candidate["decisionCheckpoint"] = {"version": 1, "cardId": null,
		"sourceCardId": run["sourceCardId"], "turn": decision,
		"decisionIndex": decision, "flowPending": true}
	return true
