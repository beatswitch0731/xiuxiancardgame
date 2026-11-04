extends RefCounted

# Browser KarmaRippleSystem is the prose/rule authority; this checked projection
# keeps pending cards reproducible without trusting effect text in save data.
const LegacyFragmentFlow = preload("res://scripts/noncombat_legacy_fragment_flow.gd")
const MilestoneFlow = preload("res://scripts/noncombat_milestone_flow.gd")
const ContentRepository = preload("res://scripts/noncombat_content_repository.gd")
const SOURCE_JS_SHA := "b4bb05e930b97e607059b7802b6f0feb0d3723a3ae87ae95310aa8072c065e4c"
const DERIVED_SHA := "3679b95d6e3df93435f4f9caec44fbd0709c0439166f37a086d8cebec9bcc2e5"
const DERIVED_PATH := "res://content/derived/karma_ripple_templates.json"
const RNG_MODULUS := 2147483647
const COOLDOWN := 8

var roll_override := -1.0 # Test-only fixed Math.random projection; not persisted.
var last_error := ""
var _content: RefCounted
var _source_missing := false

func _init(content: RefCounted = null) -> void:
	_content = content if content != null else ContentRepository.new()

func source_missing() -> bool:
	return _source_missing or not FileAccess.file_exists(DERIVED_PATH)

func derived_sha() -> String:
	return FileAccess.get_sha256(DERIVED_PATH) if FileAccess.file_exists(DERIVED_PATH) else ""

func seed_matching_opening_ripple(source: Dictionary,
		source_pending_seeds: Array = []) -> int:
	var history: Variant = source.get("history")
	if not history is Array or history.size() > 1:
		return 0
	var triggered: bool = history.size() == 1
	var event_turn := int(source.get("lastRippleTurn", -8)) if triggered else -8
	if triggered and (not history[0] is Dictionary or event_turn not in [3, 12]
			or history[0].get("turn") != event_turn) \
			or not triggered and source.get("lastRippleTurn") != -8:
		return 0
	var total_ticks: Variant = source.get("totalTicks")
	if not total_ticks is int and not total_ticks is float:
		return 0
	var ticks := int(total_ticks)
	if ticks < 0 or ticks > 14 or float(ticks) != float(total_ticks) \
			or triggered and event_turn > ticks:
		return 0
	var eligible_ids: Array = []
	if triggered:
		if event_turn == 3:
			eligible_ids = [history[0].get("seedId")]
		else:
			for row in source_pending_seeds:
				if row is Dictionary and row.get("id") is String \
						and int(row.get("delay", -999)) + ticks - event_turn >= 0:
					eligible_ids.append(row.id)
		if not eligible_ids.has(history[0].get("seedId")):
			return 0
	var templates: Dictionary = _templates()
	var rows: Array = templates.get("karma", [])
	if rows.is_empty():
		return 0
	for seed in range(1, 100001):
		var rng := {"value": seed}
		if not triggered:
			var no_event := true
			for _tick in maxi(3, ticks):
				if _roll(rng) <= 0.15:
					no_event = false
					break
			if no_event:
				return seed
			continue
		var matched := true
		for _tick in event_turn - 1:
			if _roll(rng) <= 0.15:
				matched = false
				break
		if not matched or _roll(rng) > 0.15:
			continue
		var selected: Variant = eligible_ids[mini(eligible_ids.size() - 1,
			int(floor(_roll(rng) * eligible_ids.size())))]
		var index := mini(rows.size() - 1, int(floor(_roll(rng) * rows.size())))
		if selected != history[0].get("seedId") \
				or rows[index].get("title") != history[0].get("text"):
			continue
		for _tick in range(event_turn + COOLDOWN, ticks + 1):
			if _roll(rng) <= 0.15:
				matched = false
				break
		if matched:
			return seed
	return 0

func settle(prior: Dictionary, candidate: Dictionary, replay_without_ripple: bool,
		replay_activation_index: int, replay_initial_seed: int) -> bool:
	last_error = ""
	_source_missing = false
	var index := int(candidate.get("runClock", {}).get("decisionIndex", -1))
	if index < 0:
		last_error = "因果涟漪决定时钟无效"
		return false
	if not candidate.has("rippleStateVersion"):
		if replay_without_ripple and (replay_activation_index < 0 \
				or index < replay_activation_index):
			return true
		if not prior.is_empty() and index <= int(prior.get("runClock", {}).get(
				"decisionIndex", -1)):
			return true
		if replay_activation_index >= 0 and index > replay_activation_index:
			last_error = "因果涟漪旧档激活点未重放"
			return false
		if _templates().is_empty():
			return false
		var seed := replay_initial_seed if replay_initial_seed > 0 else randi_range(
			1, RNG_MODULUS - 1)
		candidate["rippleStateVersion"] = 1
		candidate["rippleRuleSourceSha"] = SOURCE_JS_SHA
		candidate["rippleDerivedSha"] = DERIVED_SHA
		candidate["rippleActivationIndex"] = index
		candidate["rippleRngState"] = {"initialSeed": seed, "value": seed}
		candidate["karmaRippleState"] = {"version": 1, "lifeCount": _life_count(candidate),
			"lastRippleTurn": -COOLDOWN, "totalTicks": maxi(0, index - 1),
			"history": []}
	if not _valid(candidate):
		return false
	if prior.is_empty() or index <= int(prior.get("runClock", {}).get("decisionIndex", -1)):
		return true
	# Closing a vendor settles its held choice but does not rerun game.js's
	# post-choice ambient tick. A destiny trigger already consumed that slot.
	if prior.get("phase") == "VENDOR_OPEN" \
			or candidate.get("phase") in ["VENDOR_RESULT_PENDING", "DESTINY_WHEEL_PENDING"]:
		return true
	var ripple: Dictionary = candidate["karmaRippleState"]
	ripple["totalTicks"] = index
	if index - int(ripple["lastRippleTurn"]) < COOLDOWN:
		return true
	var realm_bonus := {"qi": 0, "foundation": 2, "golden": 4,
		"nascent": 6, "deity": 8, "tribulation": 10}
	var rate := 0.15 + float(realm_bonus.get(candidate.get("realm", "qi"), 0)) / 100.0
	if _roll(candidate["rippleRngState"]) > rate:
		return true
	var active: Array = []
	var prior_delay: Dictionary = {}
	for old_seed in prior.get("karmaSeeds", []):
		if old_seed is Dictionary:
			prior_delay[String(old_seed.get("id", ""))] = int(old_seed.get("delay", 0))
	for seed in candidate.get("karmaSeeds", []):
		# Browser evaluates ripple before karmaSystem.tick decrements delays.
		# Candidate already contains the decremented value; prior preserves an
		# existing seed that crossed 1→0 (or a legacy double tick) this turn.
		if seed is Dictionary and (int(prior_delay.get(String(seed.get("id", "")), 0)) > 0 \
				or not prior_delay.has(String(seed.get("id", ""))) \
				and int(seed.get("delay", -1)) >= 0):
			active.append(seed)
	if active.is_empty():
		return true
	var selected: Dictionary = active[mini(active.size() - 1,
		int(floor(_roll(candidate["rippleRngState"]) * active.size())))]
	var seed_type := String(selected.get("seedType", "karma"))
	var templates := _templates()
	var rows: Array = templates.get(seed_type, templates.get("karma", []))
	if rows.is_empty():
		return false
	var template: Dictionary = rows[mini(rows.size() - 1,
		int(floor(_roll(candidate["rippleRngState"]) * rows.size())))]
	var card := _build_card(candidate, selected, index, template)
	if card.is_empty():
		return false
	ripple["lastRippleTurn"] = index
	ripple["history"].append({"turn": index, "seedId": selected["id"],
		"seedType": seed_type, "text": template["title"]})
	while ripple["history"].size() > 50:
		ripple["history"].pop_front()
	candidate["pendingRippleCard"] = card
	return true

func resume(state: Dictionary) -> Dictionary:
	last_error = ""
	_source_missing = false
	if state.get("phase") != "FLOW_PENDING" or not state.has("pendingRippleCard"):
		return {}
	if not _valid(state):
		return {}
	var pending: Variant = state.get("pendingRippleCard")
	if not pending is Dictionary:
		return {}
	var card := _restore_card(state, pending)
	if card.is_empty():
		last_error = "因果涟漪待发卡与来源不符"
		return {}
	var candidate: Dictionary = state.duplicate(true)
	candidate["pendingRippleChoiceCard"] = card
	candidate.erase("pendingRippleCard")
	candidate["currentCardId"] = card["id"]
	candidate["phase"] = "RIPPLE_PENDING"
	candidate["decisionCheckpoint"] = {"version": 1, "cardId": card["id"],
		"sourceCardId": state.get("decisionCheckpoint", {}).get("sourceCardId"),
		"turn": state["turn"], "decisionIndex": state["runClock"]["decisionIndex"],
		"flowSource": "pending:ripple", "seedId": card["seedId"]}
	return candidate

func settle_choice(state: Dictionary, direction: String) -> Dictionary:
	last_error = ""
	_source_missing = false
	if state.get("phase") != "RIPPLE_PENDING" or direction not in ["left", "right"] \
			or not _valid(state):
		return {}
	var card: Dictionary = state.get("pendingRippleChoiceCard", {})
	if card.is_empty() or _restore_card(state, card).is_empty():
		return {}
	var effects: Dictionary = card.get("choices", {}).get(direction, {}).get("effects", {})
	if effects.is_empty():
		return {}
	var candidate: Dictionary = state.duplicate(true)
	for key in effects:
		if key not in ["cultivation", "fortune", "daoHeart", "karmaBad",
				"health", "maxHealth"] or not _integer(effects[key]):
			return {}
		if key == "maxHealth":
			candidate["maxHealth"] = maxi(1, int(candidate.get("maxHealth", 1)) + int(effects[key]))
			if int(effects[key]) > 0:
				candidate["attributes"]["health"] = clampi(
					int(candidate["attributes"].get("health", 0)) + int(effects[key]),
					0, LegacyFragmentFlow.actual_max_health(candidate))
		else:
			var maximum := LegacyFragmentFlow.actual_max_dao_heart(candidate) \
				if key == "daoHeart" else (LegacyFragmentFlow.actual_max_health(candidate) \
				if key == "health" else 100)
			candidate["attributes"][key] = clampi(int(candidate["attributes"].get(key, 0)) \
				+ LegacyFragmentFlow.effective_delta(candidate, key, int(effects[key])), 0, maximum)
	if int(effects.get("health", 0)) < 0 or int(effects.get("daoHeart", 0)) < 0:
		candidate["resources"]["lifespan"] = maxi(0,
			int(candidate["resources"].get("lifespan", 0)) - 1)
	var next_index := int(candidate["runClock"]["decisionIndex"]) + 1
	var receipt := "decision:%s:choice:%s:%d" % [candidate["runClock"]["lifeId"],
		card["id"], next_index]
	if candidate["runClock"]["receipts"].has(receipt):
		return {}
	candidate["choiceHistory"].append({"cardId": card["id"], "cardType": "KARMA_RIPPLE",
		"direction": direction, "turn": next_index - 1, "decisionIndex": next_index,
		"tags": []})
	while candidate["choiceHistory"].size() > 30:
		candidate["choiceHistory"].pop_front()
	candidate["cardsPlayed"].append(card["id"])
	candidate["turn"] = next_index
	candidate["runClock"]["decisionIndex"] = next_index
	candidate["runClock"]["receipts"][receipt] = {"token": receipt,
		"decisionIndex": next_index, "sourceCardId": card["id"], "kind": "choice"}
	MilestoneFlow.tick_seeds(candidate)
	candidate.erase("pendingRippleChoiceCard")
	candidate["currentCardId"] = ""
	candidate["phase"] = "FLOW_PENDING"
	candidate["decisionCheckpoint"] = {"version": 1, "cardId": null,
		"sourceCardId": card["id"], "turn": next_index,
		"decisionIndex": next_index, "flowPending": true}
	return candidate

func _build_card(state: Dictionary, seed: Dictionary, turn: int,
		template: Dictionary) -> Dictionary:
	var seed_id := String(seed.get("id", ""))
	var seed_type := String(seed.get("seedType", "karma"))
	if seed_id.is_empty():
		return {}
	var template_type := seed_type if seed_type in ["karma", "grudge",
		"bloodline", "fate"] else "karma"
	var registered: Dictionary = _content.find("generated_card",
		"karma_ripple_template:" + template_type)
	if registered.get("data") != template \
			or registered.get("seedType") != template_type \
			or registered.get("sourcePath") != "src/systems/KarmaRippleSystem.js" \
			or registered.get("sourceSha256") != SOURCE_JS_SHA \
			or registered.get("derivedCatalogPath") != "godot/content/derived/karma_ripple_templates.json" \
			or registered.get("derivedCatalogPointer") != "$.templates.%s[0]" % template_type \
			or registered.get("derivedCatalogSha256") != DERIVED_SHA \
			or registered.get("producerGodot") != "res://scripts/noncombat_ripple_flow.gd::_build_card":
		return {}
	var image := "assets/cards/events/scene_karma_k_fortune_wheel.png" \
		if seed_type == "fate" else "assets/cards/events/scene_karma_k_echo_karma_chain.png"
	var art: Dictionary = _content.asset_status(image)
	if not art.get("shaVerified", false) or not art.get("textureLoadable", false):
		_source_missing = not art.get("listedInManifest", false) or not art.get("fileExists", false)
		last_error = "因果涟漪原有场景图未通过校验"
		return {}
	return {"id": "karma_ripple:%s:%d:%s" % [state["runClock"]["lifeId"], turn, seed_id],
		"type": "KARMA_RIPPLE", "title": template["title"],
		"description": template["description"], "seedId": seed_id,
		"seedType": seed_type, "rippleTurn": turn, "imagePath": image,
		"npcName": null, "choices": {
			"left": {"text": template.get("leftText", "顺势而为"),
				"effects": template.get("leftEffects", {"cultivation": 5, "daoHeart": 2})},
			"right": {"text": template.get("rightText", "逆天改命"),
				"effects": template.get("rightEffects", {"daoHeart": 5, "cultivation": 3})}}}

func _restore_card(state: Dictionary, snapshot: Dictionary) -> Dictionary:
	var turn := int(snapshot.get("rippleTurn", -1))
	var seed_id := String(snapshot.get("seedId", ""))
	var seed_type := String(snapshot.get("seedType", ""))
	if turn < 0 or seed_id.is_empty() or seed_type.is_empty():
		return {}
	var templates := _templates()
	var rows: Array = templates.get(seed_type, templates.get("karma", []))
	for item in state.get("karmaRippleState", {}).get("history", []):
		if item.get("turn") == turn and item.get("seedId") == seed_id \
				and item.get("seedType") == seed_type:
			for template in rows:
				if template.get("title") == item.get("text"):
					var canonical := _build_card(state, {"id": seed_id,
						"seedType": seed_type}, turn, template)
					return canonical if JSON.parse_string(JSON.stringify(canonical)) == \
						JSON.parse_string(JSON.stringify(snapshot)) else {}
	return {}

func _templates() -> Dictionary:
	if derived_sha() != DERIVED_SHA:
		last_error = "因果涟漪派生模板指纹不符"
		return {}
	var doc: Variant = JSON.parse_string(FileAccess.get_file_as_string(DERIVED_PATH))
	if not doc is Dictionary or doc.get("source") != "src/systems/KarmaRippleSystem.js" \
			or doc.get("sourceSha256") != SOURCE_JS_SHA \
			or not doc.get("templates") is Dictionary:
		last_error = "因果涟漪来源模板无效"
		return {}
	return doc["templates"]

func _valid(state: Dictionary) -> bool:
	if state.get("rippleStateVersion") != 1 \
			or state.get("rippleRuleSourceSha") != SOURCE_JS_SHA \
			or state.get("rippleDerivedSha") != DERIVED_SHA \
			or not state.get("karmaRippleState") is Dictionary \
			or not state.get("rippleRngState") is Dictionary \
			or _templates().is_empty():
		return false
	var rng: Dictionary = state["rippleRngState"]
	var ripple: Dictionary = state["karmaRippleState"]
	return int(rng.get("initialSeed", 0)) > 0 \
		and int(rng.get("value", 0)) > 0 and int(rng.get("value", 0)) < RNG_MODULUS \
		and ripple.get("version") == 1 \
		and ripple.get("lifeCount") == _life_count(state) \
		and ripple.get("history") is Array \
		and ripple.get("history", []).size() <= 50

func _life_count(state: Dictionary) -> int:
	return int(String(state.get("runClock", {}).get("lifeId", "")).get_slice(":", 2))

func _roll(rng: Dictionary) -> float:
	if roll_override >= 0.0:
		return clampf(roll_override, 0.0, 0.999999)
	var value := int((int(rng["value"]) * 48271) % RNG_MODULUS)
	rng["value"] = value
	return float(value) / float(RNG_MODULUS)

func _integer(value: Variant) -> bool:
	return (value is int or value is float) and float(value) == float(int(value))
