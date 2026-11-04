extends SceneTree

const Registry = preload("res://scripts/runtime_data_registry.gd")
const Domain = preload("res://scripts/combat_domain.gd")


func _initialize() -> void:
	var data := Registry.new()
	var game := Domain.new(data)
	var expected: Array = data.read_json("fixtures/m0_first_turn_expected.json").get("steps", [])
	var commands := ["", "sword_probe", "sword_followthrough", "sword_sheath_guard"]
	if not game.load_m0_opening() or expected.size() != 6:
		push_error("M0 replay fixture failed to load")
		quit(1)
		return
	for index in range(commands.size()):
		if index > 0:
			var hand: Array = game.state["hand"]
			var hand_index := hand.find(commands[index])
			if hand_index < 0 or not game.play_card(hand_index):
				push_error("M0 card command rejected: " + commands[index])
				quit(1)
				return
		if not _check_step(game.state, expected[index], false):
			quit(1)
			return
	if not game.end_turn() or not _check_step(game.state, expected[4], false):
		quit(1)
		return
	# M0's second-turn draw uses the browser's global Math.random stream.
	# Compare the authoritative combat state while the RNG hand order is audited separately.
	if not game.take_hit(1.0) or not _check_step(game.state, expected[5], true):
		quit(1)
		return
	print("M0_FIRST_TURN_PARITY_PASS steps=5,6,7,8,9,10 excluding_turn2_hand_order")
	quit(0)


func _check_step(state: Dictionary, expected_step: Dictionary, ignore_hand: bool) -> bool:
	var actual := _projection(state)
	var target: Dictionary = expected_step.duplicate()
	var step: int = target["step"]
	target.erase("step")
	if ignore_hand:
		actual.erase("hand")
		target.erase("hand")
	for key in ["turn", "qi", "playerHp", "playerBlock", "enemyHp", "enemyBlock"]:
		actual[key] = int(actual[key])
		target[key] = int(target[key])
	if actual != target:
		push_error("M0 mismatch at step %d: actual=%s expected=%s" % [step, JSON.stringify(actual), JSON.stringify(target)])
		return false
	return true


func _projection(state: Dictionary) -> Dictionary:
	return {"phase": state["phase"], "turn": state["turn"], "qi": state["qi"],
		"playerHp": state["player"]["hp"], "playerBlock": state["player"]["block"],
		"enemyHp": state["enemy"]["hp"], "enemyBlock": state["enemy"]["block"],
		"planState": state["enemy"]["planRuntime"]["currentState"],
		"hand": state["hand"].duplicate()}
