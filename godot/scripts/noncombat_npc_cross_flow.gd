extends RefCounted

const MilestoneFlow = preload("res://scripts/noncombat_milestone_flow.gd")
const LegacyFragmentFlow = preload("res://scripts/noncombat_legacy_fragment_flow.gd")
const MODULE := "npcs:npc_cross_cards"
const RELATIONS_MODULE := "npcs:npc_relations"
const NPC_MODULE := "npcs:core"
const SOURCE_JS_SHA := "913ccdd6a3eb4464e3d3ce91ac1761c18cf8f2ce9346eb4929f2bf291046e6c8"
const MILESTONES := [0, 30, 55, 75, 90, 100]
const REALMS := ["qi", "foundation", "golden", "nascent", "deity", "tribulation", "ascension"]
const PERIODS := ["子时", "寅时", "辰时", "午时", "申时", "戌时"]

var last_error := ""
var roll_override_sequence: Array = []
var _content: RefCounted


func _init(content: RefCounted) -> void:
	_content = content


func marker(state: Dictionary, activation_index: int,
		dynamic_activation_index: int = -1) -> Dictionary:
	var cards: Variant = _content.read_module(MODULE)
	var relations: Variant = _content.read_module(RELATIONS_MODULE)
	var npcs: Variant = _content.read_module(NPC_MODULE)
	if not cards is Dictionary or not relations is Dictionary or not npcs is Dictionary \
			or _content.source_sha256(MODULE).length() != 64 \
			or _content.source_sha256(RELATIONS_MODULE).length() != 64 \
			or _content.source_sha256(NPC_MODULE).length() != 64:
		last_error = "NPC 交叉来源不可用"
		return {}
	var seed := int(state.get("marketRngState", {}).get("initialSeed", 0))
	if seed <= 0 or seed >= 2147483647:
		seed = 1 + absi(String(state.get("runClock", {}).get("lifeId", "npc-cross")).hash()) % 2147483646
	var relation_map := {}
	for raw in relations.get("relations", []):
		if not raw is Dictionary or not raw.get("npcA") is String \
				or not raw.get("npcB") is String:
			return {}
		var key := _pair_key(String(raw.npcA), String(raw.npcB))
		var affinity := int(raw.get("affinity", 0))
		relation_map[key] = {"affinity": affinity,
			"status": raw.get("status", "neutral"),
			"history": [{"turn": 0, "event": "初始关系", "delta": affinity}],
			"lastInteractionTurn": 0,
			"sharedSecrets": raw.get("sharedSecrets", []).duplicate(true)}
	var affections := {}
	var bonds := {}
	for raw in npcs.get("npcs", []):
		if not raw is Dictionary or not raw.get("id") is String:
			return {}
		var npc_id := String(raw.id)
		affections[npc_id] = int(state.get("npcAffection", {}).get(npc_id,
			state.get("npcEncounterScheduling", {}).get("affections", {}).get(
				npc_id, raw.get("startAffection", 0))))
		bonds[npc_id] = 0
	for roll in roll_override_sequence:
		if not (roll is int or roll is float) or float(roll) < 0.0 or float(roll) >= 1.0:
			last_error = "NPC 交叉随机带无效"
			return {}
	var result := {"version": 1, "activationIndex": activation_index,
		"lifeId": state.get("runClock", {}).get("lifeId"),
		"sourceSha": _content.source_sha256(MODULE),
		"relationsSha": _content.source_sha256(RELATIONS_MODULE),
		"npcsSha": _content.source_sha256(NPC_MODULE),
		"ruleSha": SOURCE_JS_SHA, "initialSeed": seed, "rngState": seed,
		"rollTape": roll_override_sequence.duplicate(true), "rollCursor": 0,
		"relations": relation_map, "affections": affections, "bonds": bonds,
		"resolved": [], "queuedCardId": ""}
	if dynamic_activation_index >= 0 and int(state.get("runClock", {}).get(
			"decisionIndex", -1)) >= dynamic_activation_index:
		return activate_dynamic(result, dynamic_activation_index)
	return result


func activate_dynamic(marker_value: Dictionary, activation_index: int) -> Dictionary:
	if marker_value.has("dynamicActivationIndex"):
		return marker_value
	var result: Dictionary = marker_value.duplicate(true)
	result["version"] = 2
	result["dynamicActivationIndex"] = activation_index
	result["queuedCards"] = []
	result["lastCrossTurn"] = {}
	result["lastResolvedTurn"] = {}
	result["issuedCards"] = {}
	return result


func valid(state: Dictionary) -> bool:
	var value: Variant = state.get("npcCrossState")
	if not value is Dictionary:
		return false
	return (value.get("version") == 1 or value.get("version") == 2) \
		and value.get("lifeId") == state.get("runClock", {}).get("lifeId") \
		and value.get("sourceSha") == _content.source_sha256(MODULE) \
		and value.get("relationsSha") == _content.source_sha256(RELATIONS_MODULE) \
		and value.get("npcsSha") == _content.source_sha256(NPC_MODULE) \
		and value.get("ruleSha") == SOURCE_JS_SHA \
		and int(value.get("activationIndex", -1)) >= 0 \
		and int(value.get("activationIndex", -1)) <= int(
			state.get("runClock", {}).get("decisionIndex", -1)) \
		and value.get("relations") is Dictionary \
		and value.get("affections") is Dictionary \
		and value.get("bonds") is Dictionary \
		and value.get("resolved") is Array \
		and value.get("queuedCardId") is String \
		and value.get("rollTape") is Array \
		and int(value.get("rollCursor", -1)) >= 0 \
		and (not value.has("dynamicActivationIndex") or (
			int(value.get("dynamicActivationIndex", -1)) >= 0 \
			and int(value.get("dynamicActivationIndex", -1)) <= int(
				state.get("runClock", {}).get("decisionIndex", -1)) \
			and value.get("queuedCards") is Array \
			and value.get("lastCrossTurn") is Dictionary \
			and ((value.get("version") == 1 and not value.has("issuedCards")) \
				or (value.get("version") == 2 and value.get("issuedCards") is Dictionary)) \
			and value.get("lastResolvedTurn") is Dictionary))


func collect(state: Dictionary) -> Dictionary:
	last_error = ""
	if state.get("phase") != "FLOW_PENDING" or not state.has("npcCrossState"):
		return {}
	if not valid(state):
		last_error = "NPC 交叉状态或来源无效"
		return {}
	var candidate: Dictionary = state.duplicate(true)
	var dynamic_enabled: bool = candidate.npcCrossState.has("dynamicActivationIndex")
	if dynamic_enabled and candidate.npcCrossState.get("version") == 1:
		var legacy_issued := {}
		for queued in candidate.npcCrossState.get("queuedCards", []):
			if not queued is Dictionary or queued.get("_dynamicSource") != SOURCE_JS_SHA \
					or not _valid_dynamic_card(candidate, queued, false):
				continue
			var pair: Array = queued.npcIds
			var prefix := "npc_cross_%s_%s_" % [pair[0], pair[1]]
			legacy_issued[String(queued.id)] = {
				"turn": int(String(queued.id).substr(prefix.length())),
				"pairKey": _pair_key(String(pair[0]), String(pair[1])),
				"semanticKey": String(queued.semanticKey)}
		candidate.npcCrossState["issuedCards"] = legacy_issued
		candidate.npcCrossState.version = 2
	if not dynamic_enabled and not String(candidate.npcCrossState.queuedCardId).is_empty():
		return candidate
	var data: Variant = _content.read_module(MODULE)
	if not data is Dictionary:
		last_error = "NPC 交叉卡目录不可用"
		return {}
	var eligible: Array = []
	for raw in data.get("presetCards", []):
		if raw is Dictionary and _eligible(candidate, raw):
			eligible.append(raw)
	if not eligible.is_empty() and _next_roll(candidate.npcCrossState) <= 0.15:
		var total := 0
		for raw in eligible:
			total += maxi(1, int(raw.get("weight", 1)))
		var roll := _next_roll(candidate.npcCrossState) * total
		var selected: Dictionary = eligible.back()
		for raw in eligible:
			roll -= maxi(1, int(raw.get("weight", 1)))
			if roll <= 0.0:
				selected = raw
				break
		if dynamic_enabled:
			candidate.npcCrossState.queuedCards.append(_project(selected))
		else:
			candidate.npcCrossState.queuedCardId = selected.id
		return candidate
	if dynamic_enabled and not _collect_dynamic(candidate):
		return {}
	return candidate


func take(state: Dictionary) -> Dictionary:
	if state.get("phase") != "FLOW_PENDING" or not valid(state):
		return {}
	var card_id := String(state.npcCrossState.get("queuedCardId", ""))
	var candidate: Dictionary = state.duplicate(true)
	var had_queued_cards: bool = not candidate.npcCrossState.get("queuedCards", []).is_empty()
	var projected := {}
	if not card_id.is_empty():
		var raw := _raw_card(card_id)
		candidate.npcCrossState.queuedCardId = ""
		if not raw.is_empty() and _eligible(candidate, raw):
			projected = _project(raw)
	elif candidate.npcCrossState.has("queuedCards"):
		while not candidate.npcCrossState.queuedCards.is_empty():
			var queued: Variant = candidate.npcCrossState.queuedCards.pop_front()
			var issued_id := String(queued.get("id", "")) if queued is Dictionary else ""
			if queued is Dictionary and _queued_card_eligible(candidate, queued) \
					and (not _raw_card(String(queued.get("id", ""))).is_empty() \
					or _valid_dynamic_card(candidate, queued, false)):
				projected = queued
				break
			if candidate.npcCrossState.has("issuedCards"):
				candidate.npcCrossState.issuedCards.erase(issued_id)
	if projected.is_empty():
		return candidate if not card_id.is_empty() or had_queued_cards else {}
	card_id = String(projected.id)
	candidate["pendingNpcCrossCard"] = projected
	candidate["currentCardId"] = card_id
	candidate["phase"] = "NPC_CROSS_PENDING"
	candidate["decisionCheckpoint"] = {"version": 1, "cardId": card_id,
		"sourceCardId": state.get("decisionCheckpoint", {}).get("sourceCardId"),
		"turn": candidate.get("turn"), "decisionIndex": candidate.runClock.decisionIndex,
		"flowSource": "narrative:31", "lifeId": candidate.runClock.lifeId}
	return candidate


func card(state: Dictionary) -> Dictionary:
	if state.get("phase") != "NPC_CROSS_PENDING" or not valid(state):
		return {}
	var pending: Variant = state.get("pendingNpcCrossCard")
	if pending is Dictionary and pending.get("_dynamicSource") == SOURCE_JS_SHA:
		return pending.duplicate(true) if _valid_dynamic_card(state, pending) else {}
	var raw := _raw_card(String(state.get("currentCardId", "")))
	if raw.is_empty():
		return {}
	var projected := _project(raw)
	return projected if JSON.parse_string(JSON.stringify(projected)) == \
		JSON.parse_string(JSON.stringify(state.get("pendingNpcCrossCard", {}))) else {}


func settle(state: Dictionary, direction: String) -> Dictionary:
	var source_card := card(state)
	if source_card.is_empty() or not source_card.get("choices", {}).has(direction):
		return {}
	var candidate: Dictionary = state.duplicate(true)
	var choice: Dictionary = source_card.choices[direction]
	for key_value in choice.get("effects", {}):
		var key := String(key_value)
		var value: Variant = choice.effects[key]
		if not (value is int or value is float) or float(value) != float(int(value)):
			return {}
		var delta := int(value)
		if key == "daoHeart":
			candidate.attributes.daoHeart = clampi(int(candidate.attributes.get("daoHeart", 0)) + delta,
				0, LegacyFragmentFlow.actual_max_dao_heart(candidate))
		elif key == "wisdom":
			var knowledge: Dictionary = candidate.get("knowledge", {})
			knowledge["wisdom"] = int(knowledge.get("wisdom", 0)) + delta
			candidate["knowledge"] = knowledge
		elif key == "heroism":
			var modifiers: Dictionary = candidate.get("modifiers", {})
			modifiers["heroism"] = int(modifiers.get("heroism", 0)) + delta
			candidate["modifiers"] = modifiers
		elif key.begins_with("bond_"):
			if not _add_affection(candidate, key.substr(5), delta):
				return {}
		elif key.begins_with("npc_relation:"):
			var parts := key.split(":")
			if parts.size() != 3 or not _adjust_relation(candidate, parts[1], parts[2], delta):
				return {}
		else:
			return {}
	for npc_id_value in choice.get("npcAffection", {}):
		var npc_id := String(npc_id_value)
		if not _add_affection(candidate, npc_id, int(choice.npcAffection[npc_id])):
			return {}
	if source_card.get("_dynamicSource") == SOURCE_JS_SHA:
		candidate.npcCrossState.lastResolvedTurn[source_card.semanticKey] = int(
			candidate.get("turn", 0)) + 1
		if candidate.npcCrossState.has("issuedCards"):
			candidate.npcCrossState.issuedCards.erase(String(source_card.id))
	else:
		candidate.npcCrossState.resolved.append(source_card.semanticKey)
	var base := int(candidate.get("turn", 0))
	var next_index := base + 1
	candidate.choiceHistory.append({"cardId": source_card.id,
		"cardType": "NPC_CROSS", "direction": direction, "turn": base,
		"decisionIndex": next_index, "tags": source_card.get("tags", [])})
	while candidate.choiceHistory.size() > 30:
		candidate.choiceHistory.pop_front()
	candidate.cardsPlayed.append(source_card.id)
	candidate["turn"] = next_index
	candidate.runClock.decisionIndex = next_index
	var token := "decision:%s:choice:%s:%d" % [candidate.runClock.lifeId,
		source_card.id, next_index]
	if candidate.runClock.receipts.has(token):
		return {}
	candidate.runClock.receipts[token] = {"token": token,
		"decisionIndex": next_index, "sourceCardId": source_card.id, "kind": "choice"}
	MilestoneFlow.tick_seeds(candidate)
	candidate.erase("pendingNpcCrossCard")
	candidate["currentCardId"] = ""
	candidate["phase"] = "FLOW_PENDING"
	candidate["decisionCheckpoint"] = {"version": 1, "cardId": null,
		"sourceCardId": source_card.id, "turn": next_index,
		"decisionIndex": next_index, "flowPending": true}
	return candidate


func _collect_dynamic(state: Dictionary) -> bool:
	var source: Variant = _content.read_module(NPC_MODULE)
	if not source is Dictionary:
		last_error = "NPC 动态交叉日程不可用"
		return false
	var location_map := {}
	for npc in source.get("npcs", []):
		if not npc is Dictionary or state.get("realm") not in npc.get("appearRealms", []):
			continue
		var npc_id := String(npc.get("id", ""))
		if not _physical_in_current_life(state, npc_id):
			continue
		var schedule: Dictionary = _schedule_location(npc, state)
		var location := String(schedule.get("location", ""))
		if location.is_empty():
			continue
		if npc.get("schedule") is Dictionary:
			_set_npc_location(state, npc_id, location, "npc_schedule")
		if not _locations_compatible(String(state.get("currentLocation", "")), location):
			continue
		if not location_map.has(location):
			location_map[location] = []
		location_map[location].append(npc)
	for location in location_map:
		var same_place: Array = location_map[location]
		for first in range(same_place.size()):
			for second in range(first + 1, same_place.size()):
				var npc_a: Dictionary = same_place[first]
				var npc_b: Dictionary = same_place[second]
				var pair_key := _pair_key(String(npc_a.id), String(npc_b.id))
				var relation: Dictionary = state.npcCrossState.relations.get(pair_key, {})
				var prior_turn: Variant = state.npcCrossState.lastCrossTurn.get(pair_key)
				if prior_turn != null and int(state.get("turn", 0)) - int(prior_turn) < 12:
					continue
				var chance := 0.15
				if not relation.is_empty() and int(relation.get("affinity", 0)) != 0:
					chance *= 1.5
					if relation.get("status") == "rival":
						chance *= 2.0
				if location in ["宗门大殿", "坊市中心"]:
					chance *= 1.5
				chance *= 1.0 + float(state.get("attributes", {}).get("fortune", 50)) / 500.0
				if _next_roll(state.npcCrossState) > chance:
					continue
				var card_value := _dynamic_card(state, npc_a, npc_b,
					String(location), relation)
				if card_value.is_empty() or not _queued_card_eligible(state, card_value) \
						or _queued_semantic(state.npcCrossState, String(card_value.semanticKey)):
					continue
				state.npcCrossState.queuedCards.append(card_value)
				state.npcCrossState.issuedCards[String(card_value.id)] = {
					"turn": int(state.get("turn", 0)), "pairKey": pair_key,
					"semanticKey": String(card_value.semanticKey)}
				state.npcCrossState.lastCrossTurn[pair_key] = int(state.get("turn", 0))
				if not relation.is_empty():
					relation.lastInteractionTurn = int(state.get("turn", 0))
					state.npcCrossState.relations[pair_key] = relation
	return true


func _schedule_location(npc: Dictionary, state: Dictionary) -> Dictionary:
	var period: String = PERIODS[floori(maxi(0, int(state.get("turn", 0))) / 6.0) % 6]
	return {"location": npc.get("schedule", {}).get(period,
		npc.get("defaultLocation", "")), "reason": "npc_schedule"}


func _set_npc_location(state: Dictionary, npc_id: String, location: String,
		reason: String) -> void:
	var continuity: Dictionary = state.get("worldContinuityState", {})
	var presence: Dictionary = continuity.get("npcs", {}).get(npc_id, {})
	if presence.is_empty() or presence.get("locationId") == location:
		return
	continuity.revision = int(continuity.get("revision", 0)) + 1
	presence.locationId = location
	presence.changedAtTurn = int(state.get("turn", 0))
	presence.changedByNode = reason
	presence.revision = continuity.revision
	continuity.npcs[npc_id] = presence
	state.worldContinuityState = continuity


func _dynamic_card(state: Dictionary, npc_a: Dictionary, npc_b: Dictionary,
		location: String, relation: Dictionary, neutral_variant: int = -1,
		source_turn: int = -1) -> Dictionary:
	var npc_a_id := String(npc_a.id)
	var npc_b_id := String(npc_b.id)
	var name_a := String(npc_a.get("name", npc_a_id))
	var name_b := String(npc_b.get("name", npc_b_id))
	var affinity := int(relation.get("affinity", 0))
	var status := String(relation.get("status", "neutral"))
	if not _valid_rule(status):
		return {}
	var title := ""
	var description := ""
	var choices := {}
	if status == "rival":
		title = "%s与%s·对峙" % [name_a, name_b]
		description = "%s与%s在%s不期而遇。空气骤然凝滞——%s在两人之间涌动。\n\n你被夹在中间。" % [
			name_a, name_b, location, "浓烈的杀意" if absi(affinity) >= 50 else "无声的较量"]
		choices = {
			"left": {"text": "挡在中间，以身为盾",
				"desc": "你横在两人之间。%s先按下杀意，%s也收住锋芒；这场冲突暂时止在你面前。" % [name_a, name_b],
				"effects": {"heroism": 5, "daoHeart": 3,
					"npc_relation:%s:%s" % [npc_a_id, npc_b_id]: 10},
				"npcAffection": {npc_a_id: 2, npc_b_id: 2}},
			"right": {"text": "退后一步，让他们自己解决",
				"desc": "你退出两人的锋芒。%s与%s再无顾忌，旧怨因此更深了一层。" % [name_a, name_b],
				"effects": {"wisdom": 5,
					"npc_relation:%s:%s" % [npc_a_id, npc_b_id]: -20},
				"npcAffection": {npc_a_id: -1, npc_b_id: -1}}}
	elif status in ["ally", "master-disciple"]:
		title = "%s与%s·叙旧" % [name_a, name_b]
		description = "%s和%s在%s相遇。%s说了句什么，%s罕见地笑了——你从未见过%s这样的表情。" % [
			name_a, name_b, location, name_b, name_a, name_a]
		choices = {
			"left": {"text": "上前加入他们的谈话",
				"desc": "%s为你让出半步，%s顺势把方才的话说完。你终于被纳入这段旧缘，而非只做路过的旁观者。" % [name_a, name_b],
				"effects": {"daoHeart": 3, "wisdom": 3},
				"npcAffection": {npc_a_id: 3, npc_b_id: 3}},
			"right": {"text": "不打扰他们，远远观察",
				"desc": "你没有惊动两人。%s与%s把旧事说到尽处，你也从他们的神色里看懂了几分前因。" % [name_a, name_b],
				"effects": {"wisdom": 5}, "npcAffection": {}}}
	else:
		var tensions := [
			"两人在%s见面时，相对无言。%s微微侧身，%s的目光从你身上掠过——你感觉到一种说不清的张力。" % [location, name_a, name_b],
			"%s和%s在%s擦肩而过。两人都假装没看到对方——但谁都骗不了谁。" % [name_a, name_b, location],
			"在%s，%s对%s微微点头。%s还以目光——不冷不热，像是第一次知道对方存在。" % [location, name_b, name_a, name_a]]
		title = "问心有愧"
		var variant := neutral_variant if neutral_variant >= 0 else \
			mini(int(_next_roll(state.npcCrossState) * tensions.size()),
				tensions.size() - 1)
		if variant >= tensions.size():
			return {}
		description = tensions[variant]
		choices = {
			"left": {"text": "试着缓和气氛",
				"desc": "你递出一句不偏不倚的话。%s与%s虽未就此亲近，却都肯把僵局放下一步。" % [name_a, name_b],
				"effects": {"daoHeart": 2,
					"npc_relation:%s:%s" % [npc_a_id, npc_b_id]: 5}},
			"right": {"text": "若无其事地走开",
				"desc": "你没有介入。%s与%s各自离去，那点未说出口的芥蒂仍留在原处。" % [name_a, name_b],
				"effects": {}}}
	return {"id": "npc_cross_%s_%s_%d" % [npc_a_id, npc_b_id,
		int(state.get("turn", 0)) if source_turn < 0 else source_turn],
		"type": "NPC_CROSS", "title": title,
		"description": description, "npcIds": [npc_a_id, npc_b_id],
		"manifestation": "PHYSICAL", "location": location,
		"realm": state.get("realm"), "requiresPlayerPresence": true,
		"eligibleRealms": [state.get("realm")], "relationStatus": status,
		"semanticKey": "npc-cross:%s:%s:%s" % [
			npc_a_id if npc_a_id < npc_b_id else npc_b_id,
			npc_b_id if npc_a_id < npc_b_id else npc_a_id, status],
		"once": false, "repeatPolicy": {"mode": "cooldown", "cooldownTurns": 12},
		"weight": 0, "tags": ["npc_cross", "dramatic"], "choices": choices,
		"_flowSource": "narrative:31", "_flowPhase": "TENSION",
		"_dynamicSource": SOURCE_JS_SHA}


func _queued_semantic(marker_value: Dictionary, semantic: String) -> bool:
	for queued in marker_value.get("queuedCards", []):
		if queued is Dictionary and queued.get("semanticKey") == semantic:
			return true
	return false


func _queued_card_eligible(state: Dictionary, queued: Dictionary) -> bool:
	if queued.get("type") != "NPC_CROSS" or queued.get("npcIds") is not Array \
			or queued.get("realm") != state.get("realm") \
			or not _locations_compatible(String(state.get("currentLocation", "")),
				String(queued.get("location", ""))):
		return false
	for npc_id in queued.npcIds:
		if not _physical_in_current_life(state, String(npc_id)):
			return false
	var semantic := String(queued.get("semanticKey", ""))
	if queued.get("once") == true:
		return not state.npcCrossState.resolved.has(semantic) \
			and not state.get("cardsPlayed", []).has(queued.get("id"))
	return int(state.get("runClock", {}).get("decisionIndex", 0)) - int(
		state.npcCrossState.get("lastResolvedTurn", {}).get(semantic, -1000)) >= 12


func _valid_dynamic_card(state: Dictionary, queued: Dictionary,
		require_pending: bool = true) -> bool:
	if not state.npcCrossState.has("dynamicActivationIndex") \
			or (require_pending and queued.get("id") != state.get("currentCardId")) \
			or queued.get("_dynamicSource") != SOURCE_JS_SHA \
			or queued.get("npcIds") is not Array \
			or queued.npcIds.size() != 2:
		return false
	var npc_a_id := String(queued.npcIds[0])
	var npc_b_id := String(queued.npcIds[1])
	var id_prefix := "npc_cross_%s_%s_" % [npc_a_id, npc_b_id]
	var card_id := String(queued.get("id", ""))
	if not card_id.begins_with(id_prefix):
		return false
	var turn_suffix := card_id.substr(id_prefix.length())
	if not turn_suffix.is_valid_int():
		return false
	var source_turn := int(turn_suffix)
	var pair_key := _pair_key(npc_a_id, npc_b_id)
	if str(source_turn) != turn_suffix \
			or source_turn < int(state.npcCrossState.get("dynamicActivationIndex", 0)) \
			or source_turn > int(state.get("turn", -1)) \
			or source_turn > int(state.get("runClock", {}).get("decisionIndex", -1)):
		return false
	if state.npcCrossState.has("issuedCards"):
		var issued: Variant = state.npcCrossState.issuedCards.get(card_id)
		if not issued is Dictionary or issued.get("turn") != source_turn \
				or issued.get("pairKey") != pair_key \
				or issued.get("semanticKey") != queued.get("semanticKey"):
			return false
	if npc_a_id == npc_b_id or not _physical_in_current_life(state, npc_a_id) \
			or not _physical_in_current_life(state, npc_b_id) \
			or not _locations_compatible(String(state.get("currentLocation", "")),
				String(queued.get("location", ""))):
		return false
	var source: Variant = _content.read_module(NPC_MODULE)
	if not source is Dictionary:
		return false
	var npc_a := {}
	var npc_b := {}
	for npc in source.get("npcs", []):
		if npc is Dictionary and npc.get("id") == npc_a_id:
			npc_a = npc
		if npc is Dictionary and npc.get("id") == npc_b_id:
			npc_b = npc
	if npc_a.is_empty() or npc_b.is_empty():
		return false
	var status := String(queued.get("relationStatus", ""))
	if not _valid_rule(status):
		return false
	var affinities := [0, 50] if status == "rival" else [0]
	var variants := [0, 1, 2] if status in ["neutral", "estranged"] else [0]
	for affinity in affinities:
		for variant in variants:
			var expected := _dynamic_card(state, npc_a, npc_b,
				String(queued.get("location", "")),
				{"status": status, "affinity": affinity}, variant, source_turn)
			if JSON.parse_string(JSON.stringify(expected)) == \
					JSON.parse_string(JSON.stringify(queued)):
				return true
	return false


func _valid_rule(status: String) -> bool:
	var branch := "rival" if status == "rival" else \
		"ally" if status in ["ally", "master-disciple"] else \
		"ambient" if status in ["neutral", "estranged"] else ""
	if branch.is_empty():
		return false
	var rule: Dictionary = _content.find("generated_card", "npc_cross_rule:" + branch)
	return rule.get("templateIdentity") == true \
		and rule.get("branch") == branch \
		and rule.get("relationStatuses", []).has(status) \
		and rule.get("sourcePath") == "src/systems/NpcSystem.js" \
		and rule.get("sourceSha256") == SOURCE_JS_SHA \
		and rule.get("sourceSymbol") == "NpcSystem._emitCrossCard" \
		and rule.get("producerGodot") == \
			"res://scripts/noncombat_npc_cross_flow.gd::_dynamic_card" \
		and rule.get("relationSourceSha256") == \
			_content.source_sha256(RELATIONS_MODULE) \
		and rule.get("npcSourceSha256") == _content.source_sha256(NPC_MODULE)


func _physical_in_current_life(state: Dictionary, npc_id: String) -> bool:
	var presence: Dictionary = state.get("worldContinuityState", {}).get(
		"npcs", {}).get(npc_id, {})
	return presence.get("lifecycle") == "ACTIVE" \
		and presence.get("manifestation") == "PHYSICAL" \
		and int(presence.get("lifeId", -1)) == int(state.get("lifeCount", 0))


func _eligible(state: Dictionary, raw: Dictionary) -> bool:
	if raw.get("realm") != state.get("realm") or not raw.get("npcIds") is Array \
			or raw.npcIds.size() < 2 or not _locations_compatible(
			String(state.get("currentLocation", "")), String(raw.get("location", ""))):
		return false
	var semantic := "npc-cross-preset:" + String(raw.get("id", ""))
	if state.get("npcCrossState", {}).get("resolved", []).has(semantic) \
			or state.get("cardsPlayed", []).has(raw.get("id")) \
			or state.get("npcCrossState", {}).get("queuedCardId") == raw.get("id") \
			or _queued_semantic(state.get("npcCrossState", {}), semantic):
		return false
	var npcs: Variant = _content.read_module(NPC_MODULE)
	if not npcs is Dictionary:
		return false
	var by_id := {}
	for npc in npcs.get("npcs", []):
		if npc is Dictionary:
			by_id[npc.get("id")] = npc
	for id_value in raw.npcIds:
		var npc_id := String(id_value)
		var npc: Dictionary = by_id.get(npc_id, {})
		if npc.is_empty() or state.get("realm") not in npc.get("appearRealms", []) \
				or not _physical_in_current_life(state, npc_id):
			return false
	return true


func _project(raw: Dictionary) -> Dictionary:
	var card_value: Dictionary = raw.duplicate(true)
	card_value["type"] = "NPC_CROSS"
	card_value["manifestation"] = "PHYSICAL"
	card_value["requiresPlayerPresence"] = true
	card_value["eligibleRealms"] = [raw.get("realm")]
	card_value["relationStatus"] = raw.get("status", "neutral")
	card_value["semanticKey"] = "npc-cross-preset:" + String(raw.get("id", ""))
	card_value["once"] = true
	card_value["_flowSource"] = "narrative:31"
	card_value["_flowPhase"] = "TENSION"
	return card_value


func _raw_card(card_id: String) -> Dictionary:
	var doc: Variant = _content.read_module(MODULE)
	if not doc is Dictionary:
		return {}
	for raw in doc.get("presetCards", []):
		if raw is Dictionary and raw.get("id") == card_id:
			return raw
	return {}


func _add_affection(state: Dictionary, npc_id: String, delta: int) -> bool:
	var marker_value: Dictionary = state.npcCrossState
	if not marker_value.affections.has(npc_id):
		return false
	# Another NPC consumer can change affection after this marker was created.
	var prior := int(state.get("npcAffection", {}).get(npc_id,
		state.get("npcEncounterScheduling", {}).get("affections", {}).get(
			npc_id, marker_value.affections[npc_id])))
	var value := clampi(prior + delta, -50, 100)
	marker_value.affections[npc_id] = value
	var root: Dictionary = state.get("npcAffection", {})
	root[npc_id] = value
	state["npcAffection"] = root
	for index in range(MILESTONES.size() - 1, -1, -1):
		if value >= MILESTONES[index] and int(marker_value.bonds.get(npc_id, 0)) < index:
			marker_value.bonds[npc_id] = index
			break
	if state.has("npcEncounterScheduling") \
			and state.npcEncounterScheduling.get("affections", {}).has(npc_id):
		state.npcEncounterScheduling.affections[npc_id] = value
		state.npcEncounterScheduling.bonds[npc_id] = maxi(
			int(state.npcEncounterScheduling.bonds.get(npc_id, 0)),
			int(marker_value.bonds.get(npc_id, 0)))
	return true


func _adjust_relation(state: Dictionary, npc_a: String, npc_b: String, delta: int) -> bool:
	if not state.npcCrossState.affections.has(npc_a) \
			or not state.npcCrossState.affections.has(npc_b):
		return false
	var key := _pair_key(npc_a, npc_b)
	var relations: Dictionary = state.npcCrossState.relations
	var relation: Dictionary = relations.get(key, {"affinity": 0, "status": "neutral",
		"history": [], "lastInteractionTurn": 0, "sharedSecrets": []})
	relation.affinity = clampi(int(relation.affinity) + delta, -100, 100)
	relation.lastInteractionTurn = int(state.get("turn", 0))
	relation.history.append({"turn": relation.lastInteractionTurn,
		"event": "玩家影响", "delta": delta})
	var affinity := int(relation.affinity)
	relation.status = "ally" if affinity >= 20 else "rival" if affinity <= -20 else "neutral"
	relations[key] = relation
	return true


func _next_roll(marker_value: Dictionary) -> float:
	var state_value := int(marker_value.get("rngState", 1))
	state_value = int((state_value * 48271) % 2147483647)
	marker_value.rngState = state_value
	var index := int(marker_value.get("rollCursor", 0))
	marker_value.rollCursor = index + 1
	var tape: Array = marker_value.get("rollTape", [])
	return float(tape[index]) if index < tape.size() else float(state_value) / 2147483647.0


func _pair_key(npc_a: String, npc_b: String) -> String:
	return npc_a + "_" + npc_b if npc_a < npc_b else npc_b + "_" + npc_a


func _locations_compatible(player: String, event: String) -> bool:
	if player.is_empty() or event.is_empty():
		return false
	if player == event:
		return true
	for words in [
		["宗门", "青云剑宗", "剑崖", "剑冢", "山门", "演武场", "闭关室", "裂石山径"],
		["坊市", "万宝楼", "灵草街", "铁匠铺"],
		["秘境", "遗迹", "试炼通道", "灵脉矿洞", "古修洞府"],
		["魔域", "血煞", "西域", "血砂", "白骨荒野"]]:
		var player_match := false
		var event_match := false
		for word in words:
			player_match = player_match or player.contains(word)
			event_match = event_match or event.contains(word)
		if player_match and event_match:
			return true
	return false
