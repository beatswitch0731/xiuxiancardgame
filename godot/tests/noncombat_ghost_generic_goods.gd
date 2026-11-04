extends "res://tests/noncombat_market_arrival.gd"

func _run() -> void:
	var path := "user://tests/ghost_generic_%d.json" % Time.get_ticks_usec()
	var game = Domain.new(Registry.new(), RunSession.new(path, "slot_3"), "slot_3")
	_stabilize_ambient(game)
	game._normal_roll_override = 0.0
	if not game.start("spell"):
		return _fail("spell opening did not start")
	var route := [
		["tutorial_1", "left"], ["tutorial_2", "left"],
		["tutorial_3", "left"], ["tutorial_4", "left"],
		["q_start_spell", "left"], ["COMBAT_HANDOFF", "right"],
		["promise_result_0105e2c0", "left"], ["ch_qi_20", "right"],
		["ch_qi_40", "right"], ["q_whiteFox_quest", "right"],
		["q_whiteFox_2", "right"], ["q_whiteFox_3", "right"],
		["bazaar_encounter", "right"], ["q_gathering", "right"]]
	for step in route:
		if game.state.get("phase") == "FLOW_PENDING" and not game.resume_flow():
			return _fail("route stopped before ghost market")
		var id := String(game.state.get("phase")) if step[0] == "COMBAT_HANDOFF" \
			else String(game.get_current_card().get("id", ""))
		if id != step[0] or not game.choose(step[1], game.issue_choice_token()):
			return _fail("route diverged at %s -> %s" % [str(step), id])
	if not game.resume_flow() or game.get_current_card().get("id") != \
			"market_encounter" or not game.choose("left", game.issue_choice_token()):
		return _fail("natural ghost arrival did not open")
	var session: Dictionary = game.state["marketState"]["activeSession"]
	var ordinary := ""
	var selected: Dictionary = {}
	for offer in session["immutableOffers"]:
		if offer.get("id") != "ghost_oath_rusted_sword" and offer.get(
				"type") == "treasure":
			ordinary = String(offer["id"])
			selected = offer
			break
	if ordinary.is_empty():
		return _fail("source ghost stock lacked ordinary treasure")
	var supported := false
	for offer in game.vendor_offers():
		if offer.get("id") == ordinary:
			supported = offer.get("supported", false)
	if not supported:
		return _fail("ordinary source ghost treasure has no purchase consumer")
	var ui: Control = load("res://scenes/noncombat_opening.tscn").instantiate()
	ui.save_path = ""
	root.add_child(ui)
	await process_frame
	ui.opening = game
	ui._render()
	var choices: HBoxContainer = ui.get_node(
		"DesktopMargin/ScreenStack/StoryScreen/SourceChoices")
	var button: Button = choices.get_node_or_null("VendorBuy_" + ordinary)
	if button == null or button.disabled or not button.text.contains("寿元"):
		return _fail("desktop ordinary ghost purchase was not available")
	var before: Dictionary = game.state.duplicate(true)
	var before_bytes := FileAccess.get_file_as_string(game._store.v2_path)
	var cost: Array = selected["costSpec"]
	var stone := int(cost[0]["amount"])
	var lifespan := int(cost[1]["amount"])
	var broke: Dictionary = before.duplicate(true)
	broke["resources"]["spiritStone"] = 0
	if game._ghost_vendor_flow.available_offers(broke).any(func(row: Variant) -> bool:
		return row.get("id") == ordinary and row.get("enabled", false)) \
			or not game._ghost_vendor_flow.purchase_oath(broke, ordinary).is_empty():
		return _fail("ordinary ghost purchase ignored unavailable stone")
	game._store.fail_promotion_once = true
	if game.purchase_vendor_offer(ordinary, game.issue_choice_token()) \
			or not _same(game.state, before) \
			or FileAccess.get_file_as_string(game._store.v2_path) != before_bytes:
		return _fail("failed ordinary ghost purchase changed memory or save bytes")
	button.pressed.emit()
	await process_frame
	var purchased: Dictionary = game.state.duplicate(true)
	var pending: Dictionary = purchased.get("pendingLoadoutDecision", {})
	var debts: Array = purchased["marketState"].get("debts", [])
	var debt: Dictionary = debts[0] if debts.size() == 1 else {}
	var instance: Dictionary = purchased.get("treasureInstances", {}).get(
		pending.get("instanceId"), {})
	if int(purchased["resources"]["spiritStone"]) != int(before[
			"resources"]["spiritStone"]) - stone \
			or int(purchased["resources"]["lifespan"]) != int(before[
			"resources"]["lifespan"]) - lifespan \
			or debt.has("kind") or debt.get("status") != "PENDING" \
			or debt.get("dueDecisionIndex") != 17 \
			or debt.get("settlementCostSpec") != [{"kind": "resource",
				"key": "spiritStone", "amount": maxi(1, ceili(stone * 0.5))}] \
			or instance.get("definitionId") != ordinary \
			or instance.get("provenance", {}).get("source") != "ghost_market_purchase" \
			or pending.get("ghostDebtId") != debt.get("debtId") \
			or purchased["marketState"]["activeSession"]["summary"].get(
				"purchaseCount") != 1:
		return _fail("ordinary ghost purchase did not atomically create source debt")
	if game.purchase_vendor_offer(ordinary, game.issue_choice_token()):
		return _fail("ordinary ghost treasure was purchased twice")
	var forged_debt: Dictionary = purchased.duplicate(true)
	forged_debt["marketState"]["debts"][0]["settlementCostSpec"][0]["amount"] = 0
	if not _reject_tampered_save(forged_debt):
		return _fail("forged free ordinary ghost debt passed strict restore")
	var purchased_reload = Domain.new(Registry.new(), RunSession.new(
		path, "slot_3"), "slot_3")
	_stabilize_ambient(purchased_reload)
	if not purchased_reload.restore() or not _same(purchased_reload.state,
			purchased):
		return _fail("ordinary ghost purchase did not strictly replay")
	if not game.resolve_vendor_loadout("equip", game.issue_choice_token()):
		return _fail("ordinary ghost treasure could not equip")
	var equipped: Dictionary = game.state.duplicate(true)
	if equipped.get("equipment", {}).get(pending.get("targetSlot")) != \
			pending.get("instanceId"):
		return _fail("ordinary ghost treasure equipped into wrong slot")
	var equipped_reload = Domain.new(Registry.new(), RunSession.new(
		path, "slot_3"), "slot_3")
	_stabilize_ambient(equipped_reload)
	if not equipped_reload.restore() or not _same(equipped_reload.state,
			equipped):
		return _fail("ordinary ghost loadout did not strictly replay")
	var second: Dictionary = {}
	for offer in game.state["marketState"]["activeSession"]["immutableOffers"]:
		if offer.get("id") != "ghost_oath_rusted_sword" \
				and offer.get("id") != ordinary and offer.get("_marketItem") == true:
			second = offer
			break
	if second.is_empty() or not game.purchase_vendor_offer(String(second["id"]),
			game.issue_choice_token()) or not game.resolve_vendor_loadout(
			"stash", game.issue_choice_token()):
		return _fail("second ordinary ghost treasure could not buy and stash")
	var second_done: Dictionary = game.state.duplicate(true)
	var events: Array = second_done.get("ghostVendorEventHistory", [])
	if second_done["marketState"]["activeSession"]["summary"].get(
			"purchaseCount") != 2 \
			or second_done["marketState"].get("debts", []).size() != 2 \
			or events.size() != 4 or events[0].get("kind") != "purchase" \
			or events[1].get("kind") != "loadout" \
			or events[2].get("kind") != "purchase" \
			or events[3].get("kind") != "loadout":
		return _fail("two ordinary contracts lost debt or event order")
	var second_reload = Domain.new(Registry.new(), RunSession.new(
		path, "slot_3"), "slot_3")
	_stabilize_ambient(second_reload)
	if not second_reload.restore() or not _same(second_reload.state,
			second_done):
		return _fail("two ordinary ghost contracts did not strictly replay")
	var mixed_path := "user://tests/ghost_generic_mixed_%d.json" % Time.get_ticks_usec()
	var mixed_store = RunSession.new(mixed_path, "slot_3")
	if mixed_store.commit_snapshot(equipped, -1).get("ok") != true:
		return _fail("mixed ghost contract branch could not save checkpoint")
	var mixed = Domain.new(Registry.new(), mixed_store, "slot_3")
	_stabilize_ambient(mixed)
	if not mixed.restore() or not _same(mixed.state, equipped) \
			or not mixed.purchase_vendor_offer("ghost_oath_rusted_sword",
				mixed.issue_choice_token()) \
			or not mixed.resolve_vendor_loadout("stash", mixed.issue_choice_token()):
		return _fail("ordinary goods and authored oath could not coexist")
	var mixed_done: Dictionary = mixed.state.duplicate(true)
	var mixed_events: Array = mixed_done.get("ghostVendorEventHistory", [])
	if mixed_done["marketState"].get("debts", []).size() != 2 \
			or mixed_events.size() != 4 \
			or mixed_events[2].get("offerId") != "ghost_oath_rusted_sword":
		return _fail("mixed ghost contracts lost the authored oath")
	var mixed_reload = Domain.new(Registry.new(), RunSession.new(
		mixed_path, "slot_3"), "slot_3")
	_stabilize_ambient(mixed_reload)
	if not mixed_reload.restore() or not _same(mixed_reload.state, mixed_done):
		return _fail("mixed ghost goods and oath did not strictly replay")
	var reverse_path := "user://tests/ghost_generic_reverse_%d.json" % Time.get_ticks_usec()
	var reverse_store = RunSession.new(reverse_path, "slot_3")
	if reverse_store.commit_snapshot(before, -1).get("ok") != true:
		return _fail("reverse mixed ghost checkpoint could not save")
	var reverse = Domain.new(Registry.new(), reverse_store, "slot_3")
	_stabilize_ambient(reverse)
	if not reverse.restore() or not reverse.purchase_vendor_offer(
			"ghost_oath_rusted_sword", reverse.issue_choice_token()) \
			or not reverse.resolve_vendor_loadout("stash", reverse.issue_choice_token()) \
			or not reverse.purchase_vendor_offer(ordinary, reverse.issue_choice_token()) \
			or not reverse.resolve_vendor_loadout("stash", reverse.issue_choice_token()):
		return _fail("authored oath then ordinary goods could not coexist")
	var reverse_done: Dictionary = reverse.state.duplicate(true)
	var reverse_events: Array = reverse_done.get("ghostVendorEventHistory", [])
	if reverse_events.size() != 4 \
			or reverse_events[0].get("offerId") != "ghost_oath_rusted_sword" \
			or reverse_events[2].get("offerId") != ordinary:
		return _fail("reverse mixed ghost transaction order was not preserved")
	var reverse_reload = Domain.new(Registry.new(), RunSession.new(
		reverse_path, "slot_3"), "slot_3")
	_stabilize_ambient(reverse_reload)
	if not reverse_reload.restore() or not _same(reverse_reload.state,
			reverse_done):
		return _fail("reverse mixed ghost transactions did not strictly replay")
	if not game.close_vendor(game.issue_choice_token()):
		return _fail("two ordinary ghost contracts could not close")
	if game.state.get("phase") == "DESTINY_WHEEL_PENDING" \
			and not game.choose("left", game.issue_choice_token()):
		return _fail("ghost contracts could not pass due wheel")
	if game.state.get("phase") != "VENDOR_RESULT_PENDING" \
			or not game.choose("right", game.issue_choice_token()):
		return _fail("two ordinary ghost contracts did not dismiss source result")
	for step in 10:
		if int(game.state.get("runClock", {}).get("decisionIndex", 0)) >= 17:
			break
		if game.state.get("phase") == "FLOW_PENDING" and not game.resume_flow():
			return _fail("ordinary ghost route stopped before debt due")
		var direction := "right" if game.can_choose_direction("right") else "left"
		if not game.choose(direction, game.issue_choice_token()):
			return _fail("ordinary ghost route stopped at %s" % [
				game.get_current_card().get("id")])
	if int(game.state.get("runClock", {}).get("decisionIndex", 0)) != 17 \
			or not game.state.has("pendingGhostDebtId") \
			or not game.resume_flow():
		return _fail("ordinary ghost debts did not become due at decision 17")
	var due_card: Dictionary = game.get_current_card()
	if due_card.get("type") != "GHOST_DEBT_DUE" \
			or due_card.get("causalFactInstanceId") != null \
			or due_card.get("causalConsumerId") != null \
			or not due_card.get("description", "").contains("鬼市契约"):
		return _fail("ordinary ghost debt card invented oath provenance")
	var first_due: Dictionary = game.state.duplicate(true)
	var first_due_reload = Domain.new(Registry.new(), RunSession.new(
		path, "slot_3"), "slot_3")
	_stabilize_ambient(first_due_reload)
	if not first_due_reload.restore() or not _same(first_due_reload.state,
			first_due):
		return _fail("ordinary ghost due card did not strictly replay")
	var before_settle := int(game.state["resources"]["spiritStone"])
	var due_id := String(game.state["pendingGhostDebtId"])
	var due_cost := 0
	for row in game.state["marketState"]["debts"]:
		if row.get("debtId") == due_id:
			due_cost = int(row["settlementCostSpec"][0]["amount"])
	if not game.choose("left", game.issue_choice_token()) \
			or int(game.state["resources"]["spiritStone"]) != before_settle - due_cost:
		return _fail("ordinary ghost settlement did not pay frozen debt cost")
	if not game.state.has("pendingGhostDebtId") \
			or game.state["pendingGhostDebtId"] == due_id \
			or not game.resume_flow() \
			or game.get_current_card().get("type") != "GHOST_DEBT_DUE":
		return _fail("second due ghost contract was lost after first settlement")
	var second_due: Dictionary = game.state.duplicate(true)
	var second_due_reload = Domain.new(Registry.new(), RunSession.new(
		path, "slot_3"), "slot_3")
	_stabilize_ambient(second_due_reload)
	if not second_due_reload.restore() or not _same(second_due_reload.state,
			second_due):
		return _fail("second due ordinary ghost contract did not strictly replay")
	if not game.choose("right", game.issue_choice_token()):
		return _fail("second ordinary ghost contract could not default")
	var final_state: Dictionary = game.state.duplicate(true)
	var final_debts: Array = final_state["marketState"]["debts"]
	if final_debts.size() != 2 \
			or final_debts[0].get("status") != "SETTLED" \
			or final_debts[1].get("status") != "DEFAULTED" \
			or final_state["marketState"].get("ghostMarketAccess") != "revoked" \
			or final_state.get("noncombatFlow", {}).get(
				"spineConsumptions", {}).size() != second_due.get(
				"noncombatFlow", {}).get("spineConsumptions", {}).size():
		return _fail("generic debt settlement or default changed wrong state")
	var final_reload = Domain.new(Registry.new(), RunSession.new(
		path, "slot_3"), "slot_3")
	_stabilize_ambient(final_reload)
	if not final_reload.restore() or not _same(final_reload.state, final_state):
		return _fail("ordinary ghost debt outcomes did not strictly replay")
	print("NONCOMBAT_GHOST_GENERIC_GOODS_PASS source=true atomic=true loadout=true replay=true multi=true debt=true")
	quit(0)

func _reject_tampered_save(snapshot: Dictionary) -> bool:
	var path := "user://tests/ghost_generic_forged_%d.json" % Time.get_ticks_usec()
	var store = RunSession.new(path, "slot_3")
	if store.commit_snapshot(snapshot, -1).get("ok") != true:
		return false
	var reloaded = Domain.new(Registry.new(), RunSession.new(path, "slot_3"), "slot_3")
	_stabilize_ambient(reloaded)
	return not reloaded.restore()
