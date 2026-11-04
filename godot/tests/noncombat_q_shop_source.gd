extends "res://tests/noncombat_regulated_replay.gd"


func _run() -> void:
	var game = Domain.new(Registry.new(), null, "slot_3")
	_set_zero_rolls(game)
	if not game.start("sword"):
		return _fail("source q_shop fixture could not start")
	var rich: Dictionary = game.state.duplicate(true)
	rich["resources"]["spiritStone"] = 40
	var card: Dictionary = game._normal_choice_policy.source_card("q_shop", rich)
	if card.get("id") != "q_shop" or card.get("type") != "SHOP" \
			or card.get("sceneImage") != "assets/cards/events/scene_qi_q_shop.png":
		return _fail("authored ordinary shop card or art is unavailable")
	for direction in ["left", "right", "up", "down"]:
		if not game._normal_choice_policy.choice_available(rich, card, direction):
			return _fail("source q_shop direction is still unavailable: " + direction)
	rich["attributes"]["daoHeart"] = 100
	if game._normal_choice_policy.choice_available(rich, card, "down"):
		return _fail("capped daoHeart escape bypassed affordable source offers")
	rich["resources"]["spiritStone"] = 0
	if not game._normal_choice_policy.choice_available(rich, card, "down") \
			or game._normal_choice_policy.choice_available(rich, card, "up"):
		return _fail("browser capped fallback or unaffordable shop option differs")
	print("NONCOMBAT_Q_SHOP_SOURCE_PASS choices=4 art=true")
	quit(0)
