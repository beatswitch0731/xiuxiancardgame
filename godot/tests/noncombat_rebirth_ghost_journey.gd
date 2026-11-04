extends SceneTree

const Registry = preload("res://scripts/runtime_data_registry.gd")
const Domain = preload("res://scripts/noncombat_domain.gd")
const RunSession = preload("res://scripts/noncombat_run_session.gd")
const FIXTURE := "res://tests/fixtures/pill_decision54_death_probe_v2.json"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var path := "user://tests/rebirth_ghost_%d_%d.json" % [
		OS.get_process_id(), Time.get_ticks_usec()]
	var store = RunSession.new(path, "slot_3")
	var file := FileAccess.open(store.v2_path, FileAccess.WRITE)
	if file == null:
		return _fail("cannot stage previous-life checkpoint")
	file.store_string(FileAccess.get_file_as_string(FIXTURE))
	file.close()
	var game = Domain.new(Registry.new(), store, "slot_3")
	_stabilize(game)
	if not game.restore() or not game.resume_flow() \
			or game.get_current_card().get("id") != "q_love" \
			or not game.choose("right", game.issue_choice_token()) \
			or not game.choose("left", game.issue_choice_token()) \
			or not game.select_rebirth_path("spell") \
			or not game.choose("down", game.issue_choice_token()) \
			or not game.cancel_camp_target(game.issue_choice_token()):
		return _fail("authored death and rebirth did not reach a second-life flow")
	var thread_cold_count := 0
	for step in 90:
		if step == 15 and (game.state.get("storyThreadState", {}).get("lifeCount") != 1 \
				or game.state.get("storyThreadState", {}).get("threads", {}).size() != 12):
			return _fail("second-life source threads did not enter the durable life ledger")
		if step == 15 and not _verify_old_hint_snapshot(game):
			return
		if step == 16 and not _verify_old_trade_snapshot(game):
			return
		if game.state.get("phase") == "FLOW_PENDING" and not game.resume_flow():
			return _fail("flow stopped at %d: %s" % [step, JSON.stringify({
				"normal": game._normal_flow_error,
				"market": game._market_flow.last_error,
				"mentor": game._mentor_flow.last_error,
				"karma": game._karma_flow.last_error,
				"quest": game._quest_flow.last_error,
				"hint": game._hint_flow.last_error,
				"ripple": game._ripple_flow.last_error,
				"wheel": game._destiny_wheel_flow.last_error,
				"ghostDebt": game._ghost_debt_flow.last_error,
				"trade": game._trade_route_flow.last_error,
				"legacy": game._legacy_fragment_flow.last_error,
				"store": game._store.last_error,
				"pendingMarket": game.state.get("pendingMarketCard", {})})])
		var card: Dictionary = game.get_current_card()
		var phase := String(game.state.get("phase"))
		if phase == "THREAD_PENDING" and card.get("_threadId") == "mist_valley":
			var thread_cold = Domain.new(Registry.new(),
				RunSession.new(path, "slot_3"), "slot_3")
			_stabilize(thread_cold)
			if not thread_cold.restore() or not _same(thread_cold.state, game.state) \
					or thread_cold.get_current_card().get("id") != card.get("id"):
				return _fail("second-life mist thread card failed strict cold replay")
			game = thread_cold
			thread_cold_count += 1
		print("REBIRTH_GHOST_PROGRESS step=%d phase=%s card=%s index=%d" % [
			step, phase, card.get("id"), int(game.state.get("runClock", {}).get("decisionIndex", -1))])
		if phase == "COMBAT_HANDOFF" and game.state.get("pendingCadenceCard") is Dictionary:
			var due = Domain.new(Registry.new(), RunSession.new(path, "slot_3"), "slot_3")
			_stabilize(due)
			var before_due: Dictionary = game.state.duplicate(true)
			var due_restored: bool = due.restore()
			var due_equal: bool = due_restored and _same(due.state, before_due)
			var due_avoided: bool = due_equal and due.choose("right", due.issue_choice_token())
			if card.get("id") != before_due["pendingCadenceCard"].get("id") \
					or not due_restored or not due_equal or not due_avoided \
					or due.state.get("phase") != "NARRATIVE_RESULT_PENDING" \
					or due.get_current_card().get("originCardId") != card.get("id") \
					or int(due.state.get("runClock", {}).get("decisionIndex", -1)) \
						!= int(before_due.get("runClock", {}).get("decisionIndex", -2)) + 1:
				return _fail("second-life due catalog did not strictly reopen and avoid: "
					+ JSON.stringify({"restored": due_restored, "equal": due_equal,
						"avoided": due_avoided, "store": due._store.last_error,
						"phase": due.state.get("phase"),
						"index": due.state.get("runClock", {}).get("decisionIndex")}))
			if not due.choose("left", due.issue_choice_token()) \
					or due.state.get("phase") != "FLOW_PENDING" \
					or int(due.state.get("runClock", {}).get("decisionIndex", -1)) \
						!= int(before_due.get("runClock", {}).get("decisionIndex", -2)) + 2:
				return _fail("second-life due narrative did not acknowledge")
			game = due
			continue
		if phase == "HINT_PENDING":
			if not String(card.get("id", "")).begins_with(
					"heavens_hint:slot_3:life:1:") \
					or game.state.get("heavensHintState", {}).get("lifeCount") != 1:
				return _fail("second-life hint card or current-life identity diverged")
			var hint_reopen = Domain.new(Registry.new(),
				RunSession.new(path, "slot_3"), "slot_3")
			_stabilize(hint_reopen)
			var hint_restored: bool = hint_reopen.restore()
			if not hint_restored or not _same(hint_reopen.state, game.state):
				return _fail("second-life hint pending card failed strict restart: " \
					+ JSON.stringify({"restored": hint_restored,
						"store": hint_reopen._store.last_error,
						"phase": hint_reopen.state.get("phase")}))
			game = hint_reopen
		if phase == "MARKET_PENDING" and card.get("id") == "market_encounter" \
				and game.can_choose_direction("left"):
			var pending = Domain.new(Registry.new(),
				RunSession.new(path, "slot_3"), "slot_3")
			_stabilize(pending)
			if not pending.restore() or not _same(pending.state, game.state) \
					or not pending.can_choose_direction("left"):
				return _fail("second-life ghost card or entry failed strict restart")
			var before: Dictionary = pending.state.duplicate(true)
			var bytes := FileAccess.get_file_as_string(store.v2_path)
			var token := pending.issue_choice_token()
			pending._store.fail_promotion_once = true
			if pending.choose("left", token) or not _same(pending.state, before) \
					or FileAccess.get_file_as_string(store.v2_path) != bytes \
					or not pending.choose("left", token):
				return _fail("second-life ghost entry rollback or open failed")
			var open = Domain.new(Registry.new(), RunSession.new(path, "slot_3"), "slot_3")
			_stabilize(open)
			if not open.restore() or not _same(open.state, pending.state) \
					or open.state.get("phase") != "VENDOR_OPEN" \
					or open.state.get("marketState", {}).get(
						"activeSession", {}).get("vendorId") != "ghost_market":
				return _fail("second-life ghost session failed strict restart")
			if not _verify_oath_branch(open):
				return
			if not open.close_vendor(open.issue_choice_token()):
				return _fail("second-life ghost exit failed")
			var result = Domain.new(Registry.new(), RunSession.new(path, "slot_3"), "slot_3")
			_stabilize(result)
			if not result.restore() or not _same(result.state, open.state) \
					or result.state.get("phase") != "VENDOR_RESULT_PENDING" \
					or not result.choose("right", result.issue_choice_token()):
				return _fail("second-life ghost result failed strict restart or dismissal")
			var done = Domain.new(Registry.new(), RunSession.new(path, "slot_3"), "slot_3")
			_stabilize(done)
			if not done.restore() or not _same(done.state, result.state):
				return _fail("second-life ghost dismissal failed strict restart")
			if thread_cold_count != 2:
				return _fail("second-life mist thread did not reach both authored nodes")
			print("NONCOMBAT_REBIRTH_GHOST_JOURNEY_PASS hint=true ghost=true oath=true debt=true old_hint=true old_trade=true replay=true rollback=true thread_cold=2")
			quit(0)
			return
		var direction := "right" if phase == "MARKET_PENDING" else "left"
		if card.get("id") == "q_spellTome" and int(game.state.get(
				"attributes", {}).get("daoHeart", 0)) <= 2:
			direction = "right"
		if card.get("id") == "q_shop":
			for shop_direction in ["down", "left", "right"]:
				if game.can_choose_direction(shop_direction):
					direction = shop_direction
					break
		elif not game.can_choose_direction(direction):
			direction = "right"
		if not game.choose(direction, game.issue_choice_token()):
			var preview: Dictionary = game._normal_choice_policy.settle(
				game.state, String(card.get("id", "")), direction) if phase \
				== "NORMAL_PENDING" else {}
			return _fail("source step blocked at %d: %s %s %s %s preview=%s stone=%d" % [step,
				phase, String(card.get("id", "")), direction,
				game._normal_choice_policy.last_error, str(not preview.is_empty()),
				int(game.state.get("resources", {}).get("spiritStone", 0))])
	return _fail("ghost card did not naturally arrive within 90 source cards")


func _stabilize(game: RefCounted) -> void:
	game._normal_roll_override = 0.55
	game._market_flow.roll_override = 0.0
	game._destiny_wheel_flow.roll_override = 0.0
	game._ripple_flow.roll_override = 0.999
	game._hint_flow.roll_override = 0.0


func _same(left: Dictionary, right: Dictionary) -> bool:
	return JSON.parse_string(JSON.stringify(left)) == JSON.parse_string(JSON.stringify(right))


func _verify_oath_branch(open: RefCounted) -> bool:
	var branch_path := "user://tests/rebirth_ghost_oath_%d_%d.json" % [
		OS.get_process_id(), Time.get_ticks_usec()]
	var branch_store = RunSession.new(branch_path, "slot_3")
	var file := FileAccess.open(branch_store.v2_path, FileAccess.WRITE)
	if file == null:
		_fail("second-life ghost oath branch could not stage its source save")
		return false
	file.store_string(FileAccess.get_file_as_string(open._store.v2_path))
	file.close()
	var oath = Domain.new(Registry.new(), branch_store, "slot_3")
	_stabilize(oath)
	if not oath.restore() or not _same(oath.state, open.state):
		_fail("second-life oath branch could not strictly restore open ghost stall")
		return false
	var before: Dictionary = oath.state.duplicate(true)
	var bytes := FileAccess.get_file_as_string(branch_store.v2_path)
	var token := oath.issue_choice_token()
	oath._store.fail_promotion_once = true
	if oath.purchase_vendor_offer("ghost_oath_rusted_sword", token) \
			or not _same(oath.state, before) \
			or FileAccess.get_file_as_string(branch_store.v2_path) != bytes \
			or not oath.purchase_vendor_offer("ghost_oath_rusted_sword", token):
		_fail("second-life ghost oath purchase rollback or settlement failed")
		return false
	var fact: Dictionary = oath.state.get("noncombatFlow", {}).get(
		"spineFacts", {}).get("fact:1:sword_origin_ghost_oath", {})
	var pending: Dictionary = oath.state.get("pendingLoadoutDecision", {})
	var debt: Array = oath.state.get("marketState", {}).get("debts", [])
	if int(oath.state.get("resources", {}).get("spiritStone", -1)) != int(
			before.get("resources", {}).get("spiritStone", -1)) - 4 \
			or int(oath.state.get("resources", {}).get("lifespan", -1)) != int(
			before.get("resources", {}).get("lifespan", -1)) - 3 \
			or debt.size() != 1 or not String(debt[0].get(
				"debtId", "")).contains("slot_3:life:1") \
			or fact.get("lifeCount") != 1 \
			or fact.get("payload", {}).get("itemInstanceId") != pending.get("instanceId"):
		_fail("second-life oath did not bind cost, sword, debt and current-life fact: "
			+ JSON.stringify({"stoneBefore": before.get("resources", {}).get(
				"spiritStone"), "stoneAfter": oath.state.get("resources", {}).get(
				"spiritStone"), "lifespanBefore": before.get(
				"resources", {}).get("lifespan"), "lifespanAfter": oath.state.get(
				"resources", {}).get("lifespan"), "debt": debt,
				"factLife": fact.get("lifeCount"), "factItem": fact.get(
					"payload", {}).get("itemInstanceId"),
				"pendingItem": pending.get("instanceId")}))
		return false
	var purchased = Domain.new(Registry.new(),
		RunSession.new(branch_path, "slot_3"), "slot_3")
	_stabilize(purchased)
	if not purchased.restore() or not _same(purchased.state, oath.state) \
			or not purchased.resolve_vendor_loadout("stash",
				purchased.issue_choice_token()):
		_fail("second-life purchased oath failed strict restart or stash")
		return false
	var stashed = Domain.new(Registry.new(),
		RunSession.new(branch_path, "slot_3"), "slot_3")
	_stabilize(stashed)
	if not stashed.restore() or not _same(stashed.state, purchased.state) \
			or not stashed.close_vendor(stashed.issue_choice_token()):
		_fail("second-life stashed oath failed strict restart or exit")
		return false
	var result = Domain.new(Registry.new(),
		RunSession.new(branch_path, "slot_3"), "slot_3")
	_stabilize(result)
	if not result.restore() or not _same(result.state, stashed.state) \
			or result.state.get("phase") != "VENDOR_RESULT_PENDING" \
			or not result.choose("right", result.issue_choice_token()):
		_fail("second-life purchased ghost result failed strict restart")
		return false
	var done = Domain.new(Registry.new(),
		RunSession.new(branch_path, "slot_3"), "slot_3")
	_stabilize(done)
	if not done.restore() or not _same(done.state, result.state) \
			or done.state.get("marketState", {}).get("debts", []).size() != 1 \
			or FileAccess.get_file_as_string(open._store.v2_path) != bytes:
		_fail("second-life oath branch changed main save or lost unpaid debt")
		return false
	for step in 6:
		if done.state.get("phase") == "FLOW_PENDING" and not done.resume_flow():
			_fail("second-life oath route stopped before source debt due: "
				+ done.flow_failure_reason())
			return false
		var card: Dictionary = done.get_current_card()
		if done.state.get("phase") == "GHOST_DEBT_PENDING":
			break
		var direction := "right" if done.state.get("phase") == \
			"MARKET_PENDING" else "left"
		if card.get("id") == "q_shop" and done.can_choose_direction("down"):
			direction = "down"
		elif not done.can_choose_direction(direction):
			direction = "right"
		if not done.choose(direction, done.issue_choice_token()):
			_fail("second-life oath route could not advance the debt clock")
			return false
	if done.state.get("phase") != "GHOST_DEBT_PENDING":
		_fail("second-life oath debt did not naturally mature")
		return false
	return _verify_debt_outcomes(done, branch_path)


func _verify_debt_outcomes(due: RefCounted, due_path: String) -> bool:
	var card: Dictionary = due.get_current_card()
	var debt_id := String(due.state.get("pendingGhostDebtId", ""))
	var fact_id := "fact:1:sword_origin_ghost_oath"
	var debts: Array = due.state.get("marketState", {}).get("debts", [])
	var authored_due := int(debts[0].get("dueDecisionIndex", -1)) \
		if debts.size() == 1 else -1
	if not String(card.get("id", "")).begins_with("ghost_debt_due:") \
			or not debt_id.contains("slot_3:life:1") \
			or authored_due < 0 \
			or int(due.state.get("runClock", {}).get("decisionIndex", -1)) != authored_due \
			or not due.can_choose_direction("left") \
			or not due.can_choose_direction("right"):
		_fail("second-life source ghost debt card or due clock diverged")
		return false
	var pending = Domain.new(Registry.new(),
		RunSession.new(due_path, "slot_3"), "slot_3")
	_stabilize(pending)
	if not pending.restore() or not _same(pending.state, due.state) \
			or pending.get_current_card().get("id") != card.get("id"):
		_fail("second-life pending ghost debt failed strict restart")
		return false
	var before: Dictionary = pending.state.duplicate(true)
	var bytes := FileAccess.get_file_as_string(pending._store.v2_path)
	var default_path := "user://tests/rebirth_ghost_default_%d_%d.json" % [
		OS.get_process_id(), Time.get_ticks_usec()]
	var default_store = RunSession.new(default_path, "slot_3")
	var file := FileAccess.open(default_store.v2_path, FileAccess.WRITE)
	if file == null:
		_fail("second-life ghost debt default branch could not stage save")
		return false
	file.store_string(bytes)
	file.close()
	var token := pending.issue_choice_token()
	pending._store.fail_promotion_once = true
	if pending.choose("left", token) or not _same(pending.state, before) \
			or FileAccess.get_file_as_string(pending._store.v2_path) != bytes \
			or not pending.choose("left", token):
		_fail("second-life ghost debt payment rollback or settlement failed")
		return false
	var paid_debt: Dictionary = pending.state.get("marketState", {}).get(
		"debts", [])[0]
	var paid_fact: Dictionary = pending.state.get("noncombatFlow", {}).get(
		"spineFacts", {}).get(fact_id, {})
	var consumption_key := fact_id + ":ghost_oath_debt_settlement"
	if int(pending.state.get("resources", {}).get("spiritStone", -1)) != int(
			before.get("resources", {}).get("spiritStone", -1)) - 2 \
			or paid_debt.get("status") != "SETTLED" \
			or pending.state.get("marketState", {}).get(
				"ghostMarketAccess") != "open" \
			or paid_fact.get("status") != "consumed" \
			or not pending.state.get("noncombatFlow", {}).get(
				"spineConsumptions", {}).has(consumption_key):
		_fail("second-life paid ghost debt did not settle source cost and fact once")
		return false
	var paid = Domain.new(Registry.new(),
		RunSession.new(due_path, "slot_3"), "slot_3")
	_stabilize(paid)
	if not paid.restore() or not _same(paid.state, pending.state):
		_fail("second-life paid ghost debt failed strict restart")
		return false
	var defaulted = Domain.new(Registry.new(), default_store, "slot_3")
	_stabilize(defaulted)
	if not defaulted.restore() or not _same(defaulted.state, before) \
			or not defaulted.choose("right", defaulted.issue_choice_token()):
		_fail("second-life ghost debt refusal did not settle from due save")
		return false
	var default_debt: Dictionary = defaulted.state.get("marketState", {}).get(
		"debts", [])[0]
	if default_debt.get("status") != "DEFAULTED" \
			or defaulted.state.get("marketState", {}).get(
				"ghostMarketAccess") != "revoked" \
			or defaulted.state.get("noncombatFlow", {}).get(
				"spineFacts", {}).get(fact_id, {}).get("status") != "consumed" \
			or int(defaulted.state.get("resources", {}).get(
				"spiritStone", -1)) != int(before.get(
					"resources", {}).get("spiritStone", -1)):
		_fail("second-life default did not revoke ghost access or consume fact")
		return false
	var default_reopen = Domain.new(Registry.new(),
		RunSession.new(default_path, "slot_3"), "slot_3")
	_stabilize(default_reopen)
	if not default_reopen.restore() or not _same(default_reopen.state,
			defaulted.state):
		_fail("second-life defaulted ghost debt failed strict restart")
		return false
	return true


func _verify_old_hint_snapshot(game: RefCounted) -> bool:
	if game.state.get("phase") != "FLOW_PENDING" \
			or not game.state.get("pendingHintCard") is Dictionary \
			or game.state.get("heavensHintState", {}).get("lifeCount") != 1:
		_fail("second-life pending hint was not naturally queued")
		return false
	var branch_path := "user://tests/rebirth_old_hint_%d_%d.json" % [
		OS.get_process_id(), Time.get_ticks_usec()]
	var branch_store = RunSession.new(branch_path, "slot_3")
	var file := FileAccess.open(branch_store.v2_path, FileAccess.WRITE)
	if file == null:
		_fail("old second-life hint branch could not stage save")
		return false
	file.store_string(FileAccess.get_file_as_string(game._store.v2_path))
	file.close()
	var legacy = Domain.new(Registry.new(), branch_store, "slot_3")
	_stabilize(legacy)
	if not legacy.restore() or not _same(legacy.state, game.state):
		_fail("old hint branch could not reopen its source checkpoint")
		return false
	var old_state: Dictionary = legacy.state.duplicate(true)
	old_state["heavensHintState"]["lifeCount"] = 0
	if branch_store.commit_snapshot(old_state, legacy._store_revision).get("ok") != true:
		_fail("old second-life hint identity snapshot could not be committed")
		return false
	var old_reopen = Domain.new(Registry.new(),
		RunSession.new(branch_path, "slot_3"), "slot_3")
	_stabilize(old_reopen)
	if not old_reopen.restore() or not _same(old_reopen.state, old_state) \
			or not old_reopen._hint_flow.legacy_life_count \
			or not old_reopen.resume_flow() \
			or old_reopen.state.get("phase") != "HINT_PENDING" \
			or not old_reopen.choose("left", old_reopen.issue_choice_token()):
		_fail("old second-life hint identity did not replay and continue")
		return false
	var continued = Domain.new(Registry.new(),
		RunSession.new(branch_path, "slot_3"), "slot_3")
	_stabilize(continued)
	if not continued.restore() or not _same(continued.state, old_reopen.state):
		_fail("continued old second-life hint did not strictly restart")
		return false
	return true


func _verify_old_trade_snapshot(game: RefCounted) -> bool:
	if game.state.get("phase") != "FLOW_PENDING" \
			or game.state.get("tradeRouteLegacyUnverified") != false \
			or int(game.state.get("runClock", {}).get("decisionIndex", -1)) != 17:
		_fail("second-life pre-ghost route did not reach its source checkpoint")
		return false
	var branch_path := "user://tests/rebirth_old_trade_%d_%d.json" % [
		OS.get_process_id(), Time.get_ticks_usec()]
	var branch_store = RunSession.new(branch_path, "slot_3")
	var main_bytes := FileAccess.get_file_as_string(game._store.v2_path)
	var file := FileAccess.open(branch_store.v2_path, FileAccess.WRITE)
	if file == null:
		_fail("old second-life trade branch could not stage save")
		return false
	file.store_string(main_bytes)
	file.close()
	var prior = Domain.new(Registry.new(), branch_store, "slot_3")
	_stabilize(prior)
	if not prior.restore() or not _same(prior.state, game.state):
		_fail("old second-life trade branch could not restore source checkpoint")
		return false
	var old_state: Dictionary = prior.state.duplicate(true)
	old_state["tradeRouteLegacyUnverified"] = true
	if branch_store.commit_snapshot(old_state, prior._store_revision).get("ok") != true:
		_fail("old second-life trade flag snapshot could not be committed")
		return false
	var old_reopen = Domain.new(Registry.new(),
		RunSession.new(branch_path, "slot_3"), "slot_3")
	_stabilize(old_reopen)
	if not old_reopen.restore() or not _same(old_reopen.state, old_state):
		_fail("old second-life trade flag failed strict restart")
		return false
	if not old_reopen.resume_flow():
		_fail("old second-life trade flag stopped flow: " + old_reopen.flow_failure_reason())
		return false
	if old_reopen.get_current_card().get("id") != "q_spiritStone" \
			or not old_reopen.choose("left", old_reopen.issue_choice_token()):
		_fail("old second-life trade flag lost its source spirit-stone choice")
		return false
	var branch_revision: int = old_reopen._store_revision
	# Explore the intervening authored cards in memory, then verify the entire
	# final replay from disk once at the ghost entry checkpoint.
	old_reopen._store = null
	for step in range(120):
		if old_reopen.get_current_card().get("id") == "market_encounter" \
				and old_reopen.can_choose_direction("left"):
			break
		if old_reopen.state.get("phase") == "FLOW_PENDING":
			if not old_reopen.resume_flow():
				break
		else:
			var direction := ""
			for candidate in ["right", "left", "down", "up"]:
				if old_reopen.can_choose_direction(candidate):
					direction = candidate
					break
			if direction.is_empty() or not old_reopen.choose(direction,
					old_reopen.issue_choice_token()):
				break
	if old_reopen.get_current_card().get("id") != "market_encounter" \
			or not old_reopen.can_choose_direction("left") \
			or old_reopen.state.get("tradeRouteLegacyUnverified") != true:
		_fail("old second-life trade flag blocked the natural ghost card: " \
			+ JSON.stringify({"phase": old_reopen.state.get("phase"),
				"card": old_reopen.get_current_card().get("id"),
				"flow": old_reopen.flow_failure_reason(),
				"index": old_reopen.state.get("runClock", {}).get("decisionIndex")}))
		return false
	if branch_store.commit_snapshot(old_reopen.state, branch_revision).get("ok") != true:
		_fail("old second-life trade branch could not commit its ghost checkpoint")
		return false
	var ghost = Domain.new(Registry.new(),
		RunSession.new(branch_path, "slot_3"), "slot_3")
	_stabilize(ghost)
	var ghost_restored: bool = ghost.restore()
	var ghost_equal: bool = ghost_restored and _same(ghost.state, old_reopen.state)
	var ghost_can_enter: bool = ghost_equal and ghost.can_choose_direction("left")
	if not ghost_equal or not ghost_can_enter \
			or not ghost.choose("left", ghost.issue_choice_token()):
		_fail("old second-life trade flag ghost card failed strict restart or entry: " \
			+ JSON.stringify({"restored": ghost_restored, "equal": ghost_equal,
				"canEnter": ghost_can_enter, "store": ghost._store.last_error,
				"phase": ghost.state.get("phase"),
				"card": ghost.get_current_card().get("id")}))
		return false
	var opened = Domain.new(Registry.new(),
		RunSession.new(branch_path, "slot_3"), "slot_3")
	_stabilize(opened)
	if not opened.restore() or not _same(opened.state, ghost.state) \
			or opened.state.get("marketState", {}).get(
				"activeSession", {}).get("vendorId") != "ghost_market" \
			or FileAccess.get_file_as_string(game._store.v2_path) != main_bytes:
		_fail("old second-life trade flag ghost session was not durable or isolated")
		return false
	return true


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
