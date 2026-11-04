extends SceneTree

const Domain = preload("res://scripts/noncombat_domain.gd")
const Registry = preload("res://scripts/runtime_data_registry.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var game = Domain.new(Registry.new(), null, "slot_1")
	if not game.start("body") or not game.choose("left", game.issue_choice_token()):
		return _fail("body opening did not activate hint schedule")
	var candidate: Dictionary = game.state.duplicate(true)
	candidate.realm = "golden"
	candidate.attributes.health = 4
	candidate.heavensHintState.totalTicks = int(candidate.runClock.decisionIndex)
	candidate.heavensHintState.hintsRevealed = [0]
	candidate.heavensHintState.issuedHints = [{"turn": int(candidate.turn), "index": 0}]
	var hint = game._hint_flow
	var card: Dictionary = hint._project(candidate, int(candidate.turn), 0,
		hint._pool()[0])
	candidate.pendingHintChoiceCard = card
	candidate.currentCardId = card.id
	candidate.phase = "HINT_PENDING"
	game.state = candidate
	if game.get_current_card().get("id") != card.id:
		return _fail("source hint card was not valid in the constructed run")
	if not game.choose("left", game.issue_choice_token()):
		return _fail("source hint choice was rejected: " + game.flow_failure_reason())
	if int(game.state.attributes.health) != 5:
		return _fail("hint choice skipped body turn regeneration: %s" %
			game.state.attributes.health)
	print("NONCOMBAT_PATH_SKILL_HINT_REGEN_PASS health=4>5")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
