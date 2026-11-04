extends RefCounted

# Source-backed current-life NPC registry for authored lifecycle choices.
# Mirrors WorldContinuityStore.exportState and its terminal transition rules.
const CORE_NPCS := "npcs:core"


static func initial(content: RefCounted, life_count: int = 0) -> Dictionary:
	var source_sha: String = content.source_sha256(CORE_NPCS)
	var source: Variant = content.read_module(CORE_NPCS)
	if life_count < 0 or source_sha.length() != 64 or not source is Dictionary \
			or not source.get("npcs") is Array:
		return {}
	var registry := {"version": 1, "lifeId": life_count, "revision": 0, "npcs": {}}
	for raw in source["npcs"]:
		if not raw is Dictionary or not raw.get("id") is String:
			return {}
		var npc_id := String(raw["id"])
		if npc_id.is_empty() or registry["npcs"].has(npc_id):
			return {}
		registry["revision"] += 1
		registry["npcs"][npc_id] = {"npcId": npc_id, "lifeId": life_count,
			"lifecycle": "ACTIVE", "manifestation": "PHYSICAL",
			"locationId": raw.get("defaultLocation", "宗门"),
			"factionId": raw.get("factionId"),
			"changedByNode": "npc_registered", "changedAtTurn": 0,
			"reason": "initial_presence", "revision": registry["revision"]}
	return {"sourceSha": source_sha, "state": registry}


static func transition_dead(target: Dictionary, effect: Dictionary,
		card_id: String, base_turn: int) -> bool:
	if effect.get("lifecycle") != "DEAD" or effect.get("npcId") != "bai_luoxuan" \
			or effect.get("reason") != card_id + "_left":
		return false
	var registry: Variant = target.get("worldContinuityState")
	if not registry is Dictionary or registry.get("version") != 1 \
			or int(registry.get("lifeId", -1)) != int(target.get("lifeCount", 0)):
		return false
	var npcs: Dictionary = registry.get("npcs", {})
	var prior: Dictionary = npcs.get(effect["npcId"], {})
	if prior.get("lifecycle") != "ACTIVE" or prior.get("manifestation") != "PHYSICAL":
		return false
	registry["revision"] = int(registry["revision"]) + 1
	prior["lifecycle"] = "DEAD"
	prior["manifestation"] = "ECHO_ONLY"
	prior["locationId"] = null
	prior["changedByNode"] = card_id
	prior["changedAtTurn"] = base_turn
	prior["reason"] = effect["reason"]
	prior["revision"] = registry["revision"]
	npcs[effect["npcId"]] = prior
	registry["npcs"] = npcs
	target["worldContinuityState"] = registry
	return true


static func transition_ascended(target: Dictionary, effect: Dictionary,
		base_turn: int) -> bool:
	if effect.get("npcId") != "bai_ren" or effect.get("lifecycle") != "ASCENDED" \
			or effect.get("manifestation") != "ECHO_ONLY" \
			or not (effect.get("changedByNode") == "ll_heaven_gate_farewell" \
				and effect.get("reason") == "entered_heaven_gate" \
				or effect.get("changedByNode") == "mentor_bai_ren_destiny" \
				and effect.get("locationId") == "upper_realm_heaven_gate"):
		return false
	var registry: Variant = target.get("worldContinuityState")
	if not registry is Dictionary or registry.get("version") != 1 \
			or int(registry.get("lifeId", -1)) != int(target.get("lifeCount", 0)):
		return false
	var npcs: Dictionary = registry.get("npcs", {})
	var prior: Dictionary = npcs.get("bai_ren", {})
	if prior.get("npcId") != "bai_ren" or prior.get("lifeId") != registry.get("lifeId"):
		return false
	if prior.get("lifecycle") == "ASCENDED" and prior.get("manifestation") == "ECHO_ONLY":
		return true
	if prior.get("lifecycle") != "ACTIVE" and prior.get("lifecycle") != "DISTANT":
		return false
	registry["revision"] = int(registry["revision"]) + 1
	prior["lifecycle"] = "ASCENDED"
	prior["manifestation"] = "ECHO_ONLY"
	prior["locationId"] = effect.get("locationId")
	prior["changedByNode"] = effect["changedByNode"]
	prior["changedAtTurn"] = base_turn
	prior["reason"] = effect.get("reason", "mentor_bai_ren_destiny")
	prior["revision"] = registry["revision"]
	npcs["bai_ren"] = prior
	registry["npcs"] = npcs
	target["worldContinuityState"] = registry
	return true
