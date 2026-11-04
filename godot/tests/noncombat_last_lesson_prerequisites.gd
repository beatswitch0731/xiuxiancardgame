extends SceneTree

const ContentRepository = preload("res://scripts/noncombat_content_repository.gd")
const StoryThreads = preload("res://scripts/noncombat_story_threads_v2_flow.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var source = ContentRepository.new()
	var flow = StoryThreads.new(source)
	var document: Dictionary = source.read_module("threads:last_lesson_threads")
	var definition: Dictionary = document.get("threads", [])[0]
	var state := {"realm": "deity", "turn": 12, "lifeCount": 0,
		"runClock": {"lifeId": "life:0", "decisionIndex": 12},
		"worldContinuityState": {"version": 1, "lifeId": 0, "npcs": {
			"bai_ren": {"npcId": "bai_ren", "lifeId": 0,
				"lifecycle": "ACTIVE", "manifestation": "PHYSICAL"},
			"jian_linger": {"npcId": "jian_linger", "lifeId": 0,
				"lifecycle": "ACTIVE", "manifestation": "PHYSICAL"}}}}
	if definition.get("threadId") != "bairen_last_lesson" \
			or not flow._trigger_matches(definition.trigger, state) \
			or not flow._requirements_match(definition.requirements, state) \
			or not flow._realm_matches(definition, "deity") \
			or not flow._realm_matches(definition, "tribulation") \
			or flow._realm_matches(definition, "qi"):
		return _fail("last lesson source prerequisites were not admitted")
	state.turn = 11
	if flow._trigger_matches(definition.trigger, state):
		return _fail("last lesson admitted before source turn threshold")
	state.turn = 12
	state.worldContinuityState.npcs.jian_linger.manifestation = "ECHO_ONLY"
	if flow._requirements_match(definition.requirements, state):
		return _fail("last lesson admitted without physical sword apprentice")
	state.worldContinuityState.npcs.jian_linger.manifestation = "PHYSICAL"
	state.worldContinuityState.npcs.bai_ren.lifecycle = "DEAD"
	if flow._requirements_match(definition.requirements, state):
		return _fail("last lesson admitted deceased master")
	state.worldContinuityState = null
	if flow._requirements_match(definition.requirements, state):
		return _fail("last lesson admitted missing continuity registry")
	print("NONCOMBAT_LAST_LESSON_PREREQUISITES_PASS turn=true physical=true")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
