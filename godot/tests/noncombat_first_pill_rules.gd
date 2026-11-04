extends SceneTree

const Registry = preload("res://scripts/runtime_data_registry.gd")
const Domain = preload("res://scripts/noncombat_domain.gd")
const CombatDomain = preload("res://scripts/combat_domain.gd")
const BattlePlanResolver = preload("res://scripts/battle_plan_resolver.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var story = Domain.new(Registry.new())
	if not story.start("pill"):
		return _fail("pill opening failed")
	for direction in ["right", "right", "left", "left", "left"]:
		if not story.choose(direction, story.issue_choice_token()):
			return _fail("pill route could not reach teaching battle")
	var request: Dictionary = story.battle_request()
	if story.state.get("phase") != "BATTLE_PENDING" \
			or request.get("encounterId") != "enc_trial_pill_poison":
		return _fail("pill pending request unavailable")
	var plan: Dictionary = BattlePlanResolver.new(Registry.new()).resolve_persisted(story.state)
	if plan.is_empty() or plan.get("sourceAuthenticated") != true:
		return _fail("pill request did not authenticate")
	# Only rules are under test; the source desktop stage is a separate issue.
	plan["launchAuthorized"] = true
	var battle = CombatDomain.new(Registry.new())
	battle._rng.seed = 11
	if not battle.load_first_teaching_request(request, plan):
		return _fail("pill request failed to load into combat rules")
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(
		"res://tests/fixtures/first_pill_rules_source.json"))
	if source.is_empty() or not _same(battle.state, source.get("opening", {})) \
			or battle.state.get("pathCombatState", {}).get("archetypeId") != "pill_elixirfire":
		return _fail("pill opening differs from source: " + str(_snapshot(battle.state)))
	for step in source.get("actions", []):
		var card_id: String = step.get("cardId", "")
		var index: int = battle.state.get("hand", []).find(card_id)
		if index < 0 or not battle.play_card(index):
			return _fail("pill card rejected: " + card_id + " hand=" + str(battle.state.get("hand", [])))
		if not _same(battle.state, step.get("state", {})):
			return _fail("pill card differs: " + card_id + " actual=" + str(_snapshot(battle.state)))
	if not battle.end_turn() or not battle.choose_reaction("TAKE_HIT") \
			or not _same(battle.state, source.get("afterEnemy", {})):
		return _fail("pill poison tick/first enemy action differs: " + str(_snapshot(battle.state)))
	var guard_index: int = battle.state.get("hand", []).find("pill_guard")
	if guard_index < 0 or not battle.play_card(guard_index) \
			or not _same(battle.state, source.get("afterHeal", {})):
		return _fail("pill heal differs: " + str(_snapshot(battle.state)))
	if not _poison_terminal(request, plan):
		return _fail("lethal source poison did not notify terminal victory")
	print("NONCOMBAT_FIRST_PILL_RULES_PASS source_effects=true poison=true heal=true lethal=true isolated_stage=true")
	quit(0)


func _poison_terminal(request: Dictionary, plan: Dictionary) -> bool:
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(
		"res://tests/fixtures/first_pill_poison_terminal_source.json"))
	var battle = CombatDomain.new(Registry.new())
	battle._rng.seed = 11
	if source.is_empty() or not battle.load_first_teaching_request(request, plan):
		return false
	var notifications: Array[Dictionary] = []
	var observed_battle: WeakRef = weakref(battle)
	battle.changed.connect(func(event: Dictionary) -> void:
		notifications.append({"type": event.get("type"),
			"phase": observed_battle.get_ref().state.get("phase")}))
	for card_id in source.get("firstTurn", []):
		if not battle.play_card(battle.state.get("hand", []).find(card_id)):
			return false
	if not battle.end_turn() or not battle.choose_reaction("TAKE_HIT"):
		return false
	for card_id in source.get("secondTurn", []):
		if not battle.play_card(battle.state.get("hand", []).find(card_id)):
			return false
	var before: Dictionary = source.get("before", {})
	if int(battle.state.get("player", {}).get("hp", -1)) != int(before.get("hp", -2)) \
			or int(battle.state.get("enemy", {}).get("hp", -1)) != int(before.get("enemyHp", -2)) \
			or int(battle.state.get("enemyStatus", {}).get("poison", -1)) != int(before.get("poison", -2)):
		return false
	if not battle.end_turn() or not battle.choose_reaction("TAKE_HIT"):
		return false
	return battle.state.get("phase") == "VICTORY" \
		and battle.state.get("enemy", {}).get("hp") == source.get("after", {}).get("enemyHp") \
		and not notifications.is_empty() \
		and notifications[-1] == {"type": "POISON_TICK", "phase": "VICTORY"}


func _snapshot(actual: Dictionary) -> Dictionary:
	return {"phase": actual.get("phase"), "turn": actual.get("turn"),
		"hp": actual.get("player", {}).get("hp"),
		"block": actual.get("player", {}).get("block"),
		"enemyHp": actual.get("enemy", {}).get("hp"),
		"qi": actual.get("qi"),
		"qiGained": actual.get("enemy", {}).get("planRuntime", {}).get(
			"turnMemory", {}).get("qiGained"),
		"handSize": actual.get("hand", []).size(),
		"poison": actual.get("enemyStatus", {}).get("poison", 0)}


func _same(actual: Dictionary, expected: Dictionary) -> bool:
	var values := _snapshot(actual)
	for key in ["phase", "turn", "hp", "block", "enemyHp", "qi", "qiGained", "handSize", "poison"]:
		if values.get(key) != expected.get(key):
			return false
	return true


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
