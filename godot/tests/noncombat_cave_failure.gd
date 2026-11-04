extends "res://tests/noncombat_cave_entry.gd"

const TreasureAcquisition = preload("res://scripts/noncombat_treasure_acquisition.gd")
const ContentRepository = preload("res://scripts/noncombat_content_repository.gd")

func _run() -> void:
	var path := "user://tests/cave_failure_base_%d.json" % Time.get_ticks_usec()
	var game = Domain.new(Registry.new(), RunSession.new(path, "slot_3"), "slot_3")
	_set_zero_rolls(game)
	if not _reach_decision27(game):
		return _fail("failure route did not reach the cave draw")
	game._normal_roll_override = CAVE_ROLL
	var oracle: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(
		"res://tests/fixtures/cave_mist_source.json"))
	if not game.resume_flow() or game.get_current_card().get("id") != "q_cave":
		return _fail("failure route did not draw q_cave")
	var fatal_entry = _fork(game.state)
	if fatal_entry == null:
		return _fail("fatal cave entry could not be constructed")
	fatal_entry.state["attributes"]["health"] = oracle["fatalEntryBefore"][
		"attributes"]["health"]
	fatal_entry.state["attributes"]["daoHeart"] = oracle["fatalEntryBefore"][
		"attributes"]["daoHeart"]
	fatal_entry.state["maxHealth"] = oracle["fatalEntryBefore"]["maxHealth"]
	fatal_entry.state["maxDaoHeart"] = oracle["fatalEntryBefore"]["maxDaoHeart"]
	if not fatal_entry.choose("right", fatal_entry.issue_choice_token()) \
			or fatal_entry.state.get("phase") != "DEATH_PENDING" \
			or fatal_entry.get_current_card().get("id") != oracle[
				"fatalEntryAfter"]["currentCardId"] \
			or fatal_entry.state.get("dungeonRun") != null \
			or fatal_entry.state.get("dungeonOutcomeReceipts", []).size() != 1 \
			or fatal_entry.state.get("dungeonOutcomeReceipts", [])[0].get(
				"outcome") != "failure":
		return _fail("fatal q_cave entry did not settle like browser")
	var revived_entry = _fork(game.state)
	if revived_entry == null:
		return _fail("substitute cave entry could not be constructed")
	revived_entry.state["attributes"]["health"] = oracle["fatalEntryBefore"][
		"attributes"]["health"]
	revived_entry.state["attributes"]["daoHeart"] = oracle["fatalEntryBefore"][
		"attributes"]["daoHeart"]
	revived_entry.state["maxHealth"] = oracle["fatalEntryBefore"]["maxHealth"]
	revived_entry.state["maxDaoHeart"] = oracle["fatalEntryBefore"]["maxDaoHeart"]
	var artifact_id := "tr:替身符:1"
	revived_entry.state["treasureInstances"] = {}
	revived_entry.state["treasureInventory"] = []
	revived_entry.state["treasureCommandReceipts"] = {}
	revived_entry.state["treasureCooldowns"] = {}
	revived_entry.state["equipment"] = {"weapon": null, "armor": null,
		"accessory": null, "artifact": null}
	revived_entry.state["treasureInstances"][artifact_id] = {
		"instanceId": artifact_id, "definitionId": "替身符",
		"provenance": {"source": "test_branch"}, "acquiredDecision": 27,
		"lifecycle": "owned"}
	revived_entry.state["equipment"]["artifact"] = artifact_id
	revived_entry.state["resources"]["treasures"] = ["替身符"]
	revived_entry.state["treasureRuleSourceSha"] = TreasureAcquisition.SOURCE_JS_SHA
	revived_entry.state["treasureSourceSha"] = ContentRepository.new().source_sha256(
		"shops:treasures")
	if not revived_entry.choose("right", revived_entry.issue_choice_token()) \
			or revived_entry.state.get("phase") != "FLOW_PENDING" \
			or revived_entry.state.get("dead", false) == true \
			or revived_entry.state.get("dungeonRun") != null \
			or revived_entry.state.get("dungeonOutcomeReceipts", []).size() != 1 \
			or revived_entry.state.get("dungeonOutcomeReceipts", [])[0].get(
				"outcome") != "failure" \
			or revived_entry.state.get("equipment", {}).get("artifact") != null \
			or not revived_entry.state.get("treasureInstances", {}).is_empty():
		return _fail("fatal cave entry did not consume substitute and survive")
	if not game.choose("right", game.issue_choice_token()) or not _reopen(game):
		return _fail("failure route did not enter and restore cave")
	# The two natural opening routes reach the cave with different health. Match
	# the browser fixture's post-entry health to exercise its fatal branch.
	game._store = null
	game.state["attributes"]["health"] = oracle["afterEntry"]["attributes"]["health"]
	game.state["attributes"]["daoHeart"] = oracle["afterEntry"]["attributes"]["daoHeart"]
	game.state["maxHealth"] = oracle["afterEntry"]["maxHealth"]
	game.state["maxDaoHeart"] = oracle["afterEntry"]["maxDaoHeart"]
	if not game.choose("right", game.issue_choice_token()) \
			or game.get_current_card().get("id") != "cave_beast":
		return _fail("source-health spirit right branch did not reach beast")
	var snapshot: Dictionary = game.state.duplicate(true)
	for direction in ["left", "right"]:
		var branch = _fork(snapshot)
		if branch == null:
			return _fail("beast fatal branch could not be constructed")
		if not branch.choose(direction, branch.issue_choice_token()):
			return _fail("beast fatal branch failed: %s/%s" % [direction,
				branch._normal_choice_policy.last_error])
		var terminal: Dictionary = oracle["branches"]["right_" + direction +
			"_left"]["terminal"]
		var receipts: Array = branch.state.get("dungeonOutcomeReceipts", [])
		if receipts.is_empty():
			return _fail("beast branch did not terminate: %s phase=%s health=%s dao=%s" % [
				direction, branch.state.get("phase"), branch.state.get(
					"attributes", {}).get("health"), branch.state.get(
						"attributes", {}).get("daoHeart")])
		var receipt: Dictionary = receipts[0]
		if branch.state.get("phase") != "DEATH_PENDING" \
				or branch.get_current_card().get("id") != "death_blood_loss" \
				or branch.state.get("dungeonRun") != null \
				or receipt.get("outcome") != "failure" \
				or receipt.get("sourceCardId") != "q_cave" \
				or receipt.get("settledDecisionIndex") != branch.state.get(
					"runClock", {}).get("decisionIndex") \
				or branch.state.get("attributes", {}).get("health") != terminal.get(
					"attributes", {}).get("health") \
				or branch.state.get("storyThreadState", {}).get("threads", {}).get(
					"mist_valley", {}).get("status") == "active":
			return _fail("beast fatal outcome differs from browser: " + direction)
		if direction == "right" and not branch.state.get("resources", {}).get(
				"treasures", []).has("beastCore"):
			return _fail("beastCore was lost before death")
	print("NONCOMBAT_CAVE_FAILURE_PASS fatal_entry=true source_health=true branches=2 receipt=true death=true revive=true")
	quit(0)


func _fork(snapshot: Dictionary) -> RefCounted:
	var branch = Domain.new(Registry.new(), null, "slot_3")
	_set_zero_rolls(branch)
	if not branch.start("sword"):
		return null
	branch.state = snapshot.duplicate(true)
	branch._current_card_id = String(snapshot.get("currentCardId", ""))
	branch._normal_roll_override = CAVE_ROLL
	return branch
