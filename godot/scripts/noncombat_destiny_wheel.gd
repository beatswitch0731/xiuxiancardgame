extends RefCounted

# Mirrors the authored browser wheel. A saved seed makes the covered decision
# and its reward replayable without depending on process-global Math.random.
const LegacyFragmentFlow = preload("res://scripts/noncombat_legacy_fragment_flow.gd")
const TreasureAcquisition = preload("res://scripts/noncombat_treasure_acquisition.gd")
const SOURCE_JS_SHA := "15fdd6df45dad2af2ebdd941e06965f2e80cbbe9e28760c0319fd571f0899b7e"
const RNG_MODULUS := 2147483647
const REALM_INTERVALS := {"qi": 15, "foundation": 12, "golden": 10,
	"nascent": 8, "deity": 6, "tribulation": 5}
const CATALOG := {
	"legendary": [
		["龙脉印记", "修为+30 道心+10 福缘+15", "dragon_mark"],
		["天劫免疫", "下次突破失败时免疫心魔", "tribulation_immune"],
		["混元神石", "获得传说级法宝：混元神石", "hunyuan_stone"]],
	"epic": [
		["剑心佩碎片", "攻击力永久+5", "attack_bonus"],
		["秘境密钥", "灵石+50 秘境探索次数+1", "dungeon_key"],
		["天书残页", "修为+20 解锁隐藏支线线索", "heaven_book_page"]],
	"rare": [
		["灵泉玉露", "气血回复30%", "healing_dew"],
		["灵石袋", "灵石+30", "spirit_stones_30"],
		["道心丹", "道心+5", "dao_pill"]],
	"common": [
		["灵石袋", "灵石+15", "spirit_stones_15"],
		["聚灵丹", "修为+5", "cultivation_pill"],
		["寿元桃", "寿元+3", "lifespan_peach"]],
	"empty": [["空卦", "天机未显，一无所获", "empty"]],
}

var roll_override := -1.0 # Deterministic parity seam; never saved.
var initial_seed_override := 0 # Fixture parity; the selected seed is persisted.
var last_error := ""
var _content: RefCounted
var _treasure_acquisition: RefCounted


func _init(content: RefCounted) -> void:
	_content = content
	_treasure_acquisition = TreasureAcquisition.new(content)


func settle(prior: Dictionary, candidate: Dictionary, replay_without_wheel: bool,
		replay_activation_index: int, replay_initial_seed: int) -> bool:
	last_error = ""
	if replay_without_wheel:
		return true
	var index := int(candidate.get("runClock", {}).get("decisionIndex", -1))
	if index < 0:
		last_error = "命盘决定时钟无效"
		return false
	if not candidate.has("destinyWheelVersion"):
		if replay_activation_index >= 0 and index < replay_activation_index:
			return true
		if replay_activation_index >= 0 and index > replay_activation_index:
			last_error = "命盘旧档激活点未重放"
			return false
		var seed := replay_initial_seed if replay_initial_seed > 0 else (
			initial_seed_override if initial_seed_override > 0 else randi_range(1, RNG_MODULUS - 1))
		candidate["destinyWheelVersion"] = 1
		candidate["destinyWheelRuleSourceSha"] = SOURCE_JS_SHA
		candidate["destinyWheelActivationIndex"] = index
		candidate["destinyWheelRngState"] = {"initialSeed": seed, "value": seed}
		candidate["destinyWheelTicks"] = index
	if not _valid_state(candidate):
		last_error = "命盘存档结构无效"
		return false
	if prior.is_empty() or index <= int(prior.get("runClock", {}).get("decisionIndex", -1)):
		return true
	# A battle's internal turn and warning do not advance the noncombat wheel.
	if candidate.get("phase") in ["BATTLE_PENDING", "WARNING_PENDING"]:
		return true
	if index == int(candidate.get("destinyWheelActivationIndex", -1)):
		# Upgrade from an older save: this decision is the first eligible tick.
		candidate["destinyWheelTicks"] = index
	else:
		candidate["destinyWheelTicks"] = int(candidate["destinyWheelTicks"]) + 1
	var interval := int(REALM_INTERVALS.get(String(candidate.get("realm", "qi")), 15))
	if int(candidate["destinyWheelTicks"]) % interval != 0:
		return true
	if candidate.has("pendingDestinyWheel"):
		# The browser tick keeps advancing while an earlier wheel is active.
		return true
	var deck := _generate_deck(candidate["destinyWheelRngState"])
	if deck.size() != 5:
		last_error = "命盘牌池无效"
		return false
	candidate["wheelReturn"] = {"phase": candidate.get("phase"),
		"currentCardId": candidate.get("currentCardId"),
		"decisionCheckpoint": candidate.get("decisionCheckpoint", null)}
	candidate["pendingDestinyWheel"] = {"active": true, "flipped": 0,
		"deck": deck, "triggerDecisionIndex": index}
	candidate["phase"] = "DESTINY_WHEEL_PENDING"
	candidate["currentCardId"] = "destiny_wheel"
	candidate["decisionCheckpoint"] = {"version": 1, "cardId": "destiny_wheel",
		"sourceCardId": candidate["wheelReturn"]["currentCardId"],
		"turn": index, "decisionIndex": index, "flowSource": "pending:destinyWheel"}
	return true


func resume_deferred(state: Dictionary) -> Dictionary:
	if state.get("phase") != "FLOW_PENDING" or not state.has("pendingDestinyWheel"):
		return {}
	var candidate: Dictionary = state.duplicate(true)
	candidate["wheelReturn"] = {"phase": "FLOW_PENDING",
		"currentCardId": state.get("currentCardId"),
		"decisionCheckpoint": state.get("decisionCheckpoint", null)}
	candidate["phase"] = "DESTINY_WHEEL_PENDING"
	candidate["currentCardId"] = "destiny_wheel"
	candidate["decisionCheckpoint"] = {"version": 1, "cardId": "destiny_wheel",
		"sourceCardId": state.get("decisionCheckpoint", {}).get("sourceCardId"),
		"turn": state.get("turn"),
		"decisionIndex": state.get("runClock", {}).get("decisionIndex"),
		"flowSource": "pending:destinyWheel"}
	return candidate if _valid_state(candidate) else {}


func card(state: Dictionary) -> Dictionary:
	if state.get("phase") != "DESTINY_WHEEL_PENDING" or not _valid_state(state):
		return {}
	return {"id": "destiny_wheel", "type": "DESTINY_WHEEL",
		"title": "天机涌动 · 命盘轮转", "description": "选择一张天机牌翻看。",
		"wheelState": state["pendingDestinyWheel"].duplicate(true),
		"choices": {"left": {"text": "翻看第一张"},
			"right": {"text": "翻看第二张"},
			"up": {"text": "翻看第三张"},
			"down": {"text": "翻看第四张"}}}


func flip(state: Dictionary, direction: String) -> Dictionary:
	last_error = ""
	var slot := ["left", "right", "up", "down"].find(direction)
	if slot < 0 or state.get("phase") != "DESTINY_WHEEL_PENDING" \
			or not _valid_state(state):
		return {}
	var candidate: Dictionary = state.duplicate(true)
	var reward: Dictionary = candidate["pendingDestinyWheel"]["deck"][slot]
	if not _apply_reward(candidate, String(reward["rewardId"]), slot):
		return {}
	var index := int(candidate["runClock"]["decisionIndex"])
	candidate["wheelFlips"] = candidate.get("wheelFlips", [])
	candidate["wheelFlips"].append({"slot": slot, "decisionIndex": index,
		"rewardId": reward["rewardId"]})
	# This is an internal action at the same decision index, not a new turn.
	# Record it in the replay stream so strict save restoration can interleave it
	# before any later top-level choice.
	candidate["choiceHistory"].append({"cardId": "destiny_wheel",
		"cardType": "DESTINY_WHEEL", "direction": direction,
		"turn": index, "decisionIndex": index, "tags": []})
	while candidate["choiceHistory"].size() > 30:
		candidate["choiceHistory"].pop_front()
	var covered: Dictionary = candidate["wheelReturn"]
	candidate["phase"] = covered["phase"]
	candidate["currentCardId"] = covered["currentCardId"]
	candidate["decisionCheckpoint"] = covered["decisionCheckpoint"]
	candidate.erase("wheelReturn")
	candidate.erase("pendingDestinyWheel")
	return candidate


func _generate_deck(rng: Dictionary) -> Array:
	var rarities: Array = []
	for i in 5:
		var roll := _roll(rng)
		rarities.append("legendary" if roll < 0.05 else (
			"epic" if roll < 0.20 else ("rare" if roll < 0.50 else (
				"common" if roll < 0.95 else "empty"))))
	if not rarities.any(func(value: Variant) -> bool:
		return value in ["legendary", "epic", "rare"]):
		var forced := mini(4, int(_roll(rng) * 5))
		rarities[forced] = "rare" if _roll(rng) < 0.5 else "epic"
	var empty_count := rarities.count("empty")
	var fixed := 0
	for i in 5:
		# Browser changes the first n-1 empty slots, leaving the last empty.
		if rarities[i] == "empty" and fixed < empty_count - 1:
			rarities[i] = "common"
			fixed += 1
	var deck: Array = []
	for rarity in rarities:
		var pool: Array = CATALOG[rarity]
		var definition: Array = pool[mini(pool.size() - 1, int(_roll(rng) * pool.size()))]
		deck.append({"name": definition[0], "desc": definition[1],
			"rarity": rarity, "rewardId": definition[2], "revealed": false})
	return deck


func _roll(rng: Dictionary) -> float:
	if roll_override >= 0.0:
		return clampf(roll_override, 0.0, 0.999999)
	var next_value := int((int(rng["value"]) * 48271) % RNG_MODULUS)
	rng["value"] = next_value
	return float(next_value) / float(RNG_MODULUS)


func _apply_reward(candidate: Dictionary, reward_id: String, slot: int) -> bool:
	var attr: Dictionary = candidate.get("attributes", {})
	var resources: Dictionary = candidate.get("resources", {})
	var flags: Dictionary = candidate.get("flags", {}).duplicate(true)
	match reward_id:
		"dragon_mark":
			_add_attr(candidate, "cultivation", 30)
			_add_attr(candidate, "daoHeart", 10)
			_add_attr(candidate, "fortune", 15)
			# GameStateManager.unlock('achievement', ...) currently has no
			# achievement branch, so the browser writes no unlock for this reward.
		"tribulation_immune": flags["tribulationImmune"] = true
		"hunyuan_stone":
			if not _treasure_acquisition.acquire(candidate, "混元神石",
					"slot:%d" % slot, int(candidate["runClock"]["decisionIndex"]) + 1):
				last_error = _treasure_acquisition.last_error
				return false
		"attack_bonus": flags["atkBonus"] = int(flags.get("atkBonus", 0)) + 5
		"dungeon_key":
			resources["spiritStone"] = int(resources.get("spiritStone", 0)) + 50
			flags["dungeonKeys"] = int(flags.get("dungeonKeys", 0)) + 1
		"heaven_book_page":
			_add_attr(candidate, "cultivation", 20)
			flags["heavenBookPage"] = int(flags.get("heavenBookPage", 0)) + 1
		"healing_dew": _add_attr(candidate, "health", 30)
		"spirit_stones_30": resources["spiritStone"] = int(resources.get("spiritStone", 0)) + 30
		"dao_pill": _add_attr(candidate, "daoHeart", 5)
		"spirit_stones_15": resources["spiritStone"] = int(resources.get("spiritStone", 0)) + 15
		"cultivation_pill": _add_attr(candidate, "cultivation", 5)
		"lifespan_peach": resources["lifespan"] = int(resources.get("lifespan", 0)) + 3
		"empty": pass
		_:
			last_error = "未知命盘奖励"
			return false
	candidate["flags"] = flags
	return true


func _add_attr(candidate: Dictionary, name: String, delta: int) -> void:
	var maximum := 100
	if name == "health": maximum = LegacyFragmentFlow.actual_max_health(candidate)
	if name == "daoHeart": maximum = LegacyFragmentFlow.actual_max_dao_heart(candidate)
	if name == "cultivation": maximum = 100
	delta = LegacyFragmentFlow.effective_delta(candidate, name, delta)
	var attributes: Dictionary = candidate["attributes"]
	attributes[name] = clampi(int(attributes.get(name, 0)) + delta, 0, maximum)


func _valid_state(candidate: Dictionary) -> bool:
	if candidate.get("destinyWheelVersion") != 1 \
			or candidate.get("destinyWheelRuleSourceSha") != SOURCE_JS_SHA \
			or not candidate.get("destinyWheelRngState") is Dictionary \
			or not candidate.get("destinyWheelActivationIndex") is int \
				and not candidate.get("destinyWheelActivationIndex") is float:
		return false
	var rng: Dictionary = candidate["destinyWheelRngState"]
	if int(rng.get("initialSeed", 0)) <= 0 or int(rng.get("value", 0)) <= 0 \
			or int(rng.get("value", 0)) >= RNG_MODULUS:
		return false
	if candidate.get("phase") == "DESTINY_WHEEL_PENDING":
		var wheel: Variant = candidate.get("pendingDestinyWheel")
		var covered: Variant = candidate.get("wheelReturn")
		if not wheel is Dictionary or not covered is Dictionary \
				or not wheel.get("deck") is Array or wheel["deck"].size() != 5 \
				or wheel.get("flipped") != 0 or not wheel.get("active", false):
			return false
		for reward in wheel["deck"]:
			if not reward is Dictionary or not CATALOG.has(reward.get("rarity")):
				return false
			var found := false
			for row in CATALOG[reward["rarity"]]:
				if reward.get("name") == row[0] and reward.get("desc") == row[1] \
						and reward.get("rewardId") == row[2] and reward.get("revealed") == false:
					found = true
			if not found:
				return false
	return true
