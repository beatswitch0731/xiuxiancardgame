extends RefCounted
const LegacyFragmentFlow = preload("res://scripts/noncombat_legacy_fragment_flow.gd")
const NormalChoicePolicy = preload("res://scripts/noncombat_normal_choice_policy.gd")

# Source-backed first qi mentor beat. Progression follows StoryNetworkSystem's
# cultivation and card-tag listeners; prose and effects remain in arcs.json.
const MilestoneFlow = preload("res://scripts/noncombat_milestone_flow.gd")
const WorldContinuity = preload("res://scripts/noncombat_world_continuity.gd")
const STAGE := "INNER_DISCIPLE"
const CARD_ID := "mentor_bai_ren_stage_INNER_DISCIPLE"
const TRUSTED_STAGE := "TRUSTED"
const TRUSTED_CARD_ID := "mentor_bai_ren_stage_TRUSTED"
const HEIR_STAGE := "HEIR"
const HEIR_CARD_ID := "mentor_bai_ren_stage_HEIR"
const LEGACY_STAGE := "LEGACY"
const LEGACY_CARD_ID := "mentor_bai_ren_stage_LEGACY"
const TRIBULATION_CARD_ID := "mentor_bai_ren_tribulation"
const DESTINY_CARD_ID := "mentor_bai_ren_destiny"
const REALMS := ["qi", "foundation", "golden", "nascent", "deity", "tribulation"]
const STAGES := [{"name": STAGE, "index": 1, "threshold": 20},
	{"name": TRUSTED_STAGE, "index": 2, "threshold": 40},
	{"name": HEIR_STAGE, "index": 3, "threshold": 60},
	{"name": LEGACY_STAGE, "index": 4, "threshold": 80}]
const TAGS := ["mentor", "sword_way", "disciple", "trial", "legacy"]
const STORY_RULE_SHA := "08cd0d1ac24caeae35629210a0f2de0a24a563c7e3c4ea2da3ffe346f8f0a1e4"

var _content: RefCounted
var last_error := ""

static func is_stage_card_id(card_id: String) -> bool:
	return card_id in [CARD_ID, TRUSTED_CARD_ID, HEIR_CARD_ID, LEGACY_CARD_ID,
		TRIBULATION_CARD_ID, DESTINY_CARD_ID]

static func _card_id(stage: String) -> String:
	return "mentor_bai_ren_stage_" + stage

func choice_available(state: Dictionary, direction: String) -> bool:
	if state.get("phase") != "MENTOR_PENDING" or not is_stage_card_id(String(
			state.get("currentCardId", ""))):
		return false
	var choices: Dictionary = state.get("pendingMentorCard", {}).get("choices", {})
	if not choices.has(direction):
		return false
	if not _all_positive_capped(state, choices[direction]):
		return true
	for other in choices:
		if not _all_positive_capped(state, choices[other]):
			return false
	return direction == String(choices.keys()[0])

func _all_positive_capped(state: Dictionary, choice: Dictionary) -> bool:
	var effects: Dictionary = choice.get("effects", {})
	if effects.is_empty():
		return false
	var attributes: Dictionary = state.get("attributes", {})
	for key in effects:
		var amount: Variant = effects[key]
		if not (amount is int or amount is float) or int(amount) <= 0 \
				or float(amount) != float(int(amount)):
			return false
		var maximum := -1
		match key:
			"cultivation", "fortune", "karmaGood": maximum = 100
			"daoHeart": maximum = LegacyFragmentFlow.actual_max_dao_heart(state)
			"health": maximum = LegacyFragmentFlow.actual_max_health(state)
			_: return false
		if int(attributes.get(key, 0)) < maximum:
			return false
	return true


func _init(content: RefCounted) -> void:
	_content = content


static func initial_state() -> Dictionary:
	return {"version": 4, "npcId": "bai_ren", "stage": "DISCIPLE",
		"stageIndex": 0, "progression": 0, "enteredAtTurn": 0,
		"eventsTriggered": [], "pendingStages": [], "heirActivationIndex": 0,
		"climaxActivationIndex": 0, "pendingClimaxes": [], "climaxTriggered": false}


static func advance(before: Dictionary, after: Dictionary, arc: Dictionary,
		enable_trusted: bool = true, cultivation_events: Array = [],
		enable_heir: bool = true, enable_climax: bool = true) -> Dictionary:
	# Settlement may consume an event before the central commit. Preserve that
	# candidate-owned queue change while calculating listener progression.
	var next: Dictionary = after.get("mentorArcState", arc).duplicate(true)
	var prior_version := int(next.get("version", 0))
	var may_heir := enable_heir and (int(after.get("runClock", {}).get(
		"decisionIndex", 0)) > int(before.get("runClock", {}).get(
		"decisionIndex", 0)) or prior_version >= 3)
	if enable_trusted:
		next["version"] = 2
	if may_heir:
		next["version"] = 3
		if not next.has("heirActivationIndex"):
			next["heirActivationIndex"] = int(after.get("runClock", {}).get(
				"decisionIndex", 0))
	var may_climax := enable_heir and enable_climax and (int(after.get("runClock", {}).get(
		"decisionIndex", 0)) > int(before.get("runClock", {}).get(
		"decisionIndex", 0)) or prior_version >= 4)
	if may_climax:
		next["version"] = 4
		if not next.has("climaxActivationIndex"):
			next["climaxActivationIndex"] = int(after.get("runClock", {}).get(
				"decisionIndex", 0))
			next["pendingClimaxes"] = []
			next["climaxTriggered"] = false
	var delta := int(after.get("attributes", {}).get("cultivation", 0)) - \
		int(before.get("attributes", {}).get("cultivation", 0))
	if not cultivation_events.is_empty():
		for step in cultivation_events:
			if int(step) > 0:
				next["progression"] = mini(100, int(next["progression"]) +
					maxi(1, ceili(float(step) * 0.3)))
	elif delta > 0:
		next["progression"] = mini(100, int(next["progression"]) + maxi(1, ceili(delta * 0.3)))
	var before_decision := int(before.get("runClock", {}).get("decisionIndex", 0))
	var after_decision := int(after.get("runClock", {}).get("decisionIndex", 0))
	if after_decision > before_decision:
		for entry in after.get("choiceHistory", []):
			if not entry is Dictionary or int(entry.get("decisionIndex", 0)) <= before_decision:
				continue
			for tag in entry.get("tags", []):
				if tag in TAGS:
					next["progression"] = mini(100, int(next["progression"]) + 3)
					break
	for stage_def in STAGES:
		if not enable_trusted and stage_def["name"] == TRUSTED_STAGE:
			continue
		if not may_heir and int(stage_def["index"]) >= 3:
			continue
		if int(next["progression"]) >= int(stage_def["threshold"]) \
				and int(next["stageIndex"]) < int(stage_def["index"]):
			next["stage"] = stage_def["name"]
			next["stageIndex"] = stage_def["index"]
			next["enteredAtTurn"] = int(before.get("turn", 0))
			next["pendingStages"].append(stage_def["name"])
	if may_climax and _physical_mentor(after):
		var realm_rank := REALMS.find(String(after.get("realm", "qi")))
		if realm_rank >= 2 and int(next.get("stageIndex", 0)) >= 3 \
				and not next.get("climaxTriggered", false):
			_queue_climax(next, TRIBULATION_CARD_ID)
		if realm_rank >= 4 and int(next.get("stageIndex", 0)) >= 4:
			_queue_climax(next, DESTINY_CARD_ID)
	return next


static func _physical_mentor(state: Dictionary) -> bool:
	var world: Variant = state.get("worldContinuityState")
	if not world is Dictionary:
		return true
	var mentor: Variant = world.get("npcs", {}).get("bai_ren")
	return mentor is Dictionary and mentor.get("lifecycle") == "ACTIVE" \
		and mentor.get("manifestation") == "PHYSICAL"


static func _queue_climax(arc: Dictionary, card_id: String) -> void:
	if not arc.get("eventsTriggered", []).has(card_id) \
			and not arc.get("pendingClimaxes", []).has(card_id):
		arc["pendingClimaxes"].append(card_id)


func resume(state: Dictionary, enable_upgrade: bool = true,
		kind: String = "stage") -> Dictionary:
	last_error = ""
	if state.get("phase") != "FLOW_PENDING" \
			or state.get("noncombatFlow", {}).get("scope") not in [
				"first_session_avoid", "first_session_combat", "rebirth_new_life"]:
		return {}
	var arc: Dictionary = state.get("mentorArcState", {}).duplicate(true)
	# A verified v1 save can have crossed the second threshold just before
	# saving. Queue it only on live continuation, without advancing the clock.
	if enable_upgrade and int(arc.get("version", 0)) == 1 \
			and int(arc.get("stageIndex", 0)) == 1 \
			and int(arc.get("progression", 0)) >= 40 \
			and arc.get("pendingStages", []).is_empty() \
			and not arc.get("eventsTriggered", []).has(TRUSTED_CARD_ID):
		arc["version"] = 2
		arc["stage"] = TRUSTED_STAGE
		arc["stageIndex"] = 2
		arc["enteredAtTurn"] = maxi(0, int(state.get("turn", 0)) - 1)
		arc["pendingStages"].append(TRUSTED_STAGE)
	if kind == "climax" and (int(arc.get("version", 0)) < 4 \
			or not arc.get("pendingStages", []).is_empty()):
		return {}
	var pending: Array = arc.get("pendingClimaxes", []) if kind == "climax" \
		else arc.get("pendingStages", [])
	if pending.is_empty():
		return {}
	var stage := String(pending[0])
	var card_id := stage if kind == "climax" else _card_id(stage)
	if not is_stage_card_id(card_id) or arc.get("eventsTriggered", []).has(card_id):
		return {}
	if int(arc.get("version", 0)) >= 4 and not _physical_mentor(state):
		return {}
	var sources := _source_hashes()
	if sources.is_empty():
		return {}
	var card := _project_card(state, stage, kind)
	if card.is_empty():
		return {}
	var candidate: Dictionary = state.duplicate(true)
	candidate["mentorArcState"] = arc
	candidate["noncombatFlow"]["mentorArcSourceSha"] = sources["arc"]
	candidate["noncombatFlow"]["mentorPortraitSourceSha"] = sources["portrait"]
	candidate["pendingMentorCard"] = card
	candidate["currentCardId"] = card_id
	candidate["phase"] = "MENTOR_PENDING"
	candidate["decisionCheckpoint"] = {"version": 1, "cardId": card_id,
		"sourceCardId": state.get("decisionCheckpoint", {}).get("sourceCardId"),
		"turn": state["turn"], "decisionIndex": state["runClock"]["decisionIndex"],
		"flowSource": "mentor:" + kind, "npcId": "bai_ren",
		"arcStage": card["arcStage"]}
	return candidate


func settle(state: Dictionary, direction: String,
		apply_passive_regen: bool = true) -> Dictionary:
	last_error = ""
	var arc: Dictionary = state.get("mentorArcState", {})
	var kind := "climax" if state.get("currentCardId") in [
		TRIBULATION_CARD_ID, DESTINY_CARD_ID] else "stage"
	var pending: Array = arc.get("pendingClimaxes", []) if kind == "climax" \
		else arc.get("pendingStages", [])
	if pending.is_empty():
		return {}
	var stage := String(pending[0])
	var card_id := stage if kind == "climax" else _card_id(stage)
	if state.get("phase") != "MENTOR_PENDING" or state.get("currentCardId") != card_id \
			or not is_stage_card_id(card_id) \
			or not direction in ["left", "right"] or not choice_available(state, direction):
		return {}
	var sources := _source_hashes()
	var flow: Dictionary = state.get("noncombatFlow", {})
	if sources.is_empty() or flow.get("mentorArcSourceSha") != sources["arc"] \
			or flow.get("mentorPortraitSourceSha") != sources["portrait"]:
		last_error = "师尊事件来源数据已变化"
		return {}
	var card := _project_card(state, stage, kind)
	if card.is_empty() or JSON.parse_string(JSON.stringify(card)) != \
			JSON.parse_string(JSON.stringify(state.get("pendingMentorCard", {}))):
		return {}
	if arc.get("eventsTriggered", []).has(card_id):
		return {}
	var choice: Dictionary = card.get("choices", {}).get(direction, {})
	var effects: Variant = choice.get("effects")
	if not effects is Dictionary or effects.is_empty():
		return {}
	var candidate: Dictionary = state.duplicate(true)
	for key in effects:
		var amount: Variant = effects[key]
		if key == "npcLifecycle" and amount is Dictionary and kind == "climax":
			if not WorldContinuity.transition_ascended(candidate, amount,
					int(state.get("turn", 0))):
				return {}
			continue
		if not key in ["cultivation", "daoHeart", "karmaGood", "fortune", "health"] \
				or not (amount is int or amount is float) \
				or float(amount) != float(int(amount)):
			return {}
		var maximum := LegacyFragmentFlow.actual_max_dao_heart(candidate) \
			if key == "daoHeart" else (LegacyFragmentFlow.actual_max_health(candidate) \
			if key == "health" else 100)
		candidate["attributes"][key] = clampi(int(candidate["attributes"].get(key, 0)) +
			LegacyFragmentFlow.effective_delta(candidate, key, int(amount)), 0, maximum)
	var base_index := int(state.get("runClock", {}).get("decisionIndex", -1))
	var life_id := String(state.get("runClock", {}).get("lifeId", ""))
	if base_index < 0 or not life_id.ends_with(":life:%d" % int(
			state.get("lifeCount", 0))):
		return {}
	var next_index := base_index + 1
	if apply_passive_regen:
		var passive = NormalChoicePolicy.new(_content)
		if not passive._apply_passive_regen(candidate, next_index):
			last_error = passive.last_error
			return {}
	var receipt := "decision:%s:choice:%s:%d" % [life_id, card_id, next_index]
	if candidate["runClock"]["receipts"].has(receipt):
		return {}
	candidate["runClock"]["receipts"][receipt] = {"token": receipt,
		"decisionIndex": next_index, "sourceCardId": card_id, "kind": "choice"}
	candidate["choiceHistory"].append({"cardId": card_id, "cardType": "MENTOR_ARC",
		"direction": direction, "turn": base_index, "decisionIndex": next_index,
		"tags": card["tags"].duplicate(true)})
	while candidate["choiceHistory"].size() > 30:
		candidate["choiceHistory"].pop_front()
	for tag in card["tags"]:
		candidate["recentCardTags"].append(tag)
	while candidate["recentCardTags"].size() > 20:
		candidate["recentCardTags"].pop_front()
	candidate["cardsPlayed"].append(card_id)
	candidate["turn"] = next_index
	candidate["runClock"]["decisionIndex"] = next_index
	MilestoneFlow.tick_seeds(candidate)
	var settled_arc: Dictionary = candidate["mentorArcState"]
	var settled_queue: Array = settled_arc["pendingClimaxes"] if kind == "climax" \
		else settled_arc["pendingStages"]
	settled_queue.erase(stage)
	settled_arc["pendingClimaxes" if kind == "climax" else "pendingStages"] = settled_queue
	if kind == "climax":
		settled_arc["climaxTriggered"] = true
	var triggered_events: Array = settled_arc["eventsTriggered"]
	triggered_events.append(card_id)
	settled_arc["eventsTriggered"] = triggered_events
	candidate["mentorArcState"] = settled_arc
	candidate.erase("pendingMentorCard")
	var promise_id := "promise:%08x" % _fnv32("life:%d|%s|%s|%s" % [
		int(state.get("lifeCount", 0)), card["semanticKey"], card_id, direction])
	var result_id := "promise_result_%08x" % _fnv32(promise_id)
	var response := "你在「%s」中选择了「%s」。这段因缘已给出明确回应。" % [
		card["title"], choice["text"]]
	var result := {"id": result_id, "semanticKey": "promise-result:" + promise_id,
		"type": "NARRATIVE_RESULT", "title": String(card["title"]) + "·回应",
		"description": response, "sceneImage": card["sceneImage"],
		"promiseId": promise_id, "originCardId": card_id,
		"originChoice": direction, "_narrativeLane": "primary",
		"_narrativeThreadKey": "promise:" + promise_id,
		"_narrativeSticky": true, "narrativeTtlTurns": 4, "once": true,
		"tags": ["narrative_result", "promise_resolution"],
		"choices": {"left": {"text": "记下这段回应", "effects": {},
			"resolution": {"kind": "promise_resolved", "promiseId": promise_id},
			"feedbackCue": {"kind": "promise_resolved", "text": response,
				"lane": "narrative"}}}}
	candidate["noncombatFlow"]["mentorPromise"] = {"id": promise_id,
		"status": "pending", "sourceCardId": card_id,
		"sourceSemanticKey": card["semanticKey"], "sourceTitle": card["title"],
		"choiceDirection": direction, "createdDecisionIndex": next_index,
		"dueWithinDecisions": 2, "dueDecisionIndex": next_index + 2,
		"followUpCardId": result_id, "resolvedDecisionIndex": null,
		"resolutionCardId": null}
	candidate["noncombatFlow"]["pendingResultCard"] = result.duplicate(true)
	candidate["pendingNarrativeResult"] = result
	candidate["currentCardId"] = result_id
	candidate["phase"] = "NARRATIVE_RESULT_PENDING"
	candidate["decisionCheckpoint"] = {"version": 1, "cardId": result_id,
		"sourceCardId": card_id, "turn": next_index, "decisionIndex": next_index}
	return candidate


func _source_hashes() -> Dictionary:
	var arc_sha: String = _content.source_sha256("companions:arcs")
	var portrait_sha: String = _content.source_sha256("companions:portrait_stages")
	if arc_sha.length() != 64 or portrait_sha.length() != 64:
		last_error = "师尊弧线来源数据未通过校验"
		return {}
	return {"arc": arc_sha, "portrait": portrait_sha}


func _project_card(state: Dictionary, stage: String,
		kind: String = "stage") -> Dictionary:
	var source: Variant = _content.read_module("companions:arcs")
	var portraits: Variant = _content.read_module("companions:portrait_stages")
	if not source is Dictionary or not portraits is Dictionary:
		last_error = "师尊弧线正文缺失"
		return {}
	var mentor: Dictionary = source.get("mentorArc", {}).get("bai_ren", {})
	var authored: Variant = mentor.get("arcStages", {}).get(stage) if kind == "stage" \
		else mentor.get("tribulationClimax" if stage == TRIBULATION_CARD_ID \
		else "destinyClimax")
	var stages: Variant = portraits.get("portraitStages", {}).get("bai_ren", {}).get("stages")
	if not authored is Dictionary or not stages is Array or stages.is_empty() \
			or not stages[0] is Dictionary or stages[0].get("affection") != 0:
		last_error = "师尊阶段结构无效"
		return {}
	var art_path := String(stages[0].get("asset", ""))
	var art: Dictionary = _content.asset_status(art_path)
	if not art.get("shaVerified", false) or not art.get("textureLoadable", false):
		last_error = "师尊原有立绘未通过校验"
		return {}
	var pd: Dictionary = authored
	for key in ["title", "desc", "leftText", "rightText"]:
		if not pd.get(key) is String or String(pd[key]).is_empty():
			last_error = "师尊阶段文本不完整"
			return {}
	for key in ["leftEffects", "rightEffects"]:
		if not pd.get(key) is Dictionary:
			last_error = "师尊阶段效果不完整"
			return {}
	var card_id := _card_id(stage) if kind == "stage" else stage
	var registry: Dictionary = _content.find("generated_card", card_id)
	var author_key := "arcStages." + stage if kind == "stage" else (
		"tribulationClimax" if stage == TRIBULATION_CARD_ID else "destinyClimax")
	if registry.get("data") != authored \
			or registry.get("npcId") != "bai_ren" \
			or registry.get("sourceSha256") != STORY_RULE_SHA \
			or registry.get("authorSha256") != _content.source_sha256("companions:arcs") \
			or registry.get("authorPointer") != "$.mentorArc.bai_ren." + author_key:
		last_error = "师尊生成卡来源登记不符"
		return {}
	var arc_stage := stage if kind == "stage" else ("CLIMAX" \
		if stage == TRIBULATION_CARD_ID else "DESTINY")
	return {"id": card_id,
		"semanticKey": pd.get("semanticKey", "arc:bai_ren:" + arc_stage),
		"title": pd["title"], "description": pd["desc"],
		"type": "MENTOR_ARC", "realm": state.get("realm"),
		"npcId": "bai_ren", "arcStage": arc_stage, "once": true, "weight": 0,
		"tags": ["mentor_arc", "milestone" if kind == "stage" else (
			"tribulation" if stage == TRIBULATION_CARD_ID else "destiny")],
		"sceneImage": art_path,
		"choices": {"left": {"text": pd["leftText"], "effects": pd["leftEffects"].duplicate(true)},
			"right": {"text": pd["rightText"], "effects": pd["rightEffects"].duplicate(true)}}}


func _fnv32(value: String) -> int:
	var hash := 2166136261
	for index in value.length():
		hash = ((hash ^ value.unicode_at(index)) * 16777619) & 0xffffffff
	return hash
