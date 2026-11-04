extends "res://tests/noncombat_camp_runtime.gd"

func _run() -> void:
	var path := "user://tests/regulated_replay_%d.json" % Time.get_ticks_usec()
	var game = Domain.new(Registry.new(), RunSession.new(path, "slot_3"), "slot_3")
	_set_zero_rolls(game)
	if not game.start("sword") or not _reach_bazaar(game) \
			or not game.choose("left", game.issue_choice_token()) \
			or not game.perform_vendor_action("ask_luo", game.issue_choice_token()) \
			or not game.purchase_vendor_offer("bazaar_han_healing", game.issue_choice_token()) \
			or not game.close_vendor(game.issue_choice_token()) \
			or not game.choose("right", game.issue_choice_token()) \
			or not game.resume_flow() \
			or not game.choose("right", game.issue_choice_token()) \
			or not game.resume_flow() \
			or not game.choose("left", game.issue_choice_token()) \
			or not game.choose("left", game.issue_choice_token()) \
			or not game.resume_flow() \
			or not game.choose("right", game.issue_choice_token()) \
			or not game.resume_flow() \
			or not game.choose("left", game.issue_choice_token()):
		return _fail("regulated natural source route could not reach ordinary draw")
	for n in 22:
		if game.state.get("phase") == "SHOP_PENDING":
			break
		if game.state.get("phase") == "FLOW_PENDING":
			if not game.resume_flow():
				return _fail("regulated natural flow halted: " + game.flow_failure_reason())
		else:
			var direction := ""
			for candidate in ["up", "right", "left", "down"]:
				if game.can_choose_direction(candidate):
					direction = candidate
					break
			if direction.is_empty() or not game.choose(direction, game.issue_choice_token()):
				return _fail("regulated natural flow choice halted at %s" % game.state.get("turn"))
	if game.state.get("phase") != "SHOP_PENDING" or game.get_current_card().get(
		"id") != "shop_encounter":
		return _fail("natural run did not reach P25 source card")
	var pending: Dictionary = game.state.duplicate(true)
	var load_pending = Domain.new(Registry.new(), RunSession.new(path, "slot_3"), "slot_3")
	_set_zero_rolls(load_pending)
	if not load_pending.restore() or not _same(load_pending.state, pending):
		return _fail("pending official encounter failed strict restore: %s / %s" % [
			load_pending.flow_failure_reason(), load_pending.state.get("phase", "empty")])
	if not game.choose("right", game.issue_choice_token()):
		return _fail("natural official entry failed")
	var opened: Dictionary = game.state.duplicate(true)
	var load_open = Domain.new(Registry.new(), RunSession.new(path, "slot_3"), "slot_3")
	_set_zero_rolls(load_open)
	if not load_open.restore() or not _same(load_open.state, opened):
		return _fail("open official quote failed strict restore")
	# N9u snapshots predate the ordered purchase/action ledger. Verify an
	# actual archived purchase can still replay and accept a later N9v action.
	var legacy_path := "user://tests/regulated_legacy_%d.json" % Time.get_ticks_usec()
	var legacy_store = RunSession.new(legacy_path, "slot_3")
	if not legacy_store.commit_snapshot(opened, -1).get("ok", false):
		return _fail("legacy regulated fixture could not persist open session")
	var legacy_game = Domain.new(Registry.new(), legacy_store, "slot_3")
	_set_zero_rolls(legacy_game)
	if not legacy_game.restore() or not legacy_game.purchase_vendor_offer(
			"shop_pill_healing", legacy_game.issue_choice_token()):
		return _fail("legacy regulated fixture could not purchase source pill")
	var old_snapshot: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(
		legacy_store.v2_path))
	old_snapshot["state"].erase("regulatedEventHistory")
	old_snapshot["state"].erase("regulatedCausalServiceVersion")
	old_snapshot["state"].erase("regulatedCausalActivationIndex")
	old_snapshot["state"].erase("regulatedCausalGraphSourceSha")
	old_snapshot["state"].erase("causalFactClockVersion")
	old_snapshot["state"].erase("causalFactClockActivationIndex")
	var old_session: Dictionary = old_snapshot["state"]["marketState"]["activeSession"]
	old_session["services"] = old_session.get("services", []).filter(
		func(service: Variant) -> bool:
			return service is Dictionary and service.get("kind") not in [
				"causal_fact_consumer", "causal_fact_closed"])
	# The old snapshot predates both the decision clock and venue service.
	var old_facts: Dictionary = old_snapshot["state"].get("noncombatFlow", {}).get(
		"spineFacts", {})
	for fact_id in old_facts:
		if old_facts[fact_id].get("status") == "closed":
			old_facts[fact_id]["status"] = "active"
			old_facts[fact_id]["closedDecisionIndex"] = null
			old_facts[fact_id]["terminalClosure"] = null
	var legacy_file := FileAccess.open(legacy_store.v2_path, FileAccess.WRITE)
	if legacy_file == null:
		return _fail("legacy regulated fixture could not write historical envelope")
	legacy_file.store_string(JSON.stringify(old_snapshot))
	legacy_file.close()
	var legacy_loaded = Domain.new(Registry.new(), RunSession.new(legacy_path, "slot_3"), "slot_3")
	_set_zero_rolls(legacy_loaded)
	if not legacy_loaded.restore() or legacy_loaded.state.has("regulatedEventHistory") \
			or legacy_loaded.state.has("regulatedCausalServiceVersion") \
			or legacy_loaded.perform_vendor_action("regulated_buyback:灵茶",
				legacy_loaded.issue_choice_token()):
		return _fail("N9u purchase-only snapshot failed legacy restore or inventory guard: %s / %s" % [
			legacy_loaded.flow_failure_reason(), legacy_loaded.state.get("phase", "empty")])
	if not legacy_loaded.purchase_vendor_offer("shop_gift_spirit_tea",
			legacy_loaded.issue_choice_token()) \
			or legacy_loaded.state.get("regulatedEventHistory", []).size() != 2:
		return _fail("N9u snapshot did not upgrade its ordered ledger on next purchase")
	var upgraded = Domain.new(Registry.new(), RunSession.new(legacy_path, "slot_3"), "slot_3")
	_set_zero_rolls(upgraded)
	if not upgraded.restore() or not _same(upgraded.state, legacy_loaded.state):
		return _fail("upgraded N9u official session failed ordered strict restore")
	var ui: Control = load("res://scenes/noncombat_opening.tscn").instantiate()
	ui.save_path = ""
	root.add_child(ui)
	await process_frame
	ui.opening = game
	ui._render()
	var choices: HBoxContainer = ui.get_node("DesktopMargin/ScreenStack/StoryScreen/SourceChoices")
	if ui.art_rect.texture == null or not ui.status_label.text.contains("官坊") \
			or choices.get_node_or_null("VendorBuy_shop_pill_foundation") == null \
			or choices.get_node_or_null("VendorBuy_shop_gift_spirit_tea") == null \
			or choices.get_node("VendorBuy_shop_gift_spirit_tea").disabled \
			or choices.get_node_or_null("VendorBuy_shop_treasure_dyn_玄铁甲") == null \
			or not choices.get_node("VendorBuy_shop_treasure_dyn_玄铁甲").disabled:
		return _fail("official art or frozen full quote missing from desktop")
	if not game.purchase_vendor_offer("shop_gift_spirit_tea", game.issue_choice_token()) \
			or game.state.get("itemInventory", {}).get("灵茶") != 1:
		return _fail("natural official gift did not enter authentic inventory")
	var gifted: Dictionary = game.state.duplicate(true)
	var load_gifted = Domain.new(Registry.new(), RunSession.new(path, "slot_3"), "slot_3")
	_set_zero_rolls(load_gifted)
	if not load_gifted.restore() or not _same(load_gifted.state, gifted):
		return _fail("official gift purchase failed ordered strict replay")
	ui._render()
	var buyback_button: Button = choices.get_node_or_null("VendorAction_regulated_buyback_灵茶")
	if buyback_button == null or buyback_button.disabled \
			or not buyback_button.text.contains("+2 灵石") \
			or not ui.body_label.text.contains("灵茶×1"):
		var names: Array = choices.get_children().map(func(child: Node) -> String:
			return String(child.name))
		return _fail("source buyback and owned gift were not visible in desktop venue: %s / %s" % [
			names, ui.body_label.text.right(100)])
	var buyback_found := false
	for action in game.vendor_actions():
		if action.get("id") == "regulated_buyback:灵茶" and action.get("enabled"):
			buyback_found = true
	if not buyback_found:
		return _fail("owned gift did not expose source buyback action")
	var before_buyback: Dictionary = game.state.duplicate(true)
	var buyback_bytes := FileAccess.get_file_as_string(game._store.v2_path)
	game._store.fail_promotion_once = true
	if game.perform_vendor_action("regulated_buyback:灵茶", game.issue_choice_token()) \
			or not _same(game.state, before_buyback) \
			or FileAccess.get_file_as_string(game._store.v2_path) != buyback_bytes:
		return _fail("failed official buyback changed inventory, state or save bytes")
	if not game.perform_vendor_action("regulated_buyback:灵茶", game.issue_choice_token()) \
			or game.perform_vendor_action("regulated_buyback:灵茶", game.issue_choice_token()) \
			or game.state.get("itemInventory", {}).has("灵茶") \
			or int(game.state["resources"]["spiritStone"]) != int(
			before_buyback["resources"]["spiritStone"]) + 2:
		return _fail("official buyback effect or one-time receipt differs")
	var bought_back: Dictionary = game.state.duplicate(true)
	var load_bought_back = Domain.new(Registry.new(), RunSession.new(path, "slot_3"), "slot_3")
	_set_zero_rolls(load_bought_back)
	if not load_bought_back.restore() or not _same(load_bought_back.state, bought_back):
		return _fail("official buyback failed ordered strict replay")
	var authentic_action_bytes := FileAccess.get_file_as_string(game._store.v2_path)
	var forged_action: Dictionary = JSON.parse_string(authentic_action_bytes)
	forged_action["state"]["regulatedEventHistory"].back()["actionId"] = \
		"regulated_buyback:伪造物"
	var action_file := FileAccess.open(game._store.v2_path, FileAccess.WRITE)
	if action_file == null:
		return _fail("could not prepare forged buyback regression")
	action_file.store_string(JSON.stringify(forged_action))
	action_file.close()
	var reject_action = Domain.new(Registry.new(), RunSession.new(path, "slot_3"), "slot_3")
	_set_zero_rolls(reject_action)
	if reject_action.restore():
		return _fail("forged buyback action was accepted by strict restore")
	var restore_action_file := FileAccess.open(game._store.v2_path, FileAccess.WRITE)
	if restore_action_file == null:
		return _fail("could not restore authentic buyback test file")
	restore_action_file.store_string(authentic_action_bytes)
	restore_action_file.close()
	var before_purchase: Dictionary = game.state.duplicate(true)
	var before_bytes := FileAccess.get_file_as_string(game._store.v2_path)
	game._store.fail_promotion_once = true
	if game.purchase_vendor_offer("shop_pill_healing", game.issue_choice_token()) \
			or not _same(game.state, before_purchase) \
			or FileAccess.get_file_as_string(game._store.v2_path) != before_bytes:
		return _fail("failed official purchase changed state or save bytes")
	if not game.purchase_vendor_offer("shop_pill_healing", game.issue_choice_token()) \
			or game.purchase_vendor_offer("shop_pill_healing", game.issue_choice_token()) \
			or int(game.state["resources"]["spiritStone"]) != int(
			before_purchase["resources"]["spiritStone"]) - 2:
		return _fail("source healing pill purchase or duplicate rejection differs")
	var bought: Dictionary = game.state.duplicate(true)
	var load_bought = Domain.new(Registry.new(), RunSession.new(path, "slot_3"), "slot_3")
	_set_zero_rolls(load_bought)
	if not load_bought.restore() or not _same(load_bought.state, bought):
		return _fail("purchased official quote failed strict restore")
	var original_bytes := FileAccess.get_file_as_string(game._store.v2_path)
	var forged: Dictionary = JSON.parse_string(original_bytes)
	forged["state"]["normalFlow"]["shopEntries"].back()["quote"][1]["price"] = 999
	var forged_file := FileAccess.open(game._store.v2_path, FileAccess.WRITE)
	if forged_file == null:
		return _fail("could not prepare forged official quote regression")
	forged_file.store_string(JSON.stringify(forged))
	forged_file.close()
	var forged_bytes := FileAccess.get_file_as_string(game._store.v2_path)
	var reject_forged = Domain.new(Registry.new(), RunSession.new(path, "slot_3"), "slot_3")
	_set_zero_rolls(reject_forged)
	if reject_forged.restore() or FileAccess.get_file_as_string(game._store.v2_path) != forged_bytes:
		return _fail("forged official quote restored or mutated the save")
	var original_file := FileAccess.open(game._store.v2_path, FileAccess.WRITE)
	if original_file == null:
		return _fail("could not restore authentic official quote test file")
	original_file.store_string(original_bytes)
	original_file.close()
	if not game.close_vendor(game.issue_choice_token()):
		return _fail("natural official session could not close")
	var result: Dictionary = game.state.duplicate(true)
	var load_result = Domain.new(Registry.new(), RunSession.new(path, "slot_3"), "slot_3")
	_set_zero_rolls(load_result)
	if not load_result.restore() or not _same(load_result.state, result):
		return _fail("official result failed strict restore")
	print("NONCOMBAT_REGULATED_REPLAY_PASS natural=true bazaar_purchase=true pending=true open=true gift=true buyback=true purchase=true result=true ui=true")
	quit(0)
