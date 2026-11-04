extends "res://scripts/noncombat_story_thread_flow.gd"

# V1 remains the replay authority for saves written before multiple threads.
# Upgrade only on a new committed decision; do not insert new beats on reload.
const BASE_THREAD_IDS := ["spirit_mine", "herb_refugee"]
const VILLAGE_THREAD_ID := "abandoned_village"
const SWORD_THREAD_ID := "sword_tomb_trial"
const MIST_THREAD_ID := "mist_valley"
const LAST_LESSON_THREAD_ID := "bairen_last_lesson"
const LAST_LESSON_MODULE := "threads:last_lesson_threads"
const HIGHER_MODULES := {
	"tianshu_seal_echo": "threads:foundation_threads",
	"sect_shadow_register": "threads:foundation_threads",
	"core_heaven_tax": "threads:golden_threads",
	"nascent_dream_witness": "threads:nascent_threads",
	"deity_heaven_net": "threads:deity_threads",
	"tribulation_gate_testimony": "threads:tribulation_threads",
}
const HIGHER_THREAD_IDS := ["tianshu_seal_echo", "sect_shadow_register",
	"core_heaven_tax", "nascent_dream_witness", "deity_heaven_net",
	"tribulation_gate_testimony"]
const TreasureAcquisition = preload("res://scripts/noncombat_treasure_acquisition.gd")
const WorldContinuity = preload("res://scripts/noncombat_world_continuity.gd")
const COMBAT_THREAD_NODES := {"abandoned_village": 2, "sword_tomb_trial": 1,
	"bairen_last_lesson": 3}
const THREAD_IDS := ["spirit_mine", "herb_refugee", VILLAGE_THREAD_ID,
	SWORD_THREAD_ID, MIST_THREAD_ID, "tianshu_seal_echo", "sect_shadow_register",
	"core_heaven_tax", "nascent_dream_witness", "deity_heaven_net",
	"tribulation_gate_testimony", LAST_LESSON_THREAD_ID]
const SOURCE_JS_SHA := "a5f324bc2a1d8afbf63f3eb4aaf84042cb601041df3978e9cf277085d4be29b2"
const KARMA_JS_SHA := "0d977405787abc77d42712e1d3661412d3ca3983bdde5eca008263066acf3123"
var upgrade_index := 1
var village_activation_index := 1
var sword_activation_index := 1
var mist_activation_index := 1
var higher_activation_index := 1
var last_lesson_activation_index := 1


func _init(content: RefCounted) -> void:
	super(content)


func source_rule_pins() -> Dictionary:
	return {"storyThreads": SOURCE_JS_SHA, "karma": KARMA_JS_SHA}


func higher_source_pins() -> Dictionary:
	var pins := {}
	for module_id in HIGHER_MODULES.values():
		pins[module_id] = _content.source_sha256(String(module_id))
	return pins


func thread_state(state: Dictionary, thread_id: String) -> Dictionary:
	var bundle: Dictionary = state.get("storyThreadState", {})
	if bundle.get("version") == 1:
		return bundle if bundle.get("threadId") == thread_id else {}
	return bundle.get("threads", {}).get(thread_id, {})


func _definition_for(thread_id: String) -> Dictionary:
	var module_id := LAST_LESSON_MODULE if thread_id == LAST_LESSON_THREAD_ID else \
		String(HIGHER_MODULES.get(thread_id, MODULE))
	var doc: Variant = _content.read_module(module_id)
	if not doc is Dictionary:
		var path := String(_content.module_path(module_id))
		_source_missing = _source_missing or path.is_empty() or not FileAccess.file_exists(
			ContentRepository.CONTENT_ROOT + path)
		return {}
	for item in doc.get("threads", []):
		if item is Dictionary and item.get("threadId") == thread_id:
			return item
	return {}


func _empty_thread(thread_id: String) -> Dictionary:
	return {"threadId": thread_id, "status": "inactive", "startedTurn": -1,
		"lastNodeTurn": -1, "nodeIndex": 0, "pendingNodeIndex": -1,
		"choices": [], "receipt": null}


func _enabled_thread_ids(decision: int) -> Array:
	var enabled := BASE_THREAD_IDS.duplicate()
	if decision >= village_activation_index:
		enabled.append(VILLAGE_THREAD_ID)
	if decision >= sword_activation_index:
		enabled.append(SWORD_THREAD_ID)
	if decision >= mist_activation_index:
		enabled.append(MIST_THREAD_ID)
	if decision >= higher_activation_index:
		enabled.append_array(HIGHER_THREAD_IDS)
	if decision >= last_lesson_activation_index:
		enabled.append(LAST_LESSON_THREAD_ID)
	return enabled


func _upgrade_bundle(old: Dictionary, decision: int, life_count: int) -> Dictionary:
	var threads: Dictionary = {}
	for thread_id in _enabled_thread_ids(decision):
		threads[thread_id] = _empty_thread(thread_id)
	if old.get("version") == 1:
		for key in threads[THREAD_ID]:
			threads[THREAD_ID][key] = old.get(key, threads[THREAD_ID][key])
	var bundle := {"version": 2, "lifeCount": life_count, "activationIndex": activation_index,
		"upgradeIndex": upgrade_index, "sourceSha": source_sha(),
		"ruleSourcePins": source_rule_pins(),
		"lastTriggerTurn": maxi(0, int(old.get("startedTurn", 0))),
		"threads": threads}
	if decision >= village_activation_index:
		bundle["villageActivationIndex"] = village_activation_index
		bundle["villagePresentationSha"] = _content.source_sha256(
			"combat:migrated_presentations")
	if decision >= sword_activation_index:
		bundle["swordActivationIndex"] = sword_activation_index
	if decision >= mist_activation_index:
		bundle["mistActivationIndex"] = mist_activation_index
	if decision >= higher_activation_index:
		bundle["higherActivationIndex"] = higher_activation_index
		bundle["higherSourcePins"] = higher_source_pins()
	if decision >= last_lesson_activation_index:
		bundle["lastLessonActivationIndex"] = last_lesson_activation_index
		bundle["lastLessonSourceSha"] = _content.source_sha256(LAST_LESSON_MODULE)
	return bundle


func tick(prior: Dictionary, candidate: Dictionary) -> bool:
	last_error = ""
	_source_missing = false
	var decision := int(candidate.get("runClock", {}).get("decisionIndex", -1))
	if decision < activation_index or decision <= int(prior.get(
			"runClock", {}).get("decisionIndex", -1)):
		return true
	if decision < upgrade_index:
		return super.tick(prior, candidate)
	var bundle: Dictionary = candidate.get("storyThreadState", {}).duplicate(true)
	if bundle.is_empty() or bundle.get("version") == 1:
		bundle = _upgrade_bundle(bundle, decision, int(candidate.get("lifeCount", 0)))
	if decision >= village_activation_index and not bundle.has("villageActivationIndex"):
		bundle["villageActivationIndex"] = village_activation_index
		bundle["villagePresentationSha"] = _content.source_sha256(
			"combat:migrated_presentations")
		bundle["threads"][VILLAGE_THREAD_ID] = _empty_thread(VILLAGE_THREAD_ID)
	if decision >= sword_activation_index and not bundle.has("swordActivationIndex"):
		bundle["swordActivationIndex"] = sword_activation_index
		bundle["threads"][SWORD_THREAD_ID] = _empty_thread(SWORD_THREAD_ID)
	if decision >= mist_activation_index and not bundle.has("mistActivationIndex"):
		bundle["mistActivationIndex"] = mist_activation_index
		bundle["threads"][MIST_THREAD_ID] = _empty_thread(MIST_THREAD_ID)
	if decision >= higher_activation_index and not bundle.has("higherActivationIndex"):
		bundle["higherActivationIndex"] = higher_activation_index
		bundle["higherSourcePins"] = higher_source_pins()
		for thread_id in HIGHER_THREAD_IDS:
			bundle["threads"][thread_id] = _empty_thread(thread_id)
	if decision >= last_lesson_activation_index and not bundle.has("lastLessonActivationIndex"):
		bundle["lastLessonActivationIndex"] = last_lesson_activation_index
		bundle["lastLessonSourceSha"] = _content.source_sha256(LAST_LESSON_MODULE)
		bundle["threads"][LAST_LESSON_THREAD_ID] = _empty_thread(LAST_LESSON_THREAD_ID)
	if bundle.get("version") != 2 or bundle.get("lifeCount") != candidate.get("lifeCount", 0) \
			or bundle.get("activationIndex") != activation_index \
			or bundle.get("upgradeIndex") != upgrade_index \
			or bundle.get("ruleSourcePins") != source_rule_pins() \
			or bundle.get("sourceSha") != source_sha() \
			or String(bundle.get("sourceSha", "")).length() != 64 \
			or bundle.has("villageActivationIndex") and bundle.get(
				"villageActivationIndex") != village_activation_index \
			or bundle.has("villageActivationIndex") and bundle.get(
				"villagePresentationSha") != _content.source_sha256(
					"combat:migrated_presentations") \
			or bundle.has("villageActivationIndex") and String(bundle.get(
				"villagePresentationSha", "")).length() != 64 \
			or bundle.has("swordActivationIndex") and bundle.get(
				"swordActivationIndex") != sword_activation_index \
			or bundle.has("mistActivationIndex") and bundle.get(
				"mistActivationIndex") != mist_activation_index \
			or bundle.has("higherActivationIndex") and bundle.get(
				"higherActivationIndex") != higher_activation_index \
			or bundle.has("higherActivationIndex") and bundle.get(
				"higherSourcePins") != higher_source_pins():
		last_error = "故事线程进度与源数据版本不一致"
		return false
	if bundle.has("lastLessonActivationIndex") and bundle.get(
			"lastLessonActivationIndex") != last_lesson_activation_index \
			or bundle.has("lastLessonActivationIndex") and bundle.get(
				"lastLessonSourceSha") != _content.source_sha256(LAST_LESSON_MODULE):
		last_error = "故事线程进度与源数据版本不一致"
		return false
	var active := 0
	for thread_id in _enabled_thread_ids(decision):
		var definition := _definition_for(thread_id)
		if definition.is_empty() or not definition.get("nodes") is Array:
			last_error = "故事线程源数据未通过校验"
			return false
		var runtime: Dictionary = bundle.get("threads", {}).get(thread_id, {})
		if runtime.is_empty():
			return false
		if runtime.get("status") != "active":
			continue
		var closed := ""
		if not _realm_matches(definition, String(candidate.get("realm", ""))):
			closed = "realm_expired"
		elif int(runtime.get("pendingNodeIndex", -1)) < 0 \
				and decision - int(runtime["startedTurn"]) > int(definition.get(
					"timeoutTurns", 25)):
			closed = "timeout"
		if not closed.is_empty():
			_close_thread(runtime, closed, decision)
		else:
			active += 1
	if active < 2 and decision - int(bundle["lastTriggerTurn"]) >= 4:
		for thread_id in _enabled_thread_ids(decision):
			var runtime: Dictionary = bundle["threads"][thread_id]
			var definition := _definition_for(thread_id)
			if runtime["status"] == "inactive" \
					and _realm_matches(definition, String(candidate.get("realm", ""))) \
					and _requirements_match(definition.get("requirements", {}), candidate) \
					and _trigger_matches(definition.get("trigger", {}), candidate,
						village_activation_index if thread_id == VILLAGE_THREAD_ID else \
						sword_activation_index if thread_id == SWORD_THREAD_ID else \
						mist_activation_index if thread_id == MIST_THREAD_ID else \
						last_lesson_activation_index if thread_id == LAST_LESSON_THREAD_ID else 0):
				runtime["status"] = "active"
				runtime["startedTurn"] = decision
				runtime["lastNodeTurn"] = decision
				bundle["lastTriggerTurn"] = decision
				active += 1
				if active >= 2:
					break
	candidate["storyThreadState"] = bundle
	return true


func _trigger_matches(trigger: Dictionary, state: Dictionary,
		minimum_decision: int = 0) -> bool:
	if trigger.get("type") == "turn_count":
		var turn := int(state.get("turn", 0))
		return turn >= int(trigger.get("minTurn", 0)) \
			and (not trigger.has("maxTurn") or turn <= int(trigger.maxTurn))
	if trigger.get("type") == "realm_enter":
		return state.get("realm") == trigger.get("realm") and int(state.get(
			"turn", 0)) > int(trigger.get("minTurn", 0))
	if trigger.get("type") != "choice_match":
		return false
	var decision := int(state["runClock"]["decisionIndex"])
	for entry in state.get("choiceHistory", []):
		if entry is Dictionary and entry.get("cardId") == trigger.get("cardId") \
				and entry.get("direction") == trigger.get("direction") \
				and int(entry.get("decisionIndex", -1)) >= minimum_decision \
				and decision - int(entry.get("turn", decision)) >= int(trigger.get("delay", 0)) \
				and _required_dungeon_outcome_matches(trigger, state, entry):
			return true
	return false


func _requirements_match(requirements: Dictionary, state: Dictionary) -> bool:
	for quest_id in requirements.get("completedQuestIds", []):
		if not state.get("questState", {}).get("completedQuests", []).has(quest_id) \
				or state.get("questState", {}).get("questOutcomes", {}).get(
					quest_id) != "completed":
			return false
	var contracts: Variant = requirements.get("npcManifestations", [])
	if not contracts is Array:
		return false
	if not contracts.is_empty():
		var world_value: Variant = state.get("worldContinuityState")
		if not world_value is Dictionary:
			return false
		var world: Dictionary = world_value
		if world.get("version") != 1 or int(world.get("lifeId", -1)) != int(
				state.get("lifeCount", 0)):
			return false
		var npc_rows: Variant = world.get("npcs")
		if not npc_rows is Dictionary:
			return false
		for contract in contracts:
			if not contract is Dictionary or not contract.get("npcId") is String:
				return false
			var npc_id := String(contract.npcId)
			var expected := String(contract.get("manifestation", ""))
			var npc_value: Variant = npc_rows.get(npc_id)
			if not npc_value is Dictionary:
				return false
			var npc: Dictionary = npc_value
			if npc_id.is_empty() or expected not in ["PHYSICAL", "ECHO_ONLY"] \
					or npc.get("npcId") != npc_id \
					or int(npc.get("lifeId", -1)) != int(world.lifeId) \
					or npc.get("manifestation") != expected \
					or expected == "PHYSICAL" and npc.get("lifecycle") != "ACTIVE":
				return false
	return true


func _realm_matches(definition: Dictionary, realm: String) -> bool:
	var eligible: Variant = definition.get("eligibleRealms", [])
	if eligible is Array and not eligible.is_empty():
		return eligible.has(realm)
	return definition.get("realm") == realm


func _required_dungeon_outcome_matches(trigger: Dictionary, state: Dictionary,
		entry: Dictionary) -> bool:
	if not trigger.has("requiredDungeonOutcome"):
		return true
	var required: Variant = trigger["requiredDungeonOutcome"]
	if not required is Dictionary or required.get("dungeonId") != "ancientCave" \
			or required.get("outcome") != "success":
		return false
	for receipt in state.get("dungeonOutcomeReceipts", []):
		if receipt is Dictionary and receipt.get("lifeId") == state.get(
				"runClock", {}).get("lifeId") \
				and receipt.get("sourceCardId") == entry.get("cardId") \
				and receipt.get("sourceDecisionIndex") == entry.get("decisionIndex") \
				and receipt.get("dungeonId") == required["dungeonId"] \
				and receipt.get("outcome") == required["outcome"]:
			return true
	return false


func _close_thread(runtime: Dictionary, status: String, decision: int) -> void:
	runtime["status"] = status
	runtime["receipt"] = {"threadId": runtime["threadId"], "status": status,
		"closedTurn": decision, "completedTurn": decision if status == "completed" else null,
		"nodes": _receipt_nodes(runtime["choices"])}


func resume(state: Dictionary) -> Dictionary:
	if state.get("storyThreadState", {}).get("version") != 2:
		return super.resume(state)
	last_error = ""
	_source_missing = false
	if state.get("phase") != "FLOW_PENDING" or state.get(
			"storyThreadState", {}).get("lifeCount") != state.get("lifeCount", 0):
		return {}
	var selected := ""
	var selected_priority := -1
	var selected_turn := 2147483647
	var selected_pending := false
	var pending_candidates: Array[Dictionary] = []
	var eligible_candidates: Array[Dictionary] = []
	var highest_pending := -1
	var highest_eligible := -1
	for thread_id in THREAD_IDS:
		var runtime := thread_state(state, thread_id)
		if runtime.get("status") != "active":
			continue
		var pending := int(runtime.get("pendingNodeIndex", -1)) >= 0
		var index := int(runtime["pendingNodeIndex"] if pending else runtime["nodeIndex"])
		var definition := _definition_for(thread_id)
		var nodes: Array = definition.get("nodes", [])
		if index < 0 or index >= nodes.size():
			continue
		if not pending and not _node_eligible_for_state(nodes[index],
				runtime.get("choices", []), state):
			continue
		var gap := _required_node_gap(definition, nodes[index])
		if not pending and int(state["turn"]) - int(runtime["lastNodeTurn"]) < gap:
			continue
		var priority := int(definition.get("priority", 0))
		var started := int(runtime["startedTurn"])
		var candidate := {"threadId": thread_id, "priority": priority,
			"startedTurn": started}
		if pending:
			pending_candidates.append(candidate)
			highest_pending = maxi(highest_pending, priority)
		else:
			eligible_candidates.append(candidate)
			highest_eligible = maxi(highest_eligible, priority)
	selected_pending = not pending_candidates.is_empty() and not (
		highest_eligible >= 90 and highest_eligible > highest_pending)
	var candidates: Array[Dictionary] = pending_candidates if selected_pending else eligible_candidates
	for candidate in candidates:
		var priority: int = candidate["priority"]
		var started: int = candidate["startedTurn"]
		if selected.is_empty() or priority > selected_priority \
				or priority == selected_priority and started < selected_turn:
			selected = String(candidate["threadId"])
			selected_priority = priority
			selected_turn = started
	if selected.is_empty():
		return {}
	var runtime := thread_state(state, selected)
	var index := int(runtime["pendingNodeIndex"] if selected_pending else runtime["nodeIndex"])
	var current := _node_card_v2(state, selected, index)
	if current.is_empty():
		if last_error.is_empty():
			last_error = "故事线程节点无法从原内容构建"
		return {}
	var candidate := state.duplicate(true)
	candidate["storyThreadState"]["threads"][selected]["pendingNodeIndex"] = index
	candidate["pendingThreadCard"] = current
	candidate["currentCardId"] = current["id"]
	candidate["phase"] = "THREAD_PENDING"
	candidate["decisionCheckpoint"] = {"version": 1, "cardId": current["id"],
		"sourceCardId": state.get("decisionCheckpoint", {}).get("sourceCardId"),
		"turn": state["turn"], "decisionIndex": state["runClock"]["decisionIndex"],
		"flowSource": "story_thread", "threadId": selected, "nodeIndex": index}
	return candidate


func _required_node_gap(definition: Dictionary, node: Dictionary) -> int:
	var authored := maxi(0, int(node.get("minTurnsAfterPrevious", 0)))
	return authored if int(definition.get("priority", 0)) >= 90 else maxi(2, authored)


func _node_eligible_for_state(node: Dictionary, choices: Array,
		state: Dictionary) -> bool:
	var settled := {}
	for accepted in choices:
		if accepted is Dictionary and accepted.get("nodeId") is String:
			settled[accepted.nodeId] = true
	var eligibility: Dictionary = node.get("eligibility", {})
	for node_id in eligibility.get("requiredNodes", []):
		if not settled.has(node_id):
			return false
	for node_id in eligibility.get("forbiddenNodes", []):
		if settled.has(node_id):
			return false
	var card: Dictionary = node.get("card", {})
	var location: Variant = card.get("location")
	var requires_presence: bool = card.get("requiresPlayerPresence") == true
	for variant in node.get("variants", []):
		if variant is Dictionary and _matches_history(variant.get("when", {}), choices):
			location = variant.get("card", {}).get("location", location)
			requires_presence = variant.get("card", {}).get(
				"requiresPlayerPresence", requires_presence) == true
			break
	if requires_presence:
		var locations: Array = location if location is Array else [location]
		return locations.has(state.get("currentLocation")) and \
			state.get("currentLocation") != null
	return true


func card(state: Dictionary) -> Dictionary:
	if state.get("storyThreadState", {}).get("version") != 2:
		return super.card(state)
	last_error = ""
	_source_missing = false
	if state.get("phase") != "THREAD_PENDING":
		return {}
	var thread_id := String(state.get("decisionCheckpoint", {}).get("threadId", ""))
	var runtime := thread_state(state, thread_id)
	var current := _node_card_v2(state, thread_id, int(runtime.get("pendingNodeIndex", -1)))
	return current if not current.is_empty() and state.get("currentCardId") == current["id"] \
		and JSON.parse_string(JSON.stringify(current)) == JSON.parse_string(JSON.stringify(
			state.get("pendingThreadCard", {}))) else {}


func choice_available(state: Dictionary, direction: String) -> bool:
	if state.get("phase") == "THREAD_PENDING" and state.get(
			"currentCardId") == "thread_last_lesson_n3" and direction == "left":
		var current := card(state)
		return current.get("choices", {}).get("left", {}).get(
			"triggerCombat") == true and current.get("choices", {}).get(
				"left", {}).get("enemy", {}).get(
					"templateId") == "sword_intent_avatar_deity"
	if state.get("phase") == "THREAD_PENDING" and state.get(
			"currentCardId") == "thread_last_lesson_n2" and direction == "left":
		return card(state).get("choices", {}).get("left", {}).get(
			"action", {}).get("type") == "ENTER_VENDOR"
	if state.get("storyThreadState", {}).get("version") == 2 \
			and state.get("phase") == "THREAD_PENDING" \
			and state.get("currentCardId") in ["thread_ab_village_3", "thread_sword_tomb_2"]:
		var current := card(state)
		return not current.is_empty() and current.get("choices", {}).get(
			direction, {}).get("triggerCombat") == true
	return super.choice_available(state, direction)


func thread_combat_card(state: Dictionary) -> Dictionary:
	var thread_id := String(state.get("pendingThreadCard", {}).get("_threadId", ""))
	if not COMBAT_THREAD_NODES.has(thread_id):
		return {}
	var index := int(COMBAT_THREAD_NODES[thread_id])
	var runtime := thread_state(state, thread_id)
	var current := _node_card_v2(state, thread_id, index)
	var expected_id := "thread_ab_village_3" if thread_id == VILLAGE_THREAD_ID \
		else "thread_sword_tomb_2" if thread_id == SWORD_THREAD_ID \
		else "thread_last_lesson_n3"
	return current if runtime.get("pendingNodeIndex") == index \
		and current.get("id") == expected_id \
		and JSON.parse_string(JSON.stringify(current)) == JSON.parse_string(JSON.stringify(
			state.get("pendingThreadCard", {}))) else {}


func settle_combat(state: Dictionary, direction: String, outcome: String,
		decision: int) -> Dictionary:
	if direction not in ["left", "right"] or outcome not in ["victory", "defeat", "flee"] \
			or thread_combat_card(state).is_empty():
		return {}
	var candidate := state.duplicate(true)
	var thread_id := String(candidate["pendingThreadCard"]["_threadId"])
	var node_index := int(COMBAT_THREAD_NODES[thread_id])
	var runtime: Dictionary = candidate["storyThreadState"]["threads"][thread_id]
	if runtime.get("status") != "active" or runtime.get("nodeIndex") != node_index \
			or runtime.get("choices", []).size() != node_index:
		return {}
	var choice: Dictionary = candidate["pendingThreadCard"]["choices"][direction]
	var node_id := "ab_confrontation" if thread_id == VILLAGE_THREAD_ID \
		else "st_sword_fight" if thread_id == SWORD_THREAD_ID \
		else "ll_sword_dispute"
	runtime["choices"].append({"nodeIndex": node_index, "nodeId": node_id,
		"direction": direction, "threadDirection": choice.get("threadDirection", direction),
		"turn": decision, "outcomeContext": {"mode": "combat", "combatOutcome": outcome}})
	runtime["pendingNodeIndex"] = -1
	runtime["nodeIndex"] = node_index + 1
	runtime["lastNodeTurn"] = decision
	candidate.erase("pendingThreadCard")
	return candidate


func _node_card_v2(state: Dictionary, thread_id: String, index: int) -> Dictionary:
	var bundle: Dictionary = state.get("storyThreadState", {})
	var runtime := thread_state(state, thread_id)
	var definition := _definition_for(thread_id)
	var nodes: Array = definition.get("nodes", [])
	if thread_id not in THREAD_IDS or runtime.get("status") != "active" \
			or index < 0 or index >= nodes.size() or bundle.get("sourceSha") != source_sha():
		return {}
	if HIGHER_MODULES.has(thread_id):
		var module_id := String(HIGHER_MODULES[thread_id])
		if bundle.get("higherSourcePins", {}).get(module_id) != \
				_content.source_sha256(module_id):
			last_error = "高境界故事线程来源版本已变化"
			return {}
	if thread_id == LAST_LESSON_THREAD_ID and bundle.get(
			"lastLessonSourceSha") != _content.source_sha256(LAST_LESSON_MODULE):
		last_error = "最后一课故事线程来源版本已变化"
		return {}
	var node: Dictionary = nodes[index]
	var current: Dictionary = node.get("card", {}).duplicate(true)
	for variant in node.get("variants", []):
		if variant is Dictionary and _matches_history(variant.get("when", {}), runtime["choices"]):
			_merge_variant(current, variant.get("card", {}))
			if variant.has("id"):
				current["_threadVariantId"] = variant["id"]
			break
	_append_history_echoes(current, node, runtime["choices"])
	for echo in node.get("receiptEchoes", []):
		if not echo is Dictionary:
			continue
		var receipt := _completion_receipt(state, String(echo.get("threadId", "")))
		var matched: Dictionary = {}
		for entry in receipt.get("nodes", []):
			if entry is Dictionary and entry.get("nodeId") == echo.get("nodeId"):
				matched = entry
				break
		var echo_text := String(echo.get("directions", {}).get(
			matched.get("threadDirection"), echo.get("missing", "")))
		if not echo_text.strip_edges().is_empty():
			current["description"] = String(current.get("description", "")) + \
				"\n\n" + echo_text.strip_edges()
	if COMBAT_THREAD_NODES.get(thread_id, -1) == index:
		var presentations: Dictionary = _content.read_module(
			"combat:migrated_presentations").get("presentations", {})
		for direction in (["left"] if thread_id == LAST_LESSON_THREAD_ID \
				else ["left", "right"]):
			var overlay: Dictionary = presentations.get(current["id"] + ":" + direction, {})
			var choice: Dictionary = current.get("choices", {}).get(direction, {})
			if overlay.get("sourceCardId") != current["id"] \
					or overlay.get("sourceDirection") != direction \
					or choice.get("triggerCombat") != true:
				last_error = "故事线程战斗表现与来源选择不符"
				return {}
			var merged: Dictionary = choice.get("combatPresentation", {}).duplicate(true)
			merged.merge(overlay, true)
			if thread_id == SWORD_THREAD_ID:
				for authored_key in ["warningTitle", "mechanic", "worldStory"]:
					if choice.get("combatPresentation", {}).has(authored_key):
						merged[authored_key] = choice["combatPresentation"][authored_key]
			choice["combatPresentation"] = merged
			choice["battlefield"] = overlay.get("battlefield")
			choice["sceneImage"] = overlay.get("sceneImage")
			var battle_art: Dictionary = _content.asset_status(String(overlay.get("sceneImage", "")))
			if not battle_art.get("shaVerified", false) or not battle_art.get("textureLoadable", false):
				_source_missing = not battle_art.get("fileExists", false)
				last_error = "故事线程战斗场景图未通过校验"
				return {}
		current["combatPresentation"] = current["choices"]["left"]["combatPresentation"].duplicate(true)
	if index > 0:
		current["description"] = "【%s】%s" % [definition["title"], current.get("description", "")]
	var expected_type := "STORY" if thread_id in HIGHER_THREAD_IDS \
		or thread_id == LAST_LESSON_THREAD_ID else "NORMAL"
	if thread_id == VILLAGE_THREAD_ID:
		expected_type = "COMBAT" if index == 2 else "STORY" if index == 3 else "NORMAL"
	elif thread_id == SWORD_THREAD_ID:
		expected_type = "COMBAT" if index == 1 else "STORY" if index == 2 else "NORMAL"
	elif thread_id == MIST_THREAD_ID:
		expected_type = "STORY" if index == 1 else "NORMAL"
	if not _realm_matches(current, String(state.get("realm", ""))) \
			or current.get("type") != expected_type:
		return {}
	for direction in current.get("choices", {}):
		current["choices"][direction]["_threadDirection"] = node["card"]["choices"][direction].get(
			"threadDirection", direction)
	current.merge({"_isThreadCard": true, "_threadId": thread_id,
		"_threadPhase": node["phase"], "_threadNodeIndex": index,
		"_narrativeLane": "primary", "_narrativeThreadKey": "thread:" + thread_id,
		"_narrativeSticky": true, "_narrativePriority": int(definition.get("priority", 52)),
		"eligibleRealms": current.get("eligibleRealms", [current["realm"]])}, true)
	var image: Dictionary = _content.card_scene_image_status(String(current.get("id", "")))
	if image.get("sceneImage") != current.get("sceneImage"):
		image = _content.asset_status(String(current.get("sceneImage", "")))
		image["sceneImage"] = current.get("sceneImage")
	if not image.get("shaVerified", false) or not image.get("textureLoadable", false) \
			or image.get("sceneImage") != current.get("sceneImage"):
		_source_missing = not image.get("listedInManifest", false) or not image.get("fileExists", false)
		last_error = "故事线程原有场景图未通过校验"
		return {}
	return current


func _append_history_echoes(card: Dictionary, node: Dictionary, choices: Array) -> void:
	for echo in node.get("historyEchoes", []):
		if not echo is Dictionary or not echo.get("when") is Dictionary \
				or echo.get("when", {}).is_empty() \
				or String(echo.get("text", "")).strip_edges().is_empty() \
				or not _matches_history(echo["when"], choices):
			continue
		card["description"] = String(card.get("description", "")) + "\n\n" + \
			String(echo["text"]).strip_edges()


func _completion_receipt(state: Dictionary, thread_id: String) -> Dictionary:
	var runtime := thread_state(state, thread_id)
	var receipt: Variant = runtime.get("receipt")
	var definition := _definition_for(thread_id)
	var nodes: Array = definition.get("nodes", [])
	var choices: Array = runtime.get("choices", [])
	if runtime.get("status") != "completed" or not receipt is Dictionary \
			or receipt.get("status") != "completed" \
			or receipt.get("threadId") != thread_id \
			or nodes.is_empty() or choices.size() != nodes.size() \
			or receipt.get("completedTurn") != receipt.get("closedTurn") \
			or JSON.parse_string(JSON.stringify(receipt.get("nodes", []))) != \
				JSON.parse_string(JSON.stringify(_receipt_nodes(choices))):
		return {}
	for index in nodes.size():
		var accepted: Dictionary = choices[index]
		var node: Dictionary = nodes[index]
		var direction := String(accepted.get("direction", ""))
		var authored: Variant = node.get("card", {}).get("choices", {}).get(direction)
		if not authored is Dictionary or accepted.get("nodeId") != node.get("id") \
				or accepted.get("threadDirection") != authored.get(
					"threadDirection", direction):
			return {}
	return receipt


func _matches_history(when: Dictionary, choices: Array) -> bool:
	for key in when:
		if key not in ["choiceDirections", "combatOutcomes", "vendorPurchasedItems",
				"vendorResolutions", "anyOf"]:
			return false
	if when.has("anyOf"):
		var alternatives: Variant = when.anyOf
		if not alternatives is Array or alternatives.is_empty():
			return false
		var matched := false
		for alternative in alternatives:
			if alternative is Dictionary and _matches_history(alternative, choices):
				matched = true
				break
		if not matched:
			return false
	var by_node := {}
	for accepted in choices:
		if accepted is Dictionary and accepted.get("nodeId") is String:
			by_node[accepted.nodeId] = accepted
	for node_id in when.get("choiceDirections", {}):
		if by_node.get(node_id, {}).get("direction") != when["choiceDirections"][node_id]:
			return false
	for node_id in when.get("combatOutcomes", {}):
		var context: Dictionary = by_node.get(node_id, {}).get("outcomeContext", {})
		if context.get("mode") != "combat" or context.get(
				"combatOutcome") != when["combatOutcomes"][node_id]:
			return false
	for node_id in when.get("vendorPurchasedItems", {}):
		var context: Dictionary = by_node.get(node_id, {}).get("outcomeContext", {})
		var purchased: Variant = context.get("vendorSummary", {}).get("purchasedItemIds")
		if context.get("mode") != "vendor" or not purchased is Array \
				or not purchased.has(when["vendorPurchasedItems"][node_id]):
			return false
	for node_id in when.get("vendorResolutions", {}):
		var context: Dictionary = by_node.get(node_id, {}).get("outcomeContext", {})
		if context.get("mode") != "vendor" or context.get(
				"vendorSummary", {}).get("resolution") != when["vendorResolutions"][node_id]:
			return false
	return true


func _merge_variant(current: Dictionary, overlay: Dictionary) -> void:
	for key in overlay:
		if key in ["id", "semanticKey", "realm"]:
			continue
		if key == "choices":
			for direction in overlay[key]:
				if not current.get("choices", {}).has(direction):
					continue
				var effects: Dictionary = current["choices"][direction].get("effects", {}).duplicate(true)
				effects.merge(overlay[key][direction].get("effects", {}), true)
				current["choices"][direction].merge(overlay[key][direction].duplicate(true), true)
				current["choices"][direction]["effects"] = effects
		else:
			current[key] = overlay[key]


func settle_choice(state: Dictionary, direction: String,
		outcome_context: Dictionary = {}) -> Dictionary:
	if state.get("storyThreadState", {}).get("version") != 2:
		return super.settle_choice(state, direction)
	last_error = ""
	if not choice_available(state, direction):
		return {}
	var current := card(state)
	var vendor_choice: bool = current.get("id") == "thread_last_lesson_n2" \
		and direction == "left"
	if vendor_choice and not _valid_vendor_context(outcome_context) \
			or not vendor_choice and not outcome_context.is_empty():
		return {}
	var thread_id := String(current["_threadId"])
	var runtime := thread_state(state, thread_id)
	var node_index := int(runtime["pendingNodeIndex"])
	var node: Dictionary = _definition_for(thread_id)["nodes"][node_index]
	var choice: Dictionary = current["choices"][direction]
	var candidate := state.duplicate(true)
	var next_index := int(state["runClock"]["decisionIndex"]) + 1
	if thread_id == SWORD_THREAD_ID and node_index == 2 \
			and current.get("_threadVariantId") == "victory" and direction == "left":
		if choice.get("effects", {}).get("treasure") != "剑心古剑":
			return {}
		var treasure := TreasureAcquisition.new(_content)
		var transaction_id := "treasure:narrative:life:%s:decision:%d:source:thread_sword_tomb_3:item:剑心古剑" % [
			candidate.get("runClock", {}).get("lifeId", ""), next_index]
		if not treasure.acquire(candidate, "剑心古剑", "thread_sword_tomb_3",
				next_index, {"source": "narrative_effect", "sourceId": "thread_sword_tomb_3",
				"channel": null, "transactionId": transaction_id, "details": {}}):
			last_error = treasure.last_error
			return {}
	for key in choice["effects"]:
		if key == "treasure" and thread_id == SWORD_THREAD_ID and node_index == 2 \
				and current.get("_threadVariantId") == "victory" and direction == "left":
			continue
		if not _apply_effect(candidate, String(key), choice["effects"][key],
				String(current.get("id", "")), next_index):
			last_error = "故事线程奖励尚未接入"
			return {}
	if not _choice_policy._apply_passive_regen(candidate):
		last_error = _choice_policy.last_error
		return {}
	var receipt := "decision:%s:choice:%s:%d" % [state["runClock"]["lifeId"], current["id"], next_index]
	if candidate["runClock"]["receipts"].has(receipt):
		return {}
	candidate["runClock"]["receipts"][receipt] = {"token": receipt,
		"decisionIndex": next_index, "sourceCardId": current["id"], "kind": "choice"}
	var record := {"cardId": current["id"], "cardType": current.get("type"),
		"direction": direction, "turn": next_index - 1, "decisionIndex": next_index,
		"tags": current.get("tags", []).duplicate(true)}
	if not candidate.has("replayHistory"):
		candidate["replayHistory"] = candidate.get("choiceHistory", []).duplicate(true)
	candidate["replayHistory"].append(record.duplicate(true))
	candidate["choiceHistory"].append(record)
	while candidate["choiceHistory"].size() > 30:
		candidate["choiceHistory"].pop_front()
	candidate["cardsPlayed"].append(current["id"])
	candidate["turn"] = next_index
	candidate["runClock"]["decisionIndex"] = next_index
	if choice.has("karmaSeed") and not _milestone_flow._plant_seed(candidate, current, choice, direction, next_index):
		return {}
	var advanced: Dictionary = candidate["storyThreadState"]["threads"][thread_id]
	var accepted := {"nodeIndex": node_index, "nodeId": node["id"],
		"direction": direction, "threadDirection": choice.get("threadDirection", direction),
		"turn": next_index}
	if vendor_choice:
		accepted["outcomeContext"] = outcome_context.duplicate(true)
	advanced["choices"].append(accepted)
	advanced["pendingNodeIndex"] = -1
	advanced["nodeIndex"] = node_index + 1
	advanced["lastNodeTurn"] = next_index
	var exit: Dictionary = node.get("exits", {}).get(direction, {})
	if not exit.is_empty():
		_close_thread(advanced, String(exit.get("status", "declined")), next_index)
	elif node.get("phase") == "resolution":
		var complete: Dictionary = node.get("consequences", {}).get("onComplete", {})
		for flag in complete.get("worldFlags", []):
			candidate["flags"][flag] = true
		if complete.has("karmaSeed") and (not complete.has("karmaSeedWhen") \
				or _matches_history(complete["karmaSeedWhen"], advanced["choices"])) \
				and not _plant_completion_seed(candidate, complete["karmaSeed"], thread_id, next_index):
			return {}
		_close_thread(advanced, "completed", next_index)
	MilestoneFlow.tick_seeds(candidate)
	candidate.erase("pendingThreadCard")
	candidate["phase"] = "FLOW_PENDING"
	candidate["currentCardId"] = ""
	candidate["decisionCheckpoint"] = {"version": 1, "cardId": null,
		"sourceCardId": current["id"], "turn": next_index, "decisionIndex": next_index, "flowPending": true}
	return candidate


func _valid_vendor_context(context: Dictionary) -> bool:
	if context.get("mode") != "vendor":
		return false
	var summary: Variant = context.get("vendorSummary")
	if not summary is Dictionary or not summary.get("purchasedItemIds") is Array \
			or not summary.get("purchaseCount") is int \
			or not summary.get("spiritStoneSpent") is int:
		return false
	var resolution := String(summary.get("resolution", ""))
	var purchased: Array = summary.purchasedItemIds
	if summary.purchaseCount != purchased.size() \
			or summary.purchaseCount < 0 or summary.spiritStoneSpent < 0:
		return false
	if resolution == "purchased":
		return purchased.has("last_lesson_three_tone_sword") \
			and summary.spiritStoneSpent >= 18
	return resolution in ["bartered", "sect_loan", "left_empty"] \
		and not purchased.has("last_lesson_three_tone_sword")


func _apply_effect(candidate: Dictionary, key: String, value: Variant,
		card_id: String = "", decision_index: int = -1) -> bool:
	if key == "playerLocation" and value is String and not String(value).strip_edges().is_empty():
		candidate["currentLocation"] = String(value).strip_edges()
		if not candidate.has("visitedLocations"):
			candidate["visitedLocations"] = []
		if not candidate["visitedLocations"].has(candidate["currentLocation"]):
			candidate["visitedLocations"].append(candidate["currentLocation"])
		return true
	if key == "npcLifecycle" and value is Dictionary:
		return WorldContinuity.transition_ascended(candidate, value,
			int(candidate.get("turn", 0)))
	# The current browser callback requires npc_relation:fromId:toId;
	# the authored two-part lesson key has no relation target and is a no-op.
	if key == "npc_relation:jian_linger" and (value is int or value is float):
		return true
	if key == "knowledge" and (value is int or value is float and value == floor(value)):
		var knowledge: Dictionary = candidate.get("knowledge", {}).duplicate(true)
		knowledge["world"] = int(knowledge.get("world", 0)) + int(value)
		candidate["knowledge"] = knowledge
		return true
	if key == "sword_insight" and (value is int or value is float \
			and value == floor(value)):
		var knowledge: Dictionary = candidate.get("knowledge", {}).duplicate(true)
		knowledge["sword"] = maxi(0, int(knowledge.get("sword", 0)) + int(value))
		candidate["knowledge"] = knowledge
		return true
	return super._apply_effect(candidate, key, value, card_id, decision_index)


func _receipt_nodes(choices: Array) -> Array:
	var nodes: Array = super._receipt_nodes(choices)
	for index in mini(nodes.size(), choices.size()):
		if choices[index] is Dictionary and choices[index].has("outcomeContext"):
			nodes[index]["outcomeContext"] = choices[index]["outcomeContext"].duplicate(true)
	return nodes


func _plant_completion_seed(candidate: Dictionary, spec: Dictionary, thread_id: String, decision: int) -> bool:
	var seed_id := String(spec.get("id", ""))
	if seed_id.is_empty():
		return false
	if not candidate.has("karmaPromiseFlags"):
		candidate["karmaPromiseFlags"] = {}
	for existing in candidate.get("karmaSeeds", []):
		if existing.get("id") == seed_id:
			if spec.has("delay") and int(spec["delay"]) < int(existing.get("delay", 0)):
				existing["delay"] = int(spec["delay"])
				existing["priority"] = maxi(int(existing.get("priority", 0)), int(spec.get("priority", 0)))
			if existing.get("originThread") == null:
				existing["originThread"] = thread_id
			candidate["karmaPromiseFlags"][seed_id] = true
			return true
	candidate["karmaSeeds"].append({"id": seed_id, "seedType": spec.get("seedType", "karma"),
		"delay": maxi(1, roundi(int(spec.get("delay", 5)) * 1.5)),
		"realm": spec.get("realm"), "path": spec.get("path"), "priority": int(spec.get("priority", 0)),
		"originTurn": decision, "originLife": int(candidate.get("lifeCount", 0)),
		"originCard": null, "originChoice": null, "originThread": thread_id,
		"originQuest": null, "originOutcome": null, "description": spec.get("description"),
		"tags": spec.get("tags", []), "payoffEvent": spec.get("payoffEvent"), "context": null,
		"consumed": false, "mergeGroup": spec.get("mergeGroup"), "cancelGroup": spec.get("cancelGroup")})
	candidate["karmaPromiseFlags"][seed_id] = true
	return true
