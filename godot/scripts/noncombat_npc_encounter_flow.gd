extends RefCounted

var legacy_schedule_metadata := false
const MilestoneFlow = preload("res://scripts/noncombat_milestone_flow.gd")

# The qi sword route has one physically eligible NPC. Eligibility, schedule,
# probability, and the four source scenes are kept separate from the domain's
# card ordering so the same saved draw can be replayed after a cold start.
const MODULE := "npcs:core"
const TEMPLATE_PATH := "res://content/derived/npc_encounter_templates.json"
const TEMPLATE_SHA := "5d4ea3eb4483c3d9603ac2ffb62b21d1b16c26fc6c9b0699219fc48cbb4c7b85"
const SOURCE_JS_SHA := "913ccdd6a3eb4464e3d3ce91ac1761c18cf8f2ce9346eb4929f2bf291046e6c8"
const NPC_ID := "bai_ren"
const PERIODS := ["子时", "寅时", "辰时", "午时", "申时", "戌时"]

var last_error := ""
var roll_override_sequence: Array = []
var _content: RefCounted
var _template_cache: Dictionary = {}


func _init(content: RefCounted) -> void:
	_content = content


func marker(state: Dictionary, activation_index: int,
		general_activation_index: int = -1) -> Dictionary:
	var source: Variant = _content.read_module(MODULE)
	var sha: String = _content.source_sha256(MODULE)
	if not source is Dictionary or sha.length() != 64 \
			or _definition(source).is_empty():
		last_error = "NPC 来源不可用"
		return {}
	var seed := int(state.get("marketRngState", {}).get("initialSeed", 0))
	if seed <= 0 or seed >= 2147483647:
		seed = 1 + absi(int(String(state.get("runClock", {}).get(
			"lifeId", "npc")).hash())) % 2147483646
	for value in roll_override_sequence:
		if not value is float and not value is int or float(value) < 0.0 \
				or float(value) >= 1.0:
			last_error = "NPC 回放随机值无效"
			return {}
	var result := {"version": 1, "activationIndex": activation_index,
		"lifeId": state.get("runClock", {}).get("lifeId"),
		"sourceSha": sha, "ruleSha": SOURCE_JS_SHA,
		"initialSeed": seed, "rngState": seed,
		"rollTape": roll_override_sequence.duplicate(true), "rollCursor": 0,
		"memories": {NPC_ID: []}, "affections": {NPC_ID: int(
			state.get("npcAffection", {}).get(NPC_ID, 0))},
		"bonds": {NPC_ID: 0}, "emotions": {NPC_ID: "平静"}}
	if general_activation_index >= 0 and int(state.get("runClock", {}).get(
			"decisionIndex", -1)) >= general_activation_index:
		return activate_general(result, state, general_activation_index)
	return result


func activate_general(marker_value: Dictionary, state: Dictionary,
		activation_index: int) -> Dictionary:
	if marker_value.has("generalActivationIndex"):
		return marker_value
	var templates := _templates()
	var source: Variant = _content.read_module(MODULE)
	if templates.is_empty() or not source is Dictionary:
		last_error = "NPC 全人物遭遇来源不可用"
		return {}
	var result: Dictionary = marker_value.duplicate(true)
	for npc in source.get("npcs", []):
		if not npc is Dictionary:
			return {}
		var npc_id := String(npc.get("id", ""))
		if npc_id.is_empty() or not templates.templates.has(npc_id):
			return {}
		if not result.memories.has(npc_id):
			result.memories[npc_id] = []
		if not result.affections.has(npc_id):
			result.affections[npc_id] = int(state.get("npcAffection", {}).get(
				npc_id, state.get("npcCrossState", {}).get("affections", {}).get(
					npc_id, npc.get("startAffection", 0))))
		if not result.bonds.has(npc_id):
			result.bonds[npc_id] = 0
		if not result.emotions.has(npc_id):
			result.emotions[npc_id] = String(npc.get("defaultEmotion", "平静"))
	result["generalActivationIndex"] = activation_index
	result["templateSha"] = TEMPLATE_SHA
	return result


func _templates() -> Dictionary:
	if not _template_cache.is_empty():
		return _template_cache
	if not FileAccess.file_exists(TEMPLATE_PATH) \
			or FileAccess.get_sha256(TEMPLATE_PATH).to_lower() != TEMPLATE_SHA:
		return {}
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(TEMPLATE_PATH))
	if not raw is Dictionary or raw.get("sourceSha") != SOURCE_JS_SHA \
			or not raw.get("templates") is Dictionary:
		return {}
	_template_cache = raw
	return _template_cache


func validate_marker(state: Dictionary) -> bool:
	var marker_value: Variant = state.get("npcEncounterScheduling")
	if not marker_value is Dictionary:
		return false
	var value: Dictionary = marker_value
	return value.get("version") == 1 \
		and value.get("lifeId") == state.get("runClock", {}).get("lifeId") \
		and value.get("sourceSha") == _content.source_sha256(MODULE) \
		and value.get("ruleSha") == SOURCE_JS_SHA \
		and int(value.get("activationIndex", -1)) >= 0 \
		and int(value.get("activationIndex", -1)) <= int(
			state.get("runClock", {}).get("decisionIndex", -1)) \
		and value.get("memories", {}).get(NPC_ID) is Array \
		and (value.get("affections", {}).get(NPC_ID) is int \
			or value.get("affections", {}).get(NPC_ID) is float) \
		and (value.get("bonds", {}).get(NPC_ID) is int \
			or value.get("bonds", {}).get(NPC_ID) is float) \
		and value.get("emotions", {}).get(NPC_ID) is String \
		and value.get("rollTape") is Array \
		and int(value.get("rollCursor", -1)) >= 0 \
		and (not value.has("generalActivationIndex") or (
			int(value.get("generalActivationIndex", -1)) >= 0 \
			and int(value.get("generalActivationIndex", -1)) <= int(
				state.get("runClock", {}).get("decisionIndex", -1)) \
			and value.get("templateSha") == TEMPLATE_SHA))


func collect(state: Dictionary) -> Dictionary:
	last_error = ""
	if state.get("phase") != "FLOW_PENDING" or not state.has(
			"npcEncounterScheduling"):
		return {}
	if not validate_marker(state):
		last_error = "NPC 遭遇存档或来源无效"
		return {}
	if state.npcEncounterScheduling.has("generalActivationIndex"):
		return _collect_general(state)
	var candidate: Dictionary = state.duplicate(true)
	if candidate.npcEncounterScheduling.get("queuedCard") is Dictionary:
		return candidate
	if _encounter_limit_reached(candidate.npcEncounterScheduling):
		return candidate
	var npc: Dictionary = _definition(_content.read_module(MODULE))
	if npc.is_empty() or candidate.get("realm") not in npc.get("appearRealms", []) \
			or npc.get("pathRestriction") != candidate.get("path"):
		return candidate
	var continuity: Dictionary = candidate.get("worldContinuityState", {})
	var presence: Dictionary = continuity.get("npcs", {}).get(NPC_ID, {})
	if presence.get("lifecycle") != "ACTIVE" or presence.get("manifestation") != "PHYSICAL":
		return candidate
	var draw_turn := maxi(0, int(candidate.get("turn", 0)) - 1)
	var schedule: Dictionary = npc.get("schedule", {})
	var location := String(schedule.get(PERIODS[floori(draw_turn / 6.0) % 6],
		npc.get("defaultLocation", "")))
	if location.is_empty():
		return candidate
	if presence.get("locationId") != location:
		candidate = tick_schedule(candidate, draw_turn)
		continuity = candidate.get("worldContinuityState", {})
		presence = continuity.get("npcs", {}).get(NPC_ID, {})
	if not _locations_compatible(String(candidate.get("currentLocation", "")),
			location):
		return candidate
	var memories: Array = candidate.npcEncounterScheduling.memories.get(NPC_ID, [])
	if memories.size() >= 6 or not memories.is_empty() \
			and draw_turn - int(memories.back().get("turn", 0)) < 15:
		return candidate
	var chance := 0.15 + float(candidate.get("attributes", {}).get("fortune", 0)) / 1000.0
	var scene := "初见" if memories.is_empty() else (
		"重逢" if int(candidate.npcEncounterScheduling.affections.get(NPC_ID, 0)) >= 60
		else "对峙" if int(candidate.npcEncounterScheduling.affections.get(NPC_ID, 0)) < 0
		else "偶遇")
	for attempt in 5:
		if _next_roll(candidate.npcEncounterScheduling) > chance:
			break
		# Only Bai Ren is available to this legacy branch; source still draws
		# the uniform selection index after every successful chance check.
		_next_roll(candidate.npcEncounterScheduling)
		var card := _project_card(candidate, npc, scene, location)
		if card.is_empty():
			break
		if not candidate.get("cardsPlayed", []).has(card.id):
			candidate.npcEncounterScheduling.queuedCard = card
			break
	return candidate


func tick_schedule(state: Dictionary, turn: int) -> Dictionary:
	var npc: Dictionary = _definition(_content.read_module(MODULE))
	if npc.is_empty() or state.get("realm") not in npc.get("appearRealms", []) \
			or npc.get("pathRestriction") != state.get("path"):
		return state
	var continuity: Dictionary = state.get("worldContinuityState", {})
	var presence: Dictionary = continuity.get("npcs", {}).get(NPC_ID, {})
	if presence.get("lifecycle") != "ACTIVE" or presence.get("manifestation") != "PHYSICAL":
		return state
	var schedule: Dictionary = npc.get("schedule", {})
	var location := String(schedule.get(PERIODS[floori(maxi(0, turn) / 6.0) % 6],
		npc.get("defaultLocation", "")))
	if location.is_empty() or presence.get("locationId") == location:
		return state
	var candidate: Dictionary = state.duplicate(true)
	continuity = candidate.get("worldContinuityState", {})
	presence = continuity.get("npcs", {}).get(NPC_ID, {})
	continuity["revision"] = int(continuity.get("revision", 0)) + 1
	presence["locationId"] = location
	presence["changedByNode"] = "npc_schedule"
	var old_metadata := legacy_schedule_metadata and not state.has(
		"worldContinuityActivationIndex")
	presence["changedAtTurn"] = turn + 1 if old_metadata else turn
	if old_metadata:
		presence["reason"] = "schedule"
	presence["revision"] = continuity.revision
	continuity["npcs"][NPC_ID] = presence
	candidate["worldContinuityState"] = continuity
	return candidate


func take(state: Dictionary) -> Dictionary:
	if state.get("phase") != "FLOW_PENDING" or not validate_marker(state):
		return {}
	if state.npcEncounterScheduling.has("generalActivationIndex"):
		return _take_general(state)
	var queued: Variant = state.npcEncounterScheduling.get("queuedCard")
	if not queued is Dictionary:
		return {}
	var card: Dictionary = queued
	var selector: Dictionary = card.get("npcEncounter", {})
	var expected := _project_card(state, _definition(_content.read_module(MODULE)),
		String(selector.get("scene", "")), String(selector.get("location", "")))
	if expected.is_empty() or JSON.parse_string(JSON.stringify(expected)) != \
			JSON.parse_string(JSON.stringify(card)):
		last_error = "NPC 待发卡与来源不符"
		return {}
	var candidate: Dictionary = state.duplicate(true)
	candidate["npcEncounterScheduling"].erase("queuedCard")
	candidate["pendingNpcCard"] = card
	candidate["currentCardId"] = card.id
	candidate["phase"] = "NPC_PENDING"
	candidate["decisionCheckpoint"] = {"version": 1, "cardId": card.id,
		"sourceCardId": state.get("decisionCheckpoint", {}).get("sourceCardId"),
		"turn": candidate.turn, "decisionIndex": candidate.runClock.decisionIndex,
		"flowSource": "narrative:30", "lifeId": candidate.runClock.lifeId,
		"npcEncounter": card.npcEncounter.duplicate(true)}
	return candidate


func card(state: Dictionary) -> Dictionary:
	if state.get("phase") != "NPC_PENDING" or not validate_marker(state):
		return {}
	if state.npcEncounterScheduling.has("generalActivationIndex"):
		return _card_general(state)
	var snapshot: Dictionary = state.get("pendingNpcCard", {})
	var selector: Dictionary = snapshot.get("npcEncounter", {})
	var source := _definition(_content.read_module(MODULE))
	var expected := _project_card(state, source, String(selector.get("scene", "")),
		String(selector.get("location", "")))
	return expected if not expected.is_empty() \
		and JSON.parse_string(JSON.stringify(expected)) == \
			JSON.parse_string(JSON.stringify(snapshot)) \
		and state.get("currentCardId") == expected.id else {}


func settle(state: Dictionary, direction: String) -> Dictionary:
	if state.get("npcEncounterScheduling", {}).has("generalActivationIndex"):
		return _settle_general(state, direction)
	var source_card := card(state)
	if source_card.is_empty() or not source_card.choices.has(direction):
		return {}
	var candidate: Dictionary = state.duplicate(true)
	var choice: Dictionary = source_card.choices[direction]
	var effects: Dictionary = choice.get("effects", {})
	var apply := MilestoneFlow.new(_content)
	for key in effects:
		if not apply._apply_effect(candidate, String(key), effects[key]):
			return {}
	var marker_value: Dictionary = candidate.npcEncounterScheduling
	var prior := int(candidate.get("npcAffection", {}).get(NPC_ID,
		marker_value.affections.get(NPC_ID, 0))) if candidate.has(
			"choiceEchoState") else int(marker_value.affections.get(NPC_ID, 0))
	var affection := clampi(prior + int(choice.npcAffection), -50, 100)
	marker_value["affections"][NPC_ID] = affection
	if candidate.has("choiceEchoState"):
		var root_affections: Dictionary = candidate.get("npcAffection", {})
		root_affections[NPC_ID] = affection
		candidate["npcAffection"] = root_affections
	for index in range([0, 30, 55, 75, 90, 100].size() - 1, -1, -1):
		if affection >= [0, 30, 55, 75, 90, 100][index] \
				and int(marker_value.bonds.get(NPC_ID, 0)) < index:
			marker_value["bonds"][NPC_ID] = index
			break
	var memories: Array = marker_value.memories.get(NPC_ID, [])
	memories.append({"turn": int(candidate.turn), "action": "遭遇",
		"reaction": choice.text, "affectionDelta": int(choice.npcAffection)})
	if memories.size() > 20:
		memories.pop_front()
	marker_value["memories"][NPC_ID] = memories
	candidate["npcEncounterScheduling"] = marker_value
	var base := int(candidate.turn)
	var next_index := base + 1
	candidate["choiceHistory"].append({"cardId": source_card.id,
		"cardType": "NPC_ENCOUNTER", "direction": direction,
		"turn": base, "decisionIndex": next_index, "tags": []})
	while candidate["choiceHistory"].size() > 30:
		candidate["choiceHistory"].pop_front()
	candidate["cardsPlayed"].append(source_card.id)
	candidate["turn"] = next_index
	candidate["runClock"]["decisionIndex"] = next_index
	var token := "decision:%s:choice:%s:%d" % [candidate.runClock.lifeId,
		source_card.id, next_index]
	if candidate.runClock.receipts.has(token):
		return {}
	candidate["runClock"]["receipts"][token] = {"token": token,
		"decisionIndex": next_index, "sourceCardId": source_card.id,
		"kind": "choice"}
	MilestoneFlow.tick_seeds(candidate)
	candidate.erase("pendingNpcCard")
	candidate["currentCardId"] = ""
	candidate["phase"] = "FLOW_PENDING"
	candidate["decisionCheckpoint"] = {"version": 1, "cardId": null,
		"sourceCardId": source_card.id, "turn": next_index,
		"decisionIndex": next_index, "flowPending": true}
	return candidate


func _collect_general(state: Dictionary) -> Dictionary:
	var source: Variant = _content.read_module(MODULE)
	if not source is Dictionary:
		last_error = "NPC 全人物日程来源不可用"
		return {}
	var candidate: Dictionary = state.duplicate(true)
	if candidate.npcEncounterScheduling.get("queuedCard") is Dictionary:
		return candidate
	if _encounter_limit_reached(candidate.npcEncounterScheduling):
		return candidate
	var available: Array = []
	for npc in source.get("npcs", []):
		if not npc is Dictionary or candidate.get("realm") not in npc.get("appearRealms", []) \
				or npc.get("pathRestriction", candidate.get("path")) != candidate.get("path"):
			continue
		var npc_id := String(npc.get("id", ""))
		if not _physical_current_life(candidate, npc_id):
			continue
		var schedule: Dictionary = _general_schedule(npc, candidate)
		var location := String(schedule.get("location", ""))
		if location.is_empty():
			continue
		if npc.get("schedule") is Dictionary:
			_set_general_location(candidate, npc_id, location, "npc_schedule")
		if not _locations_compatible(String(candidate.get("currentLocation", "")), location):
			continue
		var memories: Array = candidate.npcEncounterScheduling.memories.get(npc_id, [])
		if not memories.is_empty() and int(candidate.get("turn", 0)) - int(
				memories.back().get("turn", 0)) < 15:
			continue
		available.append({"npc": npc, "location": location})
	if available.is_empty():
		return candidate
	var chance := 0.15 + float(candidate.get("attributes", {}).get("fortune", 0)) / 1000.0
	for attempt in 5:
		if _next_roll(candidate.npcEncounterScheduling) > chance:
			break
		var index := mini(int(_next_roll(candidate.npcEncounterScheduling) * available.size()),
			available.size() - 1)
		var selected: Dictionary = available[index]
		var npc: Dictionary = selected.npc
		var npc_id := String(npc.id)
		var affection := int(candidate.get("npcAffection", {}).get(npc_id,
			candidate.npcEncounterScheduling.affections.get(npc_id, 0)))
		var scene := "重逢" if affection >= 60 else "对峙" if affection < 0 else \
			"初见" if candidate.npcEncounterScheduling.memories.get(npc_id, []).is_empty() else "偶遇"
		var card_value := _general_card(candidate, npc_id, scene,
			String(selected.location), String(candidate.npcEncounterScheduling.emotions.get(
				npc_id, "平静")))
		if card_value.is_empty():
			break
		if not candidate.get("cardsPlayed", []).has(card_value.id):
			candidate.npcEncounterScheduling.queuedCard = card_value
			break
	return candidate


func _encounter_limit_reached(marker_value: Dictionary) -> bool:
	var total := 0
	for raw in marker_value.get("memories", {}).values():
		if raw is Array:
			total += raw.size()
	return total >= 6


func _general_schedule(npc: Dictionary, state: Dictionary) -> Dictionary:
	var period: String = PERIODS[floori(maxi(0, int(state.get("turn", 0))) / 6.0) % 6]
	return {"location": npc.get("schedule", {}).get(period,
		npc.get("defaultLocation", ""))}


func _set_general_location(state: Dictionary, npc_id: String, location: String,
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


func _physical_current_life(state: Dictionary, npc_id: String) -> bool:
	var presence: Dictionary = state.get("worldContinuityState", {}).get(
		"npcs", {}).get(npc_id, {})
	return presence.get("lifecycle") == "ACTIVE" \
		and presence.get("manifestation") == "PHYSICAL" \
		and int(presence.get("lifeId", -1)) == int(state.get("lifeCount", 0))


func _general_card(state: Dictionary, npc_id: String, scene: String,
		location: String, emotion: String) -> Dictionary:
	var templates := _templates()
	var path := String(state.get("path", ""))
	var normalized_emotion := emotion if emotion in ["忧心", "欣喜"] else "平静"
	var template: Variant = templates.get("templates", {}).get(npc_id, {}).get(
		path, {}).get(scene, {}).get(normalized_emotion)
	if not template is Dictionary:
		return {}
	var card_id := "npc_encounter_%s_%s" % [npc_id, scene]
	var source: Dictionary = _content.find("generated_card", card_id)
	var variant: Dictionary = source.get("variants", {}).get(path, {}).get(
		normalized_emotion, {})
	if source.get("npcId") != npc_id or source.get("scene") != scene \
			or source.get("sourceSha256") != SOURCE_JS_SHA \
			or source.get("derivedCatalogSha256") != TEMPLATE_SHA \
			or variant.get("pointer") != "$.templates.%s.%s.%s.%s" % [
				npc_id, path, scene, normalized_emotion] \
			or variant.get("card") != template:
		last_error = "NPC 生成卡来源登记不符"
		return {}
	var card_value: Dictionary = template.duplicate(true)
	card_value.description = String(card_value.description).replace("@@LOCATION@@", location)
	card_value.location = location
	card_value.realm = state.get("realm")
	card_value.npcEncounter.location = location
	card_value["_flowSource"] = "narrative:30"
	card_value["_flowPhase"] = "BUILDUP"
	return card_value


func _take_general(state: Dictionary) -> Dictionary:
	var queued: Variant = state.npcEncounterScheduling.get("queuedCard")
	if not queued is Dictionary:
		return {}
	var candidate: Dictionary = state.duplicate(true)
	candidate.npcEncounterScheduling.erase("queuedCard")
	var selector: Dictionary = queued.get("npcEncounter", {})
	var npc_id := String(selector.get("npcId", ""))
	if not _physical_current_life(candidate, npc_id):
		return candidate
	var expected := _general_card(candidate, npc_id, String(selector.get("scene", "")),
		String(selector.get("location", "")), String(selector.get("emotion", "")))
	if expected.is_empty() or JSON.parse_string(JSON.stringify(expected)) != \
			JSON.parse_string(JSON.stringify(queued)):
		last_error = "全人物 NPC 待发卡与来源不符"
		return {}
	candidate.pendingNpcCard = queued
	candidate.currentCardId = queued.id
	candidate.phase = "NPC_PENDING"
	candidate.decisionCheckpoint = {"version": 1, "cardId": queued.id,
		"sourceCardId": state.get("decisionCheckpoint", {}).get("sourceCardId"),
		"turn": candidate.turn, "decisionIndex": candidate.runClock.decisionIndex,
		"flowSource": "narrative:30", "lifeId": candidate.runClock.lifeId,
		"npcEncounter": queued.npcEncounter.duplicate(true)}
	return candidate


func _card_general(state: Dictionary) -> Dictionary:
	var snapshot: Variant = state.get("pendingNpcCard")
	if not snapshot is Dictionary or state.get("currentCardId") != snapshot.get("id"):
		return {}
	var selector: Dictionary = snapshot.get("npcEncounter", {})
	var npc_id := String(selector.get("npcId", ""))
	if not _physical_current_life(state, npc_id):
		return {}
	var expected := _general_card(state, npc_id, String(selector.get("scene", "")),
		String(selector.get("location", "")), String(selector.get("emotion", "")))
	return expected if not expected.is_empty() and JSON.parse_string(
		JSON.stringify(expected)) == JSON.parse_string(JSON.stringify(snapshot)) else {}


func _settle_general(state: Dictionary, direction: String) -> Dictionary:
	var source_card := card(state)
	if source_card.is_empty() or not source_card.choices.has(direction):
		return {}
	var candidate: Dictionary = state.duplicate(true)
	var choice: Dictionary = source_card.choices[direction]
	var apply := MilestoneFlow.new(_content)
	for key in choice.get("effects", {}):
		if not apply._apply_effect(candidate, String(key), choice.effects[key]):
			return {}
	var npc_id := String(source_card.npcId)
	var marker_value: Dictionary = candidate.npcEncounterScheduling
	var prior := int(candidate.get("npcAffection", {}).get(npc_id,
		marker_value.affections.get(npc_id, 0)))
	var affection := clampi(prior + int(choice.get("npcAffection", 0)), -50, 100)
	marker_value.affections[npc_id] = affection
	var root: Dictionary = candidate.get("npcAffection", {})
	root[npc_id] = affection
	candidate.npcAffection = root
	if candidate.has("npcCrossState") and candidate.npcCrossState.get(
			"affections", {}).has(npc_id):
		candidate.npcCrossState.affections[npc_id] = affection
	for index in range([0, 30, 55, 75, 90, 100].size() - 1, -1, -1):
		if affection >= [0, 30, 55, 75, 90, 100][index] \
				and int(marker_value.bonds.get(npc_id, 0)) < index:
			marker_value.bonds[npc_id] = index
			break
	var memories: Array = marker_value.memories.get(npc_id, [])
	memories.append({"turn": int(candidate.turn), "action": "遭遇",
		"reaction": choice.text, "affectionDelta": int(choice.get("npcAffection", 0))})
	if memories.size() > 20:
		memories.pop_front()
	marker_value.memories[npc_id] = memories
	var base := int(candidate.turn)
	var next_index := base + 1
	candidate.choiceHistory.append({"cardId": source_card.id,
		"cardType": "NPC_ENCOUNTER", "direction": direction,
		"turn": base, "decisionIndex": next_index, "tags": []})
	while candidate.choiceHistory.size() > 30:
		candidate.choiceHistory.pop_front()
	candidate.cardsPlayed.append(source_card.id)
	candidate.turn = next_index
	candidate.runClock.decisionIndex = next_index
	var token := "decision:%s:choice:%s:%d" % [candidate.runClock.lifeId,
		source_card.id, next_index]
	if candidate.runClock.receipts.has(token):
		return {}
	candidate.runClock.receipts[token] = {"token": token,
		"decisionIndex": next_index, "sourceCardId": source_card.id,
		"kind": "choice"}
	MilestoneFlow.tick_seeds(candidate)
	candidate.erase("pendingNpcCard")
	candidate.currentCardId = ""
	candidate.phase = "FLOW_PENDING"
	candidate.decisionCheckpoint = {"version": 1, "cardId": null,
		"sourceCardId": source_card.id, "turn": next_index,
		"decisionIndex": next_index, "flowPending": true}
	return candidate


func _definition(source: Variant) -> Dictionary:
	if not source is Dictionary:
		return {}
	for raw in source.get("npcs", []):
		if raw is Dictionary and raw.get("id") == NPC_ID:
			return raw
	return {}


func _next_roll(marker_value: Dictionary) -> float:
	var state_value := int(marker_value.get("rngState", 1))
	state_value = int((int(state_value) * 48271) % 2147483647)
	marker_value["rngState"] = state_value
	var index := int(marker_value.get("rollCursor", 0))
	marker_value["rollCursor"] = index + 1
	var tape: Array = marker_value.get("rollTape", [])
	return float(tape[index]) if index < tape.size() else float(state_value) / 2147483647.0


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


func _project_card(state: Dictionary, npc: Dictionary, scene: String,
		location: String) -> Dictionary:
	if npc.is_empty() or scene not in ["初见", "偶遇", "重逢", "对峙"] \
			or not _locations_compatible(String(state.get("currentLocation", "")), location):
		return {}
	var name := String(npc.get("name", ""))
	var title := ""
	var description := ""
	var choices := {}
	var affection := int(state.get("npcEncounterScheduling", {}).get(
		"affections", {}).get(NPC_ID, 0))
	if scene == "初见":
		title = "初见" + name
		description = "你在%s遇到了一位修士——%s%s。%s\n\n\"剑修……好。青云剑宗又多了一把好剑。\"" % [
			location, String(npc.get("title", "")), name,
			String(npc.get("firstMeeting", ""))]
		choices = {"left": {"text": "恭敬行礼", "effects": {"daoHeart": 5},
			"npcAffection": 5}, "right": {"text": "傲然以对",
			"effects": {"cultivation": 3, "karmaBad": 3}, "npcAffection": -3}}
	elif scene == "偶遇":
		title = "偶遇" + name
		var emotion := String(state.npcEncounterScheduling.emotions.get(NPC_ID, "平静"))
		var mood := "ta看起来心事重重。" if emotion == "忧心" else (
			"ta看起来心情不错。" if emotion == "欣喜" else "ta对你微微点头。")
		description = "在%s，你又一次遇到了%s。%s ta的目光在你身上停留——剑修的气息掩饰不住。" % [location, name, mood]
		choices = {"left": {"text": "上前问候", "effects": {"daoHeart": 3},
			"npcAffection": 3}, "right": {"text": "匆匆离去", "effects": {},
			"npcAffection": -1}}
	elif scene == "重逢":
		title = "故人" + name
		description = "%s在%s远远看到你，露出了一丝笑意。\"最近修行如何？你的剑修气息更浓了。\"" % [name, location]
		choices = {"left": {"text": "汇报修炼所得",
			"effects": {"cultivation": 5, "daoHeart": 3}, "npcAffection": 5},
			"right": {"text": "请教困惑",
			"effects": {"cultivation": 8, "daoHeart": -2}, "npcAffection": 8}}
	else:
		title = "冷遇" + name
		description = "%s看到你，面色微沉。空气似乎也冷了几分。ta的目光在你身上停留——剑修的气息掩饰不住。" % name
		choices = {"left": {"text": "低头避开", "effects": {"daoHeart": -3},
			"npcAffection": 0}, "right": {"text": "直视对方",
			"effects": {"daoHeart": 5, "karmaBad": 3}, "npcAffection": -5}}
	var card := {"id": "npc_encounter_%s_%s" % [NPC_ID, scene],
		"semanticKey": "npc-encounter:%s:%s" % [NPC_ID, scene],
		"title": title, "description": description, "type": "NPC_ENCOUNTER",
		"realm": state.get("realm"), "npcId": NPC_ID,
		"manifestation": "PHYSICAL", "location": location,
		"requiresPlayerPresence": true,
		"eligibleRealms": npc.get("appearRealms", []).duplicate(true),
		"weight": 0, "once": true,
		"npcEncounter": {"version": 1, "npcId": NPC_ID,
			"scene": scene, "location": location,
			"emotion": state.get("npcEncounterScheduling", {}).get(
				"emotions", {}).get(NPC_ID, "平静")},
		"choices": choices, "_flowSource": "narrative:30",
		"_flowPhase": "BUILDUP"}
	if affection < -50:
		return {}
	return card
