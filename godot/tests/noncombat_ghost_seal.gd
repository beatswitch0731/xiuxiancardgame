extends "res://tests/noncombat_market_arrival.gd"

func _run() -> void:
	var path := "user://tests/ghost_seal_%d.json" % Time.get_ticks_usec()
	var game = Domain.new(Registry.new(), RunSession.new(path, "slot_3"), "slot_3")
	_stabilize_ambient(game)
	game._normal_roll_override = 0.0
	if not game.start("spell"):
		return _fail("spell route did not start")
	var route := [
		["tutorial_1", "left"], ["tutorial_2", "left"],
		["tutorial_3", "left"], ["tutorial_4", "left"],
		["q_start_spell", "left"], ["COMBAT_HANDOFF", "right"],
		["promise_result_0105e2c0", "left"], ["ch_qi_20", "right"],
		["ch_qi_40", "right"], ["q_whiteFox_quest", "right"],
		["q_whiteFox_2", "right"], ["q_whiteFox_3", "right"]]
	for step in route:
		if game.state.get("phase") == "FLOW_PENDING" and not game.resume_flow():
			return _fail("spell route stopped before public bazaar")
		var id := String(game.state.get("phase")) if step[0] == "COMBAT_HANDOFF" \
			else String(game.get_current_card().get("id", ""))
		if id != step[0] or not game.choose(step[1], game.issue_choice_token()):
			return _fail("spell route diverged at %s -> %s" % [str(step), id])
	if not game.resume_flow() or game.get_current_card().get("id") != \
			"bazaar_encounter" or not game.choose("left", game.issue_choice_token()) \
			or not game.purchase_vendor_offer("bazaar_luo_route_note",
				game.issue_choice_token()) or not game.close_vendor(game.issue_choice_token()):
		return _fail("source public bazaar did not provide a route note")
	if int(game.state.get("itemInventory", {}).get("商路线索", 0)) != 1:
		return _fail("route note was not owned after public bazaar purchase")
	var reached_ghost := false
	for n in 8:
		if game.state.get("phase") == "FLOW_PENDING" and not game.resume_flow():
			return _fail("route stopped before ghost market")
		var card_id := String(game.get_current_card().get("id", ""))
		if card_id == "market_encounter":
			reached_ghost = true
			break
		var direction := "right" if game.can_choose_direction("right") else "left"
		if card_id == "q_gathering":
			direction = "right"
		if not game.choose(direction, game.issue_choice_token()):
			return _fail("route note path could not pass %s / %s" % [
				game.state.get("phase"), card_id])
	if not reached_ghost or not game.choose("left", game.issue_choice_token()):
		return _fail("source route note path did not enter ghost vendor")
	var session: Dictionary = game.state.get("marketState", {}).get(
		"activeSession", {})
	var sealed_id := ""
	for offer in session.get("immutableOffers", []):
		if offer.get("hiddenTrait") is Dictionary and offer["hiddenTrait"].get(
				"status") == "sealed":
			sealed_id = String(offer["id"])
			break
	if sealed_id.is_empty():
		return _fail("source ghost stock lacked a sealed offer")
	var action_id := "ghost_inspect_seal:" + sealed_id
	var revealed_text := ""
	for offer in session.get("immutableOffers", []):
		if offer.get("id") == sealed_id:
			revealed_text = String(offer["hiddenTrait"]["revealedText"])
	var available := false
	for action in game.vendor_actions():
		if action.get("id") == action_id:
			available = action.get("enabled", false)
	if not available:
		return _fail("route note owner cannot inspect a source sealed offer")
	var opened: Dictionary = game.state.duplicate(true)
	var open_bytes := FileAccess.get_file_as_string(game._store.v2_path)
	var generic_id := ""
	for offer in opened["marketState"]["activeSession"]["immutableOffers"]:
		if offer.get("id") != "ghost_oath_rusted_sword" \
				and offer.get("id") != sealed_id \
				and offer.get("_marketItem") == true:
			generic_id = String(offer["id"])
			break
	if generic_id.is_empty():
		return _fail("source ghost stock lacked a nonsealed ordinary treasure")
	var generic_path := "user://tests/ghost_generic_then_seal_%d.json" % Time.get_ticks_usec()
	var generic_store = RunSession.new(generic_path, "slot_3")
	if generic_store.commit_snapshot(opened, -1).get("ok") != true:
		return _fail("generic-before-seal checkpoint could not save")
	var generic = Domain.new(Registry.new(), generic_store, "slot_3")
	_stabilize_ambient(generic)
	if not generic.restore() or not generic.purchase_vendor_offer(
			generic_id, generic.issue_choice_token()) \
			or not generic.resolve_vendor_loadout("stash", generic.issue_choice_token()) \
			or not generic.perform_vendor_action(action_id,
				generic.issue_choice_token()):
		return _fail("ordinary goods then source seal could not transact")
	var generic_done: Dictionary = generic.state.duplicate(true)
	var generic_events: Array = generic_done.get("ghostVendorEventHistory", [])
	if generic_events.size() != 3 or generic_events[0].get("kind") != "purchase" \
			or generic_events[1].get("kind") != "loadout" \
			or generic_events[2].get("kind") != "action":
		return _fail("ordinary goods then seal event order was not recorded")
	var generic_reload = Domain.new(Registry.new(), RunSession.new(
		generic_path, "slot_3"), "slot_3")
	_stabilize_ambient(generic_reload)
	if not generic_reload.restore() or not _same(generic_reload.state,
			generic_done):
		return _fail("ordinary goods then seal did not strictly replay")
	var no_note: Dictionary = opened.duplicate(true)
	no_note["itemInventory"]["商路线索"] = 0
	if game._ghost_vendor_flow.available_actions(no_note).any(
			func(row: Variant) -> bool:
				return row.get("id") == action_id and row.get("enabled", false)) \
			or not game._ghost_vendor_flow.inspect_seal(no_note, action_id).is_empty():
		return _fail("seal inspection ignored missing route-note inventory")
	var ui: Control = load("res://scenes/noncombat_opening.tscn").instantiate()
	ui.save_path = ""
	root.add_child(ui)
	await process_frame
	ui.opening = game
	ui._render()
	var buttons: HBoxContainer = ui.get_node(
		"DesktopMargin/ScreenStack/StoryScreen/SourceChoices")
	var action_button: Button = buttons.get_node_or_null(
		"VendorAction_" + action_id.replace(":", "_"))
	if action_button == null or action_button.disabled \
			or not action_button.text.contains("商路线索") \
			or ui.body_label.text.contains(revealed_text):
		return _fail("desktop seal button or hidden-text state is wrong")
	var token: int = game.issue_choice_token()
	game._store.fail_promotion_once = true
	if game.perform_vendor_action(action_id, token) \
			or not _same(game.state, opened) \
			or FileAccess.get_file_as_string(game._store.v2_path) != open_bytes:
		return _fail("failed seal inspection changed memory or saved bytes")
	action_button.pressed.emit()
	await process_frame
	ui._render()
	var inspected: Dictionary = game.state.duplicate(true)
	var checked_offer: Dictionary = {}
	for offer in inspected.get("marketState", {}).get(
			"activeSession", {}).get("immutableOffers", []):
		if offer.get("id") == sealed_id:
			checked_offer = offer
	var checked_session: Dictionary = inspected["marketState"]["activeSession"]
	if int(inspected.get("itemInventory", {}).get("商路线索", -1)) != 0 \
			or checked_offer.get("hiddenTrait", {}).get("status") != "revealed" \
			or checked_session.get("actionReceipts", {}).get(action_id, {}).get(
				"itemId") != sealed_id \
			or checked_session.get("summary", {}).get("exchangeCount") != 1 \
			or checked_session.get("summary", {}).get("exchangedItems", []).size() != 1 \
			or inspected.get("ghostVendorEventHistory", []).back().get(
				"actionId") != action_id \
			or not ui.body_label.text.contains(revealed_text) \
			or ui.body_label.text.contains("随身物品：商路线索×1"):
		return _fail("desktop seal action did not atomically consume, reveal and receipt")
	if game.perform_vendor_action(action_id, game.issue_choice_token()):
		return _fail("the same sealed offer was inspected twice")
	var forged_receipt: Dictionary = inspected.duplicate(true)
	forged_receipt["marketState"]["activeSession"]["actionReceipts"][
		action_id]["costSpec"][0]["amount"] = 0
	if game._ghost_vendor_flow.source_valid(forged_receipt):
		return _fail("forged zero-cost seal receipt passed source projection")
	var inspected_reload = Domain.new(Registry.new(), RunSession.new(
		path, "slot_3"), "slot_3")
	_stabilize_ambient(inspected_reload)
	if not inspected_reload.restore() or not _same(inspected_reload.state, inspected):
		return _fail("inspected ghost session did not strictly replay")
	var duplicate_event: Dictionary = inspected.duplicate(true)
	duplicate_event["ghostVendorEventHistory"].append(
		duplicate_event["ghostVendorEventHistory"].back().duplicate(true))
	var missing_action: Dictionary = inspected.duplicate(true)
	missing_action["marketActionHistory"].pop_back()
	var forged_trait: Dictionary = inspected.duplicate(true)
	for offer in forged_trait["marketState"]["activeSession"]["immutableOffers"]:
		if offer.get("id") == sealed_id:
			offer["hiddenTrait"]["status"] = "sealed"
	if not _reject_tampered_save(duplicate_event, "duplicate_event") \
			or not _reject_tampered_save(missing_action, "missing_action") \
			or not _reject_tampered_save(forged_trait, "forged_trait"):
		return _fail("tampered ghost inspection snapshot passed strict restore")
	var inspect_only_path := "user://tests/ghost_inspect_only_%d.json" % Time.get_ticks_usec()
	var inspect_only_store = RunSession.new(inspect_only_path, "slot_3")
	var inspect_only_file := FileAccess.open(inspect_only_store.v2_path,
		FileAccess.WRITE)
	if inspect_only_file == null:
		return _fail("inspect-only branch checkpoint could not be copied")
	inspect_only_file.store_string(FileAccess.get_file_as_string(game._store.v2_path))
	inspect_only_file.close()
	var inspect_only = Domain.new(Registry.new(), inspect_only_store, "slot_3")
	_stabilize_ambient(inspect_only)
	if not inspect_only.restore() or not inspect_only.close_vendor(
			inspect_only.issue_choice_token()) \
			or inspect_only.state.get("pendingVendorResultCard", {}).get(
				"title") != "鬼市 · 雾门合拢":
		return _fail("inspect-only ghost visit did not close with source result")
	var inspect_closed: Dictionary = inspect_only.state.duplicate(true)
	var inspect_closed_reload = Domain.new(Registry.new(), RunSession.new(
		inspect_only_path, "slot_3"), "slot_3")
	_stabilize_ambient(inspect_closed_reload)
	if not inspect_closed_reload.restore() or not _same(
			inspect_closed_reload.state, inspect_closed):
		return _fail("inspect-only exit did not strictly replay")
	if not inspect_only.choose("right", inspect_only.issue_choice_token()):
		return _fail("inspected ghost result did not dismiss")
	var later_bazaar := false
	for step in 20:
		if inspect_only.state.get("phase") == "FLOW_PENDING" \
				and not inspect_only.resume_flow():
			return _fail("inspected route stopped before later public bazaar")
		if inspect_only.get_current_card().get("id") == "bazaar_encounter":
			later_bazaar = true
			break
		var direction := "right" if inspect_only.can_choose_direction(
			"right") else "left"
		if not inspect_only.choose(direction, inspect_only.issue_choice_token()):
			return _fail("inspected route could not pass later card %s" % [
				inspect_only.get_current_card().get("id")])
	if not later_bazaar or not inspect_only.choose("left",
			inspect_only.issue_choice_token()):
		return _fail("source seal history blocked later public bazaar entry")
	var later_open: Dictionary = inspect_only.state.duplicate(true)
	var later_reload = Domain.new(Registry.new(), RunSession.new(
		inspect_only_path, "slot_3"), "slot_3")
	_stabilize_ambient(later_reload)
	if not later_reload.restore() or not _same(later_reload.state, later_open):
		return _fail("later public bazaar after seal did not strictly replay")
	if not game.purchase_vendor_offer("ghost_oath_rusted_sword",
			game.issue_choice_token()) or not game.resolve_vendor_loadout(
			"stash", game.issue_choice_token()):
		return _fail("seal-then-oath order could not sign and stash")
	var seal_first: Dictionary = game.state.duplicate(true)
	var seal_events: Array = seal_first.get("ghostVendorEventHistory", [])
	if seal_events.size() != 3 or seal_events[0].get("kind") != "action" \
			or seal_events[1].get("kind") != "purchase" \
			or seal_events[2].get("kind") != "loadout":
		return _fail("seal-then-oath event order was not preserved")
	var seal_first_reload = Domain.new(Registry.new(), RunSession.new(
		path, "slot_3"), "slot_3")
	_stabilize_ambient(seal_first_reload)
	if not seal_first_reload.restore() or not _same(
			seal_first_reload.state, seal_first):
		return _fail("seal-then-oath order did not strictly replay")
	var oath_first_path := "user://tests/ghost_oath_first_%d.json" % Time.get_ticks_usec()
	var oath_first_store = RunSession.new(oath_first_path, "slot_3")
	var oath_first_file := FileAccess.open(oath_first_store.v2_path,
		FileAccess.WRITE)
	if oath_first_file == null:
		return _fail("oath-first branch checkpoint could not be copied")
	oath_first_file.store_string(open_bytes)
	oath_first_file.close()
	var oath_first = Domain.new(Registry.new(), oath_first_store, "slot_3")
	_stabilize_ambient(oath_first)
	if not oath_first.restore() or not oath_first.purchase_vendor_offer(
			"ghost_oath_rusted_sword", oath_first.issue_choice_token()):
		return _fail("oath-first purchase could not finish")
	var pending_oath: Dictionary = oath_first.state.duplicate(true)
	var pending_oath_bytes := FileAccess.get_file_as_string(oath_first_store.v2_path)
	var pending_action := false
	for row in oath_first.vendor_actions():
		if row.get("id") == action_id:
			pending_action = row.get("enabled", false)
	if not pending_action:
		return _fail("pending loadout wrongly disabled source seal action")
	oath_first_store.fail_promotion_once = true
	if oath_first.perform_vendor_action(action_id,
			oath_first.issue_choice_token()) \
			or not _same(oath_first.state, pending_oath) \
			or FileAccess.get_file_as_string(oath_first_store.v2_path) != pending_oath_bytes:
		return _fail("failed pending-loadout seal changed state or save bytes")
	if not oath_first.perform_vendor_action(action_id,
			oath_first.issue_choice_token()) \
			or not oath_first.resolve_vendor_loadout("stash",
				oath_first.issue_choice_token()):
		return _fail("purchase-then-seal-then-loadout order could not finish")
	var oath_first_done: Dictionary = oath_first.state.duplicate(true)
	var oath_events: Array = oath_first_done.get("ghostVendorEventHistory", [])
	if oath_events.size() != 3 or oath_events[0].get("kind") != "purchase" \
			or oath_events[1].get("kind") != "action" \
			or oath_events[2].get("kind") != "loadout":
		return _fail("purchase-then-seal-then-loadout order was not preserved")
	var oath_first_reload = Domain.new(Registry.new(), RunSession.new(
		oath_first_path, "slot_3"), "slot_3")
	_stabilize_ambient(oath_first_reload)
	if not oath_first_reload.restore() or not _same(
			oath_first_reload.state, oath_first_done):
		return _fail("oath-then-seal order did not strictly replay")
	if not game.close_vendor(game.issue_choice_token()) \
			or not oath_first.close_vendor(oath_first.issue_choice_token()):
		return _fail("inspected oath sessions could not leave safely")
	var seal_closed: Dictionary = game.state.duplicate(true)
	var oath_closed: Dictionary = oath_first.state.duplicate(true)
	var seal_closed_reload = Domain.new(Registry.new(), RunSession.new(
		path, "slot_3"), "slot_3")
	var oath_closed_reload = Domain.new(Registry.new(), RunSession.new(
		oath_first_path, "slot_3"), "slot_3")
	_stabilize_ambient(seal_closed_reload)
	_stabilize_ambient(oath_closed_reload)
	if not seal_closed_reload.restore() or not _same(
			seal_closed_reload.state, seal_closed) \
			or not oath_closed_reload.restore() or not _same(
			oath_closed_reload.state, oath_closed):
		return _fail("inspected oath exit did not strictly replay in both orders")
	print("NONCOMBAT_GHOST_SEAL_PASS natural=true rollback=true inventory=true replay=true order=true ui=true")
	quit(0)

func _reject_tampered_save(snapshot: Dictionary, label: String) -> bool:
	var path := "user://tests/ghost_seal_forged_%s_%d.json" % [label,
		Time.get_ticks_usec()]
	var store = RunSession.new(path, "slot_3")
	if store.commit_snapshot(snapshot, -1).get("ok") != true:
		return false
	var reloaded = Domain.new(Registry.new(), RunSession.new(path, "slot_3"), "slot_3")
	_stabilize_ambient(reloaded)
	return not reloaded.restore()
