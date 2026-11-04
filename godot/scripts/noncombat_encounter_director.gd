extends RefCounted

# EncounterDirector's accumulated lifecycle only. Callers own eligibility,
# card materialization, global priority, decision commits and persistence.
const MODULE := "combat:encounter_director"
const SOURCE_JS_SHA := "ff77500fe64a052a6b6014cfa02ad46f5071b20de36ac81184c970aec0418496"
const ROLE_ORDER := ["ordinary", "elite", "relationship", "quest"]
var last_error := ""
var source_error := ""
var _content: RefCounted


func _init(content: RefCounted) -> void:
	_content = content


func source_rule_pins() -> Dictionary:
	var config := _config()
	if config.is_empty():
		return {}
	return {"src/systems/EncounterDirector.js": SOURCE_JS_SHA,
		"data/combat/encounter_director.json": _content.source_sha256(MODULE)}


func initial_state(life_id: int) -> Dictionary:
	var config := _config()
	if config.is_empty() or life_id < 0:
		return {}
	return {"version": 2, "lifeId": life_id,
		"firstTeachingStatus": "pending", "lastResolvedDecision": null,
		"lastPresentedDecision": null, "nextDueDecision": int(config.firstMin),
		"cooldownUntilDecision": 0, "pending": null,
		"realmProgress": {}, "history": []}


func schedule(state: Dictionary, candidates: Array) -> Dictionary:
	var config := _config()
	var director := _director(state)
	if config.is_empty() or director.is_empty():
		return {}
	var pending: Variant = director.get("pending")
	if pending is Dictionary:
		var restored: Dictionary = {}
		for card in candidates:
			if card is Dictionary and card.get("id") == pending.get("cardId"):
				restored = card
				break
		var reason := ""
		if pending.get("realm") != state.get("realm", "qi"):
			reason = "realm_mismatch"
		elif not restored.is_empty() and restored.get("path") != null \
				and restored.get("path") != "" and restored.get("path") != state.get("path"):
			reason = "path_mismatch"
		elif restored.is_empty():
			# Candidates are the caller's authoritative eligibility projection.
			# A missing/inaccessible catalog itself is rejected by that producer.
			reason = "eligibility_changed"
		if not reason.is_empty():
			director["pending"] = null
			_record(director, state, "invalidated", {"encounterId": pending.get("encounterId"),
				"cardId": pending.get("cardId"), "encounterKind": restored.get(
					"encounterKind", pending.get("encounterKind")), "reason": reason})
			return director
		# Pending ownership survives a later cooldown or due-date change. The
		# source's _restorePendingCard deliberately skips canPresent here.
		_present(director, state, restored)
		return director
	var turn := _turn(state)
	var teaching: bool = director.get("firstTeachingStatus") != "resolved" \
		and turn + 1 >= int(config.firstMin)
	var cadence: bool = director.get("firstTeachingStatus") == "resolved" \
		and int(director.get("nextDueDecision", 0)) > 0 \
		and turn + 1 >= maxi(int(director.nextDueDecision),
			int(director.get("cooldownUntilDecision", 0)) + 1)
	if (not teaching and not cadence) or turn < int(director.get("cooldownUntilDecision", 0)):
		return {}
	var progress := _progress(director, String(state.get("realm", "qi")))
	var eligible: Array = []
	for value in candidates:
		if not value is Dictionary:
			continue
		var card: Dictionary = value
		if String(card.get("id", "")).is_empty() or String(card.get("encounterId", "")).is_empty() \
				or card.get("encounterKind") == "realm_boss" or card.get("encounterRole") == "boss":
			continue
		if card.get("once") != false and progress.resolvedIds.has(card.encounterId):
			continue
		if teaching and (card.get("teachingEncounter") != true or _role(card) != "ordinary"):
			continue
		eligible.append(card)
	var card := _select(eligible, progress, config, teaching)
	if card.is_empty():
		return {}
	var reason := "teaching" if teaching else "cadence"
	director["pending"] = {"cardId": card.id, "encounterId": card.encounterId,
		"encounterKind": card.get("encounterKind"), "role": _role(card),
		"realm": state.get("realm", "qi"), "path": state.get("path"), "reason": reason,
		"scheduledDecision": turn + 1, "presented": false, "accepted": false}
	var payload := _payload(card)
	payload.merge({"reason": reason, "scheduledDecision": turn + 1})
	_record(director, state, "scheduled", payload)
	_present(director, state, card)
	return director


func accepted(state: Dictionary, card: Dictionary, direction: String = "left") -> Dictionary:
	var config := _config()
	var director := _director(state)
	if config.is_empty() or director.is_empty() or not _owns(director, card):
		return {}
	_accept(director, state, card, direction)
	return director


func settled(state: Dictionary, card: Dictionary, outcome: String,
		direction: String = "left") -> Dictionary:
	var config := _config()
	var director := _director(state)
	if config.is_empty() or director.is_empty() or not _owns(director, card) \
			or outcome not in ["victory", "defeat", "flee", "avoided"]:
		return {}
	var avoided := outcome == "avoided"
	if not avoided:
		_accept(director, state, card, direction)
	var pending: Dictionary = director.pending
	var presentation := int(pending.get("scheduledDecision", 0))
	if presentation == 0:
		presentation = _turn(state)
	var realm := String(card.get("realm", state.get("realm", "qi")))
	var progress := _progress(director, realm)
	if avoided:
		progress.avoidedIds.append(card.encounterId)
		if director.firstTeachingStatus != "resolved":
			director.firstTeachingStatus = "avoided"
	else:
		if not progress.resolvedIds.has(card.encounterId):
			progress.resolvedIds.append(card.encounterId)
		var role := _role(card)
		progress.counts[role] = int(progress.counts.get(role, 0)) + 1
		if card.get("teachingEncounter") == true or pending.get("reason") == "teaching":
			director.firstTeachingStatus = "resolved"
		director.lastResolvedDecision = _turn(state)
	var interval := _next_interval(director, state, config)
	director.cooldownUntilDecision = _turn(state) + int(config.cooldown)
	director.nextDueDecision = presentation + interval
	director.pending = null
	var payload := _payload(card)
	payload["nextInterval"] = interval
	payload["direction" if avoided else "outcome"] = direction if avoided else outcome
	_record(director, state, "avoided" if avoided else "resolved", payload)
	return director


func is_hard_due(state: Dictionary) -> bool:
	var config := _config()
	var director := _director(state)
	if config.is_empty() or director.is_empty() or director.firstTeachingStatus != "resolved" \
			or director.get("pending") != null or _turn(state) < int(director.cooldownUntilDecision):
		return false
	var latest := maxi(int(config.intervalMin), int(config.visibleCadenceMax) - int(config.prioritySettlementReserve))
	# Number(null) is zero in the production predicate, including realm-change state.
	return _turn(state) + 1 - _number(director.get("lastPresentedDecision")) >= latest


func can_start_authored_sequence(state: Dictionary, cost: int) -> bool:
	var config := _config()
	var director := _director(state)
	if config.is_empty() or director.is_empty():
		return false
	if director.firstTeachingStatus != "resolved" or director.get("pending") != null:
		return true
	return _turn(state) + 1 - _number(director.get("lastPresentedDecision")) + maxi(0, cost) \
		<= int(config.visibleCadenceMax)


func _config() -> Dictionary:
	last_error = ""
	source_error = ""
	var doc: Variant = _content.read_module(MODULE)
	if not doc is Dictionary or _content.source_sha256(MODULE).length() != 64:
		last_error = "遭遇排期规则来源不可用或已变化"
		var source_path: String = _content.module_path(MODULE)
		source_error = "SOURCE_UNAVAILABLE" if source_path.is_empty() \
			or not FileAccess.file_exists("res://content/" + source_path) else "SOURCE_MISMATCH"
		return {}
	var minimums: Dictionary = doc.get("realmMinimums", {})
	return {"firstMin": _setting(doc, "firstEncounterDecisionMin", 4, 1),
		"intervalMin": _setting(doc, "cadenceDecisionMin", 7, 1),
		"intervalMax": _setting(doc, "cadenceDecisionMax", 12, 1),
		"visibleCadenceMax": maxi(_setting(doc, "cadenceDecisionMax", 12, 1),
			_setting(doc, "visibleCadenceDecisionMax", 12, 0)),
		"prioritySettlementReserve": _setting(doc, "prioritySettlementDecisionReserve", 0, 0),
		"cooldown": _setting(doc, "postEncounterCooldown", 3, 0),
		"ordinary": _setting(minimums, "ordinary", 2, 0),
		"relationshipOrQuest": _setting(minimums, "relationshipOrQuest", 1, 0),
		"elite": _setting(minimums, "elite", 1, 0)}


func _director(state: Dictionary) -> Dictionary:
	var raw: Variant = state.get("noncombatFlow", {}).get("encounterDirectorState")
	if not raw is Dictionary or raw.get("version") != 2 \
			or not raw.get("realmProgress") is Dictionary or not raw.get("history") is Array:
		last_error = "累计遭遇排期状态缺失"
		return {}
	var life := int(state.get("lifeCount", state.get("unlocks", {}).get("lifeCount", 0)))
	if raw.get("lifeId") != life:
		last_error = "遭遇排期不属于当前世"
		return {}
	return raw.duplicate(true)


func _setting(doc: Dictionary, key: String, fallback: int, minimum: int) -> int:
	var value: Variant = doc.get(key)
	return maxi(minimum, floori(float(value)) if value != null and float(value) != 0.0 else fallback)


func _number(value: Variant) -> int:
	return int(value) if value != null else 0


func _turn(state: Dictionary) -> int:
	return maxi(0, int(state.get("turn", 0)))


func _progress(director: Dictionary, realm: String) -> Dictionary:
	if not director.realmProgress.has(realm):
		var counts := {"ordinary": 0, "elite": 0, "relationship": 0, "quest": 0, "boss": 0}
		director.realmProgress[realm] = {"presentedIds": [], "resolvedIds": [], "avoidedIds": [],
			"counts": counts.duplicate(), "seenCounts": counts.duplicate()}
	return director.realmProgress[realm]


func _role(card: Dictionary) -> String:
	if card.get("encounterRole") != null and not String(card.get("encounterRole", "")).is_empty():
		return String(card.encounterRole)
	return {"factionElite": "elite", "companionQuest": "relationship", "heavenChaos": "quest",
		"realmBoss": "boss"}.get(card.get("category", ""), "ordinary")


func _select(candidates: Array, progress: Dictionary, config: Dictionary, teaching: bool) -> Dictionary:
	var seen: Dictionary = progress.get("seenCounts", {})
	var quota := "ordinary" if int(seen.get("ordinary", 0)) < int(config.ordinary) else (
		"relationshipOrQuest" if int(seen.get("relationship", 0)) + int(seen.get("quest", 0)) \
		< int(config.relationshipOrQuest) else ("elite" if int(seen.get("elite", 0)) < int(config.elite) else ""))
	var pool: Array = []
	for card in candidates:
		var role := _role(card)
		if quota.is_empty() or role == quota or quota == "relationshipOrQuest" and role in ["relationship", "quest"]:
			pool.append(card)
	if pool.is_empty():
		pool = candidates.duplicate()
	pool.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		for key in ["resolvedIds", "presentedIds"]:
			var left_seen: bool = progress[key].has(left.encounterId)
			var right_seen: bool = progress[key].has(right.encounterId)
			if left_seen != right_seen:
				return not left_seen
		if not teaching:
			var left_role := _role(left)
			var right_role := _role(right)
			var left_count := int(seen.get(left_role, 0))
			var right_count := int(seen.get(right_role, 0))
			if left_count != right_count:
				return left_count < right_count
			if left_role != right_role:
				return ROLE_ORDER.find(left_role) < ROLE_ORDER.find(right_role)
		return String(left.id).casecmp_to(String(right.id)) < 0)
	return pool[0] if not pool.is_empty() else {}


func _owns(director: Dictionary, card: Dictionary) -> bool:
	return not String(card.get("encounterId", "")).is_empty() and director.get("pending") is Dictionary \
		and director.pending.get("cardId") == card.get("id")


func _payload(card: Dictionary) -> Dictionary:
	return {"encounterId": card.encounterId, "cardId": card.id,
		"encounterKind": card.get("encounterKind"), "role": _role(card),
		"narrativeSource": card.get("narrativeSource")}


func _present(director: Dictionary, state: Dictionary, card: Dictionary) -> void:
	if director.pending.get("presented", false):
		return
	director.pending.presented = true
	var scheduled := int(director.pending.get("scheduledDecision", 0))
	director.lastPresentedDecision = maxi(1, scheduled if scheduled != 0 else _turn(state) + 1)
	var progress := _progress(director, String(state.get("realm", "qi")))
	if not progress.presentedIds.has(card.encounterId):
		progress.presentedIds.append(card.encounterId)
		var role := _role(card)
		progress.seenCounts[role] = int(progress.seenCounts.get(role, 0)) + 1
	if director.pending.reason == "teaching" and director.firstTeachingStatus == "pending":
		director.firstTeachingStatus = "presented"
	var payload := _payload(card)
	payload.merge({"role": director.pending.role, "reason": director.pending.reason,
		"scheduledDecision": director.lastPresentedDecision}, true)
	_record(director, state, "presented", payload)


func _accept(director: Dictionary, state: Dictionary, card: Dictionary, direction: String) -> void:
	if director.pending.get("accepted", false):
		return
	director.pending.accepted = true
	var payload := _payload(card)
	payload["direction"] = direction
	_record(director, state, "accepted", payload)


func _record(director: Dictionary, state: Dictionary, event: String, payload: Dictionary) -> void:
	var row := {"event": event, "decision": _turn(state), "realm": state.get("realm", "qi"), "path": state.get("path")}
	row.merge(payload, true)
	director.history.append(row)
	while director.history.size() > 80:
		director.history.pop_front()


func _next_interval(director: Dictionary, state: Dictionary, config: Dictionary) -> int:
	var count := 0
	for progress in director.realmProgress.values():
		count += progress.get("resolvedIds", []).size()
	var minimum := mini(int(config.intervalMin), int(config.intervalMax))
	var maximum := maxi(int(config.intervalMin), int(config.intervalMax))
	var path_id: Variant = state.get("path")
	var key := "%d|%s|%s|%d" % [int(director.lifeId), state.get("realm", "qi"),
		path_id if path_id != null else "null", count]
	var hash := 2166136261
	for index in key.length():
		hash = ((hash ^ key.unicode_at(index)) * 16777619) & 0xffffffff
	return minimum + hash % (maximum - minimum + 1)
