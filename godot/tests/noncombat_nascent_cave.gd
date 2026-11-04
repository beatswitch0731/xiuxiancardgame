extends "res://tests/noncombat_foundation_normal_pool.gd"

func _run() -> void:
	var game = Domain.new(Registry.new(), null, "slot_3")
	if not game.start("spell"):
		return _fail("nascent cave fixture could not start")
	game.state.realm = "nascent"
	game.state.attributes.health = 80
	var starting_stone := int(game.state.resources.spiritStone)
	game.state.phase = "NORMAL_PENDING"
	game.state.currentCardId = "n_cave"
	var source: Dictionary = game.get_current_card()
	var treasure_id := String(source.get("choices", {}).get("left", {}).get(
		"effects", {}).get("treasure", ""))
	if source.get("id") != "n_cave" or treasure_id.is_empty() \
			or not game.choose("left", game.issue_choice_token()):
		return _fail("nascent cave source entry rejected")
	var source_skills: Dictionary = ContentRepository.new().read_module("config:path_skills")
	var stone_ratio := 0.0
	for skill in source_skills.get("skills", {}).get("spell", {}).get("skills", []):
		if skill.get("unlockRealm") == "foundation":
			stone_ratio += float(skill.get("passive", {}).get("spiritStoneBonus", 0.0))
	var source_stone_gain := int(source.choices.left.effects.spiritStone)
	if game.state.get("dungeonRun", {}).get("dungeonId") != "nascent_cave" \
			or not game.state.resources.treasures.has(treasure_id) \
			or not is_equal_approx(stone_ratio, 0.2) \
			or int(game.state.resources.spiritStone) != starting_stone \
				+ source_stone_gain + floori(source_stone_gain * stone_ratio) \
			or not game.state.get("karmaSeeds", []).any(
				func(seed: Variant) -> bool: return seed is Dictionary \
					and seed.get("id") == "fortuneWheel") \
			or game.get_current_card().get("id") != "nc_trap":
		return _fail("nascent cave entry effects or first node missing: " +
			JSON.stringify({"stones": game.state.resources.spiritStone,
				"startingStones": starting_stone, "sourceGain": source_stone_gain,
				"spellBonus": stone_ratio, "card": game.get_current_card().get("id")}))
	if not game.choose("left", game.issue_choice_token()) \
			or game.get_current_card().get("id") != "nc_treasure":
		return _fail("nascent cave trap did not advance")
	var reward: Dictionary = game.get_current_card()
	var reward_id := String(reward.get("choices", {}).get("right", {}).get(
		"effects", {}).get("treasure", ""))
	var chosen := not reward_id.is_empty() and game.choose("right", game.issue_choice_token())
	if not chosen \
			or game.state.phase != "FLOW_PENDING" \
			or game.state.get("dungeonRun") != null \
			or not game.state.resources.treasures.has(reward_id) \
			or game.state.get("dungeonOutcomeReceipts", []).back().get(
				"outcome") != "success":
		return _fail("nascent cave final reward or completion missing: " +
			JSON.stringify({"chosen": chosen, "phase": game.state.phase,
				"run": game.state.get("dungeonRun"),
				"treasures": game.state.resources.treasures,
				"reward": reward_id,
				"choiceError": game._normal_choice_policy.last_error,
				"receipts": game.state.get("dungeonOutcomeReceipts", [])}))
	var abandon = Domain.new(Registry.new(), null, "slot_3")
	if not abandon.start("spell"):
		return _fail("nascent cave abandon fixture could not start")
	abandon.state.realm = "nascent"
	abandon.state.phase = "NORMAL_PENDING"
	abandon.state.currentCardId = "n_cave"
	if not abandon.choose("left", abandon.issue_choice_token()) \
			or not abandon.abandon_dungeon(abandon.issue_choice_token()) \
			or abandon.state.get("dungeonOutcomeReceipts", []).back().get(
				"outcome") != "abandon" \
			or abandon.abandon_dungeon(abandon.issue_choice_token()):
		return _fail("nascent cave abandon receipt not one-time")
	print("NONCOMBAT_NASCENT_CAVE_PASS nodes=2 rewards=true abandon=true")
	quit(0)
