extends "res://tests/noncombat_foundation_shop_natural.gd"
const ContentRepository = preload("res://scripts/noncombat_content_repository.gd")


func _fixed_roll() -> float:
	return 0.39


func _iteration_limit() -> int:
	return 240


func _target_card_id() -> String:
	return "_warning_ch_foundation_100"


func _verify_shop_natural(game: RefCounted, path: String) -> void:
	var warning: Dictionary = game.state.duplicate(true)
	var source: Dictionary = game.get_current_card()
	var seen: Dictionary = warning.get("noncombatFlow", {}).get(
		"encounterDirectorState", {}).get("realmProgress", {}).get(
		"foundation", {}).get("seenCounts", {})
	if warning.get("realm") != "foundation" or warning.get("phase") != "WARNING_PENDING" \
			or int(seen.get("ordinary", 0)) < 2 \
			or int(seen.get("relationship", 0)) + int(seen.get("quest", 0)) < 1 \
			or int(seen.get("elite", 0)) < 1 \
			or source.get("id") != "_warning_ch_foundation_100":
		return _fail("foundation natural gate quota or warning missing: " + JSON.stringify({
			"phase": warning.get("phase"), "card": source.get("id"), "seen": seen}))
	var cold = _shop_branch(FileAccess.get_file_as_bytes(game._store.v2_path), path)
	if cold == null or not _same(cold.state, warning):
		return _fail("foundation gate warning did not strictly cold restore")
	var direction := "right" if cold.get_current_card().get("choices", {}).has("right") \
		else "left"
	if not cold.choose(direction, cold.issue_choice_token()) \
			or cold.state.phase != "BATTLE_PENDING":
		return _fail("foundation gate warning did not prepare battle")
	var pending = _shop_branch(FileAccess.get_file_as_bytes(cold._store.v2_path), path)
	if pending == null or not _same(pending.state, cold.state):
		return _fail("foundation gate pending battle did not strictly cold restore")
	var request: Dictionary = pending.battle_request()
	if request.get("sourceCardId") != "ch_foundation_100" \
			or not pending.submit_battle_result(_result_for(request, "victory")):
		return _fail("foundation natural gate victory did not settle")
	var reward = _shop_branch(FileAccess.get_file_as_bytes(pending._store.v2_path), path)
	if reward == null or not _same(reward.state, pending.state) \
			or reward.state.realm != "golden" \
			or reward.get_current_card().get("id") != "breakthrough_reward":
		return _fail("foundation gate reward did not strictly cold restore")
	if not reward.choose("left", reward.issue_choice_token()) \
			or reward.get_current_card().get("id") != "realm_arrival_golden":
		return _fail("foundation gate reward did not reach golden arrival")
	var arrival = _shop_branch(FileAccess.get_file_as_bytes(reward._store.v2_path), path)
	if arrival == null:
		return _fail("golden arrival cold restore rejected: " + reward._store.last_error)
	if not _same(arrival.state, reward.state):
		return _fail("golden arrival cold restore state differs")
	if not arrival.choose("left", arrival.issue_choice_token()):
		return _fail("golden arrival choice rejected: " + arrival.flow_failure_reason())
	var found_golden_draw := false
	var pre_draw_trace: Array[String] = []
	for step in 48:
		if arrival.state.get("phase") == "FLOW_PENDING" and not arrival.resume_flow():
			return _fail("golden flow stopped before draw: " + arrival.flow_failure_reason())
		if arrival.state.get("phase") == "NORMAL_PENDING" and arrival.state.get(
				"normalFlow", {}).get("goldenSourceSha") == ContentRepository.new(
				).source_sha256("cards:golden"):
			found_golden_draw = true
			break
		var interim: Dictionary = arrival.get_current_card()
		pre_draw_trace.append("%s:%s" % [arrival.state.get("phase"),
			interim.get("id")])
		if interim.is_empty():
			return _fail("golden pre-draw card missing: " + String(arrival.state.phase))
		if arrival.state.get("phase") == "VENDOR_OPEN":
			if not arrival.close_vendor(arrival.issue_choice_token()):
				return _fail("golden pre-draw vendor could not close")
			continue
		var interim_direction := "right" if arrival.state.phase == "COMBAT_HANDOFF" else "left"
		if not arrival.can_choose_direction(interim_direction):
			for fallback in ["right", "down", "up"]:
				if arrival.can_choose_direction(fallback):
					interim_direction = fallback
					break
		if not arrival.can_choose_direction(interim_direction) or not arrival.choose(
				interim_direction, arrival.issue_choice_token()):
			return _fail("golden pre-draw choice failed: " + JSON.stringify({
				"card": interim.get("id"), "phase": arrival.state.phase,
				"direction": interim_direction}))
	if not found_golden_draw:
		return _fail("golden ordinary draw not reached: " +
			JSON.stringify(pre_draw_trace))
	var golden_draw = _shop_branch(FileAccess.get_file_as_bytes(
		arrival._store.v2_path), path)
	if golden_draw == null or not _same(golden_draw.state, arrival.state) \
			or golden_draw.get_current_card().is_empty():
		return _fail("golden first draw did not strictly cold restore")
	var next_card: Dictionary = golden_draw.get_current_card()
	var playable: Array = next_card.get("choices", {}).keys().filter(
		func(value: Variant) -> bool: return golden_draw.can_choose_direction(
			String(value)))
	if playable.is_empty() or not golden_draw.choose(String(playable[0]),
			golden_draw.issue_choice_token()):
		return _fail("golden first natural card could not be chosen: " +
			String(next_card.get("id")))
	var after_choice = _shop_branch(FileAccess.get_file_as_bytes(
		golden_draw._store.v2_path), path)
	if after_choice == null or not _same(after_choice.state, golden_draw.state):
		return _fail("golden first natural choice did not strictly cold restore")
	print("NONCOMBAT_FOUNDATION_GATE_NATURAL_PASS quota=true warning=true request=true victory=true arrival=true replay=true golden_draw=true pre_draw=%d" % pre_draw_trace.size())
	quit(0)
