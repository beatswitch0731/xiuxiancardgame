extends "res://tests/noncombat_mist_valley_outcomes.gd"

func _run() -> void:
	var path := "user://tests/cave_rewards_%d.json" % Time.get_ticks_usec()
	var game = Domain.new(Registry.new(), RunSession.new(path, "slot_3"), "slot_3")
	_set_zero_rolls(game)
	if not _reach_decision27(game):
		return _fail("cave reward route did not reach ordinary draw")
	game._normal_roll_override = CAVE_ROLL
	if not game.resume_flow() or game.get_current_card().get("id") != "q_cave":
		return _fail("cave reward route did not draw q_cave")
	var pending: Dictionary = game.state.duplicate(true)
	# The natural Godot route has capped daoHeart here. Preview the authored
	# left option with one point available, leaving the real saved route intact.
	pending["attributes"]["daoHeart"] = int(pending.get("maxDaoHeart", 1)) - 1
	var bypass: Dictionary = game._normal_choice_policy.settle(pending,
		"q_cave", "left")
	if bypass.is_empty() or bypass.get("dungeonRun") != null \
			or bypass.get("dungeonOutcomeReceipts", []).size() != 0 \
			or bypass.get("attributes", {}).get("daoHeart") != pending.get(
				"maxDaoHeart"):
		return _fail("q_cave left numeric bypass policy failed")
	if not game.choose("right", game.issue_choice_token()) \
			or not game.choose("left", game.issue_choice_token()):
		return _fail("cave reward route did not finish spirit left")
	var spirit_state: Dictionary = game.state.duplicate(true)
	var oracle: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(
		"res://tests/fixtures/cave_mist_source.json"))
	for beast in ["left", "right"]:
		for reward in ["left", "right"]:
			var branch = _fork(spirit_state, beast + "_" + reward)
			if branch == null or not branch.choose(beast,
					branch.issue_choice_token()):
				return _fail("cave beast reward branch failed: " + beast)
			if branch.state.get("phase") == "DESTINY_WHEEL_PENDING" and not branch.choose(
					"left", branch.issue_choice_token()):
				return _fail("cave reward wheel could not return to dungeon")
			if branch.get_current_card().get("id") != "cave_reward" \
					or not branch.choose(reward, branch.issue_choice_token()):
				return _fail("cave reward choice failed: " + beast + "/" + reward)
			var source: Dictionary = oracle["branches"]["left_" + beast +
				"_" + reward]
			var receipts: Array = branch.state.get("dungeonOutcomeReceipts", [])
			if receipts.size() != 1 or receipts[0].get("outcome") != source[
					"completionReceipt"].get("outcome") \
					or branch.state.get("dungeonRun") != null \
					or branch.state.get("storyThreadState", {}).get("threads", {}).get(
						"mist_valley", {}).get("status") != "active":
				return _fail("cave success receipt or mist gate failed: " + beast + "/" + reward)
			var has_core: bool = branch.state.get("resources", {}).get(
				"treasures", []).has("beastCore")
			if has_core != (beast == "right"):
				return _fail("beastCore reward owner mismatch: " + beast)
			if beast == "right":
				var owned: bool = false
				for instance in branch.state.get("treasureInstances", {}).values():
					if instance.get("definitionId") == "beastCore" and instance.get(
							"provenance", {}).get("sourceId") == "cave_beast":
						owned = true
				if not owned:
					return _fail("beastCore source provenance missing")
			if not _reopen(branch):
				return _fail("cave reward branch failed strict replay: " + beast + "/" + reward)
	print("NONCOMBAT_CAVE_REWARDS_PASS bypass_policy=true success_branches=4 treasure=true replay=true")
	quit(0)
