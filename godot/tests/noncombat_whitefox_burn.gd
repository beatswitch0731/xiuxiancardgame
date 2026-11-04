extends "res://tests/noncombat_whitefox_battle.gd"

func _run() -> void:
	var file := "user://tests/whitefox_burn_%d.json" % Time.get_ticks_usec()
	var game = Domain.new(Registry.new(), Session.new(file, "slot_2"), "slot_2")
	game._market_flow.roll_override = 0.0
	game._ripple_flow.roll_override = 0.999
	game._hint_flow.roll_override = 0.0
	if not game.start("sword"):
		return _fail("burn opening")
	# Public source route: skip instruction, risk progress, blood sword,
	# avoid teaching, three chapters, rescue fox and collect herb.
	for direction in ["right", "right", "left", "right", "left"]:
		if not game.choose(direction, game.issue_choice_token()):
			return _fail("burn opener choice")
	for chapter in ["ch_qi_20", "ch_qi_40", "ch_qi_60"]:
		if game.state.phase == "FLOW_PENDING" and not game.resume_flow():
			return _fail("burn chapter resume")
		if game.get_current_card().get("id") != chapter \
				or not game.choose("left", game.issue_choice_token()):
			return _fail("burn chapter source route")
	if not game.resume_flow() or not game.choose("right", game.issue_choice_token()) \
			or not game.choose("left", game.issue_choice_token()) \
			or game.get_current_card().get("id") != "q_whiteFox_3" \
			or game.state.turn != 10 or game.state.attributes.health != 1 \
			or game.state.attributes.daoHeart != 4 or game.state.maxDaoHeart != 4 \
			or game.state.maxHealth != 5:
		return _fail("burn natural precondition differs from browser")
	if not game.choose("left", game.issue_choice_token()) \
			or not game.choose("left", game.issue_choice_token()):
		return _fail("burn pending entry")
	var before: Dictionary = game.state.duplicate(true)
	var result := _result(game.battle_request(), "defeat")
	var bytes := FileAccess.get_file_as_bytes(game._store.v2_path)
	game._store.fail_promotion_once = true
	if game.submit_battle_result(result) or not _same(game.state, before) \
			or FileAccess.get_file_as_bytes(game._store.v2_path) != bytes:
		return _fail("burn failed write changed caps or injury")
	# game._resolveCombatOutcome applies injury AND defeatEffects first, then
	# GameStateManager.checkDeath burns caps and clamps the already-reduced dao.
	if not game.submit_battle_result(result) or game.state.attributes.health != 1 \
			or game.state.maxHealth != 4 or game.state.maxDaoHeart != 3 \
			or game.state.attributes.daoHeart != 3:
		return _fail("whitefox burn order deducted daoHeart twice")
	if game.state.turn != 11 or not _same(game.state.questState, before.questState) \
			or game.state.battleResultHistory.back().defeatHealthLoss != 1 \
			or game.submit_battle_result(result) or not _reopens(game):
		return _fail("burn quest/receipt/replay")
	if not game.choose("down", game.issue_choice_token()) or not game.resume_flow() \
			or game.get_current_card().get("id") != "ch_qi_80" or not _reopens(game):
		return _fail("burn source chapter continuation differs: " + str(game.state.currentCardId))
	print("NONCOMBAT_WHITEFOX_BURN_PASS source_order=true natural=true atomic=true replay=true continuation=true")
	quit(0)

func _reopens(game: RefCounted) -> bool:
	var next = Domain.new(Registry.new(), Session.new(game._store.legacy_path, "slot_2"), "slot_2")
	next._market_flow.roll_override = 0.0
	next._ripple_flow.roll_override = 0.999
	next._hint_flow.roll_override = 0.0
	return next.restore() and _same(next.state, game.state)
