extends RefCounted

# Story-side protocol only. The combat scene is an independent consumer. No
# method here starts combat, changes a run, or awards a battle result.
const CONTRACT_VERSION := 2
const ENCOUNTER_PREFIX := "encounter_card_"
const WHITEFOX_SOURCE_ID := "q_whiteFox_3"
const WHITEFOX_QUEST_ID := "white_fox_line"
const WHITEFOX_MODULE := "quests:white_fox"
const SWORD_QUEST_SOURCE_ID := "q_sword_3"
const SWORD_QUEST_ID := "sword_legacy"
const SWORD_QUEST_MODULE := "quests:sword_legacy"
const FELLOW_SOURCE_ID := "q_fellow"
const MISSION_SOURCE_ID := "f_mission"
const BANDIT_SOURCE_ID := "ds_female_bandit"
const DUNGEON_BOSS_SOURCE_ID := "realm_guardian"
const NASCENT_COMBAT_IDS := ["n_hunt", "ar_boss"]
const TRIAL_COMBAT_ID := "it_combat"
const VILLAGE_SOURCE_ID := "thread_ab_village_3"
const VILLAGE_THREAD_ID := "abandoned_village"
const SWORD_SOURCE_ID := "thread_sword_tomb_2"
const SWORD_THREAD_ID := "sword_tomb_trial"
const LAST_LESSON_SOURCE_ID := "thread_last_lesson_n3"
const LAST_LESSON_THREAD_ID := "bairen_last_lesson"
const LAST_LESSON_MODULE := "threads:last_lesson_threads"
const THREAD_SOURCE_IDS := [VILLAGE_SOURCE_ID, SWORD_SOURCE_ID,
	LAST_LESSON_SOURCE_ID]


func _thread_id_for_source(source_id: String) -> String:
	return VILLAGE_THREAD_ID if source_id == VILLAGE_SOURCE_ID \
		else SWORD_THREAD_ID if source_id == SWORD_SOURCE_ID \
		else LAST_LESSON_THREAD_ID if source_id == LAST_LESSON_SOURCE_ID else ""
const ContentRepository = preload("res://scripts/noncombat_content_repository.gd")
const NormalChoicePolicy = preload("res://scripts/noncombat_normal_choice_policy.gd")
const LegacyFragmentFlow = preload("res://scripts/noncombat_legacy_fragment_flow.gd")
const PathSkillFlow = preload("res://scripts/noncombat_path_skill_flow.gd")
const FirstSessionRoute = preload("res://scripts/noncombat_first_session_route.gd")
const CatalogEncounter = preload("res://scripts/noncombat_catalog_encounter.gd")
const StoryThreadFlow = preload("res://scripts/noncombat_story_threads_v2_flow.gd")
const FactionEvents = preload("res://scripts/noncombat_faction_events.gd")
const FACTION_GATE_SOURCE_ID := "faction_wumeng_gatekeeper_call"
const CompanionEvents = preload("res://scripts/noncombat_companion_events.gd")
const COMPANION_OLD_MASTER_SOURCE_ID := "comp_jian_linger_jle_8_sword_tomb_old_master"
const COMPANION_OLD_MASTER_ENCOUNTER_ID := "enc_companion_jian_linger_tomb"
const EncounterDirector = preload("res://scripts/noncombat_encounter_director.gd")
const RealmGateFlow = preload("res://scripts/noncombat_realm_gate_flow.gd")
const FoundationDungeonFlow = preload("res://scripts/noncombat_foundation_dungeon_flow.gd")
const HigherDungeonFlow = preload("res://scripts/noncombat_higher_linear_dungeon_flow.gd")
const CONTENT_FILES := [
	"data/cards/qi.json",
	"data/config/paths.json",
	"data/progression/first_session_cohesion.json",
	"data/combat/encounters.json",
	"data/combat/encounter_presentations.json",
	"data/combat/encounter_director.json",
	"data/combat/deck_progression.json",
	"data/cards/battle_cards.json",
]

var _registry: RefCounted
var _content: RefCounted
var source_error := ""


func _init(registry: RefCounted, content: RefCounted = null) -> void:
	_registry = registry
	_content = content if content != null else ContentRepository.new()


func _document(module_id: String) -> Dictionary:
	var doc: Variant = _content.read_module(module_id) if _content != null else null
	return doc if doc is Dictionary else {}


func offer_from_state(state: Dictionary) -> Dictionary:
	if state.get("phase") not in ["COMBAT_HANDOFF", "FIRST_SESSION_ROUTE_PENDING", "QUEST_PENDING", "NORMAL_PENDING", "THREAD_PENDING", "FACTION_PENDING", "COMPANION_PENDING"]:
		return {}
	return _resolve_offer(state)


func source_offer(state: Dictionary) -> Dictionary:
	return _resolve_offer(state)


func source_content_hash() -> String:
	return _source_content_hash()


func source_resolution_for_offer(state: Dictionary) -> Dictionary:
	var offer := _resolve_offer(state)
	if offer.is_empty():
		return {}
	if offer.get("sourceCardId") == FirstSessionRoute.ROUTE_ID:
		return _mountain_resolution(state, offer)
	if offer.get("sourceCardId") == WHITEFOX_SOURCE_ID:
		return _whitefox_resolution(state)
	if offer.get("sourceCardId") == SWORD_QUEST_SOURCE_ID:
		return _sword_quest_resolution(state, offer)
	if offer.get("sourceCardId") == FELLOW_SOURCE_ID:
		return _fellow_resolution(state)
	if offer.get("sourceCardId") == MISSION_SOURCE_ID:
		return _mission_resolution(state)
	if offer.get("sourceCardId") == BANDIT_SOURCE_ID:
		return _bandit_resolution(state)
	if offer.get("sourceCardId") == DUNGEON_BOSS_SOURCE_ID:
		return _dungeon_boss_resolution(state)
	if offer.get("sourceCardId") in NASCENT_COMBAT_IDS:
		return _nascent_resolution(state)
	if offer.get("sourceCardId") == TRIAL_COMBAT_ID:
		return _trial_resolution(state)
	if offer.get("sourceCardId") in THREAD_SOURCE_IDS:
		return _thread_resolution(state, offer)
	if offer.get("sourceCardId") == FACTION_GATE_SOURCE_ID:
		return _faction_resolution(state, offer)
	if offer.get("sourceCardId") == COMPANION_OLD_MASTER_SOURCE_ID:
		return _companion_resolution(state, offer)
	if state.get("pendingCadenceCard") is Dictionary:
		var catalog := CatalogEncounter.new(_content)
		return catalog.resolution(state, String(offer["sourceCardId"]))
	if state.get("pendingRealmGateCard") is Dictionary:
		var source := RealmGateFlow.new(_content).source_card(state)
		if source.is_empty() or not _same(source, state.pendingRealmGateCard):
			return {}
		return {"sourceCardId": source.id, "direction": "left", "sourceCard": source,
			"choice": {"triggerCombat": true, "enemy": source.enemy.duplicate(true),
				"combatRewards": source.combatRewards.duplicate(true),
				"combatPresentation": source.combatPresentation.duplicate(true),
				"combatRules": source.combatRules.duplicate(true)},
			"combatCard": source.duplicate(true)}
	var choice := _authored_choice(offer)
	if choice.is_empty():
		return {}
	var source_id := String(offer["sourceCardId"])
	return {"sourceCardId": source_id, "direction": "left",
		"sourceCard": {"id": source_id, "type": "COMBAT"},
		"choice": choice,
		"combatCard": {"id": source_id, "encounterId": offer["encounterId"]}}


func build_request(state: Dictionary) -> Dictionary:
	if state.get("phase") != "BATTLE_PENDING" or not state.get("pendingBattle") is Dictionary:
		return {}
	var offer := _resolve_offer(state)
	var pending: Dictionary = state["pendingBattle"]
	var clock: Dictionary = _as_dictionary(state.get("runClock"))
	var receipts: Dictionary = _as_dictionary(clock.get("receipts"))
	var life_id := String(clock.get("lifeId", ""))
	var base_index := int(clock.get("decisionIndex", 0))
	var next_index := base_index + 1
	var source_id := String(offer.get("sourceCardId", ""))
	# An encounter is owned by the already committed turn. Its source decision
	# remains prospective until an authenticated combat outcome settles it.
	var owner := "enc:%s:%d:%s:1" % [life_id, base_index, source_id]
	var warning_direction := String(pending.get("warningChoiceDirection", ""))
	var warning_token := "warning:%s:%s" % [owner, warning_direction]
	var checkpoint: Dictionary = _as_dictionary(state.get("decisionCheckpoint"))
	var prep_receipts: Dictionary = _as_dictionary(clock.get("preparationReceipts"))
	var prep: Dictionary = _as_dictionary(prep_receipts.get(warning_token))
	var loadout: Dictionary = _as_dictionary(state.get("battleLoadout"))
	var resolution: Dictionary = _as_dictionary(pending.get("pendingResolution"))
	var source_card: Dictionary = _as_dictionary(resolution.get("sourceCard"))
	var choice: Dictionary = _as_dictionary(resolution.get("choice"))
	var combat_card: Dictionary = _as_dictionary(resolution.get("combatCard"))
	var source_hash := _source_content_hash()
	var current_loadout := source_id in [FirstSessionRoute.ROUTE_ID, WHITEFOX_SOURCE_ID, SWORD_QUEST_SOURCE_ID, FELLOW_SOURCE_ID, MISSION_SOURCE_ID, BANDIT_SOURCE_ID, DUNGEON_BOSS_SOURCE_ID, VILLAGE_SOURCE_ID, SWORD_SOURCE_ID, LAST_LESSON_SOURCE_ID, TRIAL_COMBAT_ID, FACTION_GATE_SOURCE_ID, COMPANION_OLD_MASTER_SOURCE_ID] or source_id in NASCENT_COMBAT_IDS \
		or state.get("pendingCadenceCard") is Dictionary \
		or state.get("pendingRealmGateCard") is Dictionary
	var resolution_matches := _same(resolution, source_resolution_for_offer(state)) if current_loadout else (
		source_card == {"id": source_id, "type": "COMBAT"} \
		and _source_choice_matches(choice, offer) \
		and combat_card == {"id": source_id, "encounterId": offer.get("encounterId")})
	var snapshot := player_snapshot(state)
	# The teaching encounter's accepted battle choice is left even when its
	# preceding prologue choice (originDirection) was right.
	if offer.is_empty() or snapshot.is_empty() or base_index <= 0 or life_id.is_empty() \
			or int(state.get("turn", -1)) != base_index \
			or pending.get("baseDecisionIndex") != base_index \
			or pending.get("nextDecisionIndex") != next_index \
			or pending.get("sourceCardId") != source_id \
			or source_id in [DUNGEON_BOSS_SOURCE_ID, "ar_boss", TRIAL_COMBAT_ID] and pending.get("dungeonSessionId") != state.get("dungeonRun", {}).get("sessionId") \
			or pending.get("direction") != offer.get("originDirection") \
			or pending.get("encounterId") != offer.get("encounterId") \
			or source_id in [WHITEFOX_SOURCE_ID, SWORD_QUEST_SOURCE_ID] and (not pending.has("encounterId") \
				or pending.get("questId") != (WHITEFOX_QUEST_ID if source_id == WHITEFOX_SOURCE_ID else SWORD_QUEST_ID)) \
			or source_id in THREAD_SOURCE_IDS and pending.get("threadId") != \
				_thread_id_for_source(source_id) \
			or pending.get("encounterInstanceId") != owner \
			or pending.get("warningConfirmed") != true \
			or not warning_direction in ["left", "right"] and not (
				warning_direction == "up" and source_id in [
					RealmGateFlow.FOUNDATION_CARD_ID, RealmGateFlow.GOLDEN_CARD_ID,
					RealmGateFlow.NASCENT_CARD_ID]) \
			or pending.get("warningCheckpointToken") != warning_token \
			or checkpoint.get("version") != 1 \
			or checkpoint.get("cardId") != source_id \
			or checkpoint.get("sourceCardId") != source_id \
			or checkpoint.get("decisionIndex") != base_index \
			or checkpoint.get("warningChoiceDirection") != warning_direction \
			or prep.get("sourceCardId") != source_id \
			or prep.get("direction") != warning_direction \
			or prep.get("baseDecisionIndex") != base_index \
			or prep.get("applied") != true \
			or not _valid_preparation(state, prep, warning_direction) \
			or not _valid_loadout(loadout, state, offer) \
			or pending.get("returnPolicy") != "source_flow" \
			or source_hash.is_empty() \
			or pending.get("sourceContentHash") != source_hash \
			or resolution.is_empty() \
			or resolution.get("sourceCardId") != source_id \
			or resolution.get("direction") != (
				offer.get("originDirection") if current_loadout else "left") \
			or not resolution_matches \
			or current_loadout and not _same(pending.get("playerSnapshot"), snapshot) \
			or receipts.has("decision:%s:choice:%s:%d" % [life_id, source_id, next_index]) \
			or receipts.has("decision:%s:combat:%s" % [life_id, owner]) \
			or receipts.has("battle:" + owner):
		return {}
	return {
		"contractVersion": CONTRACT_VERSION,
		"slotId": life_id.get_slice(":", 0),
		"lifeId": life_id,
		"decisionIndex": next_index,
		"baseDecisionIndex": base_index,
		"sourceCardId": source_id,
		"direction": offer["originDirection"],
		"originCardId": offer["originCardId"],
		"originDirection": offer["originDirection"],
		"encounterId": offer["encounterId"],
		"encounterInstanceId": owner,
		"warningChoiceDirection": warning_direction,
		"warningCheckpointToken": warning_token,
		"path": offer["path"],
		"realm": offer["realm"],
		"questId": pending.get("questId", ""),
		"threadId": pending.get("threadId", ""),
		"presentationId": offer["presentationId"],
		"battlefieldId": offer["battlefieldId"],
		"pendingResolution": resolution.duplicate(true),
		"returnPolicy": "source_flow",
		"sourceContentHash": source_hash,
		"playerSnapshot": snapshot,
	}


func player_snapshot(state: Dictionary) -> Dictionary:
	var path_skill = PathSkillFlow.new(_content)
	var active: Dictionary = path_skill.active_bonuses(state)
	if not path_skill.last_error.is_empty():
		return {}
	var max_health := path_skill.actual_max_health(state)
	if not path_skill.last_error.is_empty():
		return {}
	var snapshot := {
		"attributes": state.get("attributes", {}).duplicate(true),
		"resources": state.get("resources", {}).duplicate(true),
		"flags": state.get("flags", {}).duplicate(true),
		"maxHealth": max_health,
		"maxDaoHeart": LegacyFragmentFlow.actual_max_dao_heart(state),
		"legacyPassives": LegacyFragmentFlow.aggregate_passives(state),
		"treasureInstances": state.get("treasureInstances", {}).duplicate(true),
		"equipment": state.get("equipment", {}).duplicate(true),
		"battleLoadout": state.get("battleLoadout", {}).duplicate(true),
	}
	var combat_passives := {}
	for key in ["def", "critRate", "lowHpAtkBonus"]:
		if active.has(key):
			combat_passives[key] = active[key]
	if not combat_passives.is_empty():
		snapshot["pathSkillPassives"] = combat_passives
	if state.get("currentCardId") in [FirstSessionRoute.ROUTE_ID, WHITEFOX_SOURCE_ID, SWORD_QUEST_SOURCE_ID, FELLOW_SOURCE_ID, MISSION_SOURCE_ID, BANDIT_SOURCE_ID, DUNGEON_BOSS_SOURCE_ID, VILLAGE_SOURCE_ID, SWORD_SOURCE_ID, LAST_LESSON_SOURCE_ID, TRIAL_COMBAT_ID, FACTION_GATE_SOURCE_ID, COMPANION_OLD_MASTER_SOURCE_ID] or state.get("currentCardId") in NASCENT_COMBAT_IDS \
			or state.get("pendingCadenceCard") is Dictionary \
			or state.get("pendingRealmGateCard") is Dictionary:
		snapshot["knowledge"] = state.get("knowledge", {}).duplicate(true)
		snapshot["modifiers"] = state.get("modifiers", {}).duplicate(true)
	return snapshot


func _valid_loadout(loadout: Dictionary, state: Dictionary,
		offer: Dictionary) -> bool:
	if not loadout.get("deck") is Array or loadout["deck"].is_empty():
		return false
	if not state.get("deck") is Array \
			or loadout["deck"] != state["deck"] \
			or state.get("starterDeckPath") != offer.get("path"):
		return false
	var starter: Array = _document("combat:deck_progression").get("paths", {}).get(
			offer.get("path"), {}).get("starterDeck", [])
	var current_loadout: bool = offer.get("sourceCardId") in [FirstSessionRoute.ROUTE_ID, WHITEFOX_SOURCE_ID, SWORD_QUEST_SOURCE_ID, FELLOW_SOURCE_ID, MISSION_SOURCE_ID, BANDIT_SOURCE_ID, DUNGEON_BOSS_SOURCE_ID, VILLAGE_SOURCE_ID, SWORD_SOURCE_ID, LAST_LESSON_SOURCE_ID, TRIAL_COMBAT_ID, FACTION_GATE_SOURCE_ID, COMPANION_OLD_MASTER_SOURCE_ID] or offer.get("sourceCardId") in NASCENT_COMBAT_IDS \
		or state.get("pendingCadenceCard") is Dictionary \
		or state.get("pendingRealmGateCard") is Dictionary
	# The original teaching request retains its compact starter-only contract.
	# The later source route consumes the player's acquired deck and passives.
	if starter.is_empty() or not current_loadout and loadout["deck"] != starter:
		return false
	for card_id in loadout["deck"]:
		if not card_id is String or String(card_id).is_empty():
			return false
	for key in ["equipment", "skills", "lineage", "modifiers", "pathOpening"]:
		if not loadout.get(key) is Dictionary:
			return false
	for key in ["treasures", "companions"]:
		if not loadout.get(key) is Array:
			return false
	if current_loadout:
		var definitions := {}
		for definition in _document("cards:battle_cards").get("battle_cards", []):
			if definition is Dictionary:
				definitions[definition.get("id")] = definition
		for card_id in loadout["deck"]:
			if not definitions.has(String(card_id).trim_suffix("+")):
				return false
		for key in ["equipment", "skills", "lineage", "modifiers"]:
			if not _same(loadout[key], state.get(key, {})):
				return false
		for key in ["treasures", "companions"]:
			if not _same(loadout[key], state.get("resources", {}).get(key, [])):
				return false
	var path_definition: Dictionary = _document("config:paths").get(
		"paths", {}).get(offer.get("path"), {})
	if path_definition.is_empty():
		return false
	var opening_block := int(path_definition.get("bonuses", {}).get("combatOpeningBlock", 0))
	var path_opening: Dictionary = loadout["pathOpening"]
	var persisted_block: Variant = path_opening.get("combatOpeningBlock")
	if path_opening.size() != 1 or not persisted_block is int and not persisted_block is float \
			or float(persisted_block) != float(opening_block):
		return false
	return true


func _valid_preparation(state: Dictionary, prep: Dictionary,
		direction: String) -> bool:
	# These encounters use CombatCoordinator's ordinary warning:
	# left enters directly; right costs 10 spirit stones and heals up to 1 HP.
	# This receipt is a checkpoint, never the source choice's decision receipt.
	var resources: Dictionary = _as_dictionary(state.get("resources"))
	var attributes: Dictionary = _as_dictionary(state.get("attributes"))
	for key in ["beforeSpiritStone", "afterSpiritStone", "beforeHealth", "afterHealth"]:
		if not prep.has(key) or not prep[key] is int and not prep[key] is float:
			return false
		if float(prep[key]) != float(int(prep[key])):
			return false
	var before_stones := int(prep["beforeSpiritStone"])
	var after_stones := int(prep["afterSpiritStone"])
	var before_health := int(prep["beforeHealth"])
	var after_health := int(prep["afterHealth"])
	var path_skill = PathSkillFlow.new(_content)
	var max_health := path_skill.actual_max_health(state)
	if not path_skill.last_error.is_empty():
		return false
	if before_stones < 0 or before_health < 0 or max_health <= 0 \
			or before_health > max_health \
			or int(resources.get("spiritStone", -1)) != after_stones \
			or int(attributes.get("health", -1)) != after_health:
		return false
	var realm_gate: bool = state.get("pendingRealmGateCard") is Dictionary
	var foundation_gate: bool = realm_gate and state.pendingRealmGateCard.get(
		"id") == RealmGateFlow.FOUNDATION_CARD_ID
	var golden_gate: bool = realm_gate and state.pendingRealmGateCard.get(
		"id") == RealmGateFlow.GOLDEN_CARD_ID
	var nascent_gate: bool = realm_gate and state.pendingRealmGateCard.get(
		"id") == RealmGateFlow.NASCENT_CARD_ID
	var deity_gate: bool = realm_gate and state.pendingRealmGateCard.get(
		"id") == RealmGateFlow.DEITY_CARD_ID
	var tribulation_gate: bool = realm_gate and state.pendingRealmGateCard.get(
		"id") == RealmGateFlow.TRIBULATION_CARD_ID
	var pill_key := "deity" if nascent_gate else (
		"nascent" if golden_gate else ("golden" if foundation_gate else "foundation"))
	var prefix := "Deity" if nascent_gate else (
		"Nascent" if golden_gate else ("Golden" if foundation_gate else "Foundation"))
	var before_pill := int(prep.get("before%sPill" % prefix, 0))
	var after_pill := int(prep.get("after%sPill" % prefix, 0))
	var used_pill: bool = prep.get("used%sPill" % prefix) == true
	if realm_gate and not deity_gate and not tribulation_gate:
		if before_pill < 0 or after_pill < 0 or used_pill != (before_pill > 0 and direction == "left") \
				or after_pill != before_pill - (1 if used_pill else 0) \
				or int(resources.get("pills", {}).get(pill_key, 0)) != after_pill \
				or used_pill and state.get("flags", {}).get(
					"used_deity_pill" if nascent_gate else (
						"used_nascent_pill" if golden_gate else (
							"used_golden_pill" if foundation_gate else "used_foundation_pill"))) != true:
			return false
	var using_array: bool = golden_gate and direction == (
		"right" if before_pill > 0 else "left")
	if using_array and state.get("flags", {}).get("used_lightning_array") != true:
		return false
	var cost := 0
	if nascent_gate:
		cost = 15 if direction == "right" and before_pill == 0 else 0
	elif deity_gate:
		var equipped_before: Array = prep.get("equippedTreasureIdsBefore", [])
		var consumed_id := String(prep.get("consumedTreasureInstanceId", ""))
		var using_relic: bool = prep.get("usedRelicShield") == true
		if not equipped_before is Array or using_relic != (not equipped_before.is_empty() \
				and direction == "left") or using_relic != not consumed_id.is_empty() \
				or using_relic and (not equipped_before.has(consumed_id) \
					or state.get("treasureInstances", {}).has(consumed_id) \
					or state.get("flags", {}).get("used_relic_shield") != true):
			return false
		cost = 20 if equipped_before.is_empty() and direction == "right" else 0
	elif tribulation_gate:
		if direction != "left":
			return false
	elif golden_gate:
		cost = 25 if using_array else 0
	elif foundation_gate:
		cost = 5 if direction == "up" or direction == "right" and before_pill == 0 else 0
	else:
		cost = 10 if direction == "right" and not (
			realm_gate and before_pill > 0) else 0
	if before_stones < cost or after_stones != before_stones - cost:
		return false
	return after_health == (before_health if foundation_gate or golden_gate else mini(max_health,
		before_health + (1 if cost > 0 else 0)))


func _as_dictionary(value: Variant) -> Dictionary:
	return value if value is Dictionary else {}


func validate_result(state: Dictionary, result: Dictionary) -> Dictionary:
	var request := build_request(state)
	if request.is_empty():
		return {"ok": false, "error": "NO_PENDING_BATTLE"}
	if result.get("contractVersion") != CONTRACT_VERSION:
		return {"ok": false, "error": "VERSION_MISMATCH"}
	for field in ["encounterInstanceId", "sourceCardId", "encounterId"]:
		if not result.has(field) or result.get(field) != request.get(field):
			return {"ok": false, "error": "FOREIGN_RESULT"}
	if result.get("sourceContentHash") != request.get("sourceContentHash"):
		return {"ok": false, "error": "SOURCE_CHANGED"}
	if not result.get("outcome") in ["victory", "defeat", "flee"]:
		return {"ok": false, "error": "INVALID_OUTCOME"}
	if result.get("outcome") == "flee" and state["pendingBattle"].get("fleeAllowed") == false:
		return {"ok": false, "error": "FLEE_FORBIDDEN"}
	var receipt: Variant = result.get("combatReceipt")
	var terminal_phase := {"victory": "VICTORY", "defeat": "DEFEAT", "flee": "FLEE"}
	if receipt != "combat:" + String(request["encounterInstanceId"]) \
			or not result.get("postBattleState") is Dictionary:
		return {"ok": false, "error": "INCOMPLETE_RESULT"}
	var post_state: Dictionary = result["postBattleState"]
	if post_state.get("encounterInstanceId") != request["encounterInstanceId"] \
			or post_state.get("terminal") != true \
			or post_state.get("combatPhase") != terminal_phase[result["outcome"]]:
		return {"ok": false, "error": "NONTERMINAL_RESULT"}
	# Validation is intentionally not settlement. The RunSession owner must
	# atomically persist the battle receipt, source effects and next decision.
	return {"ok": true, "normalized": result.duplicate(true), "settled": false}


func _source_choice_matches(choice: Dictionary, offer: Dictionary) -> bool:
	var expected := _authored_choice(offer)
	# Godot parses integral JSON numbers as floats after a save reload. Compare
	# canonical JSON values, while still requiring the complete source shape.
	return not expected.is_empty() and JSON.parse_string(JSON.stringify(choice)) == \
		JSON.parse_string(JSON.stringify(expected))


func _authored_choice(offer: Dictionary) -> Dictionary:
	var catalog: Dictionary = _document("combat:encounters")
	var encounter: Dictionary = {}
	for entry in catalog.get("encounters", []):
		if entry is Dictionary and entry.get("id") == offer.get("encounterId"):
			encounter = entry
			break
	if encounter.is_empty():
		return {}
	var authored_visual: Dictionary = _document(
		"combat:encounter_presentations").get("presentations", {}).get(
			offer.get("encounterId"), {})
	var tier := int(encounter.get("enemy", {}).get("tier", 1))
	var tier_loss := int(catalog.get("defeatHealthLossByTier", {}).get(str(tier), tier))
	# The persisted pending choice is a compact, fully comparable projection of
	# authored encounter data. Browser CardSystem adds a derived plan graph; the
	# battle adapter must rebuild and verify that graph before real play.
	var expected := {
		"encounterId": offer.get("encounterId"),
		"encounterKind": encounter.get("encounterKind", "ordinary"),
		"triggerCombat": true,
		"enemy": encounter.get("enemy", {}),
		"battlefield": authored_visual.get("battlefield", encounter.get("battlefield", null)),
		"combatPresentation": authored_visual,
		"victoryEffects": encounter.get("victoryEffects", {}),
		"combatRewards": encounter.get("victoryEffects", {}),
		"combatOutcomeLinks": encounter.get("outcomeLinks", {}),
		"defeatHealthLoss": int(encounter.get("defeatHealthLoss", tier_loss)),
	}
	for optional in ["defeatEffects", "fleeEffects", "combatOutcomePresentation",
			"karmaSeed", "karmaSeedOn"]:
		if encounter.has(optional):
			expected[optional] = encounter[optional]
	return expected


func _faction_source(state: Dictionary) -> Dictionary:
	var faction := FactionEvents.new(_content)
	if not faction.valid(state):
		return {}
	var pending: Variant = state.get("pendingFactionCard")
	if not pending is Dictionary or pending.get("id") != FACTION_GATE_SOURCE_ID:
		return {}
	var rebuilt := faction.source_card(state, FACTION_GATE_SOURCE_ID,
		String(pending.get("realm", "")))
	return rebuilt if _same(rebuilt, pending) else {}


func _faction_encounter(state: Dictionary) -> Dictionary:
	var source := _faction_source(state)
	if source.is_empty():
		return {}
	var choice: Dictionary = source.get("choices", {}).get("left", {})
	var encounter_id := String(choice.get("combatEncounterId", ""))
	if choice.get("triggerCombat") != true \
			or encounter_id != "enc_faction_wumeng_elite":
		return {}
	var encounter := {}
	for row in _document("combat:encounters").get("encounters", []):
		if row is Dictionary and row.get("id") == encounter_id:
			encounter = row.duplicate(true)
			break
	var visual: Dictionary = _document("combat:encounter_presentations").get(
		"presentations", {}).get(encounter_id, {})
	if encounter.is_empty() or visual.is_empty() \
			or not encounter.get("enemy") is Dictionary \
			or not encounter.get("outcomeLinks") is Dictionary:
		return {}
	for image in [source.get("sceneImage"), visual.get("sceneImage")]:
		var art: Dictionary = _content.asset_status(String(image))
		if not art.get("shaVerified", false) or not art.get("textureLoadable", false):
			source_error = "SOURCE_UNAVAILABLE" if art.get("fileExists") == false else "SOURCE_MISMATCH"
			return {}
	encounter["inlineFaction"] = true
	encounter["sceneImage"] = visual.sceneImage
	encounter["combatPresentation"] = visual.duplicate(true)
	encounter["battlefield"] = visual.get("battlefield")
	encounter["combatOutcomePresentation"] = choice.get(
		"combatOutcomePresentation", {}).duplicate(true)
	return encounter


func _faction_offer(state: Dictionary) -> Dictionary:
	var source := _faction_source(state)
	var encounter := _faction_encounter(state)
	if source.is_empty() or encounter.is_empty():
		return {}
	var visual: Dictionary = encounter.combatPresentation
	return {"sourceCardId": source.id, "originCardId": source.id,
		"originDirection": "left", "encounterId": encounter.id,
		"path": state.get("path"), "realm": state.get("realm"),
		"title": source.title, "description": source.description,
		"enemyName": encounter.enemy.get("name", ""),
		"mechanic": visual.get("mechanic", encounter.get("mechanic", "")),
		"challengeText": source.choices.left.text,
		"avoidText": source.choices.right.text,
		"warningTitle": visual.get("warningTitle", encounter.title),
		"presentationId": visual.get("presentationId"),
		"battlefieldId": visual.get("battlefieldId"),
		"sceneImage": visual.get("sceneImage"),
		"originSceneImage": source.get("sceneImage")}


func _faction_resolution(state: Dictionary, offer: Dictionary) -> Dictionary:
	var source := _faction_source(state)
	var encounter := _faction_encounter(state)
	if source.is_empty() or encounter.is_empty() \
			or offer.get("sourceCardId") != source.id:
		return {}
	var choice: Dictionary = source.choices.left.duplicate(true)
	choice.merge(_authored_choice(offer), true)
	choice["combatOutcomePresentation"] = source.choices.left.get(
		"combatOutcomePresentation", {}).duplicate(true)
	var combat: Dictionary = source.duplicate(true)
	combat.merge({"encounterId": encounter.id,
		"enemy": encounter.enemy.duplicate(true),
		"battlefield": encounter.battlefield,
		"combatPresentation": encounter.combatPresentation.duplicate(true),
		"victoryEffects": encounter.get("victoryEffects", {}).duplicate(true),
		"combatOutcomeLinks": encounter.get("outcomeLinks", {}).duplicate(true),
		"defeatHealthLoss": int(encounter.enemy.get("tier", 1)),
		"combatRules": {}}, true)
	return {"sourceCardId": source.id, "direction": "left",
		"sourceCard": source, "choice": choice, "combatCard": combat}

func _companion_source(state: Dictionary) -> Dictionary:
	var events := CompanionEvents.new(_content)
	if not events.valid(state):
		return {}
	var pending: Variant = state.get("pendingCompanionCard")
	if not pending is Dictionary or pending.get("id") != COMPANION_OLD_MASTER_SOURCE_ID:
		return {}
	var data: Dictionary = _document("companions:events")
	var owner: Dictionary = events._definition(data, "jian_linger")
	for event in owner.get("events", []):
		if event is Dictionary and event.get("id") == "jle_8_sword_tomb_old_master":
			var projected: Dictionary = events._build_card(state, owner, event)
			return projected if _same(projected, pending) else {}
	return {}

func _companion_encounter(state: Dictionary) -> Dictionary:
	var source := _companion_source(state)
	if source.is_empty() or source.get("choices", {}).get("left", {}).get(
			"encounterId") != COMPANION_OLD_MASTER_ENCOUNTER_ID:
		return {}
	var encounter := {}
	for row in _document("combat:encounters").get("encounters", []):
		if row is Dictionary and row.get("id") == COMPANION_OLD_MASTER_ENCOUNTER_ID:
			encounter = row.duplicate(true)
			break
	if encounter.is_empty() or encounter.get("requiredCompanion") != "jian_linger" \
			or state.get("realm") != encounter.get("realm") \
			or not state.get("resources", {}).get("companions", []).has("jian_linger") \
			or not encounter.get("enemy") is Dictionary \
			or not encounter.get("outcomeLinks") is Dictionary:
		return {}
	var visual: Dictionary = encounter.get("combatPresentation", {})
	for image in [source.get("sceneImage"), visual.get("sceneImage")]:
		var art: Dictionary = _content.asset_status(String(image))
		if not art.get("shaVerified", false) or not art.get("textureLoadable", false):
			source_error = "SOURCE_UNAVAILABLE" if art.get("fileExists") == false else "SOURCE_MISMATCH"
			return {}
	encounter["inlineCompanion"] = true
	encounter["sceneImage"] = visual.get("sceneImage")
	encounter["battlefield"] = visual.get("battlefield")
	return encounter

func _companion_offer(state: Dictionary) -> Dictionary:
	var source := _companion_source(state)
	var encounter := _companion_encounter(state)
	if source.is_empty() or encounter.is_empty():
		return {}
	var visual: Dictionary = encounter.combatPresentation
	return {"sourceCardId": source.id, "originCardId": source.id,
		"originDirection": "left", "encounterId": encounter.id,
		"path": state.get("path"), "realm": state.get("realm"),
		"title": source.title, "description": source.description,
		"enemyName": encounter.enemy.get("name", ""),
		"mechanic": visual.get("mechanic", encounter.get("mechanic", "")),
		"challengeText": source.choices.left.text,
		"avoidText": source.choices.right.text,
		"warningTitle": visual.get("warningTitle", encounter.title),
		"presentationId": visual.get("presentationId"),
		"battlefieldId": visual.get("battlefieldId"),
		"sceneImage": visual.get("sceneImage"),
		"originSceneImage": source.get("sceneImage")}

func _companion_resolution(state: Dictionary, offer: Dictionary) -> Dictionary:
	var source := _companion_source(state)
	var encounter := _companion_encounter(state)
	if source.is_empty() or encounter.is_empty() \
			or offer.get("sourceCardId") != source.id:
		return {}
	var choice: Dictionary = source.choices.left.duplicate(true)
	choice["defeatHealthLoss"] = int(encounter.enemy.get("tier", 1))
	var combat: Dictionary = source.duplicate(true)
	combat.merge({"encounterId": encounter.id,
		"enemy": encounter.enemy.duplicate(true),
		"battlefield": encounter.battlefield,
		"combatPresentation": encounter.combatPresentation.duplicate(true),
		"victoryEffects": encounter.get("victoryEffects", {}).duplicate(true),
		"combatOutcomeLinks": encounter.get("outcomeLinks", {}).duplicate(true),
		"defeatHealthLoss": int(encounter.enemy.get("tier", 1)),
		"combatRules": {}}, true)
	return {"sourceCardId": source.id, "direction": "left",
		"sourceCard": source, "choice": choice, "combatCard": combat}


func _resolve_offer(state: Dictionary) -> Dictionary:
	source_error = ""
	if _registry == null or _content == null \
			or not state.get("phase") in ["COMBAT_HANDOFF", "WARNING_PENDING", "BATTLE_PENDING",
				"FIRST_SESSION_ROUTE_PENDING", "QUEST_PENDING", "NORMAL_PENDING", "THREAD_PENDING", "FACTION_PENDING", "COMPANION_PENDING"]:
		return {}
	# The offer and the future battle request must agree on one verified source
	# set. An incomplete offer must not stay visible when a rule file drifts.
	if _source_content_hash().is_empty():
		return {}
	var card_id := String(state.get("currentCardId", ""))
	if card_id == FirstSessionRoute.ROUTE_ID:
		return _mountain_offer(state)
	if card_id == WHITEFOX_SOURCE_ID:
		return _whitefox_offer(state)
	if card_id == SWORD_QUEST_SOURCE_ID:
		return _sword_quest_offer(state)
	if card_id == FELLOW_SOURCE_ID:
		return _fellow_offer(state)
	if card_id == MISSION_SOURCE_ID:
		return _mission_offer(state)
	if card_id == BANDIT_SOURCE_ID:
		return _bandit_offer(state)
	if card_id == DUNGEON_BOSS_SOURCE_ID:
		return _dungeon_boss_offer(state)
	if card_id in NASCENT_COMBAT_IDS:
		return _nascent_offer(state)
	if card_id == TRIAL_COMBAT_ID:
		return _trial_offer(state)
	if card_id in THREAD_SOURCE_IDS:
		return _thread_offer(state)
	if card_id == FACTION_GATE_SOURCE_ID:
		return _faction_offer(state)
	if card_id == COMPANION_OLD_MASTER_SOURCE_ID:
		return _companion_offer(state)
	if state.get("pendingCadenceCard") is Dictionary:
		return _cadence_offer(state)
	if state.get("pendingRealmGateCard") is Dictionary:
		return _realm_gate_offer(state)
	if state.get("phase") in ["FIRST_SESSION_ROUTE_PENDING", "QUEST_PENDING", "THREAD_PENDING", "FACTION_PENDING", "COMPANION_PENDING"]:
		return {}
	if not card_id.begins_with(ENCOUNTER_PREFIX):
		return {}
	var encounter_id := card_id.trim_prefix(ENCOUNTER_PREFIX)
	var path_id := String(state.get("path", ""))
	var realm_id := String(state.get("realm", ""))
	var route: Dictionary = _document("progression:first_session_cohesion").get(
		"paths", {}).get(path_id, {})
	var history: Array = state.get("choiceHistory", [])
	if route.is_empty() or history.is_empty() \
			or route.get("teachingEncounterId") != encounter_id \
			or realm_id != "qi":
		return {}
	var clock: Dictionary = state.get("runClock", {})
	var decision_index := int(clock.get("decisionIndex", 0))
	var origin: Dictionary = history.back()
	var origin_id := String(origin.get("cardId", ""))
	var origin_direction := String(origin.get("direction", ""))
	if origin_id != route.get("prologueCardId") \
			or not origin_direction in ["left", "right"] \
			or int(origin.get("decisionIndex", -1)) != decision_index:
		return {}
	var encounter: Dictionary = {}
	for entry in _document("combat:encounters").get("encounters", []):
		if entry is Dictionary and entry.get("id") == encounter_id:
			encounter = entry
			break
	if encounter.is_empty() or encounter.get("path") != path_id \
			or encounter.get("realm") != realm_id \
			or encounter.get("teachingEncounter") != true:
		return {}
	var visual: Dictionary = _document("combat:encounter_presentations").get(
		"presentations", {}).get(encounter_id, {})
	var presentation_id := String(visual.get("presentationId", ""))
	var battlefield_id := String(visual.get("battlefieldId", ""))
	var scene_image := String(visual.get("sceneImage", ""))
	if scene_image.is_empty():
		scene_image = String(encounter.get("sceneImage", ""))
	if presentation_id.is_empty() or battlefield_id.is_empty() \
			or not scene_image.begins_with("assets/"):
		return {}
	var origin_card: Dictionary = {}
	for entry in _document("cards:qi").get("cards", []):
		if entry is Dictionary and entry.get("id") == origin_id:
			origin_card = entry
			break
	if origin_card.is_empty():
		return {}
	var enemy_name := String(encounter.get("enemy", {}).get("name", ""))
	var challenge_text := String(encounter.get("challengeText", ""))
	if challenge_text.is_empty():
		challenge_text = "迎战·" + enemy_name
	var avoid_text := String(encounter.get("avoid", {}).get("text", ""))
	if avoid_text.is_empty():
		avoid_text = "避开此战"
	return {
		"sourceCardId": card_id,
		"originCardId": origin_id,
		"originDirection": origin_direction,
		"encounterId": encounter_id,
		"path": path_id,
		"realm": realm_id,
		"title": String(encounter.get("title", "")),
		"description": String(encounter.get("description", "")),
		"enemyName": enemy_name,
		"mechanic": String(encounter.get("mechanic", "")),
		"challengeText": challenge_text,
		"avoidText": avoid_text,
		"warningTitle": String(visual.get("warningTitle", encounter.get("title", ""))),
		"presentationId": presentation_id,
		"battlefieldId": battlefield_id,
		"sceneImage": scene_image,
		"originSceneImage": String(origin_card.get("sceneImage", "")),
	}


func _realm_gate_offer(state: Dictionary) -> Dictionary:
	var realm := String(state.get("realm", ""))
	var gate_ids := {"qi": RealmGateFlow.CARD_ID,
		"foundation": RealmGateFlow.FOUNDATION_CARD_ID,
		"golden": RealmGateFlow.GOLDEN_CARD_ID,
		"nascent": RealmGateFlow.NASCENT_CARD_ID,
		"deity": RealmGateFlow.DEITY_CARD_ID,
		"tribulation": RealmGateFlow.TRIBULATION_CARD_ID}
	var card_id: String = gate_ids.get(realm, "")
	if state.get("phase") not in ["COMBAT_HANDOFF", "WARNING_PENDING", "BATTLE_PENDING"] \
			or state.get("currentCardId") != card_id \
			or realm not in ["qi", "foundation", "golden", "nascent", "deity", "tribulation"] \
			or state.get("noncombatFlow", {}).get("realmGateSourceSha") != _content.source_sha256(
				"cards:chapter_milestones"):
		return {}
	var source := RealmGateFlow.new(_content).source_card(state)
	if source.is_empty() or not _same(source, state.get("pendingRealmGateCard")):
		return {}
	var visual: Dictionary = source.get("combatPresentation", {})
	for image in [source.get("sceneImage"), visual.get("sceneImage")]:
		var status: Dictionary = _content.asset_status(image)
		if not status.get("shaVerified", false) or not status.get("textureLoadable", false):
			source_error = "SOURCE_UNAVAILABLE" if status.get("fileExists") == false else "SOURCE_MISMATCH"
			return {}
	var challenge := {"qi": "迎战雷关", "foundation": "迎战心魔劫",
		"golden": "迎战元婴天劫", "nascent": "迎战化神虚空雷罚",
		"deity": "迎战九重雷劫", "tribulation": "迎战飞升大劫"}
	var avoid := {"qi": "暂退雷关", "foundation": "暂退心魔劫",
		"golden": "暂退元婴天劫", "nascent": "暂退虚空雷罚",
		"deity": "暂退九重雷劫", "tribulation": "兵解遁入轮回"}
	var warning := {"qi": "筑基雷关将启", "foundation": "金丹心魔劫",
		"golden": "元婴天劫将至", "nascent": "化神虚空雷罚",
		"deity": "九重雷劫降临", "tribulation": "九九飞升大劫"}
	return {"sourceCardId": source.id, "originCardId": source.id,
		"originDirection": "left", "encounterId": source.id,
		"path": state.path, "realm": state.realm,
		"title": source.title, "description": source.description,
		"enemyName": source.enemy.name,
		"mechanic": visual.get("mechanic", ""),
		"challengeText": challenge[realm],
		"avoidText": avoid[realm],
		"warningTitle": visual.get("warningTitle", warning[realm]),
		"presentationId": visual.get("presentationId"),
		"battlefieldId": visual.get("battlefieldId"),
		"sceneImage": visual.get("sceneImage"),
		"originSceneImage": source.get("sceneImage")}


func _cadence_source_card(state: Dictionary, source_id: String) -> Dictionary:
	var catalog := CatalogEncounter.new(_content)
	var hashes := catalog.source_hashes()
	if hashes.is_empty():
		source_error = catalog.source_error
		return {}
	var director := EncounterDirector.new(_content)
	var pins := catalog.source_rule_pins()
	var director_pins := director.source_rule_pins()
	if director_pins.is_empty():
		source_error = director.source_error
		return {}
	pins.merge(director_pins, true)
	var marker: Dictionary = _as_dictionary(state.get("encounterCadence"))
	if marker.get("version") != 1:
		source_error = "SOURCE_MISMATCH"
		return {}
	# Each owner verifies its own pins; the shared marker can also contain
	# pins belonging to the global scheduler and settlement consumers.
	for key in pins:
		if _as_dictionary(marker.get("rulePins")).get(key) != pins[key]:
			source_error = "SOURCE_MISMATCH"
			return {}
	for key in hashes:
		if _as_dictionary(marker.get("sourceHashes")).get(key) != hashes[key]:
			source_error = "SOURCE_MISMATCH"
			return {}
	var source := catalog.card(state, source_id)
	if source.is_empty():
		source_error = catalog.source_error
		return {}
	for scene in [source.get("sceneImage"), source.get("choices", {}).get("left", {}).get(
			"combatPresentation", {}).get("sceneImage")]:
		if not scene is String or not String(scene).begins_with("assets/"):
			source_error = "SOURCE_MISMATCH"
			return {}
		var art: Dictionary = _content.asset_status(scene)
		if not art.get("shaVerified", false) or not art.get("textureLoadable", false):
			source_error = "SOURCE_UNAVAILABLE" if art.get("fileExists") == false else "SOURCE_MISMATCH"
			return {}
	return source


func _cadence_offer(state: Dictionary) -> Dictionary:
	if state.get("phase") not in ["COMBAT_HANDOFF", "WARNING_PENDING", "BATTLE_PENDING"]:
		return {}
	var source := _cadence_source_card(state, String(state.get("currentCardId", "")))
	if source.is_empty() or not _same(source, state.get("pendingCadenceCard")):
		return {}
	var catalog := CatalogEncounter.new(_content)
	if not catalog.eligible(state, source):
		return {}
	var director: Dictionary = _as_dictionary(state.get("noncombatFlow", {}).get("encounterDirectorState"))
	var pending: Dictionary = _as_dictionary(director.get("pending"))
	var decision := int(state.get("runClock", {}).get("decisionIndex", -1))
	var marker: Dictionary = state["encounterCadence"]
	var activation: Variant = marker.get("activationIndex")
	if decision < 0 or state.get("turn") != decision \
			or not activation is int and not activation is float \
			or float(activation) != floorf(float(activation)) or activation < 0 or activation > decision + 1 \
			or director.get("version") != 2 \
			or director.get("lifeId") != state.get("lifeCount", state.get("unlocks", {}).get("lifeCount", 0)) \
			or pending.get("cardId") != source.id or pending.get("encounterId") != source.encounterId \
			or pending.get("encounterKind") != source.encounterKind or pending.get("role") != source.encounterRole \
			or pending.get("realm") != state.get("realm") or pending.get("path") != state.get("path") \
			or pending.get("scheduledDecision") != decision + 1 or pending.get("presented") != true \
			or pending.get("accepted") != (state.get("phase") != "COMBAT_HANDOFF"):
		return {}
	var choice: Dictionary = source.choices.left
	var visual: Dictionary = choice.combatPresentation
	if String(visual.get("presentationId", "")).is_empty() or String(visual.get("battlefieldId", "")).is_empty():
		return {}
	return {"sourceCardId": source.id, "originCardId": source.id, "originDirection": "left",
		"encounterId": source.encounterId, "path": state.path, "realm": state.realm,
		"title": source.title, "description": source.description, "enemyName": choice.enemy.get("name", ""),
		"mechanic": source.mechanic, "challengeText": choice.text, "avoidText": source.choices.right.text,
		"warningTitle": visual.get("warningTitle", "危险预感"), "presentationId": visual.presentationId,
		"battlefieldId": visual.battlefieldId, "sceneImage": visual.sceneImage, "originSceneImage": source.sceneImage}


func fellow_source_card(state: Dictionary) -> Dictionary:
	var policy := NormalChoicePolicy.new(_content)
	var source: Dictionary = policy.source_card(FELLOW_SOURCE_ID, state)
	var choice: Dictionary = _as_dictionary(source.get("choices", {}).get("right"))
	var overlay: Dictionary = _document("combat:migrated_presentations").get(
		"presentations", {}).get("q_fellow:right", {})
	if source.get("type") != "COMBAT" or source.get("realm") != "qi" \
			or choice.get("triggerCombat") != true or not source.get("enemy") is Dictionary \
			or source["enemy"].get("templateId") != "sect_sparring_qi" \
			or not source.get("combatRewards") is Dictionary \
			or overlay.get("sourceCardId") != FELLOW_SOURCE_ID \
			or overlay.get("sourceDirection") != "right" \
			or String(overlay.get("presentationId", "")).is_empty() \
			or String(overlay.get("battlefieldId", "")).is_empty():
		source_error = "SOURCE_MISMATCH"
		return {}
	for scene in [source.get("sceneImage"), overlay.get("sceneImage")]:
		var art: Dictionary = _content.asset_status(scene)
		if not art.get("shaVerified", false) or not art.get("textureLoadable", false):
			source_error = "SOURCE_UNAVAILABLE" if art.get("fileExists") == false else "SOURCE_MISMATCH"
			return {}
	var merged: Dictionary = choice.get("combatPresentation", {}).duplicate(true)
	merged.merge(overlay, true)
	source["choices"]["right"]["combatPresentation"] = merged
	source["choices"]["right"]["battlefield"] = overlay.get("battlefield")
	source["choices"]["right"]["sceneImage"] = overlay.get("sceneImage")
	source["combatPresentation"] = merged.duplicate(true)
	return source


func bandit_source_card(state: Dictionary) -> Dictionary:
	var source: Dictionary = NormalChoicePolicy.new(_content).source_card(
		BANDIT_SOURCE_ID, state)
	var choice: Dictionary = source.get("choices", {}).get("left", {})
	var visual: Dictionary = choice.get("combatPresentation", {})
	if source.get("id") != BANDIT_SOURCE_ID or source.get("realm") != "golden" \
			or choice.get("triggerCombat") != true \
			or choice.get("enemy", {}).get("id") != "tiger_queen_golden" \
			or visual.get("presentationId") != "combat_tiger_queen_bandit_fort_v1":
		return {}
	for scene in [source.get("sceneImage"), visual.get("sceneImage"),
			visual.get("actorCards", {}).get("enemy", {}).get("image")]:
		var art: Dictionary = _content.asset_status(String(scene))
		if not art.get("shaVerified", false) or not art.get("textureLoadable", false):
			source_error = "SOURCE_UNAVAILABLE" if art.get("fileExists") == false else "SOURCE_MISMATCH"
			return {}
	return source


func _bandit_offer(state: Dictionary) -> Dictionary:
	if state.get("phase") not in ["NORMAL_PENDING", "WARNING_PENDING", "BATTLE_PENDING"] \
			or state.get("realm") != "golden":
		return {}
	var source := bandit_source_card(state)
	if source.is_empty():
		return {}
	var choice: Dictionary = source.choices.left
	var visual: Dictionary = choice.combatPresentation
	return {"sourceCardId": BANDIT_SOURCE_ID, "originCardId": BANDIT_SOURCE_ID,
		"originDirection": "left", "encounterId": null,
		"path": state.path, "realm": "golden",
		"title": source.title, "description": source.description,
		"enemyName": choice.enemy.name,
		"mechanic": visual.get("mechanic", ""),
		"challengeText": choice.text,
		"avoidText": source.choices.right.text,
		"warningTitle": visual.get("warningTitle", "女匪寨·虎娘试刀"),
		"presentationId": visual.presentationId,
		"battlefieldId": visual.battlefieldId,
		"sceneImage": visual.sceneImage,
		"originSceneImage": source.sceneImage}


func _bandit_resolution(state: Dictionary) -> Dictionary:
	var source := bandit_source_card(state)
	if source.is_empty():
		return {}
	var choice: Dictionary = source.choices.left.duplicate(true)
	var combat: Dictionary = source.duplicate(true)
	combat.merge({"encounterId": null, "encounterKind": null,
		"enemy": choice.enemy.duplicate(true),
		"battlefield": choice.enemy.get("battlefield"),
		"combatPresentation": choice.combatPresentation.duplicate(true),
		"combatRules": {}}, true)
	return {"sourceCardId": BANDIT_SOURCE_ID, "direction": "left",
		"sourceCard": source, "choice": choice, "combatCard": combat}


func _nascent_source_card(state: Dictionary) -> Dictionary:
	if state.get("realm") != "nascent" or state.get("currentCardId") not in NASCENT_COMBAT_IDS:
		return {}
	var source_id := String(state.currentCardId)
	var source: Dictionary = NormalChoicePolicy.new(_content).source_card(source_id, state)
	var choice: Dictionary = source.get("choices", {}).get("left", {})
	var overlay: Dictionary = _document("combat:migrated_presentations").get(
		"presentations", {}).get(source_id + ":left", {})
	if source.get("id") != source_id or choice.get("triggerCombat") != true \
			or source.get("enemy", {}).get("tier", 0) < 2 \
			or not source.get("combatRewards") is Dictionary \
			or overlay.get("sourceCardId") != source_id \
			or overlay.get("sourceDirection") != "left" \
			or String(overlay.get("presentationId", "")).is_empty() \
			or String(overlay.get("battlefieldId", "")).is_empty() \
			or source_id == "ar_boss" and (source.get("_dungeonId") != "ancient_ruins" \
				or source.get("_dungeonNodeIndex") != 3):
		source_error = "SOURCE_MISMATCH"
		return {}
	for scene in [source.get("sceneImage"), overlay.get("sceneImage"),
			overlay.get("actorCards", {}).get("enemy", {}).get("image")]:
		var art: Dictionary = _content.asset_status(String(scene))
		if not art.get("shaVerified", false) or not art.get("textureLoadable", false):
			source_error = "SOURCE_UNAVAILABLE" if art.get("fileExists") == false else "SOURCE_MISMATCH"
			return {}
	var merged: Dictionary = choice.get("combatPresentation", {}).duplicate(true)
	if source_id == "ar_boss":
		source["realm"] = "nascent"
	merged.merge(overlay, true)
	source["choices"]["left"]["combatPresentation"] = merged
	source["choices"]["left"]["battlefield"] = overlay.get("battlefield")
	source["choices"]["left"]["sceneImage"] = overlay.get("sceneImage")
	source["combatPresentation"] = merged.duplicate(true)
	return source


func _nascent_offer(state: Dictionary) -> Dictionary:
	if state.get("phase") not in ["NORMAL_PENDING", "WARNING_PENDING", "BATTLE_PENDING"]:
		return {}
	var source := _nascent_source_card(state)
	if source.is_empty():
		return {}
	var choice: Dictionary = source.choices.left
	var visual: Dictionary = choice.combatPresentation
	return {"sourceCardId": source.id, "originCardId": source.id,
		"originDirection": "left", "encounterId": null,
		"path": state.path, "realm": "nascent",
		"title": source.title, "description": source.description,
		"enemyName": source.enemy.name, "mechanic": visual.get("mechanic", ""),
		"challengeText": choice.text, "avoidText": source.choices.right.text,
		"warningTitle": visual.get("warningTitle", "危险预感"),
		"presentationId": visual.presentationId,
		"battlefieldId": visual.battlefieldId,
		"sceneImage": visual.sceneImage,
		"originSceneImage": source.sceneImage}


func _nascent_resolution(state: Dictionary) -> Dictionary:
	var source := _nascent_source_card(state)
	if source.is_empty():
		return {}
	var choice: Dictionary = source.choices.left.duplicate(true)
	var combat: Dictionary = source.duplicate(true)
	combat.merge({"encounterId": null,
		"enemy": source.enemy.duplicate(true),
		"battlefield": choice.get("battlefield"),
		"combatPresentation": choice.combatPresentation.duplicate(true),
		"combatRules": {}}, true)
	return {"sourceCardId": source.id, "direction": "left",
		"sourceCard": source, "choice": choice, "combatCard": combat}


func _trial_source_card(state: Dictionary) -> Dictionary:
	var run: Variant = state.get("dungeonRun")
	if state.get("realm") != "tribulation" or state.get("currentCardId") != TRIAL_COMBAT_ID \
			or not run is Dictionary or run.get("dungeonId") != "immortal_trial":
		return {}
	var source: Dictionary = HigherDungeonFlow.new(_content).node_card(state)
	var choice: Dictionary = source.get("choices", {}).get("left", {})
	var overlay: Dictionary = _document("combat:migrated_presentations").get(
		"presentations", {}).get("it_combat:left", {})
	if source.get("id") != TRIAL_COMBAT_ID or source.get("_dungeonNodeIndex") != 1 \
			or source.get("type") != "COMBAT" or choice.get("triggerCombat") != true \
			or source.get("enemy", {}).get("templateId") != "immortal_shadow_tribulation" \
			or not source.get("combatRewards") is Dictionary \
			or overlay.get("sourceCardId") != TRIAL_COMBAT_ID \
			or overlay.get("sourceDirection") != "left" \
			or String(overlay.get("presentationId", "")).is_empty() \
			or String(overlay.get("battlefieldId", "")).is_empty():
		source_error = "SOURCE_MISMATCH"
		return {}
	for scene in [source.get("sceneImage"), overlay.get("sceneImage"),
			overlay.get("actorCards", {}).get("enemy", {}).get("image")]:
		var art: Dictionary = _content.asset_status(String(scene))
		if art.get("shaVerified") != true or art.get("textureLoadable") != true:
			source_error = "SOURCE_UNAVAILABLE" if art.get("fileExists") == false else "SOURCE_MISMATCH"
			return {}
	var merged: Dictionary = choice.get("combatPresentation", {}).duplicate(true)
	merged.merge(overlay, true)
	source["realm"] = "tribulation"
	source["choices"]["left"]["combatPresentation"] = merged
	source["choices"]["left"]["battlefield"] = overlay.get("battlefield")
	source["choices"]["left"]["sceneImage"] = overlay.get("sceneImage")
	source["combatPresentation"] = merged.duplicate(true)
	return source


func _trial_offer(state: Dictionary) -> Dictionary:
	if state.get("phase") not in ["NORMAL_PENDING", "WARNING_PENDING", "BATTLE_PENDING"]:
		return {}
	var source := _trial_source_card(state)
	if source.is_empty():
		return {}
	var choice: Dictionary = source.choices.left
	var visual: Dictionary = choice.combatPresentation
	return {"sourceCardId": TRIAL_COMBAT_ID, "originCardId": TRIAL_COMBAT_ID,
		"originDirection": "left", "encounterId": null,
		"path": state.path, "realm": "tribulation",
		"title": source.title, "description": source.description,
		"enemyName": source.enemy.name, "mechanic": visual.get("mechanic", ""),
		"challengeText": choice.text, "avoidText": source.choices.right.text,
		"warningTitle": visual.get("warningTitle", "危险预感"),
		"presentationId": visual.presentationId,
		"battlefieldId": visual.battlefieldId,
		"sceneImage": visual.sceneImage,
		"originSceneImage": source.sceneImage}


func _trial_resolution(state: Dictionary) -> Dictionary:
	var source := _trial_source_card(state)
	if source.is_empty():
		return {}
	var choice: Dictionary = source.choices.left.duplicate(true)
	var combat: Dictionary = source.duplicate(true)
	combat.merge({"encounterId": null, "enemy": source.enemy.duplicate(true),
		"battlefield": choice.get("battlefield"),
		"combatPresentation": choice.combatPresentation.duplicate(true),
		"combatRules": {}}, true)
	return {"sourceCardId": TRIAL_COMBAT_ID, "direction": "left",
		"sourceCard": source, "choice": choice, "combatCard": combat}


func mission_source_card(state: Dictionary) -> Dictionary:
	var policy := NormalChoicePolicy.new(_content)
	var source: Dictionary = policy.source_card(MISSION_SOURCE_ID, state)
	var choice: Dictionary = _as_dictionary(source.get("choices", {}).get("right"))
	var overlay: Dictionary = _document("combat:migrated_presentations").get(
		"presentations", {}).get("f_mission:right", {})
	if source.get("type") != "COMBAT" or source.get("realm") != "foundation" \
			or choice.get("triggerCombat") != true or not source.get("enemy") is Dictionary \
			or source["enemy"].get("templateId") != "blazing_tiger_foundation" \
			or not source.get("combatRewards") is Dictionary \
			or overlay.get("sourceCardId") != MISSION_SOURCE_ID \
			or overlay.get("sourceDirection") != "right" \
			or String(overlay.get("presentationId", "")).is_empty() \
			or String(overlay.get("battlefieldId", "")).is_empty():
		source_error = "SOURCE_MISMATCH"
		return {}
	for scene in [source.get("sceneImage"), overlay.get("sceneImage")]:
		var art: Dictionary = _content.asset_status(scene)
		if not art.get("shaVerified", false) or not art.get("textureLoadable", false):
			source_error = "SOURCE_UNAVAILABLE" if art.get("fileExists") == false else "SOURCE_MISMATCH"
			return {}
	var merged: Dictionary = choice.get("combatPresentation", {}).duplicate(true)
	merged.merge(overlay, true)
	source["choices"]["right"]["combatPresentation"] = merged
	source["choices"]["right"]["battlefield"] = overlay.get("battlefield")
	source["choices"]["right"]["sceneImage"] = overlay.get("sceneImage")
	source["combatPresentation"] = merged.duplicate(true)
	return source


func _fellow_offer(state: Dictionary) -> Dictionary:
	if state.get("phase") not in ["NORMAL_PENDING", "WARNING_PENDING", "BATTLE_PENDING"] \
			or state.get("currentCardId") != FELLOW_SOURCE_ID:
		return {}
	var source := fellow_source_card(state)
	if source.is_empty():
		return {}
	var choice: Dictionary = source["choices"]["right"]
	var visual: Dictionary = choice["combatPresentation"]
	return {"sourceCardId": FELLOW_SOURCE_ID, "originCardId": FELLOW_SOURCE_ID,
		"originDirection": "right", "encounterId": null,
		"path": state.get("path"), "realm": state.get("realm"),
		"title": source["title"], "description": source["description"],
		"enemyName": source["enemy"].get("name", ""),
		"mechanic": visual.get("mechanic", ""),
		"challengeText": choice.get("text", ""),
		"avoidText": source["choices"]["left"].get("text", ""),
		"warningTitle": visual.get("warningTitle", "危险预感"),
		"presentationId": visual["presentationId"],
		"battlefieldId": visual["battlefieldId"],
		"sceneImage": visual["sceneImage"],
		"originSceneImage": source["sceneImage"]}


func _fellow_resolution(state: Dictionary) -> Dictionary:
	var source := fellow_source_card(state)
	if source.is_empty():
		return {}
	var choice: Dictionary = source["choices"]["right"].duplicate(true)
	var combat: Dictionary = source.duplicate(true)
	combat.merge({"encounterId": null, "encounterKind": null,
		"enemy": source["enemy"].duplicate(true),
		"battlefield": choice.get("battlefield"),
		"combatPresentation": choice["combatPresentation"].duplicate(true),
		"combatRules": {}}, true)
	return {"sourceCardId": FELLOW_SOURCE_ID, "direction": "right",
		"sourceCard": source, "choice": choice, "combatCard": combat}


func _mission_offer(state: Dictionary) -> Dictionary:
	if state.get("phase") not in ["NORMAL_PENDING", "WARNING_PENDING", "BATTLE_PENDING"] \
			or state.get("realm") != "foundation":
		return {}
	var source := mission_source_card(state)
	if source.is_empty():
		return {}
	var choice: Dictionary = source["choices"]["right"]
	var visual: Dictionary = choice["combatPresentation"]
	return {"sourceCardId": MISSION_SOURCE_ID, "originCardId": MISSION_SOURCE_ID,
		"originDirection": "right", "encounterId": null,
		"path": state.get("path"), "realm": "foundation",
		"title": source["title"], "description": source["description"],
		"enemyName": source["enemy"].get("name", ""),
		"mechanic": visual.get("mechanic", ""),
		"challengeText": choice.get("text", ""),
		"avoidText": source["choices"]["left"].get("text", ""),
		"warningTitle": visual.get("warningTitle", "危险预感"),
		"presentationId": visual["presentationId"],
		"battlefieldId": visual["battlefieldId"],
		"sceneImage": visual["sceneImage"],
		"originSceneImage": source["sceneImage"]}


func _mission_resolution(state: Dictionary) -> Dictionary:
	var source := mission_source_card(state)
	if source.is_empty():
		return {}
	var choice: Dictionary = source["choices"]["right"].duplicate(true)
	var combat: Dictionary = source.duplicate(true)
	combat.merge({"encounterId": null, "encounterKind": null,
		"enemy": source["enemy"].duplicate(true),
		"battlefield": choice.get("battlefield"),
		"combatPresentation": choice["combatPresentation"].duplicate(true),
		"combatRules": {}}, true)
	return {"sourceCardId": MISSION_SOURCE_ID, "direction": "right",
		"sourceCard": source, "choice": choice, "combatCard": combat}


func _dungeon_boss_source_card(state: Dictionary) -> Dictionary:
	if state.get("phase") not in ["NORMAL_PENDING", "WARNING_PENDING", "BATTLE_PENDING"] \
			or state.get("realm") != "foundation" \
			or state.get("currentCardId") != DUNGEON_BOSS_SOURCE_ID \
			or not state.get("dungeonRun") is Dictionary \
			or state.dungeonRun.get("dungeonId") != FoundationDungeonFlow.DUNGEON_ID:
		return {}
	var source: Dictionary = FoundationDungeonFlow.new(_content).node_card(state)
	if source.get("id") != DUNGEON_BOSS_SOURCE_ID \
			or source.get("_dungeonNodeId") != "boss" \
			or source.get("type") != "BOSS_COMBAT" \
			or not source.get("enemy", {}).get("phases") is Array \
			or source.enemy.phases.size() != 3:
		return {}
	return source


func _dungeon_boss_offer(state: Dictionary) -> Dictionary:
	var source := _dungeon_boss_source_card(state)
	var direction := String(state.get("pendingDungeonBossDirection", ""))
	if source.is_empty() or direction not in ["left", "right"]:
		return {}
	var visual: Dictionary = source.get("combatPresentation", {})
	var scene_image := String(source.get("sceneImage", ""))
	if visual.get("id") != "combat_realm_guardian_array_agc_v1" \
			or visual.get("battlefieldId") != "battlefield_realm_guardian_array_agc_v1" \
			or not _content.asset_status(scene_image).get("textureLoadable", false):
		return {}
	return {"sourceCardId": DUNGEON_BOSS_SOURCE_ID,
		"originCardId": DUNGEON_BOSS_SOURCE_ID,
		"originDirection": direction, "encounterId": null,
		"path": state.get("path"), "realm": "foundation",
		"title": source.title, "description": source.description,
		"enemyName": source.enemy.name, "mechanic": "三相连续战斗",
		"challengeText": source.choices[direction].get("text", ""),
		"avoidText": "离开秘境", "warningTitle": "太虚阵灵将启",
		"presentationId": visual.id,
		"battlefieldId": visual.battlefieldId,
		"sceneImage": scene_image, "originSceneImage": scene_image}


func _dungeon_boss_resolution(state: Dictionary) -> Dictionary:
	var source := _dungeon_boss_source_card(state)
	var direction := String(state.get("pendingDungeonBossDirection", ""))
	if source.is_empty() or direction not in ["left", "right"]:
		return {}
	var choice: Dictionary = source.choices[direction].duplicate(true)
	if choice.get("effects") != {}:
		return {}
	choice["triggerCombat"] = true
	var combat := source.duplicate(true)
	var visual: Dictionary = combat["combatPresentation"]
	var phase_visual: Dictionary = _document("combat:action_presentations").get(
		"bossPhaseTransitions", {}).get(DUNGEON_BOSS_SOURCE_ID, {})
	var frames: Array = phase_visual.get("animation", {}).get("frames", [])
	if phase_visual.get("sourceCardId") != DUNGEON_BOSS_SOURCE_ID \
			or frames.size() != 4:
		return {}
	for frame in frames:
		var art: Dictionary = _content.asset_status(String(frame))
		if not art.get("shaVerified", false) or not art.get("textureLoadable", false):
			return {}
	visual["sceneImage"] = source.sceneImage
	visual["presentationId"] = visual.id
	visual["actorCards"] = {"enemy": {"image": frames[0],
		"intentFrames": {"attack": frames[1], "buff": frames[2]}}}
	visual["bossPhaseFrames"] = frames.duplicate()
	combat["encounterId"] = null
	combat["realm"] = "foundation"
	return {"sourceCardId": DUNGEON_BOSS_SOURCE_ID,
		"direction": direction, "sourceCard": source,
		"choice": choice, "combatCard": combat}


func _thread_source_card(state: Dictionary, source_id: String) -> Dictionary:
	if source_id not in THREAD_SOURCE_IDS:
		return {}
	var bundle: Dictionary = state.get("storyThreadState", {})
	var source_pin := "lastLessonSourceSha" if source_id == LAST_LESSON_SOURCE_ID \
		else "sourceSha"
	var module_id := LAST_LESSON_MODULE if source_id == LAST_LESSON_SOURCE_ID \
		else "threads:qi_threads"
	if bundle.get(source_pin) != _content.source_sha256(module_id) \
			or bundle.get("villagePresentationSha") != _content.source_sha256(
				"combat:migrated_presentations"):
		source_error = "SOURCE_MISMATCH"
		return {}
	var thread := StoryThreadFlow.new(_content)
	var source: Dictionary = thread.thread_combat_card(state)
	var expected_enemy := "resentment_shadow_qi" if source_id == VILLAGE_SOURCE_ID \
		else "sword_intent_avatar_qi" if source_id == SWORD_SOURCE_ID \
		else "sword_intent_avatar_deity"
	var enemy: Dictionary = source.get("choices", {}).get("left", {}).get(
		"enemy", {}) if source_id == LAST_LESSON_SOURCE_ID else source.get("enemy", {})
	if source.get("id") != source_id or enemy.get("templateId") != expected_enemy:
		source_error = "SOURCE_MISMATCH"
		return {}
	return source


func _thread_offer(state: Dictionary) -> Dictionary:
	if state.get("phase") not in ["THREAD_PENDING", "WARNING_PENDING", "BATTLE_PENDING"]:
		return {}
	var direction := String(state.get("pendingThreadCombatDirection", ""))
	if direction not in ["left", "right"]:
		return {}
	var source_id := String(state.get("currentCardId", ""))
	var source := _thread_source_card(state, source_id)
	if source.is_empty():
		return {}
	if source_id == LAST_LESSON_SOURCE_ID and direction != "left":
		return {}
	var choice: Dictionary = source["choices"][direction]
	var visual: Dictionary = choice["combatPresentation"]
	return {"sourceCardId": source_id, "originCardId": source_id,
		"originDirection": direction, "encounterId": null,
		"threadId": _thread_id_for_source(source_id),
		"path": state.get("path"), "realm": source["realm"],
		"title": source["title"], "description": source["description"],
		"enemyName": choice.get("enemy", source.get("enemy", {})).get("name", ""),
		"mechanic": visual.get("mechanic", ""),
		"challengeText": choice.get("text", ""),
		"avoidText": source["choices"]["right" if direction == "left" else "left"].get("text", ""),
		"warningTitle": visual.get("warningTitle", "危险预感"),
		"presentationId": visual.get("presentationId"),
		"battlefieldId": visual.get("battlefieldId"),
		"sceneImage": source.get("sceneImage") if source_id in [SWORD_SOURCE_ID,
			LAST_LESSON_SOURCE_ID] \
			else visual.get("sceneImage"),
		"originSceneImage": source["sceneImage"]}


func _thread_resolution(state: Dictionary, offer: Dictionary) -> Dictionary:
	var source_id := String(offer.get("sourceCardId", ""))
	var source := _thread_source_card(state, source_id)
	if source.is_empty():
		return {}
	var direction := String(offer.get("originDirection", ""))
	if direction not in ["left", "right"]:
		return {}
	if source_id == LAST_LESSON_SOURCE_ID and direction != "left":
		return {}
	var choice: Dictionary = source["choices"][direction].duplicate(true)
	var combat: Dictionary = source.duplicate(true)
	combat.merge({"encounterId": null, "encounterKind": null,
		"enemy": choice.get("enemy", source.get("enemy", {})).duplicate(true),
		"battlefield": choice.get("battlefield"),
		"combatPresentation": choice["combatPresentation"].duplicate(true),
		"combatRules": {}}, true)
	return {"sourceCardId": source_id, "direction": direction,
		"sourceCard": source, "choice": choice, "combatCard": combat}


func _whitefox_source_card(state: Dictionary) -> Dictionary:
	# Quest data has its own save pin; keep CONTENT_FILES unchanged so existing
	# teaching and mountain requests retain their source hash.
	var quest_sha := String(_content.source_sha256(WHITEFOX_MODULE))
	if quest_sha.length() != 64:
		var path := String(_content.module_path(WHITEFOX_MODULE))
		source_error = "SOURCE_UNAVAILABLE" if path.is_empty() \
			or not FileAccess.file_exists(ContentRepository.CONTENT_ROOT + path) else "SOURCE_MISMATCH"
		return {}
	var gateway_hash := _source_content_hash()
	if gateway_hash.is_empty():
		return {}
	var flow: Dictionary = _as_dictionary(state.get("noncombatFlow"))
	if flow.get("questSourceSha") != quest_sha or flow.get("sourceContentHash") != gateway_hash:
		source_error = "SOURCE_MISMATCH"
		return {}
	var document := _document(WHITEFOX_MODULE)
	if not document.get("quest") is Dictionary \
			or document["quest"].get("id") != WHITEFOX_QUEST_ID \
			or not document.get("cards") is Array:
		source_error = "SOURCE_MISMATCH"
		return {}
	var source := {}
	for row in document["cards"]:
		if row is Dictionary and row.get("id") == WHITEFOX_SOURCE_ID:
			source = row.duplicate(true)
			break
	var choices: Dictionary = _as_dictionary(source.get("choices"))
	var choice: Dictionary = _as_dictionary(choices.get("left"))
	var enemy: Dictionary = _as_dictionary(choice.get("enemy"))
	var presentation: Dictionary = _as_dictionary(choice.get("combatPresentation"))
	if source.get("type") != "QUEST" or source.get("questId") != WHITEFOX_QUEST_ID \
			or source.get("questStep") != 3 or source.get("realm") != "qi" \
			or not source.get("title") is String or not source.get("description") is String \
			or not choices.get("right") is Dictionary or not choices.get("down") is Dictionary \
			or choice.get("triggerCombat") != true or choice.has("combatEncounterId") \
			or choice.has("encounterId") or source.has("encounterId") \
			or enemy.is_empty() or not enemy.get("name") is String \
			or not enemy.get("hp") is float and not enemy.get("hp") is int \
			or not enemy.get("atk") is float and not enemy.get("atk") is int \
			or not enemy.get("def") is float and not enemy.get("def") is int \
			or not enemy.get("tier") is float and not enemy.get("tier") is int \
			or String(presentation.get("presentationId", "")).is_empty() \
			or String(presentation.get("battlefieldId", "")).is_empty():
		source_error = "SOURCE_MISMATCH"
		return {}
	for scene in [source.get("sceneImage"), presentation.get("sceneImage")]:
		if not scene is String or not String(scene).begins_with("assets/"):
			source_error = "SOURCE_MISMATCH"
			return {}
		var art: Dictionary = _content.asset_status(scene)
		if not art.get("shaVerified", false) or not art.get("textureLoadable", false):
			source_error = "SOURCE_UNAVAILABLE" if art.get("fileExists") == false else "SOURCE_MISMATCH"
			return {}
	return source


func _whitefox_offer(state: Dictionary) -> Dictionary:
	if state.get("phase") not in ["QUEST_PENDING", "WARNING_PENDING", "BATTLE_PENDING"]:
		return {}
	var source := _whitefox_source_card(state)
	if source.is_empty() or not _same(source, state.get("pendingQuestCard")):
		return {}
	var quest_state: Dictionary = _as_dictionary(state.get("questState"))
	var active: Variant = quest_state.get("activeQuests")
	var flags: Dictionary = _as_dictionary(state.get("flags"))
	if not active is Array or active.size() != 1 or not active[0] is Dictionary \
			or active[0].get("questId") != WHITEFOX_QUEST_ID or active[0].get("step") != 2 \
			or flags.get("quest_white_fox_line_active") != true \
			or flags.get("quest_white_fox_line_step") != 2 or flags.get("whiteFoxCompleted") == true \
			or source.get("realm") != state.get("realm"):
		return {}
	var choice: Dictionary = source["choices"]["left"]
	var visual: Dictionary = choice["combatPresentation"]
	return {"sourceCardId": source["id"], "originCardId": source["id"], "originDirection": "left",
		"encounterId": null, "questId": source["questId"], "path": state.get("path"), "realm": source["realm"],
		"title": source["title"], "description": source["description"],
		"enemyName": choice["enemy"]["name"], "mechanic": visual.get("mechanic", ""),
		"challengeText": choice.get("text", ""), "avoidText": source["choices"]["right"].get("text", ""),
		"warningTitle": visual.get("warningTitle", "危险预感"),
		"presentationId": visual["presentationId"], "battlefieldId": visual["battlefieldId"],
		"sceneImage": visual["sceneImage"], "originSceneImage": source["sceneImage"]}


func _whitefox_resolution(state: Dictionary) -> Dictionary:
	var source := _whitefox_source_card(state)
	if source.is_empty():
		return {}
	var choice: Dictionary = source["choices"]["left"].duplicate(true)
	# CombatCoordinator.buildChoiceCombatWarning adds null catalog fields and
	# omits JavaScript undefined fields; the original choice remains untouched.
	var combat: Dictionary = source.duplicate(true)
	combat.merge({"encounterId": null, "encounterKind": null,
		"enemy": choice["enemy"].duplicate(true), "battlefield": choice["enemy"].get("battlefield"),
		"combatPresentation": choice["combatPresentation"].duplicate(true), "combatRules": {}}, true)
	return {"sourceCardId": source["id"], "direction": "left", "sourceCard": source,
		"choice": choice, "combatCard": combat}


func _sword_quest_source_card(state: Dictionary) -> Dictionary:
	var source_sha: String = _content.source_sha256(SWORD_QUEST_MODULE)
	if source_sha.length() != 64:
		var path := String(_content.module_path(SWORD_QUEST_MODULE))
		source_error = "SOURCE_UNAVAILABLE" if path.is_empty() or not FileAccess.file_exists(
			ContentRepository.CONTENT_ROOT + path) else "SOURCE_MISMATCH"
		return {}
	if state.get("noncombatFlow", {}).get("foundationQuestSourceSha") != source_sha \
			or state.get("noncombatFlow", {}).get("sourceContentHash") != _source_content_hash():
		source_error = "SOURCE_MISMATCH"
		return {}
	var document := _document(SWORD_QUEST_MODULE)
	if document.get("quest", {}).get("id") != SWORD_QUEST_ID \
			or not document.get("cards") is Array:
		source_error = "SOURCE_MISMATCH"
		return {}
	var source: Dictionary = {}
	for row in document.cards:
		if row is Dictionary and row.get("id") == SWORD_QUEST_SOURCE_ID:
			source = row.duplicate(true)
			break
	if source.get("type") != "QUEST" or source.get("questId") != SWORD_QUEST_ID \
			or int(source.get("questStep", -1)) != 3 or source.get("realm") != "foundation":
		source_error = "SOURCE_MISMATCH"
		return {}
	for variant in source.get("stateVariants", []):
		if variant is Dictionary and state.get("flags", {}).get(variant.get("whenFlag"), false):
			for key in ["title", "description", "sceneImage", "artDirection", "choices"]:
				if variant.has(key):
					var value: Variant = variant[key]
					source[key] = value.duplicate(true) if value is Dictionary or value is Array else value
			break
	if source != state.get("pendingQuestCard"):
		return {}
	for direction in ["left", "right"]:
		var choice: Dictionary = source.get("choices", {}).get(direction, {})
		var visual: Dictionary = choice.get("combatPresentation", {})
		if choice.get("triggerCombat") != true or not choice.get("enemy") is Dictionary \
				or visual.get("sourceCardId") != SWORD_QUEST_SOURCE_ID \
				or visual.get("sourceDirection") != direction \
				or String(visual.get("presentationId", "")).is_empty() \
				or String(visual.get("battlefieldId", "")).is_empty():
			source_error = "SOURCE_MISMATCH"
			return {}
		for scene in [source.get("sceneImage"), visual.get("sceneImage")]:
			var art: Dictionary = _content.asset_status(String(scene))
			if not art.get("shaVerified", false) or not art.get("textureLoadable", false):
				source_error = "SOURCE_UNAVAILABLE" if art.get("fileExists") == false else "SOURCE_MISMATCH"
				return {}
	return source


func _sword_quest_offer(state: Dictionary) -> Dictionary:
	if state.get("phase") not in ["QUEST_PENDING", "WARNING_PENDING", "BATTLE_PENDING"]:
		return {}
	var source := _sword_quest_source_card(state)
	var direction := String(state.get("pendingQuestCombatDirection", ""))
	var active: Array = state.get("questState", {}).get("activeQuests", [])
	if source.is_empty() or direction not in ["left", "right"] or active.size() != 1 \
			or active[0].get("questId") != SWORD_QUEST_ID or int(active[0].get("step", -1)) != 2 \
			or state.get("flags", {}).get("quest_sword_legacy_active") != true \
			or state.get("realm") != "foundation":
		return {}
	var choice: Dictionary = source.choices[direction]
	var visual: Dictionary = choice.combatPresentation
	return {"sourceCardId": source.id, "originCardId": source.id,
		"originDirection": direction, "encounterId": null,
		"questId": SWORD_QUEST_ID, "path": state.get("path"), "realm": source.realm,
		"title": source.title, "description": source.description,
		"enemyName": choice.enemy.name, "mechanic": visual.get("mechanic", ""),
		"challengeText": choice.get("text", ""),
		"avoidText": source.choices.down.get("text", ""),
		"warningTitle": visual.get("warningTitle", "危险预感"),
		"presentationId": visual.presentationId,
		"battlefieldId": visual.battlefieldId,
		"sceneImage": visual.sceneImage,
		"originSceneImage": source.sceneImage}


func _sword_quest_resolution(state: Dictionary, offer: Dictionary) -> Dictionary:
	var source := _sword_quest_source_card(state)
	var direction := String(offer.get("originDirection", ""))
	if source.is_empty() or direction not in ["left", "right"]:
		return {}
	var choice: Dictionary = source.choices[direction].duplicate(true)
	var combat: Dictionary = source.duplicate(true)
	combat.merge({"encounterId": null, "encounterKind": null,
		"enemy": choice.enemy.duplicate(true),
		"battlefield": choice.combatPresentation.get("battlefield"),
		"combatPresentation": choice.combatPresentation.duplicate(true),
		"combatRules": {}}, true)
	return {"sourceCardId": source.id, "direction": direction,
		"sourceCard": source, "choice": choice, "combatCard": combat}


func _mountain_source_card(state: Dictionary) -> Dictionary:
	var route := FirstSessionRoute.new(_content)
	var hashes: Dictionary = route.source_hashes()
	if hashes.is_empty():
		source_error = route.source_error
		return {}
	var gateway_hash := _source_content_hash()
	if gateway_hash.is_empty():
		return {}
	if state.get("noncombatFlow", {}).get("firstSessionRouteSourceHashes") != hashes \
			or state.get("noncombatFlow", {}).get("sourceContentHash") != gateway_hash:
		source_error = "SOURCE_MISMATCH"
		return {}
	var source := route.card(state, FirstSessionRoute.ROUTE_ID)
	if source.is_empty():
		source_error = route.source_error
		return {}
	var definition: Dictionary = _document("progression:first_session_cohesion")
	if definition.get("paths", {}).get(state.get("path"), {}).get(
			"routeLensRef", {}).get("cardId") != source.get("id") \
			or source.get("choices", {}).get("left", {}).get("combatEncounterId") != definition.get(
				"beats", {}).get("route", {}).get("encounterId"):
		return {}
	return source


func _mountain_offer(state: Dictionary) -> Dictionary:
	if state.get("phase") not in ["FIRST_SESSION_ROUTE_PENDING", "WARNING_PENDING", "BATTLE_PENDING"]:
		return {}
	var source := _mountain_source_card(state)
	if source.is_empty():
		return {}
	var choice: Dictionary = source["choices"]["left"]
	var encounter := resolved_encounter(state, String(choice.get("combatEncounterId", "")))
	if encounter.is_empty() or encounter.get("realm") != state.get("realm"):
		return {}
	var visual: Dictionary = encounter.get("combatPresentation", {})
	var scene := String(visual.get("sceneImage", encounter.get("sceneImage", "")))
	if String(visual.get("presentationId", "")).is_empty() \
			or String(visual.get("battlefieldId", "")).is_empty() or not scene.begins_with("assets/"):
		return {}
	var art: Dictionary = _content.asset_status(scene)
	if not art.get("shaVerified", false) or not art.get("textureLoadable", false):
		source_error = "SOURCE_UNAVAILABLE" if art.get("fileExists") == false else "SOURCE_MISMATCH"
		return {}
	return {"sourceCardId": source["id"], "originCardId": source["id"], "originDirection": "left",
		"encounterId": encounter["id"], "path": state["path"], "realm": state["realm"],
		"title": source["title"], "description": source["description"],
		"enemyName": encounter["enemy"].get("name", ""), "mechanic": encounter.get("mechanic", ""),
		"challengeText": choice.get("text", ""), "avoidText": source["choices"]["right"].get("text", ""),
		"warningTitle": visual.get("warningTitle", encounter.get("title", "")),
		"presentationId": visual["presentationId"], "battlefieldId": visual["battlefieldId"],
		"sceneImage": scene, "originSceneImage": source.get("sceneImage", "")}


func resolved_encounter(state: Dictionary, encounter_id: Variant, source_card_id: String = "") -> Dictionary:
	if source_card_id == COMPANION_OLD_MASTER_SOURCE_ID:
		var companion_encounter := _companion_encounter(state)
		return companion_encounter if companion_encounter.get("id") == encounter_id else {}
	if source_card_id == FACTION_GATE_SOURCE_ID:
		var faction_encounter := _faction_encounter(state)
		return faction_encounter if faction_encounter.get("id") == encounter_id else {}
	if source_card_id == TRIAL_COMBAT_ID:
		if encounter_id != null:
			return {}
		var source: Dictionary = state.get("pendingBattle", {}).get(
			"pendingResolution", {}).get("combatCard", {})
		if source.is_empty():
			var history: Array = state.get("battleResultHistory", [])
			source = history.back().get("sourceCombat", {}) if not history.is_empty() else {}
		if source.get("id") != TRIAL_COMBAT_ID or source.get("realm") != "tribulation" \
				or source.get("_dungeonId") != "immortal_trial" \
				or source.get("_dungeonNodeIndex") != 1:
			return {}
		var choice: Dictionary = source.get("choices", {}).get("left", {})
		return {"id": TRIAL_COMBAT_ID, "inlineHigherDungeon": true,
			"title": source.get("title", ""), "realm": "tribulation",
			"enemy": source.get("enemy", {}).duplicate(true),
			"sceneImage": source.get("sceneImage", ""),
			"combatPresentation": source.get("combatPresentation", {}).duplicate(true),
			"battlefield": source.get("battlefield"),
			"defeatHealthLoss": int(source.get("enemy", {}).get("tier", 1)),
			"victoryEffects": choice.get("victoryEffects", {}).duplicate(true),
			"defeatEffects": choice.get("defeatEffects", {}).duplicate(true),
			"fleeEffects": choice.get("fleeEffects", {}).duplicate(true),
			"combatRewards": source.get("combatRewards", {}).duplicate(true)}
	if source_card_id in NASCENT_COMBAT_IDS:
		if encounter_id != null:
			return {}
		var source: Dictionary = state.get("pendingBattle", {}).get(
			"pendingResolution", {}).get("combatCard", {})
		if source.is_empty():
			var history: Array = state.get("battleResultHistory", [])
			source = history.back().get("sourceCombat", {}) \
				if not history.is_empty() else {}
		if source.get("id") != source_card_id or source.get("realm") != "nascent":
			return {}
		var choice: Dictionary = source.get("choices", {}).get("left", {})
		return {"id": source_card_id, "inlineNascent": true,
			"title": source.get("title", ""), "realm": "nascent",
			"enemy": source.get("enemy", {}).duplicate(true),
			"sceneImage": source.get("sceneImage", ""),
			"combatPresentation": source.get("combatPresentation", {}).duplicate(true),
			"battlefield": source.get("battlefield"),
			"defeatHealthLoss": int(source.get("enemy", {}).get("tier", 1)),
			"victoryEffects": choice.get("victoryEffects", {}).duplicate(true),
			"defeatEffects": choice.get("defeatEffects", {}).duplicate(true),
			"fleeEffects": choice.get("fleeEffects", {}).duplicate(true),
			"combatRewards": source.get("combatRewards", {}).duplicate(true)}
	if source_card_id == DUNGEON_BOSS_SOURCE_ID:
		if encounter_id != null:
			return {}
		var source: Dictionary = state.get("pendingBattle", {}).get(
			"pendingResolution", {}).get("combatCard", {})
		if source.is_empty():
			var history: Array = state.get("battleResultHistory", [])
			source = history.back().get("sourceCombat", {}) \
				if not history.is_empty() else {}
		if source.get("id") != DUNGEON_BOSS_SOURCE_ID \
				or source.get("_dungeonNodeId") != "boss":
			return {}
		return {"id": DUNGEON_BOSS_SOURCE_ID, "inlineDungeonBoss": true,
			"title": source.get("title", ""), "realm": "foundation",
			"enemy": source.get("enemy", {}).duplicate(true),
			"sceneImage": source.get("sceneImage", ""),
			"combatPresentation": source.get("combatPresentation", {}).duplicate(true),
			"battlefield": source.get("battlefield", "cave"),
			"combatRewards": source.get("combatRewards", {}).duplicate(true)} \
			if not source.is_empty() else {}
	if source_card_id == SWORD_QUEST_SOURCE_ID:
		if encounter_id != null:
			return {}
		var source := _sword_quest_source_card(state)
		var direction := String(state.get("pendingQuestCombatDirection", ""))
		if source.is_empty() or direction not in ["left", "right"]:
			return {}
		var choice: Dictionary = source.choices[direction]
		return {"id": source_card_id, "inlineQuest": true,
			"sourceDirection": direction, "title": source.title,
			"realm": source.realm, "questId": source.questId,
			"enemy": choice.enemy.duplicate(true),
			"sceneImage": source.sceneImage,
			"combatPresentation": choice.combatPresentation.duplicate(true),
			"battlefield": choice.combatPresentation.get("battlefield"),
			"defeatHealthLoss": int(choice.enemy.get("tier", 1)),
			"defeatHealthFloor": int(choice.get("defeatHealthFloor", 0)),
			"victoryEffects": choice.get("victoryEffects", {}).duplicate(true),
			"defeatEffects": choice.get("defeatEffects", {}).duplicate(true),
			"fleeEffects": choice.get("fleeEffects", {}).duplicate(true)}
	if source_card_id in THREAD_SOURCE_IDS:
		var lesson: bool = source_card_id == LAST_LESSON_SOURCE_ID
		var module_id := LAST_LESSON_MODULE if lesson else "threads:qi_threads"
		var pin_id := "lastLessonSourceSha" if lesson else "sourceSha"
		if encounter_id != null or state.get("storyThreadState", {}).get(
				pin_id) != _content.source_sha256(module_id) \
				or state.get("storyThreadState", {}).get("villagePresentationSha") != \
				_content.source_sha256("combat:migrated_presentations"):
			return {}
		var direction := String(state.get("pendingThreadCombatDirection", ""))
		var source: Dictionary = _as_dictionary(state.get("pendingBattle", {}).get(
			"pendingResolution", {}).get("sourceCard"))
		if source.is_empty():
			var history: Array = state.get("battleResultHistory", [])
			var record: Dictionary = history.back() if not history.is_empty() else {}
			direction = String(record.get("sourceDirection", ""))
			var settled: Dictionary = _as_dictionary(record.get("sourceCombat"))
			return settled if settled.get("id") == source_card_id and settled.get(
				"sourceDirection") == direction else {}
		if direction not in (["left"] if lesson else ["left", "right"]) or not _same(source,
				_thread_source_card(state, source_card_id)):
			return {}
		var choice: Dictionary = source["choices"][direction]
		var result_visual: Dictionary = choice["combatPresentation"].duplicate(true)
		if source_card_id == SWORD_SOURCE_ID:
			var authored: Dictionary = {}
			for thread in _document("threads:qi_threads").get("threads", []):
				if thread is Dictionary and thread.get("threadId") == SWORD_THREAD_ID:
					authored = thread.get("nodes", [])[1].get("card", {}).get(
						"choices", {}).get(direction, {}).get("combatPresentation", {})
					break
			if authored.is_empty():
				return {}
			result_visual = authored.duplicate(true)
		var enemy: Dictionary = choice.get("enemy", source.get("enemy", {}))
		return {"id": source_card_id, "inlineThread": true,
			"sourceDirection": direction, "title": source["title"], "realm": source["realm"],
			"enemy": enemy.duplicate(true), "sceneImage": source["sceneImage"],
			"combatPresentation": result_visual,
			"battlefield": choice.get("battlefield"),
			"defeatHealthLoss": int(choice.get("defeatHealthLoss",
				enemy.get("tier", 1))),
			"defeatHealthFloor": int(choice.get("defeatHealthFloor", 0)),
			"victoryEffects": choice.get("victoryEffects", {}).duplicate(true),
			"defeatEffects": choice.get("defeatEffects", {}).duplicate(true),
			"fleeEffects": choice.get("fleeEffects", {}).duplicate(true)}
	if source_card_id == BANDIT_SOURCE_ID:
		if encounter_id != null:
			return {}
		var source := bandit_source_card(state)
		if source.is_empty():
			return {}
		var choice: Dictionary = source.choices.left
		return {"id": BANDIT_SOURCE_ID, "inlineBandit": true,
			"title": source.title, "realm": "golden",
			"enemy": choice.enemy.duplicate(true),
			"sceneImage": source.sceneImage,
			"combatPresentation": choice.combatPresentation.duplicate(true),
			"battlefield": choice.enemy.get("battlefield"),
			"defeatHealthLoss": int(choice.defeatHealthLoss),
			"victoryEffects": choice.victoryEffects.duplicate(true),
			"defeatEffects": choice.defeatEffects.duplicate(true),
			"fleeEffects": choice.fleeEffects.duplicate(true)}
	if source_card_id in [FELLOW_SOURCE_ID, MISSION_SOURCE_ID]:
		if encounter_id != null:
			return {}
		var source := fellow_source_card(state) if source_card_id == FELLOW_SOURCE_ID \
			else mission_source_card(state)
		if source.is_empty():
			return {}
		var choice: Dictionary = source["choices"]["right"]
		return {"id": source_card_id, "inlineCombat": true,
			"title": source["title"], "realm": source["realm"],
			"enemy": source["enemy"].duplicate(true),
			"sceneImage": source["sceneImage"],
			"combatPresentation": choice["combatPresentation"].duplicate(true),
			"battlefield": choice.get("battlefield"),
			"defeatHealthLoss": int(source["enemy"].get("tier", 1)),
			"victoryEffects": choice.get("victoryEffects", {}).duplicate(true),
			"defeatEffects": choice.get("defeatEffects", {}).duplicate(true),
			"fleeEffects": choice.get("fleeEffects", {}).duplicate(true),
			"combatRewards": source["combatRewards"].duplicate(true)}
	if source_card_id == WHITEFOX_SOURCE_ID:
		if encounter_id != null:
			return {}
		var source := _whitefox_source_card(state)
		if source.is_empty():
			return {}
		var choice: Dictionary = source["choices"]["left"]
		# Settlement projection of an inline QUEST, never a catalog encounter.
		# Static source access also works after quest completion and reward handoff.
		var inline_encounter := {"id": source["id"], "inlineQuest": true,
			"title": source["title"], "realm": source["realm"], "questId": source["questId"],
			"enemy": choice["enemy"].duplicate(true), "sceneImage": source["sceneImage"],
			"combatPresentation": choice["combatPresentation"].duplicate(true),
			"battlefield": choice["enemy"].get("battlefield"),
			"defeatHealthLoss": int(choice.get("defeatHealthLoss", choice["enemy"].get("tier", 1)))}
		for key in ["victoryEffects", "defeatEffects", "fleeEffects", "combatOutcomePresentation"]:
			if choice.has(key):
				inline_encounter[key] = choice[key].duplicate(true)
		return inline_encounter
	if source_card_id.begins_with(ENCOUNTER_PREFIX) and state.get("encounterCadence") is Dictionary:
		var source := _cadence_source_card(state, source_card_id)
		if source.is_empty() or source.get("encounterId") != encounter_id:
			return {}
		return CatalogEncounter.new(_content).encounter(state, String(encounter_id))
	var encounter := {}
	for row in _document("combat:encounters").get("encounters", []):
		if row is Dictionary and row.get("id") == encounter_id:
			encounter = row.duplicate(true)
			break
	if encounter.is_empty() or encounter.get("teachingEncounter") == true:
		return encounter
	var source := _mountain_source_card(state)
	if source.is_empty() or source["choices"]["left"].get("combatEncounterId") != encounter_id:
		return {}
	var enemy := _balanced_mountain_enemy(encounter, String(state.get("path", "")))
	if enemy.is_empty():
		return {}
	encounter["enemy"] = enemy
	var presentation: Dictionary = encounter.get("combatPresentation", {})
	presentation.merge(_document("combat:encounter_presentations").get("presentations", {}).get(
		encounter_id, {}), true)
	encounter["combatPresentation"] = presentation
	if source["choices"]["left"].has("combatOutcomePresentation"):
		encounter["combatOutcomePresentation"] = source["choices"]["left"]["combatOutcomePresentation"].duplicate(true)
	return encounter


func _mountain_resolution(state: Dictionary, offer: Dictionary) -> Dictionary:
	var source := _mountain_source_card(state)
	var encounter := resolved_encounter(state, String(offer.get("encounterId", "")))
	if source.is_empty() or encounter.is_empty():
		return {}
	var canonical := _authored_choice(offer)
	canonical["enemy"] = encounter["enemy"].duplicate(true)
	canonical["combatPresentation"] = encounter["combatPresentation"].duplicate(true)
	canonical["battlefield"] = encounter["combatPresentation"].get("battlefield", encounter.get("battlefield"))
	var choice: Dictionary = source["choices"]["left"].duplicate(true)
	choice.merge(canonical, true)
	# Direct-choice normalization lets the authored route own these overrides.
	for key in ["entryEffects", "combatOutcomePresentation"]:
		if source["choices"]["left"].has(key):
			choice[key] = source["choices"]["left"][key].duplicate(true)
	var combat: Dictionary = source.duplicate(true)
	combat.merge({"encounterId": choice["encounterId"], "encounterKind": choice["encounterKind"],
		"enemy": choice["enemy"].duplicate(true), "battlefield": choice["battlefield"],
		"combatPresentation": choice["combatPresentation"].duplicate(true),
		"defeatHealthLoss": choice["defeatHealthLoss"], "combatRules": {}}, true)
	return {"sourceCardId": source["id"], "direction": "left", "sourceCard": source,
		"choice": choice, "combatCard": combat}


func _balanced_mountain_enemy(encounter: Dictionary, path_id: String) -> Dictionary:
	return CatalogEncounter.new(_content).balanced_enemy(encounter, path_id)


func _same(left: Variant, right: Variant) -> bool:
	return JSON.parse_string(JSON.stringify(left)) == JSON.parse_string(JSON.stringify(right))


func _source_content_hash() -> String:
	var fingerprint := ""
	for path in CONTENT_FILES:
		var module_id := String(path).trim_prefix("data/").trim_suffix(".json").replace("/", ":")
		var digest := String(_content.source_sha256(module_id)) if _content != null else ""
		if digest.length() != 64:
			var source_path := String(_content.module_path(module_id)) if _content != null else ""
			source_error = "SOURCE_UNAVAILABLE" if source_path.is_empty() \
				or not FileAccess.file_exists(ContentRepository.CONTENT_ROOT + source_path) else "SOURCE_MISMATCH"
			return ""
		fingerprint += path + ":" + digest + "\n"
	return fingerprint.sha256_text()
