extends RefCounted

const Repository = preload("res://scripts/noncombat_content_repository.gd")
const CompanionEvents = preload("res://scripts/noncombat_companion_events.gd")
const LegacyFragmentFlow = preload("res://scripts/noncombat_legacy_fragment_flow.gd")
const MilestoneFlow = preload("res://scripts/noncombat_milestone_flow.gd")
const NormalChoicePolicy = preload("res://scripts/noncombat_normal_choice_policy.gd")
const NormalDrawPolicy = preload("res://scripts/noncombat_normal_draw_policy.gd")
const CATALOG_PATH := "res://content/derived/companion_arc_cards.json"
const CATALOG_SHA := "5fada85fc5722e865e24aff4cb41c8f81e3abc27683b15bb73e1c276d13977ef"
const MODULE := "companions:arcs"
const PORTRAITS := "companions:portrait_stages"
const OWNER_IDS := ["bai_luoxuan", "jian_linger", "jiuwei_suyue", "mu_qinglan", "yin_xue"]
const STAGES := ["NOT_BOUND", "ACQUAINTANCE", "KNOWING", "DEEP_BOND", "SOUL_BOND", "DESTINY"]
const THRESHOLDS := [0, 20, 40, 60, 80, 95]
const BONDS := [0, 0, 0, 2, 3, 4]
const REALMS := ["qi", "foundation", "golden", "nascent", "deity", "tribulation"]
const NUMERIC_EFFECTS := ["cultivation", "daoHeart", "health", "fortune", "karmaGood", "karmaBad", "wisdom"]

var last_error := ""
var _content: RefCounted
var _events: RefCounted
var _choice_policy: RefCounted
var _draw_policy: RefCounted
var _catalog: Dictionary = {}


func _init(content: RefCounted = null) -> void:
	_content = content if content != null else Repository.new()
	_events = CompanionEvents.new(_content)
	_choice_policy = NormalChoicePolicy.new(_content)
	_draw_policy = NormalDrawPolicy.new(_content)


func _source_catalog() -> Dictionary:
	if not _catalog.is_empty():
		return _catalog
	if FileAccess.get_sha256(CATALOG_PATH).to_lower() != CATALOG_SHA:
		last_error = "道侣弧线卡目录与来源不符"
		return {}
	var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(CATALOG_PATH))
	if not value is Dictionary or value.get("dataSha") != _content.source_sha256(MODULE) \
			or not value.get("ruleSha") is String or not value.get("cards") is Dictionary:
		last_error = "道侣弧线来源不可用"
		return {}
	for owner in OWNER_IDS:
		if not value.cards.get(owner) is Array or value.cards[owner].size() != 8:
			last_error = "道侣弧线来源卡缺失"
			return {}
	_catalog = value
	return _catalog


func marker(activation_index: int, life_count: int) -> Dictionary:
	var catalog := _source_catalog()
	if catalog.is_empty() or _content.source_sha256(PORTRAITS).length() != 64:
		return {}
	return {"version": 1, "activationIndex": activation_index,
		"lifeCount": life_count, "catalogSha": CATALOG_SHA,
		"ruleSha": catalog.ruleSha, "dataSha": catalog.dataSha,
		"portraitSha": _content.source_sha256(PORTRAITS),
		"states": {}, "pendingEvents": [], "pendingClimaxes": []}


func valid(state: Dictionary) -> bool:
	var arc: Variant = state.get("companionArcState")
	var catalog := _source_catalog()
	if catalog.is_empty() or not arc is Dictionary or arc.get("version") != 1 \
			or arc.get("lifeCount") != state.get("lifeCount", 0) \
			or arc.get("catalogSha") != CATALOG_SHA \
			or arc.get("ruleSha") != catalog.ruleSha \
			or arc.get("dataSha") != catalog.dataSha \
			or arc.get("portraitSha") != _content.source_sha256(PORTRAITS) \
			or not arc.get("states") is Dictionary \
			or not arc.get("pendingEvents") is Array \
			or not arc.get("pendingClimaxes") is Array:
		last_error = "道侣弧线进度或来源不符"
		return false
	return true


func advance(prior: Dictionary, candidate: Dictionary) -> bool:
	last_error = ""
	if not valid(candidate):
		return false
	var arc: Dictionary = candidate.companionArcState
	var owned: Variant = candidate.get("resources", {}).get("companions", [])
	if not owned is Array:
		return false
	for comp_id in owned:
		if comp_id not in OWNER_IDS:
			continue
		if not arc.states.has(comp_id):
			arc.states[comp_id] = {"compId": comp_id, "stage": "NOT_BOUND",
				"stageIndex": 0, "enteredAtTurn": int(candidate.get("turn", 0)),
				"eventsTriggered": [], "climaxTriggered": false,
				"secretsRevealed": []}
		if not _events._physically_present(candidate, comp_id):
			continue
		var own: Dictionary = arc.states[comp_id]
		var old_affection := int(prior.get("npcAffection", {}).get(comp_id,
			candidate.get("npcAffection", {}).get(comp_id, 0)))
		var new_affection := int(candidate.get("npcAffection", {}).get(comp_id,
			old_affection))
		var old_bond := int(prior.get("companionProgress", {}).get("states", {}).get(
			comp_id, {}).get("bond", 0))
		var new_bond := int(candidate.get("companionProgress", {}).get("states", {}).get(
			comp_id, {}).get("bond", old_bond))
		if old_affection != new_affection or old_bond != new_bond:
			var old_stage := int(own.get("stageIndex", 0))
			var attained := _attained_stage(new_affection, new_bond)
			if attained > old_stage:
				own.stageIndex = attained
				own.stage = STAGES[attained]
				own.enteredAtTurn = int(prior.get("turn", 0))
				for index in range(old_stage + 1, attained + 1):
					_queue(arc.pendingEvents, own, "arc_%s_stage_%s" % [
						comp_id, STAGES[index]], comp_id)
				if attained >= 3 and own.secretsRevealed.is_empty():
					_queue(arc.pendingClimaxes, own,
						"arc_%s_secret_reveal" % comp_id, comp_id)
			if new_affection - old_affection < -20 and int(own.stageIndex) > 1:
				own.stageIndex = int(own.stageIndex) - 1
				own.stage = STAGES[int(own.stageIndex)]
		_reconcile_realm(arc, own, comp_id, String(candidate.get("realm", "qi")))
	return true


func _attained_stage(affection: int, bond: int) -> int:
	var result := 0
	for index in range(1, STAGES.size()):
		if affection >= THRESHOLDS[index] and bond >= BONDS[index]:
			result = index
	return result


func _queue(queue: Array, own: Dictionary, card_id: String, comp_id: String) -> void:
	if own.eventsTriggered.has(card_id):
		return
	for item in queue:
		if item is Dictionary and item.get("cardId") == card_id:
			return
	queue.append({"compId": comp_id, "cardId": card_id})


func _reconcile_realm(arc: Dictionary, own: Dictionary, comp_id: String,
		realm: String) -> void:
	var rank := REALMS.find(realm)
	if rank >= 2 and int(own.stageIndex) >= 3 and not own.climaxTriggered:
		_queue(arc.pendingClimaxes, own, "arc_%s_tribulation" % comp_id, comp_id)
	if rank >= 4 and int(own.stageIndex) >= 4:
		_queue(arc.pendingClimaxes, own, "arc_%s_destiny" % comp_id, comp_id)


func take(state: Dictionary, kind: String) -> Dictionary:
	last_error = ""
	if state.get("phase") != "FLOW_PENDING" or kind not in ["event", "climax"] \
			or not valid(state):
		return {}
	var candidate := state.duplicate(true)
	var arc: Dictionary = candidate.companionArcState
	var queue: Array = arc.pendingClimaxes if kind == "climax" else arc.pendingEvents
	for item in queue.duplicate(true):
		var comp_id := String(item.get("compId", ""))
		var card_id := String(item.get("cardId", ""))
		var own: Dictionary = arc.states.get(comp_id, {})
		if own.is_empty() or own.eventsTriggered.has(card_id) \
				or not _events._physically_present(candidate, comp_id):
			queue.erase(item)
			continue
		if kind == "climax" and arc.pendingEvents.any(func(row: Variant) -> bool:
			return row is Dictionary and row.get("compId") == comp_id):
			continue
		var projected := _project(comp_id, card_id, String(candidate.get("realm", "qi")))
		if projected.is_empty():
			last_error = "道侣弧线来源卡无法投影"
			return {}
		if _draw_policy._resolved_semantic_keys(candidate).has(
				String(projected.semanticKey)):
			queue.erase(item)
			continue
		candidate.pendingCompanionArcCard = projected
		candidate.phase = "COMPANION_ARC_PENDING"
		candidate.currentCardId = card_id
		candidate.decisionCheckpoint = {"version": 1, "cardId": card_id,
			"sourceCardId": state.get("decisionCheckpoint", {}).get("sourceCardId"),
			"turn": state.get("turn"), "decisionIndex": state.get(
				"runClock", {}).get("decisionIndex"),
			"flowSource": "companion_arc:" + kind, "compId": comp_id}
		return candidate
	return candidate if candidate != state else {}


func _project(comp_id: String, card_id: String, realm: String) -> Dictionary:
	var catalog := _source_catalog()
	var rows: Array = catalog.get("cards", {}).get(comp_id, [])
	for i in range(rows.size()):
		var row: Variant = rows[i]
		if row is Dictionary and row.get("id") == card_id:
			var source: Dictionary = _content.find("generated_card", card_id)
			if source.get("data") != row \
					or source.get("companionId") != comp_id \
					or source.get("sourceSha256") != catalog.ruleSha \
					or source.get("authorSha256") != catalog.dataSha \
					or source.get("derivedCatalogSha256") != CATALOG_SHA \
					or source.get("derivedCatalogPointer") != \
					"$.cards.%s[%d]" % [comp_id,i]:
				last_error = "道侣弧线生成卡来源登记不符"
				return {}
			var card: Dictionary = row.duplicate(true)
			card.realm = realm
			card.semanticKey = card.get("semanticKey", "companion-arc:" + card_id)
			for direction in ["left", "right"]:
				var option: Variant = card.get("choices", {}).get(direction)
				if not option is Dictionary or not option.get("text") is String \
						or String(option.text).is_empty() \
						or not option.get("effects") is Dictionary:
					card.choices.erase(direction)
			if card.choices.is_empty():
				return {}
			var portraits: Variant = _content.read_module(PORTRAITS)
			var stages: Variant = portraits.get("portraitStages", {}).get(
				comp_id, {}).get("stages", []) if portraits is Dictionary else []
			if not stages is Array or stages.is_empty() or not stages[0] is Dictionary:
				return {}
			var image_path := String(stages[0].get("asset", ""))
			var image_status: Dictionary = _content.asset_status(image_path)
			if not image_status.get("shaVerified", false) \
					or not image_status.get("textureLoadable", false):
				return {}
			card.sceneImage = image_path
			return card
	return {}


func card(state: Dictionary) -> Dictionary:
	if state.get("phase") != "COMPANION_ARC_PENDING" or not valid(state):
		return {}
	var checkpoint: Dictionary = state.get("decisionCheckpoint", {})
	var projected := _project(String(checkpoint.get("compId", "")),
		String(state.get("currentCardId", "")), String(state.get("realm", "qi")))
	return projected if not projected.is_empty() and JSON.parse_string(
		JSON.stringify(projected)) == JSON.parse_string(JSON.stringify(
			state.get("pendingCompanionArcCard", {}))) else {}


func choice_available(state: Dictionary, direction: String) -> bool:
	return card(state).get("choices", {}).has(direction)


func settle(state: Dictionary, direction: String) -> Dictionary:
	last_error = ""
	var current := card(state)
	if current.is_empty() or not choice_available(state, direction):
		return {}
	var candidate := state.duplicate(true)
	var choice: Dictionary = current.choices[direction]
	var next_index := int(state.runClock.decisionIndex) + 1
	for key in choice.get("effects", {}):
		if not _apply_attribute(candidate, String(key), choice.effects[key]):
			return {}
	if not _events._apply_companion_effects(candidate, current, choice,
			direction, next_index) or not _choice_policy._apply_passive_regen(candidate):
		return {}
	if choice.has("karmaSeed") and not MilestoneFlow.new(_content)._plant_seed(
			candidate, current, choice, direction, next_index):
		return {}
	var receipt := "decision:%s:choice:%s:%d" % [state.runClock.lifeId,
		current.id, next_index]
	if candidate.runClock.receipts.has(receipt):
		return {}
	candidate.runClock.receipts[receipt] = {"token": receipt,
		"decisionIndex": next_index, "sourceCardId": current.id, "kind": "choice"}
	var record := {"cardId": current.id, "cardType": current.type,
		"direction": direction, "turn": next_index - 1,
		"decisionIndex": next_index, "tags": current.tags.duplicate(true)}
	if not candidate.has("replayHistory"):
		candidate.replayHistory = candidate.get("choiceHistory", []).duplicate(true)
	candidate.replayHistory.append(record.duplicate(true))
	candidate.choiceHistory.append(record)
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
	var arc: Dictionary = candidate.companionArcState
	var comp_id := String(current.compId)
	var own: Dictionary = arc.states.get(comp_id, {})
	var queue: Array = arc.pendingClimaxes if current.arcStage in [
		"SECRET", "CLIMAX", "DESTINY_CLIMAX"] else arc.pendingEvents
	var queue_index := queue.find({"compId": comp_id, "cardId": current.id})
	if own.is_empty() or queue_index < 0:
		return {}
	queue.pop_at(queue_index)
	own.eventsTriggered.append(current.id)
	if current.arcStage in ["CLIMAX", "DESTINY", "DESTINY_CLIMAX"]:
		own.climaxTriggered = true
	if current.arcStage == "SECRET":
		own.secretsRevealed.append(current.id)
	candidate.erase("pendingCompanionArcCard")
	if not candidate.get("noncombatFlow") is Dictionary:
		return {}
	var promise_id := "promise:%08x" % _events._fnv32("life:%d|%s|%s|%s" % [
		int(state.get("lifeCount", 0)), current.semanticKey, current.id, direction])
	var result_id := "promise_result_%08x" % _events._fnv32(promise_id)
	var response := "你在「%s」中选择了「%s」。这段因缘已给出明确回应。" % [
		current.title, choice.text]
	var result := {"id": result_id, "semanticKey": "promise-result:" + promise_id,
		"type": "NARRATIVE_RESULT", "title": String(current.title) + "·回应",
		"description": response, "sceneImage": current.sceneImage,
		"promiseId": promise_id, "originCardId": current.id,
		"originChoice": direction, "_narrativeLane": "primary",
		"_narrativeThreadKey": "promise:" + promise_id,
		"_narrativeSticky": true, "narrativeTtlTurns": 4, "once": true,
		"tags": ["narrative_result", "promise_resolution"],
		"choices": {"left": {"text": "记下这段回应", "effects": {},
			"resolution": {"kind": "promise_resolved", "promiseId": promise_id},
			"feedbackCue": {"kind": "promise_resolved", "text": response,
				"lane": "narrative"}}}}
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


func _apply_attribute(candidate: Dictionary, key: String, value: Variant) -> bool:
	if key not in NUMERIC_EFFECTS or not (value is int or value is float) \
			or float(value) != floor(float(value)):
		return false
	if key == "wisdom":
		var knowledge: Dictionary = candidate.get("knowledge", {})
		knowledge["wisdom"] = int(knowledge.get("wisdom", 0)) + int(value)
		candidate["knowledge"] = knowledge
		return true
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
		if not (threshold is int or threshold is float):
			return false
		maximum = int(threshold)
	var delta := LegacyFragmentFlow.effective_delta(candidate, key, int(value))
	if key == "health" and delta < 0 and int(candidate.attributes.get("aura", 0)) > 0:
		var absorbed := mini(int(candidate.attributes.aura), -delta)
		candidate.attributes.aura = int(candidate.attributes.aura) - absorbed
		delta += absorbed
	candidate.attributes[key] = clampi(int(candidate.attributes.get(key, 0)) + delta,
		0, maximum)
	return true
