extends SceneTree

const Domain = preload("res://scripts/noncombat_domain.gd")
const Registry = preload("res://scripts/runtime_data_registry.gd")
const RunSession = preload("res://scripts/noncombat_run_session.gd")

func _initialize() -> void:
	var path := "user://tests/mortal_natural_%d.json" % Time.get_ticks_usec()
	var game = Domain.new(Registry.new(), RunSession.new(path, "slot_2"), "slot_2")
	game._normal_roll_override = 0.45
	game._market_flow.roll_override = 0.45
	game._destiny_wheel_flow.roll_override = 0.45
	game._ripple_flow.roll_override = 0.45
	game._hint_flow.roll_override = 0.45
	if not game.start("body"):
		return _fail("clean body start failed")
	var bonded := false
	for i in 100:
		if game.state.phase == "FLOW_PENDING" and not game.resume_flow():
			return _fail("flow stopped before mortal bond at %d" % i)
		var card: Dictionary = game.get_current_card()
		var current_id := String(card.get("id", game.state.get("currentCardId", "")))
		var direction := "right" if game.state.phase in ["COMBAT_HANDOFF",
			"MARKET_PENDING", "FIRST_SESSION_ROUTE_PENDING"] \
			or current_id in ["q_start_body", "q_love", "q_inherit"] else "left"
		if not game.can_choose_direction(direction):
			for fallback in ["left", "right", "down", "up"]:
				if game.can_choose_direction(fallback):
					direction = fallback
					break
		if not game.choose(direction, game.issue_choice_token()):
			return _fail("choice failed at %d %s %s %s" % [i, current_id,
				game.state.phase, direction])
		if current_id == "q_love" and direction == "right" \
				and game.state.resources.companions.has("mortal"):
			bonded = true
			break
	if not bonded:
		return _fail("natural Qi draw did not reach executable q_love.right")
	if not game.state.resources.companions.has("mortal") \
			or not game.state.get("companionProgress", {}).get("states", {}).has("mortal"):
		return _fail("natural q_love did not register mortal")
	var cold = Domain.new(Registry.new(), RunSession.new(path, "slot_2"), "slot_2")
	cold._normal_roll_override = 0.45
	cold._market_flow.roll_override = 0.45
	cold._destiny_wheel_flow.roll_override = 0.45
	cold._ripple_flow.roll_override = 0.45
	cold._hint_flow.roll_override = 0.45
	if not cold.restore():
		return _fail("natural mortal bond did not strictly restore")
	var crisis_seen := false
	for i in 160:
		if cold.state.phase == "FLOW_PENDING" and not cold.resume_flow():
			return _fail("post-bond flow stopped at %d: %s" % [i,
				cold.flow_failure_reason()])
		var card: Dictionary = cold.get_current_card()
		var card_id := String(card.get("id", cold.state.get("currentCardId", "")))
		if card_id == "comp_mortal_qi_karma_crisis_good":
			crisis_seen = true
			break
		if cold.state.realm != "qi":
			return _fail("reached %s before Qi crisis" % cold.state.realm)
		var direction := "right" if cold.state.phase in ["COMBAT_HANDOFF",
			"MARKET_PENDING", "FIRST_SESSION_ROUTE_PENDING"] \
			or card_id in ["q_inherit", "q_love"] else "left"
		if not cold.can_choose_direction(direction):
			for fallback in ["left", "right", "down", "up"]:
				if cold.can_choose_direction(fallback):
					direction = fallback
					break
		if not cold.choose(direction, cold.issue_choice_token()):
			return _fail("post-bond choice failed at %d %s %s" % [i,
				card_id, direction])
	if not crisis_seen:
		return _fail("natural Qi flow did not reach mortal crisis")
	var crisis_reopen = Domain.new(Registry.new(), RunSession.new(path, "slot_2"), "slot_2")
	crisis_reopen._normal_roll_override = 0.45
	crisis_reopen._market_flow.roll_override = 0.45
	crisis_reopen._destiny_wheel_flow.roll_override = 0.45
	crisis_reopen._ripple_flow.roll_override = 0.45
	crisis_reopen._hint_flow.roll_override = 0.45
	if not crisis_reopen.restore() \
			or crisis_reopen.get_current_card().get("id") != "comp_mortal_qi_karma_crisis_good" \
			or not crisis_reopen.can_choose_direction("left") \
			or not crisis_reopen.can_choose_direction("right"):
		return _fail("natural crisis did not strictly restore with two choices")
	var before_affection := int(crisis_reopen.state.get("npcAffection", {}).get(
		"mortal", 50))
	var before_trust := int(crisis_reopen.state.companionProgress.states.mortal.trust)
	if not crisis_reopen.choose("left", crisis_reopen.issue_choice_token()):
		return _fail("natural crisis left choice failed")
	var settled = Domain.new(Registry.new(), RunSession.new(path, "slot_2"), "slot_2")
	settled._normal_roll_override = 0.45
	settled._market_flow.roll_override = 0.45
	settled._destiny_wheel_flow.roll_override = 0.45
	settled._ripple_flow.roll_override = 0.45
	settled._hint_flow.roll_override = 0.45
	var restored := settled.restore()
	if not restored or int(settled.state.get("npcAffection", {}).get(
			"mortal", 0)) != mini(100, before_affection + 4) \
			or int(settled.state.get("companionProgress", {}).get(
				"states", {}).get("mortal", {}).get("trust", 0)) != mini(100, before_trust + 2):
		return _fail("natural crisis settlement did not strictly restore: " + JSON.stringify({
			"restored": restored, "store": settled._store.last_error,
			"affection": settled.state.get("npcAffection", {}).get("mortal"),
			"trust": settled.state.get("companionProgress", {}).get(
				"states", {}).get("mortal", {}).get("trust")}))
	print("NONCOMBAT_MORTAL_NATURAL_PASS bond=true crisis=true cold=true")
	quit(0)

func _fail(message: String) -> void:
	push_error(message)
	quit(1)
