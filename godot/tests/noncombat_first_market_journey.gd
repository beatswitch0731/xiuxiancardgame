extends "res://tests/noncombat_battle_return.gd"

func _run() -> void:
	for visit in ["left", "right"]:
		var file := "user://tests/first_market_journey_%s_%d.json" % [visit, Time.get_ticks_usec()]
		var store = Session.new(file, "slot_2")
		var game = Domain.new(Registry.new(), store, "slot_2")
		if not game.start("sword"):
			return _fail("start")
		for direction in ["right", "right", "left", "left", "left"]:
			if not game.choose(direction, game.issue_choice_token()):
				return _fail("teaching entry")
		if not game.submit_battle_result(_result(game.battle_request(), "victory")) \
				or not game.choose("left", game.issue_choice_token()):
			return _fail("reward")
		if game.state.phase == "FLOW_PENDING" and not game.resume_flow():
			return _fail("interrupt resume")
		if game.state.phase == "MILESTONE_PENDING" and not game.choose("left", game.issue_choice_token()):
			return _fail("interrupt decision")
		if not game.choose("right", game.issue_choice_token()) \
				or game.state.currentCardId != "loc_market_first":
			return _fail("first market arrival")
		var screen: Control = load("res://scenes/noncombat_opening.tscn").instantiate()
		screen.save_path = ""
		root.add_child(screen)
		await process_frame
		screen.opening = game
		screen._render()
		for d in ["left", "right"]:
			var button := screen.find_child("Choice_" + d, true, false)
			if button == null or button.disabled or screen.art_rect.texture == null:
				return _fail("desktop market actions/image missing")
		screen.queue_free()
		await process_frame
		var before: Dictionary = game.state.duplicate(true)
		if not game.choose(visit, game.issue_choice_token()) or not _reopens(game):
			return _fail("first market action/reopen: " + visit)
		if visit == "right":
			if game.state.phase != "NARRATIVE_RESULT_PENDING" \
					or game.get_current_card().get("originCardId") != "loc_market_first" \
					or not game.choose("left", game.issue_choice_token()) or not _reopens(game):
				return _fail("market promise acknowledgement/replay")
		else:
			if game.state.phase != "VENDOR_OPEN" or game.state.turn != before.turn \
					or game.state.attributes.fortune != before.attributes.fortune:
				return _fail("vendor action settled before close")
			var opened: Dictionary = game.state.duplicate(true)
			var token: int = game.issue_choice_token()
			store.fail_promotion_once = true
			if game.close_vendor(token) or not _same(game.state, opened):
				return _fail("vendor close rollback")
			if not game.close_vendor(token) or not _reopens(game) \
					or game.state.attributes.fortune != mini(100, int(before.attributes.fortune) + 3) \
					or int(game.state.turn) != int(before.turn) + 1:
				return _fail("vendor source reward/strict reload")
			if game.close_vendor(token) or not game.choose("right", game.issue_choice_token()) \
					or not _reopens(game):
				return _fail("vendor duplicate/dismiss replay")
		if game.state.phase != "FLOW_PENDING" or not game.resume_flow() or not _reopens(game):
			return _fail("market return to original flow")
	print("NONCOMBAT_FIRST_MARKET_JOURNEY_PASS vendor=true narrative=true deferred_reward=true replay=true atomic=true desktop=true")
	quit(0)
