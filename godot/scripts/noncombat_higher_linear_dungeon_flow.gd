extends RefCounted
const PathSkillFlow = preload("res://scripts/noncombat_path_skill_flow.gd")

const ENTRIES := {"d_immortal_trace": "immortal_ruins",
	"t_immortal_test": "immortal_trial"}
const REALMS := {"immortal_ruins": "deity", "immortal_trial": "tribulation"}

var last_error := ""
var _content: RefCounted


func _init(content: RefCounted) -> void:
	_content = content


func _module(dungeon_id: String) -> String:
	return "cards:" + String(REALMS.get(dungeon_id, ""))


func catalog(dungeon_id: String) -> Dictionary:
	last_error = ""
	if not REALMS.has(dungeon_id):
		return {}
	var module_id := _module(dungeon_id)
	var document: Variant = _content.read_module(module_id)
	if not document is Dictionary or _content.source_sha256(module_id).length() != 64:
		last_error = "higher dungeon source unavailable"
		return {}
	var dungeon: Dictionary = document.get("dungeons", {}).get(dungeon_id, {})
	var cards: Variant = document.get("dungeonCards")
	if dungeon.get("id") != dungeon_id or not cards is Dictionary \
			or not dungeon.get("nodes") is Array \
			or dungeon.nodes.size() != int(dungeon.get("nodeCount", -1)) \
			or dungeon.nodes.is_empty():
		last_error = "higher dungeon node sequence invalid"
		return {}
	for index in dungeon.nodes.size():
		var node: Dictionary = dungeon.nodes[index]
		var node_id := String(node.get("card", ""))
		var card: Dictionary = cards.get(node_id, {})
		if node_id.is_empty() or card.get("id") != node_id \
				or card.get("dungeon") != dungeon_id \
				or int(card.get("nodeIndex", -1)) != index \
				or not card.get("choices") is Dictionary:
			last_error = "higher dungeon card source invalid"
			return {}
	return document


func entry(state: Dictionary, card: Dictionary, direction: String) -> bool:
	var dungeon_id := String(ENTRIES.get(card.get("id"), ""))
	return not dungeon_id.is_empty() and direction == "left" \
		and state.get("realm") == REALMS[dungeon_id] \
		and state.get("dungeonRun") == null \
		and card.get("choices", {}).get(direction, {}).get("dungeon") == dungeon_id \
		and not catalog(dungeon_id).is_empty()


func node_card(state: Dictionary) -> Dictionary:
	var run: Variant = state.get("dungeonRun")
	if not run is Dictionary or run.get("status") != "active":
		return {}
	var dungeon_id := String(run.get("dungeonId", ""))
	if not REALMS.has(dungeon_id) or run.get("realm") != REALMS[dungeon_id] \
			or state.get("dungeon") != dungeon_id \
			or run.get("sourceSha") != _content.source_sha256(_module(dungeon_id)):
		return {}
	var document := catalog(dungeon_id)
	if document.is_empty():
		return {}
	var nodes: Array = document.dungeons[dungeon_id].nodes
	var index := int(state.get("dungeonNodeIndex", -1))
	if index < 0 or index >= nodes.size():
		return {}
	var source: Dictionary = document.dungeonCards.get(nodes[index].card, {})
	if state.get("currentCardId") != source.get("id"):
		return {}
	var art: Dictionary = _content.asset_status(source.get("sceneImage"))
	if art.get("shaVerified") != true or art.get("textureLoadable") != true:
		last_error = "higher dungeon scene unavailable"
		return {}
	var card := source.duplicate(true)
	card["_dungeonId"] = dungeon_id
	card["_dungeonNodeIndex"] = index
	return card


func enter(candidate: Dictionary, source: Dictionary, direction: String,
		decision: int) -> bool:
	if not entry(candidate, source, direction) or decision <= 0:
		return false
	var dungeon_id := String(ENTRIES[source.id])
	var life_id := String(candidate.get("runClock", {}).get("lifeId", ""))
	if life_id.is_empty():
		return false
	candidate["dungeon"] = dungeon_id
	candidate["dungeonNodeIndex"] = 0
	candidate["dungeonNodeId"] = null
	candidate["dungeonPath"] = []
	candidate["dungeonRun"] = {"sessionId": "dungeon:%s:%d:%s" % [life_id,
		decision, dungeon_id], "dungeonId": dungeon_id,
		"realm": REALMS[dungeon_id], "sourceCardId": source.id,
		"sourceDecisionIndex": decision, "enteredAtTurn": decision - 1,
		"sourceSha": _content.source_sha256(_module(dungeon_id)), "status": "active"}
	return _move_to(candidate, String(catalog(dungeon_id).dungeons[dungeon_id].nodes[0].card),
		source.id, decision)


func advance(candidate: Dictionary, source_id: String, decision: int) -> bool:
	var current := node_card(candidate)
	if current.is_empty() or current.get("id") != source_id:
		return false
	var dungeon_id := String(candidate.dungeonRun.dungeonId)
	var nodes: Array = catalog(dungeon_id).dungeons[dungeon_id].nodes
	var next_index := int(candidate.get("dungeonNodeIndex", -1)) + 1
	if next_index >= nodes.size():
		return complete(candidate, "success", decision)
	candidate["dungeonNodeIndex"] = next_index
	return _move_to(candidate, String(nodes[next_index].card), source_id, decision)


func after_trial_victory(candidate: Dictionary, decision: int) -> bool:
	var run: Variant = candidate.get("dungeonRun")
	if not run is Dictionary or run.get("status") != "active" \
			or run.get("dungeonId") != "immortal_trial" \
			or candidate.get("dungeonNodeIndex") != 1 \
			or candidate.get("dungeon") != "immortal_trial":
		return false
	var nodes: Array = catalog("immortal_trial").get("dungeons", {}).get(
		"immortal_trial", {}).get("nodes", [])
	if nodes.size() != 4 or nodes[1].get("card") != "it_combat" \
			or nodes[2].get("card") != "it_reward":
		return false
	candidate["dungeonNodeIndex"] = 2
	return _move_to(candidate, "it_reward", "it_combat", decision)


func _move_to(candidate: Dictionary, card_id: String, source_id: String,
		decision: int) -> bool:
	candidate["phase"] = "NORMAL_PENDING"
	candidate["currentCardId"] = card_id
	candidate["decisionCheckpoint"] = {"version": 1, "cardId": card_id,
		"sourceCardId": source_id, "turn": decision, "decisionIndex": decision,
		"flowSource": "dungeon", "dungeonId": candidate.dungeonRun.dungeonId}
	return not node_card(candidate).is_empty()


func complete(candidate: Dictionary, outcome: String, decision: int) -> bool:
	var run: Variant = candidate.get("dungeonRun")
	if not run is Dictionary or run.get("status") != "active" \
			or not REALMS.has(run.get("dungeonId")) \
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
