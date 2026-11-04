extends RefCounted

# Source-backed presentation and right-choice settlement for the authored
# teaching-reward -> mountain path -> first market continuation. The domain
# owns persistence, interrupts, passive regeneration, combat and vendor entry.
const Repository = preload("res://scripts/noncombat_content_repository.gd")
const MilestoneFlow = preload("res://scripts/noncombat_milestone_flow.gd")
const ROUTE_ID := "q_mountain_shadow_approach"
const MARKET_ID := "loc_market_first"
const MODULES := ["cards:qi", "progression:first_session_cohesion", "locations:locations"]

var _content: RefCounted
var last_error := ""
var source_error := ""


func _init(content: RefCounted = null) -> void:
	_content = content if content != null else Repository.new()


func source_hashes() -> Dictionary:
	last_error = ""
	source_error = ""
	var hashes := {}
	for module_id in MODULES:
		var sha: String = _content.source_sha256(module_id)
		if sha.length() != 64:
			last_error = "首局路线来源数据未通过校验：" + module_id
			var path: String = _content.module_path(module_id)
			source_error = "SOURCE_UNAVAILABLE" if path.is_empty() \
				or not FileAccess.file_exists(Repository.CONTENT_ROOT + path) else "SOURCE_MISMATCH"
			return {}
		hashes[module_id] = sha
	return hashes


func card(state: Dictionary, card_id: String = "") -> Dictionary:
	last_error = ""
	source_error = ""
	var source_id := card_id if not card_id.is_empty() else String(state.get("currentCardId", ""))
	if state.get("realm") != "qi" or source_id not in [ROUTE_ID, MARKET_ID] \
			or source_hashes().is_empty():
		return {}
	var module_id := "cards:qi" if source_id == ROUTE_ID else "locations:locations"
	var document: Variant = _content.read_module(module_id)
	if not document is Dictionary:
		return {}
	var result := {}
	for raw in document.get("cards", []):
		if raw is Dictionary and raw.get("id") == source_id:
			result = raw.duplicate(true)
			break
	if result.is_empty() or result.get("realm") != state.get("realm"):
		return {}
	if source_id == ROUTE_ID:
		result = _apply_route_lens(result, state)
	if result.is_empty() or not _scene_verified(String(result.get("sceneImage", ""))):
		return {}
	for presentation in result.get("choices", {}).get("left", {}).get(
			"combatOutcomePresentation", {}).values():
		if not _scene_verified(String(presentation.get("sceneImage", ""))):
			return {}
	return result


func enter(state: Dictionary, card_id: String) -> Dictionary:
	var current := card(state, card_id)
	if current.is_empty():
		return {}
	var hashes := source_hashes()
	if hashes.is_empty():
		return {}
	var candidate := state.duplicate(true)
	var flow: Dictionary = candidate.get("noncombatFlow", {})
	flow["firstSessionRouteSourceHashes"] = hashes
	candidate["noncombatFlow"] = flow
	candidate["currentCardId"] = card_id
	candidate["phase"] = "FIRST_SESSION_ROUTE_PENDING"
	candidate["decisionCheckpoint"] = {"version": 1, "cardId": card_id,
		"sourceCardId": state.get("decisionCheckpoint", {}).get("sourceCardId",
			state.get("currentCardId", "")),
		"turn": state.get("turn", 0),
		"decisionIndex": state.get("runClock", {}).get("decisionIndex", 0),
		"flowSource": "first_session_route"}
	# GameLogic._syncCardDrivenLocation calls SceneLayerSystem.transition.
	# That method records presence; visits belong to the separate card draw.
	var location := String(current.get("location", ""))
	if not location.is_empty() and not current.get("requiresPlayerPresence", false) \
			and state.get("currentLocation") != location:
		candidate["currentLocation"] = location
		var visited: Array = candidate.get("visitedLocations", [])
		if not visited.has(location):
			visited.append(location)
		candidate["visitedLocations"] = visited
	return candidate


func settle_right(state: Dictionary) -> Dictionary:
	last_error = ""
	source_error = ""
	if state.get("phase") != "FIRST_SESSION_ROUTE_PENDING":
		return {}
	var hashes := source_hashes()
	if hashes.is_empty():
		return {}
	if state.get("noncombatFlow", {}).get(
			"firstSessionRouteSourceHashes") != hashes:
		last_error = "首局路线存档与来源数据版本不一致"
		source_error = "SOURCE_MISMATCH"
		return {}
	var current := card(state)
	var choice: Dictionary = current.get("choices", {}).get("right", {})
	if current.is_empty() or not choice.get("effects") is Dictionary \
			or not choice["effects"].is_empty() or choice.has("action") \
			or choice.has("costCheck") or choice.get("triggerCombat", false):
		return {}
	var source_id := String(current["id"])
	if source_id == ROUTE_ID and not _serial_matches(state, current, choice):
		return {}
	var clock: Dictionary = state.get("runClock", {})
	var base_index := int(clock.get("decisionIndex", -1))
	var life_id := String(clock.get("lifeId", ""))
	var life_count := int(state.get("lifeCount", 0))
	if base_index < 0 or life_count < 0 or not life_id.ends_with(":life:" + str(life_count)):
		return {}
	var next_index := base_index + 1
	var receipt := "decision:%s:choice:%s:%d" % [life_id, source_id, next_index]
	if clock.get("receipts", {}).has(receipt):
		return {}
	var candidate := state.duplicate(true)
	var tags: Array = current.get("tags", [])
	var record := {"cardId": source_id, "cardType": current["type"],
		"direction": "right", "turn": int(state.get("turn", base_index)),
		"decisionIndex": next_index, "tags": tags.duplicate(true)}
	if not candidate.has("replayHistory"):
		candidate["replayHistory"] = candidate["choiceHistory"].duplicate(true)
	candidate["replayHistory"].append(record.duplicate(true))
	candidate["choiceHistory"].append(record)
	while candidate["choiceHistory"].size() > 30:
		candidate["choiceHistory"].pop_front()
	for tag in tags:
		candidate["recentCardTags"].append(tag)
	while candidate["recentCardTags"].size() > 20:
		candidate["recentCardTags"].pop_front()
	candidate["cardsPlayed"].append(source_id)
	candidate["turn"] = next_index
	candidate["runClock"]["decisionIndex"] = next_index
	candidate["runClock"]["receipts"][receipt] = {"token": receipt,
		"decisionIndex": next_index, "sourceCardId": source_id, "kind": "choice"}
	MilestoneFlow.tick_seeds(candidate)
	candidate["decisionCheckpoint"] = {"version": 1, "cardId": null,
		"sourceCardId": source_id, "turn": next_index, "decisionIndex": next_index}
	if source_id == ROUTE_ID:
		return enter(candidate, String(choice["nextCard"]))
	var result := _market_result(current, life_count)
	if result.is_empty() or candidate["noncombatFlow"].has("pendingResultCard"):
		return {}
	candidate["noncombatFlow"]["firstSessionRoutePromise"] = {
		"id": result["promiseId"], "status": "pending", "sourceCardId": source_id,
		"sourceSemanticKey": current.get("semanticKey", "card:" + source_id),
		"sourceTitle": current["title"], "choiceDirection": "right",
		"createdDecisionIndex": next_index, "dueWithinDecisions": 2,
		"dueDecisionIndex": next_index + 2, "followUpCardId": result["id"],
		"resolvedDecisionIndex": null, "resolutionCardId": null}
	candidate["noncombatFlow"]["pendingResultCard"] = result.duplicate(true)
	candidate["pendingNarrativeResult"] = result.duplicate(true)
	candidate["currentCardId"] = result["id"]
	candidate["phase"] = "NARRATIVE_RESULT_PENDING"
	candidate["decisionCheckpoint"]["cardId"] = result["id"]
	return candidate


func _apply_route_lens(source: Dictionary, state: Dictionary) -> Dictionary:
	# CardSystem._applyFirstSessionRouteLens: shallow choice/outcome overlays
	# retain the source combat binding while replacing the authored path text.
	var manifest: Variant = _content.read_module("progression:first_session_cohesion")
	if not manifest is Dictionary:
		return {}
	var path_id := String(state.get("path", ""))
	var ref: Dictionary = manifest.get("paths", {}).get(path_id, {}).get("routeLensRef", {})
	var lens_key := String(ref.get("variantKey", "")) if ref.get("cardId") == source["id"] else ""
	var lens: Dictionary = manifest.get("routeLenses", {}).get(lens_key, {})
	if lens.is_empty():
		return source
	if lens.get("description") is String and not String(lens["description"]).strip_edges().is_empty():
		source["description"] = lens["description"]
	for direction in ["left", "right"]:
		if lens.get("choices", {}).get(direction) is Dictionary \
				and source.get("choices", {}).get(direction) is Dictionary:
			source["choices"][direction].merge(lens["choices"][direction], true)
			if source["choices"][direction].get("continuityClass") == "first_session_serial":
				source["choices"][direction].erase("promise")
	var outcomes: Dictionary = source.get("choices", {}).get("left", {}).get("combatOutcomePresentation", {})
	if not outcomes.is_empty():
		var scene := String(source.get("sceneImage", outcomes.get("victory", {}).get("sceneImage", "")))
		for outcome in ["victory", "defeat", "flee"]:
			if not lens.get("outcomes", {}).get(outcome) is Dictionary:
				continue
			var presentation: Dictionary = outcomes.get(outcome, {})
			presentation.merge(lens["outcomes"][outcome], true)
			if not scene.is_empty() and not presentation.get("sceneImage"):
				presentation["sceneImage"] = scene
			outcomes[outcome] = presentation
	source["_firstSessionCohesion"] = {"id": manifest["id"], "path": path_id, "lensKey": lens_key}
	return source


func _serial_matches(state: Dictionary, current: Dictionary, choice: Dictionary) -> bool:
	var manifest: Dictionary = _content.read_module("progression:first_session_cohesion")
	var serial: Dictionary = manifest.get("serialDelivery", {})
	var ref: Dictionary = manifest.get("paths", {}).get(state.get("path", ""), {}).get("routeLensRef", {})
	var recovery: Dictionary = serial.get("preemptionRecovery", {})
	return ref.get("cardId") == current["id"] \
		and serial.get("from", {}).get("cardId") == current["id"] \
		and serial.get("from", {}).get("choice") == "right" \
		and choice.get("continuityClass") == serial.get("continuityClass") \
		and choice.get("nextCard") == serial.get("to", {}).get("cardId") \
		and choice.get("nextCard") == MARKET_ID \
		and recovery.get("resumeCardId") == MARKET_ID \
		and int(recovery.get("maxAdditionalTopLevelDecisions", 0)) == 1


func _market_result(current: Dictionary, life_count: int) -> Dictionary:
	# ChoiceOutcomeRouter._buildPromise; narrativeBlock is a follow-up scene.
	var narrative := String(current["choices"]["right"].get("narrativeBlock", "")).strip_edges()
	if narrative.is_empty():
		return {}
	var source_id := String(current["id"])
	var semantic := String(current.get("semanticKey", "card:" + source_id))
	var promise_id := "promise:%08x" % _fnv32("life:%d|%s|%s|right" % [life_count, semantic, source_id])
	var result_id := "promise_result_%08x" % _fnv32(promise_id)
	return {"id": result_id, "semanticKey": "promise-result:" + promise_id,
		"type": "NARRATIVE_RESULT", "title": String(current["title"]) + "·回应",
		"description": narrative, "promiseId": promise_id,
		"originCardId": source_id, "originChoice": "right",
		"_narrativeLane": "primary", "_narrativeThreadKey": "promise:" + promise_id,
		"_narrativeSticky": true, "narrativeTtlTurns": 4, "once": true,
		"tags": ["narrative_result", "promise_resolution"],
		"choices": {"left": {"text": "记下这段回应", "effects": {},
			"resolution": {"kind": "promise_resolved", "promiseId": promise_id},
			"feedbackCue": {"kind": "promise_resolved", "text": narrative, "lane": "narrative"}}}}


func _scene_verified(path: String) -> bool:
	var status: Dictionary = _content.asset_status(path)
	if not status.get("shaVerified", false) or not status.get("textureLoadable", false):
		last_error = "首局路线场景素材未通过校验：" + path
		source_error = "SOURCE_UNAVAILABLE" if status.get("fileExists") == false else "SOURCE_MISMATCH"
		return false
	return true


func _fnv32(value: String) -> int:
	var hash := 2166136261
	for index in value.length():
		hash = ((hash ^ value.unicode_at(index)) * 16777619) & 0xffffffff
	return hash
