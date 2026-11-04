extends "res://tests/noncombat_battle_return.gd"

func _run() -> void:
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/mountain_battle_source.json"))
	var count := 0
	for row in fixture.rows:
		var row_started := Time.get_ticks_msec()
		var file := "user://tests/mountain_%s_%s_%d.json" % [row.path, row.outcome, Time.get_ticks_usec()]
		var store = Session.new(file, "slot_2")
		var game = Domain.new(Registry.new(), store, "slot_2")
		if not game.start(row.path):
			return _fail("start")
		for direction in ["right", "right", "left", "left", "left"]:
			if not game.choose(direction, game.issue_choice_token()):
				return _fail("teaching")
		var first_result := _result(game.battle_request(), "victory")
		if not game.submit_battle_result(first_result) or not game.choose("left", game.issue_choice_token()):
			return _fail("first reward")
		if game.state.phase == "FLOW_PENDING" and not game.resume_flow():
			return _fail("continuation")
		if game.state.phase == "MILESTONE_PENDING" and not game.choose("left", game.issue_choice_token()):
			return _fail("inserted chapter")
		var route: Dictionary = game.state.duplicate(true)
		if game.state.currentCardId != "q_mountain_shadow_approach" \
				or not game.can_choose_direction("left") or not game.choose("left", game.issue_choice_token()):
			return _fail("mountain left has no second-battle consumer")
		var warning: Dictionary = game.get_current_card()
		for key in ["id", "type", "title", "description", "sceneImage"]:
			if warning.get(key) != row.warning.get(key):
				return _fail("warning source presentation mismatch: " + key)
		for direction in ["left", "right"]:
			for key in ["text", "desc"]:
				if warning.choices[direction].get(key) != row.warning.choices[direction].get(key):
					return _fail("warning source choice mismatch: " + direction + "/" + key)
		if game.state.turn != route.turn or not _reopens(game):
			return _fail("warning clock/replay")
		if not game.choose("left", game.issue_choice_token()):
			return _fail("mountain preparation")
		var request: Dictionary = game.battle_request()
		if request.is_empty() or request.sourceCardId != row.sourceCard.id \
				or not _same(request.pendingResolution.sourceCard, row.sourceCard) \
				or not _same(request.pendingResolution.choice, row.pendingResolution.choice) \
				or request.pendingResolution.combatCard.has("combatRewards") \
				or not _same(request.playerSnapshot.battleLoadout.deck, route.deck) \
				or not request.playerSnapshot.battleLoadout.deck.has(row.seventhCardId) \
				or not _same(request.playerSnapshot.get("knowledge", {}), route.get("knowledge", {})) \
				or not _same(request.playerSnapshot.get("modifiers", {}), route.get("modifiers", {})) \
				or not _reopens(game):
			return _fail("mountain contract/source/current loadout/replay")
		var before: Dictionary = game.state.duplicate(true)
		var result := _result(request, row.outcome)
		if game.submit_battle_result(first_result) or not _same(game.state, before):
			return _fail("first battle receipt hijacked second battle")
		var bytes := FileAccess.get_file_as_bytes(store.v2_path)
		store.fail_promotion_once = true
		if game.submit_battle_result(result) or not _same(game.state, before) \
				or FileAccess.get_file_as_bytes(store.v2_path) != bytes:
			return _fail("second result save rollback")
		if not game.submit_battle_result(result):
			return _fail("second result rejected: " + game.flow_failure_reason())
		var current: Dictionary = game.get_current_card()
		if not _same(current, row.resultCard):
			for key in row.resultCard:
				if not _same(current.get(key), row.resultCard[key]):
					return _fail("second result field differs %s: actual=%s expected=%s" % [key, current.get(key), row.resultCard[key]])
			return _fail("second result has extra fields")
		if not _same(game.state.noncombatFlow.encounterDirectorState, route.noncombatFlow.encounterDirectorState):
			return _fail("second story battle changed director")
		if game.state.battleResultHistory.size() != 2 or not _reopens(game):
			return _fail("second battle history replay")
		for group in ["attributes", "resources"]:
			for key in ["cultivation", "fortune", "health", "daoHeart"] if group == "attributes" else ["spiritStone", "lifespan"]:
				var expected_delta := int(row.after[group][key]) - int(row.before[group][key])
				if int(game.state[group][key]) - int(before[group][key]) != expected_delta:
					return _fail("source second reward/injury delta differs: " + row.path + "/" + key)
		var last: Dictionary = game.state.choiceHistory.back()
		if last.cardType != "STORY" or last.cardId != row.sourceCard.id or last.tags != row.sourceCard.tags \
				or int(game.state.turn) != int(before.turn) + 1 or game.submit_battle_result(result):
			return _fail("story source receipt/duplicate")
		if not game.choose("down", game.issue_choice_token()) or game.state.phase != "FLOW_PENDING" \
				or game.state.has("authoredFirstSessionNext") or game.state.has("firstSessionContinuation") \
				or not _reopens(game) or not game.resume_flow() or not _reopens(game):
			return _fail("second outcome acknowledgement loops back or loses original flow")
		count += 1
		print("MOUNTAIN_BATTLE_PROGRESS path=%s outcome=%s elapsed_ms=%d" % [
			row.path, row.outcome, Time.get_ticks_msec() - row_started])
	print("NONCOMBAT_MOUNTAIN_BATTLE_PASS cases=%d source=true current_deck=true multiple_results=true atomic=true replay=true" % count)
	quit(0)
