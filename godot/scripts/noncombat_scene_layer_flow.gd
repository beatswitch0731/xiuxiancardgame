extends RefCounted

const Repository = preload("res://scripts/noncombat_content_repository.gd")
const LegacyFragmentFlow = preload("res://scripts/noncombat_legacy_fragment_flow.gd")
const PathSkillFlow = preload("res://scripts/noncombat_path_skill_flow.gd")
const MilestoneFlow = preload("res://scripts/noncombat_milestone_flow.gd")
const TreasureAcquisition = preload("res://scripts/noncombat_treasure_acquisition.gd")
const MODULE := "locations:locations"
const RULE_SHA := "117095af9b888cdf6ae27c9fd6f25629aa53f652dc4be13969a64d408112df6f"
const DEEP_LAYER_INTERVAL := 8

var last_error := ""
var _content: RefCounted
var _treasures: RefCounted

func _init(content: RefCounted = null) -> void:
	_content = content if content != null else Repository.new()
	_treasures = TreasureAcquisition.new(_content)

func marker(activation_index: int) -> Dictionary:
	var sha: String = _content.source_sha256(MODULE)
	if sha.length() != 64:
		last_error = "地点来源不可用"
		return {}
	return {"version": 1, "activationIndex": activation_index,
		"ruleSha": RULE_SHA, "sourceSha": sha, "triggeredCards": []}

func valid(state: Dictionary) -> bool:
	var scene: Variant = state.get("sceneLayerState")
	if not scene is Dictionary or scene.get("version") != 1 \
			or scene.get("ruleSha") != RULE_SHA \
			or scene.get("sourceSha") != _content.source_sha256(MODULE) \
			or not scene.get("triggeredCards") is Array:
		last_error = "地点状态或来源指纹不符"
		return false
	return true

func visit(state: Dictionary) -> Dictionary:
	last_error = ""
	if not valid(state) or state.get("phase") != "FLOW_PENDING":
		return {}
	var candidate := state.duplicate(true)
	var location := String(candidate.get("currentLocation", ""))
	if location.is_empty():
		return candidate
	var locations: Dictionary = candidate.get("locationStates", {})
	var local: Dictionary = locations.get(location, {"visits": 0,
		"layer": 1, "eventFlags": []})
	local["visits"] = int(local.get("visits", 0)) + 1
	locations[location] = local
	candidate["locationStates"] = locations
	if int(local["visits"]) < 3 or int(local.get("layer", 1)) >= 3 \
			or int(local["visits"]) % DEEP_LAYER_INTERVAL != 0:
		return candidate
	local["layer"] = int(local.get("layer", 1)) + 1
	var document: Variant = _content.read_module(MODULE)
	if not document is Dictionary or not document.get("cards") is Array:
		last_error = "地点卡来源无效"
		return {}
	var available: Array = []
	for row in document["cards"]:
		if row is Dictionary and row.get("location") == location \
				and row.get("layer") == local["layer"] \
				and not candidate["sceneLayerState"]["triggeredCards"].has(row.get("id")):
			available.append(row)
	if available.is_empty():
		return candidate
	# The current authored catalog has one card per location and layer. A future
	# multi-card layer needs a persisted draw receipt before it can be admitted.
	if available.size() != 1:
		last_error = "地点层多卡抽样尚未迁移"
		return {}
	var selected: Dictionary = available[0]
	var card_id := String(selected.get("id", ""))
	if card_id.is_empty() or _card_by_id(card_id).is_empty():
		last_error = "地点卡或素材不可用"
		return {}
	candidate["sceneLayerState"]["triggeredCards"].append(card_id)
	candidate["phase"] = "LOCATION_PENDING"
	candidate["currentCardId"] = card_id
	candidate["decisionCheckpoint"] = {"version": 1, "cardId": card_id,
		"sourceCardId": state.get("decisionCheckpoint", {}).get("sourceCardId"),
		"turn": candidate.get("turn"),
		"decisionIndex": candidate.get("runClock", {}).get("decisionIndex"),
		"flowSource": "location_scene"}
	return candidate

func card(state: Dictionary) -> Dictionary:
	last_error = ""
	if state.get("phase") != "LOCATION_PENDING" or not valid(state):
		return {}
	var card_id := String(state.get("currentCardId", ""))
	if not state["sceneLayerState"]["triggeredCards"].has(card_id):
		return {}
	return _card_by_id(card_id)

func settle(state: Dictionary, direction: String) -> Dictionary:
	last_error = ""
	var current := card(state)
	if current.is_empty() or direction not in ["left", "right"] \
			or not current.get("choices", {}).has(direction):
		return {}
	var effects: Variant = current.choices[direction].get("effects")
	if not effects is Dictionary:
		return {}
	var candidate := state.duplicate(true)
	var path_skill = PathSkillFlow.new(_content)
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
					"sourceId": current.id, "details": {},
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
			var npc_id := String(key).trim_prefix("bond_")
			var affections: Dictionary = candidate.get("npcAffection", {})
			affections[npc_id] = clampi(int(affections.get(npc_id, 0)) + int(value), -50, 100)
			candidate["npcAffection"] = affections
		elif key in ["cultivation", "fortune", "daoHeart", "health", "karmaBad"] and _integer(value):
			var maximum := path_skill.actual_max_health(candidate) if key == "health" else (
				LegacyFragmentFlow.actual_max_dao_heart(candidate) if key == "daoHeart" else 100)
			var amount := path_skill.effect_delta(candidate, String(key), int(value),
				String(current.id), int(candidate.runClock.decisionIndex) + 1)
			if not path_skill.last_error.is_empty():
				return {}
			candidate["attributes"][key] = clampi(int(candidate["attributes"].get(key, 0))
				+ LegacyFragmentFlow.effective_delta(candidate, key, amount), 0, maximum)
		else:
			last_error = "地点效果尚无消费者：" + String(key)
			return {}
	var next_index := int(state.runClock.decisionIndex) + 1
	var receipt := "decision:%s:choice:%s:%d" % [state.runClock.lifeId,
		current.id, next_index]
	if candidate.runClock.receipts.has(receipt):
		return {}
	candidate.runClock.receipts[receipt] = {"token": receipt,
		"decisionIndex": next_index, "sourceCardId": current.id, "kind": "choice"}
	var record := {"cardId": current.id, "cardType": "LOCATION",
		"direction": direction, "turn": next_index - 1,
		"decisionIndex": next_index,
		"tags": current.get("tags", []).duplicate(true)}
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
	candidate["currentCardId"] = ""
	candidate["phase"] = "FLOW_PENDING"
	candidate["decisionCheckpoint"] = {"version": 1, "cardId": null,
		"sourceCardId": current.id, "turn": next_index,
		"decisionIndex": next_index, "flowPending": true}
	return candidate

func _card_by_id(card_id: String) -> Dictionary:
	var document: Variant = _content.read_module(MODULE)
	if not document is Dictionary or not document.get("cards") is Array:
		return {}
	for row in document["cards"]:
		if row is Dictionary and row.get("id") == card_id:
			var status: Dictionary = _content.asset_status(String(row.get("sceneImage", "")))
			return row.duplicate(true) if status.get("shaVerified", false) \
				and status.get("textureLoadable", false) else {}
	return {}

func _integer(value: Variant) -> bool:
	return value is int or value is float and value == floorf(value)
