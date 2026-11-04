extends "res://tests/noncombat_bazaar_vendor.gd"

func _run() -> void:
	var path := "user://tests/bazaar_route_note_%d.json" % Time.get_ticks_usec()
	var store = RunSession.new(path, "slot_3")
	var game = Domain.new(Registry.new(), store, "slot_3")
	game._market_flow.roll_override = 0.0
	game._destiny_wheel_flow.roll_override = 0.0
	if not game.start("sword") or not _reach_bazaar(game) \
			or not game.choose("left", game.issue_choice_token()):
		return _fail("real source route did not open bazaar for route note")
	var offer_found := false
	for offer in game.vendor_offers():
		if offer.get("id") == "bazaar_luo_route_note":
			offer_found = offer.get("supported", false) and offer.get("enabled", false)
	if not offer_found:
		return _fail("source route-note offer unavailable in Godot")
	var opened: Dictionary = game.state.duplicate(true)
	var original_bytes := FileAccess.get_file_as_string(store.v2_path)
	var token: int = game.issue_choice_token()
	store.fail_promotion_once = true
	if game.purchase_vendor_offer("bazaar_luo_route_note", token) \
			or not _same(game.state, opened) \
			or FileAccess.get_file_as_string(store.v2_path) != original_bytes:
		return _fail("failed route-note purchase changed money, item or save")
	if not game.purchase_vendor_offer("bazaar_luo_route_note", token) \
			or game.purchase_vendor_offer("bazaar_luo_route_note", game.issue_choice_token()):
		return _fail("route-note purchase failed or repeated")
	var bought: Dictionary = game.state.duplicate(true)
	var session: Dictionary = bought.get("marketState", {}).get("activeSession", {})
	if bought.get("runClock", {}).get("decisionIndex") != 21 \
			or bought.get("resources", {}).get("spiritStone") != 9 \
			or bought.get("itemInventory", {}).get("商路线索") != 1 \
			or session.get("immutableOffers", []).size() != 3 \
			or session.get("summary", {}).get("spiritStoneSpent") != 5 \
			or session.get("summary", {}).get("purchaseCount") != 1:
		return _fail("route-note purchase differs from browser trace")
	var replay = Domain.new(Registry.new(), RunSession.new(path, "slot_3"), "slot_3")
	replay._market_flow.roll_override = 0.0
	replay._destiny_wheel_flow.roll_override = 0.0
	if not replay.restore() or not _same(replay.state, bought) \
			or not replay.close_vendor(replay.issue_choice_token()):
		return _fail("purchased route note did not replay or close")
	var closed: Dictionary = replay.state.duplicate(true)
	if closed.get("itemInventory", {}).get("商路线索") != 1 \
			or closed.get("marketState", {}).get("visitHistory", []).back().get("outcome") != "traded" \
			or replay.get_current_card().get("description") != \
				"你完成 1 笔交易，并与 0 位摊主留下来往。花费 5 灵石；摊主会记得。":
		return _fail("route-note ownership or visit missing after close")
	var replay_closed = Domain.new(Registry.new(), RunSession.new(path, "slot_3"), "slot_3")
	replay_closed._market_flow.roll_override = 0.0
	replay_closed._destiny_wheel_flow.roll_override = 0.0
	if not replay_closed.restore() or not _same(replay_closed.state, closed):
		return _fail("closed route-note purchase did not strictly replay")
	var ui: Control = load("res://scenes/noncombat_opening.tscn").instantiate()
	ui.save_path = ""
	root.add_child(ui)
	await process_frame
	ui.opening._market_flow.roll_override = 0.0
	ui.opening._destiny_wheel_flow.roll_override = 0.0
	if not ui.opening.start("sword") or not _reach_bazaar(ui.opening) \
			or not ui.opening.choose("left", ui.opening.issue_choice_token()):
		return _fail("desktop route-note purchase path did not open")
	await process_frame
	var row: HBoxContainer = ui.get_node("DesktopMargin/ScreenStack/StoryScreen/SourceChoices")
	var button: Button = row.get_node_or_null("VendorBuy_bazaar_luo_route_note")
	if button == null or button.disabled:
		return _fail("desktop route-note purchase button unavailable")
	button.pressed.emit()
	await process_frame
	if ui.opening.state.get("itemInventory", {}).get("商路线索") != 1 \
			or row.get_node_or_null("VendorBuy_bazaar_luo_route_note") != null \
			or not ui.body_label.text.contains("随身物品：商路线索×1"):
		return _fail("desktop route-note purchase did not refresh ownership/stock")
	print("NONCOMBAT_BAZAAR_STORY_ITEM_PASS buy=true item=true replay=true rollback=true ui=true")
	quit(0)
