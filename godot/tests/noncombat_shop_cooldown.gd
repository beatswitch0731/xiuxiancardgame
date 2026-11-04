extends "res://tests/noncombat_normal_runtime.gd"

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var path := "user://tests/shop_cooldown_%d.json" % Time.get_ticks_usec()
	var game = Domain.new(Registry.new(), RunSession.new(path, "slot_3"), "slot_3")
	if not game.start("sword"):
		return _fail("source run did not start")
	var due: Dictionary = game.state.duplicate(true)
	due["turn"] = 32
	var prepared: Dictionary = game._prepare_normal_flow(due)
	if prepared.is_empty():
		return _fail("ordinary flow did not initialize")
	prepared["shopCooldown"] = 2
	prepared["randomMode"] = "fixed"
	prepared["fixedRoll"] = 0.99
	var first: Dictionary = game._check_prepriority_encounters(due)
	if first.is_empty() or first.get("normalFlow", {}).get("shopCooldown") != 1:
		return _fail("P25 check did not consume first cooldown tick")
	var second_flow: Dictionary = first["normalFlow"]
	var row := {}
	var before_rng := int(second_flow["rngState"])
	if game._secondary_shop_check(second_flow, {}, row, 32) != 0 \
			or second_flow.get("shopCooldown") != 0 \
			or row.get("phaseShopCooldownBefore") != 1 \
			or row.get("phaseShopCooldownAfter") != 0 \
			or row.has("phaseShopRoll") or int(second_flow["rngState"]) != before_rng:
		return _fail("P10 check ignored cooldown after P25")
	var off_interval: Dictionary = second_flow.duplicate(true)
	off_interval["shopCooldown"] = 1
	row = {}
	if game._secondary_shop_check(off_interval, {}, row, 33) != 0 \
			or off_interval.get("shopCooldown") != 0 or row.has("phaseShopRoll"):
		return _fail("P10 off-interval check did not consume cooldown")
	var ready: Dictionary = second_flow.duplicate(true)
	ready["shopCooldown"] = 0
	ready["fixedRoll"] = 0.0
	row = {}
	if game._secondary_shop_check(ready, {}, row, 32) != 1 \
			or ready.get("shopCooldown") != 6 or row.get("phaseShopRoll") != 0.0:
		return _fail("P10 eligible shop check did not hit or establish protection")
	var legacy: Dictionary = second_flow.duplicate(true)
	legacy["shopCooldown"] = 1
	legacy["fixedRoll"] = 0.99
	row = {}
	if game._secondary_shop_check(legacy, {"phaseShopRoll": 0.99}, row, 32) != 0 \
			or legacy.get("shopCooldown") != 1 \
			or row.get("phaseShopRoll") != 0.99 \
			or row.has("phaseShopCooldownBefore"):
		return _fail("old P10 receipt lost its historical replay rule")
	if not _verify_real_shop_source():
		return
	print("NONCOMBAT_SHOP_COOLDOWN_PASS first=true second=true real_resume=true old_restore=true")
	quit(0)

func _verify_real_shop_source() -> bool:
	var path := "user://tests/shop_source_%d.json" % Time.get_ticks_usec()
	var game = Domain.new(Registry.new(), RunSession.new(path, "slot_3"), "slot_3")
	_set_zero_rolls(game)
	if not game.start("sword") or not _reach_bazaar(game) \
			or not game.choose("left", game.issue_choice_token()) \
			or not game.perform_vendor_action("ask_luo", game.issue_choice_token()) \
			or not game.close_vendor(game.issue_choice_token()) \
			or not game.choose("right", game.issue_choice_token()) \
			or not game.resume_flow() \
			or not game.choose("right", game.issue_choice_token()) \
			or not game.resume_flow() \
			or not game.choose("left", game.issue_choice_token()) \
			or not game.choose("left", game.issue_choice_token()) \
			or not game.resume_flow() \
			or not game.choose("right", game.issue_choice_token()) \
			or not game.resume_flow() \
			or not game.choose("left", game.issue_choice_token()) \
			or game.state.get("phase") != "FLOW_PENDING" \
			or game.state.get("runClock", {}).get("decisionIndex") != 27:
		_fail("source route did not reach first ordinary draw")
		return false
	var source_roll := -1.0
	for n in range(1, 100):
		var trial := float(n) / 100.0
		game._normal_roll_override = trial
		var projected: Dictionary = game._draw_normal_after_priorities(game.state)
		if not projected.is_empty() and projected.get("normalFlow", {}).get(
				"draws", []).back().get("source") == "shop":
			source_roll = trial
			break
	if source_roll < 0.0:
		_fail("no supported source-shop card found from real ordinary checkpoint")
		return false
	if not game.resume_flow() or game.state.get("phase") != "NORMAL_PENDING":
		_fail("real resume_flow did not present source-shop ordinary card")
		return false
	var draw: Dictionary = game.state.get("normalFlow", {}).get("draws", []).back()
	if draw.get("source") != "shop" or draw.get("phaseShopCooldownBefore") != 0 \
			or draw.get("phaseShopCooldownAfter") != 0 or draw.has("phaseShopRoll"):
		_fail("real source-shop draw lost second-check receipt")
		return false
	var pending: Dictionary = game.state.duplicate(true)
	var reload = Domain.new(Registry.new(), RunSession.new(path, "slot_3"), "slot_3")
	_set_zero_rolls(reload)
	reload._normal_roll_override = source_roll
	if not reload.restore() or not _same(reload.state, pending):
		_fail("source-shop ordinary card did not strictly restore")
		return false
	var old_record: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(
		game._store.v2_path))
	var old_draw: Dictionary = old_record["state"]["normalFlow"]["draws"].back()
	old_draw.erase("phaseShopCooldownBefore")
	old_draw.erase("phaseShopCooldownAfter")
	var old_path := "user://tests/shop_old_draw_%d.json" % Time.get_ticks_usec()
	var old_store = RunSession.new(old_path, "slot_3")
	var file := FileAccess.open(old_store.v2_path, FileAccess.WRITE)
	if file == null:
		_fail("old source-shop receipt could not be staged")
		return false
	file.store_string(JSON.stringify(old_record))
	file.close()
	var old_game = Domain.new(Registry.new(), old_store, "slot_3")
	_set_zero_rolls(old_game)
	old_game._normal_roll_override = source_roll
	if not old_game.restore() or old_game.state.get("normalFlow", {}).get(
			"draws", []).back().has("phaseShopCooldownBefore") \
			or old_game.get_current_card().get("id") != draw.get("cardId"):
		_fail("historical source-shop receipt did not strictly restore")
		return false
	return true

func _fail(message: String) -> void:
	push_error(message)
	quit(1)
