extends SceneTree

const Registry = preload("res://scripts/runtime_data_registry.gd")
const Domain = preload("res://scripts/noncombat_domain.gd")
const ContentRepository = preload("res://scripts/noncombat_content_repository.gd")
const StoryThreads = preload("res://scripts/noncombat_story_threads_v2_flow.gd")
const RunSession = preload("res://scripts/noncombat_run_session.gd")
const REBIRTH_FIXTURE := "res://tests/fixtures/pill_decision54_death_probe_v2.json"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var game = Domain.new(Registry.new(), null, "slot_3")
	if not game.start("sword"):
		return _fail("source opening unavailable")
	var flow = StoryThreads.new(ContentRepository.new())
	var prior: Dictionary = game.state.duplicate(true)
	prior["lifeCount"] = 1
	prior["runClock"]["lifeId"] = "slot_3:life:1"
	prior["phase"] = "FLOW_PENDING"
	prior["realm"] = "qi"
	prior["path"] = "sword"
	prior["decisionCheckpoint"] = {"version": 1, "cardId": null,
		"sourceCardId": "q_spiritStone", "turn": 0, "decisionIndex": 0,
		"flowPending": true}
	prior.erase("storyThreadState")
	var first: Dictionary = prior.duplicate(true)
	first["turn"] = 1
	first["runClock"]["decisionIndex"] = 1
	if not flow.tick(prior, first) \
			or first.get("storyThreadState", {}).get("version") != 2 \
			or first.storyThreadState.get("lifeCount") != 1 \
			or first.storyThreadState.get("threads", {}).size() != 12:
		return _fail("second-life first decision did not start its own thread ledger")
	var triggered: Dictionary = first.duplicate(true)
	triggered["turn"] = 4
	triggered["runClock"]["decisionIndex"] = 4
	triggered["choiceHistory"] = [{"cardId": "q_spiritStone", "direction": "right",
		"turn": 1, "decisionIndex": 1}]
	if not flow.tick(first, triggered) \
			or flow.thread_state(triggered, "spirit_mine").get("status") != "active":
		return _fail("second-life source choice did not activate spirit mine")
	triggered["turn"] = 6
	triggered["runClock"]["decisionIndex"] = 6
	var pending: Dictionary = flow.resume(triggered)
	if pending.get("phase") != "THREAD_PENDING" \
			or pending.get("currentCardId") != "thread_spirit_mine_1" \
			or flow.card(pending).get("id") != "thread_spirit_mine_1":
		return _fail("second-life thread did not produce its source card")
	var settled: Dictionary = flow.settle_choice(pending, "left")
	if settled.get("phase") != "FLOW_PENDING" \
			or settled.get("storyThreadState", {}).get("lifeCount") != 1 \
			or settled.get("runClock", {}).get("lifeId") != "slot_3:life:1" \
			or flow.thread_state(settled, "spirit_mine").get("choices", []).size() != 1:
		return _fail("second-life thread choice lost its life-scoped receipt")
	var wrong_life: Dictionary = pending.duplicate(true)
	wrong_life["lifeCount"] = 2
	if not flow.resume(wrong_life).is_empty():
		return _fail("previous-life thread card crossed the new-life boundary")
	if not _disk_rebirth():
		return
	print("NONCOMBAT_REBIRTH_STORY_THREADS_PASS ledger=true trigger=true card=true choice=true boundary=true cold=true")
	quit(0)


func _disk_rebirth() -> bool:
	var path := "user://tests/rebirth_story_%d_%d.json" % [
		OS.get_process_id(), Time.get_ticks_usec()]
	var store = RunSession.new(path, "slot_3")
	var file := FileAccess.open(store.v2_path, FileAccess.WRITE)
	if file == null:
		_fail("cannot stage first-life source checkpoint")
		return false
	file.store_string(FileAccess.get_file_as_string(REBIRTH_FIXTURE))
	file.close()
	var newborn = Domain.new(Registry.new(), store, "slot_3")
	_stabilize(newborn)
	if not newborn.restore() or not newborn.resume_flow() \
			or newborn.get_current_card().get("id") != "q_love" \
			or not newborn.choose("right", newborn.issue_choice_token()) \
			or not newborn.choose("left", newborn.issue_choice_token()) \
			or not newborn.select_rebirth_path("spell") \
			or not newborn.choose("down", newborn.issue_choice_token()) \
			or not newborn.cancel_camp_target(newborn.issue_choice_token()):
		_fail("source death did not produce a second-life decision")
		return false
	if newborn.state.get("storyThreadState", {}).get("lifeCount") != 1 \
			or newborn.state.get("storyThreadState", {}).get("threads", {}).size() != 12:
		_fail("first second-life decision did not persist new thread ledger")
		return false
	var cold = Domain.new(Registry.new(), RunSession.new(path, "slot_3"), "slot_3")
	_stabilize(cold)
	if not cold.restore() or JSON.parse_string(JSON.stringify(cold.state)) != \
			JSON.parse_string(JSON.stringify(newborn.state)):
		_fail("new second-life thread ledger failed strict cold replay")
		return false
	return true


func _stabilize(game: RefCounted) -> void:
	game._normal_roll_override = 0.55
	game._market_flow.roll_override = 0.0
	game._destiny_wheel_flow.roll_override = 0.0
	game._ripple_flow.roll_override = 0.999
	game._hint_flow.roll_override = 0.0


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
