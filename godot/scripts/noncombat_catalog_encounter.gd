extends RefCounted

# CardSystem's catalog projection and normal-draw eligibility. Scheduling,
# acceptance, settlement and persistence belong to the encounter director.
const Repository = preload("res://scripts/noncombat_content_repository.gd")
const PREFIX := "encounter_card_"
const MODULES := ["combat:encounters", "combat:encounter_presentations",
	"combat:encounter_director", "combat:migrated_presentations", "cards:battle_cards"]
const RULE_PINS := {
	"src/systems/CardSystem.js": "12f99d576b413313b36c9b6b2e3d0c23a56f9eff4793f0c9737c6dc5cb2e1c5f",
	"src/coordinators/CombatCoordinator.js": "a834065e633d44a9ef6a3a117ad9aee3291b0daa8abad672c20f38b2b11993b0",
	"src/systems/NarrativeLedger.js": "485c6d61b335db1a418900a552d3b001aea66348b8ba02ef8b82111264c9e20a",
	"src/core/GameStateManager.js": "75e60d10e3284f96715c1ce9229c211215190a39eb10f920e0bb10187b741080",
}
const ROLES := {"archetypeTrial": "ordinary", "realmPatrol": "ordinary",
	"factionElite": "elite", "companionQuest": "relationship", "heavenChaos": "quest",
	"realmQuotaOrdinary": "ordinary", "realmQuest": "quest", "realmElite": "elite", "realmBoss": "boss"}
const WEIGHTS := {"realmBoss": 1, "archetypeTrial": 2, "factionElite": 1,
	"companionQuest": 2, "heavenChaos": 1, "realmQuotaOrdinary": 1, "realmQuest": 1, "realmElite": 1}
var last_error := ""
var source_error := ""
var _content: RefCounted


func _init(content: RefCounted = null) -> void:
	_content = content if content != null else Repository.new()


func source_rule_pins() -> Dictionary:
	return RULE_PINS.duplicate()


func source_hashes() -> Dictionary:
	last_error = ""
	source_error = ""
	var hashes := {}
	for module_id in MODULES:
		var sha := String(_content.source_sha256(module_id))
		if sha.length() != 64:
			last_error = "遭遇目录来源数据未通过校验：" + module_id
			var path := String(_content.module_path(module_id))
			source_error = "SOURCE_UNAVAILABLE" if path.is_empty() \
				or not FileAccess.file_exists(Repository.CONTENT_ROOT + path) else "SOURCE_MISMATCH"
			return {}
		hashes[module_id] = sha
	return hashes


func candidates(state: Dictionary) -> Array:
	var result: Array = []
	var realm := String(state.get("realm", ""))
	if realm not in ["qi", "foundation", "golden", "nascent", "deity", "tribulation"] \
			or source_hashes().is_empty():
		return result
	for raw in _document("combat:encounters").get("encounters", []):
		if not raw is Dictionary or raw.get("realm") != realm or _is_boss(raw):
			continue
		var current := _build_card(raw, String(state.get("path", "")))
		if not current.is_empty() and eligible(state, current):
			result.append(current)
	return result


func card(state: Dictionary, source_id: String = "") -> Dictionary:
	# Static source access remains valid after this once-only card is resolved.
	# Only candidates() applies live eligibility and neither API filters cadence.
	if source_hashes().is_empty():
		return {}
	var id := source_id if not source_id.is_empty() else String(state.get("currentCardId", ""))
	if not id.begins_with(PREFIX):
		return {}
	for raw in _document("combat:encounters").get("encounters", []):
		if raw is Dictionary and raw.get("id") == id.trim_prefix(PREFIX) \
				and raw.get("realm") == state.get("realm") and not _is_boss(raw):
			return _build_card(raw, String(state.get("path", "")))
	return {}


func encounter(state: Dictionary, encounter_id: String) -> Dictionary:
	var source := card(state, PREFIX + encounter_id)
	if source.is_empty():
		return {}
	for raw in _document("combat:encounters").get("encounters", []):
		if raw is Dictionary and raw.get("id") == encounter_id:
			var result: Dictionary = raw.duplicate(true)
			var choice: Dictionary = source.choices.left
			for key in ["enemy", "battlefield", "combatPresentation", "defeatHealthLoss"]:
				result[key] = _copy(choice[key])
			return result
	return {}


func resolution(state: Dictionary, source_id: String) -> Dictionary:
	var source := card(state, source_id)
	if source.is_empty():
		return {}
	var choice: Dictionary = source.choices.left.duplicate(true)
	var combat := source.duplicate(true)
	combat.merge({"encounterId": choice.encounterId, "encounterKind": choice.encounterKind,
		"enemy": choice.enemy.duplicate(true), "battlefield": choice.battlefield,
		"defeatHealthLoss": choice.defeatHealthLoss, "combatRules": {}}, true)
	var presentation: Dictionary = source.combatPresentation.duplicate(true)
	presentation.merge(choice.combatPresentation, true)
	combat["combatPresentation"] = presentation
	return {"sourceCardId": source.id, "direction": "left", "sourceCard": source,
		"choice": choice, "combatCard": combat}


func eligible(state: Dictionary, source: Dictionary) -> bool:
	# The catalog builder does not emit narrative NPC/location/prerequisite
	# fields. Its repeat policy is once or unrestricted, as in NarrativeLedger.
	if source.is_empty() or float(source.get("weight", 0)) <= 0 \
			or not is_finite(float(source.get("weight", 0))) \
			or source.get("realm") != state.get("realm") \
			or _truthy(state.get("flags", {}).get("post_ascension_active")):
		return false
	var path: Variant = source.get("path")
	var paths: Array = path if path is Array else ([path.strip_edges()] if path is String and not path.strip_edges().is_empty() else [])
	if not paths.is_empty() and not paths.has(state.get("path")):
		return false
	if _truthy(source.get("requiredCompanion")) and not state.get("resources", {}).get(
			"companions", []).has(source.requiredCompanion):
		return false
	if source.get("once") == true:
		var ledger: Variant = state.get("narrativeLedgerState")
		var entries: Dictionary = ledger.get("entries", {}) if ledger is Dictionary else {}
		if state.get("cardsPlayed", []).has(source.id):
			return false
		if float(entries.get("card:" + source.id, {}).get("resolvedCount", 0)) > 0:
			return false
		# Bounded projection of the migrated COMBAT card:chosen boundary:
		# committed source choices have replay-verified run-clock receipts,
		# including avoidance, which deliberately does not write cardsPlayed.
		# The complete NarrativeLedger producer remains outside this slice.
		for receipt in state.get("runClock", {}).get("receipts", {}).values():
			if receipt is Dictionary and receipt.get("kind") == "choice" \
					and receipt.get("sourceCardId") == source.id:
				return false
	var flags: Dictionary = state.get("flags", {})
	var required: Variant = source.get("requiresFlags")
	if required is Dictionary:
		for key in required:
			if required[key] == null:
				if not flags.has(key):
					return false
			elif flags.get(key) != required[key]:
				return false
	var any: Variant = source.get("requiresAnyFlags")
	if any is Array and not any.is_empty():
		var found := false
		for key in any:
			found = found or _truthy(flags.get(key))
		if not found:
			return false
	var forbidden: Variant = source.get("forbiddenFlags")
	if forbidden is Dictionary:
		for key in forbidden:
			if _truthy(flags.get(key)) if forbidden[key] == null else flags.get(key) == forbidden[key]:
				return false
	return true


func _build_card(raw: Dictionary, path_id: String) -> Dictionary:
	var entry := raw.duplicate(true)
	var presentation: Dictionary = entry.get("combatPresentation", {}).duplicate(true)
	presentation.merge(_document("combat:encounter_presentations").get("presentations", {}).get(entry.id, {}), true)
	entry["combatPresentation"] = presentation
	var enemy := balanced_enemy(entry, path_id)
	if enemy.is_empty():
		return {}
	var kind: String = _or(entry.get("encounterKind"), "realm_boss" if entry.get("category") == "realmBoss" else "ordinary")
	var tier := int(entry.enemy.get("tier", 1))
	var loss: Variant = _document("combat:encounters").get("defeatHealthLossByTier", {}).get(str(tier), tier)
	var choice := {"text": _or(entry.get("challengeText"), "迎战·" + entry.enemy.name),
		"desc": _or(entry.get("mechanic"), "进入战斗；胜败与撤离会分别结算。"),
		"encounterId": entry.id, "encounterKind": kind, "triggerCombat": true,
		"enemy": enemy, "battlefield": _or(presentation.get("battlefield"), _or(entry.get("battlefield"), null)),
		"combatPresentation": presentation.duplicate(true),
		"victoryEffects": _copy(_or(entry.get("victoryEffects"), {})),
		"defeatHealthLoss": _or(entry.get("defeatHealthLoss"), loss),
		"combatRewards": _copy(_or(entry.get("victoryEffects"), {})),
		"combatOutcomeLinks": _copy(_or(entry.get("outcomeLinks"), {}))}
	for key in ["defeatEffects", "fleeEffects", "karmaSeed", "karmaSeedOn"]:
		if entry.has(key):
			choice[key] = _copy(entry[key])
	if _truthy(entry.get("combatOutcomePresentation")):
		choice["combatOutcomePresentation"] = _copy(entry.combatOutcomePresentation)
	var avoid: Dictionary = entry.get("avoid", {})
	var has_cost := false
	for value in avoid.get("effects", {}).values():
		if (value is int or value is float) and value < 0:
			has_cost = true
	for value in avoid.get("costCheck", {}).values():
		if float(value) > 0:
			has_cost = true
	var narrative: Variant = avoid.get("narrativeBlock")
	if not _truthy(narrative):
		narrative = null if has_cost else "%s %s" % [
			_or(avoid.get("desc"), "你没有立刻迎战%s。" % entry.enemy.name),
			_or(entry.get("worldStory"), _or(entry.get("mechanic"), "你记下敌手的路数，准备在下一次相逢时给出答案。"))]
	var right := {"text": _or(avoid.get("text"), "避开此战"),
		"desc": _or(avoid.get("desc"), "保留当前状态，不触发本场战斗的结果联动。"),
		"effects": _copy(_or(avoid.get("effects"), {})), "narrativeBlock": narrative}
	if avoid.has("costCheck"):
		right["costCheck"] = _copy(avoid.costCheck)
	var result := {"id": PREFIX + entry.id, "encounterId": entry.id, "encounterKind": kind,
		"encounterRole": _or(entry.get("encounterRole"), ROLES.get(entry.get("category"), "ordinary")),
		"teachingEncounter": entry.get("teachingEncounter") == true,
		"narrativeSource": _or(entry.get("narrativeSource"), "encounter_catalog:%s:%s" % [entry.get("category", ""), entry.id]),
		"originThreadId": _or(entry.get("originThreadId"), null), "originNodeId": _or(entry.get("originNodeId"), null),
		"title": entry.title, "description": entry.description, "type": "COMBAT", "realm": entry.realm,
		"path": _or(entry.get("path"), null), "weight": entry.get("weight", WEIGHTS.get(entry.get("category"), 1)),
		"once": entry.get("once") != false, "category": entry.category,
		"requiredCompanion": _or(entry.get("requiredCompanion"), null),
		"requiresFlags": _copy(_or(entry.get("requiresFlags"), null)),
		"requiresAnyFlags": _copy(entry.get("requiresAnyFlags")) if entry.get("requiresAnyFlags") is Array else null,
		"forbiddenFlags": _copy(_or(entry.get("forbiddenFlags"), null)),
		"mechanic": _or(entry.get("mechanic"), ""), "worldStory": _or(entry.get("worldStory"), ""),
		"tags": ["combat", "encounter", entry.category],
		"sceneImage": _or(presentation.get("sceneImage"), _or(entry.get("sceneImage"), null)),
		"combatPresentation": presentation.duplicate(true), "choices": {"left": choice, "right": right}}
	# hydrateCombatCardPresentation is a second source-owned presentation pass.
	var overlays: Dictionary = _document("combat:migrated_presentations").get("presentations", {})
	for direction in ["left", "right", "up", "down"]:
		var overlay: Variant = overlays.get(result.id + ":" + direction)
		if overlay is Dictionary and result.choices.has(direction):
			var target: Dictionary = result.choices[direction]
			var merged: Dictionary = target.get("combatPresentation", {}).duplicate(true)
			merged.merge(overlay, true)
			target["combatPresentation"] = merged
			for key in ["battlefield", "sceneImage"]:
				if overlay.has(key):
					target[key] = overlay[key]
				else:
					target.erase(key)
			if not _truthy(result.get("sceneImage")) and overlay.has("sceneImage"):
				result["sceneImage"] = overlay.sceneImage
	return result


func balanced_enemy(entry: Dictionary, path_id: String) -> Dictionary:
	# CardSystem._withEncounterPlanGraph, including template-preserving zero
	# deltas and the generic graph used by authored catalog enemies.
	var enemy: Dictionary = entry.get("enemy", {}).duplicate(true)
	if enemy.is_empty() or _is_boss(entry):
		return enemy
	var role: String = _or(entry.get("encounterRole"), ROLES.get(entry.get("category"),
		"elite" if int(enemy.get("tier", 1)) >= 2 else "ordinary"))
	var micro: Dictionary = _document("combat:encounter_director").get("roleMicroBalance", {})
	var attack_delta := 0
	if not (micro.get("excludeTeaching") == true and entry.get("teachingEncounter") == true):
		var role_key := "elite" if role == "elite" else ("ordinary" if role == "ordinary" else "defaultNonBoss")
		var path_rules: Dictionary = micro.get("pathOverrides", {}).get(path_id, {})
		var rule: Dictionary = path_rules.get("realmOverrides", {}).get(entry.get("realm"), {}).get(
			role_key, path_rules.get(role_key, micro.get(role_key, {})))
		var hp_delta := floori(float(rule.get("enemyHpDelta", 0)))
		attack_delta = floori(float(rule.get("enemyAtkDelta", 0)))
		if hp_delta != 0:
			enemy["hp"] = maxi(1, floori(float(_or(enemy.get("hp"), 1))) + hp_delta)
			if enemy.has("maxHp"):
				enemy["maxHp"] = maxi(enemy.hp, floori(float(enemy.maxHp)) + hp_delta)
		if attack_delta != 0:
			enemy["atk"] = maxi(1, floori(float(_or(enemy.get("atk"), _or(enemy.get("tier"), 1)))) + attack_delta)
			for intent in enemy.get("intents", []):
				_adjust_attack_intent(intent, attack_delta)
	if enemy.get("planGraph") is Dictionary:
		_adjust_attack_graph(enemy.planGraph, attack_delta)
		return enemy
	for template in _document("cards:battle_cards").get("enemies", []):
		if template is Dictionary and template.get("id") == enemy.get("templateId") and template.get("planGraph") is Dictionary:
			if attack_delta != 0:
				enemy["planGraph"] = template.planGraph.duplicate(true)
				_adjust_attack_graph(enemy.planGraph, attack_delta)
			return enemy
	var attack := maxi(1, floori(float(_or(enemy.get("atk"), _or(enemy.get("tier"), 1)))))
	var defense := maxi(1, floori(float(enemy.get("def", 0))))
	var label: String = _or(enemy.get("name"), _or(entry.get("title"), "敌手"))
	var states := {
		"OBSERVE": {"label": "观势", "cue": label + "正在辨认你的出牌节奏。", "intent": {
			"type": "defend", "value": defense, "desc": "观势：获得%d点护盾" % defense,
			"actionName": label + "收住攻势，护住中线并观察你的真元去向"}},
		"PRESSURE": {"label": "追击空档", "cue": label + "抓住你耗尽真元后的空档。", "intent": {
			"type": "attack", "value": attack + 1, "desc": "追击：造成%d点伤害" % (attack + 1),
			"actionName": label + "在真元枯竭的一刻抢入空门，发动重击"}},
		"EXPOSED": {"label": "失衡破绽", "cue": "你改变节奏，%s的预判落空。" % label, "intent": {
			"type": "defend", "value": 0, "desc": "失衡：本轮不造成伤害", "actionName": label + "失去攻击落点，被迫重新调整架势"}}}
	var transitions := [
		{"from": "OBSERVE", "when": "player_overcommitted", "to": "PRESSURE", "minCards": 2, "maxReservedQi": 1},
		{"from": "OBSERVE", "when": "player_reserved_resource", "to": "EXPOSED", "maxCards": 1, "minReservedQi": 2},
		{"from": ["OBSERVE", "PRESSURE"], "when": "deflected", "to": "EXPOSED"},
		{"from": ["PRESSURE", "EXPOSED"], "when": "action_resolved", "to": "OBSERVE"}]
	if role == "elite":
		states["COUNTER"] = {"label": "同式反制", "cue": label + "已经看穿你连续重复的牌型。", "intent": {
			"type": "attack", "value": attack, "piercing": true, "desc": "反制：穿透造成%d点伤害" % attack,
			"actionName": label + "沿重复招路切入，以反制手段越过外层护势"}}
		transitions.push_front({"from": "OBSERVE", "when": "repeated_card_type", "to": "COUNTER", "minConsecutive": 2})
		transitions.insert(transitions.size() - 1, {"from": "COUNTER", "when": "deflected", "to": "EXPOSED"})
		transitions.back()["from"].append("COUNTER")
	enemy["planGraph"] = {"planId": "catalog_%s_reactive_v1" % entry.id,
		"initialState": "OBSERVE", "states": states, "transitions": transitions}
	return enemy


func _is_boss(entry: Dictionary) -> bool:
	return entry.get("category") == "realmBoss" or entry.get("encounterKind") == "realm_boss" or entry.get("encounterRole") == "boss"


func _adjust_attack_graph(graph: Dictionary, delta: int) -> void:
	for stage in graph.get("states", {}).values():
		if stage is Dictionary and stage.get("intent") is Dictionary:
			_adjust_attack_intent(stage.intent, delta)


func _adjust_attack_intent(intent: Dictionary, delta: int) -> void:
	if delta == 0 or intent.get("type") not in ["attack", "piercing_attack"]:
		return
	var damage := maxi(1, maxi(1, floori(float(_or(intent.get("value"), 1)))) + delta)
	intent["value"] = damage
	if intent.get("desc") is String:
		intent["desc"] = RegEx.create_from_string("造成\\d+点伤害").sub(intent.desc, "造成%d点伤害" % damage)


func _document(module_id: String) -> Dictionary:
	var result: Variant = _content.read_module(module_id)
	return result if result is Dictionary else {}


func _truthy(value: Variant) -> bool:
	if value == null:
		return false
	if value is bool:
		return value
	if value is int or value is float:
		return value != 0
	if value is String:
		return not value.is_empty()
	return true


func _or(value: Variant, fallback: Variant) -> Variant:
	return value if _truthy(value) else fallback


func _copy(value: Variant) -> Variant:
	return value.duplicate(true) if value is Dictionary or value is Array else value
