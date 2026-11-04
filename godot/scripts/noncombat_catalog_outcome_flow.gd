extends RefCounted

# Source encounter outcomeLinks and delayed karma, applied at the battle return
# transaction before its decision clock advances.
const CompanionEvents = preload("res://scripts/noncombat_companion_events.gd")
const FactionEvents = preload("res://scripts/noncombat_faction_events.gd")
const REALM_DELAY := {"qi": 1.5, "foundation": 1.2, "golden": 1.0,
	"nascent": 0.8, "deity": 0.6, "tribulation": 0.5}

var last_error := ""
var _content: RefCounted


func _init(content: RefCounted) -> void:
	_content = content


func apply(candidate: Dictionary, source: Dictionary, choice: Dictionary,
		encounter: Dictionary, outcome: String, decision: int) -> bool:
	last_error = ""
	if outcome not in ["victory", "defeat", "flee"] or decision < 1:
		return _reject("来源战果或时钟无效")
	var direct_on: Variant = choice.get("karmaSeedOn", ["victory"])
	if not direct_on is Array:
		return _reject("遭遇直接因果结果集无效")
	if choice.has("karmaSeed") and direct_on.has(outcome):
		if not _plant_all(candidate, choice.karmaSeed, source, outcome, decision):
			return false
	var links: Variant = choice.get("combatOutcomeLinks", {})
	if not links is Dictionary:
		return _reject("遭遇结果联动无效")
	var link: Variant = links.get(outcome, {})
	if not link is Dictionary:
		return _reject("遭遇对应结果联动无效")
	for key in link:
		if key not in ["companionEffects", "factionEffects", "karmaSeed"]:
			return _reject("遭遇结果字段缺少消费者：" + String(key))
	if link.has("companionEffects"):
		var effect: Variant = link.companionEffects
		if not effect is Dictionary or not effect.get("compId") is String \
				or not candidate.get("companionProgress", {}).get(
					"states", {}).has(effect.compId):
			return _reject("遭遇道侣状态无效")
		for key in effect:
			if key not in ["compId", "affectionDelta", "bondDelta", "trustDelta"]:
				return _reject("遭遇道侣字段缺少消费者：" + String(key))
		var relation := {"text": choice.get("text", ""),
			"companionEffects": effect}
		if not CompanionEvents.new(_content)._apply_companion_effects(
				candidate, source, relation, "left", decision):
			return _reject("遭遇道侣战果未能结算")
	if link.has("factionEffects") and not _faction(candidate, link.factionEffects):
		return false
	if link.has("karmaSeed") and not _plant_all(candidate, link.karmaSeed,
			source, outcome, decision):
		return false
	if outcome == "victory" and encounter.get("enemy", {}).get("factionId") is String \
			and not String(encounter.enemy.factionId).is_empty():
		var enemy: Dictionary = encounter.enemy
		if not _plant_all(candidate, {"id": "combatGlory", "seedType": "karma",
			"delay": 6, "priority": maxi(2, int(enemy.get("tier", 1))),
			"context": {"enemyId": enemy.get("id"), "enemyName": enemy.get("name"),
				"factionId": enemy.factionId, "tier": int(enemy.get("tier", 1))}},
			source, outcome, decision):
			return false
	return true


func _faction(candidate: Dictionary, effect: Variant) -> bool:
	if not effect is Dictionary or effect.size() != 2 \
			or not effect.get("factionId") is String \
			or not _integer(effect.get("reputationDelta")) \
			or not FactionEvents.new(_content).valid(candidate):
		return _reject("遭遇势力结果无效")
	var faction_id := String(effect.factionId)
	var progress: Dictionary = candidate.factionProgress
	if not progress.get("reputations", {}).has(faction_id):
		return _reject("遭遇势力身份无效")
	var before := int(progress.reputations[faction_id])
	var after := clampi(before + int(effect.reputationDelta), -100, 100)
	progress.reputations[faction_id] = after
	if before != after:
		candidate["tradeRoutePendingEvents"] = candidate.get(
			"tradeRoutePendingEvents", []).duplicate(true)
		candidate.tradeRoutePendingEvents.append({"kind": "reputation",
			"factionId": faction_id, "oldValue": before, "newValue": after})
	return true


func _plant_all(candidate: Dictionary, raw: Variant, source: Dictionary,
		outcome: String, decision: int) -> bool:
	var specs: Array = raw if raw is Array else [raw]
	for raw_spec in specs:
		var spec: Variant = {"id": raw_spec, "seedType": "karma", "delay": 5,
			"priority": 1} if raw_spec is String else raw_spec
		if not spec is Dictionary or not _plant_one(candidate, spec, source,
				outcome, decision):
			return _reject("遭遇因果种子来源无效")
	return true


func _plant_one(candidate: Dictionary, spec: Dictionary, source: Dictionary,
		outcome: String, decision: int) -> bool:
	var seed_id := String(spec.get("id", ""))
	if not candidate.has("karmaSeeds"):
		candidate["karmaSeeds"] = []
	if not candidate.has("karmaPromiseFlags"):
		candidate["karmaPromiseFlags"] = {}
	if seed_id.is_empty() or not _integer(spec.get("delay", 5)) \
			or not _integer(spec.get("priority", 0)) \
			or not candidate.get("karmaSeeds") is Array \
			or not candidate.get("karmaPromiseFlags") is Dictionary:
		return false
	for key in spec:
		if key not in ["id", "seedType", "delay", "realm", "path", "priority",
				"description", "tags", "payoffEvent", "context", "mergeGroup",
				"cancelGroup"]:
			return false
	var seeds: Array = candidate.karmaSeeds
	for existing in seeds:
		if existing is Dictionary and existing.get("id") == seed_id:
			if int(spec.get("delay", 5)) < int(existing.get("delay", 0)):
				existing.delay = int(spec.get("delay", 5))
				existing.priority = maxi(int(existing.get("priority", 0)),
					int(spec.get("priority", 0)))
			if existing.get("context") == null and spec.get("context") is Dictionary:
				existing.context = spec.context.duplicate(true)
			if existing.get("originOutcome") == null:
				existing.originOutcome = outcome
			candidate.get_or_add("karmaPromiseFlags", {})[seed_id] = true
			return true
	var delay := maxi(1, roundi(int(spec.get("delay", 5)) * float(
		REALM_DELAY.get(String(candidate.get("realm", "qi")), 1.0))))
	var seed := {"id": seed_id, "seedType": spec.get("seedType", "karma"),
		"delay": delay, "realm": spec.get("realm"), "path": spec.get("path"),
		"priority": int(spec.get("priority", 0)), "originTurn": decision,
		"originLife": int(candidate.get("lifeCount", 0)),
		"originCard": source.get("id"), "originChoice": "left",
		"originThread": null, "originQuest": null, "originOutcome": outcome,
		"description": spec.get("description"), "tags": spec.get("tags", []),
		"payoffEvent": spec.get("payoffEvent"),
		"context": spec.get("context", null), "consumed": false,
		"mergeGroup": spec.get("mergeGroup"), "cancelGroup": spec.get("cancelGroup")}
	seeds.append(seed)
	candidate.get_or_add("karmaPromiseFlags", {})[seed_id] = true
	return true


func _integer(value: Variant) -> bool:
	return value is int or value is float and value == floorf(value)


func _reject(reason: String) -> bool:
	last_error = reason
	return false
