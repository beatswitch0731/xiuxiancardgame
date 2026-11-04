extends SceneTree

const Registry = preload("res://scripts/runtime_data_registry.gd")
const Domain = preload("res://scripts/noncombat_domain.gd")
const RunSession = preload("res://scripts/noncombat_run_session.gd")

class MissingMarketSource extends "res://scripts/noncombat_content_repository.gd":
	func module_path(module_id: String) -> String:
		return "data/markets/missing_vendor_profiles.json" if module_id == \
			"markets:vendor_profiles" else super.module_path(module_id)
	func read_module(module_id: String) -> Variant:
		return null if module_id == "markets:vendor_profiles" else super.read_module(module_id)
	func source_sha256(module_id: String) -> String:
		return "" if module_id == "markets:vendor_profiles" else super.source_sha256(module_id)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var path := "user://tests/market_arrival_%d.json" % Time.get_ticks_usec()
	var store = RunSession.new(path, "slot_3")
	var game = Domain.new(Registry.new(), store, "slot_3")
	var flow: Variant = game.get("_market_flow")
	if flow == null:
		return _fail("market scheduler missing from the noncombat domain")
	_stabilize_ambient(game)
	if not game.start("sword"):
		return _fail("sword opening did not start")
	var market: Dictionary = game.state.get("marketState", {})
	if market.get("nextBazaarDecisionIndex") != 6 or market.get("nextGhostDecisionIndex") != 14:
		return _fail("fresh market cadence differs from source fixed-zero trace")
	var ghost_checkpoint := {}
	if not _reach_sect_result(game, ghost_checkpoint):
		return _fail("real source route to sect choice could not be played")
	var ghost_snapshot: Dictionary = ghost_checkpoint.get("state", {})
	if ghost_snapshot.is_empty() or ghost_snapshot.get("pendingGhostPlan", {}).get(
			"card") != ghost_snapshot.get("pendingMarketCard") \
			or ghost_snapshot.get("pendingGhostPlan", {}).get("stock", []).is_empty():
		return _fail("real ghost arrival did not freeze a stock/card checkpoint")
	var ghost_path := "user://tests/market_ghost_due_%d.json" % Time.get_ticks_usec()
	var ghost_store = RunSession.new(ghost_path, "slot_3")
	if ghost_store.commit_snapshot(ghost_snapshot, -1).get("ok") != true:
		return _fail("ghost arrival checkpoint could not be persisted")
	var ghost_loaded = Domain.new(Registry.new(), RunSession.new(ghost_path,
		"slot_3"), "slot_3")
	_stabilize_ambient(ghost_loaded)
	if not ghost_loaded.restore() or not _same(ghost_loaded.state, ghost_snapshot):
		return _fail("frozen ghost arrival did not strictly replay: " +
			ghost_loaded._store.last_error)
	var pre_stock_path := "user://tests/market_pre_stock_%d.json" % Time.get_ticks_usec()
	var pre_stock = Domain.new(Registry.new(), RunSession.new(pre_stock_path,
		"slot_3"), "slot_3")
	_stabilize_ambient(pre_stock)
	pre_stock._market_flow.ghost_plan_activation_index = 100
	var pre_stock_due := {}
	if not pre_stock.start("sword") or not _reach_sect_result(pre_stock,
			pre_stock_due) or pre_stock.state.has("ghostPlanVersion") \
			or pre_stock.state.get("pendingMarketCard", {}).get("id") != \
				"bazaar_encounter" or pre_stock_due.get("state", {}).get(
				"pendingMarketCard", {}).get("unportedStock") != true:
		return _fail("pre-stock ghost arrival then bazaar overwrite fixture failed")
	var old_due_path := "user://tests/market_old_ghost_due_%d.json" % Time.get_ticks_usec()
	var old_due_store = RunSession.new(old_due_path, "slot_3")
	if old_due_store.commit_snapshot(pre_stock_due["state"], -1).get("ok") != true:
		return _fail("old ghost placeholder checkpoint could not be saved")
	var old_due_loaded = Domain.new(Registry.new(), RunSession.new(old_due_path,
		"slot_3"), "slot_3")
	_stabilize_ambient(old_due_loaded)
	if not old_due_loaded.restore() or not _same(old_due_loaded.state,
			pre_stock_due["state"]):
		return _fail("old ghost placeholder did not replay at its original decision")
	var pre_stock_loaded = Domain.new(Registry.new(), RunSession.new(pre_stock_path,
		"slot_3"), "slot_3")
	_stabilize_ambient(pre_stock_loaded)
	if not pre_stock_loaded.restore() or not _same(pre_stock_loaded.state,
			pre_stock.state):
		return _fail("old ghost roll history did not survive later bazaar overwrite")
	if not pre_stock_loaded.resume_flow() or not pre_stock_loaded.choose("right",
			pre_stock_loaded.issue_choice_token()) or pre_stock_loaded.state.get(
			"ghostPlanVersion") != 1 or pre_stock_loaded.state.get(
			"ghostPlanActivationIndex") != 22:
		return _fail("old ghost roll history did not activate on the next decision")
	var upgraded_stock = Domain.new(Registry.new(), RunSession.new(pre_stock_path,
		"slot_3"), "slot_3")
	_stabilize_ambient(upgraded_stock)
	if not upgraded_stock.restore() or not _same(upgraded_stock.state,
			pre_stock_loaded.state):
		return _fail("activated ghost stock rule did not strictly replay")
	if game.state.get("runClock", {}).get("decisionIndex") != 21:
		return _fail("route decision clock differs")
	market = game.state.get("marketState", {})
	if market.get("lastBazaarDecisionIndex") != 18 \
			or market.get("nextBazaarDecisionIndex") != 24 \
			or market.get("lastGhostDecisionIndex") != 14 \
			or market.get("nextGhostDecisionIndex") != 30 \
			or game.state.get("pendingMarketCard", {}).get("id") != "bazaar_encounter":
		return _fail("market overwrite timeline differs: %s" % str(market))
	var before: Dictionary = game.state.duplicate(true)
	var before_bytes := FileAccess.get_file_as_string(store.v2_path)
	var missing = MissingMarketSource.new()
	game._content = missing
	game._market_flow._content = missing
	if game.resume_flow() or store.last_error != "SOURCE_UNAVAILABLE" \
			or not _same(game.state, before) \
			or FileAccess.get_file_as_string(store.v2_path) != before_bytes:
		return _fail("missing queued market source not classified unavailable")
	var loaded = Domain.new(Registry.new(), RunSession.new(path, "slot_3"), "slot_3")
	_stabilize_ambient(loaded)
	if not loaded.restore() or not _same(loaded.state, before) \
			or FileAccess.get_file_as_string(store.v2_path) != before_bytes:
		return _fail("queued bazaar failed strict replay")
	if not loaded.resume_flow() or loaded.get_current_card().get("id") != "bazaar_encounter" \
			or loaded.get_current_card().get("description") != \
				"商队在洞府外支起三盏不同的灯：药材、旧货和鉴物各占一席。摊主说得明白——买卖不占人情，但你若肯帮忙或打听，他们会记得。" \
			or not loaded.can_choose_direction("left") or not loaded.can_choose_direction("right"):
		return _fail("bazaar not presented with safe choice admission")
	var presented: Dictionary = loaded.state.duplicate(true)
	var presented_bytes := FileAccess.get_file_as_string(store.v2_path)
	var token: int = loaded.issue_choice_token()
	loaded._store.fail_promotion_once = true
	if loaded.choose("right", token) or not _same(loaded.state, presented) \
			or FileAccess.get_file_as_string(store.v2_path) != presented_bytes:
		return _fail("failed bazaar right-choice write changed state")
	if not loaded.choose("right", token) \
			or loaded.choose("right", token):
		return _fail("bazaar entry admitted or skip did not settle once")
	if loaded.state.get("choiceHistory", []).back().get("cardId") != "bazaar_encounter" \
			or loaded.state.get("runClock", {}).get("decisionIndex") != 22 \
			or loaded.state.get("marketState", {}).get("totalVisits") != 0:
		return _fail("bazaar skip result differs from browser")
	var settled: Dictionary = loaded.state.duplicate(true)
	var replay = Domain.new(Registry.new(), RunSession.new(path, "slot_3"), "slot_3")
	_stabilize_ambient(replay)
	if not replay.restore() or not _same(replay.state, settled):
		return _fail("settled bazaar did not replay")
	var old_path := "user://tests/market_legacy_%d.json" % Time.get_ticks_usec()
	var old_store = RunSession.new(old_path, "slot_3")
	var old = Domain.new(Registry.new(), old_store, "slot_3")
	old._legacy_market_replay = true
	if not old.start("sword") or not old.choose("left", old.issue_choice_token()) \
			or old.state.has("marketStateVersion"):
		return _fail("legacy pre-market save fixture failed")
	var old_bytes := FileAccess.get_file_as_string(old_store.v2_path)
	var upgraded = Domain.new(Registry.new(), RunSession.new(old_path, "slot_3"), "slot_3")
	upgraded._market_flow.roll_override = 0.0
	if not upgraded.restore() or FileAccess.get_file_as_string(old_store.v2_path) != old_bytes \
			or not upgraded.choose("left", upgraded.issue_choice_token()) \
			or upgraded.state.get("marketActivationIndex") != 2 \
			or upgraded.state.get("marketState", {}).get("nextBazaarDecisionIndex") != 8:
		return _fail("old save market activation or immutable restore failed")
	var upgraded_bytes := FileAccess.get_file_as_string(old_store.v2_path)
	var upgraded_replay = Domain.new(Registry.new(), RunSession.new(old_path, "slot_3"), "slot_3")
	upgraded_replay._market_flow.roll_override = 0.0
	if not upgraded_replay.restore() or not _same(upgraded_replay.state, upgraded.state) \
			or FileAccess.get_file_as_string(old_store.v2_path) != upgraded_bytes:
		return _fail("upgraded market save did not strictly replay")
	var pending_path := "user://tests/market_legacy_flow_%d.json" % Time.get_ticks_usec()
	var pending_store = RunSession.new(pending_path, "slot_3")
	var old_pending = Domain.new(Registry.new(), pending_store, "slot_3")
	old_pending._legacy_market_replay = true
	if not old_pending.start("sword"):
		return _fail("legacy pending fixture did not start")
	for i in 5:
		if not old_pending.choose("left", old_pending.issue_choice_token()):
			return _fail("legacy pending tutorial did not advance")
	if not old_pending.choose("right", old_pending.issue_choice_token()) \
			or not old_pending.choose("left", old_pending.issue_choice_token()) \
			or old_pending.state.get("phase") != "FLOW_PENDING":
		return _fail("legacy pending source phase not reached")
	var pending_loaded = Domain.new(Registry.new(), RunSession.new(pending_path, "slot_3"), "slot_3")
	if not pending_loaded.restore() or not pending_loaded.resume_flow() \
			or pending_loaded.state.has("marketStateVersion"):
		return _fail("old FLOW_PENDING was upgraded before a player decision")
	print("NONCOMBAT_MARKET_ARRIVAL_PASS cadence=true overwrite=true replay=true rollback=true legacy=true")
	quit(0)

func _reach_sect_result(game: RefCounted, ghost_checkpoint: Dictionary) -> bool:
	for i in 5:
		if not game.choose("left", game.issue_choice_token()): return false
	var steps := [
		["choose", "right"], ["choose", "left"], ["resume", ""],
		["choose", "left"], ["choose", "right"], ["resume", ""],
		["choose", "right"], ["choose", "left"], ["choose", "down"],
		["resume", ""], ["choose", "left"], ["resume", ""],
		["choose", "left"], ["resume", ""], ["choose", "left"],
		["choose", "left"], ["choose", "left"], ["resume", ""],
		["choose", "left"], ["resume", ""], ["choose", "right"],
		["resume", ""], ["choose", "left"], ["resume", ""],
		["choose", "left"], ["resume", ""], ["choose", "left"]]
	for index in steps.size():
		if index == 15 and game.get_current_card().get("type") != "DESTINY_WHEEL":
			return false
		var step: Array = steps[index]
		if not (game.resume_flow() if step[0] == "resume" else game.choose(
			String(step[1]), game.issue_choice_token())):
			return false
		if ghost_checkpoint.is_empty() and (game.state.has("pendingGhostPlan") \
				or game.state.get("pendingMarketCard", {}).get(
					"unportedStock") == true):
			ghost_checkpoint["state"] = game.state.duplicate(true)
	return game.get_current_card().get("id") != ""

func _same(left: Dictionary, right: Dictionary) -> bool:
	return JSON.parse_string(JSON.stringify(left)) == JSON.parse_string(JSON.stringify(right))

func _stabilize_ambient(game: RefCounted) -> void:
	# The market timeline depends on earlier ripple/hint interruption slots.
	# Pin all four ambient streams so this case has one reproducible trace.
	game._market_flow.roll_override = 0.0
	game._destiny_wheel_flow.roll_override = 0.0
	game._ripple_flow.roll_override = 0.999
	game._hint_flow.roll_override = 0.0

func _fail(message: String) -> void:
	push_error(message)
	quit(1)
