extends "res://tests/noncombat_normal_runtime.gd"

const CAVE_ROLL := 0.323

func _run() -> void:
	var path := "user://tests/cave_entry_%d.json" % Time.get_ticks_usec()
	var game = Domain.new(Registry.new(), RunSession.new(path, "slot_3"), "slot_3")
	_set_zero_rolls(game)
	if not _reach_decision27(game):
		return _fail("natural route did not reach the cave draw")
	game._normal_roll_override = CAVE_ROLL
	if not game.resume_flow() or game.get_current_card().get("id") != "q_cave":
		return _fail("ordinary pool did not draw q_cave")
	var oracle: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(
		"res://tests/fixtures/cave_mist_source.json"))
	var source: Dictionary = game.get_current_card()
	for key in ["id", "title", "description", "type", "realm", "choices", "sceneImage"]:
		if not _same(source.get(key), oracle["sourceCard"].get(key)):
			return _fail("cave source card mismatch: " + key)
	var before: Dictionary = game.state.duplicate(true)
	if not game.can_choose_direction("right") \
			or not game.choose("right", game.issue_choice_token()):
		return _fail("q_cave right did not enter the authored dungeon")
	var entry: Dictionary = game.state
	if entry.get("phase") != "NORMAL_PENDING" \
			or entry.get("dungeonRun", {}).get("sourceCardId") != "q_cave" \
			or entry.get("dungeonRun", {}).get("sourceDecisionIndex") != int(
				before["runClock"]["decisionIndex"]) + 1 \
			or entry.get("dungeonNodeIndex") != 0 \
			or entry.get("dungeonOutcomeReceipts", []).size() != 0:
		return _fail("cave run entry ledger differs from browser")
	var source_seed: Dictionary = {}
	for row in oracle["afterEntry"]["karmaSeeds"]:
		if row.get("id") == "spellHidden":
			source_seed = row
			break
	var godot_seed: Dictionary = {}
	for row in entry.get("karmaSeeds", []):
		if row.get("id") == "spellHidden":
			godot_seed = row
			break
	for key in ["delay", "realm", "priority", "originCard", "originChoice", "context"]:
		if not _same(godot_seed.get(key), source_seed.get(key)):
			return _fail("cave spellHidden seed mismatch: " + key)
	if not _reopen(game):
		return _fail("cave entry did not strictly recover")
	var authored: Array = oracle["branches"]["left_left_left"]["cards"]
	for index in 3:
		if game.state.get("phase") == "DESTINY_WHEEL_PENDING":
			if not _reopen(game) or not game.choose("left", game.issue_choice_token()) \
					or game.get_current_card().get("id") != "cave_reward":
				return _fail("due destiny wheel did not return to cave reward")
		var current: Dictionary = game.get_current_card()
		for key in ["id", "title", "description", "type", "choices", "sceneImage"]:
			if not _same(current.get(key), authored[index].get(key)):
				return _fail("authored cave node differs from browser: %d/%s" % [index, key])
		if not game.choose("left", game.issue_choice_token()):
			return _fail("cave node left choice failed: " + current.get("id", ""))
		if index < 2 and not _reopen(game):
			return _fail("cave node did not strictly recover: " + current.get("id", ""))
	var receipts: Array = game.state.get("dungeonOutcomeReceipts", [])
	if game.state.get("dungeonRun") != null or game.state.get("dungeon") != null \
			or receipts.size() != 1 or receipts[0].get("outcome") != "success" \
			or receipts[0].get("sourceCardId") != "q_cave" \
			or receipts[0].get("sourceDecisionIndex") != entry[
				"dungeonRun"]["sourceDecisionIndex"] \
			or receipts[0].get("settledDecisionIndex") != game.state[
				"runClock"]["decisionIndex"]:
		return _fail("cave completion did not write one owned success receipt")
	if game.state.get("storyThreadState", {}).get("threads", {}).get(
			"mist_valley", {}).get("status") != "active":
		return _fail("successful cave did not activate mist valley")
	if not _reopen(game):
		return _fail("completed cave did not strictly recover")
	print("NONCOMBAT_CAVE_ENTRY_PASS natural=true nodes=3 receipt=true replay=true")
	quit(0)


func _same(left: Variant, right: Variant) -> bool:
	return JSON.parse_string(JSON.stringify(left)) == JSON.parse_string(JSON.stringify(right))


func _reopen(game: RefCounted) -> bool:
	var loaded = Domain.new(Registry.new(), RunSession.new(game._store.legacy_path,
		"slot_3"), "slot_3")
	_set_zero_rolls(loaded)
	loaded._normal_roll_override = CAVE_ROLL
	return loaded.restore() and _same(loaded.state, game.state) \
		and _same(loaded.get_current_card(), game.get_current_card())
