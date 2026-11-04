extends RefCounted

const Repository = preload("res://scripts/noncombat_content_repository.gd")
const WorldPulse = preload("res://scripts/noncombat_world_pulse.gd")
const MODULE := "world:world_map"
const NPC_MODULE := "npcs:core"
const TRADE_MODULE := "world:trade_routes"
const FACTION_MODULE := "world:factions"
const REALMS := ["qi", "foundation", "golden", "nascent", "deity", "tribulation", "ascension"]

var last_error := ""
var _content: RefCounted


func _init(content: RefCounted = null) -> void:
	_content = content if content != null else Repository.new()


func project(state: Dictionary, current_card: Dictionary = {}) -> Dictionary:
	last_error = ""
	var source: Variant = _content.read_module(MODULE)
	var source_sha: String = _content.source_sha256(MODULE)
	if not source is Dictionary or source_sha.length() != 64 \
			or not source.get("nodes") is Array or not source.get("routes") is Array \
			or not source.get("chronicles") is Array:
		last_error = "世界地图来源不可用"
		return {}
	var nodes_by_id := {}
	for raw in source.nodes:
		if not raw is Dictionary or not raw.get("id") is String \
				or nodes_by_id.has(raw.id):
			last_error = "世界地图地点目录无效"
			return {}
		nodes_by_id[raw.id] = raw
	var current_id := _node_for_location(source.nodes,
		String(state.get("currentLocation", "宗门")))
	if current_id.is_empty():
		current_id = "sect"
	var active_quests := {}
	for quest in state.get("questState", {}).get("activeQuests", []):
		if quest is Dictionary:
			active_quests[String(quest.get("questId", ""))] = true
	var closed_quests: Array = state.get("questState", {}).get("completedQuests", [])
	var active_threads := {}
	var completed_threads := {}
	for thread_id in state.get("storyThreadState", {}).get("threads", {}):
		var thread: Variant = state.storyThreadState.threads[thread_id]
		if not thread is Dictionary:
			continue
		if thread.get("status") == "active":
			active_threads[thread_id] = true
		elif thread.get("status") == "completed":
			completed_threads[thread_id] = true
	var active_nodes := {}
	var active_quest_nodes := {}
	for quest_id in active_quests:
		var bound := String(source.get("questBindings", {}).get(quest_id, ""))
		if not bound.is_empty():
			active_nodes[bound] = true
			active_quest_nodes[bound] = true
	for thread_id in active_threads:
		var bound := String(source.get("threadBindings", {}).get(thread_id, ""))
		if not bound.is_empty():
			active_nodes[bound] = true
	var visited: Array = state.get("visitedLocations", [])
	var nodes := []
	for raw in source.nodes:
		var accessible := _realm_index(String(state.get("realm", "qi"))) >= \
			_realm_index(String(raw.get("minRealm", "qi")))
		var discovered: bool = accessible or visited.has(raw.get("playLocation")) \
			or active_nodes.has(raw.id)
		var row: Dictionary = raw.duplicate(true)
		row["discovered"] = discovered
		row["current"] = raw.id == current_id
		row["visited"] = visited.has(raw.get("playLocation"))
		row["displayName"] = String(raw.get("shortName", raw.id)) if discovered else "雾中地"
		row["summary"] = String(raw.get("summary", "")) if accessible \
			or row.current else "此地仍在命书迷雾之外。"
		nodes.append(row)
	var trade_doc: Variant = _content.read_module(TRADE_MODULE)
	var trade_sha: String = _content.source_sha256(TRADE_MODULE)
	if not trade_doc is Dictionary or trade_sha.length() != 64:
		last_error = "世界地图商路目录不可用"
		return {}
	var trade_definitions := {}
	for definition in trade_doc.get("routes", []):
		if definition is Dictionary:
			trade_definitions[definition.get("id")] = definition
	var dynamic_routes: Dictionary = state.get("tradeRouteState", {}).get("routes", {})
	var factions: Variant = _content.read_module(FACTION_MODULE)
	var faction_sha: String = _content.source_sha256(FACTION_MODULE)
	if not factions is Dictionary or faction_sha.length() != 64:
		last_error = "世界地图势力目录不可用"
		return {}
	var faction_names := {}
	var faction_definitions := {}
	for faction in factions.get("factions", []):
		if faction is Dictionary:
			var faction_id := String(faction.get("id", ""))
			faction_names[faction_id] = String(faction.get("name", faction_id))
			faction_definitions[faction_id] = faction
	var progress: Dictionary = state.get("factionProgress", {})
	var reputations: Dictionary = progress.get("reputations", {})
	var undercurrent_stages: Dictionary = progress.get("undercurrentStages", {})
	for node in nodes:
		node["factionNames"] = []
		node["factionDetails"] = []
		if node.discovered:
			for faction_id in node.get("factions", []):
				node.factionNames.append(faction_names.get(String(faction_id),
					String(faction_id)))
				var definition: Dictionary = faction_definitions.get(String(faction_id), {})
				if definition.is_empty():
					continue
				var undercurrent_id := String(definition.get("undercurrentId", ""))
				var undercurrent: Dictionary = factions.get("undercurrents", {}).get(
					undercurrent_id, {})
				var stage := int(undercurrent_stages.get(undercurrent_id,
					undercurrent.get("stage", 0)))
				var subfactions := []
				for sub in definition.get("subfactions", []):
					if sub is Dictionary:
						var sub_rep := int(reputations.get(sub.get("id"),
							sub.get("startReputation", 0)))
						subfactions.append({"name": sub.get("name", ""),
							"reputation": sub_rep, "level": _reputation_level(sub_rep)})
				var reputation := int(reputations.get(faction_id,
					definition.get("startReputation", 0)))
				node.factionDetails.append({"id": faction_id,
					"name": faction_names[String(faction_id)],
					"reputation": reputation, "level": _reputation_level(reputation),
					"undercurrentName": undercurrent.get("name", ""),
					"undercurrentStage": stage,
					"undercurrentText": undercurrent.get("stages", {}).get(
						str(stage), ""), "subfactions": subfactions})
	var routes := []
	for raw in source.routes:
		if not raw is Dictionary or not nodes_by_id.has(raw.get("from")) \
				or not nodes_by_id.has(raw.get("to")):
			last_error = "世界地图路线引用无效"
			return {}
		var row: Dictionary = raw.duplicate(true)
		var locked := _realm_index(String(state.get("realm", "qi"))) < maxi(
			_realm_index(String(nodes_by_id[raw["from"]].get("minRealm", "qi"))),
			_realm_index(String(nodes_by_id[raw["to"]].get("minRealm", "qi"))))
		var trade_definition: Dictionary = trade_definitions.get(raw.id, {})
		var runtime: Dictionary = dynamic_routes.get(raw.id,
			trade_definition.get("initial", {}))
		row["locked"] = locked
		row["name"] = trade_definition.get("name", raw.get("name", raw.id))
		row["openness"] = runtime.get("openness")
		row["danger"] = runtime.get("danger")
		row["prosperity"] = runtime.get("prosperity")
		row["condition"] = "locked" if locked else "danger" if int(runtime.get(
			"danger", 70 if raw.get("type") == "rumor" else 35)) >= 65 \
			else "prosperous" if int(runtime.get("prosperity", 0)) >= 65 else "open"
		routes.append(row)
	var chronicles := []
	for raw in source.chronicles:
		if not raw is Dictionary or not nodes_by_id.has(raw.get("node")):
			last_error = "世界地图纪事引用无效"
			return {}
		var row: Dictionary = raw.duplicate(true)
		var chronicle_id := String(raw.get("id", ""))
		var chronicle_state := "available"
		if active_quests.has(chronicle_id) or active_threads.has(chronicle_id):
			chronicle_state = "active"
		elif closed_quests.has(chronicle_id) or completed_threads.has(chronicle_id):
			chronicle_state = "resolved"
		elif _realm_index(String(state.get("realm", "qi"))) < _realm_index(
			String(raw.get("minRealm", "qi"))) or raw.has("path") and \
			String(raw.path) != String(state.get("path", "")):
			chronicle_state = "locked"
		elif raw.get("kind") == "world" and int(state.get("factionProgress", {}).get(
			"undercurrentStages", {}).get(chronicle_id, factions.get(
			"undercurrents", {}).get(chronicle_id, {}).get("stage", 0))) > 0:
			chronicle_state = "active"
		elif raw.get("kind") == "truth" and state.get("clues", []).size() >= 2:
			chronicle_state = "active"
		row["state"] = chronicle_state
		chronicles.append(row)
	var npcs := []
	var npc_doc: Variant = _content.read_module(NPC_MODULE)
	var npc_sha: String = _content.source_sha256(NPC_MODULE)
	if not npc_doc is Dictionary or npc_sha.length() != 64:
		last_error = "世界地图人物目录不可用"
		return {}
	for raw in npc_doc.get("npcs", []):
		var npc_id := String(raw.get("id", ""))
		if not source.get("characterBindings", {}).has(npc_id):
			continue
		var continuity: Variant = state.get("worldContinuityState")
		var live: Dictionary = continuity.get("npcs", {}).get(npc_id, {}) \
			if continuity is Dictionary else {"manifestation": "PHYSICAL",
				"locationId": raw.get("defaultLocation", "宗门")}
		if live.get("manifestation") != "PHYSICAL":
			continue
		var known: bool = raw.get("appearRealms", []).has(state.get("realm")) \
			or int(state.get("npcAffection", {}).get(npc_id, raw.get(
				"startAffection", 0))) > int(raw.get("startAffection", 0)) \
			or active_quest_nodes.has(String(source.characterBindings[npc_id].get(
				"homeNode", "")))
		if not known:
			continue
		var binding: Dictionary = source.characterBindings[npc_id]
		var period: String = ["子时", "寅时", "辰时", "午时", "申时", "戌时"][
			int(state.get("turn", 0)) / 6 % 6]
		var location := String(raw.get("schedule", {}).get(period,
			live.get("locationId", raw.get("defaultLocation", ""))))
		var node_id := _node_for_location(source.nodes, location)
		if node_id.is_empty():
			node_id = String(binding.get("homeNode", ""))
		if nodes_by_id.has(node_id):
			var emotion := String(state.get("npcEncounterScheduling", {}).get(
				"emotions", {}).get(npc_id, raw.get("defaultEmotion", "平静")))
			npcs.append({"id": npc_id, "name": raw.get("name", npc_id),
				"nodeId": node_id, "location": location,
				"emotion": emotion, "portrait": binding.get("portrait", "")})
	return {"title": source.get("title", "山河命卷"), "sourceSha": source_sha,
		"currentNodeId": current_id, "currentCardTitle": current_card.get("title", ""),
		"realm": state.get("realm", "qi"), "turn": state.get("turn", 0),
		"worldPulse": WorldPulse.project(state.get("worldPulseState"),
			String(state.get("currentLocation", "宗门"))),
		"nodes": nodes, "routes": routes, "chronicles": chronicles, "characters": npcs}


func _node_for_location(nodes: Array, location: String) -> String:
	if location.is_empty():
		return ""
	for node in nodes:
		if node.get("playLocation") == location:
			return String(node.id)
	var selected := ""
	var score := -1
	for node in nodes:
		for alias in node.get("aliases", []):
			var phrase := String(alias)
			if not location.contains(phrase):
				continue
			var specificity := phrase.length() + (100 if location.ends_with(
				phrase) else 0) + (8 if node.get("kind") == "landmark" else 0)
			if specificity > score:
				score = specificity
				selected = String(node.id)
	return selected


func _realm_index(realm: String) -> int:
	return REALMS.find(realm)


func _reputation_level(reputation: int) -> String:
	if reputation >= 80: return "崇敬"
	if reputation >= 50: return "尊敬"
	if reputation >= 20: return "友善"
	if reputation >= 0: return "中立"
	if reputation >= -20: return "冷淡"
	if reputation >= -50: return "敌视"
	return "仇恨"
