extends "res://tests/noncombat_regulated_replay.gd"

const LicensedDelivery = preload("res://scripts/noncombat_licensed_delivery.gd")

func _run() -> void:
	var game = Domain.new(Registry.new(), null, "slot_3")
	_set_zero_rolls(game)
	if not game.start("sword") or not _reach_bazaar(game) \
			or not game.choose("left", game.issue_choice_token()) \
			or not game.perform_vendor_action("ask_luo", game.issue_choice_token()):
		return _fail("source flow number could not be produced")
	var staged: Dictionary = game.state.duplicate(true)
	staged["phase"] = "SHOP_PENDING"
	staged["currentCardId"] = "shop_encounter"
	staged["marketState"]["activeSession"] = null
	staged["runClock"]["decisionIndex"] = 22
	staged["turn"] = 22
	var opened: Dictionary = game._regulated_vendor.open(staged,
		[{"id": "shop_pill_foundation", "name": "筑基丹", "price": 10}])
	var action_id := "causal_fact:regulated_rusted_sword_order:fact:0:rumor_rusted_sword_origin"
	var ordered: Dictionary = game._regulated_vendor.interact(opened, action_id)
	if ordered.is_empty():
		return _fail("source-shaped registered order unavailable")
	var order_id: String = ordered["marketState"]["rustedSwordOrders"][0]["orderId"]
	# This internal producer test starts at the committed registration index.
	# The public end-to-end route remains gated until the claim consumer exists.
	ordered["runClock"]["decisionIndex"] = int(ordered["marketState"][
		"rustedSwordOrders"][0]["registeredCoreDecisionIndex"])
	ordered["turn"] = int(ordered["runClock"]["decisionIndex"])
	var delivery = LicensedDelivery.new(game._content)
	var before: Dictionary = ordered.duplicate(true)
	if not delivery.settle(before, ordered) or ordered.has("pendingLicensedDeliveryOrderId"):
		return _fail("same-index vendor action advanced the core delivery clock")
	for next_index in [24, 25]:
		var candidate: Dictionary = ordered.duplicate(true)
		candidate["runClock"]["decisionIndex"] = next_index
		candidate["turn"] = next_index
		if not delivery.settle(ordered, candidate) \
				or candidate["marketState"]["rustedSwordOrders"][0]["status"] != "REGISTERED" \
				or candidate.has("pendingLicensedDeliveryOrderId"):
			return _fail("order arrived before three core decisions")
		ordered = candidate
	var due: Dictionary = ordered.duplicate(true)
	due["runClock"]["decisionIndex"] = 26
	due["turn"] = 26
	if not delivery.settle(ordered, due):
		return _fail("third core decision did not settle delivery")
	var delivered: Dictionary = due["marketState"]["rustedSwordOrders"][0]
	if delivered.get("status") != "READY" \
			or delivered.get("deliveryReceiptId") != "licensed_rusted_sword_due:" + order_id \
			or delivered.get("deliveryQueued") != true \
			or due.get("pendingLicensedDeliveryOrderId") != order_id:
		return _fail("third core decision lost unique durable due receipt")
	var same_index: Dictionary = due.duplicate(true)
	if not delivery.settle(due, same_index) or not _same(due, same_index):
		return _fail("non-core action duplicated the delivery queue")
	var later: Dictionary = due.duplicate(true)
	later["runClock"]["decisionIndex"] = 27
	later["turn"] = 27
	if not delivery.settle(due, later) or later["marketState"]["rustedSwordOrders"].size() != 1 \
			or later.get("pendingLicensedDeliveryOrderId") != order_id:
		return _fail("subsequent core decision queued duplicate delivery")
	var forged: Dictionary = ordered.duplicate(true)
	forged["marketState"]["rustedSwordOrders"][0]["dueCoreDecisionIndex"] = 25
	var forged_before: Dictionary = forged.duplicate(true)
	if delivery.settle(ordered, forged) or not _same(forged, forged_before):
		return _fail("forged early due index was accepted or mutated")
	var battle: Dictionary = ordered.duplicate(true)
	battle["runClock"]["decisionIndex"] = 26
	battle["turn"] = 26
	battle["phase"] = "BATTLE_PENDING"
	if game._delivery_eligible_for_tick(ordered, battle) \
			or not delivery.settle(ordered, battle,
				game._delivery_eligible_for_tick(ordered, battle)) \
			or battle["marketState"]["rustedSwordOrders"][0]["status"] != "REGISTERED" \
			or battle.has("pendingLicensedDeliveryOrderId"):
		return _fail("in-combat decision queued delivery")
	var inheritance: Dictionary = ordered.duplicate(true)
	inheritance["currentCardId"] = "breakthrough_reward"
	inheritance["realmTransition"] = {"status": "inheritance_pending"}
	var inheritance_candidate: Dictionary = inheritance.duplicate(true)
	inheritance_candidate["runClock"]["decisionIndex"] = 26
	inheritance_candidate["turn"] = 26
	if game._delivery_eligible_for_tick(inheritance, inheritance_candidate) \
			or not delivery.settle(inheritance, inheritance_candidate,
				game._delivery_eligible_for_tick(inheritance, inheritance_candidate)) \
			or inheritance_candidate["marketState"]["rustedSwordOrders"][0][
				"status"] != "REGISTERED" or inheritance_candidate.has(
					"pendingLicensedDeliveryOrderId"):
		return _fail("mandatory inheritance handoff queued delivery")
	var before_cadence: Dictionary = inheritance_candidate["marketState"].duplicate(true)
	if not game._market_flow.settle(inheritance, inheritance_candidate, false, -1, 0,
			not game._delivery_eligible_for_tick(inheritance, inheritance_candidate)) \
			or not _same(before_cadence, inheritance_candidate["marketState"]):
		return _fail("mandatory inheritance handoff advanced ambient market cadence")
	var no_market := {"pendingLicensedDeliveryOrderId": order_id}
	if delivery.settle({}, no_market):
		return _fail("delivery pointer survived without market ledger")
	print("NONCOMBAT_LICENSED_DELIVERY_DUE_PASS core3=true once=true source=true")
	quit(0)
