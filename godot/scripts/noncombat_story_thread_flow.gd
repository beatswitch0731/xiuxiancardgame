extends RefCounted

# First source-backed StoryThread consumer: the two-node spirit mine line.
# State is current-life data; authored cards and variants stay in qi_threads.json.
const LegacyFragmentFlow = preload("res://scripts/noncombat_legacy_fragment_flow.gd")
const PathSkillFlow = preload("res://scripts/noncombat_path_skill_flow.gd")
const MilestoneFlow = preload("res://scripts/noncombat_milestone_flow.gd")
const NormalChoicePolicy = preload("res://scripts/noncombat_normal_choice_policy.gd")
const ContentRepository = preload("res://scripts/noncombat_content_repository.gd")
const MODULE := "threads:qi_threads"
const THREAD_ID := "spirit_mine"
const TRIGGER_CARD := "q_spiritStone"

var _content: RefCounted
var _choice_policy: RefCounted
var _milestone_flow: RefCounted
var activation_index := 1
var last_error := ""
var _source_missing := false


func _init(content: RefCounted) -> void:
	_content = content
	_choice_policy = NormalChoicePolicy.new(content)
	_milestone_flow = MilestoneFlow.new(content)


func source_sha() -> String:
	return _content.source_sha256(MODULE)


func source_missing() -> bool:
	var path: String = _content.module_path(MODULE)
	return _source_missing or path.is_empty() or not FileAccess.file_exists(
		ContentRepository.CONTENT_ROOT + path)


func _definition() -> Dictionary:
	var doc: Variant = _content.read_module(MODULE)
	if not doc is Dictionary or not doc.get("threads") is Array:
		return {}
	for item in doc["threads"]:
		if item is Dictionary and item.get("threadId") == THREAD_ID:
			return item
	return {}


func tick(prior: Dictionary, candidate: Dictionary) -> bool:
	last_error = ""
	_source_missing = false
	if int(candidate.get("lifeCount", 0)) != 0:
		return true
	var decision := int(candidate.get("runClock", {}).get("decisionIndex", -1))
	if decision < activation_index or decision <= int(prior.get(
			"runClock", {}).get("decisionIndex", -1)):
		return true
	var sha := source_sha()
	var definition := _definition()
	if sha.length() != 64 or definition.get("trigger", {}).get("type") != "choice_match" \
			or definition.get("trigger", {}).get("cardId") != TRIGGER_CARD \
			or definition.get("trigger", {}).get("direction") != "right" \
			or not definition.get("nodes") is Array \
			or definition["nodes"].size() != 2:
		last_error = "spirit mine thread source invalid"
		return false
	var runtime: Dictionary = candidate.get("storyThreadState", {}).duplicate(true)
	if runtime.is_empty():
		runtime = {"version": 1, "lifeCount": 0,
			"activationIndex": activation_index, "sourceSha": sha,
			"threadId": THREAD_ID, "status": "inactive", "startedTurn": -1,
			"lastNodeTurn": -1, "nodeIndex": 0, "pendingNodeIndex": -1,
			"choices": [], "receipt": null}
	if runtime.get("version") != 1 or runtime.get("lifeCount") != 0 \
			or runtime.get("sourceSha") != sha \
			or runtime.get("activationIndex") != activation_index \
			or runtime.get("threadId") != THREAD_ID:
		last_error = "spirit mine thread runtime/source mismatch"
		return false
	if runtime.get("status") == "active" \
			and int(runtime.get("pendingNodeIndex", -1)) < 0 \
			and decision - int(runtime.get("startedTurn", decision)) > int(
				definition.get("timeoutTurns", 25)):
		runtime["status"] = "timeout"
		runtime["receipt"] = {"threadId": THREAD_ID, "status": "timeout",
			"closedTurn": decision, "completedTurn": null,
			"nodes": _receipt_nodes(runtime.get("choices", []))}
	if runtime.get("status") == "inactive" and decision >= 4:
		var trigger: Dictionary = definition["trigger"]
		for entry in candidate.get("choiceHistory", []):
			if entry is Dictionary and entry.get("cardId") == TRIGGER_CARD \
					and entry.get("direction") == "right" \
					and int(entry.get("decisionIndex", -1)) >= activation_index \
					and decision - int(entry.get("turn", decision)) >= int(trigger.get("delay", 0)):
				runtime["status"] = "active"
				runtime["startedTurn"] = decision
				runtime["lastNodeTurn"] = decision
				break
	candidate["storyThreadState"] = runtime
	return true


func resume(state: Dictionary) -> Dictionary:
	last_error = ""
	_source_missing = false
	if state.get("phase") != "FLOW_PENDING" or int(state.get("lifeCount", 0)) != 0:
		return {}
	var runtime: Dictionary = state.get("storyThreadState", {})
	if runtime.get("status") != "active" or int(runtime.get("pendingNodeIndex", -1)) >= 0:
		return {}
	var index := int(runtime.get("nodeIndex", -1))
	if index < 0 or index > 1 or int(state.get("turn", -1)) - int(
			runtime.get("lastNodeTurn", -1)) < 2:
		return {}
	var card := _node_card(state, index)
	if card.is_empty():
		last_error = "spirit mine pending node cannot be built"
		return {}
	var candidate := state.duplicate(true)
	candidate["storyThreadState"]["pendingNodeIndex"] = index
	candidate["pendingThreadCard"] = card
	candidate["currentCardId"] = card["id"]
	candidate["phase"] = "THREAD_PENDING"
	candidate["decisionCheckpoint"] = {"version": 1, "cardId": card["id"],
		"sourceCardId": state.get("decisionCheckpoint", {}).get("sourceCardId"),
		"turn": state["turn"], "decisionIndex": state["runClock"]["decisionIndex"],
		"flowSource": "story_thread", "threadId": THREAD_ID, "nodeIndex": index}
	return candidate


func card(state: Dictionary) -> Dictionary:
	last_error = ""
	_source_missing = false
	if state.get("phase") != "THREAD_PENDING":
		return {}
	var runtime: Dictionary = state.get("storyThreadState", {})
	var index := int(runtime.get("pendingNodeIndex", -1))
	var authoritative := _node_card(state, index)
	return authoritative if not authoritative.is_empty() \
		and JSON.parse_string(JSON.stringify(authoritative)) == \
		JSON.parse_string(JSON.stringify(state.get("pendingThreadCard", {}))) \
		and state.get("currentCardId") == authoritative.get("id") else {}


func choice_available(state: Dictionary, direction: String) -> bool:
	var current := card(state)
	var choice: Variant = current.get("choices", {}).get(direction)
	if not choice is Dictionary or not choice.get("effects") is Dictionary:
		return false
	var stone := int(choice["effects"].get("spiritStone", 0))
	return stone >= 0 or int(state.get("resources", {}).get("spiritStone", 0)) >= -stone


func settle_choice(state: Dictionary, direction: String) -> Dictionary:
	last_error = ""
	if not choice_available(state, direction):
		return {}
	var current := card(state)
	var runtime: Dictionary = state["storyThreadState"]
	var node_index := int(runtime["pendingNodeIndex"])
	var definition := _definition()
	var node: Dictionary = definition.get("nodes", [])[node_index]
	var choice: Dictionary = current["choices"][direction]
	var candidate := state.duplicate(true)
	for key in choice["effects"]:
		if not _apply_effect(candidate, String(key), choice["effects"][key],
				String(current.get("id", "")), int(state.runClock.decisionIndex) + 1):
			last_error = "spirit mine reward unsupported"
			return {}
	if not _choice_policy._apply_passive_regen(candidate):
		last_error = _choice_policy.last_error
		return {}
	var next_index := int(state["runClock"]["decisionIndex"]) + 1
	var receipt := "decision:%s:choice:%s:%d" % [state["runClock"]["lifeId"],
		current["id"], next_index]
	if candidate["runClock"]["receipts"].has(receipt):
		return {}
	candidate["runClock"]["receipts"][receipt] = {"token": receipt,
		"decisionIndex": next_index, "sourceCardId": current["id"], "kind": "choice"}
	var record := {"cardId": current["id"], "cardType": current.get("type"),
		"direction": direction, "turn": next_index - 1,
		"decisionIndex": next_index, "tags": current.get("tags", []).duplicate(true)}
	if not candidate.has("replayHistory"):
		candidate["replayHistory"] = candidate.get("choiceHistory", []).duplicate(true)
	candidate["replayHistory"].append(record.duplicate(true))
	candidate["choiceHistory"].append(record)
	while candidate["choiceHistory"].size() > 30:
		candidate["choiceHistory"].pop_front()
	candidate["cardsPlayed"].append(current["id"])
	candidate["turn"] = next_index
	candidate["runClock"]["decisionIndex"] = next_index
	if choice.has("karmaSeed") and not _milestone_flow._plant_seed(candidate,
			current, choice, direction, next_index):
		return {}
	MilestoneFlow.tick_seeds(candidate)
	var choice_row := {"nodeIndex": node_index, "nodeId": node["id"],
		"direction": direction, "threadDirection": choice.get(
			"threadDirection", direction), "turn": next_index}
	candidate["storyThreadState"]["choices"].append(choice_row)
	candidate["storyThreadState"]["pendingNodeIndex"] = -1
	candidate["storyThreadState"]["nodeIndex"] = node_index + 1
	candidate["storyThreadState"]["lastNodeTurn"] = next_index
	if node.get("phase") == "resolution":
		var complete: Dictionary = node.get("consequences", {}).get("onComplete", {})
		for flag in complete.get("worldFlags", []):
			candidate["flags"][flag] = true
		candidate["storyThreadState"]["status"] = "completed"
		candidate["storyThreadState"]["receipt"] = {"threadId": THREAD_ID,
			"status": "completed", "closedTurn": next_index,
			"completedTurn": next_index,
			"nodes": _receipt_nodes(candidate["storyThreadState"]["choices"])}
	candidate.erase("pendingThreadCard")
	candidate["phase"] = "FLOW_PENDING"
	candidate["currentCardId"] = ""
	candidate["decisionCheckpoint"] = {"version": 1, "cardId": null,
		"sourceCardId": current["id"], "turn": next_index,
		"decisionIndex": next_index, "flowPending": true}
	return candidate


func _node_card(state: Dictionary, index: int) -> Dictionary:
	var runtime: Dictionary = state.get("storyThreadState", {})
	if index < 0 or index > 1 or runtime.get("sourceSha") != source_sha() \
			or runtime.get("lifeCount") != 0:
		return {}
	var definition := _definition()
	if definition.get("threadId") != THREAD_ID:
		return {}
	var node: Dictionary = definition["nodes"][index]
	var current: Dictionary = node.get("card", {}).duplicate(true)
	if current.get("id") != "thread_spirit_mine_%d" % (index + 1) \
			or current.get("type") != "NORMAL" \
			or current.get("realm") != state.get("realm"):
		return {}
	if index > 0:
		var first: Dictionary = runtime.get("choices", [])[0] if not runtime.get(
			"choices", []).is_empty() else {}
		for variant in node.get("variants", []):
			if variant is Dictionary and variant.get("when", {}).get(
					"choiceDirections", {}).get("sm_arrival") == first.get("direction"):
				current["description"] = variant.get("card", {}).get(
					"description", current.get("description"))
				break
		current["description"] = "【%s】%s" % [definition["title"],
			current.get("description", "")]
	var image: Dictionary = _content.card_scene_image_status(String(current["id"]))
	if not image.get("shaVerified", false) or not image.get("textureLoadable", false) \
			or image.get("sceneImage") != current.get("sceneImage"):
		_source_missing = not image.get("listedInManifest", false) \
			or not image.get("fileExists", false)
		last_error = "灵矿故事原有场景图未通过校验"
		return {}
	return current


func _receipt_nodes(choices: Array) -> Array:
	var nodes: Array = []
	for accepted in choices:
		if accepted is Dictionary:
			nodes.append({"nodeId": accepted.get("nodeId"),
				"direction": accepted.get("direction"),
				"threadDirection": accepted.get("threadDirection"),
				"turn": accepted.get("turn")})
	return nodes


func _apply_effect(candidate: Dictionary, key: String, value: Variant,
		card_id: String = "", decision_index: int = -1) -> bool:
	if key == "pills" and value is String and not String(value).is_empty():
		var pills: Dictionary = candidate["resources"].get("pills", {})
		pills[value] = int(pills.get(value, 0)) + 1
		candidate["resources"]["pills"] = pills
		return true
	if not (value is int or value is float and value == floor(value)):
		return false
	var amount := int(value)
	var path_skill = PathSkillFlow.new(_content)
	if not card_id.is_empty():
		amount = path_skill.effect_delta(candidate, key, amount, card_id,
			decision_index)
		if not path_skill.last_error.is_empty():
			return false
	if key in ["spiritStone", "lifespan"]:
		candidate["resources"][key] = maxi(0, int(
			candidate["resources"].get(key, 0)) + amount)
		return true
	if key in ["cultivation", "daoHeart", "health", "fortune",
			"karmaGood", "karmaBad"]:
		amount = LegacyFragmentFlow.effective_delta(candidate, key, amount)
		var limit := 100
		if key == "daoHeart":
			limit = LegacyFragmentFlow.actual_max_dao_heart(candidate)
		elif key == "health":
			limit = path_skill.actual_max_health(candidate, decision_index)
			if not path_skill.last_error.is_empty():
				return false
		candidate["attributes"][key] = clampi(int(candidate["attributes"].get(
			key, 0)) + amount, 0, limit)
		return true
	return false
