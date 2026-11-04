extends RefCounted

# The five golden dungeons in the live browser source use linear node arrays.
# Their `battle` node labels currently lead to authored NORMAL choice cards.
const MODULE := "cards:golden"
const ENTRIES := {"g_ruins": "ancientRuins", "g_secret_sword": "swordSanctum",
	"g_secret_spell": "spellSanctum", "g_secret_body": "bodySanctum",
	"g_secret_pill": "pillSanctum"}

var last_error := ""
var _content: RefCounted


func _init(content: RefCounted) -> void:
	_content = content


func catalog() -> Dictionary:
	last_error = ""
	var document: Variant = _content.read_module(MODULE)
	if not document is Dictionary or _content.source_sha256(MODULE).length() != 64:
		last_error = "golden dungeon source unavailable"
		return {}
	var dungeons: Variant = document.get("dungeons")
	var cards: Variant = document.get("dungeonCards")
	if not dungeons is Dictionary or not cards is Dictionary \
			or dungeons.size() != ENTRIES.size():
		last_error = "golden dungeon catalog invalid"
		return {}
	for entry_id in ENTRIES:
		var dungeon_id: String = ENTRIES[entry_id]
		var dungeon: Dictionary = dungeons.get(dungeon_id, {})
		var nodes: Variant = dungeon.get("nodes")
		if not nodes is Array or nodes.size() != (4 if dungeon_id == "ancientRuins" else 3):
			last_error = "golden dungeon node sequence invalid"
			return {}
		for index in nodes.size():
			var node: Dictionary = nodes[index]
			var card: Dictionary = cards.get(node.get("card"), {})
			if node.get("type") not in ["event", "battle", "choice", "reward"] \
					or card.get("id") != node.get("card") \
					or card.get("type") != "NORMAL" \
					or not card.get("choices") is Dictionary:
				last_error = "golden dungeon card source invalid"
				return {}
	return document


func entry(state: Dictionary, card: Dictionary, direction: String) -> bool:
	if state.get("realm") != "golden" or state.get("dungeonRun") != null \
			or not ENTRIES.has(card.get("id")) or catalog().is_empty():
		return false
	var dungeon_id: String = ENTRIES[card.id]
	var expected_direction := "right" if card.id == "g_ruins" else "left"
	if direction != expected_direction or card.get("choices", {}).get(
			direction, {}).get("dungeon") != dungeon_id:
		return false
	if dungeon_id != "ancientRuins" and state.get("path") != catalog()[
		"dungeons"][dungeon_id].get("pathRestriction"):
		return false
	return true


func node_card(state: Dictionary) -> Dictionary:
	var run: Variant = state.get("dungeonRun")
	if not run is Dictionary or run.get("status") != "active" \
			or run.get("realm") != "golden" \
			or state.get("dungeon") != run.get("dungeonId") \
			or run.get("sourceSha") != _content.source_sha256(MODULE):
		return {}
	var document := catalog()
	if document.is_empty() or not document["dungeons"].has(run.dungeonId):
		return {}
	var nodes: Array = document["dungeons"][run.dungeonId].get("nodes", [])
	var index := int(state.get("dungeonNodeIndex", -1))
	if index < 0 or index >= nodes.size():
		return {}
	var node: Dictionary = nodes[index]
	var source: Dictionary = document["dungeonCards"].get(node.get("card"), {})
	if state.get("currentCardId") != source.get("id"):
		return {}
	var image: Dictionary = _content.asset_status(source.get("sceneImage"))
	if image.get("shaVerified") != true or image.get("textureLoadable") != true:
		last_error = "golden dungeon scene unavailable"
		return {}
	var card := source.duplicate(true)
	card["_dungeonId"] = run.dungeonId
	card["_dungeonNodeIndex"] = index
	card["_dungeonNodeType"] = node.type
	return card


func enter(candidate: Dictionary, source: Dictionary, direction: String,
		decision: int) -> bool:
	if not entry(candidate, source, direction):
		return false
	var dungeon_id: String = ENTRIES[source.id]
	var document := catalog()
	var first: Dictionary = document["dungeons"][dungeon_id]["nodes"][0]
	var life_id := String(candidate.get("runClock", {}).get("lifeId", ""))
	if life_id.is_empty():
		return false
	candidate["dungeon"] = dungeon_id
	candidate["dungeonNodeIndex"] = 0
	candidate["dungeonNodeId"] = null
	# CardSystem only appends dungeonPath for graph nodes; these source arrays
	# use dungeonNodeIndex and leave the path empty through completion.
	candidate["dungeonPath"] = []
	candidate["dungeonRun"] = {"sessionId": "dungeon:%s:%d:%s" % [life_id,
		decision, dungeon_id], "dungeonId": dungeon_id, "realm": "golden",
		"sourceCardId": source.id, "sourceDecisionIndex": decision,
		"enteredAtTurn": decision - 1, "sourceSha": _content.source_sha256(MODULE),
		"status": "active"}
	return _move_to(candidate, String(first.card), source.id, decision)


func advance(candidate: Dictionary, source_id: String, decision: int) -> bool:
	var current := node_card(candidate)
	if current.is_empty() or current.get("id") != source_id:
		return false
	var document := catalog()
	var run: Dictionary = candidate.dungeonRun
	var nodes: Array = document["dungeons"][run.dungeonId].nodes
	var next_index := int(candidate.dungeonNodeIndex) + 1
	if next_index >= nodes.size():
		return complete(candidate, "success", decision)
	candidate["dungeonNodeIndex"] = next_index
	var next_id := String(nodes[next_index].card)
	return _move_to(candidate, next_id, source_id, decision)


func _move_to(candidate: Dictionary, card_id: String, source_id: String,
		decision: int) -> bool:
	candidate["phase"] = "NORMAL_PENDING"
	candidate["currentCardId"] = card_id
	candidate["decisionCheckpoint"] = {"version": 1, "cardId": card_id,
		"sourceCardId": source_id, "turn": decision,
		"decisionIndex": decision, "flowSource": "dungeon",
		"dungeonId": candidate.dungeon}
	return not node_card(candidate).is_empty()


func complete(candidate: Dictionary, outcome: String, decision: int) -> bool:
	var run: Variant = candidate.get("dungeonRun")
	if not run is Dictionary or run.get("status") != "active" \
			or run.get("realm") != "golden" \
			or outcome not in ["success", "failure", "abandon"]:
		return false
	var receipts: Array = candidate.get("dungeonOutcomeReceipts", [])
	if receipts.any(func(row: Variant) -> bool:
		return row is Dictionary and row.get("sessionId") == run.sessionId):
		return false
	receipts.append({"lifeId": candidate.get("runClock", {}).get("lifeId"),
		"sessionId": run.sessionId, "dungeonId": run.dungeonId,
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
