extends "res://tests/noncombat_market_arrival.gd"

const DrawPolicy = preload("res://scripts/noncombat_normal_draw_policy.gd")
const ChoicePolicy = preload("res://scripts/noncombat_normal_choice_policy.gd")
const ContentRepository = preload("res://scripts/noncombat_content_repository.gd")
const BattlePlanResolver = preload("res://scripts/battle_plan_resolver.gd")
const CombatDomain = preload("res://scripts/combat_domain.gd")


func _run() -> void:
	var path := "user://tests/foundation_normal_pool_%d.json" % Time.get_ticks_usec()
	var game = Domain.new(Registry.new(), RunSession.new(path, "slot_3"), "slot_3")
	if not game.start("spell"):
		return _fail("foundation normal source state could not start")
	var state: Dictionary = game.state.duplicate(true)
	state.realm = "foundation"
	state.attributes.cultivation = 10
	state.attributes.daoHeart = state.maxDaoHeart
	state.resources.spiritStone = 15
	var draw = DrawPolicy.new(ContentRepository.new())
	var buckets: Dictionary = draw.buckets(state)
	if buckets.is_empty() or not buckets.get("current", []).any(
			func(row: Variant) -> bool: return row.get("id") == "f_master"):
		return _fail("foundation source pool omitted current-realm cultivation card")
	var choice = ChoicePolicy.new(ContentRepository.new())
	var shop: Dictionary = choice.source_card("f_shop", state)
	if shop.get("id") != "f_shop" \
			or not choice.choice_available(state, shop, "down") \
			or choice.choice_available(state, shop, "left"):
		return _fail("unaffordable auction blocked source capped exit")
	var exit_state: Dictionary = choice.settle(state, "f_shop", "down")
	if exit_state.is_empty() or int(exit_state.resources.spiritStone) != 15:
		return _fail("foundation auction exit failed to settle once")
	var rich: Dictionary = state.duplicate(true)
	rich.resources.spiritStone = 96
	var trim: Dictionary = state.duplicate(true)
	trim.resources.spiritStone = 30
	if not choice.choice_available(trim, shop, "up") \
			or choice.choice_available(trim, shop, "down"):
		return _fail("foundation auction 25-49 stone band has no source card-removal route")
	var trim_state: Dictionary = choice.settle(trim, "f_shop", "up")
	if trim_state.is_empty() or int(trim_state.resources.spiritStone) != 5:
		return _fail("foundation auction did not charge authored removal fee")
	var auction_left: Dictionary = choice.settle(rich, "f_shop", "left")
	var auction_right: Dictionary = choice.settle(rich, "f_shop", "right")
	if auction_left.is_empty() or int(auction_left.resources.spiritStone) != 36 \
			or not auction_left.resources.treasures.has("剑心佩") \
			or auction_right.is_empty() \
			or int(auction_right.resources.spiritStone) != 46 \
			or int(auction_right.resources.pills.get("结金丹", 0)) != 1:
		return _fail("foundation auction paid source goods did not settle")
	var master: Dictionary = choice.source_card("f_master", state)
	var learned: Dictionary = choice.settle(state, "f_master", "left")
	if master.get("id") != "f_master" or learned.is_empty() \
			or int(learned.attributes.cultivation) != 30:
		return _fail("foundation mentor card did not grant source cultivation")
	var target = Domain.new(Registry.new(), null, "slot_3")
	if not target.start("spell"):
		return _fail("foundation auction target fixture could not start")
	target.state = rich.duplicate(true)
	target.state.phase = "NORMAL_PENDING"
	target.state.currentCardId = "f_shop"
	var deck_before: Array = target.state.deck.duplicate(true)
	if not target.choose("up", target.issue_choice_token()) \
			or target.state.phase != "CAMP_TARGET_PENDING" \
			or target.get_current_card().get("id") != "f_shop" \
			or int(target.state.resources.spiritStone) != 71 \
			or not target.resolve_camp_target(5, String(deck_before[5]),
				target.issue_choice_token()) \
			or int(target.state.resources.spiritStone) != 65 \
			or target.state.deck.size() != deck_before.size() - 1 \
			or target.state.campTargetHistory.back().get("sourceCardId") != "f_shop":
		return _fail("foundation auction target did not charge both source fees")
	var market: Dictionary = choice.source_card("f_market", state)
	if market.get("id") != "f_market" \
			or not choice.choice_available(state, market, "right"):
		return _fail("foundation market low-stone alternate path unavailable")
	var market_game = Domain.new(Registry.new(), null, "slot_3")
	if not market_game.start("spell"):
		return _fail("foundation market seed fixture could not start")
	market_game.state = state.duplicate(true)
	market_game.state.phase = "NORMAL_PENDING"
	market_game.state.currentCardId = "f_market"
	if not market_game.choose("right", market_game.issue_choice_token()) \
			or not market_game.state.karmaSeeds.any(func(seed: Variant) -> bool:
				return seed.get("id") == "fortuneWheel" \
					and seed.get("originCard") == "f_market"):
		return _fail("foundation market did not plant authored golden-realm promise")
	var bribe: Dictionary = choice.source_card("f_bribe", rich)
	var paid: Dictionary = choice.settle(rich, "f_bribe", "left")
	if bribe.get("id") != "f_bribe" or paid.is_empty() \
			or int(paid.resources.spiritStone) != 66 \
			or int(paid.attributes.cultivation) != 15:
		return _fail("foundation relationship source fee or gain differs")
	var demon: Dictionary = choice.source_card("f_demon2", state)
	if demon.get("id") != "f_demon2" \
			or not choice.choice_available(state, demon, "left"):
		return _fail("foundation demon refusal unavailable")
	var ruins: Dictionary = choice.source_card("f_ruins_explore", state)
	if ruins.get("id") != "f_ruins_explore" \
			or not choice.choice_available(state, ruins, "left") \
			or not choice.choice_available(state, ruins, "right"):
		return _fail("foundation ruins lost both authored paths")
	var body_game = Domain.new(Registry.new(), null, "slot_3")
	if not body_game.start("body"):
		return _fail("foundation ruins body fixture could not start")
	var body_state: Dictionary = body_game.state.duplicate(true)
	body_state.realm = "foundation"
	var body_reward: Dictionary = choice.settle(body_state, "f_ruins_explore", "left")
	if body_reward.is_empty() or not body_reward.deck.has("qi_shield"):
		return _fail("foundation ruins body deck reward missing")
	var demon_reward: Dictionary = choice.settle(rich, "f_demon2", "right")
	if demon_reward.is_empty() or not demon_reward.resources.treasures.has(
			"demonTome"):
		return _fail("foundation demon bargain did not grant authored treasure")
	var relic: Dictionary = choice.settle(rich, "f_artifact", "left")
	if relic.is_empty() or int(relic.resources.spiritStone) != 46 \
			or not relic.resources.treasures.has("pathRelic"):
		return _fail("foundation relic auction did not grant authored treasure")
	var sword_game = Domain.new(Registry.new(), null, "slot_3")
	if not sword_game.start("sword"):
		return _fail("foundation black market sword fixture could not start")
	var sword_state: Dictionary = sword_game.state.duplicate(true)
	sword_state.realm = "foundation"
	sword_state.resources.spiritStone = 96
	var black_market: Dictionary = choice.source_card("f_black_market", sword_state)
	var sword_buy: Dictionary = choice.settle(sword_state, "f_black_market", "left")
	if black_market.get("id") != "f_black_market" \
			or not choice.choice_available(sword_state, black_market, "left") \
			or choice.choice_available(sword_state, black_market, "right") \
			or sword_buy.is_empty() or int(sword_buy.resources.spiritStone) != 46 \
			or not sword_buy.deck.has("sword_array"):
		return _fail("foundation black market source sword purchase differs")
	var spell_buy: Dictionary = choice.settle(rich, "f_black_market", "right")
	if spell_buy.is_empty() or int(spell_buy.resources.spiritStone) != 46 \
			or not spell_buy.deck.has("spell_nuke") \
			or choice.choice_available(rich, black_market, "left"):
		return _fail("foundation black market source spell purchase differs")
	var trial: Dictionary = choice.source_card("f_trial", state)
	if trial.get("id") != "f_trial" \
			or not choice.choice_available(state, trial, "left"):
		return _fail("foundation secret-realm token sale unavailable")
	for promise in [{"card": "f_demon2", "seed": "combatScar"},
			{"card": "f_trial", "seed": "swordHonor"}]:
		var promise_game = Domain.new(Registry.new(), null, "slot_3")
		if not promise_game.start("spell"):
			return _fail("foundation seed fixture could not start")
		promise_game.state = state.duplicate(true)
		promise_game.state.phase = "NORMAL_PENDING"
		promise_game.state.currentCardId = promise["card"]
		if not promise_game.choose("left", promise_game.issue_choice_token()) \
				or not promise_game.state.karmaSeeds.any(func(seed: Variant) -> bool:
					return seed.get("id") == promise["seed"] \
						and seed.get("originCard") == promise["card"]):
			return _fail("foundation source promise missing: " + promise["card"])
	var love_state: Dictionary = state.duplicate(true)
	love_state.attributes.karmaGood = 100
	var love: Dictionary = choice.source_card("f_love", love_state)
	var love_right: Dictionary = choice.settle(love_state, "f_love", "right")
	if love.get("id") != "f_love" or love_right.is_empty() \
			or not love_right.resources.companions.has("demon"):
		return _fail("foundation demon companion choice left a capped card stranded")
	var next_after_love: Dictionary = choice.settle(love_right, "f_master", "right")
	if next_after_love.is_empty() or not next_after_love.resources.companions.has(
			"demon"):
		return _fail("unregistered demon inventory blocked later ordinary choices")
	var mission: Dictionary = choice.source_card("f_mission", state)
	if mission.get("id") != "f_mission" \
			or not choice.choice_available(state, mission, "right"):
		return _fail("foundation source beast mission combat route unavailable")
	var mission_game = Domain.new(Registry.new(), null, "slot_3")
	if not mission_game.start("spell"):
		return _fail("foundation beast mission fixture could not start")
	mission_game.state = state.duplicate(true)
	mission_game.state.phase = "NORMAL_PENDING"
	mission_game.state.currentCardId = "f_mission"
	mission_game.state.runClock.decisionIndex = 1
	mission_game.state.turn = 1
	if not mission_game.choose("right", mission_game.issue_choice_token()) \
			or mission_game.state.phase != "WARNING_PENDING" \
			or not mission_game.choose("left", mission_game.issue_choice_token()) \
			or mission_game.state.phase != "BATTLE_PENDING" \
			or mission_game.battle_request().get("sourceCardId") != "f_mission":
		return _fail("foundation beast mission did not reach owned battle request: " \
			+ JSON.stringify({"phase": mission_game.state.phase,
				"card": mission_game.get_current_card().get("id"),
				"gateway": mission_game._battle_gateway.source_error,
				"error": mission_game.flow_failure_reason()}))
	var mission_request: Dictionary = mission_game.battle_request()
	var mission_plan: Dictionary = BattlePlanResolver.new(Registry.new()).resolve_persisted(
		mission_game.state)
	if mission_plan.get("launchAuthorized") != true \
			or mission_plan.get("enemy") != mission_request.get(
				"pendingResolution", {}).get("combatCard", {}).get("enemy"):
		return _fail("foundation beast mission lacks source battle stage")
	var mission_combat = CombatDomain.new(Registry.new())
	if not mission_combat.load_persisted_request(mission_request, mission_plan) \
			or mission_combat.state.get("enemyIntent", {}).get("type") != "debuff":
		return _fail("foundation beast mission combat template or first intent differs")
	mission_combat._advance_sequential_intent()
	if mission_combat.state.enemyIntent.get("type") != "attack":
		return _fail("foundation beast mission second normal intent differs")
	mission_combat.state.enemy.hp = 5
	mission_combat._advance_sequential_intent()
	if mission_combat.state.enemyIntent.get("type") != "buff" \
			or int(mission_combat.state.enemy.intentIndex) != 2:
		return _fail("foundation beast injury did not trigger one-time rage")
	mission_combat._advance_sequential_intent()
	if mission_combat.state.enemyIntent.get("type") != "debuff":
		return _fail("foundation beast rage wrongly consumed normal intent cycle")
	var pending_mission: Dictionary = mission_game.state.duplicate(true)
	for outcome in ["victory", "defeat", "flee"]:
		var branch = Domain.new(Registry.new(), null, "slot_3")
		if not branch.start("spell"):
			return _fail("foundation beast result fixture could not start")
		branch.state = pending_mission.duplicate(true)
		var request: Dictionary = branch.battle_request()
		var result := {"contractVersion": 2,
			"encounterInstanceId": request.encounterInstanceId,
			"sourceCardId": request.sourceCardId,
			"encounterId": request.encounterId,
			"sourceContentHash": request.sourceContentHash,
			"outcome": outcome,
			"combatReceipt": "combat:" + String(request.encounterInstanceId),
			"postBattleState": {"encounterInstanceId": request.encounterInstanceId,
				"terminal": true, "combatPhase": outcome.to_upper()}}
		if not branch.submit_battle_result(result) \
				or branch.state.phase != "BATTLE_RESULT_PENDING":
			return _fail("foundation beast source result failed: " + outcome)
		if outcome == "victory" and (int(branch.state.resources.pills.get(
				"筑基丹", 0)) != 1 or int(branch.state.attributes.karmaBad) != 5):
			return _fail("foundation beast victory source pill or karma missing")
		if outcome == "defeat" and (int(branch.state.attributes.daoHeart) \
				!= int(pending_mission.attributes.daoHeart) - 1 \
				or int(branch.state.attributes.health) \
				!= int(pending_mission.attributes.health) - 2):
			return _fail("foundation beast defeat source injury differs: " \
				+ JSON.stringify({"before": pending_mission.attributes,
					"after": branch.state.attributes,
					"maxHealth": branch.state.maxHealth}))
		if outcome == "flee" and int(branch.state.resources.lifespan) \
				!= int(pending_mission.resources.lifespan) - 1:
			return _fail("foundation beast flee source lifespan differs")
	print("NONCOMBAT_FOUNDATION_NORMAL_POOL_PASS pool=true auction=true mentor=true seeds=true treasures=true deck=true love=true")
	quit(0)
