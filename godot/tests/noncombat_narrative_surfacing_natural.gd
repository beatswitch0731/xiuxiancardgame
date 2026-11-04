extends "res://tests/noncombat_foundation_shop_natural.gd"

func _fixed_roll() -> float:
	return 0.39

func _iteration_limit() -> int:
	return 240

func _target_card_id() -> String:
	return "surface_karma_burden"

func _verify_shop_natural(game: RefCounted, path: String) -> void:
	if game.state.phase != "SURFACING_PENDING" \
			or game.state.get("karmaSeeds", []).size() < 4 \
			or not game.get_current_card().get("description", "").contains("因果种子"):
		return _fail("public karma burden was not a source surfacing card")
	var pending: Dictionary = game.state.duplicate(true)
	var cold = _shop_branch(FileAccess.get_file_as_bytes(game._store.v2_path), path)
	if cold == null or not _same(cold.state, pending) \
			or not cold.choose("left", cold.issue_choice_token()):
		return _fail("public surfacing pending cold replay failed")
	var chosen: Dictionary = cold.state.duplicate(true)
	var chosen_cold = _shop_branch(FileAccess.get_file_as_bytes(
		cold._store.v2_path), path)
	if chosen_cold == null or not _same(chosen_cold.state, chosen) \
			or chosen_cold.state.get("narrativeSurfacingState", {}).get(
				"lastResolved", {}).get("surface_karma_burden") != chosen.turn:
		return _fail("public surfacing choice cold replay failed")
	print("NONCOMBAT_NARRATIVE_SURFACING_NATURAL_PASS pending=true chosen=true replay=true")
	quit(0)
