extends "res://tests/noncombat_foundation_tianshu_quest.gd"

const HigherThreadFlow = preload("res://scripts/noncombat_story_threads_v2_flow.gd")


func _run() -> void:
	var game = Domain.new(Registry.new(), null, "slot_2")
	if not game.start("spell"):
		return _fail("higher thread fixture could not start")
	var state: Dictionary = game.state.duplicate(true)
	state.realm = "foundation"
	state.phase = "FLOW_PENDING"
	state.decisionCheckpoint = {"sourceCardId": "q_tianshu_4"}
	state.turn = 20
	state.runClock.decisionIndex = 20
	state.flags = {"tianshuCodexCompleted": true}
	state.knowledge = {}
	state.questState = {"saveVersion": 3, "activeQuests": [],
		"completedQuests": ["tianshu_codex"], "closedQuests": ["tianshu_codex"],
		"questOutcomes": {"tianshu_codex": "completed"}}
	var prior := state.duplicate(true)
	prior.turn = 19
	prior.runClock.decisionIndex = 19
	var flow = HigherThreadFlow.new(ContentRepository.new())
	if not flow.tick(prior, state) or state.get("storyThreadState", {}).get(
			"higherSourcePins") != flow.higher_source_pins():
		return _fail("higher source threads did not enter versioned scheduler")
	state.turn += 2
	state.runClock.decisionIndex += 2
	var first: Dictionary = flow.resume(state)
	if first.get("currentCardId") != "thread_tianshu_seal_echo_1":
		return _fail("completed tianshu did not schedule source priority thread: " +
			JSON.stringify({"error": flow.last_error,
				"threads": state.storyThreadState.threads,
				"first": first.get("currentCardId")}))
	var second: Dictionary = flow.settle_choice(first, "left")
	if second.is_empty():
		return _fail("tianshu thread first node did not settle: " + flow.last_error)
	second.turn += 2
	second.runClock.decisionIndex += 2
	var variant: Dictionary = flow.resume(second)
	var source: Dictionary = ContentRepository.new().read_module(
		"threads:foundation_threads")
	var authored: Dictionary = source.threads[0].nodes[1].variants[0].card
	if variant.get("currentCardId") != "thread_tianshu_seal_echo_2" \
			or not String(variant.get("pendingThreadCard", {}).get(
				"description", "")).ends_with(String(authored.description)):
		return _fail("tianshu thread second node lost first-choice variant")
	var done: Dictionary = flow.settle_choice(variant, "left")
	if done.get("storyThreadState", {}).get("threads", {}).get(
			"tianshu_seal_echo", {}).get("status") != "completed" \
			or done.get("storyThreadState", {}).get("threads", {}).get(
				"tianshu_seal_echo", {}).get("receipt", {}).get("nodes", []).size() != 2:
		return _fail("tianshu thread completion receipt missing: " + flow.last_error)
	var register: Dictionary = flow.resume(done)
	if register.get("currentCardId") != "thread_sect_register_1":
		return _fail("sect register did not resume after tianshu thread")
	var register_done: Dictionary = flow.settle_choice(register, "left")
	if register_done.is_empty():
		return _fail("sect register first node did not settle: " + flow.last_error)
	register_done.turn += 2
	register_done.runClock.decisionIndex += 2
	var ledger: Dictionary = flow.resume(register_done)
	if ledger.get("currentCardId") != "thread_sect_register_2":
		return _fail("sect register second node did not present")
	register_done = flow.settle_choice(ledger, "right")
	if register_done.is_empty():
		return _fail("sect register ledger did not settle: " + flow.last_error)
	register_done.turn += 2
	register_done.runClock.decisionIndex += 2
	var verdict: Dictionary = flow.resume(register_done)
	if verdict.get("currentCardId") != "thread_sect_register_3":
		return _fail("sect register verdict did not present")
	register_done = flow.settle_choice(verdict, "right")
	if register_done.get("storyThreadState", {}).get("threads", {}).get(
			"sect_shadow_register", {}).get("receipt", {}).get("nodes", []).size() != 3:
		return _fail("sect register completion receipt missing: " + flow.last_error)
	var tribulation := register_done.duplicate(true)
	tribulation.realm = "tribulation"
	# Keep this fixture scoped to the gate testimony; a physical Bai Ren now
	# legitimately activates the higher-priority last lesson at this turn.
	tribulation.worldContinuityState.npcs.bai_ren.manifestation = "ECHO_ONLY"
	tribulation.turn += 5
	tribulation.runClock.decisionIndex += 5
	var tribulation_prior := tribulation.duplicate(true)
	tribulation_prior.turn -= 1
	tribulation_prior.runClock.decisionIndex -= 1
	if not flow.tick(tribulation_prior, tribulation):
		return _fail("tribulation testimony did not activate: " + flow.last_error)
	tribulation.turn += 2
	tribulation.runClock.decisionIndex += 2
	var testimony: Dictionary = flow.resume(tribulation)
	var echoes: Array = ContentRepository.new().read_module(
		"threads:tribulation_threads").threads[0].nodes[0].receiptEchoes
	var testimony_text := String(testimony.get("pendingThreadCard", {}).get(
		"description", ""))
	if testimony.get("currentCardId") != "thread_gate_testimony_1" \
			or not testimony_text.contains(echoes[0].directions.preserve_evidence) \
			or not testimony_text.contains(echoes[1].directions.rescue_first) \
			or not testimony_text.contains(echoes[2].missing):
		return _fail("tribulation testimony lost source receipt or neutral echoes")
	var forged := tribulation.duplicate(true)
	forged.storyThreadState.threads.tianshu_seal_echo.receipt.nodes[1][
		"threadDirection"] = "guard_the_path"
	var neutral: Dictionary = flow.resume(forged)
	if not String(neutral.get("pendingThreadCard", {}).get(
			"description", "")).contains(echoes[0].missing):
		return _fail("mismatched completion receipt projected an invented echo")
	var abandoned: Dictionary = game.state.duplicate(true)
	abandoned.realm = "foundation"
	abandoned.phase = "FLOW_PENDING"
	abandoned.decisionCheckpoint = {"sourceCardId": "q_tianshu_1"}
	abandoned.turn = 20
	abandoned.runClock.decisionIndex = 20
	abandoned.flags = {"tianshuCodexCompleted": false}
	abandoned.questState = {"saveVersion": 3, "activeQuests": [],
		"completedQuests": [], "closedQuests": ["tianshu_codex"],
		"questOutcomes": {"tianshu_codex": "abandoned"}}
	var abandoned_prior: Dictionary = abandoned.duplicate(true)
	abandoned_prior.turn -= 1
	abandoned_prior.runClock.decisionIndex -= 1
	var other = HigherThreadFlow.new(ContentRepository.new())
	if not other.tick(abandoned_prior, abandoned) \
			or abandoned.storyThreadState.threads.tianshu_seal_echo.status != "inactive":
		return _fail("abandoned tianshu unlocked completion-only story thread")
	var drifted := first.duplicate(true)
	drifted.storyThreadState.higherSourcePins["threads:foundation_threads"] = "wrong"
	if not flow.card(drifted).is_empty() or flow.last_error.is_empty():
		return _fail("high story thread accepted changed source pin")
	print("NONCOMBAT_FOUNDATION_HIGHER_THREADS_PASS tianshu=true variant=true receipt=true sect=true refusal=true pin=true echoes=true")
	quit(0)
