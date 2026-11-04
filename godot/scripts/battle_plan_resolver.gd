extends RefCounted

# Read-only first-session BattleRequest -> production plan boundary. The story
# gateway authenticates ownership and source hash against persisted state; this
# consumer checks that the frozen loadout still names real combat content.
const CONTRACT_VERSION := 2
const SLOTS := ["weapon", "armor", "accessory", "artifact"]
const StageRouter = preload("res://scripts/combat_stage_router.gd")
const BattlefieldArtRegistry = preload("res://scripts/battlefield_art_registry.gd")
const SourceTrialStage = preload("res://scripts/duel_stage_source_2d.gd")
const WhitefoxStage = preload("res://scripts/duel_stage_whitefox_2d.gd")
const FellowStage = preload("res://scripts/duel_stage_fellow_2d.gd")
const VillageStage = preload("res://scripts/duel_stage_village_2d.gd")
const SwordTombStage = preload("res://scripts/duel_stage_sword_tomb_2d.gd")
const LastLessonStage = preload("res://scripts/duel_stage_last_lesson_2d.gd")
const BattleGateway = preload("res://scripts/noncombat_battle_gateway.gd")

var last_error := ""
var _registry: RefCounted


func _init(registry: RefCounted) -> void:
	_registry = registry


func resolve_persisted(state: Dictionary) -> Dictionary:
	# Only this entrypoint can return a plan eligible for a future combat launch.
	# The gateway rechecks the persisted owner, warning receipt, source hash and
	# unsettled source choice before this read-only plan is assembled.
	var request: Dictionary = BattleGateway.new(_registry).build_request(state)
	if request.is_empty():
		return _reject("持久待战状态未通过来源合同校验")
	var plan := inspect_request(request)
	if not plan.is_empty():
		plan["sourceAuthenticated"] = true
		# Ownership and content identity are separate from asset readiness.
		# Do not start a branch whose 3D stage or equipped visual is absent.
		plan["launchAuthorized"] = plan["sceneAvailable"] and _visuals_ready(plan["equipment"])
	return plan


func inspect_request(request: Dictionary) -> Dictionary:
	# Diagnostics/production preflight only. A dictionary alone does not prove
	# ownership or freshness; never start combat from this method's result.
	last_error = ""
	if request.get("contractVersion") != CONTRACT_VERSION \
			or request.get("returnPolicy") != "source_flow" \
			or not request.get("playerSnapshot") is Dictionary \
			or String(request.get("encounterInstanceId", "")).is_empty() \
			or String(request.get("sourceCardId", "")).is_empty():
		return _reject("待战请求合同或来源身份无效")
	var raw_encounter_id: Variant = request.get("encounterId")
	var encounter_id := String(raw_encounter_id) if raw_encounter_id is String else ""
	var mountain: bool = encounter_id == "enc_patrol_qi_mountain_shadow" \
		and request.get("sourceCardId") == "q_mountain_shadow_approach"
	var teaching: bool = request.get("sourceCardId") == "encounter_card_" + encounter_id \
		and request.get("realm") == "qi"
	var cadence_catalog: bool = request.get("sourceCardId") == "encounter_card_" + encounter_id \
		and request.get("realm") in ["foundation", "golden", "nascent", "deity", "tribulation"]
	var faction: bool = encounter_id == "enc_faction_wumeng_elite" \
		and request.get("sourceCardId") == "faction_wumeng_gatekeeper_call" \
		and request.get("realm") == "foundation"
	var companion: bool = encounter_id == "enc_companion_jian_linger_tomb" \
		and request.get("sourceCardId") == "comp_jian_linger_jle_8_sword_tomb_old_master" \
		and request.get("realm") == "golden"
	var whitefox: bool = raw_encounter_id == null \
		and request.get("sourceCardId") == "q_whiteFox_3" \
		and request.get("questId") == "white_fox_line"
	var fellow: bool = raw_encounter_id == null \
		and request.get("sourceCardId") == "q_fellow"
	var mission: bool = raw_encounter_id == null \
		and request.get("sourceCardId") == "f_mission"
	var bandit: bool = raw_encounter_id == null \
		and request.get("sourceCardId") == "ds_female_bandit"
	var nascent: bool = raw_encounter_id == null \
		and request.get("sourceCardId") in ["n_hunt", "ar_boss"] \
		and request.get("realm") == "nascent"
	var trial: bool = raw_encounter_id == null \
		and request.get("sourceCardId") == "it_combat" \
		and request.get("realm") == "tribulation"
	var qi_gate: bool = request.get("sourceCardId") == "ch_qi_100" \
		and raw_encounter_id == "ch_qi_100" \
		and request.get("realm") == "qi"
	var foundation_gate: bool = request.get("sourceCardId") == "ch_foundation_100" \
		and raw_encounter_id == "ch_foundation_100" \
		and request.get("realm") == "foundation"
	var golden_gate: bool = request.get("sourceCardId") == "ch_golden_100" \
		and raw_encounter_id == "ch_golden_100" \
		and request.get("realm") == "golden"
	var nascent_gate: bool = request.get("sourceCardId") == "ch_nascent_100" \
		and raw_encounter_id == "ch_nascent_100" \
		and request.get("realm") == "nascent"
	var deity_gate: bool = request.get("sourceCardId") == "ch_deity_100" \
		and raw_encounter_id == "ch_deity_100" \
		and request.get("realm") == "deity"
	var tribulation_gate: bool = request.get("sourceCardId") == "ch_tribulation_100" \
		and raw_encounter_id == "ch_tribulation_100" \
		and request.get("realm") == "tribulation"
	var dungeon_boss: bool = raw_encounter_id == null \
		and request.get("sourceCardId") == "realm_guardian"
	var village: bool = raw_encounter_id == null \
		and request.get("sourceCardId") == "thread_ab_village_3" \
		and request.get("threadId") == "abandoned_village"
	var sword_tomb: bool = raw_encounter_id == null \
		and request.get("sourceCardId") == "thread_sword_tomb_2" \
		and request.get("threadId") == "sword_tomb_trial"
	var last_lesson: bool = raw_encounter_id == null \
		and request.get("sourceCardId") == "thread_last_lesson_n3" \
		and request.get("threadId") == "bairen_last_lesson" \
		and request.get("realm") in ["deity", "tribulation"]
	var sword_quest: bool = raw_encounter_id == null \
		and request.get("sourceCardId") == "q_sword_3" \
		and request.get("questId") == "sword_legacy"
	var resolution: Dictionary = request.get("pendingResolution", {})
	# The teaching request retains the prologue's left/right origin direction.
	# The mountain source is an authored left choice with a frozen balanced foe.
	if not teaching and not cadence_catalog and not faction and not companion and not mountain and not whitefox and not fellow and not mission and not bandit and not nascent and not trial and not qi_gate and not foundation_gate and not golden_gate and not nascent_gate and not deity_gate and not tribulation_gate and not dungeon_boss \
			and not village and not sword_tomb and not last_lesson and not sword_quest \
			or (teaching or cadence_catalog) and request.get("direction") not in ["left", "right"] \
			or (mountain or faction or companion or whitefox or bandit or nascent or trial or qi_gate or foundation_gate or golden_gate or nascent_gate or deity_gate or tribulation_gate) and request.get("direction") != "left" \
			or (fellow or mission) and request.get("direction") != "right" \
			or dungeon_boss and request.get("direction") not in ["left", "right"] \
			or (village or sword_tomb or sword_quest) and request.get("direction") not in ["left", "right"] \
			or last_lesson and request.get("direction") != "left" \
			or not resolution.is_empty() and resolution.get("direction") != (
				request.get("direction") if village or fellow or mission or bandit or nascent or trial or dungeon_boss or sword_tomb or last_lesson or sword_quest else "left"):
		return _reject("待战剧情卡来源不一致")
	var source: Dictionary = {}
	if not whitefox and not fellow and not mission and not bandit and not nascent and not trial and not qi_gate and not foundation_gate and not golden_gate and not nascent_gate and not deity_gate and not tribulation_gate and not dungeon_boss and not village and not sword_tomb and not last_lesson and not sword_quest:
		for row in _registry.read_json("data/combat/encounters.json").get("encounters", []):
			if row is Dictionary and row.get("id") == encounter_id:
				source = row
				break
		if source.is_empty() or teaching and source.get("path") != request.get("path") \
				or source.get("realm") != request.get("realm"):
			return _reject("遭遇与待战专修/境界不一致")
	var enemy: Dictionary = source.get("enemy", {})
	if faction:
		var combat_card: Dictionary = resolution.get("combatCard", {})
		var source_card: Dictionary = resolution.get("sourceCard", {})
		var choice: Dictionary = resolution.get("choice", {})
		enemy = combat_card.get("enemy", {})
		if resolution.get("sourceCardId") != request.get("sourceCardId") \
				or source_card.get("id") != request.get("sourceCardId") \
				or source_card.get("type") != "FACTION_EVENT" \
				or source_card.get("factionId") != "wumeng_alliance" \
				or choice.get("triggerCombat") != true \
				or choice.get("combatEncounterId") != encounter_id \
				or combat_card.get("encounterId") != encounter_id \
				or enemy.is_empty() or enemy != source.get("enemy") \
				or combat_card.get("combatPresentation") != _registry.read_json(
					"data/combat/encounter_presentations.json").get(
						"presentations", {}).get(encounter_id, {}) \
				or not enemy.get("planGraph") is Dictionary:
			return _reject("武盟请关战斗来源快照不一致")
	elif companion:
		var combat_card: Dictionary = resolution.get("combatCard", {})
		var source_card: Dictionary = resolution.get("sourceCard", {})
		var choice: Dictionary = resolution.get("choice", {})
		enemy = combat_card.get("enemy", {})
		if resolution.get("sourceCardId") != request.get("sourceCardId") \
				or source_card.get("id") != request.get("sourceCardId") \
				or source_card.get("type") != "COMPANION_EVENT" \
				or source_card.get("compId") != "jian_linger" \
				or choice.get("triggerCombat") != true \
				or choice.get("encounterId") != encounter_id \
				or combat_card.get("encounterId") != encounter_id \
				or enemy != source.get("enemy") \
				or combat_card.get("combatPresentation") != source.get("combatPresentation") \
				or not enemy.get("planGraph") is Dictionary:
			return _reject("剑灵儿旧主战斗来源快照不一致")
	elif cadence_catalog:
		var combat_card: Dictionary = resolution.get("combatCard", {})
		enemy = combat_card.get("enemy", {})
		if resolution.get("sourceCardId") != request.get("sourceCardId") \
				or resolution.get("sourceCard", {}).get("id") != request.get("sourceCardId") \
				or resolution.get("choice", {}).get("triggerCombat") != true \
				or resolution.get("choice", {}).get("enemy") != enemy \
				or combat_card.get("encounterId") != encounter_id:
			return _reject("定期遭遇来源快照不一致")
	elif whitefox:
		var combat_card: Dictionary = resolution.get("combatCard", {})
		var choice: Dictionary = resolution.get("choice", {})
		enemy = combat_card.get("enemy", {})
		if resolution.get("sourceCardId") != request.get("sourceCardId") \
				or resolution.get("sourceCard", {}).get("id") != request.get("sourceCardId") \
				or resolution.get("sourceCard", {}).get("questId") != request.get("questId") \
				or choice.get("triggerCombat") != true \
				or combat_card.get("encounterId") != null \
				or enemy.is_empty() or enemy != choice.get("enemy") \
				or enemy.get("id") != "hound_pack_qi" \
				or int(enemy.get("hp", 0)) <= 0 \
				or combat_card.get("combatPresentation") != choice.get("combatPresentation"):
			return _reject("白狐任务内嵌战斗快照不一致")
	elif fellow or mission:
		var combat_card: Dictionary = resolution.get("combatCard", {})
		var choice: Dictionary = resolution.get("choice", {})
		enemy = combat_card.get("enemy", {})
		var expected_id := "q_fellow" if fellow else "f_mission"
		var expected_template := "sect_sparring_qi" if fellow else "blazing_tiger_foundation"
		if resolution.get("sourceCardId") != expected_id \
				or resolution.get("sourceCard", {}).get("id") != expected_id \
				or choice.get("triggerCombat") != true \
				or combat_card.get("encounterId") != null \
				or enemy.is_empty() \
				or enemy != resolution.get("sourceCard", {}).get("enemy") \
				or enemy.get("templateId") != expected_template \
				or int(enemy.get("hp", 0)) <= 0:
			return _reject("普通卡内嵌战斗快照不一致")
	elif bandit:
		var combat_card: Dictionary = resolution.get("combatCard", {})
		var choice: Dictionary = resolution.get("choice", {})
		enemy = combat_card.get("enemy", {})
		if resolution.get("sourceCardId") != "ds_female_bandit" \
				or resolution.get("sourceCard", {}).get("id") != "ds_female_bandit" \
				or choice.get("triggerCombat") != true \
				or combat_card.get("encounterId") != null \
				or enemy != choice.get("enemy") \
				or enemy.get("id") != "tiger_queen_golden" \
				or not enemy.get("intents") is Array \
				or enemy.intents.size() != 3:
			return _reject("虎娘战斗来源快照不一致")
	elif nascent:
		var combat_card: Dictionary = resolution.get("combatCard", {})
		var source_card: Dictionary = resolution.get("sourceCard", {})
		var choice: Dictionary = resolution.get("choice", {})
		enemy = combat_card.get("enemy", {})
		var expected_template := "nascent_soul_hunter" if request.get(
			"sourceCardId") == "n_hunt" else "tomb_guardian_nascent"
		if resolution.get("sourceCardId") != request.get("sourceCardId") \
				or source_card.get("id") != request.get("sourceCardId") \
				or source_card.get("realm") != "nascent" \
				or choice.get("triggerCombat") != true \
				or combat_card.get("encounterId") != null \
				or enemy != source_card.get("enemy") \
				or enemy.get("templateId") != expected_template \
				or int(enemy.get("hp", 0)) <= 0 \
				or request.get("sourceCardId") == "ar_boss" and (
					source_card.get("_dungeonId") != "ancient_ruins" \
					or source_card.get("_dungeonNodeIndex") != 3):
			return _reject("元婴普通战斗来源快照不一致")
	elif trial:
		var combat_card: Dictionary = resolution.get("combatCard", {})
		var source_card: Dictionary = resolution.get("sourceCard", {})
		var choice: Dictionary = resolution.get("choice", {})
		enemy = combat_card.get("enemy", {})
		if resolution.get("sourceCardId") != "it_combat" \
				or source_card.get("id") != "it_combat" \
				or source_card.get("_dungeonId") != "immortal_trial" \
				or source_card.get("_dungeonNodeIndex") != 1 \
				or choice.get("triggerCombat") != true \
				or combat_card.get("encounterId") != null \
				or enemy != source_card.get("enemy") \
				or enemy.get("templateId") != "immortal_shadow_tribulation":
			return _reject("渡劫仙影来源快照不一致")
	elif qi_gate or foundation_gate or golden_gate or nascent_gate or deity_gate or tribulation_gate:
		var combat_card: Dictionary = resolution.get("combatCard", {})
		var source_card: Dictionary = resolution.get("sourceCard", {})
		enemy = combat_card.get("enemy", {})
		var expected_gate := "ch_qi_100" if qi_gate else "ch_tribulation_100" if tribulation_gate else (
		"ch_deity_100" if deity_gate else (
			"ch_nascent_100" if nascent_gate else (
			"ch_golden_100" if golden_gate else "ch_foundation_100")))
		if source_card.get("id") != expected_gate \
				or resolution.get("sourceCardId") != expected_gate \
				or combat_card != source_card \
				or resolution.get("choice", {}).get("triggerCombat") != true \
				or enemy != source_card.get("enemy") \
				or not enemy.get("planGraph") is Dictionary \
				or qi_gate and (source_card.get("encounterKind") != "realm_boss" \
					or source_card.get("combatRules", {}).get("victoryCondition") != "survive_turns" \
					or int(source_card.get("combatRules", {}).get("surviveTurns", 0)) != 3) \
				or golden_gate and source_card.get("combatRules", {}).get(
					"turnCycle", {}).get("order") != ["yang", "yin"] \
				or nascent_gate and source_card.get("combatRules", {}).get(
					"attackBacklash", {}).get("triggerCardType") != "attack" \
				or deity_gate and source_card.get("combatRules", {}).get(
					"karmaDamage", {}).get("attribute") != "karmaBad" \
				or tribulation_gate and source_card.get("combatRules", {}).get(
					"karmaJudgment", {}).get("timing") != "after_draw":
			return _reject("破境关卡来源快照不一致")
	elif dungeon_boss:
		var combat_card: Dictionary = resolution.get("combatCard", {})
		var source_card: Dictionary = resolution.get("sourceCard", {})
		enemy = combat_card.get("enemy", {})
		if source_card.get("id") != "realm_guardian" \
				or source_card.get("_dungeonNodeId") != "boss" \
				or resolution.get("sourceCardId") != "realm_guardian" \
				or resolution.get("choice", {}).get("triggerCombat") != true \
				or not enemy.get("phases") is Array \
				or enemy.phases.size() != 3 \
				or enemy != source_card.get("enemy") \
				or combat_card.get("encounterId") != null:
			return _reject("秘境守卫三相来源快照不一致")
	elif village:
		var combat_card: Dictionary = resolution.get("combatCard", {})
		var choice: Dictionary = resolution.get("choice", {})
		var source_card: Dictionary = resolution.get("sourceCard", {})
		enemy = combat_card.get("enemy", {})
		if resolution.get("sourceCardId") != "thread_ab_village_3" \
				or source_card.get("id") != "thread_ab_village_3" \
				or source_card.get("_threadId") != "abandoned_village" \
				or source_card.get("_threadNodeIndex") != 2 \
				or choice.get("triggerCombat") != true \
				or combat_card.get("encounterId") != null \
				or enemy.is_empty() or enemy != source_card.get("enemy") \
				or enemy.get("templateId") != "resentment_shadow_qi" \
				or int(enemy.get("hp", 0)) <= 0:
			return _reject("荒村第三幕内嵌战斗快照不一致")
	elif sword_tomb:
		var combat_card: Dictionary = resolution.get("combatCard", {})
		var choice: Dictionary = resolution.get("choice", {})
		var source_card: Dictionary = resolution.get("sourceCard", {})
		enemy = combat_card.get("enemy", {})
		if resolution.get("sourceCardId") != "thread_sword_tomb_2" \
				or source_card.get("id") != "thread_sword_tomb_2" \
				or source_card.get("_threadId") != "sword_tomb_trial" \
				or source_card.get("_threadNodeIndex") != 1 \
				or choice.get("triggerCombat") != true \
				or combat_card.get("encounterId") != null \
				or enemy.is_empty() or enemy != source_card.get("enemy") \
				or enemy.get("templateId") != "sword_intent_avatar_qi" \
				or int(enemy.get("hp", 0)) <= 0:
			return _reject("剑冢问心内嵌战斗快照不一致")
	elif last_lesson:
		var combat_card: Dictionary = resolution.get("combatCard", {})
		var choice: Dictionary = resolution.get("choice", {})
		var source_card: Dictionary = resolution.get("sourceCard", {})
		enemy = combat_card.get("enemy", {})
		if resolution.get("sourceCardId") != "thread_last_lesson_n3" \
				or source_card.get("id") != "thread_last_lesson_n3" \
				or source_card.get("_threadId") != "bairen_last_lesson" \
				or source_card.get("_threadNodeIndex") != 3 \
				or choice.get("triggerCombat") != true \
				or combat_card.get("encounterId") != null \
				or enemy.is_empty() or enemy != choice.get("enemy") \
				or enemy.get("templateId") != "sword_intent_avatar_deity" \
				or not enemy.get("planGraph") is Dictionary \
				or int(enemy.get("hp", 0)) <= 0:
			return _reject("最后一课战斗变体快照不一致")
	elif sword_quest:
		var combat_card: Dictionary = resolution.get("combatCard", {})
		var choice: Dictionary = resolution.get("choice", {})
		var source_card: Dictionary = resolution.get("sourceCard", {})
		enemy = combat_card.get("enemy", {})
		if resolution.get("sourceCardId") != "q_sword_3" \
				or source_card.get("id") != "q_sword_3" \
				or source_card.get("questId") != "sword_legacy" \
				or choice.get("triggerCombat") != true \
				or combat_card.get("encounterId") != null \
				or enemy.is_empty() or enemy != choice.get("enemy") \
				or enemy.get("templateId") != "sword_intent_avatar_qi" \
				or int(enemy.get("hp", 0)) <= 0 \
				or combat_card.get("combatPresentation") != choice.get("combatPresentation"):
			return _reject("剑道遗承试锋快照不一致")
	elif mountain:
		var combat_card: Dictionary = resolution.get("combatCard", {})
		enemy = combat_card.get("enemy", {})
		if resolution.get("sourceCardId") != request.get("sourceCardId") \
				or resolution.get("sourceCard", {}).get("id") != request.get("sourceCardId") \
				or combat_card.get("encounterId") != encounter_id \
				or enemy.is_empty() or enemy != resolution.get("choice", {}).get("enemy") \
				or enemy.get("templateId") != source.get("enemy", {}).get("templateId") \
				or int(enemy.get("hp", 0)) <= 0:
			return _reject("山径来源敌人冻结快照不一致")
	var router = StageRouter.new(_registry)
	var context: Dictionary = router.resolve_choice(
		String(request["sourceCardId"]), String(request["direction"]),
		resolution.get("combatCard", {}), String(request["encounterInstanceId"]),
		resolution, String(request["path"]), String(request["realm"])) if faction or companion or cadence_catalog or whitefox or fellow or mission or bandit or nascent or trial or qi_gate or foundation_gate or golden_gate or nascent_gate or deity_gate or tribulation_gate or dungeon_boss or village or sword_tomb or last_lesson or sword_quest else (
		router.resolve_encounter(encounter_id, String(request["encounterInstanceId"])))
	if context.is_empty() or context.get("presentationId") != request.get("presentationId") \
			or context.get("battlefieldId") != request.get("battlefieldId"):
		return _reject("来源展示与战场身份不一致")
	var stage: Dictionary = BattlefieldArtRegistry.new().resolve(context)
	if stage.is_empty():
		return _reject("战场来源目录不匹配")
	var snapshot: Dictionary = request["playerSnapshot"]
	var raw_loadout: Variant = snapshot.get("battleLoadout")
	if not raw_loadout is Dictionary:
		return _reject("待战牌组结构无效")
	var loadout: Dictionary = raw_loadout
	var raw_deck: Variant = loadout.get("deck")
	if not raw_deck is Array:
		return _reject("待战牌组结构无效")
	var deck: Array = raw_deck
	if deck.is_empty():
		return _reject("待战牌组为空")
	var starter: Array = _registry.read_json(
		"data/combat/deck_progression.json").get("paths", {}).get(
		request.get("path"), {}).get("starterDeck", [])
	if starter.is_empty() or deck != starter:
		if teaching:
			return _reject("首轮教学战卡组与专修来源不一致")
	for card_id in deck:
		if not card_id is String or _registry.get_battle_card(card_id).is_empty():
			return _reject("牌组引用未知战斗卡")
	context["path"] = request["path"]
	context["deck"] = deck.duplicate(true)
	var equipment: Dictionary = _resolve_equipment(snapshot)
	if not last_error.is_empty():
		return {}
	var scene_path := String(stage.get("selectedScene", ""))
	var scene_available := scene_path.begins_with("res://") and ResourceLoader.exists(scene_path)
	if whitefox:
		scene_available = scene_available and WhitefoxStage.source_assets_ready(_registry, context)
	elif companion or cadence_catalog or fellow or mission or bandit or nascent or trial or qi_gate or foundation_gate or golden_gate or nascent_gate or deity_gate or tribulation_gate or dungeon_boss:
		scene_available = scene_available and FellowStage.source_assets_ready(_registry, context)
	elif village:
		scene_available = scene_available and VillageStage.source_assets_ready(_registry, context)
	elif sword_tomb or sword_quest:
		scene_available = scene_available and SwordTombStage.source_assets_ready(_registry, context)
	elif last_lesson:
		scene_available = scene_available and LastLessonStage.source_assets_ready(_registry, context)
	elif encounter_id in ["enc_trial_spell_seal", "enc_trial_body_iron", "enc_trial_pill_poison",
			"enc_patrol_qi_mountain_shadow", "enc_faction_wumeng_elite"]:
		scene_available = scene_available and SourceTrialStage.source_assets_ready(_registry, context)
	return {
		"encounterInstanceId": request["encounterInstanceId"],
		"sourceCardId": request["sourceCardId"],
		"encounterId": raw_encounter_id if whitefox or fellow or mission or bandit or nascent or trial or qi_gate or foundation_gate or golden_gate or nascent_gate or deity_gate or tribulation_gate or dungeon_boss or village or sword_tomb or last_lesson or sword_quest else encounter_id,
		"presentationId": context["presentationId"],
		"battlefieldId": context["battlefieldId"],
		"path": request["path"],
		"realm": request["realm"],
		"enemy": enemy.duplicate(true),
		"mechanic": context.get("pendingResolution", {}).get("combatCard", {}).get(
			"combatPresentation", {}).get("mechanic", "") if faction or companion or cadence_catalog or whitefox or fellow or mission or bandit or nascent or trial or qi_gate or foundation_gate or golden_gate or nascent or deity_gate or tribulation_gate or dungeon_boss or village or sword_tomb or last_lesson or sword_quest else source.get("mechanic", ""),
		"isBoss": resolution.get("sourceCard", {}).get("encounterKind") == "realm_boss" \
			or source.get("category") == "realmBoss" or dungeon_boss,
		"deck": deck.duplicate(true),
		"equipment": equipment,
		"stageScene": scene_path,
		"sceneAvailable": scene_available,
		"finalArtApproved": stage.get("approvedForFinalArt", false) == true,
		"sourceAuthenticated": false,
		"launchAuthorized": false,
		"returnPolicy": "source_flow",
	}


func _resolve_equipment(snapshot: Dictionary) -> Dictionary:
	var slots: Variant = snapshot.get("equipment")
	var instances: Variant = snapshot.get("treasureInstances")
	if not slots is Dictionary or not instances is Dictionary:
		_reject("装备实例账本缺失")
		return {}
	var definitions := {}
	for row in _registry.read_json("data/shops/treasures.json").get("treasures", []):
		if row is Dictionary and row.get("id") is String:
			definitions[row["id"]] = row
	var result := {}
	var used := {}
	for slot in SLOTS:
		var instance_id: Variant = slots.get(slot)
		if instance_id == null or instance_id == "":
			result[slot] = {}
			continue
		if not instance_id is String or used.has(instance_id) \
				or not instances.has(instance_id) or not instances[instance_id] is Dictionary:
			_reject("装备槽引用未知或重复实例")
			return {}
		var instance: Dictionary = instances[instance_id]
		var definition_id := String(instance.get("definitionId", ""))
		if instance.get("instanceId") != instance_id \
				or instance.get("lifecycle") != "owned" \
				or not definitions.has(definition_id) \
				or definitions[definition_id].get("type") != slot:
			_reject("装备实例归属或槽位不符")
			return {}
		used[instance_id] = true
		result[slot] = {"instanceId": instance_id, "definitionId": definition_id,
			"slot": slot, "visualReady": false}
	return result


func _visuals_ready(equipment: Dictionary) -> bool:
	for slot in SLOTS:
		var visual: Dictionary = equipment.get(slot, {})
		if not visual.is_empty() and visual.get("visualReady") != true:
			return false
	return true


func _reject(message: String) -> Dictionary:
	last_error = message
	return {}
