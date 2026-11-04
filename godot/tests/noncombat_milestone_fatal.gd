extends SceneTree

const Registry = preload("res://scripts/runtime_data_registry.gd")
const Domain = preload("res://scripts/noncombat_domain.gd")
const RunSession = preload("res://scripts/noncombat_run_session.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var path := "user://tests/milestone_fatal_%d.json" % Time.get_ticks_usec()
	var game = Domain.new(Registry.new(), RunSession.new(path, "slot_3"), "slot_3")
	if not game.start("body"):
		return _fail("body opening unavailable")
	for step in 5:
		if not game.choose("left", game.issue_choice_token()):
			return _fail("tutorial source choice blocked at " + str(step))
	if not game.choose("right", game.issue_choice_token()) \
			or not game.choose("left", game.issue_choice_token()) \
			or not game.resume_flow() \
			or game.get_current_card().get("id") != "ch_qi_20":
		return _fail("source first chapter milestone did not arrive")
	# Expose the authored right-choice blood-loss boundary without an unrelated
	# combat route. The card and chapter scheduling above are production output.
	game._store = null
	game.state["maxHealth"] = 1
	game.state["maxDaoHeart"] = 1
	game.state["attributes"]["health"] = 1
	game.state["attributes"]["daoHeart"] = 1
	var before_index := int(game.state.get("runClock", {}).get("decisionIndex", -1))
	if not game.choose("right", game.issue_choice_token()):
		return _fail("fatal authored chapter right choice was rejected")
	if game.state.get("phase") != "DEATH_PENDING" \
			or game.get_current_card().get("id") != "death_blood_loss" \
			or game.state.get("deathCauseId") != "death_blood_loss" \
			or game.state.get("decisionCheckpoint", {}).get("sourceCardId") != "ch_qi_20" \
			or int(game.state.get("attributes", {}).get("health", -1)) != 0 \
			or int(game.state.get("runClock", {}).get("decisionIndex", -1)) != before_index + 1:
		return _fail("chapter fatal settlement or authored blood-loss card diverged: "
			+ JSON.stringify({"phase": game.state.get("phase"),
				"card": game.get_current_card().get("id"),
				"cause": game.state.get("deathCauseId"),
				"health": game.state.get("attributes", {}).get("health"),
				"choice": game.state.get("choiceHistory", []).back()}))
	print("NONCOMBAT_MILESTONE_FATAL_PASS source=true death=true")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
