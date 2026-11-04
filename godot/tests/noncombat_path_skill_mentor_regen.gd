extends SceneTree

const Domain = preload("res://scripts/noncombat_domain.gd")
const Registry = preload("res://scripts/runtime_data_registry.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var game = Domain.new(Registry.new(), null, "slot_3")
	if not game.start("sword"):
		return _fail("sword opening failed")
	for step in 5:
		if not game.choose("left", game.issue_choice_token()):
			return _fail("tutorial choice failed")
	for direction in ["right", "left"]:
		if not game.choose(direction, game.issue_choice_token()):
			return _fail("opening choice failed")
	if not game.resume_flow() or not game.choose("left", game.issue_choice_token()) \
			or not game.choose("right", game.issue_choice_token()) \
			or not game.resume_flow() or not game.choose("left", game.issue_choice_token()) \
			or not game.resume_flow() or not game.choose("left", game.issue_choice_token()) \
			or not game.resume_flow() or game.state.get("phase") != "MENTOR_PENDING":
		return _fail("source mentor pending state unreachable")
	var candidate: Dictionary = game.state.duplicate(true)
	candidate.path = "body"
	candidate.realm = "golden"
	candidate.attributes.health = 4
	candidate.pendingMentorCard = game._mentor_flow._project_card(candidate,
		"INNER_DISCIPLE")
	var legacy: Dictionary = game._mentor_flow.settle(candidate, "right", false)
	if legacy.is_empty() or int(legacy.attributes.health) != 4:
		return _fail("legacy mentor replay gained new turn regeneration")
	var settled: Dictionary = game._mentor_flow.settle(candidate, "right")
	if settled.is_empty():
		return _fail("mentor choice rejected")
	if int(settled.attributes.health) != 5:
		return _fail("mentor choice skipped body turn regeneration: %s" %
			settled.attributes.health)
	print("NONCOMBAT_PATH_SKILL_MENTOR_REGEN_PASS health=4>5 legacy=4")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
