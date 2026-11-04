extends RefCounted

const MilestoneFlow = preload("res://scripts/noncombat_milestone_flow.gd")
const LegacyFragmentFlow = preload("res://scripts/noncombat_legacy_fragment_flow.gd")

# First-session source encounter avoidance. Produces one candidate snapshot;
# the domain persists it before publishing a result card or accepting input.
var _content: RefCounted
var _gateway: RefCounted
var legacy_replay := false
var legacy_schema_replay := false
var legacy_lifespan_replay := false


func _init(content: RefCounted, gateway: RefCounted) -> void:
	_content = content
	_gateway = gateway


func settle(state: Dictionary) -> Dictionary:
	var offer: Dictionary = _gateway.offer_from_state(state)
	var source_hash := String(_gateway.source_content_hash())
	var encounters: Dictionary = _dict(_content.read_module("combat:encounters"))
	var config: Dictionary = _dict(_content.read_module("combat:encounter_director"))
	if offer.is_empty() or source_hash.length() != 64 or config.is_empty():
		return {}
	var encounter: Dictionary = {}
	for entry in encounters.get("encounters", []):
		if entry is Dictionary and entry.get("id") == offer.get("encounterId"):
			encounter = entry
			break
	if encounter.is_empty() or encounter.get("path") != offer.get("path") \
			or encounter.get("realm") != offer.get("realm") \
			or encounter.get("teachingEncounter") != true:
		return {}
	var avoid: Dictionary = _dict(encounter.get("avoid"))
	var effects: Dictionary = _dict(avoid.get("effects", {}))
	if avoid.get("costCheck") not in [null, {}] or effects.is_empty():
		return {}
	var clock: Dictionary = _dict(state.get("runClock"))
	var base_index := int(clock.get("decisionIndex", -1))
	var life_id := String(clock.get("lifeId", ""))
	if base_index <= 0 or not life_id.ends_with(":life:0") \
			or state.get("currentCardId") != offer.get("sourceCardId"):
		return {}
	var candidate: Dictionary = state.duplicate(true)
	for key in effects:
		var value: Variant = effects[key]
		if not (value is int or value is float) or float(value) != float(int(value)):
			return {}
		match String(key):
			"knowledge":
				var knowledge: Dictionary = _dict(candidate.get("knowledge"))
				knowledge["world"] = int(knowledge.get("world", 0)) + int(value)
				candidate["knowledge"] = knowledge
			"health":
				candidate["attributes"]["health"] = clampi(
					int(candidate["attributes"]["health"]) + int(value),
					0, LegacyFragmentFlow.actual_max_health(candidate))
			"fortune":
				candidate["attributes"]["fortune"] = clampi(
					int(candidate["attributes"]["fortune"]) + int(value), 0, 100)
			_:
				return {}
	var source_id := String(offer["sourceCardId"])
	var encounter_id := String(offer["encounterId"])
	var category := String(encounter.get("category", ""))
	var tags := ["combat", "encounter", category]
	var next_index := base_index + 1
	candidate["choiceHistory"].append({"cardId": source_id, "cardType": "COMBAT",
		"direction": "right", "turn": int(state.get("turn", base_index)),
		"decisionIndex": next_index, "tags": tags.duplicate(true)})
	while candidate["choiceHistory"].size() > 30:
		candidate["choiceHistory"].pop_front()
	for tag in tags:
		if not String(tag).is_empty():
			candidate["recentCardTags"].append(tag)
	while candidate["recentCardTags"].size() > 20:
		candidate["recentCardTags"].pop_front()
	candidate["turn"] = next_index
	candidate["runClock"]["decisionIndex"] = next_index
	var receipt := "decision:%s:choice:%s:%d" % [life_id, source_id, next_index]
	if candidate["runClock"]["receipts"].has(receipt):
		return {}
	candidate["runClock"]["receipts"][receipt] = {"token": receipt,
		"decisionIndex": next_index, "sourceCardId": source_id, "kind": "choice"}
	# Web GameLogic._shouldConsumeLifespan charges every COMBAT-card decision,
	# including avoidance, after applying the authored avoid effects.
	if not legacy_lifespan_replay:
		candidate["resources"]["lifespan"] = maxi(0,
			int(candidate["resources"].get("lifespan", 0)) - 1)
	if not legacy_replay:
		MilestoneFlow.tick_seeds(candidate)
	var director: Dictionary = _director_state(state, offer, encounter, config, base_index)
	if director.is_empty():
		return {}
	var result: Dictionary = _result_card(offer, encounter, avoid)
	if result.is_empty():
		return {}
	candidate["noncombatFlow"] = {"version": 1, "scope": "first_session_avoid",
		"sourceContentHash": source_hash,
		"encounterDirectorState": director, "pendingResultCard": result.duplicate(true),
		"resumePolicy": "await_general_flow"}
	if not legacy_schema_replay:
		candidate["noncombatFlow"]["promise"] = {"id": result["promiseId"], "status": "pending",
			"sourceCardId": source_id, "sourceSemanticKey": "card:" + source_id,
			"sourceTitle": offer["title"], "choiceDirection": "right",
			"createdDecisionIndex": next_index, "dueWithinDecisions": 2,
			"dueDecisionIndex": next_index + 2, "followUpCardId": result["id"],
			"resolvedDecisionIndex": null, "resolutionCardId": null}
	if not legacy_replay:
		candidate["noncombatFlow"]["karmaClockVersion"] = 1
	if not legacy_lifespan_replay:
		candidate["noncombatFlow"]["lifespanCostVersion"] = 1
	candidate["pendingNarrativeResult"] = result.duplicate(true)
	candidate["currentCardId"] = result["id"]
	candidate["phase"] = "NARRATIVE_RESULT_PENDING"
	candidate["decisionCheckpoint"] = {"version": 1, "cardId": result["id"],
		"sourceCardId": source_id, "turn": next_index,
		"decisionIndex": next_index}
	return candidate


func _director_state(state: Dictionary, offer: Dictionary, encounter: Dictionary,
		config: Dictionary, base_index: int) -> Dictionary:
	var minimum := int(config.get("cadenceDecisionMin", 0))
	var maximum := int(config.get("cadenceDecisionMax", 0))
	var cooldown := int(config.get("postEncounterCooldown", -1))
	if minimum <= 0 or maximum < minimum or cooldown < 0:
		return {}
	var path_id := String(offer["path"])
	var interval_key := "0|%s|%s|0" % [offer["realm"], path_id]
	var interval := minimum + int(_fnv32(interval_key) % (maximum - minimum + 1))
	var encounter_id := String(offer["encounterId"])
	var source_id := String(offer["sourceCardId"])
	var narrative_source := String(encounter.get("narrativeSource",
		"encounter_catalog:%s:%s" % [encounter.get("category", ""), encounter_id]))
	var shared := {"encounterId": encounter_id, "cardId": source_id,
		"encounterKind": String(encounter.get("encounterKind", "ordinary")),
		"role": String(encounter.get("encounterRole", "ordinary")),
		"narrativeSource": narrative_source}
	var history := []
	for event in ["scheduled", "presented", "avoided"]:
		var item: Dictionary = {"event": event, "decision": base_index,
			"realm": offer["realm"], "path": path_id}
		item.merge(shared)
		if event in ["scheduled", "presented"]:
			item["reason"] = "teaching"
			item["scheduledDecision"] = base_index + 1
		else:
			item["direction"] = "right"
			item["nextInterval"] = interval
		history.append(item)
	var counts := {"ordinary": 0, "elite": 0, "relationship": 0,
		"quest": 0, "boss": 0}
	var seen: Dictionary = counts.duplicate()
	seen["ordinary"] = 1
	return {"version": 2, "lifeId": 0, "firstTeachingStatus": "avoided",
		"lastResolvedDecision": null, "lastPresentedDecision": base_index + 1,
		"nextDueDecision": base_index + 1 + interval,
		"cooldownUntilDecision": base_index + cooldown,
		"pending": null, "realmProgress": {String(offer["realm"]): {
			"presentedIds": [encounter_id], "resolvedIds": [],
			"avoidedIds": [encounter_id], "counts": counts, "seenCounts": seen}},
		"history": history}


func _result_card(offer: Dictionary, encounter: Dictionary, avoid: Dictionary) -> Dictionary:
	var source_id := String(offer["sourceCardId"])
	var semantic := "card:" + source_id
	var promise_id := "promise:%08x" % _fnv32("life:0|%s|%s|right" % [semantic, source_id])
	var result_id := "promise_result_%08x" % _fnv32(promise_id)
	var description := String(avoid.get("narrativeBlock", "")).strip_edges()
	if description.is_empty():
		var prefix := String(avoid.get("desc", ""))
		if prefix.is_empty():
			prefix = "你没有立刻迎战%s。" % encounter.get("enemy", {}).get("name", "")
		var world_story := String(encounter.get("worldStory", ""))
		if world_story.is_empty():
			world_story = String(encounter.get("mechanic", ""))
		description = (prefix + " " + world_story).strip_edges()
	if description.is_empty():
		return {}
	if legacy_schema_replay:
		return {"id": result_id, "type": "NARRATIVE_RESULT",
			"title": String(offer["title"]) + "·回应", "description": description,
			"sceneImage": offer["sceneImage"], "promiseId": promise_id,
			"originCardId": source_id, "originChoice": "right",
			"tags": ["narrative_result", "promise_resolution"],
			"choices": {"left": {"text": "记下这段回应", "effects": {}}}}
	return {"id": result_id, "semanticKey": "promise-result:" + promise_id,
		"type": "NARRATIVE_RESULT",
		"title": String(offer["title"]) + "·回应", "description": description,
		"sceneImage": offer["sceneImage"], "promiseId": promise_id,
		"originCardId": source_id, "originChoice": "right",
		"_narrativeLane": "primary", "_narrativeThreadKey": "promise:" + promise_id,
		"_narrativeSticky": true, "narrativeTtlTurns": 4, "once": true,
		"tags": ["narrative_result", "promise_resolution"],
		"choices": {"left": {"text": "记下这段回应", "effects": {},
			"resolution": {"kind": "promise_resolved", "promiseId": promise_id},
			"feedbackCue": {"kind": "promise_resolved", "text": description,
				"lane": "narrative"}}}}


func _fnv32(value: String) -> int:
	var hash := 2166136261
	for index in value.length():
		hash = ((hash ^ value.unicode_at(index)) * 16777619) & 0xffffffff
	return hash


func _dict(value: Variant) -> Dictionary:
	return value if value is Dictionary else {}
