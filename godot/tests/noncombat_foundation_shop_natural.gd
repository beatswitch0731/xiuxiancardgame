extends "res://tests/noncombat_foundation_spell_natural.gd"

func _run() -> void:
	var path := "user://tests/foundation_shop_natural_%d.json" % Time.get_ticks_usec()
	var game = Domain.new(Registry.new(), RunSession.new(path, "slot_3"), "slot_3")
	_stabilize_ambient(game)
	game._normal_roll_override = _fixed_roll()
	if _normal_seed() > 0:
		game._normal_replay_seed = _normal_seed()
	if not game.start("spell"):
		return _fail("foundation shop natural opening failed")
	for direction in ["left", "left", "left", "left", "left", "left", "left"]:
		if not game.choose(direction, game.issue_choice_token()):
			return _fail("foundation shop first battle prefix failed")
	var first_request: Dictionary = game.battle_request()
	if first_request.get("encounterId") != "enc_trial_spell_seal" \
			or not game.submit_battle_result(_result_for(first_request, "victory")) \
			or not game.choose("left", game.issue_choice_token()):
		return _fail("foundation shop first teaching did not return")
	for index in _iteration_limit():
		if game.state.phase == "FLOW_PENDING" and not game.resume_flow():
			return _fail("foundation shop flow stopped at %d turn=%d realm=%s reason=%s" % [
				index, int(game.state.get("turn", 0)), String(game.state.get("realm", "")),
				game.flow_failure_reason()])
		var card: Dictionary = game.get_current_card()
		if card.get("id") == _target_card_id() and _target_ready(game):
			await _verify_shop_natural(game, path)
			return
		if game.state.phase == "VENDOR_OPEN":
			if not game.close_vendor(game.issue_choice_token()):
				return _fail("foundation source vendor could not close")
			continue
		if game.state.phase == "BATTLE_PENDING":
			var request: Dictionary = game.battle_request()
			if request.is_empty() or not game.submit_battle_result(
					_result_for(request, _battle_outcome_for_request(request))):
				return _fail("foundation source battle could not return")
			continue
		if card.get("id") == "q_fellow" and _fight_fellow_before_camp():
			var right_available := game.can_choose_direction("right")
			if not game.choose("right", game.issue_choice_token()):
				return _fail("foundation source fellow route failed: " + JSON.stringify({
					"phase": game.state.phase, "card": game.get_current_card().get("id"),
					"reason": game.flow_failure_reason(), "available": right_available,
					"choice": card.get("choices", {}).get("right", {}),
					"attributes": game.state.attributes, "realm": game.state.realm}))
			if not game.choose("left", game.issue_choice_token()):
				return _fail("foundation source fellow sparring could not start: " + JSON.stringify({
					"phase": game.state.phase, "card": game.get_current_card().get("id"),
					"reason": game.flow_failure_reason()}))
			var fellow_request: Dictionary = game.battle_request()
			if fellow_request.get("sourceCardId") != "q_fellow" \
					or not game.submit_battle_result(_result_for(
						fellow_request, "victory")) \
					or not game.choose("down", game.issue_choice_token()):
				return _fail("foundation source fellow sparring did not award spoils")
			continue
		if card.get("id") == "camp_meditation" and _camp_upgrade_index() >= 0:
			var target_index := _camp_upgrade_index()
			var deck: Array = game.state.deck.duplicate(true)
			if String(deck[target_index]).ends_with("+"):
				if not game.choose("up", game.issue_choice_token()):
					return _fail("natural camp could not leave after the source card upgrade")
				continue
			if not game.choose("down", game.issue_choice_token()) \
					or not game.resolve_camp_target(target_index,
						String(deck[target_index]), game.issue_choice_token()):
				return _fail("natural camp could not upgrade source card")
			continue
		if card.get("id") == "_warning_ch_qi_100":
			if not game.choose("left", game.issue_choice_token()):
				return _fail("foundation shop gate warning failed")
			var gate_request: Dictionary = game.battle_request()
			if gate_request.get("sourceCardId") != "ch_qi_100" \
					or not game.submit_battle_result(_result_for(gate_request,
						"victory")) or not game.choose("left", game.issue_choice_token()) \
					or not game.choose("left", game.issue_choice_token()):
				return _fail("foundation shop gate failed")
			continue
		var direction := "right" if game.state.phase in [
			"COMBAT_HANDOFF", "MARKET_PENDING", "FIRST_SESSION_ROUTE_PENDING",
			"VENDOR_RESULT_PENDING"] \
			or card.get("id") in ["kx_ch_sword_sect_path", "q_spell_1"] else "left"
		if not game.can_choose_direction(direction):
			for fallback in ["right", "down", "up"]:
				if game.can_choose_direction(fallback):
					direction = fallback
					break
		var faction_before := {}
		if card.get("id") == "faction_spell_0" and direction == "left":
			faction_before = {"reputation": int(game.state.factionProgress.reputations.tianshu_academy),
				"stage": int(game.state.factionProgress.undercurrentStages.tianshu_forbidden),
				"route": game.state.tradeRouteState.routes.ruin_star_path.duplicate(true)}
		if not game.can_choose_direction(direction) or not game.choose(
				direction, game.issue_choice_token()):
			return _fail("foundation shop prefix stopped on " + JSON.stringify({
				"card": card.get("id"), "phase": game.state.phase,
				"stone": game.state.resources.spiritStone,
				"direction": direction, "reason": game.flow_failure_reason(),
				"faction": game._faction_events.last_error,
				"choice": card.get("choices", {}).get(direction, {}),
				"attributes": game.state.attributes}))
		if not faction_before.is_empty():
			var route: Dictionary = game.state.tradeRouteState.routes.ruin_star_path
			var old_route: Dictionary = faction_before.route
			if int(game.state.factionProgress.reputations.tianshu_academy) != faction_before.reputation + 5 \
					or int(game.state.factionProgress.undercurrentStages.tianshu_forbidden) != faction_before.stage + 1 \
					or int(route.danger) != mini(100, int(old_route.danger) + 2) \
					or int(route.openness) != maxi(0, mini(100, int(old_route.openness) + 2) - 1) \
					or int(route.prosperity) != mini(100, int(old_route.prosperity) + 1):
				return _fail("foundation faction choice did not atomically update reputation, undercurrent and route")
	return _fail("foundation shop did not reach foundation: " + JSON.stringify({
		"realm": game.state.realm, "turn": game.state.turn,
		"phase": game.state.phase, "card": game.get_current_card().get("id"),
		"target": _target_card_id(), "deck0": game.state.deck[0],
		"reason": game.flow_failure_reason()}))


func _fixed_roll() -> float:
	return 0.55


func _normal_seed() -> int:
	return 0


func _target_ready(_game: RefCounted) -> bool:
	return true


func _battle_outcome_for_request(_request: Dictionary) -> String:
	return "victory"


func _iteration_limit() -> int:
	return 140


func _target_card_id() -> String:
	return "f_shop"


func _camp_upgrade_index() -> int:
	return -1


func _fight_fellow_before_camp() -> bool:
	return false


func _verify_shop_natural(game: RefCounted, path: String) -> void:
	if game.state.realm != "foundation" or game.state.phase != "NORMAL_PENDING" \
			or not game.can_choose_direction("up"):
		return _fail("natural foundation auction source or removal eligibility differs")
	var pending: Dictionary = game.state.duplicate(true)
	var before_stone := int(pending.resources.spiritStone)
	var pending_bytes := FileAccess.get_file_as_bytes(game._store.v2_path)
	var cold = _shop_branch(pending_bytes, path)
	if cold == null or not _same(cold.state, pending):
		return _fail("natural pending foundation auction did not strictly restore")
	var story: Control = load("res://scenes/noncombat_opening.tscn").instantiate()
	story.save_path = ""
	root.add_child(story)
	await process_frame
	story.opening = cold
	story.slot_screen.visible = false
	story.name_screen.visible = false
	story.path_screen.visible = false
	story.story_screen.visible = true
	story._set_scene_surface(true)
	story._render()
	var row: Control = story.get_node(
		"DesktopMargin/ScreenStack/StoryScreen/SourceChoices")
	if story.art_rect.texture == null \
			or not story.status_label.text.contains("拍卖行") \
			or not story.status_label.text.contains("25") \
			or not story.status_label.text.contains("6") \
			or not story.story_screen.is_visible_in_tree() \
			or row.get_node("Choice_up").disabled:
		return _fail("desktop foundation auction art or source fees missing")
	var before_bytes := FileAccess.get_file_as_bytes(cold._store.v2_path)
	cold._store.fail_promotion_once = true
	if cold.choose("up", cold.issue_choice_token()) \
			or not _same(cold.state, pending) \
			or FileAccess.get_file_as_bytes(cold._store.v2_path) != before_bytes:
		return _fail("failed auction removal write changed memory or save")
	cold.changed.connect(story._on_opening_changed)
	row.get_node("Choice_up").pressed.emit()
	await process_frame
	if cold.state.phase != "CAMP_TARGET_PENDING" \
			or cold.get_current_card().get("id") != "f_shop" \
			or int(cold.state.resources.spiritStone) != before_stone - 25:
		return _fail("natural auction first fee or target phase differs")
	if not story.status_label.text.contains("拍卖行") \
			or not story.story_screen.is_visible_in_tree() \
			or row.get_node_or_null("CampTargets/CampTargetCancel") == null:
		return _fail("desktop auction target selector or cancel missing")
	var target_pending: Dictionary = cold.state.duplicate(true)
	var target_cold = _shop_branch(FileAccess.get_file_as_bytes(
		cold._store.v2_path), path)
	if target_cold == null or not _same(target_cold.state, target_pending):
		return _fail("natural auction target selector did not strictly restore")
	var deck_before: Array = target_cold.state.deck.duplicate(true)
	if not target_cold.resolve_camp_target(5, String(deck_before[5]),
			target_cold.issue_choice_token()) \
			or int(target_cold.state.resources.spiritStone) != before_stone - 31 \
			or target_cold.state.deck.size() != deck_before.size() - 1 \
			or target_cold.state.campTargetHistory.back().get(
				"sourceCardId") != "f_shop":
		return _fail("natural auction did not charge target fee or remove one card")
	var selected_cold = _shop_branch(FileAccess.get_file_as_bytes(
		target_cold._store.v2_path), path)
	if selected_cold == null or not _same(selected_cold.state, target_cold.state):
		return _fail("selected auction target did not strictly restore")
	var cancel_path := "user://tests/foundation_shop_cancel_%d.json" % Time.get_ticks_usec()
	var cancelled = _shop_branch(pending_bytes, cancel_path)
	if cancelled == null or not cancelled.choose("up", cancelled.issue_choice_token()) \
			or not cancelled.cancel_camp_target(cancelled.issue_choice_token()) \
			or int(cancelled.state.resources.spiritStone) != before_stone - 25:
		return _fail("auction cancel refunded first fee or failed to settle")
	var cancel_cold = _shop_branch(FileAccess.get_file_as_bytes(
		cancelled._store.v2_path), cancel_path)
	if cancel_cold == null or not _same(cancel_cold.state, cancelled.state):
		return _fail("cancelled auction target did not strictly restore")
	story.queue_free()
	print("NONCOMBAT_FOUNDATION_SHOP_NATURAL_PASS draw=true fees=true target=true cancel=true replay=true rollback=true")
	quit(0)


func _shop_branch(bytes: PackedByteArray, path: String) -> RefCounted:
	var store = RunSession.new(path, "slot_3")
	var file := FileAccess.open(store.v2_path, FileAccess.WRITE)
	if file == null:
		return null
	file.store_buffer(bytes)
	file.close()
	var branch = Domain.new(Registry.new(), store, "slot_3")
	_stabilize_ambient(branch)
	branch._normal_roll_override = _fixed_roll()
	return branch if branch.restore() else null
