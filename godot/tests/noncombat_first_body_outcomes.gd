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
		return _fail("body pending story unavailable")
	var request: Dictionary = story.battle_request()
	var plan: Dictionary = BattlePlanResolver.new(Registry.new()).resolve_persisted(story.state)
	var defeat = CombatDomain.new(Registry.new())
	defeat._rng.seed = 11
	if not defeat.load_first_teaching_request(request, plan) \
			or not defeat.play_card(defeat.state.get("hand", []).find("body_fist")) \
			or not defeat.end_turn() or not defeat.choose_reaction("TAKE_HIT") \
			or defeat.state.get("phase") != "DEFEAT":
		return _fail("real body enemy attack did not produce defeat")
	var defeat_result := _result(defeat, request)
	var defeated_story = _pending_story()
	if defeat_result.get("outcome") != "defeat" \
			or not defeated_story.submit_battle_result(defeat_result) \
			or defeated_story.submit_battle_result(defeat_result):
		return _fail("body defeat did not settle once")
	var victory = CombatDomain.new(Registry.new())
	victory._rng.seed = 11
	if not victory.load_first_teaching_request(request, plan):
		return _fail("body victory source request did not load")
	var played: Array = []
	for _turn in range(8):
		if victory.state.get("phase") == "VICTORY":
			break
		if victory.state.get("phase") != "PLAYER_TURN":
			return _fail("body victory route left player phase")
		for _card in range(6):
			var card_id := _choose_card(victory)
			if card_id.is_empty():
				break
			played.append(card_id)
			if not victory.play_card(victory.state["hand"].find(card_id)):
				return _fail("body victory card was rejected: " + card_id)
			if victory.state.get("phase") == "VICTORY":
				break
		if victory.state.get("phase") == "VICTORY":
			break
		if not victory.end_turn():
			return _fail("body victory turn could not end")
		var reaction := "GUARD" if victory.reaction_options()[2]["available"] else "TAKE_HIT"
		played.append("END_TURN:" + reaction)
		if not victory.choose_reaction(reaction):
			return _fail("body victory reaction was rejected")
		if victory.state.get("phase") == "DEFEAT":
			return _fail("body victory route lost: " + JSON.stringify(played))
	if victory.state.get("phase") != "VICTORY":
		return _fail("body victory route did not finish: " + JSON.stringify(played))
	var victory_result := _result(victory, request)
	var winning_story = _pending_story()
	if victory_result.get("outcome") != "victory" \
			or not winning_story.submit_battle_result(victory_result) \
			or winning_story.submit_battle_result(victory_result):
		return _fail("body victory did not settle once")
	print("NONCOMBAT_FIRST_BODY_OUTCOMES_PASS victory=true defeat=true source_owner=true")
	quit(0)


func _pending_story():
	var game = Domain.new(Registry.new())
	if not game.start("body"):
		return null
	for direction in ["right", "right", "left", "left", "left"]:
		if not game.choose(direction, game.issue_choice_token()):
			return null
	return game if game.state.get("phase") == "BATTLE_PENDING" else null


func _choose_card(battle: RefCounted) -> String:
	var hand: Array = battle.state.get("hand", [])
	var qi := int(battle.state.get("qi", 0))
	if qi <= 0:
		return ""
	var seals := int(battle.state.get("playerStatus", {}).get("fortify", 0))
	for card_id in (["body_counter", "body_stance", "body_fist"] if seals >= 2 \
			else ["body_stance", "body_fist", "body_counter"]):
		if hand.has(card_id):
			return card_id
	return ""


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
