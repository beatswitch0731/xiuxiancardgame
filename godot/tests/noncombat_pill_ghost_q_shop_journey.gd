extends "res://tests/noncombat_market_arrival.gd"

func _run() -> void:
	var path := "user://tests/pill_ghost_shop_%d.json" % Time.get_ticks_usec()
	var game = Domain.new(Registry.new(), RunSession.new(path, "slot_3"), "slot_3")
	_stabilize_ambient(game)
	game._normal_roll_override = 0.55
	# This trace predates StoryThread migration; a separate source fixture covers it.
	game._story_thread_flow.activation_index = 1000
	game._surfacing_activation_index = 1000
	game._echo_activation_index = 1000
	if not game.start("pill"):
		return _fail("pill opening did not start")
	var route := [
		["tutorial_1", "left"], ["tutorial_2", "left"],
		["tutorial_3", "left"], ["tutorial_4", "left"],
		["q_start_pill", "left"], ["COMBAT_HANDOFF", "right"],
		["promise_result_799e44eb", "left"], ["ch_qi_20", "left"],
		["ch_qi_40", "right"], ["q_whiteFox_quest", "left"],
		["ch_qi_60", "left"],
	]
	for step in route:
		if game.state.get("phase") == "FLOW_PENDING" and not game.resume_flow():
			return _fail("pill route stopped before ghost market: " +
				game.flow_failure_reason())
		var id := String(game.state.get("phase")) if step[0] == \
			"COMBAT_HANDOFF" else String(game.get_current_card().get("id", ""))
		if id != step[0] or not game.choose(step[1], game.issue_choice_token()):
			return _fail("pill route diverged at %s -> %s" % [str(step), id])
	if game.state.get("phase") == "FLOW_PENDING" and not game.resume_flow():
		return _fail("pill route stopped after chapter choice: " +
			game.flow_failure_reason())
	if game.get_current_card().get("id") != "mentor_bai_ren_stage_INNER_DISCIPLE" \
			or not game.choose("left", game.issue_choice_token()):
		return _fail("pill route did not settle mentor event")
	if game.state.get("phase") == "FLOW_PENDING" and not game.resume_flow():
		return _fail("pill route stopped after mentor event: " +
			game.flow_failure_reason())
	if game.get_current_card().get("id") != "promise_result_3b3a1690" \
			or not game.choose("left", game.issue_choice_token()):
		return _fail("pill route did not settle authored promise result")
	if game.state.get("phase") == "FLOW_PENDING" and not game.resume_flow():
		return _fail("pill route stopped after promise result: " +
			game.flow_failure_reason())
	if game.get_current_card().get("id") != "bazaar_encounter" \
			or not game.choose("right", game.issue_choice_token()):
		return _fail("pill route did not leave source bazaar")
	if game.state.get("phase") == "FLOW_PENDING" and not game.resume_flow():
		return _fail("pill route stopped after bazaar: " +
			game.flow_failure_reason())
	if game.get_current_card().get("id") != "market_encounter" \
			or not game.choose("left", game.issue_choice_token()):
		return _fail("pill route did not enter source ghost market")
	if not game.purchase_vendor_offer("灵泉葫芦", game.issue_choice_token()) \
			or not game.resolve_vendor_loadout("stash", game.issue_choice_token()) \
			or not game.close_vendor(game.issue_choice_token()):
		return _fail("natural pill ghost purchase or close failed")
	if game.state.get("phase") == "FLOW_PENDING" and not game.resume_flow():
		return _fail("pill route stopped after ghost purchase: " +
			game.flow_failure_reason())
	if game.get_current_card().get("id") != "destiny_wheel" \
			or not game.choose("left", game.issue_choice_token()):
		return _fail("pill route did not settle source destiny wheel")
	if game.state.get("phase") == "FLOW_PENDING" and not game.resume_flow():
		return _fail("pill route stopped after destiny wheel: " +
			game.flow_failure_reason())
	if not String(game.get_current_card().get("id", "")).begins_with(
			"vendor_result:") or not game.choose("right", game.issue_choice_token()):
		return _fail("pill route did not settle ghost vendor result: %s %s" % [
			game.get_current_card().get("id"), game.state.get("phase")])
	if game.state.get("phase") == "FLOW_PENDING" and not game.resume_flow():
		return _fail("pill route stopped after ghost vendor result: " +
			game.flow_failure_reason())
	if game.get_current_card().get("id") != "ch_qi_80" \
			or not game.choose("right", game.issue_choice_token()):
		return _fail("pill route did not settle fourth chapter card")
	if game.state.get("phase") == "FLOW_PENDING" and not game.resume_flow():
		return _fail("pill route stopped after fourth chapter card: " +
			game.flow_failure_reason())
	if game.get_current_card().get("id") != "em_heaven_gaze" \
			or not game.choose("right", game.issue_choice_token()):
		return _fail("pill route did not settle source emergent card")
	if game.state.get("phase") == "FLOW_PENDING" and not game.resume_flow():
		return _fail("pill route stopped after emergent card: " +
			game.flow_failure_reason())
	if not String(game.get_current_card().get("id", "")).begins_with(
			"ghost_debt_due:") or not game.choose("left", game.issue_choice_token()):
		return _fail("pill route did not settle ordinary ghost debt")
	if game.state.get("phase") == "FLOW_PENDING" and not game.resume_flow():
		return _fail("pill route stopped after ghost debt: " +
			game.flow_failure_reason())
	if game.get_current_card().get("id") != "bazaar_encounter" \
			or not game.choose("right", game.issue_choice_token()):
		return _fail("pill route did not leave second source bazaar")
	if game.state.get("phase") == "FLOW_PENDING" and not game.resume_flow():
		return _fail("pill route stopped after second bazaar: " +
			game.flow_failure_reason())
	if game.state.get("phase") != "HINT_PENDING" \
			or not game.choose("left" if game.can_choose_direction("left") \
			else "right", game.issue_choice_token()):
		return _fail("pill route did not settle natural heavens hint")
	if game.state.get("phase") == "FLOW_PENDING" and not game.resume_flow():
		return _fail("pill route stopped after heavens hint: " +
			game.flow_failure_reason())
	if game.get_current_card().get("id") != "q_fortune" \
			or not game.choose("right", game.issue_choice_token()):
		return _fail("pill route did not settle first ordinary draw: " +
			String(game.get_current_card().get("id")))
	if game.state.get("phase") == "FLOW_PENDING" and not game.resume_flow():
		return _fail("pill route stopped after ordinary draw: " +
			game.flow_failure_reason())
	if game.get_current_card().get("id") != "q_inherit" \
			or not game.choose("right", game.issue_choice_token()):
		return _fail("pill route did not settle inheritance card")
	if game.state.get("phase") == "FLOW_PENDING" and not game.resume_flow():
		return _fail("pill route stopped after inheritance card: " +
			game.flow_failure_reason())
	var recipe_card: Dictionary = game.get_current_card()
	if recipe_card.get("id") != "q_pillRecipe" \
			or recipe_card.get("sceneImage") != \
			"assets/cards/events/scene_qi_q_pillRecipe.png" \
			or not game.can_choose_direction("left") \
			or not game.can_choose_direction("right"):
		return _fail("natural pill recipe lacked source art or both choices: %s fortune=%s stone=%s available=%s" % [
			recipe_card.get("id"), game.state["attributes"].get("fortune"),
			game.state["resources"].get("spiritStone"),
			[game.can_choose_direction("left"), game.can_choose_direction("right")]])
	var recipe_ui: Control = load("res://scenes/noncombat_opening.tscn").instantiate()
	recipe_ui.save_path = ""
	root.add_child(recipe_ui)
	await process_frame
	recipe_ui.opening = game
	recipe_ui._render()
	var recipe_row: Control = recipe_ui.get_node(
		"DesktopMargin/ScreenStack/StoryScreen/SourceChoices")
	if recipe_ui.art_rect.texture == null \
			or recipe_row.get_node_or_null("Choice_left") == null \
			or recipe_row.get_node_or_null("Choice_right") == null \
			or recipe_row.get_node("Choice_left").disabled \
			or recipe_row.get_node("Choice_right").disabled:
		return _fail("desktop natural pill recipe art or choices were not rendered")
	root.remove_child(recipe_ui)
	recipe_ui.queue_free()
	var recipe_pending: Dictionary = game.state.duplicate(true)
	var capped: Dictionary = recipe_pending.duplicate(true)
	capped["attributes"]["fortune"] = 100
	if game._normal_choice_policy.choice_available(capped, recipe_card, "right"):
		return _fail("capped recipe fortune wrongly allows poison when purchase is affordable")
	var unaffordable: Dictionary = capped.duplicate(true)
	unaffordable["resources"]["spiritStone"] = 0
	if game._normal_choice_policy.choice_available(unaffordable, recipe_card,
			"left") or not game._normal_choice_policy.choice_available(
				unaffordable, recipe_card, "right"):
		return _fail("capped recipe did not leave the unaffordable fallback choice")
	var recipe_reload = Domain.new(Registry.new(), RunSession.new(path, "slot_3"),
		"slot_3")
	_stabilize_ambient(recipe_reload)
	if not recipe_reload.restore() or not _same(recipe_reload.state, recipe_pending):
		return _fail("pending natural pill recipe did not strictly restore")
	var left_path := "user://tests/pill_recipe_left_%d.json" % Time.get_ticks_usec()
	var left_store = RunSession.new(left_path, "slot_3")
	if left_store.commit_snapshot(recipe_pending, -1).get("ok") != true:
		return _fail("natural pill recipe left checkpoint could not save")
	var left = Domain.new(Registry.new(), left_store, "slot_3")
	_stabilize_ambient(left)
	if not left.restore():
		return _fail("natural pill recipe left checkpoint could not restore")
	var left_bytes := FileAccess.get_file_as_string(left_store.v2_path)
	left_store.fail_promotion_once = true
	if left.choose("left", left.issue_choice_token()) \
			or not _same(left.state, recipe_pending) \
			or FileAccess.get_file_as_string(left_store.v2_path) != left_bytes:
		return _fail("failed pill recipe purchase changed save or memory")
	if not left.choose("left", left.issue_choice_token()) \
			or left.state["resources"]["spiritStone"] != \
			int(recipe_pending["resources"]["spiritStone"]) - 10 \
			or left.state["resources"]["pills"].get("foundation") != 1 \
			or left.state["attributes"]["cultivation"] != mini(100,
				int(recipe_pending["attributes"]["cultivation"]) + 15):
		return _fail("source pill recipe purchase lost fee, cultivation or foundation pill")
	var left_reload = Domain.new(Registry.new(), RunSession.new(left_path,
		"slot_3"), "slot_3")
	_stabilize_ambient(left_reload)
	if not left_reload.restore() or not _same(left_reload.state, left.state):
		return _fail("purchased foundation pill did not strictly restore")
	if not game.choose("right", game.issue_choice_token()):
		return _fail("natural pill recipe did not settle its causal choice")
	var poison: Dictionary = {}
	for seed in game.state.get("karmaSeeds", []):
		if seed.get("id") == "pillPoison":
			poison = seed
	if poison.get("originCard") != "q_pillRecipe" \
			or poison.get("originChoice") != "right" \
			or poison.get("realm") != "golden" \
			or poison.get("delay") != 11 \
			or game.state["resources"]["spiritStone"] != \
			recipe_pending["resources"]["spiritStone"]:
		return _fail("recipe discard did not retain authored golden-realm poison promise")
	var repeat = Domain.new(Registry.new(), null, "slot_3")
	_stabilize_ambient(repeat)
	if not repeat.start("pill"):
		return _fail("repeat recipe fixture could not start")
	var repeat_pending: Dictionary = recipe_pending.duplicate(true)
	var older_seed: Dictionary = poison.duplicate(true)
	older_seed["delay"] = 3
	repeat_pending["karmaSeeds"].append(older_seed)
	repeat.state = repeat_pending
	if not repeat.can_choose_direction("right") \
			or not repeat.choose("right", repeat.issue_choice_token()):
		return _fail("repeated recipe could not merge its existing poison seed")
	var poison_count := 0
	for seed in repeat.state.get("karmaSeeds", []):
		if seed.get("id") == "pillPoison":
			poison_count += 1
			if seed.get("delay") != 2:
				return _fail("repeated recipe reset the existing poison timer")
	if poison_count != 1:
		return _fail("repeated recipe duplicated the poison seed")
	var right_reload = Domain.new(Registry.new(), RunSession.new(path, "slot_3"),
		"slot_3")
	_stabilize_ambient(right_reload)
	if not right_reload.restore() or not _same(right_reload.state, game.state):
		return _fail("discarded pill recipe did not strictly restore")
	if game.state.get("phase") == "FLOW_PENDING" and not game.resume_flow():
		return _fail("pill route stopped after recipe: " +
			game.flow_failure_reason())
	var shop_card: Dictionary = game.get_current_card()
	var shop_before: Dictionary = game.state.duplicate(true)
	var stone_before := int(shop_before["resources"]["spiritStone"])
	var deck_before: Array = shop_before["deck"].duplicate(true)
	if shop_card.get("id") != "q_shop" \
			or shop_card.get("sceneImage") != "assets/cards/events/scene_qi_q_shop.png" \
			or stone_before < 21 or not game.can_choose_direction("up"):
		return _fail("natural pill route did not reach affordable source q_shop")
	var shop_reload = Domain.new(Registry.new(), RunSession.new(path, "slot_3"),
		"slot_3")
	_stabilize_ambient(shop_reload)
	if not shop_reload.restore() or not _same(shop_reload.state, shop_before):
		return _fail("affordable natural q_shop did not strictly restore")
	if not game.choose("up", game.issue_choice_token()) \
			or game.state.get("phase") != "CAMP_TARGET_PENDING" \
			or game.state["resources"]["spiritStone"] != stone_before - 15:
		return _fail("natural q_shop removal did not charge the authored entry fee")
	var target_pending: Dictionary = game.state.duplicate(true)
	var target_reload = Domain.new(Registry.new(), RunSession.new(path, "slot_3"),
		"slot_3")
	_stabilize_ambient(target_reload)
	if not target_reload.restore() or not _same(target_reload.state,
			target_pending):
		return _fail("natural q_shop target decision did not strictly restore")
	var target_index := -1
	var target_id := ""
	var options: Array = game.camp_targets()
	for i in options.size():
		if options[i].get("allowed", false):
			target_index = i
			target_id = String(options[i].get("cardId", ""))
			break
	if target_index < 0 or target_id.is_empty():
		return _fail("natural q_shop had no affordable removable deck card")
	var ui: Control = load("res://scenes/noncombat_opening.tscn").instantiate()
	ui.save_path = ""
	root.add_child(ui)
	await process_frame
	ui.opening = game
	ui._render()
	var choice_row: Control = ui.get_node(
		"DesktopMargin/ScreenStack/StoryScreen/SourceChoices")
	if ui.art_rect.texture == null or choice_row.get_node_or_null(
			"CampTargets/CampTarget_%d" % target_index) == null:
		return _fail("desktop natural q_shop target option was not rendered")
	if not game.resolve_camp_target(target_index, target_id,
			game.issue_choice_token()) \
			or game.state["resources"]["spiritStone"] != stone_before - 21 \
			or game.state["deck"].size() != deck_before.size() - 1 \
			or game.state.get("campTargetHistory", []).back().get(
				"sourceCardId") != "q_shop":
		return _fail("natural q_shop did not pay second fee and remove one card")
	var done = Domain.new(Registry.new(), RunSession.new(path, "slot_3"), "slot_3")
	_stabilize_ambient(done)
	if not done.restore() or not _same(done.state, game.state):
		return _fail("completed natural q_shop removal did not strictly restore")
	if game.state.get("phase") != "FLOW_PENDING" or game.state.get(
			"pendingMarketCard", {}).get("id") != "bazaar_encounter":
		return _fail("natural shop removal lost the scheduled bazaar")
	if not game.resume_flow() or game.get_current_card().get("id") != \
			"bazaar_encounter":
		return _fail("natural shop route did not serve the scheduled bazaar: " +
			game.flow_failure_reason())
	var bazaar_pending: Dictionary = game.state.duplicate(true)
	var bazaar_reload = Domain.new(Registry.new(), RunSession.new(path,
		"slot_3"), "slot_3")
	_stabilize_ambient(bazaar_reload)
	if not bazaar_reload.restore() or not _same(bazaar_reload.state,
			bazaar_pending):
		return _fail("post-shop bazaar pending state did not strictly restore")
	if not game.choose("right", game.issue_choice_token()):
		return _fail("post-shop bazaar could not settle its source right choice")
	var bazaar_left: Dictionary = game.state.duplicate(true)
	var left_bazaar_reload = Domain.new(Registry.new(), RunSession.new(path,
		"slot_3"), "slot_3")
	_stabilize_ambient(left_bazaar_reload)
	if not left_bazaar_reload.restore() or not _same(left_bazaar_reload.state,
			bazaar_left):
		return _fail("post-shop bazaar leave did not strictly restore")
	if game.state.get("phase") == "FLOW_PENDING" and not game.resume_flow():
		return _fail("pill route stopped after post-shop bazaar: " +
			game.flow_failure_reason())
	if game.get_current_card().get("id") != "q_spiritStone" \
			or game.get_current_card().get("sceneImage") != \
			"assets/cards/events/scene_event_qi_spirit_mine.png":
		return _fail("natural post-bazaar draw lost source spirit mine")
	var mine_pending: Dictionary = game.state.duplicate(true)
	var mine_reload = Domain.new(Registry.new(), RunSession.new(path, "slot_3"),
		"slot_3")
	_stabilize_ambient(mine_reload)
	if not mine_reload.restore() or not _same(mine_reload.state, mine_pending):
		return _fail("natural spirit mine pending did not strictly restore")
	if not game.choose("right", game.issue_choice_token()):
		return _fail("natural spirit mine could not settle source donation")
	var mine_done: Dictionary = game.state.duplicate(true)
	var mine_done_reload = Domain.new(Registry.new(), RunSession.new(path,
		"slot_3"), "slot_3")
	_stabilize_ambient(mine_done_reload)
	if not mine_done_reload.restore() or not _same(mine_done_reload.state,
			mine_done):
		return _fail("natural spirit mine donation did not strictly restore")
	if game.state.get("phase") == "FLOW_PENDING" and not game.resume_flow():
		return _fail("pill route stopped after spirit mine: " +
			game.flow_failure_reason())
	if game.get_current_card().get("id") != "karma_spell_awakening" \
			or game.get_current_card().get("sceneImage") != \
			"assets/cards/events/scene_qi_q_spellTome.png":
		return _fail("natural post-mine draw differs from source karma card")
	var karma_pending: Dictionary = game.state.duplicate(true)
	var karma_reload = Domain.new(Registry.new(), RunSession.new(path, "slot_3"),
		"slot_3")
	_stabilize_ambient(karma_reload)
	if not karma_reload.restore() or not _same(karma_reload.state,
			karma_pending):
		return _fail("natural karma card pending did not strictly restore")
	if not game.choose("right", game.issue_choice_token()):
		return _fail("natural karma card could not settle source talisman choice")
	var karma_done: Dictionary = game.state.duplicate(true)
	var karma_done_reload = Domain.new(Registry.new(), RunSession.new(path,
		"slot_3"), "slot_3")
	_stabilize_ambient(karma_done_reload)
	if not karma_done_reload.restore() or not _same(karma_done_reload.state,
			karma_done):
		return _fail("natural karma card choice did not strictly restore")
	if game.state.get("phase") == "FLOW_PENDING" and not game.resume_flow():
		return _fail("pill route stopped after source karma card: " +
			game.flow_failure_reason())
	if game.get_current_card().get("id") != "q_love" \
			or game.get_current_card().get("sceneImage") != \
			"assets/cards/events/scene_event_qi_love.png" \
			or game.can_choose_direction("left") \
			or not game.can_choose_direction("right"):
		return _fail("natural love card did not admit its source companion choice")
	ui._render()
	var love_row: HBoxContainer = ui.get_node(
		"DesktopMargin/ScreenStack/StoryScreen/SourceChoices")
	var love_left: Button = love_row.get_node_or_null("Choice_left")
	var love_right: Button = love_row.get_node_or_null("Choice_right")
	if ui.art_rect.texture == null or love_left == null \
			or not love_left.disabled or love_right == null \
			or love_right.disabled:
		return _fail("desktop source love art or capped choice gate differs")
	var love_pending: Dictionary = game.state.duplicate(true)
	var love_reload = Domain.new(Registry.new(), RunSession.new(path, "slot_3"),
		"slot_3")
	_stabilize_ambient(love_reload)
	if not love_reload.restore() or not _same(love_reload.state,
			love_pending):
		return _fail("natural love pending did not strictly restore")
	var love_bytes := FileAccess.get_file_as_string(game._store.v2_path)
	game._store.fail_promotion_once = true
	if game.choose("right", game.issue_choice_token()) \
			or not _same(game.state, love_pending) \
			or FileAccess.get_file_as_string(game._store.v2_path) != love_bytes:
		return _fail("failed love choice changed memory or save bytes")
	if not game.choose("right", game.issue_choice_token()) \
			or game.state["resources"]["companions"] != ["mortal"] \
			or game.state["attributes"]["daoHeart"] != \
			int(love_pending["attributes"]["daoHeart"]) - 2 \
			or game.state["attributes"]["cultivation"] != \
			int(love_pending["attributes"]["cultivation"]) - 5 \
			or game.state["resources"]["lifespan"] != \
			int(love_pending["resources"]["lifespan"]) - 1:
		return _fail("natural love companion or negative effects differ")
	var love_done = Domain.new(Registry.new(), RunSession.new(path, "slot_3"),
		"slot_3")
	_stabilize_ambient(love_done)
	if not love_done.restore() or not _same(love_done.state, game.state):
		return _fail("natural love choice did not strictly restore")
	if game.state.get("phase") == "FLOW_PENDING" and not game.resume_flow():
		return _fail("pill route stopped before body karma: " +
			game.flow_failure_reason())
	var body_card: Dictionary = game.get_current_card()
	if body_card.get("id") != "karma_body_awakening" \
			or body_card.get("sceneImage") != \
			"assets/cards/events/scene_qi_q_bodyTrial.png" \
			or not game.can_choose_direction("left") \
			or not game.can_choose_direction("right"):
		return _fail("natural body karma source art or two choices unavailable")
	ui._render()
	var body_row: HBoxContainer = ui.get_node(
		"DesktopMargin/ScreenStack/StoryScreen/SourceChoices")
	var body_left_button: Button = body_row.get_node_or_null("Choice_left")
	var body_right_button: Button = body_row.get_node_or_null("Choice_right")
	if ui.art_rect.texture == null or body_left_button == null \
			or body_left_button.disabled or body_right_button == null \
			or body_right_button.disabled:
		return _fail("desktop body karma art or source options unavailable")
	var body_pending: Dictionary = game.state.duplicate(true)
	var body_reload = Domain.new(Registry.new(), RunSession.new(path, "slot_3"),
		"slot_3")
	_stabilize_ambient(body_reload)
	if not body_reload.restore() or not _same(body_reload.state, body_pending):
		return _fail("natural body karma pending did not strictly restore")
	var body_left_path := "user://tests/pill_body_left_%d.json" % Time.get_ticks_usec()
	var body_left_store = RunSession.new(body_left_path, "slot_3")
	if body_left_store.commit_snapshot(body_pending, -1).get("ok") != true:
		return _fail("body karma left checkpoint could not save")
	var body_left_game = Domain.new(Registry.new(), body_left_store, "slot_3")
	_stabilize_ambient(body_left_game)
	if not body_left_game.restore() or not body_left_game.choose(
			"left", body_left_game.issue_choice_token()):
		return _fail("natural body karma max-health choice could not settle")
	var expected_body_health := mini(
		int(body_pending["maxHealth"]) + 2,
		int(body_pending["attributes"]["health"]) + 4)
	if body_left_game.state["maxHealth"] != int(body_pending["maxHealth"]) + 2 \
			or body_left_game.state["attributes"]["health"] != expected_body_health \
			or body_left_game.state["attributes"]["cultivation"] != mini(100,
				int(body_pending["attributes"]["cultivation"]) + 20) \
			or body_left_game.state["deck"] != body_pending["deck"]:
		return _fail("natural body karma max-health reward diverged")
	var body_left_reload = Domain.new(Registry.new(), RunSession.new(
		body_left_path, "slot_3"), "slot_3")
	_stabilize_ambient(body_left_reload)
	if not body_left_reload.restore() or not _same(body_left_reload.state,
			body_left_game.state):
		return _fail("natural body karma max-health choice did not strictly restore")
	var body_bytes := FileAccess.get_file_as_string(game._store.v2_path)
	game._store.fail_promotion_once = true
	if game.choose("right", game.issue_choice_token()) \
			or not _same(game.state, body_pending) \
			or FileAccess.get_file_as_string(game._store.v2_path) != body_bytes:
		return _fail("failed body karma choice changed memory or save bytes")
	if not game.choose("right", game.issue_choice_token()) \
			or game.state["attributes"]["cultivation"] != mini(100,
				int(body_pending["attributes"]["cultivation"]) + 15) \
			or game.state["deck"] != body_pending["deck"] \
			or game.state.get("skillAcquisitions", {}).has("iron_skin"):
		return _fail("natural pill path granted an off-path body card")
	var body_right_reload = Domain.new(Registry.new(), RunSession.new(path,
		"slot_3"), "slot_3")
	_stabilize_ambient(body_right_reload)
	if not body_right_reload.restore() or not _same(body_right_reload.state,
			game.state):
		return _fail("natural body karma right choice did not strictly restore")
	var second_hint_route := [
		["q_fortune", "right"], ["market_encounter", "right"],
		["destiny_wheel", "left"], ["q_pillRecipe", "left"],
	]
	for step in second_hint_route:
		if game.state.get("phase") == "FLOW_PENDING" and not game.resume_flow():
			return _fail("natural route stopped before second hint: " +
				game.flow_failure_reason())
		if game.get_current_card().get("id") != step[0] \
				or not game.choose(step[1], game.issue_choice_token()):
			return _fail("natural second-hint route diverged at %s -> %s" % [
				str(step), game.get_current_card().get("id")])
	if game.state.get("phase") != "FLOW_PENDING" or not game.resume_flow():
		return _fail("natural second hint could not be issued: " +
			game.flow_failure_reason())
	var second_hint: Dictionary = game.get_current_card()
	var hint_state: Dictionary = game.state.get("heavensHintState", {})
	if game.state.get("phase") != "HINT_PENDING" \
			or second_hint.get("id") != "heavens_hint:slot_3:life:0:32:1" \
			or hint_state.get("hintsRevealed", []).size() != 2 \
			or hint_state.get("issuedHints", []).size() != 2 \
			or not game._hint_flow._valid(game.state):
		return _fail("natural persisted hint index was duplicated after reload")
	var hint_pending: Dictionary = game.state.duplicate(true)
	var hint_reload = Domain.new(Registry.new(), RunSession.new(path, "slot_3"),
		"slot_3")
	_stabilize_ambient(hint_reload)
	if not hint_reload.restore() or not _same(hint_reload.state, hint_pending):
		return _fail("natural second hint pending state did not strictly restore")
	var hint_direction := "left" if game.can_choose_direction("left") else "right"
	var hint_bytes := FileAccess.get_file_as_string(game._store.v2_path)
	game._store.fail_promotion_once = true
	if game.choose(hint_direction, game.issue_choice_token()) \
			or not _same(game.state, hint_pending) \
			or FileAccess.get_file_as_string(game._store.v2_path) != hint_bytes \
			or not game.choose(hint_direction, game.issue_choice_token()):
		return _fail("natural second hint choice did not roll back then settle")
	var hint_done = Domain.new(Registry.new(), RunSession.new(path, "slot_3"),
		"slot_3")
	_stabilize_ambient(hint_done)
	if not hint_done.restore() or not _same(hint_done.state, game.state):
		return _fail("natural second hint choice did not strictly restore")
	print("NONCOMBAT_PILL_GHOST_Q_SHOP_JOURNEY_PASS ghost=true recipe=true debt=true shop=true love=true body=true second_hint=true replay=true decision=%d stone_before=%d" % [
		int(shop_before["runClock"]["decisionIndex"]), stone_before])
	quit(0)
