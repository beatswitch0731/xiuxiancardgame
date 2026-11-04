extends RefCounted

const TradeRouteFlow = preload("res://scripts/noncombat_trade_route_flow.gd")
const PathSkillFlow = preload("res://scripts/noncombat_path_skill_flow.gd")

# CardSystem._buildShopCard and ShopSystem.getAvailableItems.
# The caller owns the RNG and records every draw; this class only derives
# the source stock and never changes a persisted run or a source document.
const CARD_ID := "shop_encounter"
const REALM_ORDER := ["qi", "foundation", "golden", "nascent", "deity", "tribulation"]
const TRADE_ROUTE_JS_SHA := "527aa8454e339fa0a67fe4f4f9d6030494616a8647943bd31defe7b39418bf3e"
const MODULES := ["shops:shop_items", "shops:treasures",
	"combat:deck_progression", "cards:battle_cards",
	"world:trade_routes", "world:factions"]

var _content: RefCounted
var last_error := ""

func _init(content: RefCounted) -> void:
	_content = content

func source_pins() -> Dictionary:
	var pins := {}
	for module_id in MODULES:
		var sha := String(_content.source_sha256(module_id))
		if sha.length() != 64:
			return {}
		pins[module_id] = sha
	return pins

func card(state: Dictionary) -> Dictionary:
	last_error = ""
	var realm := String(state.get("realm", ""))
	if not REALM_ORDER.has(realm) or source_pins().is_empty():
		last_error = "官坊来源或境界尚未接通"
		return {}
	return {"id": CARD_ID, "title": "官坊 · 万宝楼明码",
		"description": "朱砂官印压住价签，万宝楼的执事在柜后核验来历。这里可以买到明码货，也能把合规旧物交回回购台。",
		"type": "SHOP", "realm": realm, "weight": 0, "once": false,
		"choices": {
			"left": {"text": "不入楼，继续赶路", "effects": {},
				"desc": "专心修行，不被俗物分心。"},
			"right": {"text": "入楼核价", "effects": {},
				"action": {"type": "ENTER_VENDOR", "vendorId": "regulated_market",
					"resumePolicy": "ON_VENDOR_CLOSED",
					"settlePolicy": "AFTER_CLOSE_EXACTLY_ONCE"},
				"desc": "进入万宝楼，核对明码与回购范围。（你有 %d 灵石）" % int(
					state.get("resources", {}).get("spiritStone", 0))}}}

func generate(state: Dictionary, next_roll: Callable,
		previous_pill_prices: Dictionary = {}) -> Array:
	last_error = ""
	if state.get("realm") != "qi" or not next_roll.is_valid():
		last_error = "官坊只审过炼气境界"
		return []
	var item_doc: Variant = _content.read_module("shops:shop_items")
	var treasure_doc: Variant = _content.read_module("shops:treasures")
	var deck_doc: Variant = _content.read_module("combat:deck_progression")
	var card_doc: Variant = _content.read_module("cards:battle_cards")
	var price_multiplier := _price_multiplier(state)
	if not item_doc is Dictionary or not treasure_doc is Dictionary \
			or not deck_doc is Dictionary or not card_doc is Dictionary \
			or source_pins().is_empty() or price_multiplier <= 0.0:
		last_error = "官坊货单来源不可用"
		return []
	var items: Array = item_doc.get("items", [])
	var treasures: Array = treasure_doc.get("treasures", [])
	var result: Array = []
	var foundation := _item(items, "shop_pill_foundation")
	if foundation.is_empty():
		last_error = "保底筑基丹丢失"
		return []
	result.append(foundation)
	var restore: Array = []
	var gifts: Array = []
	for raw in items:
		if not raw is Dictionary or raw.get("realm") != "qi":
			continue
		if raw.get("type") == "pill" and raw.get("name") in ["回春丹", "清心丹"]:
			restore.append(raw)
		if raw.get("type") in ["gift", "material"]:
			gifts.append(raw)
	if restore.is_empty() or treasures.is_empty() or gifts.is_empty():
		last_error = "官坊来源槽缺失"
		return []
	var draw := _roll(next_roll)
	if draw < 0.0:
		return []
	result.append(restore[int(floor(draw * restore.size()))].duplicate(true))
	var qi_treasures: Array = []
	for raw in treasures:
		if raw is Dictionary and raw.get("storyOnly") != true and raw.get("realm", "qi") == "qi":
			qi_treasures.append(raw)
	if qi_treasures.is_empty():
		last_error = "炼气法宝池为空"
		return []
	# Browser spends a rarity roll even when qi is the only eligible realm.
	if _roll(next_roll) < 0.0:
		return []
	draw = _roll(next_roll)
	if draw < 0.0:
		return []
	var treasure: Dictionary = qi_treasures[int(floor(draw * qi_treasures.size()))]
	result.append({"id": "shop_treasure_dyn_" + String(treasure["id"]),
		"name": treasure.get("name"), "type": "treasure",
		"price": treasure.get("price", 15), "realm": treasure.get("realm", "qi"),
		"desc": treasure.get("desc", ""), "effect": {"treasureId": treasure["id"]}})
	var path_offer := _path_offer(state, deck_doc, card_doc)
	if not path_offer.is_empty():
		result.append(path_offer)
	draw = _roll(next_roll)
	if draw < 0.0:
		return []
	result.append(gifts[int(floor(draw * gifts.size()))].duplicate(true))
	draw = _roll(next_roll)
	if draw < 0.0:
		return []
	if draw < 0.35 + float(state.get("attributes", {}).get("fortune", 0)) * 0.03:
		var box_roll := _roll(next_roll)
		if box_roll < 0.0:
			return []
		var box := box_roll < 0.5
		result.append({"id": "shop_treasure_box" if box else "shop_treasure_mysterious",
			"name": "天机宝匣" if box else "神秘古玩", "type": "treasure",
			"price": 25 if box else 15, "realm": "qi",
			"desc": "由天机锁封印的神秘古匣，隐约透出太古灵气。价格不高不低。开启需消耗道心与福缘破解天机！" if box else \
				"地摊上淘来的蒙尘古物，价格不高不低。买下鉴宝，全看主角机缘（Fortune）气运！",
			"effect": {"_identifyTreasure": "box" if box else "antique"}})
	for raw in result:
		var item: Dictionary = raw
		var base := int(previous_pill_prices.get(item.get("id"), item.get("price", 15))) \
			if item.get("type") == "pill" else int(item.get("price", 15))
		item["price"] = maxi(1, int(floor(base * price_multiplier)))
	return result


func generate_for_realm(state: Dictionary, next_roll: Callable,
		previous_pill_prices: Dictionary = {}) -> Array:
	last_error = ""
	var realm := String(state.get("realm", ""))
	var realm_index := REALM_ORDER.find(realm)
	if realm_index < 0 or not next_roll.is_valid():
		last_error = "官坊境界或抽签无效"
		return []
	if realm == "qi":
		return generate(state, next_roll, previous_pill_prices)
	var item_doc: Variant = _content.read_module("shops:shop_items")
	var treasure_doc: Variant = _content.read_module("shops:treasures")
	var deck_doc: Variant = _content.read_module("combat:deck_progression")
	var card_doc: Variant = _content.read_module("cards:battle_cards")
	var realms_doc: Variant = _content.read_module("config:realms")
	var price_multiplier := _price_multiplier(state)
	var pill_discount := _high_realm_pill_discount(state)
	if not item_doc is Dictionary or not treasure_doc is Dictionary \
			or not deck_doc is Dictionary or not card_doc is Dictionary \
			or not realms_doc is Dictionary or realms_doc.get("order") != REALM_ORDER \
			or source_pins().is_empty() or price_multiplier <= 0.0 \
			or pill_discount <= 0.0:
		last_error = "官坊高境界货单来源不可用"
		return []
	var items: Array = item_doc.get("items", [])
	var all_treasures: Array = []
	for raw in treasure_doc.get("treasures", []):
		if raw is Dictionary and raw.get("storyOnly") != true \
				and REALM_ORDER.find(String(raw.get("realm", "qi"))) >= 0 \
				and REALM_ORDER.find(String(raw.get("realm", "qi"))) <= realm_index:
			all_treasures.append(raw)
	var restore: Array = []
	var gifts: Array = []
	for raw in items:
		if not raw is Dictionary:
			continue
		var item_realm := REALM_ORDER.find(String(raw.get("realm", "")))
		if item_realm < 0 or item_realm > realm_index:
			continue
		if raw.get("type") == "pill" and raw.get("name") in ["回春丹", "清心丹"]:
			restore.append(raw)
		if raw.get("type") in ["gift", "material"]:
			gifts.append(raw)
	if restore.is_empty() or all_treasures.is_empty() or gifts.is_empty():
		last_error = "官坊高境界商品槽缺失"
		return []
	var result: Array = []
	var breakthrough_ids := {"foundation": "shop_pill_golden",
		"golden": "shop_pill_nascent_pill", "nascent": "shop_pill_deity"}
	if breakthrough_ids.has(realm):
		var breakthrough: Dictionary = _item(items, breakthrough_ids[realm])
		if breakthrough.is_empty():
			last_error = "官坊高境界保底突破丹缺失"
			return []
		result.append(breakthrough)
	var draw := _roll(next_roll)
	if draw < 0.0:
		return []
	result.append(restore[int(floor(draw * restore.size()))].duplicate(true))
	var fortune := float(state.get("attributes", {}).get("fortune", 0))
	var dao_heart := float(state.get("attributes", {}).get("daoHeart", 0))
	var base_weights := [60.0, 30.0, 10.0, 5.0, 2.0, 1.0]
	var weights: Array = []
	var total := 0.0
	for i in range(realm_index + 1):
		var weight: float = base_weights[i]
		if i == realm_index and i > 0:
			weight += fortune * 2.0 + dao_heart * 1.5
		elif i == realm_index - 1:
			weight += fortune + dao_heart * 0.8
		else:
			weight = maxf(2.0, weight - (fortune * 0.5 + dao_heart * 0.3))
		weights.append(weight)
		total += weight
	draw = _roll(next_roll)
	if draw < 0.0:
		return []
	var rarity_roll := draw * total
	var chosen_realm := "qi"
	for i in weights.size():
		if rarity_roll < weights[i]:
			chosen_realm = REALM_ORDER[i]
			break
		rarity_roll -= weights[i]
	var candidates: Array = []
	for raw in all_treasures:
		if raw.get("realm", "qi") == chosen_realm:
			candidates.append(raw)
	if candidates.is_empty():
		for i in range(realm_index, -1, -1):
			for raw in all_treasures:
				if raw.get("realm", "qi") == REALM_ORDER[i]:
					candidates.append(raw)
			if not candidates.is_empty():
				break
	draw = _roll(next_roll)
	if draw < 0.0 or candidates.is_empty():
		return []
	var treasure: Dictionary = candidates[int(floor(draw * candidates.size()))]
	result.append({"id": "shop_treasure_dyn_" + String(treasure.id),
		"name": treasure.get("name"), "type": "treasure",
		"price": treasure.get("price", 15), "realm": treasure.get("realm", "qi"),
		"desc": treasure.get("desc", ""), "effect": {"treasureId": treasure.id}})
	var path_offer := _path_offer(state, deck_doc, card_doc, realm)
	if not path_offer.is_empty():
		result.append(path_offer)
	draw = _roll(next_roll)
	if draw < 0.0:
		return []
	result.append(gifts[int(floor(draw * gifts.size()))].duplicate(true))
	draw = _roll(next_roll)
	if draw < 0.0:
		return []
	if draw < 0.35 + fortune * 0.03:
		var box_roll := _roll(next_roll)
		if box_roll < 0.0:
			return []
		result.append({"id": "shop_treasure_box" if box_roll < 0.5 else \
			"shop_treasure_mysterious", "name": "天机宝匣" if box_roll < 0.5 else \
			"神秘古玩", "type": "treasure", "price": 25 if box_roll < 0.5 else 15,
			"realm": realm, "desc": "由天机锁封印的神秘古匣，隐约透出太古灵气。价格不高不低。开启需消耗道心与福缘破解天机！" \
			if box_roll < 0.5 else "地摊上淘来的蒙尘古物，价格不高不低。买下鉴宝，全看主角机缘（Fortune）气运！",
			"effect": {"_identifyTreasure": "box" if box_roll < 0.5 else "antique"}})
	for raw in result:
		var item: Dictionary = raw
		var base := int(previous_pill_prices.get(item.get("id"), item.get("price", 15))) \
			if item.get("type") == "pill" else int(item.get("price", 15))
		item["price"] = maxi(1, int(floor(base * price_multiplier * (
			pill_discount if item.get("type") == "pill" else 1.0))))
	return result


func _high_realm_pill_discount(state: Dictionary) -> float:
	var skill = PathSkillFlow.new(_content)
	var passive: Dictionary = skill.active_bonuses(state)
	if not skill.last_error.is_empty():
		last_error = skill.last_error
		return -1.0
	return 0.8 if int(passive.get("stoneToPill", 0)) > 0 else 1.0

func _price_multiplier(state: Dictionary) -> float:
	var routes_doc: Variant = _content.read_module("world:trade_routes")
	var factions_doc: Variant = _content.read_module("world:factions")
	if not routes_doc is Dictionary or not factions_doc is Dictionary:
		return -1.0
	var saved_routes: Dictionary = state.get("tradeRouteState", {}) \
		if state.get("tradeRouteState") is Dictionary else {}
	var authoritative: bool = TradeRouteFlow.new(_content).snapshot_valid(state)
	if (state.has("tradeRouteVersion") or not saved_routes.is_empty()) \
			and not authoritative:
		last_error = "官坊商路快照未通过严格来源校验"
		return -1.0
	# TradeRouteSystem receives reputation, undercurrent, victory and ghost
	# market events. Ordinary public bazaar purchases emit source "shop" in the
	# browser and do not change routes; only changed faction state is gated here.
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
					last_error = "商路声望变动尚未迁入"
					return -1.0
		for id in progress.get("undercurrentStages", {}):
			if int(progress["undercurrentStages"][id]) != int(
					factions_doc.get("undercurrents", {}).get(id, {}).get("stage", 0)):
				if not authoritative:
					last_error = "商路暗流变动尚未迁入"
					return -1.0
	var location := String(state.get("currentLocation", ""))
	var best: Dictionary = {}
	var best_score := -999999.0
	var all_routes: Array = routes_doc.get("routes", [])
	var candidates: Array = []
	for route in all_routes:
		if route is Dictionary and (route.get("from") == location \
				or route.get("to") == location or location == "坊市"):
			candidates.append(route)
	if candidates.is_empty():
		candidates = all_routes
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
			best = {"danger": danger, "prosperity": prosperity}
	if best.is_empty():
		last_error = "商路档案无可用路线"
		return -1.0
	return clampf(1.0 + (best["danger"] - best["prosperity"]) / 250.0,
		0.8, 1.25)

func _path_offer(state: Dictionary, deck_doc: Dictionary, card_doc: Dictionary,
		realm: String = "qi") -> Dictionary:
	var path := String(state.get("path", ""))
	var contract: Dictionary = deck_doc.get("paths", {}).get(path, {})
	var pool: Array = contract.get("shopPoolByRealm", {}).get(realm, \
		contract.get("shopPool", []))
	for value in pool:
		var card_id := String(value)
		var owned := false
		for owned_value in state.get("deck", []):
			if String(owned_value).trim_suffix("+") == card_id:
				owned = true
		for acquired in state.get("skillAcquisitions", {}):
			if String(acquired).trim_suffix("+") == card_id:
				owned = true
		if owned:
			continue
		for raw in card_doc.get("battle_cards", []):
			if raw is Dictionary and raw.get("id") == card_id and raw.get("tags", []).has(path):
				var economy: Dictionary = deck_doc.get("economy", {})
				var price := maxi(1, int(economy.get("shopBasePrice", 0)) + \
					int(raw.get("cost", 0)) * int(economy.get("shopCostMultiplier", 0)) \
					+ REALM_ORDER.find(realm) * int(economy.get("shopRealmStep", 0)))
				return {"id": "card_%s_%s" % [path, card_id],
					"name": "本脉功法：" + String(raw.get("name", card_id)),
					"type": "card", "desc": raw.get("description", raw.get("desc", "")),
					"price": price, "realm": realm, "cardId": card_id,
					"path": path, "sourceType": "shop_path_slot",
					"effect": {"deckCard": {"cardId": card_id, "path": path,
						"sourceType": "shop_path_slot", "sourceId": "shop:" + realm + ":" + path}}}
	return {}

func _item(items: Array, item_id: String) -> Dictionary:
	for raw in items:
		if raw is Dictionary and raw.get("id") == item_id:
			return raw.duplicate(true)
	return {}

func _roll(next_roll: Callable) -> float:
	var value: Variant = next_roll.call()
	if not (value is float or value is int) or float(value) < 0.0 \
			or float(value) >= 1.0:
		last_error = "官坊抽签无效"
		return -1.0
	return float(value)
