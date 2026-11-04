extends "res://tests/noncombat_regulated_replay.gd"

func _run() -> void:
	var game = Domain.new(Registry.new(), null, "slot_3")
	_set_zero_rolls(game)
	if not game.start("sword") or not _reach_bazaar(game) \
			or not game.choose("left", game.issue_choice_token()) \
			or not game.perform_vendor_action("ask_luo", game.issue_choice_token()):
		return _fail("source order fact unavailable")
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
		return _fail("source order transaction unavailable")
	var order_id: String = ordered["marketState"]["rustedSwordOrders"][0]["orderId"]
	ordered["runClock"]["decisionIndex"] = int(ordered["marketState"][
		"rustedSwordOrders"][0]["registeredCoreDecisionIndex"])
	ordered["turn"] = int(ordered["runClock"]["decisionIndex"])
	var due: Dictionary = ordered.duplicate(true)
	due["runClock"]["decisionIndex"] = int(due["marketState"][
		"rustedSwordOrders"][0]["dueCoreDecisionIndex"])
	due["turn"] = int(due["runClock"]["decisionIndex"])
	due["phase"] = "FLOW_PENDING"
	due["currentCardId"] = ""
	if not game._licensed_delivery.settle(ordered, due):
		return _fail("source order could not become due")
	var pending: Dictionary = game._licensed_delivery.resume(due)
	if pending.is_empty() or pending.get("currentCardId") != \
			"regulated_rusted_sword_delivery:" + order_id:
		return _fail("due order did not generate source delivery card")
	var claimed: Dictionary = game._licensed_delivery.claim(pending)
	var sword: Dictionary = claimed.get("marketState", {}).get(
		"rustedSwordOrders", [{}])[0] if not claimed.is_empty() else {}
	var instance_id := String(sword.get("instanceId", ""))
	var fact_id := String(sword.get("provenanceFactInstanceId", ""))
	if claimed.is_empty() or sword.get("status") != "CLAIMED" \
			or instance_id.is_empty() or fact_id != "fact:0:sword_origin_licensed" \
			or claimed.get("treasureInstances", {}).get(instance_id, {}).get(
				"definitionId") != "licensed_rusted_sword" \
			or claimed.get("noncombatFlow", {}).get("spineFacts", {}).get(
				fact_id, {}).get("payload", {}).get("itemInstanceId") != instance_id \
			or claimed.get("pendingLoadoutDecision", {}).get("instanceId") != instance_id:
		return _fail("claim failed atomic instance/fact/loadout transaction")
	if not game._licensed_delivery.claim(pending) == claimed:
		# Reapplying to an *old immutable input* is deterministic replay, not a
		# duplicate transition on the already claimed candidate.
		return _fail("claim projection was nondeterministic")
	if not game._licensed_delivery.claim(claimed).is_empty():
		return _fail("claimed order produced duplicate instance")
	var equipped: Dictionary = game._licensed_delivery.resolve_loadout(claimed,
		"equip")
	if equipped.is_empty() or equipped.get("equipment", {}).get(
			"weapon") != instance_id or equipped.get("pendingLoadoutDecision") != null \
			or not game._licensed_delivery.resolve_loadout(equipped, "equip").is_empty():
		return _fail("licensed instance could not equip exactly once")
	var stashed: Dictionary = game._licensed_delivery.resolve_loadout(claimed,
		"stash")
	if stashed.is_empty() or stashed.get("equipment", {}).get("weapon") == instance_id \
			or stashed.get("pendingLoadoutDecision") != null:
		return _fail("licensed instance could not be stored in inventory")
	print("NONCOMBAT_LICENSED_DELIVERY_CLAIM_PASS card=true instance=true fact=true equip=true stash=true")
	quit(0)
