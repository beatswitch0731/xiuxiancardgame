extends "res://tests/noncombat_foundation_body_natural.gd"

const FactionFlow = preload("res://scripts/noncombat_faction_events.gd")
const BattlePlan = preload("res://scripts/battle_plan_resolver.gd")
const BattleScene = preload("res://scenes/main.tscn")


func _finish_body_quest(game: RefCounted, path: String) -> void:
	# The inherited route starts at the public opening and reaches this source
	# quest through the real first fight, realm gate, and story scheduler.
	if game.state.get("realm") != "foundation" or not game.choose(
			"right", game.issue_choice_token()):
		return _fail("faction natural route could not leave the body quest")
	for index in 100:
		if game.state.get("phase") == "FLOW_PENDING" and not game.resume_flow():
			return _fail("faction natural scheduler stopped at " + str(index))
		var card: Dictionary = game.get_current_card()
		if game.state.get("phase") == "FACTION_PENDING":
			if card.get("type") != "FACTION_EVENT" or not FactionFlow.new().valid(game.state):
				return _fail("faction natural card lost its source authority")
			var before: Dictionary = game.state.duplicate(true)
			var cold = Domain.new(Registry.new(), RunSession.new(path, "slot_3"), "slot_3")
			_stabilize_ambient(cold)
			cold._normal_roll_override = 0.55
			var restored: bool = cold.restore()
			if not restored or not _same(cold.state, before):
				var differing := []
				if restored:
					for key in before:
						if JSON.parse_string(JSON.stringify(before[key])) != \
								JSON.parse_string(JSON.stringify(cold.state.get(key))):
							differing.append(key)
				return _fail("natural faction pending card failed strict cold restore: " +
					JSON.stringify({"restored": restored, "storeError": cold._store.last_error,
						"flowError": cold.flow_failure_reason(), "card": card.get("id"),
						"decision": before.runClock.decisionIndex,
						"differenceKeys": differing}))
			var right_path := "user://tests/faction_natural_right_%d.json" % Time.get_ticks_usec()
			var right = _branch_body(FileAccess.get_file_as_bytes(
				game._store.v2_path), right_path)
			if right == null or not right.can_choose_direction("right") \
					or not right.choose("right", right.issue_choice_token()):
				return _fail("natural faction card could not settle")
			if right.state.get("phase") == "WARNING_PENDING":
				return _fail("natural faction ordinary settlement entered combat")
			if not _strict_cold(right_path, right.state):
				return _fail("natural faction choice failed strict cold restore")
			if card.get("id") == "faction_wumeng_gatekeeper_call":
				if not game.choose("left", game.issue_choice_token()) \
						or game.state.get("phase") != "WARNING_PENDING":
					return _fail("natural Wumeng invitation did not reach warning")
				if not _strict_cold(path, game.state):
					return _fail("natural Wumeng warning failed strict cold restore")
				if not game.choose("left", game.issue_choice_token()) \
						or game.state.get("phase") != "BATTLE_PENDING":
					return _fail("natural Wumeng warning did not enter battle")
				if not _strict_cold(path, game.state):
					return _fail("natural Wumeng pending battle failed strict cold restore")
				var request: Dictionary = game.battle_request()
				var plan: Dictionary = BattlePlan.new(Registry.new()).resolve_persisted(game.state)
				if request.get("encounterId") != "enc_faction_wumeng_elite" \
						or plan.get("launchAuthorized") != true:
					return _fail("natural Wumeng battle request could not launch")
				var battle_ui: Control = BattleScene.instantiate()
				battle_ui.battle_request = request.duplicate(true)
				battle_ui.battle_plan = plan.duplicate(true)
				root.add_child(battle_ui)
				await process_frame
				var flee_button: Button = battle_ui.get_node_or_null("FleeBattle")
				if battle_ui.duel_stage == null or not battle_ui.stage_assets_ready \
						or flee_button == null or flee_button.disabled:
					battle_ui.queue_free()
					return _fail("natural Wumeng desktop stage was unavailable")
				flee_button.pressed.emit()
				var result: Dictionary = battle_ui.terminal_result()
				battle_ui.queue_free()
				await process_frame
				if result.get("outcome") != "flee" \
						or not game.submit_battle_result(result) \
						or game.state.get("phase") != "BATTLE_RESULT_PENDING" \
						or int(game.state.factionProgress.reputations.wumeng_alliance) != -4:
					return _fail("natural Wumeng desktop flee did not settle reputation")
				if not _strict_cold(path, game.state):
					return _fail("natural Wumeng battle result failed strict cold restore")
				if not game.choose("down", game.issue_choice_token()) \
						or game.state.has("pendingFactionCard") \
						or not _strict_cold(path, game.state):
					return _fail("natural Wumeng result did not return to cold-restorable story")
			print("NONCOMBAT_FACTION_NATURAL_PASS card=", card.id,
				" decision=", before.runClock.decisionIndex,
				" pending=true settlement=true battle_flee=true replay=true")
			quit(0)
			return
		var direction: String = "right" if game.state.get("phase") in [
			"COMBAT_HANDOFF", "MARKET_PENDING", "FIRST_SESSION_ROUTE_PENDING"] \
			or card.get("id") == "kx_ch_sword_sect_path" else "left"
		if not game.can_choose_direction(direction):
			for fallback in ["right", "down", "up", "left"]:
				if game.can_choose_direction(fallback):
					direction = fallback
					break
		if not game.can_choose_direction(direction) or not game.choose(
				direction, game.issue_choice_token()):
			return _fail("natural faction route stopped at %s/%s: %s" % [
				game.state.get("phase"), card.get("id"), game.flow_failure_reason()])
	return _fail("natural faction event did not surface within 100 decisions")


func _strict_cold(path: String, expected: Dictionary) -> bool:
	var cold = Domain.new(Registry.new(), RunSession.new(path, "slot_3"), "slot_3")
	_stabilize_ambient(cold)
	cold._normal_roll_override = 0.55
	return cold.restore() and _same(cold.state, expected)
