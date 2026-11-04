extends "res://tests/noncombat_market_arrival.gd"

func _run() -> void:
	var path := "user://tests/ghost_oath_%d.json" % Time.get_ticks_usec()
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
			return _fail("spell route stopped before ghost entry")
		var id := String(game.state.get("phase")) if step[0] == "COMBAT_HANDOFF" \
			else String(game.get_current_card().get("id", ""))
		if id != step[0] or not game.choose(step[1], game.issue_choice_token()):
			return _fail("spell route diverged at %s -> %s" % [str(step), id])
	if not game.resume_flow() or game.get_current_card().get("id") != "market_encounter" \
			or not game.choose("left", game.issue_choice_token()):
		return _fail("natural ghost entry did not open")
	var ui: Control = load("res://scenes/noncombat_opening.tscn").instantiate()
	ui.save_path = ""
	root.add_child(ui)
	await process_frame
	ui.opening = game
	ui._render()
	var choices: HBoxContainer = ui.get_node(
		"DesktopMargin/ScreenStack/StoryScreen/SourceChoices")
	var oath_button: Button = choices.get_node_or_null(
		"VendorBuy_ghost_oath_rusted_sword")
	if oath_button == null or oath_button.disabled or not oath_button.text.contains("寿元"):
		return _fail("desktop ghost oath purchase was not visibly available")
	var before: Dictionary = game.state.duplicate(true)
	var before_bytes := FileAccess.get_file_as_string(game._store.v2_path)
	var token: int = game.issue_choice_token()
	game._store.fail_promotion_once = true
	if game.purchase_vendor_offer("ghost_oath_rusted_sword", token) \
			or not _same(game.state, before) \
			or FileAccess.get_file_as_string(game._store.v2_path) != before_bytes:
		return _fail("failed ghost oath purchase changed state or saved bytes")
	if not game.purchase_vendor_offer("ghost_oath_rusted_sword", token):
		return _fail("source ghost oath purchase is still gated: %s / %s / valid=%s / offer=%s / pin=%s" % [
			game._ghost_vendor_flow.last_error,
			str(game._ghost_vendor_flow.purchase_oath(game.state,
				"ghost_oath_rusted_sword").keys()),
			str(game._ghost_vendor_flow.source_valid(game.state)),
			str(game.state.get("marketState", {}).get("activeSession", {}).get("immutableOffers", [])[0]),
			str(game.state.get("noncombatFlow", {}).get("causalGraphSourceSha", ""))])
	var after: Dictionary = game.state
	var session: Dictionary = after.get("marketState", {}).get("activeSession", {})
	var debts: Array = after.get("marketState", {}).get("debts", [])
	var pending: Dictionary = after.get("pendingLoadoutDecision", {})
	var facts: Dictionary = after.get("noncombatFlow", {}).get("spineFacts", {})
	var oath_fact: Dictionary = facts.get("fact:0:sword_origin_ghost_oath", {})
	if int(after["resources"].get("spiritStone", -1)) != int(before[
			"resources"].get("spiritStone", -1)) - 4 \
			or int(after["resources"].get("lifespan", -1)) != int(before[
			"resources"].get("lifespan", -1)) - 3 \
			or debts.size() != 1 or debts[0].get("kind") != "ghost_oath_sword" \
			or debts[0].get("dueDecisionIndex") != 17 \
			or not String(pending.get("instanceId", "")).begins_with(
				"tr:ghost_oath_rusted_sword:") \
			or not after.get("treasureInstances", {}).has(pending.get("instanceId")) \
			or oath_fact.get("payload", {}).get("itemInstanceId") != pending.get(
				"instanceId") \
			or session.get("summary", {}).get("purchaseCount") != 1:
		return _fail("ghost oath purchase did not atomically bind cost, sword, fact and debt")
	if FileAccess.get_file_as_string(game._store.v2_path) == before_bytes \
			or game.purchase_vendor_offer("ghost_oath_rusted_sword", token):
		return _fail("ghost oath purchase did not commit exactly once")
	var replay = Domain.new(Registry.new(), RunSession.new(path, "slot_3"), "slot_3")
	_stabilize_ambient(replay)
	if not replay.restore() or not _same(replay.state, after):
		return _fail("ghost oath purchase did not strictly replay")
	var forged_debt: Dictionary = after.duplicate(true)
	forged_debt["marketState"]["debts"][0]["acquiredInstanceId"] = "tr:forged"
	if game._ghost_vendor_flow.source_valid(forged_debt):
		return _fail("forged debt-to-sword identity passed ghost source validation")
	var stash_path := "user://tests/ghost_stash_%d.json" % Time.get_ticks_usec()
	var stash_store = RunSession.new(stash_path, "slot_3")
	var stash_file := FileAccess.open(stash_store.v2_path, FileAccess.WRITE)
	if stash_file == null:
		return _fail("ghost oath stash branch could not copy purchased checkpoint")
	stash_file.store_string(FileAccess.get_file_as_string(game._store.v2_path))
	stash_file.close()
	var stash_game = Domain.new(Registry.new(), stash_store, "slot_3")
	_stabilize_ambient(stash_game)
	if not stash_game.restore() or not stash_game.resolve_vendor_loadout(
			"stash", stash_game.issue_choice_token()) \
			or stash_game.state.get("equipment", {}).get("weapon") == pending.get(
				"instanceId") \
			or stash_game.state.get("pendingLoadoutDecision") != null:
		return _fail("authentic ghost oath stash branch did not resolve")
	var stashed: Dictionary = stash_game.state.duplicate(true)
	var stash_reload = Domain.new(Registry.new(), RunSession.new(
		stash_path, "slot_3"), "slot_3")
	_stabilize_ambient(stash_reload)
	if not stash_reload.restore() or not _same(stash_reload.state, stashed):
		return _fail("ghost oath stash branch did not strictly replay")
	var debt_clock: Dictionary = after.duplicate(true)
	debt_clock["runClock"]["decisionIndex"] = 16
	debt_clock["turn"] = 16
	var battle_due: Dictionary = debt_clock.duplicate(true)
	battle_due["runClock"]["decisionIndex"] = 17
	battle_due["turn"] = 17
	battle_due["phase"] = "BATTLE_PENDING"
	if game._delivery_eligible_for_tick(debt_clock, battle_due) \
			or not game._ghost_debt_flow.settle(debt_clock, battle_due,
				game._delivery_eligible_for_tick(debt_clock, battle_due)) \
			or battle_due["marketState"]["debts"][0]["status"] != "PENDING" \
			or battle_due.has("pendingGhostDebtId"):
		return _fail("battle handoff queued ghost debt before combat resolved")
	var inheritance_clock: Dictionary = debt_clock.duplicate(true)
	inheritance_clock["currentCardId"] = "breakthrough_reward"
	inheritance_clock["realmTransition"] = {"status": "inheritance_pending"}
	var inheritance_due: Dictionary = inheritance_clock.duplicate(true)
	inheritance_due["runClock"]["decisionIndex"] = 17
	inheritance_due["turn"] = 17
	if game._delivery_eligible_for_tick(inheritance_clock, inheritance_due) \
			or not game._ghost_debt_flow.settle(inheritance_clock, inheritance_due,
				game._delivery_eligible_for_tick(inheritance_clock, inheritance_due)) \
			or inheritance_due["marketState"]["debts"][0]["status"] != "PENDING" \
			or inheritance_due.has("pendingGhostDebtId"):
		return _fail("mandatory inheritance continuation queued ghost debt")
	var released_due: Dictionary = inheritance_due.duplicate(true)
	released_due["runClock"]["decisionIndex"] = 18
	released_due["turn"] = 18
	released_due["currentCardId"] = "breakthrough_arrival"
	released_due["realmTransition"] = {"status": "arrival_pending"}
	if not game._ghost_debt_flow.settle(inheritance_due, released_due,
			game._delivery_eligible_for_tick(inheritance_due, released_due)) \
			or released_due["marketState"]["debts"][0]["status"] != "DUE" \
			or not released_due.has("pendingGhostDebtId"):
		return _fail("deferred ghost debt did not queue after inheritance")
	var forged_due: Dictionary = released_due.duplicate(true)
	forged_due["marketState"]["debts"][0]["acquiredInstanceId"] = "tr:forged"
	if not game._ghost_debt_flow.due_card(forged_due).is_empty():
		return _fail("forged due debt projected a playable card")
	var instance_id := String(pending["instanceId"])
	if not replay.resolve_vendor_loadout("equip", replay.issue_choice_token()) \
			or replay.state.get("equipment", {}).get("weapon") != instance_id \
			or replay.state.get("pendingLoadoutDecision") != null:
		return _fail("purchased ghost oath sword did not resolve into worn loadout")
	var equipped: Dictionary = replay.state.duplicate(true)
	var equipped_reload = Domain.new(Registry.new(), RunSession.new(path, "slot_3"), "slot_3")
	_stabilize_ambient(equipped_reload)
	if not equipped_reload.restore() or not _same(equipped_reload.state, equipped):
		return _fail("ghost oath loadout did not strictly replay")
	if not equipped_reload.close_vendor(equipped_reload.issue_choice_token()):
		return _fail("completed ghost oath session could not leave safely")
	if equipped_reload.state.get("phase") != "DESTINY_WHEEL_PENDING" \
			or equipped_reload.state.get("wheelReturn", {}).get("phase") != \
				"VENDOR_RESULT_PENDING" \
			or equipped_reload.state.get("pendingVendorResultCard", {}).get(
				"title") != "鬼市 · 契约已成" \
			or equipped_reload.state.get("marketState", {}).get(
				"visitHistory", []).back().get("outcome") != "traded":
		return _fail("ghost oath exit did not settle traded visit under due wheel")
	var closed: Dictionary = equipped_reload.state.duplicate(true)
	var closed_reload = Domain.new(Registry.new(), RunSession.new(path, "slot_3"), "slot_3")
	_stabilize_ambient(closed_reload)
	if not closed_reload.restore() or not _same(closed_reload.state, closed) \
			or not closed_reload.choose("left", closed_reload.issue_choice_token()) \
			or closed_reload.get_current_card().get("title") != "鬼市 · 契约已成":
		return _fail("ghost oath exit and deferred result did not strictly replay")
	if not closed_reload.choose("right", closed_reload.issue_choice_token()):
		return _fail("ghost oath result did not dismiss")
	while int(closed_reload.state.get("runClock", {}).get("decisionIndex", 0)) < 17:
		if closed_reload.state.get("phase") == "FLOW_PENDING" and not closed_reload.resume_flow():
			return _fail("ghost oath route stopped before debt came due")
		var direction := "right" if closed_reload.can_choose_direction("right") else "left"
		if not closed_reload.can_choose_direction(direction) \
				or not closed_reload.choose(direction, closed_reload.issue_choice_token()):
			return _fail("ghost oath route could not advance at %s" % closed_reload.get_current_card().get("id"))
	if not closed_reload.state.has("pendingGhostDebtId"):
		return _fail("source ghost debt did not become due at core decision 17: %s %s" % [closed_reload.state.get("phase"), closed_reload.state.get("runClock", {}).get("decisionIndex")])
	if not closed_reload.resume_flow() or closed_reload.get_current_card().get(
			"type") != "GHOST_DEBT_DUE" or not closed_reload.can_choose_direction(
			"left") or not closed_reload.can_choose_direction("right"):
		return _fail("due ghost debt did not preempt the next story card")
	if String(closed_reload.get_current_card().get("description", "")).contains(
			"胜利中催近债期"):
		return _fail("ghost debt card claims an unimplemented victory pressure")
	var due_state: Dictionary = closed_reload.state.duplicate(true)
	var due_reload = Domain.new(Registry.new(), RunSession.new(path, "slot_3"), "slot_3")
	_stabilize_ambient(due_reload)
	if not due_reload.restore() or not _same(due_reload.state, due_state):
		return _fail("due ghost debt card did not strictly replay")
	var due_bytes := FileAccess.get_file_as_string(due_reload._store.v2_path)
	var due_token: int = due_reload.issue_choice_token()
	due_reload._store.fail_promotion_once = true
	if due_reload.choose("left", due_token) or not _same(due_reload.state,
			due_state) or FileAccess.get_file_as_string(
			due_reload._store.v2_path) != due_bytes:
		return _fail("failed ghost debt settlement changed state or saved bytes")
	var paid: bool = due_reload.choose("left", due_token)
	if not paid or due_reload.state.get(
			"marketState", {}).get("debts", [])[0].get("status") != "SETTLED" \
			or int(due_reload.state.get("resources", {}).get("spiritStone", -1)) != \
			int(due_state.get("resources", {}).get("spiritStone", -1)) - 2:
		return _fail("ghost debt did not settle once for the source 2-stone balance: paid=%s available=%s card=%s saved=%s" % [str(paid), str(due_reload._ghost_debt_flow.choice_available(due_reload.state, "left")), str(due_reload._ghost_debt_flow.due_card(due_reload.state)), str(due_reload.state.get("pendingGhostDebtCard", {}))])
	var settled: Dictionary = due_reload.state.duplicate(true)
	var settled_reload = Domain.new(Registry.new(), RunSession.new(path, "slot_3"), "slot_3")
	_stabilize_ambient(settled_reload)
	if not settled_reload.restore() or not _same(settled_reload.state, settled):
		return _fail("settled ghost debt did not strictly replay")
	var default_path := "user://tests/ghost_default_%d.json" % Time.get_ticks_usec()
	var default_store = RunSession.new(default_path, "slot_3")
	var branch_file := FileAccess.open(default_store.v2_path, FileAccess.WRITE)
	if branch_file == null:
		return _fail("ghost debt default branch could not copy an authentic due checkpoint")
	branch_file.store_string(due_bytes)
	branch_file.close()
	var default_game = Domain.new(Registry.new(), default_store, "slot_3")
	_stabilize_ambient(default_game)
	if not default_game.restore() or not _same(default_game.state, due_state) \
			or not default_game.choose("right", default_game.issue_choice_token()):
		return _fail("authentic ghost debt default branch could not settle")
	if default_game.state.get("marketState", {}).get("ghostMarketAccess") != "revoked" \
			or default_game.state.get("marketState", {}).get("debts", [])[0].get(
				"status") != "DEFAULTED" \
			or default_game.state.get("resources", {}).get("spiritStone") != due_state.get(
				"resources", {}).get("spiritStone"):
		return _fail("ghost debt default did not revoke access without charging stones")
	var default_done: Dictionary = default_game.state.duplicate(true)
	var default_reload = Domain.new(Registry.new(), RunSession.new(default_path, "slot_3"), "slot_3")
	_stabilize_ambient(default_reload)
	if not default_reload.restore() or not _same(default_reload.state, default_done):
		return _fail("defaulted ghost debt did not strictly replay")
	var unaffordable: Dictionary = due_state.duplicate(true)
	unaffordable["resources"]["spiritStone"] = 0
	if default_game._ghost_debt_flow.choice_available(unaffordable, "left") \
			or not default_game._ghost_debt_flow.choice_available(unaffordable, "right"):
		return _fail("unaffordable ghost debt allowed free settlement")
	print("NONCOMBAT_GHOST_OATH_PURCHASE_PASS natural=true atomic=true loadout=true settle=true default=true replay=true")
	quit(0)
