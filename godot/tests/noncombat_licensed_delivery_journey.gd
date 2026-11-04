extends "res://tests/noncombat_regulated_replay.gd"

# Full fresh-run route: no staged authored card, edited balance, or injected
# order. The official venue comes from the ordinary q_market draw.
func _run() -> void:
	# This legal draw path reaches q_market within Luo's fact window and
	# continues through supported ordinary choices until delivery is due.
	var roll := 0.21
	var path := "user://tests/licensed_delivery_journey_%d.json" % Time.get_ticks_usec()
	var session = RunSession.new(path, "slot_3")
	var game = Domain.new(Registry.new(), session, "slot_3")
	_set_zero_rolls(game)
	if not game.start("sword") or not _reach_bazaar(game) \
			or not game.choose("right", game.issue_choice_token()):
		return _fail("natural later-Luo route did not start")
	var fact_id := "fact:0:rumor_rusted_sword_origin"
	var action_id := "causal_fact:regulated_rusted_sword_order:" + fact_id
	var reached_official := false
	for step in 80:
		var phase := String(game.state.get("phase", ""))
		var card_id := String(game.get_current_card().get("id", ""))
		if phase == "FLOW_PENDING":
			if not game.resume_flow():
				return _fail("natural order route stalled before official venue")
			continue
		if phase == "MARKET_PENDING" and card_id == "bazaar_encounter":
			if not game.state.get("noncombatFlow", {}).get("spineFacts", {}).has(fact_id):
				if not game.choose("left", game.issue_choice_token()) \
						or not game.perform_vendor_action("ask_luo",
							game.issue_choice_token()):
					return _fail("second bazaar failed to produce source flow number")
				game._normal_roll_override = roll
				if not game.close_vendor(game.issue_choice_token()):
					return _fail("second bazaar failed to close")
			else:
				if not game.choose("right", game.issue_choice_token()):
					return _fail("later bazaar skip failed")
			continue
		if phase == "SHOP_PENDING" and card_id == "q_market":
			if not game.choose("left", game.issue_choice_token()):
				return _fail("natural q_market did not open official venue")
			reached_official = true
			break
		if not _advance_one(game):
			return _fail("natural order route stopped before official venue: %s" % phase)
	if not reached_official:
		return _fail("natural order route did not reach official venue")
	var offered: Array = game.vendor_actions().filter(func(row: Variant) -> bool:
		return row is Dictionary and row.get("id") == action_id)
	if offered.size() != 1 or int(game.state.get("resources", {}).get(
			"spiritStone", -1)) < 12:
		return _fail("natural venue has no affordable source order")
	var before: Dictionary = game.state.duplicate(true)
	var before_bytes := FileAccess.get_file_as_string(session.v2_path)
	session.fail_promotion_once = true
	if game.perform_vendor_action(action_id, game.issue_choice_token()) \
			or not _same(game.state, before) \
			or FileAccess.get_file_as_string(session.v2_path) != before_bytes:
		return _fail("failed public order write changed money, fact, order or save")
	if not game.perform_vendor_action(action_id, game.issue_choice_token()):
		return _fail("public source order remains gated")
	var order_id := "licensed_rusted_sword:%s:regulated_rusted_sword_order" % fact_id
	var order: Dictionary = game.state.get("marketState", {}).get(
		"rustedSwordOrders", [{}])[0]
	if order.get("orderId") != order_id or order.get("status") != "REGISTERED" \
			or int(game.state["resources"]["spiritStone"]) != int(
				before["resources"]["spiritStone"]) - 12 \
			or game.perform_vendor_action(action_id, game.issue_choice_token()):
		return _fail("natural order did not settle money and fact once")
	if not _strict_restore(path, game):
		return _fail("paid open venue could not strictly restore")
	if not game.close_vendor(game.issue_choice_token()):
		return _fail("ordered venue could not close")
	var due_index := int(order.get("dueCoreDecisionIndex", -1))
	var delivery_seen := false
	for step in 80:
		var phase := String(game.state.get("phase", ""))
		var index := int(game.state.get("runClock", {}).get("decisionIndex", -1))
		if phase == "FLOW_PENDING":
			if not game.resume_flow():
				return _fail("paid order route stalled before delivery at %d: %s / order=%s" % [
					index, game.flow_failure_reason(), game.state.get("attributes", {})])
			continue
		if phase == "LICENSED_DELIVERY_PENDING":
			if index != due_index or game.get_current_card().get("id") \
					!= "regulated_rusted_sword_delivery:" + order_id:
				return _fail("delivery surfaced on the wrong core decision")
			delivery_seen = true
			break
		if not _advance_one(game):
			return _fail("paid order route stopped before delivery: %s at %d" % [
				phase, index])
	if not delivery_seen or not _strict_restore(path, game):
		return _fail("due delivery card was missing or failed strict restore")
	var due_before: Dictionary = game.state.duplicate(true)
	var due_bytes := FileAccess.get_file_as_string(session.v2_path)
	session.fail_promotion_once = true
	if game.choose("left", game.issue_choice_token()) \
			or not _same(game.state, due_before) \
			or FileAccess.get_file_as_string(session.v2_path) != due_bytes:
		return _fail("failed delivery write consumed card, instance, fact or save")
	if not game.choose("left", game.issue_choice_token()):
		return _fail("source delivery could not be claimed")
	var claimed: Dictionary = game.state.get("marketState", {}).get(
		"rustedSwordOrders", [{}])[0]
	var instance_id := String(claimed.get("instanceId", ""))
	var provenance_id := String(claimed.get("provenanceFactInstanceId", ""))
	if claimed.get("status") != "CLAIMED" or instance_id.is_empty() \
			or provenance_id != "fact:0:sword_origin_licensed" \
			or game.state.get("treasureInstances", {}).get(instance_id, {}).get(
				"definitionId") != "licensed_rusted_sword" \
			or game.state.get("pendingLoadoutDecision", {}).get(
				"instanceId") != instance_id \
			or not _strict_restore(path, game):
		return _fail("claim did not atomically create sword, fact and loadout")
	# Fork only the naturally reached pending decision, then replay that exact
	# source history in an independent slot file to exercise the other choice.
	var stash_path := "user://tests/licensed_delivery_stash_%d.json" % Time.get_ticks_usec()
	var stash_session = RunSession.new(stash_path, "slot_3")
	if stash_session.commit_snapshot(game.state, -1).get("ok") != true:
		return _fail("natural pending loadout could not be saved for stash branch")
	var stash_game = Domain.new(Registry.new(), stash_session, "slot_3")
	_set_zero_rolls(stash_game)
	if not stash_game.restore() or not _same(stash_game.state, game.state) \
			or not stash_game.resolve_vendor_loadout("stash",
				stash_game.issue_choice_token()) \
			or stash_game.state.get("equipment", {}).get("weapon") == instance_id \
			or stash_game.state.get("treasureInstances", {}).get(instance_id, {}).get(
				"lifecycle") != "owned" \
			or not _strict_restore(stash_path, stash_game):
		return _fail("natural source sword stash failed strict restore")
	if game.choose("left", game.issue_choice_token()):
		return _fail("claimed delivery could be claimed twice")
	var loadout_before: Dictionary = game.state.duplicate(true)
	var loadout_bytes := FileAccess.get_file_as_string(session.v2_path)
	session.fail_promotion_once = true
	if game.resolve_vendor_loadout("equip", game.issue_choice_token()) \
			or not _same(game.state, loadout_before) \
			or FileAccess.get_file_as_string(session.v2_path) != loadout_bytes:
		return _fail("failed loadout write changed equipment or save")
	if not game.resolve_vendor_loadout("equip", game.issue_choice_token()) \
			or game.state.get("equipment", {}).get("weapon") != instance_id \
			or not _strict_restore(path, game):
		return _fail("licensed sword equip failed strict restore")
	print("NONCOMBAT_LICENSED_DELIVERY_JOURNEY_PASS natural=true order=true due=true claim=true equip=true stash=true rollback=true replay=true")
	quit(0)


func _advance_one(game: RefCounted) -> bool:
	if game.state.get("phase") == "VENDOR_OPEN":
		return game.close_vendor(game.issue_choice_token())
	if game.state.get("phase") == "WARNING_PENDING":
		return game.get_current_card().get("id") == "_warning_q_fellow" \
			and game.choose("left", game.issue_choice_token())
	if game.state.get("phase") == "BATTLE_PENDING":
		var request: Dictionary = game.battle_request()
		if request.get("sourceCardId") != "q_fellow":
			return false
		var result := {"contractVersion": 2,
			"encounterInstanceId": request.get("encounterInstanceId"),
			"sourceCardId": request.get("sourceCardId"),
			"encounterId": request.get("encounterId"),
			"sourceContentHash": request.get("sourceContentHash"),
			"outcome": "flee",
			"combatReceipt": "combat:" + String(request.get("encounterInstanceId", "")),
			"postBattleState": {"encounterInstanceId": request.get("encounterInstanceId"),
				"terminal": true, "combatPhase": "FLEE"}}
		return game.submit_battle_result(result)
	for direction in ["right", "left", "down", "up"]:
		if game.can_choose_direction(direction):
			return game.choose(direction, game.issue_choice_token())
	return false


func _strict_restore(path: String, game: RefCounted) -> bool:
	var loaded = Domain.new(Registry.new(), RunSession.new(path, "slot_3"), "slot_3")
	_set_zero_rolls(loaded)
	return loaded.restore() and _same(loaded.state, game.state)
