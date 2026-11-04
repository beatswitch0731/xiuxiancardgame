extends "res://tests/noncombat_foundation_higher_threads.gd"


func _run() -> void:
	for spec in [
		{"realm": "golden", "module": "threads:golden_threads",
			"thread": "core_heaven_tax", "flag": "golden_core_tax_exposed"},
		{"realm": "nascent", "module": "threads:nascent_threads",
			"thread": "nascent_dream_witness",
			"flag": "nascent_ascension_testimony_verified"},
		{"realm": "deity", "module": "threads:deity_threads",
			"thread": "deity_heaven_net", "flag": "deity_heaven_net_mapped"},
		{"realm": "tribulation", "module": "threads:tribulation_threads",
			"thread": "tribulation_gate_testimony",
			"flag": "tribulation_gate_testimony_complete"},
	]:
		var game = Domain.new(Registry.new(), null, "slot_2")
		if not game.start("spell"):
			return _fail("higher thread fixture could not start")
		var state: Dictionary = game.state.duplicate(true)
		state.realm = spec.realm
		state.phase = "FLOW_PENDING"
		state.decisionCheckpoint = {"sourceCardId": "realm_arrival_" + spec.realm}
		state.turn = 20
		state.runClock.decisionIndex = 20
		state.flags = {}
		state.knowledge = {}
		if spec.realm in ["deity", "tribulation"]:
			# This fixture isolates the ordinary high-realm thread. A physical
			# master would now activate priority-100 last lesson first.
			state.worldContinuityState.npcs.bai_ren.manifestation = "ECHO_ONLY"
		var prior := state.duplicate(true)
		prior.turn = 19
		prior.runClock.decisionIndex = 19
		var flow = HigherThreadFlow.new(ContentRepository.new())
		if not flow.tick(prior, state):
			return _fail("higher thread did not start: " + spec.thread + " " +
				flow.last_error)
		var nodes: Array = ContentRepository.new().read_module(
			spec.module).threads[0].nodes
		for index in nodes.size():
			state.turn += 2
			state.runClock.decisionIndex += 2
			var presented: Dictionary = flow.resume(state)
			if presented.get("currentCardId") != nodes[index].card.id:
				return _fail("higher thread node did not present: " + spec.thread +
					"/" + str(index) + " " + flow.last_error)
			state = flow.settle_choice(presented, "right")
			if state.is_empty():
				return _fail("higher thread node did not settle: " + spec.thread +
					"/" + str(index) + " " + flow.last_error)
		if state.get("storyThreadState", {}).get("threads", {}).get(
				spec.thread, {}).get("status") != "completed" \
				or state.get("flags", {}).get(spec.flag) != true:
			return _fail("higher thread receipt or source flag missing: " + spec.thread)
	print("NONCOMBAT_HIGHER_SIMPLE_THREADS_PASS golden=true nascent=true deity=true tribulation=true")
	quit(0)
