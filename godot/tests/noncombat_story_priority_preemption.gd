extends SceneTree

const Repository = preload("res://scripts/noncombat_content_repository.gd")
const Registry = preload("res://scripts/runtime_data_registry.gd")
const Domain = preload("res://scripts/noncombat_domain.gd")
const StoryThreads = preload("res://scripts/noncombat_story_threads_v2_flow.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var game = Domain.new(Registry.new(), null, "slot_2")
	if not game.start("spell"):
		return _fail("priority fixture could not start")
	var state: Dictionary = game.state.duplicate(true)
	state.realm = "foundation"
	state.phase = "FLOW_PENDING"
	state.decisionCheckpoint = {"sourceCardId": "q_tianshu_4"}
	state.turn = 20
	state.runClock.decisionIndex = 20
	state.flags = {"tianshuCodexCompleted": true}
	state.questState = {"saveVersion": 3, "activeQuests": [],
		"completedQuests": ["tianshu_codex"], "closedQuests": ["tianshu_codex"],
		"questOutcomes": {"tianshu_codex": "completed"}}
	var prior := state.duplicate(true)
	prior.turn = 19
	prior.runClock.decisionIndex = 19
	var flow = StoryThreads.new(Repository.new())
	if not flow.tick(prior, state):
		return _fail("source high-priority thread did not activate")
	var high: Dictionary = state.storyThreadState.threads.tianshu_seal_echo
	if high.get("status") != "active":
		return _fail("tianshu was not eligible for priority arbitration")
	var low: Dictionary = state.storyThreadState.threads.spirit_mine
	low.status = "active"
	low.startedTurn = 1
	low.lastNodeTurn = 1
	low.nodeIndex = 0
	low.pendingNodeIndex = 0
	var selected: Dictionary = flow.resume(state)
	if selected.get("currentCardId") != "thread_tianshu_seal_echo_1" \
			or int(selected.get("storyThreadState", {}).get("threads", {}).get(
				"spirit_mine", {}).get("pendingNodeIndex", -1)) != 0:
		return _fail("eligible priority-90 scene did not preempt lower pending thread")
	print("NONCOMBAT_STORY_PRIORITY_PREEMPTION_PASS high=true low_pending_preserved=true")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
