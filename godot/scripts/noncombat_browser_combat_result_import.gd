extends RefCounted

const Domain = preload("res://scripts/noncombat_domain.gd")
const Registry = preload("res://scripts/runtime_data_registry.gd")
const ContentRepository = preload("res://scripts/noncombat_content_repository.gd")
const HintFlow = preload("res://scripts/noncombat_heavens_hint_flow.gd")
const MarketFlow = preload("res://scripts/noncombat_market_flow.gd")
const RippleFlow = preload("res://scripts/noncombat_ripple_flow.gd")
const IDS := ["tutorial_1", "tutorial_2", "tutorial_3", "tutorial_4", "q_start_sword"]
const RESULT_ID := "combat_fled_encounter_card_enc_trial_sword_swift"
const ENCOUNTER_ID := "encounter_card_enc_trial_sword_swift"

func prepare(source: Dictionary, browser: Dictionary, slot_id: String,
		source_sha: String) -> Dictionary:
	if not browser.get("marketState") is Dictionary \
			or not browser.get("heavensHint") is Dictionary \
			or not browser.get("karmaRipple") is Dictionary \
			or not browser.get("companionProgress") is Dictionary \
			or not source.get("pendingKarmaSeeds") is Array:
		return {"ok": false, "error": "UNSUPPORTED_IMPORT_RESULT_STATE"}
	var history: Variant = browser.get("choiceHistory")
	var checkpoint: Variant = browser.get("decisionCheckpoint")
	if browser.get("lifeCount") != 0 or browser.get("path") != "sword" \
			or browser.get("realm") != "qi" or browser.get("combatSession") != null \
			or not history is Array or history.size() != 6 \
			or browser.get("runClock", {}).get("decisionIndex") != 6 \
			or not checkpoint is Dictionary or checkpoint.get("cardId") != RESULT_ID \
			or checkpoint.get("sourceCardId") != ENCOUNTER_ID \
			or checkpoint.get("decisionIndex") != 6 \
			or browser.get("pendingLoadoutDecision") != null:
		return {"ok": false, "error": "UNSUPPORTED_IMPORT_RESULT"}
	for field in ["itemInventory", "treasureInstances", "interactionBudget"]:
		if browser.get(field) != {}:
			return {"ok": false, "error": "UNSUPPORTED_IMPORT_OWNERSHIP"}
	for index in IDS.size():
		if history[index].get("cardId") != IDS[index] \
				or history[index].get("direction") != "left" \
				or history[index].get("decisionIndex") != index + 1:
			return {"ok": false, "error": "UNSUPPORTED_IMPORT_RESULT_HISTORY"}
	if history[5].get("cardId") != ENCOUNTER_ID \
			or history[5].get("direction") != "left" \
			or history[5].get("decisionIndex") != 6:
		return {"ok": false, "error": "UNSUPPORTED_IMPORT_RESULT_HISTORY"}
	var receipts: Variant = browser.get("runClock", {}).get("receipts")
	var token := "decision:%s:life:0:combat:enc:0:5:%s:1" % [slot_id, ENCOUNTER_ID]
	if not receipts is Dictionary or receipts.size() != 6 \
			or not receipts.get(token) is Dictionary \
			or receipts[token].get("token") != token \
			or receipts[token].get("kind") != "combat" \
			or receipts[token].get("sourceCardId") != ENCOUNTER_ID \
			or receipts[token].get("decisionIndex") != 6:
		return {"ok": false, "error": "UNSUPPORTED_IMPORT_RESULT_RECEIPT"}
	for index in IDS.size():
		var choice_token := "decision:%s:life:0:choice:%s:%d" % [
			slot_id, IDS[index], index + 1]
		if not receipts.get(choice_token) is Dictionary \
				or receipts[choice_token].get("token") != choice_token \
				or receipts[choice_token].get("kind") != "choice" \
				or receipts[choice_token].get("sourceCardId") != IDS[index] \
				or receipts[choice_token].get("decisionIndex") != index + 1:
			return {"ok": false, "error": "UNSUPPORTED_IMPORT_RESULT_RECEIPT"}
	var content = ContentRepository.new()
	var game = Domain.new(Registry.new(), null, slot_id)
	var hint_seed := HintFlow.new(content).seed_matching_initial_trigger(
		int(browser.get("heavensHint", {}).get("nextTrigger", -1)))
	var market: Dictionary = browser.get("marketState", {})
	var last_bazaar := int(market.get("lastBazaarDecisionIndex", -99))
	if last_bazaar not in [-99, 6]:
		return {"ok": false, "error": "UNSUPPORTED_IMPORT_SCHEDULE"}
	var market_seed := MarketFlow.new(content).seed_matching_initial_schedule(
		last_bazaar if last_bazaar == 6 else int(market.get(
			"nextBazaarDecisionIndex", -1)),
		int(market.get("nextGhostDecisionIndex", -1)),
		int(market.get("nextBazaarDecisionIndex", -1)) if last_bazaar == 6 else -1)
	var ripple_seed := RippleFlow.new(content).seed_matching_opening_ripple(
		browser.get("karmaRipple", {}), source.get("pendingKarmaSeeds", []))
	if hint_seed == 0 or market_seed == 0 or ripple_seed == 0:
		return {"ok": false, "error": "UNSUPPORTED_IMPORT_SCHEDULE"}
	game._legacy_hint_replay_initial_seed = hint_seed
	game._legacy_market_replay_initial_seed = market_seed
	game._legacy_ripple_replay_initial_seed = ripple_seed
	if not game.start("sword", String(browser.get("playerName", ""))):
		return {"ok": false, "error": "REPLAY_START_FAILED"}
	for index in IDS.size():
		if game.get_current_card().get("id") != IDS[index] \
				or not game.choose("left", game.issue_choice_token()):
			return {"ok": false, "error": "REPLAY_CHOICE_MISMATCH"}
	if game.state.get("phase") != "COMBAT_HANDOFF" \
			or game.state.get("currentCardId") != ENCOUNTER_ID \
			or not game.choose("left", game.issue_choice_token()) \
			or game.state.get("phase") != "WARNING_PENDING" \
			or not game.choose("left", game.issue_choice_token()):
		return {"ok": false, "error": "REPLAY_BATTLE_HANDOFF_FAILED"}
	var request: Dictionary = game.battle_request()
	if request.get("sourceCardId") != ENCOUNTER_ID \
			or request.get("encounterId") != "enc_trial_sword_swift":
		return {"ok": false, "error": "REPLAY_BATTLE_OWNER_FAILED"}
	var result := {"contractVersion": 2,
		"encounterInstanceId": request.encounterInstanceId,
		"sourceCardId": request.sourceCardId,
		"encounterId": request.encounterId,
		"sourceContentHash": request.sourceContentHash,
		"outcome": "flee", "combatReceipt": "combat:" + String(request.encounterInstanceId),
		"postBattleState": {"encounterInstanceId": request.encounterInstanceId,
			"terminal": true, "combatPhase": "FLEE"}}
	if not game.submit_battle_result(result) \
			or game.get_current_card().get("id") != RESULT_ID:
		return {"ok": false, "error": "REPLAY_RESULT_FAILED"}
	var actual: Dictionary = game.state
	if actual.get("battleResultHistory", []).size() != 1 \
			or actual.battleResultHistory[0].get("result", {}).get("outcome") != "flee" \
			or actual.battleResultHistory[0].get("result", {}).get("encounterInstanceId") \
				!= request.encounterInstanceId:
		return {"ok": false, "error": "REPLAY_RESULT_RECEIPT_FAILED"}
	for field in ["path", "realm", "turn", "playerName", "maxHealth",
			"maxDaoHeart", "attributes", "deck", "deckOperations",
			"cardsPlayed", "recentCardTags", "currentLocation"]:
		if not _same(actual.get(field), browser.get(field)):
			return {"ok": false, "error": "STATE_MISMATCH", "field": field}
	if actual.get("resources", {}).get("treasures") != []:
		return {"ok": false, "error": "STATE_MISMATCH", "field": "resources.treasures"}
	for key in browser.get("resources", {}):
		var left: Variant = actual.get("resources", {}).get(key)
		var right: Variant = browser.resources[key]
		if left is float or left is int:
			if not (right is float or right is int) or float(left) != float(right):
				return {"ok": false, "error": "STATE_MISMATCH", "field": "resources." + String(key)}
		elif not _same(left, right):
			return {"ok": false, "error": "STATE_MISMATCH", "field": "resources." + String(key)}
	for pair in [["tradeRoute", "tradeRouteState"], ["worldPulse", "worldPulseState"],
			["worldContinuity", "worldContinuityState"],
			["karmaRipple", "karmaRippleState"], ["heavensHint", "heavensHintState"]]:
		var native_value: Variant = actual.get(pair[1])
		var browser_value: Variant = browser.get(pair[0])
		if not native_value is Dictionary or not browser_value is Dictionary:
			return {"ok": false, "error": "STATE_MISMATCH", "field": pair[0]}
		for key in browser_value:
			if not _same(native_value.get(key), browser_value[key]):
				return {"ok": false, "error": "STATE_MISMATCH",
					"field": pair[0] + "." + String(key)}
	if not (actual.get("knowledge") == null and browser.get("knowledge") == {}) \
			and not _same_numeric_map(actual.get("knowledge"), browser.get("knowledge")):
		return {"ok": false, "error": "STATE_MISMATCH", "field": "knowledge"}
	if not (actual.get("clues") == null and browser.get("clues") == []) \
			and not _same(actual.get("clues"), browser.get("clues")):
		return {"ok": false, "error": "STATE_MISMATCH", "field": "clues"}
	var equipment: Variant = browser.get("equipment")
	if not equipment is Dictionary or equipment.keys().size() != 4 \
			or ["weapon", "armor", "accessory", "artifact"].any(
				func(slot: Variant) -> bool: return not equipment.has(slot) \
					or equipment[slot] != null) \
			or actual.get("equipment") != null:
		return {"ok": false, "error": "STATE_MISMATCH", "field": "equipment"}
	for pair in [["visitedLocations", "visitedLocations"],
			["factionProgress", "factionProgress"]]:
		if not _same(actual.get(pair[1]), browser.get(pair[0])):
			return {"ok": false, "error": "STATE_MISMATCH", "field": pair[0]}
	if not _same(actual.get("companionProgress", {}).get("states"),
			browser.get("companionProgress", {}).get("states")):
		return {"ok": false, "error": "STATE_MISMATCH", "field": "companionProgress.states"}
	if actual.get("runClock", {}).get("decisionIndex") != 6:
		return {"ok": false, "error": "STATE_MISMATCH", "field": "history"}
	for index in history.size():
		var entry: Dictionary = actual.get("choiceHistory", [])[index]
		if entry.get("cardId") != history[index].get("cardId") \
				or entry.get("direction") != history[index].get("direction") \
				or int(entry.get("decisionIndex", -1)) != int(history[index].get("decisionIndex", -2)):
			return {"ok": false, "error": "STATE_MISMATCH", "field": "history"}
	if not _same(game.get_current_card(), checkpoint.get("cardSnapshot")):
		return {"ok": false, "error": "STATE_MISMATCH", "field": "decisionCheckpoint"}
	var quest: Variant = source.get("questState")
	if not quest is Dictionary or quest.get("saveVersion") != 3 \
			or quest.get("activeQuests") != [] or quest.get("completedQuests") != [] \
			or quest.get("closedQuests") != [] or quest.get("questOutcomes") != {} \
			or actual.has("questState"):
		return {"ok": false, "error": "STATE_MISMATCH", "field": "questState"}
	if not _same(actual.get("pendingKarmaSeeds"), source.get("pendingKarmaSeeds")):
		return {"ok": false, "error": "STATE_MISMATCH", "field": "pendingKarmaSeeds",
			"actual": actual.get("pendingKarmaSeeds"), "browser": source.get("pendingKarmaSeeds")}
	return {"ok": true, "state": actual.duplicate(true),
		"sourceSha256": source_sha, "slotId": slot_id,
		"currentCardId": RESULT_ID}

func _same(left: Variant, right: Variant) -> bool:
	return JSON.parse_string(JSON.stringify(left)) == JSON.parse_string(JSON.stringify(right))

func _same_numeric_map(left: Variant, right: Variant) -> bool:
	if not left is Dictionary or not right is Dictionary or left.size() != right.size():
		return false
	for key in right:
		if not left.has(key) or not (left[key] is int or left[key] is float) \
				or not (right[key] is int or right[key] is float) \
				or float(left[key]) != float(right[key]):
			return false
	return true
