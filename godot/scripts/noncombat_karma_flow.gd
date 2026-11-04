extends RefCounted
const LegacyFragmentFlow = preload("res://scripts/noncombat_legacy_fragment_flow.gd")
const PathSkillFlow = preload("res://scripts/noncombat_path_skill_flow.gd")

# First source-backed qi payoff after the white-fox terminal.
const MODULE := "cards:karma_expansion"
const SEED_ID := "causal:sword_legacy_start"
const CARD_ID := "kx_path_sword_legacy"
const CHAPTER_MODULE := "cards:karma"
const CHAPTER_SEED_ID := "causal:qi_sword_attune"
const CHAPTER_CARD_ID := "k_chapter_sword_left"
const REBIRTH_BODY_SEED_ID := "causal:qi_body_stance"
const REBIRTH_BODY_CARD_ID := "k_chapter_body_left"
const REBIRTH_BODY_BURDEN_SEED_ID := "causal:qi_body_burden"
const REBIRTH_BODY_BURDEN_CARD_ID := "k_chapter_body_right"
const HOARDED_MANUAL_SEED_ID := "causal:hoarded_manual"
const HOARDED_MANUAL_CARD_ID := "kx_ch_hoarded_manual"
const SHARED_SEED_ID := "causal:shared_opportunity"
const SHARED_CARD_ID := "kx_ch_shared_opportunity"
const SECT_SEED_ID := "causal:sword_sect_path"
const SECT_CARD_ID := "kx_ch_sword_sect_path"
const BODY_SEED_ID := "causal:body_trial_start"
const BODY_CARD_ID := "karma_body_awakening"
const BODY_MODULE := "cards:qi"
const BODY_ECHO_SEED_ID := "bodyTrialStarted"
const BODY_ECHO_CARD_ID := "k_body_echo"
const BODY_ASCENSION_SEED_ID := "bodyTrialDeep"
const BODY_ASCENSION_CARD_ID := "k_body_ascension"
const REALM_ORDER := ["qi", "foundation", "golden", "nascent", "deity", "tribulation"]
const MilestoneFlow = preload("res://scripts/noncombat_milestone_flow.gd")
const DeckAcquisition = preload("res://scripts/noncombat_deck_acquisition.gd")
const NormalChoicePolicy = preload("res://scripts/noncombat_normal_choice_policy.gd")
const CompanionEvents = preload("res://scripts/noncombat_companion_events.gd")
const COMPANION_PAYOFF_IDS := ["kx_companion_bond_acquaint",
	"kx_companion_bond_trust", "kx_companion_bond_deep",
	"kx_companion_bond_ultimate", "kx_companion_bond_hostile"]

var _content: RefCounted
var _deck_acquisition: RefCounted
var _normal_choice_policy: RefCounted
var _companion_events: RefCounted
var last_error := ""

func _init(content: RefCounted) -> void:
	_content = content
	_deck_acquisition = DeckAcquisition.new(content)
	_normal_choice_policy = NormalChoicePolicy.new(content)
	_companion_events = CompanionEvents.new(content)


func resume(state: Dictionary) -> Dictionary:
	last_error = ""
	if state.get("phase") != "FLOW_PENDING" \
			or state.get("realm") not in REALM_ORDER \
			or state.get("noncombatFlow", {}).get("scope") not in [
				"first_session_avoid", "first_session_combat", "rebirth_new_life"]:
		return {}
	var seed := _ready_seed(state)
	var companion_seed := _ready_companion_seed(state)
	if not companion_seed.is_empty() and (seed.is_empty() or int(
			companion_seed.get("priority", 0)) >= int(seed.get("priority", 0))):
		return _resume_companion_payoff(state, companion_seed)
	if seed.is_empty():
		return {}
	var chapter: bool = seed.get("id") in [CHAPTER_SEED_ID,
		REBIRTH_BODY_SEED_ID, REBIRTH_BODY_BURDEN_SEED_ID,
		BODY_ECHO_SEED_ID, BODY_ASCENSION_SEED_ID]
	var body: bool = seed.get("id") == BODY_SEED_ID
	var module_id := CHAPTER_MODULE if chapter else BODY_MODULE if body else MODULE
	var seed_id := CHAPTER_SEED_ID if chapter else BODY_SEED_ID if body else SEED_ID
	var card_id := CHAPTER_CARD_ID if chapter else BODY_CARD_ID if body else CARD_ID
	if seed.get("id") == REBIRTH_BODY_SEED_ID:
		seed_id = REBIRTH_BODY_SEED_ID
		card_id = REBIRTH_BODY_CARD_ID
	elif seed.get("id") == REBIRTH_BODY_BURDEN_SEED_ID:
		seed_id = REBIRTH_BODY_BURDEN_SEED_ID
		card_id = REBIRTH_BODY_BURDEN_CARD_ID
	elif seed.get("id") == HOARDED_MANUAL_SEED_ID:
		seed_id = HOARDED_MANUAL_SEED_ID
		card_id = HOARDED_MANUAL_CARD_ID
	if seed.get("id") == SHARED_SEED_ID:
		seed_id = SHARED_SEED_ID
		card_id = SHARED_CARD_ID
	elif seed.get("id") == SECT_SEED_ID:
		seed_id = SECT_SEED_ID
		card_id = SECT_CARD_ID
	elif seed.get("id") == BODY_ECHO_SEED_ID:
		seed_id = BODY_ECHO_SEED_ID
		card_id = BODY_ECHO_CARD_ID
	elif seed.get("id") == BODY_ASCENSION_SEED_ID:
		seed_id = BODY_ASCENSION_SEED_ID
		card_id = BODY_ASCENSION_CARD_ID
	var source := _source_card(module_id, seed_id, card_id)
	if source.is_empty():
		return {}
	var sha: String = _content.source_sha256(module_id)
	if sha.length() != 64:
		last_error = "因果来源数据未通过校验"
		return {}
	var pin_key := "karmaSourceSha" if chapter else "karmaBodySourceSha" if body \
		else "karmaExpansionSourceSha"
	var prior_pin: Variant = state.get("noncombatFlow", {}).get(pin_key)
	if prior_pin is String and String(prior_pin).length() == 64 and prior_pin != sha:
		last_error = "因果来源规则已变化"
		return {}
	var mapping_sha: String = _content.source_sha256(MODULE) if body else ""
	if body and (mapping_sha.length() != 64 or state.get("noncombatFlow", {}).get(
			"karmaExpansionSourceSha", mapping_sha) != mapping_sha):
		last_error = "因果映射规则已变化"
		return {}
	var card: Dictionary = _materialize_card(source, seed)
	card["_karmaSeedId"] = seed_id
	card["_karmaCardId"] = card_id
	var candidate: Dictionary = state.duplicate(true)
	candidate["noncombatFlow"][pin_key] = sha
	if body:
		candidate["noncombatFlow"]["karmaExpansionSourceSha"] = mapping_sha
	candidate["noncombatFlow"]["karmaArbitrationVersion"] = 1
	candidate["pendingKarmaCard"] = card
	candidate["currentCardId"] = card_id
	candidate["phase"] = "KARMA_PENDING"
	candidate["decisionCheckpoint"] = {"version": 1, "cardId": card_id,
		"sourceCardId": state.get("decisionCheckpoint", {}).get("sourceCardId"),
		"turn": state["turn"], "decisionIndex": state["runClock"]["decisionIndex"],
		"flowSource": "karma", "seedId": seed_id}
	return candidate

func close_redundant_companion_seeds(candidate: Dictionary) -> void:
	if not candidate.get("karmaSeeds") is Array:
		return
	candidate.karmaSeeds = candidate.karmaSeeds.filter(func(row: Variant) -> bool:
		return not row is Dictionary or int(row.get("delay", 1)) > 0 \
			or row.get("payoffEvent") not in COMPANION_PAYOFF_IDS \
			or not candidate.get("cardsPlayed", []).has(
				row.get("payoffEvent")))


func choice_available(state: Dictionary, direction: String = "") -> bool:
	if state.get("currentCardId") in COMPANION_PAYOFF_IDS:
		return _companion_payoff_choice_available(state, direction)
	if state.get("phase") != "KARMA_PENDING" \
			or state.get("currentCardId") not in [CARD_ID, CHAPTER_CARD_ID,
				REBIRTH_BODY_CARD_ID, REBIRTH_BODY_BURDEN_CARD_ID,
				SHARED_CARD_ID, SECT_CARD_ID, BODY_CARD_ID,
				HOARDED_MANUAL_CARD_ID, BODY_ECHO_CARD_ID,
				BODY_ASCENSION_CARD_ID]:
		return false
	if direction.is_empty():
		return true
	var choices: Dictionary = state.get("pendingKarmaCard", {}).get("choices", {})
	if not choices.has(direction):
		return false
	var deck_reward: Variant = choices[direction].get("effects", {}).get("deckCard")
	if deck_reward is String and _deck_acquisition.acquire_legacy(state,
			String(deck_reward), String(state.get("currentCardId", ""))).is_empty():
		return false
	if state.get("currentCardId") == BODY_CARD_ID:
		return _normal_choice_policy.choice_available(state,
			state.get("pendingKarmaCard", {}), direction)
	if not _all_positive_capped(state, choices[direction]):
		return true
	# EffectService.previewCardChoices only unlocks the first capped option
	# when no alternative is executable, so a capped card never hard-locks.
	for other_direction in choices:
		if not _all_positive_capped(state, choices[other_direction]):
			return false
	return direction == String(choices.keys()[0])


func settle(state: Dictionary, direction: String) -> Dictionary:
	last_error = ""
	if state.get("currentCardId") in COMPANION_PAYOFF_IDS:
		return _settle_companion_payoff(state, direction)
	if not choice_available(state, direction) or not direction in ["left", "right"]:
		return {}
	var chapter: bool = state.get("currentCardId") in [CHAPTER_CARD_ID,
		REBIRTH_BODY_CARD_ID, REBIRTH_BODY_BURDEN_CARD_ID,
		BODY_ECHO_CARD_ID, BODY_ASCENSION_CARD_ID]
	var body: bool = state.get("currentCardId") == BODY_CARD_ID
	var module_id := CHAPTER_MODULE if chapter else BODY_MODULE if body else MODULE
	var seed_id := CHAPTER_SEED_ID if chapter else BODY_SEED_ID if body else SEED_ID
	var card_id := CHAPTER_CARD_ID if chapter else BODY_CARD_ID if body else CARD_ID
	if state.get("currentCardId") == REBIRTH_BODY_CARD_ID:
		seed_id = REBIRTH_BODY_SEED_ID
		card_id = REBIRTH_BODY_CARD_ID
	elif state.get("currentCardId") == REBIRTH_BODY_BURDEN_CARD_ID:
		seed_id = REBIRTH_BODY_BURDEN_SEED_ID
		card_id = REBIRTH_BODY_BURDEN_CARD_ID
	elif state.get("currentCardId") == HOARDED_MANUAL_CARD_ID:
		seed_id = HOARDED_MANUAL_SEED_ID
		card_id = HOARDED_MANUAL_CARD_ID
	if state.get("currentCardId") == SHARED_CARD_ID:
		seed_id = SHARED_SEED_ID
		card_id = SHARED_CARD_ID
	elif state.get("currentCardId") == SECT_CARD_ID:
		seed_id = SECT_SEED_ID
		card_id = SECT_CARD_ID
	elif state.get("currentCardId") == BODY_ECHO_CARD_ID:
		seed_id = BODY_ECHO_SEED_ID
		card_id = BODY_ECHO_CARD_ID
	elif state.get("currentCardId") == BODY_ASCENSION_CARD_ID:
		seed_id = BODY_ASCENSION_SEED_ID
		card_id = BODY_ASCENSION_CARD_ID
	var sha: String = _content.source_sha256(module_id)
	var pin_key := "karmaSourceSha" if chapter else "karmaBodySourceSha" if body \
		else "karmaExpansionSourceSha"
	if sha.length() != 64 or state.get("noncombatFlow", {}).get(pin_key) != sha:
		last_error = "因果来源规则已变化"
		return {}
	if body and state.get("noncombatFlow", {}).get("karmaExpansionSourceSha") \
			!= _content.source_sha256(MODULE):
		last_error = "因果映射规则已变化"
		return {}
	var source := _source_card(module_id, seed_id, card_id)
	var seed := _ready_seed(state)
	var presented: Dictionary = state.get("pendingKarmaCard", {})
	if source.is_empty() or seed.is_empty() or seed.get("id") != seed_id \
			or presented.get("_karmaSeedId") != seed_id \
			or presented.get("_karmaCardId") != card_id \
			or not _same_source_card(presented, _materialize_card(source, seed)):
		return {}
	var choice: Variant = source.get("choices", {}).get(direction)
	if not choice is Dictionary or not choice.get("effects") is Dictionary:
		return {}
	var candidate: Dictionary = _normal_choice_policy.settle(state, card_id, direction) \
		if body else state.duplicate(true)
	if candidate.is_empty():
		last_error = _normal_choice_policy.last_error
		return {}
	var path_skill = PathSkillFlow.new(_content)
	for key in ([] if body else choice["effects"].keys()):
		var value: Variant = choice["effects"][key]
		if key == "_setFlag":
			if not value is String or String(value).is_empty():
				return {}
			candidate["flags"][value] = true
		elif key in ["daoHeart", "fortune", "karmaGood", "karmaBad"] and _integer(value):
			var maximum := LegacyFragmentFlow.actual_max_dao_heart(candidate) if key == "daoHeart" else 100
			var amount := path_skill.effect_delta(candidate, String(key), int(value),
				card_id, int(state.runClock.decisionIndex) + 1)
			if not path_skill.last_error.is_empty():
				return {}
			candidate["attributes"][key] = clampi(
				int(candidate["attributes"].get(key, 0)) +
				LegacyFragmentFlow.effective_delta(candidate, key, amount), 0, maximum)
		elif key in ["cultivation", "health"] and _integer(value):
			var maximum := path_skill.actual_max_health(candidate) if key == "health" else 100
			var amount := path_skill.effect_delta(candidate, String(key), int(value),
				card_id, int(state.runClock.decisionIndex) + 1)
			if not path_skill.last_error.is_empty():
				return {}
			candidate["attributes"][key] = clampi(
				int(candidate["attributes"].get(key, 0)) +
				LegacyFragmentFlow.effective_delta(candidate, key, amount), 0, maximum)
		elif key == "spiritStone" and _integer(value):
			var amount := path_skill.effect_delta(candidate, String(key), int(value),
				card_id, int(state.runClock.decisionIndex) + 1)
			if not path_skill.last_error.is_empty():
				return {}
			candidate["resources"][key] = maxi(0,
				int(candidate["resources"].get(key, 0)) + amount)
		elif key == "deckCard" and value is String and direction == "left":
			candidate = _deck_acquisition.acquire_legacy(candidate, String(value), card_id)
			if candidate.is_empty():
				last_error = _deck_acquisition.last_error
				return {}
		else:
			return {}
	if int(choice["effects"].get("health", 0)) < 0 \
			or int(choice["effects"].get("daoHeart", 0)) < 0:
		candidate["resources"]["lifespan"] = maxi(0,
			int(candidate["resources"].get("lifespan", 0)) - 1)
	if not body and not _normal_choice_policy._apply_passive_regen(candidate):
		last_error = _normal_choice_policy.last_error
		return {}
	var base_index := int(state.get("runClock", {}).get("decisionIndex", -1))
	var life_id := String(state.get("runClock", {}).get("lifeId", ""))
	var life_count := int(state.get("lifeCount", 0))
	if base_index < 0 or life_count < 0 \
			or not life_id.ends_with(":life:" + str(life_count)):
		return {}
	var next_index := base_index + 1
	var receipt := "decision:%s:choice:%s:%d" % [life_id, card_id, next_index]
	if candidate["runClock"]["receipts"].has(receipt):
		return {}
	var seeds: Array = candidate.get("karmaSeeds", [])
	var remaining := []
	for item in seeds:
		if item is Dictionary and item.get("id") != seed_id:
			remaining.append(item)
	candidate["karmaSeeds"] = remaining
	candidate["choiceHistory"].append({"cardId": card_id,
		"cardType": source.get("type"), "direction": direction, "turn": base_index,
		"decisionIndex": next_index, "tags": source.get("tags", []).duplicate(true)})
	while candidate["choiceHistory"].size() > 30:
		candidate["choiceHistory"].pop_front()
	for tag in source.get("tags", []):
		candidate["recentCardTags"].append(tag)
	while candidate["recentCardTags"].size() > 20:
		candidate["recentCardTags"].pop_front()
	candidate["cardsPlayed"].append(card_id)
	candidate["turn"] = next_index
	candidate["runClock"]["decisionIndex"] = next_index
	candidate["runClock"]["receipts"][receipt] = {"token": receipt,
		"decisionIndex": next_index, "sourceCardId": card_id, "kind": "choice"}
	MilestoneFlow.tick_seeds(candidate)
	candidate.erase("pendingKarmaCard")
	candidate["currentCardId"] = ""
	candidate["phase"] = "FLOW_PENDING"
	candidate["decisionCheckpoint"] = {"version": 1, "cardId": null,
		"sourceCardId": card_id, "turn": next_index,
		"decisionIndex": next_index, "flowPending": true}
	return candidate


func _ready_companion_seed(state: Dictionary) -> Dictionary:
	var best := {}
	for item in state.get("karmaSeeds", []):
		if not item is Dictionary or int(item.get("delay", 1)) > 0 \
				or item.get("path") not in [null, state.get("path")] \
				or item.get("realm") not in [null, state.get("realm")]:
			continue
		if item.get("payoffEvent") not in COMPANION_PAYOFF_IDS \
				or not item.get("context") is Dictionary \
				or not item.context.get("companionId") is String \
				or state.get("cardsPlayed", []).has(item.get("payoffEvent")):
			continue
		if best.is_empty() or int(item.get("priority", 0)) > int(best.get("priority", 0)):
			best = item
	return best

func _companion_source(card_id: String) -> Dictionary:
	var source: Variant = _content.read_module(MODULE)
	if not source is Dictionary:
		last_error = "道侣因果来源不可用"
		return {}
	for row in source.get("cards", []):
		if row is Dictionary and row.get("id") == card_id \
				and row.get("type") == "KARMA" \
				and row.get("once") == true \
				and row.get("tags", []).has("companion_dynamic"):
			var art: Dictionary = _content.card_scene_image_status(card_id)
			if art.get("shaVerified", false) and art.get("textureLoadable", false) \
					and art.get("sceneImage") == row.get("sceneImage"):
				return row.duplicate(true)
			last_error = "道侣因果原卡或画面不符"
			return {}
	last_error = "道侣因果原卡缺失"
	return {}

func _companion_materialize(value: Variant, context: Dictionary) -> Variant:
	if value is String:
		return value.replace("{{companion}}", String(context.get("companionName",
			context.get("companionId", "")))).replace("{{companionId}}",
			String(context.get("companionId", ""))).replace("{{milestoneId}}",
			String(context.get("milestoneId", "")))
	if value is Array:
		var items := []
		for item in value:
			items.append(_companion_materialize(item, context))
		return items
	if value is Dictionary:
		var fields := {}
		for key in value:
			fields[key] = _companion_materialize(value[key], context)
		return fields
	return value

func _resume_companion_payoff(state: Dictionary, seed: Dictionary) -> Dictionary:
	var card_id := String(seed.payoffEvent)
	var source := _companion_source(card_id)
	if source.is_empty():
		return {}
	if state.get("cardsPlayed", []).has(card_id):
		return {}
	var source_sha: String = _content.source_sha256(MODULE)
	if source_sha.length() != 64 or state.get("noncombatFlow", {}).get(
			"karmaExpansionSourceSha", source_sha) != source_sha:
		last_error = "道侣因果来源指纹不符"
		return {}
	var card_data: Dictionary = _companion_materialize(source, seed.context)
	card_data["_karmaSeedId"] = seed.id
	card_data["_karmaCardId"] = card_id
	var candidate := state.duplicate(true)
	candidate.noncombatFlow.karmaExpansionSourceSha = source_sha
	candidate.pendingKarmaCard = card_data
	candidate.currentCardId = card_id
	candidate.phase = "KARMA_PENDING"
	var prior_checkpoint: Variant = state.get("decisionCheckpoint")
	candidate.decisionCheckpoint = {"version": 1, "cardId": card_id,
		"sourceCardId": prior_checkpoint.get("sourceCardId") \
			if prior_checkpoint is Dictionary else null,
		"turn": state.get("turn"),
		"decisionIndex": state.get("runClock", {}).get("decisionIndex"),
		"flowSource": "karma", "seedId": seed.id}
	return candidate

func _companion_payoff_choice_available(state: Dictionary,
		direction: String) -> bool:
	if state.get("phase") != "KARMA_PENDING" \
			or not state.get("pendingKarmaCard") is Dictionary:
		return false
	if direction.is_empty():
		return true
	return state.pendingKarmaCard.get("choices", {}).has(direction)

func _settle_companion_payoff(state: Dictionary, direction: String) -> Dictionary:
	if not _companion_payoff_choice_available(state, direction):
		return {}
	var card_id := String(state.currentCardId)
	var seed_id := String(state.pendingKarmaCard.get("_karmaSeedId", ""))
	var seed := {}
	for item in state.get("karmaSeeds", []):
		if item is Dictionary and item.get("id") == seed_id and int(item.get("delay", 1)) <= 0:
			seed = item
			break
	var source := _companion_source(card_id)
	if seed.is_empty() or source.is_empty() or seed.get("payoffEvent") != card_id \
			or state.get("noncombatFlow", {}).get("karmaExpansionSourceSha") \
			!= _content.source_sha256(MODULE):
		return {}
	var projected: Dictionary = _companion_materialize(source, seed.context)
	projected["_karmaSeedId"] = seed_id
	projected["_karmaCardId"] = card_id
	if projected != state.pendingKarmaCard:
		return {}
	var choice: Dictionary = projected.get("choices", {}).get(direction, {})
	if choice.is_empty() or not choice.get("effects") is Dictionary \
			or not choice.get("companionEffects") is Dictionary:
		return {}
	var candidate := state.duplicate(true)
	var path_skill = PathSkillFlow.new(_content)
	for key in choice.effects:
		var value: Variant = choice.effects[key]
		if key == "_setFlag" and value is String:
			candidate.get_or_add("flags", {})[value] = true
		elif key in ["daoHeart", "fortune", "karmaGood", "karmaBad",
				"cultivation", "health"] and _integer(value):
			var maximum := LegacyFragmentFlow.actual_max_dao_heart(candidate) \
				if key == "daoHeart" else path_skill.actual_max_health(
				candidate) if key == "health" else 100
			var amount := path_skill.effect_delta(candidate, String(key), int(value),
				card_id, int(state.runClock.decisionIndex) + 1)
			if not path_skill.last_error.is_empty():
				return {}
			candidate.attributes[key] = clampi(int(candidate.attributes.get(key, 0))
				+ LegacyFragmentFlow.effective_delta(candidate, key, amount),
				0, maximum)
		else:
			return {}
	if not _companion_events._apply_companion_effects(candidate, projected,
			choice, direction, int(state.runClock.decisionIndex) + 1):
		last_error = _companion_events.last_error
		return {}
	if not _normal_choice_policy._apply_passive_regen(candidate):
		last_error = _normal_choice_policy.last_error
		return {}
	var next_index := int(state.runClock.decisionIndex) + 1
	var receipt := "decision:%s:choice:%s:%d" % [state.runClock.lifeId,
		card_id, next_index]
	if candidate.runClock.receipts.has(receipt):
		return {}
	candidate.karmaSeeds = candidate.get("karmaSeeds", []).filter(func(row: Variant) -> bool:
		return row.get("id") != seed_id)
	var history := {"cardId": card_id, "cardType": "KARMA",
		"direction": direction, "turn": next_index - 1,
		"decisionIndex": next_index, "tags": projected.get("tags", []).duplicate(true)}
	candidate.choiceHistory.append(history)
	while candidate.choiceHistory.size() > 30:
		candidate.choiceHistory.pop_front()
	if candidate.has("replayHistory"):
		candidate.replayHistory.append(history.duplicate(true))
	for tag in projected.get("tags", []):
		candidate.recentCardTags.append(tag)
	while candidate.recentCardTags.size() > 20:
		candidate.recentCardTags.pop_front()
	candidate.cardsPlayed.append(card_id)
	candidate.turn = next_index
	candidate.runClock.decisionIndex = next_index
	candidate.runClock.receipts[receipt] = {"token": receipt,
		"decisionIndex": next_index, "sourceCardId": card_id, "kind": "choice"}
	MilestoneFlow.tick_seeds(candidate)
	candidate.erase("pendingKarmaCard")
	candidate.currentCardId = ""
	candidate.phase = "FLOW_PENDING"
	candidate.decisionCheckpoint = {"version": 1, "cardId": null,
		"sourceCardId": card_id, "turn": next_index,
		"decisionIndex": next_index, "flowPending": true}
	return candidate

func _ready_seed(state: Dictionary) -> Dictionary:
	if state.get("realm") != "qi":
		return _ready_high_body_seed(state)
	var best: Dictionary = {}
	var priority := -2147483648
	for item in state.get("karmaSeeds", []):
		if not item is Dictionary or int(item.get("delay", 1)) > 0 \
				or item.get("path") not in [null, state.get("path")] \
				or item.get("realm") not in [null, "qi"]:
			continue
		var item_priority := int(item.get("priority", 0))
		if item_priority > priority:
			best = item
			priority = item_priority
	if best.get("id") == SEED_ID and not state.get("cardsPlayed", []).has(CARD_ID):
		return best
	if best.get("id") == SHARED_SEED_ID and not state.get("cardsPlayed", []).has(SHARED_CARD_ID):
		return best
	if best.get("id") == SECT_SEED_ID and not state.get("cardsPlayed", []).has(SECT_CARD_ID):
		return best
	if best.get("id") == HOARDED_MANUAL_SEED_ID \
			and not state.get("cardsPlayed", []).has(HOARDED_MANUAL_CARD_ID):
		return best
	if best.get("id") == BODY_SEED_ID:
		return best
	return best if best.get("id") in [CHAPTER_SEED_ID, REBIRTH_BODY_SEED_ID,
		REBIRTH_BODY_BURDEN_SEED_ID] else {}


func _ready_high_body_seed(state: Dictionary) -> Dictionary:
	var realm_index := REALM_ORDER.find(state.get("realm"))
	var best: Dictionary = {}
	var best_priority := -2147483648
	for item in state.get("karmaSeeds", []):
		if not item is Dictionary or int(item.get("delay", 1)) > 0 \
				or item.get("path") not in [null, "body"] \
				or state.get("path") != "body":
			continue
		var card_id := BODY_ECHO_CARD_ID if item.get("id") == BODY_ECHO_SEED_ID \
			else BODY_ASCENSION_CARD_ID if item.get("id") == BODY_ASCENSION_SEED_ID else ""
		var required_realm := "golden" if item.get("id") == BODY_ECHO_SEED_ID \
			else "nascent" if item.get("id") == BODY_ASCENSION_SEED_ID else ""
		var required_index := REALM_ORDER.find(required_realm)
		if card_id.is_empty() or required_index < 0 or realm_index < required_index \
				or item.get("realm") != required_realm \
				or state.get("cardsPlayed", []).has(card_id):
			continue
		var priority := int(item.get("priority", 0)) \
			+ (3 if realm_index > required_index else 0)
		if priority > best_priority:
			best = item
			best_priority = priority
	return best


func _source_card(module_id: String, seed_id: String, card_id: String) -> Dictionary:
	if seed_id == BODY_SEED_ID:
		var mappings: Variant = _content.read_module(MODULE)
		if not mappings is Dictionary or mappings.get("karmaCards", {}).get(
				BODY_SEED_ID) != BODY_CARD_ID:
			last_error = "因果映射缺失"
			return {}
		var qi: Variant = _content.read_module(BODY_MODULE)
		var body_card: Variant = qi.get("karmaCards", {}).get("body_awakening") \
			if qi is Dictionary else null
		if not body_card is Dictionary or body_card.get("id") != BODY_CARD_ID \
				or body_card.get("type") != "NORMAL" or body_card.get("realm") != "qi":
			last_error = "因果卡缺失"
			return {}
		var body_art: Dictionary = _content.card_scene_image_status(BODY_CARD_ID)
		if body_art.get("shaVerified", false) \
				and body_art.get("textureLoadable", false) \
				and body_art.get("sceneImage") == body_card.get("sceneImage"):
			return body_card.duplicate(true)
		last_error = "因果卡或原图未通过校验"
		return {}
	var source: Variant = _content.read_module(module_id)
	if not source is Dictionary or source.get("karmaCards", {}).get(seed_id) != card_id:
		last_error = "因果映射缺失"
		return {}
	for row in source.get("cards", []):
		if row is Dictionary and row.get("id") == card_id:
			var art: Dictionary = _content.card_scene_image_status(card_id)
			var valid_card: bool = row.get("type") == "KARMA"
			if card_id in [CARD_ID, SHARED_CARD_ID, SECT_CARD_ID,
					HOARDED_MANUAL_CARD_ID]:
				valid_card = valid_card and row.get("realm") == "qi" and row.get("once") == true
			elif card_id in [BODY_ECHO_CARD_ID, BODY_ASCENSION_CARD_ID]:
				valid_card = valid_card and row.get("realm") == (
					"golden" if card_id == BODY_ECHO_CARD_ID else "nascent") \
					and row.get("once") == true and row.get("tags", []).has("body")
			else:
				valid_card = valid_card and not row.has("realm") and row.get("once") == false \
					and row.get("tags", []).has("chapter_variant_dynamic") \
					and row.get("tags", []).has("path:body" if card_id in [
						REBIRTH_BODY_CARD_ID, REBIRTH_BODY_BURDEN_CARD_ID] \
						else "path:sword")
			if valid_card and art.get("shaVerified", false) \
					and art.get("textureLoadable", false) \
					and art.get("sceneImage") == row.get("sceneImage"):
				return row.duplicate(true)
			last_error = "因果卡或原图未通过校验"
			return {}
	last_error = "因果卡缺失"
	return {}


func _materialize_card(source: Dictionary, seed: Dictionary) -> Dictionary:
	var card: Dictionary = source.duplicate(true)
	if not card.get("tags", []).has("chapter_variant_dynamic"):
		return card
	var context: Dictionary = seed.get("context", {}) if seed.get("context") is Dictionary else {}
	var replacements := {"{{sourceTitle}}": context.get("sourceTitle", seed.get("originCard", "旧日选择")),
		"{{choiceText}}": context.get("choiceText", seed.get("originChoice", "当时的取舍")),
		"{{seedId}}": seed.get("id", ""), "{{realm}}": context.get("realm", seed.get("realm", "")),
		"{{path}}": context.get("path", seed.get("path", ""))}
	for field in ["title", "description"]:
		var value := String(card.get(field, ""))
		for token in replacements:
			value = value.replace(String(token), String(replacements[token]))
		card[field] = value
	return card


func _same_source_card(presented: Dictionary, source: Dictionary) -> bool:
	var original: Dictionary = presented.duplicate(true)
	original.erase("_karmaSeedId")
	original.erase("_karmaCardId")
	return JSON.parse_string(JSON.stringify(original)) == JSON.parse_string(JSON.stringify(source))


func _integer(value: Variant) -> bool:
	return (value is int or value is float) and float(value) == float(int(value))


func _all_positive_capped(state: Dictionary, choice: Dictionary) -> bool:
	var effects: Dictionary = choice.get("effects", {})
	if effects.is_empty():
		return false
	var attributes: Dictionary = state.get("attributes", {})
	var checked := false
	for key in effects:
		var value: Variant = effects[key]
		if not _integer(value) or int(value) <= 0:
			return false
		var maximum := -1
		match key:
			"cultivation", "fortune", "karmaGood": maximum = 100
			"daoHeart": maximum = LegacyFragmentFlow.actual_max_dao_heart(state)
			"health": maximum = LegacyFragmentFlow.actual_max_health(state)
			_: return false
		if int(attributes.get(key, 0)) < maximum:
			return false
		checked = true
	return checked
