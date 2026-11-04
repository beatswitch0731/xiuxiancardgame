extends "res://tests/noncombat_bazaar_vendor.gd"

func _run() -> void:
	var path := "user://tests/bazaar_ask_luo_%d.json" % Time.get_ticks_usec()
	var store = RunSession.new(path, "slot_3")
	var game = Domain.new(Registry.new(), store, "slot_3")
	game._market_flow.roll_override = 0.0
	game._destiny_wheel_flow.roll_override = 0.0
	if not game.start("sword") or not _reach_bazaar(game) \
			or not game.choose("left", game.issue_choice_token()):
		return _fail("real source route did not open Luo's stall")
	var offer: Array = game._vendor_flow.available_actions(game.state).filter(func(row):
		return row.get("id") == "ask_luo")
	if offer.size() != 1 or not offer[0].get("enabled", false):
		return _fail("source ask_luo action was absent or disabled")
	var before: Dictionary = game.state.duplicate(true)
	var poor: Dictionary = before.duplicate(true)
	poor["resources"]["spiritStone"] = 0
	if not game._vendor_flow.interact(poor, "ask_luo").is_empty():
		return _fail("source paid inquiry succeeded without one spirit stone")
	var before_bytes := FileAccess.get_file_as_string(store.v2_path)
	var token: int = game.issue_choice_token()
	store.fail_promotion_once = true
	if game.perform_vendor_action("ask_luo", token) \
			or not _same(game.state, before) \
			or FileAccess.get_file_as_string(store.v2_path) != before_bytes:
		return _fail("failed fact purchase changed save, money or relation")
	if not game.perform_vendor_action("ask_luo", token):
		return _fail("source fact action did not commit")
	var asked: Dictionary = game.state.duplicate(true)
	var session: Dictionary = asked.get("marketState", {}).get("activeSession", {})
	var fact_id := "fact:0:rumor_rusted_sword_origin"
	var fact: Dictionary = asked.get("noncombatFlow", {}).get("spineFacts", {}).get(fact_id, {})
	var receipt: Dictionary = session.get("actionReceipts", {}).get("ask_luo", {})
	if asked.get("runClock", {}).get("decisionIndex") != 21 \
			or asked.get("resources", {}).get("spiritStone") != 13 \
			or asked.get("marketState", {}).get("vendorRelations", {}).get("luo_trader") != 1 \
			or session.get("interactionBudget", {}).get("remaining") != 1 \
			or session.get("summary", {}).get("interactionCount") != 1 \
			or session.get("summary", {}).get("spiritStoneSpent") != 0 \
			or receipt.get("factInstanceId") != fact_id \
			or receipt.get("costSpec", [])[0].get("amount") != 1 \
			or fact.get("producerId") != "bazaar_xu_rusted_origin" \
			or fact.get("payload", {}).get("ledgerNo") != "许摊·锈铁流转抄本" \
			or fact.get("createdDecisionIndex") != 22:
		return _fail("ask_luo did not match source cost, fact and interaction receipt")
	if game.perform_vendor_action("ask_luo", game.issue_choice_token()):
		return _fail("same-session duplicate causal action committed")
	var combined: Dictionary = game._vendor_flow.purchase_offer(asked,
		"bazaar_luo_traded_rusted_sword", "favor")
	if combined.is_empty() or combined.get("resources", {}).get("spiritStone") != 7 \
			or not combined.get("noncombatFlow", {}).get("spineFacts", {}).has(
				"fact:0:sword_origin_traded") \
			or not combined.get("noncombatFlow", {}).get("spineFacts", {}).has(fact_id):
		return _fail("paid origin inquiry failed to authorize later favor purchase")
	var reopened = Domain.new(Registry.new(), RunSession.new(path, "slot_3"), "slot_3")
	reopened._market_flow.roll_override = 0.0
	reopened._destiny_wheel_flow.roll_override = 0.0
	if not reopened.restore() or not _same(reopened.state, asked) \
			or not reopened.close_vendor(reopened.issue_choice_token()):
		return _fail("causal action did not strictly replay or close")
	var closed: Dictionary = reopened.state.duplicate(true)
	if closed.get("marketState", {}).get("visitHistory", []).back().get("outcome") != "interacted" \
			or closed.get("resources", {}).get("spiritStone") != 13 \
			or not reopened.choose("right", reopened.issue_choice_token()):
		return _fail("source ask_luo visit or result dismissal mismatched")
	var dismissed: Dictionary = reopened.state.duplicate(true)
	var later: Dictionary = dismissed.duplicate(true)
	later["phase"] = "MARKET_PENDING"
	later["currentCardId"] = "bazaar_encounter"
	later["runClock"]["decisionIndex"] = 23
	later["turn"] = 23
	later["pendingMarketChoiceCard"] = reopened._market_flow._bazaar_card("洞府", "qi")
	var remembered: Dictionary = reopened._vendor_flow.open(later)
	if remembered.is_empty() or not reopened._vendor_flow.interact(remembered,
			"ask_luo").is_empty():
		return _fail("same-life fact could be purchased again on next visit")
	var ui: Control = load("res://scenes/noncombat_opening.tscn").instantiate()
	ui.save_path = ""
	root.add_child(ui)
	await process_frame
	ui.opening._market_flow.roll_override = 0.0
	ui.opening._destiny_wheel_flow.roll_override = 0.0
	if not ui.opening.start("sword") or not _reach_bazaar(ui.opening) \
			or not ui.opening.choose("left", ui.opening.issue_choice_token()):
		return _fail("desktop real route did not open Luo's stall")
	await process_frame
	var row: HBoxContainer = ui.get_node("DesktopMargin/ScreenStack/StoryScreen/SourceChoices")
	var button: Button = row.get_node_or_null("VendorAction_ask_luo")
	if button == null or button.disabled:
		return _fail("desktop source ask_luo button missing")
	button.pressed.emit()
	await process_frame
	if ui.opening.state.get("resources", {}).get("spiritStone") != 13 \
			or ui.opening.state.get("noncombatFlow", {}).get("spineFacts", {}).get(
				fact_id, {}).get("factTypeId") != "rumor_rusted_sword_origin":
		return _fail("desktop ask_luo button did not commit source transaction")
	print("NONCOMBAT_BAZAAR_ASK_LUO_PASS cost=true fact=true replay=true rollback=true ui=true")
	quit(0)
