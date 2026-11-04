extends "res://tests/noncombat_regulated_replay.gd"

func _run() -> void:
	var game = Domain.new(Registry.new(), null, "slot_3")
	_set_zero_rolls(game)
	if not game.start("sword") or not _reach_bazaar(game) \
			or not game.choose("left", game.issue_choice_token()) \
			or not game.perform_vendor_action("ask_luo", game.issue_choice_token()):
		return _fail("source flow number could not be produced")
	var fact_id := "fact:0:rumor_rusted_sword_origin"
	var fresh: Dictionary = game.state.duplicate(true)
	var fact: Dictionary = fresh.get("noncombatFlow", {}).get("spineFacts", {}).get(
		fact_id, {})
	if fact.get("status") != "active":
		return _fail("source flow number was not active at production")
	var at_first: Dictionary = fresh.duplicate(true)
	var first: Array = game._regulated_vendor._materialize_causal_services(
		at_first, int(fact["createdDecisionIndex"]) + 1)
	if first.size() != 1 or first[0].get("kind") != "causal_fact_consumer" \
			or first[0].get("costSpec", []).size() != 1 \
			or first[0]["costSpec"][0].get("key") != "spiritStone" \
			or int(first[0]["costSpec"][0].get("amount", -1)) != 12 \
			or at_first["noncombatFlow"]["spineFacts"][fact_id]["status"] != "active":
		return _fail("first legal decision did not expose source order: %s / %s / %s" % [
			first, at_first["noncombatFlow"]["spineFacts"][fact_id],
			game._regulated_vendor.last_error])
	var live_market: Dictionary = fresh.duplicate(true)
	live_market["phase"] = "SHOP_PENDING"
	live_market["currentCardId"] = "shop_encounter"
	live_market["marketState"]["activeSession"] = null
	live_market["runClock"]["decisionIndex"] = 22
	live_market["turn"] = 22
	var live_open: Dictionary = game._regulated_vendor.open(live_market,
		[{"id": "shop_pill_foundation", "name": "筑基丹", "price": 10}])
	var actions: Array = game._regulated_vendor.available_actions(live_open)
	var causal_actions: Array = actions.filter(func(row: Variant) -> bool:
		return row is Dictionary and String(row.get("id", "")).begins_with(
			"causal_fact:"))
	if live_open.is_empty() or causal_actions.size() != 1 \
			or causal_actions[0].get("costText") != "12 灵石" \
			or causal_actions[0].get("costSpec", []).size() != 1:
		return _fail("live official quote lost source price")
	var action_id: String = String(causal_actions[0]["id"])
	var poor: Dictionary = live_open.duplicate(true)
	poor["resources"]["spiritStone"] = 11
	if not game._regulated_vendor.interact(poor, action_id).is_empty():
		return _fail("source causal order succeeded without twelve spirit stones")
	var forged: Dictionary = live_open.duplicate(true)
	forged["marketState"]["activeSession"]["services"][-1]["costSpec"][0]["amount"] = 0
	if not game._regulated_vendor.interact(forged, action_id).is_empty():
		return _fail("forged zero-price causal service was accepted")
	var ordered: Dictionary = game._regulated_vendor.interact(live_open, action_id)
	var order_id := "licensed_rusted_sword:%s:regulated_rusted_sword_order" % fact_id
	var order: Dictionary = ordered.get("marketState", {}).get(
		"rustedSwordOrders", [{}])[0] if not ordered.is_empty() else {}
	if ordered.is_empty() or int(ordered.get("resources", {}).get(
			"spiritStone", -1)) != 1 or ordered.get("noncombatFlow", {}).get(
			"spineFacts", {}).get(fact_id, {}).get("status") != "consumed" \
			or not ordered.get("noncombatFlow", {}).get("spineConsumptions", {}).has(
				fact_id + ":regulated_rusted_sword_order") \
			or order.get("orderId") != order_id \
			or order.get("registeredCoreDecisionIndex") != 23 \
			or order.get("dueCoreDecisionIndex") != 26 \
			or ordered.get("marketState", {}).get("activeSession", {}).get(
				"actionReceipts", {}).get(action_id, {}).get("orderId") != order_id:
		return _fail("source causal order was not atomic: %s" % order)
	if not game._regulated_vendor.interact(ordered, action_id).is_empty():
		return _fail("same-session causal order committed twice")
	# Exercise the domain's single-snapshot commit gate with a source-shaped
	# staged venue. The fixed-roll natural route reaches this venue after expiry.
	var order_path := "user://tests/causal_order_atomic_%d.json" % Time.get_ticks_usec()
	var order_store = RunSession.new(order_path, "slot_3")
	var order_game = Domain.new(Registry.new(), order_store, "slot_3")
	if not order_game.start("sword"):
		return _fail("source-shaped order transaction could not initialize")
	var staged_revision := int(order_store.load_snapshot().get("revision", -1))
	var staged_commit: Dictionary = order_store.commit_snapshot(live_open,
		staged_revision)
	if not staged_commit.get("ok", false):
		return _fail("source-shaped order session could not be staged")
	order_game.state = live_open.duplicate(true)
	order_game._store_revision = int(staged_commit["revision"])
	var staged_before: Dictionary = order_game.state.duplicate(true)
	var staged_bytes := FileAccess.get_file_as_string(order_store.v2_path)
	order_store.fail_promotion_once = true
	if order_game.perform_vendor_action(action_id, order_game.issue_choice_token()) \
			or not _same(order_game.state, staged_before) \
			or FileAccess.get_file_as_string(order_store.v2_path) != staged_bytes:
		return _fail("failed causal order changed money, fact, order or save bytes")
	if not order_game.perform_vendor_action(action_id, order_game.issue_choice_token()) \
			or order_game.state.get("marketState", {}).get(
				"rustedSwordOrders", []).size() != 1:
		return _fail("causal order retry did not commit once after write failure")
	var at_expiry: Dictionary = fresh.duplicate(true)
	var closed: Array = game._regulated_vendor._materialize_causal_services(
		at_expiry, int(fact["createdDecisionIndex"]) + 5)
	if closed.size() != 1 or closed[0].get("kind") != "causal_fact_closed" \
			or at_expiry["noncombatFlow"]["spineFacts"][fact_id]["status"] != "closed":
		return _fail("fifth decision did not close source order: %s" % closed)
	print("NONCOMBAT_CAUSAL_SERVICES_PASS first=true expired=true order=true rollback=true")
	quit(0)
