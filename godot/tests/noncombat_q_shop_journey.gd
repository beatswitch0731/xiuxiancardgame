extends "res://tests/noncombat_regulated_replay.gd"


func _run() -> void:
	var suffix := "%d_%d_%d" % [Time.get_unix_time_from_system(),
		OS.get_process_id(), Time.get_ticks_usec()]
	var path := "user://tests/q_shop_journey_%s.json" % suffix
	var game = Domain.new(Registry.new(), RunSession.new(path, "slot_3"), "slot_3")
	_set_zero_rolls(game)
	if not game.start("sword") or not _reach_bazaar(game) \
			or not game.choose("left", game.issue_choice_token()) \
			or not game.perform_vendor_action("ask_luo", game.issue_choice_token()) \
			or not game.close_vendor(game.issue_choice_token()) \
			or not game.choose("right", game.issue_choice_token()) \
			or not game.resume_flow() \
			or not game.choose("right", game.issue_choice_token()) \
			or not game.resume_flow() \
			or not game.choose("left", game.issue_choice_token()) \
			or not game.choose("left", game.issue_choice_token()) \
			or not game.resume_flow() \
			or not game.choose("right", game.issue_choice_token()) \
			or not game.resume_flow() \
			or not game.choose("left", game.issue_choice_token()):
		return _fail("q_shop ordinary source route did not reach first draw")
	if game.state.get("phase") != "FLOW_PENDING" or game.state.get(
			"runClock", {}).get("decisionIndex") != 27 or game.state.get(
			"normalFlow", {}) != {}:
		return _fail("q_shop natural draw starting point differs")
	game._normal_roll_override = 0.55
	if not game.resume_flow() or game.get_current_card().get("id") != "q_shop" \
			or game.state.get("resources", {}).get("spiritStone") != 16 \
			or game.can_choose_direction("left") \
			or not game.can_choose_direction("right") \
			or not game.can_choose_direction("up") \
			or game.can_choose_direction("down"):
		return _fail("natural q_shop admission, draw or balances differ: " +
			"card=%s phase=%s stone=%s choices=%s flow=%s" % [
				game.get_current_card().get("id"), game.state.get("phase"),
				game.state.get("resources", {}).get("spiritStone"),
				[game.can_choose_direction("left"), game.can_choose_direction("right"),
					game.can_choose_direction("up"), game.can_choose_direction("down")],
				game.flow_failure_reason()])
	var pending: Dictionary = game.state.duplicate(true)
	var reload = Domain.new(Registry.new(), RunSession.new(path, "slot_3"), "slot_3")
	_set_zero_rolls(reload)
	if not reload.restore() or not _same(reload.state, pending):
		return _fail("natural pending q_shop did not strictly restore")
	var ui: Control = load("res://scenes/noncombat_opening.tscn").instantiate()
	ui.save_path = ""
	root.add_child(ui)
	await process_frame
	ui.opening = game
	ui._render()
	if ui.ambient_particles.phase != game.state.get("normalFlow", {}).get("phase"):
		return _fail("source ordinary flow phase did not reach ambient presentation")
	var row: Control = ui.get_node("DesktopMargin/ScreenStack/StoryScreen/SourceChoices")
	if ui.title_label.text != game.get_current_card().get("title") \
			or ui.art_rect.texture == null \
			or not ui.status_label.text.contains("15") \
			or not ui.status_label.text.contains("6") \
			or not row.get_node("Choice_left").disabled \
			or row.get_node("Choice_right").disabled \
			or row.get_node("Choice_up").disabled \
			or not row.get_node("Choice_down").disabled:
		return _fail("desktop q_shop art, fee or choice states differ")
	var before_bytes := FileAccess.get_file_as_string(game._store.v2_path)
	game._store.fail_promotion_once = true
	if game.choose("right", game.issue_choice_token()) \
			or not _same(game.state, pending) \
			or FileAccess.get_file_as_string(game._store.v2_path) != before_bytes:
		return _fail("failed pill purchase changed memory or save bytes")
	if not game.choose("right", game.issue_choice_token()) \
			or game.state.get("resources", {}).get("spiritStone") != 6 \
			or game.state.get("resources", {}).get("pills", {}).get("回春丹") != 1 \
			or game.state.get("phase") != "FLOW_PENDING":
		return _fail("natural source pill purchase did not settle exactly once")
	var pill_reload = Domain.new(Registry.new(), RunSession.new(path, "slot_3"), "slot_3")
	_set_zero_rolls(pill_reload)
	if not pill_reload.restore() or not _same(pill_reload.state, game.state):
		return _fail("purchased source pill did not strictly restore")
	var target_path := "user://tests/q_shop_target_%s.json" % suffix
	var target_store = RunSession.new(target_path, "slot_3")
	if not target_store.commit_snapshot(pending, -1).get("ok", false):
		return _fail("natural pending q_shop branch could not persist")
	var target = Domain.new(Registry.new(), target_store, "slot_3")
	_set_zero_rolls(target)
	if not target.restore() or not target.choose("up", target.issue_choice_token()) \
			or target.state.get("phase") != "CAMP_TARGET_PENDING" \
			or target.get_current_card().get("id") != "q_shop" \
			or target.state.get("resources", {}).get("spiritStone") != 1 \
			or target.camp_targets().any(func(item: Variant) -> bool:
				return item.get("allowed", false)):
		return _fail("natural q_shop removal entry or second fee differs")
	ui.opening = target
	ui._render()
	var target_row: Control = ui.get_node(
		"DesktopMargin/ScreenStack/StoryScreen/SourceChoices")
	if not ui.status_label.text.contains("山间坊市") \
			or target_row.get_node_or_null("CampTargets/CampTargetCancel") == null:
		return _fail("source q_shop removal target UI is not visible")
	var target_reload = Domain.new(Registry.new(), RunSession.new(target_path,
		"slot_3"), "slot_3")
	_set_zero_rolls(target_reload)
	if not target_reload.restore() or not _same(target_reload.state, target.state) \
			or not target_reload.cancel_camp_target(target_reload.issue_choice_token()) \
			or target_reload.state.get("resources", {}).get("spiritStone") != 1:
		return _fail("pending or cancelled q_shop target did not strictly settle")
	var cancelled = Domain.new(Registry.new(), RunSession.new(target_path,
		"slot_3"), "slot_3")
	_set_zero_rolls(cancelled)
	if not cancelled.restore() or not _same(cancelled.state, target_reload.state):
		return _fail("cancelled q_shop target did not strictly restore")
	if not _verify_rich_branches(pending):
		return
	print("NONCOMBAT_Q_SHOP_JOURNEY_PASS natural=true art=true pill=true target=true replay=true rollback=true")
	quit(0)


func _verify_rich_branches(pending: Dictionary) -> bool:
	var rich: Dictionary = pending.duplicate(true)
	rich["resources"]["spiritStone"] = 40
	var left = Domain.new(Registry.new(), null, "slot_3")
	_set_zero_rolls(left)
	if not left.start("sword"):
		return _reject("high-balance purchase fixture could not start")
	left.state = rich.duplicate(true)
	if not left.choose("left", left.issue_choice_token()) \
			or left.state["resources"]["spiritStone"] != 20 \
			or left.state["resources"]["pills"].get("筑基丹") != 1:
		return _reject("20-stone authored foundation pill purchase differs")
	var remove = Domain.new(Registry.new(), null, "slot_3")
	_set_zero_rolls(remove)
	if not remove.start("sword"):
		return _reject("high-balance removal fixture could not start")
	remove.state = rich.duplicate(true)
	var deck_before: Array = remove.state["deck"].duplicate(true)
	if not remove.choose("up", remove.issue_choice_token()) \
			or remove.state["resources"]["spiritStone"] != 25 \
			or not remove.resolve_camp_target(5, String(deck_before[5]),
				remove.issue_choice_token()) \
			or remove.state["resources"]["spiritStone"] != 19 \
			or remove.state["deck"].size() != deck_before.size() - 1 \
			or remove.state.get("campTargetHistory", []).back().get(
				"sourceCardId") != "q_shop":
		return _reject("q_shop targeted removal did not charge 15+6 and remove one card")
	return true
