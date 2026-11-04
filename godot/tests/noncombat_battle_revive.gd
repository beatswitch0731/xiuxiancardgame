extends SceneTree

const Registry = preload("res://scripts/runtime_data_registry.gd")
const Domain = preload("res://scripts/noncombat_domain.gd")
const ContentRepository = preload("res://scripts/noncombat_content_repository.gd")
const TreasureAcquisition = preload("res://scripts/noncombat_treasure_acquisition.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var game = Domain.new(Registry.new(), null, "slot_2")
	if not game.start("sword"):
		return _fail("sword opening unavailable")
	for direction in ["right", "right", "left", "left", "left"]:
		if not game.choose(direction, game.issue_choice_token()):
			return _fail("source teaching battle did not reach pending handoff")
	if game.state.get("phase") != "BATTLE_PENDING":
		return _fail("teaching battle pending state unavailable")
	game.state["maxHealth"] = 1
	game.state["maxDaoHeart"] = 1
	game.state["attributes"]["health"] = 1
	game.state["attributes"]["daoHeart"] = 1
	var artifact_id := "tr:替身符:1"
	game.state["treasureInstances"] = {}
	game.state["treasureInstances"][artifact_id] = {
		"instanceId": artifact_id, "definitionId": "替身符",
		"provenance": {"source": "test_branch"}, "acquiredDecision": 0,
		"lifecycle": "owned"}
	game.state["treasureInventory"] = []
	game.state["treasureCommandReceipts"] = {}
	game.state["treasureCooldowns"] = {}
	game.state["equipment"] = {"weapon": null, "armor": null,
		"accessory": null, "artifact": artifact_id}
	game.state["resources"]["treasures"] = ["替身符"]
	game.state["treasureRuleSourceSha"] = TreasureAcquisition.SOURCE_JS_SHA
	game.state["treasureSourceSha"] = ContentRepository.new().source_sha256(
		"shops:treasures")
	var request: Dictionary = game.battle_request()
	if request.is_empty():
		return _fail("equipped source battle request unavailable")
	var result := {"contractVersion": 2,
		"encounterInstanceId": request.encounterInstanceId,
		"sourceCardId": request.sourceCardId, "encounterId": request.encounterId,
		"sourceContentHash": request.sourceContentHash, "outcome": "defeat",
		"combatReceipt": "combat:" + String(request.encounterInstanceId),
		"postBattleState": {"encounterInstanceId": request.encounterInstanceId,
			"terminal": true, "combatPhase": "DEFEAT"}}
	if not game.submit_battle_result(result):
		return _fail("equipped substitute did not intercept fatal battle injury: "
			+ game.flow_failure_reason())
	if game.state.get("phase") != "BATTLE_RESULT_PENDING" \
			or game.state.get("dead", false) == true \
			or int(game.state.get("attributes", {}).get("health", -1)) != 1 \
			or game.state.get("equipment", {}).get("artifact") != null \
			or not game.state.get("treasureInstances", {}).is_empty() \
			or game.state.get("battleResultHistory", []).size() != 1:
		return _fail("source battle revive ownership, injury or result diverged: "
			+ JSON.stringify({"phase": game.state.get("phase"),
				"health": game.state.get("attributes", {}).get("health")}))
	var fatal = Domain.new(Registry.new(), null, "slot_2")
	if not fatal.start("sword"):
		return _fail("fatal battle source opening unavailable")
	for direction in ["right", "right", "left", "left", "left"]:
		if not fatal.choose(direction, fatal.issue_choice_token()):
			return _fail("fatal battle source route blocked")
	fatal.state["maxHealth"] = 1
	fatal.state["maxDaoHeart"] = 1
	fatal.state["attributes"]["health"] = 1
	fatal.state["attributes"]["daoHeart"] = 1
	var fatal_request: Dictionary = fatal.battle_request()
	if fatal_request.is_empty():
		return _fail("fatal battle request unavailable")
	var fatal_result: Dictionary = result.duplicate(true)
	for key in ["encounterInstanceId", "sourceCardId", "encounterId",
			"sourceContentHash"]:
		fatal_result[key] = fatal_request[key]
	fatal_result["combatReceipt"] = "combat:" + String(
		fatal_request.encounterInstanceId)
	fatal_result["postBattleState"]["encounterInstanceId"] = \
		fatal_request.encounterInstanceId
	if not fatal.submit_battle_result(fatal_result) \
			or fatal.state.get("phase") != "DEATH_PENDING" \
			or fatal.get_current_card().get("id") != "death_blood_loss" \
			or int(fatal.state.get("attributes", {}).get("health", 1)) != 0 \
			or fatal.state.get("battleResultHistory", []).size() != 1:
		return _fail("unprotected teaching battle death was not authored")
	var fleeing = Domain.new(Registry.new(), null, "slot_2")
	if not fleeing.start("sword"):
		return _fail("lifespan battle source opening unavailable")
	for direction in ["right", "right", "left", "left", "left"]:
		if not fleeing.choose(direction, fleeing.issue_choice_token()):
			return _fail("lifespan battle source route blocked")
	fleeing.state["resources"]["lifespan"] = 1
	var flee_request: Dictionary = fleeing.battle_request()
	if flee_request.is_empty():
		return _fail("lifespan battle request unavailable")
	var flee_result: Dictionary = result.duplicate(true)
	for key in ["encounterInstanceId", "sourceCardId", "encounterId",
			"sourceContentHash"]:
		flee_result[key] = flee_request[key]
	flee_result["combatReceipt"] = "combat:" + String(
		flee_request.encounterInstanceId)
	flee_result["outcome"] = "flee"
	flee_result["postBattleState"] = {
		"encounterInstanceId": flee_request.encounterInstanceId,
		"terminal": true, "combatPhase": "FLEE"}
	if not fleeing.submit_battle_result(flee_result) \
			or fleeing.state.get("phase") != "DEATH_PENDING" \
			or fleeing.get_current_card().get("id") != "death_lifespan" \
			or int(fleeing.state.get("resources", {}).get("lifespan", -1)) != 0:
		return _fail("teaching battle flee lifespan death was not authored")
	print("NONCOMBAT_BATTLE_REVIVE_PASS defeat=true substitute=true death=true flee_lifespan=true")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
