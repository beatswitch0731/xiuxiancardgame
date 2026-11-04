extends "res://tests/noncombat_bazaar_vendor.gd"

func _run() -> void:
	var path := "user://tests/bazaar_rusted_sword_%d.json" % Time.get_ticks_usec()
	var store = RunSession.new(path, "slot_3")
	var game = Domain.new(Registry.new(), store, "slot_3")
	game._market_flow.roll_override = 0.0
	game._destiny_wheel_flow.roll_override = 0.0
	if not game.start("sword") or not _reach_bazaar(game) \
			or not game.choose("left", game.issue_choice_token()):
		return _fail("real route did not open bazaar for traded sword")
	var token: int = game.issue_choice_token()
	if game.purchase_vendor_offer("bazaar_luo_traded_rusted_sword", token, "favor"):
		return _fail("unearned favor purchased the traded sword")
	if not game.perform_vendor_action("assist_luo", token):
		return _fail("source favor interaction unavailable")
	token = game.issue_choice_token()
	var before: Dictionary = game.state.duplicate(true)
	var before_bytes := FileAccess.get_file_as_string(store.v2_path)
	store.fail_promotion_once = true
	if game.purchase_vendor_offer("bazaar_luo_traded_rusted_sword", token, "favor") \
			or not _same(game.state, before) \
			or FileAccess.get_file_as_string(store.v2_path) != before_bytes:
		return _fail("failed traded-sword purchase changed save or item ledger")
	if not game.purchase_vendor_offer("bazaar_luo_traded_rusted_sword", token, "favor"):
		return _fail("valid favor trade unavailable")
	var bought: Dictionary = game.state.duplicate(true)
	var session: Dictionary = bought.get("marketState", {}).get("activeSession", {})
	var instances: Dictionary = bought.get("treasureInstances", {})
	var fact: Dictionary = bought.get("noncombatFlow", {}).get("spineFacts", {}).get(
		"fact:0:sword_origin_traded", {})
	var pending: Dictionary = bought.get("pendingLoadoutDecision", {})
	if bought.get("runClock", {}).get("decisionIndex") != 21 \
			or bought.get("resources", {}).get("spiritStone") != 8 \
			or session.get("immutableOffers", []).size() != 3 \
			or session.get("summary", {}).get("purchaseCount") != 1 \
			or session.get("summary", {}).get("spiritStoneSpent") != 6 \
			or not instances.has("tr:traded_rusted_sword:1") \
			or fact.get("factTypeId") != "sword_origin_traded" \
			or fact.get("payload", {}).get("exchangeMode") != "favor" \
			or pending.get("instanceId") != "tr:traded_rusted_sword:1":
		return _fail("favor purchase missed source money/instance/fact/loadout")
	if game.purchase_vendor_offer("bazaar_luo_traded_rusted_sword",
			game.issue_choice_token(), "favor"):
		return _fail("duplicate favor purchase acquired a second instance")
	var stashed: Dictionary = game._vendor_flow.resolve_loadout(bought, "stash")
	if stashed.is_empty() or stashed.get("pendingLoadoutDecision") != null \
			or not stashed.get("treasureInventory", []).has("tr:traded_rusted_sword:1") \
			or stashed.get("equipment", {}).get("weapon") != null:
		return _fail("stash did not keep the owned instance unequipped")
	var replay = Domain.new(Registry.new(), RunSession.new(path, "slot_3"), "slot_3")
	replay._market_flow.roll_override = 0.0
	replay._destiny_wheel_flow.roll_override = 0.0
	if not replay.restore() or not _same(replay.state, bought):
		return _fail("purchased traded sword did not strictly replay")
	if not replay.close_vendor(replay.issue_choice_token()) \
			or replay.state.get("phase") != "VENDOR_RESULT_PENDING" \
			or replay.state.get("pendingLoadoutDecision", {}).get("instanceId") \
			!= "tr:traded_rusted_sword:1":
		return _fail("closing vendor lost the source pending loadout decision")
	var closed_pending: Dictionary = replay.state.duplicate(true)
	var replay_pending = Domain.new(Registry.new(), RunSession.new(path, "slot_3"), "slot_3")
	replay_pending._market_flow.roll_override = 0.0
	replay_pending._destiny_wheel_flow.roll_override = 0.0
	if not replay_pending.restore() or not _same(replay_pending.state, closed_pending):
		return _fail("closed vendor did not restore pending loadout")
	var loadout_bytes := FileAccess.get_file_as_string(store.v2_path)
	var loadout_token: int = replay_pending.issue_choice_token()
	replay_pending._store.fail_promotion_once = true
	if replay_pending.resolve_vendor_loadout("equip", loadout_token) \
			or not _same(replay_pending.state, closed_pending) \
			or FileAccess.get_file_as_string(store.v2_path) != loadout_bytes:
		return _fail("failed equip changed pending, ownership or save")
	if not replay_pending.resolve_vendor_loadout("equip", loadout_token) \
			or replay_pending.resolve_vendor_loadout("equip", replay_pending.issue_choice_token()) \
			or replay_pending.state.get("equipment", {}).get("weapon") != "tr:traded_rusted_sword:1" \
			or replay_pending.state.get("pendingLoadoutDecision") != null \
			or replay_pending.state.get("treasureInventory", []).has("tr:traded_rusted_sword:1"):
		return _fail("equip failed, repeated or left owned sword in inventory")
	var equipped: Dictionary = replay_pending.state.duplicate(true)
	var replay_equipped = Domain.new(Registry.new(), RunSession.new(path, "slot_3"), "slot_3")
	replay_equipped._market_flow.roll_override = 0.0
	replay_equipped._destiny_wheel_flow.roll_override = 0.0
	if not replay_equipped.restore() or not _same(replay_equipped.state, equipped) \
			or equipped.get("marketState", {}).get("visitHistory", []).back().get("outcome") != "traded":
		return _fail("closed traded-sword result lost equipment or visit")
	var unbought_closed: Dictionary = game._vendor_flow.close(before)
	var unbought_dismissed: Dictionary = game._vendor_flow.dismiss(unbought_closed)
	if unbought_dismissed.is_empty():
		return _fail("remembered favor setup could not close and dismiss")
	var later: Dictionary = unbought_dismissed.duplicate(true)
	later["phase"] = "MARKET_PENDING"
	later["currentCardId"] = "bazaar_encounter"
	later["runClock"]["decisionIndex"] = 23
	later["turn"] = 23
	later["pendingMarketChoiceCard"] = game._market_flow._bazaar_card("洞府", "qi")
	var remembered: Dictionary = game._vendor_flow.open(later)
	var remembered_offer: Dictionary = {}
	for item in remembered.get("marketState", {}).get("activeSession", {}).get(
			"immutableOffers", []):
		if item.get("id") == "bazaar_luo_traded_rusted_sword":
			remembered_offer = item
			break
	if remembered_offer.get("price") != 5:
		return _fail("remembered favor did not discount display price to five")
	var remembered_bought: Dictionary = game._vendor_flow.purchase_offer(remembered,
		"bazaar_luo_traded_rusted_sword", "favor")
	if remembered_bought.is_empty() \
			or remembered_bought.get("resources", {}).get("spiritStone") != 8 \
			or remembered_bought.get("marketState", {}).get("activeSession", {}).get(
				"summary", {}).get("spiritStoneSpent") != 6 \
			or game._vendor_flow.available_offers(remembered).filter(func(item):
				return item.get("id") == "bazaar_luo_traded_rusted_sword")[0].get("price") != 6:
		return _fail("remembered favor trade did not charge authored six stones")
	var ui: Control = load("res://scenes/noncombat_opening.tscn").instantiate()
	ui.save_path = ""
	root.add_child(ui)
	await process_frame
	ui.opening._market_flow.roll_override = 0.0
	ui.opening._destiny_wheel_flow.roll_override = 0.0
	if not ui.opening.start("sword") or not _reach_bazaar(ui.opening) \
			or not ui.opening.choose("left", ui.opening.issue_choice_token()):
		return _fail("desktop traded-sword path did not open")
	await process_frame
	var row: HBoxContainer = ui.get_node("DesktopMargin/ScreenStack/StoryScreen/SourceChoices")
	var sword_button: Button = row.get_node_or_null(
		"VendorBuy_bazaar_luo_traded_rusted_sword")
	if sword_button == null or not sword_button.disabled:
		return _fail("desktop favor purchase ignored relation prerequisite")
	(row.get_node("VendorAction_assist_luo") as Button).pressed.emit()
	await process_frame
	sword_button = row.get_node_or_null("VendorBuy_bazaar_luo_traded_rusted_sword")
	if sword_button == null or sword_button.disabled:
		return _fail("desktop favor purchase stayed locked after relation action")
	sword_button.pressed.emit()
	await process_frame
	var equip_button: Button = row.get_node_or_null("VendorLoadout_equip")
	if equip_button == null or row.get_node_or_null(
			"VendorBuy_bazaar_luo_traded_rusted_sword") != null:
		return _fail("desktop purchase did not show pending equip decision")
	(row.get_node("VendorClose") as Button).pressed.emit()
	await process_frame
	equip_button = row.get_node_or_null("VendorLoadout_equip")
	if ui.opening.state.get("phase") != "VENDOR_RESULT_PENDING" \
			or equip_button == null:
		return _fail("desktop close lost the still-pending loadout decision")
	equip_button.pressed.emit()
	await process_frame
	if ui.opening.state.get("equipment", {}).get("weapon") != "tr:traded_rusted_sword:1" \
			or row.get_node_or_null("VendorLoadout_equip") != null:
		return _fail("desktop equip did not update owned instance")
	print("NONCOMBAT_BAZAAR_RUSTED_SWORD_PASS buy=true fact=true loadout=true replay=true rollback=true ui=true")
	quit(0)
