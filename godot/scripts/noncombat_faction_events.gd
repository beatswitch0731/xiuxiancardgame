extends RefCounted

const Repository = preload("res://scripts/noncombat_content_repository.gd")
const QuestFlow = preload("res://scripts/noncombat_quest_flow.gd")
const DeckAcquisition = preload("res://scripts/noncombat_deck_acquisition.gd")
const LegacyFragmentFlow = preload("res://scripts/noncombat_legacy_fragment_flow.gd")
const MilestoneFlow = preload("res://scripts/noncombat_milestone_flow.gd")
const NormalChoicePolicy = preload("res://scripts/noncombat_normal_choice_policy.gd")
const MODULE := "world:factions"
const RULE_SHA := "2c15864821765f6614f8a99a5f52a648cb3221cd4d730d87293a1be5690243cc"
const REALMS := ["qi", "foundation", "golden", "nascent", "deity", "tribulation"]

var last_error := ""
var _content: RefCounted


func _init(content: RefCounted = null) -> void:
	_content = content if content != null else Repository.new()


func marker(activation_index: int) -> Dictionary:
	var source: Variant = _content.read_module(MODULE)
	var sha: String = _content.source_sha256(MODULE)
	if not source is Dictionary or not source.get("factions") is Array \
			or not source.get("undercurrents") is Dictionary or sha.length() != 64:
		last_error = "势力事件来源不可用"
		return {}
	return {"version": 1, "activationIndex": activation_index,
		"sourceSha": sha, "ruleSha": RULE_SHA}


func baseline_progress() -> Dictionary:
	var source: Variant = _content.read_module(MODULE)
	return QuestFlow.new(_content)._initial_faction_progress(source) \
		if source is Dictionary else {}


func valid(state: Dictionary) -> bool:
	var marker_value: Variant = state.get("factionEventState")
	var progress: Variant = state.get("factionProgress")
	if not marker_value is Dictionary or not progress is Dictionary \
			or marker_value.get("version") != 1 or marker_value.get("ruleSha") != RULE_SHA \
			or marker_value.get("sourceSha") != _content.source_sha256(MODULE) \
			or not _integer(marker_value.get("activationIndex")) \
			or int(marker_value.activationIndex) < 0 \
			or not progress.get("reputations") is Dictionary \
			or not progress.get("undercurrentStages") is Dictionary \
			or not progress.get("globalFlags") is Dictionary \
			or not _integer(progress.get("ticksSinceEvent")) \
			or int(progress.ticksSinceEvent) < 0:
		last_error = "势力事件进度或来源不符"
		return false
	return true


func collect(state: Dictionary) -> Dictionary:
	last_error = ""
	if state.get("phase") != "FLOW_PENDING" or not valid(state):
		return {}
	var candidate := state.duplicate(true)
	var progress: Dictionary = candidate.factionProgress
	progress.ticksSinceEvent = int(progress.ticksSinceEvent) + 1
	if candidate.get("pendingFactionCard") is Dictionary \
			or int(progress.ticksSinceEvent) < 15:
		return candidate
	var source: Variant = _content.read_module(MODULE)
	if not source is Dictionary:
		last_error = "势力事件来源不可用"
		return {}
	var pool := []
	var total := 0.0
	for faction in source.factions:
		if not faction is Dictionary:
			continue
		for event in faction.get("events", []):
			if not event is Dictionary or not _eligible(candidate, faction, event):
				continue
			var weight := float(event.get("weight", 10))
			if int(candidate.get("attributes", {}).get("fortune", 0)) > 60:
				weight += 3.0
			if event.get("pathRestriction") == candidate.get("path"):
				weight *= 1.5
			if weight <= 0.0:
				continue
			pool.append({"faction": faction, "event": event, "weight": weight})
			total += weight
	if pool.is_empty():
		return candidate
	var roll_key := "%s|%d|%d|faction" % [candidate.get("runClock", {}).get(
		"lifeId", ""), int(candidate.get("runClock", {}).get("decisionIndex", 0)),
		int(progress.ticksSinceEvent)]
	var roll := float(roll_key.hash() & 0x7fffffff) / 2147483648.0 * total
	var selected: Dictionary = pool.back()
	for row in pool:
		roll -= float(row.weight)
		if roll < 0.0:
			selected = row
			break
	var card_value := _build(candidate, selected.faction, selected.event)
	if card_value.is_empty():
		last_error = "势力事件卡无法由来源重建"
		return {}
	progress.ticksSinceEvent = 0
	candidate.pendingFactionCard = card_value
	return candidate


func take(state: Dictionary) -> Dictionary:
	if state.get("phase") != "FLOW_PENDING" or not valid(state):
		return {}
	var pending: Variant = state.get("pendingFactionCard")
	if not pending is Dictionary:
		return {}
	var projected := source_card(state, String(pending.get("id", "")),
		String(pending.get("realm", "")))
	if projected.is_empty() or not _same(projected, pending):
		last_error = "势力事件卡来源不符"
		return {}
	if pending.get("requiresPlayerPresence") == true \
			and not _locations_compatible(String(state.get("currentLocation", "")),
				String(pending.get("location", ""))):
		var expired := state.duplicate(true)
		expired.erase("pendingFactionCard")
		return expired
	var candidate := state.duplicate(true)
	candidate.phase = "FACTION_PENDING"
	candidate.currentCardId = pending.id
	var prior_checkpoint: Dictionary = state.get("decisionCheckpoint") \
		if state.get("decisionCheckpoint") is Dictionary else {}
	candidate.decisionCheckpoint = {"version": 1, "cardId": pending.id,
		"sourceCardId": prior_checkpoint.get("sourceCardId"),
		"turn": state.get("turn"),
		"decisionIndex": state.get("runClock", {}).get("decisionIndex"),
		"flowSource": "faction_event"}
	return candidate


func card(state: Dictionary) -> Dictionary:
	if state.get("phase") != "FACTION_PENDING" or not valid(state):
		return {}
	var pending: Variant = state.get("pendingFactionCard")
	if not pending is Dictionary or pending.get("id") != state.get("currentCardId"):
		return {}
	var projected := source_card(state, String(pending.id), String(pending.get("realm", "")))
	return projected if _same(projected, pending) else {}


func source_card(state: Dictionary, card_id: String, realm: String = "") -> Dictionary:
	var registered: Dictionary = _content.find("generated_card", card_id)
	if registered.get("sourcePath") != "data/world/factions.json":
		return {}
	var source: Variant = _content.read_module(MODULE)
	if not source is Dictionary:
		return {}
	for faction in source.get("factions", []):
		if not faction is Dictionary:
			continue
		for event in faction.get("events", []):
			if event is Dictionary and "faction_" + String(event.get("id", "")) == card_id:
				var card_state := state.duplicate(true)
				if not realm.is_empty():
					card_state.realm = realm
				return _build(card_state, faction, event)
	return {}


func choice_available(state: Dictionary, direction: String) -> bool:
	return card(state).get("choices", {}).has(direction)


func apply_battle_outcome(candidate: Dictionary, encounter: Dictionary,
		outcome: String) -> bool:
	if not valid(candidate) or encounter.get("id") != "enc_faction_wumeng_elite" \
			or outcome not in ["victory", "defeat", "flee"]:
		return false
	var link: Dictionary = encounter.get("outcomeLinks", {}).get(outcome, {})
	var effect: Dictionary = link.get("factionEffects", {})
	if effect.get("factionId") != "wumeng_alliance" \
			or not _integer(effect.get("reputationDelta")) \
			or not candidate.factionProgress.reputations.has("wumeng_alliance"):
		return false
	var before := int(candidate.factionProgress.reputations.wumeng_alliance)
	var after := clampi(before + int(effect.reputationDelta), -100, 100)
	candidate.factionProgress.reputations.wumeng_alliance = after
	if before != after:
		candidate["tradeRoutePendingEvents"] = candidate.get(
			"tradeRoutePendingEvents", []).duplicate(true)
		candidate.tradeRoutePendingEvents.append({"kind": "reputation",
			"factionId": "wumeng_alliance", "oldValue": before,
			"newValue": after})
	return true


func settle(state: Dictionary, direction: String) -> Dictionary:
	last_error = ""
	var current := card(state)
	if current.is_empty() or not choice_available(state, direction):
		return {}
	var choice: Dictionary = current.choices[direction]
	if choice.get("triggerCombat") == true:
		last_error = "势力战斗选择须由战斗网关处理"
		return {}
	var candidate := state.duplicate(true)
	if not _settle_effects(candidate, current, choice):
		return {}
	var fe: Dictionary = choice.factionEffects
	var progress: Dictionary = candidate.factionProgress
	for pair in [[_optional_id(fe.get("factionId")), int(fe.reputationDelta)],
			[_optional_id(fe.get("subfactionId")), int(fe.subReputationDelta)]]:
		var faction_id: String = pair[0]
		var delta: int = pair[1]
		if faction_id.is_empty() or delta == 0:
			continue
		if not progress.reputations.has(faction_id):
			return {}
		var before := int(progress.reputations[faction_id])
		var after := clampi(before + delta, -100, 100)
		progress.reputations[faction_id] = after
		if before != after:
			candidate["tradeRoutePendingEvents"] = candidate.get(
				"tradeRoutePendingEvents", []).duplicate(true)
			candidate.tradeRoutePendingEvents.append({"kind": "reputation",
				"factionId": faction_id, "oldValue": before, "newValue": after})
	var undercurrent_id := _optional_id(fe.get("undercurrentId"))
	if not undercurrent_id.is_empty() and int(fe.undercurrentStageChange) != 0:
		var source: Dictionary = _content.read_module(MODULE)
		var undercurrent: Dictionary = source.get("undercurrents", {}).get(
			undercurrent_id, {})
		if undercurrent.is_empty() or not progress.undercurrentStages.has(undercurrent_id):
			return {}
		var before := int(progress.undercurrentStages[undercurrent_id])
		var after := clampi(before + int(fe.undercurrentStageChange), 0,
			int(undercurrent.get("maxStage", 5)))
		progress.undercurrentStages[undercurrent_id] = after
		candidate["tradeRoutePendingEvents"] = candidate.get(
			"tradeRoutePendingEvents", []).duplicate(true)
		candidate.tradeRoutePendingEvents.append({"kind": "undercurrent",
			"undercurrentId": undercurrent_id, "oldStage": before,
			"newStage": after})
		if before < 2 and after >= 2:
			_plant_uprising(candidate, undercurrent_id, undercurrent, after)
	var global_flag := _optional_id(fe.get("globalFlag"))
	if not global_flag.is_empty():
		progress.globalFlags[global_flag] = true
	var next_index := int(state.runClock.decisionIndex) + 1
	var receipt := "decision:%s:choice:%s:%d" % [state.runClock.lifeId,
		current.id, next_index]
	if candidate.runClock.receipts.has(receipt):
		return {}
	candidate.runClock.receipts[receipt] = {"token": receipt,
		"decisionIndex": next_index, "sourceCardId": current.id, "kind": "choice"}
	var row := {"cardId": current.id, "cardType": current.type,
		"direction": direction, "turn": next_index - 1,
		"decisionIndex": next_index, "tags": []}
	if not candidate.has("replayHistory"):
		candidate.replayHistory = candidate.get("choiceHistory", []).duplicate(true)
	candidate.replayHistory.append(row.duplicate(true))
	candidate.choiceHistory.append(row)
	while candidate.choiceHistory.size() > 30:
		candidate.choiceHistory.pop_front()
	candidate.cardsPlayed.append(current.id)
	candidate.turn = next_index
	candidate.runClock.decisionIndex = next_index
	MilestoneFlow.tick_seeds(candidate)
	candidate.erase("pendingFactionCard")
	candidate.phase = "FLOW_PENDING"
	candidate.currentCardId = ""
	candidate.decisionCheckpoint = {"version": 1, "cardId": null,
		"sourceCardId": current.id, "turn": next_index,
		"decisionIndex": next_index, "flowPending": true}
	return candidate


func _eligible(state: Dictionary, faction: Dictionary, event: Dictionary) -> bool:
	var event_id := String(event.get("id", ""))
	if event_id.is_empty():
		return false
	if event.get("requiresPlayerPresence") == true and not _locations_compatible(
			String(state.get("currentLocation", "")), String(event.get("location", ""))):
		return false
	var min_realm := String(event.get("minRealm", ""))
	if not min_realm.is_empty() and REALMS.find(state.get("realm")) < REALMS.find(min_realm):
		return false
	if event.has("pathRestriction") and event.pathRestriction != state.get("path"):
		return false
	if int(state.get("factionProgress", {}).get("reputations", {}).get(
			faction.id, 0)) < int(event.get("minReputation", -100)):
		return false
	if event.get("once", true) and (state.get("cardsPlayed", []).has(
			"faction_" + event_id) or state.get("factionProgress", {}).get(
			"globalFlags", {}).get("faction_" + event_id) == true):
		return false
	if event.has("requiresFlag") and state.get("flags", {}).get(event.requiresFlag) != true:
		return false
	var undercurrent_id := String(event.get("undercurrentId", ""))
	if not undercurrent_id.is_empty() and int(state.get("factionProgress", {}).get(
			"undercurrentStages", {}).get(undercurrent_id, -1)) < int(
				event.get("undercurrentStage", 1)):
		return false
	return true


func _build(state: Dictionary, faction: Dictionary, event: Dictionary) -> Dictionary:
	var faction_id := String(faction.get("id", ""))
	var event_id := String(event.get("id", ""))
	if faction_id.is_empty() or event_id.is_empty() \
			or not _registered_event_matches(faction_id, event, "faction_" + event_id):
		return {}
	var choices := {}
	for direction in event.get("choices", {}):
		var raw: Variant = event.choices[direction]
		if not raw is Dictionary:
			return {}
		var choice := {"text": raw.get("text", "..."),
			"effects": raw.get("effects", {}).duplicate(true),
			"factionEffects": {"factionId": faction_id,
				"reputationDelta": raw.get("reputationDelta", 0),
				"subfactionId": raw.get("subfactionId"),
				"subReputationDelta": raw.get("subReputationDelta", 0),
				"undercurrentId": raw.get("undercurrentId"),
				"undercurrentStageChange": raw.get("undercurrentStageChange", 0),
				"globalFlag": raw.get("globalFlag")}}
		if raw.get("triggerCombat") == true:
			choice["triggerCombat"] = true
			choice["combatEncounterId"] = raw.get("combatEncounterId")
			for key in ["entryEffects", "combatOutcomePresentation"]:
				if raw.has(key):
					choice[key] = raw[key].duplicate(true)
		choices[direction] = choice
	return {"id": "faction_" + event_id,
		"semanticKey": event.get("semanticKey", "faction:%s:event:%s" % [
			faction_id, event_id]), "title": event.get("title", "势力事件"),
		"description": event.get("desc", "宗门中暗流涌动..."),
		"type": "FACTION_EVENT", "realm": state.get("realm", "qi"),
		"factionId": faction_id, "factionEventId": event_id,
		"location": event.get("location"),
		"requiresPlayerPresence": event.get("requiresPlayerPresence") == true,
		"deliveryClass": event.get("deliveryClass"),
		"sceneImage": event.get("sceneImage"),
		"narrativeSource": event.get("narrativeSource",
			"faction:%s:%s" % [faction_id, event_id]),
		"weight": 0, "once": event.get("once", true), "choices": choices}


func _registered_event_matches(faction_id: String, event: Dictionary,
		card_id: String) -> bool:
	var source: Dictionary = _content.find("generated_card", card_id)
	return source.get("factionId") == faction_id \
		and source.get("data") == event \
		and source.get("sourcePath") == "data/world/factions.json" \
		and String(source.get("jsonPointer", "")).begins_with("$.factions[") \
		and source.get("sourceSha256") == _content.source_sha256(MODULE)


func _settle_effects(candidate: Dictionary, card_value: Dictionary,
		choice: Dictionary) -> bool:
	for key in choice.get("effects", {}):
		var value: Variant = choice.effects[key]
		if key == "pill":
			if not value is String:
				return false
			var pills: Dictionary = candidate.resources.get("pills", {})
			pills[value] = int(pills.get(value, 0)) + 1
			candidate.resources.pills = pills
		elif key == "deckCard":
			if not value is String:
				return false
			var acquired := DeckAcquisition.new(_content).acquire_legacy(candidate,
				value, card_value.id)
			if not acquired.is_empty():
				candidate.clear()
				candidate.merge(acquired, true)
		elif key in ["cultivation", "daoHeart", "health", "fortune",
			"karmaGood", "karmaBad", "spiritStone", "lifespan"]:
			if not QuestFlow.new(_content)._apply_number(candidate, key, value):
				return false
		else:
			last_error = "势力事件效果缺少消费者：" + String(key)
			return false
	if int(choice.get("effects", {}).get("health", 0)) < 0 \
			or int(choice.get("effects", {}).get("daoHeart", 0)) < 0:
		candidate.resources.lifespan = maxi(0,
			int(candidate.resources.get("lifespan", 0)) - 1)
	return NormalChoicePolicy.new(_content)._apply_passive_regen(candidate)


func _plant_uprising(candidate: Dictionary, undercurrent_id: String,
		undercurrent: Dictionary, stage: int) -> void:
	for seed in candidate.get("karmaSeeds", []):
		if seed is Dictionary and seed.get("id") == "factionUprising":
			return
	var seed := {"id": "factionUprising", "seedType": "karma", "delay": 5,
		"realm": null, "path": null, "priority": 0,
		"originTurn": int(candidate.runClock.decisionIndex) + 1,
		"originLife": candidate.get("lifeCount", 0),
		"originCard": "faction_event", "originChoice": null,
		"originThread": null, "originQuest": null, "originOutcome": null,
		"description": "%s——势力矛盾已经爆发，你被卷入其中。" % undercurrent.get(
			"name", undercurrent_id), "tags": [], "payoffEvent": null,
		"context": {"factionId": undercurrent_id, "magnitude": stage},
		"consumed": false, "mergeGroup": null, "cancelGroup": null}
	candidate["karmaSeeds"] = candidate.get("karmaSeeds", []).duplicate(true)
	candidate.karmaSeeds.append(seed)
	candidate["karmaPromiseFlags"] = candidate.get(
		"karmaPromiseFlags", {}).duplicate(true)
	candidate.karmaPromiseFlags["factionUprising"] = true


func _integer(value: Variant) -> bool:
	return (value is int or value is float) and float(value) == float(int(value))


func _optional_id(value: Variant) -> String:
	return String(value) if value is String else ""


func _locations_compatible(player: String, event: String) -> bool:
	if player.is_empty() or event.is_empty():
		return false
	if player == event:
		return true
	# Current faction data has one physical event, authored at 宗门. The browser
	# NarrativeLedger treats the named sect landmarks as one region.
	if event == "宗门":
		for landmark in ["宗门", "青云剑宗", "宗门大殿", "演武场", "闭关室",
				"山门", "剑崖", "剑冢", "裂石山径"]:
			if player.contains(landmark):
				return true
	return false


func _same(a: Variant, b: Variant) -> bool:
	return JSON.parse_string(JSON.stringify(a)) == JSON.parse_string(JSON.stringify(b))
