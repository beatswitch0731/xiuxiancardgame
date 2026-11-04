extends "res://tests/noncombat_normal_runtime.gd"

func _run() -> void:
	var path := "user://tests/priority_order_%d.json" % Time.get_ticks_usec()
	var game = Domain.new(Registry.new(), RunSession.new(path, "slot_3"), "slot_3")
	_set_zero_rolls(game)
	game._echo_activation_index = 1000
	if not game.start("sword") or not _reach_bazaar(game):
		return _fail("priority order source bazaar was unreachable")
	var bazaar_card: Dictionary = game.get_current_card().duplicate(true)
	var bazaar_location: String = String(game.state.get("marketCardLocation", ""))
	if not game.choose("left", game.issue_choice_token()) \
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
			or not game.choose("left", game.issue_choice_token()):
		return _fail("priority order source route could not reach ordinary cards")
	var pre_normal_bytes := FileAccess.get_file_as_string(game._store.v2_path)
	if not _verify_legacy_short_upgrade(pre_normal_bytes) \
			or not _verify_missed_priority_replay(pre_normal_bytes,
				bazaar_card, bazaar_location):
		return
	var collision_checked := false
	for n in 16:
		if game.state.get("turn") == 30 and game.state.get("phase") == "FLOW_PENDING":
			game.state["pendingMarketCard"] = bazaar_card.duplicate(true)
			game.state["marketCardLocation"] = bazaar_location
			var before: Dictionary = game.state.duplicate(true)
			if not game.resume_flow() or game.get_current_card().get("id") \
					!= "camp_meditation" or game.state.get("phase") != "CAMP_PENDING" \
					or game.state.get("pendingMarketCard") != bazaar_card \
					or game.state.get("normalFlow", {}).get("priorityChecks", []).back().get(
						"p24CampRoll") != 0.0:
				return _fail("P24 source camp was skipped behind P20 bazaar at decision 30")
			var no_hit: Dictionary = before.duplicate(true)
			var flow: Dictionary = no_hit.get("normalFlow", {})
			if flow.is_empty():
				return _fail("priority order route lost normal RNG authority")
			flow["fixedRoll"] = 0.99
			var old_rng := int(flow.get("rngState", 0))
			var checked: Dictionary = game._check_prepriority_encounters(no_hit)
			var checks: Array = checked.get("normalFlow", {}).get("priorityChecks", [])
			if checked.is_empty() or checks.is_empty() \
					or checks.back().get("p24CampRoll") != 0.99 \
					or int(checked["normalFlow"].get("rngState", 0)) \
						!= int((old_rng * 48271) % 2147483647) \
					or game._market_flow.resume(checked).get("phase") != "MARKET_PENDING":
				return _fail("missed P24 roll did not advance RNG before queued market")
			var shop_due: Dictionary = before.duplicate(true)
			shop_due["turn"] = 32
			shop_due["normalFlow"]["fixedRoll"] = 0.99
			var shop_checked: Dictionary = game._check_prepriority_encounters(shop_due)
			var shop_checks: Array = shop_checked.get("normalFlow", {}).get(
				"priorityChecks", [])
			if shop_checked.is_empty() or shop_checks.is_empty() \
					or shop_checks.back().get("p25ShopRoll") != 0.99 \
					or game._market_flow.resume(shop_checked).get("phase") != "MARKET_PENDING":
				return _fail("missed P25 roll did not precede queued market")
			collision_checked = true
			break
		if game.state.get("phase") == "FLOW_PENDING":
			if not game.resume_flow():
				return _fail("priority order route stopped before boundary: " + game.flow_failure_reason())
		else:
			var direction := ""
			for value in ["right", "left", "down", "up"]:
				if game.can_choose_direction(value):
					direction = value
					break
			if direction.is_empty() or not game.choose(direction, game.issue_choice_token()):
				return _fail("priority order route choice blocked: " + direction)
	if not collision_checked:
		return _fail("priority order P24/P20 collision was not reached")
	print("NONCOMBAT_PRIORITY_ORDER_PASS p24_before_market=true p25_before_market=true rng=true atomic=true")
	quit(0)


func _verify_missed_priority_replay(pre_normal_bytes: String,
		bazaar_card: Dictionary, bazaar_location: String) -> bool:
	var path := "user://tests/priority_miss_%d.json" % Time.get_ticks_usec()
	var store = RunSession.new(path, "slot_3")
	var file := FileAccess.open(store.v2_path, FileAccess.WRITE)
	if file == null:
		return _reject("priority replay fixture could not be staged")
	file.store_string(pre_normal_bytes)
	file.close()
	var game = Domain.new(Registry.new(), store, "slot_3")
	_set_zero_rolls(game)
	if not game.restore():
		return _reject("priority replay source checkpoint could not restore")
	game._echo_activation_index = 1000
	game._normal_roll_override = 0.99
	if not game.resume_flow() or game.get_current_card().get("id") \
			!= "atm_qi_sect_gate_night" \
			or not game.choose("left", game.issue_choice_token()) \
			or not game.resume_flow() or game.get_current_card().get("id") \
			!= "atm_qi_market_old_woman" \
			or not game.choose("right", game.issue_choice_token()) \
			or not game.resume_flow() or game.get_current_card().get("id") \
			!= "atm_qi_tea_rumor" \
			or not game.choose("right", game.issue_choice_token()) \
			or not game.choose("up", game.issue_choice_token()):
		return _reject("high-roll source route did not reach P24 miss")
	var collision_path := "user://tests/priority_missed_market_%d.json" % Time.get_ticks_usec()
	var collision_store = RunSession.new(collision_path, "slot_3")
	var collision_file := FileAccess.open(collision_store.v2_path, FileAccess.WRITE)
	if collision_file == null:
		return _reject("missed priority market fixture could not be staged")
	collision_file.store_string(FileAccess.get_file_as_string(store.v2_path))
	collision_file.close()
	var collision = Domain.new(Registry.new(), collision_store, "slot_3")
	_set_zero_rolls(collision)
	if not collision.restore():
		return _reject("missed priority market checkpoint did not restore")
	collision._echo_activation_index = 1000
	collision.state["pendingMarketCard"] = bazaar_card.duplicate(true)
	collision.state["marketCardLocation"] = bazaar_location
	if not collision.resume_flow() or collision.get_current_card().get("id") \
			!= "bazaar_encounter" or collision.state.get("normalFlow", {}).get(
			"priorityChecks", []).back().get("p24CampRoll") != 0.99:
		return _reject("real resume_flow skipped P24 miss before P20 market: phase=%s card=%s checks=%s" % [
			collision.state.get("phase"), collision.get_current_card().get("id"),
			collision.state.get("normalFlow", {}).get("priorityChecks", [])])
	if not game.resume_flow() or game.get_current_card().get("id") \
			!= "sd_qi_meditation_voice":
		return _reject("high-roll source route did not reach P24 miss")
	var pending: Dictionary = game.state.duplicate(true)
	var checks: Array = pending.get("normalFlow", {}).get("priorityChecks", [])
	if checks.is_empty() or checks.back().get("turn") != 30 \
			or checks.back().get("p24CampRoll") != 0.99:
		return _reject("missed P24 was not committed with its RNG receipt")
	var reload = Domain.new(Registry.new(), RunSession.new(path, "slot_3"), "slot_3")
	_set_zero_rolls(reload)
	if not reload.restore() or not _same(reload.state, pending):
		return _reject("missed P24 priority receipt did not strictly replay")
	var forged: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(
		store.v2_path))
	forged["state"]["normalFlow"]["priorityChecks"][-1]["p24CampRoll"] = 0.01
	var bad_store = RunSession.new(
		"user://tests/priority_forged_%d.json" % Time.get_ticks_usec(), "slot_3")
	var bad_file := FileAccess.open(bad_store.v2_path, FileAccess.WRITE)
	if bad_file == null:
		return _reject("forged priority receipt could not be staged")
	var bad_bytes := JSON.stringify(forged)
	bad_file.store_string(bad_bytes)
	bad_file.close()
	var bad_game = Domain.new(Registry.new(), bad_store, "slot_3")
	_set_zero_rolls(bad_game)
	if bad_game.restore() or FileAccess.get_file_as_string(bad_store.v2_path) != bad_bytes:
		return _reject("forged priority receipt was accepted or modified on disk")
	return true


func _verify_legacy_short_upgrade(pre_normal_bytes: String) -> bool:
	var old_record: Dictionary = JSON.parse_string(pre_normal_bytes)
	old_record["state"].erase("replayHistory")
	var path := "user://tests/priority_old_history_%d.json" % Time.get_ticks_usec()
	var store = RunSession.new(path, "slot_3")
	var file := FileAccess.open(store.v2_path, FileAccess.WRITE)
	if file == null:
		return _reject("short legacy history fixture could not be staged")
	file.store_string(JSON.stringify(old_record))
	file.close()
	var game = Domain.new(Registry.new(), store, "slot_3")
	_set_zero_rolls(game)
	if not game.restore() or game.state.has("replayHistory"):
		return _reject("short legacy history did not strictly restore")
	game._echo_activation_index = 1000
	if not game.resume_flow() or game.get_current_card().get("id") != "q_gathering" \
			or not game.choose("left", game.issue_choice_token()) \
			or game.state.get("replayHistory", []).size() != 30:
		return _reject("short legacy history did not upgrade on first decision")
	var reload = Domain.new(Registry.new(), RunSession.new(path, "slot_3"), "slot_3")
	_set_zero_rolls(reload)
	if not reload.restore() or not _same(reload.state, game.state):
		return _reject("upgraded short legacy history did not replay")
	return true


func _reject(message: String) -> bool:
	_fail(message)
	return false
