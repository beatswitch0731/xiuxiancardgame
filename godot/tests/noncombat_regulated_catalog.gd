extends SceneTree

const Content = preload("res://scripts/noncombat_content_repository.gd")
const Catalog = preload("res://scripts/noncombat_regulated_shop_catalog.gd")
const FIXTURE := "res://tests/fixtures/regulated_shop_qi_zero.json"

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var source = Content.new()
	var shop = Catalog.new(source)
	var fixture: Variant = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	if not fixture is Dictionary:
		return _fail("browser-regulated fixture missing")
	for list_name in ["discarded", "frozen", "secondDiscarded", "secondFrozen"]:
		for row in fixture[list_name]:
			row["price"] = int(row["price"])
	var state := {"realm": "qi", "path": "sword", "currentLocation": "宗门",
		"deck": ["sword_edge"],
		"skillAcquisitions": {}, "attributes": {"fortune": 0, "daoHeart": 2},
		"resources": {"spiritStone": 10}}
	var calls: Array = []
	var offers: Array = shop.generate(state, func() -> float:
		calls.append(0.0)
		return 0.0)
	var first_prices := {}
	var first_rows := []
	for offer in offers:
		first_rows.append({"id": offer["id"], "price": offer["price"]})
		if offer.get("type") == "pill":
			first_prices[offer["id"]] = offer["price"]
	if JSON.stringify(first_rows) != JSON.stringify(fixture["discarded"]) \
			or calls.size() != int(fixture["discardedRolls"]):
		return _fail("discarded catalog differs: actual=%s expected=%s calls=%d" % [
			JSON.stringify(first_rows), JSON.stringify(fixture["discarded"]), calls.size()])
	calls.clear()
	var entry: Array = shop.generate(state, func() -> float:
		calls.append(0.0)
		return 0.0, first_prices)
	var entry_rows := []
	for offer in entry:
		entry_rows.append({"id": offer["id"], "price": offer["price"]})
	if JSON.stringify(entry_rows) != JSON.stringify(fixture["frozen"]) \
			or calls.size() != int(fixture["entryRolls"]):
		return _fail("frozen entry catalog differs from executed ShopSystem: %s" % [entry_rows])
	var entry_prices := {}
	for offer in entry:
		if offer.get("type") == "pill":
			entry_prices[offer["id"]] = offer["price"]
	calls.clear()
	var second: Array = shop.generate(state, func() -> float:
		calls.append(0.0)
		return 0.0, entry_prices)
	var second_rows := []
	var second_prices := {}
	for offer in second:
		second_rows.append({"id": offer["id"], "price": offer["price"]})
		if offer.get("type") == "pill":
			second_prices[offer["id"]] = offer["price"]
	if JSON.stringify(second_rows) != JSON.stringify(fixture["secondDiscarded"]) \
			or calls.size() != int(fixture["secondDiscardedRolls"]):
		return _fail("second official prefetch lost persistent ShopSystem prices")
	calls.clear()
	var second_entry: Array = shop.generate(state, func() -> float:
		calls.append(0.0)
		return 0.0, second_prices)
	var second_entry_rows := []
	for offer in second_entry:
		second_entry_rows.append({"id": offer["id"], "price": offer["price"]})
	if JSON.stringify(second_entry_rows) != JSON.stringify(fixture["secondFrozen"]) \
			or calls.size() != int(fixture["secondEntryRolls"]):
		return _fail("second official entry lost persistent ShopSystem prices")
	if offers.size() < 5 or offers[0].get("id") != "shop_pill_foundation" \
			or offers[0].get("price") != 6 or offers[1].get("id") != "shop_pill_healing" \
			or calls.size() != 6 or shop.source_pins().size() != 6:
		return _fail("regulated source catalog or browser draw order differs: %s / %s" % [offers, calls])
	var card: Dictionary = shop.card(state)
	if card.get("id") != "shop_encounter" or card.get("type") != "SHOP" \
			or card.get("choices", {}).get("right", {}).get("action", {}).get("vendorId") \
			!= "regulated_market" or card.get("choices", {}).get("left", {}).get("text") \
			!= "不入楼，继续赶路":
		return _fail("regulated encounter lost source card identity")
	print("NONCOMBAT_REGULATED_CATALOG_PASS source=true six_rolls=true card=true")
	quit(0)

func _fail(message: String) -> void:
	printerr("NONCOMBAT_REGULATED_CATALOG_FAIL " + message)
	quit(1)
