extends "res://tests/noncombat_q_shop_source.gd"


func _run() -> void:
	var helper: Script = load("res://scripts/noncombat_ghost_market_catalog.gd")
	if helper == null:
		return _fail("ghost market source catalogue is not implemented")
	var game = Domain.new(Registry.new(), null, "slot_3")
	if not game.start("sword"):
		return _fail("ghost catalogue fixture could not start")
	var state: Dictionary = game.state.duplicate(true)
	state["realm"] = "qi"
	state["currentLocation"] = "宗门"
	state["attributes"]["fortune"] = 50
	state["resources"]["spiritStone"] = 40
	var catalog: RefCounted = helper.new(game._content)
	var plan: Dictionary = catalog.generate(state, func() -> float: return 0.0)
	var stock: Array = plan.get("stock", [])
	var card: Dictionary = plan.get("card", {})
	if stock.size() != 4 or stock.map(func(item: Variant) -> Variant:
		return item.get("id")) != ["玄铁甲", "brokenSword", "灵泉葫芦", "beastCore"] \
			or stock.any(func(item: Variant) -> bool:
				return item.get("price") != 6 or item.get("ghostMarkup") != 1.1) \
			or stock[0].get("hiddenTrait", {}).get("status") != "sealed" \
			or stock[1].get("hiddenTrait") != null \
			or card.get("id") != "market_encounter" \
			or card.get("title") != "🏪 鬼市偶遇 — 福运小成" \
			or not String(card.get("description", "")).contains("青云剑路") \
			or card.get("choices", {}).get("left", {}).get("action", {}).get(
				"vendorId") != "ghost_market" \
			or not String(card.get("choices", {}).get("left", {}).get(
				"desc", "")).contains("6 件商品"):
		return _fail("ghost fixed-roll stock, seal, route or card differs from browser")
	var alternate: Dictionary = catalog.generate(state, func() -> float: return 0.37)
	var other_stock: Array = alternate.get("stock", [])
	if other_stock.size() != 4 or other_stock.map(func(item: Variant) -> Variant:
		return item.get("id")) != ["灵泉葫芦", "brokenSword", "玄铁甲", "beastCore"] \
			or other_stock.any(func(item: Variant) -> bool:
				return item.get("price") != 8) \
			or other_stock[1].get("hiddenTrait", {}).get("revealedText") != \
				"禁纹在夜气里反复指向一条未标商路。" \
			or not String(alternate.get("card", {}).get("description", "")).begins_with(
				"雾气中浮现一扇古铜门"):
		return _fail("ghost second fixed-roll source stock or flavor differs")
	if not catalog.generate(state, func() -> float: return 1.0).is_empty():
		return _fail("invalid ghost random roll was admitted")
	var session: Dictionary = catalog.build_session(plan, "ghost:test", 14)
	var offers: Array = session.get("immutableOffers", [])
	if offers.size() != 5 or offers[0].get("id") != "ghost_oath_rusted_sword" \
			or offers.slice(1).map(func(item: Variant) -> Variant:
				return item.get("id")) != stock.map(func(item: Variant) -> Variant:
				return item.get("id")) \
			or offers[0].get("costSpec", []) != [
				{"kind": "resource", "key": "spiritStone", "amount": 4},
				{"kind": "resource", "key": "lifespan", "amount": 3}] \
			or offers[1].get("costSpec", []) != [
				{"kind": "resource", "key": "spiritStone", "amount": 6},
				{"kind": "resource", "key": "lifespan", "amount": 3}] \
			or offers.any(func(item: Variant) -> bool:
				return item.get("provenance") != "ghost_market") \
			or session.get("interactionBudget") != {"limit": 1, "remaining": 1} \
			or session.get("services", [])[0].get("id") != "ghost_inspect_seal" \
			or session.get("presentationProfile", {}).get("id") != "ghost-contract-plinth" \
			or session.get("debt", {}).get("creditorId") != "faceless_broker" \
			or session.get("summary", {}).get("openingOfferCount") != 5:
		return _fail("ghost session offer order, composite costs or source profile differs")
	if not catalog.build_session(plan, "", 14).is_empty():
		return _fail("empty ghost session key was admitted")
	var duplicate: Dictionary = plan.duplicate(true)
	duplicate["stock"].append(stock[0].duplicate(true))
	duplicate["stock"].back()["id"] = "ghost_oath_rusted_sword"
	var deduped: Dictionary = catalog.build_session(duplicate, "ghost:dedup", 14)
	if deduped.get("immutableOffers", []).size() != 5:
		return _fail("profile contract was duplicated by ambient stock")
	var richer: Dictionary = state.duplicate(true)
	richer["realm"] = "golden"
	richer["attributes"]["fortune"] = 90
	var roll_count := [0]
	var rich_plan: Dictionary = catalog.generate(richer, func() -> float:
		roll_count[0] += 1
		return float(posmod(roll_count[0] * 7, 97)) / 97.0)
	var rich_stock: Array = rich_plan.get("stock", [])
	if roll_count[0] != 42 or rich_plan.get("meta", {}).get("slotCount") != 8 \
			or rich_stock.size() != 5 or rich_stock.map(func(item: Variant) -> Variant:
				return item.get("id")) != ["问道剑", "白刃遗剑", "ancientSword",
				"血玉扳指", "剑心佩"] \
			or rich_stock.map(func(item: Variant) -> Variant:
				return item.get("price")) != [24, 24, 23, 22, 15] \
			or rich_stock.map(func(item: Variant) -> Variant:
				return item.get("hiddenTrait") != null) != [false, true, true,
				false, false]:
		return _fail("high-fortune ghost cap, seal positions or RNG order differs from browser: " + JSON.stringify({"rolls": roll_count[0], "slots": rich_plan.get("meta", {}).get("slotCount"), "stock": rich_stock.map(func(item: Variant) -> Variant: return {"id": item.get("id"), "price": item.get("price"), "hidden": item.get("hiddenTrait") != null})}))
	var depleted: Dictionary = state.duplicate(true)
	depleted["realm"] = "deity"
	depleted["attributes"]["fortune"] = 90
	# Keep the complete source-pinned route snapshot; this fixture isolates the
	# source fallback at high prosperity rather than testing malformed saves.
	depleted["tradeRouteState"]["routes"]["cloud_sword_road"]["prosperity"] = 80
	depleted["resources"]["treasures"] = []
	for treasure in game._content.read_module("shops:treasures")["treasures"]:
		if int(treasure.get("rarity", 0)) == 5:
			depleted["resources"]["treasures"].append(treasure["id"])
	var scripted := [0.5, 0.0, 0.0, 0.5, 0.0, 0.0, 0.9, 0.0, 0.0, 0.0]
	var cursor := [0]
	var depleted_plan: Dictionary = catalog.generate(depleted, func() -> float:
		var i: int = cursor[0]
		cursor[0] += 1
		return float(scripted[i]) if i < scripted.size() else float(posmod(
			i * 7, 97)) / 97.0)
	var depleted_stock: Array = depleted_plan.get("stock", [])
	if cursor[0] != 37 or depleted_stock.map(func(item: Variant) -> Variant:
		return item.get("id")) != ["破魂锥", "青云剑匣", "剑心古剑",
		"ancientSword", "万卷封魔残页"] \
			or depleted_stock.map(func(item: Variant) -> Variant:
				return item.get("price")) != [27, 13, 13, 19, 14] \
			or depleted_stock.map(func(item: Variant) -> Variant:
				return item.get("hiddenTrait") != null) != [true, false,
				false, false, true]:
		return _fail("depleted gold-pool fallback changed the sixth-rarity source pick: " + JSON.stringify({"rolls": cursor[0], "stock": depleted_stock.map(func(item: Variant) -> Variant: return {"id": item.get("id"), "price": item.get("price"), "hidden": item.get("hiddenTrait") != null})}))
	if not catalog.generate(richer, func() -> float: return 0.9).is_empty() \
			or not catalog.last_error.contains("封签随机源"):
		return _fail("degenerate high-pool seal RNG did not fail closed")
	print("NONCOMBAT_GHOST_CATALOG_SOURCE_PASS stock=4 source_card=true session=5 high_pool=5 fallback=true")
	quit(0)
