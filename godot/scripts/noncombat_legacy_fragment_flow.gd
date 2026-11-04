extends RefCounted

# The browser's LegacyFragmentSystem ordinary-choice lane. All mutations live
# in a candidate RunSession snapshot; replay starts from its saved initial seed.
const SOURCE_JS_SHA := "6aa5a5b9d4fda4af633c744b601321883bf1f729964978f0a62b1206f43157c4"
const LineageFlow = preload("res://scripts/noncombat_lineage_flow.gd")
const SET_IDS := ["sword_heart", "pill_way", "array_way", "heaven_book",
	"demon_blood", "immortal_will"]
const DROP_RATES := {"qi": 0.08, "foundation": 0.085, "golden": 0.09,
	"nascent": 0.095, "deity": 0.10, "tribulation": 0.10}
const PIECES := 8
const PITY_MISSES := 7
const RNG_MODULUS := 2147483647
const PASSIVES := {
	"sword_heart": {"critRate": 5},
	"pill_way": {"pillBonus": 15},
	"array_way": {"combatStartBlock": 3, "daoResist": 10},
	"heaven_book": {"cultivationBonus": 10},
	"demon_blood": {"lowHpDamageBonus": 2, "daoHeartPenalty": -2},
	"immortal_will": {"maxHp": 6, "maxLifespan": 5},
}
const SET_NAMES := {"sword_heart": "剑心通明", "pill_way": "丹道真解",
	"array_way": "阵法玄机", "heaven_book": "天书残卷",
	"demon_blood": "魔血传承", "immortal_will": "仙人之志"}
const SET_EFFECTS := {"sword_heart": "本世暴击率 +5%",
	"pill_way": "本世丹药治疗与丹毒效果 +15%",
	"array_way": "开战护盾 +3；道心伤害减免 10%",
	"heaven_book": "激活时福缘 +3；修为正收益 +10%",
	"demon_blood": "气血≤50%时伤害 +2；道心上限 -2",
	"immortal_will": "最大气血 +6；本世寿元 +5"}

static func seed_without_early_drop(choice_count: int) -> int:
	if choice_count < 0 or choice_count > 7:
		return 0
	for seed in range(1, 100001):
		var value := seed
		var no_drop := true
		for _choice in choice_count:
			value = int((value * 48271) % RNG_MODULUS)
			if float(value) / RNG_MODULUS <= DROP_RATES["qi"]:
				no_drop = false
				break
		if no_drop:
			return seed
	return 0


func seed_matching_opening_pity(path_id: String, set_id: String,
		second_set_id: String = "", trailing_misses: int = 0) -> int:
	var fragments := {}
	for id in SET_IDS:
		fragments[id] = 0
	var eligible := _eligible_sets({"path": path_id, "legacyArchive": {
		"completedSetIds": [], "fragmentsBySet": fragments}})
	if not eligible.has(set_id) or not second_set_id.is_empty() \
			and (not eligible.has(second_set_id) or trailing_misses not in [0, 1]):
		return 0
	for seed in range(1, 100001):
		var value := seed
		var no_drop := true
		for _choice in PITY_MISSES:
			value = int((value * 48271) % RNG_MODULUS)
			if float(value) / RNG_MODULUS <= DROP_RATES["qi"]:
				no_drop = false
				break
		if not no_drop:
			continue
		value = int((value * 48271) % RNG_MODULUS)
		if eligible[mini(eligible.size() - 1,
				int(float(value) / RNG_MODULUS * eligible.size()))] != set_id:
			continue
		if not second_set_id.is_empty():
			var second_ready := true
			for _choice in 3:
				value = int((value * 48271) % RNG_MODULUS)
				if float(value) / RNG_MODULUS <= DROP_RATES["qi"]:
					second_ready = false
					break
			if not second_ready:
				continue
			value = int((value * 48271) % RNG_MODULUS)
			if float(value) / RNG_MODULUS > DROP_RATES["qi"]:
				continue
			value = int((value * 48271) % RNG_MODULUS)
			if eligible[mini(eligible.size() - 1,
					int(float(value) / RNG_MODULUS * eligible.size()))] != second_set_id:
				continue
			for _choice in trailing_misses:
				value = int((value * 48271) % RNG_MODULUS)
				if float(value) / RNG_MODULUS <= DROP_RATES["qi"]:
					second_ready = false
					break
			if not second_ready:
				continue
		return seed
	return 0

var roll_override := -1.0 # Deterministic source-parity tests only; never persisted.
var last_error := ""
var _content: RefCounted
var _deck_acquisition: RefCounted
var _lineage_flow: RefCounted


func _init(content: RefCounted, deck_acquisition: RefCounted) -> void:
	_content = content
	_deck_acquisition = deck_acquisition
	_lineage_flow = LineageFlow.new(content)


func pacing_contract(state: Dictionary) -> Dictionary:
	var tree: Variant = state.get("rebirthTree")
	if tree != null and not _lineage_flow.valid_tree(tree):
		last_error = _lineage_flow.last_error
		return {}
	var pity_reduction := maxi(0, int(floorf(_lineage_flow.effect_value(
		tree, "pityReduction")))) if tree is Dictionary else 0
	var weight_bonus := maxf(0.0, _lineage_flow.effect_value(tree,
		"focusedWeightBonus")) if tree is Dictionary else 0.0
	var drop_bonus := maxf(0.0, _lineage_flow.effect_value(tree,
		"ordinaryDropBonus")) if tree is Dictionary else 0.0
	var rates := {}
	for realm in DROP_RATES:
		rates[realm] = minf(0.12, float(DROP_RATES[realm]) + drop_bonus)
	return {"pityMissLimit": maxi(5, PITY_MISSES - pity_reduction),
		"focusedWeight": minf(0.75, 0.60 + weight_bonus),
		"ordinaryDropRates": rates}


func boss_candidate_set_ids(state: Dictionary, set_ids: Array,
		focused_set_id: String, encounter_instance_id: String) -> Array[String]:
	var result: Array[String] = []
	var pacing: Dictionary = pacing_contract(state)
	if pacing.is_empty() or encounter_instance_id.is_empty():
		return result
	var unique := {}
	for id in set_ids:
		if id is String and SET_IDS.has(id):
			unique[id] = true
	var pool: Array = unique.keys()
	pool.sort()
	if pool.is_empty():
		return result
	if pool.has(focused_set_id):
		result.append(focused_set_id)
		pool.erase(focused_set_id)
	pool.sort_custom(func(left: Variant, right: Variant) -> bool:
		return _hash_encounter(encounter_instance_id + ":" + String(left)) < \
			_hash_encounter(encounter_instance_id + ":" + String(right)))
	for id in pool:
		result.append(id)
	var bonus := maxi(0, int(floorf(_lineage_flow.effect_value(
		state.get("rebirthTree", {}), "bossChoiceBonus")))) \
		if state.get("rebirthTree") is Dictionary else 0
	result.resize(mini(result.size(), 3 + bonus))
	return result


func _hash_encounter(value: String) -> int:
	var hash_value := 2166136261
	for character in value:
		hash_value = ((hash_value ^ character.unicode_at(0)) * 16777619) \
			& 0xffffffff
	return hash_value


func begin_boss_reward(candidate: Dictionary, request: Dictionary) -> bool:
	last_error = ""
	if not _valid_state(candidate) or candidate.get("legacyRunState") is not Dictionary:
		last_error = "Boss 残卷状态无效"
		return false
	var source: Dictionary = request.get("pendingResolution", {}).get("sourceCard", {})
	var choice: Dictionary = request.get("pendingResolution", {}).get("choice", {})
	var kind := String(choice.get("encounterKind", source.get("encounterKind", "")))
	var owner := String(request.get("encounterInstanceId", ""))
	if kind not in ["boss", "realm_boss"] or owner.is_empty():
		return true
	var run: Dictionary = candidate.legacyRunState
	if run.get("claimedEncounterInstanceIds", []).has(owner) or run.get(
			"pendingBossFragmentReward") != null:
		return true
	var eligible := _eligible_sets(candidate)
	var focused: Variant = run.get("focusedSetId")
	var choices := boss_candidate_set_ids(candidate, eligible,
		String(focused) if focused is String else "", owner)
	if choices.is_empty():
		return true
	run["pendingBossFragmentReward"] = {"schemaVersion": 1,
		"encounterInstanceId": owner, "encounterKind": kind,
		"cardId": request.get("sourceCardId"), "realm": request.get("realm"),
		"path": request.get("path"),
		"focusedSetId": focused if focused is String and choices.has(focused) else null,
		"candidateSetIds": choices, "createdAtTurn": int(candidate.get("turn", 0))}
	return true


func boss_reward_options(state: Dictionary) -> Array[Dictionary]:
	var options: Array[Dictionary] = []
	var pending: Variant = state.get("legacyRunState", {}).get("pendingBossFragmentReward")
	if not pending is Dictionary:
		return options
	for set_id in pending.get("candidateSetIds", []):
		if not SET_NAMES.has(set_id):
			continue
		options.append({"setId": set_id, "name": SET_NAMES[set_id],
			"count": state.get("legacyArchive", {}).get("fragmentsBySet", {}).get(set_id, 0),
			"total": PIECES, "focused": pending.get("focusedSetId") == set_id,
			"effect": SET_EFFECTS[set_id],
			"variantCardId": _variant_card_id(String(set_id), String(pending.get("path", "")))})
	return options


func focus_options(state: Dictionary) -> Array[Dictionary]:
	var options: Array[Dictionary] = []
	if not _valid_state(state):
		return options
	var focused: Variant = state.legacyRunState.get("focusedSetId")
	for set_id in _eligible_sets(state):
		options.append({"setId": set_id, "name": SET_NAMES[set_id],
			"effect": SET_EFFECTS[set_id],
			"count": int(state.legacyArchive.fragmentsBySet[set_id]),
			"total": PIECES, "focused": focused == set_id})
	return options


func set_focus(candidate: Dictionary, set_id: String) -> bool:
	last_error = ""
	if not _valid_state(candidate):
		last_error = "残卷追踪状态无效"
		return false
	var current: Variant = candidate.legacyRunState.get("focusedSetId")
	if set_id.is_empty():
		if current == null:
			return false
		candidate.legacyRunState.focusedSetId = null
		return true
	if current == set_id or not _eligible_sets(candidate).has(set_id):
		last_error = "追踪套装当前不可获得或未变化"
		return false
	candidate.legacyRunState.focusedSetId = set_id
	return true


func claim_boss_reward(candidate: Dictionary, set_id: String) -> bool:
	last_error = ""
	if not _valid_state(candidate):
		last_error = "Boss 残卷状态无效"
		return false
	var run: Dictionary = candidate.legacyRunState
	var pending: Variant = run.get("pendingBossFragmentReward")
	if not pending is Dictionary or not pending.get("candidateSetIds", []).has(set_id) \
			or run.get("claimedEncounterInstanceIds", []).has(pending.get("encounterInstanceId")):
		last_error = "Boss 残卷待领项无效"
		return false
	if not _award_fragment(candidate, set_id, int(pending.get("createdAtTurn", 0))):
		return false
	run = candidate.legacyRunState
	run.claimedEncounterInstanceIds.append(pending.encounterInstanceId)
	run.pendingBossFragmentReward = null
	return true


func settle(prior: Dictionary, candidate: Dictionary, replay_without_fragments: bool,
		replay_activation_index: int, replay_initial_seed: int) -> bool:
	last_error = ""
	if replay_without_fragments:
		return true
	var index := int(candidate.get("runClock", {}).get("decisionIndex", -1))
	if index < 0:
		last_error = "残卷决定时钟无效"
		return false
	if not candidate.has("legacyFragmentVersion"):
		if replay_activation_index >= 0 and index < replay_activation_index:
			return true
		if replay_activation_index >= 0 and index > replay_activation_index:
			last_error = "残卷旧档激活点未重放"
			return false
		var seed := replay_initial_seed if replay_initial_seed > 0 else randi_range(1, RNG_MODULUS - 1)
		candidate["legacyFragmentVersion"] = 1
		candidate["legacyRuleSourceSha"] = SOURCE_JS_SHA
		candidate["legacyFragmentActivationIndex"] = index
		candidate["legacyRngState"] = {"initialSeed": seed, "value": seed}
		var fragments := {}
		for set_id in SET_IDS:
			fragments[set_id] = 0
		candidate["legacyArchive"] = {"schemaVersion": 1, "migrationVersion": 1,
			"fragmentsBySet": fragments, "completedSetIds": [],
			"discoveredVariantCardIds": [],
			"migrationDiagnostics": {"unknownSetIds": []}}
		candidate["legacyRunState"] = {"lifeCount": 0, "focusedSetId": null,
			"activeSetIds": [], "inheritedSetId": null,
			"pendingInheritanceChoice": null, "ordinaryMissStreak": 0,
			"pendingBossFragmentReward": null, "claimedEncounterInstanceIds": []}
	if not _valid_state(candidate):
		last_error = "残卷存档结构无效"
		return false
	if prior.is_empty() or index <= int(prior.get("runClock", {}).get("decisionIndex", -1)):
		return true
	var history: Array = candidate.get("choiceHistory", [])
	if history.is_empty() or not history.back() is Dictionary \
			or int(history.back().get("decisionIndex", -1)) != index \
			or history.back().get("cardType") == "COMBAT":
		return true
	var eligible := _eligible_sets(candidate)
	if eligible.is_empty():
		return true
	var pacing: Dictionary = pacing_contract(candidate)
	if pacing.is_empty():
		return false
	var run: Dictionary = candidate["legacyRunState"]
	var pity_limit: int = int(pacing.pityMissLimit)
	var pity := int(run.get("ordinaryMissStreak", 0)) >= pity_limit
	if not pity and _next_roll(candidate["legacyRngState"]) > \
			float(pacing.ordinaryDropRates.get(candidate.get("realm"),
				pacing.ordinaryDropRates.qi)):
		run["ordinaryMissStreak"] = mini(pity_limit,
			int(run.get("ordinaryMissStreak", 0)) + 1)
		return true
	var focused: Variant = run.get("focusedSetId")
	var chosen := ""
	if focused is String and eligible.has(focused):
		if eligible.size() == 1 or _next_roll(candidate["legacyRngState"]) < \
				float(pacing.focusedWeight):
			chosen = focused
		else:
			eligible.erase(focused)
	if chosen.is_empty():
		chosen = eligible[mini(eligible.size() - 1,
			int(_next_roll(candidate["legacyRngState"]) * eligible.size()))]
	if not _award_fragment(candidate, chosen, int(prior.get("turn", 0))):
		return false
	candidate["legacyRunState"]["ordinaryMissStreak"] = 0
	return true


func _award_fragment(candidate: Dictionary, chosen: String, source_turn: int) -> bool:
	if not _eligible_sets(candidate).has(chosen):
		last_error = "残卷套装当前不可获得"
		return false
	var archive: Dictionary = candidate["legacyArchive"]
	var run: Dictionary = candidate["legacyRunState"]
	var counts: Dictionary = archive["fragmentsBySet"]
	counts[chosen] = int(counts.get(chosen, 0)) + 1
	if int(counts[chosen]) == PIECES:
		var art_id := _variant_card_id(chosen, String(candidate.get("path", "")))
		if art_id.is_empty():
			last_error = "完整传承缺少流派绝学"
			return false
		var acquired: Dictionary = _deck_acquisition.acquire_legacy(candidate, art_id,
			chosen, "legacy_fragment_set", source_turn)
		if acquired.is_empty():
			last_error = _deck_acquisition.last_error
			return false
		candidate.merge(acquired, true)
		archive = candidate["legacyArchive"]
		run = candidate["legacyRunState"]
		archive["completedSetIds"].append(chosen)
		archive["discoveredVariantCardIds"].append(art_id)
		run["activeSetIds"].append(chosen)
		# Browser checkCompletions applies one-time activation after the set is
		# active, so its new max-health/dao-heart passive participates in caps.
		match chosen:
			"heaven_book":
				candidate["attributes"]["fortune"] = mini(100,
					int(candidate["attributes"].get("fortune", 0)) + 3)
			"immortal_will":
				candidate["resources"]["lifespan"] = maxi(0,
					int(candidate["resources"].get("lifespan", 0)) + 5)
				candidate["attributes"]["health"] = mini(actual_max_health(candidate),
					int(candidate["attributes"].get("health", 0)) + 6)
			"demon_blood":
				candidate["attributes"]["daoHeart"] = mini(actual_max_dao_heart(candidate),
					int(candidate["attributes"].get("daoHeart", 0)))
	return true


func passive_bonuses(state: Dictionary) -> Dictionary:
	return aggregate_passives(state)


static func aggregate_passives(state: Dictionary) -> Dictionary:
	var archive: Variant = state.get("legacyArchive")
	var run: Variant = state.get("legacyRunState")
	if not archive is Dictionary or not run is Dictionary:
		return {}
	var completed: Variant = archive.get("completedSetIds")
	var active: Variant = run.get("activeSetIds")
	if not completed is Array or not active is Array:
		return {}
	var result := {}
	for set_id in active:
		if not completed.has(set_id) or not PASSIVES.has(set_id):
			continue
		for key in PASSIVES[set_id]:
			result[key] = int(result.get(key, 0)) + int(PASSIVES[set_id][key])
	return result


static func actual_max_health(state: Dictionary) -> int:
	return maxi(1, int(state.get("maxHealth", 1)) +
		int(aggregate_passives(state).get("maxHp", 0)))


static func actual_max_dao_heart(state: Dictionary) -> int:
	return maxi(1, int(state.get("maxDaoHeart", 1)) +
		int(aggregate_passives(state).get("daoHeartPenalty", 0)))


static func effective_delta(state: Dictionary, key: String, amount: int) -> int:
	var bonuses := aggregate_passives(state)
	if key == "cultivation" and amount > 0:
		return int(floorf(float(amount) *
			(1.0 + float(bonuses.get("cultivationBonus", 0)) / 100.0)))
	if key == "daoHeart" and amount < 0:
		var resist := clampi(int(bonuses.get("daoResist", 0)), 0, 80)
		return -int(ceilf(float(-amount) * (1.0 - float(resist) / 100.0)))
	return amount


func _eligible_sets(state: Dictionary) -> Array[String]:
	var result: Array[String] = []
	var path_id: Variant = state.get("path")
	if not path_id is String or String(path_id).is_empty():
		return result
	var archive: Dictionary = state["legacyArchive"]
	for set_id in SET_IDS:
		if archive["completedSetIds"].has(set_id) \
				or int(archive["fragmentsBySet"].get(set_id, 0)) >= PIECES:
			continue
		if not _variant_card_id(set_id, path_id).is_empty():
			result.append(set_id)
	return result


func _variant_card_id(set_id: String, path_id: String) -> String:
	var doc: Variant = _content.read_module("cards:battle_cards")
	if not doc is Dictionary or not doc.get("battle_cards") is Array:
		return ""
	var found := ""
	for value in doc["battle_cards"]:
		if value is Dictionary and value.get("legacySetId") == set_id \
				and value.get("legacyPath") == path_id \
				and value.get("tags", []) is Array \
				and value["tags"].has("legacy") \
				and value["tags"].has(path_id):
			if not found.is_empty() or not value.get("id") is String:
				return ""
			found = String(value["id"])
	return found


func _next_roll(rng: Dictionary) -> float:
	rng["value"] = (int(rng["value"]) * 48271) % RNG_MODULUS
	return roll_override if roll_override >= 0.0 else float(rng["value"]) / RNG_MODULUS


func _valid_state(candidate: Dictionary) -> bool:
	if candidate.get("legacyFragmentVersion") != 1 \
			or candidate.get("legacyRuleSourceSha") != SOURCE_JS_SHA \
			or not candidate.get("legacyArchive") is Dictionary \
			or not candidate.get("legacyRunState") is Dictionary \
			or not candidate.get("legacyRngState") is Dictionary:
		return false
	var rng: Dictionary = candidate["legacyRngState"]
	var archive: Dictionary = candidate["legacyArchive"]
	var run: Dictionary = candidate["legacyRunState"]
	if int(rng.get("initialSeed", 0)) < 1 or int(rng.get("initialSeed", 0)) >= RNG_MODULUS \
			or int(rng.get("value", 0)) < 1 or int(rng.get("value", 0)) >= RNG_MODULUS \
			or not archive.get("fragmentsBySet") is Dictionary \
			or not archive.get("completedSetIds") is Array \
			or not run.get("activeSetIds") is Array:
		return false
	for set_id in SET_IDS:
		if not archive["fragmentsBySet"].has(set_id) \
				or int(archive["fragmentsBySet"][set_id]) < 0 \
				or int(archive["fragmentsBySet"][set_id]) > PIECES:
			return false
	return true
