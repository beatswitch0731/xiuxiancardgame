extends "res://tests/noncombat_sword_tomb_entry.gd"

const Resolver = preload("res://scripts/battle_plan_resolver.gd")
const Combat = preload("res://scripts/combat_domain.gd")
const StageRouter = preload("res://scripts/combat_stage_router.gd")


func _run() -> void:
	var path := "user://tests/sword_tomb_live_%d.json" % Time.get_ticks_usec()
	var game = Domain.new(Registry.new(), RunSession.new(path, "slot_3"), "slot_3")
	_set_zero_rolls(game)
	if not _reach_decision27(game):
		return _fail("sword tomb source prefix did not reach the ordinary draw")
	game._normal_roll_override = 0.46
	if not game.resume_flow() or game.get_current_card().get("id") != "q_swordTomb" \
			or not game.choose("left", game.issue_choice_token()) \
			or not _continue_to(game, "thread_sword_tomb_1") \
			or not game.choose("left", game.issue_choice_token()) \
			or not _continue_to(game, "thread_sword_tomb_2"):
		return _fail("natural sword tomb combat node did not arrive")
	var oracle: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(
		"res://tests/fixtures/sword_tomb_source.json"))
	for direction in ["left", "right"]:
		if not _check_direction(game, direction, oracle):
			return _fail("sword tomb %s live plan or source intent differs" % direction)
	print("NONCOMBAT_SWORD_TOMB_LIVE_LOADOUT_PASS natural=true branches=2 deck=true intent=true")
	quit(0)


func _check_direction(game: RefCounted, direction: String, oracle: Dictionary) -> bool:
	var path := "user://tests/sword_tomb_live_%s_%d.json" % [
		direction, Time.get_ticks_usec()]
	var store = RunSession.new(path, "slot_3")
	if store.commit_snapshot(game.state, -1).get("ok") != true:
		return false
	var branch = Domain.new(Registry.new(), store, "slot_3")
	_set_zero_rolls(branch)
	branch._normal_roll_override = 0.46
	if not branch.restore() or not branch.choose(direction, branch.issue_choice_token()) \
			or branch.state.get("phase") != "WARNING_PENDING" \
			or not branch.choose("left", branch.issue_choice_token()) \
			or branch.state.get("phase") != "BATTLE_PENDING":
		return false
	var restored = Domain.new(Registry.new(), RunSession.new(path, "slot_3"), "slot_3")
	_set_zero_rolls(restored)
	restored._normal_roll_override = 0.46
	if not restored.restore():
		return false
	var request: Dictionary = restored.battle_request()
	var plan: Dictionary = Resolver.new(Registry.new()).resolve_persisted(restored.state)
	var presentation: Dictionary = oracle["accepted"]["secondCard"]["choices"][
		direction]["combatPresentation"]
	if request.get("sourceCardId") != "thread_sword_tomb_2" \
			or request.get("threadId") != "sword_tomb_trial" \
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
	var context: Dictionary = StageRouter.new(Registry.new()).resolve_choice(
		"thread_sword_tomb_2", direction,
		request.get("pendingResolution", {}).get("combatCard", {}),
		String(request.get("encounterInstanceId", "")),
		request.get("pendingResolution", {}), String(request.get("path", "")),
		String(request.get("realm", "")))
	context["deck"] = plan["deck"]
	var stage: Control = load(String(plan["stageScene"])).instantiate()
	root.add_child(stage)
	var stage_ready: bool = stage.bind_stage_context(context) \
		and stage._background_texture == Registry.new().texture_for(
			presentation.get("sceneImage", "")) \
		and stage._enemy_idle == Registry.new().texture_for(
			presentation.get("actorCards", {}).get("enemy", {}).get("image", "")) \
		and stage._clips.get("enemy", {}).has("buff")
	stage.queue_free()
	if not stage_ready:
		return false
	var combat = Combat.new(Registry.new())
	if not combat.load_persisted_request(request, plan):
		return false
	var states: Array = oracle["battleProbes"][direction]["states"]
	if states.size() != 5 or combat.state.get("enemy", {}).get("hp") != \
			states[0]["enemy"].get("hp") \
			or combat.state.get("enemy", {}).get("def", {}).get("id") != \
				states[0]["enemy"].get("def", {}).get("id") \
			or combat.state.get("enemyIntent", {}).get("type") != \
				states[0]["enemyIntent"].get("type"):
		return false
	var opening_hp := int(combat.state["player"]["hp"])
	if not combat.end_turn() or not combat.choose_reaction("TAKE_HIT", 0.99) \
			or combat.state["player"].get("hp") != opening_hp \
			or combat.state["enemyStatus"].get("sword_intent") != \
				states[2]["enemyStatus"].get("sword_intent") \
			or combat.state["enemyIntent"].get("type") != "attack":
		return false
	var source_loss := int(states[3]["player"]["hp"]) - \
		int(states[4]["player"]["hp"])
	return combat.end_turn() and combat.choose_reaction("TAKE_HIT", 0.99) \
		and combat.state["player"].get("hp") == maxi(0, opening_hp - source_loss) \
		and combat.state["enemyStatus"].get("sword_intent") == 0
