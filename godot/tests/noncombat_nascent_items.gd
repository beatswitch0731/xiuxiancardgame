extends "res://tests/noncombat_golden_normal_pool.gd"

func _run() -> void:
	var game = Domain.new(Registry.new(), null, "slot_3")
	if not game.start("spell"):
		return _fail("nascent item fixture could not start")
	var state: Dictionary = game.state.duplicate(true)
	state.realm = "nascent"
	state.resources.spiritStone = 100
	var policy = ChoicePolicy.new(ContentRepository.new())
	var cave: Dictionary = policy.source_card("n_cave", state)
	var city: Dictionary = policy.source_card("n_trade_city", state)
	if cave.is_empty() or city.is_empty():
		return _fail("nascent source cards unavailable")
	if not policy.choice_available(state, cave, "right") \
			or not policy.choice_available(state, city, "left") \
			or not policy.choice_available(state, city, "right"):
		return _fail("nascent item source choices unavailable")
	var cave_after: Dictionary = policy.settle(state, "n_cave", "right")
	var cave_pill := String(cave.choices.right.effects.pill)
	var source_skills: Dictionary = ContentRepository.new().read_module("config:path_skills")
	var stone_ratio := 0.0
	for skill in source_skills.get("skills", {}).get("spell", {}).get("skills", []):
		if skill.get("unlockRealm") == "foundation":
			stone_ratio += float(skill.get("passive", {}).get("spiritStoneBonus", 0.0))
	var source_stone_gain := int(cave.choices.right.effects.spiritStone)
	if cave_after.is_empty() or int(cave_after.resources.pills.get(cave_pill, 0)) \
			!= int(state.resources.pills.get(cave_pill, 0)) + 1 \
			or not is_equal_approx(stone_ratio, 0.2) \
			or int(cave_after.resources.spiritStone) != 100 + source_stone_gain \
				+ floori(source_stone_gain * stone_ratio):
		return _fail("nascent cave pill or stone settlement differs from source: "
			+ JSON.stringify({"stones": cave_after.get("resources", {}).get(
				"spiritStone"), "sourceGain": source_stone_gain,
				"spellBonus": stone_ratio}))
	var city_after: Dictionary = policy.settle(state, "n_trade_city", "left")
	var treasure_id := String(city.choices.left.effects.treasure)
	if city_after.is_empty() or int(city_after.resources.spiritStone) != 70 \
			or not city_after.get("treasureInstances", {}).values().any(
				func(value: Variant) -> bool: return value is Dictionary \
					and value.get("definitionId") == treasure_id):
		return _fail("nascent city treasure settlement differs from source: " +
			policy.last_error)
	var pill_after: Dictionary = policy.settle(state, "n_trade_city", "right")
	var city_pill := String(city.choices.right.effects.pill)
	if pill_after.is_empty() or int(pill_after.resources.spiritStone) != 76 \
			or int(pill_after.resources.pills.get(city_pill, 0)) \
			!= int(state.resources.pills.get(city_pill, 0)) + 1:
		return _fail("nascent city pill settlement differs from source")
	var poor: Dictionary = state.duplicate(true)
	poor.resources.spiritStone = 23
	if policy.choice_available(poor, city, "left") \
			or policy.choice_available(poor, city, "right") \
			or not policy.choice_available(poor, city, "down"):
		return _fail("nascent city affordability or leave direction invalid")
	print("NONCOMBAT_NASCENT_ITEMS_PASS cave=true treasure=true pill=true poor=true")
	quit(0)
