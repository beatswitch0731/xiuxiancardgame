extends SceneTree

const Registry = preload("res://scripts/runtime_data_registry.gd")
const Domain = preload("res://scripts/noncombat_domain.gd")
const TRACE_PATH := "res://content/fixtures/noncombat_prologue_source_trace.json"


func _initialize() -> void:
	var trace: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(TRACE_PATH))
	if trace.get("cases", []).size() != 8:
		_fail("live browser trace must cover four paths and both choices")
		return
	var registry = Registry.new()
	for case in trace["cases"]:
		var path_id: String = case["path"]
		var direction: String = case["direction"]
		var game = Domain.new(registry)
		if not game.start(path_id) or not game.choose("right", game.issue_choice_token()) \
				or not game.choose("left", game.issue_choice_token()):
			_fail("could not replay source tutorial: %s" % path_id)
			return
		if game.get_current_card().get("id") != "q_start_" + path_id:
			_fail("source prologue was not reached: %s" % path_id)
			return
		var token: int = game.issue_choice_token()
		if token <= 0 or not game.choose(direction, token):
			_fail("source prologue choice was rejected: %s/%s" % [path_id, direction])
			return
		var expected: Dictionary = case["after"]
		for key in ["currentCardId", "path", "realm", "turn", "maxHealth", "maxDaoHeart",
				"cardsPlayed", "karmaSeeds", "pendingKarmaSeeds", "karmaPromiseFlags",
				"choiceHistory", "recentCardTags", "runClock", "decisionCheckpoint",
				"tutorialCompleted"]:
			if not _same(game.state.get(key), expected.get(key)):
				_fail("source mismatch %s/%s field %s: %s versus %s" % [
					path_id, direction, key, str(game.state.get(key)), str(expected.get(key))])
				return
		for key in expected["attributes"]:
			if not _same(game.state["attributes"].get(key), expected["attributes"][key]):
				_fail("source attribute mismatch %s/%s %s" % [path_id, direction, key])
				return
		for key in expected["resources"]:
			if not _same(game.state["resources"].get(key), expected["resources"][key]):
				_fail("source resource mismatch %s/%s %s" % [path_id, direction, key])
				return
		if game.state.get("phase") != "COMBAT_HANDOFF" or game.issue_choice_token() <= 0:
			_fail("teaching encounter did not stop at the battle interface")
			return
		var committed: Dictionary = game.state.duplicate(true)
		if game.choose(direction, token) or game.state != committed:
			_fail("prologue accepted a duplicate decision")
			return
	print("NONCOMBAT_PROLOGUE_PARITY_PASS paths=4 choices=8 handoff=4")
	quit(0)


func _same(left: Variant, right: Variant) -> bool:
	return JSON.parse_string(JSON.stringify(left)) == JSON.parse_string(JSON.stringify(right))


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
