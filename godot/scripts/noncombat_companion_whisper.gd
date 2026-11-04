extends RefCounted

const CATALOG_PATH := "res://content/derived/companion_whispers.json"
const SOURCE_SHA := "4c3035245f1ecc2e16ab0a0cce8103222234384e4fe8b18ca09d5b24409df3c6"
const UI_SOURCE_SHA := "82ae0a82c1568b722992bdccc2078be99c5291887b021634cd170ff222053e29"
const CATALOG_SHA := "ac216d169226be7d03e983fa7a040899238be102fa47da69ed1374ab0fa846ae"


func npc_portrait_path(comp_id: String) -> String:
	var catalog := _catalog()
	if catalog.is_empty():
		return ""
	return String(catalog.npcPortraitMap.get(comp_id,
		"assets/characters/concept_bai_luoxuan.webp"))


func reaction(run: Dictionary, card: Dictionary, direction: String) -> Dictionary:
	if card.is_empty() or not card.get("choices") is Dictionary \
			or not card.choices.get(direction) is Dictionary:
		return {}
	var active := active_companion(run)
	if active.is_empty():
		return {}
	var catalog := _catalog()
	if catalog.is_empty():
		return {}
	var event_type := _event_type(card, direction)
	var lines: Variant = catalog.reactions.get(active.id, {}).get(event_type, [])
	if not lines is Array or lines.is_empty():
		return {}
	var affection := int(active.affection)
	var tier := 0 if affection < 40 else 1 if affection < 70 else 2
	var line: Variant = lines[mini(tier, lines.size() - 1)]
	return {"companionId": active.id, "affection": affection,
		"eventType": event_type, "text": line} if line is String \
		and not line.is_empty() else {}


func greeting(run: Dictionary) -> Dictionary:
	var active := active_companion(run)
	if active.is_empty():
		return {}
	var catalog := _catalog()
	if catalog.is_empty():
		return {}
	var lines: Variant = catalog.greetings.get(active.id, ["……", "……", "……"])
	if not lines is Array or lines.size() < 3:
		return {}
	return {"companionId": active.id, "affection": active.affection,
		"text": lines[_tier(int(active.affection))]}


func idle_lines(run: Dictionary) -> Array:
	var active := active_companion(run)
	if active.is_empty():
		return []
	var catalog := _catalog()
	if catalog.is_empty():
		return []
	var tiers: Variant = catalog.idleLines.get(active.id,
		[["……"], ["……"], ["……"]])
	if not tiers is Array or tiers.size() < 3:
		return []
	var lines: Variant = tiers[_tier(int(active.affection))]
	return lines if lines is Array else []


func active_companion(run: Dictionary) -> Dictionary:
	var owned: Variant = run.get("resources", {}).get("companions", [])
	var states: Variant = run.get("companionProgress", {}).get("states", {})
	var affections: Variant = run.get("npcAffection", {})
	if not owned is Array or not states is Dictionary \
			or not affections is Dictionary:
		return {}
	var best := {}
	var best_affection := -1
	for comp_id in owned:
		if comp_id is String and states.has(comp_id) \
				and affections.has(comp_id) and int(affections[comp_id]) > best_affection:
			best_affection = int(affections[comp_id])
			best = {"id": comp_id, "affection": best_affection}
	return best


func _catalog() -> Dictionary:
	if FileAccess.get_sha256(CATALOG_PATH).to_lower() != CATALOG_SHA:
		return {}
	var catalog: Variant = JSON.parse_string(FileAccess.get_file_as_string(CATALOG_PATH))
	return catalog if catalog is Dictionary \
		and catalog.get("sourceSha256") == SOURCE_SHA \
		and catalog.get("uiSourceSha256") == UI_SOURCE_SHA \
		and catalog.get("reactions") is Dictionary \
		and catalog.get("greetings") is Dictionary \
		and catalog.get("idleLines") is Dictionary \
		and catalog.get("npcPortraitMap") is Dictionary else {}


func _tier(affection: int) -> int:
	return 0 if affection < 40 else 1 if affection < 70 else 2


func _event_type(card: Dictionary, direction: String) -> String:
	var choice: Dictionary = card.choices.get(direction, {})
	var effects: Dictionary = choice.get("effects", {})
	if int(effects.get("health", 0)) < -20 \
			or card.get("tags", []).has("death") or card.get("type") == "DEATH":
		return "death_near"
	if int(effects.get("health", 0)) > 0 or effects.get("heal", false):
		return "heal"
	if int(effects.get("cultivation", 0)) > 0 or int(effects.get("exp", 0)) > 0:
		return "cultivate"
	if int(effects.get("karmaBad", 0)) > 0:
		return "karma_bad"
	if int(effects.get("karmaGood", 0)) > 10:
		return "save"
	if absi(int(effects.get("daoHeart", 0))) >= 10:
		return "dao_heart_gain"
	if int(effects.get("daoHeart", 0)) > 0:
		return "save"
	if card.get("type") == "BREAKTHROUGH" or card.get("tags", []).has("breakthrough"):
		return "breakthrough"
	return "neutral"
