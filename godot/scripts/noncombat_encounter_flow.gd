extends RefCounted
const LegacyFragmentFlow = preload("res://scripts/noncombat_legacy_fragment_flow.gd")
const PathSkillFlow = preload("res://scripts/noncombat_path_skill_flow.gd")
const FirstSessionRoute = preload("res://scripts/noncombat_first_session_route.gd")
const EncounterDirector = preload("res://scripts/noncombat_encounter_director.gd")
const RealmGateFlow = preload("res://scripts/noncombat_realm_gate_flow.gd")
const TreasureAcquisition = preload("res://scripts/noncombat_treasure_acquisition.gd")
const StoryThreads = preload("res://scripts/noncombat_story_threads_v2_flow.gd")
const FACTION_GATE_SOURCE_ID := "faction_wumeng_gatekeeper_call"
const COMPANION_OLD_MASTER_SOURCE_ID := "comp_jian_linger_jle_8_sword_tomb_old_master"

# Pure candidate-state builder for teaching, catalog, mountain and inline quest combat.
# The opening domain owns persistence and events; the battle stage only consumes
# a verified request after warning confirmation.

var _content: RefCounted
var _gateway: RefCounted


func _init(content: RefCounted, gateway: RefCounted) -> void:
	_content = content
	_gateway = gateway


func accept(state: Dictionary) -> Dictionary:
	var offer: Dictionary = _gateway.offer_from_state(state)
	var resolution: Dictionary = _gateway.source_resolution_for_offer(state)
	var source_hash := String(_gateway.source_content_hash())
	if offer.is_empty() or resolution.is_empty() or source_hash.length() != 64:
		return {}
	var source_id := String(offer["sourceCardId"])
	var base_index := int(state.get("runClock", {}).get("decisionIndex", -1))
	var life_id := String(state.get("runClock", {}).get("lifeId", ""))
	if base_index <= 0 or life_id.is_empty():
		return {}
	var owner := "enc:%s:%d:%s:1" % [life_id, base_index, source_id]
	var candidate: Dictionary = state.duplicate(true)
	if state.get("pendingCadenceCard") is Dictionary:
		var accepted := EncounterDirector.new(_content).accepted(state, resolution["sourceCard"])
		if accepted.is_empty():
			return {}
		candidate["noncombatFlow"]["encounterDirectorState"] = accepted
	candidate["phase"] = "WARNING_PENDING"
	candidate["pendingWarning"] = {
		"sourceCardId": source_id, "encounterId": offer["encounterId"],
		"encounterInstanceId": owner, "baseDecisionIndex": base_index,
		"sourceContentHash": source_hash,
		"pendingResolution": resolution.duplicate(true),
	}
	candidate["decisionCheckpoint"] = {"version": 1,
		"cardId": "_warning_" + source_id, "sourceCardId": source_id,
		"decisionIndex": base_index}
	candidate["encounterActionHistory"] = [offer["originDirection"]]
	return candidate


func warning_card(state: Dictionary) -> Dictionary:
	if state.get("phase") != "WARNING_PENDING":
		return {}
	var warning: Dictionary = _as_dictionary(state.get("pendingWarning"))
	var offer: Dictionary = _gateway.source_offer(state)
	if warning.is_empty() or offer.is_empty() \
			or warning.get("sourceCardId") != offer.get("sourceCardId") \
			or warning.get("encounterId") != offer.get("encounterId") \
			or warning.get("sourceContentHash") != _gateway.source_content_hash():
		return {}
	if state.get("pendingRealmGateCard") is Dictionary:
		if JSON.parse_string(JSON.stringify(warning.get("pendingResolution"))) != \
				JSON.parse_string(JSON.stringify(_gateway.source_resolution_for_offer(state))):
			return {}
		return RealmGateFlow.new(_content).warning_card(state)
	if offer.get("sourceCardId") in [FirstSessionRoute.ROUTE_ID, "q_whiteFox_3", "q_sword_3", "q_fellow", "f_mission", "ds_female_bandit", "realm_guardian", "n_hunt", "ar_boss", "it_combat", "thread_ab_village_3", "thread_sword_tomb_2", "thread_last_lesson_n3", FACTION_GATE_SOURCE_ID, COMPANION_OLD_MASTER_SOURCE_ID] \
			or state.get("pendingCadenceCard") is Dictionary:
		var base_index := int(state.get("runClock", {}).get("decisionIndex", -1))
		var owner := "enc:%s:%d:%s:1" % [state.get("runClock", {}).get("lifeId", ""),
			base_index, offer["sourceCardId"]]
		if warning.get("encounterInstanceId") != owner \
				or warning.get("baseDecisionIndex") != base_index \
				or JSON.parse_string(JSON.stringify(warning.get("pendingResolution"))) != \
					JSON.parse_string(JSON.stringify(_gateway.source_resolution_for_offer(state))):
			return {}
	var enemy_name := String(offer.get("enemyName", ""))
	var description := "前方出现了强大的气息。%s挡住了你的去路，似乎已准备好战斗。" % enemy_name
	var presentation: Dictionary = _as_dictionary(_content.read_module(
		"combat:encounter_presentations")).get("presentations", {}).get(
			offer["encounterId"], {})
	if offer.get("sourceCardId") in ["q_whiteFox_3", "q_sword_3", "q_fellow", "f_mission", "ds_female_bandit", "realm_guardian", "n_hunt", "ar_boss", "it_combat", "thread_ab_village_3", "thread_sword_tomb_2", "thread_last_lesson_n3", FACTION_GATE_SOURCE_ID, COMPANION_OLD_MASTER_SOURCE_ID] or state.get("pendingCadenceCard") is Dictionary:
		var combat: Dictionary = warning["pendingResolution"]["combatCard"]
		presentation = combat["combatPresentation"]
		match combat.get("battlefield"):
			"cave":
				description = "洞壁上的青苔被踩碎的声音从前方传来。你闻到了血腥气——%s正在前方等候。" % enemy_name
			"sect":
				description = "一道剑气划破空气，对方已发现你的气息。%s挡在了去路上。" % enemy_name
			"wilderness":
				description = "荒野中突然安静下来。你感到一股强烈的杀意从四面涌来——是%s。" % enemy_name
	var mechanic := String(presentation.get("mechanic", ""))
	if not mechanic.is_empty():
		description += "\n\n【战局情报】" + mechanic
	var injury := int(warning.get("pendingResolution", {}).get("choice", {}).get(
		"defeatHealthLoss", warning.get("pendingResolution", {}).get(
			"combatCard", {}).get("enemy", {}).get("tier", 1)))
	description += "\n\n【结算规则】战斗中的护体值是独立局内资源；胜利不会把局内受击写回真实气血。战败伤势上限 %d 点；实际损失按结算时气血计算，备战疗伤可改变实际损失。" % injury
	var warning_choices := {
		"left": {"text": "直接迎战", "desc": "正面应对。"},
		"right": {"text": "调整气息", "desc": "消耗 10 灵石，恢复 1 点气血。"},
	}
	if offer.get("sourceCardId") in ["q_sword_3", "q_fellow", "f_mission", "ds_female_bandit", "realm_guardian", "n_hunt", "ar_boss", "it_combat", "thread_ab_village_3", "thread_sword_tomb_2", "thread_last_lesson_n3", FACTION_GATE_SOURCE_ID, COMPANION_OLD_MASTER_SOURCE_ID]:
		warning_choices["left"]["_confirmCombat"] = true
		warning_choices["left"]["effects"] = {}
		warning_choices["right"]["_confirmCombat"] = true
		warning_choices["right"]["costCheck"] = {"spiritStone": 10}
		warning_choices["right"]["effects"] = {"health": 1}
	return {"id": "_warning_" + String(offer["sourceCardId"]),
		"type": "COMBAT_WARNING", "title": offer["warningTitle"],
		"description": description, "sceneImage": offer["sceneImage"],
		"choices": warning_choices}


func confirm(state: Dictionary, direction: String) -> Dictionary:
	var source_warning: Dictionary = warning_card(state)
	if source_warning.is_empty() or not source_warning.get("choices", {}).has(direction):
		return {}
	if source_warning.choices[direction].get("_confirmCombat") != true \
			and state.get("pendingRealmGateCard", {}).get("id") == RealmGateFlow.TRIBULATION_CARD_ID:
		return {}
	var warning: Dictionary = state["pendingWarning"]
	var offer: Dictionary = _gateway.source_offer(state)
	var source_hash := String(_gateway.source_content_hash())
	var source_id := String(offer["sourceCardId"])
	var current_loadout := source_id in [FirstSessionRoute.ROUTE_ID, "q_whiteFox_3", "q_sword_3", "q_fellow", "f_mission", "ds_female_bandit", "realm_guardian", "n_hunt", "ar_boss", "it_combat", "thread_ab_village_3", "thread_sword_tomb_2", "thread_last_lesson_n3", FACTION_GATE_SOURCE_ID, COMPANION_OLD_MASTER_SOURCE_ID] \
		or state.get("pendingCadenceCard") is Dictionary \
		or state.get("pendingRealmGateCard") is Dictionary
	var base_index := int(state.get("runClock", {}).get("decisionIndex", -1))
	var owner := String(warning.get("encounterInstanceId", ""))
	var expected_owner := "enc:%s:%d:%s:1" % [
		state.get("runClock", {}).get("lifeId", ""), base_index, source_id]
	if base_index <= 0 or warning.get("baseDecisionIndex") != base_index \
			or owner != expected_owner or warning.get("sourceContentHash") != source_hash:
		return {}
	var deck_doc: Dictionary = _as_dictionary(_content.read_module("combat:deck_progression"))
	var path_doc: Dictionary = _as_dictionary(_content.read_module("config:paths"))
	var path_id := String(offer["path"])
	var starter: Array = deck_doc.get("paths", {}).get(path_id, {}).get("starterDeck", [])
	var path: Dictionary = path_doc.get("paths", {}).get(path_id, {})
	if starter.is_empty() or path.is_empty():
		return {}
	var before_stones := int(state.get("resources", {}).get("spiritStone", -1))
	var before_health := int(state.get("attributes", {}).get("health", -1))
	var path_skill = PathSkillFlow.new(_content)
	var max_health := path_skill.actual_max_health(state)
	if not path_skill.last_error.is_empty():
		return {}
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
	var before_pill := int(state.get("resources", {}).get("pills", {}).get(pill_key, 0)) \
		if realm_gate else 0
	var using_pill: bool = realm_gate and not deity_gate and not tribulation_gate \
		and before_pill > 0 and direction == "left"
	var using_array: bool = golden_gate and direction == (
		"right" if before_pill > 0 else "left")
	var equipped_before: Array = RealmGateFlow.new(_content)._equipped_treasure_ids(state) \
		if deity_gate else []
	var using_relic: bool = deity_gate and not equipped_before.is_empty() and direction == "left"
	var cost := 0
	if nascent_gate:
		cost = 15 if direction == "right" and before_pill == 0 else 0
	elif deity_gate:
		cost = 20 if equipped_before.is_empty() and direction == "right" else 0
	elif tribulation_gate:
		cost = 0
	elif golden_gate:
		cost = 25 if using_array else 0
	elif foundation_gate:
		cost = 5 if direction == "up" or direction == "right" and before_pill == 0 else 0
	else:
		cost = 10 if direction == "right" and not (
			realm_gate and before_pill > 0) else 0
	if before_stones < cost or before_health < 0 or max_health <= 0 \
			or before_health > max_health:
		return {}
	var candidate: Dictionary = state.duplicate(true)
	var after_stones := before_stones - cost
	var after_health := before_health if foundation_gate or golden_gate else mini(max_health,
		before_health + (1 if cost > 0 else 0))
	candidate["resources"]["spiritStone"] = after_stones
	candidate["attributes"]["health"] = after_health
	if source_id == "thread_last_lesson_n3":
		var entry: Dictionary = warning.get("pendingResolution", {}).get(
			"choice", {}).get("entryEffects", {})
		if entry.is_empty():
			return {}
		var story := StoryThreads.new(_content)
		for key in entry:
			if not story._apply_effect(candidate, String(key), entry[key]):
				return {}
	if source_id == FACTION_GATE_SOURCE_ID:
		var faction_entry: Dictionary = warning.get("pendingResolution", {}).get(
			"choice", {}).get("entryEffects", {})
		if faction_entry != {"playerLocation": "武盟雷峰"}:
			return {}
		candidate["currentLocation"] = "武盟雷峰"
		candidate["visitedLocations"] = candidate.get("visitedLocations", []).duplicate(true)
		if not candidate.visitedLocations.has("武盟雷峰"):
			candidate.visitedLocations.append("武盟雷峰")
	if using_pill:
		var pills: Dictionary = candidate["resources"]["pills"]
		if before_pill == 1:
			pills.erase(pill_key)
		else:
			pills[pill_key] = before_pill - 1
		var flags: Dictionary = candidate.get("flags", {})
		var flag := "used_deity_pill" if nascent_gate else (
			"used_nascent_pill" if golden_gate else (
			"used_golden_pill" if foundation_gate else "used_foundation_pill"))
		flags[flag] = true
		candidate["flags"] = flags
	if using_array:
		var flags: Dictionary = candidate.get("flags", {})
		flags["used_lightning_array"] = true
		candidate["flags"] = flags
	var consumed_treasure_id := ""
	if using_relic:
		var selected_index := (owner.hash() & 0x7fffffff) % equipped_before.size()
		consumed_treasure_id = String(equipped_before[selected_index])
		for slot in ["weapon", "armor", "accessory", "artifact"]:
			if candidate.get("equipment", {}).get(slot) == consumed_treasure_id:
				candidate["equipment"][slot] = null
		candidate["treasureInstances"].erase(consumed_treasure_id)
		candidate.get("treasureCooldowns", {}).erase(consumed_treasure_id)
		TreasureAcquisition.new(_content)._refresh_derived(candidate)
		var flags: Dictionary = candidate.get("flags", {})
		flags["used_relic_shield"] = true
		candidate["flags"] = flags
	var warning_token := "warning:%s:%s" % [owner, direction]
	var preparation: Dictionary = _as_dictionary(candidate["runClock"].get(
		"preparationReceipts"))
	if preparation.has(warning_token):
		return {}
	preparation[warning_token] = {
		"sourceCardId": source_id, "direction": direction,
		"baseDecisionIndex": base_index, "applied": true,
		"beforeSpiritStone": before_stones, "afterSpiritStone": after_stones,
		"beforeHealth": before_health, "afterHealth": after_health,
	}
	if realm_gate and not deity_gate and not tribulation_gate:
		var prefix := "Deity" if nascent_gate else (
			"Nascent" if golden_gate else ("Golden" if foundation_gate else "Foundation"))
		preparation[warning_token]["before%sPill" % prefix] = before_pill
		preparation[warning_token]["after%sPill" % prefix] = before_pill - (1 if using_pill else 0)
		preparation[warning_token]["used%sPill" % prefix] = using_pill
	if deity_gate:
		preparation[warning_token]["equippedTreasureIdsBefore"] = equipped_before.duplicate(true)
		preparation[warning_token]["consumedTreasureInstanceId"] = consumed_treasure_id
		preparation[warning_token]["usedRelicShield"] = using_relic
	candidate["runClock"]["preparationReceipts"] = preparation
	if current_loadout:
		if not candidate.get("deck") is Array or candidate["deck"].is_empty() \
				or candidate.get("starterDeckPath") != path_id:
			return {}
		var loadout := {"deck": candidate["deck"].duplicate(true),
			"pathOpening": {"combatOpeningBlock": int(path.get("bonuses", {}).get(
				"combatOpeningBlock", 0))}}
		for key in ["equipment", "skills", "lineage", "modifiers"]:
			var current: Variant = candidate.get(key, {})
			if not current is Dictionary:
				return {}
			loadout[key] = current.duplicate(true)
		for key in ["treasures", "companions"]:
			var current: Variant = candidate["resources"].get(key, [])
			if not current is Array:
				return {}
			loadout[key] = current.duplicate(true)
		candidate["battleLoadout"] = loadout
	else:
		candidate["deck"] = starter.duplicate(true)
		candidate["starterDeckPath"] = path_id
		candidate["battleLoadout"] = {"deck": starter.duplicate(true),
			"equipment": {}, "treasures": [], "skills": {}, "companions": [],
			"lineage": {}, "modifiers": {},
			"pathOpening": {"combatOpeningBlock": int(path.get("bonuses", {}).get(
				"combatOpeningBlock", 0))}}
	candidate["decisionCheckpoint"] = {"version": 1, "cardId": source_id,
		"sourceCardId": source_id, "decisionIndex": base_index,
		"warningChoiceDirection": direction}
	candidate["pendingBattle"] = {
		"sourceCardId": source_id, "direction": offer["originDirection"],
		"encounterId": offer["encounterId"], "encounterInstanceId": owner,
		"baseDecisionIndex": base_index, "nextDecisionIndex": base_index + 1,
		"warningChoiceDirection": direction, "warningCheckpointToken": warning_token,
		"pendingResolution": warning["pendingResolution"].duplicate(true),
		"returnPolicy": "source_flow", "warningConfirmed": true,
		"sourceContentHash": source_hash,
	}
	if source_id in ["q_whiteFox_3", "q_sword_3"]:
		candidate["pendingBattle"]["questId"] = offer["questId"]
	if source_id in ["thread_ab_village_3", "thread_sword_tomb_2",
			"thread_last_lesson_n3"]:
		candidate["pendingBattle"]["threadId"] = offer["threadId"]
	if source_id in ["realm_guardian", "ar_boss", "it_combat"]:
		candidate["pendingBattle"]["dungeonSessionId"] = state.get("dungeonRun", {}).get("sessionId")
	if current_loadout:
		candidate["pendingBattle"]["playerSnapshot"] = _gateway.player_snapshot(candidate)
	candidate.erase("pendingWarning")
	candidate["phase"] = "BATTLE_PENDING"
	candidate["encounterActionHistory"] = [direction] if state.get(
		"pendingRealmGateCard") is Dictionary else [offer["originDirection"], direction]
	return candidate if not _gateway.build_request(candidate).is_empty() else {}


func _as_dictionary(value: Variant) -> Dictionary:
	return value if value is Dictionary else {}
