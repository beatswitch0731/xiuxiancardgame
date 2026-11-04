extends RefCounted
const DeckAcquisition = preload("res://scripts/noncombat_deck_acquisition.gd")
const MilestoneFlow = preload("res://scripts/noncombat_milestone_flow.gd")
const PathSkillFlow = preload("res://scripts/noncombat_path_skill_flow.gd")
const DeathFlow = preload("res://scripts/noncombat_death_flow.gd")

# Qi terminal milestone is scheduled only after the authored visible encounter
# quota. The source card stays in chapter_milestones.json; this class owns the
# saved gate checkpoint and its projected warning.
const CARD_ID := "ch_qi_100"
const WARNING_ID := "_warning_ch_qi_100"
const FOUNDATION_CARD_ID := "ch_foundation_100"
const GOLDEN_CARD_ID := "ch_golden_100"
const NASCENT_CARD_ID := "ch_nascent_100"
const DEITY_CARD_ID := "ch_deity_100"
const TRIBULATION_CARD_ID := "ch_tribulation_100"
const MODULE := "cards:chapter_milestones"
const DIRECTOR_MODULE := "combat:encounter_director"
var last_error := ""
var _content: RefCounted
var legacy_qi_spine_victory_replay := false

func _init(content: RefCounted) -> void:
	_content = content

func source_card(state: Dictionary) -> Dictionary:
	var realm := String(state.get("realm", ""))
	var card_id := _gate_id(realm)
	if card_id.is_empty():
		return {}
	var doc: Variant = _content.read_module(MODULE)
	if not doc is Dictionary:
		last_error = "炼气关卡来源不可用"
		return {}
	var raw: Variant = doc.get(card_id)
	if not raw is Dictionary or raw.get("id") != card_id \
			or raw.get("type") != "COMBAT" or raw.get("realm") != realm:
		last_error = "炼气关卡来源卡无效"
		return {}
	var card: Dictionary = raw.duplicate(true)
	var stage: Dictionary = card.get("bossJourney", {}).get("stages", {}).get("100", {})
	if stage.get("combatCardId") != card_id or String(stage.get("cue", "")).is_empty():
		return {}
	card["bossJourneyStage"] = {"journeyId": card.bossJourney.id,
		"bossName": card.bossJourney.get("bossName"),
		"strengthModel": card.bossJourney.get("strengthModel"),
		"scalesWithPlayerRealm": card.bossJourney.get("scalesWithPlayerRealm"),
		"canonicalThreshold": 100, "triggerThreshold": 100}
	card.bossJourneyStage.merge(stage.duplicate(true), true)
	card["description"] = String(card.description) + "\n\n" + String(stage.cue)
	card["_flowSource"] = "milestone"
	card["_flowPhase"] = "BUILDUP"
	card["encounterContext"] = {"encounterInstanceId": "enc:%s:%d:%s:1" % [
		String(state.get("runClock", {}).get("lifeId", "")), int(state.get("turn", 0)), card_id],
		"encounterKind": "realm_boss", "cardId": card_id,
		"realm": realm, "path": state.get("path")}
	return card

func resume(state: Dictionary) -> Dictionary:
	last_error = ""
	var realm := String(state.get("realm", ""))
	var card_id := _gate_id(realm)
	if state.get("phase") != "FLOW_PENDING" or card_id.is_empty() \
			or int(state.get("attributes", {}).get("cultivation", 0)) < 100:
		return {}
	var gate: Dictionary = state.get("noncombatFlow", {}).get("realmGateState", {})
	if gate.get("realm") == realm and gate.get("cardId") == card_id \
			and gate.get("status") in ["in_progress", "resolved"]:
		return {}
	if gate.get("realm") == realm and gate.get("status") == "deferred" \
			and int(gate.get("deferDrawsRemaining", 0)) > 0:
		gate["deferDrawsRemaining"] = int(gate.deferDrawsRemaining) - 1
		if int(gate.deferDrawsRemaining) == 0:
			gate["status"] = "available"
		state["noncombatFlow"]["realmGateState"] = gate
		return {}
	var director: Dictionary = state.get("noncombatFlow", {}).get("encounterDirectorState", {})
	var seen: Dictionary = director.get("realmProgress", {}).get(realm, {}).get("seenCounts", {})
	var config: Variant = _content.read_module(DIRECTOR_MODULE)
	if not config is Dictionary:
		last_error = "炼气遭遇配额来源不可用"
		return {}
	if seen.is_empty():
		return {}
	var minimum: Dictionary = config.get("realmMinimums", {})
	if int(seen.get("ordinary", 0)) < int(minimum.get("ordinary", 2)) \
			or int(seen.get("relationship", 0)) + int(seen.get("quest", 0)) < int(
				minimum.get("relationshipOrQuest", 1)) \
			or int(seen.get("elite", 0)) < int(minimum.get("elite", 1)):
		return {}
	if realm in ["foundation", "golden", "nascent", "deity", "tribulation"]:
		var prior: Array = state.get("chapterProgress", {}).get(
			"triggeredMilestones", {}).get("foundation", [])
		if realm == "golden":
			prior = state.get("chapterProgress", {}).get(
				"triggeredMilestones", {}).get("golden", [])
		elif realm == "nascent":
			prior = state.get("chapterProgress", {}).get(
				"triggeredMilestones", {}).get("nascent", [])
		elif realm == "deity":
			prior = state.get("chapterProgress", {}).get(
				"triggeredMilestones", {}).get("deity", [])
		elif realm == "tribulation":
			prior = state.get("chapterProgress", {}).get(
				"triggeredMilestones", {}).get("tribulation", [])
		for threshold in ([25, 50, 70, 90] if realm == "nascent" else (
			[20, 45, 65, 85] if realm == "golden" else [20, 40, 60, 80])):
			if not prior.has(threshold):
				return {}
	var card := source_card(state)
	if card.is_empty():
		return {}
	var candidate: Dictionary = state.duplicate(true)
	var progress: Dictionary = candidate.get("chapterProgress", {})
	var triggered: Dictionary = progress.get("triggeredMilestones", {})
	var current: Array = triggered.get(realm, [])
	if not current.has(100):
		current.append(100)
	triggered[realm] = current
	progress["triggeredMilestones"] = triggered
	candidate["chapterProgress"] = progress
	candidate["noncombatFlow"]["realmGateSourceSha"] = _content.source_sha256(MODULE)
	if not _prepare_spine_combat(candidate, card):
		return {}
	candidate["noncombatFlow"]["realmGateState"] = {"realm": realm, "cardId": card_id,
		"status": "in_progress", "deferDrawsRemaining": 0}
	candidate["pendingRealmGateCard"] = card
	candidate["currentCardId"] = card_id
	candidate["phase"] = "COMBAT_HANDOFF"
	candidate["decisionCheckpoint"] = {"version": 1, "cardId": card_id,
		"sourceCardId": state.get("decisionCheckpoint", {}).get("sourceCardId"),
		"turn": state.turn, "decisionIndex": state.runClock.decisionIndex,
		"flowSource": "milestone", "chapterThreshold": 100}
	return candidate

func warning_card(state: Dictionary) -> Dictionary:
	if state.get("phase") != "WARNING_PENDING" or not state.get("pendingRealmGateCard") is Dictionary \
			or state.get("noncombatFlow", {}).get("realmGateSourceSha") != _content.source_sha256(MODULE):
		return {}
	var target := source_card(state)
	if target.is_empty() or JSON.parse_string(JSON.stringify(target)) != JSON.parse_string(
			JSON.stringify(state.pendingRealmGateCard)):
		return {}
	if target.get("id") == FOUNDATION_CARD_ID:
		return _foundation_warning_card(state, target)
	if target.get("id") == GOLDEN_CARD_ID:
		return _golden_warning_card(state, target)
	if target.get("id") == NASCENT_CARD_ID:
		return _nascent_warning_card(state, target)
	if target.get("id") == DEITY_CARD_ID:
		return _deity_warning_card(state, target)
	if target.get("id") == TRIBULATION_CARD_ID:
		return _tribulation_warning_card(target)
	var rules: Dictionary = target.get("combatRules", {})
	var counter: Dictionary = rules.get("counter", {})
	var source: Dictionary = target.get("bossJourney", {}).get("stages", {}).get("60", {}).get(
		"counterSource", {})
	var turns := maxi(1, int(rules.get("surviveTurns", 3)))
	var percent := roundi((1.0 - float(counter.get("incomingDamageMultiplier", 0.5))) * 100.0)
	var resource_key := String(source.get("resourceKey", "foundation"))
	var has_pill := int(state.get("resources", {}).get("pills", {}).get(resource_key, 0)) > 0
	var desc := "古石台上的惊雷石傀以铜柱引雷，三息雷律正校验你的道基。若无灵药护持，导入经络的雷火会造成重创；稳住 %d 回合即可通过雷关。" % turns
	var choices: Dictionary
	if has_pill:
		desc += "\n\n【机缘提示】：检测到你拥有【筑基丹】。可在此服用，药力将削弱导雷 %d%% 的伤害！" % percent
		choices = {"left": {"text": "吞服筑基丹入关", "desc": "消耗筑基丹以温养经脉，导雷伤害降低 %d%%。" % percent,
			"effects": {"_consumePill": resource_key, "_setFlag": counter.get("flag", "used_foundation_pill")}, "_confirmCombat": true},
			"right": {"text": "以肉身应雷", "desc": "硬接石傀导雷，不消耗任何丹药。",
				"effects": {}, "_confirmCombat": true}}
	else:
		desc += "\n\n【机缘提示】：你身上没有任何【筑基丹】，此番导雷避无可避，只能凭借护盾和本领稳住道基！"
		choices = {"left": {"text": "直面雷关", "desc": "正面稳住石傀雷击！",
			"effects": {}, "_confirmCombat": true},
			"right": {"text": "吞吐灵气调整", "desc": "消耗 10 灵石，恢复 1 点气血后再迎战。",
				"effects": {"health": 1}, "costCheck": {"spiritStone": 10}, "_confirmCombat": true}}
	desc += "\n\n【结算规则】战斗中的护体值是独立局内资源；胜利不会把局内受击写回真实气血。战败伤势上限 1 点；实际损失按结算时气血计算，备战疗伤可改变实际损失。"
	var warning: Dictionary = {"id": WARNING_ID, "title": "筑基雷关将启",
		"description": desc, "type": "COMBAT_WARNING", "_targetCombatCard": target,
		"choices": choices, "encounterContext": target.encounterContext,
		"sceneImage": target.get("combatPresentation", {}).get("sceneImage")}
	return warning


func _gate_id(realm: String) -> String:
	match realm:
		"qi": return CARD_ID
		"foundation": return FOUNDATION_CARD_ID
		"golden": return GOLDEN_CARD_ID
		"nascent": return NASCENT_CARD_ID
		"deity": return DEITY_CARD_ID
		"tribulation": return TRIBULATION_CARD_ID
	return ""


func _tribulation_warning_card(target: Dictionary) -> Dictionary:
	var judgment: Dictionary = target.get("combatRules", {}).get("karmaJudgment", {})
	var draw := maxi(0, int(judgment.get("goodDraw", 0)))
	var discard := maxi(0, int(judgment.get("badDiscard", 0)))
	var desc := "这是最后的飞升神雷大劫，你将面对天道意志本身！每回合抽牌后发起“天道审判”：善业高则额外抽 %d 张，恶业高则随机弃 %d 张。接住此劫即可飞升。" % [draw, discard]
	desc += "\n\n【天命抉择】：选择兵解重修将直接终止战斗进入下世轮回，但能带走 2 点道心和部分前世遗赠；选择迎战胜则登仙，败则重伤甚至可能陨落！"
	return {"id": "_warning_" + TRIBULATION_CARD_ID,
		"title": "九九飞升大劫", "description": desc,
		"type": "COMBAT_WARNING", "_targetCombatCard": target,
		"sceneImage": target.get("combatPresentation", {}).get("sceneImage"),
		"encounterContext": target.get("encounterContext"),
		"choices": {"left": {"text": "拼死搏击天门",
			"desc": "迎战天道意志！胜则白日飞升！",
			"effects": {}, "_confirmCombat": true},
			"right": {"text": "兵解遁入轮回",
				"desc": "散去修为，带走 2 点道心主动转世。",
				"effects": {"reincarnation_bonus": "daoHeart +2",
					"reincarnate": true}}}}


func _equipped_treasure_ids(state: Dictionary) -> Array:
	var ids: Array = []
	var instances: Dictionary = state.get("treasureInstances", {})
	for slot in ["weapon", "armor", "accessory", "artifact"]:
		var instance_id: Variant = state.get("equipment", {}).get(slot)
		if instance_id is String and instances.has(instance_id) \
				and instances[instance_id].get("lifecycle") == "owned":
			ids.append(instance_id)
	return ids


func _deity_warning_card(state: Dictionary, target: Dictionary) -> Dictionary:
	var rules: Dictionary = target.get("combatRules", {})
	var karma: Dictionary = rules.get("karmaDamage", {})
	var counter: Dictionary = rules.get("counter", {})
	var bad := int(state.get("attributes", {}).get(String(karma.get("attribute", "karmaBad")), 0))
	var points := maxi(1, int(karma.get("perPoints", 1)))
	var damage := maxi(0, int(karma.get("damagePerStep", 0)))
	var block := maxi(0, int(counter.get("openingBlock", 0)))
	var reduction := maxi(0, int(counter.get("enemyAttackReduction", 0)))
	if karma.get("attribute") != "karmaBad" or counter.get("flag") != "used_relic_shield" \
			or counter.get("consumeEffectKey") != "_consumeTreasure":
		return {}
	var desc := "九霄云涌，九重雷龙狂啸！天雷与因果紧密相连：当前恶业 %d，每 %d 点恶业使雷击伤害额外 +%d。" % [bad, points, damage]
	var choices := {}
	if not _equipped_treasure_ids(state).is_empty():
		desc += "\n\n【机缘提示】：检测到你已穿戴法宝。可碎裂一件穿戴中的法宝，获得 %d 护盾且天劫攻击 -%d！" % [block, reduction]
		choices = {"left": {"text": "以法宝分担天雷",
			"desc": "消耗一件穿戴中的法宝代劫，获得 %d 护盾且天劫攻击 -%d。" % [block, reduction],
			"effects": {"_consumeTreasure": true, "_setFlag": counter.flag}, "_confirmCombat": true},
			"right": {"text": "以肉身硬抗九天",
				"desc": "硬抗天雷！若能成功获胜，将磨砺道心，胜后额外获得 2 点道心！",
				"effects": {}, "_confirmCombat": true}}
	else:
		desc += "\n\n【机缘提示】：你身上别无法宝，只能以血肉躯体硬撼雷霆！若胜，额外获得 2 点道心！"
		choices = {"left": {"text": "以肉身迎战", "desc": "正面硬撑！",
			"effects": {}, "_confirmCombat": true},
			"right": {"text": "吞吐灵石调息",
				"desc": "消耗 20 灵石，恢复 1 点气血后再迎战。",
				"effects": {"health": 1}, "costCheck": {"spiritStone": 20},
				"_confirmCombat": true}}
	return {"id": "_warning_" + DEITY_CARD_ID, "title": "九重雷劫降临",
		"description": desc, "type": "COMBAT_WARNING", "_targetCombatCard": target,
		"choices": choices, "encounterContext": target.encounterContext,
		"sceneImage": target.get("combatPresentation", {}).get("sceneImage")}


func _nascent_warning_card(state: Dictionary, target: Dictionary) -> Dictionary:
	var backlash: Dictionary = target.get("combatRules", {}).get("attackBacklash", {})
	var counter: Dictionary = backlash.get("counter", {})
	var source: Dictionary = target.get("bossJourney", {}).get("stages", {}).get(
		"60", {}).get("counterSource", {})
	var pill_key := String(source.get("resourceKey", counter.get("resourceKey", "deity")))
	var flag := String(counter.get("flag", "used_deity_pill"))
	var damage := maxi(0, int(backlash.get("damage", 0)))
	var reduction := maxi(0, int(counter.get("enemyHpReduction", 0)))
	if pill_key != "deity" or flag != "used_deity_pill" or damage <= 0 \
			or backlash.get("triggerCardType") != "attack" or reduction <= 0:
		return {}
	var desc := "九天玄雷狂暴积蓄，虚空撕裂！虚空雷罚拥有“天机反噬”：每打出一张【攻击卡】，反噬天雷便直接扣减 %d 点气血，不受护体值抵挡。" % damage
	var has_pill := int(state.get("resources", {}).get("pills", {}).get(pill_key, 0)) > 0
	var choices: Dictionary
	if has_pill:
		desc += "\n\n【机缘提示】：检测到你拥有【化神丹】。服用后可洗练因果天机，完全免除攻击反噬伤害，且削弱雷罚 %d 点根基！" % reduction
		choices = {"left": {"text": "服用化神丹出战",
			"desc": "消耗化神丹，洗练周身尘缘，完全免疫天机反噬，弱化雷罚。",
			"effects": {"_consumePill": pill_key, "_setFlag": flag},
			"_confirmCombat": true},
			"right": {"text": "逆天硬闯雷劫",
				"desc": "保留自身锋芒，不做额外防护硬战！",
				"effects": {}, "_confirmCombat": true}}
	else:
		desc += "\n\n【机缘提示】：你没有【化神丹】，在战斗中需尽量减少使用普通攻击牌以防反噬！"
		choices = {"left": {"text": "硬闯天罚", "desc": "直接迎战！",
			"effects": {}, "_confirmCombat": true},
			"right": {"text": "吐纳平复气血",
				"desc": "消耗 15 灵石，调息恢复 1 气血后再战。",
				"effects": {"health": 1}, "costCheck": {"spiritStone": 15},
				"_confirmCombat": true}}
	return {"id": "_warning_" + NASCENT_CARD_ID,
		"title": "化神虚空雷罚", "description": desc,
		"type": "COMBAT_WARNING", "_targetCombatCard": target,
		"choices": choices, "encounterContext": target.encounterContext,
		"sceneImage": target.get("combatPresentation", {}).get("sceneImage")}


func _golden_warning_card(state: Dictionary, target: Dictionary) -> Dictionary:
	var rules: Dictionary = target.get("combatRules", {})
	var counters: Dictionary = rules.get("counters", {})
	var pill_counter: Dictionary = counters.get("nascentPill", {})
	var array_counter: Dictionary = counters.get("lightningArray", {})
	var source: Dictionary = target.get("bossJourney", {}).get("stages", {}).get(
		"60", {}).get("counterSource", {})
	var alternate: Dictionary = target.get("bossJourney", {}).get("stages", {}).get(
		"60", {}).get("alternateSource", {})
	var yang: Dictionary = rules.get("turnCycle", {}).get("yang", {})
	var yin: Dictionary = rules.get("turnCycle", {}).get("yin", {})
	var pill_key := String(source.get("resourceKey", pill_counter.get("resourceKey", "nascent")))
	var pill_flag := String(pill_counter.get("flag", "used_nascent_pill"))
	var array_flag := String(array_counter.get("flag", alternate.get("flag", "used_lightning_array")))
	var array_cost := maxi(0, int(array_counter.get("cost", {}).get("spiritStone",
		alternate.get("cost", 0))))
	var block := maxi(0, int(array_counter.get("openingBlock", 0)))
	if pill_key != "nascent" or pill_flag != "used_nascent_pill" \
			or array_flag != "used_lightning_array" or array_cost != 25 \
			or block != 8 or yin.get("piercing") != true:
		return {}
	var desc := "金丹圆满，碎丹化婴！劫雷奇数回合降下“阳雷”（%d 倍伤害，可被盾挡），偶数回合降下“阴雷”（穿透护盾直击本源）。避雷阵可提供 %d 点开局护盾。" % [
		maxi(1, int(yang.get("damageMultiplier", 2))), block]
	var has_pill := int(state.get("resources", {}).get("pills", {}).get(pill_key, 0)) > 0
	var choices: Dictionary
	if has_pill:
		desc += "\n\n【机缘提示】：检测到你拥有【凝婴丹】。服用后可在战斗中保护元神，使阴雷无法穿透护甲！"
		choices = {"left": {"text": "吞服凝婴丹迎战",
			"desc": "消耗凝婴丹，药力护住泥丸宫，免疫阴雷穿甲效果。",
			"effects": {"_consumePill": pill_key, "_setFlag": pill_flag},
			"_confirmCombat": true},
			"right": {"text": "布避雷阵迎击",
				"desc": "花费 %d 灵石布下御雷大阵，战斗开始获得 %d 点护盾。" % [array_cost, block],
				"effects": {"_setFlag": array_flag},
				"costCheck": {"spiritStone": array_cost}, "_confirmCombat": true},
			"up": {"text": "凭肉身硬接雷劫", "desc": "不做准备，直接出战。",
				"effects": {}, "_confirmCombat": true}}
	else:
		desc += "\n\n【机缘提示】：你没有【凝婴丹】，偶数回合需特别警惕阴雷对气血的无视盾牌伤害！"
		choices = {"left": {"text": "布避雷法阵",
			"desc": "花费 %d 灵石布下避雷大阵，获得 %d 点开局护盾。" % [array_cost, block],
			"effects": {"_setFlag": array_flag},
			"costCheck": {"spiritStone": array_cost}, "_confirmCombat": true},
			"right": {"text": "肉身硬顶天威", "desc": "直接迎战！",
				"effects": {}, "_confirmCombat": true}}
	return {"id": "_warning_" + GOLDEN_CARD_ID, "title": "元婴天劫将至",
		"description": desc, "type": "COMBAT_WARNING", "_targetCombatCard": target,
		"choices": choices, "encounterContext": target.encounterContext,
		"sceneImage": target.get("combatPresentation", {}).get("sceneImage")}


func _foundation_warning_card(state: Dictionary, target: Dictionary) -> Dictionary:
	var rules: Dictionary = target.get("combatRules", {})
	var counter: Dictionary = rules.get("counter", {})
	var source: Dictionary = target.get("bossJourney", {}).get("stages", {}).get(
		"60", {}).get("counterSource", {})
	var base_hp := maxi(1, int(rules.get("baseHp", 30)))
	var minimum_hp := maxi(1, int(rules.get("minimumHp", 10)))
	var reduction := maxi(0, int(rules.get("daoHeartHpReductionPerPoint", 0)))
	var opening_block := maxi(0, int(counter.get("openingBlock", 0)))
	var enemy_reduction := maxi(0, int(counter.get("enemyHpReduction", 0)))
	var resource_key := String(source.get("resourceKey", "golden"))
	var counter_flag := String(counter.get("flag", "used_golden_pill"))
	var has_pill := int(state.get("resources", {}).get("pills", {}).get(
		resource_key, 0)) > 0
	var desc := "心气浮躁间，虚空中涌出滚滚心魔，将你笼罩在无尽幻象中！这是你的金丹心魔大劫。心魔固定根基为 %d，你当前道心为 %d；每点道心削去 %d 点，最低压至 %d 点。" % [
		base_hp, int(state.get("attributes", {}).get("daoHeart", 0)),
		reduction, minimum_hp]
	var choices: Dictionary
	if has_pill:
		desc += "\n\n【机缘提示】：检测到你拥有【结金丹】。服用后开场获得 %d 点护盾，并削去心魔 %d 点根基！" % [
			opening_block, enemy_reduction]
		choices = {"left": {"text": "服用结金丹迎战",
			"desc": "消耗结金丹，开场获得 %d 点护盾并削去心魔 %d 点根基。" % [
				opening_block, enemy_reduction],
			"effects": {"_consumePill": resource_key, "_setFlag": counter_flag},
			"_confirmCombat": true},
			"right": {"text": "以道心正面斩魔", "desc": "正面迎战，不使用结金丹。",
				"effects": {}, "_confirmCombat": true},
			"up": {"text": "静心沉思", "desc": "消耗 5 灵石，平复一下颤动的道心。",
				"effects": {}, "costCheck": {"spiritStone": 5},
				"_confirmCombat": true}}
	else:
		desc += "\n\n【机缘提示】：你身上没有【结金丹】，此战无法依靠丹药，只能全凭自身道心御魔！"
		choices = {"left": {"text": "直面心神拷问", "desc": "正面迎击！",
			"effects": {}, "_confirmCombat": true},
			"right": {"text": "静心沉思", "desc": "消耗 5 灵石，平复一下颤动的道心。",
				"effects": {}, "costCheck": {"spiritStone": 5},
				"_confirmCombat": true}}
	return {"id": "_warning_" + FOUNDATION_CARD_ID, "title": "金丹心魔劫",
		"description": desc, "type": "COMBAT_WARNING",
		"_targetCombatCard": target, "choices": choices,
		"encounterContext": target.encounterContext,
		"sceneImage": target.get("combatPresentation", {}).get("sceneImage")}


func settle_result(state: Dictionary, result: Dictionary, request: Dictionary) -> Dictionary:
	last_error = ""
	var realm := String(state.get("realm", ""))
	var gate_id := _gate_id(realm)
	if state.get("phase") != "BATTLE_PENDING" or gate_id.is_empty() \
			or state.get("currentCardId") != gate_id \
			or JSON.parse_string(JSON.stringify(state.get("pendingRealmGateCard"))) != \
				JSON.parse_string(JSON.stringify(source_card(state))) \
			or state.get("noncombatFlow", {}).get("realmGateState", {}).get("status") != "in_progress" \
			or request.get("sourceCardId") != gate_id \
			or result.get("outcome") not in ["victory", "defeat", "flee"]:
		last_error = "破境关卡战果或来源无效"
		return {}
	var candidate: Dictionary = state.duplicate(true)
	var outcome := String(result.outcome)
	var card: Dictionary = candidate.pendingRealmGateCard
	var base := int(request.baseDecisionIndex)
	var next_index := base + 1
	var owner := String(request.encounterInstanceId)
	var canonical := {}
	for key in ["contractVersion", "encounterInstanceId", "sourceCardId", "encounterId",
			"sourceContentHash", "outcome", "combatReceipt"]:
		canonical[key] = result[key]
	canonical["postBattleState"] = {"encounterInstanceId": owner,
		"terminal": true, "combatPhase": outcome.to_upper()}
	var record := {"result": canonical, "warningDirection": request.warningChoiceDirection,
		"decisionIndex": next_index, "defeatHealthLoss": 0}
	# The source consumes this realm's one-use boost when breakthrough resolves.
	# A retreat does not enter that resolution path.
	if outcome != "flee":
		candidate.get("flags", {}).erase("breakthrough_boost:" + realm)
	if outcome == "victory":
		var rewards: Dictionary = card.get("combatRewards", {})
		if rewards.get("breakSuccess") != true or int(rewards.get("cultivation", -1)) < 0 \
				or int(rewards.get("health", 0)) < 0 \
				or int(rewards.get("daoHeart", -1)) < 0 \
				or int(rewards.get("spiritStone", 0)) < 0 \
				or int(rewards.get("maxHealth", 0)) < 0 \
				or int(rewards.get("maxDaoHeart", 0)) < 0:
			return {}
		if not (legacy_qi_spine_victory_replay and gate_id == CARD_ID) \
				and not _settle_spine_combat(candidate, card, next_index):
			last_error = "化神雷罚主线事实无法结算"
			return {}
		if gate_id == TRIBULATION_CARD_ID:
			if candidate.get("terminalContext") != null \
					or card.get("isFinale") != true \
					or card.get("terminalGateId") != "tribulation_finale":
				return {}
			candidate["terminalContext"] = {
				"gateId": card.terminalGateId,
				"encounterId": gate_id,
				"encounterInstanceId": owner,
				"victoryToken": "combat:" + owner,
				"outcome": "victory", "stage": "REWARD_PENDING",
				"consumed": false,
				"eligibilitySnapshot": _ending_snapshot(state)}
		var apply := MilestoneFlow.new(_content)
		var base_cult := 5 + int(floor(int(candidate.attributes.cultivation) / 20.0))
		var base_stones := int(floor(maxi(1, int(card.enemy.get("atk", 1))) * 1.5))
		if not apply._apply_effect(candidate, "cultivation", base_cult) \
				or not apply._apply_effect(candidate, "spiritStone", base_stones):
			return {}
		for key in ["cultivation", "daoHeart", "health", "spiritStone"]:
			if not apply._apply_effect(candidate, key, int(rewards.get(key, 0)),
					String(card.get("id", "")), next_index):
				return {}
		candidate["maxHealth"] = int(candidate.maxHealth) + int(rewards.get("maxHealth", 0))
		candidate["maxDaoHeart"] = int(candidate.maxDaoHeart) + int(rewards.get("maxDaoHeart", 0))
		if gate_id != TRIBULATION_CARD_ID:
			var realms: Variant = _content.read_module("config:realms")
			if not realms is Dictionary:
				return {}
			var next_realm := "tribulation" if realm == "deity" else (
				"deity" if realm == "nascent" else (
				"nascent" if realm == "golden" else (
				"golden" if realm == "foundation" else "foundation")))
			var next_config: Dictionary = realms.get("realms", {}).get(next_realm, {})
			if next_config.is_empty() or int(next_config.get("lifespanBonus", 0)) <= 0:
				return {}
			candidate["realm"] = next_realm
			var prep: Dictionary = state.get("runClock", {}).get(
				"preparationReceipts", {}).get(request.get("warningCheckpointToken"), {})
			var pill_prefix := "Deity" if realm == "nascent" else (
				"Nascent" if realm == "golden" else (
				"Golden" if realm == "foundation" else "Foundation"))
			var path_skill = PathSkillFlow.new(_content)
			var threshold := int(next_config.get("cultivationThreshold", 100))
			var pill_bonus := path_skill.breakthrough_cultivation_bonus(state,
				threshold, prep.get("used%sPill" % pill_prefix) == true, next_index)
			if not path_skill.last_error.is_empty():
				return {}
			candidate["attributes"]["cultivation"] = mini(threshold, 10 + pill_bonus)
			if pill_bonus > 0:
				record["breakthroughCultivationBonus"] = pill_bonus
			candidate["maxHealth"] = int(candidate.maxHealth) + 1
			candidate["maxDaoHeart"] = int(candidate.maxDaoHeart) + 1
			candidate["attributes"]["health"] = int(candidate.maxHealth)
			candidate["attributes"]["daoHeart"] = int(candidate.maxDaoHeart)
			candidate["resources"]["lifespan"] = int(candidate.resources.lifespan) + int(
				next_config.lifespanBonus)
			candidate["currentLocation"] = "宗门"
		candidate["noncombatFlow"]["realmGateState"]["status"] = "resolved"
		record["baseRewards"] = {"cultivation": base_cult, "spiritStone": base_stones}
		record["sourceRewards"] = rewards.duplicate(true)
	elif outcome == "flee":
		candidate["resources"]["lifespan"] = maxi(0, int(candidate.resources.lifespan) - 1)
		if int(candidate.resources.lifespan) <= 0 and gate_id != TRIBULATION_CARD_ID:
			last_error = "雷关撤离后的寿尽结算尚未迁入"
			return {}
		candidate["noncombatFlow"]["realmGateState"]["status"] = "deferred"
		candidate["noncombatFlow"]["realmGateState"]["deferDrawsRemaining"] = 1
	else:
		var injury := mini(1, int(candidate.attributes.health))
		candidate["attributes"]["health"] = int(candidate.attributes.health) - injury
		if int(candidate.attributes.health) <= 0 and gate_id != TRIBULATION_CARD_ID:
			if int(candidate.maxHealth) <= 1 or int(candidate.maxDaoHeart) <= 1:
				last_error = "雷关战败死亡或法宝复活尚未迁入"
				return {}
			candidate["maxHealth"] = int(candidate.maxHealth) - 1
			candidate["maxDaoHeart"] = int(candidate.maxDaoHeart) - 1
			candidate["attributes"]["health"] = 1
			candidate["attributes"]["daoHeart"] = mini(int(candidate.attributes.daoHeart),
				int(candidate.maxDaoHeart))
		candidate["attributes"]["cultivation"] = maxi(0, int(candidate.attributes.cultivation) - 30)
		candidate["pendingConsequence"] = {"version": 1, "type": "inner_demon",
			"lifeId": request.lifeId, "realm": realm, "sourceCardId": gate_id}
		candidate["noncombatFlow"]["realmGateState"]["status"] = "available"
		record["defeatHealthLoss"] = injury
	var history: Array = candidate.get("battleResultHistory", []).duplicate(true)
	history.append(record)
	candidate["battleResultHistory"] = history
	candidate["choiceHistory"].append({"cardId": gate_id, "cardType": "COMBAT",
		"direction": "left", "turn": base, "decisionIndex": next_index,
		"tags": [], "combatOutcome": outcome})
	while candidate["choiceHistory"].size() > 30:
		candidate["choiceHistory"].pop_front()
	candidate["cardsPlayed"].append(gate_id)
	candidate["turn"] = next_index
	candidate["runClock"]["decisionIndex"] = next_index
	var token := "decision:%s:combat:%s" % [request.lifeId, owner]
	candidate["runClock"]["receipts"][token] = {"token": token,
		"decisionIndex": next_index, "sourceCardId": gate_id, "kind": "combat"}
	candidate["runClock"]["receipts"]["battle:" + owner] = {"outcome": outcome,
		"decisionIndex": next_index, "sourceCardId": gate_id, "defeatHealthLoss": 0}
	MilestoneFlow.tick_seeds(candidate)
	candidate.erase("pendingBattle")
	candidate.erase("encounterActionHistory")
	if gate_id == TRIBULATION_CARD_ID and (int(candidate.attributes.health) <= 0 \
			or int(candidate.resources.lifespan) <= 0):
		var death := DeathFlow.new(_content).prepare_death(candidate, gate_id)
		if death.is_empty():
			last_error = "终局战斗死亡卡来源或复活边界无效"
			return {}
		return death
	if outcome == "defeat":
		var demon := inner_demon_card(candidate)
		if demon.is_empty():
			last_error = "心魔卡来源无效"
			return {}
		candidate["pendingInnerDemonCard"] = demon
		candidate["currentCardId"] = demon.id
		candidate["phase"] = "INNER_DEMON_PENDING"
		candidate["decisionCheckpoint"] = {"version": 1, "cardId": demon.id,
			"sourceCardId": gate_id, "turn": next_index, "decisionIndex": next_index}
		return candidate
	var card_result := result_card(candidate)
	if card_result.is_empty():
		last_error = "破境关卡战果卡来源无效"
		return {}
	candidate["pendingBattleResultCard"] = card_result
	candidate["currentCardId"] = card_result.id
	candidate["phase"] = "BATTLE_RESULT_PENDING"
	candidate["decisionCheckpoint"] = {"version": 1, "cardId": card_result.id,
		"sourceCardId": gate_id, "turn": next_index, "decisionIndex": next_index}
	return candidate


func _ending_snapshot(state: Dictionary) -> Dictionary:
	var atlas: Variant = _content.read_module("world:truth_atlas")
	if not atlas is Dictionary:
		return {}
	var clue_ids: Array = []
	for clue in state.get("clues", []):
		var clue_id := String(clue.get("id", "") if clue is Dictionary else clue)
		if not clue_id.is_empty() and not clue_ids.has(clue_id):
			clue_ids.append(clue_id)
	for clue in state.get("noncombatFlow", {}).get("hintClues", []):
		if clue is Dictionary:
			var clue_id := String(clue.get("id", ""))
			if not clue_id.is_empty() and not clue_ids.has(clue_id):
				clue_ids.append(clue_id)
	var hypothesis_confidence := {}
	for hypothesis in atlas.get("hypotheses", []):
		if not hypothesis is Dictionary or not hypothesis.get("supports") is Array \
				or not hypothesis.get("contradicts") is Array:
			continue
		var support_count := 0
		for clue_id in hypothesis["supports"]:
			if clue_ids.has(clue_id):
				support_count += 1
		var contradiction_count := 0
		for clue_id in hypothesis["contradicts"]:
			if clue_ids.has(clue_id):
				contradiction_count += 1
		var required := maxi(1, int(hypothesis.get("requiredEvidence", 1)))
		hypothesis_confidence[String(hypothesis.get("id", ""))] = clampi(
			roundi(float(support_count) / float(required) * 100.0
				- float(contradiction_count) * 25.0), 0, 100)
	var max_bond := 0
	for value in state.get("npcAffection", {}).values():
		max_bond = maxi(max_bond, int(value))
	for value in state.get("npcEncounterScheduling", {}).get("affections", {}).values():
		max_bond = maxi(max_bond, int(value))
	return {"version": 1, "realm": state.get("realm"),
		"clueIds": clue_ids,
		"hypothesisConfidence": hypothesis_confidence,
		"maxBond": max_bond,
		"capturedTurn": int(state.get("turn", 0)),
		"lifeCount": int(state.get("lifeCount", 0))}


func _prepare_spine_combat(target: Dictionary, card: Dictionary) -> bool:
	var spine: Dictionary = card.get("narrativeSpine", {})
	var settlement: Dictionary = spine.get("combatSettlement", {})
	if settlement.is_empty():
		return true
	var flow: Dictionary = target.get("noncombatFlow", {})
	var facts: Dictionary = flow.get("spineFacts", {}).duplicate(true)
	var life_count := int(target.get("lifeCount", 0))
	for fact_type in settlement.get("consumes", []):
		var fact_id := "fact:%d:%s" % [life_count, String(fact_type)]
		if facts.has(fact_id):
			if facts[fact_id].get("status") != "active":
				return false
			continue
		var payload: Dictionary = {"threadId": spine.get("threadId"),
			"step": spine.get("step"), "legacyMigration": true}
		payload.merge(settlement.get("legacyMigration", {}).get(
			"defaultPayloadByFactType", {}).get(fact_type, {}), true)
		facts[fact_id] = {"factInstanceId": fact_id, "factTypeId": fact_type,
			"lifeCount": life_count, "status": "active",
			"producerId": settlement.get("legacyMigration", {}).get("producerId",
				"%s:legacy_gate_migration" % String(spine.get("threadId", ""))),
			"payload": payload, "createdDecisionIndex": int(target.get("turn", 0)),
			"terminalClosure": null, "closedDecisionIndex": null}
	flow["spineFacts"] = facts
	target["noncombatFlow"] = flow
	return true


func _settle_spine_combat(target: Dictionary, card: Dictionary, decision: int) -> bool:
	var spine: Dictionary = card.get("narrativeSpine", {})
	var settlement: Dictionary = spine.get("combatSettlement", {})
	if settlement.is_empty():
		return true
	var graph: Variant = _content.read_module("narrative:causal_graph")
	if not graph is Dictionary:
		return false
	var definitions: Dictionary = {}
	for entry in graph.get("factTypes", []):
		if entry is Dictionary and entry.has("factTypeId"):
			definitions[String(entry.factTypeId)] = entry
	var flow: Dictionary = target.get("noncombatFlow", {})
	var facts: Dictionary = flow.get("spineFacts", {}).duplicate(true)
	var consumptions: Dictionary = flow.get("spineConsumptions", {}).duplicate(true)
	var life_count := int(target.get("lifeCount", 0))
	var consumed_payloads := {}
	for fact_type in settlement.get("consumes", []):
		var fact_id := "fact:%d:%s" % [life_count, String(fact_type)]
		var fact: Dictionary = facts.get(fact_id, {})
		var consumer_id := String(settlement.get("consumerIds", {}).get(fact_type, ""))
		var consumer: Dictionary = {}
		for entry in definitions.get(String(fact_type), {}).get("consumers", []):
			if entry is Dictionary and entry.get("consumerId") == consumer_id:
				consumer = entry
				break
		if fact.get("status") != "active" or consumer.is_empty() \
				or consumer.get("mode") == "observe" \
				or consumptions.has(fact_id + ":" + consumer_id) \
				or decision < int(fact.get("createdDecisionIndex", -1000)) + int(
					consumer.get("earliestDecisionOffset", 0)) \
				or decision > int(fact.get("createdDecisionIndex", -1000)) + int(
					consumer.get("latestDecisionOffset", -1)):
			return false
		consumptions[fact_id + ":" + consumer_id] = {"factInstanceId": fact_id,
			"factTypeId": fact_type, "consumerId": consumer_id,
			"consumedDecisionIndex": decision, "receipt": {"threadId": spine.get("threadId"),
				"outcome": "victory", "combatCardId": card.id}}
		consumed_payloads[String(fact_type)] = fact.get("payload", {}).duplicate(true)
		fact["status"] = "consumed"
		fact["consumedDecisionIndex"] = decision
		fact["consumedBy"] = consumer_id
		facts[fact_id] = fact
	var produces: Array = spine.get("produces", [])
	if produces.is_empty():
		return false
	var outcome_type := String(produces[0])
	var outcome_id := "fact:%d:%s" % [life_count, outcome_type]
	if not definitions.has(outcome_type) or facts.has(outcome_id):
		return false
	var payload: Dictionary = {"threadId": spine.get("threadId"),
		"step": spine.get("step"), "outcome": "victory", "sourceCardId": card.id}
	for field in settlement.get("outcomePayloadFields", []):
		if not field is Dictionary:
			continue
		var source_key := String(field.get("sourceKey", ""))
		var target_key := String(field.get("targetKey", source_key))
		payload[target_key] = consumed_payloads.get(String(field.get("factTypeId", "")), {}).get(
			source_key, field.get("fallback"))
	facts[outcome_id] = {"factInstanceId": outcome_id, "factTypeId": outcome_type,
		"lifeCount": life_count, "status": "active",
		"producerId": "%s:combat:victory" % card.id,
		"payload": payload, "createdDecisionIndex": decision,
		"terminalClosure": null, "closedDecisionIndex": null}
	flow["spineFacts"] = facts
	flow["spineConsumptions"] = consumptions
	target["noncombatFlow"] = flow
	return true


func result_card(state: Dictionary) -> Dictionary:
	var card: Dictionary = state.get("pendingRealmGateCard", {})
	var history: Array = state.get("battleResultHistory", [])
	var gate_id := String(card.get("id", ""))
	if gate_id not in [CARD_ID, FOUNDATION_CARD_ID, GOLDEN_CARD_ID, NASCENT_CARD_ID, DEITY_CARD_ID, TRIBULATION_CARD_ID] or history.is_empty() \
			or state.get("noncombatFlow", {}).get("realmGateSourceSha") != _content.source_sha256(MODULE):
		return {}
	var outcome := String(history.back().get("result", {}).get("outcome", ""))
	var visual: Dictionary = card.get("combatPresentation", {})
	if outcome == "flee":
		return {"id": "combat_fled_" + gate_id, "type": "NORMAL",
			"sceneImage": card.sceneImage,
			"combatPresentationId": visual.get("presentationId"),
			"title": "脱离战场",
			"description": "你暂退飞升大劫，天门仍未开启。" if gate_id == TRIBULATION_CARD_ID else ("你暂退九重雷劫，认领的业债仍待下次兑现。" if gate_id == DEITY_CARD_ID else ("你暂退虚空雷罚，已认领的道路仍待下次兑现。" if gate_id == NASCENT_CARD_ID else ("你趁阴阳雷兽气机转换退出天劫。道路暂时保住了，但这场未完的冲突会留下后果。" if gate_id == GOLDEN_CARD_ID else ("你趁镜中道敌攻势转换退出心魔劫。道路暂时保住了，但这场未完的冲突会留下后果。" if gate_id == FOUNDATION_CARD_ID else "你抓住惊雷石傀攻势转换的间隙退出战局。道路暂时保住了，但这场未完的冲突会留下后果。")))),
			"choices": {"down": {"text": "收敛气息，继续前行", "effects": {}}}}
	if outcome == "defeat":
		var injury := int(history.back().get("defeatHealthLoss", 0))
		return {"id": "combat_defeat_" + gate_id, "type": "NORMAL",
			"sceneImage": card.sceneImage,
			"combatPresentationId": visual.get("presentationId"),
			"title": "重伤退却",
			"description": ("飞升大劫压过了你的最后一轮攻势。离场伤势使真实气血减少 %d 点；天门未开。" if gate_id == TRIBULATION_CARD_ID else ("九重雷劫压过了你的最后一轮攻势。离场伤势使真实气血减少 %d 点；业债未结，破境奖励不会发放。" if gate_id == DEITY_CARD_ID else ("虚空雷罚压过了你的最后一轮攻势。离场伤势使真实气血减少 %d 点；破境没有完成。" if gate_id == NASCENT_CARD_ID else ("阴阳雷兽压过了你的最后一轮攻势。局内护体值已经耗尽，离场伤势使真实气血减少 %d 点；破境没有完成，胜利奖励也不会发放。" if gate_id == GOLDEN_CARD_ID else ("镜中道敌压过了你的最后一轮攻势。局内护体值已经耗尽，离场伤势使真实气血减少 %d 点；破境没有完成，胜利奖励也不会发放。" if gate_id == FOUNDATION_CARD_ID else "惊雷石傀压过了你的最后一轮攻势。局内护体值已经耗尽，离场伤势使真实气血减少 %d 点；任务没有完成，胜利奖励也不会发放。"))))) % injury,
			"choices": {"down": {"text": "稳住伤势，记下此败", "effects": {}}}}
	if outcome != "victory":
		return {}
	var world: Dictionary = _content.read_module("combat:visual_worlds").get(
		"worlds", {}).get(visual.get("visualWorldId"), {})
	var material: Dictionary = world.get("uiMaterial", {})
	var deck := DeckAcquisition.new(_content)
	var offers := deck.battle_reward_offers(state)
	var world_id := String(visual.get("visualWorldId", ""))
	if offers.size() != 3 or (not world_id.is_empty() \
			and material.get("visualWorldId") != world_id):
		return {}
	var choices := {}
	for i in range(3):
		var offer: Dictionary = offers[i]
		choices[["left", "right", "down"][i]] = {"text": "参悟【%s】" % offer.cardName,
			"desc": "%s\n\n【来源】境界突破" % String(offer.get("description", "将本流派功法纳入识海。")),
			"effects": {"deckCard": {"cardId": offer.cardId, "path": state.path,
				"sourceType": "breakthrough_reward", "sourceId": gate_id}}}
	var base: Dictionary = history.back().get("baseRewards", {})
	var rewards: Dictionary = history.back().get("sourceRewards", {})
	var summary := "\n\n【本次结算】修为 +%d，灵石 +%d。" % [int(base.get("cultivation", 0)),
		int(base.get("spiritStone", 0))]
	summary += "\n\n除了战利品，你还获得了：修为 +%d。" % int(rewards.get("cultivation", 0))
	var pill_bonus := int(history.back().get("breakthroughCultivationBonus", 0))
	if pill_bonus > 0:
		summary += "\n\n【丹道真意】入境后额外修为 +%d。" % pill_bonus
	summary += "\n\n【终局胜利】：天门已开，待择传承后裁定此世结局。" if gate_id == TRIBULATION_CARD_ID else "\n\n【境界突破】：劫数已过，你感觉体内的力量正在蜕变！"
	return {"id": "breakthrough_reward", "type": "NORMAL",
		"sceneImage": visual.get("sceneImage"),
		"combatPresentationId": visual.get("presentationId"),
		"visualWorldId": world_id if not world_id.is_empty() else null,
		"uiMaterialId": material.get("id") if not world_id.is_empty() else null,
		"visualSurface": "combat_settlement_ledger" if not world_id.is_empty() else null,
		"title": "神意蜕变 · 本命传承",
		"description": ("最终天劫已经伏下，胜利事实已封入命盘。选择一门本脉法诀后，天道将据你的证据与旧愿裁定此世结局。%s" if gate_id == TRIBULATION_CARD_ID else "九天惊雷渐渐散去，你历经雷劫心魔的千锤百炼，肉身神魂皆脱胎换骨。%s\n\n在灵台清明的一瞬间，你感受到了功法法则的召唤，请在传承的法诀中选择其一参悟！") % summary,
		"choices": choices}


func inner_demon_card(state: Dictionary) -> Dictionary:
	var gate_id := String(state.get("pendingRealmGateCard", {}).get("id", ""))
	if state.get("pendingConsequence", {}).get("type") != "inner_demon" \
			or gate_id not in [CARD_ID, FOUNDATION_CARD_ID, GOLDEN_CARD_ID, NASCENT_CARD_ID, DEITY_CARD_ID, TRIBULATION_CARD_ID] \
			or state.get("pendingConsequence", {}).get("sourceCardId") != gate_id:
		return {}
	var card := {"id": "inner_demon", "type": "INNER_DEMON",
		"title": "心魔反噬",
		"description": "突破失败，心魔趁虚而入——黑暗的念头在你识海中翻涌。你感到另一个自己在低语：\n\n\"何必苦苦坚持正道？接受我，你将更强。\"",
		"realm": state.get("realm"),
		"tags": ["inner_demon", "breakthrough_failure"],
		"choices": {"left": {"text": "接受心魔", "effects": {"cultivation": 5,
			"daoHeart": -5, "karmaBad": 10}, "innerDemonAction": "accept"},
			"right": {"text": "抵抗心魔", "effects": {"daoHeart": -3,
				"cultivation": 2}, "innerDemonAction": "resist"},
			"up": {"text": "暂时封印", "effects": {}, "innerDemonAction": "seal"}}}
	return card


func settle_inner_demon(state: Dictionary, direction: String,
		death_flow: RefCounted) -> Dictionary:
	var card := inner_demon_card(state)
	if state.get("phase") != "INNER_DEMON_PENDING" or card.is_empty() \
			or JSON.parse_string(JSON.stringify(card)) != JSON.parse_string(
				JSON.stringify(state.get("pendingInnerDemonCard"))) \
			or not card.choices.has(direction):
		return {}
	var candidate: Dictionary = state.duplicate(true)
	var effects: Dictionary = card.choices[direction].effects
	var apply := MilestoneFlow.new(_content)
	for key in effects:
		if not apply._apply_effect(candidate, String(key), effects[key]):
			return {}
	var action := String(card.choices[direction].innerDemonAction)
	if action == "accept":
		candidate["flags"]["innerDemonBoost"] = true
	elif action == "resist":
		var resisted := int(candidate["flags"].get("innerDemonResisted", 0)) + 1
		candidate["flags"]["innerDemonResisted"] = resisted
		if resisted >= 3:
			if not apply._apply_effect(candidate, "daoHeart", 5):
				return {}
	elif action == "seal":
		var sealed := int(candidate["flags"].get("innerDemonSealed", 0)) + 1
		candidate["flags"]["innerDemonSealed"] = sealed
		if sealed >= 5:
			if not apply._apply_effect(candidate, "daoHeart", -20) \
					or not apply._apply_effect(candidate, "karmaBad", 20):
				return {}
			candidate["flags"]["innerDemonSealed"] = 0
	else:
		return {}
	candidate["pendingConsequence"] = null
	candidate.erase("pendingInnerDemonCard")
	var base := int(candidate.turn)
	var next_index := base + 1
	candidate["choiceHistory"].append({"cardId": "inner_demon",
		"cardType": "INNER_DEMON", "direction": direction,
		"turn": base, "decisionIndex": next_index,
		"tags": card.tags.duplicate(true)})
	while candidate["choiceHistory"].size() > 30:
		candidate["choiceHistory"].pop_front()
	candidate["cardsPlayed"].append("inner_demon")
	candidate["turn"] = next_index
	candidate["runClock"]["decisionIndex"] = next_index
	var token := "decision:%s:choice:inner_demon:%d" % [candidate.runClock.lifeId,
		next_index]
	if candidate.runClock.receipts.has(token):
		return {}
	candidate["runClock"]["receipts"][token] = {"token": token,
		"decisionIndex": next_index, "sourceCardId": "inner_demon", "kind": "choice"}
	MilestoneFlow.tick_seeds(candidate)
	if int(candidate.attributes.daoHeart) <= 0:
		return death_flow.prepare_death(candidate, "inner_demon")
	var result := result_card(candidate)
	if result.is_empty():
		return {}
	candidate["pendingBattleResultCard"] = result
	candidate["currentCardId"] = result.id
	candidate["phase"] = "BATTLE_RESULT_PENDING"
	candidate["decisionCheckpoint"] = {"version": 1, "cardId": result.id,
		"sourceCardId": state.get("pendingRealmGateCard", {}).get("id"),
		"turn": next_index, "decisionIndex": next_index}
	return candidate


func dismiss(state: Dictionary, direction: String) -> Dictionary:
	var card := result_card(state)
	if state.get("phase") != "BATTLE_RESULT_PENDING" or card.is_empty() \
			or card.get("id") != state.get("currentCardId") \
			or JSON.parse_string(JSON.stringify(card)) != JSON.parse_string(
				JSON.stringify(state.get("pendingBattleResultCard"))) \
			or not card.get("choices", {}).has(direction):
		return {}
	var candidate: Dictionary = state.duplicate(true)
	var gate_id := String(state.get("pendingRealmGateCard", {}).get("id", ""))
	if card.id == "breakthrough_reward":
		var card_id := String(card.choices[direction].effects.deckCard.cardId)
		candidate = DeckAcquisition.new(_content).acquire_battle_reward(candidate,
			card_id, gate_id, "breakthrough_reward")
		if candidate.is_empty():
			return {}
	var base := int(candidate.turn)
	var next_index := base + 1
	candidate["choiceHistory"].append({"cardId": card.id, "cardType": "NORMAL",
		"direction": direction, "turn": base, "decisionIndex": next_index, "tags": []})
	while candidate["choiceHistory"].size() > 30:
		candidate["choiceHistory"].pop_front()
	candidate["cardsPlayed"].append(card.id)
	candidate["turn"] = next_index
	candidate["runClock"]["decisionIndex"] = next_index
	var token := "decision:%s:choice:%s:%d" % [candidate.runClock.lifeId, card.id, next_index]
	if candidate.runClock.receipts.has(token):
		return {}
	candidate["runClock"]["receipts"][token] = {"token": token,
		"decisionIndex": next_index, "sourceCardId": card.id, "kind": "choice"}
	MilestoneFlow.tick_seeds(candidate)
	candidate.erase("pendingBattleResultCard")
	candidate.erase("pendingRealmGateCard")
	if card.id == "breakthrough_reward":
		if gate_id == TRIBULATION_CARD_ID:
			var context: Dictionary = candidate.get("terminalContext", {})
			if context.get("stage") != "REWARD_PENDING" \
					or context.get("consumed") != false \
					or context.get("encounterId") != TRIBULATION_CARD_ID:
				return {}
			var preferred := String(candidate.get("endingCandidate", "ascension"))
			var ending_id := preferred if _ending_eligible(preferred, context) else "ascension"
			if not _ending_eligible(ending_id, context):
				return {}
			var ending := _ending_source_card(ending_id)
			if ending.is_empty():
				return {}
			context["stage"] = "EPILOGUE"
			context["consumed"] = true
			context["endingId"] = ending_id
			candidate["terminalContext"] = context
			candidate["endingId"] = ending_id
			candidate["lifePhase"] = "EPILOGUE"
			var flags: Dictionary = candidate.get("flags", {})
			flags["game_ended"] = true
			candidate["flags"] = flags
			candidate["endingSourceSha"] = _content.source_sha256("cards:qi")
			candidate["pendingEndingCard"] = ending
			candidate["currentCardId"] = ending.id
			candidate["phase"] = "ENDING_PENDING"
			candidate["decisionCheckpoint"] = {"version": 1, "cardId": ending.id,
				"sourceCardId": TRIBULATION_CARD_ID, "turn": next_index,
				"decisionIndex": next_index}
			return candidate
		var arrival := arrival_card(candidate)
		if arrival.is_empty():
			return {}
		candidate["pendingRealmArrivalCard"] = arrival
		candidate["currentCardId"] = arrival.id
		candidate["phase"] = "REALM_ARRIVAL_PENDING"
		candidate["decisionCheckpoint"] = {"version": 1, "cardId": arrival.id,
			"sourceCardId": state.get("pendingRealmGateCard", {}).get("id"), "turn": next_index,
			"decisionIndex": next_index}
	else:
		candidate["currentCardId"] = ""
		candidate["phase"] = "FLOW_PENDING"
		candidate["decisionCheckpoint"] = {"version": 1, "cardId": null,
			"sourceCardId": card.id, "turn": next_index,
			"decisionIndex": next_index, "flowPending": true}
	return candidate


func _ending_eligible(ending_id: String, context: Dictionary) -> bool:
	var atlas: Variant = _content.read_module("world:truth_atlas")
	if not atlas is Dictionary:
		return false
	var config := {}
	for row in atlas.get("endings", []):
		if row is Dictionary and row.get("id") == ending_id:
			config = row
			break
	var gate: Dictionary = config.get("terminalGate", {})
	var snapshot: Dictionary = context.get("eligibilitySnapshot", {})
	if gate.get("id") != context.get("gateId") \
			or gate.get("requiredOutcome") != context.get("outcome") \
			or not gate.get("encounterIds", []).has(context.get("encounterId")) \
			or context.get("stage") != "REWARD_PENDING" \
			or context.get("consumed") != false \
			or context.get("victoryToken") != "combat:" + String(context.get("encounterInstanceId", "")) \
			or snapshot.get("version") != 1:
		return false
	var requirements: Dictionary = config.get("requirements", {})
	var realms := ["qi", "foundation", "golden", "nascent", "deity", "tribulation"]
	if realms.find(snapshot.get("realm")) < realms.find(requirements.get("minRealm", "qi")):
		return false
	if int(snapshot.get("maxBond", 0)) < int(requirements.get("minBond", 0)):
		return false
	for hypothesis_id in requirements.get("hypotheses", []):
		if int(snapshot.get("hypothesisConfidence", {}).get(hypothesis_id, 0)) < 100:
			return false
	for clue_id in requirements.get("clues", []):
		if not snapshot.get("clueIds", []).has(clue_id):
			return false
	return true


func _ending_source_card(ending_id: String) -> Dictionary:
	var row: Dictionary = _content.find("card", "ending_" + ending_id)
	var card: Variant = row.get("data")
	if row.get("sourcePath") != "data/cards/qi.json" \
			or not card is Dictionary or card.get("id") != "ending_" + ending_id \
			or card.get("type") != "DESTINY" \
			or not card.get("choices") is Dictionary:
		return {}
	return card.duplicate(true)


func ending_card(state: Dictionary) -> Dictionary:
	if state.get("phase") != "ENDING_PENDING" \
			or state.get("lifePhase") != "EPILOGUE" \
			or state.get("endingSourceSha") != _content.source_sha256("cards:qi"):
		return {}
	var context: Dictionary = state.get("terminalContext", {})
	var ending_id := String(state.get("endingId", ""))
	var card := _ending_source_card(ending_id)
	if context.get("stage") != "EPILOGUE" or context.get("consumed") != true \
			or context.get("endingId") != ending_id \
			or card.get("id") != state.get("currentCardId") \
			or JSON.parse_string(JSON.stringify(card)) != JSON.parse_string(
				JSON.stringify(state.get("pendingEndingCard"))):
		return {}
	return card


func continue_after_ending(state: Dictionary) -> Dictionary:
	var card := ending_card(state)
	var choice: Dictionary = card.get("choices", {}).get("left", {})
	if card.get("id") != "ending_ascension" \
			or choice.get("enterUpperRealm") != true \
			or choice.get("nextCard") != "pa_ascension_moment":
		return {}
	var upper := _upper_source_card("pa_ascension_moment")
	if upper.is_empty():
		return {}
	var candidate: Dictionary = state.duplicate(true)
	var next_index := int(candidate.get("turn", 0)) + 1
	candidate["choiceHistory"].append({"cardId": card.id, "cardType": "DESTINY",
		"direction": "left", "turn": int(candidate.turn),
		"decisionIndex": next_index, "tags": []})
	while candidate["choiceHistory"].size() > 30:
		candidate["choiceHistory"].pop_front()
	candidate["cardsPlayed"].append(card.id)
	candidate["turn"] = next_index
	candidate["runClock"]["decisionIndex"] = next_index
	var token := "decision:%s:choice:%s:%d" % [candidate.runClock.lifeId,
		card.id, next_index]
	if candidate.runClock.receipts.has(token):
		return {}
	candidate.runClock.receipts[token] = {"token": token,
		"decisionIndex": next_index, "sourceCardId": card.id, "kind": "choice"}
	MilestoneFlow.tick_seeds(candidate)
	candidate["terminalContext"]["stage"] = "UPPER_REALM"
	candidate["lifePhase"] = "ALIVE"
	candidate["flags"].erase("game_ended")
	candidate["flags"]["post_ascension_active"] = true
	candidate["flags"]["ascension_continued_this_life"] = true
	candidate["flags"]["post_ascension_next_card"] = upper.id
	candidate["currentLocation"] = "云中城"
	var locations: Array = candidate.get("visitedLocations", [])
	if not locations.has("云中城"):
		locations.append("云中城")
	candidate["visitedLocations"] = locations
	candidate.erase("pendingEndingCard")
	candidate["upperSourceSha"] = _content.source_sha256("cards:post_ascension")
	candidate["pendingUpperCard"] = upper
	candidate["currentCardId"] = upper.id
	candidate["phase"] = "UPPER_REALM_PENDING"
	candidate["decisionCheckpoint"] = {"version": 1, "cardId": upper.id,
		"sourceCardId": card.id, "turn": next_index,
		"decisionIndex": next_index}
	return candidate


func _upper_source_card(card_id: String) -> Dictionary:
	var row: Dictionary = _content.find("card", card_id)
	var card: Variant = row.get("data")
	if row.get("sourcePath") != "data/cards/post_ascension.json" \
			or not card is Dictionary or card.get("id") != card_id \
			or card.get("worldLayer") != "upper_realm" \
			or not card.get("choices") is Dictionary:
		return {}
	return card.duplicate(true)


func upper_card(state: Dictionary) -> Dictionary:
	if state.get("phase") != "UPPER_REALM_PENDING" \
			or state.get("flags", {}).get("post_ascension_active") != true \
			or state.get("upperSourceSha") != _content.source_sha256("cards:post_ascension"):
		return {}
	var card := _upper_source_card(String(state.get("currentCardId", "")))
	if card.is_empty() or JSON.parse_string(JSON.stringify(card)) != JSON.parse_string(
			JSON.stringify(state.get("pendingUpperCard"))):
		return {}
	return card


func upper_normal_choice_available(state: Dictionary, direction: String) -> bool:
	if state.get("phase") != "NORMAL_PENDING" \
			or state.get("flags", {}).get("post_ascension_active") != true \
			or state.get("upperSourceSha") != _content.source_sha256("cards:post_ascension"):
		return false
	var card := _upper_source_card(String(state.get("currentCardId", "")))
	var choice: Dictionary = card.get("choices", {}).get(direction, {})
	if card.get("type") != "NORMAL" or not choice.get("nextCard") is String \
			or _upper_source_card(String(choice.get("nextCard"))).is_empty() \
			or not choice.get("effects") is Dictionary:
		return false
	for key in choice.effects:
		if key not in ["cultivation", "daoHeart", "health", "fortune",
			"karmaGood", "karmaBad", "spiritStone", "lifespan", "maxDaoHeart"] \
				or not (choice.effects[key] is int or choice.effects[key] is float):
			return false
	return true


func settle_upper(state: Dictionary, direction: String,
		from_normal: bool = false) -> Dictionary:
	var card := _upper_source_card(String(state.get("currentCardId", ""))) \
		if from_normal and upper_normal_choice_available(state, direction) else upper_card(state)
	var choice: Dictionary = card.get("choices", {}).get(direction, {})
	if card.is_empty() or choice.is_empty() \
			or choice.get("effects", {}).get("reincarnate") == true:
		return {}
	var candidate: Dictionary = state.duplicate(true)
	var next_index := int(candidate.get("turn", 0)) + 1
	var effects: Dictionary = choice.get("effects", {})
	var apply := MilestoneFlow.new(_content)
	for key in effects:
		if key == "maxDaoHeart":
			candidate["maxDaoHeart"] = int(candidate.get("maxDaoHeart", 0)) + int(effects[key])
		elif not apply._apply_effect(candidate, String(key), effects[key]):
			return {}
	if choice.has("karmaSeed") and not apply._plant_seed(candidate, card,
			choice, direction, next_index):
		return {}
	candidate["choiceHistory"].append({"cardId": card.id, "cardType": card.type,
		"direction": direction, "turn": int(candidate.turn),
		"decisionIndex": next_index, "tags": card.get("tags", []).duplicate(true)})
	while candidate["choiceHistory"].size() > 30:
		candidate["choiceHistory"].pop_front()
	candidate["cardsPlayed"].append(card.id)
	candidate["turn"] = next_index
	candidate["runClock"]["decisionIndex"] = next_index
	var token := "decision:%s:choice:%s:%d" % [candidate.runClock.lifeId,
		card.id, next_index]
	if candidate.runClock.receipts.has(token):
		return {}
	candidate.runClock.receipts[token] = {"token": token,
		"decisionIndex": next_index, "sourceCardId": card.id, "kind": "choice"}
	MilestoneFlow.tick_seeds(candidate)
	candidate.erase("pendingUpperCard")
	var next_id := String(choice.get("nextCard", ""))
	if not next_id.is_empty():
		var next_card := _upper_source_card(next_id)
		if next_card.is_empty():
			return {}
		candidate["pendingUpperCard"] = next_card
		candidate["currentCardId"] = next_id
		candidate["phase"] = "UPPER_REALM_PENDING"
		candidate["flags"]["post_ascension_next_card"] = next_id
	else:
		candidate["currentCardId"] = ""
		candidate["phase"] = "FLOW_PENDING"
		candidate["flags"].erase("post_ascension_next_card")
	candidate["decisionCheckpoint"] = {"version": 1,
		"cardId": next_id if not next_id.is_empty() else null,
		"sourceCardId": card.id, "turn": next_index,
		"decisionIndex": next_index,
		"flowPending": next_id.is_empty()}
	return candidate


func epiphany_card(state: Dictionary) -> Dictionary:
	if state.get("realm") != "foundation" or state.get("path") not in [
			"sword", "spell", "body", "pill"]:
		return {}
	var path := String(state.path)
	var label := "奇绝术法根基"
	var choices := {}
	if path == "body":
		label = "不坏筋骨与沉稳气血"
		choices = {
			"left": _awakening_choice("领悟【金刚架】", "以筋骨承势，获得护盾与金刚劲。", "body_guard"),
			"right": _awakening_choice("领悟【重剑无锋】", "把肉身力量灌入重击，以势破巧。", "heavy_strike"),
			"down": _awakening_choice("领悟【太乙玄黄罩】", "将护体真元炼成可以保留的罡气。", "qi_shield")}
	elif path == "pill":
		label = "药理循环与炉火灵机"
		choices = {
			"left": _awakening_choice("炼成【回春丹】", "在战斗中恢复局内护体值；不能抹去战败伤势。", "pill_mending"),
			"right": _awakening_choice("炼成【回气丹】", "临阵恢复真元，延长一轮操作链。", "mana_potion"),
			"down": _awakening_choice("参悟【太乙玄黄罩】", "以丹气护体，建立长线防守。", "qi_shield")}
	elif path == "sword":
		label = "纯粹剑骨气劲"
		choices = {
			"left": _awakening_choice("领悟【太虚剑阵】", "以真气聚万剑，防御并获取剑意。", "sword_array"),
			"right": _awakening_choice("领悟【养剑诀】", "极聚锋芒，以宝剑养神。", "sword_intent"),
			"down": _awakening_choice("领悟【拔剑式】", "寒光一闪，极速攻击。", "draw_sword")}
	else:
		choices = {
			"left": _awakening_choice("领悟【五气朝元】", "凝聚五行法印，防御并累积层数。", "spell_gather"),
			"right": _awakening_choice("领悟【九天玄雷诀】", "以气血引天雷，雷云洗地！", "spell_nuke"),
			"down": _awakening_choice("领悟【灵力潮汐】", "根据法印层数，灵潮爆发大量抽牌。", "spell_tide")}
	return {"id": "epiphany_foundation", "title": "天道灌顶 · 本命觉醒",
		"description": "劫散云开，天降七彩祥光，浩瀚的天道灵气洗练周身！你在渡劫中展现出的【%s】引动了天道的本源共鸣。请挑选你的筑基期本命神通！" % label,
		"type": "NORMAL", "protagonistIdentity": {
			"consumer": "realm_arrival", "stageSource": "current_realm",
			"pathSource": "current_life_path"},
		"choices": choices, "sceneImage": "assets/cards/events/scene_qi_break_qi.png"}


func arrival_card(state: Dictionary) -> Dictionary:
	if state.get("realm") == "foundation":
		return epiphany_card(state)
	var realm := String(state.get("realm", ""))
	if realm not in ["golden", "nascent", "deity", "tribulation"] or state.get("path") not in [
			"sword", "spell", "body", "pill"] \
			or state.get("noncombatFlow", {}).get("realmGateSourceSha") != _content.source_sha256(MODULE):
		return {}
	var chapters: Variant = _content.read_module(MODULE)
	if not chapters is Dictionary:
		return {}
	var source: Dictionary = chapters.get(DEITY_CARD_ID if realm == "tribulation" else (
		NASCENT_CARD_ID if realm == "deity" else (
		GOLDEN_CARD_ID if realm == "nascent" else FOUNDATION_CARD_ID)), {})
	var visual: Dictionary = source.get("combatPresentation", {})
	if source.get("combatRewards", {}).get("breakSuccess") != true \
			or String(visual.get("sceneImage", "")).is_empty():
		return {}
	var path_names := {"sword": "剑修", "spell": "法修", "body": "体修", "pill": "丹修"}
	var profiles: Dictionary = {"golden": {"title": "金丹既成 · 本命丹纹",
		"description": "灵液凝作金丹，丹纹随你的功法流转。自此真元可以离体久存，新的敌人与机缘也将进入牌池。"},
		"nascent": {"title": "元婴出窍 · 神识初成",
		"description": "金丹碎而不灭，一点灵光化作元婴。神识越过肉身边界，你终于能看见天地灵机的脉络。"},
		"deity": {"title": "元神化生 · 神念初成",
		"description": "虚空雷罚散去，元婴化为元神。你先前认领的道路仍由自己承负，神念已能远探天地。"},
		"tribulation": {"title": "渡劫初成 · 业债已照",
		"description": "九重天雷散去，化神所认领的业债已由自身承担。你踏入渡劫之境，天道仍将检验往后的选择。"}}
	var profile: Dictionary = profiles[realm]
	var description := "%s\n\n当前道路：%s。气血与道心上限各提升 1，新境界卡池、Boss 与流派证明战已经开放。" % [
		String(profile.description), String(path_names[state.path])]
	var world_id: Variant = visual.get("visualWorldId")
	var material_id: Variant = visual.get("uiMaterialId")
	var world_contract: bool = world_id is String and not String(world_id).is_empty() \
		and material_id is String and not String(material_id).is_empty()
	return {"id": "realm_arrival_" + realm, "title": profile.title,
		"description": description, "type": "REALM_UPGRADE", "realm": realm,
		"tags": ["realm_upgrade", realm, state.path],
		"protagonistIdentity": {"consumer": "realm_arrival",
			"stageSource": "current_realm", "pathSource": "current_life_path"},
		"sceneImage": visual.sceneImage,
		"combatPresentationId": visual.get("presentationId"),
		"visualWorldId": world_id if world_contract else null,
		"uiMaterialId": material_id if world_contract else null,
		"visualSurface": "realm_arrival_ledger" if world_contract else null,
		"choices": {
			"left": {"text": "稳固道基", "desc": "以新境真元温养经脉，修为 +5。",
				"effects": {"cultivation": 5, "_setFlag": "realm_upgrade_" + realm + "_foundation"}},
			"right": {"text": "澄明道心", "desc": "回望破境所得，道心 +2。",
				"effects": {"daoHeart": 2, "_setFlag": "realm_upgrade_" + realm + "_daoheart"}},
			"down": {"text": "推演本命法", "desc": "把新境感悟沉入自身流派，气运 +2。",
				"effects": {"fortune": 2, "_setFlag": "realm_upgrade_" + realm + "_path"}}}}


func _awakening_choice(label: String, description: String, card_id: String) -> Dictionary:
	return {"text": label, "desc": description, "effects": {"deckCard": card_id},
		"nextCard": "q_foundation"}


func settle_epiphany(state: Dictionary, direction: String) -> Dictionary:
	var card := arrival_card(state)
	if state.get("phase") != "REALM_ARRIVAL_PENDING" or card.is_empty() \
			or JSON.parse_string(JSON.stringify(card)) != JSON.parse_string(
				JSON.stringify(state.get("pendingRealmArrivalCard"))) \
			or not card.choices.has(direction):
		return {}
	var base := int(state.turn)
	var candidate: Dictionary = state.duplicate(true)
	if card.id == "epiphany_foundation":
		var card_id := String(card.choices[direction].effects.deckCard)
		if not candidate.get("deck", []).has(card_id) \
				and not candidate.get("skillAcquisitions", {}).has(card_id):
			candidate = DeckAcquisition.new(_content).acquire_legacy(state,
				card_id, card.id, "legacy_deck_effect", base)
	else:
		var effects: Dictionary = card.choices[direction].effects
		var apply := MilestoneFlow.new(_content)
		for key in effects:
			if key == "_setFlag":
				var flags: Dictionary = candidate.get("flags", {})
				flags[String(effects[key])] = true
				candidate["flags"] = flags
			elif not apply._apply_effect(candidate, String(key), effects[key]):
				return {}
	if candidate.is_empty():
		return {}
	var next_index := base + 1
	candidate["choiceHistory"].append({"cardId": card.id,
		"cardType": "NORMAL", "direction": direction, "turn": base,
		"decisionIndex": next_index, "tags": []})
	while candidate["choiceHistory"].size() > 30:
		candidate["choiceHistory"].pop_front()
	candidate["cardsPlayed"].append(card.id)
	candidate["turn"] = next_index
	candidate["runClock"]["decisionIndex"] = next_index
	var token := "decision:%s:choice:%s:%d" % [candidate.runClock.lifeId,
		card.id, next_index]
	if candidate.runClock.receipts.has(token):
		return {}
	candidate["runClock"]["receipts"][token] = {"token": token,
		"decisionIndex": next_index, "sourceCardId": card.id, "kind": "choice"}
	MilestoneFlow.tick_seeds(candidate)
	candidate.erase("pendingRealmArrivalCard")
	candidate["currentCardId"] = ""
	candidate["phase"] = "FLOW_PENDING"
	candidate["decisionCheckpoint"] = {"version": 1, "cardId": null,
		"sourceCardId": card.id, "turn": next_index,
		"decisionIndex": next_index, "flowPending": true}
	return candidate


