extends RefCounted

const TradeRouteFlow = preload("res://scripts/noncombat_trade_route_flow.gd")

# Pure port of MarketSystem._generateGhostItems/_buildMarketCard. The caller
# owns the random stream, its receipts and the RunSession commit. Nothing in
# this class opens a vendor or advances the market clock.
const MODULES := ["markets:vendor_profiles", "shops:treasures",
	"world:trade_routes", "world:factions"]
const REALMS := ["qi", "foundation", "golden", "nascent", "deity", "tribulation"]
const TIERS := [
	{"max": 20, "slots": 3, "weights": [0.70, 0.17, 0.10, 0.03, 0.0], "price": 1.5},
	{"max": 40, "slots": 4, "weights": [0.50, 0.30, 0.15, 0.05, 0.0], "price": 1.2},
	{"max": 60, "slots": 5, "weights": [0.35, 0.35, 0.20, 0.10, 0.0], "price": 1.0},
	{"max": 80, "slots": 6, "weights": [0.25, 0.30, 0.25, 0.20, 0.0], "price": 0.9},
	{"max": 1000000, "slots": 7, "weights": [0.15, 0.30, 0.30, 0.25, 0.0], "price": 0.8},
]
const PRICE_RANGES := {1: [4, 7], 2: [7, 11], 3: [11, 17],
	4: [17, 25], 5: [25, 37], 6: [37, 51]}
const RARITY_NAMES := {1: "☆ 灰", 2: "★★ 白", 3: "★★★ 蓝",
	4: "★★★★ 紫", 5: "★★★★★ 金", 6: "★★★★★★ 传说"}
const TYPE_LABELS := {"weapon": "🗡️ 武器", "armor": "🛡️ 防具",
	"accessory": "📿 饰品", "artifact": "🔮 秘宝", "consumable": "📜 消耗",
	"tool": "🔧 法器", "material": "💎 材料", "regen": "💧 回复"}
const FLAVORS := [
	"你路过一座废弃坊市时，感到一阵空间波动——这不是普通的坊市，是鬼市。",
	"雾气中浮现一扇古铜门。门楣上写着\"有缘者入\"——你的福源微微发热。",
	"一阵阴风吹过，路边突然出现了几个摊铺。摊主不露脸，只露手——这是鬼市的规矩。",
	"你听到铃铛声。三声为号——鬼市开了。你正好走在那个时辰、那个地点。",
]
const HIDDEN_ORIGINS := ["封签下有一段被抹去的前主名字。",
	"禁纹在夜气里反复指向一条未标商路。", "器纹里夹着债主留下的半枚收据。"]

var _content: RefCounted
var last_error := ""
var rebirth_archive_verified := false


func _init(content: RefCounted) -> void:
	_content = content


func source_pins() -> Dictionary:
	var pins := {}
	for module_id in MODULES:
		var sha := String(_content.source_sha256(module_id))
		if sha.length() != 64:
			last_error = "鬼市来源缺少 " + module_id
			return {}
		pins[module_id] = sha
	return pins


func generate(state: Dictionary, next_roll: Callable) -> Dictionary:
	last_error = ""
	if not next_roll.is_valid() or not REALMS.has(state.get("realm")):
		last_error = "鬼市境界或随机源无效"
		return {}
	var pins := source_pins()
	var treasure_doc: Variant = _content.read_module("shops:treasures")
	var profile_doc: Variant = _content.read_module("markets:vendor_profiles")
	if pins.is_empty() or not treasure_doc is Dictionary \
			or not treasure_doc.get("treasures") is Array \
			or not profile_doc is Dictionary:
		last_error = "鬼市货源不可用"
		return {}
	var profile := {}
	for row in profile_doc.get("vendors", []):
		if row is Dictionary and row.get("id") == "ghost_market":
			profile = row
	if profile.get("marketType") != "ghost":
		last_error = "鬼市来源档无效"
		return {}
	var route := _active_route(state)
	if route.is_empty():
		return {}
	var fortune := int(state.get("attributes", {}).get("fortune", 0))
	var tier: Dictionary = TIERS.back()
	for value in TIERS:
		if fortune <= int(value["max"]):
			tier = value
			break
	var slots := clampi(int(tier["slots"]) + (1 if int(route["openness"]) >= 70
		else -1 if int(route["openness"]) <= 25 else 0), 2, 8)
	var price_multiplier := float(tier["price"]) * clampf(1.0 + (float(
		route["danger"]) - float(route["prosperity"])) / 250.0, 0.8, 1.25)
	var rarity_bias := 1 if int(route["prosperity"]) >= 70 else (
		-1 if int(route["danger"]) >= 70 else 0)
	var pool := _treasure_pool(state, treasure_doc["treasures"])
	var stock: Array = []
	var used := {}
	var gold_count := 0
	for i in slots:
		if pool.is_empty():
			break
		var rarity_roll := _draw(next_roll)
		if rarity_roll < 0.0:
			return {}
		var rarity := 2
		var cumulative := 0.0
		for weight_index in tier["weights"].size():
			cumulative += float(tier["weights"][weight_index])
			if rarity_roll < cumulative:
				rarity = weight_index + 2
				break
		rarity = clampi(rarity + rarity_bias, 1, 6)
		if rarity >= 5 and gold_count >= 2:
			rarity = 4
		var candidates := _candidates(pool, used, rarity)
		var supplied: Array = candidates.filter(func(item: Variant) -> bool:
			return route.get("supply", []).has(item.get("type")))
		if not supplied.is_empty():
			var supply_roll := _draw(next_roll)
			if supply_roll < 0.0:
				return {}
			if supply_roll < 0.7:
				candidates = supplied
		var downgraded := false
		if candidates.is_empty():
			for lower in range(rarity - 1, 0, -1):
				candidates = _candidates(pool, used, lower)
				if not candidates.is_empty():
					downgraded = true
					break
		if candidates.is_empty():
			continue
		var pick_roll := _draw(next_roll)
		if pick_roll < 0.0:
			return {}
		var picked: Dictionary = candidates[int(floor(pick_roll * candidates.size()))]
		var range_value: Array = PRICE_RANGES.get(int(picked.get("rarity", 2)),
			PRICE_RANGES[2])
		var price_roll := _draw(next_roll)
		if price_roll < 0.0:
			return {}
		var base := int(range_value[0]) + int(floor(price_roll * (
			int(range_value[1]) - int(range_value[0]))))
		var item := picked.duplicate(true)
		item["type"] = "treasure"
		item["treasureType"] = picked.get("type")
		item["effect"] = {"treasureId": picked["id"]}
		item["displayPrice"] = int(floor(base * price_multiplier))
		item["rarityName"] = RARITY_NAMES.get(int(picked.get("rarity", 2)), "★★ 白")
		item["typeLabel"] = TYPE_LABELS.get(picked.get("type"), "📦 杂物")
		item["_marketItem"] = true
		item["tradeRouteId"] = route["id"]
		item["_originalIndex"] = stock.size()
		stock.append(item)
		used[picked["id"]] = true
		if rarity >= 5 and not downgraded:
			gold_count += 1
	stock.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("rarity", 0)) > int(b.get("rarity", 0)) or int(
			a.get("rarity", 0)) == int(b.get("rarity", 0)) and int(
			a["_originalIndex"]) < int(b["_originalIndex"]))
	for item in stock:
		item.erase("_originalIndex")
	# Browser _generateGhostItems takes only the first five sorted ambient goods.
	# The card still reports the pre-slice _slotCount from _generateItems.
	stock.resize(mini(stock.size(), 5))
	var hidden_rate := clampf(float(profile.get("riskRules", {}).get(
		"hiddenTraitRate", 0.30)), 0.25, 0.40)
	var sealed_count := clampi(roundi(stock.size() * hidden_rate),
		1, stock.size()) if not stock.is_empty() else 0
	var sealed := {}
	var sealing_attempts := 0
	while sealed.size() < sealed_count:
		sealing_attempts += 1
		if sealing_attempts > maxi(64, stock.size() * 32):
			last_error = "鬼市封签随机源未产生足够不同货位"
			return {}
		var seal_roll := _draw(next_roll)
		if seal_roll < 0.0:
			return {}
		sealed[int(floor(seal_roll * stock.size()))] = true
	for index in stock.size():
		var markup_roll := _draw(next_roll)
		if markup_roll < 0.0:
			return {}
		var item: Dictionary = stock[index]
		var markup := 1.10 + markup_roll * 0.50
		item["price"] = maxi(1, ceili(maxf(1.0, float(item.get(
			"displayPrice", item.get("price", 1)))) * markup))
		item["displayPrice"] = item["price"]
		item["ghostMarkup"] = markup
		item["hiddenTrait"] = null
		if sealed.has(index):
			var origin_roll := _draw(next_roll)
			if origin_roll < 0.0:
				return {}
			item["hiddenTrait"] = {"status": "sealed",
				"inspection": "需要交出一份商路线索，才能验看此物的来路。",
				"revealedText": HIDDEN_ORIGINS[int(floor(
					origin_roll * HIDDEN_ORIGINS.size()))]}
	var flavor_roll := _draw(next_roll)
	if flavor_roll < 0.0:
		return {}
	var tier_text := _fortune_tier_text(fortune)
	var route_text := "🧭 本次货源：%s（通畅%d / 风险%d）\n%s\n\n" % [
		route["name"], int(route["openness"]), int(route["danger"]), route["flavor"]]
	var card := {"id": "market_encounter", "title": "🏪 鬼市偶遇 — " + tier_text,
		"description": FLAVORS[int(floor(flavor_roll * FLAVORS.size()))] +
			"\n\n" + route_text + "🕯️ 当前福源: %d | 灵石: %d" % [fortune,
				int(state.get("resources", {}).get("spiritStone", 0))],
		"type": "MARKET", "realm": state["realm"], "weight": 0, "once": false,
		"choices": {
			"left": {"text": "进去逛逛", "effects": {}, "action": {
				"type": "ENTER_VENDOR", "vendorId": "ghost_market",
				"marketEncounter": true, "resumePolicy": "ON_VENDOR_CLOSED",
				"settlePolicy": "AFTER_CLOSE_EXACTLY_ONCE"},
				"desc": "踏入鬼市大门。以你%s的运道，可刷出 %d 件商品。" % [
					tier_text, slots]},
			"right": {"text": "绕道而行", "effects": {},
				"desc": "鬼市虽有好货，但也可能沾上不干净的东西。还是赶路要紧。"}}}
	return {"stock": stock, "card": card, "sourcePins": pins,
		"meta": {"route": route, "slotCount": slots,
			"priceMultiplier": price_multiplier, "fortuneTier": tier_text}}


func build_session(plan: Dictionary, session_key: String,
		opened_at_decision_index: int) -> Dictionary:
	last_error = ""
	if session_key.is_empty() or opened_at_decision_index < 0 \
			or not plan.get("stock") is Array or not plan.get("card") is Dictionary \
			or plan.get("card", {}).get("id") != "market_encounter" \
			or plan.get("sourcePins") != source_pins():
		last_error = "鬼市入摊计划或来源无效"
		return {}
	var profiles: Variant = _content.read_module("markets:vendor_profiles")
	if not profiles is Dictionary:
		last_error = "鬼市摊主档不可用"
		return {}
	var profile := {}
	for row in profiles.get("vendors", []):
		if row is Dictionary and row.get("id") == "ghost_market":
			profile = row
	if profile.get("marketType") != "ghost" or not profile.get("contractOffers") is Array:
		last_error = "鬼市契约档无效"
		return {}
	var contracts: Array = profile["contractOffers"]
	var supplied: Array = plan["stock"]
	var offers: Array = []
	for raw in contracts:
		if raw is Dictionary:
			offers.append(raw.duplicate(true))
	for raw in supplied:
		if not raw is Dictionary:
			last_error = "鬼市商品记录无效"
			return {}
		var is_contract := false
		for contract in contracts:
			if contract is Dictionary and contract.get("id") == raw.get("id"):
				is_contract = true
				break
		if not is_contract:
			offers.append(raw.duplicate(true))
	var normalized: Array = []
	for raw in offers:
		var offer: Dictionary = raw.duplicate(true)
		offer["provenance"] = "ghost_market"
		var authored: Array = offer.get("costSpec", []) if offer.get("costSpec") is Array else []
		var stone := 0.0
		var lifespan := 0.0
		var other_costs: Array = []
		for cost in authored:
			if not cost is Dictionary or cost.get("kind") != "resource" \
					or not cost.get("key") in ["spiritStone", "lifespan"]:
				other_costs.append(cost)
			elif cost.get("key") == "spiritStone":
				stone += maxf(0.0, float(cost.get("amount", 0)))
			else:
				lifespan += maxf(0.0, float(cost.get("amount", 0)))
		if stone <= 0.0:
			stone = maxf(0.0, float(offer.get("displayPrice",
				offer.get("price", 0))))
		lifespan = maxf(maxf(1.0, float(profile.get("riskRules", {}).get(
			"lifespanCost", 3))), lifespan)
		offer["costSpec"] = other_costs.duplicate(true) + [
			{"kind": "resource", "key": "spiritStone", "amount": _number(stone)},
			{"kind": "resource", "key": "lifespan", "amount": _number(lifespan)}]
		normalized.append(offer)
	var budget := maxi(0, int(profile.get("interactionBudget", 0)))
	return {"version": 2, "status": "open", "sessionId": session_key,
		"sessionKey": session_key, "vendorId": "ghost_market", "marketType": "ghost",
		"entryCardId": "market_encounter",
		"openedAtDecisionIndex": opened_at_decision_index, "offerRevision": 1,
		"immutableOffers": normalized, "actionReceipts": {},
		"interactionBudget": {"limit": budget, "remaining": budget},
		"stalls": profile.get("stalls", []).duplicate(true),
		"services": profile.get("services", []).duplicate(true),
		"riskRules": profile.get("riskRules", {}).duplicate(true),
		"debt": profile.get("debt", {}).duplicate(true),
		"presentationProfile": profile.get("presentationProfile", {}).duplicate(true),
		"exitContract": profile.get("exitContract", ""),
		"summary": {"openingOfferCount": normalized.size(), "purchaseCount": 0,
			"spiritStoneSpent": 0, "purchasedItems": [], "exchangedItems": []}}


func _number(value: float) -> Variant:
	return int(value) if value == floorf(value) else value


func _draw(next_roll: Callable) -> float:
	var value: Variant = next_roll.call()
	if not (value is float or value is int) or float(value) < 0.0 \
			or float(value) >= 1.0:
		last_error = "鬼市抽签无效"
		return -1.0
	return float(value)


func _candidates(pool: Array, used: Dictionary, rarity: int) -> Array:
	return pool.filter(func(item: Variant) -> bool:
		return int(item.get("rarity", -1)) == rarity and not used.has(item.get("id")))


func _treasure_pool(state: Dictionary, definitions: Array) -> Array:
	var owned := {}
	for id in state.get("resources", {}).get("treasures", []):
		if id is String:
			owned[id] = true
	for value in state.get("treasureInstances", {}).values():
		if value is Dictionary:
			owned[String(value.get("definitionId", ""))] = true
	var maximum := REALMS.find(state.get("realm"))
	var pool: Array = []
	for value in definitions:
		if value is Dictionary and value.get("storyOnly") != true \
				and not owned.has(value.get("id")) \
				and REALMS.find(value.get("realm")) >= 0 \
				and REALMS.find(value.get("realm")) <= maximum:
			pool.append(value)
	return pool


func _fortune_tier_text(fortune: int) -> String:
	if fortune <= 20: return "厄运缠身"
	if fortune <= 40: return "时运平平"
	if fortune <= 60: return "福运小成"
	if fortune <= 80: return "天运亨通"
	return "天命所归"


func _active_route(state: Dictionary) -> Dictionary:
	var routes_doc: Variant = _content.read_module("world:trade_routes")
	var factions_doc: Variant = _content.read_module("world:factions")
	if not routes_doc is Dictionary or not factions_doc is Dictionary:
		last_error = "商路来源不可用"
		return {}
	var saved_routes: Dictionary = state.get("tradeRouteState", {}) if \
		state.get("tradeRouteState") is Dictionary else {}
	# Earlier Godot second-life saves labelled the fresh life-1 route as an
	# unverified legacy prefix. The domain may authorize it only after replaying
	# the archived death and every new-life choice from source.
	var archived_new_life: bool = rebirth_archive_verified \
		and int(state.get("lifeCount", 0)) > 0 \
		and int(state.get("tradeRouteActivationIndex", -1)) == 1 \
		and state.get("tradeRouteLegacyUnverified") == true
	var authoritative: bool = TradeRouteFlow.new(_content).snapshot_valid(
		state, not archived_new_life)
	if (state.has("tradeRouteVersion") or not saved_routes.is_empty()) \
			and not authoritative:
		last_error = "鬼市商路快照未通过严格来源校验"
		return {}
	var progress: Variant = state.get("factionProgress")
	if progress is Dictionary:
		var starts := {}
		for faction in factions_doc.get("factions", []):
			starts[faction.get("id")] = int(faction.get("startReputation", 0))
			for sub in faction.get("subfactions", []):
				starts[sub.get("id")] = int(sub.get("startReputation", 0))
		for id in progress.get("reputations", {}):
			if not starts.has(id) or int(progress["reputations"][id]) != starts[id]:
				if not authoritative:
					last_error = "商路声望变化尚无来源回放"
					return {}
		for id in progress.get("undercurrentStages", {}):
			if int(progress["undercurrentStages"][id]) != int(
					factions_doc.get("undercurrents", {}).get(id, {}).get("stage", 0)):
				if not authoritative:
					last_error = "商路暗流变化尚无来源回放"
					return {}
	var location := String(state.get("currentLocation", ""))
	var all_routes: Array = routes_doc.get("routes", [])
	var candidates: Array = all_routes.filter(func(route: Variant) -> bool:
		return route is Dictionary and (route.get("from") == location \
			or route.get("to") == location or location == "坊市"))
	if candidates.is_empty(): candidates = all_routes
	var best := {}
	var best_score := -999999.0
	for route in candidates:
		if not route is Dictionary:
			continue
		var initial: Dictionary = route.get("initial", {})
		var saved: Dictionary = saved_routes.get("routes", {}).get(route.get("id"), {})
		var openness := float(saved.get("openness", initial.get("openness", 50)))
		var danger := float(saved.get("danger", initial.get("danger", 30)))
		var prosperity := float(saved.get("prosperity", initial.get("prosperity", 50)))
		var score := openness + prosperity - danger
		if score > best_score:
			best_score = score
			best = {"id": route.get("id"), "name": route.get("name"),
				"from": route.get("from"), "to": route.get("to"),
				"openness": openness, "danger": danger,
				"prosperity": prosperity,
				"shipments": int(saved.get("shipments", 0)),
				"flavor": route.get("flavor", ""), "supply": route.get("supply", []),
				"undercurrents": route.get("undercurrents", []),
				"lastChange": saved.get("history", []).back() if not saved.get(
					"history", []).is_empty() else null}
	if best.is_empty():
		last_error = "商路档案无可用路线"
	return best
