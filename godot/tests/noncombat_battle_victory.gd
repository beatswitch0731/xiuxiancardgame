extends "res://tests/noncombat_battle_return.gd"

func _run() -> void:
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/battle_victory_source.json"))
	var count := 0
	for row in fixture.rows:
		var file := "user://tests/victory_%s_%s_%d.json" % [row.path, row.direction, Time.get_ticks_usec()]
		var store = Session.new(file, "slot_2")
		var game = Domain.new(Registry.new(), store, "slot_2")
		if not game.start(row.path):
			return _fail("victory opening")
		for direction in ["right", "right", "left", "left", "left"]:
			if not game.choose(direction, game.issue_choice_token()):
				return _fail("victory natural route")
		var before: Dictionary = game.state.duplicate(true)
		var result := _result(game.battle_request(), "victory")
		store.fail_promotion_once = true
		var bytes := FileAccess.get_file_as_bytes(store.v2_path)
		if game.submit_battle_result(result) or not _same(game.state, before) \
				or bytes != FileAccess.get_file_as_bytes(store.v2_path):
			return _fail("victory failed save mutated rewards")
		if not game.submit_battle_result(result):
			return _fail("victory consumer missing: " + game.flow_failure_reason())
		for key in ["attributes", "resources", "knowledge", "modifiers", "deck", "skillAcquisitions", "deckOperations", "turn"]:
			if not _same(game.state.get(key, {}), row.victory[key]):
				return _fail("victory source mismatch %s/%s: %s != %s" % [row.path, key, game.state.get(key), row.victory[key]])
		if not _same(game.get_current_card(), row.rewardCard) or not _reopens(game):
			return _fail("reward card/source replay mismatch " + row.path)
		var rewarded: Dictionary = game.state.duplicate(true)
		if game.submit_battle_result(result) or not _same(game.state, rewarded):
			return _fail("duplicate victory granted twice")
		var token: int = game.issue_choice_token()
		store.fail_promotion_once = true
		if game.choose(row.direction, token) or not _same(game.state, rewarded):
			return _fail("reward selection not atomic")
		if not game.choose(row.direction, token):
			return _fail("reward choice refused " + row.path + "/" + row.direction)
		for key in ["deck", "skillAcquisitions", "deckOperations", "attributes", "resources", "knowledge", "modifiers", "turn"]:
			if not _same(game.state.get(key, {}), row.chosen[key]):
				return _fail("acquired reward differs: " + row.path + "/" + key)
		if game.choose(row.direction, token) or not _reopens(game):
			return _fail("reward duplicate/reopen")
		# Random ambient rolls use the existing persisted Godot RNG; the authored
		# continuation must survive one inserted decision, whichever path rolled it.
		if game.state.phase == "FLOW_PENDING" and not game.resume_flow():
			return _fail("reward interrupt cannot resume")
		if game.state.phase == "MILESTONE_PENDING":
			if not game.choose("left", game.issue_choice_token()):
				return _fail("inserted chapter choice")
		if game.get_current_card().get("id") != "q_mountain_shadow_approach" \
				or not _same(game.get_current_card(), row.routeCard) or not _reopens(game):
			return _fail("protected route lost or chapter chain swallowed it: " + str(game.state.get("phase")))
		if not game.choose("right", game.issue_choice_token()) \
				or not _same(game.get_current_card(), row.marketCard) or not _reopens(game):
			return _fail("serial market transition or original artwork differs")
		count += 1
	print("NONCOMBAT_BATTLE_VICTORY_PASS cases=%d rewards=true deck=true continuation=true replay=true atomic=true" % count)
	quit(0)
