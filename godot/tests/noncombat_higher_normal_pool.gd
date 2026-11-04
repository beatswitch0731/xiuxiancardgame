extends "res://tests/noncombat_foundation_normal_pool.gd"


func _run() -> void:
	var game = Domain.new(Registry.new(), null, "slot_3")
	if not game.start("spell"):
		return _fail("higher normal pool fixture could not start")
	var draw = DrawPolicy.new(ContentRepository.new())
	var choice = ChoicePolicy.new(ContentRepository.new())
	for realm in ["deity", "tribulation"]:
		var state: Dictionary = game.state.duplicate(true)
		state.realm = realm
		state.attributes.cultivation = 10
		state.resources.spiritStone = 0
		var stranded: Array = []
		for card in draw._catalog(state, true):
			if not draw.eligible(card, state, []):
				continue
			if not card.get("choices", {}).keys().any(func(direction: Variant) -> bool:
				return choice.choice_available(state, card, String(direction))):
				stranded.append(card.id)
		if not stranded.is_empty():
			return _fail("%s normal pool strands players: %s" % [realm,
				JSON.stringify(stranded)])
		var rich: Dictionary = state.duplicate(true)
		rich.resources.spiritStone = 1000
		var unsupported: Array = []
		for card in draw._catalog(rich, true):
			if card.get("realm") != realm or not draw.eligible(card, rich, []):
				continue
			for direction in card.get("choices", {}):
				if card.get("id") in ["d_auction", "t_last_auction"] \
						and direction == "down":
					continue
				if not choice.choice_available(rich, card, String(direction)):
					unsupported.append(String(card.id) + ":" + String(direction))
		if not unsupported.is_empty():
			return _fail("%s source option gap: %s" % [realm,
				JSON.stringify(unsupported)])
		var auction_id := "d_auction" if realm == "deity" else "t_last_auction"
		var auction: Dictionary = choice.source_card(auction_id, rich)
		var paid: Dictionary = choice.settle(rich, auction_id,
			"left" if realm == "deity" else "right")
		if auction.is_empty() or paid.is_empty() \
				or int(paid.resources.spiritStone) != 1000 + int(auction.choices[
					"left" if realm == "deity" else "right"].effects.spiritStone) \
				or int(paid.resources.pills.get(auction.choices[
					"left" if realm == "deity" else "right"].effects.pill, 0)) != 1:
			return _fail(realm + " auction pill settlement failed")
		var empty: Dictionary = state.duplicate(true)
		if not choice.choice_available(empty, choice.source_card(auction_id, empty), "down"):
			return _fail(realm + " auction unaffordable exit blocked")
	var deity: Dictionary = game.state.duplicate(true)
	deity.realm = "deity"
	var final_choice: Dictionary = choice.settle(deity, "sd_dt_final_choice", "left")
	if final_choice.get("endingCandidate") != "chaos":
		return _fail("deity final story did not retain source ending candidate")
	if draw.buckets(deity).is_empty():
		return _fail("deity normal draw remained closed: " + draw.last_error)
	var deity_flow: Dictionary = game._prepare_normal_flow(deity)
	if deity_flow.get("deitySourceSha") != ContentRepository.new().source_sha256(
			"cards:deity"):
		return _fail("deity first draw did not pin source module")
	var auction_game = Domain.new(Registry.new(), null, "slot_3")
	if not auction_game.start("spell"):
		return _fail("deity auction domain fixture could not start")
	auction_game.state.realm = "deity"
	auction_game.state.resources.spiritStone = 1000
	auction_game.state.phase = "NORMAL_PENDING"
	auction_game.state.currentCardId = "d_auction"
	if not auction_game.choose("left", auction_game.issue_choice_token()) \
			or not auction_game.state.get("karmaSeeds", []).any(
				func(row: Variant) -> bool: return row.get("id") == "spellRevealed"):
		return _fail("deity auction purchase did not plant source seed")
	print("NONCOMBAT_HIGHER_NORMAL_POOL_PASS realms=2")
	quit(0)
