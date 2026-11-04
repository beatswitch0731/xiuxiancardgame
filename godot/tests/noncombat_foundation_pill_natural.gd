extends "res://tests/noncombat_foundation_body_natural.gd"

func _run() -> void:
	var path := "user://tests/foundation_pill_natural_%d.json" % Time.get_ticks_usec()
	var game = Domain.new(Registry.new(), RunSession.new(path, "slot_3"), "slot_3")
	_stabilize_ambient(game)
	game._normal_roll_override = 0.55
	if not game.start("pill"):
		return _fail("pill natural opening failed")
	for direction in ["left", "left", "left", "left", "left", "left", "left"]:
		if not game.choose(direction, game.issue_choice_token()):
			return _fail("pill natural first battle prefix failed")
	var first_request: Dictionary = game.battle_request()
	if first_request.get("encounterId") != "enc_trial_pill_poison" \
			or not game.submit_battle_result(_result_for(first_request, "victory")) \
			or not game.choose("left", game.issue_choice_token()):
		return _fail("pill natural first battle did not return")
	for step in 100:
		if game.state.phase == "FLOW_PENDING" and not game.resume_flow():
			return _fail("pill natural flow stopped at " + str(step) + ": " +
				game.flow_failure_reason())
		var card: Dictionary = game.get_current_card()
		if card.get("id") == "q_pill_1":
			return _finish_pill_quest(game, path)
		if card.get("id") == "_warning_ch_qi_100":
			if not game.choose("left", game.issue_choice_token()):
				return _fail("pill natural gate preparation failed")
			var gate_request: Dictionary = game.battle_request()
			if gate_request.get("sourceCardId") != "ch_qi_100" \
					or not game.submit_battle_result(_result_for(
						gate_request, "victory")) \
					or not game.choose("left", game.issue_choice_token()) \
					or not game.choose("left", game.issue_choice_token()):
				return _fail("pill natural qi gate failed")
			continue
		if game.state.phase == "VENDOR_OPEN":
			if not game.close_vendor(game.issue_choice_token()):
				return _fail("pill natural vendor could not close")
			continue
		var direction := "right" if game.state.phase in [
			"COMBAT_HANDOFF", "MARKET_PENDING", "FIRST_SESSION_ROUTE_PENDING",
			"VENDOR_RESULT_PENDING"] or card.get("id") == "kx_ch_sword_sect_path" else "left"
		if not game.can_choose_direction(direction):
			for fallback in ["right", "down", "up"]:
				if game.can_choose_direction(fallback):
					direction = fallback
					break
		if not game.can_choose_direction(direction) or not game.choose(
				direction, game.issue_choice_token()):
			return _fail("pill natural prefix stopped: " + JSON.stringify({
				"card": card.get("id"), "phase": game.state.phase,
				"realm": game.state.realm, "error": game.flow_failure_reason()}))
	return _fail("pill natural quest not reached within 100 decisions")


func _finish_pill_quest(game: RefCounted, path: String) -> void:
	var entry: Dictionary = game.state.duplicate(true)
	var original_bytes := FileAccess.get_file_as_bytes(game._store.v2_path)
	var cold = _branch_body(original_bytes,
		"user://tests/foundation_pill_entry_%d.json" % Time.get_ticks_usec())
	if cold == null or not _same(cold.state, entry):
		return _fail("pill natural entry did not strictly cold restore")
	var refusal = _branch_body(original_bytes,
		"user://tests/foundation_pill_refusal_%d.json" % Time.get_ticks_usec())
	if refusal == null or not refusal.choose("right", refusal.issue_choice_token()) \
			or refusal.state.questState.questOutcomes.get("pill_master") != "abandoned" \
			or refusal.state.flags.get("pillMasterCompleted") == true:
		return _fail("pill natural refusal was rewarded or remained open")
	game._store.fail_promotion_once = true
	if game.choose("left", game.issue_choice_token()) or not _same(game.state, entry) \
			or FileAccess.get_file_as_bytes(game._store.v2_path) != original_bytes:
		return _fail("pill natural failed write changed entry")
	for expected in ["q_pill_2", "q_pill_3", "q_pill_4"]:
		if not game.choose("left", game.issue_choice_token()) \
				or game.get_current_card().get("id") != expected:
			return _fail("pill natural quest chain stopped before " + expected)
	if int(game.state.get("knowledge", {}).get("pill", -1)) < 2 \
			or not game.state.get("karmaSeeds", []).any(
				func(seed: Variant) -> bool: return seed is Dictionary \
					and seed.get("id") == "pillMasterSacrifice"):
		return _fail("pill natural insight or sacrifice seed missing")
	if not game.choose("left", game.issue_choice_token()) \
			or game.state.questState.questOutcomes.get("pill_master") != "completed" \
			or game.state.get("opportunityAcquisitions", {}).get(
				"pill_master_completion_v1", {}).get("profile") != "restraint_vow":
		return _fail("pill natural completion reward missing")
	var restored = Domain.new(Registry.new(), RunSession.new(path, "slot_3"), "slot_3")
	_stabilize_ambient(restored)
	restored._normal_roll_override = 0.55
	if not restored.restore() or not _same(restored.state, game.state):
		return _fail("pill natural completion did not strictly cold restore: " +
			restored._store.last_error)
	print("NONCOMBAT_FOUNDATION_PILL_NATURAL_PASS entry=true refusal=true reward=true rollback=true replay=true")
	quit(0)
