extends RefCounted

const Repository = preload("res://scripts/noncombat_content_repository.gd")
const LegacyFragmentFlow = preload("res://scripts/noncombat_legacy_fragment_flow.gd")
const MilestoneFlow = preload("res://scripts/noncombat_milestone_flow.gd")
const TreasureAcquisition = preload("res://scripts/noncombat_treasure_acquisition.gd")
const MODULE := "echoes:echo_templates"
const RULE_SHA := "9b98f72a08ee2e02e87a8cd4b8277dc693ed4dcc9afbb6c77469e67c72c87db5"
const SEED_CARD_TYPES := ["COMPANION_ARC", "COMPANION_EVENT", "MENTOR_ARC",
	"ALLY_ARC", "SEER_ARC"]
const REALMS := ["qi", "foundation", "golden", "nascent", "deity", "tribulation"]
const GENERIC_TEXTS := [
	"%s看到你，眼神里有一丝不易察觉的温度——仿佛想起了什么。",
	"风吹过%s，%s的目光在你身上停留了片刻。",
	"你注意到%s的动作比以前从容了些。时间改变了很多事，也包括你们之间的距离。",
	"%s没有开口，但你从ta的神情里读到了某种确认——就像多年前的那天一样。",
]

var last_error := ""
var _content: RefCounted
var _treasures: RefCounted

func _init(content: RefCounted = null) -> void:
	_content = content if content != null else Repository.new()
	_treasures = TreasureAcquisition.new(_content)

func marker(activation_index: int) -> Dictionary:
	var sha: String = _content.source_sha256(MODULE)
	if sha.length() != 64:
		last_error = "人物回响模板来源不可用"
		return {}
	return {"version": 1, "activationIndex": activation_index,
		"ruleSha": RULE_SHA, "sourceSha": sha, "nextSequence": 0}

func valid(state: Dictionary) -> bool:
	var rule: Variant = state.get("choiceEchoState")
	if not rule is Dictionary or rule.get("version") != 1 \
			or rule.get("ruleSha") != RULE_SHA \
			or rule.get("sourceSha") != _content.source_sha256(MODULE) \
			or not _integer(rule.get("nextSequence")) \
			or int(rule.get("nextSequence", -1)) < 0 \
			or not state.get("choiceEchoes") is Array:
		last_error = "人物回响状态或来源指纹不符"
		return false
	return true

func plant(candidate: Dictionary, card: Dictionary,
		direction: String) -> bool:
	last_error = ""
	if card.get("type") not in SEED_CARD_TYPES:
		return true
	if not valid(candidate):
		return false
	var choice: Variant = card.get("choices", {}).get(direction)
	if not choice is Dictionary or not choice.get("text") is String \
			or String(card.get("id", "")).is_empty():
		last_error = "人物回响原选择无效"
		return false
	var template_doc: Variant = _content.read_module(MODULE)
	if not template_doc is Dictionary:
		last_error = "人物回响模板不可用"
		return false
	var npc_id := String(card.get("npcId", ""))
	var affection := _affection(candidate, npc_id)
	var chosen: Dictionary = {}
	var group: Variant = template_doc.get(npc_id, {})
	if group is Dictionary:
		for row in group.get("echoTemplates", []):
			if not row is Dictionary:
				return false
			if row.has("triggerCardId") and row.triggerCardId != card.id \
					or row.has("triggerChoice") and row.triggerChoice != direction \
					or int(row.get("minAffection", 0)) > affection \
					or int(row.get("minTurnGap", 0)) > 0 and int(candidate.get("turn", 0)) == 0:
				continue
			chosen = row
			break
	var sequence := int(candidate["choiceEchoState"]["nextSequence"])
	var location := String(candidate.get("currentLocation", "未知"))
	var gap := int(chosen.get("minTurnGap", 15)) if not chosen.is_empty() else 15
	var echo := {"id": "echo_%s_%d_%d" % [candidate.runClock.lifeId,
		int(candidate.runClock.decisionIndex), sequence],
		"turn": int(candidate.get("turn", 0)), "realm": candidate.get("realm", "qi"),
		"cardId": card.id, "choice": direction, "choiceLabel": choice.text,
		"context": {"npcId": npc_id if not npc_id.is_empty() else null,
			"affection": affection, "location": location, "cardType": card.type},
		"echoConditions": {"minTurnGap": gap,
			"minAffection": int(chosen.get("minAffection", 0)),
			"npcAlive": chosen.get("npcAlive", true) if not chosen.is_empty() \
				else not npc_id.is_empty(),
			"location": chosen.get("location") if not chosen.is_empty() else location,
			"minRealm": chosen.get("minRealm") if not chosen.is_empty() else null},
		"templateId": chosen.get("id") if not chosen.is_empty() else null,
		"genericIndex": sequence % GENERIC_TEXTS.size(), "triggered": false}
	candidate["choiceEchoes"].append(echo)
	candidate["choiceEchoState"]["nextSequence"] = sequence + 1
	return true

func take(state: Dictionary) -> Dictionary:
	last_error = ""
	if state.get("phase") != "FLOW_PENDING" or not valid(state):
		return {}
	for index in state["choiceEchoes"].size():
		var echo: Variant = state["choiceEchoes"][index]
		if not echo is Dictionary or echo.get("triggered") == true \
				or not _conditions_met(state, echo):
			continue
		var card_value: Dictionary = _project(echo)
		if card_value.is_empty():
			last_error = "人物回响卡投影失败"
			return {}
		var candidate := state.duplicate(true)
		candidate["choiceEchoes"][index]["triggered"] = true
		candidate["pendingEchoCard"] = card_value
		candidate["phase"] = "CHOICE_ECHO_PENDING"
		candidate["currentCardId"] = card_value.id
		candidate["decisionCheckpoint"] = {"version": 1,
			"cardId": card_value.id,
			"sourceCardId": state.get("decisionCheckpoint", {}).get("sourceCardId"),
			"turn": state.get("turn"),
			"decisionIndex": state.get("runClock", {}).get("decisionIndex"),
			"flowSource": "choice_echo", "echoIndex": index}
		return candidate
	return {}

func card(state: Dictionary) -> Dictionary:
	last_error = ""
	if state.get("phase") != "CHOICE_ECHO_PENDING" or not valid(state):
		return {}
	var index := int(state.get("decisionCheckpoint", {}).get("echoIndex", -1))
	if index < 0 or index >= state["choiceEchoes"].size():
		return {}
	var echo: Variant = state["choiceEchoes"][index]
	if not echo is Dictionary or echo.get("triggered") != true:
		return {}
	var canonical: Dictionary = _project(echo)
	return canonical if JSON.parse_string(JSON.stringify(canonical)) \
		== JSON.parse_string(JSON.stringify(state.get("pendingEchoCard"))) \
		and canonical.get("id") == state.get("currentCardId") else {}

func settle(state: Dictionary, direction: String) -> Dictionary:
	last_error = ""
	var current: Dictionary = card(state)
	if current.is_empty() or direction not in ["left", "right"] \
			or not current.get("choices", {}).has(direction):
		return {}
	var choice: Dictionary = current.choices[direction]
	var effects: Variant = choice.get("effects", {})
	if not effects is Dictionary:
		return {}
	var candidate := state.duplicate(true)
	for key in effects:
		var value: Variant = effects[key]
		if key == "find_clue":
			if not value is String or String(value).is_empty():
				return {}
			var clues: Array = candidate.get("clues", [])
			if not clues.any(func(row: Variant) -> bool:
				return row is Dictionary and row.get("id") == value):
				clues.append({"id": value, "source": current.id,
					"turn": int(candidate.get("turn", 0)),
					"life": int(candidate.get("lifeCount", 0))})
			candidate["clues"] = clues
		elif key == "treasure":
			if not value is String or not _treasures.acquire(candidate, String(value),
					String(current.id), int(candidate.runClock.decisionIndex) + 1,
					{"source": "narrative_effect", "channel": null,
					"sourceId": current.id, "details": {"direction": direction},
					"transactionId": "treasure:narrative:life:%s:decision:%d:source:%s:item:%s" % [
						candidate.runClock.lifeId, int(candidate.runClock.decisionIndex) + 1,
						current.id, value]}):
				last_error = _treasures.last_error
				return {}
		elif key in ["wisdom", "sword_insight"] and _integer(value):
			var knowledge: Dictionary = candidate.get("knowledge", {})
			var kind := "sword" if key == "sword_insight" else "wisdom"
			knowledge[kind] = maxi(0, int(knowledge.get(kind, 0)) + int(value))
			candidate["knowledge"] = knowledge
		elif String(key).begins_with("bond_") and _integer(value):
			_add_affection(candidate, String(key).trim_prefix("bond_"), int(value))
		elif key in ["cultivation", "fortune", "daoHeart", "health",
				"karmaGood", "karmaBad"] and _integer(value):
			var maximum := 100
			if key == "health":
				maximum = LegacyFragmentFlow.actual_max_health(candidate)
			elif key == "daoHeart":
				maximum = LegacyFragmentFlow.actual_max_dao_heart(candidate)
			elif key == "cultivation":
				var realms: Variant = _content.read_module("config:realms")
				var threshold: Variant = realms.get("realms", {}).get(
					String(candidate.get("realm", "qi")), {}).get(
						"cultivationThreshold") if realms is Dictionary else null
				if not _integer(threshold) or int(threshold) <= 0:
					last_error = "回响修为境界上限来源不可用"
					return {}
				maximum = int(threshold)
			candidate["attributes"][key] = clampi(int(candidate["attributes"].get(key, 0))
				+ LegacyFragmentFlow.effective_delta(candidate, key, int(value)), 0, maximum)
		elif key == "combat_skill" and _integer(value):
			var modifiers: Dictionary = candidate.get("modifiers", {})
			modifiers["combat_skill"] = int(modifiers.get("combat_skill", 0)) + int(value)
			candidate["modifiers"] = modifiers
		else:
			last_error = "人物回响效果尚无消费者：" + String(key)
			return {}
	var companion: Variant = choice.get("companionEffects")
	if companion is Dictionary:
		if companion.get("type") != "affection" or not _integer(companion.get("value")):
			return {}
		_add_affection(candidate, String(companion.get("id", "")), int(companion.value))
	var next_index := int(state.runClock.decisionIndex) + 1
	var receipt := "decision:%s:choice:%s:%d" % [state.runClock.lifeId,
		current.id, next_index]
	if candidate.runClock.receipts.has(receipt):
		return {}
	candidate.runClock.receipts[receipt] = {"token": receipt,
		"decisionIndex": next_index, "sourceCardId": current.id, "kind": "choice"}
	var record := {"cardId": current.id, "cardType": "CHOICE_ECHO",
		"direction": direction, "turn": next_index - 1,
		"decisionIndex": next_index,
		"tags": current.tags.duplicate(true)}
	if not candidate.has("replayHistory"):
		candidate["replayHistory"] = candidate.get("choiceHistory", []).duplicate(true)
	candidate["replayHistory"].append(record.duplicate(true))
	candidate["choiceHistory"].append(record)
	while candidate["choiceHistory"].size() > 30:
		candidate["choiceHistory"].pop_front()
	for tag in current.tags:
		candidate["recentCardTags"].append(tag)
	while candidate["recentCardTags"].size() > 20:
		candidate["recentCardTags"].pop_front()
	candidate["cardsPlayed"].append(current.id)
	candidate["turn"] = next_index
	candidate["runClock"]["decisionIndex"] = next_index
	MilestoneFlow.tick_seeds(candidate)
	candidate.erase("pendingEchoCard")
	candidate["currentCardId"] = ""
	candidate["phase"] = "FLOW_PENDING"
	candidate["decisionCheckpoint"] = {"version": 1, "cardId": null,
		"sourceCardId": current.id, "turn": next_index,
		"decisionIndex": next_index, "flowPending": true}
	return candidate

func _conditions_met(state: Dictionary, echo: Dictionary) -> bool:
	var condition: Dictionary = echo.get("echoConditions", {})
	var context: Dictionary = echo.get("context", {})
	var raw_npc_id: Variant = context.get("npcId")
	var npc_id := String(raw_npc_id) if raw_npc_id is String else ""
	if int(state.get("turn", 0)) - int(echo.get("turn", 0)) < int(
			condition.get("minTurnGap", 15)):
		return false
	if int(condition.get("minAffection", 0)) > 0 and not npc_id.is_empty() \
			and _affection(state, npc_id) < int(
				condition.minAffection):
		return false
	if condition.get("npcAlive", false) and not npc_id.is_empty() \
			and state.get("deadNpcs", []).has(npc_id):
		return false
	if condition.get("location") != null and condition.location != state.get(
			"currentLocation"):
		return false
	var minimum := String(condition.get("minRealm")) if condition.get("minRealm") != null \
		else ""
	if not minimum.is_empty() and REALMS.has(minimum) \
			and REALMS.find(String(state.get("realm", "qi"))) < REALMS.find(minimum):
		return false
	return true

func _project(echo: Dictionary) -> Dictionary:
	var context: Dictionary = echo.get("context", {})
	var template_id := String(echo.get("templateId")) if echo.get("templateId") != null \
		else ""
	var template: Dictionary = {}
	if not template_id.is_empty():
		var document: Variant = _content.read_module(MODULE)
		if not document is Dictionary:
			return {}
		var group: Variant = document.get(String(context.get("npcId", "")), {})
		if not group is Dictionary:
			return {}
		for row in group.get("echoTemplates", []):
			if row is Dictionary and row.get("id") == template_id:
				template = row
				break
		if template.is_empty():
			return {}
	var label := String(echo.get("choiceLabel", ""))
	var base := {"id": "echo_" + String(echo.get("id", "")),
		"type": "CHOICE_ECHO", "npcId": context.get("npcId"),
		"originTurn": echo.get("turn"), "originChoice": label,
		"once": true, "weight": 0,
		"tags": ["echo", "memory", "choice_echo"]}
	if not template.is_empty():
		base["title"] = "%d轮前，你说:\"%s\"" % [int(echo.get("turn", 0)), label]
		base["description"] = template.get("echoText")
		base["choices"] = template.get("echoChoices", {}).duplicate(true)
		return base
	var raw_npc_id: Variant = context.get("npcId")
	var npc_name := _npc_name(String(raw_npc_id) if raw_npc_id is String else "")
	var raw_location: Variant = context.get("location")
	var location := String(raw_location) if raw_location is String else "这里"
	var index := posmod(int(echo.get("genericIndex", 0)), GENERIC_TEXTS.size())
	var text_value := ""
	match index:
		0: text_value = GENERIC_TEXTS[0] % npc_name
		1: text_value = GENERIC_TEXTS[1] % [location, npc_name]
		2: text_value = GENERIC_TEXTS[2] % npc_name
		3: text_value = GENERIC_TEXTS[3] % npc_name
	base["title"] = "%d轮前，你选择了:\"%s\"" % [int(echo.get("turn", 0)), label]
	base["description"] = text_value
	base["choices"] = {"left": {"text": "微笑回应", "effects": {"daoHeart": 2},
		"companionEffects": {"id": context.get("npcId"),
			"type": "affection", "value": 3} if context.get("npcId") != null else null},
		"right": {"text": "移开目光", "effects": {}, "companionEffects": null}}
	return base

func _npc_name(npc_id: String) -> String:
	if npc_id.is_empty():
		return ""
	var document: Variant = _content.read_module("npcs:core")
	if document is Dictionary:
		for row in document.get("npcs", []):
			if row is Dictionary and row.get("id") == npc_id:
				return String(row.get("name", npc_id))
	return npc_id

func _add_affection(state: Dictionary, npc_id: String, amount: int) -> void:
	if npc_id.is_empty():
		return
	var affections: Dictionary = state.get("npcAffection", {})
	var next_value := clampi(_affection(state, npc_id) + amount, -50, 100)
	affections[npc_id] = next_value
	state["npcAffection"] = affections
	if npc_id == "bai_ren" and state.get("npcEncounterScheduling") is Dictionary:
		var scheduling: Dictionary = state["npcEncounterScheduling"]
		if scheduling.get("affections") is Dictionary:
			scheduling["affections"][npc_id] = next_value
			if scheduling.get("bonds") is Dictionary:
				for index in range([0, 30, 55, 75, 90, 100].size() - 1, -1, -1):
					if next_value >= [0, 30, 55, 75, 90, 100][index] \
							and int(scheduling["bonds"].get(npc_id, 0)) < index:
						scheduling["bonds"][npc_id] = index
						break
			state["npcEncounterScheduling"] = scheduling

func _affection(state: Dictionary, npc_id: String) -> int:
	var root: Variant = state.get("npcAffection")
	if root is Dictionary and root.has(npc_id):
		return int(root[npc_id])
	if npc_id == "bai_ren" and state.get("npcEncounterScheduling") is Dictionary:
		var scheduled: Dictionary = state["npcEncounterScheduling"]
		if scheduled.get("affections") is Dictionary \
				and scheduled["affections"].has(npc_id):
			return int(scheduled["affections"][npc_id])
	return 0

func _integer(value: Variant) -> bool:
	return value is int or value is float and value == floorf(value)
