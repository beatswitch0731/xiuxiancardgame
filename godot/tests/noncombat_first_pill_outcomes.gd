extends SceneTree

const Registry = preload("res://scripts/runtime_data_registry.gd")
const Domain = preload("res://scripts/noncombat_domain.gd")
const CombatDomain = preload("res://scripts/combat_domain.gd")
const BattlePlanResolver = preload("res://scripts/battle_plan_resolver.gd")
const BattleScene = preload("res://scenes/main.tscn")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var story = _pending_story()
	if story == null:
		return _fail("pill pending story unavailable")
	var request: Dictionary = story.battle_request()
	var plan: Dictionary = BattlePlanResolver.new(Registry.new()).resolve_persisted(story.state)
	if plan.get("launchAuthorized") != true:
		return _fail("pill source stage was not authorized")
	var defeat = CombatDomain.new(Registry.new())
	defeat._rng.seed = 11
	if not defeat.load_first_teaching_request(request, plan):
		return _fail("pill defeat source request did not load")
	for _turn in range(8):
		if defeat.state.get("phase") == "DEFEAT":
			break
		var ember_index: int = defeat.state.get("hand", []).find("pill_ember")
		if ember_index >= 0 and not defeat.play_card(ember_index):
			return _fail("pill defeat route could not play ember")
		if not defeat.end_turn() or not defeat.choose_reaction("TAKE_HIT"):
			return _fail("pill defeat route could not advance enemy action")
	if defeat.state.get("phase") != "DEFEAT":
		return _fail("pill defeat route did not finish: " + str(defeat.state.get("phase")))
	var defeat_result := _result(defeat, request)
	var defeated_story = _pending_story()
	if defeat_result.get("outcome") != "defeat" \
			or not defeated_story.submit_battle_result(defeat_result) \
			or defeated_story.submit_battle_result(defeat_result):
		return _fail("pill defeat did not settle once")
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(
		"res://tests/fixtures/first_pill_poison_terminal_source.json"))
	var victory = CombatDomain.new(Registry.new())
	victory._rng.seed = 11
	if source.is_empty() or not victory.load_first_teaching_request(request, plan):
		return _fail("pill victory source request did not load")
	for card_id in source.get("firstTurn", []):
		if not victory.play_card(victory.state.get("hand", []).find(card_id)):
			return _fail("pill first-turn victory card rejected: " + card_id)
	if not victory.end_turn() or not victory.choose_reaction("TAKE_HIT"):
		return _fail("pill first enemy action failed")
	for card_id in source.get("secondTurn", []):
		if not victory.play_card(victory.state.get("hand", []).find(card_id)):
			return _fail("pill second-turn victory card rejected: " + card_id)
	if not victory.end_turn() or not victory.choose_reaction("TAKE_HIT") \
			or victory.state.get("phase") != "VICTORY":
		return _fail("pill poison did not produce victory")
	var victory_result := _result(victory, request)
	var winning_story = _pending_story()
	if victory_result.get("outcome") != "victory" \
			or not winning_story.submit_battle_result(victory_result) \
			or winning_story.submit_battle_result(victory_result):
		return _fail("pill victory did not settle once")
	print("NONCOMBAT_FIRST_PILL_OUTCOMES_PASS victory=true defeat=true poison=true source_owner=true")
	quit(0)


func _pending_story():
	var game = Domain.new(Registry.new())
	if not game.start("pill"):
		return null
	for direction in ["right", "right", "left", "left", "left"]:
		if not game.choose(direction, game.issue_choice_token()):
			return null
	return game if game.state.get("phase") == "BATTLE_PENDING" else null


func _result(battle: RefCounted, request: Dictionary) -> Dictionary:
	var scene: Control = BattleScene.instantiate()
	scene.combat = battle
	scene.battle_request = request
	var result: Dictionary = scene.terminal_result()
	scene.free()
	return result


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
