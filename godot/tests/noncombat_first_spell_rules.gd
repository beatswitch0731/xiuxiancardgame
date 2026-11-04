extends SceneTree

const Registry = preload("res://scripts/runtime_data_registry.gd")
const Domain = preload("res://scripts/noncombat_domain.gd")
const RunSession = preload("res://scripts/noncombat_run_session.gd")
const CombatDomain = preload("res://scripts/combat_domain.gd")
const BattlePlanResolver = preload("res://scripts/battle_plan_resolver.gd")
const OpeningScene = preload("res://scenes/noncombat_opening.tscn")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var save_path := "user://tests/first_spell_live_%d.json" % Time.get_ticks_usec()
	var game = Domain.new(Registry.new(), RunSession.new(save_path))
	if not game.start("spell"):
		return _fail("spell opening failed")
	for direction in ["right", "right", "left", "left", "left"]:
		if not game.choose(direction, game.issue_choice_token()):
			return _fail("spell route could not reach teaching battle")
	var request: Dictionary = game.battle_request()
	if game.state.get("phase") != "BATTLE_PENDING" \
			or request.get("encounterId") != "enc_trial_spell_seal":
		return _fail("spell request was not persisted")
	var restored = Domain.new(Registry.new(), RunSession.new(save_path))
	if not restored.restore():
		return _fail("spell pending request could not restore")
	var plan: Dictionary = BattlePlanResolver.new(Registry.new()).resolve_persisted(restored.state)
	if plan.get("launchAuthorized") != true or plan.get("sceneAvailable") != true:
		return _fail("source spell battlefield was not authorized")
	var battle = CombatDomain.new(Registry.new())
	battle._rng.seed = 11
	if not battle.load_first_teaching_request(request, plan):
		return _fail("spell source request failed to load")
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(
		"res://tests/fixtures/first_spell_rules_source.json"))
	if source.is_empty() or not _same_source_state(battle.state, source.get("opening", {})) \
			or battle.state.get("pathCombatState", {}).get("archetypeId") != "spell_cycle":
		return _fail("spell opening stats differ from source")
	for step in source.get("actions", []):
		var card_id: String = step.get("cardId", "")
		var index: int = battle.state.get("hand", []).find(card_id)
		if index < 0 or not battle.play_card(index):
			return _fail("spell source card rejected: " + card_id)
		if not _same_source_state(battle.state, step.get("state", {})):
			return _fail("spell card differs from production source: " + card_id)
	var story: Control = OpeningScene.instantiate()
	story.save_path = save_path
	root.add_child(story)
	await process_frame
	var launch: Button = story.find_child("LaunchBattle", true, false)
	if launch == null or story.active_battle != null \
			or story.opening.state.get("phase") != "BATTLE_PENDING":
		return _fail("spell desktop did not expose its source battlefield")
	story.queue_free()
	await process_frame
	print("NONCOMBAT_FIRST_SPELL_RULES_PASS source_effects=true desktop_available=true replay=true")
	quit(0)


func _same_source_state(actual: Dictionary, expected: Dictionary) -> bool:
	return actual.get("player", {}).get("hp") == expected.get("hp") \
		and actual.get("player", {}).get("maxHp") == expected.get("maxHp") \
		and actual.get("enemy", {}).get("hp") == expected.get("enemyHp") \
		and actual.get("qi") == expected.get("qi") \
		and actual.get("hand", []).size() == expected.get("handSize") \
		and actual.get("playerStatus", {}).get("spell_seal", 0) == expected.get("spellSeal")


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
