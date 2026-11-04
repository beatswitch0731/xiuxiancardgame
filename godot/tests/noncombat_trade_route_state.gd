extends SceneTree

const Registry = preload("res://scripts/runtime_data_registry.gd")
const Domain = preload("res://scripts/noncombat_domain.gd")
const RunSession = preload("res://scripts/noncombat_run_session.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var helper: Script = load("res://scripts/noncombat_trade_route_flow.gd")
	if helper == null:
		return _fail("trade route source projection is not implemented")
	var path := "user://tests/trade_route_%d.json" % Time.get_ticks_usec()
	var game = Domain.new(Registry.new(), RunSession.new(path, "slot_3"), "slot_3")
	if not game.start("sword"):
		return _fail("fresh route source fixture failed to start")
	var flow: RefCounted = helper.new(game._content)
	var prior: Dictionary = game.state.duplicate(true)
	var initial: Dictionary = prior.get("tradeRouteState", {})
	if prior.get("tradeRouteVersion") != 1 or initial.get("version") != 1 \
			or initial.get("routes", {}).get("cloud_sword_road", {}).get("openness") != 70 \
			or initial.get("routes", {}).get("herb_river", {}).get("prosperity") != 60:
		return _fail("fresh run did not persist source trade routes")
	var factions: Dictionary = game._content.read_module("world:factions")
	var reputations := {}
	var stages := {}
	for faction in factions.get("factions", []):
		reputations[faction["id"]] = int(faction["startReputation"])
		for sub in faction.get("subfactions", []):
			reputations[sub["id"]] = int(sub["startReputation"])
	for id in factions.get("undercurrents", {}):
		stages[id] = int(factions["undercurrents"][id]["stage"])
	var candidate: Dictionary = prior.duplicate(true)
	var quest: Dictionary = game._content.read_module("quests:white_fox")["quest"]
	candidate["factionProgress"] = {"reputations": reputations.duplicate(true),
		"undercurrentStages": stages, "globalFlags": {}, "ticksSinceEvent": 0}
	candidate["tradeRoutePendingEvents"] = []
	for id in quest["factionRewards"]:
		var old: int = int(candidate["factionProgress"]["reputations"][id])
		var next: int = clampi(old + int(quest["factionRewards"][id]), -100, 100)
		candidate["factionProgress"]["reputations"][id] = next
		candidate["tradeRoutePendingEvents"].append({"kind": "reputation",
			"factionId": id, "oldValue": old, "newValue": next})
	prior["turn"] = 13
	candidate["turn"] = 14
	if not flow.settle(prior, candidate) or candidate.has("tradeRoutePendingEvents"):
		return _fail("white fox reputation events were not settled into routes")
	var routes: Dictionary = candidate.get("tradeRouteState", {}).get("routes", {})
	if routes.get("cloud_sword_road", {}).get("openness") != 72 \
			or routes.get("cloud_sword_road", {}).get("prosperity") != 56 \
			or routes.get("herb_river", {}).get("openness") != 64 \
			or routes.get("herb_river", {}).get("prosperity") != 61 \
			or routes.get("western_blood_route", {}).get("openness") != 36 \
			or routes.get("western_blood_route", {}).get("prosperity") != 41 \
			or routes.get("ruin_star_path", {}).get("openness") != 28 \
			or routes.get("ruin_star_path", {}).get("prosperity") != 32 \
			or routes.get("ruin_star_path", {}).get("history", []).size() != 2 \
			or routes.get("ruin_star_path", {}).get("history", [])[0].get("turn") != 13:
		return _fail("trade route reputation projection differs from source JS")
	var forged: Dictionary = candidate.duplicate(true)
	forged["factionProgress"]["reputations"]["qingyun_sword"] += 1
	if flow.settle(candidate, forged):
		return _fail("unreceipted reputation change was accepted")
	var undercurrent: Dictionary = prior.duplicate(true)
	undercurrent["factionProgress"] = {"reputations": reputations.duplicate(true),
		"undercurrentStages": stages.duplicate(true), "globalFlags": {},
		"ticksSinceEvent": 0}
	undercurrent["factionProgress"]["undercurrentStages"]["qingyun_debate"] = 2
	undercurrent["tradeRoutePendingEvents"] = [{"kind": "undercurrent",
		"undercurrentId": "qingyun_debate", "oldStage": 1, "newStage": 2}]
	if not flow.settle(prior, undercurrent) or undercurrent.get(
			"tradeRouteState", {}).get("routes", {}).get(
			"cloud_sword_road", {}).get("openness") != 69 or undercurrent.get(
			"tradeRouteState", {}).get("routes", {}).get(
			"cloud_sword_road", {}).get("danger") != 20:
		return _fail("source undercurrent event did not change its matching route")
	var unreceipted_stage: Dictionary = prior.duplicate(true)
	unreceipted_stage["factionProgress"] = undercurrent["factionProgress"].duplicate(true)
	if flow.settle(prior, unreceipted_stage):
		return _fail("unreceipted undercurrent stage was accepted")
	var catalog: RefCounted = load("res://scripts/noncombat_ghost_market_catalog.gd").new(
		game._content)
	var ghost_plan: Dictionary = catalog.generate(candidate,
		func() -> float: return 0.37)
	if ghost_plan.is_empty() or ghost_plan.get("meta", {}).get("route", {}).get(
		"openness") != 72:
		return _fail("source-backed changed faction route still blocks ghost catalogue")
	var regulated: RefCounted = load(
		"res://scripts/noncombat_regulated_shop_catalog.gd").new(game._content)
	if not is_equal_approx(regulated._price_multiplier(candidate), 0.848):
		return _fail("regulated market ignored source-backed faction route")
	if not game.choose("left", game.issue_choice_token()):
		return _fail("fresh route tutorial decision failed")
	var restored = Domain.new(Registry.new(), RunSession.new(path, "slot_3"), "slot_3")
	var restored_ok: bool = restored.restore()
	if not restored_ok or JSON.parse_string(JSON.stringify(restored.state)) != \
			JSON.parse_string(JSON.stringify(game.state)):
		return _fail("fresh route state did not strictly replay: " +
			str(restored_ok) + " / " + String(restored._store.last_error) + " / " +
			String(restored._trade_route_flow.last_error))
	var legacy_path := "user://tests/trade_route_legacy_%d.json" % Time.get_ticks_usec()
	var legacy_snapshot: Dictionary = game.state.duplicate(true)
	for key in ["tradeRouteVersion", "tradeRouteActivationIndex",
			"tradeRouteSourcePins", "tradeRouteRuleSourceSha",
			"tradeRouteLegacyUnverified", "tradeRouteState"]:
		legacy_snapshot.erase(key)
	var later_prefix: Dictionary = legacy_snapshot.duplicate(true)
	later_prefix["runClock"]["decisionIndex"] = 6
	if flow.legacy_prefix_trusted(later_prefix):
		return _fail("late legacy prefix was treated as a certified initial route")
	var legacy_store = RunSession.new(legacy_path, "slot_3")
	if legacy_store.commit_snapshot(legacy_snapshot, -1).get("ok") != true:
		return _fail("pre-route snapshot fixture could not be committed")
	var legacy = Domain.new(Registry.new(), RunSession.new(legacy_path, "slot_3"),
		"slot_3")
	if not legacy.restore() or legacy.state.has("tradeRouteState") \
			or not legacy.choose("left", legacy.issue_choice_token()) \
			or legacy.state.get("tradeRouteActivationIndex") != 2 \
			or legacy.state.get("tradeRouteLegacyUnverified") != false \
			or catalog.generate(legacy.state,
				func() -> float: return 0.37).is_empty() \
			or not is_equal_approx(regulated._price_multiplier(
				legacy.state), 0.852):
		return _fail("pre-route snapshot did not resume with bounded legacy activation")
	var legacy_reloaded = Domain.new(Registry.new(), RunSession.new(legacy_path,
		"slot_3"), "slot_3")
	if not legacy_reloaded.restore() or JSON.parse_string(JSON.stringify(
			legacy_reloaded.state)) != JSON.parse_string(JSON.stringify(legacy.state)):
		return _fail("activated legacy route snapshot did not strictly replay")
	print("NONCOMBAT_TRADE_ROUTE_STATE_PASS fresh=true quest_routes=4 replay=true legacy=true")
	quit(0)


func _fail(reason: String) -> void:
	push_error(reason)
	quit(1)
