extends "res://tests/noncombat_foundation_normal_pool.gd"

func _run() -> void:
	var game = Domain.new(Registry.new(), null, "slot_3")
	if not game.start("spell"):
		return _fail("golden pool fixture could not start")
	var state: Dictionary = game.state.duplicate(true)
	state.realm = "golden"
	state.attributes.cultivation = 10
	state.resources.spiritStone = 100
	var draw = DrawPolicy.new(ContentRepository.new())
	var choice = ChoicePolicy.new(ContentRepository.new())
	var stranded: Array = []
	for source_card in draw._catalog(state, true):
		if not draw.eligible(source_card, state, []):
			continue
		if not source_card.get("choices", {}).keys().any(func(direction: Variant) -> bool:
			return choice.choice_available(state, source_card, String(direction))):
			stranded.append(source_card.id)
	if not stranded.is_empty():
		return _fail("golden catalog can strand players on cards: " + JSON.stringify(stranded))
	var rich: Dictionary = state.duplicate(true)
	rich.resources.spiritStone = 1000
	rich.resources.pills.foundation = 1
	var unsupported: Array = []
	for card in draw._catalog(rich, true):
		if card.get("realm") != "golden" or not draw.eligible(card, rich, []):
			continue
		for direction in card.get("choices", {}):
			if not choice.choice_available(rich, card, String(direction)):
				unsupported.append(String(card.id) + ":" + String(direction))
	if unsupported != ["g_shop:down"]:
		return _fail("golden source option gap changed: " + JSON.stringify(unsupported))
	print("GOLDEN_SOURCE_UNSUPPORTED_CHOICES ", JSON.stringify(unsupported))
	var buckets: Dictionary = draw.buckets(state)
	if buckets.is_empty() or not buckets.get("current", []).any(
			func(row: Variant) -> bool: return row.get("id") == "g_spellGreat"):
		return _fail("golden normal source pool is closed: " + draw.last_error)
	for card_id in ["g_coreFormed", "g_spellGreat", "g_tribulationOmen", "g_fateChoice"]:
		var card: Dictionary = choice.source_card(card_id, state)
		if card.is_empty() or not choice.choice_available(state, card, "left") \
				or choice.settle(state, card_id, "left").is_empty():
			return _fail("golden numeric source card did not settle: " + card_id)
	print("NONCOMBAT_GOLDEN_NORMAL_POOL_PASS draw=true basic=4")
	quit(0)
