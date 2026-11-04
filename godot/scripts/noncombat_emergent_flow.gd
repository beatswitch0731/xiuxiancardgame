extends RefCounted

const LegacyFragmentFlow = preload("res://scripts/noncombat_legacy_fragment_flow.gd")
const MilestoneFlow = preload("res://scripts/noncombat_milestone_flow.gd")
const DERIVED_PATH := "res://content/derived/story_emergent_cards.json"
const DERIVED_SHA := "626f263cdbc605c11dd811173ebc5d98c4c7390e69609327f0abe09567c063bc"
const SOURCE_JS_SHA := "08cd0d1ac24caeae35629210a0f2de0a24a563c7e3c4ea2da3ffe346f8f0a1e4"
const NARRATIVE_LEDGER_JS_SHA := "485c6d61b335db1a418900a552d3b001aea66348b8ba02ef8b82111264c9e20a"
const CARD_ID := "em_heaven_gaze"
const REPEAT_COOLDOWN := 12

var last_error := ""
var derived_path := DERIVED_PATH


func source_sha() -> String:
	return SOURCE_JS_SHA


func derived_sha() -> String:
	return FileAccess.get_sha256(derived_path) if FileAccess.file_exists(derived_path) else ""


func source_available() -> bool:
	last_error = ""
	return not _card().is_empty()


func resume(state: Dictionary) -> Dictionary:
	last_error = ""
	if state.get("phase") != "FLOW_PENDING" or state.get("realm") != "qi" \
			or state.get("noncombatFlow", {}).get("scope") not in ["first_session_avoid", "first_session_combat"]:
		return {}
	if not _heaven_due(state):
		return {}
	var card := _card()
	if card.is_empty():
		return {}
	var sha := derived_sha()
	var flow: Dictionary = state.get("noncombatFlow", {})
	if flow.has("emergentSourceSha") and flow["emergentSourceSha"] != SOURCE_JS_SHA \
			or flow.has("emergentDerivedSha") and flow["emergentDerivedSha"] != sha:
		last_error = "涌现叙事来源规则已变化"
		return {}
	var candidate: Dictionary = state.duplicate(true)
	candidate["noncombatFlow"]["emergentSourceSha"] = SOURCE_JS_SHA
	candidate["noncombatFlow"]["emergentDerivedSha"] = sha
	candidate["pendingEmergentCard"] = card
	candidate["currentCardId"] = CARD_ID
	candidate["phase"] = "EMERGENT_PENDING"
	candidate["decisionCheckpoint"] = {"version": 1, "cardId": CARD_ID,
		"sourceCardId": state.get("decisionCheckpoint", {}).get("sourceCardId"),
		"turn": state["turn"], "decisionIndex": state["runClock"]["decisionIndex"],
		"flowSource": "narrative:45", "narrativeSource": "emergent_narrative"}
	return candidate


func settle(state: Dictionary, direction: String) -> Dictionary:
	last_error = ""
	if state.get("phase") != "EMERGENT_PENDING" or state.get("currentCardId") != CARD_ID \
			or direction not in ["left", "right"]:
		return {}
	var card := _card()
	if card.is_empty():
		return {}
	var flow: Dictionary = state.get("noncombatFlow", {})
	if flow.get("emergentSourceSha") != SOURCE_JS_SHA \
			or flow.get("emergentDerivedSha") != derived_sha() \
			or JSON.parse_string(JSON.stringify(state.get("pendingEmergentCard", {}))) != \
				JSON.parse_string(JSON.stringify(card)):
		last_error = "涌现叙事待选卡与来源不符"
		return {}
	var effects: Dictionary = card.get("choices", {}).get(direction, {}).get("effects", {})
	if effects.is_empty():
		return {}
	var candidate: Dictionary = state.duplicate(true)
	for key in effects:
		if key not in ["cultivation", "fortune", "daoHeart", "karmaBad"] \
				or not _integer(effects[key]):
			return {}
		var maximum := LegacyFragmentFlow.actual_max_dao_heart(candidate) if key == "daoHeart" else 100
		candidate["attributes"][key] = clampi(
			int(candidate["attributes"].get(key, 0)) +
			LegacyFragmentFlow.effective_delta(candidate, key, int(effects[key])), 0, maximum)
	var base_index := int(state.get("runClock", {}).get("decisionIndex", -1))
	var life_id := String(state.get("runClock", {}).get("lifeId", ""))
	if base_index < 0 or not life_id.ends_with(":life:0"):
		return {}
	var next_index := base_index + 1
	var receipt := "decision:%s:choice:%s:%d" % [life_id, CARD_ID, next_index]
	if candidate["runClock"]["receipts"].has(receipt):
		return {}
	candidate["choiceHistory"].append({"cardId": CARD_ID,
		"cardType": "EMERGENT", "direction": direction,
		"turn": base_index, "decisionIndex": next_index,
		"tags": card.get("tags", []).duplicate(true)})
	while candidate["choiceHistory"].size() > 30:
		candidate["choiceHistory"].pop_front()
	for tag in card.get("tags", []):
		candidate["recentCardTags"].append(tag)
	while candidate["recentCardTags"].size() > 20:
		candidate["recentCardTags"].pop_front()
	candidate["cardsPlayed"].append(CARD_ID)
	candidate["turn"] = next_index
	candidate["runClock"]["decisionIndex"] = next_index
	candidate["runClock"]["receipts"][receipt] = {"token": receipt,
		"decisionIndex": next_index, "sourceCardId": CARD_ID, "kind": "choice"}
	MilestoneFlow.tick_seeds(candidate)
	candidate.erase("pendingEmergentCard")
	candidate["currentCardId"] = ""
	candidate["phase"] = "FLOW_PENDING"
	candidate["decisionCheckpoint"] = {"version": 1, "cardId": null,
		"sourceCardId": CARD_ID, "turn": next_index,
		"decisionIndex": next_index, "flowPending": true}
	return candidate


func _heaven_due(state: Dictionary) -> bool:
	var attrs: Dictionary = state.get("attributes", {})
	if int(attrs.get("fortune", 0)) <= 80 or int(attrs.get("cultivation", 0)) <= 80:
		return false
	var decision_index := int(state.get("runClock", {}).get("decisionIndex", -1))
	for choice in state.get("choiceHistory", []):
		if choice is Dictionary and choice.get("cardId") == CARD_ID:
			var resolved_at := int(choice.get("decisionIndex", -1))
			if resolved_at < 0 or decision_index < resolved_at \
					or decision_index - resolved_at < REPEAT_COOLDOWN:
				return false
	# Preserve the six ordered browser thresholds. Earlier categories own this
	# narrative slot and must not be replaced by the heaven card.
	if int(attrs.get("karmaGood", 0)) > 40 and int(attrs.get("karmaBad", 0)) > 40:
		return false
	if state.get("resources", {}).get("companions", []).is_empty() and int(state.get("turn", 0)) > 30:
		return false
	if state.get("karmaSeeds", []).size() >= 5:
		return false
	if int(state.get("turn", 0)) > 20 and not String(state.get("runClock", {}).get("lifeId", "")).ends_with(":life:0"):
		return false
	return true


func _card() -> Dictionary:
	if not FileAccess.file_exists(derived_path):
		last_error = "涌现叙事派生文件缺失"
		return {}
	if derived_sha() != DERIVED_SHA:
		last_error = "涌现叙事派生文件指纹不符"
		return {}
	var text := FileAccess.get_file_as_string(derived_path)
	var doc: Variant = JSON.parse_string(text)
	if not doc is Dictionary or doc.get("sourceSha256") != SOURCE_JS_SHA \
			or doc.get("source") != "src/systems/StoryNetworkSystem.js" \
			or doc.get("realm") != "qi":
		last_error = "涌现叙事来源校验失败"
		return {}
	var card: Variant = doc.get("cards", {}).get(CARD_ID)
	if not card is Dictionary or card.get("id") != CARD_ID \
			or card.get("type") != "EMERGENT" or card.get("realm") != "qi" \
			or card.has("sceneImage") or card.get("choices", {}).size() != 2:
		last_error = "天道注视来源卡无效"
		return {}
	return card.duplicate(true)


func _integer(value: Variant) -> bool:
	return (value is int or value is float) and float(value) == float(int(value))
