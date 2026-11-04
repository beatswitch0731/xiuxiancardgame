extends RefCounted

const MilestoneFlow = preload("res://scripts/noncombat_milestone_flow.gd")
const LegacyFragmentFlow = preload("res://scripts/noncombat_legacy_fragment_flow.gd")
const ContentRepository = preload("res://scripts/noncombat_content_repository.gd")
const SOURCE_JS_SHA := "67f2f543bbbc04f340cee18afb00d7f43cbae28dd9e65d3eb2a15cac31ef12c2"
const DERIVED_SHA := "16946a5d930631f36a610ceb42cbb063ea7b68d56c15a7b814f688427f4df209"
const DERIVED_PATH := "res://content/derived/heavens_hint_pool.json"
const RNG_MODULUS := 2147483647

var roll_override := -1.0
var legacy_life_count := false
var legacy_clue_sink := false
var last_error := ""
var _source_missing := false
var _content: RefCounted

func _init(content: RefCounted = null) -> void:
	_content = content if content != null else ContentRepository.new()

func derived_sha() -> String:
	return FileAccess.get_sha256(DERIVED_PATH) if FileAccess.file_exists(DERIVED_PATH) else ""

func source_missing() -> bool:
	return _source_missing or not FileAccess.file_exists(DERIVED_PATH)

func choice_available(state: Dictionary, direction: String) -> bool:
	if state.get("phase") != "HINT_PENDING":
		return false
	var choices: Dictionary = state.get("pendingHintChoiceCard", {}).get("choices", {})
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
	for key in effects:
		if key not in ["cultivation", "fortune", "daoHeart", "karmaGood", "health"] or not _integer(effects[key]) or int(effects[key]) <= 0:
			return false
		var maximum := LegacyFragmentFlow.actual_max_dao_heart(state) if key == "daoHeart" else (LegacyFragmentFlow.actual_max_health(state) if key == "health" else 100)
		if int(state.get("attributes", {}).get(key, 0)) < maximum:
			return false
	return true

func settle(prior: Dictionary, candidate: Dictionary, replay_without_hint: bool,
		replay_activation_index: int, replay_initial_seed: int) -> bool:
	last_error = ""
	_source_missing = false
	var index := int(candidate.get("runClock", {}).get("decisionIndex", -1))
	if index < 0:
		last_error = "天机决定时钟无效"
		return false
	if not candidate.has("hintStateVersion"):
		if replay_without_hint and index < replay_activation_index:
			return true
		if not prior.is_empty() and index <= int(prior.get("runClock", {}).get("decisionIndex", -1)):
			return true
		if replay_activation_index >= 0 and index > replay_activation_index:
			last_error = "天机旧档激活点未重放"
			return false
		if _pool().is_empty():
			return false
		var seed := replay_initial_seed if replay_initial_seed > 0 else randi_range(1, RNG_MODULUS - 1)
		candidate["hintStateVersion"] = 1
		candidate["hintRuleSourceSha"] = SOURCE_JS_SHA
		candidate["hintDerivedSha"] = DERIVED_SHA
		candidate["hintActivationIndex"] = index
		candidate["hintRngState"] = {"initialSeed": seed, "value": seed}
		candidate["heavensHintState"] = {"version": 1,
			"lifeCount": 0 if legacy_life_count else int(candidate.get("lifeCount", 0)),
			"totalTicks": maxi(0, index - 1),
			"nextTrigger": index + 15 + int(floor(_roll(candidate["hintRngState"]) * 11)),
			"hintsRevealed": [], "issuedHints": [], "seerRevelation": 0}
	if not _valid(candidate):
		return false
	if prior.is_empty() or index <= int(prior.get("runClock", {}).get("decisionIndex", -1)):
		return true
	if prior.get("phase") == "VENDOR_OPEN" or candidate.get("phase") in ["VENDOR_RESULT_PENDING", "DESTINY_WHEEL_PENDING", "BATTLE_PENDING", "WARNING_PENDING"] or index <= 5 and candidate.get("noncombatFlow", {}).get("scope") == "first_session_avoid" and index < int(candidate.get("earlyAvoidActivationIndex", 2147483647)) or int(candidate.get("karmaRippleState", {}).get("lastRippleTurn", -99)) == index:
		return true
	var hint: Dictionary = candidate["heavensHintState"]
	hint["totalTicks"] = index
	if index < int(hint["nextTrigger"]):
		return true
	var mod := {"qi": 1.0, "foundation": 0.9, "golden": 0.8,
		"nascent": 0.7, "deity": 0.6, "tribulation": 0.5}
	var interval := 15 + int(floor(_roll(candidate["hintRngState"]) * 10))
	hint["nextTrigger"] = index + maxi(5, roundi(interval * float(mod.get(candidate.get("realm", "qi"), 1.0))))
	var pool := _pool()
	if pool.is_empty():
		return false
	var available: Array = []
	for i in pool.size():
		var already_revealed := false
		for revealed in hint["hintsRevealed"]:
			if int(revealed) == i:
				already_revealed = true
				break
		if not already_revealed:
			available.append(i)
	var selection_size := available.size() if not available.is_empty() else pool.size()
	var picked := mini(selection_size - 1, int(floor(_roll(candidate["hintRngState"]) * selection_size)))
	var hint_index: int = int(available[picked]) if not available.is_empty() else picked
	if not available.is_empty():
		hint["hintsRevealed"].append(hint_index)
	hint["issuedHints"].append({"turn": index, "index": hint_index})
	hint["seerRevelation"] = mini(100, int(hint["seerRevelation"]) + 3)
	var card := _project(candidate, index, hint_index, pool[hint_index])
	if card.is_empty():
		return false
	candidate["pendingHintCard"] = card
	return true

func resume(state: Dictionary) -> Dictionary:
	last_error = ""
	if state.get("phase") != "FLOW_PENDING" or not state.has("pendingHintCard"):
		return {}
	if not _valid(state) or not state["pendingHintCard"] is Dictionary:
		return {}
	var card := _restore_card(state, state["pendingHintCard"])
	if card.is_empty():
		last_error = "天机待发卡与来源不符"
		return {}
	var candidate: Dictionary = state.duplicate(true)
	candidate["pendingHintChoiceCard"] = card
	candidate.erase("pendingHintCard")
	candidate["currentCardId"] = card["id"]
	candidate["phase"] = "HINT_PENDING"
	candidate["decisionCheckpoint"] = {"version": 1, "cardId": card["id"],
		"sourceCardId": state.get("decisionCheckpoint", {}).get("sourceCardId"),
		"turn": state["turn"], "decisionIndex": state["runClock"]["decisionIndex"],
		"flowSource": "pending:hint", "hintTurn": card["hintTurn"], "hintIndex": card["hintIndex"]}
	return candidate

func settle_choice(state: Dictionary, direction: String) -> Dictionary:
	last_error = ""
	if state.get("phase") != "HINT_PENDING" or direction not in ["left", "right"] or not choice_available(state, direction) or not _valid(state):
		return {}
	var card: Dictionary = state.get("pendingHintChoiceCard", {})
	if card.is_empty() or _restore_card(state, card).is_empty():
		return {}
	var effects: Dictionary = card["choices"][direction]["effects"]
	var candidate: Dictionary = state.duplicate(true)
	for key in effects:
		var value: Variant = effects[key]
		if key == "find_clue":
			if not value is String or String(value).is_empty():
				return {}
			var clues: Array = candidate["noncombatFlow"].get("hintClues", []) if legacy_clue_sink else candidate.get("clues", [])
			var known := false
			for clue in clues:
				if clue is Dictionary and clue.get("id") == value:
					known = true
					break
			if not known:
				if legacy_clue_sink:
					clues.append({"id": value, "sourceCardId": card["id"]})
				else:
					clues.append({"id": value, "source": card["id"],
						"turn": int(candidate.get("turn", 0)), "life": int(candidate.get("lifeCount", 0))})
			if legacy_clue_sink:
				candidate["noncombatFlow"]["hintClues"] = clues
			else:
				candidate["clues"] = clues
			continue
		if not _integer(value):
			return {}
		if key == "spiritStone":
			candidate["resources"]["spiritStone"] = maxi(0, int(candidate["resources"].get("spiritStone", 0)) + int(value))
		elif key == "damageReduction":
			var modifiers: Dictionary = candidate["noncombatFlow"].get("hintModifiers", {})
			modifiers[key] = int(modifiers.get(key, 0)) + int(value)
			candidate["noncombatFlow"]["hintModifiers"] = modifiers
		elif key in ["cultivation", "fortune", "daoHeart", "karmaBad"]:
			var maximum := LegacyFragmentFlow.actual_max_dao_heart(candidate) if key == "daoHeart" else 100
			candidate["attributes"][key] = clampi(int(candidate["attributes"].get(key, 0)) + LegacyFragmentFlow.effective_delta(candidate, key, int(value)), 0, maximum)
		else:
			return {}
	var next_index := int(state["runClock"]["decisionIndex"]) + 1
	var receipt := "decision:%s:choice:%s:%d" % [state["runClock"]["lifeId"], card["id"], next_index]
	if candidate["runClock"]["receipts"].has(receipt):
		return {}
	candidate["runClock"]["receipts"][receipt] = {"token": receipt,
		"decisionIndex": next_index, "sourceCardId": card["id"], "kind": "choice"}
	candidate["choiceHistory"].append({"cardId": card["id"], "cardType": "HEAVENS_HINT",
		"direction": direction, "turn": next_index - 1, "decisionIndex": next_index, "tags": []})
	while candidate["choiceHistory"].size() > 30:
		candidate["choiceHistory"].pop_front()
	candidate["cardsPlayed"].append(card["id"])
	candidate["turn"] = next_index
	candidate["runClock"]["decisionIndex"] = next_index
	MilestoneFlow.tick_seeds(candidate)
	candidate.erase("pendingHintChoiceCard")
	candidate["currentCardId"] = ""
	candidate["phase"] = "FLOW_PENDING"
	candidate["decisionCheckpoint"] = {"version": 1, "cardId": null,
		"sourceCardId": card["id"], "turn": next_index,
		"decisionIndex": next_index, "flowPending": true}
	return candidate

func _project(state: Dictionary, turn: int, hint_index: int, row: Dictionary) -> Dictionary:
	var category := String(row.get("category", ""))
	var text_value := String(row.get("text", ""))
	var interpretation := String(row.get("interpretation", ""))
	if text_value.is_empty() or interpretation.is_empty():
		return {}
	var choices := {}
	var title := ""
	match category:
		"吉兆":
			title = "✨ 天机一闪 · 吉兆"
			choices = {"left": {"text": "顺应天机，接受馈赠", "effects": {"cultivation": 2, "fortune": 1, "spiritStone": 3}},
				"right": {"text": "保持谦逊，不贪天功", "effects": {"daoHeart": 1, "cultivation": 1, "fortune": 1}}}
		"凶兆":
			title = "⚠ 天机一闪 · 凶兆"
			choices = {"left": {"text": "相信预警，提前准备", "effects": {"daoHeart": 1, "damageReduction": 1, "fortune": -1}},
				"right": {"text": "无视凶兆，勇往直前", "effects": {"cultivation": 2, "daoHeart": -1, "karmaBad": 1}}}
		"天机":
			title = "🌀 天机一闪 · 天机"
			var effects := {"daoHeart": 1, "fortune": 1, "cultivation": 1}
			if text_value.contains("飞升非终") or text_value.contains("天道在筛选"):
				effects["find_clue"] = "ancient_prophecy_warning"
			choices = {"left": {"text": "铭记于心", "effects": effects},
				"right": {"text": "顺其自然", "effects": {"cultivation": 2, "fortune": 1}}}
		_: return {}
	return {"id": "heavens_hint:%s:%d:%d" % [state["runClock"]["lifeId"], turn, hint_index],
		"type": "HEAVENS_HINT", "title": title,
		"description": "识海微微震动，一道灵光闪过——\n\n\"%s\"\n\n%s" % [text_value, interpretation],
		"hintCategory": category, "hintIndex": hint_index, "hintTurn": turn, "choices": choices}

func _restore_card(state: Dictionary, snapshot: Dictionary) -> Dictionary:
	var turn: Variant = snapshot.get("hintTurn")
	var idx: Variant = snapshot.get("hintIndex")
	if not _integer(turn) or not _integer(idx) or int(turn) < 0:
		return {}
	var pool := _pool()
	if int(idx) < 0 or int(idx) >= pool.size() or int(turn) > int(state["heavensHintState"]["totalTicks"]):
		return {}
	var issued := false
	for row in state["heavensHintState"]["issuedHints"]:
		if row is Dictionary and row.get("turn") == turn and row.get("index") == idx:
			issued = true
			break
	if not issued:
		return {}
	var canonical := _project(state, int(turn), int(idx), pool[int(idx)])
	return canonical if JSON.parse_string(JSON.stringify(canonical)) == JSON.parse_string(JSON.stringify(snapshot)) else {}

func _pool() -> Array:
	if derived_sha() != DERIVED_SHA:
		_source_missing = not FileAccess.file_exists(DERIVED_PATH)
		last_error = "天机来源模板指纹不符"
		return []
	var doc: Variant = JSON.parse_string(FileAccess.get_file_as_string(DERIVED_PATH))
	if not doc is Dictionary or doc.get("source") != "src/systems/HeavensHintSystem.js" or doc.get("sourceSha256") != SOURCE_JS_SHA or not doc.get("pool") is Array or doc["pool"].size() != 40:
		last_error = "天机来源模板无效"
		return []
	return doc["pool"]

func _valid(state: Dictionary) -> bool:
	if state.get("hintStateVersion") != 1 or state.get("hintRuleSourceSha") != SOURCE_JS_SHA or state.get("hintDerivedSha") != DERIVED_SHA or not state.get("hintRngState") is Dictionary or not state.get("heavensHintState") is Dictionary or _pool().is_empty():
		return false
	var hint: Dictionary = state["heavensHintState"]
	var rng: Dictionary = state["hintRngState"]
	for key in ["initialSeed", "value"]:
		if not _integer(rng.get(key)) or int(rng[key]) <= 0 or int(rng[key]) >= RNG_MODULUS:
			return false
	for key in ["totalTicks", "nextTrigger", "seerRevelation"]:
		if not _integer(hint.get(key)) or int(hint[key]) < 0:
			return false
	if hint.get("version") != 1 or hint.get("lifeCount") != (0 if legacy_life_count else int(state.get("lifeCount", 0))) or not hint.get("hintsRevealed") is Array or not hint.get("issuedHints") is Array or int(hint["nextTrigger"]) <= int(hint["totalTicks"]):
		return false
	var revealed: Array = hint["hintsRevealed"]
	if revealed.size() > 40:
		return false
	var unique := {}
	for idx in revealed:
		if not _integer(idx) or int(idx) < 0 or int(idx) >= 40 or unique.has(int(idx)):
			return false
		unique[int(idx)] = true
	var issued: Array = hint["issuedHints"]
	var issued_unique := {}
	for entry in issued:
		if not entry is Dictionary or not _integer(entry.get("turn")) or not _integer(entry.get("index")):
			return false
		var turn := int(entry["turn"])
		var idx := int(entry["index"])
		var key := "%d:%d" % [turn, idx]
		if turn < 0 or turn > int(hint["totalTicks"]) or idx < 0 or idx >= 40 or not unique.has(idx) or issued_unique.has(key):
			return false
		issued_unique[key] = true
	return true

func _roll(rng: Dictionary) -> float:
	if roll_override >= 0.0:
		return clampf(roll_override, 0.0, 0.999999)
	var value := int((int(rng["value"]) * 48271) % RNG_MODULUS)
	rng["value"] = value
	return float(value) / float(RNG_MODULUS)

func seed_matching_initial_trigger(next_trigger: int) -> int:
	for seed in range(1, 100001):
		var rng := {"value": seed}
		if 15 + int(floor(_roll(rng) * 11)) == next_trigger:
			return seed
	return 0

func _integer(value: Variant) -> bool:
	return (value is int or value is float) and float(value) == float(int(value))
