extends "res://tests/noncombat_foundation_normal_pool.gd"


func _run() -> void:
	for scenario in [
		{"outcome": "defeat", "resource": "daoHeart", "cause": "death_dao_collapse"},
		{"outcome": "flee", "resource": "lifespan", "cause": "death_lifespan"},
		{"outcome": "defeat", "resource": "health", "cause": "death_blood_loss"}]:
		var game = Domain.new(Registry.new(), null, "slot_3")
		if not game.start("spell"):
			return _fail("fatal mission fixture could not start")
		game.state.realm = "foundation"
		game.state.phase = "NORMAL_PENDING"
		game.state.currentCardId = "f_mission"
		game.state.runClock.decisionIndex = 1
		game.state.turn = 1
		match String(scenario.resource):
			"daoHeart": game.state.attributes.daoHeart = 1
			"lifespan": game.state.resources.lifespan = 1
			"health":
				game.state.maxHealth = 1
				game.state.attributes.health = 1
		if not game.choose("right", game.issue_choice_token()) \
				or not game.choose("left", game.issue_choice_token()) \
				or game.state.phase != "BATTLE_PENDING":
			return _fail("fatal mission battle did not start: " + scenario.resource)
		var request: Dictionary = game.battle_request()
		var result := {"contractVersion": 2,
			"encounterInstanceId": request.encounterInstanceId,
			"sourceCardId": request.sourceCardId,
			"encounterId": request.encounterId,
			"sourceContentHash": request.sourceContentHash,
			"outcome": scenario.outcome,
			"combatReceipt": "combat:" + String(request.encounterInstanceId),
			"postBattleState": {"encounterInstanceId": request.encounterInstanceId,
				"terminal": true, "combatPhase": String(scenario.outcome).to_upper()}}
		if not game.submit_battle_result(result) \
				or game.state.phase != "DEATH_PENDING" \
				or game.get_current_card().get("id") != scenario.cause \
				or game.state.battleResultHistory.size() != 1 \
				or game.submit_battle_result(result):
			return _fail("fatal mission result was not settled exactly once: "
				+ String(scenario.resource) + "/" + game.flow_failure_reason())
		print("FOUNDATION_MISSION_FATAL_PASS " + String(scenario.resource))
	print("NONCOMBAT_FOUNDATION_MISSION_FATAL_PASS outcomes=3 death=true receipt=true")
	quit(0)
