extends RefCounted

const MODULE := "cards:foundation"
const DUNGEON_ID := "mysteryRealm"
const SOURCE_CARD_ID := "f_trial"
const NODE_CARDS := {"echo": "realm_elder", "prepare": "realm_prepare",
	"boss": "realm_guardian", "reward": "realm_treasure"}
const FORK_CARD_ID := "_dungeon_fork_fork"

var last_error := ""
var _content: RefCounted


func _init(content: RefCounted) -> void:
	_content = content


func _catalog() -> Dictionary:
	last_error = ""
	var document: Variant = _content.read_module(MODULE)
	if not document is Dictionary:
		last_error = "筑基秘境来源数据不可用"
		return {}
	var dungeon: Variant = document.get("dungeons", {}).get(DUNGEON_ID)
	var cards: Variant = document.get("dungeonCards")
	if not dungeon is Dictionary or not cards is Dictionary \
			or dungeon.get("startNode") != "echo" \
			or not dungeon.get("graph") is Dictionary:
		last_error = "筑基秘境图来源不符"
		return {}
	var graph: Dictionary = dungeon["graph"]
	if graph.size() != 6 or graph.get("echo", {}).get("next") != "fork" \
			or graph.get("fork", {}).get("type") != "FORK" \
			or graph.get("prepare", {}).get("next") != "boss" \
			or graph.get("boss", {}).get("next") != "reward" \
			or graph.get("reward", {}).get("next") != "exit" \
			or graph.get("exit", {}).get("type") != "EXIT":
		last_error = "筑基秘境图节点不完整"
		return {}
	for node_id in NODE_CARDS:
		if graph.get(node_id, {}).get("card") != NODE_CARDS[node_id] \
				or not cards.get(NODE_CARDS[node_id]) is Dictionary:
			last_error = "筑基秘境卡来源不符"
			return {}
	var paths: Dictionary = graph["fork"].get("paths", {})
	if paths.size() != 2 or paths.get("deduce", {}).get("next") != "prepare" \
			or paths.get("break", {}).get("next") != "boss":
		last_error = "筑基秘境岔路来源不符"
		return {}
	return document


func node_card(state: Dictionary) -> Dictionary:
	var run: Variant = state.get("dungeonRun")
	if not run is Dictionary or run.get("status") != "active" \
			or run.get("dungeonId") != DUNGEON_ID \
			or state.get("dungeon") != DUNGEON_ID:
		return {}
	var node_id := String(state.get("dungeonNodeId", ""))
	var document := _catalog()
	if document.is_empty():
		return {}
	var graph: Dictionary = document["dungeons"][DUNGEON_ID]["graph"]
	var node: Dictionary = graph.get(node_id, {})
	if node_id == "fork":
		if state.get("currentCardId") != FORK_CARD_ID:
			return {}
		var choices := {}
		var directions := ["left", "right"]
		var path_keys: Array = node.get("paths", {}).keys()
		for index in path_keys.size():
			var path: Dictionary = node["paths"][path_keys[index]]
			choices[directions[index]] = {"text": path.get("text", ""),
				"desc": path.get("desc", ""),
				"effects": path.get("effects", {}).duplicate(true),
				"_dungeonForkNext": path.get("next", "")}
		return {"id": FORK_CARD_ID, "type": "DUNGEON_FORK",
			"title": node.get("title", ""),
			"description": node.get("description", ""),
			"_dungeonNodeId": node_id, "choices": choices}
	if not NODE_CARDS.has(node_id) \
			or state.get("currentCardId") != NODE_CARDS[node_id]:
		return {}
	var card: Dictionary = document["dungeonCards"][NODE_CARDS[node_id]].duplicate(true)
	var image: Dictionary = _content.asset_status(String(card.get("sceneImage", "")))
	if not image.get("shaVerified", false) or not image.get("textureLoadable", false):
		last_error = "筑基秘境节点原图不可用"
		return {}
	card["_dungeonNodeId"] = node_id
	card["_dungeonNodeType"] = node.get("type", "")
	return card


func enter(candidate: Dictionary, source: Dictionary, decision: int) -> bool:
	if source.get("id") != SOURCE_CARD_ID or source.get("choices", {}).get(
			"right", {}).get("dungeon") != DUNGEON_ID \
			or candidate.get("realm") != "foundation" \
			or candidate.get("dungeonRun") != null or _catalog().is_empty():
		return false
	var life_id := String(candidate.get("runClock", {}).get("lifeId", ""))
	var session_id := "dungeon:%s:%d:%s" % [life_id, decision, DUNGEON_ID]
	candidate["dungeon"] = DUNGEON_ID
	candidate["dungeonNodeIndex"] = 0
	candidate["dungeonNodeId"] = "echo"
	candidate["dungeonPath"] = ["echo"]
	candidate["dungeonRun"] = {"sessionId": session_id,
		"dungeonId": DUNGEON_ID, "realm": candidate.get("realm"),
		"sourceCardId": SOURCE_CARD_ID, "sourceDecisionIndex": decision,
		"enteredAtTurn": decision - 1, "status": "active"}
	if not candidate.has("dungeonOutcomeReceipts"):
		candidate["dungeonOutcomeReceipts"] = []
	return _move_to(candidate, "echo", SOURCE_CARD_ID, decision)


func advance(candidate: Dictionary, source_id: String, direction: String,
		decision: int, cult_roll: float = -1.0, stone_roll: float = -1.0) -> bool:
	var card := node_card(candidate)
	if card.is_empty() or card.get("id") != source_id:
		return false
	var document := _catalog()
	if document.is_empty():
		return false
	var graph: Dictionary = document["dungeons"][DUNGEON_ID]["graph"]
	var node_id := String(candidate.get("dungeonNodeId", ""))
	var next_id := String(card.get("choices", {}).get(direction, {}).get(
		"_dungeonForkNext", "")) if node_id == "fork" else String(
		graph[node_id].get("next", ""))
	if node_id == "boss" or not graph.has(next_id):
		return false
	if next_id == "exit":
		if cult_roll < 0.0 or cult_roll >= 1.0 \
				or stone_roll < 0.0 or stone_roll >= 1.0:
			return false
		var cultivation := 3 + floori(cult_roll * 3.0)
		var stone := 2 + floori(stone_roll * 3.0)
		candidate["attributes"]["cultivation"] = mini(100,
			int(candidate["attributes"].get("cultivation", 0)) + cultivation)
		candidate["resources"]["spiritStone"] = int(candidate["resources"].get(
			"spiritStone", 0)) + stone
		candidate["dungeonPath"].append("exit")
		return complete(candidate, "success", decision)
	return _move_to(candidate, next_id, source_id, decision)


func after_boss_victory(candidate: Dictionary, decision: int) -> bool:
	if candidate.get("dungeonNodeId") != "boss" \
			or candidate.get("dungeonRun", {}).get("status") != "active" \
			or candidate.get("dungeonRun", {}).get("dungeonId") != DUNGEON_ID \
			or _catalog().is_empty():
		return false
	return _move_to(candidate, "reward", "realm_guardian", decision)


func _move_to(candidate: Dictionary, next_id: String, source_id: String,
		decision: int) -> bool:
	var card_id := FORK_CARD_ID if next_id == "fork" else String(
		NODE_CARDS.get(next_id, ""))
	if card_id.is_empty():
		return false
	candidate["dungeonNodeId"] = next_id
	if candidate.get("dungeonPath", []).back() != next_id:
		candidate["dungeonPath"].append(next_id)
	candidate["phase"] = "NORMAL_PENDING"
	candidate["currentCardId"] = card_id
	candidate["decisionCheckpoint"] = {"version": 1, "cardId": card_id,
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
		"outcome": outcome, "settledDecisionIndex": decision,
		"path": candidate.get("dungeonPath", []).duplicate(true)}
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
