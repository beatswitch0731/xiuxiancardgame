extends "res://tests/noncombat_market_arrival.gd"

func _run() -> void:
	var path := "user://tests/ghost_choice_%d.json" % Time.get_ticks_usec()
	var game = Domain.new(Registry.new(), RunSession.new(path, "slot_3"), "slot_3")
	_stabilize_ambient(game)
	var checkpoint := {}
	if not game.start("sword") or not _reach_sect_result(game, checkpoint):
		return _fail("real route did not reach the ghost arrival checkpoint")
	var due: Dictionary = checkpoint.get("state", {})
	if due.get("pendingGhostPlan", {}).get("card") != due.get("pendingMarketCard"):
		return _fail("ghost arrival was not source frozen")
	var presented: Dictionary = game._market_flow.resume(due)
	if presented.get("phase") != "MARKET_PENDING" \
			or presented.get("currentCardId") != "market_encounter" \
			or presented.get("pendingMarketChoiceCard") != due.get("pendingMarketCard") \
			or not presented.has("pendingGhostPlan"):
		return _fail("source ghost arrival did not become an authentic pending choice")
	if not game._market_flow.choice_available(presented, "right") \
			or not game._market_flow.choice_available(presented, "left"):
		return _fail("night-window ghost choice did not admit both source directions")
	var day: Dictionary = presented.duplicate(true)
	day["runClock"]["decisionIndex"] = 15
	if game._market_flow.choice_available(day, "left") \
			or not game._market_flow.choice_available(day, "right"):
		return _fail("ghost entry bypassed next-decision night requirement")
	var physical_lead: Dictionary = presented.duplicate(true)
	physical_lead["attributes"]["fortune"] = 0
	physical_lead["attributes"]["karmaBad"] = 0
	physical_lead["marketState"]["ghostMarketLead"] = false
	physical_lead["itemInventory"] = {"鬼市路引": 1}
	if not game._market_flow.choice_available(physical_lead, "left"):
		return _fail("authored ghost route item did not satisfy the source signal")
	var delayed: Dictionary = presented.duplicate(true)
	delayed["attributes"]["fortune"] = 10
	delayed["marketState"]["ghostMarketLead"] = true
	delayed["currentLocation"] = "魔域"
	var delayed_open: Dictionary = game._ghost_vendor_flow.open(delayed)
	var delayed_meta: Dictionary = delayed_open.get("marketState", {}).get(
		"activeSession", {}).get("vendorMeta", {})
	if delayed_open.get("phase") != "VENDOR_OPEN" \
			or delayed_meta.get("fortuneTier") != "厄运缠身" \
			or delayed_meta.get("tradeRoute", {}).get("id") != "western_blood_route" \
			or delayed_meta.get("priceMult") != delayed.get(
				"pendingGhostPlan", {}).get("meta", {}).get("priceMultiplier"):
		return _fail("delayed ghost entry did not separate live header from frozen stock price: %s %s %s" % [delayed_open.get("phase"), str(delayed_meta), game._ghost_vendor_flow.last_error])
	var forged: Dictionary = due.duplicate(true)
	forged["pendingGhostPlan"]["sourcePins"]["shops:treasures"] = "0".repeat(64)
	if not game._market_flow.resume(forged).is_empty():
		return _fail("ghost card accepted a forged treasure source pin")
	var old: Dictionary = due.duplicate(true)
	old.erase("pendingGhostPlan")
	old.erase("ghostPlanVersion")
	if not game._market_flow.resume(old).is_empty():
		return _fail("old ghost placeholder was silently promoted")
	var skipped: Dictionary = game._market_flow.settle_skip(presented, "right")
	if skipped.get("phase") != "FLOW_PENDING" \
			or skipped.get("runClock", {}).get("decisionIndex") != int(due.get(
				"runClock", {}).get("decisionIndex", -1)) + 1 \
			or skipped.has("pendingGhostPlan") \
			or skipped.get("choiceHistory", []).back().get("cardId") != "market_encounter":
		return _fail("ghost skip did not settle the source card exactly once")
	var spell_path := "user://tests/ghost_spell_%d.json" % Time.get_ticks_usec()
	var spell = Domain.new(Registry.new(), RunSession.new(spell_path, "slot_3"), "slot_3")
	_stabilize_ambient(spell)
	spell._normal_roll_override = 0.0
	if not spell.start("spell"):
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
		if spell.state.get("phase") == "FLOW_PENDING" and not spell.resume_flow():
			return _fail("natural spell route failed to present next card")
		var id := String(spell.state.get("phase")) if step[0] == "COMBAT_HANDOFF" \
			else String(spell.get_current_card().get("id", ""))
		if id != step[0] or not spell.choose(step[1], spell.issue_choice_token()):
			return _fail("natural spell route diverged at %s -> %s" % [str(step), id])
	if spell.state.get("phase") != "FLOW_PENDING" or not spell.resume_flow() \
			or spell.get_current_card().get("id") != "market_encounter" \
			or spell.state.get("runClock", {}).get("decisionIndex") != 14:
		return _fail("natural spell route did not present the ghost source card")
	var natural_pending: Dictionary = spell.state.duplicate(true)
	var pending_bytes := FileAccess.get_file_as_string(spell._store.v2_path)
	var reload = Domain.new(Registry.new(), RunSession.new(spell_path, "slot_3"), "slot_3")
	_stabilize_ambient(reload)
	if not reload.restore() or not _same(reload.state, natural_pending) \
			or FileAccess.get_file_as_string(reload._store.v2_path) != pending_bytes \
			or not reload.can_choose_direction("left") \
			or not reload.can_choose_direction("right"):
		return _fail("natural ghost pending choice did not strictly replay")
	var ui: Control = load("res://scenes/noncombat_opening.tscn").instantiate()
	ui.save_path = ""
	root.add_child(ui)
	await process_frame
	ui.opening = reload
	ui._render()
	var scene_art: TextureRect = ui.get_node(
		"DesktopMargin/ScreenStack/StoryScreen/SourceContent/SourceSceneImage")
	var choice_row: HBoxContainer = ui.get_node(
		"DesktopMargin/ScreenStack/StoryScreen/SourceChoices")
	if scene_art.texture == null or choice_row.get_node_or_null("Choice_right") == null \
			or choice_row.get_node_or_null("Choice_left") == null \
			or (choice_row.get_node("Choice_left") as Button).disabled:
		return _fail("desktop ghost card lacks source art or night entry controls")
	var natural_token: int = reload.issue_choice_token()
	reload._store.fail_promotion_once = true
	if reload.choose("right", natural_token) or not _same(reload.state,
			natural_pending) or FileAccess.get_file_as_string(
			reload._store.v2_path) != pending_bytes:
		return _fail("failed natural ghost skip changed state or saved bytes")
	if not reload.choose("right", natural_token) or reload.choose("right",
			natural_token) or reload.state.get("runClock", {}).get(
			"decisionIndex") != 15 or reload.state.get("choiceHistory", []).back().get(
			"cardId") != "market_encounter":
		return _fail("natural ghost skip did not settle exactly once")
	var natural_done: Dictionary = reload.state.duplicate(true)
	var settled_reload = Domain.new(Registry.new(), RunSession.new(spell_path,
		"slot_3"), "slot_3")
	_stabilize_ambient(settled_reload)
	if not settled_reload.restore() or not _same(settled_reload.state, natural_done):
		return _fail("natural ghost skip did not strictly replay")
	print("NONCOMBAT_GHOST_CHOICE_PASS card=true skip=true entry_guarded=true natural=true replay=true")
	quit(0)
