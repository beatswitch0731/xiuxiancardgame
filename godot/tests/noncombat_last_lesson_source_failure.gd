extends SceneTree

const Repository = preload("res://scripts/noncombat_content_repository.gd")
const StoryThreads = preload("res://scripts/noncombat_story_threads_v2_flow.gd")

class MissingLessonContent extends "res://scripts/noncombat_content_repository.gd":
	func module_path(module_id: String) -> String:
		return "data/threads/absent_last_lesson.json" if module_id == \
			"threads:last_lesson_threads" else super.module_path(module_id)

	func source_sha256(module_id: String) -> String:
		return "" if module_id == "threads:last_lesson_threads" else \
			super.source_sha256(module_id)

	func read_module(module_id: String) -> Variant:
		return null if module_id == "threads:last_lesson_threads" else \
			super.read_module(module_id)

class ChangedLessonContent extends "res://scripts/noncombat_content_repository.gd":
	func read_module(module_id: String) -> Variant:
		return {"threads": []} if module_id == "threads:last_lesson_threads" else \
			super.read_module(module_id)


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	for spec in [[MissingLessonContent.new(), true], [ChangedLessonContent.new(), false]]:
		var flow = StoryThreads.new(spec[0])
		var state := {"lifeCount": 0, "realm": "deity", "turn": 12,
			"runClock": {"lifeId": "life:0", "decisionIndex": 12},
			"worldContinuityState": {"version": 1, "lifeId": 0, "npcs": {
				"bai_ren": {"npcId": "bai_ren", "lifeId": 0,
					"lifecycle": "ACTIVE", "manifestation": "PHYSICAL"},
				"jian_linger": {"npcId": "jian_linger", "lifeId": 0,
					"lifecycle": "ACTIVE", "manifestation": "PHYSICAL"}}}}
		var prior: Dictionary = state.duplicate(true)
		prior.turn = 11
		prior.runClock.decisionIndex = 11
		if flow.tick(prior, state) or flow.source_missing() != spec[1] \
				or flow.last_error.is_empty():
			return _fail("last lesson missing/drifted source was misclassified")
	print("NONCOMBAT_LAST_LESSON_SOURCE_FAILURE_PASS missing=true drift=true")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
