extends RefCounted

# Numerical rewards belong to the story transaction. Incoming combat results
# identify the terminal battle, never provide trusted reward amounts or cards.
const Deck = preload("res://scripts/noncombat_deck_acquisition.gd")
const Milestones = preload("res://scripts/noncombat_milestone_flow.gd")
const StoryThreads = preload("res://scripts/noncombat_story_threads_v2_flow.gd")
const RULE_PINS := {
	"combat": "25c214fbb599ac146b5d4424ce4272ba5fdb77c3a9342acd6e80caba77a01be0",
	"acquisition": "2eff2c858d7ee9cd9065daff6bf309f08cd7ba12140a2f0d0ebdcb560e263098",
	"effects": "7552c41cbb707c642c1b66d434c084c33241227ada146ff9322ba707a53a72dc",
}
var _content: RefCounted
var last_error := ""
var source_error := ""
var inline_summary := {}
var cultivation_events: Array[int] = []

func _init(content: RefCounted) -> void:
	_content = content

func apply_rewards(candidate: Dictionary, encounter: Dictionary, choice: Dictionary,
		source_card_id: String = "", decision_index: int = -1) -> Dictionary:
	last_error = ""
	inline_summary = {}
	cultivation_events.clear()
	var before_cult := int(candidate.attributes.cultivation)
	var before_stones := int(candidate.resources.spiritStone)
	var before_attributes: Dictionary = candidate.attributes.duplicate(true)
	var before_resources: Dictionary = candidate.resources.duplicate(true)
	var effects: Dictionary = choice.get("victoryEffects", {})
	if effects != encounter.get("victoryEffects", {}) \
			or effects.is_empty() and encounter.get("inlineDungeonBoss") != true:
		return {}
	var apply := Milestones.new(_content)
	# The gateway supplies the source's resolved enemy, including path balancing.
	var attack := int(encounter.enemy.get("atk", encounter.enemy.get("tier", 1)))
	var base_cult := 5 + int(floor(before_cult / 20.0))
	var base_stones := int(floor(maxi(1, attack) * 1.5))
	if not apply._apply_effect(candidate, "cultivation", base_cult) \
			or not apply._apply_effect(candidate, "spiritStone", base_stones):
		return {}
	var after_base_cult := int(candidate.attributes.cultivation)
	if after_base_cult > before_cult:
		cultivation_events.append(after_base_cult - before_cult)
	var after_base_stones := int(candidate.resources.spiritStone)
	for key in effects:
		var amount: Variant = effects[key]
		var before_effect_cult := int(candidate.attributes.cultivation)
		if key == "skillAcquire" and encounter.get("inlineBandit") == true \
				and amount is Dictionary and amount.get("offerId") \
				== "opportunity_tiger_queen_break_stance_v1":
			continue
		if key == "_setFlag" and encounter.get("inlineThread") == true \
				and encounter.get("id") == "thread_sword_tomb_2" \
				and amount == "sword_trial_passed":
			candidate["flags"]["sword_trial_passed"] = true
			continue
		if key == "_setFlag" and encounter.get("inlineQuest") == true \
				and encounter.get("id") == "q_sword_3" and amount in [
					"sword_legacy_trial_heart", "sword_legacy_trial_iron"]:
			candidate["flags"][amount] = true
			continue
		if encounter.get("inlineThread") == true \
				and encounter.get("id") == "thread_last_lesson_n3" \
				and key in ["playerLocation", "npc_relation:jian_linger"]:
			if not StoryThreads.new(_content)._apply_effect(candidate, key, amount):
				return {}
			continue
		if not (amount is int or amount is float) or float(amount) != float(int(amount)):
			return {}
		if key == "sword_insight":
			var knowledge: Dictionary = candidate.get("knowledge", {})
			knowledge["sword"] = maxi(0, int(knowledge.get("sword", 0)) + int(amount))
			candidate["knowledge"] = knowledge
		elif key == "knowledge":
			var knowledge: Dictionary = candidate.get("knowledge", {})
			knowledge["world"] = int(knowledge.get("world", 0)) + int(amount)
			candidate["knowledge"] = knowledge
		elif key in ["spellPower", "rawPower", "alchemyYield"]:
			var modifiers: Dictionary = candidate.get("modifiers", {})
			modifiers[key] = int(modifiers.get(key, 0)) + int(amount)
			candidate["modifiers"] = modifiers
		elif not apply._apply_effect(candidate, key, amount,
				source_card_id if not source_card_id.is_empty() else String(encounter.get("id", "")),
				decision_index):
			return {}
		if int(candidate.attributes.cultivation) > before_effect_cult:
			cultivation_events.append(int(candidate.attributes.cultivation) - before_effect_cult)
	if encounter.get("inlineCombat") == true or encounter.get("inlineBandit") == true or encounter.get("inlineThread") == true or encounter.get("inlineNascent") == true or encounter.get("inlineHigherDungeon") == true or encounter.get("inlineFaction") == true or encounter.get("inlineCompanion") == true \
			or encounter.get("inlineDungeonBoss") == true:
		# Browser's result text combines the configured base spoils with the
		# actual delayed choice effects before top-level combatRewards are paid.
		# The base amount remains visible even when cultivation is capped.
		inline_summary = {"cultivation": base_cult + int(candidate.attributes.cultivation) - after_base_cult,
			"spiritStone": base_stones + int(candidate.resources.spiritStone) - after_base_stones}
		for key in ["health", "daoHeart", "karmaGood", "karmaBad", "fortune", "aura"]:
			var delta := int(candidate.attributes.get(key, 0)) - int(before_attributes.get(key, 0))
			if delta != 0:
				inline_summary[key] = delta
		var life_delta := int(candidate.resources.lifespan) - int(before_resources.lifespan)
		if life_delta != 0:
			inline_summary["lifespan"] = life_delta
	if encounter.get("inlineCombat") == true or encounter.get("inlineDungeonBoss") == true or encounter.get("inlineNascent") == true or encounter.get("inlineHigherDungeon") == true:
		var source_rewards: Dictionary = encounter.get("combatRewards", {})
		var mission: bool = encounter.get("id") == "f_mission"
		var dungeon_boss: bool = encounter.get("inlineDungeonBoss") == true
		var trial: bool = encounter.get("inlineHigherDungeon") == true
		if source_rewards.size() != (3 if mission or dungeon_boss or trial else 2) \
				or not source_rewards.has("cultivation") \
				or not source_rewards.has("spiritStone") \
				or mission and source_rewards.get("pill") != "筑基丹" \
				or trial and source_rewards.get("pill") != "渡劫丹" \
				or dungeon_boss and source_rewards.get("knowledge") != 1:
			return {}
		for key in source_rewards:
			if key == "pill" and (mission or trial):
				var pills: Dictionary = candidate.get("resources", {}).get("pills", {})
				var pill_name := "渡劫丹" if trial else "筑基丹"
				pills[pill_name] = int(pills.get(pill_name, 0)) + 1
				candidate["resources"]["pills"] = pills
				continue
			if key == "knowledge" and dungeon_boss:
				var knowledge: Dictionary = candidate.get("knowledge", {})
				knowledge["world"] = int(knowledge.get("world", 0)) + int(source_rewards[key])
				candidate["knowledge"] = knowledge
				continue
			var amount: Variant = source_rewards[key]
			var before_reward_cult := int(candidate.attributes.cultivation)
			if not (amount is int or amount is float) or float(amount) != float(int(amount)) \
					or not apply._apply_effect(candidate, key, amount, "",
						decision_index, true):
				return {}
			if int(candidate.attributes.cultivation) > before_reward_cult:
				cultivation_events.append(int(candidate.attributes.cultivation) - before_reward_cult)
	candidate["battleVictoryRulePins"] = RULE_PINS.duplicate()
	candidate["battleVictoryWorldSha"] = _content.source_sha256("combat:visual_worlds")
	var rewards := {"cultivation": int(candidate.attributes.cultivation) - before_cult,
		"spiritStone": int(candidate.resources.spiritStone) - before_stones}
	for key in ["health", "daoHeart", "karmaGood", "karmaBad", "fortune", "aura"]:
		var delta := int(candidate.attributes.get(key, 0)) - int(before_attributes.get(key, 0))
		if delta != 0:
			rewards[key] = delta
	var lifespan := int(candidate.resources.lifespan) - int(before_resources.lifespan)
	if lifespan != 0:
		rewards["lifespan"] = lifespan
	return rewards

func card(state: Dictionary, record: Dictionary, encounter: Dictionary) -> Dictionary:
	source_error = ""
	if state.get("battleVictoryRulePins") != RULE_PINS \
			or state.get("battleVictoryWorldSha") != _content.source_sha256("combat:visual_worlds"):
		source_error = "SOURCE_MISMATCH"
		return {}
	var presentations: Variant = _content.read_module("combat:encounter_presentations")
	var worlds: Variant = _content.read_module("combat:visual_worlds")
	if not presentations is Dictionary or not worlds is Dictionary:
		source_error = "SOURCE_UNAVAILABLE"
		return {}
	var inline: bool = encounter.get("inlineQuest") == true or encounter.get("inlineCombat") == true or encounter.get("inlineBandit") == true or encounter.get("inlineThread") == true or encounter.get("inlineDungeonBoss") == true or encounter.get("inlineNascent") == true or encounter.get("inlineHigherDungeon") == true or encounter.get("inlineFaction") == true or encounter.get("inlineCompanion") == true
	var visual: Dictionary = encounter.combatPresentation if inline else presentations.get("presentations", {}).get(encounter.id, {})
	var world: Dictionary = worlds.get("worlds", {}).get(visual.get("visualWorldId"), {})
	var material: Dictionary = world.get("uiMaterial", {})
	# DeckCombatSystem._encounterActionId uses the original card ID before the
	# encounter ID. The STORY mountain card has no matching composition, even
	# though its canonical encounter does. Preserve that source UI projection;
	# this bounded check does not replace the battle renderer's full validation.
	var action_id := String(visual.get("actionPresentationId", record.result.sourceCardId)).trim_prefix("encounter_card_")
	var composition: Dictionary = world.get("encounterCompositions", {}).get(action_id, {})
	var has_world: bool = not world.is_empty() and world.get("id") == visual.get("visualWorldId") \
		and material.get("visualWorldId") == world.get("id") and material.has("id") \
		and composition.get("id") == action_id and composition.get("battlefieldProfileId") == visual.get("battlefieldId")
	var outcome: Dictionary = encounter.get("combatOutcomePresentation", {}).get("victory", {})
	var scene_image := String(outcome.get("sceneImage", encounter.get("sceneImage", "") if inline else visual.get("sceneImage", "")))
	var art: Dictionary = _content.asset_status(scene_image)
	if not art.get("shaVerified", false) or not art.get("textureLoadable", false):
		source_error = "SOURCE_UNAVAILABLE" if art.get("fileExists") == false else "SOURCE_MISMATCH"
		return {}
	var continuation := String(outcome.get("nextCard", ""))
	if not continuation.is_empty() and continuation != "q_mountain_shadow_approach":
		return {}
	var offers: Array = Deck.new(_content).battle_reward_offers(state)
	var choices := {}
	var directions := ["left", "right", "up"]
	for i in range(offers.size()):
		var offer: Dictionary = offers[i]
		var description := String(offer.get("description", ""))
		choices[directions[i]] = {"text": "参悟【%s】" % offer.cardName,
			"desc": (description if not description.is_empty() else "将本流派功法纳入识海。") + "\n\n【来源】战斗缴获",
			"effects": {"deckCard": {"cardId": offer.cardId, "path": state.path,
				"sourceType": "battle_reward", "sourceId": record.result.sourceCardId}}}
	choices["down"] = {"text": "不纳新法，整理战利品离去", "desc": "保留当前牌组，不取得新功法。",
		"effects": {}, "settlementFeedbackMode": "log_only"}
	if not continuation.is_empty():
		for choice in choices.values():
			choice["nextCard"] = continuation
	var rewards: Dictionary = record.get("sourceVictoryRewards",
		record.get("victoryRewards", {})) if encounter.get("inlineCombat") == true \
		or encounter.get("inlineBandit") == true \
		or encounter.get("inlineDungeonBoss") == true \
		or encounter.get("inlineThread") == true or encounter.get("inlineNascent") == true or encounter.get("inlineHigherDungeon") == true or encounter.get("inlineFaction") == true or encounter.get("inlineCompanion") == true \
		else record.get("victoryRewards", {})
	if not rewards.has("cultivation") or not rewards.has("spiritStone"):
		return {}
	if not inline:
		# The browser prints its uncapped base cultivation grant, then the
		# actual delayed encounter effect. Keep the settled state capped.
		var actual_total := int(rewards.cultivation)
		var prior_cult := int(state.attributes.cultivation) - actual_total
		if prior_cult < 0:
			return {}
		var base_cult := 5 + int(floor(prior_cult / 20.0))
		var after_base := state.duplicate(true)
		after_base.attributes.cultivation = prior_cult
		if not Milestones.new(_content)._apply_effect(after_base, "cultivation", base_cult):
			return {}
		rewards = rewards.duplicate(true)
		rewards.cultivation = base_cult + int(state.attributes.cultivation) \
			- int(after_base.attributes.cultivation)
	var summary: Array[String] = []
	for pair in [["cultivation", "修为"], ["spiritStone", "灵石"], ["health", "气血"], ["daoHeart", "道心"], ["karmaGood", "善缘"], ["karmaBad", "恶业"], ["fortune", "气运"], ["aura", "灵气"], ["lifespan", "寿元"]]:
		var amount := int(rewards.get(pair[0], 0))
		if amount != 0:
			summary.append("%s %s%d" % [pair[1], "+" if amount > 0 else "", amount])
	return {"id": "combat_reward", "type": "NORMAL", "sceneImage": scene_image,
		"combatPresentationId": visual.get("presentationId"),
		"visualWorldId": world.id if has_world else null,
		"uiMaterialId": material.id if has_world else null,
		"visualWorldMediaDensity": material.get("mediaDensity") if has_world else null,
		"visualWorldLogicalPixelGrid": material.get("logicalPixelGrid") if has_world else null,
		"visualSurface": "combat_settlement_ledger" if has_world else null,
		"title": outcome.get("title", "大胜 · 择法"),
		"description": (String(outcome.description) + "\n\n" if outcome.has("description") else "")
			+ "战斗结束。你从对手散落的行功痕迹里辨出三条本脉法门；可取其一，也可保持精简。"
			+ ("\n\n【本次结算】" + "，".join(summary) + "。" if not summary.is_empty() else "")
			+ ("\n\n除了战利品，你还获得了：灵石 +%d，修为 +%d。" % [
				int(encounter.get("combatRewards", {}).get("spiritStone", 0)),
				int(encounter.get("combatRewards", {}).get("cultivation", 0))]
				if encounter.get("inlineCombat") == true or encounter.get("inlineDungeonBoss") == true or encounter.get("inlineNascent") == true or encounter.get("inlineHigherDungeon") == true else ""),
		"choices": choices}

func acquire(state: Dictionary, current: Dictionary, direction: String) -> Dictionary:
	var choice: Dictionary = current.get("choices", {}).get(direction, {})
	if choice.is_empty():
		return {}
	if direction == "down":
		return state.duplicate(true)
	return Deck.new(_content).acquire_battle_reward(state,
		String(choice.effects.deckCard.cardId), String(choice.effects.deckCard.sourceId))
