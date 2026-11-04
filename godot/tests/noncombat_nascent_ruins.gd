extends "res://tests/noncombat_foundation_normal_pool.gd"

func _run() -> void:
	var game = Domain.new(Registry.new(), null, "slot_3")
	if not game.start("spell"):
		return _fail("nascent ruins fixture could not start")
	game.state.realm = "nascent"
	game.state.phase = "NORMAL_PENDING"
	game.state.currentCardId = "n_ancient_ruins"
	if game.get_current_card().get("id") != "n_ancient_ruins" \
			or not game.choose("left", game.issue_choice_token()) \
			or game.get_current_card().get("id") != "ar_entrance" \
			or game.state.get("dungeonRun", {}).get("dungeonId") != "ancient_ruins":
		return _fail("ruins entry or first node unavailable")
	if not game.choose("left", game.issue_choice_token()) \
			or game.get_current_card().get("id") != "ar_hall" \
			or not game.choose("right", game.issue_choice_token()) \
			or game.get_current_card().get("id") != "ar_secret":
		return _fail("ruins first two nodes did not advance")
	var secret: Dictionary = game.get_current_card()
	var reward_id := String(secret.get("choices", {}).get("left", {}).get(
		"effects", {}).get("treasure", ""))
	if reward_id.is_empty() or not game.choose("left", game.issue_choice_token()) \
			or not game.state.resources.treasures.has(reward_id) \
			or game.get_current_card().get("id") != "ar_boss":
		return _fail("ruins treasure or final node unavailable: " +
			JSON.stringify({"error": game._normal_choice_policy.last_error,
				"reward": reward_id, "card": game.get_current_card().get("id")}))
	if not game.can_choose_direction("left") \
			or not game.can_choose_direction("right") \
			or not game.choose("right", game.issue_choice_token()) \
			or game.state.get("dungeonRun") != null \
			or game.state.get("dungeonOutcomeReceipts", []).back().get("outcome") != "success":
		return _fail("ruins parley completion or combat boundary invalid")
	var abandon = Domain.new(Registry.new(), null, "slot_3")
	if not abandon.start("spell"):
		return _fail("nascent ruins abandon fixture could not start")
	abandon.state.realm = "nascent"
	abandon.state.phase = "NORMAL_PENDING"
	abandon.state.currentCardId = "n_ancient_ruins"
	if not abandon.choose("left", abandon.issue_choice_token()) \
			or not abandon.abandon_dungeon(abandon.issue_choice_token()) \
			or abandon.state.get("dungeonOutcomeReceipts", []).back().get("outcome") != "abandon" \
			or abandon.abandon_dungeon(abandon.issue_choice_token()):
		return _fail("ruins abandon receipt not one-time")
	print("NONCOMBAT_NASCENT_RUINS_PASS nodes=4 parley=true treasure=true abandon=true")
	quit(0)
