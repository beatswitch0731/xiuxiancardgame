extends "res://tests/noncombat_battle_return.gd"

class RouteArt extends "res://scripts/noncombat_content_repository.gd":
	var mode := ""
	var target := "scene_qi_mountain_shadow_path_agc_v1.png"
	func asset_status(path: String) -> Dictionary:
		var art := super.asset_status(path)
		if not mode.is_empty() and path.ends_with(target):
			art.shaVerified = false
			art.textureLoadable = false
			if mode == "missing":
				art.fileExists = false
		return art

func _settings(game: RefCounted) -> void:
	game._market_flow.roll_override = 0.3
	game._ripple_flow.roll_override = 0.99999
	game._hint_flow.roll_override = 0.99999

func _reopens(game: RefCounted) -> bool:
	var next = Domain.new(Registry.new(), Session.new(game._store.legacy_path, "slot_2"), "slot_2")
	_settings(next)
	return next.restore() and _same(game.state, next.state)

func _run() -> void:
	var file := "user://tests/victory_continuation_%d.json" % Time.get_ticks_usec()
	var store = Session.new(file, "slot_2")
	var game = Domain.new(Registry.new(), store, "slot_2")
	_settings(game)
	if not game.start("sword"):
		return _fail("start")
	for step in 7:
		if not game.choose("left", game.issue_choice_token()):
			return _fail("source long tutorial")
	if int(game.state.turn) != 5 or int(game.state.marketState.nextBazaarDecisionIndex) != 7:
		return _fail("source cadence prerequisite")
	if not game.submit_battle_result(_result(game.battle_request(), "victory")) \
			or game.state.has("pendingMarketCard") or not game.choose("down", game.issue_choice_token()):
		return _fail("victory long route")
	if game.state.phase != "FLOW_PENDING" or game.state.get("firstSessionContinuation") != "q_mountain_shadow_approach" \
			or game.state.get("pendingMarketCard", {}).get("id") != "bazaar_encounter" or not _reopens(game):
		return _fail("new market did not suspend and preserve authored continuation")
	if not game.resume_flow() or game.get_current_card().get("id") != "ch_qi_20" \
			or not _reopens(game) or not game.choose("left", game.issue_choice_token()):
		return _fail("inserted chapter/reload")
	if game.state.currentCardId != "q_mountain_shadow_approach" \
			or game.state.has("firstSessionContinuation") \
			or not _same(game.state.chapterProgress.triggeredMilestones.qi, [15]) \
			or not game.state.has("pendingMarketCard") or not _reopens(game):
		return _fail("second chapter swallowed continuation or pending market lost")
	for target in ["scene_qi_mountain_shadow_path_agc_v1.png", "scene_fd_f_market.png"]:
		if target == "scene_fd_f_market.png" and not game.choose("right", game.issue_choice_token()):
			return _fail("serial first market")
		var bytes := FileAccess.get_file_as_bytes(store.v2_path)
		for mode in ["missing", "changed"]:
			var broken = RouteArt.new()
			broken.mode = mode
			broken.target = target
			var next_store = Session.new(file, "slot_2")
			var next = Domain.new(Registry.new(), next_store, "slot_2", broken)
			_settings(next)
			if next.restore() or not next.state.is_empty() \
					or next_store.last_error != ("SOURCE_UNAVAILABLE" if mode == "missing" else "SOURCE_MISMATCH") \
					or FileAccess.get_file_as_bytes(store.v2_path) != bytes:
				return _fail("route source failure unclassified: " + next_store.last_error)
		if not _reopens(game):
			return _fail("restored artwork did not recover save")
	print("NONCOMBAT_VICTORY_CONTINUATION_PASS market_interrupt=true one_decision=true serial=true missing_art=true replay=true")
	quit(0)
