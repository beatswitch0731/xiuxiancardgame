extends "res://tests/noncombat_battle_return.gd"

func _run() -> void:
	for outcome in ["defeat", "flee"]:
		var path := "user://tests/battle_return_scope_%s_%d.json" % [outcome, Time.get_ticks_usec()]
		var game = Domain.new(Registry.new(), Session.new(path, "slot_2"), "slot_2")
		if not game.start("sword"):
			return _fail("sword start failed")
		# This original seven-choice route has enough cultivation for exactly the
		# first two chapters. The risky short tutorial route can unlock a third.
		for step in 7:
			if not game.choose("left", game.issue_choice_token()):
				return _fail("natural seven-choice source route failed")
		if not game.submit_battle_result(_result(game.battle_request(), outcome)) \
				or not game.choose("down", game.issue_choice_token()) \
				or not game.resume_flow() or game.get_current_card().get("id") != "ch_qi_20" \
				or not game.choose("left", game.issue_choice_token()) \
				or game.get_current_card().get("id") != "ch_qi_40" \
				or not game.choose("right", game.issue_choice_token()) \
				or not game.resume_flow() or game.get_current_card().get("id") != "q_whiteFox_quest" \
				or not _reopens(game):
			return _fail("battle-return scope skipped the original white-fox quest: " + str(game.state.get("currentCardId")))
		if not game.choose("right", game.issue_choice_token()) \
				or game.get_current_card().get("id") != "q_whiteFox_2" or not _reopens(game):
			return _fail("returned white-fox choice did not continue or reopen")
	print("NONCOMBAT_BATTLE_RETURN_SCOPE_PASS defeat=true flee=true white_fox=true replay=true")
	quit(0)
