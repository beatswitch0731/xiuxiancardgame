extends SceneTree

const Registry = preload("res://scripts/runtime_data_registry.gd")
const Domain = preload("res://scripts/noncombat_domain.gd")
const RunSession = preload("res://scripts/noncombat_run_session.gd")

class FactionDriftContent extends "res://scripts/noncombat_content_repository.gd":
	func source_sha256(module_id: String) -> String:
		return "f".repeat(64) if module_id == "world:factions" else super.source_sha256(module_id)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var path := "user://tests/whitefox_third_%d.json" % Time.get_ticks_usec()
	var game = Domain.new(Registry.new(), RunSession.new(path, "slot_3"), "slot_3")
	if not game.start("sword"):
		return _fail("start")
	for i in 5:
		if not game.choose("left", game.issue_choice_token()):
			return _fail("tutorial")
	if not game.choose("right", game.issue_choice_token()) \
			or not game.choose("left", game.issue_choice_token()) \
			or not game.resume_flow() \
			or not game.choose("left", game.issue_choice_token()) \
			or not game.choose("right", game.issue_choice_token()) \
			or not game.resume_flow() \
			or not game.choose("right", game.issue_choice_token()) \
			or not game.choose("left", game.issue_choice_token()):
		return _fail("third card route")
	if game.get_current_card().get("id") != "q_whiteFox_3":
		return _fail("third card missing")
	var view: Control = load("res://scenes/noncombat_opening.tscn").instantiate()
	view.save_path = ""
	root.add_child(view)
	await process_frame
	view.opening = game
	view._render()
	var left_button: Button = view.choice_row.get_node_or_null("Choice_left")
	var right_button: Button = view.choice_row.get_node_or_null("Choice_right")
	var down_button: Button = view.choice_row.get_node_or_null("Choice_down")
	if left_button == null or right_button == null or down_button == null \
			or left_button.disabled or not right_button.disabled or down_button.disabled \
			or view.art_rect.texture == null:
		return _fail("third card desktop admission")
	game._store.fail_promotion_once = true
	view._on_choice_pressed("down", view._choice_token)
	await process_frame
	left_button = view.choice_row.get_node_or_null("Choice_left")
	right_button = view.choice_row.get_node_or_null("Choice_right")
	down_button = view.choice_row.get_node_or_null("Choice_down")
	if left_button == null or right_button == null or down_button == null \
			or left_button.disabled or not right_button.disabled or down_button.disabled \
			or game.get_current_card().get("id") != "q_whiteFox_3":
		return _fail("failed write reopened forbidden UI choice")
	root.remove_child(view)
	view.queue_free()
	var before: Dictionary = game.state.duplicate(true)
	var token: int = game.issue_choice_token()
	if token <= 0 or not game.can_choose_direction("left") or game.choose("right", token) \
			or game.state != before:
		return _fail("combat unavailable or unaffordable choice admitted")
	game._store.fail_promotion_once = true
	if game.choose("down", token) or game.state != before:
		return _fail("failed write leaked abandon")
	if not game.choose("down", token) or game.choose("down", token):
		return _fail("abandon did not settle once")
	if game.state.get("phase") != "FLOW_PENDING" \
			or game.state.get("questState", {}).get("questOutcomes", {}).get("white_fox_line") != "abandoned" \
			or not game.state.get("questState", {}).get("completedQuests", []).is_empty() \
			or game.state["resources"]["spiritStone"] != 10 \
			or game.state["attributes"]["karmaGood"] != 25 \
			or game.state.get("karmaPromiseFlags", {}).has("whiteFox") \
			or game.state.get("flags", {}).get("white_fox_lineCompleted") != false:
		return _fail("abandon differs from browser")
	var reloaded = Domain.new(Registry.new(), RunSession.new(path, "slot_3"), "slot_3")
	var restored_ok: bool = reloaded.restore()
	if not restored_ok:
		print("RELOAD_ERROR=", reloaded._store.last_error, " QUEST_ERROR=", reloaded._quest_flow.last_error)
	if not restored_ok or JSON.parse_string(JSON.stringify(reloaded.state)) != \
			JSON.parse_string(JSON.stringify(game.state)) \
			or not reloaded.resume_flow() or reloaded.get_current_card().get("id") != "ch_qi_60":
		return _fail("abandon reload or next card")
	var drift_store = RunSession.new(path, "slot_3")
	var drift = Domain.new(Registry.new(), drift_store, "slot_3", FactionDriftContent.new())
	var drift_restored: bool = drift.restore()
	if drift_restored or drift_store.last_error != "SOURCE_MISMATCH":
		return _fail("faction source drift accepted: restored=%s error=%s" % [
			str(drift_restored), drift_store.last_error])
	# A controlled funded projection checks source reward math. The bounded
	# opening does not yet contain a source-backed +10 stone earning decision.
	var funded: Dictionary = before.duplicate(true)
	funded["resources"]["spiritStone"] = 20
	var paid: Dictionary = game._quest_flow.settle(funded, "right")
	if paid.is_empty() or paid["resources"]["spiritStone"] != 20 \
			or paid["attributes"]["karmaGood"] != 52 \
			or paid["attributes"]["fortune"] != 80 \
			or paid.get("questState", {}).get("questOutcomes", {}).get("white_fox_line") != "completed" \
			or paid.get("factionProgress", {}).get("reputations", {}).get("qingyun_sword") != 15 \
			or paid.get("factionProgress", {}).get("reputations", {}).get("xuesha_sect") != -15 \
			or not paid.get("karmaPromiseFlags", {}).has("whiteFox") \
			or not paid.get("karmaPromiseFlags", {}).has("foxGratitude") \
			or paid.get("karmaSeeds", []).filter(func(s: Dictionary) -> bool: return s.get("id") == "whiteFox")[0].get("delay") != 14 \
			or paid.get("karmaSeeds", []).filter(func(s: Dictionary) -> bool: return s.get("id") == "foxGratitude")[0].get("originQuest") != "white_fox_line":
		return _fail("funded reward differs from browser")
	if paid.get("tradeRoutePendingEvents", []).size() != 6 \
			or not game._trade_route_flow.settle(funded, paid) \
			or paid.has("tradeRoutePendingEvents") \
			or paid.get("tradeRouteState", {}).get("routes", {}).get(
				"cloud_sword_road", {}).get("openness") != 72 \
			or paid.get("tradeRouteState", {}).get("routes", {}).get(
				"western_blood_route", {}).get("openness") != 36:
		return _fail("white fox quest reward did not emit source trade route events")
	var continuing: Dictionary = funded.duplicate(true)
	continuing["factionProgress"] = paid["factionProgress"].duplicate(true)
	continuing["factionProgress"]["reputations"]["qingyun_sword"] = 20
	var carried: Dictionary = game._quest_flow.settle(continuing, "right")
	if carried.is_empty() or carried["factionProgress"]["reputations"]["qingyun_sword"] != 25:
		return _fail("existing faction reputation was reset")
	print("NONCOMBAT_WHITEFOX_THIRD_PASS abandon=true funds_gate=true reward_projection=true replay=true")
	quit(0)

func _fail(reason: String) -> void:
	push_error(reason)
	quit(1)
