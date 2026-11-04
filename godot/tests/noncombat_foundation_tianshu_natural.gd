extends "res://tests/noncombat_foundation_spell_natural.gd"


func _run() -> void:
	var path := "user://tests/foundation_tianshu_natural_%d.json" % Time.get_ticks_usec()
	var game = Domain.new(Registry.new(), RunSession.new(path, "slot_3"), "slot_3")
	_stabilize_ambient(game)
	game._normal_roll_override = 0.55
	if not game.start("spell"):
		return _fail("tianshu natural opening failed")
	for direction in ["left", "left", "left", "left", "left", "left", "left"]:
		if not game.choose(direction, game.issue_choice_token()):
			return _fail("tianshu natural first battle prefix failed")
	var first_request: Dictionary = game.battle_request()
	if first_request.get("encounterId") != "enc_trial_spell_seal" \
			or not game.submit_battle_result(_result_for(first_request, "victory")) \
			or not game.choose("left", game.issue_choice_token()):
		return _fail("tianshu natural first battle did not return")
	for step in 100:
		if game.state.phase == "FLOW_PENDING" and not game.resume_flow():
			return _fail("tianshu natural flow stopped at " + str(step) + ": " +
				game.flow_failure_reason())
		var card: Dictionary = game.get_current_card()
		if card.get("id") == "q_tianshu_1":
			return _finish_tianshu(game, path)
		if card.get("id") == "_warning_ch_qi_100":
			if not game.choose("left", game.issue_choice_token()):
				return _fail("tianshu natural qi gate preparation failed")
			var gate_request: Dictionary = game.battle_request()
			if gate_request.get("sourceCardId") != "ch_qi_100" \
					or not game.submit_battle_result(_result_for(gate_request, "victory")) \
					or not game.choose("left", game.issue_choice_token()) \
					or game.get_current_card().get("id") != "epiphany_foundation" \
					or not game.choose("left", game.issue_choice_token()):
				return _fail("tianshu natural qi gate did not enter foundation")
			continue
		var direction := "right" if game.state.phase in [
			"COMBAT_HANDOFF", "MARKET_PENDING", "FIRST_SESSION_ROUTE_PENDING"] \
			or card.get("id") == "kx_ch_sword_sect_path" else "left"
		if not game.can_choose_direction(direction):
			for fallback in ["right", "down", "up"]:
				if game.can_choose_direction(fallback):
					direction = fallback
					break
		if not game.can_choose_direction(direction) or not game.choose(
				direction, game.issue_choice_token()):
			return _fail("tianshu natural prefix stopped: " + JSON.stringify({
				"card": card.get("id"), "phase": game.state.phase,
				"realm": game.state.realm, "error": game.flow_failure_reason()}))
	return _fail("tianshu natural quest not reached within 100 decisions")


func _finish_tianshu(game: RefCounted, path: String) -> void:
	var entry: Dictionary = game.state.duplicate(true)
	if game.state.realm != "foundation" or int(game.state.turn) < 15 \
			or int(game.state.attributes.daoHeart) < 4:
		return _fail("tianshu natural entry lost source eligibility")
	var original_bytes := FileAccess.get_file_as_bytes(game._store.v2_path)
	var cold = _branch_body(original_bytes,
		"user://tests/foundation_tianshu_entry_%d.json" % Time.get_ticks_usec())
	if cold == null or not _same(cold.state, entry):
		return _fail("tianshu natural entry did not strictly cold restore")
	var refusal = _branch_body(original_bytes,
		"user://tests/foundation_tianshu_refusal_%d.json" % Time.get_ticks_usec())
	if refusal == null or not refusal.choose("right", refusal.issue_choice_token()) \
			or refusal.state.questState.questOutcomes.get("tianshu_codex") != "abandoned" \
			or refusal.state.flags.get("tianshuCodexCompleted") == true:
		return _fail("tianshu natural refusal was rewarded or remained open")
	game._store.fail_promotion_once = true
	if game.choose("left", game.issue_choice_token()) or not _same(game.state, entry) \
			or FileAccess.get_file_as_bytes(game._store.v2_path) != original_bytes:
		return _fail("tianshu natural failed write changed entry")
	for expected in ["q_tianshu_2", "q_tianshu_3", "q_tianshu_4"]:
		if not game.choose("left", game.issue_choice_token()):
			return _fail("tianshu natural choice failed before " + expected)
		if game.state.phase == "DESTINY_WHEEL_PENDING" \
				and not game.choose("left", game.issue_choice_token()):
			return _fail("tianshu natural wheel interrupt could not return")
		if game.get_current_card().get("id") != expected:
			return _fail("tianshu natural chain stopped before " + expected +
				": " + JSON.stringify({"card": game.get_current_card().get("id"),
					"phase": game.state.phase, "error": game.flow_failure_reason(),
					"dao": game.state.attributes.daoHeart,
					"fortune": game.state.attributes.fortune}))
	if not game.choose("right", game.issue_choice_token()) \
			or game.state.questState.questOutcomes.get("tianshu_codex") != "completed" \
			or game.state.flags.get("tianshuCodexCompleted") != true \
			or not game.state.get("karmaSeeds", []).any(
				func(seed: Variant) -> bool: return seed is Dictionary \
					and seed.get("id") == "tianshuDeep"):
		return _fail("tianshu natural deep outcome missing")
	var restored = Domain.new(Registry.new(), RunSession.new(path, "slot_3"), "slot_3")
	_stabilize_ambient(restored)
	restored._normal_roll_override = 0.55
	if not restored.restore() or not _same(restored.state, game.state):
		return _fail("tianshu natural completion did not strictly cold restore: " +
			restored._store.last_error)
	for step in 30:
		if game.state.phase == "FLOW_PENDING" and not game.resume_flow():
			return _fail("tianshu natural thread handoff stopped: " +
				game.flow_failure_reason())
		var card: Dictionary = game.get_current_card()
		if card.get("id") == "thread_tianshu_seal_echo_1":
			var thread_cold = Domain.new(Registry.new(), RunSession.new(path, "slot_3"),
				"slot_3")
			_stabilize_ambient(thread_cold)
			thread_cold._normal_roll_override = 0.55
			if not thread_cold.restore() or not _same(thread_cold.state, game.state) \
					or thread_cold.get_current_card() != card \
					or not game.choose("left", game.issue_choice_token()):
				return _fail("natural tianshu thread pending or choice failed")
			print("NONCOMBAT_FOUNDATION_TIANSHU_NATURAL_PASS entry=true refusal=true deep=true rollback=true replay=true thread=true")
			quit(0)
			return
		var direction := "right" if card.get("id") == "q_spell_1" \
			or game.state.phase in ["COMBAT_HANDOFF", "MARKET_PENDING"] else "left"
		if not game.can_choose_direction(direction):
			for fallback in ["right", "down", "up"]:
				if game.can_choose_direction(fallback):
					direction = fallback
					break
		if not game.can_choose_direction(direction) or not game.choose(
				direction, game.issue_choice_token()):
			return _fail("tianshu thread handoff interrupted by " +
				str(card.get("id")) + "/" + str(game.state.phase))
	return _fail("natural tianshu thread did not surface within 30 decisions")
