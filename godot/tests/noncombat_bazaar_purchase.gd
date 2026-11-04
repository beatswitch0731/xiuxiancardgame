extends "res://tests/noncombat_bazaar_vendor.gd"

const LegacyFragmentFlow = preload("res://scripts/noncombat_legacy_fragment_flow.gd")

func _run() -> void:
	var path := "user://tests/bazaar_purchase_%d.json" % Time.get_ticks_usec()
	var store = RunSession.new(path, "slot_3")
	var game = Domain.new(Registry.new(), store, "slot_3")
	game._market_flow.roll_override = 0.0
	game._destiny_wheel_flow.roll_override = 0.0
	if not game.start("sword") or not _reach_bazaar(game) \
			or not game.choose("left", game.issue_choice_token()):
		return _fail("real source route did not open vendor for purchase")
	var before: Dictionary = game.state.duplicate(true)
	var before_bytes := FileAccess.get_file_as_string(store.v2_path)
	if not game.has_method("purchase_vendor_offer"):
		return _fail("source healing offer has no purchase command")
	var no_money: Dictionary = before.duplicate(true)
	no_money["resources"]["spiritStone"] = 3
	if not game._vendor_flow.purchase_offer(no_money, "bazaar_han_healing").is_empty():
		return _fail("source healing offer accepted insufficient spirit stones")
	var capped: Dictionary = before.duplicate(true)
	var health_cap: int = LegacyFragmentFlow.actual_max_health(capped)
	capped["attributes"]["health"] = health_cap - 1
	var capped_result: Dictionary = game._vendor_flow.purchase_offer(
		capped, "bazaar_han_healing")
	if capped_result.is_empty() or capped_result.get("attributes", {}).get("health") != health_cap:
		return _fail("healing purchase exceeded or missed source health cap")
	var token: int = game.issue_choice_token()
	store.fail_promotion_once = true
	if game.purchase_vendor_offer("bazaar_han_healing", token) \
			or not _same(game.state, before) \
			or FileAccess.get_file_as_string(store.v2_path) != before_bytes:
		return _fail("failed healing purchase changed money/health/stock or save")
	if not game.purchase_vendor_offer("bazaar_han_healing", token) \
			or game.purchase_vendor_offer("bazaar_han_healing", game.issue_choice_token()):
		return _fail("healing purchase failed or repeated")
	var purchased: Dictionary = game.state.duplicate(true)
	var session: Dictionary = purchased.get("marketState", {}).get("activeSession", {})
	if purchased.get("runClock", {}).get("decisionIndex") != 21 \
			or purchased.get("resources", {}).get("spiritStone") != 10 \
			or purchased.get("attributes", {}).get("health") != 3 \
			or session.get("summary", {}).get("purchaseCount") != 1 \
			or session.get("summary", {}).get("spiritStoneSpent") != 4 \
			or session.get("immutableOffers", []).size() != 3:
		return _fail("healing purchase differs from browser offer trace")
	var replay = Domain.new(Registry.new(), RunSession.new(path, "slot_3"), "slot_3")
	replay._market_flow.roll_override = 0.0
	replay._destiny_wheel_flow.roll_override = 0.0
	if not replay.restore() or not _same(replay.state, purchased):
		return _fail("open purchased session did not strictly replay")
	if not replay.close_vendor(replay.issue_choice_token()):
		return _fail("purchased vendor could not close")
	var visit: Dictionary = replay.state.get("marketState", {}).get("visitHistory", []).back()
	if replay.state.get("runClock", {}).get("decisionIndex") != 22 \
			or visit.get("outcome") != "traded" or visit.get("refused") != false \
			or visit.get("missedOffers", []).size() != 3 \
			or replay.get_current_card().get("description") != \
				"你完成 1 笔交易，并与 0 位摊主留下来往。花费 4 灵石；摊主会记得。":
		return _fail("purchased vendor result/visit differs from browser")
	var closed: Dictionary = replay.state.duplicate(true)
	var closed_replay = Domain.new(Registry.new(), RunSession.new(path, "slot_3"), "slot_3")
	closed_replay._market_flow.roll_override = 0.0
	closed_replay._destiny_wheel_flow.roll_override = 0.0
	if not closed_replay.restore() or not _same(closed_replay.state, closed):
		return _fail("closed purchased vendor did not strictly replay")
	# Retained purchase inputs must survive the source visit-history cap; a
	# later replay still needs the early stone debit and healing command.
	var long_market: Dictionary = before.duplicate(true)
	long_market["phase"] = "MARKET_PENDING"
	long_market["currentCardId"] = "bazaar_encounter"
	long_market["pendingMarketChoiceCard"] = before["marketState"]["activeSession"]["card"]
	long_market["marketState"]["activeSession"] = null
	long_market["turn"] = 48
	long_market["runClock"]["decisionIndex"] = 48
	long_market["marketState"]["vendorRelations"] = {"han_peddler": 48}
	long_market["marketActionHistory"] = []
	for decision in range(1, 49):
		var prior_key := "vendor:%s:%d:bazaar_encounter:public_bazaar" % [
			long_market["runClock"]["lifeId"], decision]
		long_market["marketState"]["visitHistory"].append({"sessionKey": prior_key,
			"vendorId": "public_bazaar", "marketType": "public_bazaar",
			"decisionIndex": decision, "seen": true,
			"outcome": "traded" if decision == 1 else "interacted"})
		long_market["marketActionHistory"].append({"sessionKey": prior_key,
			"actionId": "assist_han"})
	long_market["marketPurchaseHistory"] = [{"sessionKey":
		long_market["marketState"]["visitHistory"][0]["sessionKey"],
		"offerId": "bazaar_han_healing"}]
	var long_open: Dictionary = game._vendor_flow.open(long_market)
	var long_closed: Dictionary = game._vendor_flow.close(long_open)
	if long_closed.is_empty():
		return _fail("49th vendor close rejected source-valid old purchase history")
	if long_closed.get("marketPurchaseHistory", []).size() != 1:
		return _fail("49th vendor visit discarded purchased replay input")
	long_closed["phase"] = "MARKET_PENDING"
	long_closed["currentCardId"] = "bazaar_encounter"
	long_closed["marketState"]["activeSession"] = null
	long_closed["pendingMarketChoiceCard"] = game._market_flow._bazaar_card("洞府", "qi")
	var after_prune: Dictionary = game._vendor_flow.open(long_closed)
	if after_prune.is_empty() or game._vendor_flow.available_offers(after_prune).is_empty():
		return _fail("retained purchase history rejected next source vendor session")
	var ui_audio_settings := "user://tests/bazaar_purchase_audio_%d.cfg" % Time.get_ticks_usec()
	var ui_slot_root := "user://tests/bazaar_purchase_slots_%d_%d" % [
		OS.get_process_id(), Time.get_ticks_usec()]
	var ui: Control = load("res://scenes/noncombat_opening.tscn").instantiate()
	ui.slot_root_path = ui_slot_root
	ui.audio_settings_path = ui_audio_settings
	root.add_child(ui)
	await process_frame
	var slots: Control = ui.get_node("DesktopMargin/ScreenStack/SlotSelection")
	(slots.get_node("Slot_slot_1") as Button).pressed.emit()
	await process_frame
	ui.opening._market_flow.roll_override = 0.0
	ui.opening._destiny_wheel_flow.roll_override = 0.0
	if not ui.opening.start("sword") or not _reach_bazaar(ui.opening) \
			or not ui.opening.choose("left", ui.opening.issue_choice_token()):
		return _fail("desktop purchase route did not open")
	await process_frame
	var row: HBoxContainer = ui.get_node("DesktopMargin/ScreenStack/StoryScreen/SourceChoices")
	var body: Label = ui.body_label
	var buy: Button = row.get_node_or_null("VendorBuy_bazaar_han_healing")
	if buy == null or buy.disabled:
		return _fail("desktop purchase button missing or disabled")
	var market_audio: Node = ui.opening_audio.market_audio
	if not market_audio.ambience_player.playing \
			or market_audio.ambience_player.get_meta("ambience_id", "") != "amb_market_bazaar" \
			or market_audio.transaction_player.playing:
		return _fail("bazaar UI did not enter the source ambience without a purchase cue: phase=%s profile=%s playing=%s id=%s tx=%s" % [
			ui.opening.state.get("phase"), ui.opening.state.get("marketState", {}).get(
				"activeSession", {}).get("presentationProfile", {}),
			market_audio.ambience_player.playing,
			market_audio.ambience_player.get_meta("ambience_id", ""),
			market_audio.transaction_player.playing])
	buy.pressed.emit()
	await process_frame
	if ui.opening.state.get("resources", {}).get("spiritStone") != 10 \
			or row.get_node_or_null("VendorBuy_bazaar_han_healing") != null \
			or body.text.contains("行脚回春散"):
		return _fail("desktop purchase did not refresh source stock and resources")
	if not market_audio.transaction_player.playing \
			or not market_audio.ambience_player.playing:
		return _fail("committed bazaar purchase missed its transaction cue or ambience")
	(ui.get_node("DesktopMargin/ScreenStack/StoryScreen/ReturnToSlots") as Button).pressed.emit()
	await process_frame
	if not slots.visible or market_audio.ambience_player.playing:
		return _fail("returning to the slot menu left bazaar ambience playing")
	ui.queue_free()
	await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(ui_audio_settings))
	print("NONCOMBAT_BAZAAR_PURCHASE_PASS buy=true replay=true close=true rollback=true ui=true")
	quit(0)
