extends RefCounted

# Browser authority: TradeRouteSystem.loadData/_onReputation/
# _onUndercurrent/_change/exportState. Only emitted source events may move a
# route; a final faction total cannot reconstruct the order of changes.
const SOURCE_JS_SHA := "527aa8454e339fa0a67fe4f4f9d6030494616a8647943bd31defe7b39418bf3e"
const ROUTES_MODULE := "world:trade_routes"
const FACTIONS_MODULE := "world:factions"

var activation_index := 0
var legacy_initial_trusted := false
var last_error := ""
var _content: RefCounted


func _init(content: RefCounted) -> void:
	_content = content


func source_pins() -> Dictionary:
	var route_sha := String(_content.source_sha256(ROUTES_MODULE))
	var faction_sha := String(_content.source_sha256(FACTIONS_MODULE))
	if route_sha.length() != 64 or faction_sha.length() != 64:
		last_error = "商路来源指纹不可用"
		return {}
	return {ROUTES_MODULE: route_sha, FACTIONS_MODULE: faction_sha}


func initial_state() -> Dictionary:
	var doc: Variant = _content.read_module(ROUTES_MODULE)
	if not doc is Dictionary or not doc.get("routes") is Array:
		last_error = "商路来源配置不可用"
		return {}
	var routes := {}
	for row in doc["routes"]:
		if not row is Dictionary or not row.get("id") is String \
				or String(row["id"]).is_empty() or routes.has(row["id"]):
			last_error = "商路来源路线无效"
			return {}
		var initial: Dictionary = row.get("initial", {})
		routes[row["id"]] = {"openness": int(initial.get("openness", 50)),
			"danger": int(initial.get("danger", 30)),
			"prosperity": int(initial.get("prosperity", 50)),
			"shipments": 0, "history": []}
	return {"version": 1, "routes": routes}


func snapshot_valid(state: Dictionary, require_trusted: bool = true) -> bool:
	var pins := source_pins()
	if pins.is_empty() or state.get("tradeRouteVersion") != 1 \
			or state.get("tradeRouteSourcePins") != pins \
			or state.get("tradeRouteRuleSourceSha") != SOURCE_JS_SHA \
			or not (state.get("tradeRouteActivationIndex") is int \
				or state.get("tradeRouteActivationIndex") is float) \
			or int(state.get("tradeRouteActivationIndex", -1)) < 0 \
			or not state.get("tradeRouteLegacyUnverified") is bool \
			or require_trusted and state["tradeRouteLegacyUnverified"]:
		return false
	var snapshot: Variant = state.get("tradeRouteState")
	if not snapshot is Dictionary or snapshot.get("version") != 1 \
			or not snapshot.get("routes") is Dictionary:
		return false
	var doc: Variant = _content.read_module(ROUTES_MODULE)
	if not doc is Dictionary or not doc.get("routes") is Array \
			or snapshot["routes"].size() != doc["routes"].size():
		return false
	for definition in doc["routes"]:
		var route: Variant = snapshot["routes"].get(definition.get("id"))
		if not route is Dictionary or not route.get("history") is Array \
				or route["history"].size() > 8:
			return false
		for key in ["openness", "danger", "prosperity"]:
			if not (route.get(key) is int or route.get(key) is float) \
					or float(route[key]) < 0.0 or float(route[key]) > 100.0:
				return false
		if not (route.get("shipments") is int or route.get("shipments") is float) \
				or int(route["shipments"]) < 0:
			return false
	return true


func legacy_prefix_trusted(saved: Dictionary) -> bool:
	# Decisions 0–5 are the four tutorials and the authored path opener. The
	# first battle result or ambient market can only follow that boundary.
	var index := int(saved.get("runClock", {}).get("decisionIndex", -1))
	if index < 0 or index > 5 or not String(saved.get("runClock", {}).get(
			"lifeId", "")).ends_with(":life:0") \
			or not saved.get("marketPurchaseHistory", []).is_empty():
		return false
	var progress: Variant = saved.get("factionProgress")
	if progress == null:
		return true
	if not progress is Dictionary:
		return false
	var doc: Variant = _content.read_module(FACTIONS_MODULE)
	if not doc is Dictionary:
		return false
	var starts := {}
	for faction in doc.get("factions", []):
		starts[faction["id"]] = int(faction.get("startReputation", 0))
		for sub in faction.get("subfactions", []):
			starts[sub["id"]] = int(sub.get("startReputation", 0))
	for id in progress.get("reputations", {}):
		if not starts.has(id) or int(progress["reputations"][id]) != starts[id]:
			return false
	for id in progress.get("undercurrentStages", {}):
		if not doc.get("undercurrents", {}).has(id) or int(
			progress["undercurrentStages"][id]) != int(doc[
				"undercurrents"][id].get("stage", 0)):
			return false
	return true


func settle(prior: Dictionary, candidate: Dictionary) -> bool:
	last_error = ""
	var index := int(candidate.get("runClock", {}).get("decisionIndex", -1))
	if index < 0 or activation_index < 0:
		last_error = "商路激活时钟无效"
		return false
	var pending: Variant = candidate.get("tradeRoutePendingEvents", [])
	if not pending is Array:
		last_error = "商路事件队列损坏"
		return false
	if index < activation_index:
		candidate.erase("tradeRoutePendingEvents")
		return true
	var pins := source_pins()
	if pins.is_empty():
		return false
	if not prior.has("tradeRouteVersion"):
		if candidate.has("tradeRouteVersion") or candidate.has("tradeRouteState"):
			last_error = "商路未授权预置快照"
			return false
		var fresh := initial_state()
		if fresh.is_empty():
			return false
		candidate["tradeRouteVersion"] = 1
		candidate["tradeRouteActivationIndex"] = activation_index
		candidate["tradeRouteSourcePins"] = pins
		candidate["tradeRouteRuleSourceSha"] = SOURCE_JS_SHA
		candidate["tradeRouteLegacyUnverified"] = activation_index > 0 \
			and not legacy_initial_trusted
		candidate["tradeRouteState"] = fresh
	else:
		if not snapshot_valid(prior, false) \
				or prior.get("tradeRouteActivationIndex") != activation_index \
				or prior.get("tradeRouteSourcePins") != pins \
				or prior.get("tradeRouteRuleSourceSha") != SOURCE_JS_SHA \
				or not prior.get("tradeRouteState") is Dictionary \
				or candidate.get("tradeRouteState") != prior.get("tradeRouteState") \
				or candidate.get("tradeRouteSourcePins") != pins \
				or candidate.get("tradeRouteRuleSourceSha") != SOURCE_JS_SHA \
				or candidate.get("tradeRouteActivationIndex") != activation_index \
				or candidate.get("tradeRouteLegacyUnverified") != \
					prior.get("tradeRouteLegacyUnverified"):
			last_error = "商路快照或来源指纹不符"
			return false
	var faction_doc: Variant = _content.read_module(FACTIONS_MODULE)
	var route_doc: Variant = _content.read_module(ROUTES_MODULE)
	if not faction_doc is Dictionary or not route_doc is Dictionary:
		last_error = "商路事件来源不可用"
		return false
	var expected_reputations := {}
	for faction in faction_doc.get("factions", []):
		expected_reputations[faction["id"]] = int(faction.get("startReputation", 0))
		for sub in faction.get("subfactions", []):
			expected_reputations[sub["id"]] = int(sub.get("startReputation", 0))
	var expected_stages := {}
	for id in faction_doc.get("undercurrents", {}):
		expected_stages[id] = int(faction_doc["undercurrents"][id].get("stage", 0))
	var previous_progress: Variant = prior.get("factionProgress")
	if previous_progress is Dictionary:
		for id in previous_progress.get("reputations", {}):
			if not expected_reputations.has(id):
				last_error = "商路上游声望 ID 无效"
				return false
			expected_reputations[id] = int(previous_progress["reputations"][id])
		for id in previous_progress.get("undercurrentStages", {}):
			if not expected_stages.has(id):
				last_error = "商路上游暗流 ID 无效"
				return false
			expected_stages[id] = int(previous_progress["undercurrentStages"][id])
	var routes: Dictionary = candidate["tradeRouteState"]["routes"]
	for value in pending:
		if not value is Dictionary:
			last_error = "商路事件条目无效"
			return false
		var event: Dictionary = value
		match event.get("kind"):
			"reputation":
				var faction_id := String(event.get("factionId", ""))
				var old := int(event.get("oldValue", -999))
				var next := int(event.get("newValue", -999))
				if not expected_reputations.has(faction_id) \
						or old != int(expected_reputations[faction_id]) \
						or next == old or next < -100 or next > 100:
					last_error = "商路声望事件与上游不符"
					return false
				expected_reputations[faction_id] = next
				var sign_value := signi(next - old)
				for route in route_doc["routes"]:
					if route.get("factions", []).has(faction_id):
						_change(routes[route["id"]], {"openness": sign_value * 2,
							"prosperity": sign_value}, "势力声望变化",
							int(prior.get("turn", 0)))
			"undercurrent":
				var undercurrent_id := String(event.get("undercurrentId", ""))
				var old_stage := int(event.get("oldStage", -999))
				var next_stage := int(event.get("newStage", -999))
				var source: Dictionary = faction_doc.get("undercurrents", {}).get(
					undercurrent_id, {})
				if source.is_empty() or old_stage != int(expected_stages.get(
					undercurrent_id, -998)) or next_stage < 0 \
						or next_stage > int(source.get("maxStage", 5)):
					last_error = "商路暗流事件与上游不符"
					return false
				expected_stages[undercurrent_id] = next_stage
				for route in route_doc["routes"]:
					if route.get("undercurrents", []).has(undercurrent_id):
						_change(routes[route["id"]], {"danger": 2,
							"openness": -1}, String(source.get("name", "势力暗流")) +
							"推进", int(prior.get("turn", 0)))
			_:
				last_error = "商路事件类型尚未迁移"
				return false
	var actual: Variant = candidate.get("factionProgress")
	if actual is Dictionary:
		if not actual.get("reputations") is Dictionary \
				or not actual.get("undercurrentStages") is Dictionary:
			last_error = "商路势力快照损坏"
			return false
		for id in actual["reputations"]:
			if not expected_reputations.has(id) \
					or int(actual["reputations"][id]) != int(expected_reputations[id]):
				last_error = "商路声望有未登记变化"
				return false
		for id in actual["undercurrentStages"]:
			if not expected_stages.has(id) \
					or int(actual["undercurrentStages"][id]) != int(expected_stages[id]):
				last_error = "商路暗流有未登记变化"
				return false
	elif not pending.is_empty():
		last_error = "商路事件缺少势力快照"
		return false
	candidate.erase("tradeRoutePendingEvents")
	return true


func _change(route: Dictionary, delta: Dictionary, cause: String, turn: int) -> void:
	for key in delta:
		route[key] = clampi(int(route[key]) + int(delta[key]), 0, 100)
	route["history"].append({"turn": turn, "cause": cause, "delta": delta})
	while route["history"].size() > 8:
		route["history"].pop_front()
