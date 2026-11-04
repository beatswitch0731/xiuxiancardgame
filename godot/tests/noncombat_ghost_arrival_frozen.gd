extends SceneTree

const Registry = preload("res://scripts/runtime_data_registry.gd")
const Domain = preload("res://scripts/noncombat_domain.gd")
const MarketFlow = preload("res://scripts/noncombat_market_flow.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var game = Domain.new(Registry.new(), null, "slot_3")
	game._market_flow.roll_override = 0.0
	if not game.start("pill"):
		return _fail("ghost arrival source fixture could not start")
	var prior: Dictionary = game.state.duplicate(true)
	prior["runClock"]["decisionIndex"] = 13
	prior["turn"] = 13
	prior["attributes"]["fortune"] = 50
	prior["currentLocation"] = "宗门"
	prior["marketState"]["nextGhostDecisionIndex"] = 14
	prior["marketState"]["nextBazaarDecisionIndex"] = 99
	var candidate: Dictionary = prior.duplicate(true)
	candidate["runClock"]["decisionIndex"] = 14
	candidate["turn"] = 14
	var flow = MarketFlow.new(game._content)
	flow.roll_override = 0.0
	if not flow.settle(prior, candidate, false, 0, 0):
		return _fail("due ghost arrival did not freeze stock: " + flow.last_error)
	var plan: Dictionary = candidate.get("pendingGhostPlan", {})
	if plan.is_empty() or plan.get("card") != candidate.get("pendingMarketCard") \
			or plan.get("stock", []).is_empty() \
			or not plan.get("sourcePins") is Dictionary \
			or plan.get("sourcePins", {}).get("markets:vendor_profiles") != \
				game._content.source_sha256("markets:vendor_profiles") \
			or candidate.get("marketState", {}).get("lastGhostDecisionIndex") != 14 \
			or candidate.get("marketState", {}).get("nextGhostDecisionIndex") != 30 \
			or candidate.get("marketRngState", {}).get("value") == prior.get(
				"marketRngState", {}).get("value"):
		return _fail("ghost stock/card or cadence was not frozen with the random stream")
	var repeated: Dictionary = prior.duplicate(true)
	repeated["runClock"]["decisionIndex"] = 14
	repeated["turn"] = 14
	var replay_flow = MarketFlow.new(game._content)
	replay_flow.roll_override = 0.0
	if not replay_flow.settle(prior, repeated, false, 0, 0) \
			or JSON.parse_string(JSON.stringify(repeated)) != \
				JSON.parse_string(JSON.stringify(candidate)):
		return _fail("same saved market RNG did not reproduce ghost stock and card")
	var untrusted: Dictionary = prior.duplicate(true)
	untrusted["runClock"]["decisionIndex"] = 14
	untrusted["turn"] = 14
	untrusted["tradeRouteLegacyUnverified"] = true
	if flow.settle(prior, untrusted, false, 0, 0):
		return _fail("unverified legacy trade route generated ghost stock")
	print("NONCOMBAT_GHOST_ARRIVAL_FROZEN_PASS stock=true cadence=true replay=true untrusted=true")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
