extends "res://tests/noncombat_foundation_shop_natural.gd"


func _fixed_roll() -> float:
	return 0.39


func _target_card_id() -> String:
	return "ch_foundation_20"


func _verify_shop_natural(game: RefCounted, path: String) -> void:
	if game.state.realm != "foundation" or game.state.phase != "MILESTONE_PENDING" \
			or game.get_current_card().get("id") != "ch_foundation_20":
		return _fail("natural foundation milestone did not become actionable")
	var pending: Dictionary = game.state.duplicate(true)
	var cold = _shop_branch(FileAccess.get_file_as_bytes(game._store.v2_path), path)
	if cold == null or not _same(cold.state, pending):
		return _fail("foundation milestone did not strictly cold restore")
	var card: Dictionary = cold.get_current_card()
	if card.get("_pathVariant", {}).get("path") != "spell" \
			or card.get("bossJourneyStage", {}).get("canonicalThreshold") != 20 \
			or not cold.can_choose_direction("left"):
		return _fail("foundation milestone path, omen or choice missing")
	if not cold.choose("left", cold.issue_choice_token()) \
			or not cold.state.cardsPlayed.has("ch_foundation_20") \
			or not cold.state.get("noncombatFlow", {}).get("spineFacts", {}).has(
				"fact:%d:foundation_main_enrollment" % int(cold.state.get("lifeCount", 0))):
		return _fail("foundation milestone choice did not record source chapter fact")
	var committed = _shop_branch(FileAccess.get_file_as_bytes(
		cold._store.v2_path), path)
	if committed == null or not _same(committed.state, cold.state):
		return _fail("foundation milestone result did not strictly cold restore")
	print("NONCOMBAT_FOUNDATION_MILESTONES_NATURAL_PASS entry=true path=true spine=true replay=true")
	quit(0)
