extends "res://tests/noncombat_market_arrival.gd"

func _run() -> void:
	var path := "user://tests/ghost_entry_%d.json" % Time.get_ticks_usec()
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
			return _fail("spell route stopped before ghost card")
		var id := String(game.state.get("phase")) if step[0] == "COMBAT_HANDOFF" \
			else String(game.get_current_card().get("id", ""))
		if id != step[0] or not game.choose(step[1], game.issue_choice_token()):
			return _fail("spell route diverged at %s -> %s" % [str(step), id])
	if not game.resume_flow() or game.get_current_card().get("id") != "market_encounter":
		return _fail("natural ghost entry card did not appear")
	var due: Dictionary = game.state.duplicate(true)
	var due_bytes := FileAccess.get_file_as_string(game._store.v2_path)
	var token: int = game.issue_choice_token()
	if not game.can_choose_direction("left"):
		return _fail("night-window ghost entry remained closed")
	game._store.fail_promotion_once = true
	if game.choose("left", token) or not _same(game.state, due) \
			or FileAccess.get_file_as_string(game._store.v2_path) != due_bytes:
		return _fail("failed ghost entry changed memory or save bytes")
	if not game.choose("left", token) or game.state.get("phase") != "VENDOR_OPEN":
		return _fail("ghost left choice did not open a durable session")
	var session: Dictionary = game.state.get("marketState", {}).get("activeSession", {})
	if session.get("vendorId") != "ghost_market" \
			or session.get("entryCardId") != "market_encounter" \
			or session.get("immutableOffers", []).is_empty() \
			or session.get("immutableOffers", [])[0].get("id") != "ghost_oath_rusted_sword" \
			or game.get_current_card().get("title") != "鬼市契约进行中" \
			or game.vendor_offers().is_empty():
		return _fail("ghost session did not freeze the source contracts and offers")
	if session.get("vendorMeta", {}).get("fortune") != game.state.get(
			"attributes", {}).get("fortune") \
			or not session.get("vendorMeta", {}).get("ghostMarkupRange") is Dictionary:
		return _fail("ghost session lost the source fortune or markup header")
	var open_state: Dictionary = game.state.duplicate(true)
	var opened = Domain.new(Registry.new(), RunSession.new(path, "slot_3"), "slot_3")
	_stabilize_ambient(opened)
	if not opened.restore() or not _same(opened.state, open_state):
		return _fail("open ghost session did not strictly replay")
	var ui: Control = load("res://scenes/noncombat_opening.tscn").instantiate()
	ui.save_path = ""
	root.add_child(ui)
	await process_frame
	ui.opening = opened
	ui._render()
	var art: TextureRect = ui.get_node(
		"DesktopMargin/ScreenStack/StoryScreen/SourceContent/SourceSceneImage")
	var buttons: HBoxContainer = ui.get_node(
		"DesktopMargin/ScreenStack/StoryScreen/SourceChoices")
	var contract_button: Button = buttons.get_node_or_null(
		"VendorBuy_ghost_oath_rusted_sword")
	if art.texture == null or contract_button == null \
			or contract_button.disabled or not contract_button.text.contains("寿元") \
			or not ui.body_label.text.contains("通畅") \
			or not ui.body_label.text.contains("灵石物价") \
			or buttons.get_node_or_null("VendorClose") == null:
		return _fail("desktop ghost session omitted source art, contract terms, or safe exit")
	var open_bytes := FileAccess.get_file_as_string(opened._store.v2_path)
	opened._store.fail_promotion_once = true
	if opened.close_vendor(opened.issue_choice_token()) \
			or not _same(opened.state, open_state) \
			or FileAccess.get_file_as_string(opened._store.v2_path) != open_bytes:
		return _fail("failed ghost exit changed memory or save bytes")
	if not opened.close_vendor(opened.issue_choice_token()) \
			or opened.state.get("phase") != "DESTINY_WHEEL_PENDING" \
			or opened.state.get("wheelReturn", {}).get("phase") != "VENDOR_RESULT_PENDING" \
			or opened.state.get("runClock", {}).get("decisionIndex") != 15:
		return _fail("empty ghost exit did not defer the source result under due wheel")
	var wheel: Dictionary = opened.state.duplicate(true)
	var result_reload = Domain.new(Registry.new(), RunSession.new(path, "slot_3"), "slot_3")
	_stabilize_ambient(result_reload)
	if not result_reload.restore() or not _same(result_reload.state, wheel) \
			or not result_reload.choose("left", result_reload.issue_choice_token()) \
			or result_reload.state.get("phase") != "VENDOR_RESULT_PENDING" \
			or result_reload.get_current_card().get("title") != "鬼市 · 雾门合拢":
		return _fail("ghost wheel overlay did not restore the result")
	var result: Dictionary = result_reload.state.duplicate(true)
	var result_restart = Domain.new(Registry.new(), RunSession.new(path, "slot_3"), "slot_3")
	_stabilize_ambient(result_restart)
	if not result_restart.restore() or not _same(result_restart.state, result) \
			or not result_restart.choose("right", result_restart.issue_choice_token()):
		return _fail("ghost result did not strictly replay and dismiss")
	var dismissed: Dictionary = result_restart.state.duplicate(true)
	var final_reload = Domain.new(Registry.new(), RunSession.new(path, "slot_3"), "slot_3")
	_stabilize_ambient(final_reload)
	if not final_reload.restore() or not _same(final_reload.state, dismissed):
		return _fail("dismissed ghost entry did not strictly replay")
	print("NONCOMBAT_GHOST_ENTRY_PASS natural=true open=true exit=true replay=true rollback=true")
	quit(0)
