extends "res://tests/noncombat_foundation_normal_pool.gd"

func _run() -> void:
	var game = Domain.new(Registry.new(), null, "slot_3")
	if not game.start("spell"):
		return _fail("nascent pool fixture could not start")
	var state: Dictionary = game.state.duplicate(true)
	state.realm = "nascent"
	state.attributes.cultivation = 10
	state.resources.spiritStone = 0
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
		return _fail("nascent catalog can strand players: " + JSON.stringify(stranded))
	var rich: Dictionary = state.duplicate(true)
	rich.resources.spiritStone = 1000
	rich.resources.pills.foundation = 1
	var unsupported: Array = []
	for card in draw._catalog(rich, true):
		if card.get("realm") != "nascent" or not draw.eligible(card, rich, []):
			continue
		for direction in card.get("choices", {}):
			if not choice.choice_available(rich, card, String(direction)):
				unsupported.append(String(card.id) + ":" + String(direction))
	if not unsupported.is_empty():
		return _fail("nascent source option gap: " + JSON.stringify(unsupported))
	var buckets: Dictionary = draw.buckets(state)
	if buckets.is_empty() or not buckets.get("current", []).any(
			func(row: Variant) -> bool: return row.get("id") == "n_hunt"):
		return _fail("nascent normal source pool is closed: " + draw.last_error)
	var flow: Dictionary = game._prepare_normal_flow(state)
	if flow.get("nascentSourceSha") != ContentRepository.new().source_sha256(
			"cards:nascent"):
		return _fail("nascent first draw did not pin source module")
	print("NONCOMBAT_NASCENT_NORMAL_POOL_PASS draw=true choices=all")
	quit(0)
