extends RefCounted

const Repository = preload("res://scripts/noncombat_content_repository.gd")
const LegacyFragmentFlow = preload("res://scripts/noncombat_legacy_fragment_flow.gd")
const MilestoneFlow = preload("res://scripts/noncombat_milestone_flow.gd")
const TreasureAcquisition = preload("res://scripts/noncombat_treasure_acquisition.gd")
const RULE_SHA := "08cd0d1ac24caeae35629210a0f2de0a24a563c7e3c4ea2da3ffe346f8f0a1e4"
const EVENTS := "companions:events"

var last_error := ""
var _content: RefCounted
var _treasures: RefCounted

func _init(content: RefCounted = null) -> void:
	_content = content if content != null else Repository.new()
	_treasures = TreasureAcquisition.new(_content)

func marker(activation_index: int) -> Dictionary:
	var event_sha: String = _content.source_sha256(EVENTS)
	if event_sha.length() != 64:
		last_error = "叙事浮现人物来源不可用"
		return {}
	return {"version": 1, "activationIndex": activation_index,
		"ruleSha": RULE_SHA, "eventSha": event_sha,
		"lastCheckTurn": 0, "lastResolved": {}}

func valid(state: Dictionary) -> bool:
	var rule: Variant = state.get("narrativeSurfacingState")
	if not rule is Dictionary or rule.get("version") != 1 \
			or rule.get("ruleSha") != RULE_SHA \
			or rule.get("eventSha") != _content.source_sha256(EVENTS) \
			or not _integer(rule.get("lastCheckTurn")) \
			or not rule.get("lastResolved") is Dictionary:
		last_error = "叙事浮现状态或来源指纹不符"
		return false
	return true

func take(state: Dictionary) -> Dictionary:
	last_error = ""
	if state.get("phase") != "FLOW_PENDING" or not valid(state):
		return {}
	var turn := int(state.get("turn", 0))
	var rule: Dictionary = state["narrativeSurfacingState"]
	if turn % 5 != 0 or turn - int(rule.lastCheckTurn) < 5:
		return {}
	var candidate := state.duplicate(true)
	candidate["narrativeSurfacingState"]["lastCheckTurn"] = turn
	var projected := _world_card(candidate)
	if projected.is_empty():
		projected = _karma_card(candidate)
	if projected.is_empty():
		projected = _affection_card(candidate)
	if projected.is_empty():
		return candidate
	var last_resolved := int(rule.lastResolved.get(projected.id, -1000))
	if turn - last_resolved < 12:
		return candidate
	if projected.has("compId"):
		var flags: Dictionary = candidate.get("flags", {})
		flags["surface_pushed_%s_20" % projected.compId] = true
		candidate["flags"] = flags
	candidate["pendingSurfacingCard"] = projected
	candidate["phase"] = "SURFACING_PENDING"
	candidate["currentCardId"] = projected.id
	candidate["decisionCheckpoint"] = {"version": 1, "cardId": projected.id,
		"sourceCardId": state.get("decisionCheckpoint", {}).get("sourceCardId"),
		"turn": turn, "decisionIndex": state.get("runClock", {}).get("decisionIndex"),
		"flowSource": "narrative_surfacing"}
	return candidate

func card(state: Dictionary) -> Dictionary:
	if state.get("phase") != "SURFACING_PENDING" or not valid(state):
		return {}
	var card_id := String(state.get("currentCardId", ""))
	var projected := _world_card(state) if card_id == "surface_bairen_memory" else (
		_karma_card(state) if card_id == "surface_karma_burden" else
		_affection_card(state, true, String(state.get("pendingSurfacingCard", {}).get(
			"compId", ""))))
	return projected if not projected.is_empty() and projected.get("id") == card_id \
		and JSON.parse_string(JSON.stringify(projected)) == JSON.parse_string(
			JSON.stringify(state.get("pendingSurfacingCard"))) else {}

func choice_available(state: Dictionary, direction: String) -> bool:
	return not card(state).is_empty() and direction in ["left", "right"]

func settle(state: Dictionary, direction: String) -> Dictionary:
	last_error = ""
	var current := card(state)
	if current.is_empty() or not choice_available(state, direction):
		return {}
	var candidate := state.duplicate(true)
	var choice: Dictionary = current.choices[direction]
	for key in choice.effects:
		var value: Variant = choice.effects[key]
		if key == "treasure":
			if not value is String or not _treasures.acquire(candidate, String(value),
					current.id, int(candidate.runClock.decisionIndex) + 1,
					{"source": "narrative_effect", "channel": null,
					"sourceId": current.id, "details": {"direction": direction},
					"transactionId": "treasure:narrative:life:%s:decision:%d:source:%s:item:%s" % [
					candidate.runClock.lifeId, int(candidate.runClock.decisionIndex) + 1,
					current.id, value]}):
				last_error = _treasures.last_error
				return {}
		elif key in ["cultivation", "daoHeart", "fortune", "karmaGood"] \
				and _integer(value):
			var maximum := 100
			if key == "daoHeart":
				maximum = LegacyFragmentFlow.actual_max_dao_heart(candidate)
			elif key == "cultivation":
				var realms: Variant = _content.read_module("config:realms")
				var threshold: Variant = realms.get("realms", {}).get(
					String(candidate.get("realm", "qi")), {}).get(
					"cultivationThreshold") if realms is Dictionary else null
				if not _integer(threshold) or int(threshold) <= 0:
					last_error = "叙事浮现境界上限来源不可用"
					return {}
				maximum = int(threshold)
			candidate["attributes"][key] = clampi(int(candidate["attributes"].get(key, 0)) \
				+ LegacyFragmentFlow.effective_delta(candidate, key, int(value)), 0, maximum)
		else:
			last_error = "叙事浮现效果尚无消费者：" + String(key)
			return {}
	var companion_effect: Variant = choice.get("companionEffects")
	if companion_effect is Dictionary:
		var npc_id := String(companion_effect.get("compId", ""))
		if npc_id.is_empty() or not _integer(companion_effect.get("affectionDelta")):
			return {}
		var affections: Dictionary = candidate.get("npcAffection", {})
		affections[npc_id] = clampi(int(affections.get(npc_id, 0)) \
			+ int(companion_effect.affectionDelta), -50, 100)
		candidate["npcAffection"] = affections
	var next_index := int(state.runClock.decisionIndex) + 1
	var receipt := "decision:%s:choice:%s:%d" % [state.runClock.lifeId,
		current.id, next_index]
	if candidate.runClock.receipts.has(receipt):
		return {}
	candidate.runClock.receipts[receipt] = {"token": receipt,
		"decisionIndex": next_index, "sourceCardId": current.id, "kind": "choice"}
	var record := {"cardId": current.id, "cardType": "SURFACING",
		"direction": direction, "turn": next_index - 1,
		"decisionIndex": next_index, "tags": current.get("tags", []).duplicate(true)}
	if not candidate.has("replayHistory"):
		candidate["replayHistory"] = candidate.get("choiceHistory", []).duplicate(true)
	candidate["replayHistory"].append(record.duplicate(true))
	candidate["choiceHistory"].append(record)
	while candidate["choiceHistory"].size() > 30:
		candidate["choiceHistory"].pop_front()
	for tag in current.get("tags", []):
		candidate["recentCardTags"].append(tag)
	while candidate["recentCardTags"].size() > 20:
		candidate["recentCardTags"].pop_front()
	candidate["cardsPlayed"].append(current.id)
	candidate["turn"] = next_index
	candidate["runClock"]["decisionIndex"] = next_index
	MilestoneFlow.tick_seeds(candidate)
	candidate["narrativeSurfacingState"]["lastResolved"][current.id] = next_index
	candidate.erase("pendingSurfacingCard")
	candidate["currentCardId"] = ""
	candidate["phase"] = "FLOW_PENDING"
	candidate["decisionCheckpoint"] = {"version": 1, "cardId": null,
		"sourceCardId": current.id, "turn": next_index,
		"decisionIndex": next_index, "flowPending": true}
	return candidate

func _world_card(state: Dictionary) -> Dictionary:
	var bairen: Variant = state.get("worldContinuityState", {}).get("npcs", {}).get(
		"bairen_zhenren")
	if not bairen is Dictionary or bairen.get("lifecycle") != "DEAD" \
			or int(state.get("turn", 0)) - int(bairen.get("changedAtTurn", -1000)) != 3:
		return {}
	var card := {"id": "surface_bairen_memory", "title": "白刃的遗产",
		"description": "今天路过剑冢时——一把剑自己出鞘了。不是你的剑。是白刃真人的。它悬在空中，剑尖指向你，没有敌意——像是一个遗愿。剑身上映出了白刃真人最后一次舞剑的残影——那是他教你的第一式。也是最后一批学员的第一式。\\n\\n他没有弟子了——只有你。",
		"type": "SURFACING", "realm": state.get("realm", "qi"),
		"choices": {"left": {"text": "接过剑——继承剑道传承",
			"effects": {"cultivation": 15, "daoHeart": 20, "treasure": "白刃遗剑"}},
			"right": {"text": "让剑回剑冢——和师父一起安息",
			"effects": {"daoHeart": 20, "karmaGood": 15}}}}
	return _registered_fixed_card(card, "_checkWorldChange", "_world_card")

func _karma_card(state: Dictionary) -> Dictionary:
	var seeds: Variant = state.get("karmaSeeds", [])
	if not seeds is Array or seeds.size() < 4:
		return {}
	var card := {"id": "surface_karma_burden", "title": "肩上的重量",
		"description": "你感到双肩沉重——不是肉体上的，是因果上的。%d颗因果种子在你识海中沉睡——每一颗都是一件未了的事、一笔未清的账。它们不吵不闹，但它们在那里——你知道它们在那里。" % seeds.size(),
		"type": "SURFACING", "realm": state.get("realm", "qi"),
		"tags": ["surfacing", "karma"],
		"choices": {"left": {"text": "坦然面对——「该来的总会来」",
			"effects": {"daoHeart": 10, "fortune": 5}},
			"right": {"text": "暂时放下——专注当下",
			"effects": {"cultivation": 10, "daoHeart": -3}}}}
	return _registered_fixed_card(card, "_checkKarmaSurface", "_karma_card")

func _registered_fixed_card(card: Dictionary, browser: String,
		godot: String) -> Dictionary:
	var row: Dictionary = _content.find("generated_card", String(card.id))
	return card if row.get("data", {}).get("id") == card.id \
		and row.get("sourcePath") == "src/systems/StoryNetworkSystem.js" \
		and row.get("sourceSha256") == RULE_SHA \
		and row.get("sourceSymbol") == "NarrativeSurfacing." + browser \
		and row.get("producerGodot") == "res://scripts/noncombat_narrative_surfacing.gd::" + godot else {}

func _affection_card(state: Dictionary, allow_pushed: bool = false,
		only_id: String = "") -> Dictionary:
	var active: Variant = state.get("resources", {}).get("companions", [])
	var progress: Variant = state.get("companionProgress", {}).get("states", {})
	if not active is Array or not progress is Dictionary:
		return {}
	for comp_id in active:
		if not comp_id is String or not progress.has(comp_id) \
				or not only_id.is_empty() and comp_id != only_id:
			continue
		if not _affection_companion_physical(state, String(comp_id)):
			continue
		var affection := int(state.get("npcAffection", {}).get(comp_id, 0))
		if affection < 18 or affection >= 20 or not allow_pushed \
				and state.get("flags", {}).get("surface_pushed_%s_20" % comp_id, false):
			continue
		var name := _companion_name(String(comp_id))
		var card := {"id": "surface_%s_near_20" % comp_id,
			"title": "%s的眼神" % name,
			"description": "你注意到%s最近看你的方式有些不一样——不是奇怪，是更专注了。ta在你说话时不会走神了——这在以前很常见。ta记得你前天说过的一句无关紧要的话——这种记忆对于一个修士来说很不寻常。\\n\\n也许ta自己都没意识到。但你意识到了。" % name,
			"type": "SURFACING", "realm": state.get("realm", "qi"),
			"compId": comp_id,
			"choices": {"left": {"text": "回应这份关注——多陪陪ta",
				"effects": {"daoHeart": 8, "fortune": 5},
				"companionEffects": {"compId": comp_id, "affectionDelta": 5}},
				"right": {"text": "装作没注意到",
				"effects": {"daoHeart": 5}}}}
		return _registered_affection_card(card, String(comp_id))
	return {}

func _affection_companion_physical(state: Dictionary, comp_id: String) -> bool:
	if state.get("deadNpcs", []).has(comp_id):
		return false
	var world: Variant = state.get("worldContinuityState")
	# Pre-registry Godot saves retain the earlier deadNpcs-only admission.
	if not world is Dictionary:
		return true
	if world.get("version") != 1 or world.get("lifeId") != state.get("lifeCount", 0):
		return false
	var row: Variant = world.get("npcs", {}).get(comp_id)
	return row is Dictionary and row.get("npcId") == comp_id \
		and row.get("lifeId") == world.get("lifeId") \
		and row.get("lifecycle") == "ACTIVE" \
		and row.get("manifestation") == "PHYSICAL"

func _registered_affection_card(card: Dictionary, comp_id: String) -> Dictionary:
	var row: Dictionary = _content.find("generated_card", String(card.id))
	return card if row.get("data", {}).get("id") == card.id \
		and row.get("companionId") == comp_id \
		and row.get("sourcePath") == "src/systems/StoryNetworkSystem.js" \
		and row.get("sourceSha256") == RULE_SHA \
		and row.get("sourceSymbol") == "NarrativeSurfacing._checkAffectionSurface" \
		and row.get("npcSourcePath") == "data/npcs/core_npcs.json" \
		and row.get("npcSourceSha256") == _content.source_sha256("npcs:core") \
		and row.get("producerGodot") == "res://scripts/noncombat_narrative_surfacing.gd::_affection_card" else {}

func _companion_name(comp_id: String) -> String:
	var document: Variant = _content.read_module(EVENTS)
	if document is Dictionary:
		for row in document.get("companions", []):
			if row is Dictionary and row.get("id") == comp_id:
				return String(row.get("name", comp_id))
	return comp_id

func _integer(value: Variant) -> bool:
	return (value is int or value is float) and float(value) == floor(float(value))
