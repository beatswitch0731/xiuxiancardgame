extends SceneTree

const Registry = preload("res://scripts/runtime_data_registry.gd")
const Domain = preload("res://scripts/noncombat_domain.gd")
const CombatDomain = preload("res://scripts/combat_domain.gd")
const BattlePlanResolver = preload("res://scripts/battle_plan_resolver.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var story = Domain.new(Registry.new())
	if not story.start("body"):
		return _fail("body opening failed")
	for direction in ["right", "right", "left", "left", "left"]:
		if not story.choose(direction, story.issue_choice_token()):
			return _fail("body route could not reach teaching battle")
	var request: Dictionary = story.battle_request()
	if story.state.get("phase") != "BATTLE_PENDING" \
			or request.get("encounterId") != "enc_trial_body_iron":
		return _fail("body pending request unavailable")
	var plan: Dictionary = BattlePlanResolver.new(Registry.new()).resolve_persisted(story.state)
	if plan.is_empty() or plan.get("sourceAuthenticated") != true:
		return _fail("body pending request did not authenticate")
	# This rule probe changes only scene readiness; the desktop scene is a later issue.
	plan["launchAuthorized"] = true
	var battle = CombatDomain.new(Registry.new())
	var suitable_hand := false
	for seed in range(1, 21):
		battle._rng.seed = seed
		if not battle.load_first_teaching_request(request, plan):
			return _fail("body source request failed to load into combat rules")
		if battle.state.get("hand", []).count("body_stance") == 2:
			suitable_hand = true
			break
	if not suitable_hand:
		return _fail("body source request failed to load into combat rules")
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(
		"res://tests/fixtures/first_body_rules_source.json"))
	if source.is_empty() or not _same(battle.state, source.get("opening", {})) \
			or battle.state.get("pathCombatState", {}).get("archetypeId") != "body_fortress":
		print("ACTUAL_BODY_OPENING=", _snapshot(battle.state), " EXPECTED=", source.get("opening", {}))
		return _fail("body opening differs from source")
	for step in source.get("actions", []):
		var card_id: String = step.get("cardId", "")
		var index: int = battle.state.get("hand", []).find(card_id)
		if index < 0 or not battle.play_card(index):
			print("ACTUAL_BODY_HAND=", battle.state.get("hand", []))
			return _fail("body source card rejected: " + card_id)
		if not _same(battle.state, step.get("state", {})):
			print("ACTUAL_BODY_STEP=", _snapshot(battle.state), " EXPECTED=", step.get("state", {}))
			return _fail("body source step differs: " + card_id)
	print("NONCOMBAT_FIRST_BODY_RULES_PASS source_effects=true isolated_stage=true")
	quit(0)


func _same(actual: Dictionary, expected: Dictionary) -> bool:
	return actual.get("player", {}).get("hp") == expected.get("hp") \
		and actual.get("player", {}).get("block") == expected.get("block") \
		and actual.get("enemy", {}).get("hp") == expected.get("enemyHp") \
		and actual.get("qi") == expected.get("qi") \
		and actual.get("hand", []).size() == expected.get("handSize") \
		and actual.get("playerStatus", {}).get("fortify", 0) == expected.get("fortify")


func _snapshot(actual: Dictionary) -> Dictionary:
	return {"hp": actual.get("player", {}).get("hp"),
		"block": actual.get("player", {}).get("block"),
		"enemyHp": actual.get("enemy", {}).get("hp"),
		"qi": actual.get("qi"), "handSize": actual.get("hand", []).size(),
		"fortify": actual.get("playerStatus", {}).get("fortify", 0),
		"archetype": actual.get("pathCombatState", {}).get("archetypeId")}


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
