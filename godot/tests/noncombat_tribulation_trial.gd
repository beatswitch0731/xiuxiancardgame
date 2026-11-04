extends "res://tests/noncombat_foundation_normal_pool.gd"


func _run() -> void:
	var game = Domain.new(Registry.new(), null, "slot_3")
	if not game.start("spell"):
		return _fail("tribulation trial fixture could not start")
	game.state.realm = "tribulation"
	game.state.phase = "NORMAL_PENDING"
	game.state.currentCardId = "t_immortal_test"
	if not game.choose("left", game.issue_choice_token()) \
			or game.get_current_card().get("id") != "it_entrance":
		return _fail("tribulation trial entry failed")
	if not game.choose("left", game.issue_choice_token()) \
			or game.get_current_card().get("id") != "it_combat" \
			or not game.choose("right", game.issue_choice_token()) \
			or game.get_current_card().get("id") != "it_reward" \
			or not game.choose("left", game.issue_choice_token()) \
			or game.get_current_card().get("id") != "it_blessing" \
			or not game.choose("right", game.issue_choice_token()) \
			or game.state.get("dungeonOutcomeReceipts", []).back().get("outcome") != "success":
		return _fail("tribulation trial noncombat path failed")
	print("NONCOMBAT_TRIBULATION_TRIAL_PASS nodes=4 parley=true")
	quit(0)
