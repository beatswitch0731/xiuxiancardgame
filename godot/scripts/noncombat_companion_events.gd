extends RefCounted

const Repository = preload("res://scripts/noncombat_content_repository.gd")
const LegacyFragmentFlow = preload("res://scripts/noncombat_legacy_fragment_flow.gd")
const MilestoneFlow = preload("res://scripts/noncombat_milestone_flow.gd")
const RULE_SHA := "bd6386d3fb6bae095ce312c5bac520129bbee18f692ba25cb6ccc7f13104adcb"
const MILESTONE_CATALOG := "res://content/derived/companion_milestones.json"
const MILESTONE_CATALOG_SHA := "d2f02a0918fcb381d772a6d1239df312e134ecaa792d4eefb087dc7eb63211a5"
const MODULE := "companions:events"
const QI_CRISIS_MODULE := "companions:qi_crisis"
const NPC_MODULE := "npcs:core"
const OLD_MASTER_ENCOUNTER_ID := "enc_companion_jian_linger_tomb"
const NUMERIC_EFFECTS := ["cultivation", "daoHeart", "health", "fortune", "karmaGood", "karmaBad"]

var last_error := ""
var roll_override := -1.0 # Deterministic source-trace seam; never saved.
var _content: RefCounted

func _init(content: RefCounted = null) -> void:
	_content = content if content != null else Repository.new()

func marker(activation_index: int, turn: int,
		milestone_activation_index: int = 0) -> Dictionary:
	last_error = ""
	var data: Variant = _content.read_module(MODULE)
	var sha: String = _content.source_sha256(MODULE)
	var npc_sha: String = _content.source_sha256(NPC_MODULE)
	if not data is Dictionary or not data.get("companions") is Array \
			or sha.length() != 64 or npc_sha.length() != 64:
		last_error = "道侣事件来源不可用"
		return {}
	var states := {}
	for row in data.companions:
		if not row is Dictionary or not row.get("id") is String:
			return {}
		states[row.id] = {"bond": clampi(int(row.get("startBond", 0)), 0, 5),
			"trust": clampi(int(row.get("startTrust", 0)), 0, 100),
			"lastEventTurn": 0, "lastCooldownTurn": turn, "totalEvents": 0}
	var result := {"version": 1, "activationIndex": activation_index,
		"ruleSha": RULE_SHA, "eventSha": sha, "npcSha": npc_sha,
		"states": states,
		"cooldowns": {}, "checkedTurn": -1}
	if milestone_activation_index >= 0:
		result["milestoneActivationIndex"] = milestone_activation_index
	return result

func valid(state: Dictionary) -> bool:
	var progress: Variant = state.get("companionProgress")
	if not progress is Dictionary or progress.get("version") != 1 \
			or progress.get("ruleSha") != RULE_SHA \
			or progress.get("eventSha") != _content.source_sha256(MODULE) \
			or progress.get("npcSha") != _content.source_sha256(NPC_MODULE) \
			or not progress.get("states") is Dictionary \
			or not progress.get("cooldowns") is Dictionary \
			or not progress.get("pendingMilestones", []) is Array \
			or not progress.get("pendingCrises", []) is Array \
			or progress.has("milestoneActivationIndex") and (
				not _integer(progress.milestoneActivationIndex) \
				or int(progress.milestoneActivationIndex) < 0) \
			or not _integer(progress.get("checkedTurn")):
		last_error = "道侣进度或来源指纹不符"
		return false
	return true

func register(state: Dictionary, comp_id: String, registered_turn: int) -> bool:
	if not valid(state):
		return false
	var progress: Dictionary = state.companionProgress
	if not progress.states.has(comp_id):
		var npc: Variant = _content.read_module(NPC_MODULE)
		if not npc is Dictionary or not npc.get("npcs") is Array \
				or not npc.npcs.any(func(row: Variant) -> bool:
					return row is Dictionary and row.get("id") == comp_id):
			return false
		progress.states[comp_id] = {"bond": 1, "trust": 20,
			"lastEventTurn": registered_turn,
			"lastCooldownTurn": registered_turn,
			"totalEvents": 0}
	progress.cooldowns[comp_id] = 8
	progress.states[comp_id].lastCooldownTurn = registered_turn
	return true

func take(state: Dictionary) -> Dictionary:
	last_error = ""
	if state.get("phase") != "FLOW_PENDING" or not valid(state):
		return {}
	var queued: Dictionary = _take_milestone(state)
	if queued.get("phase") == "COMPANION_PENDING":
		return queued
	if not last_error.is_empty():
		return {}
	var working: Dictionary = queued if not queued.is_empty() else state
	var crisis: Dictionary = _take_crisis(working)
	if crisis.get("phase") == "COMPANION_PENDING":
		return crisis
	if not last_error.is_empty():
		return {}
	working = crisis if not crisis.is_empty() else working
	var turn := int(working.get("turn", 0))
	if turn <= int(working.companionProgress.checkedTurn):
		return working if not queued.is_empty() or not crisis.is_empty() else {}
	var candidate := working.duplicate(true)
	candidate.companionProgress.checkedTurn = turn
	var progress: Dictionary = candidate.companionProgress
	var owned: Variant = candidate.get("resources", {}).get("companions", [])
	if not owned is Array:
		last_error = "道侣资源状态无效"
		return {}
	var data: Variant = _content.read_module(MODULE)
	if not data is Dictionary:
		last_error = "道侣事件来源不可用"
		return {}
	for comp_id in owned:
		if not comp_id is String or not progress.states.has(comp_id):
			continue
		if not _physically_present(candidate, comp_id):
			continue
		var own_state: Dictionary = progress.states[comp_id]
		var cooldown := int(progress.cooldowns.get(comp_id, 0))
		if cooldown > 0:
			if int(own_state.get("lastCooldownTurn", -1)) != turn:
				progress.cooldowns[comp_id] = cooldown - 1
				own_state.lastCooldownTurn = turn
			continue
		var definition := _definition(data, comp_id)
		if definition.is_empty():
			continue
		var affection := int(candidate.get("npcAffection", {}).get(comp_id,
			definition.get("startAffection", 0)))
		var faction_mod := float(candidate.get("factionProgress", {}).get(
			"reputations", {}).get(definition.get("factionId", ""), 0)) / 1000.0
		var chance := minf(0.15 + affection / 100.0 * 0.10 \
			+ int(own_state.get("bond", 0)) * 0.03 \
			- maxi(0, owned.size() - 1) * 0.05 + faction_mod, 0.35)
		if _roll(candidate, comp_id, "chance") > chance:
			continue
		var pool := []
		for event in definition.get("events", []):
			if not event is Dictionary or not _eligible(candidate, comp_id, event,
					affection, own_state):
				continue
			pool.append(event)
		if pool.is_empty():
			continue
		var picked: Dictionary = _pick(pool, candidate, comp_id)
		if picked.is_empty():
			continue
		var card := _build_card(candidate, definition, picked)
		if card.is_empty():
			continue
		if not _registered_event_matches(comp_id, picked, String(card.id)):
			last_error = "道侣事件来源登记不符"
			return {}
		progress.cooldowns[comp_id] = 10
		own_state.lastEventTurn = turn
		own_state.lastCooldownTurn = turn
		own_state.totalEvents = int(own_state.get("totalEvents", 0)) + 1
		candidate.pendingCompanionCard = card
		candidate.phase = "COMPANION_PENDING"
		candidate.currentCardId = card.id
		candidate.decisionCheckpoint = {"version": 1, "cardId": card.id,
			"sourceCardId": _prior_source_id(state),
			"turn": turn, "decisionIndex": state.runClock.decisionIndex,
			"flowSource": "companion_event"}
		return candidate
	return candidate

func card(state: Dictionary) -> Dictionary:
	if state.get("phase") != "COMPANION_PENDING" or not valid(state):
		return {}
	var pending: Variant = state.get("pendingCompanionCard")
	if not pending is Dictionary or pending.get("id") != state.get("currentCardId"):
		return {}
	if pending.get("type") == "COMPANION_MILESTONE":
		var milestone: Variant = state.get("pendingCompanionMilestone")
		var projected_milestone := _milestone_card(state, milestone)
		return projected_milestone if projected_milestone == pending else {}
	if String(pending.get("id", "")).contains("_qi_karma_crisis_"):
		var entry: Variant = state.get("pendingCompanionCrisis")
		var projected_crisis := _crisis_card(state, entry)
		return projected_crisis if JSON.parse_string(JSON.stringify(projected_crisis)) \
			== JSON.parse_string(JSON.stringify(pending)) else {}
	var data: Variant = _content.read_module(MODULE)
	if not data is Dictionary:
		return {}
	var comp_id := String(pending.get("compId", ""))
	var definition := _definition(data, comp_id)
	for event in definition.get("events", []):
		if event is Dictionary and pending.get("id") == "comp_%s_%s" % [comp_id,
				String(event.get("id", ""))]:
			if not _registered_event_matches(comp_id, event, String(pending.id)):
				return {}
			var projected := _build_card(state, definition, event)
			return projected if projected == pending else {}
	return {}


func _registered_event_matches(comp_id: String, event: Dictionary,
		card_id: String) -> bool:
	var source: Dictionary = _content.find("generated_card", card_id)
	if source.get("sourcePath") == "src/systems/CompanionSystem.js":
		var kinds := ["generic_daily", "generic_emo", "generic_help"]
		var index := kinds.find(event.get("id"))
		return index >= 0 and source.get("companionId") == comp_id \
			and source.get("eventId") == event.id \
			and source.get("sourceLocation") == "_getGenericEvent:pool[%d]" % index \
			and source.get("sourceSha256") == RULE_SHA \
			and source.get("npcSourceSha256") == _content.source_sha256(NPC_MODULE) \
			and _generic_events()[index] == event
	return source.get("companionId") == comp_id \
		and source.get("data") == event \
		and source.get("sourcePath") == "data/companions/events.json" \
		and String(source.get("jsonPointer", "")).begins_with("$.companions[")

func queue_crisis(candidate: Dictionary,
		card_data: Dictionary, direction: String) -> bool:
	if not candidate.has("companionProgress") or not valid(candidate):
		return true
	if candidate.get("realm") != "qi":
		return true
	var choice: Variant = card_data.get("choices", {}).get(direction)
	if not choice is Dictionary or not choice.get("effects") is Dictionary:
		return true
	var effects: Dictionary = choice.effects
	var delta := int(effects.get("karmaGood", 0)) - int(effects.get("karmaBad", 0))
	var source: Variant = _content.read_module(QI_CRISIS_MODULE)
	if not source is Dictionary or not source.get("variants") is Dictionary:
		last_error = "炼气道侣危机来源不可用"
		return false
	if absi(delta) < int(source.get("minKarmaDelta", 15)):
		return true
	var owned: Variant = candidate.get("resources", {}).get("companions", [])
	if not owned is Array:
		return false
	var variant := "good" if delta > 0 else "bad"
	var eligible: Array[String] = []
	for comp_id in owned:
		if not comp_id is String or not candidate.companionProgress.states.has(comp_id):
			continue
		var definition := _definition(_content.read_module(MODULE), comp_id)
		var affection := int(candidate.get("npcAffection", {}).get(comp_id,
			definition.get("startAffection", 0)))
		if affection < int(source.get("minAffection", 50)):
			continue
		eligible.append(comp_id)
	if not eligible.is_empty():
		var selected: String = eligible[mini(eligible.size() - 1,
			int(_roll(candidate, "crisis", "owner") * eligible.size()))]
		candidate.companionProgress["pendingCrises"] = [{
			"compId": selected, "variant": variant,
			"sourceSha": _content.source_sha256(QI_CRISIS_MODULE),
			"originCardId": card_data.get("id", ""),
			"originDecisionIndex": candidate.get("runClock", {}).get("decisionIndex", 0)}]
	return true
func _take_crisis(state: Dictionary) -> Dictionary:
	var queue: Array = state.companionProgress.get("pendingCrises", [])
	if queue.is_empty():
		return {}
	var candidate := state.duplicate(true)
	while not candidate.companionProgress.pendingCrises.is_empty():
		var entry: Variant = candidate.companionProgress.pendingCrises.pop_front()
		if not entry is Dictionary or not entry.get("compId") is String:
			last_error = "炼气道侣危机队列无效"
			return {}
		if not _physically_present(candidate, entry.compId):
			candidate.companionProgress.checkedTurn = int(state.get("turn", 0))
			return candidate
		var card_data := _crisis_card(candidate, entry)
		if card_data.is_empty():
			last_error = "炼气道侣危机卡来源不符"
			return {}
		candidate.pendingCompanionCrisis = entry
		candidate.pendingCompanionCard = card_data
		candidate.phase = "COMPANION_PENDING"
		candidate.currentCardId = card_data.id
		candidate.decisionCheckpoint = {"version": 1, "cardId": card_data.id,
			"sourceCardId": _prior_source_id(state), "turn": state.get("turn"),
			"decisionIndex": state.get("runClock", {}).get("decisionIndex"),
			"flowSource": "companion_crisis"}
		return candidate
	return candidate

func _crisis_card(state: Dictionary, entry: Variant) -> Dictionary:
	if not entry is Dictionary or state.get("realm") != "qi" \
			or entry.get("sourceSha") != _content.source_sha256(QI_CRISIS_MODULE):
		return {}
	var source: Variant = _content.read_module(QI_CRISIS_MODULE)
	var variant := String(entry.get("variant", ""))
	if not source is Dictionary or variant not in ["good", "bad"]:
		return {}
	var event: Variant = source.get("variants", {}).get(variant)
	var definition := _definition(_content.read_module(MODULE),
		String(entry.get("compId", "")))
	if not event is Dictionary or definition.is_empty() or not event.get("choices") is Dictionary:
		return {}
	return _build_card(state, definition, event)

func choice_available(state: Dictionary, direction: String) -> bool:
	var choices: Dictionary = card(state).get("choices", {})
	if not choices.has(direction):
		return false
	if not _all_positive_capped(state, choices[direction]):
		return true
	for other in choices:
		if not _all_positive_capped(state, choices[other]):
			return false
	return direction == String(choices.keys()[0])

func _all_positive_capped(state: Dictionary, choice: Dictionary) -> bool:
	var effects: Variant = choice.get("effects")
	if not effects is Dictionary or effects.is_empty():
		return false
	for key in effects:
		if key not in NUMERIC_EFFECTS or not _integer(effects[key]) \
				or int(effects[key]) <= 0:
			return false
		var maximum := 100
		if key == "health":
			maximum = LegacyFragmentFlow.actual_max_health(state)
		elif key == "daoHeart":
			maximum = LegacyFragmentFlow.actual_max_dao_heart(state)
		elif key == "cultivation":
			var realms: Variant = _content.read_module("config:realms")
			var threshold: Variant = realms.get("realms", {}).get(
				String(state.get("realm", "qi")), {}).get(
				"cultivationThreshold") if realms is Dictionary else null
			if not _integer(threshold):
				return false
			maximum = int(threshold)
		if int(state.get("attributes", {}).get(key, 0)) < maximum:
			return false
	return true

func settle(state: Dictionary, direction: String) -> Dictionary:
	last_error = ""
	var current := card(state)
	if current.is_empty() or not choice_available(state, direction):
		return {}
	var candidate := state.duplicate(true)
	var choice: Dictionary = current.choices[direction]
	var is_milestone: bool = current.get("type") == "COMPANION_MILESTONE"
	for key in choice.effects:
		var delta := int(choice.effects[key])
		if key not in NUMERIC_EFFECTS or not _integer(choice.effects[key]):
			return {}
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
			if not _integer(threshold):
				return {}
			maximum = int(threshold)
		var amount := LegacyFragmentFlow.effective_delta(candidate, key, delta)
		if key == "health" and amount < 0 \
				and int(candidate.attributes.get("aura", 0)) > 0:
			var absorbed := mini(int(candidate.attributes.aura), -amount)
			candidate.attributes.aura = int(candidate.attributes.aura) - absorbed
			amount += absorbed
		candidate.attributes[key] = clampi(int(candidate.attributes.get(key, 0))
			+ amount, 0, maximum)
	if int(choice.effects.get("health", 0)) < 0 \
			or int(choice.effects.get("daoHeart", 0)) < 0:
		candidate.resources.lifespan = maxi(0,
			int(candidate.resources.get("lifespan", 0)) - 1)
	var next_index := int(state.runClock.decisionIndex) + 1
	if not is_milestone and not _apply_companion_effects(candidate, current,
			choice, direction, next_index):
		return {}
	var receipt := "decision:%s:choice:%s:%d" % [state.runClock.lifeId,
		current.id, next_index]
	if candidate.runClock.receipts.has(receipt):
		return {}
	candidate.runClock.receipts[receipt] = {"token": receipt,
		"decisionIndex": next_index, "sourceCardId": current.id, "kind": "choice"}
	var row := {"cardId": current.id, "cardType": current.type,
		"direction": direction, "turn": next_index - 1,
		"decisionIndex": next_index,
		"tags": current.get("tags", []).duplicate(true)}
	if not candidate.has("replayHistory"):
		candidate.replayHistory = candidate.get("choiceHistory", []).duplicate(true)
	candidate.replayHistory.append(row.duplicate(true))
	candidate.choiceHistory.append(row)
	while candidate.choiceHistory.size() > 30:
		candidate.choiceHistory.pop_front()
	for tag in current.get("tags", []):
		candidate.recentCardTags.append(tag)
	while candidate.recentCardTags.size() > 20:
		candidate.recentCardTags.pop_front()
	candidate.cardsPlayed.append(current.id)
	candidate.turn = next_index
	candidate.runClock.decisionIndex = next_index
	MilestoneFlow.tick_seeds(candidate)
	candidate.erase("pendingCompanionCard")
	candidate.erase("pendingCompanionCrisis")
	if is_milestone:
		candidate.erase("pendingCompanionMilestone")
		candidate.phase = "FLOW_PENDING"
		candidate.currentCardId = ""
		candidate.decisionCheckpoint = {"version": 1, "cardId": null,
			"sourceCardId": current.id, "turn": next_index,
			"decisionIndex": next_index, "flowPending": true}
		return candidate
	if not candidate.get("noncombatFlow") is Dictionary:
		return {}
	var promise_id := "promise:%08x" % _fnv32("life:%d|%s|%s|%s" % [
		int(state.get("lifeCount", 0)), current.semanticKey, current.id, direction])
	var result_id := "promise_result_%08x" % _fnv32(promise_id)
	var response := "你在「%s」中选择了「%s」。这段因缘已给出明确回应。" % [
		current.title, choice.text]
	var result := {"id": result_id, "semanticKey": "promise-result:" + promise_id,
		"type": "NARRATIVE_RESULT", "title": String(current.title) + "·回应",
		"description": response, "promiseId": promise_id,
		"originCardId": current.id, "originChoice": direction,
		"_narrativeLane": "primary", "_narrativeThreadKey": "promise:" + promise_id,
		"_narrativeSticky": true, "narrativeTtlTurns": 4, "once": true,
		"tags": ["narrative_result", "promise_resolution"],
		"choices": {"left": {"text": "记下这段回应", "effects": {},
			"resolution": {"kind": "promise_resolved", "promiseId": promise_id},
			"feedbackCue": {"kind": "promise_resolved", "text": response,
				"lane": "narrative"}}}}
	if current.has("sceneImage"):
		result["sceneImage"] = current.sceneImage
	candidate.noncombatFlow.promise = {"id": promise_id,
		"status": "pending", "sourceCardId": current.id,
		"sourceSemanticKey": current.semanticKey, "sourceTitle": current.title,
		"choiceDirection": direction, "createdDecisionIndex": next_index,
		"dueWithinDecisions": 2, "dueDecisionIndex": next_index + 2,
		"followUpCardId": result_id, "resolvedDecisionIndex": null,
		"resolutionCardId": null}
	candidate.noncombatFlow.pendingResultCard = result.duplicate(true)
	candidate.pendingNarrativeResult = result
	candidate.currentCardId = result_id
	candidate.phase = "NARRATIVE_RESULT_PENDING"
	candidate.decisionCheckpoint = {"version": 1, "cardId": result_id,
		"sourceCardId": current.id, "turn": next_index,
		"decisionIndex": next_index}
	return candidate

func _apply_companion_effects(candidate: Dictionary, card: Dictionary,
		choice: Dictionary, direction: String, decision: int) -> bool:
	var ce: Dictionary = choice.companionEffects
	var comp_id := String(ce.compId)
	var own_state: Dictionary = candidate.companionProgress.states[comp_id]
	own_state.bond = clampi(int(own_state.bond) + int(ce.get("bondDelta", 0)), 0, 5)
	own_state.trust = clampi(int(own_state.trust) + int(ce.get("trustDelta", 0)), 0, 100)
	var data: Variant = _content.read_module(MODULE)
	var definition := _definition(data, comp_id)
	var old_affection := int(candidate.get("npcAffection", {}).get(comp_id,
		definition.get("startAffection", 0)))
	var affections: Dictionary = candidate.get("npcAffection", {})
	var new_affection := clampi(old_affection + int(ce.get("affectionDelta", 0)), -50, 100)
	affections[comp_id] = new_affection
	candidate.npcAffection = affections
	var bonds: Dictionary = candidate.get("npcBonds", {})
	for level in range(5, -1, -1):
		if new_affection >= [0, 30, 55, 75, 90, 100][level] \
				and int(bonds.get(comp_id, 0)) < level:
			bonds[comp_id] = level
			break
	candidate.npcBonds = bonds
	if int(ce.get("affectionDelta", 0)) <= -20:
		var sacrifice := {"text": choice.text, "karmaSeed": {
			"id": "companionSacrifice",
			"description": "%s与你之间的关系发生了剧烈变化。" % definition.get(
				"name", comp_id)}}
		if not MilestoneFlow.new(_content)._plant_seed(candidate,
			{"id": "comp_%s" % comp_id, "title": definition.get("name", comp_id)},
			sacrifice, direction, decision):
			return false
	if int(ce.get("trustDelta", 0)) >= 20:
		var trust := {"text": choice.text, "karmaSeed": {
			"id": "companionTrust", "magnitude": int(ce.get("trustDelta", 0)),
			"description": "%s深深信任了你——这份信任会在关键时刻成为你的倚仗。" % definition.get(
				"name", comp_id)}}
		if not MilestoneFlow.new(_content)._plant_seed(candidate,
			{"id": "comp_%s" % comp_id, "title": definition.get("name", comp_id)},
			trust, direction, decision):
			return false
	return _check_milestone(candidate, comp_id, String(definition.get("name", comp_id)),
		old_affection, new_affection)

func _milestone_catalog() -> Dictionary:
	if FileAccess.get_sha256(MILESTONE_CATALOG).to_lower() != MILESTONE_CATALOG_SHA:
		last_error = "道侣里程碑来源不符"
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(MILESTONE_CATALOG))
	if not parsed is Dictionary or parsed.get("sourceSha") != RULE_SHA \
			or not parsed.get("milestones") is Array \
			or parsed.milestones.size() != 5:
		last_error = "道侣里程碑目录无效"
		return {}
	return parsed

func _check_milestone(candidate: Dictionary, comp_id: String, name: String,
		old_affection: int, new_affection: int) -> bool:
	var activation: Variant = candidate.get("companionProgress", {}).get(
		"milestoneActivationIndex")
	if activation == null or int(candidate.get("runClock", {}).get(
			"decisionIndex", 0)) + 1 < int(activation):
		return true
	var catalog := _milestone_catalog()
	if catalog.is_empty():
		return false
	for spec in catalog.milestones:
		var threshold := int(spec.threshold)
		var crossed: bool = old_affection > threshold and new_affection <= threshold \
			if spec.direction == "down" else old_affection < threshold \
			and new_affection >= threshold
		if not crossed:
			continue
		var flag := "comp_milestone_%s_%s" % [comp_id, spec.id]
		if bool(candidate.get("flags", {}).get(flag, false)):
			continue
		var entry := {"id": spec.id, "compId": comp_id, "name": name,
			"affection": new_affection}
		if _milestone_card(candidate, entry).is_empty():
			return false
		candidate.get_or_add("flags", {})[flag] = int(candidate.get("turn", 0))
		candidate.companionProgress.get_or_add("pendingMilestones", []).append(entry)
		var seed_id := "companion_milestone_%s_%s" % [comp_id, spec.id]
		var raw_delay := 3 if threshold >= 80 else 8
		var raw_seed := {"id": seed_id, "seedType": spec.seedType,
			"delay": raw_delay, "priority": 7 if threshold >= 80 else 4,
			"originCard": "comp_%s_milestone" % comp_id,
			"payoffEvent": spec.payoffEvent,
			"context": {"companionId": comp_id, "companionName": name,
				"milestoneId": spec.id}}
		_plant_milestone_seed(candidate, raw_seed)
		return true
	return true

func _plant_milestone_seed(candidate: Dictionary, spec: Dictionary) -> void:
	var seeds: Array = candidate.get("karmaSeeds", [])
	for existing in seeds:
		if existing.get("id") == spec.id:
			if int(spec.delay) < int(existing.get("delay", 0)):
				existing.delay = spec.delay
				existing.priority = maxi(int(existing.get("priority", 0)), int(spec.priority))
			if not existing.get("context") is Dictionary:
				existing.context = spec.context.duplicate(true)
			if not existing.get("payoffEvent"):
				existing.payoffEvent = spec.payoffEvent
			candidate.karmaSeeds = seeds
			candidate.get_or_add("karmaPromiseFlags", {})[spec.id] = true
			return
	var realm_mod := {"qi": 1.5, "foundation": 1.2, "golden": 1.0,
		"nascent": 0.8, "deity": 0.6, "tribulation": 0.5}
	var delay := maxi(1, roundi(float(spec.delay) * float(realm_mod.get(
		candidate.get("realm", "qi"), 1.0))))
	seeds.append({"id": spec.id, "seedType": spec.seedType, "delay": delay,
		"realm": null, "path": null, "priority": spec.priority,
		"originTurn": int(candidate.get("turn", 0)),
		"originLife": int(candidate.get("lifeCount", 0)),
		"originCard": spec.originCard, "originChoice": null,
		"originThread": null, "originQuest": null, "originOutcome": null,
		"description": null, "tags": [], "payoffEvent": spec.payoffEvent,
		"context": spec.context.duplicate(true), "consumed": false,
		"mergeGroup": null, "cancelGroup": null})
	candidate.karmaSeeds = seeds
	candidate.get_or_add("karmaPromiseFlags", {})[spec.id] = true

func _take_milestone(state: Dictionary) -> Dictionary:
	var queue: Array = state.companionProgress.get("pendingMilestones", [])
	if queue.is_empty():
		return {}
	var candidate := state.duplicate(true)
	while not candidate.companionProgress.pendingMilestones.is_empty():
		var entry: Variant = candidate.companionProgress.pendingMilestones.pop_front()
		if not entry is Dictionary or not entry.get("compId") is String:
			last_error = "道侣里程碑队列无效"
			return {}
		if not _physically_present(candidate, entry.compId):
			continue
		var card_data := _milestone_card(candidate, entry)
		if card_data.is_empty():
			return {}
		candidate.pendingCompanionMilestone = entry
		candidate.pendingCompanionCard = card_data
		candidate.phase = "COMPANION_PENDING"
		candidate.currentCardId = card_data.id
		candidate.decisionCheckpoint = {"version": 1, "cardId": card_data.id,
			"sourceCardId": _prior_source_id(state),
			"turn": state.get("turn"),
			"decisionIndex": state.get("runClock", {}).get("decisionIndex"),
			"flowSource": "companion_milestone"}
		return candidate
	return candidate

func _milestone_card(state: Dictionary, entry: Variant) -> Dictionary:
	if not entry is Dictionary:
		return {}
	var catalog := _milestone_catalog()
	if catalog.is_empty():
		return {}
	for spec in catalog.milestones:
		if spec.id == entry.get("id"):
			var comp_id := String(entry.get("compId", ""))
			var card_id := "comp_%s_milestone_%s" % [comp_id, spec.id]
			var source: Dictionary = _content.find("generated_card", card_id)
			if source.get("companionId") != comp_id \
					or source.get("data") != spec \
					or source.get("sourceSha256") != RULE_SHA \
					or source.get("derivedCatalogPointer") != \
					"$.milestones[%d]" % catalog.milestones.find(spec):
				last_error = "道侣里程碑来源登记不符"
				return {}
			var projected: Variant = _replace_milestone_tokens(spec.card,
				String(entry.get("compId", "")), String(entry.get("name", "")),
				String(state.get("realm", "qi")))
			return projected if projected is Dictionary else {}
	return {}

func _replace_milestone_tokens(value: Variant, comp_id: String,
		name: String, realm: String) -> Variant:
	if value is String:
		return value.replace("__COMP_ID__", comp_id).replace("__NAME__", name).replace(
			"__REALM__", realm)
	if value is Array:
		var items := []
		for item in value:
			items.append(_replace_milestone_tokens(item, comp_id, name, realm))
		return items
	if value is Dictionary:
		var fields := {}
		for key in value:
			fields[key] = _replace_milestone_tokens(value[key], comp_id, name, realm)
		return fields
	return value

func _prior_source_id(state: Dictionary) -> Variant:
	var checkpoint: Variant = state.get("decisionCheckpoint")
	return checkpoint.get("sourceCardId") if checkpoint is Dictionary else null

func _definition(data: Dictionary, comp_id: String) -> Dictionary:
	for row in data.get("companions", []):
		if row is Dictionary and row.get("id") == comp_id:
			return row
	var npc: Variant = _content.read_module(NPC_MODULE)
	if npc is Dictionary:
		for row in npc.get("npcs", []):
			if row is Dictionary and row.get("id") == comp_id:
				return {"id": comp_id, "name": row.get("name", comp_id),
					"title": row.get("title", ""),
					"startAffection": row.get("startAffection", 30),
					"events": _generic_events()}
	return {}

func _generic_events() -> Array:
	return [
		{"id": "generic_daily", "type": "daily", "once": false,
			"repeatPolicy": {"mode": "cooldown", "cooldownTurns": 12},
			"title": "日常陪伴",
			"desc": "道侣为你端来一杯热茶，轻声问起今日修行如何。",
			"choices": {"left": {"text": "分享修行心得", "affection": 5,
				"effects": {"cultivation": 3, "daoHeart": 2}},
				"right": {"text": "静静品茶", "affection": 3,
					"effects": {"daoHeart": 5}}}},
		{"id": "generic_emo", "type": "emotional", "once": false,
			"repeatPolicy": {"mode": "cooldown", "cooldownTurns": 12},
			"title": "月下谈心",
			"desc": "月华如练，道侣与你并肩而坐。星河之下，人间万事都显得渺小。",
			"choices": {"left": {"text": "倾诉心声", "affection": 8,
				"effects": {"daoHeart": 5, "fortune": 3}},
				"right": {"text": "静默相伴", "affection": 5,
					"effects": {"daoHeart": 8}}}},
		{"id": "generic_help", "type": "daily", "once": false,
			"repeatPolicy": {"mode": "cooldown", "cooldownTurns": 12},
			"title": "修行相助",
			"desc": "道侣递来一枚丹药：\"这是我闭关三日炼成的，你试试。\"",
			"choices": {"left": {"text": "感激收下", "affection": 6,
				"effects": {"cultivation": 10, "health": 5}},
				"right": {"text": "婉拒", "affection": -2,
					"effects": {"daoHeart": 3}}}},
	]

func _eligible(state: Dictionary, comp_id: String, event: Dictionary,
		affection: int, own_state: Dictionary) -> bool:
	if affection < int(event.get("minAffection", 0)) \
			or int(own_state.get("bond", 0)) < int(event.get("minBond", 0)):
		return false
	if event.has("realm") and event.realm != state.get("realm"):
		return false
	if event.has("requiredFlag") and not state.get("flags", {}).get(event.requiredFlag, false):
		return false
	if event.has("forbiddenFlag") and state.get("flags", {}).get(event.forbiddenFlag, false):
		return false
	var card_id := "comp_%s_%s" % [comp_id, event.get("id", "")]
	if event.get("once", true):
		if state.get("cardsPlayed", []).has(card_id):
			return false
	else:
		var cooldown_turns := int(event.get("repeatPolicy", {}).get("cooldownTurns", 12))
		for row in state.get("replayHistory", state.get("choiceHistory", [])):
			if row is Dictionary and row.get("cardId") == card_id \
					and int(state.get("turn", 0)) - int(row.get("decisionIndex", 0)) < cooldown_turns:
				return false
	for choice in event.get("choices", {}).values():
		if not choice is Dictionary:
			return false
		if choice.has("encounterId") and (comp_id != "jian_linger" \
				or event.get("id") != "jle_8_sword_tomb_old_master" \
				or choice.encounterId != OLD_MASTER_ENCOUNTER_ID \
				or _old_master_encounter().is_empty()):
			return false
		if not choice.get("effects", {}) is Dictionary:
			return false
		for key in choice.get("effects", {}):
			if key not in NUMERIC_EFFECTS or not _integer(choice.effects[key]):
				return false
	return true

func _build_card(state: Dictionary, definition: Dictionary,
		event: Dictionary) -> Dictionary:
	if definition.is_empty() or event.is_empty():
		return {}
	var comp_id := String(definition.id)
	var choices := {}
	for direction in event.get("choices", {}):
		var authored: Dictionary = event.choices[direction]
		choices[direction] = {"text": authored.get("text", "..."),
			"effects": authored.get("effects", {}).duplicate(true),
			"companionEffects": {"compId": comp_id,
				"affectionDelta": int(authored.get("affection", 0)),
				"bondDelta": int(authored.get("bondDelta", 0)),
				"trustDelta": int(authored.get("trustDelta", 0))}}
		if authored.has("encounterId"):
			var encounter := _old_master_encounter()
			if authored.encounterId != OLD_MASTER_ENCOUNTER_ID \
					or encounter.is_empty():
				return {}
			var visual: Dictionary = encounter.get("combatPresentation", {})
			choices[direction].merge({"encounterId": encounter.id,
				"triggerCombat": true, "enemy": encounter.enemy.duplicate(true),
				"battlefield": visual.get("battlefield", encounter.get("battlefield")),
				"combatPresentation": visual.duplicate(true),
				"victoryEffects": encounter.get("victoryEffects", {}).duplicate(true),
				"combatRewards": encounter.get("victoryEffects", {}).duplicate(true),
				"combatOutcomeLinks": encounter.get("outcomeLinks", {}).duplicate(true)}, true)
	var result := {"id": "comp_%s_%s" % [comp_id, event.get("id", "")],
		"semanticKey": "companion:%s:event:%s" % [comp_id, event.get("id", "")],
		"title": event.get("title", "道侣"),
		"description": String(event.get("desc", "")).replace("{name}",
			String(definition.get("name", comp_id))),
		"type": "COMPANION_EVENT", "realm": state.get("realm", "qi"),
		"compId": comp_id, "compEvent": event.duplicate(true), "weight": 0,
		"once": event.get("once", true), "repeatPolicy": event.get("repeatPolicy"),
		"choices": choices}
	for optional in ["sceneImage", "artDirection"]:
		if event.has(optional):
			result[optional] = event[optional]
	return result

func _old_master_encounter() -> Dictionary:
	var catalog: Variant = _content.read_module("combat:encounters")
	if not catalog is Dictionary or not catalog.get("encounters") is Array:
		return {}
	for row in catalog.encounters:
		if row is Dictionary and row.get("id") == OLD_MASTER_ENCOUNTER_ID \
				and row.get("requiredCompanion") == "jian_linger" \
				and row.get("realm") == "golden" \
				and row.get("enemy") is Dictionary \
				and row.get("combatPresentation") is Dictionary \
				and row.get("outcomeLinks") is Dictionary:
			return row
	return {}

func _pick(pool: Array, state: Dictionary, comp_id: String) -> Dictionary:
	var roll := _roll(state, comp_id, "type")
	var crisis: Array = pool.filter(func(row: Variant) -> bool:
		return row.get("type") == "crisis")
	var emotional: Array = pool.filter(func(row: Variant) -> bool:
		return row.get("type") == "emotional")
	var daily: Array = pool.filter(func(row: Variant) -> bool:
		return row.get("type") == "daily")
	var selected: Array = crisis if roll < 0.05 and not crisis.is_empty() else \
		(emotional if roll < 0.30 and not emotional.is_empty() else daily)
	if selected.is_empty():
		selected = pool
	return selected[mini(selected.size() - 1,
		int(_roll(state, comp_id, "index") * selected.size()))]

func _roll(state: Dictionary, comp_id: String, channel: String) -> float:
	if roll_override >= 0.0:
		return clampf(roll_override, 0.0, 0.999999)
	var key := "%s:%d:%s:%s" % [state.get("runClock", {}).get("lifeId", ""),
		int(state.get("turn", 0)), comp_id, channel]
	return float(key.hash() & 0x7fffffff) / 2147483648.0

func _physically_present(state: Dictionary, comp_id: String) -> bool:
	if state.get("deadNpcs", []).has(comp_id):
		return false
	var world: Variant = state.get("worldContinuityState")
	if not world is Dictionary:
		return true
	if world.get("version") != 1 or world.get("lifeId") != state.get("lifeCount", 0):
		return false
	var row: Variant = world.get("npcs", {}).get(comp_id)
	return row is Dictionary and row.get("npcId") == comp_id \
		and row.get("lifeId") == world.get("lifeId") \
		and row.get("lifecycle") == "ACTIVE" \
		and row.get("manifestation") == "PHYSICAL"

func _integer(value: Variant) -> bool:
	return (value is int or value is float) and float(value) == floor(float(value))

func _fnv32(value: String) -> int:
	var hash_value := 0x811c9dc5
	for index in range(value.length()):
		hash_value = (hash_value ^ value.unicode_at(index)) * 0x01000193 & 0xffffffff
	return hash_value
