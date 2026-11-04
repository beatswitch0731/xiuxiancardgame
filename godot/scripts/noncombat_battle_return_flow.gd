extends RefCounted

# Story-side terminal result consumer. The combat scene owns producing a result;
# only this candidate is committed by NoncombatDomain. Combat HP is never copied
# into persistent health. Victory delegates to the source-derived reward owner.
const EncounterDirector = preload("res://scripts/noncombat_encounter_director.gd")
const AvoidFlow = preload("res://scripts/noncombat_avoid_flow.gd")
const MilestoneFlow = preload("res://scripts/noncombat_milestone_flow.gd")
const VictoryFlow = preload("res://scripts/noncombat_battle_victory_flow.gd")
const QuestFlow = preload("res://scripts/noncombat_quest_flow.gd")
const StoryThreadFlow = preload("res://scripts/noncombat_story_threads_v2_flow.gd")
const DeathFlow = preload("res://scripts/noncombat_death_flow.gd")
const RealmGateFlow = preload("res://scripts/noncombat_realm_gate_flow.gd")
const FoundationDungeonFlow = preload("res://scripts/noncombat_foundation_dungeon_flow.gd")
const NascentRuinsFlow = preload("res://scripts/noncombat_nascent_ruins_flow.gd")
const HigherDungeonFlow = preload("res://scripts/noncombat_higher_linear_dungeon_flow.gd")
const SkillOpportunity = preload("res://scripts/noncombat_skill_opportunity.gd")
const FactionEvents = preload("res://scripts/noncombat_faction_events.gd")
const CompanionEvents = preload("res://scripts/noncombat_companion_events.gd")
const CatalogOutcome = preload("res://scripts/noncombat_catalog_outcome_flow.gd")
const TreasureAcquisition = preload("res://scripts/noncombat_treasure_acquisition.gd")
const RULE_PINS := {
	"game": "73d5038d1427433134a644e314d9d501d772c0ba79f67f61f9a46c3e4f8e093b",
	"coordinator": "a834065e633d44a9ef6a3a117ad9aee3291b0daa8abad672c20f38b2b11993b0",
	"state": "75e60d10e3284f96715c1ce9229c211215190a39eb10f920e0bb10187b741080",
	"director": "ff77500fe64a052a6b6014cfa02ad46f5071b20de36ac81184c970aec0418496",
}
var last_error := ""
var source_error := ""
var legacy_qi_spine_victory_replay := false
var _content: RefCounted
var _gateway: RefCounted

func _init(content: RefCounted, gateway: RefCounted) -> void:
	_content = content
	_gateway = gateway

func settle(state: Dictionary, result: Dictionary) -> Dictionary:
	last_error = ""
	source_error = ""
	var checked: Dictionary = _gateway.validate_result(state, result)
	if checked.get("ok") != true:
		source_error = _gateway.source_error
		return _reject(String(checked.get("error", "INVALID_RESULT")))
	var request: Dictionary = _gateway.build_request(state)
	var dungeon_boss: bool = request.get("sourceCardId") == "realm_guardian"
	if request.get("sourceCardId") in [RealmGateFlow.CARD_ID,
			RealmGateFlow.FOUNDATION_CARD_ID, RealmGateFlow.GOLDEN_CARD_ID,
			RealmGateFlow.NASCENT_CARD_ID, RealmGateFlow.DEITY_CARD_ID,
			RealmGateFlow.TRIBULATION_CARD_ID]:
		var gate := RealmGateFlow.new(_content)
		gate.legacy_qi_spine_victory_replay = legacy_qi_spine_victory_replay
		var gate_candidate := gate.settle_result(state, result, request)
		if gate_candidate.is_empty():
			return _reject(gate.last_error)
		return gate_candidate
	var offer: Dictionary = _gateway.source_offer(state)
	var encounter: Dictionary = _gateway.resolved_encounter(state, request.get("encounterId"), String(request.get("sourceCardId", "")))
	var config: Variant = _content.read_module("combat:encounter_director")
	if encounter.is_empty() or not config is Dictionary:
		return _reject("战果来源不可用")
	var outcome := String(result["outcome"])
	var choice: Dictionary = request.pendingResolution.choice
	var inline_quest: bool = encounter.get("inlineQuest", false)
	var inline_combat: bool = encounter.get("inlineCombat", false)
	var inline_bandit: bool = encounter.get("inlineBandit", false)
	var inline_thread: bool = encounter.get("inlineThread", false)
	var inline_nascent: bool = encounter.get("inlineNascent", false)
	var inline_trial: bool = encounter.get("inlineHigherDungeon", false)
	var inline_faction: bool = encounter.get("inlineFaction", false)
	var inline_companion: bool = encounter.get("inlineCompanion", false)
	# Teaching and the authored mountain fight have no extra non-victory effects.
	for key in ["defeatEffects", "fleeEffects", "karmaSeed", "defeatHealthFloor"]:
		if choice.has(key) and not (key == "karmaSeed" and state.has(
				"pendingCadenceCard")) and not inline_quest and not inline_combat and not inline_bandit and not inline_thread and not inline_nascent and not inline_trial and not inline_faction and not inline_companion and not dungeon_boss:
			return _reject("战斗新增结算字段尚未迁入：" + key)
	if (not choice.get("combatOutcomeLinks", {}).is_empty() or encounter.enemy.has("factionId")) \
			and not inline_combat and not inline_nascent and not dungeon_boss \
			and not inline_faction and not inline_companion and not state.has(
				"pendingCadenceCard"):
		return _reject("该战果的势力结算尚未迁入")
	var candidate: Dictionary = state.duplicate(true)
	var base := int(request.baseDecisionIndex)
	var next_index := base + 1
	var source_id := String(request.sourceCardId)
	var owner := String(request.encounterInstanceId)
	var injury := 0
	if outcome == "defeat":
		injury = mini(maxi(0, int(candidate.attributes.health) - int(choice.get(
			"defeatHealthFloor", encounter.get("defeatHealthFloor", 0)))),
			int(choice.get("defeatHealthLoss", encounter.get("defeatHealthLoss", 1))))
		candidate.attributes.health = int(candidate.attributes.health) - injury
	elif outcome == "flee" and not inline_quest and not inline_combat and not inline_bandit and not inline_thread and not inline_nascent and not inline_trial:
		candidate.resources.lifespan = maxi(0, int(candidate.resources.lifespan) - 1)
	var canonical := {}
	for key in ["contractVersion", "encounterInstanceId", "sourceCardId", "encounterId",
			"sourceContentHash", "outcome", "combatReceipt"]:
		canonical[key] = result[key]
	canonical["postBattleState"] = {"encounterInstanceId": owner,
		"terminal": true, "combatPhase": outcome.to_upper()}
	var record := {"result": canonical, "warningDirection": request.warningChoiceDirection,
		"decisionIndex": next_index, "defeatHealthLoss": injury}
	if dungeon_boss or inline_nascent or inline_trial:
		record["sourceCombat"] = request.pendingResolution.combatCard.duplicate(true)
	if inline_thread or inline_bandit or source_id == "q_sword_3":
		record["sourceDirection"] = request.direction
		record["sourceCombat"] = encounter.duplicate(true)
	if outcome == "victory":
		var victory_flow := VictoryFlow.new(_content)
		var rewards: Dictionary = victory_flow.apply_rewards(candidate, encounter,
			choice, source_id, next_index)
		if rewards.is_empty():
			return _reject("胜利奖励来源或效果尚未接通")
		if inline_bandit:
			var skill := SkillOpportunity.new(_content)
			var preview: Dictionary = skill.preview(candidate)
			if preview.is_empty():
				return _reject("虎娘传功来源不可用")
			if preview.get("eligible") == true:
				var acquired: Dictionary = skill.acquire_guaranteed(candidate, next_index)
				if acquired.is_empty():
					return _reject("虎娘必得招式未能取得")
				candidate = acquired
		candidate["_mentorCultivationEvents"] = victory_flow.cultivation_events.duplicate()
		record["victoryRewards"] = rewards
		if inline_combat or inline_bandit or inline_thread or inline_nascent or inline_trial or inline_companion or dungeon_boss:
			record["sourceVictoryRewards"] = victory_flow.inline_summary.duplicate(true)
	if inline_nascent and outcome != "victory":
		var nascent_effects: Dictionary = choice.get(
			"defeatEffects", {}) if outcome == "defeat" else choice.get("fleeEffects", {})
		for key in nascent_effects:
			if not MilestoneFlow.new(_content)._apply_effect(candidate,
					String(key), nascent_effects[key], source_id, next_index):
				return _reject("元婴战斗非胜效果未能结算")
	if inline_trial and outcome != "victory":
		var trial_effects: Dictionary = choice.get(
			"defeatEffects", {}) if outcome == "defeat" else choice.get("fleeEffects", {})
		for key in trial_effects:
			if not MilestoneFlow.new(_content)._apply_effect(candidate,
					String(key), trial_effects[key], source_id, next_index):
				return _reject("渡劫试炼非胜效果未能结算")
		if not HigherDungeonFlow.new(_content).complete(candidate,
				"failure" if outcome == "defeat" else "abandon", next_index):
			return _reject("渡劫试炼战败或撤离归属无效")
	if inline_nascent and source_id == "ar_boss" and outcome != "victory":
		if not NascentRuinsFlow.new(_content).complete(candidate,
				"failure" if outcome == "defeat" else "abandon", next_index):
			return _reject("元婴遗迹战败或撤离归属无效")
	if inline_nascent and source_id == "n_hunt" and not _settle_nascent_hunter_world(
			candidate, encounter, outcome, next_index):
		return _reject("元婴猎杀者势力或因果未能结算")
	if inline_faction and not FactionEvents.new(_content).apply_battle_outcome(
			candidate, encounter, outcome):
		return _reject("武盟请关的势力战果未能结算")
	if inline_companion:
		var links: Dictionary = encounter.get("outcomeLinks", {}).get(outcome, {})
		var relation: Dictionary = links.get("companionEffects", {})
		if relation.get("compId") != "jian_linger" \
				or not CompanionEvents.new(_content)._apply_companion_effects(candidate,
					request.pendingResolution.sourceCard, {"text": request.pendingResolution.choice.get("text", ""),
						"companionEffects": relation}, "left", next_index):
			return _reject("剑灵儿剑冢战果的道侣关系未能结算")
	if dungeon_boss and outcome != "victory":
		if not FoundationDungeonFlow.new(_content).complete(candidate,
				"failure" if outcome == "defeat" else "abandon", next_index):
			return _reject("秘境守卫战败或撤离归属无效")
	if inline_quest:
		var before_quest_cult := int(candidate.attributes.cultivation)
		var quest := QuestFlow.new(_content)
		if not quest.apply_battle_outcome(candidate, request.pendingResolution.sourceCard, choice, outcome, next_index):
			return _reject("任务战果未能结算：" + quest.last_error)
		if int(candidate.attributes.cultivation) > before_quest_cult:
			if not candidate.has("_mentorCultivationEvents"):
				candidate["_mentorCultivationEvents"] = []
			candidate["_mentorCultivationEvents"].append(
				int(candidate.attributes.cultivation) - before_quest_cult)
		if outcome == "victory":
			# The source summary spans base spoils, choice effects and quest rewards.
			var rewards := {"cultivation": int(candidate.attributes.cultivation) - int(state.attributes.cultivation),
				"spiritStone": int(candidate.resources.spiritStone) - int(state.resources.spiritStone)}
			for key in ["karmaGood", "fortune"]:
				var delta := int(candidate.attributes[key]) - int(state.attributes[key])
				if delta != 0:
					rewards[key] = delta
			record["victoryRewards"] = rewards
	if inline_bandit and outcome != "victory":
		var bandit_effects: Dictionary = choice.get(
			"defeatEffects", {}) if outcome == "defeat" else choice.get("fleeEffects", {})
		var effect_key := "daoHeart" if outcome == "defeat" else "lifespan"
		if bandit_effects.size() != 1 or int(bandit_effects.get(effect_key, 0)) != -1 \
				or not MilestoneFlow.new(_content)._apply_effect(candidate, effect_key,
					-1, source_id, next_index):
			return _reject("虎娘战败或撤离效果来源无效")
	if inline_combat:
		var effects: Dictionary = choice.get("defeatEffects", {}) if outcome == "defeat" \
			else choice.get("fleeEffects", {}) if outcome == "flee" else {}
		if source_id == "f_mission":
			var expected_key := "daoHeart" if outcome == "defeat" else "lifespan"
			if outcome != "victory" and (effects.size() != 1 \
					or int(effects.get(expected_key, 0)) != -1 \
					or not MilestoneFlow.new(_content)._apply_effect(candidate,
						expected_key, -1, source_id, next_index)):
				return _reject("宗门任务战败或撤离效果来源无效")
		else:
			if outcome != "victory" and (effects.size() != 1 \
					or int(effects.get("daoHeart", 0)) != -1 \
					or not MilestoneFlow.new(_content)._apply_effect(candidate,
						"daoHeart", -1, source_id, next_index)):
				return _reject("同门比试战败或撤离效果来源无效")
			if not _settle_fellow_world(candidate, encounter, outcome, next_index):
				return _reject("同门比试的势力或因果结算失败")
	if inline_thread:
		var thread_effects: Dictionary = choice.get("defeatEffects", {}) if outcome == "defeat" \
			else choice.get("fleeEffects", {}) if outcome == "flee" else {}
		var last_lesson: bool = source_id == "thread_last_lesson_n3"
		if last_lesson:
			var expected: Dictionary = {"knowledge": 1,
				"npc_relation:jian_linger": 1,
				"playerLocation": "upper_realm_heaven_gate"} if outcome == "defeat" \
				else {"fortune": -1, "npc_relation:jian_linger": -1,
					"playerLocation": "upper_realm_heaven_gate"} if outcome == "flee" else {}
			if JSON.parse_string(JSON.stringify(thread_effects)) != \
					JSON.parse_string(JSON.stringify(expected)):
				return _reject("最后一课战果效果与来源不符")
		elif outcome == "defeat" and (thread_effects.size() != 1 \
				or int(thread_effects.get("daoHeart", 0)) != -1) \
				or outcome == "flee" and (thread_effects.size() != 1 \
				or int(thread_effects.get("lifespan", 0)) != -1):
			return _reject("故事线程战斗非胜效果与来源不符")
		for key in thread_effects:
			var applied: bool = StoryThreadFlow.new(_content)._apply_effect(candidate,
					String(key), thread_effects[key]) if last_lesson else \
				MilestoneFlow.new(_content)._apply_effect(candidate,
					String(key), thread_effects[key], source_id, next_index)
			if not applied:
				return _reject("故事线程战斗非胜效果未能结算")
		candidate = StoryThreadFlow.new(_content).settle_combat(candidate,
			request.direction, outcome, next_index)
		if candidate.is_empty():
			return _reject("故事线程战果未能推进到终幕")
	if state.has("pendingCadenceCard") and not inline_companion and not inline_faction:
		var catalog_outcome := CatalogOutcome.new(_content)
		if not catalog_outcome.apply(candidate, request.pendingResolution.sourceCard,
				choice, encounter, outcome, next_index):
			return _reject(catalog_outcome.last_error)
	# game._resolveCombatOutcome applies choice defeatEffects before checkDeath.
	# Clamping daoHeart to the reduced cap first would charge its penalty twice.
	if int(candidate.attributes.daoHeart) > 0 and int(candidate.attributes.health) <= 0 \
			and int(candidate.maxHealth) > 1 and int(candidate.maxDaoHeart) > 1:
		candidate.maxHealth = int(candidate.maxHealth) - 1
		candidate.maxDaoHeart = int(candidate.maxDaoHeart) - 1
		candidate.attributes.health = 1
		candidate.attributes.daoHeart = mini(int(candidate.attributes.daoHeart), int(candidate.maxDaoHeart))
	if int(candidate.attributes.daoHeart) <= 0 \
			or int(candidate.attributes.health) <= 0 \
			or int(candidate.resources.lifespan) <= 0:
		var revival: Dictionary = TreasureAcquisition.new(
			_content).revive_equipped(candidate)
		if revival.is_empty():
			return _reject("战果复活秘宝来源或所有权无效")
		if revival.get("revived") == true:
			candidate = revival["state"]
	var fatal_battle: bool = int(candidate.attributes.daoHeart) <= 0 \
		or int(candidate.attributes.health) <= 0 or int(candidate.resources.lifespan) <= 0
	var result_card := {} if fatal_battle else _result_card(record, encounter, candidate)
	if not fatal_battle and result_card.is_empty():
		return _reject("战果原图缺失或来源变化")
	if state.has("pendingCadenceCard"):
		var director: Dictionary = EncounterDirector.new(_content).settled(state, request.pendingResolution.sourceCard, outcome)
		if director.is_empty():
			return _reject("累计遭遇排期来源无效")
		candidate.noncombatFlow.encounterDirectorState = director
	elif encounter.get("teachingEncounter") == true:
		var director := AvoidFlow.new(_content, _gateway)._director_state(state, offer, encounter, config, base)
		if director.is_empty():
			return _reject("遭遇排期来源无效")
		var minimum := int(config.get("cadenceDecisionMin", 0))
		var maximum := int(config.get("cadenceDecisionMax", 0))
		var interval := minimum + int(AvoidFlow.new(_content, _gateway)._fnv32(
			"0|%s|%s|1" % [request.realm, request.path]) % (maximum - minimum + 1))
		var accepted: Dictionary = director.history.pop_back()
		accepted.erase("nextInterval")
		accepted["event"] = "accepted"
		accepted["direction"] = "left"
		director.history.append(accepted)
		var resolved: Dictionary = accepted.duplicate(true)
		resolved.erase("direction")
		resolved.merge({"event": "resolved", "outcome": outcome, "nextInterval": interval}, true)
		director.history.append(resolved)
		director["firstTeachingStatus"] = "resolved"
		director["lastResolvedDecision"] = base
		director["nextDueDecision"] = base + 1 + interval
		var progress: Dictionary = director.realmProgress[request.realm]
		progress["avoidedIds"] = []
		progress["resolvedIds"] = [request.encounterId]
		progress.counts["ordinary"] = 1
		candidate["noncombatFlow"] = {"version": 1, "scope": "first_session_combat",
			"sourceContentHash": request.sourceContentHash, "encounterDirectorState": director,
			"karmaClockVersion": 1, "lifespanCostVersion": 1, "resumePolicy": "await_general_flow"}
	if not candidate.get("noncombatFlow") is Dictionary:
		candidate["noncombatFlow"] = {}
	candidate["noncombatFlow"]["sourceContentHash"] = request.sourceContentHash
	candidate["battleReturnRulePins"] = RULE_PINS.duplicate()
	var history: Array = candidate.get("battleResultHistory", []).duplicate(true)
	history.append(record)
	candidate["battleResultHistory"] = history
	var source: Dictionary = request.pendingResolution.sourceCard
	var tags: Array = ["combat", "encounter", encounter.category] if encounter.get("teachingEncounter") == true else source.get("tags", [])
	candidate.choiceHistory.append({"cardId": source_id, "cardType": source.type,
		"direction": request.direction, "turn": base, "decisionIndex": next_index,
		"tags": tags, "combatOutcome": outcome})
	while candidate.choiceHistory.size() > 30:
		candidate.choiceHistory.pop_front()
	candidate.recentCardTags.append_array(tags)
	while candidate.recentCardTags.size() > 20:
		candidate.recentCardTags.pop_front()
	candidate.cardsPlayed.append(source_id)
	candidate["turn"] = next_index
	candidate.runClock.decisionIndex = next_index
	var token := "decision:%s:combat:%s" % [request.lifeId, owner]
	candidate.runClock.receipts[token] = {"token": token, "decisionIndex": next_index,
		"sourceCardId": source_id, "kind": "combat"}
	candidate.runClock.receipts["battle:" + owner] = {"outcome": outcome,
		"decisionIndex": next_index, "sourceCardId": source_id, "defeatHealthLoss": injury}
	MilestoneFlow.tick_seeds(candidate)
	candidate.erase("pendingCadenceCard")
	candidate.erase("pendingBattle")
	candidate.erase("pendingDungeonBossDirection")
	candidate.erase("pendingThreadCombatDirection")
	candidate.erase("encounterActionHistory")
	if fatal_battle:
		var death := DeathFlow.new(_content).prepare_death(candidate, source_id)
		if death.is_empty():
			return _reject("战果死亡卡来源或复活边界无效")
		return death
	candidate["pendingBattleResultCard"] = result_card
	candidate["currentCardId"] = result_card.id
	candidate["phase"] = "BATTLE_RESULT_PENDING"
	candidate["decisionCheckpoint"] = {"version": 1, "cardId": result_card.id,
		"sourceCardId": source_id, "turn": next_index, "decisionIndex": next_index}
	return candidate

func card(state: Dictionary) -> Dictionary:
	last_error = ""
	source_error = ""
	if state.get("phase") == "BATTLE_RESULT_PENDING" \
			and state.get("pendingRealmGateCard") is Dictionary:
		var gate_card := RealmGateFlow.new(_content).result_card(state)
		return gate_card if gate_card == state.get("pendingBattleResultCard") else {}
	if state.get("phase") != "BATTLE_RESULT_PENDING" or state.get("battleReturnRulePins") != RULE_PINS \
			or state.get("noncombatFlow", {}).get("sourceContentHash") != _gateway.source_content_hash():
		return {}
	var history: Variant = state.get("battleResultHistory")
	if not history is Array or history.is_empty() or not history.back() is Dictionary:
		return {}
	var record: Dictionary = history.back()
	var result: Dictionary = record.get("result", {})
	var encounter: Dictionary = _gateway.resolved_encounter(state, result.get("encounterId"), String(result.get("sourceCardId", "")))
	if encounter.is_empty():
		source_error = _gateway.source_error
		return {}
	var expected := _result_card(record, encounter, state)
	if expected.is_empty() or expected.get("id") != state.get("currentCardId") \
			or JSON.parse_string(JSON.stringify(expected)) != JSON.parse_string(JSON.stringify(state.get("pendingBattleResultCard"))):
		return _reject("战果卡或来源原图校验失败")
	return expected

func dismiss(state: Dictionary, direction: String) -> Dictionary:
	if state.get("pendingRealmGateCard") is Dictionary:
		return RealmGateFlow.new(_content).dismiss(state, direction)
	var current := card(state)
	if current.is_empty() or not current.get("choices", {}).has(direction):
		return {}
	var candidate: Dictionary = state.duplicate(true)
	var victory: bool = current.get("id") == "combat_reward"
	if victory:
		candidate = VictoryFlow.new(_content).acquire(state, current, direction)
		if candidate.is_empty():
			return _reject("择法未能取得对应功法")
	var base := int(candidate.turn)
	var next_index := base + 1
	var source_id := String(current.id)
	candidate.choiceHistory.append({"cardId": source_id, "cardType": "NORMAL", "direction": direction,
		"turn": base, "decisionIndex": next_index, "tags": []})
	while candidate.choiceHistory.size() > 30:
		candidate.choiceHistory.pop_front()
	candidate.cardsPlayed.append(source_id)
	candidate["turn"] = next_index
	candidate.runClock.decisionIndex = next_index
	var token := "decision:%s:choice:%s:%d" % [candidate.runClock.lifeId, source_id, next_index]
	candidate.runClock.receipts[token] = {"token": token, "decisionIndex": next_index,
		"sourceCardId": source_id, "kind": "choice"}
	MilestoneFlow.tick_seeds(candidate)
	candidate.erase("pendingBattleResultCard")
	candidate.erase("pendingFactionCard")
	candidate.erase("pendingCompanionCard")
	candidate["currentCardId"] = ""
	candidate["phase"] = "FLOW_PENDING"
	candidate["decisionCheckpoint"] = {"version": 1, "cardId": null, "sourceCardId": source_id,
		"turn": next_index, "decisionIndex": next_index, "flowPending": true}
	if victory and current.choices[direction].has("nextCard"):
		candidate["authoredFirstSessionNext"] = current.choices[direction].nextCard
	if victory and not state.get("battleResultHistory", []).is_empty() \
			and state.battleResultHistory.back().get("result", {}).get(
				"sourceCardId") == "realm_guardian":
		if not FoundationDungeonFlow.new(_content).after_boss_victory(
				candidate, next_index):
			return _reject("秘境守卫胜利后未能进入宝藏节点")
	if victory and not state.get("battleResultHistory", []).is_empty() \
			and state.battleResultHistory.back().get("result", {}).get(
				"sourceCardId") == "ar_boss":
		if not NascentRuinsFlow.new(_content).complete(candidate, "success", next_index):
			return _reject("元婴遗迹守关胜利未能完成秘境")
	if victory and not state.get("battleResultHistory", []).is_empty() \
			and state.battleResultHistory.back().get("result", {}).get(
				"sourceCardId") == "it_combat":
		if not HigherDungeonFlow.new(_content).after_trial_victory(candidate, next_index):
			return _reject("渡劫仙影胜利后未能进入宝藏节点")
	return candidate

func _settle_fellow_world(candidate: Dictionary, encounter: Dictionary,
		outcome: String, decision: int) -> bool:
	var source: Variant = _content.read_module("world:factions")
	if not source is Dictionary or encounter.get("enemy", {}).get("factionId") != "qingyun_sword":
		return false
	var factions: Dictionary = candidate.get("factionProgress", {})
	if factions.is_empty():
		factions = QuestFlow.new(_content)._initial_faction_progress(source)
	if factions.is_empty() or not factions.get("reputations") is Dictionary:
		return false
	if outcome == "victory":
		var before := int(factions.reputations.get("qingyun_sword", 0))
		var after := clampi(before - 3, -100, 100)
		factions.reputations["qingyun_sword"] = after
		if after != before:
			candidate["tradeRoutePendingEvents"] = candidate.get("tradeRoutePendingEvents", []).duplicate(true)
			candidate.tradeRoutePendingEvents.append({"kind": "reputation",
				"factionId": "qingyun_sword", "oldValue": before, "newValue": after})
	elif outcome == "defeat":
		for faction in source.get("factions", []):
			if not faction is Dictionary or faction.get("id") == "xuesha_sect":
				continue
			var faction_id := String(faction.get("id", ""))
			if not factions.reputations.has(faction_id):
				return false
			var before := int(factions.reputations[faction_id])
			var after := clampi(before - 2, -100, 100)
			factions.reputations[faction_id] = after
			if after != before:
				candidate["tradeRoutePendingEvents"] = candidate.get("tradeRoutePendingEvents", []).duplicate(true)
				candidate.tradeRoutePendingEvents.append({"kind": "reputation",
					"factionId": faction_id, "oldValue": before, "newValue": after})
	candidate["factionProgress"] = factions
	if outcome != "victory":
		return true
	var context := {"enemyId": null, "enemyName": encounter.enemy.name,
		"factionId": "qingyun_sword", "tier": int(encounter.enemy.tier)}
	for seed in candidate.get("karmaSeeds", []):
		if seed is Dictionary and seed.get("id") == "combatGlory":
			if 6 < int(seed.get("delay", 999)):
				seed["delay"] = 6
				seed["priority"] = maxi(int(seed.get("priority", 0)), 2)
			if not seed.get("context") is Dictionary:
				seed["context"] = context
			if not seed.get("originOutcome"):
				seed["originOutcome"] = "victory"
			candidate.karmaPromiseFlags["combatGlory"] = true
			candidate.flags["combatGlory"] = true
			return true
	candidate.karmaSeeds.append({"id": "combatGlory", "seedType": "karma",
		"delay": 9, "realm": null, "path": null, "priority": 2,
		"originTurn": decision, "originLife": int(candidate.get("lifeCount", 0)),
		"originCard": "q_fellow", "originChoice": "right",
		"originThread": null, "originQuest": null, "originOutcome": "victory",
		"description": null, "tags": [], "payoffEvent": null,
		"context": context, "consumed": false, "mergeGroup": null,
		"cancelGroup": null})
	candidate.karmaPromiseFlags["combatGlory"] = true
	candidate.flags["combatGlory"] = true
	return true


func _settle_nascent_hunter_world(candidate: Dictionary, encounter: Dictionary,
		outcome: String, decision: int) -> bool:
	var source: Variant = _content.read_module("world:factions")
	if not source is Dictionary or encounter.get("enemy", {}).get("factionId") != "xuesha_sect":
		return false
	if outcome in ["victory", "defeat"]:
		var factions: Dictionary = candidate.get("factionProgress", {})
		if factions.is_empty():
			factions = QuestFlow.new(_content)._initial_faction_progress(source)
		if factions.is_empty() or not factions.get("reputations") is Dictionary:
			return false
		for faction in source.get("factions", []):
			if not faction is Dictionary or not faction.get("id") is String:
				return false
			var faction_id := String(faction.id)
			if not factions.reputations.has(faction_id):
				return false
			var delta := (-10 if faction_id == "xuesha_sect" else 5) \
				if outcome == "victory" else -2
			var before := int(factions.reputations[faction_id])
			var after := clampi(before + delta, -100, 100)
			factions.reputations[faction_id] = after
			if after != before:
				candidate["tradeRoutePendingEvents"] = candidate.get(
					"tradeRoutePendingEvents", []).duplicate(true)
				candidate.tradeRoutePendingEvents.append({"kind": "reputation",
					"factionId": faction_id, "oldValue": before, "newValue": after})
		candidate["factionProgress"] = factions
	if outcome != "victory":
		return true
	if not candidate.get("karmaPromiseFlags") is Dictionary:
		candidate["karmaPromiseFlags"] = {}
	if not candidate.get("flags") is Dictionary:
		candidate["flags"] = {}
	var seeds: Array = candidate.get("karmaSeeds", [])
	var context := {"enemyId": encounter.enemy.get("id"),
		"enemyName": encounter.enemy.get("name"),
		"factionId": "xuesha_sect", "tier": int(encounter.enemy.get("tier", 2))}
	for seed in seeds:
		if seed is Dictionary and seed.get("id") == "combatGlory":
			if 6 < int(seed.get("delay", 999)):
				seed.delay = 6
				seed.priority = maxi(int(seed.get("priority", 0)), int(context.tier))
			if not seed.get("context") is Dictionary:
				seed.context = context
			if not seed.get("originOutcome"):
				seed.originOutcome = "victory"
			candidate.karmaPromiseFlags["combatGlory"] = true
			candidate.flags["combatGlory"] = true
			return true
	seeds.append({"id": "combatGlory", "seedType": "karma",
		"delay": 5, "realm": null, "path": null,
		"priority": maxi(2, int(context.tier)), "originTurn": decision,
		"originLife": int(candidate.get("lifeCount", 0)),
		"originCard": "n_hunt", "originChoice": "left",
		"originThread": null, "originQuest": null, "originOutcome": "victory",
		"description": null, "tags": [], "payoffEvent": null,
		"context": context, "consumed": false, "mergeGroup": null,
		"cancelGroup": null})
	candidate["karmaSeeds"] = seeds
	candidate.karmaPromiseFlags["combatGlory"] = true
	candidate.flags["combatGlory"] = true
	return true


func _encounter(encounter_id: String) -> Dictionary:
	var source: Variant = _content.read_module("combat:encounters")
	if source is Dictionary:
		for row in source.get("encounters", []):
			if row is Dictionary and row.get("id") == encounter_id and row.get("teachingEncounter") == true:
				return row
	return {}

func _result_card(record: Dictionary, encounter: Dictionary, state: Dictionary = {}) -> Dictionary:
	if encounter.is_empty():
		return {}
	if record.get("result", {}).get("outcome") == "victory":
		var victory := VictoryFlow.new(_content)
		var projected: Dictionary = victory.card(state, record, encounter)
		source_error = victory.source_error
		return projected
	var result: Dictionary = record.get("result", {})
	var source_id := String(result.get("sourceCardId", ""))
	var outcome := String(result.get("outcome", ""))
	if outcome not in ["defeat", "flee"] or (source_id != "encounter_card_" + String(encounter.id) \
			and not (source_id == "q_mountain_shadow_approach" and encounter.id == "enc_patrol_qi_mountain_shadow") \
			and not (source_id in ["q_whiteFox_3", "q_sword_3"] and encounter.get("inlineQuest") == true) \
			and not (source_id in ["q_fellow", "f_mission", "n_hunt", "ar_boss"] \
				and encounter.get("inlineCombat") == true)
			and not (source_id in ["n_hunt", "ar_boss"] \
				and encounter.get("inlineNascent") == true)
			and not (source_id == "it_combat" \
				and encounter.get("inlineHigherDungeon") == true)
			and not (source_id == "ds_female_bandit" \
				and encounter.get("inlineBandit") == true)
			and not (source_id == "faction_wumeng_gatekeeper_call" \
				and encounter.get("inlineFaction") == true)
			and not (source_id == "comp_jian_linger_jle_8_sword_tomb_old_master" \
				and encounter.get("inlineCompanion") == true)
			and not (source_id == "realm_guardian" \
				and encounter.get("inlineDungeonBoss") == true)
		and not (source_id in ["thread_ab_village_3", "thread_sword_tomb_2",
			"thread_last_lesson_n3"] \
				and encounter.get("inlineThread") == true)):
		return {}
	var presentations: Variant = _content.read_module("combat:encounter_presentations")
	if not presentations is Dictionary:
		return {}
	var inline: bool = encounter.get("inlineQuest") == true or encounter.get("inlineCombat") == true or encounter.get("inlineBandit") == true or encounter.get("inlineThread") == true or encounter.get("inlineDungeonBoss") == true or encounter.get("inlineNascent") == true or encounter.get("inlineHigherDungeon") == true or encounter.get("inlineFaction") == true or encounter.get("inlineCompanion") == true
	var visual: Dictionary = encounter.combatPresentation if inline else presentations.get("presentations", {}).get(encounter.id, {})
	var authored: Dictionary = encounter.get("combatOutcomePresentation", {}).get(outcome, {})
	var scene_image := String(authored.get("sceneImage", encounter.get("sceneImage", "") if inline else visual.get("sceneImage", encounter.get("sceneImage", ""))))
	var art: Dictionary = _content.asset_status(scene_image)
	if not art.get("shaVerified", false) or not art.get("textureLoadable", false):
		source_error = "SOURCE_UNAVAILABLE" if art.get("fileExists") == false else "SOURCE_MISMATCH"
		return {}
	var enemy := String(encounter.enemy.name)
	var result_card := {"id": ("combat_fled_" if outcome == "flee" else "combat_defeat_") + source_id,
		"type": "NORMAL", "sceneImage": scene_image,
		"combatPresentationId": visual.get("presentationId"),
		"title": "脱离战场" if outcome == "flee" else "重伤退却",
		"description": ("你抓住%s攻势转换的间隙退出战局。道路暂时保住了，但这场未完的冲突会留下后果。" % enemy) if outcome == "flee" else (
			"%s压过了你的最后一轮攻势。局内护体值已经耗尽，离场伤势使真实气血减少 %d 点；任务没有完成，胜利奖励也不会发放。" % [enemy, int(record.get("defeatHealthLoss", -1))]),
		"choices": {"down": {"text": "收敛气息，继续前行" if outcome == "flee" else "稳住伤势，记下此败", "effects": {}}}}
	for key in ["title", "description"]:
		if authored.has(key):
			result_card[key] = authored[key]
	return result_card

func _reject(message: String) -> Dictionary:
	last_error = message
	return {}
