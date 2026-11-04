extends RefCounted
const PathSkillFlow = preload("res://scripts/noncombat_path_skill_flow.gd")

const MODULE := "cards:nascent"
const ENTRY_CARD_ID := "n_ancient_ruins"
const DUNGEON_ID := "ancient_ruins"
const NODE_IDS := ["ar_entrance", "ar_hall", "ar_secret", "ar_boss"]

var last_error := ""
var _content: RefCounted


func _init(content: RefCounted) -> void:
	_content = content


func catalog() -> Dictionary:
	last_error = ""
	var document: Variant = _content.read_module(MODULE)
	if not document is Dictionary or _content.source_sha256(MODULE).length() != 64:
		last_error = "nascent ruins source unavailable"
		return {}
	var dungeon: Dictionary = document.get("dungeons", {}).get(DUNGEON_ID, {})
	var cards: Variant = document.get("dungeonCards")
	if not cards is Dictionary or dungeon.get("id") != DUNGEON_ID \
			or dungeon.get("nodeCount") != NODE_IDS.size() \
			or not dungeon.get("nodes") is Array \
			or dungeon.nodes.size() != NODE_IDS.size():
		last_error = "nascent ruins node sequence invalid"
		return {}
	for index in NODE_IDS.size():
		var node: Dictionary = dungeon.nodes[index]
		var card: Dictionary = cards.get(NODE_IDS[index], {})
		if node.get("card") != NODE_IDS[index] or card.get("id") != NODE_IDS[index] \
				or card.get("dungeon") != DUNGEON_ID \
				or card.get("nodeIndex") != index \
				or not card.get("choices") is Dictionary:
			last_error = "nascent ruins card source invalid"
			return {}
	return document


func entry(state: Dictionary, card: Dictionary, direction: String) -> bool:
	return state.get("realm") == "nascent" and state.get("dungeonRun") == null \
		and card.get("id") == ENTRY_CARD_ID and direction == "left" \
		and card.get("choices", {}).get("left", {}).get("dungeon") == DUNGEON_ID \
		and not catalog().is_empty()


func node_card(state: Dictionary) -> Dictionary:
	var run: Variant = state.get("dungeonRun")
	if not run is Dictionary or run.get("status") != "active" \
			or run.get("realm") != "nascent" \
			or run.get("dungeonId") != DUNGEON_ID \
			or state.get("dungeon") != DUNGEON_ID \
			or run.get("sourceSha") != _content.source_sha256(MODULE):
		return {}
	var document := catalog()
	if document.is_empty():
		return {}
	var index := int(state.get("dungeonNodeIndex", -1))
	if index < 0 or index >= NODE_IDS.size():
		return {}
	var source: Dictionary = document.dungeonCards.get(NODE_IDS[index], {})
	if state.get("currentCardId") != source.get("id"):
		return {}
	var image: Dictionary = _content.asset_status(source.get("sceneImage"))
	if image.get("shaVerified") != true or image.get("textureLoadable") != true:
		last_error = "nascent ruins scene unavailable"
		return {}
	var card := source.duplicate(true)
	card["_dungeonId"] = DUNGEON_ID
	card["_dungeonNodeIndex"] = index
	return card


func enter(candidate: Dictionary, source: Dictionary, direction: String,
		decision: int) -> bool:
	if not entry(candidate, source, direction) or decision <= 0:
		return false
	var life_id := String(candidate.get("runClock", {}).get("lifeId", ""))
	if life_id.is_empty():
		return false
	candidate["dungeon"] = DUNGEON_ID
	candidate["dungeonNodeIndex"] = 0
	candidate["dungeonNodeId"] = null
	candidate["dungeonPath"] = []
	candidate["dungeonRun"] = {"sessionId": "dungeon:%s:%d:%s" % [life_id,
		decision, DUNGEON_ID], "dungeonId": DUNGEON_ID, "realm": "nascent",
		"sourceCardId": source.id, "sourceDecisionIndex": decision,
		"enteredAtTurn": decision - 1, "sourceSha": _content.source_sha256(MODULE),
		"status": "active"}
	return _move_to(candidate, NODE_IDS[0], source.id, decision)


func advance(candidate: Dictionary, source_id: String, decision: int) -> bool:
	var current := node_card(candidate)
	if current.is_empty() or current.get("id") != source_id:
		return false
	var next_index := int(candidate.get("dungeonNodeIndex", -1)) + 1
	if next_index >= NODE_IDS.size():
		return complete(candidate, "success", decision)
	candidate["dungeonNodeIndex"] = next_index
	return _move_to(candidate, NODE_IDS[next_index], source_id, decision)


func _move_to(candidate: Dictionary, card_id: String, source_id: String,
		decision: int) -> bool:
	candidate["phase"] = "NORMAL_PENDING"
	candidate["currentCardId"] = card_id
	candidate["decisionCheckpoint"] = {"version": 1, "cardId": card_id,
		"sourceCardId": source_id, "turn": decision,
		"decisionIndex": decision, "flowSource": "dungeon",
		"dungeonId": DUNGEON_ID}
	return not node_card(candidate).is_empty()


func complete(candidate: Dictionary, outcome: String, decision: int) -> bool:
	var run: Variant = candidate.get("dungeonRun")
	if not run is Dictionary or run.get("status") != "active" \
			or run.get("realm") != "nascent" \
			or run.get("dungeonId") != DUNGEON_ID \
			or outcome not in ["success", "failure", "abandon"]:
		return false
	var receipts: Array = candidate.get("dungeonOutcomeReceipts", [])
	if receipts.any(func(row: Variant) -> bool:
		return row is Dictionary and row.get("sessionId") == run.sessionId):
		return false
	if not PathSkillFlow.new(_content).apply_dungeon_completion(candidate,
			outcome, decision):
		return false
	receipts.append({"lifeId": candidate.get("runClock", {}).get("lifeId"),
		"sessionId": run.sessionId, "dungeonId": DUNGEON_ID,
		"sourceCardId": run.sourceCardId,
		"sourceDecisionIndex": run.sourceDecisionIndex,
		"outcome": outcome, "settledDecisionIndex": decision,
		"path": candidate.get("dungeonPath", []).duplicate(true)})
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
		"sourceCardId": run.sourceCardId, "turn": decision,
		"decisionIndex": decision, "flowPending": true}
	return true
