extends SceneTree

const Repository = preload("res://scripts/noncombat_content_repository.gd")
const LineageFlow = preload("res://scripts/noncombat_lineage_flow.gd")
const TradeRouteFlow = preload("res://scripts/noncombat_trade_route_flow.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var flow = LineageFlow.new(Repository.new())
	var nodes: Dictionary = flow.source_nodes()
	var tree: Dictionary = flow.initial_tree()
	if nodes.size() != 16 or not flow.valid_tree(tree):
		return _fail("authored rebirth tree unavailable")
	var state := {"rebirthTree": tree, "legacyBonuses": {},
		"lineageEntries": []}
	var terminal := {"rebirthTree": tree, "lineageEntries": [],
		"lifeCount": 0, "path": "sword", "realm": "golden",
		"playerName": "试炼者", "turn": 60,
		"currentLocation": "宗门",
		"tradeRouteState": TradeRouteFlow.new(Repository.new()).initial_state(),
		"npcAffection": {"bai_luoxuan": 85},
		"clues": [{"id": "a"}, {"id": "b"}, {"id": "c"}],
		"attributes": {"karmaGood": 20, "karmaBad": 3},
		"battleResultHistory": [{"result": {"outcome": "victory"},
			"sourceCombat": {"title": "旧主", "enemy": {"phases": [1, 2]}}}],
		"dungeonOutcomeReceipts": [{"outcome": "success"}],
		"marketPurchaseHistory": [{"sessionKey": "market:one",
			"offerId": "sample"}],
		"lastLessonVendorEventHistory": [{"sessionKey": "lesson:one",
			"kind": "purchase", "itemId": "lesson_goods"}]}
	var archived: Dictionary = flow.archive_life(terminal)
	if archived.get("lineageEntries", []).size() != 1 \
			or archived.lineageEntries[0].get("insightAwarded") != 9 \
			or archived.rebirthTree.insight != 9:
		return _fail("first archive did not award source insight formula")
	if archived.lineageEntries[0].get("activeRoute") != "青云剑路" \
			or archived.lineageEntries[0].get("deeds", {}).get("purchases") != 2:
		return _fail("current route or last-lesson purchase missing from new archive")
	var old_archive: Dictionary = flow.archive_life(terminal, false)
	if old_archive.get("lineageEntries", []).size() != 1 \
			or old_archive.lineageEntries[0].get("activeRoute") != null \
			or old_archive.lineageEntries[0].get("deeds", {}).get("purchases") != 1:
		return _fail("v4 archive projection changed during v5 migration")
	terminal["lineageEntries"] = archived.lineageEntries
	terminal["rebirthTree"] = archived.rebirthTree
	var repeated: Dictionary = flow.archive_life(terminal)
	if repeated.get("rebirthTree", {}).get("insight") != 9 \
			or repeated.get("lineageEntries", []).size() != 1:
		return _fail("same life awarded insight twice")
	state["rebirthTree"] = archived.rebirthTree
	var first: Dictionary = flow.unlock(state, "bonds_familiar_voice")
	if first.is_empty() or first.rebirthTree.insight != 8 \
			or flow.effect_value(first.rebirthTree, "affectionRetention") != 0.05:
		return _fail("source bond node did not spend insight or add retention")
	if not flow.unlock(state, "bonds_red_thread").is_empty():
		return _fail("locked prerequisite was bypassed")
	var second: Dictionary = flow.unlock(first, "bonds_red_thread")
	if second.is_empty() or second.rebirthTree.insight != 6 \
			or not flow.refund(second, "bonds_familiar_voice").is_empty():
		return _fail("dependent bond node did not enforce source dependency")
	var refunded: Dictionary = flow.refund(second, "bonds_red_thread")
	if refunded.is_empty() or refunded.rebirthTree.insight != 8:
		return _fail("source node refund did not restore insight")
	var body: Dictionary = flow.unlock(state, "foundation_tempered_meridian")
	if body.is_empty() or body.get("legacyBonuses", {}).get("maxHp") != 1.0:
		return _fail("source bonus node did not update next-life bonus")
	var memory: Dictionary = flow.unlock(state, "memory_clear_mark")
	memory = flow.unlock(memory, "memory_other_shore")
	memory = flow.unlock(memory, "memory_four_paths")
	memory["legacyPathMemories"] = {"sword": 1, "pill": 5}
	if memory.is_empty() or flow.path_mastery(memory, "sword") != 3:
		return _fail("source cross-path memory translation did not resolve")
	print("NONCOMBAT_LINEAGE_TREE_PASS nodes=16 archive=true once=true prerequisite=true refund=true effects=true")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
