extends "res://tests/noncombat_foundation_normal_pool.gd"
const SkillOpportunity = preload("res://scripts/noncombat_skill_opportunity.gd")


func _run() -> void:
	var game = Domain.new(Registry.new(), null, "slot_3")
	if not game.start("spell"):
		return _fail("golden choice fixture could not start")
	var state: Dictionary = game.state.duplicate(true)
	state.realm = "golden"
	state.attributes.cultivation = 10
	state.attributes.daoHeart = 5
	state.attributes.fortune = 50
	var policy = ChoicePolicy.new(ContentRepository.new())
	var count := 0
	for card_id in ["g_coreFormed", "g_spellGreat", "g_tribulationOmen",
			"g_elderMystery"]:
		var card: Dictionary = policy.source_card(card_id, state)
		if card.is_empty():
			return _fail("golden source card unavailable: " + card_id)
		for direction in ["left", "right"]:
			var next: Dictionary = policy.settle(state, card_id, direction)
			if not policy.choice_available(state, card, direction) or next.is_empty():
				return _fail("golden numeric choice unavailable: " + card_id + ":" + direction)
			count += 1
	for row in [{"id": "g_veinFight", "direction": "left"},
			{"id": "g_oldFriend", "direction": "left"},
			{"id": "g_daoConference", "direction": "left"},
			{"id": "g_forbiddenTome", "direction": "left"},
			{"id": "g_fateChoice", "direction": "right"},
			{"id": "iw_sect_family_clash", "direction": "left"},
			{"id": "iw_comp_sect_forbid", "direction": "left"}]:
		var card_id: String = row.id
		var direction: String = row.direction
		var card: Dictionary = policy.source_card(card_id, state)
		if card.is_empty() or not policy.choice_available(state, card, direction):
			return _fail("golden seeded source choice unavailable: " + card_id)
		var branch = Domain.new(Registry.new(), null, "slot_3")
		if not branch.start("spell"):
			return _fail("golden seed branch could not start")
		branch.state = state.duplicate(true)
		branch.state.phase = "NORMAL_PENDING"
		branch.state.currentCardId = card_id
		if not branch.choose(direction, branch.issue_choice_token()) \
				or branch.state.get("karmaSeeds", []).is_empty():
			return _fail("golden seeded choice did not plant: " + card_id)
		if card_id == "iw_sect_family_clash" and branch.state.karmaSeeds.size() != 2:
			return _fail("golden interweave choice lost its two source seeds")
	for row in [{"id": "dp_demon_recruit_again", "direction": "right",
			"seed": "demonRefusedTwice"},
			{"id": "dp_end_of_foundation", "direction": "left",
				"seed": "orthodoxSideChosen"},
			{"id": "dp_end_of_foundation", "direction": "right",
				"seed": "demonSideChosen"}]:
		var branch = Domain.new(Registry.new(), null, "slot_3")
		if not branch.start("spell"):
			return _fail("previous-realm seed fixture could not start")
		branch.state = state.duplicate(true)
		branch.state.phase = "NORMAL_PENDING"
		branch.state.currentCardId = row.id
		if not branch.choose(row.direction, branch.issue_choice_token()) \
				or not branch.state.get("karmaSeeds", []).any(
					func(seed: Variant) -> bool: return seed.get("id") == row.seed \
						and seed.get("originCard") == row.id):
			return _fail("previous-realm source seed not planted: " + row.id)
	var demon_reveal = Domain.new(Registry.new(), null, "slot_3")
	if not demon_reveal.start("spell"):
		return _fail("demon continuation fixture could not start")
	demon_reveal.state = state.duplicate(true)
	demon_reveal.state.phase = "NORMAL_PENDING"
	demon_reveal.state.currentCardId = "dp_demon_recruit_again"
	if not demon_reveal.choose("left", demon_reveal.issue_choice_token()) \
			or demon_reveal.state.phase != "NORMAL_PENDING" \
			or demon_reveal.get_current_card().get("id") != "dp_demon_truth" \
			or demon_reveal.state.get("decisionCheckpoint", {}).get(
				"sourceCardId") != "dp_demon_recruit_again" \
			or not demon_reveal.choose("left", demon_reveal.issue_choice_token()):
		return _fail("authored demon truth continuation did not arrive and settle")
	var friend: Dictionary = policy.source_card("g_oldFriend", state)
	var token: Dictionary = policy.settle(state, "g_oldFriend", "right")
	if not policy.choice_available(state, friend, "right") or token.is_empty() \
			or not token.get("resources", {}).get("treasures", []).has("ancientToken") \
			or not token.get("treasureCommandReceipts", {}).values().any(
				func(row: Variant) -> bool: return row.get("definitionId") == "ancientToken"):
		return _fail("golden old-friend ancient token did not enter ownership ledger")
	for row in [{"id": "g_veinFight", "direction": "up", "field": "maxHealth"},
			{"id": "g_demonSeed", "direction": "left", "field": "maxHealth"},
			{"id": "g_forbiddenTome", "direction": "right", "field": "maxDaoHeart"}]:
		var before: int = int(state[row.field])
		var max_card: Dictionary = policy.source_card(row.id, state)
		var max_result: Dictionary = policy.settle(state, row.id, row.direction)
		if not policy.choice_available(state, max_card, row.direction) \
				or max_result.is_empty() or int(max_result[row.field]) != before - 1:
			return _fail("golden authored maximum loss did not settle: " + row.id)
	for direction in ["left", "right"]:
		var formula: Dictionary = policy.source_card("g_pillSecret", state)
		var pill_result: Dictionary = policy.settle(state, "g_pillSecret", direction)
		var pill_id := "nascent" if direction == "left" else "golden"
		if not policy.choice_available(state, formula, direction) \
				or pill_result.is_empty() \
				or int(pill_result.resources.pills.get(pill_id, 0)) != 1:
			return _fail("golden pill-secret source choice did not grant " + pill_id)
	var rich: Dictionary = state.duplicate(true)
	rich.resources.spiritStone = 80
	var bribe: Dictionary = policy.source_card("g_bribe", rich)
	var paid: Dictionary = policy.settle(rich, "g_bribe", "left")
	if not policy.choice_available(rich, bribe, "left") or paid.is_empty() \
			or int(paid.resources.spiritStone) != 30 \
			or int(paid.attributes.cultivation) != int(rich.attributes.cultivation) + 10:
		return _fail("golden bribe fee or authored gain differs")
	var shop: Dictionary = policy.source_card("g_shop", state)
	var poor: Dictionary = state.duplicate(true)
	poor.resources.spiritStone = 15
	var affluent: Dictionary = state.duplicate(true)
	affluent.resources.spiritStone = 130
	var medicine: Dictionary = policy.settle(affluent, "g_shop", "left")
	var jewelry: Dictionary = policy.settle(affluent, "g_shop", "right")
	var source_pill := String(shop.choices.left.effects.pill)
	var source_treasure := String(shop.choices.right.effects.treasure)
	if shop.is_empty() or not policy.choice_available(poor, shop, "down") \
			or policy.choice_available(poor, shop, "up") \
			or not policy.choice_available(affluent, shop, "left") \
			or policy.choice_available(affluent, shop, "down") \
			or medicine.is_empty() or int(medicine.resources.spiritStone) != 106 \
			or int(medicine.resources.pills.get(source_pill, 0)) != 1 \
			or jewelry.is_empty() or int(jewelry.resources.spiritStone) != 40 \
			or not jewelry.resources.treasures.has(source_treasure):
		return _fail("golden shop source price gate or goods differ")
	var shop_game = Domain.new(Registry.new(), null, "slot_3")
	if not shop_game.start("spell"):
		return _fail("golden shop branch could not start")
	shop_game.state = affluent.duplicate(true)
	shop_game.state.phase = "NORMAL_PENDING"
	shop_game.state.currentCardId = "g_shop"
	if not shop_game.choose("up", shop_game.issue_choice_token()) \
			or shop_game.state.phase != "CAMP_TARGET_PENDING" \
			or int(shop_game.state.resources.spiritStone) != 90 \
			or shop_game.camp_targets().is_empty():
		return _fail("golden shop removal did not reach paid target selector")
	var deck_before: Array = shop_game.state.deck.duplicate(true)
	if not shop_game.resolve_camp_target(5, String(deck_before[5]),
			shop_game.issue_choice_token()) \
			or int(shop_game.state.resources.spiritStone) != 84 \
			or shop_game.state.deck.size() != deck_before.size() - 1 \
			or shop_game.state.campTargetHistory.back().get("sourceCardId") != "g_shop":
		return _fail("golden shop second removal fee or target receipt differs")
	var social_state: Dictionary = state.duplicate(true)
	social_state.resources.spiritStone = 40
	for row in [{"id": "ds_blood_moon", "npc": "ds_bloodrose"},
			{"id": "ds_temptation_inn", "npc": "ds_traveler"}]:
		var encounter: Dictionary = policy.source_card(row.id, social_state)
		for direction in ["left", "right"]:
			var outcome: Dictionary = policy.settle(social_state, row.id, direction)
			if not policy.choice_available(social_state, encounter, direction) \
					or outcome.is_empty() or int(outcome.get("npcAffection", {}).get(
						row.npc, 0)) != int(encounter.choices[direction].npcAffection) \
					or outcome.get("npcMemories", {}).get(row.npc, []).size() != 1:
				return _fail("source NPC encounter effect or relationship missing: " \
					+ row.id + ":" + direction)
	var spirit: Dictionary = policy.source_card("ds_spirit_vein", social_state)
	var spirit_right: Dictionary = policy.settle(social_state,
		"ds_spirit_vein", "right")
	if spirit.is_empty() or not policy.choice_available(social_state,
			spirit, "right") or spirit_right.is_empty() \
			or not policy.choice_available(social_state, spirit, "left"):
		return _fail("spirit-vine ordinary branches unavailable")
	var boost_state: Dictionary = social_state.duplicate(true)
	boost_state.attributes.cultivation = 60
	var boosted: Dictionary = policy.settle(boost_state, "ds_spirit_vein", "left")
	if boosted.is_empty() or int(boosted.attributes.cultivation) != 35 \
			or int(boosted.attributes.daoHeart) != mini(int(boost_state.maxDaoHeart),
				int(boost_state.attributes.daoHeart) + 10) \
			or not is_equal_approx(float(boosted.get("flags", {}).get(
				"breakthrough_boost:golden", 0.0)), 0.2) \
			or boost_state.get("flags", {}).has("breakthrough_boost:golden"):
		return _fail("spirit-vine authored boost producer or numeric settlement differs")
	boost_state["flags"] = {"breakthrough_boost:golden": 0.4}
	var capped: Dictionary = policy.settle(boost_state, "ds_spirit_vein", "left")
	if capped.is_empty() or not is_equal_approx(float(capped.get("flags", {}).get(
			"breakthrough_boost:golden", 0.0)), 0.5):
		return _fail("spirit-vine boost exceeded source cap")
	var moon: Dictionary = policy.source_card("ds_moon_lake", social_state)
	var moon_paid: Dictionary = social_state.duplicate(true)
	moon_paid.resources.pills.foundation = 1
	var moon_result: Dictionary = policy.settle(moon_paid, "ds_moon_lake", "right")
	if moon.is_empty() or policy.choice_available(social_state, moon, "right") \
			or not policy.choice_available(moon_paid, moon, "right") \
			or moon_result.is_empty() \
			or moon_result.resources.pills.has("foundation") \
			or int(moon_result.get("npcAffection", {}).get("ds_moonmist", 0)) != 20:
		return _fail("moon-lake pill fee or NPC relationship differs: " \
			+ JSON.stringify({"poorAvailable": policy.choice_available(
				social_state, moon, "right"), "paidAvailable": policy.choice_available(
				moon_paid, moon, "right"), "result": moon_result,
				"shape": policy._source_npc_choice(moon, moon.choices.right),
				"pills": moon_paid.resources.pills,
				"error": policy.last_error}))
	var forbid: Dictionary = policy.source_card("iw_comp_sect_forbid", state)
	var detached: Dictionary = policy.settle(state,
		"iw_comp_sect_forbid", "right")
	if forbid.is_empty() or not policy.choice_available(state, forbid, "right") \
			or detached.is_empty() \
			or int(detached.maxDaoHeart) != int(state.maxDaoHeart) - 1 \
			or detached.has("npcAffection"):
		return _fail("source companion-null interweave branch differs")
	var bandit: Dictionary = policy.source_card("ds_female_bandit", state)
	var parley: Dictionary = policy.settle(state, "ds_female_bandit", "right")
	if bandit.is_empty() or not policy.choice_available(state, bandit, "right") \
			or parley.is_empty() or int(parley.attributes.cultivation) \
			!= int(state.attributes.cultivation) + 4:
		return _fail("bandit parley did not apply its authored numeric branch")
	var body_game = Domain.new(Registry.new(), null, "slot_3")
	if not body_game.start("body"):
		return _fail("bandit body opportunity fixture could not start")
	var body: Dictionary = body_game.state.duplicate(true)
	body.realm = "golden"
	body.attributes.fortune = 50
	body.attributes.daoHeart = 5
	body.attributes.cultivation = 10
	var skill_flow = SkillOpportunity.new(ContentRepository.new())
	var skill_preview: Dictionary = skill_flow.preview(body)
	var won: Dictionary = skill_flow.resolve(body,
		int(body.runClock.decisionIndex) + 1, 0.0)
	var lost: Dictionary = skill_flow.resolve(body,
		int(body.runClock.decisionIndex) + 1, 0.999)
	if skill_preview.get("chance") != 50 or won.is_empty() or lost.is_empty() \
			or not won.deck.has("tiger_break_stance") \
			or won.get("skillAcquisitions", {}).get("tiger_break_stance", {}).get(
				"sourceId") != "ds_female_bandit" \
			or won.get("skillOpportunityAttempts", {}).get(
				"opportunity_tiger_queen_break_stance_v1", {}).get("outcome") != "acquired" \
			or lost.deck.has("tiger_break_stance") \
			or lost.get("skillOpportunityAttempts", {}).get(
				"opportunity_tiger_queen_break_stance_v1", {}).get("outcome") != "failed" \
			or skill_flow.preview(won).get("reason") != "already_acquired" \
			or skill_flow.preview(lost).get("reason") != "already_attempted":
		return _fail("bandit skill opportunity chance or once-per-life ledger differs")
	body_game.state = body.duplicate(true)
	body_game.state.phase = "NORMAL_PENDING"
	body_game.state.currentCardId = "ds_female_bandit"
	body_game.state.normalFlow = body_game._prepare_normal_flow(body_game.state)
	body_game.state.normalFlow.rngState = 1
	var body_parley: Dictionary = policy.settle(body_game.state,
		"ds_female_bandit", "right")
	var body_preview: Dictionary = skill_flow.preview(body_parley)
	var bandit_chosen: bool = body_game.choose("right", body_game.issue_choice_token())
	if not bandit_chosen \
			or not body_game.state.deck.has("tiger_break_stance") \
			or body_game.state.get("skillOpportunityAttempts", {}).get(
				"opportunity_tiger_queen_break_stance_v1", {}).get("outcome") != "acquired":
		return _fail("bandit source choice did not commit its skill attempt atomically: " \
			+ JSON.stringify({"chosen": bandit_chosen,
				"reason": body_game.flow_failure_reason(),
				"phase": body_game.state.phase,
				"card": body_game.get_current_card().get("id"),
				"policy": policy.choice_available(body_game.state,
					bandit, "right"),
				"settled": not body_parley.is_empty(),
				"offer": body_preview.get("reason"),
				"attempts": body_game.state.get("skillOpportunityAttempts", {}),
				"deck": body_game.state.deck}))
	var spell_parley = Domain.new(Registry.new(), null, "slot_3")
	if not spell_parley.start("spell"):
		return _fail("bandit alternate-path fixture could not start")
	spell_parley.state = state.duplicate(true)
	spell_parley.state.phase = "NORMAL_PENDING"
	spell_parley.state.currentCardId = "ds_female_bandit"
	if not spell_parley.choose("right", spell_parley.issue_choice_token()) \
			or int(spell_parley.state.attributes.cultivation) != 14 \
			or spell_parley.state.has("skillOpportunityAttempts"):
		return _fail("bandit alternate path lost numeric effect or rolled an ineligible skill")
	print("NONCOMBAT_GOLDEN_CHOICES_PASS numeric=", count,
		" seeded=10 treasure=true max_loss=3 pills=2 bribe=true shop=true npc=6 boost_producer=true bandit_parley=true")
	quit(0)
