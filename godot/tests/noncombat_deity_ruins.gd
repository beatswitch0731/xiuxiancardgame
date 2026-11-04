extends "res://tests/noncombat_foundation_normal_pool.gd"


func _run() -> void:
	var game = Domain.new(Registry.new(), null, "slot_3")
	if not game.start("spell"):
		return _fail("deity ruins fixture could not start")
	game.state.realm = "deity"
	game.state.phase = "NORMAL_PENDING"
	game.state.currentCardId = "d_immortal_trace"
	if not game.choose("left", game.issue_choice_token()) \
			or game.state.get("dungeonRun", {}).get("dungeonId") != "immortal_ruins" \
			or game.get_current_card().get("id") != "ir_gate":
		return _fail("deity ruins entry unavailable")
	for row in [{"card": "ir_gate", "direction": "left", "next": "ir_test"},
			{"card": "ir_test", "direction": "right", "next": "ir_treasure"},
			{"card": "ir_treasure", "direction": "left", "next": "ir_truth"}]:
		if game.get_current_card().get("id") != row.card \
				or not game.choose(row.direction, game.issue_choice_token()) \
				or game.get_current_card().get("id") != row.next:
			return _fail("deity ruins node did not advance: " + String(row.card))
	var pill_id := String(game._content.read_module("cards:deity").dungeonCards[
		"ir_treasure"].choices.left.effects.pill)
	if int(game.state.resources.pills.get(pill_id, 0)) != 1:
		return _fail("deity ruins pill reward missing")
	if not game.choose("right", game.issue_choice_token()) \
			or game.state.get("dungeonRun") != null \
			or game.state.get("dungeonOutcomeReceipts", []).back().get("outcome") != "success":
		return _fail("deity ruins success receipt missing")
	var abandon = Domain.new(Registry.new(), null, "slot_3")
	if not abandon.start("spell"):
		return _fail("deity ruins abandon fixture could not start")
	abandon.state.realm = "deity"
	abandon.state.phase = "NORMAL_PENDING"
	abandon.state.currentCardId = "d_immortal_trace"
	if not abandon.choose("left", abandon.issue_choice_token()) \
			or not abandon.abandon_dungeon(abandon.issue_choice_token()) \
			or abandon.state.get("dungeonOutcomeReceipts", []).back().get("outcome") != "abandon":
		return _fail("deity ruins abandon receipt missing")
	var fatal = Domain.new(Registry.new(), null, "slot_3")
	if not fatal.start("spell"):
		return _fail("deity ruins fatal fixture could not start")
	fatal.state.realm = "deity"
	fatal.state.phase = "NORMAL_PENDING"
	fatal.state.currentCardId = "d_immortal_trace"
	if not fatal.choose("left", fatal.issue_choice_token()) \
			or not fatal.choose("left", fatal.issue_choice_token()) \
			or not fatal.choose("right", fatal.issue_choice_token()) \
			or not fatal.choose("right", fatal.issue_choice_token()):
		return _fail("deity ruins fatal route did not reach last node")
	fatal.state.attributes.daoHeart = 1
	if not fatal.choose("left", fatal.issue_choice_token()) \
			or fatal.state.get("phase") != "DEATH_PENDING" \
			or fatal.state.get("dungeonOutcomeReceipts", []).back().get("outcome") != "failure":
		return _fail("deity ruins fatal choice did not record failure and death")
	print("NONCOMBAT_DEITY_RUINS_PASS nodes=4 pill=true abandon=true death=true")
	quit(0)
