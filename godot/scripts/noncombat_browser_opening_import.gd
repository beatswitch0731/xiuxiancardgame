extends RefCounted

# Importable first-life history through the sword chapter's early karma choices.
# The browser snapshot remains the source of truth; Godot commits only a
# locally replayed candidate whose next decision and owned state match it.
const Inspector = preload("res://scripts/noncombat_browser_save_inspector.gd")
const Domain = preload("res://scripts/noncombat_domain.gd")
const Registry = preload("res://scripts/runtime_data_registry.gd")
const ContentRepository = preload("res://scripts/noncombat_content_repository.gd")
const MarketFlow = preload("res://scripts/noncombat_market_flow.gd")
const HintFlow = preload("res://scripts/noncombat_heavens_hint_flow.gd")
const LegacyFragmentFlow = preload("res://scripts/noncombat_legacy_fragment_flow.gd")
const RippleFlow = preload("res://scripts/noncombat_ripple_flow.gd")
const CombatSemantics = preload("res://scripts/noncombat_browser_combat_semantics.gd")
const CombatPendingImport = preload("res://scripts/noncombat_browser_combat_pending_import.gd")
const CombatResultImport = preload("res://scripts/noncombat_browser_combat_result_import.gd")
const TUTORIAL_CARDS := ["tutorial_1", "tutorial_2", "tutorial_3", "tutorial_4"]
const PARITY_FIELDS := ["path", "realm", "turn", "playerName", "maxHealth",
	"maxDaoHeart", "attributes", "deck", "deckOperations", "cardsPlayed", "choiceHistory",
	"recentCardTags", "runClock"]


func prepare(raw_text: String, slot_id: String) -> Dictionary:
	var read: Dictionary = Inspector.new().read_slot(raw_text, slot_id)
	if read.get("ok") != true:
		return read
	var source: Dictionary = read.source
	if not source.get("causalSessionState") is Dictionary:
		return {"ok": false, "error": "UNSUPPORTED_IMPORT_BOUNDARY"}
	var browser: Dictionary = source.causalSessionState
	var history: Array = browser.choiceHistory
	var combat_snapshot: Variant = browser.get("combatSession")
	var checkpoint: Variant = browser.get("decisionCheckpoint")
	if checkpoint is Dictionary and checkpoint.get("cardId") == \
			"combat_fled_encounter_card_enc_trial_sword_swift" \
			and combat_snapshot == null:
		return CombatResultImport.new().prepare(source, browser, slot_id,
			String(read.sourceSha256))
	var first_sword_combat: bool = combat_snapshot is Dictionary \
		and CombatSemantics.new().verify_first_sword_card(
			combat_snapshot, browser, Registry.new())
	if browser.get("lifeCount") != 0 or browser.get("realm") != "qi" \
			or not browser.get("path") is String \
			or not browser.get("playerName") is String \
			or combat_snapshot != null and not first_sword_combat \
			or int(browser.runClock.decisionIndex) != history.size() \
			or history.size() > 14:
		return {"ok": false, "error": "UNSUPPORTED_IMPORT_BOUNDARY"}
	for index in history.size():
		var entry: Dictionary = history[index]
		if entry.get("cardId") not in TUTORIAL_CARDS and not (
				index == (4 if first_sword_combat else 2) \
				and entry.get("cardId") == "q_start_" + browser.path) \
				and not (index == 3 and browser.path == "sword" \
				and entry.get("cardId") == "encounter_card_enc_trial_sword_swift" \
				and entry.get("direction") == "right") \
				and not (index == 4 and browser.path == "sword" \
				and entry.get("cardId") == "promise_result_8f87a81d" \
				and entry.get("direction") == "left") \
				and not (index == 5 and browser.path == "sword" \
				and entry.get("cardId") == "ch_qi_20" \
				and entry.get("direction") == "left") \
				and not (index == 6 and browser.path == "sword" \
				and entry.get("cardId") == "ch_qi_40" \
				and entry.get("direction") == "left") \
				and not (index == 7 and browser.path == "sword" \
				and entry.get("cardId") == "q_whiteFox_quest" \
			and entry.get("direction") == "left") \
			and not (index == 8 and browser.path == "sword" \
			and entry.get("cardId") == "ch_qi_60" \
			and entry.get("direction") == "left") \
			and not (index == 9 and browser.path == "sword" \
			and entry.get("cardId") == "mentor_bai_ren_stage_INNER_DISCIPLE" \
			and entry.get("direction") == "left") \
			and not (index == 10 and browser.path == "sword" \
			and entry.get("cardId") == "promise_result_3b3a1690" \
			and entry.get("direction") == "left") \
			and not (index == 11 and browser.path == "sword" \
			and entry.get("cardId") == "ch_qi_80" \
			and entry.get("direction") == "left") \
			and not (index == 12 and browser.path == "sword" \
			and entry.get("cardId") == "kx_path_sword_legacy" \
			and entry.get("direction") == "left") \
			and not (index == 13 and browser.path == "sword" \
			and entry.get("cardId") == "k_chapter_sword_left" \
			and entry.get("direction") == "left"):
			return {"ok": false, "error": "UNSUPPORTED_IMPORT_BOUNDARY"}
	if first_sword_combat:
		return CombatPendingImport.new().prepare(source, browser, slot_id,
			String(read.sourceSha256))
	if not source.get("questState") is Dictionary \
			or not source.get("pendingKarmaSeeds") is Array \
			or not browser.get("itemInventory") is Dictionary \
			or history.size() < 7 and not source.questState.get(
				"activeQuests", []).is_empty() \
			or not source.questState.get("completedQuests", []).is_empty() \
			or history.size() < 8 and not source.questState.get(
				"closedQuests", []).is_empty() \
			or history.size() < 8 and not source.questState.get(
				"questOutcomes", {}).is_empty() \
			or not browser.itemInventory.is_empty() \
			or not browser.get("treasureInstances", {}).is_empty() \
			or browser.get("pendingLoadoutDecision") != null:
		return {"ok": false, "error": "UNSUPPORTED_IMPORT_OWNERSHIP"}
	var source_market: Variant = browser.get("marketState")
	var source_hint: Variant = browser.get("heavensHint")
	var source_flow: Variant = browser.get("flowState")
	var source_ripple: Variant = browser.get("karmaRipple")
	if not source_market is Dictionary or not source_hint is Dictionary \
			or not source_flow is Dictionary or not source_ripple is Dictionary \
			or not source_flow.get("pendingFlags") is Dictionary \
			or not source_flow.get("encounterDirectorState") is Dictionary \
			or not _nonnegative_integer(source_market.get("nextBazaarDecisionIndex")) \
			or not _nonnegative_integer(source_market.get("nextGhostDecisionIndex")) \
			or not _nonnegative_integer(source_hint.get("nextTrigger")) \
			or source_flow.get("phase") != "CALM" \
			or source_flow.get("cardCount") != (10 if history.size() == 14 else \
				9 if history.size() == 13 else \
				8 if history.size() == 12 else \
				7 if history.size() == 11 else \
				6 if history.size() >= 9 else \
				5 if history.size() == 8 else \
				4 if history.size() == 7 else \
				3 if history.size() == 6 else \
				2 if history.size() == 5 else \
				1 if history.size() >= 3 else 0) \
			or history.size() < 3 and not source_flow.get(
				"pendingFlags", {}).is_empty() \
			or history.size() == 3 and source_flow.get(
				"pendingFlags", {}).keys().any(func(key: Variant) -> bool:
					return key != "ripple") \
			or history.size() >= 4 and source_flow.get(
				"pendingFlags", {}).keys().any(func(key: Variant) -> bool:
					return key != "ripple" and not (
						history.size() >= 8 and key == "market")) \
			or source_flow.get("encounterDirectorState", {}).get(
				"nextDueDecision") != (13 if history.size() >= 4 else 4) \
			or history.size() >= 4 and source_flow.get(
				"encounterDirectorState", {}).get("firstTeachingStatus") != "avoided":
		return {"ok": false, "error": "UNSUPPORTED_IMPORT_SCHEDULE"}
	var content = ContentRepository.new()
	var bazaar_triggered := history.size() >= 8 and int(source_market.get(
		"lastBazaarDecisionIndex", -99)) >= 0
	var initial_bazaar_due := int(source_market.get("lastBazaarDecisionIndex", -99)) \
		if bazaar_triggered else int(source_market.get(
			"nextBazaarDecisionIndex", -1))
	var market_seed := MarketFlow.new(content).seed_matching_initial_schedule(
		initial_bazaar_due,
		int(source_market.get("nextGhostDecisionIndex", -1)),
		int(source_market.get("nextBazaarDecisionIndex", -1)) \
			if bazaar_triggered else -1)
	var hint_seed := HintFlow.new(content).seed_matching_initial_trigger(
		int(source_hint.get("nextTrigger", -1)))
	var ripple_seed := RippleFlow.new(content).seed_matching_opening_ripple(
		source_ripple, source.pendingKarmaSeeds)
	if market_seed == 0 or hint_seed == 0 or ripple_seed == 0:
		return {"ok": false, "error": "UNSUPPORTED_IMPORT_SCHEDULE"}
	var source_archive: Variant = source.get("legacyArchive")
	var source_legacy_run: Variant = browser.get("legacyRunState")
	var ordinary_count := history.size() - (1 if history.size() >= 4 else 0)
	var expected_streak := history.size() - 13 if history.size() >= 13 else \
		history.size() - 9 if history.size() >= 9 else ordinary_count
	if not source_archive is Dictionary or not source_archive.get(
			"fragmentsBySet") is Dictionary or not source_legacy_run is Dictionary \
			or not _nonnegative_integer(source_legacy_run.get("ordinaryMissStreak")) \
			or int(source_legacy_run.get("ordinaryMissStreak", -1)) != expected_streak:
		return {"ok": false, "error": "UNSUPPORTED_IMPORT_LEGACY"}
	var first_fragment_set := ""
	var second_fragment_set := ""
	for set_id in LegacyFragmentFlow.SET_IDS:
		var count: Variant = source_archive.fragmentsBySet.get(set_id)
		if count == 1 and history.size() >= 9 and first_fragment_set.is_empty():
			first_fragment_set = set_id
		elif count == 1 and history.size() >= 13 and second_fragment_set.is_empty():
			second_fragment_set = set_id
		elif count != 0:
			return {"ok": false, "error": "UNSUPPORTED_IMPORT_LEGACY"}
	if history.size() >= 9 and first_fragment_set.is_empty():
		return {"ok": false, "error": "UNSUPPORTED_IMPORT_LEGACY"}
	if history.size() >= 13:
		if first_fragment_set != "pill_way" or second_fragment_set != "heaven_book":
			return {"ok": false, "error": "UNSUPPORTED_IMPORT_LEGACY"}
		first_fragment_set = "heaven_book"
		second_fragment_set = "pill_way"
	var fragment_flow = LegacyFragmentFlow.new(content, null)
	var legacy_seed := fragment_flow.seed_matching_opening_pity(
		String(browser.path), first_fragment_set, second_fragment_set,
		history.size() - 13 if history.size() >= 13 else 0) \
		if history.size() >= 9 else \
		LegacyFragmentFlow.seed_without_early_drop(ordinary_count)
	if legacy_seed == 0:
		return {"ok": false, "error": "UNSUPPORTED_IMPORT_LEGACY"}
	var game = Domain.new(Registry.new(), null, slot_id)
	game._legacy_market_replay_initial_seed = market_seed
	game._legacy_hint_replay_initial_seed = hint_seed
	game._legacy_fragment_replay_initial_seed = legacy_seed
	game._legacy_ripple_replay_initial_seed = ripple_seed
	if not game.start(String(browser.get("path", "")),
			String(browser.get("playerName", "叶凌云"))):
		return {"ok": false, "error": "REPLAY_START_FAILED"}
	for entry in history:
		if game.state.get("phase") == "FLOW_PENDING" and not game.resume_flow():
			return {"ok": false, "error": "REPLAY_FLOW_FAILED"}
		var current_id: Variant = game.state.get("currentCardId") \
			if game.state.get("phase") == "COMBAT_HANDOFF" else \
			game.get_current_card().get("id")
		if current_id != entry.get("cardId") \
				or not game.choose(String(entry.get("direction", "")),
					game.issue_choice_token()):
			return {"ok": false, "error": "REPLAY_CHOICE_MISMATCH"}
	if game.state.get("phase") == "FLOW_PENDING" and not game.resume_flow():
		return {"ok": false, "error": "REPLAY_FLOW_FAILED"}
	var expected_card := "tutorial_1"
	if browser.get("decisionCheckpoint") is Dictionary:
		expected_card = String(browser.decisionCheckpoint.get("cardId", ""))
	var actual_card := String(game.state.get("currentCardId", "")) \
		if game.state.get("phase") == "COMBAT_HANDOFF" else \
		String(game.get_current_card().get("id", ""))
	if actual_card != expected_card:
		return {"ok": false, "error": "NEXT_CARD_MISMATCH"}
	var actual: Dictionary = game.state
	for field in PARITY_FIELDS:
		if not _same_json(actual.get(field), browser.get(field)):
			return {"ok": false, "error": "STATE_MISMATCH", "field": field}
	var browser_checkpoint: Variant = browser.get("decisionCheckpoint")
	var actual_checkpoint: Variant = actual.get("decisionCheckpoint")
	if browser_checkpoint is Dictionary and actual_checkpoint is Dictionary:
		for key in browser_checkpoint:
			if not _same_json(actual_checkpoint.get(key), browser_checkpoint[key]):
				return {"ok": false, "error": "STATE_MISMATCH",
					"field": "decisionCheckpoint." + String(key)}
	elif not _same_json(actual_checkpoint, browser_checkpoint):
		return {"ok": false, "error": "STATE_MISMATCH",
			"field": "decisionCheckpoint"}
	if history.size() >= 4 and not _same_numeric_map(actual.get("knowledge"),
			browser.get("knowledge")):
		return {"ok": false, "error": "STATE_MISMATCH", "field": "knowledge"}
	if history.size() >= 7 and not _same_json(actual.get("questState"),
			source.questState):
		return {"ok": false, "error": "STATE_MISMATCH", "field": "questState"}
	if not _same_json(actual.get("pendingKarmaSeeds", []), source.pendingKarmaSeeds):
		return {"ok": false, "error": "STATE_MISMATCH",
			"field": "pendingKarmaSeeds"}
	if not _same_json(actual.get("pendingRippleCard"), source_flow.pendingFlags.get(
			"ripple")):
		return {"ok": false, "error": "STATE_MISMATCH",
			"field": "pendingRippleCard"}
	if not _same_json(actual.get("pendingMarketCard"), source_flow.pendingFlags.get(
			"market")):
		return {"ok": false, "error": "STATE_MISMATCH",
			"field": "pendingMarketCard"}
	if history.size() >= 4:
		if not _same_json(actual.get("noncombatFlow", {}).get(
				"encounterDirectorState"), source_flow.encounterDirectorState):
			return {"ok": false, "error": "STATE_MISMATCH",
				"field": "encounterDirectorState"}
	if history.size() == 4 or history.size() == 10:
		var queued: Array = source_flow.get("narrativeQueue", [])
		var browser_card: Dictionary = queued[0].get("card", {}) \
			if queued.size() == 1 and queued[0] is Dictionary else {}
		var visible: Dictionary = game.get_current_card()
		for key in ["id", "type", "title", "description", "originCardId",
				"originChoice", "promiseId", "semanticKey"]:
			if not _same_json(visible.get(key), browser_card.get(key)):
				return {"ok": false, "error": "STATE_MISMATCH",
					"field": "visibleCard." + key}
		for key in ["text", "effects", "feedbackCue", "resolution"]:
			if not _same_json(visible.get("choices", {}).get("left", {}).get(key),
					browser_card.get("choices", {}).get("left", {}).get(key)):
				return {"ok": false, "error": "STATE_MISMATCH",
					"field": "visibleCard.choice." + key}
	var actual_resources: Dictionary = actual.get("resources", {})
	for key in browser.get("resources", {}):
		if not _same_json(actual_resources.get(key), browser.resources[key]):
			return {"ok": false, "error": "STATE_MISMATCH", "field": "resources." + key}
	for pair in [["marketState", "marketState"], ["heavensHint", "heavensHintState"],
			["karmaRipple", "karmaRippleState"], ["tradeRoute", "tradeRouteState"],
			["worldPulse", "worldPulseState"],
			["worldContinuity", "worldContinuityState"]]:
		var browser_value: Variant = browser.get(pair[0])
		var godot_value: Variant = actual.get(pair[1])
		if not browser_value is Dictionary or not godot_value is Dictionary:
			return {"ok": false, "error": "STATE_MISMATCH", "field": pair[0]}
		for key in browser_value:
			if pair[0] == "marketState" and key in ["currentItems", "priceMultiplier",
					"slotCount", "routeModifiers", "vendorRelations", "debts",
					"rustedSwordOrders"]:
				continue
			var matching := _same_world_npcs(godot_value.get(key), browser_value[key]) \
				if pair[0] == "worldContinuity" and key == "npcs" else \
				_same_json(godot_value.get(key), browser_value[key])
			if not matching:
				return {"ok": false, "error": "STATE_MISMATCH",
					"field": pair[0] + "." + key}
	if source_market.get("currentItems") != [] \
			or source_market.get("priceMultiplier") != 1 \
			or source_market.get("slotCount") != 5 \
			or source_market.get("routeModifiers") != null \
			or source_market.get("vendorRelations") != {} \
			or source_market.get("debts") != [] \
			or source_market.get("rustedSwordOrders") != []:
		return {"ok": false, "error": "STATE_MISMATCH", "field": "marketBaseline"}
	for pair in [["factionProgress", actual.get("factionProgress"),
			browser.get("factionProgress")], ["companionProgress.states",
			actual.get("companionProgress", {}).get("states"),
			browser.get("companionProgress", {}).get("states") \
			if browser.get("companionProgress") is Dictionary else null],
			["legacyArchive", actual.get("legacyArchive"), source.get("legacyArchive")],
			["legacyRunState", actual.get("legacyRunState"),
				browser.get("legacyRunState")]]:
		if not _same_json(pair[1], pair[2]):
			return {"ok": false, "error": "STATE_MISMATCH", "field": pair[0]}
	var persisted: Dictionary = JSON.parse_string(JSON.stringify(actual))
	var cold = Domain.new(Registry.new(), Domain.ReplaySnapshotStore.new(persisted), slot_id)
	if not cold.restore():
		return {"ok": false, "error": "GODOT_COLD_REPLAY_FAILED"}
	return {"ok": true, "state": actual.duplicate(true),
		"sourceSha256": read.sourceSha256, "slotId": slot_id,
		"currentCardId": expected_card}


func import_to_empty_slot(raw_text: String, slot_id: String,
		session: RefCounted) -> Dictionary:
	if session == null or session.slot_id != slot_id \
			or session.has_state_file():
		return {"ok": false, "error": "DESTINATION_OCCUPIED"}
	var candidate := prepare(raw_text, slot_id)
	if candidate.get("ok") != true:
		return candidate
	var committed: Dictionary = session.commit_snapshot(candidate.state, -1)
	if committed.get("ok") != true:
		return {"ok": false, "error": String(committed.get("error", "WRITE_FAILED"))}
	return {"ok": true, "slotId": slot_id,
		"sourceSha256": candidate.sourceSha256,
		"currentCardId": candidate.currentCardId}


func replace_slot(raw_text: String, slot_id: String, session: RefCounted,
		expected_revision: int) -> Dictionary:
	if session == null or session.slot_id != slot_id or not session.has_state_file():
		return {"ok": false, "error": "DESTINATION_EMPTY"}
	var candidate := prepare(raw_text, slot_id)
	if candidate.get("ok") != true:
		return candidate
	var committed: Dictionary = session.commit_browser_import(
		candidate.state, expected_revision)
	if committed.get("ok") != true:
		return committed
	return {"ok": true, "slotId": slot_id,
		"sourceSha256": candidate.sourceSha256,
		"currentCardId": candidate.currentCardId,
		"backup": committed.backup}


func _same_json(left: Variant, right: Variant) -> bool:
	return JSON.parse_string(JSON.stringify(left)) == JSON.parse_string(JSON.stringify(right))


func _same_numeric_map(left: Variant, right: Variant) -> bool:
	if not left is Dictionary or not right is Dictionary \
			or left.size() != right.size():
		return false
	for key in left:
		if not right.has(key) or not (left[key] is int or left[key] is float) \
				or not (right[key] is int or right[key] is float) \
				or float(left[key]) != float(right[key]):
			return false
	return true


func _same_world_npcs(left: Variant, right: Variant) -> bool:
	if not left is Dictionary or not right is Dictionary:
		return false
	var normalized: Dictionary = JSON.parse_string(JSON.stringify(left))
	for npc_id in right:
		if right[npc_id] is Dictionary and not right[npc_id].has("locationId") \
				and normalized.get(npc_id) is Dictionary \
				and normalized[npc_id].get("locationId") == null:
			normalized[npc_id].erase("locationId")
	return _same_json(normalized, right)


func _nonnegative_integer(value: Variant) -> bool:
	return (value is int or value is float) \
		and float(value) == floor(float(value)) and int(value) >= 0
