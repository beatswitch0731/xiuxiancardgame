extends RefCounted

# Story-side transaction for the source opportunity contract. The caller
# commits the returned candidate with the quest choice in one RunSession write.
const MODULE := "progression:acquisition_opportunities"
const RNG_MODULUS := 2147483647
const DeckAcquisition = preload("res://scripts/noncombat_deck_acquisition.gd")
const TreasureAcquisition = preload("res://scripts/noncombat_treasure_acquisition.gd")

var last_error := ""
var roll_override := -1.0 # Browser parity test seam; never persisted.
var initial_seed_override := 0 # Replay supplies the committed initial seed.
var last_result: Dictionary = {}
var _content: RefCounted


func _init(content: RefCounted) -> void:
	_content = content


func preview(state: Dictionary, opportunity_id: String,
		profile: String, source_card_id: String) -> Dictionary:
	last_error = ""
	var contract: Variant = _content.read_module(MODULE)
	var sha: String = _content.source_sha256(MODULE)
	if not contract is Dictionary or sha.length() != 64:
		last_error = "机缘奖池来源不可用"
		return {}
	if state.has("opportunitySourceSha") and state.opportunitySourceSha != sha:
		last_error = "机缘奖池来源版本已变化"
		return {}
	var opportunity: Dictionary = contract.get("opportunities", {}).get(opportunity_id, {})
	if opportunity.is_empty() or not opportunity.get("profiles", {}).has(profile) \
			or opportunity.get("sourceCardId") != source_card_id \
			or opportunity.get("path") != state.get("path"):
		return {"eligible": false, "reason": "source_mismatch"}
	var order: Array = contract.get("realmOrder", [])
	if not order.has(state.get("realm")) or not order.has(opportunity.get("minRealm")) \
			or order.find(state.get("realm")) < order.find(opportunity.get("minRealm")):
		return {"eligible": false, "reason": "realm_locked"}
	if opportunity.get("oncePerLife") == true and (
			state.get("opportunityAcquisitions", {}).has(opportunity_id) \
			or state.get("opportunityAttempts", {}).has(opportunity_id)):
		return {"eligible": false, "reason": "already_resolved"}
	for special in opportunity.get("specialRules", []):
		if special is Dictionary and special.get("profile") == profile \
				and not _owned(state, special) and _conditions_met(state,
					special.get("conditions", {})):
			return {"eligible": true, "mode": "special", "sourceSha": sha,
				"opportunity": opportunity, "profile": profile,
				"specialReason": special.get("reason"),
				"totalWeight": 1.0,
				"candidates": [_project_candidate(special, 1.0, 100.0)]}
	var weighted: Array = []
	var total := 0.0
	for candidate in opportunity.get("candidates", []):
		if not candidate is Dictionary or _owned(state, candidate) \
				or not _conditions_met(state, candidate.get("conditions", {})):
			continue
		var weight := _weight(state, candidate, profile, opportunity)
		if weight <= 0.0:
			continue
		weighted.append(_project_candidate(candidate, weight, 0.0))
		total += weight
	if total <= 0.0:
		return {"eligible": false, "reason": "pool_exhausted", "sourceSha": sha}
	for row in weighted:
		row["probability"] = roundf(float(row.weight) / total * 10000.0) / 100.0
	return {"eligible": true, "mode": "weighted", "sourceSha": sha,
		"opportunity": opportunity, "profile": profile,
		"totalWeight": total, "candidates": weighted}


func format_preview(state: Dictionary, opportunity_id: String,
		profile: String, source_card_id: String) -> String:
	var offer := preview(state, opportunity_id, profile, source_card_id)
	if offer.get("eligible") != true:
		var reasons := {"realm_locked": "境界尚未契合",
			"source_mismatch": "来源因果不符", "pool_exhausted": "此处传承已尽",
			"already_resolved": "此生机缘已结"}
		return String(reasons.get(offer.get("reason"), "机缘尚未显形"))
	if offer.mode == "special":
		return "特殊机缘已显：" + String(offer.candidates[0].rewardName)
	var names: Array[String] = []
	for row in offer.candidates:
		names.append("%s %d%%" % [row.rewardName, roundi(float(row.probability))])
	return "%s：%s" % [offer.opportunity.profiles[profile].get("name", profile),
		" · ".join(names)]


func resolve(state: Dictionary, opportunity_id: String, profile: String,
		source_card_id: String, decision_index: int) -> Dictionary:
	last_result = {}
	var offer := preview(state, opportunity_id, profile, source_card_id)
	if offer.get("eligible") != true or decision_index != int(state.get(
			"runClock", {}).get("decisionIndex", -2)) + 1:
		last_error = String(offer.get("reason", last_error))
		return {}
	var candidate: Dictionary = state.duplicate(true)
	var rng: Dictionary = candidate.get("opportunityRngState", {})
	if rng.is_empty():
		var seed := initial_seed_override if initial_seed_override > 0 else randi_range(
			1, RNG_MODULUS - 1)
		rng = {"initialSeed": seed, "value": seed}
	elif int(rng.get("initialSeed", 0)) <= 0 or int(rng.get("value", 0)) <= 0 \
			or int(rng.get("value", 0)) >= RNG_MODULUS:
		last_error = "机缘随机账本无效"
		return {}
	var next_value := int((int(rng.value) * 48271) % RNG_MODULUS)
	rng["value"] = next_value
	candidate["opportunityRngState"] = rng
	var roll := clampf(roll_override, 0.0, 0.999999) if roll_override >= 0.0 \
		else float(next_value) / float(RNG_MODULUS)
	var selected: Dictionary = offer.candidates[0]
	if offer.mode == "weighted":
		var threshold := roll * float(offer.totalWeight)
		var cursor := 0.0
		selected = offer.candidates.back()
		for row in offer.candidates:
			cursor += float(row.weight)
			if threshold < cursor:
				selected = row
				break
	var opportunity: Dictionary = offer.opportunity
	var reward_id := String(selected.rewardId)
	if selected.rewardType == "card":
		var acquired := DeckAcquisition.new(_content).acquire_legacy(candidate,
			reward_id, source_card_id, String(opportunity.sourceType), int(state.turn),
			{"locationId": opportunity.get("locationId"), "mode": offer.mode,
				"chance": 100.0 if offer.mode == "special" else selected.probability,
				"roll": 0 if offer.mode == "special" else int(floor(roll * 100.0)) + 1})
		if acquired.is_empty():
			last_error = "机缘技能牌取得失败"
			return {}
		candidate = acquired
	elif selected.rewardType == "treasure":
		var source_id := opportunity_id + ":" + source_card_id
		var transaction_id := "treasure:opportunity:life:%s:decision:%d:source:%s:item:%s" % [
			candidate.get("runClock", {}).get("lifeId", ""), decision_index,
			source_id, reward_id]
		if not TreasureAcquisition.new(_content).acquire(candidate, reward_id,
				source_card_id, decision_index,
				{"source": "opportunity_reward", "sourceId": source_id,
					"opportunityId": opportunity_id,
					"channel": opportunity.sourceType,
					"transactionId": transaction_id, "details": {}}):
			last_error = "机缘法宝取得失败"
			return {}
	else:
		last_error = "机缘奖励类型未接入"
		return {}
	var record := {"opportunityId": opportunity_id,
		"opportunityName": opportunity.get("name"), "sourceId": source_card_id,
		"sourceType": opportunity.sourceType,
		"locationId": opportunity.get("locationId"),
		"locationName": opportunity.get("locationName"),
		"profile": profile, "profileName": opportunity.profiles[profile].get("name"),
		"realm": state.get("realm"), "path": state.get("path"),
		"turn": int(state.get("turn", 0)), "mode": offer.mode,
		"roll": 0 if offer.mode == "special" else floor(roll * 10000.0) / 100.0,
		"rewardType": selected.rewardType, "rewardId": reward_id,
		"rewardName": selected.rewardName,
		"probability": 100.0 if offer.mode == "special" else selected.probability,
		"candidates": []}
	for row in offer.candidates:
		record.candidates.append({"rewardType": row.rewardType,
			"rewardId": row.rewardId, "probability": row.probability})
	candidate["opportunityAttempts"] = candidate.get("opportunityAttempts", {})
	candidate["opportunityAcquisitions"] = candidate.get("opportunityAcquisitions", {})
	candidate.opportunityAttempts[opportunity_id] = record.duplicate(true)
	candidate.opportunityAcquisitions[opportunity_id] = record.duplicate(true)
	candidate["opportunitySourceSha"] = offer.sourceSha
	last_result = record.duplicate(true)
	return candidate


func _project_candidate(source: Dictionary, weight: float, probability: float) -> Dictionary:
	return {"rewardType": source.get("rewardType"), "rewardId": source.get("rewardId"),
		"rewardName": source.get("rewardName"), "weight": weight,
		"probability": probability}


func _owned(state: Dictionary, reward: Dictionary) -> bool:
	if reward.get("rewardType") == "card":
		return state.get("deck", []).has(reward.get("rewardId")) \
			or state.get("skillAcquisitions", {}).has(reward.get("rewardId"))
	if reward.get("rewardType") == "treasure":
		return state.get("resources", {}).get("treasures", []).has(reward.get("rewardId"))
	return true


func _conditions_met(state: Dictionary, conditions: Dictionary) -> bool:
	for key in conditions.get("requiredAttributes", {}):
		if float(state.get("attributes", {}).get(key, 0)) < float(conditions.requiredAttributes[key]):
			return false
	for key in conditions.get("maximumAttributes", {}):
		if float(state.get("attributes", {}).get(key, 0)) > float(conditions.maximumAttributes[key]):
			return false
	for key in conditions.get("requiredKnowledge", {}):
		if float(state.get("knowledge", {}).get(key, 0)) < float(conditions.requiredKnowledge[key]):
			return false
	for key in conditions.get("requiredFlags", []):
		if state.get("flags", {}).get(key) != true:
			return false
	for key in conditions.get("forbiddenFlags", []):
		if state.get("flags", {}).get(key) == true:
			return false
	for key in conditions.get("requiredFactionReputation", {}):
		if float(state.get("factionProgress", {}).get("reputations", {}).get(key, 0)) < float(
			conditions.requiredFactionReputation[key]):
			return false
	for key in conditions.get("requiredNpcAffection", {}):
		if float(state.get("npcAffection", {}).get(key, 0)) < float(
			conditions.requiredNpcAffection[key]):
			return false
	return true


func _weight(state: Dictionary, item: Dictionary, profile: String,
		opportunity: Dictionary) -> float:
	var weight := float(item.get("baseWeight", 0)) + float(item.get(
		"profileBonuses", {}).get(profile, 0))
	for key in item.get("attributeScales", {}):
		var factor: Dictionary = item.attributeScales[key]
		weight += (float(state.get("attributes", {}).get(key, 0)) - float(
			factor.get("center", 0))) * float(factor.get("scale", 0))
	for key in item.get("knowledgeScales", {}):
		weight += float(state.get("knowledge", {}).get(key, 0)) * float(
			item.knowledgeScales[key])
	for key in item.get("factionReputationScales", {}):
		weight += float(state.get("factionProgress", {}).get("reputations", {}).get(
			key, 0)) * float(item.factionReputationScales[key])
	for key in item.get("npcAffectionScales", {}):
		weight += float(state.get("npcAffection", {}).get(key, 0)) * float(
			item.npcAffectionScales[key])
	var bounds: Dictionary = opportunity.get("weightClamp", {})
	return clampf(roundf(weight * 1000.0) / 1000.0,
		float(bounds.get("min", 0)), float(bounds.get("max", 1.0e12)))
