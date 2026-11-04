extends SceneTree

const Registry = preload("res://scripts/runtime_data_registry.gd")
const Repository = preload("res://scripts/noncombat_content_repository.gd")
const Domain = preload("res://scripts/noncombat_domain.gd")
const Catalog = preload("res://scripts/noncombat_regulated_shop_catalog.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var game = Domain.new(Registry.new(), null, "slot_2")
	if not game.start("sword"):
		return _fail("ambient catalog fixture could not start")
	var state: Dictionary = game.state.duplicate(true)
	state.realm = "deity"
	var rolls := [0.0, 0.99, 0.0, 0.0, 0.0, 0.0]
	var cursor := [0]
	var catalog = Catalog.new(Repository.new())
	var offers: Array = catalog.generate_for_realm(state, func() -> float:
		var value: float = rolls[cursor[0]]
		cursor[0] += 1
		return value)
	if offers.size() < 4 or cursor[0] != 6 \
			or offers[0].get("id") != "shop_pill_healing" \
			or not String(offers[1].get("id", "")).begins_with("shop_treasure_dyn_") \
			or not offers.any(func(row: Variant) -> bool:
				return row is Dictionary and row.get("id") == "shop_gift_spirit_tea") \
			or offers.back().get("id") != "shop_treasure_box":
		return _fail("deity ambient stock or source RNG order diverged")
	if offers.any(func(row: Variant) -> bool:
		return row is Dictionary and row.get("id") == "last_lesson_three_tone_sword"):
		return _fail("authored sword leaked into ordinary stock")
	var pill_game = Domain.new(Registry.new(), null, "slot_3")
	if not pill_game.start("pill"):
		return _fail("pill path catalog fixture could not start")
	var pill_state: Dictionary = pill_game.state.duplicate(true)
	pill_state.realm = "deity"
	var pill_rolls := [0.0, 0.99, 0.0, 0.0, 0.0, 0.0]
	var pill_cursor := [0]
	var pill_offers: Array = catalog.generate_for_realm(pill_state, func() -> float:
		var value: float = pill_rolls[pill_cursor[0]]
		pill_cursor[0] += 1
		return value)
	if pill_offers.is_empty() or pill_offers[0].get("id") != "shop_pill_healing" \
			or int(pill_offers[0].get("price", -1)) != int(floor(
				float(offers[0].get("price", 0)) * 0.8)):
		return _fail("nascent pill passive did not discount deity healing pill")
	var old_pill_state: Dictionary = pill_state.duplicate(true)
	old_pill_state.erase("pathSkillActivationIndex")
	var old_cursor := [0]
	var old_pill_offers: Array = catalog.generate_for_realm(old_pill_state,
		func() -> float:
			var value: float = pill_rolls[old_cursor[0]]
			old_cursor[0] += 1
			return value)
	if old_pill_offers.is_empty() or old_pill_offers[0].get("price") != \
			int(offers[0].get("price", -1)):
		return _fail("legacy save received a path skill before activation")
	print("NONCOMBAT_LAST_LESSON_AMBIENT_CATALOG_PASS stock=%d rolls=%d" % [
		offers.size(), cursor[0]])
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
