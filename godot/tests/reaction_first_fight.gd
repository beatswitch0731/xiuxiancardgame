extends SceneTree

const Registry = preload("res://scripts/runtime_data_registry.gd")
const Domain = preload("res://scripts/combat_domain.gd")


func _initialize() -> void:
	for reaction_id in ["GUARD", "DEFLECT", "EVADE"]:
		var game := Domain.new(Registry.new())
		if not game.load_m0_opening():
			_fail("M0 opening missing")
			return
		var card_index: int = game.state["hand"].find("sword_sheath_guard")
		if not game.play_card(card_index) or not game.end_turn():
			_fail("original guard card or reaction window failed")
			return
		var available: Array = game.reaction_options().filter(func(option: Dictionary) -> bool: return option["available"])
		if available.map(func(option: Dictionary) -> String: return option["id"]) != ["TAKE_HIT", "DEFLECT", "GUARD", "EVADE"]:
			_fail("reaction availability differs from browser rules")
			return
		if not game.choose_reaction(reaction_id, 1.0) or game.state["phase"] != "PLAYER_TURN" or game.state["turn"] != 2:
			_fail("reaction failed: " + reaction_id)
			return
		if reaction_id == "GUARD" and (game.state["player"]["hp"] != 3 or game.state["enemy"]["planRuntime"]["currentState"] != "PROBE"):
			_fail("guard did not mitigate original attack")
			return
		if reaction_id == "DEFLECT" and (game.state["player"]["hp"] != 1 or game.state["enemy"]["planRuntime"]["currentState"] != "BROKEN" or game.state["enemyStatus"].get("vulnerable") != 1):
			_fail("deflect did not expose original enemy plan")
			return
		if reaction_id == "EVADE" and (game.state["player"]["hp"] != 3 or game.state["hand"].size() != 4):
			_fail("evade did not consume one next-turn draw")
			return
	print("FIRST_FIGHT_REACTION_PASS guard,deflect,evade")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
