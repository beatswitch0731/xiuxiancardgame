extends SceneTree

const Registry = preload("res://scripts/runtime_data_registry.gd")
const Domain = preload("res://scripts/noncombat_domain.gd")


func _initialize() -> void:
	var data = Registry.new()
	var game = Domain.new(data)
	if game.start("unknown") or not game.state.is_empty():
		_fail("invalid path changed the opening state")
		return
	if not game.start("sword"):
		_fail("source sword path did not start")
		return
	if not _matches(game.state, {
		"path": "sword", "realm": "qi", "turn": 0,
		"currentCardId": "tutorial_1", "tutorialCompleted": false,
		"maxHealth": 5, "maxDaoHeart": 4,
		"cultivation": 5, "health": 4, "daoHeart": 3,
		"fortune": 50, "spiritStone": 10, "lifespan": 80,
		"cardsPlayed": [],
	}):
		return
	var card: Dictionary = game.get_current_card()
	card["title"] = "mutated view"
	if game.get_current_card().get("title") != "初入仙途":
		_fail("source card was exposed as mutable runtime data")
		return
	var token: int = game.issue_choice_token()
	if token <= 0 or not game.choose("right", token):
		_fail("M0 tutorial_1 right choice rejected")
		return
	var settled: Dictionary = game.state.duplicate(true)
	if game.choose("left", token) or game.state != settled:
		_fail("stale choice token applied a second decision")
		return
	if not _matches(game.state, {
		"turn": 1, "currentCardId": "tutorial_4", "cultivation": 10,
		"cardsPlayed": ["tutorial_1"], "tutorialCompleted": false,
	}):
		return
	if not game.choose("left", game.issue_choice_token()):
		_fail("M0 tutorial_4 left choice rejected")
		return
	if not _matches(game.state, {
		"turn": 2, "currentCardId": "q_start_sword", "cultivation": 13,
		"health": 5, "lifespan": 80,
		"cardsPlayed": ["tutorial_1", "tutorial_4"],
		"tutorialCompleted": true,
	}):
		return
	if game.issue_choice_token() <= 0 or game.choose("left", token):
		_fail("starter-card choice token did not advance with the source decision")
		return
	if not _check_all_paths(data) or not _check_full_tutorial(data):
		return
	print("NONCOMBAT_OPENING_PARITY_PASS m0=2 choices paths=4 full_tutorial=4")
	quit(0)


func _check_all_paths(data: RefCounted) -> bool:
	var expected := {
		"spell": {"cultivation": 3, "daoHeart": 4, "maxDaoHeart": 5,
			"health": 5, "maxHealth": 6, "fortune": 60, "spiritStone": 10},
		"body": {"cultivation": 0, "daoHeart": 3, "maxDaoHeart": 4,
			"health": 7, "maxHealth": 8, "fortune": 50, "spiritStone": 10},
		"pill": {"cultivation": 3, "daoHeart": 2, "maxDaoHeart": 3,
			"health": 5, "maxHealth": 6, "fortune": 65, "spiritStone": 15},
	}
	for path_id in expected:
		var game = Domain.new(data)
		if not game.start(path_id) or not _matches(game.state, expected[path_id]):
			return false
		if not game.choose("right", game.issue_choice_token()) \
				or not game.choose("left", game.issue_choice_token()) \
				or game.state.get("currentCardId") != "q_start_" + path_id:
			_fail("tutorial did not reach source path starter: " + path_id)
			return false
	return true


func _check_full_tutorial(data: RefCounted) -> bool:
	var game = Domain.new(data)
	if not game.start("body"):
		_fail("body path did not start full tutorial")
		return false
	for expected_card_id in ["tutorial_2", "tutorial_3", "tutorial_4"]:
		if not game.choose("left", game.issue_choice_token()) \
				or game.state.get("currentCardId") != expected_card_id:
			_fail("full tutorial lost authored nextCard: " + expected_card_id)
			return false
	if not game.choose("right", game.issue_choice_token()):
		_fail("tutorial_4 risk choice rejected")
		return false
	return _matches(game.state, {
		"turn": 4, "currentCardId": "q_start_body",
		"cultivation": 10, "health": 7, "fortune": 51, "lifespan": 79,
		"cardsPlayed": ["tutorial_1", "tutorial_2", "tutorial_3", "tutorial_4"],
		"tutorialCompleted": true,
	})


func _matches(actual: Dictionary, expected: Dictionary) -> bool:
	for key in expected:
		var got: Variant = actual.get(key)
		if key in ["cultivation", "health", "daoHeart", "fortune"]:
			got = actual.get("attributes", {}).get(key)
		elif key in ["spiritStone", "lifespan"]:
			got = actual.get("resources", {}).get(key)
		if got != expected[key]:
			_fail("source parity mismatch %s: actual=%s expected=%s" % [key, str(got), str(expected[key])])
			return false
	return true


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
