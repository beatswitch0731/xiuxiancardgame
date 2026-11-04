extends RefCounted

# Source-backed settlement preview for the admitted ordinary choices, including
# golden cards and the first nascent item options. The caller owns histories,
# clocks, target selection, death narrative and the atomic RunSession commit.
const ContentRepository = preload("res://scripts/noncombat_content_repository.gd")
const NormalDrawPolicy = preload("res://scripts/noncombat_normal_draw_policy.gd")
const LegacyFragmentFlow = preload("res://scripts/noncombat_legacy_fragment_flow.gd")
const PathSkillFlow = preload("res://scripts/noncombat_path_skill_flow.gd")
const DeckAcquisition = preload("res://scripts/noncombat_deck_acquisition.gd")
const TreasureAcquisition = preload("res://scripts/noncombat_treasure_acquisition.gd")
const CaveFlow = preload("res://scripts/noncombat_cave_flow.gd")
const FoundationDungeonFlow = preload("res://scripts/noncombat_foundation_dungeon_flow.gd")
const GoldenDungeonFlow = preload("res://scripts/noncombat_golden_dungeon_flow.gd")
const NascentCaveFlow = preload("res://scripts/noncombat_nascent_cave_flow.gd")
const NascentRuinsFlow = preload("res://scripts/noncombat_nascent_ruins_flow.gd")
const HigherDungeonFlow = preload("res://scripts/noncombat_higher_linear_dungeon_flow.gd")
const GAME_LOGIC_JS_SHA := "73d5038d1427433134a644e314d9d501d772c0ba79f67f61f9a46c3e4f8e093b"
const GAME_STATE_JS_SHA := "75e60d10e3284f96715c1ce9229c211215190a39eb10f920e0bb10187b741080"
const EFFECT_SERVICE_JS_SHA := "7552c41cbb707c642c1b66d434c084c33241227ada146ff9322ba707a53a72dc"
const NUMERIC_EFFECTS := ["cultivation", "daoHeart", "health", "fortune",
	"karmaGood", "karmaBad", "spiritStone", "lifespan", "maxHealth",
	"maxDaoHeart"]
const REALM_ORDER := ["qi", "foundation", "golden", "nascent", "deity", "tribulation"]

var last_error := ""
var _content: RefCounted
var _draw_policy: RefCounted
var _deck_acquisition: RefCounted
var _treasure_acquisition: RefCounted

func _init(content: RefCounted = null) -> void:
	_content = content if content != null else ContentRepository.new()
	_draw_policy = NormalDrawPolicy.new(_content)
	_deck_acquisition = DeckAcquisition.new(_content)
	_treasure_acquisition = TreasureAcquisition.new(_content)


func source_card(card_id: String, state: Dictionary = {}) -> Dictionary:
	last_error = ""
	var lookup := state if not state.is_empty() else {"realm": "qi"}
	if card_id in CaveFlow.NODE_IDS:
		var cave := CaveFlow.new(_content)
		var node: Dictionary = cave.node_card(lookup)
		last_error = cave.last_error
		return node if node.get("id") == card_id else {}
	if card_id in FoundationDungeonFlow.NODE_CARDS.values() \
			or card_id == FoundationDungeonFlow.FORK_CARD_ID:
		var dungeon := FoundationDungeonFlow.new(_content)
		var node: Dictionary = dungeon.node_card(lookup)
		last_error = dungeon.last_error
		return node if node.get("id") == card_id else {}
	if state.get("dungeonRun") is Dictionary and state.dungeonRun.get(
			"dungeonId") == NascentCaveFlow.DUNGEON_ID:
		var nascent_cave := NascentCaveFlow.new(_content)
		var nascent_node: Dictionary = nascent_cave.node_card(state)
		last_error = nascent_cave.last_error
		return nascent_node if nascent_node.get("id") == card_id else {}
	if state.get("dungeonRun") is Dictionary and state.dungeonRun.get(
			"dungeonId") == NascentRuinsFlow.DUNGEON_ID:
		var ruins := NascentRuinsFlow.new(_content)
		var ruins_node: Dictionary = ruins.node_card(state)
		last_error = ruins.last_error
		return ruins_node if ruins_node.get("id") == card_id else {}
	if state.get("dungeonRun") is Dictionary and HigherDungeonFlow.REALMS.has(
			state.dungeonRun.get("dungeonId")):
		var higher := HigherDungeonFlow.new(_content)
		var higher_node: Dictionary = higher.node_card(state)
		last_error = higher.last_error
		return higher_node if higher_node.get("id") == card_id else {}
	if state.get("dungeonRun") is Dictionary and state.dungeonRun.get(
			"realm") == "golden":
		var golden_node := GoldenDungeonFlow.new(_content)
		var node: Dictionary = golden_node.node_card(state)
		last_error = golden_node.last_error
		return node if node.get("id") == card_id else {}
	var card: Dictionary = _draw_policy.source_card(lookup, card_id)
	last_error = _draw_policy.last_error
	return card


func choice_available(state: Dictionary, card: Dictionary, direction: String) -> bool:
	var choices: Variant = card.get("choices")
	if not choices is Dictionary or not choices.has(direction):
		return false
	if card.get("id") == "q_shop" or card.get("id") == "f_shop" \
			and direction in ["up", "down"]:
		if direction == "down":
			if not _simple_choice(choices[direction]) \
					or not _affordable(state, choices[direction]):
				return false
			if not _all_positive_capped(state, choices[direction]):
				return true
			for other in ["left", "right", "up"]:
				if _authored_shop_choice(card, other) and _affordable(state,
						choices[other]):
					return false
			return true
		return _authored_shop_choice(card, direction) and _affordable(state,
			choices[direction])
	if card.get("id") == "f_shop" and direction in ["left", "right"]:
		var auction: Dictionary = choices[direction]
		var cost := 60 if direction == "left" else 50
		var item_key := "treasure" if direction == "left" else "pill"
		var item_id := "剑心佩" if direction == "left" else "结金丹"
		return card.get("type") == "SHOP" and card.get("realm") == "foundation" \
			and auction.get("costCheck", {}).get("spiritStone") == cost \
			and auction.get("effects", {}).get("spiritStone") == -cost \
			and auction.get("effects", {}).get(item_key) == item_id \
			and auction.get("effects", {}).size() == 2 \
			and (direction != "left" or auction.get("karmaSeed", {}).get("id") == "pillPoison") \
			and _affordable(state, auction)
	if card.get("id") == "g_shop":
		return _golden_shop_choice(state, card, direction)
	if card.get("id") in ["d_auction", "t_last_auction"]:
		return _higher_shop_choice(state, card, direction)
	if card.get("id") == "ds_demonic_auction" and direction == "left":
		var auction: Dictionary = choices[direction]
		var auction_effects: Dictionary = auction.get("effects", {})
		return card.get("type") == "NORMAL" and card.get("realm") == "nascent" \
			and auction.keys().all(func(key: Variant) -> bool:
				return key in ["text", "desc", "effects", "npcAffection"]) \
			and auction.get("npcAffection") == 20 \
			and auction_effects.get("companion") == "ds_demoness" \
			and auction_effects.size() == 4 \
			and auction_effects.keys().all(func(key: Variant) -> bool:
				return key == "companion" or key in NUMERIC_EFFECTS \
					and _integer(auction_effects[key])) \
			and _affordable(state, auction)
	if card.get("id") == "ds_pill_master_trade" and direction == "right":
		var secret: Dictionary = choices[direction]
		return card.get("type") == "NORMAL" and card.get("realm") == "nascent" \
			and secret.keys().all(func(key: Variant) -> bool:
				return key in ["text", "desc", "effects", "narrativeBlock",
					"_adultThemes"]) \
			and secret.get("narrativeBlock") is String \
			and not String(secret.narrativeBlock).is_empty() \
			and secret.get("_adultThemes") == true \
			and secret.get("effects") is Dictionary \
			and _simple_choice({"effects": secret.effects}) \
			and _affordable(state, secret)
	if card.get("id") == NascentCaveFlow.ENTRY_CARD_ID and direction == "left":
		var cave_entry: Dictionary = choices[direction]
		var cave_effects: Dictionary = cave_entry.get("effects", {})
		return NascentCaveFlow.new(_content).entry(state, card, direction) \
			and cave_entry.keys().all(func(key: Variant) -> bool:
				return key in ["text", "desc", "effects", "dungeon", "karmaSeed"]) \
			and cave_effects.get("treasure") is String \
			and _integer(cave_effects.get("spiritStone")) \
			and cave_effects.size() == 2 \
			and cave_entry.get("karmaSeed") is Dictionary \
			and _affordable(state, cave_entry)
	if card.get("id") == NascentRuinsFlow.ENTRY_CARD_ID and direction == "left":
		var ruins_entry: Dictionary = choices[direction]
		return NascentRuinsFlow.new(_content).entry(state, card, direction) \
			and card.get("type") == "DUNGEON" \
			and ruins_entry.keys().all(func(key: Variant) -> bool:
				return key in ["text", "desc", "dungeon"])
	if HigherDungeonFlow.ENTRIES.has(card.get("id")) and direction == "left":
		return HigherDungeonFlow.new(_content).entry(state, card, direction) \
			and card.get("choices", {}).get(direction, {}).keys().all(
				func(key: Variant) -> bool: return key in ["text", "desc", "dungeon"])
	if card.get("id") in ["n_hunt", "ar_boss", "it_combat"] and direction == "left":
		var combat_choice: Dictionary = choices[direction]
		return card.get("type") == "COMBAT" \
			and (card.get("realm") == "nascent" if card.get("id") == "n_hunt" \
			else card.get("_dungeonId") == (
				"immortal_trial" if card.get("id") == "it_combat" else NascentRuinsFlow.DUNGEON_ID)) \
			and combat_choice.get("triggerCombat") == true \
			and card.get("enemy", {}).get("tier", 0) >= 2 \
			and combat_choice.get("victoryEffects") is Dictionary \
			and combat_choice.get("defeatEffects") is Dictionary \
			and combat_choice.get("fleeEffects") is Dictionary \
			and card.get("combatRewards") is Dictionary
	if card.get("id") in ["n_cave", "n_trade_city"] and (
			card.get("id") == "n_trade_city" and direction in ["left", "right"]
			or card.get("id") == "n_cave" and direction == "right"):
		return _nascent_item_choice(card, choices[direction]) \
			and _affordable(state, choices[direction])
	if card.get("id") == "f_black_market":
		if card.get("realm") != "foundation" or card.get("type") != "NORMAL":
			return false
		if direction == "down":
			if not _simple_choice(choices[direction]):
				return false
			if not _all_positive_capped(state, choices[direction]):
				return true
			for paid_direction in ["left", "right"]:
				if _foundation_deck_purchase(state, card, paid_direction):
					return false
			return true
		return _foundation_deck_purchase(state, card, direction)
	if card.get("id") == "g_bribe" and direction == "left":
		var bribe: Dictionary = choices[direction]
		var bribe_effects: Dictionary = bribe.get("effects", {})
		return card.get("realm") == "golden" and card.get("type") == "SHOP" \
			and bribe.keys().all(func(key: Variant) -> bool:
				return key in ["text", "desc", "effects", "costCheck"]) \
			and bribe.get("costCheck", {}).get("spiritStone") == 50 \
			and bribe_effects.get("spiritStone") == -50 \
			and bribe_effects.get("fortune") == 10 \
			and bribe_effects.get("cultivation") == 10 \
			and bribe_effects.get("karmaBad") == 5 \
			and bribe_effects.size() == 4 and _affordable(state, bribe)
	if card.get("realm") == "foundation" and (
			card.get("id") == "f_market" and direction == "right" \
			or card.get("id") == "f_bribe" and direction == "left" \
			or card.get("id") == "f_demon2" and direction == "left" \
			or card.get("id") == "f_trial" and direction == "left"):
		return _foundation_numeric_extra(card, direction) \
			and _affordable(state, choices[direction])
	if card.get("id") == "f_ruins_explore":
		var ruins_choice: Dictionary = choices[direction]
		var ruins_effects: Dictionary = ruins_choice.get("effects", {})
		return card.get("realm") == "foundation" \
			and card.get("type") == "NORMAL" and direction in ["left", "right"] \
			and ruins_choice.keys().all(func(key: Variant) -> bool:
				return key in ["text", "desc", "effects"]) \
			and ruins_effects.size() == 2 \
			and ruins_effects.get("deckCard") == (
				"qi_shield" if direction == "left" else "heavy_strike") \
			and _integer(ruins_effects.get(
				"daoHeart" if direction == "left" else "health")) \
			and _affordable(state, ruins_choice)
	if card.get("realm") == "foundation" and (
			card.get("id") == "f_demon2" and direction == "right" \
			or card.get("id") == "f_artifact" and direction == "left"):
		var treasure_choice: Dictionary = choices[direction]
		var treasure_effects: Dictionary = treasure_choice.get("effects", {})
		var expected_treasure := "demonTome" if card.get("id") == "f_demon2" \
			else "pathRelic"
		return card.get("type") == "NORMAL" and treasure_choice.keys().all(
			func(key: Variant) -> bool:
				return key in ["text", "desc", "effects"]) \
			and treasure_effects.size() == 3 \
			and treasure_effects.get("treasure") == expected_treasure \
			and treasure_effects.keys().all(func(key: Variant) -> bool:
				return key == "treasure" or key in NUMERIC_EFFECTS \
					and _integer(treasure_effects[key])) \
			and _affordable(state, treasure_choice)
	if card.get("id") == "q_pillRecipe":
		if not _recipe_choice(card, direction) or not _affordable(state,
				choices[direction]):
			return false
		# The authored karma seed is outside effects. A capped fortune reward is
		# browser-disabled unless the paid pill choice is unavailable.
		return direction != "right" or not _all_positive_capped(state,
			choices[direction]) or not _affordable(state, choices["left"])
	if card.get("id") == "q_swordTomb" and direction == "left":
		var sword_choice: Dictionary = choices[direction]
		var seed: Variant = sword_choice.get("karmaSeed")
		var effects: Variant = sword_choice.get("effects")
		return card.get("type") == "NORMAL" and card.get("realm") == "qi" \
			and card.get("path") == "sword" and effects is Dictionary \
			and effects.size() == 3 and effects.get("treasure") == "brokenSword" \
			and _integer(effects.get("cultivation")) \
			and _integer(effects.get("karmaBad")) \
			and seed is Dictionary and seed.get("id") == "swordHonor" \
			and _integer(seed.get("delay")) and _integer(seed.get("priority")) \
			and seed.get("realm") == "nascent" and _affordable(state, sword_choice)
	if card.get("id") == "q_cave" and direction == "right":
		var cave_choice: Dictionary = choices[direction]
		var cave_seed: Variant = cave_choice.get("karmaSeed")
		return card.get("type") == "DUNGEON" and card.get("realm") == "qi" \
			and cave_choice.get("dungeon") == "ancientCave" \
			and cave_choice.get("effects", {}).size() == 3 \
			and _integer(cave_choice.get("effects", {}).get("health")) \
			and _integer(cave_choice.get("effects", {}).get("cultivation")) \
			and _integer(cave_choice.get("effects", {}).get("fortune")) \
			and cave_seed is Dictionary and cave_seed.get("id") == "spellHidden" \
			and _integer(cave_seed.get("delay")) \
			and cave_seed.get("realm") == "golden" and _affordable(state, cave_choice)
	if card.get("id") == "f_trial" and direction == "right":
		var entry: Dictionary = choices[direction]
		return card.get("type") == "DUNGEON" \
			and card.get("realm") == "foundation" \
			and entry.get("dungeon") == FoundationDungeonFlow.DUNGEON_ID \
			and entry.get("effects", {}).size() == 2 \
			and _integer(entry.get("effects", {}).get("health")) \
			and _integer(entry.get("effects", {}).get("cultivation")) \
			and _affordable(state, entry)
	if card.get("id") == FoundationDungeonFlow.FORK_CARD_ID:
		var fork_choice: Dictionary = choices[direction]
		return card.get("type") == "DUNGEON_FORK" \
			and card.get("_dungeonNodeId") == "fork" \
			and fork_choice.get("_dungeonForkNext") == (
				"prepare" if direction == "left" else "boss") \
			and fork_choice.get("effects") is Dictionary \
			and fork_choice.get("effects", {}).size() == (
				1 if direction == "left" else 2) \
			and _integer(fork_choice.get("effects", {}).get(
				"knowledge" if direction == "left" else "health")) \
			and (direction == "left" or _integer(fork_choice.get(
				"effects", {}).get("cultivation"))) \
			and _affordable(state, fork_choice)
	if card.get("id") == "realm_prepare" and direction == "right":
		var preparation: Dictionary = choices[direction]
		return card.get("_dungeonNodeId") == "prepare" \
			and preparation.get("effects", {}).get("deckCard") == "mana_potion" \
			and preparation.get("effects", {}).get("fortune") == 1 \
			and preparation.get("effects", {}).size() == 2 \
			and _affordable(state, preparation)
	if card.get("id") == "realm_treasure":
		var reward: Dictionary = choices[direction]
		var reward_effects: Dictionary = reward.get("effects", {})
		return card.get("_dungeonNodeId") == "reward" \
			and reward_effects.size() == 2 \
			and (reward_effects.get("treasure") == "realmCore" \
				and _integer(reward_effects.get("cultivation")) \
				if direction == "left" else reward_effects.get("pill") == "golden" \
				and _integer(reward_effects.get("spiritStone"))) \
			and _affordable(state, reward)
	if card.get("_dungeonId") == NascentCaveFlow.DUNGEON_ID:
		return _nascent_cave_node_choice(card, choices[direction]) \
			and _affordable(state, choices[direction])
	if card.get("_dungeonId") == NascentRuinsFlow.DUNGEON_ID:
		return _nascent_ruins_node_choice(card, choices[direction]) \
			and _affordable(state, choices[direction])
	if HigherDungeonFlow.REALMS.has(card.get("_dungeonId")):
		return _higher_dungeon_node_choice(card, choices[direction]) \
			and _affordable(state, choices[direction])
	if card.has("_dungeonId"):
		return _golden_dungeon_node_choice(card, choices[direction]) \
			and _affordable(state, choices[direction])
	if card.get("id") in GoldenDungeonFlow.ENTRIES and choices[direction].has("dungeon"):
		return GoldenDungeonFlow.new(_content).entry(state, card, direction) \
			and choices[direction].keys().all(func(key: Variant) -> bool:
				return key in ["text", "desc", "effects", "dungeon"]) \
			and choices[direction].get("effects") is Dictionary \
			and choices[direction].effects.keys().all(func(key: Variant) -> bool:
				return key in NUMERIC_EFFECTS and _integer(
					choices[direction].effects[key])) \
			and _affordable(state, choices[direction])
	if card.get("id") == "realm_guardian":
		return card.get("_dungeonNodeId") == "boss" \
			and card.get("type") == "BOSS_COMBAT" \
			and choices[direction].get("effects") == {} \
			and state.get("dungeonRun", {}).get("dungeonId") \
				== FoundationDungeonFlow.DUNGEON_ID
	if card.get("id") in ["cave_spirit", "cave_beast", "cave_reward"]:
		return _cave_node_choice(card, direction) and _affordable(state,
			choices[direction])
	if card.get("id") == "q_love" and direction == "right":
		if not _mortal_love_choice(card) or not _affordable(state,
				choices[direction]):
			return false
		# The domain now consumes the source's fatal q_love result. Artifact
		# revival has a different browser path and remains outside this slice.
		return state.get("equipment", {}).get("artifact") == null
	if card.get("id") == "f_love" and direction == "right":
		var love_choice: Dictionary = choices[direction]
		var love_effects: Dictionary = love_choice.get("effects", {})
		return card.get("type") == "NORMAL" and card.get("realm") == "foundation" \
			and love_choice.keys().all(func(key: Variant) -> bool:
				return key in ["text", "desc", "effects"]) \
			and love_effects.size() == 3 \
			and love_effects.get("companion") == "demon" \
			and _integer(love_effects.get("cultivation")) \
			and _integer(love_effects.get("karmaBad")) \
			and _affordable(state, love_choice)
	if card.get("id") in ["q_fellow", "f_mission"] and direction == "right":
		return card.get("type") == "COMBAT" and card.get("realm") == (
			"qi" if card.get("id") == "q_fellow" else "foundation") \
			and choices[direction].get("triggerCombat") == true \
			and not card.get("enemy", {}).is_empty() \
			and choices[direction].get("victoryEffects") is Dictionary \
			and choices[direction].get("defeatEffects") is Dictionary \
			and choices[direction].get("fleeEffects") is Dictionary \
			and (card.get("id") != "f_mission" or card.get("combatRewards") is Dictionary \
				and card.get("enemy", {}).get("templateId") == "blazing_tiger_foundation")
	if card.get("id") == "g_oldFriend" and direction == "right":
		var reward: Dictionary = choices[direction]
		var reward_effects: Dictionary = reward.get("effects", {})
		return card.get("realm") == "golden" and card.get("type") == "NORMAL" \
			and reward.keys().all(func(key: Variant) -> bool:
				return key in ["text", "desc", "effects"]) \
			and reward_effects.get("treasure") == "ancientToken" \
			and reward_effects.size() == 3 \
			and _integer(reward_effects.get("cultivation")) \
			and _integer(reward_effects.get("karmaBad"))
	if card.get("id") == "g_pillSecret":
		var formula: Dictionary = choices[direction]
		var formula_effects: Dictionary = formula.get("effects", {})
		return card.get("realm") == "golden" and card.get("type") == "NORMAL" \
			and formula.keys().all(func(key: Variant) -> bool:
				return key in ["text", "desc", "effects"]) \
			and formula_effects.get("pill") == (
				"nascent" if direction == "left" else "golden") \
			and formula_effects.keys().all(func(key: Variant) -> bool:
				return key == "pill" or key in NUMERIC_EFFECTS \
					and _integer(formula_effects[key]))
	if card.get("id") == "sd_dt_final_choice":
		var final_choice: Dictionary = choices[direction]
		var final_effects: Dictionary = final_choice.get("effects", {})
		return card.get("realm") == "deity" and card.get("type") == "STORY" \
			and direction in ["left", "right"] \
			and final_choice.keys().all(func(key: Variant) -> bool:
				return key in ["text", "desc", "effects"]) \
			and final_effects.get("endingCandidate") == (
				"chaos" if direction == "left" else "red_dust") \
			and final_effects.keys().all(func(key: Variant) -> bool:
				return key == "endingCandidate" or key in NUMERIC_EFFECTS \
					and _integer(final_effects[key])) \
			and _affordable(state, final_choice)
	if card.get("type") == "NPC_ENCOUNTER":
		return _source_npc_choice(card, choices[direction]) and _affordable(state,
			choices[direction]) and (card.get("id") != "ds_moon_lake" \
			or direction != "right" or int(state.get("resources", {}).get(
				"pills", {}).get("foundation", 0)) >= 1)
	if card.get("id") == "ds_female_bandit":
		return _bandit_challenge_choice(card, choices[direction]) if direction == "left" \
			else _bandit_parley_choice(card, choices[direction])
	if card.get("id") == "dp_demon_recruit_again" and direction == "left":
		var reveal: Dictionary = choices[direction]
		return card.get("realm") == "foundation" and card.get("type") == "SPECIAL" \
			and reveal.get("nextCard") == "dp_demon_truth" \
			and reveal.keys().all(func(key: Variant) -> bool:
				return key in ["text", "desc", "effects", "nextCard"]) \
			and reveal.get("effects", {}).size() == 2 \
			and _integer(reveal.get("effects", {}).get("daoHeart")) \
			and _integer(reveal.get("effects", {}).get("fortune")) \
			and _affordable(state, reveal)
	if card.get("id") == "iw_comp_sect_forbid" and direction == "right":
		var detached: Dictionary = choices[direction]
		return card.get("type") == "SPECIAL" and card.get("realm") == "golden" \
			and detached.keys().all(func(key: Variant) -> bool:
				return key in ["text", "desc", "effects", "companionEffects"]) \
			and detached.get("companionEffects") is Dictionary \
			and detached.companionEffects.size() == 3 \
			and detached.companionEffects.get("compId") == null \
			and detached.companionEffects.get("affectionDelta") == -50 \
			and detached.companionEffects.get("bondDelta") == -2 \
			and detached.get("effects") is Dictionary \
			and detached.effects.keys().all(func(key: Variant) -> bool:
				return key in NUMERIC_EFFECTS and _integer(detached.effects[key])) \
			and _affordable(state, detached)
	if card.get("id") == "karma_body_awakening":
		return _body_karma_choice(card, direction) and _affordable(state,
			choices[direction])
	if choices[direction].has("karmaSeed"):
		return _seeded_numeric_choice(choices[direction]) and _affordable(state,
			choices[direction])
	if not _simple_choice(choices[direction]) or not _affordable(state, choices[direction]):
		return false
	if not _all_positive_capped(state, choices[direction]):
		return true
	for other in choices:
		if other == direction:
			continue
		# An unported choice may be executable in the browser. Do not create
		# a capped fallback by pretending that choice is unavailable.
		if _affordable(state, choices[other]) and (
				not _simple_choice(choices[other]) \
				or not _all_positive_capped(state, choices[other])):
			return false
	for capped_direction in choices:
		if _simple_choice(choices[capped_direction]) \
				and _affordable(state, choices[capped_direction]) \
				and _all_positive_capped(state, choices[capped_direction]):
			return direction == String(capped_direction)
	return false


func settle(state: Dictionary, card_id: String, direction: String) -> Dictionary:
	last_error = ""
	var card := source_card(card_id, state)
	if card.is_empty() or not choice_available(state, card, direction):
		last_error = "ordinary choice unavailable or unsupported"
		return {}
	var choice: Dictionary = card["choices"][direction]
	var effects: Dictionary = choice.get("effects", {})
	var candidate: Dictionary = state.duplicate(true)
	var path_skill = PathSkillFlow.new(_content)
	if card_id == "ds_moon_lake" and direction == "right":
		var pills: Dictionary = candidate.get("resources", {}).get("pills", {})
		var remaining := int(pills.get("foundation", 0)) - 1
		if remaining < 0:
			return {}
		if remaining == 0:
			pills.erase("foundation")
		else:
			pills["foundation"] = remaining
	if card_id == "ds_spirit_vein" and direction == "left":
		var boost: Dictionary = effects.get("breakthroughBoost", {})
		var flags: Dictionary = candidate.get("flags", {})
		var flag_id := "breakthrough_boost:" + String(boost.get("realm", ""))
		flags[flag_id] = minf(0.5, float(flags.get(flag_id, 0.0)) + float(
			boost.get("amount", 0.0)))
		candidate["flags"] = flags
	if card_id == "q_swordTomb" and direction == "left":
		var next_decision := int(candidate.get("runClock", {}).get("decisionIndex", -1)) + 1
		var transaction_id := "treasure:narrative:life:%s:decision:%d:source:q_swordTomb:item:brokenSword" % [
			candidate.get("runClock", {}).get("lifeId", ""), next_decision]
		if not _treasure_acquisition.acquire(candidate, "brokenSword", "q_swordTomb",
				next_decision, {"source": "narrative_effect", "sourceId": "q_swordTomb",
				"channel": null, "transactionId": transaction_id, "details": {}}):
			last_error = _treasure_acquisition.last_error
			return {}
	if card_id == "cave_beast" and direction == "right":
		var beast_transaction := "treasure:narrative:life:%s:decision:%d:source:cave_beast:item:beastCore" % [
			candidate.get("runClock", {}).get("lifeId", ""),
			int(candidate.get("runClock", {}).get("decisionIndex", -1)) + 1]
		if not _treasure_acquisition.acquire(candidate, "beastCore", "cave_beast",
				int(candidate.get("runClock", {}).get("decisionIndex", -1)) + 1,
				{"source": "narrative_effect", "sourceId": "cave_beast",
				"channel": null, "transactionId": beast_transaction, "details": {}}):
			last_error = _treasure_acquisition.last_error
			return {}
	if card_id == "realm_treasure" and direction == "left":
		var next_decision := int(candidate.get("runClock", {}).get(
			"decisionIndex", -1)) + 1
		var transaction_id := "treasure:narrative:life:%s:decision:%d:source:realm_treasure:item:realmCore" % [
			candidate.get("runClock", {}).get("lifeId", ""), next_decision]
		if not _treasure_acquisition.acquire(candidate, "realmCore", "realm_treasure",
				next_decision, {"source": "narrative_effect", "sourceId": "realm_treasure",
				"channel": null, "transactionId": transaction_id, "details": {}}):
			last_error = _treasure_acquisition.last_error
			return {}
	if card_id in ["f_demon2", "f_artifact"] and direction == (
			"right" if card_id == "f_demon2" else "left"):
		var treasure_id := String(effects["treasure"])
		var next_decision := int(candidate.get("runClock", {}).get(
			"decisionIndex", -1)) + 1
		var transaction_id := "treasure:narrative:life:%s:decision:%d:source:%s:item:%s" % [
			candidate.get("runClock", {}).get("lifeId", ""), next_decision,
			card_id, treasure_id]
		if not _treasure_acquisition.acquire(candidate, treasure_id, card_id,
				next_decision, {"source": "narrative_effect", "sourceId": card_id,
				"channel": null, "transactionId": transaction_id, "details": {}}):
			last_error = _treasure_acquisition.last_error
			return {}
	if card_id == "g_oldFriend" and direction == "right":
		var next_decision := int(candidate.get("runClock", {}).get(
			"decisionIndex", -1)) + 1
		var transaction_id := "treasure:narrative:life:%s:decision:%d:source:g_oldFriend:item:ancientToken" % [
			candidate.get("runClock", {}).get("lifeId", ""), next_decision]
		if not _treasure_acquisition.acquire(candidate, "ancientToken", card_id,
				next_decision, {"source": "narrative_effect", "sourceId": card_id,
				"channel": null, "transactionId": transaction_id, "details": {}}):
			last_error = _treasure_acquisition.last_error
			return {}
	if card.has("_dungeonId") and effects.has("treasure"):
		var treasure_id := String(effects.treasure)
		var next_decision := int(candidate.get("runClock", {}).get(
			"decisionIndex", -1)) + 1
		var transaction_id := "treasure:narrative:life:%s:decision:%d:source:%s:item:%s" % [
			candidate.get("runClock", {}).get("lifeId", ""), next_decision,
			card_id, treasure_id]
		if not _treasure_acquisition.acquire(candidate, treasure_id, card_id,
				next_decision, {"source": "narrative_effect", "sourceId": card_id,
				"channel": null, "transactionId": transaction_id,
				"details": {}}):
			last_error = _treasure_acquisition.last_error
			return {}
	if card_id in ["q_shop", "f_shop", "g_shop"] and direction == "up" \
			or card_id == "q_shop" and direction in ["left", "right"]:
		var cost := int(choice["costCheck"]["spiritStone"])
		candidate["resources"]["spiritStone"] = int(
			candidate["resources"]["spiritStone"]) - cost
		if direction in ["left", "right"]:
			var pill_id := String(effects["pill"])
			var pills: Dictionary = candidate["resources"].get("pills", {})
			pills[pill_id] = int(pills.get(pill_id, 0)) + 1
			candidate["resources"]["pills"] = pills
		return candidate if _apply_passive_regen(candidate) else {}
	if card_id == "f_shop" and direction in ["left", "right"]:
		var cost := int(choice.get("costCheck", {}).get("spiritStone", 0))
		candidate.resources.spiritStone = int(candidate.resources.spiritStone) - cost
		if direction == "left":
			var next_decision := int(candidate.runClock.decisionIndex) + 1
			var transaction_id := "treasure:narrative:life:%s:decision:%d:source:f_shop:item:剑心佩" % [
				candidate.runClock.lifeId, next_decision]
			if not _treasure_acquisition.acquire(candidate, "剑心佩", "f_shop",
					next_decision, {"source": "narrative_effect", "sourceId": "f_shop",
					"channel": null, "transactionId": transaction_id,
					"details": {}}):
				last_error = _treasure_acquisition.last_error
				return {}
		else:
			var pills: Dictionary = candidate.resources.get("pills", {})
			pills["结金丹"] = int(pills.get("结金丹", 0)) + 1
			candidate.resources.pills = pills
		return candidate if _apply_passive_regen(candidate) else {}
	if card_id == "g_shop" and direction in ["left", "right"]:
		candidate.resources.spiritStone = int(candidate.resources.spiritStone) + int(
			effects.spiritStone)
		if direction == "left":
			var pill_id := String(effects.pill)
			var pills: Dictionary = candidate.resources.get("pills", {})
			pills[pill_id] = int(pills.get(pill_id, 0)) + 1
			candidate.resources.pills = pills
		else:
			var treasure_id := String(effects.treasure)
			var next_decision := int(candidate.runClock.decisionIndex) + 1
			var transaction_id := "treasure:narrative:life:%s:decision:%d:source:g_shop:item:%s" % [
				candidate.runClock.lifeId, next_decision, treasure_id]
			if not _treasure_acquisition.acquire(candidate, treasure_id, card_id,
					next_decision, {"source": "narrative_effect", "sourceId": card_id,
					"channel": null, "transactionId": transaction_id, "details": {}}):
				last_error = _treasure_acquisition.last_error
				return {}
		return candidate if _apply_passive_regen(candidate) else {}
	if card_id == "n_trade_city" and direction == "left" \
			or card_id == NascentCaveFlow.ENTRY_CARD_ID and direction == "left":
		var treasure_id := String(effects.treasure)
		var next_decision := int(candidate.runClock.decisionIndex) + 1
		var transaction_id := "treasure:narrative:life:%s:decision:%d:source:%s:item:%s" % [
			candidate.runClock.lifeId, next_decision, card_id, treasure_id]
		if not _treasure_acquisition.acquire(candidate, treasure_id, card_id,
				next_decision, {"source": "narrative_effect", "sourceId": card_id,
				"channel": null, "transactionId": transaction_id, "details": {}}):
			last_error = _treasure_acquisition.last_error
			return {}
	var attributes: Dictionary = candidate.get("attributes", {})
	var resources: Dictionary = candidate.get("resources", {})
	for key in effects:
		if key == "endingCandidate" and card_id == "sd_dt_final_choice":
			candidate["endingCandidate"] = String(effects[key])
			continue
		if key == "breakthroughBoost" and card_id == "ds_spirit_vein":
			continue
		if key == "skillOpportunity" and card_id == "ds_female_bandit":
			continue
		if key == "treasure" and card.has("_dungeonId"):
			continue
		if key == "treasure" and card_id == "q_swordTomb" and direction == "left":
			continue
		if key == "treasure" and (card_id == "cave_beast" and direction == "right" \
				or card_id == "realm_treasure" and direction == "left"):
			continue
		if key == "treasure" and card_id in ["f_demon2", "f_artifact"]:
			continue
		if key == "treasure" and card_id == "g_oldFriend":
			continue
		if key == "treasure" and card_id in ["n_trade_city", "n_cave",
				"nc_treasure"]:
			continue
		if key == "deckCard" and card_id in ["cave_spirit", "cave_reward", "realm_prepare",
				"f_ruins_explore", "f_black_market"]:
			var cave_acquired: Dictionary = _deck_acquisition.acquire_legacy(candidate,
				String(effects[key]), card_id)
			if cave_acquired.is_empty():
				if not _deck_acquisition.last_error in ["奖励卡与流派不符", "奖励卡已取得"]:
					last_error = _deck_acquisition.last_error
					return {}
			else:
				candidate = cave_acquired
				attributes = candidate.get("attributes", {})
				resources = candidate.get("resources", {})
			continue
		if key == "maxHealth" and card_id == "karma_body_awakening":
			var max_gain := int(effects[key])
			candidate["maxHealth"] = maxi(1,
				int(candidate.get("maxHealth", 1)) + max_gain)
			if max_gain > 0:
				var health_cap := path_skill.actual_max_health(candidate)
				if not path_skill.last_error.is_empty():
					return {}
				attributes["health"] = mini(health_cap,
					int(attributes.get("health", 0)) + max_gain)
			continue
		if key == "deckCard" and card_id == "karma_body_awakening":
			var acquired: Dictionary = _deck_acquisition.acquire_legacy(candidate,
				String(effects[key]), card_id)
			if acquired.is_empty():
				# Browser keeps the numeric reward when the authored card belongs
				# to another path or is already owned.
				if not _deck_acquisition.last_error in ["奖励卡与流派不符",
						"奖励卡已取得"]:
					last_error = _deck_acquisition.last_error
					return {}
			else:
				candidate = acquired
				attributes = candidate.get("attributes", {})
				resources = candidate.get("resources", {})
			continue
		if key == "pill" and (card_id in ["q_pillRecipe", "g_pillSecret",
				"d_auction", "t_last_auction"] \
				or card_id == "n_trade_city" and direction == "right" \
				or card_id == "n_cave" and direction == "right" \
				or card.has("_dungeonId")):
			var pill_id := String(effects[key])
			var pills: Dictionary = resources.get("pills", {})
			pills[pill_id] = int(pills.get(pill_id, 0)) + 1
			resources["pills"] = pills
			continue
		if key == "pill" and card_id == "realm_treasure":
			var pills: Dictionary = resources.get("pills", {})
			var pill_id := String(effects[key])
			pills[pill_id] = int(pills.get(pill_id, 0)) + 1
			resources["pills"] = pills
			continue
		if key == "knowledge" and card_id == FoundationDungeonFlow.FORK_CARD_ID:
			var knowledge: Dictionary = candidate.get("knowledge", {})
			knowledge["world"] = int(knowledge.get("world", 0)) + int(effects[key])
			candidate["knowledge"] = knowledge
			continue
		if key == "companion" and card_id in ["q_love", "f_love",
				"ds_demonic_auction"]:
			var companions: Array = resources.get("companions", [])
			if not companions.has(effects[key]):
				companions.append(effects[key])
			resources["companions"] = companions
			continue
		if key in ["maxHealth", "maxDaoHeart"]:
			var max_amount := int(effects[key])
			candidate[key] = maxi(1, int(candidate.get(key, 1)) + max_amount)
			if max_amount > 0:
				var attribute_key := "health" if key == "maxHealth" else "daoHeart"
				var new_maximum := path_skill.actual_max_health(candidate) \
					if key == "maxHealth" else LegacyFragmentFlow.actual_max_dao_heart(candidate)
				if not path_skill.last_error.is_empty():
					return {}
				attributes[attribute_key] = mini(new_maximum,
					int(attributes.get(attribute_key, 0)) + max_amount)
			continue
		var amount := path_skill.effect_delta(candidate, String(key),
			int(effects[key]), String(card.get("id", "")))
		if not path_skill.last_error.is_empty():
			return {}
		if key in ["spiritStone", "lifespan"]:
			resources[key] = maxi(0, int(resources.get(key, 0)) + amount)
			continue
		amount = LegacyFragmentFlow.effective_delta(candidate, key, amount)
		var maximum := 100
		if key == "health":
			maximum = path_skill.actual_max_health(candidate)
			if not path_skill.last_error.is_empty():
				return {}
		elif key == "daoHeart":
			maximum = LegacyFragmentFlow.actual_max_dao_heart(candidate)
		if key == "health" and amount < 0 and int(attributes.get("aura", 0)) > 0:
			var absorbed := mini(int(attributes["aura"]), -amount)
			attributes["aura"] = int(attributes["aura"]) - absorbed
			amount += absorbed
		attributes[key] = clampi(int(attributes.get(key, 0)) + amount, 0, maximum)
	if card.get("type") == "NPC_ENCOUNTER" and choice.has("npcAffection"):
		var npc_id: String = card["npcId"]
		var affections: Dictionary = candidate.get("npcAffection", {})
		var prior_affection := int(affections.get(npc_id,
			candidate.get("npcEncounterScheduling", {}).get("affections", {}).get(
				npc_id, 0))) if candidate.has("choiceEchoState") else int(
				affections.get(npc_id, 0))
		var next_affection := clampi(prior_affection \
			+ int(choice["npcAffection"]), -50, 100)
		affections[npc_id] = next_affection
		candidate["npcAffection"] = affections
		if candidate.has("choiceEchoState") and npc_id == "bai_ren" \
				and candidate.get("npcEncounterScheduling") is Dictionary:
			candidate["npcEncounterScheduling"]["affections"][npc_id] = next_affection
		var bonds: Dictionary = candidate.get("npcBonds", {})
		for level in range(5, -1, -1):
			if next_affection >= [0, 30, 55, 75, 90, 100][level] \
					and int(bonds.get(npc_id, 0)) < level:
				bonds[npc_id] = level
				break
		candidate["npcBonds"] = bonds
		var memories: Dictionary = candidate.get("npcMemories", {})
		var recent: Array = memories.get(npc_id, [])
		recent.append({"turn": int(candidate.get("turn", 0)), "action": "遭遇",
			"reaction": choice.get("text", ""),
			"affectionDelta": int(choice["npcAffection"])})
		if recent.size() > 20:
			recent.pop_front()
		memories[npc_id] = recent
		candidate["npcMemories"] = memories
	if card.get("type") == "COMBAT" or card.get("tags", []).has("combat") \
			or int(effects.get("health", 0)) < 0 or int(effects.get("daoHeart", 0)) < 0:
		resources["lifespan"] = maxi(0, int(resources.get("lifespan", 0)) - 1)
	# The browser applies passive regeneration after the choice and lifespan
	# cost, but before checkDeath. A healer can prevent burn-blood here.
	if not _apply_passive_regen(candidate):
		return {}
	# Browser checkDeath checks dao heart before blood loss. Keep the settled
	# fatal state for the domain to project its authored death card atomically.
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
	return candidate


func _apply_passive_regen(candidate: Dictionary, decision_index: int = -1) -> bool:
	var attributes: Dictionary = candidate.get("attributes", {})
	var resources: Dictionary = candidate.get("resources", {})
	var companions: Variant = resources.get("companions", [])
	# Source effects add these raw IDs to the resource list even when no
	# CompanionSystem profile or NPC exists for registration.
	if not companions is Array or not companions.all(func(id: Variant) -> bool:
		return id is String):
		last_error = "companion passive consumer required"
		return false
	var modifier: Variant = candidate.get("modifiers", {})
	if not modifier is Dictionary:
		last_error = "passive modifier state invalid"
		return false
	var hp_regen := clampi(int(modifier.get("hpRegen", 0)), 0, 2)
	var fortune_bonus := 0
	var arcs: Variant = _content.read_module("companions:arcs")
	if not arcs is Dictionary or not arcs.get("companionArcs") is Dictionary:
		last_error = "companion arc source unavailable"
		return false
	for companion_id in companions:
		var arc: Variant = arcs.companionArcs.get(companion_id)
		if not arc is Dictionary:
			if companion_id not in ["mortal", "demon", "ds_demoness", "whiteFox"]:
				last_error = "companion passive consumer required"
				return false
			continue
		if candidate.get("deadNpcs", []).has(companion_id):
			continue
		var world: Variant = candidate.get("worldContinuityState")
		if world is Dictionary:
			var continuity: Variant = world.get("npcs", {}).get(companion_id)
			if world.get("version") != 1 or world.get("lifeId") != candidate.get(
					"lifeCount", 0) or not continuity is Dictionary \
					or continuity.get("npcId") != companion_id \
					or continuity.get("lifeId") != world.get("lifeId") \
					or continuity.get("lifecycle") != "ACTIVE" \
					or continuity.get("manifestation") != "PHYSICAL":
				continue
		var bonuses: Variant = arc.get("bonuses", {}).get("effects", {})
		if not bonuses is Dictionary:
			return false
		hp_regen += int(bonuses.get("hpRegen", 0))
		fortune_bonus += int(bonuses.get("fortuneBonus", 0))
	var treasure_doc: Variant = _content.read_module("shops:treasures")
	if not treasure_doc is Dictionary or not treasure_doc.get("treasures") is Array:
		last_error = "passive source catalog unavailable"
		return false
	var definitions := {}
	for value in treasure_doc["treasures"]:
		if value is Dictionary and value.get("id") is String:
			definitions[value["id"]] = value
	var equipment: Variant = candidate.get("equipment", {})
	var instances: Variant = candidate.get("treasureInstances", {})
	if not equipment is Dictionary or not instances is Dictionary:
		last_error = "passive equipment ledger invalid"
		return false
	for slot in ["weapon", "armor", "accessory", "artifact"]:
		var equipped: Variant = equipment.get(slot)
		if equipped == null or equipped == "":
			continue
		var definition_id: String = String(equipped)
		if instances.has(equipped):
			var instance: Variant = instances[equipped]
			if not instance is Dictionary or instance.get("lifecycle") != "owned":
				last_error = "passive equipped instance invalid"
				return false
			definition_id = String(instance.get("definitionId", ""))
		var definition: Variant = definitions.get(definition_id)
		if not definition is Dictionary or definition.get("type") != slot:
			last_error = "passive equipped definition invalid"
			return false
		var passive: Variant = definition.get("passive", {})
		if not passive is Dictionary:
			last_error = "passive equipped bonus invalid"
			return false
		hp_regen += int(passive.get("hpRegen", 0))
		fortune_bonus += int(passive.get("fortuneBonus", 0))
	var path_skill = PathSkillFlow.new(_content)
	var path_passive: Dictionary = path_skill.active_bonuses(candidate, decision_index)
	if not path_skill.last_error.is_empty():
		last_error = path_skill.last_error
		return false
	hp_regen += int(path_passive.get("hpRegen", 0))
	fortune_bonus += int(path_passive.get("fortuneBonus", 0))
	if hp_regen > 0:
		var health_cap := path_skill.actual_max_health(candidate, decision_index)
		if not path_skill.last_error.is_empty():
			last_error = path_skill.last_error
			return false
		attributes["health"] = mini(health_cap,
			int(attributes.get("health", 0)) + hp_regen)
	if fortune_bonus > 0:
		attributes["fortune"] = mini(100, int(attributes.get("fortune", 0)) + fortune_bonus)
	return true


func _simple_choice(choice: Variant) -> bool:
	if not choice is Dictionary or not choice.get("effects") is Dictionary:
		return false
	for key in choice:
		if key not in ["text", "desc", "effects"]:
			return false
	for key in choice["effects"]:
		if key not in NUMERIC_EFFECTS or not _integer(choice["effects"][key]):
			return false
	return true


func _higher_shop_choice(state: Dictionary, card: Dictionary,
		direction: String) -> bool:
	if card.get("type") != "SHOP" or card.get("realm") != (
			"deity" if card.id == "d_auction" else "tribulation"):
		return false
	var choices: Dictionary = card.get("choices", {})
	if direction == "down":
		if not _simple_choice(choices[direction]):
			return false
		return not (["left", "right"].any(func(other: String) -> bool:
			return _higher_shop_choice(state, card, other)))
	var choice: Dictionary = choices.get(direction, {})
	if direction not in ["left", "right"] or not choice.get("effects") is Dictionary \
			or not choice.keys().all(func(key: Variant) -> bool:
				return key in ["text", "desc", "effects", "karmaSeed"]) \
			or not choice.effects.keys().all(func(key: Variant) -> bool:
				return key in NUMERIC_EFFECTS and _integer(choice.effects[key]) \
					or key == "pill" and choice.effects[key] is String \
					and not String(choice.effects[key]).is_empty()):
		return false
	if choice.has("karmaSeed") and not _valid_seed(choice.karmaSeed):
		return false
	return _affordable(state, choice)


func _valid_seed(value: Variant) -> bool:
	var seeds: Array = value if value is Array else [value]
	return not seeds.is_empty() and seeds.all(func(seed: Variant) -> bool:
		return seed is String and not String(seed).is_empty() or seed is Dictionary \
			and seed.get("id") is String and not String(seed.id).is_empty())


func _seeded_numeric_choice(choice: Dictionary) -> bool:
	if not choice.keys().all(func(key: Variant) -> bool:
		return key in ["text", "desc", "effects", "karmaSeed"]) \
			or not choice.get("effects") is Dictionary \
			or not choice.effects.keys().all(func(key: Variant) -> bool:
				return key in NUMERIC_EFFECTS and _integer(choice.effects[key])):
		return false
	var seeds: Array = choice.karmaSeed if choice.karmaSeed is Array else [choice.karmaSeed]
	return not seeds.is_empty() and seeds.all(func(seed: Variant) -> bool:
		return seed is String and not String(seed).is_empty() or seed is Dictionary \
			and seed.get("id") is String and not String(seed.id).is_empty())


func _nascent_item_choice(card: Dictionary, choice: Dictionary) -> bool:
	if card.get("realm") != "nascent" or not choice.get("effects") is Dictionary \
			or not choice.keys().all(func(key: Variant) -> bool:
				return key in ["text", "desc", "effects"]):
		return false
	var item_key := "treasure" if card.get("id") == "n_trade_city" \
		and choice.get("effects", {}).has("treasure") else "pill"
	var effects: Dictionary = choice.effects
	return effects.get(item_key) is String and not String(effects[item_key]).is_empty() \
		and effects.keys().all(func(key: Variant) -> bool:
			return key == item_key or key in NUMERIC_EFFECTS and _integer(effects[key]))


func _nascent_cave_node_choice(card: Dictionary, choice: Dictionary) -> bool:
	if card.get("id") not in NascentCaveFlow.NODE_IDS \
			or not choice.get("effects") is Dictionary \
			or not choice.keys().all(func(key: Variant) -> bool:
				return key in ["text", "desc", "effects"]):
		return false
	var effects: Dictionary = choice.effects
	return effects.keys().all(func(key: Variant) -> bool:
		return key in NUMERIC_EFFECTS and _integer(effects[key]) \
			or card.get("id") == "nc_treasure" and key == "treasure" \
			and effects[key] is String and not String(effects[key]).is_empty())


func _nascent_ruins_node_choice(card: Dictionary, choice: Dictionary) -> bool:
	if card.get("id") not in NascentRuinsFlow.NODE_IDS \
			or not choice.get("effects") is Dictionary \
			or not choice.keys().all(func(key: Variant) -> bool:
				return key in ["text", "desc", "effects"]):
		return false
	return choice.effects.keys().all(func(key: Variant) -> bool:
		return key in NUMERIC_EFFECTS and _integer(choice.effects[key]) \
			or card.get("id") == "ar_secret" and key == "treasure" \
			and choice.effects[key] == "涅槃羽" \
			or card.get("id") == "ar_secret" and key == "pill" \
			and choice.effects[key] == "凝婴丹")


func _higher_dungeon_node_choice(card: Dictionary, choice: Dictionary) -> bool:
	if card.get("_dungeonId") not in HigherDungeonFlow.REALMS \
			or not choice.get("effects") is Dictionary \
			or not choice.keys().all(func(key: Variant) -> bool:
				return key in ["text", "desc", "effects"]):
		return false
	return choice.effects.keys().all(func(key: Variant) -> bool:
		return key in NUMERIC_EFFECTS and _integer(choice.effects[key]) \
			or card.get("id") == "ir_treasure" and key == "pill" \
			and choice.effects[key] is String and not String(choice.effects[key]).is_empty())


func _source_npc_choice(card: Dictionary, choice: Dictionary) -> bool:
	if not card.get("npcId") is String or not choice.get("effects") is Dictionary:
		return false
	var core: Variant = _content.read_module("npcs:core")
	if not core is Dictionary or not core.get("npcs", []).any(
			func(row: Variant) -> bool: return row is Dictionary \
				and row.get("id") == card["npcId"]):
		return false
	if not choice.keys().all(func(key: Variant) -> bool:
		return key in ["text", "desc", "effects", "npcAffection",
			"narrativeBlock", "_adultThemes", "costCheck"]):
		return false
	if choice.has("costCheck") and (card.get("id") != "ds_moon_lake" \
			or not choice.costCheck is Dictionary \
			or choice.costCheck.size() != 1 \
			or not choice.costCheck.get("pills") is Dictionary \
			or choice.costCheck.pills.size() != 1 \
			or choice.costCheck.pills.get("foundation") != 1):
		return false
	if choice.has("npcAffection") and not _integer(choice["npcAffection"]):
		return false
	if choice.has("narrativeBlock") and not choice["narrativeBlock"] is String:
		return false
	if choice.has("_adultThemes") and not choice["_adultThemes"] is bool:
		return false
	if card.get("id") == "ds_spirit_vein" and choice.effects.has(
			"breakthroughBoost"):
		var boost: Variant = choice.effects.breakthroughBoost
		if not boost is Dictionary or boost.size() != 2 \
				or boost.get("realm") != "golden" \
				or not is_equal_approx(float(boost.get("amount", 0.0)), 0.2):
			return false
	return choice.effects.keys().all(func(key: Variant) -> bool:
		return key in NUMERIC_EFFECTS and _integer(choice.effects[key]) \
			or key == "breakthroughBoost" and card.get("id") == "ds_spirit_vein")


func _bandit_parley_choice(card: Dictionary, choice: Dictionary) -> bool:
	if card.get("realm") != "golden" or card.get("type") != "DUNGEON" \
			or card.get("npcId") != "ds_bandit_queen" \
			or choice.get("effects") is not Dictionary:
		return false
	var effects: Dictionary = choice.effects
	return choice.keys().all(func(key: Variant) -> bool:
		return key in ["text", "desc", "image", "effects", "npcAffection",
			"narrativeBlock", "_adultThemes"]) \
		and effects.get("skillOpportunity", {}).get("offerId") \
			== "opportunity_tiger_queen_break_stance_v1" \
		and effects.size() == 3 and _integer(effects.get("cultivation")) \
		and _integer(effects.get("karmaBad")) \
		and _integer(choice.get("npcAffection")) \
		and choice.get("narrativeBlock") is String \
		and choice.get("_adultThemes") is bool


func _bandit_challenge_choice(card: Dictionary, choice: Dictionary) -> bool:
	var enemy: Dictionary = choice.get("enemy", {})
	var presentation: Dictionary = choice.get("combatPresentation", {})
	return card.get("realm") == "golden" and card.get("type") == "DUNGEON" \
		and card.get("npcId") == "ds_bandit_queen" \
		and choice.get("triggerCombat") == true \
		and enemy.get("id") == "tiger_queen_golden" \
		and enemy.get("intents") is Array and enemy.intents.size() == 3 \
		and presentation.get("presentationId") == "combat_tiger_queen_bandit_fort_v1" \
		and presentation.get("battlefieldId") == "battlefield_bandit_fort_pc98_v1" \
		and choice.get("victoryEffects", {}).get("skillAcquire", {}).get(
			"offerId") == "opportunity_tiger_queen_break_stance_v1" \
		and choice.get("defeatEffects", {}).size() == 1 \
		and int(choice.get("defeatEffects", {}).get("daoHeart", 0)) == -1 \
		and choice.get("fleeEffects", {}).size() == 1 \
		and int(choice.get("fleeEffects", {}).get("lifespan", 0)) == -1 \
		and int(choice.get("defeatHealthLoss", 0)) == 2


func _golden_dungeon_node_choice(card: Dictionary, choice: Dictionary) -> bool:
	if card.get("type") != "NORMAL" or not choice.get("effects") is Dictionary \
			or not choice.keys().all(func(key: Variant) -> bool:
				return key in ["text", "desc", "effects"]):
		return false
	var treasure_by_card := {"ruins_guardian": "guardianCore",
		"ruins_fork": "ancientSword", "ruins_reward": "ancientJade"}
	for key in choice.effects:
		if key == "treasure":
			if choice.effects[key] != treasure_by_card.get(card.id):
				return false
		elif key == "pill":
			if card.id != "ruins_fork" or choice.effects[key] != "nascent":
				return false
		elif key not in NUMERIC_EFFECTS or not _integer(choice.effects[key]):
			return false
	return true


func _golden_shop_choice(state: Dictionary, card: Dictionary,
		direction: String) -> bool:
	if card.get("realm") != "golden" or card.get("type") != "SHOP":
		return false
	var choices: Dictionary = card.get("choices", {})
	var choice: Dictionary = choices.get(direction, {})
	if choice.is_empty() or not choice.get("effects") is Dictionary:
		return false
	if direction == "down":
		if not _simple_choice(choice):
			return false
		for paid in ["left", "right", "up"]:
			if _golden_shop_choice(state, card, paid):
				return false
		return true
	var effects: Dictionary = choice.effects
	var cost: Dictionary = choice.get("costCheck", {})
	var expected_cost := 120 if direction == "left" else 90 if direction == "right" else 40
	var debit := -24 if direction == "left" else -90 if direction == "right" else -40
	if not direction in ["left", "right", "up"] \
			or not choice.keys().all(func(key: Variant) -> bool:
				return key in ["text", "desc", "effects", "costCheck"]) \
			or cost.size() != 1 or cost.get("spiritStone") != expected_cost \
			or effects.get("spiritStone") != debit or effects.size() != 2 \
			or int(state.get("resources", {}).get("spiritStone", 0)) < expected_cost:
		return false
	if direction == "left":
		return effects.get("pill") is String and not String(effects.pill).is_empty()
	if direction == "right":
		return effects.get("treasure") is String and not String(effects.treasure).is_empty()
	return effects.get("removeCard") == true


func _cave_node_choice(card: Dictionary, direction: String) -> bool:
	if card.get("type") != "NORMAL" or direction not in ["left", "right"]:
		return false
	var choice: Variant = card.get("choices", {}).get(direction)
	if not choice is Dictionary or not choice.get("effects") is Dictionary \
			or not choice.keys().all(func(key: Variant) -> bool:
			return key in ["text", "desc", "effects"]):
		return false
	var effects: Dictionary = choice["effects"]
	var required := []
	match String(card.get("id", "")):
		"cave_spirit":
			required = ["cultivation", "fortune"] if direction == "left" else [
				"cultivation", "karmaBad", "health", "deckCard"]
		"cave_beast":
			required = ["health", "cultivation"] if direction == "left" else [
				"health", "cultivation", "treasure"]
		"cave_reward":
			required = ["spiritStone"] if direction == "left" else [
				"cultivation", "deckCard"]
		_:
			return false
	if effects.size() != required.size():
		return false
	for key in required:
		if not effects.has(key):
			return false
		if key == "deckCard" and effects[key] not in ["backlash_flame", "heavy_strike"]:
			return false
		if key == "treasure" and effects[key] != "beastCore":
			return false
		if key not in ["deckCard", "treasure"] and not _integer(effects[key]):
			return false
	return true


func _authored_shop_choice(card: Dictionary, direction: String) -> bool:
	if card.get("type") != "SHOP" or not direction in ["left", "right", "up"]:
		return false
	if card.get("id") == "f_shop" and (card.get("realm") != "foundation" \
			or direction != "up"):
		return false
	var choice: Variant = card.get("choices", {}).get(direction)
	if not choice is Dictionary or not choice.get("effects") is Dictionary \
			or not choice.get("costCheck") is Dictionary:
		return false
	for key in choice:
		if key not in ["text", "desc", "effects", "costCheck"]:
			return false
	var effects: Dictionary = choice["effects"]
	var check: Dictionary = choice["costCheck"]
	if check.size() != 1 or not _integer(check.get("spiritStone")) \
			or int(check["spiritStone"]) <= 0 \
			or not _integer(effects.get("spiritStone")) \
			or int(effects["spiritStone"]) != -int(check["spiritStone"]):
		return false
	if direction == "up":
		return effects.size() == 2 and effects.get("removeCard") == true
	return effects.size() == 2 and effects.get("pill") is String \
		and not String(effects["pill"]).is_empty()


func _foundation_numeric_extra(card: Dictionary, direction: String) -> bool:
	var choice: Variant = card.get("choices", {}).get(direction)
	if not choice is Dictionary or not choice.get("effects") is Dictionary:
		return false
	var effects: Dictionary = choice["effects"]
	if not effects.keys().all(func(key: Variant) -> bool:
		return key in NUMERIC_EFFECTS and _integer(effects[key])):
		return false
	if card.get("id") in ["f_market", "f_demon2", "f_trial"]:
		var seed: Variant = choice.get("karmaSeed")
		var expected_seed := "fortuneWheel" if card.get("id") == "f_market" \
			else "combatScar" if card.get("id") == "f_demon2" else "swordHonor"
		return card.get("type") == ("DUNGEON" if card.get("id") == "f_trial" \
			else "NORMAL") and choice.keys().all(
			func(key: Variant) -> bool:
				return key in ["text", "desc", "effects", "karmaSeed"]) \
			and seed is Dictionary and seed.get("id") == expected_seed \
			and _integer(seed.get("delay")) and seed.get("realm") == (
				"nascent" if card.get("id") == "f_trial" else "golden") \
			and _integer(seed.get("priority"))
	var check: Variant = choice.get("costCheck")
	return card.get("id") == "f_bribe" and card.get("type") == "SHOP" \
		and choice.keys().all(func(key: Variant) -> bool:
			return key in ["text", "desc", "effects", "costCheck"]) \
		and check is Dictionary and check.size() == 1 \
		and _integer(check.get("spiritStone")) \
		and int(check["spiritStone"]) > 0 \
		and int(effects.get("spiritStone", 0)) == -int(check["spiritStone"])


func _foundation_deck_purchase(state: Dictionary, card: Dictionary,
		direction: String) -> bool:
	if direction not in ["left", "right"]:
		return false
	var choice: Variant = card.get("choices", {}).get(direction)
	if not choice is Dictionary or not choice.get("effects") is Dictionary \
			or not choice.get("costCheck") is Dictionary:
		return false
	var effects: Dictionary = choice["effects"]
	var check: Dictionary = choice["costCheck"]
	var card_id := "sword_array" if direction == "left" else "spell_nuke"
	if not choice.keys().all(func(key: Variant) -> bool:
		return key in ["text", "desc", "effects", "costCheck"]) \
			or effects.size() != 2 or effects.get("deckCard") != card_id \
			or check.size() != 1 or not _integer(check.get("spiritStone")) \
			or int(check["spiritStone"]) != 50 \
			or int(effects.get("spiritStone", 0)) != -50 \
			or not _affordable(state, choice):
		return false
	var deck_source: Variant = _content.read_module("cards:battle_cards")
	if not deck_source is Dictionary:
		return false
	for definition in deck_source.get("battle_cards", []):
		if definition is Dictionary and definition.get("id") == card_id:
			return definition.get("tags", []).has(state.get("path"))
	return false


func _recipe_choice(card: Dictionary, direction: String) -> bool:
	if card.get("type") != "NORMAL" or card.get("path") != "pill" \
			or direction not in ["left", "right"]:
		return false
	var choice: Variant = card.get("choices", {}).get(direction)
	if not choice is Dictionary or not choice.get("effects") is Dictionary:
		return false
	var effects: Dictionary = choice["effects"]
	if direction == "left":
		return choice.keys().all(func(key: Variant) -> bool:
			return key in ["text", "desc", "effects"]) \
			and effects.size() == 3 \
			and _integer(effects.get("spiritStone")) \
			and int(effects["spiritStone"]) < 0 \
			and _integer(effects.get("cultivation")) \
			and effects.get("pill") is String \
			and not String(effects["pill"]).is_empty()
	var seed: Variant = choice.get("karmaSeed")
	return choice.keys().all(func(key: Variant) -> bool:
		return key in ["text", "desc", "effects", "karmaSeed"]) \
		and effects.size() == 1 and _integer(effects.get("fortune")) \
		and seed is Dictionary and seed.get("id") is String \
		and not String(seed["id"]).is_empty() \
		and _integer(seed.get("delay")) and _integer(seed.get("priority"))


func _mortal_love_choice(card: Dictionary) -> bool:
	if card.get("type") != "NORMAL":
		return false
	var choice: Variant = card.get("choices", {}).get("right")
	if not choice is Dictionary or not choice.get("effects") is Dictionary:
		return false
	var effects: Dictionary = choice["effects"]
	return choice.keys().all(func(key: Variant) -> bool:
		return key in ["text", "desc", "effects"]) \
		and effects.size() == 3 and effects.get("companion") == "mortal" \
		and _integer(effects.get("daoHeart")) \
		and _integer(effects.get("cultivation")) \
		and int(effects["daoHeart"]) < 0 \
		and int(effects["cultivation"]) < 0


func _body_karma_choice(card: Dictionary, direction: String) -> bool:
	if card.get("type") != "NORMAL" or direction not in ["left", "right"]:
		return false
	var choice: Variant = card.get("choices", {}).get(direction)
	if not choice is Dictionary or not choice.get("effects") is Dictionary \
			or not choice.keys().all(func(key: Variant) -> bool:
			return key in ["text", "desc", "effects"]):
		return false
	var effects: Dictionary = choice["effects"]
	if direction == "left":
		return effects.size() == 3 and _integer(effects.get("cultivation")) \
			and _integer(effects.get("maxHealth")) \
			and int(effects["maxHealth"]) > 0 \
			and _integer(effects.get("health")) \
			and int(effects["health"]) > 0
	return effects.size() == 2 and _integer(effects.get("cultivation")) \
		and effects.get("deckCard") == "iron_skin"


func _affordable(state: Dictionary, choice: Dictionary) -> bool:
	for key in ["spiritStone", "lifespan"]:
		var amount := int(choice.get("effects", {}).get(key, 0))
		if amount < 0 and int(state.get("resources", {}).get(key, 0)) < -amount:
			return false
	return true


func _all_positive_capped(state: Dictionary, choice: Dictionary) -> bool:
	var effects: Dictionary = choice.get("effects", {})
	var path_skill = PathSkillFlow.new(_content)
	if effects.is_empty():
		return false
	for key in effects:
		if key not in ["cultivation", "daoHeart", "health", "fortune",
				"karmaGood", "karmaBad"] or int(effects[key]) <= 0:
			return false
		var maximum := 100
		if key == "health":
			maximum = path_skill.actual_max_health(state)
			if not path_skill.last_error.is_empty():
				return false
		elif key == "daoHeart":
			maximum = LegacyFragmentFlow.actual_max_dao_heart(state)
		if int(state.get("attributes", {}).get(key, 0)) < maximum:
			return false
	return true


func _integer(value: Variant) -> bool:
	return value is int or value is float and float(value) == float(int(value))
