extends "res://tests/noncombat_q_fellow_entry.gd"

const Resolver = preload("res://scripts/battle_plan_resolver.gd")
const Combat = preload("res://scripts/combat_domain.gd")


func _run() -> void:
	var path := "user://tests/q_fellow_live_%d.json" % Time.get_ticks_usec()
	var game = Domain.new(Registry.new(), RunSession.new(path, "slot_3"), "slot_3")
	_set_zero_rolls(game)
	if not _reach_decision27(game):
		return _fail("q_fellow source prefix did not reach the ordinary draw")
	game._normal_roll_override = 0.18
	if not game.resume_flow() or game.get_current_card().get("id") != "q_fellow" \
			or not game.choose("right", game.issue_choice_token()) \
			or game.state.get("phase") != "WARNING_PENDING" \
			or not game.choose("left", game.issue_choice_token()) \
			or game.state.get("phase") != "BATTLE_PENDING":
		return _fail("natural q_fellow right choice did not persist a battle")
	var restored = Domain.new(Registry.new(), RunSession.new(path, "slot_3"), "slot_3")
	_set_zero_rolls(restored)
	if not restored.restore():
		return _fail("q_fellow battle could not cold restore")
	var request: Dictionary = restored.battle_request()
	if request.get("sourceCardId") != "q_fellow" \
			or request.get("direction") != "right" \
			or request.get("encounterId") != null:
		return _fail("q_fellow source request identity changed")
	var plan: Dictionary = Resolver.new(Registry.new()).resolve_persisted(restored.state)
	if plan.get("sourceAuthenticated") != true \
			or plan.get("launchAuthorized") != true \
			or plan.get("enemy") != request.get("pendingResolution", {}).get(
				"combatCard", {}).get("enemy") \
			or plan.get("deck") != request.get("playerSnapshot", {}).get(
				"battleLoadout", {}).get("deck"):
		return _fail("q_fellow inline fight has no authenticated source plan/current deck")
	var combat = Combat.new(Registry.new())
	if not combat.load_persisted_request(request, plan):
		return _fail("q_fellow source battle could not load its current deck")
	var oracle: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(
		"res://tests/fixtures/q_fellow_combat_source.json"))
	var expected: Dictionary = oracle.get("active", {})
	if combat.state.get("enemy", {}).get("hp") != expected.get("enemy", {}).get("hp") \
			or combat.state.get("enemy", {}).get("def", {}).get("id") != \
				expected.get("enemy", {}).get("def", {}).get("id") \
			or combat.state.get("enemyIntent", {}).get("type") != \
				expected.get("enemyIntent", {}).get("type") \
			or combat.state.get("enemy", {}).get("intentIndex") != \
				expected.get("enemy", {}).get("intentIndex"):
		return _fail("q_fellow opening foe or first source intent differs")
	var source_states: Array = oracle.get("branches", {}).get("defeat", {}).get("battleStates", [])
	if source_states.size() != 8:
		return _fail("q_fellow source turn cycle is incomplete")
	var starting_hp := int(combat.state["player"]["hp"])
	if not combat.end_turn() or not combat.choose_reaction("TAKE_HIT", 0.99) \
			or combat.state["player"]["hp"] != starting_hp \
			or combat.state["enemyStatus"].get("sword_intent") != \
				source_states[1]["enemyStatus"].get("sword_intent") \
			or combat.state["enemyIntent"].get("type") != \
				source_states[1]["enemyIntent"].get("type") \
			or combat.state["enemy"].get("intentIndex") != \
				source_states[1]["enemy"].get("intentIndex"):
		return _fail("q_fellow sword-intent buff or next attack differs from source")
	var source_loss := int(source_states[2]["player"]["hp"]) - \
		int(source_states[3]["player"]["hp"])
	if not combat.end_turn() or not combat.choose_reaction("TAKE_HIT", 0.99) \
			or combat.state["player"]["hp"] != maxi(0, starting_hp - source_loss) \
			or combat.state["enemyStatus"].get("sword_intent") != \
				source_states[3]["enemyStatus"].get("sword_intent"):
		return _fail("q_fellow sword-intent attack damage differs from source")
	print("NONCOMBAT_Q_FELLOW_LIVE_LOADOUT_PASS natural=true source_plan=true deck=true intent=true buff=true attack=true")
	quit(0)
