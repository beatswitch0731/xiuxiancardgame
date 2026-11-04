extends RefCounted

# Browser authority: LineageSystem.js and progression/rebirth_tree.json.
const MODULE := "progression:rebirth_tree"
const RULE_SHA := "3076bd19e9fe0be27aa59cebe451440a680247708b5aad05fe85e6cc4b776bcd"
const REALMS := ["qi", "foundation", "golden", "nascent", "deity", "tribulation"]

var last_error := ""
var _content: RefCounted


func _init(content: RefCounted) -> void:
	_content = content


func source_nodes() -> Dictionary:
	last_error = ""
	var doc: Variant = _content.read_module(MODULE)
	if not doc is Dictionary or doc.get("version") != 1 \
			or doc.get("contractId") != "rebirth_tree_v1" \
			or not doc.get("branches") is Array \
			or _content.source_sha256(MODULE).length() != 64:
		last_error = "轮回树来源不可用"
		return {}
	var nodes := {}
	for branch in doc.branches:
		if not branch is Dictionary or not branch.get("nodes") is Array:
			last_error = "轮回树分支无效"
			return {}
		for node in branch.nodes:
			if not node is Dictionary or not node.get("id") is String \
					or nodes.has(node.id) or not node.get("cost") is int \
						and not node.get("cost") is float \
					or not node.get("requires") is Array \
					or not node.get("effect") is Dictionary \
					or not node.effect.get("key") is String \
					or not node.effect.get("value") is int \
						and not node.effect.get("value") is float:
				last_error = "轮回树节点无效"
				return {}
			nodes[node.id] = node
	return nodes


func initial_tree() -> Dictionary:
	if source_nodes().is_empty():
		return {}
	return {"version": 1, "insight": 0, "spentInsight": 0,
		"unlockedNodeIds": [], "sourceSha": _content.source_sha256(MODULE),
		"ruleSha": RULE_SHA}


func valid_tree(tree: Variant) -> bool:
	var nodes := source_nodes()
	if nodes.is_empty() or not tree is Dictionary or tree.get("version") != 1 \
			or tree.get("sourceSha") != _content.source_sha256(MODULE) \
			or tree.get("ruleSha") != RULE_SHA \
			or not _whole(tree.get("insight")) or int(tree.insight) < 0 \
			or not _whole(tree.get("spentInsight")) or int(tree.spentInsight) < 0 \
			or not tree.get("unlockedNodeIds") is Array:
		last_error = "轮回树存档或来源无效"
		return false
	var seen := {}
	for id in tree.unlockedNodeIds:
		if not id is String or not nodes.has(id) or seen.has(id):
			last_error = "轮回树解锁记录无效"
			return false
		seen[id] = true
	return true


func _whole(value: Variant) -> bool:
	return (value is int or value is float) and float(value) == float(int(value))


func effect_value(tree: Dictionary, key: String) -> float:
	if not valid_tree(tree):
		return 0.0
	var nodes := source_nodes()
	var amount := 0.0
	for id in tree.unlockedNodeIds:
		var effect: Dictionary = nodes[id].effect
		if effect.get("key") == key:
			amount += float(effect.value)
	return amount


func path_mastery(state: Dictionary, path_id: String) -> int:
	var memories: Variant = state.get("legacyPathMemories", {})
	var tree: Variant = state.get("rebirthTree")
	if path_id.is_empty() or not memories is Dictionary \
			or not valid_tree(tree):
		return 0
	var own := int(memories.get(path_id, 0))
	var rate := minf(0.5, maxf(0.0, effect_value(tree,
		"crossPathMemoryRate")))
	var other := 0
	for id in memories:
		if id != path_id:
			other = maxi(other, int(memories[id]))
	return mini(5, own + int(floorf(other * rate)))


func unlock(state: Dictionary, node_id: String) -> Dictionary:
	var tree: Variant = state.get("rebirthTree")
	var nodes := source_nodes()
	if not valid_tree(tree) or not nodes.has(node_id) \
			or tree.unlockedNodeIds.has(node_id):
		return {}
	var node: Dictionary = nodes[node_id]
	for required in node.requires:
		if not tree.unlockedNodeIds.has(required):
			return {}
	var cost := maxi(0, int(node.cost))
	if int(tree.insight) < cost:
		return {}
	var result := state.duplicate(true)
	result.rebirthTree.insight -= cost
	result.rebirthTree.spentInsight += cost
	result.rebirthTree.unlockedNodeIds.append(node_id)
	if node.effect.get("channel") == "bonuses":
		var key: String = node.effect.key
		var bonuses: Dictionary = result.get("legacyBonuses", {})
		bonuses[key] = float(bonuses.get(key, 0)) + float(node.effect.value)
		result["legacyBonuses"] = bonuses
	return result


func refund(state: Dictionary, node_id: String) -> Dictionary:
	var tree: Variant = state.get("rebirthTree")
	var nodes := source_nodes()
	if not valid_tree(tree) or not nodes.has(node_id) \
			or not tree.unlockedNodeIds.has(node_id):
		return {}
	for id in tree.unlockedNodeIds:
		if nodes[id].get("requires", []).has(node_id):
			return {}
	var node: Dictionary = nodes[node_id]
	var cost := maxi(0, int(node.cost))
	var result := state.duplicate(true)
	result.rebirthTree.unlockedNodeIds.erase(node_id)
	result.rebirthTree.insight += cost
	result.rebirthTree.spentInsight = maxi(0, int(tree.spentInsight) - cost)
	if node.effect.get("channel") == "bonuses":
		var key: String = node.effect.key
		var bonuses: Dictionary = result.get("legacyBonuses", {})
		bonuses[key] = maxf(0.0, float(bonuses.get(key, 0)) \
			- float(node.effect.value))
		result["legacyBonuses"] = bonuses
	return result


func archive_life(terminal: Dictionary, complete_deeds: bool = true) -> Dictionary:
	var tree: Dictionary = terminal.get("rebirthTree", initial_tree())
	var lineage: Variant = terminal.get("lineageEntries", [])
	if not valid_tree(tree) or not lineage is Array:
		return {}
	var next_life := int(terminal.get("lifeCount", -1)) + 1
	var prior_entry: Dictionary = {}
	for row in lineage:
		if not row is Dictionary:
			return {}
		if int(row.get("life", -1)) == next_life:
			prior_entry = row
	var npc_source: Variant = _content.read_module("npcs:core")
	var companion_source: Variant = _content.read_module("companions:events")
	if not npc_source is Dictionary or not npc_source.get("npcs") is Array \
			or not companion_source is Dictionary \
			or not companion_source.get("companions") is Array:
		last_error = "谱系人物来源不可用"
		return {}
	var starts := {}
	for companion in companion_source.companions:
		if companion is Dictionary and companion.get("id") is String:
			starts[companion.id] = float(companion.get("startAffection", 0))
	var affection: Dictionary = terminal.get("npcAffection", {})
	var top_npc: Variant = null
	for npc in npc_source.npcs:
		if not npc is Dictionary or not npc.get("id") is String:
			return {}
		var id: String = npc.id
		var value := float(affection.get(id, maxf(float(npc.get(
			"startAffection", 0)), float(starts.get(id, 0)))))
		if top_npc == null or value > float(top_npc.affection):
			top_npc = {"id": id, "name": npc.get("name", id), "affection": value}
	var top_faction: Variant = null
	for id in terminal.get("factionProgress", {}).get("reputations", {}):
		var value := int(terminal.factionProgress.reputations[id])
		if top_faction == null or value > int(top_faction.reputation):
			top_faction = {"id": id, "reputation": value}
	var wins := 0
	var bosses := []
	for record in terminal.get("battleResultHistory", []):
		if not record is Dictionary or record.get("result", {}).get(
				"outcome") != "victory":
			continue
		wins += 1
		var combat: Dictionary = record.get("sourceCombat", {})
		if combat.get("enemy", {}).get("phases") is Array:
			bosses.append(String(combat.get("title", combat.get(
				"enemy", {}).get("name", "未知 Boss"))))
	var dungeons := 0
	for receipt in terminal.get("dungeonOutcomeReceipts", []):
		if receipt is Dictionary and receipt.get("outcome") == "success":
			dungeons += 1
	var routes := []
	var route_source: Variant = _content.read_module("world:trade_routes")
	if route_source is Dictionary:
		for route in route_source.get("routes", []):
			var history: Array = terminal.get("tradeRouteState", {}).get(
				"routes", {}).get(route.get("id"), {}).get("history", [])
			if not history.is_empty():
				routes.append(route.get("name", route.get("id")))
	var purchases: int = terminal.get("marketPurchaseHistory", []).size()
	if complete_deeds:
		for event in terminal.get("lastLessonVendorEventHistory", []):
			if event is Dictionary and event.get("kind") == "purchase":
				purchases += 1
	var deeds := {"combatsWon": wins, "bossesDefeated": bosses,
		"dungeonsCompleted": dungeons, "routesChanged": routes,
		"purchases": purchases}
	var entry := {"id": prior_entry.get("id", "life_%d" % next_life),
		"life": next_life, "name": terminal.get("playerName", "无名修士"),
		"path": terminal.get("path"), "pathName": terminal.get("path"),
		"archetype": null, "realm": terminal.get("realm", "qi"),
		"turn": terminal.get("turn", 0),
		"cause": terminal.get("deadReason", "主动轮回"),
		"deathCauseId": terminal.get("deathCauseId"),
		"endingId": terminal.get("endingId"), "ending": null,
		"archiveVersion": 1, "clues": terminal.get("clues", []).size(),
		"karma": {"good": terminal.get("attributes", {}).get("karmaGood", 0),
			"bad": terminal.get("attributes", {}).get("karmaBad", 0)},
		"topNpc": top_npc, "topFaction": top_faction,
		"activeRoute": _active_route_name(terminal, route_source) \
			if complete_deeds else null, "deeds": deeds}
	var realm_value := maxi(0, REALMS.find(entry.realm))
	var unique_bosses := {}
	for boss in bosses:
		unique_bosses[boss] = true
	var new_path := not String(entry.path).is_empty()
	for row in lineage:
		if row.get("life") != next_life and row.get("path") == entry.path:
			new_path = false
	var points := maxi(1, 2 + realm_value + mini(3, unique_bosses.size()) \
		+ mini(2, dungeons) + (1 if float(top_npc.affection) >= 80 else 0) \
		+ (1 if int(entry.clues) >= 3 else 0) + (1 if new_path else 0) \
		+ maxi(0, int(effect_value(tree, "lifeInsightBonus"))))
	entry["insightAwarded"] = int(prior_entry.get("insightAwarded", points))
	var result := {"rebirthTree": tree.duplicate(true),
		"lineageEntries": lineage.duplicate(true)}
	if prior_entry.is_empty():
		result.rebirthTree.insight += points
		result.lineageEntries.append(entry)
	else:
		for i in result.lineageEntries.size():
			if int(result.lineageEntries[i].get("life", -1)) == next_life:
				result.lineageEntries[i] = entry
	if result.lineageEntries.size() > 24:
		result.lineageEntries = result.lineageEntries.slice(
			result.lineageEntries.size() - 24)
	return result


func _active_route_name(terminal: Dictionary, source: Variant) -> Variant:
	var snapshot: Variant = terminal.get("tradeRouteState")
	if not source is Dictionary or not source.get("routes") is Array \
			or not snapshot is Dictionary or not snapshot.get("routes") is Dictionary:
		return null
	var location := String(terminal.get("currentLocation", ""))
	var matching: Array = []
	for route in source.routes:
		if route is Dictionary and (route.get("from") == location \
				or route.get("to") == location or location == "坊市"):
			matching.append(route)
	var pool: Array = matching if not matching.is_empty() else source.routes
	var best_name: Variant = null
	var best_score := -1000000
	for route in pool:
		if not route is Dictionary:
			return null
		var live: Variant = snapshot.routes.get(route.get("id"))
		if not live is Dictionary:
			return null
		var score := int(live.get("openness", 0)) + int(live.get(
			"prosperity", 0)) - int(live.get("danger", 0))
		if best_name == null or score > best_score:
			best_name = route.get("name")
			best_score = score
	return best_name
