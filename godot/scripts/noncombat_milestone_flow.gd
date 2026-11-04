extends RefCounted
const LegacyFragmentFlow = preload("res://scripts/noncombat_legacy_fragment_flow.gd")
const PathSkillFlow = preload("res://scripts/noncombat_path_skill_flow.gd")
const NormalChoicePolicy = preload("res://scripts/noncombat_normal_choice_policy.gd")

# Authored chapter continuations from chapter_milestones.json. The qi route
# retains its first-session scope; later realms share saved chapter progress.
const DUE_THRESHOLDS := {"qi": [15, 30, 50, 70],
	"foundation": [20, 40, 60, 80],
	"golden": [20, 45, 65, 85],
	"nascent": [25, 50, 70, 90],
	"deity": [30, 55, 75, 95],
	"tribulation": [20, 38, 55, 72]}
const THRESHOLD_ALIASES := {"qi": {15: 20, 30: 40, 50: 60, 70: 80},
	"golden": {45: 40, 65: 60, 85: 80},
	"nascent": {25: 20, 50: 40, 70: 60, 90: 80},
	"deity": {30: 20, 55: 40, 75: 60, 95: 80},
	"tribulation": {38: 40, 55: 60, 72: 80}}
const REALMS := ["qi", "foundation", "golden", "nascent", "deity", "tribulation"]

var _content: RefCounted
var last_error := ""


func _init(content: RefCounted) -> void:
	_content = content


func resume(state: Dictionary) -> Dictionary:
	last_error = ""
	var realm := String(state.get("realm", ""))
	if state.get("phase") != "FLOW_PENDING" or not DUE_THRESHOLDS.has(realm):
		return {}
	if realm == "qi" and state.get("noncombatFlow", {}).get("scope") not in [
			"first_session_avoid", "first_session_combat", "rebirth_new_life"]:
		return {}
	var chapter_sha: String = _content.source_sha256("cards:chapter_milestones")
	var causal_sha: String = _content.source_sha256("narrative:causal_graph")
	if chapter_sha.length() != 64 or causal_sha.length() != 64:
		last_error = "章节或因果来源数据未通过校验"
		return {}
	var progress: Dictionary = _progress(state.get("chapterProgress", {}))
	var triggered: Array = progress["triggeredMilestones"][realm]
	var cultivation := int(state.get("attributes", {}).get("cultivation", 0))
	for threshold in DUE_THRESHOLDS[realm]:
		if cultivation < threshold or triggered.any(func(value: Variant) -> bool:
			return int(value) == threshold):
			continue
		var card := _project_card(state, threshold)
		if card.is_empty():
			return {}
		var candidate: Dictionary = state.duplicate(true)
		progress["triggeredMilestones"][realm].append(threshold)
		candidate["chapterProgress"] = progress
		candidate["noncombatFlow"]["milestoneSourceSha"] = chapter_sha
		candidate["noncombatFlow"]["causalGraphSourceSha"] = causal_sha
		candidate["pendingMilestoneCard"] = card.duplicate(true)
		candidate["currentCardId"] = card["id"]
		candidate["phase"] = "MILESTONE_PENDING"
		candidate["decisionCheckpoint"] = {"version": 1, "cardId": card["id"],
			"sourceCardId": state.get("decisionCheckpoint", {}).get("sourceCardId"),
			"turn": state["turn"], "decisionIndex": state["runClock"]["decisionIndex"],
			"flowSource": "milestone", "chapterThreshold": threshold}
		return candidate
	return {}


func settle(state: Dictionary, direction: String) -> Dictionary:
	last_error = ""
	if state.get("phase") != "MILESTONE_PENDING" or not direction in ["left", "right"]:
		return {}
	var flow: Dictionary = state.get("noncombatFlow", {})
	if flow.get("milestoneSourceSha") != _content.source_sha256("cards:chapter_milestones") \
			or flow.get("causalGraphSourceSha") != _content.source_sha256("narrative:causal_graph"):
		return {}
	var card: Dictionary = state.get("pendingMilestoneCard", {})
	var threshold := int(card.get("threshold", -1))
	var realm := String(state.get("realm", ""))
	if not DUE_THRESHOLDS.has(realm) or not threshold in DUE_THRESHOLDS[realm] \
			or card.get("id") != state.get("currentCardId") \
			or JSON.parse_string(JSON.stringify(card)) != \
				JSON.parse_string(JSON.stringify(_project_card(state, threshold))):
		return {}
	var choice: Dictionary = card.get("choices", {}).get(direction, {})
	var effects: Dictionary = choice.get("effects", {})
	if effects.is_empty():
		return {}
	var candidate: Dictionary = state.duplicate(true)
	for key in effects:
		if not _apply_effect(candidate, String(key), effects[key],
				String(card.get("id", "")), int(state.runClock.decisionIndex) + 1):
			return {}
	if int(effects.get("health", 0)) < 0 or int(effects.get("daoHeart", 0)) < 0:
		candidate["resources"]["lifespan"] = maxi(0,
			int(candidate["resources"]["lifespan"]) - 1)
	# The browser applies passives, then checkDeath, after a chapter choice too.
	var passive_policy := NormalChoicePolicy.new(_content)
	if not passive_policy._apply_passive_regen(candidate):
		last_error = passive_policy.last_error
		return {}
	var attributes: Dictionary = candidate["attributes"]
	if int(attributes.get("health", 0)) <= 0 \
			and int(attributes.get("daoHeart", 0)) > 0:
		var max_health := int(candidate.get("maxHealth", 1))
		var max_dao := int(candidate.get("maxDaoHeart", 1))
		if max_health > 1 and max_dao > 1:
			candidate["maxHealth"] = max_health - 1
			candidate["maxDaoHeart"] = max_dao - 1
			attributes["health"] = 1
			attributes["daoHeart"] = mini(int(attributes["daoHeart"]),
				LegacyFragmentFlow.actual_max_dao_heart(candidate))
	var base_index := int(state.get("runClock", {}).get("decisionIndex", -1))
	var life_id := String(state.get("runClock", {}).get("lifeId", ""))
	var life_count := int(state.get("lifeCount", 0))
	if base_index < 0 or life_count < 0 \
			or not life_id.ends_with(":life:" + str(life_count)):
		return {}
	var next_index := base_index + 1
	if not _settle_spine(candidate, card, direction, next_index):
		return {}
	if choice.has("karmaSeed") and not _plant_seed(candidate, card, choice, direction, next_index):
		return {}
	var tags: Array = card.get("tags", [])
	candidate["choiceHistory"].append({"cardId": card["id"],
		"cardType": "MILESTONE", "direction": direction,
		"turn": base_index, "decisionIndex": next_index, "tags": tags.duplicate(true)})
	while candidate["choiceHistory"].size() > 30:
		candidate["choiceHistory"].pop_front()
	for tag in tags:
		candidate["recentCardTags"].append(tag)
	while candidate["recentCardTags"].size() > 20:
		candidate["recentCardTags"].pop_front()
	candidate["cardsPlayed"].append(card["id"])
	candidate["turn"] = next_index
	candidate["runClock"]["decisionIndex"] = next_index
	var receipt := "decision:%s:choice:%s:%d" % [life_id, card["id"], next_index]
	if candidate["runClock"]["receipts"].has(receipt):
		return {}
	candidate["runClock"]["receipts"][receipt] = {"token": receipt,
		"decisionIndex": next_index, "sourceCardId": card["id"], "kind": "choice"}
	tick_seeds(candidate)
	candidate.erase("pendingMilestoneCard")
	candidate["phase"] = "FLOW_PENDING"
	candidate["currentCardId"] = ""
	candidate["decisionCheckpoint"] = {"version": 1, "cardId": null,
		"sourceCardId": card["id"], "turn": next_index,
		"decisionIndex": next_index, "flowPending": true}
	if state.has("firstSessionContinuation"):
		return candidate
	if int(candidate["attributes"].get("daoHeart", 1)) <= 0 \
			or int(candidate["attributes"].get("health", 1)) <= 0 \
			or int(candidate["resources"].get("lifespan", 1)) <= 0:
		return candidate
	var next_candidate := resume(candidate)
	return next_candidate if not next_candidate.is_empty() else candidate


func _project_card(state: Dictionary, threshold: int) -> Dictionary:
	var source: Variant = _content.read_module("cards:chapter_milestones")
	if not source is Dictionary:
		return {}
	var realm := String(state.get("realm", ""))
	if not DUE_THRESHOLDS.has(realm):
		return {}
	var canonical_threshold := int(THRESHOLD_ALIASES.get(realm, {}).get(
		threshold, threshold))
	var source_id := "ch_%s_%d" % [realm, canonical_threshold]
	var raw: Variant = source.get(source_id)
	if not raw is Dictionary or raw.get("id") != source_id or raw.get("realm") != realm:
		return {}
	var card: Dictionary = raw.duplicate(true)
	card["threshold"] = threshold
	if canonical_threshold != threshold or realm == "qi":
		card["_aliasedFrom"] = canonical_threshold
	var path_id := String(state.get("path", ""))
	var variants: Variant = card.get("pathVariants")
	if variants is Dictionary:
		var variant: Dictionary = variants.get(path_id, {})
		var text: Dictionary = variant.get("text", {})
		var rules: Dictionary = variant.get("rules", {})
		var rewards: Dictionary = variant.get("rewards", {})
		var causal: Dictionary = variant.get("causal", {})
		var scene: Dictionary = variant.get("scene", {})
		if variant.get("realm") != realm or variant.get("path") != path_id \
				or rules.get("identityTag") != "path:" + path_id \
				or String(text.get("title", "")).is_empty() \
				or String(text.get("description", "")).is_empty() \
				or String(scene.get("image", "")).is_empty():
			return {}
		card["title"] = text["title"]
		card["description"] = text["description"]
		card["path"] = path_id
		card["location"] = scene.get("location")
		card["sceneImage"] = scene["image"]
		var tags: Array = card.get("tags", []).duplicate(true)
		for tag in ["milestone", "realm:" + realm, "path:" + path_id]:
			if not tags.has(tag):
				tags.append(tag)
		card["tags"] = tags
		for direction in ["left", "right"]:
			var label: Dictionary = text.get("choices", {}).get(direction, {})
			var reward: Dictionary = rewards.get(direction, {})
			var seed: Dictionary = causal.get(direction, {})
			if String(label.get("text", "")).is_empty() \
					or not reward.get("effects") is Dictionary \
					or seed.get("path") != path_id or seed.get("realm") != realm:
				return {}
			card["choices"][direction]["text"] = label["text"]
			card["choices"][direction]["desc"] = label.get("desc", "")
			card["choices"][direction]["effects"] = reward["effects"].duplicate(true)
			card["choices"][direction]["karmaSeed"] = seed.duplicate(true)
		card["_pathVariant"] = {"sourceCardId": source_id, "realm": realm,
			"path": path_id, "identityTag": rules["identityTag"],
			"consumers": variant.get("consumers", []).duplicate(true)}
		card.erase("pathVariants")
	if (realm == "qi" and threshold in [50, 70]) or realm != "qi":
		# RealmChapterSystem projects the authored qi boss journey onto the
		# third and fourth milestones. The third carries its default origin echo;
		# earlier pending cards retain their serialized projection for old saves.
		var boss: Dictionary = source.get("ch_%s_100" % realm, {})
		var journey: Dictionary = boss.get("bossJourney", {})
		var stage: Dictionary = journey.get("stages", {}).get(str(canonical_threshold), {})
		if String(journey.get("id", "")).is_empty() or String(stage.get("cue", "")).is_empty():
			return {}
		var projected_stage := {"journeyId": journey["id"],
			"bossName": journey.get("bossName"),
			"strengthModel": journey.get("strengthModel"),
			"scalesWithPlayerRealm": journey.get("scalesWithPlayerRealm"),
			"canonicalThreshold": canonical_threshold, "triggerThreshold": threshold}
		projected_stage.merge(stage.duplicate(true), true)
		card["bossJourneyStage"] = projected_stage
		card["description"] = String(card.get("description", "")) + "\n\n" + String(stage["cue"])
		# This bounded first-session route has no sword-origin producer. The
		# source narrative context therefore renders its documented default.
		if realm == "qi" and threshold == 50 and card.get("narrativeSpine", {}).get("threadId") == "qi_ask_sword" \
				and int(card.get("narrativeSpine", {}).get("step", -1)) == 3:
			card["narrativeSpine"]["observedOrigins"] = []
			card["description"] += "\n\n【来历回声】这一世未曾留下残剑来历；问剑只能照见你自己立下的气机。"
		elif realm == "qi" and threshold == 70 and card.get("narrativeSpine", {}).get("threadId") == "qi_ask_sword":
			card["narrativeSpine"]["observedOrigins"] = []
		if realm == "qi":
			var image: Dictionary = _content.card_scene_image_status(source_id)
			if not image.get("shaVerified", false) or not image.get("textureLoadable", false) \
					or image.get("sceneImage") != card.get("sceneImage"):
				last_error = "炼气章节卡场景图未通过校验"
				return {}
	if realm != "qi":
		_append_spine_echo(card, state)
	return card


func _append_spine_echo(card: Dictionary, state: Dictionary) -> void:
	var spine: Dictionary = card.get("narrativeSpine", {})
	var echo: Dictionary = spine.get("presentation", {}).get("echo", {})
	var marker := String(echo.get("marker", ""))
	var segments: Array = echo.get("segments", [])
	if marker.is_empty() or segments.is_empty():
		return
	var facts: Dictionary = state.get("noncombatFlow", {}).get("spineFacts", {})
	var life_count := int(state.get("lifeCount", 0))
	var phrases: Array[String] = []
	for segment in segments:
		var fact: Dictionary = facts.get("fact:%d:%s" % [life_count,
			String(segment.get("factTypeId", ""))], {})
		var value: Variant = fact.get("payload", {}).get(String(segment.get(
			"payloadKey", "")))
		var phrase := String(segment.get("variants", {}).get(value, "")).strip_edges()
		if not phrase.is_empty():
			phrases.append(phrase)
	if phrases.is_empty():
		return
	var summary := marker + String(echo.get("prefix", "")) + String(echo.get(
		"separator", "；")).join(phrases) + String(echo.get("suffix", ""))
	if not String(card.get("description", "")).contains(summary):
		card["description"] = String(card.get("description", "")) + "\n\n" + summary


func _progress(raw: Variant) -> Dictionary:
	var progress: Dictionary = raw.duplicate(true) if raw is Dictionary else {}
	if not progress.has("version"):
		progress = {"version": 1, "activeChapterRealm": null,
			"triggeredMilestones": {}}
	for realm in REALMS:
		if not progress["triggeredMilestones"].has(realm):
			progress["triggeredMilestones"][realm] = []
		else:
			var normalized: Array = []
			for value in progress["triggeredMilestones"][realm]:
				normalized.append(int(value))
			progress["triggeredMilestones"][realm] = normalized
	return progress


func _apply_effect(target: Dictionary, key: String, raw_amount: Variant,
		card_id: String = "", decision_index: int = -1,
		apply_path: bool = false) -> bool:
	if not (raw_amount is int or raw_amount is float) \
			or float(raw_amount) != float(int(raw_amount)):
		return false
	var amount := int(raw_amount)
	var path_skill = PathSkillFlow.new(_content)
	if key == "pill":
		# EffectService.addResource('pills', value, 1) treats this authored
		# numeric value as the pill ID. Preserve that browser behavior exactly.
		if amount < 0 or not target.get("resources", {}).get("pills", {}) is Dictionary:
			return false
		var pills: Dictionary = target["resources"]["pills"]
		var pill_id := str(amount)
		pills[pill_id] = int(pills.get(pill_id, 0)) + 1
		return true
	if apply_path or not card_id.is_empty():
		amount = path_skill.effect_delta(target, key, amount, card_id, decision_index)
		if not path_skill.last_error.is_empty():
			return false
	if key in ["cultivation", "daoHeart", "health", "fortune", "karmaGood", "karmaBad", "tianji"]:
		amount = LegacyFragmentFlow.effective_delta(target, key, amount)
		var maximum := 100
		match key:
			"cultivation": maximum = 100
			"daoHeart": maximum = LegacyFragmentFlow.actual_max_dao_heart(target)
			"health": maximum = path_skill.actual_max_health(target, decision_index)
		if not path_skill.last_error.is_empty():
			return false
		if key == "health" and amount < 0 and int(target["attributes"].get("aura", 0)) > 0:
			var absorbed := mini(int(target["attributes"]["aura"]), -amount)
			target["attributes"]["aura"] = int(target["attributes"]["aura"]) - absorbed
			amount += absorbed
		target["attributes"][key] = clampi(int(target["attributes"].get(key, 0)) + amount, 0, maximum)
		return true
	if key in ["spiritStone", "lifespan"]:
		target["resources"][key] = maxi(0, int(target["resources"].get(key, 0)) + amount)
		return true
	return false


func _plant_seed(target: Dictionary, card: Dictionary, choice: Dictionary,
		direction: String, decision: int) -> bool:
	if not target.has("karmaPromiseFlags"):
		target["karmaPromiseFlags"] = {}
	if not target.has("karmaSeeds"):
		target["karmaSeeds"] = []
	var raw: Variant = choice.get("karmaSeed")
	var spec: Dictionary = {"id": raw, "seedType": "karma", "delay": 5,
		"priority": 1} if raw is String else raw
	if not spec is Dictionary or String(spec.get("id", "")).is_empty():
		return false
	var seed_id := String(spec["id"])
	for existing in target.get("karmaSeeds", []):
		if existing.get("id") == seed_id:
			var raw_delay := int(spec.get("delay", 5))
			if raw_delay < int(existing.get("delay", 0)):
				existing["delay"] = raw_delay
				existing["priority"] = maxi(int(existing.get("priority", 0)),
					int(spec.get("priority", 0)))
			target["karmaPromiseFlags"][seed_id] = true
			return true
	var delay := maxi(1, roundi(int(spec.get("delay", 5)) * 1.5))
	var seed := {"id": seed_id, "seedType": spec.get("seedType", "karma"),
		"delay": delay, "realm": spec.get("realm"), "path": spec.get("path"),
		"priority": int(spec.get("priority", 0)), "originTurn": decision,
		"originLife": int(target.get("lifeCount", 0)),
		"originCard": card["id"], "originChoice": direction,
		"originThread": spec.get("originThread"), "originQuest": spec.get("originQuest"),
		"originOutcome": spec.get("originOutcome"), "description": spec.get("description"),
		"tags": spec.get("tags", []), "payoffEvent": spec.get("payoffEvent"),
		"context": {"sourceTitle": card.get("title", card["id"]),
			"choiceText": choice.get("text", direction), "realm": spec.get("realm", "qi"),
			"path": spec.get("path", target.get("path"))},
		"consumed": false, "mergeGroup": spec.get("mergeGroup"),
		"cancelGroup": spec.get("cancelGroup")}
	target["karmaSeeds"].append(seed)
	target["karmaPromiseFlags"][seed_id] = true
	return true


func _settle_spine(target: Dictionary, card: Dictionary,
		direction: String, decision: int) -> bool:
	var spine: Dictionary = card.get("narrativeSpine", {})
	if spine.is_empty():
		return true
	var graph: Variant = _content.read_module("narrative:causal_graph")
	if not graph is Dictionary:
		return false
	var definitions: Dictionary = {}
	for entry in graph.get("factTypes", []):
		if entry is Dictionary and entry.has("factTypeId"):
			definitions[String(entry["factTypeId"])] = entry
	var flow: Dictionary = target.get("noncombatFlow", {})
	var facts: Dictionary = flow.get("spineFacts", {}).duplicate(true)
	var consumptions: Dictionary = flow.get("spineConsumptions", {}).duplicate(true)
	var life_count := int(target.get("lifeCount", 0))
	for fact_type in spine.get("consumes", []):
		var instance_id := "fact:%d:%s" % [life_count, String(fact_type)]
		var fact: Dictionary = facts.get(instance_id, {})
		var consumer_id := String(spine.get("consumerIds", {}).get(fact_type, ""))
		var definition: Dictionary = definitions.get(String(fact_type), {})
		var consumer: Dictionary = {}
		for entry in definition.get("consumers", []):
			if entry is Dictionary and entry.get("consumerId") == consumer_id:
				consumer = entry
				break
		var key := instance_id + ":" + consumer_id
		if fact.get("status") != "active" or consumer_id.is_empty() \
				or consumer.get("mode") == "observe" or consumptions.has(key) \
				or decision < int(fact.get("createdDecisionIndex", -1000)) + int(consumer.get("earliestDecisionOffset", 0)) \
				or decision > int(fact.get("createdDecisionIndex", -1000)) + int(consumer.get("latestDecisionOffset", -1)):
			return false
		consumptions[key] = {"factInstanceId": instance_id,
			"factTypeId": fact_type, "consumerId": consumer_id,
			"consumedDecisionIndex": decision,
			"receipt": {"threadId": spine.get("threadId"), "step": spine.get("step"),
				"sourceCardId": card["id"], "direction": direction}}
		fact["status"] = "consumed"
		fact["consumedDecisionIndex"] = decision
		fact["consumedBy"] = consumer_id
		facts[instance_id] = fact
	for fact_type in spine.get("produces", []):
		var instance_id := "fact:%d:%s" % [life_count, String(fact_type)]
		if not definitions.has(String(fact_type)) or facts.has(instance_id):
			return false
		var payload: Dictionary = {"threadId": spine.get("threadId"),
			"step": spine.get("step"), "sourceCardId": card["id"],
			"direction": direction}
		payload.merge(spine.get("choicePayload", {}).get(direction, {}), true)
		payload["observedOrigins"] = []
		facts[instance_id] = {"factInstanceId": instance_id,
			"factTypeId": fact_type, "lifeCount": life_count, "status": "active",
			"producerId": "%s:%s" % [card["id"], direction],
			"payload": payload, "createdDecisionIndex": decision,
			"terminalClosure": null, "closedDecisionIndex": null}
	flow["spineFacts"] = facts
	flow["spineConsumptions"] = consumptions
	target["noncombatFlow"] = flow
	return true


static func tick_seeds(target: Dictionary) -> void:
	var seeds: Array = target.get("karmaSeeds", [])
	for seed in seeds:
		if seed is Dictionary:
			seed["delay"] = int(seed.get("delay", 0)) - 1
	target["pendingKarmaSeeds"] = seeds.duplicate(true)
