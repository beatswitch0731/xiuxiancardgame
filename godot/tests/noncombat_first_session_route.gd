extends SceneTree

const Repository = preload("res://scripts/noncombat_content_repository.gd")
const ROUTE_SCRIPT := "res://scripts/noncombat_first_session_route.gd"

class BrokenArtRepository extends "res://scripts/noncombat_content_repository.gd":
	var missing := false
	var broken := true

	func asset_status(path: String) -> Dictionary:
		var result: Dictionary = super.asset_status(path)
		if broken:
			result["shaVerified"] = false
			if missing:
				result["fileExists"] = false
		return result

class BrokenModuleRepository extends "res://scripts/noncombat_content_repository.gd":
	var missing := false

	func source_sha256(module_id: String) -> String:
		return "" if module_id == "cards:qi" else super.source_sha256(module_id)

	func module_path(module_id: String) -> String:
		return "data/cards/route_missing_source_test.json" if missing and module_id == "cards:qi" \
			else super.module_path(module_id)

class PreparedRepository extends "res://scripts/noncombat_content_repository.gd":
	func read_module(module_id: String) -> Variant:
		var document: Variant = super.read_module(module_id)
		if module_id == "cards:qi" and document is Dictionary:
			for raw in document.get("cards", []):
				if raw.get("id") == "q_mountain_shadow_approach":
					raw["choices"]["right"]["promise"] = {"id": "stale"}
					raw["choices"]["right"]["narrativeBlock"] = "stale"
		return document


func _initialize() -> void:
	if not FileAccess.file_exists(ROUTE_SCRIPT):
		return _fail("first-session route projection is missing")
	var script: Script = load(ROUTE_SCRIPT)
	if script == null or not script.can_instantiate():
		return _fail("first-session route script cannot instantiate")
	var content := Repository.new()
	var route: RefCounted = script.new(content)
	var manifest: Dictionary = content.read_module("progression:first_session_cohesion")
	var mountain_id: String = manifest["beats"]["route"]["cardId"]
	var market_id: String = manifest["beats"]["firstVendor"]["entryCardId"]
	var raw_mountain := _source_card(content.read_module("cards:qi"), mountain_id)
	var raw_market := _source_card(content.read_module("locations:locations"), market_id)
	for path_id in manifest["paths"]:
		var prior := _state(path_id)
		var original := prior.duplicate(true)
		var lens: Dictionary = manifest["routeLenses"][path_id]
		var card: Dictionary = route.card(prior, mountain_id)
		if card.get("description") != lens["description"] \
				or card.get("sceneImage") != raw_mountain["sceneImage"] \
				or card.get("tags") != raw_mountain["tags"]:
			return _fail("route source/lens presentation differs: " + path_id)
		for direction in ["left", "right"]:
			for key in lens["choices"][direction]:
				if card["choices"][direction].get(key) != lens["choices"][direction][key]:
					return _fail("authored route choice field lost: " + key)
		if card["choices"]["left"].get("combatEncounterId") != \
				raw_mountain["choices"]["left"]["combatEncounterId"] \
				or card["choices"]["right"].has("promise"):
			return _fail("route combat metadata or serial promise differs")
		for outcome in ["victory", "defeat", "flee"]:
			var presentation: Dictionary = card["choices"]["left"]["combatOutcomePresentation"][outcome]
			if presentation.get("title") != lens["outcomes"][outcome]["title"] \
					or presentation.get("description") != lens["outcomes"][outcome]["description"] \
					or presentation.get("sceneImage") != raw_mountain["sceneImage"]:
				return _fail("combat outcome route lens differs: " + outcome)
		var entered: Dictionary = route.enter(prior, mountain_id)
		if entered.get("phase") != "FIRST_SESSION_ROUTE_PENDING" \
				or entered.get("currentLocation") != raw_mountain["location"] \
				or not entered.get("visitedLocations", []).has(raw_mountain["location"]) \
				or entered.get("locationStates") != prior["locationStates"] \
				or entered.get("runClock") != prior["runClock"] \
				or entered.get("choiceHistory") != prior["choiceHistory"]:
			return _fail("arrival charged a decision/visit or lost source location")
		if route.card(entered) != card or route.enter(entered, mountain_id) != entered:
			return _fail("route reload or repeated arrival changed the snapshot")
		var market: Dictionary = route.settle_right(entered)
		if market.get("currentCardId") != market_id \
				or market.get("phase") != "FIRST_SESSION_ROUTE_PENDING" \
				or market.get("currentLocation") != raw_market["location"] \
				or market.get("locationStates") != prior["locationStates"] \
				or route.card(market) != raw_market:
			return _fail("serial right choice failed to deliver source market")
		if not _choice_is_exact(market, raw_mountain, 1) \
				or market["karmaSeeds"][0]["delay"] != 2 \
				or market["pendingKarmaSeeds"] != market["karmaSeeds"]:
			return _fail("route choice history/receipt/seed clock differs")
		var response: Dictionary = route.settle_right(market)
		var result: Dictionary = response.get("pendingNarrativeResult", {})
		# Oracle from the unmodified browser ChoiceOutcomeRouter._buildPromise
		# for the authored market card, right choice and first life.
		if response.get("phase") != "NARRATIVE_RESULT_PENDING" \
				or result.get("promiseId") != "promise:ed3dd3ad" \
				or result.get("id") != "promise_result_7a4e4ea2" \
				or result.get("description") != raw_market["choices"]["right"]["narrativeBlock"] \
				or result.get("originCardId") != market_id \
				or result.get("originChoice") != "right" \
				or response.get("currentCardId") != result.get("id") \
				or result != response.get("noncombatFlow", {}).get("pendingResultCard") \
				or not _choice_is_exact(response, raw_market, 2) \
				or response["karmaSeeds"][0]["delay"] != 1:
			return _fail("market right choice lost its authored result or charged incorrectly")
		if not route.settle_right(response).is_empty() or prior != original:
			return _fail("settlement repeated or mutated the caller snapshot")
		var stale := entered.duplicate(true)
		stale["noncombatFlow"]["firstSessionRouteSourceHashes"]["cards:qi"] = "changed"
		if not route.settle_right(stale).is_empty():
			return _fail("stale route provenance settled")
		var duplicate := entered.duplicate(true)
		var key := "decision:%s:choice:%s:6" % [duplicate["runClock"]["lifeId"], mountain_id]
		duplicate["runClock"]["receipts"][key] = {"token": key}
		if not route.settle_right(duplicate).is_empty():
			return _fail("duplicate decision receipt settled")
	var bounded := _state("sword")
	for index in range(30):
		bounded["choiceHistory"].append({"cardId": "prior_%d" % index})
	bounded["replayHistory"] = bounded["choiceHistory"].duplicate(true)
	for index in range(20):
		bounded["recentCardTags"].append("prior_%d" % index)
	var bounded_result: Dictionary = route.settle_right(route.enter(bounded, mountain_id))
	if bounded_result.get("choiceHistory", []).size() != 30 \
			or bounded_result.get("replayHistory", []).size() != 31 \
			or bounded_result["choiceHistory"][0]["cardId"] != "prior_1" \
			or bounded_result.get("recentCardTags", []).size() != 20:
		return _fail("bounded display history/tags lost the complete replay journal")
	var prepared: RefCounted = script.new(PreparedRepository.new())
	var prepared_card: Dictionary = prepared.card(_state("sword"), mountain_id)
	if prepared_card["choices"]["right"].has("promise") \
			or prepared_card["choices"]["right"].get("narrativeBlock") != null:
		return _fail("prepared base card retained a superseded generic promise")
	var broken: RefCounted = script.new(BrokenArtRepository.new())
	if not broken.card(_state("sword"), mountain_id).is_empty() \
			or not broken.enter(_state("sword"), market_id).is_empty() \
			or not route.card(_state("sword"), "q_gathering").is_empty():
		return _fail("unverified scene art or unsupported card entered route flow")
	if broken.get("source_error") != "SOURCE_MISMATCH" or broken.last_error.is_empty():
		return _fail("route asset mismatch was not propagated for failed entry")
	for missing in [false, true]:
		var asset_repository := BrokenArtRepository.new()
		asset_repository.missing = missing
		var asset_route: RefCounted = script.new(asset_repository)
		var expected := "SOURCE_UNAVAILABLE" if missing else "SOURCE_MISMATCH"
		if not asset_route.enter(_state("sword"), mountain_id).is_empty() \
				or asset_route.get("source_error") != expected or asset_route.last_error.is_empty():
			return _fail("failed route entry lost source asset status: " + expected)
		asset_repository.broken = false
		if asset_route.enter(_state("sword"), mountain_id).is_empty() \
				or asset_route.get("source_error") != "" or asset_route.last_error != "":
			return _fail("repaired route entry retained an old source error")
		var module_repository := BrokenModuleRepository.new()
		module_repository.missing = missing
		var module_route: RefCounted = script.new(module_repository)
		if not module_route.source_hashes().is_empty() \
				or module_route.get("source_error") != expected or module_route.last_error.is_empty():
			return _fail("route module failure lost availability/hash distinction: " + expected)
	print("NONCOMBAT_FIRST_SESSION_ROUTE_PASS paths=4 outcomes=12 serial=true narrative=true provenance=true")
	quit(0)


func _source_card(document: Dictionary, card_id: String) -> Dictionary:
	for raw in document["cards"]:
		if raw["id"] == card_id:
			return raw
	return {}


func _state(path_id: String) -> Dictionary:
	return {"realm": "qi", "path": path_id, "phase": "FLOW_PENDING", "turn": 5,
		"lifeCount": 0, "currentCardId": "", "currentLocation": "宗门",
		"visitedLocations": ["宗门"], "locationStates": {"宗门": {"visits": 3}},
		"runClock": {"lifeId": "route:life:0", "decisionIndex": 5, "receipts": {}},
		"choiceHistory": [], "replayHistory": [], "recentCardTags": [], "cardsPlayed": [],
		"karmaSeeds": [{"id": "route_seed", "delay": 3}], "pendingKarmaSeeds": [],
		"noncombatFlow": {"version": 1, "scope": "first_session_combat", "karmaClockVersion": 1}}


func _choice_is_exact(state: Dictionary, source: Dictionary, count: int) -> bool:
	var decision := 5 + count
	var key := "decision:route:life:0:choice:%s:%d" % [source["id"], decision]
	var expected := {"cardId": source["id"], "cardType": source["type"],
		"direction": "right", "turn": decision - 1, "decisionIndex": decision,
		"tags": source["tags"]}
	return state["turn"] == decision and state["runClock"]["decisionIndex"] == decision \
		and state["choiceHistory"].size() == count and state["choiceHistory"].back() == expected \
		and state["replayHistory"] == state["choiceHistory"] \
		and state["cardsPlayed"].back() == source["id"] \
		and state["recentCardTags"].slice(-source["tags"].size()) == source["tags"] \
		and state["runClock"]["receipts"].get(key) == {"token": key,
			"decisionIndex": decision, "sourceCardId": source["id"], "kind": "choice"}


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
