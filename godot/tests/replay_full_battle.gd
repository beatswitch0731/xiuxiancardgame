extends SceneTree

const Registry = preload("res://scripts/runtime_data_registry.gd")
const Domain = preload("res://scripts/combat_domain.gd")


func _initialize() -> void:
	var data := Registry.new()
	var fixture: Dictionary = data.read_json("fixtures/m0_full_battle_expected.json")
	var steps: Array = fixture.get("steps", [])
	var game := Domain.new(data)
	if steps.size() != 12 or fixture.get("sourceRewardCardId") != "combat_reward" \
			or fixture.get("sourceRewardPathCombatState", "invalid") != null \
			or not game.load_m0_opening():
		_fail("Source full-fight fixture did not load")
		return
	if not game.call("set_replay_random_values", fixture["randomValues"]):
		_fail("Browser random input was rejected")
		return
	for expected in steps:
		if not _check(game.state, expected):
			quit(1)
			return
		var action := String(expected["action"])
		var accepted := false
		if action == "END_TURN":
			accepted = game.end_turn()
		elif action == "TAKE_HIT":
			accepted = game.choose_reaction("TAKE_HIT")
		else:
			accepted = game.play_card(game.state["hand"].find(action))
		if not accepted:
			_fail("Browser action was rejected at source step %s: %s" % [expected["step"], action])
			return
	if game.state["phase"] != "VICTORY" or game.state["active"] \
			or int(game.state["enemy"]["hp"]) != 0 \
			or game.state["pathCombatState"] != null \
			or int(game.call("replay_random_remaining")) != 0:
		_fail("Third-turn source victory or random-tape consumption diverged")
		return
	print("M0_FULL_BATTLE_PARITY_PASS steps=5..16 reward_source=combat_reward random_values=9")
	quit(0)


func _check(state: Dictionary, expected: Dictionary) -> bool:
	var actual := {
		"phase": state["phase"], "turn": state["turn"], "qi": state["qi"],
		"playerHp": state["player"]["hp"], "playerBlock": state["player"]["block"],
		"enemyHp": state["enemy"]["hp"], "enemyBlock": state["enemy"]["block"],
		"planState": state["enemy"]["planRuntime"]["currentState"],
		"enemyIntent": state["enemyIntent"],
		"pathCombatState": state["pathCombatState"],
		"playerStatus": state["playerStatus"],
		"enemyStatus": state["enemyStatus"],
		"hand": state["hand"], "drawPile": state["drawPile"],
		"discardPile": state["discardPile"],
	}
	var wanted := expected.duplicate(true)
	wanted.erase("step")
	wanted.erase("action")
	for field in ["turn", "qi", "playerHp", "playerBlock", "enemyHp", "enemyBlock"]:
		actual[field] = int(actual[field])
		wanted[field] = int(wanted[field])
	if _normalized(actual) != _normalized(wanted):
		push_error("M0 full fight mismatch at step %s: actual=%s expected=%s" % [
			expected["step"], JSON.stringify(actual), JSON.stringify(wanted)])
		return false
	return true


func _normalized(value: Variant) -> Variant:
	if value is Dictionary:
		var out := {}
		for key in value:
			out[key] = _normalized(value[key])
		return out
	if value is Array:
		var out := []
		for item in value:
			out.append(_normalized(item))
		return out
	if value is float and is_equal_approx(value, floor(value)):
		return int(value)
	return value


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
