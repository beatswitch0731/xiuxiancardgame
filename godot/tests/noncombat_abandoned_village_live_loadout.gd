extends "res://tests/noncombat_abandoned_village_entry.gd"

const Resolver = preload("res://scripts/battle_plan_resolver.gd")
const Combat = preload("res://scripts/combat_domain.gd")


func _run() -> void:
	var path := "user://tests/village_live_%d.json" % Time.get_ticks_usec()
	var game = Domain.new(Registry.new(), RunSession.new(path, "slot_3"), "slot_3")
	_set_zero_rolls(game)
	if not _reach_decision27(game):
		return _fail("village source prefix did not reach the ordinary draw")
	game._normal_roll_override = 0.12
	if not game.resume_flow() or game.get_current_card().get("id") != "q_beggar" \
			or not game.choose("right", game.issue_choice_token()) \
			or not _continue_to(game, "thread_ab_village_1") \
			or not game.choose("right", game.issue_choice_token()) \
			or not _continue_to(game, "thread_ab_village_2") \
			or not game.choose("left", game.issue_choice_token()) \
			or not _continue_to(game, "thread_ab_village_3"):
		return _fail("natural village third node did not arrive")
	var oracle: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(
		"res://tests/fixtures/abandoned_village_source.json"))
	var left_states: Array = oracle.get("branches", {}).get("defeat", {}).get(
		"battleStates", [])
	var right_states: Array = oracle.get("entry", {}).get("rightBattleStates", [])
	if left_states.size() != 4 or right_states.size() != 4:
		return _fail("village source intent cycle is incomplete")
	for direction in ["left", "right"]:
		if not _check_direction(game, direction, oracle,
			left_states if direction == "left" else right_states):
			return _fail("village %s source battle plan or intent differs" % direction)
	print("NONCOMBAT_ABANDONED_VILLAGE_LIVE_LOADOUT_PASS natural=true branches=2 deck=true intent=true")
	quit(0)


func _check_direction(game: RefCounted, direction: String, oracle: Dictionary,
		source_states: Array) -> bool:
	var path := "user://tests/village_live_%s_%d.json" % [direction, Time.get_ticks_usec()]
	var store = RunSession.new(path, "slot_3")
	if store.commit_snapshot(game.state, -1).get("ok") != true:
		return false
	var branch = Domain.new(Registry.new(), store, "slot_3")
	_set_zero_rolls(branch)
	branch._normal_roll_override = 0.12
	if not branch.restore() or not branch.choose(direction, branch.issue_choice_token()) \
			or branch.state.get("phase") != "WARNING_PENDING" \
			or not branch.choose("left", branch.issue_choice_token()) \
			or branch.state.get("phase") != "BATTLE_PENDING":
		return false
	var restored = Domain.new(Registry.new(), RunSession.new(path, "slot_3"), "slot_3")
	_set_zero_rolls(restored)
	restored._normal_roll_override = 0.12
	if not restored.restore():
		return false
	var request: Dictionary = restored.battle_request()
	var plan: Dictionary = Resolver.new(Registry.new()).resolve_persisted(restored.state)
	var presentation: Dictionary = oracle["entry"]["thirdCard"]["choices"][direction][
		"combatPresentation"]
	if request.get("sourceCardId") != "thread_ab_village_3" \
			or request.get("threadId") != "abandoned_village" \
			or request.get("direction") != direction \
			or request.get("encounterId") != null \
			or plan.get("sourceAuthenticated") != true \
			or plan.get("launchAuthorized") != true \
			or plan.get("enemy") != request.get("pendingResolution", {}).get(
				"combatCard", {}).get("enemy") \
			or plan.get("deck") != request.get("playerSnapshot", {}).get(
				"battleLoadout", {}).get("deck") \
			or plan.get("presentationId") != presentation.get("presentationId") \
			or plan.get("battlefieldId") != presentation.get("battlefieldId"):
		return false
	var combat = Combat.new(Registry.new())
	if not combat.load_persisted_request(request, plan):
		return false
	var enemy: Dictionary = oracle["entry"]["battle"]["enemy"]
	if combat.state.get("enemy", {}).get("hp") != enemy.get("hp") \
			or combat.state.get("enemy", {}).get("def", {}).get("id") != \
				enemy.get("def", {}).get("id") \
			or combat.state.get("enemyIntent", {}).get("type") != "debuff" \
			or combat.state.get("enemy", {}).get("intentIndex") != 1:
		return false
	var opening_hp := int(combat.state["player"]["hp"])
	if not combat.end_turn() or not combat.choose_reaction("TAKE_HIT", 0.99) \
			or combat.state["player"].get("hp") != opening_hp \
			or combat.state["playerStatus"].get("weak") != \
				source_states[1]["playerStatus"].get("weak") \
			or combat.state["enemyIntent"].get("type") != "attack":
		return false
	var source_loss := int(source_states[2]["player"]["hp"]) - \
		int(source_states[3]["player"]["hp"])
	return combat.end_turn() and combat.choose_reaction("TAKE_HIT", 0.99) \
		and combat.state["player"].get("hp") == maxi(0, opening_hp - source_loss)
