extends "res://tests/noncombat_market_arrival.gd"


class DriftBodyMapping extends "res://scripts/noncombat_content_repository.gd":
	func source_sha256(module_id: String) -> String:
		return "f".repeat(64) if module_id == "cards:karma_expansion" \
			else super.source_sha256(module_id)


func _run() -> void:
	var path := "user://tests/body_karma_due_%d.json" % Time.get_ticks_usec()
	var store = RunSession.new(path, "slot_3")
	var game = Domain.new(Registry.new(), store, "slot_3")
	_stabilize_ambient(game)
	game._normal_roll_override = 0.55
	if not _reach_due_seed(game):
		return _fail("source body route did not reach its mature opening seed")
	var due_state: Dictionary = game.state.duplicate(true)
	var left_path := "user://tests/body_karma_left_%d.json" % Time.get_ticks_usec()
	var left_store = RunSession.new(left_path, "slot_3")
	if left_store.commit_snapshot(due_state, -1).get("ok") != true:
		return _fail("body source checkpoint could not branch")
	if not game.resume_flow() or game.state.get("phase") != "KARMA_PENDING" \
			or game.get_current_card().get("id") != "karma_body_awakening":
		return _fail("mature body seed was not given its source priority")
	var card: Dictionary = game.get_current_card()
	if card.get("_karmaSeedId") != "causal:body_trial_start" \
			or card.get("sceneImage") != "assets/cards/events/scene_qi_q_bodyTrial.png" \
			or Registry.new().texture_for(String(card.get("sceneImage", ""))) == null \
			or not game.can_choose_direction("left") \
			or not game.can_choose_direction("right"):
		return _fail("body payoff did not retain its original card and art")
	var pending: Dictionary = game.state.duplicate(true)
	var pending_bytes := FileAccess.get_file_as_string(store.v2_path)
	var drift_store = RunSession.new(path, "slot_3")
	var drift = Domain.new(Registry.new(), drift_store, "slot_3",
		DriftBodyMapping.new())
	_stabilize_ambient(drift)
	drift._normal_roll_override = 0.55
	if drift.restore() or drift_store.last_error != "SOURCE_MISMATCH" \
			or FileAccess.get_file_as_string(store.v2_path) != pending_bytes:
		return _fail("body causal mapping drift was not rejected without rewriting save")
	var reopened = Domain.new(Registry.new(), RunSession.new(path, "slot_3"), "slot_3")
	_stabilize_ambient(reopened)
	reopened._normal_roll_override = 0.55
	if not reopened.restore() or not _same(reopened.state, pending):
		return _fail("body payoff pending card did not strictly restore")
	var view: Control = load("res://scenes/noncombat_opening.tscn").instantiate()
	view.save_path = ""
	root.add_child(view)
	await process_frame
	view.opening = reopened
	view._render()
	var left_button: Button = view.choice_row.get_node_or_null("Choice_left")
	var right_button: Button = view.choice_row.get_node_or_null("Choice_right")
	if view.art_rect.texture == null or left_button == null or right_button == null \
			or left_button.disabled or right_button.disabled:
		return _fail("body karma desktop art or choices missing")
	root.remove_child(view)
	view.queue_free()
	var token: int = reopened.issue_choice_token()
	reopened._store.fail_promotion_once = true
	if reopened.choose("right", token) or not _same(reopened.state, pending) \
			or FileAccess.get_file_as_string(store.v2_path) != pending_bytes:
		return _fail("failed body payoff write changed state or save")
	var before_deck: Array = pending.get("deck", [])
	var before_cultivation := int(pending.get("attributes", {}).get("cultivation", 0))
	if not reopened.choose("right", token) or reopened.choose("right", token):
		return _fail("body payoff right choice was not committed once")
	var awarded: Dictionary = reopened.state
	if awarded.get("deck", []).size() != before_deck.size() + 1 \
			or not awarded.get("deck", []).has("iron_skin") \
			or awarded.get("skillAcquisitions", {}).get("iron_skin", {}).get(
				"sourceId") != "karma_body_awakening" \
			or int(awarded.get("attributes", {}).get("cultivation", -1)) != \
				mini(100, before_cultivation + 15) \
			or awarded.get("choiceHistory", []).back().get("cardType") != "NORMAL" \
			or awarded.get("karmaSeeds", []).any(func(seed: Variant) -> bool:
				return seed is Dictionary and seed.get("id") == "causal:body_trial_start"):
		return _fail("body payoff deck grant or seed settlement differs")
	var awarded_reopen = Domain.new(Registry.new(), RunSession.new(path, "slot_3"), "slot_3")
	_stabilize_ambient(awarded_reopen)
	awarded_reopen._normal_roll_override = 0.55
	var awarded_restored: bool = awarded_reopen.restore()
	if not awarded_restored or not _same(awarded_reopen.state, awarded):
		var different := []
		for key in awarded:
			if JSON.stringify(awarded.get(key)) != JSON.stringify(
					awarded_reopen.state.get(key)):
				different.append(key)
		return _fail("awarded body card did not strictly restore: ok=%s error=%s diff=%s" % [
			awarded_restored, awarded_reopen._store.last_error, different])
	var left = Domain.new(Registry.new(), left_store, "slot_3")
	_stabilize_ambient(left)
	left._normal_roll_override = 0.55
	if not left.restore() or not left.resume_flow() \
			or left.get_current_card().get("id") != "karma_body_awakening":
		return _fail("body left branch did not replay from source checkpoint")
	var before_left: Dictionary = left.state.duplicate(true)
	if not left.choose("left", left.issue_choice_token()):
		return _fail("body payoff left choice failed")
	var left_result: Dictionary = left.state
	if int(left_result.get("maxHealth", 0)) != int(before_left.get("maxHealth", 0)) + 2 \
			or int(left_result.get("attributes", {}).get("health", 0)) != mini(
				int(left_result.get("maxHealth", 0)),
				int(before_left.get("attributes", {}).get("health", 0)) + 4) \
			or int(left_result.get("attributes", {}).get("cultivation", -1)) != mini(
				100, int(before_left.get("attributes", {}).get("cultivation", 0)) + 20) \
			or left_result.get("choiceHistory", []).back().get("cardType") != "NORMAL" \
			or left_result.get("deck", []) != before_deck:
		return _fail("body left max-health and stacked healing differ")
	var left_reopen = Domain.new(Registry.new(), RunSession.new(left_path, "slot_3"), "slot_3")
	_stabilize_ambient(left_reopen)
	left_reopen._normal_roll_override = 0.55
	if not left_reopen.restore() or not _same(left_reopen.state, left_result):
		return _fail("body left reward did not strictly restore")
	print("NONCOMBAT_BODY_KARMA_DUE_PASS natural=true deck=true heal=true rollback=true replay=true ui=true")
	quit(0)


func _reach_due_seed(game: RefCounted) -> bool:
	if not game.start("body"):
		return false
	for i in 4:
		if not game.choose("left", game.issue_choice_token()):
			return false
	if game.get_current_card().get("id") != "q_start_body" \
			or not game.choose("left", game.issue_choice_token()):
		return false
	if game.state.get("phase") != "COMBAT_HANDOFF" \
			or not game.choose("right", game.issue_choice_token()):
		return false
	if not game.choose("left", game.issue_choice_token()):
		return false
	for row in [["ch_qi_20", "left"], ["ch_qi_40", "right"],
			["q_whiteFox_quest", "right"], ["q_whiteFox_2", "right"],
			["q_whiteFox_3", "down"]]:
		if game.state.get("phase") == "FLOW_PENDING" and not game.resume_flow():
			return false
		if game.get_current_card().get("id") != row[0] \
				or not game.choose(row[1], game.issue_choice_token()):
			return false
	return game.state.get("phase") == "FLOW_PENDING" \
		and int(game.state.get("runClock", {}).get("decisionIndex", -1)) == 12 \
		and game.state.get("karmaSeeds", []).any(func(seed: Variant) -> bool:
			return seed is Dictionary and seed.get("id") == "causal:body_trial_start" \
				and int(seed.get("delay", 1)) <= 0)


func _same(left: Dictionary, right: Dictionary) -> bool:
	return JSON.parse_string(JSON.stringify(left)) == JSON.parse_string(JSON.stringify(right))
