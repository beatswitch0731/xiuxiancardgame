extends RefCounted
const LegacyFragmentFlow = preload("res://scripts/noncombat_legacy_fragment_flow.gd")
const PathSkillFlow = preload("res://scripts/noncombat_path_skill_flow.gd")

# Source JSON supplies quest triggers and cards. The white fox chain retains
# its NPC-specific settlement; the foundation sword chain uses its own state.
const QUEST_MODULE := "quests:white_fox"
const FOUNDATION_QUEST_MODULE := "quests:sword_legacy"
const FOUNDATION_QUEST_MODULES := {"sword": FOUNDATION_QUEST_MODULE,
	"body": "quests:body_tribulation", "spell": "quests:spell_codex",
	"pill": "quests:pill_master"}
const TIANSHU_MODULE := "quests:tianshu_codex"
const WorldContinuity = preload("res://scripts/noncombat_world_continuity.gd")
const MilestoneFlow = preload("res://scripts/noncombat_milestone_flow.gd")
const OpportunityFlow = preload("res://scripts/noncombat_opportunity_acquisition.gd")
const NormalChoicePolicy = preload("res://scripts/noncombat_normal_choice_policy.gd")
const BATTLE_RULE_PINS := {
	"quest": "4ff9fbeb8baed1ab4c5b26e65b80124457516d9a9eb55bb14d44bd3def20f4a0",
	"karma": "0d977405787abc77d42712e1d3661412d3ca3983bdde5eca008263066acf3123",
}

var _content: RefCounted
var last_error := ""
var legacy_entry_replay := false
var legacy_tianshu_replay := false
var replay_first_foundation_quest_module := ""
var opportunity_flow: RefCounted


func _init(content: RefCounted) -> void:
	_content = content
	opportunity_flow = OpportunityFlow.new(content)


func resume(state: Dictionary) -> Dictionary:
	last_error = ""
	if state.get("phase") != "FLOW_PENDING" \
			or state.get("noncombatFlow", {}).get("scope") not in [
				"first_session_avoid", "first_session_combat", "rebirth_new_life"]:
		return {}
	var active_quests: Array = state.get("questState", {}).get("activeQuests", [])
	if state.get("realm") == "foundation" and (active_quests.is_empty() \
			or active_quests[0].get("questId") != "white_fox_line"):
		return _resume_foundation(state)
	var flow: Dictionary = state.get("noncombatFlow", {})
	var chapter_sha: String = _content.source_sha256("cards:chapter_milestones")
	var causal_sha: String = _content.source_sha256("narrative:causal_graph")
	if chapter_sha.length() != 64 or causal_sha.length() != 64:
		last_error = "炼气章节来源数据未通过校验"
		return {}
	var rebirth_before_chapter: bool = flow.get("scope") == "rebirth_new_life" \
		and int(state.get("lifeCount", 0)) > 0 \
		and state.get("chapterProgress", {}).get("triggeredMilestones", {}).get("qi", []).is_empty() \
		and not flow.has("milestoneSourceSha") and not flow.has("causalGraphSourceSha")
	if not rebirth_before_chapter and (flow.get("milestoneSourceSha") != chapter_sha \
			or flow.get("causalGraphSourceSha") != causal_sha):
		last_error = "炼气章节来源数据未通过校验"
		return {}
	var source_sha: String = _content.source_sha256(QUEST_MODULE)
	var source: Variant = _content.read_module(QUEST_MODULE)
	if source_sha.length() != 64 or not source is Dictionary:
		last_error = "白狐任务来源数据未通过校验"
		return {}
	var quest: Variant = source.get("quest")
	var cards: Variant = source.get("cards")
	if not quest is Dictionary or not cards is Array:
		last_error = "白狐任务来源结构无效"
		return {}
	# A non-winning inline battle leaves the existing task on its third node.
	# FlowDirector still serves due chapters before asking for the current quest.
	if state.has("battleQuestRulePins"):
		var active: Array = state.get("questState", {}).get("activeQuests", [])
		if active.size() == 1 and active[0].get("questId") == "white_fox_line" and active[0].get("step") == 2:
			if state.get("battleQuestRulePins") != BATTLE_RULE_PINS \
					or flow.get("questSourceSha") != source_sha:
				last_error = "任务战果来源版本已变化"
				return {}
			for row in cards:
				if row.get("id") != "q_whiteFox_3":
					continue
				var art: Dictionary = _content.asset_status(String(row.get("sceneImage", "")))
				if not art.get("shaVerified", false) or not art.get("textureLoadable", false):
					last_error = "白狐任务续卡场景图未通过校验"
					return {}
				var retry := state.duplicate(true)
				retry["pendingQuestCard"] = row.duplicate(true)
				retry["currentCardId"] = row.id
				retry["phase"] = "QUEST_PENDING"
				retry["decisionCheckpoint"] = {"version": 1, "cardId": row.id,
					"sourceCardId": state.get("decisionCheckpoint", {}).get("sourceCardId"),
					"turn": state.turn, "decisionIndex": state.runClock.decisionIndex,
					"flowSource": "quest:active", "questId": "white_fox_line"}
				return retry
			return {}
	if not _eligible(state, quest):
		return {}
	var quest_id := String(quest.get("id", ""))
	var entry_id := String(quest.get("entryCardId", ""))
	var card: Dictionary = {}
	for row in cards:
		if row is Dictionary and row.get("id") == entry_id:
			card = row.duplicate(true)
			break
	if entry_id.is_empty() or card.get("type") != "QUEST" \
			or card.get("questId") != quest_id or int(card.get("questStep", -1)) != 1:
		last_error = "白狐任务入口卡未通过校验"
		return {}
	var image: Dictionary = _content.card_scene_image_status(entry_id)
	if not image.get("shaVerified", false) or not image.get("textureLoadable", false) \
			or image.get("sceneImage") != card.get("sceneImage"):
		last_error = "白狐任务场景图未通过校验"
		return {}
	var candidate: Dictionary = state.duplicate(true)
	if rebirth_before_chapter:
		candidate["noncombatFlow"]["milestoneSourceSha"] = chapter_sha
		candidate["noncombatFlow"]["causalGraphSourceSha"] = causal_sha
	var world: Dictionary = {}
	if not legacy_entry_replay:
		if candidate.get("worldContinuityState") is Dictionary:
			world = {"sourceSha": _content.source_sha256("npcs:core"),
				"state": candidate["worldContinuityState"]}
		else:
			world = WorldContinuity.initial(_content, int(state.get("lifeCount", 0)))
		if world.is_empty() or not world.get("state", {}).get("npcs", {}).has("bai_luoxuan"):
			last_error = "白狐人物来源数据未通过校验"
			return {}
		candidate["worldContinuityState"] = world["state"]
	var prior_quests: Dictionary = candidate.get("questState", {})
	var quest_state := {"saveVersion": 3, "activeQuests": [
		{"questId": quest_id, "step": 0, "startedAt": int(state["turn"])}],
		"completedQuests": prior_quests.get("completedQuests", []).duplicate(true),
		"closedQuests": prior_quests.get("closedQuests", []).duplicate(true),
		"questOutcomes": prior_quests.get("questOutcomes", {}).duplicate(true)}
	candidate["questState"] = quest_state
	var flags: Dictionary = candidate.get("flags", {}).duplicate(true)
	flags["quest_" + quest_id + "_active"] = true
	flags["quest_" + quest_id + "_step"] = 0
	candidate["flags"] = flags
	candidate["noncombatFlow"]["questSourceSha"] = source_sha
	if not legacy_entry_replay:
		candidate["noncombatFlow"]["npcSourceSha"] = world["sourceSha"]
	candidate["pendingQuestCard"] = card
	candidate["currentCardId"] = entry_id
	candidate["phase"] = "QUEST_PENDING"
	candidate["decisionCheckpoint"] = {"version": 1, "cardId": entry_id,
		"sourceCardId": state.get("decisionCheckpoint", {}).get("sourceCardId"),
		"turn": state["turn"], "decisionIndex": state["runClock"]["decisionIndex"],
		"flowSource": "quest:entry", "questId": quest_id}
	return candidate


func _resume_foundation(state: Dictionary) -> Dictionary:
	var active: Array = state.get("questState", {}).get("activeQuests", [])
	var module := ""
	var modules: Array = _foundation_modules(state)
	if not active.is_empty():
		module = String(state.get("noncombatFlow", {}).get(
			"foundationQuestModule", FOUNDATION_QUEST_MODULE))
		if module not in modules:
			return {}
	else:
		for candidate_module in modules:
			var candidate_source: Variant = _content.read_module(String(candidate_module))
			if candidate_source is Dictionary and candidate_source.get("quest") is Dictionary \
					and _eligible(state, candidate_source.quest):
				module = String(candidate_module)
				break
	if module.is_empty():
		return {}
	var source_sha: String = _content.source_sha256(module)
	var source: Variant = _content.read_module(module)
	if source_sha.length() != 64 or not source is Dictionary \
			or not source.get("quest") is Dictionary or not source.get("cards") is Array:
		last_error = "筑基任务来源数据未通过校验"
		return {}
	var quest: Dictionary = source.quest
	var step := 0
	if not active.is_empty():
		if active.size() != 1 or active[0].get("questId") != quest.get("id"):
			return {}
		step = int(active[0].get("step", -1))
		if state.get("noncombatFlow", {}).get("foundationQuestSourceSha") != source_sha \
				or state.get("noncombatFlow", {}).get("foundationQuestModule",
					FOUNDATION_QUEST_MODULE) != module:
			last_error = "筑基任务来源版本已变化"
			return {}
	else:
		if not _eligible(state, quest):
			return {}
	if state.get("path") == "spell" and state.get("noncombatFlow", {}).has(
			"tianshuSourceSha") and state.noncombatFlow.tianshuSourceSha \
			!= _content.source_sha256(TIANSHU_MODULE):
		last_error = "天书任务调度来源版本已变化"
		return {}
	var cards: Array = source.cards
	if step < 0 or step >= cards.size() or not cards[step] is Dictionary:
		last_error = "筑基任务步骤无效"
		return {}
	var card: Dictionary = _project_foundation_card(cards[step], state)
	if card.get("type") != "QUEST" or card.get("questId") != quest.get("id") \
			or int(card.get("questStep", -1)) != step + 1 \
			or step == 0 and card.get("id") != quest.get("entryCardId"):
		last_error = "筑基任务卡结构无效"
		return {}
	var image: Dictionary = _content.card_scene_image_status(String(card.id))
	if image.get("sceneImage") != card.get("sceneImage") \
			or not image.get("shaVerified", false) or not image.get("textureLoadable", false):
		last_error = "筑基任务场景图未通过校验"
		return {}
	var candidate: Dictionary = state.duplicate(true)
	candidate.erase("pendingQuestCombatDirection")
	if active.is_empty():
		var previous: Dictionary = candidate.get("questState", {})
		candidate.questState = {"saveVersion": 3,
			"activeQuests": [{"questId": quest.id, "step": 0,
				"startedAt": int(state.turn)}],
			"completedQuests": previous.get("completedQuests", []).duplicate(true),
			"closedQuests": previous.get("closedQuests", []).duplicate(true),
			"questOutcomes": previous.get("questOutcomes", {}).duplicate(true)}
		candidate.flags["quest_" + String(quest.id) + "_active"] = true
		candidate.flags["quest_" + String(quest.id) + "_step"] = 0
		candidate.noncombatFlow["foundationQuestSourceSha"] = source_sha
		if state.get("path") == "spell" and not legacy_tianshu_replay:
			candidate.noncombatFlow["tianshuSourceSha"] = _content.source_sha256(
				TIANSHU_MODULE)
	if module != FOUNDATION_QUEST_MODULE:
		candidate.noncombatFlow["foundationQuestModule"] = module
	candidate.pendingQuestCard = card
	candidate.currentCardId = card.id
	candidate.phase = "QUEST_PENDING"
	candidate.decisionCheckpoint = {"version": 1, "cardId": card.id,
		"sourceCardId": state.get("decisionCheckpoint", {}).get("sourceCardId"),
		"turn": state.turn, "decisionIndex": state.runClock.decisionIndex,
		"flowSource": "quest:entry" if active.is_empty() else "quest:active",
		"questId": quest.id}
	return candidate


func _foundation_modules(state: Dictionary) -> Array:
	var path := String(state.get("path", ""))
	if path == "spell":
		if legacy_tianshu_replay:
			return ["quests:spell_codex"]
		if replay_first_foundation_quest_module == "quests:spell_codex" \
				and not state.get("questState", {}).get("closedQuests", []).has(
					"spell_codex"):
			return ["quests:spell_codex", TIANSHU_MODULE]
		return [TIANSHU_MODULE, "quests:spell_codex"]
	var module := String(FOUNDATION_QUEST_MODULES.get(path, ""))
	return [] if module.is_empty() else [module]


func _project_foundation_card(source_card: Dictionary, state: Dictionary) -> Dictionary:
	var card := source_card.duplicate(true)
	for variant in source_card.get("stateVariants", []):
		if variant is Dictionary and state.get("flags", {}).get(variant.get("whenFlag"), false):
			for key in ["title", "description", "sceneImage", "artDirection", "choices"]:
				if variant.has(key):
					var value: Variant = variant[key]
					card[key] = value.duplicate(true) if value is Dictionary or value is Array else value
			break
	return card


func _eligible(state: Dictionary, quest: Dictionary) -> bool:
	var trigger: Variant = quest.get("trigger")
	if not trigger is Dictionary or String(quest.get("id", "")).is_empty():
		return false
	if quest.get("startRealm", trigger.get("startRealm")) != null \
			and quest.get("startRealm", trigger.get("startRealm")) != state.get("realm"):
		return false
	if quest.get("pathRestriction", trigger.get("pathRestriction")) != null \
			and quest.get("pathRestriction", trigger.get("pathRestriction")) != state.get("path"):
		return false
	if int(state.get("turn", -1)) < int(trigger.get("minTurn", 0)):
		return false
	var current: Variant = state.get("questState", {})
	if not current is Dictionary:
		return false
	if not current.get("activeQuests", []).is_empty() \
			or current.get("closedQuests", []).has(quest.get("id")):
		return false
	var flags: Dictionary = state.get("flags", {})
	var required_flags: Variant = trigger.get("requiredFlags")
	if required_flags is Array:
		for required in required_flags:
			if not flags.get(required, false):
				return false
	var forbidden_flags: Variant = trigger.get("forbiddenFlags")
	if forbidden_flags is Array:
		for forbidden in forbidden_flags:
			if flags.get(forbidden, false):
				return false
	var visited: Array = state.get("cardsPlayed", []).duplicate()
	for previous in state.get("choiceHistory", []):
		if previous is Dictionary:
			visited.append(previous.get("cardId"))
	var forbidden_ids: Variant = trigger.get("forbiddenCardIds")
	if forbidden_ids is Array:
		for forbidden in forbidden_ids:
			if visited.has(forbidden):
				return false
	var required_attributes: Variant = trigger.get("requiredAttributes")
	if required_attributes is Dictionary:
		for attribute in required_attributes:
			if int(state.get("attributes", {}).get(attribute, 0)) < int(required_attributes[attribute]):
				return false
	return true


func choice_available(state: Dictionary) -> bool:
	return state.get("phase") == "QUEST_PENDING" \
		and String(state.get("currentCardId", "")) in ["q_whiteFox_quest", "q_whiteFox_2", "q_whiteFox_3",
			"q_sword_1", "q_sword_2", "q_sword_3", "q_sword_4",
			"q_body_1", "q_body_2", "q_body_3", "q_body_4",
			"q_spell_1", "q_spell_2", "q_spell_3", "q_spell_4",
			"q_pill_1", "q_pill_2", "q_pill_3", "q_pill_4",
			"q_tianshu_1", "q_tianshu_2", "q_tianshu_3", "q_tianshu_4"]


func choice_direction_available(state: Dictionary, direction: String) -> bool:
	if not choice_available(state):
		return false
	var choice: Variant = state.get("pendingQuestCard", {}).get("choices", {}).get(direction)
	if not choice is Dictionary:
		return false
	if String(state.get("currentCardId", "")).begins_with("q_sword_") \
			or String(state.get("currentCardId", "")).begins_with("q_body_") \
			or String(state.get("currentCardId", "")).begins_with("q_spell_") \
			or String(state.get("currentCardId", "")).begins_with("q_pill_") \
			or String(state.get("currentCardId", "")).begins_with("q_tianshu_"):
		if choice.get("triggerCombat") == true:
			return false
		var reward: Variant = choice.get("effects", {}).get("opportunityReward")
		if reward is Dictionary:
			var preview: Dictionary = opportunity_flow.preview(state,
				String(reward.get("opportunityId", "")),
				String(reward.get("profile", "")),
				String(state.get("currentCardId", "")))
			return preview.get("eligible") == true or preview.get("reason") == "pool_exhausted"
		return true
	return true


func settle(state: Dictionary, direction: String) -> Dictionary:
	last_error = ""
	if not choice_available(state) or not direction in ["left", "right", "down"]:
		return {}
	if String(state.get("currentCardId", "")).begins_with("q_sword_") \
			or String(state.get("currentCardId", "")).begins_with("q_body_") \
			or String(state.get("currentCardId", "")).begins_with("q_spell_") \
			or String(state.get("currentCardId", "")).begins_with("q_pill_") \
			or String(state.get("currentCardId", "")).begins_with("q_tianshu_"):
		return _settle_foundation(state, direction)
	var third: bool = state.get("currentCardId") == "q_whiteFox_3"
	if (third and direction == "left") or (not third and direction == "down"):
		return {}
	var working: Dictionary = state.duplicate(true)
	var flow: Dictionary = working.get("noncombatFlow", {})
	if not flow.has("npcSourceSha") and not working.has("worldContinuityState") \
			and state.get("currentCardId") == "q_whiteFox_quest":
		var world: Dictionary = WorldContinuity.initial(_content,
			int(state.get("lifeCount", 0)))
		if world.is_empty():
			last_error = "白狐人物来源数据未通过校验"
			return {}
		working["worldContinuityState"] = world["state"]
		working["noncombatFlow"]["npcSourceSha"] = world["sourceSha"]
		flow = working["noncombatFlow"]
	if flow.get("questSourceSha") != _content.source_sha256(QUEST_MODULE) \
			or flow.get("npcSourceSha") != _content.source_sha256("npcs:core") \
			or flow.get("milestoneSourceSha") != _content.source_sha256("cards:chapter_milestones") \
			or flow.get("causalGraphSourceSha") != _content.source_sha256("narrative:causal_graph"):
		last_error = "白狐任务依赖的来源规则已变化"
		return {}
	var source: Variant = _content.read_module(QUEST_MODULE)
	if not source is Dictionary or not source.get("cards") is Array:
		return {}
	var card: Dictionary = {}
	var next_card: Dictionary = {}
	for row in source["cards"]:
		if row is Dictionary and row.get("id") == state.get("currentCardId"):
			card = row.duplicate(true)
		if row is Dictionary and row.get("id") == "q_whiteFox_2" \
				and state.get("currentCardId") == "q_whiteFox_quest":
			next_card = row.duplicate(true)
		if row is Dictionary and row.get("id") == "q_whiteFox_3" \
				and state.get("currentCardId") == "q_whiteFox_2":
			next_card = row.duplicate(true)
	if card.is_empty() or JSON.parse_string(JSON.stringify(card)) != \
			JSON.parse_string(JSON.stringify(state.get("pendingQuestCard", {}))):
		return {}
	var choice: Variant = card.get("choices", {}).get(direction)
	if not choice is Dictionary or not choice.get("effects") is Dictionary:
		return {}
	for cost_key in ["spiritStone", "lifespan"]:
		var delta := int(choice["effects"].get(cost_key, 0))
		if delta < 0 and int(state.get("resources", {}).get(cost_key, 0)) < -delta:
			return {}
	var quest_state: Dictionary = state.get("questState", {})
	var active: Array = quest_state.get("activeQuests", [])
	var expected_step := 0 if card["id"] == "q_whiteFox_quest" else (2 if third else 1)
	if active.size() != 1 or active[0].get("questId") != "white_fox_line" \
			or int(active[0].get("step", -1)) != expected_step:
		return {}
	var candidate: Dictionary = working
	var base_index := int(state.get("runClock", {}).get("decisionIndex", -1))
	var life_id := String(state.get("runClock", {}).get("lifeId", ""))
	var life_count := int(state.get("lifeCount", 0))
	if base_index < 0 or life_count < 0 \
			or not life_id.ends_with(":life:" + str(life_count)):
		return {}
	for key in choice["effects"]:
		var value: Variant = choice["effects"][key]
		if key == "_setFlag":
			if not value is String or String(value).is_empty():
				return {}
			candidate["flags"][value] = true
		elif key == "npcLifecycle":
			if not value is Dictionary or not WorldContinuity.transition_dead(
					candidate, value, String(card["id"]), base_index):
				return {}
		elif not _apply_number(candidate, String(key), value,
				String(card.get("id", "")), base_index + 1):
			return {}
	if int(choice["effects"].get("health", 0)) < 0 \
			or int(choice["effects"].get("daoHeart", 0)) < 0:
		candidate["resources"]["lifespan"] = maxi(0,
			int(candidate["resources"]["lifespan"]) - 1)
	var next_index := base_index + 1
	if third:
		var faction_sha: String = _content.source_sha256("world:factions")
		var faction_source: Variant = _content.read_module("world:factions")
		if faction_sha.length() != 64 or not faction_source is Dictionary:
			last_error = "势力来源数据未通过校验"
			return {}
		if flow.has("factionSourceSha") and flow["factionSourceSha"] != faction_sha:
			last_error = "势力来源规则已变化"
			return {}
		candidate["noncombatFlow"]["factionSourceSha"] = faction_sha
		if not _settle_third_reward(candidate, source.get("quest", {}), card,
				choice, direction, next_index, faction_source):
			return {}
	var receipt := "decision:%s:choice:%s:%d" % [life_id, card["id"], next_index]
	if candidate["runClock"]["receipts"].has(receipt):
		return {}
	candidate["choiceHistory"].append({"cardId": card["id"], "cardType": "QUEST",
		"direction": direction, "turn": base_index, "decisionIndex": next_index, "tags": []})
	while candidate["choiceHistory"].size() > 30:
		candidate["choiceHistory"].pop_front()
	candidate["cardsPlayed"].append(card["id"])
	candidate["turn"] = next_index
	candidate["runClock"]["decisionIndex"] = next_index
	candidate["runClock"]["receipts"][receipt] = {"token": receipt,
		"decisionIndex": next_index, "sourceCardId": card["id"], "kind": "choice"}
	MilestoneFlow.tick_seeds(candidate)
	candidate.erase("pendingQuestCard")
	var quest_id := String(card["questId"])
	if choice.get("questEnd") == true:
		var outcome := String(choice.get("questOutcome", ""))
		if choice.has("questNext") or (not third and (card["id"] != "q_whiteFox_quest" \
				or direction != "left" or outcome != "failed")) \
				or (third and not outcome in ["completed", "abandoned"]):
			return {}
		candidate["questState"]["activeQuests"] = []
		if not candidate["questState"]["closedQuests"].has(quest_id):
			candidate["questState"]["closedQuests"].append(quest_id)
		candidate["questState"]["questOutcomes"][quest_id] = outcome
		if outcome == "completed" \
				and not candidate["questState"]["completedQuests"].has(quest_id):
			candidate["questState"]["completedQuests"].append(quest_id)
		candidate["flags"][quest_id + "Completed"] = outcome == "completed"
		if outcome != "completed":
			candidate["flags"]["quest_" + quest_id + "_" + outcome] = true
		candidate["flags"]["quest_" + quest_id + "_active"] = false
		candidate["phase"] = "FLOW_PENDING"
		candidate["currentCardId"] = ""
		candidate["decisionCheckpoint"] = {"version": 1, "cardId": null,
			"sourceCardId": card["id"], "turn": next_index,
			"decisionIndex": next_index, "flowPending": true}
	else:
		if choice.get("questNext") != next_card.get("id") \
				or next_card.get("type") != "QUEST" \
				or next_card.get("questId") != quest_id \
				or int(next_card.get("questStep", -1)) != expected_step + 2:
			return {}
		var image: Dictionary = _content.card_scene_image_status(String(next_card["id"]))
		if not image.get("shaVerified", false) or not image.get("textureLoadable", false):
			last_error = "白狐任务续卡场景图未通过校验"
			return {}
		candidate["questState"]["activeQuests"][0]["step"] = expected_step + 1
		candidate["flags"]["quest_" + quest_id + "_step"] = expected_step + 1
		candidate["pendingQuestCard"] = next_card
		candidate["phase"] = "QUEST_PENDING"
		candidate["currentCardId"] = next_card["id"]
		candidate["decisionCheckpoint"] = {"version": 1, "cardId": next_card["id"],
			"sourceCardId": card["id"], "turn": next_index,
			"decisionIndex": next_index, "flowSource": "quest:active",
			"questId": quest_id}
	return candidate


func _settle_foundation(state: Dictionary, direction: String) -> Dictionary:
	var module := String(state.get("noncombatFlow", {}).get(
		"foundationQuestModule", FOUNDATION_QUEST_MODULE))
	var source_sha: String = _content.source_sha256(module)
	if module not in _foundation_modules(state) or state.get("noncombatFlow", {}).get(
			"foundationQuestSourceSha") != source_sha \
			or state.get("noncombatFlow", {}).get("foundationQuestModule",
				FOUNDATION_QUEST_MODULE) != module:
		last_error = "筑基任务来源版本已变化"
		return {}
	var source: Variant = _content.read_module(module)
	if not source is Dictionary or not source.get("cards") is Array \
			or not source.get("quest") is Dictionary:
		last_error = "筑基任务来源数据未通过校验"
		return {}
	var quest_id := String(source.quest.get("id", ""))
	var active: Array = state.get("questState", {}).get("activeQuests", [])
	if quest_id.is_empty() or active.size() != 1 or active[0].get("questId") != quest_id:
		return {}
	var step := int(active[0].get("step", -1))
	var cards: Array = source.cards
	if step < 0 or step >= cards.size() or not cards[step] is Dictionary:
		return {}
	var card: Dictionary = _project_foundation_card(cards[step], state)
	if card.get("id") != state.get("currentCardId") \
			or card != state.get("pendingQuestCard"):
		return {}
	var choice: Variant = card.get("choices", {}).get(direction)
	if not choice is Dictionary or not choice.get("effects") is Dictionary:
		return {}
	# The combat directions wait for a battle contract. A refusal is a normal
	# authored quest ending and can settle here without a battle result.
	if choice.get("triggerCombat") == true:
		return {}
	if choice.get("questEnd") != true and choice.get("questNext") != \
			(cards[step + 1].get("id") if step + 1 < cards.size() else null):
		return {}
	var candidate: Dictionary = state.duplicate(true)
	var effects: Dictionary = choice.effects
	if effects.get("opportunityReward") is Dictionary:
		var spec: Dictionary = effects.opportunityReward
		var acquired: Dictionary = opportunity_flow.resolve(candidate,
			String(spec.get("opportunityId", "")), String(spec.get("profile", "")),
			String(card.id), int(state.runClock.decisionIndex) + 1)
		if acquired.is_empty() and opportunity_flow.last_error != "pool_exhausted":
			last_error = opportunity_flow.last_error
			return {}
		if not acquired.is_empty():
			candidate = acquired
	for key in effects:
		if key == "opportunityReward":
			continue
		if key == "_setFlag":
			if not effects[key] is String or String(effects[key]).is_empty():
				return {}
			candidate.flags[effects[key]] = true
		elif key in ["sword_insight", "body_insight", "spell_insight",
				"pill_insight"]:
			if not _integer(effects[key]):
				return {}
			var insight_path := String(key).trim_suffix("_insight")
			candidate["knowledge"] = candidate.get("knowledge", {}).duplicate(true)
			candidate.knowledge[insight_path] = maxi(0,
				int(candidate.knowledge.get(insight_path, 0)) + int(effects[key]))
		elif not _apply_number(candidate, String(key), effects[key],
				String(card.get("id", "")), int(state.runClock.decisionIndex) + 1):
			return {}
	if int(effects.get("health", 0)) < 0 or int(effects.get("daoHeart", 0)) < 0:
		candidate.resources.lifespan = maxi(0, int(candidate.resources.lifespan) - 1)
	var next_index := int(state.runClock.decisionIndex) + 1
	var life_id := String(state.runClock.lifeId)
	var receipt := "decision:%s:choice:%s:%d" % [life_id, card.id, next_index]
	if candidate.runClock.receipts.has(receipt):
		return {}
	candidate.choiceHistory.append({"cardId": card.id, "cardType": "QUEST",
		"direction": direction, "turn": state.turn, "decisionIndex": next_index,
		"tags": []})
	while candidate.choiceHistory.size() > 30:
		candidate.choiceHistory.pop_front()
	candidate.cardsPlayed.append(card.id)
	candidate.turn = next_index
	candidate.runClock.decisionIndex = next_index
	candidate.runClock.receipts[receipt] = {"token": receipt,
		"decisionIndex": next_index, "sourceCardId": card.id, "kind": "choice"}
	candidate.erase("pendingQuestCard")
	if choice.get("karmaSeed") != null and not _plant_choice_seeds(candidate,
			choice.karmaSeed, card, choice, direction, next_index, false):
		return {}
	if choice.get("questEnd") == true:
		var outcome := String(choice.get("questOutcome", ""))
		if not outcome in ["abandoned", "failed", "completed"] \
				or outcome == "completed" and (step != cards.size() - 1 \
					or not _complete_foundation_rewards(
						candidate, source.get("quest"), card, choice,
						direction, next_index)):
			return {}
		candidate.questState.activeQuests = []
		candidate.questState.closedQuests.append(quest_id)
		candidate.questState.questOutcomes[quest_id] = outcome
		if outcome == "completed":
			candidate.questState.completedQuests.append(quest_id)
		else:
			candidate.flags["quest_" + quest_id + "_" + outcome] = true
		for flag in source.quest.get("rewardOnComplete", {}).get("flags", []):
			candidate.flags[flag] = outcome == "completed"
		candidate.flags["quest_" + quest_id + "_active"] = false
		candidate.phase = "FLOW_PENDING"
		candidate.currentCardId = ""
		candidate.decisionCheckpoint = {"version": 1, "cardId": null,
			"sourceCardId": card.id, "turn": next_index,
			"decisionIndex": next_index, "flowPending": true}
	else:
		candidate.questState.activeQuests[0].step = step + 1
		candidate.flags["quest_" + quest_id + "_step"] = step + 1
		var next_card := _project_foundation_card(cards[step + 1], candidate)
		var image: Dictionary = _content.card_scene_image_status(String(next_card.id))
		if image.get("sceneImage") != next_card.get("sceneImage") \
				or not image.get("shaVerified", false) or not image.get("textureLoadable", false):
			last_error = "筑基任务续卡场景图未通过校验"
			return {}
		candidate.pendingQuestCard = next_card
		candidate.currentCardId = next_card.id
		candidate.phase = "QUEST_PENDING"
		candidate.decisionCheckpoint = {"version": 1, "cardId": next_card.id,
			"sourceCardId": card.id, "turn": next_index,
			"decisionIndex": next_index, "flowSource": "quest:active",
			"questId": quest_id}
	var passive = NormalChoicePolicy.new(_content)
	if not passive._apply_passive_regen(candidate):
		last_error = passive.last_error
		return {}
	MilestoneFlow.tick_seeds(candidate)
	return candidate


func _complete_foundation_rewards(target: Dictionary, raw_quest: Variant,
		card: Dictionary, choice: Dictionary, direction: String,
		decision: int) -> bool:
	if not raw_quest is Dictionary or raw_quest.get("id") != card.get("questId"):
		return false
	var reward: Variant = raw_quest.get("rewardOnComplete")
	if not reward is Dictionary or not reward.get("attributes", {}) is Dictionary \
			or not reward.get("resources", {}) is Dictionary \
			or not reward.get("flags", []) is Array \
			or not reward.get("karmaSeeds", []) is Array \
			or not raw_quest.get("factionRewards") is Dictionary:
		return false
	for key in reward.get("attributes", {}):
		if not _apply_number(target, String(key), reward.attributes[key]):
			return false
	for key in reward.get("resources", {}):
		if not _apply_number(target, String(key), reward.resources[key]):
			return false
	for flag in reward.get("flags", []):
		if not flag is String or String(flag).is_empty():
			return false
		target.flags[flag] = true
	for seed in reward.get("karmaSeeds", []):
		if not _plant_quest_seed(target, seed, card, choice,
				direction, decision, true):
			return false
	var faction_source: Variant = _content.read_module("world:factions")
	var faction_sha: String = _content.source_sha256("world:factions")
	if not faction_source is Dictionary or faction_sha.length() != 64 \
			or target.get("noncombatFlow", {}).has("factionSourceSha") and target.noncombatFlow.factionSourceSha != faction_sha:
		return false
	var factions: Dictionary = target.get("factionProgress", {})
	if factions.is_empty():
		factions = _initial_faction_progress(faction_source)
	if factions.is_empty() or not factions.get("reputations") is Dictionary:
		return false
	for faction_id in raw_quest.factionRewards:
		if not factions.reputations.has(faction_id) \
				or not _integer(raw_quest.factionRewards[faction_id]):
			return false
		var old_value := int(factions.reputations[faction_id])
		var new_value := clampi(old_value + int(raw_quest.factionRewards[faction_id]),
			-100, 100)
		factions.reputations[faction_id] = new_value
		if new_value != old_value:
			target["tradeRoutePendingEvents"] = target.get(
				"tradeRoutePendingEvents", []).duplicate(true)
			target.tradeRoutePendingEvents.append({"kind": "reputation",
				"factionId": faction_id, "oldValue": old_value,
				"newValue": new_value})
	target["factionProgress"] = factions
	target.noncombatFlow["factionSourceSha"] = faction_sha
	return true


func apply_battle_outcome(target: Dictionary, card: Dictionary, choice: Dictionary,
		outcome: String, decision: int) -> bool:
	# Called inside the gateway-verified battle transaction, before its one tick.
	if card.get("id") == "q_sword_3":
		return _apply_foundation_battle_outcome(target, card, choice, outcome, decision)
	var active: Array = target.get("questState", {}).get("activeQuests", [])
	if card.get("id") != "q_whiteFox_3" or active.size() != 1 \
			or active[0].get("questId") != "white_fox_line" or active[0].get("step") != 2:
		return false
	target["battleQuestRulePins"] = BATTLE_RULE_PINS.duplicate()
	if outcome != "victory":
		for key in choice.get(outcome + "Effects", {}):
			if not _apply_number(target, key, choice[outcome + "Effects"][key],
					String(card.get("id", "")), decision):
				return false
		return true
	if choice.get("questEndOn") != ["victory"] or choice.get("karmaSeedOn") != ["victory"]:
		return false
	var source: Dictionary = _content.read_module(QUEST_MODULE)
	var faction_sha: String = _content.source_sha256("world:factions")
	var factions: Variant = _content.read_module("world:factions")
	if faction_sha.length() != 64 or not factions is Dictionary \
			or target.noncombatFlow.get("factionSourceSha", faction_sha) != faction_sha:
		last_error = "势力来源数据未通过校验"
		return false
	target.noncombatFlow["factionSourceSha"] = faction_sha
	if not _settle_third_reward(target, source.quest, card, choice, "left", decision, factions, outcome):
		return false
	var quest_id: String = card.questId
	target.questState.activeQuests = []
	for key in ["completedQuests", "closedQuests"]:
		if not target.questState[key].has(quest_id):
			target.questState[key].append(quest_id)
	target.questState.questOutcomes[quest_id] = "completed"
	target.flags[quest_id + "Completed"] = true
	target.flags["quest_" + quest_id + "_active"] = false
	target.erase("pendingQuestCard")
	return true


func _apply_foundation_battle_outcome(target: Dictionary, card: Dictionary,
		choice: Dictionary, outcome: String, decision: int) -> bool:
	var active: Array = target.get("questState", {}).get("activeQuests", [])
	var direction := String(target.get("pendingQuestCombatDirection", ""))
	if active.size() != 1 or active[0].get("questId") != "sword_legacy" \
			or int(active[0].get("step", -1)) != 2 \
			or target.get("noncombatFlow", {}).get("foundationQuestSourceSha") != \
			_content.source_sha256(FOUNDATION_QUEST_MODULE) \
			or direction not in ["left", "right"] \
			or card != target.get("pendingQuestCard") \
			or choice != card.get("choices", {}).get(direction):
		return false
	if outcome in ["defeat", "flee"]:
		var effects: Dictionary = choice.get(outcome + "Effects", {})
		if effects.is_empty():
			return false
		for key in effects:
			if not _apply_number(target, String(key), effects[key],
					String(card.get("id", "")), decision):
				return false
		return true
	if outcome != "victory" or choice.get("questNext") != "q_sword_4" \
			or choice.get("questEndOn") != ["victory"] \
			or choice.get("karmaSeedOn") != ["victory"]:
		return false
	var trial_flag := "sword_legacy_trial_heart" if direction == "left" else "sword_legacy_trial_iron"
	if choice.get("victoryEffects", {}).get("_setFlag") != trial_flag \
			or target.get("flags", {}).get(trial_flag) != true \
			or not _plant_quest_seed(target, choice.get("karmaSeed"), card,
				choice, direction, decision, false, outcome):
		return false
	target.questState.activeQuests[0].step = 3
	target.flags["quest_sword_legacy_step"] = 3
	return true


func _settle_third_reward(target: Dictionary, quest: Variant, card: Dictionary,
		choice: Dictionary, direction: String, decision: int,
		faction_source: Dictionary, battle_outcome: String = "") -> bool:
	if not quest is Dictionary or quest.get("id") != card.get("questId"):
		return false
	var factions: Dictionary = _initial_faction_progress(faction_source)
	if factions.is_empty():
		return false
	if target.has("factionProgress"):
		var persisted: Variant = target["factionProgress"]
		if not persisted is Dictionary or not persisted.get("reputations") is Dictionary \
				or not persisted.get("undercurrentStages") is Dictionary \
				or not persisted.get("globalFlags") is Dictionary:
			return false
		for id in persisted["reputations"]:
			if factions["reputations"].has(id) and _integer(persisted["reputations"][id]):
				factions["reputations"][id] = clampi(int(persisted["reputations"][id]), -100, 100)
		for id in persisted["undercurrentStages"]:
			if factions["undercurrentStages"].has(id) \
					and _integer(persisted["undercurrentStages"][id]):
				var maximum: int = int(faction_source["undercurrents"][id].get("maxStage", 5))
				factions["undercurrentStages"][id] = clampi(
					int(persisted["undercurrentStages"][id]), 0, maximum)
		for id in persisted["globalFlags"]:
			if persisted["globalFlags"][id] == true:
				factions["globalFlags"][id] = true
		factions["ticksSinceEvent"] = maxi(0, int(persisted.get("ticksSinceEvent", 0)))
	target["factionProgress"] = factions
	if direction == "down":
		return choice.get("questOutcome") == "abandoned"
	if (direction != "right" and not (direction == "left" and battle_outcome == "victory")) \
			or choice.get("questOutcome") != "completed":
		return false
	if battle_outcome.is_empty() and not _plant_quest_seed(target, choice.get("karmaSeed"), card, choice,
			direction, decision, false):
		return false
	var reward: Variant = quest.get("rewardOnComplete")
	if not reward is Dictionary or not reward.get("attributes") is Dictionary \
			or not reward.get("resources") is Dictionary or not reward.get("flags") is Array \
			or not reward.get("karmaSeeds") is Array:
		return false
	for key in reward["attributes"]:
		if not _apply_number(target, String(key), reward["attributes"][key]):
			return false
	for key in reward["resources"]:
		if not _apply_number(target, String(key), reward["resources"][key]):
			return false
	for flag in reward["flags"]:
		if not flag is String or String(flag).is_empty():
			return false
		target["flags"][flag] = true
	for spec in reward["karmaSeeds"]:
		if not _plant_quest_seed(target, spec, card, choice, direction, decision, true, battle_outcome):
			return false
	var reputation_rewards: Variant = quest.get("factionRewards")
	if not reputation_rewards is Dictionary:
		return false
	for faction_id in reputation_rewards:
		if not factions["reputations"].has(faction_id) \
				or not _integer(reputation_rewards[faction_id]):
			return false
		var prior_reputation := int(factions["reputations"][faction_id])
		var next_reputation := clampi(prior_reputation + int(
			reputation_rewards[faction_id]), -100, 100)
		factions["reputations"][faction_id] = next_reputation
		if next_reputation != prior_reputation:
			target["tradeRoutePendingEvents"] = target.get(
				"tradeRoutePendingEvents", []).duplicate(true)
			target["tradeRoutePendingEvents"].append({"kind": "reputation",
				"factionId": faction_id, "oldValue": prior_reputation,
				"newValue": next_reputation})
	if not battle_outcome.is_empty() and not _plant_quest_seed(target, choice.get("karmaSeed"),
			card, choice, direction, decision, false, battle_outcome):
		return false
	return true


func _initial_faction_progress(source: Dictionary) -> Dictionary:
	if not source.get("factions") is Array or not source.get("undercurrents") is Dictionary:
		return {}
	var reputations := {}
	for faction in source["factions"]:
		if not faction is Dictionary or String(faction.get("id", "")).is_empty() \
				or not _integer(faction.get("startReputation")):
			return {}
		reputations[faction["id"]] = int(faction["startReputation"])
		for sub in faction.get("subfactions", []):
			if not sub is Dictionary or String(sub.get("id", "")).is_empty() \
					or not _integer(sub.get("startReputation")):
				return {}
			reputations[sub["id"]] = int(sub["startReputation"])
	var stages := {}
	for id in source["undercurrents"]:
		var undercurrent: Variant = source["undercurrents"][id]
		if not undercurrent is Dictionary or not _integer(undercurrent.get("stage")):
			return {}
		stages[id] = int(undercurrent["stage"])
	return {"reputations": reputations, "undercurrentStages": stages,
		"globalFlags": {}, "ticksSinceEvent": 0}


func _plant_quest_seed(target: Dictionary, raw: Variant, card: Dictionary,
		choice: Dictionary, direction: String, decision: int,
		completion_reward: bool, battle_outcome: String = "") -> bool:
	if not raw is Dictionary or String(raw.get("id", "")).is_empty():
		return false
	var seed_id := String(raw["id"])
	for existing in target.get("karmaSeeds", []):
		if existing is Dictionary and existing.get("id") == seed_id:
			if battle_outcome.is_empty():
				return false
			if int(raw.get("delay", 5)) < int(existing.get("delay", 0)):
				existing.delay = int(raw.get("delay", 5))
				existing.priority = maxi(int(existing.get("priority", 0)), int(raw.get("priority", 0)))
			if not existing.get("originQuest") and completion_reward:
				existing["originQuest"] = card.questId
			if not existing.get("originOutcome"):
				existing["originOutcome"] = battle_outcome
			target.karmaPromiseFlags[seed_id] = true
			target.flags[seed_id] = true
			return true
	var realm_delay := {"qi": 1.5, "foundation": 1.2, "golden": 1.0,
		"nascent": 0.8, "deity": 0.6, "tribulation": 0.5}
	var seed := {"id": seed_id, "seedType": raw.get("seedType", "karma"),
		"delay": maxi(1, roundi(int(raw.get("delay", 5)) * float(
			realm_delay.get(target.get("realm"), 1.0)))),
		"realm": raw.get("realm"), "path": raw.get("path"),
		"priority": int(raw.get("priority", 0)), "originTurn": decision,
		"originLife": int(target.get("lifeCount", 0)),
		"originCard": card["id"], "originChoice": direction,
		"originThread": raw.get("originThread"),
		"originQuest": card["questId"] if completion_reward else raw.get("originQuest"),
		"originOutcome": battle_outcome if not battle_outcome.is_empty() else ("completed" if completion_reward else raw.get("originOutcome")),
		"description": raw.get("description"), "tags": raw.get("tags", []),
		"payoffEvent": raw.get("payoffEvent"),
		"context": null if completion_reward or not battle_outcome.is_empty() else {
			"sourceTitle": card.get("title", card["id"]),
			"choiceText": choice.get("text", direction),
			"realm": raw.get("realm", target.get("realm")),
			"path": raw.get("path", target.get("path"))},
		"consumed": false, "mergeGroup": raw.get("mergeGroup"),
		"cancelGroup": raw.get("cancelGroup")}
	target["karmaSeeds"].append(seed)
	target["karmaPromiseFlags"][seed_id] = true
	target["flags"][seed_id] = true
	return true


func _plant_choice_seeds(target: Dictionary, raw: Variant, card: Dictionary,
		choice: Dictionary, direction: String, decision: int,
		completion_reward: bool) -> bool:
	if raw is Array:
		for seed in raw:
			if not _plant_quest_seed(target, seed, card, choice,
					direction, decision, completion_reward):
				return false
		return true
	return _plant_quest_seed(target, raw, card, choice,
		direction, decision, completion_reward)


func _integer(value: Variant) -> bool:
	return (value is int or value is float) and float(value) == float(int(value))


func _apply_number(target: Dictionary, key: String, raw: Variant,
		card_id: String = "", decision_index: int = -1) -> bool:
	if not (raw is int or raw is float) or float(raw) != float(int(raw)):
		return false
	var amount := int(raw)
	var path_skill = PathSkillFlow.new(_content)
	if not card_id.is_empty():
		amount = path_skill.effect_delta(target, key, amount, card_id,
			decision_index)
		if not path_skill.last_error.is_empty():
			return false
	if key in ["cultivation", "daoHeart", "health", "fortune", "karmaGood", "karmaBad"]:
		amount = LegacyFragmentFlow.effective_delta(target, key, amount)
		var maximum := 100
		if key == "daoHeart": maximum = LegacyFragmentFlow.actual_max_dao_heart(target)
		if key == "health": maximum = path_skill.actual_max_health(target,
			decision_index)
		if not path_skill.last_error.is_empty():
			return false
		if key == "health" and amount < 0 and int(target["attributes"].get("aura", 0)) > 0:
			var absorbed := mini(int(target["attributes"]["aura"]), -amount)
			target["attributes"]["aura"] = int(target["attributes"]["aura"]) - absorbed
			amount += absorbed
		target["attributes"][key] = clampi(
			int(target["attributes"].get(key, 0)) + amount, 0, maximum)
		return true
	if key in ["spiritStone", "lifespan"]:
		target["resources"][key] = maxi(0, int(target["resources"].get(key, 0)) + amount)
		return true
	return false
