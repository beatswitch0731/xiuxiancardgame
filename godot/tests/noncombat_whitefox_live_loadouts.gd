extends "res://tests/noncombat_whitefox_battle.gd"

const PlanResolver = preload("res://scripts/battle_plan_resolver.gd")
const CombatDomain = preload("res://scripts/combat_domain.gd")
const SOURCE = "res://tests/fixtures/whitefox_battle_source.json"
const INTENTS = "res://tests/fixtures/whitefox_hound_intents_source.json"


func _run() -> void:
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SOURCE))
	var intents: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(INTENTS))
	if fixture.get("realCombat") != true or fixture.get("publicInput") != true:
		return _fail("whitefox source combat fixture is not production evidence")
	if intents.get("publicInput") != true or intents.get("injectedState") != false \
			or intents.get("rows", []).size() != 4:
		return _fail("whitefox hound intent source trace is incomplete")
	for source_path in intents.get("pins", {}):
		var actual := FileAccess.get_sha256(ProjectSettings.globalize_path(
			"res://").path_join("../" + source_path))
		if actual != intents["pins"][source_path]:
			return _fail("whitefox hound source drift: " + source_path)
	var cycle_by_path := {}
	for cycle in intents["rows"]:
		cycle_by_path[cycle["path"]] = cycle
	var checked := {}
	for row in fixture.get("rows", []):
		var path_id := String(row.get("path", ""))
		if row.get("outcome") != "victory" or checked.has(path_id):
			continue
		var save_path := "user://tests/whitefox_live_loadout_%s_%d.json" % [
			path_id, Time.get_ticks_usec()]
		var game = Domain.new(Registry.new(), Session.new(save_path, "slot_2"), "slot_2")
		if not _open_third(game, path_id) \
				or not game.choose("left", game.issue_choice_token()) \
				or not game.choose("left", game.issue_choice_token()):
			return _fail("natural whitefox battle route failed: " + path_id)
		var cold = Domain.new(Registry.new(), Session.new(save_path, "slot_2"), "slot_2")
		if not cold.restore():
			return _fail("whitefox pending battle cold restore failed: " + path_id)
		var request: Dictionary = cold.battle_request()
		var plan: Dictionary = PlanResolver.new(Registry.new()).resolve_persisted(cold.state)
		if request.get("encounterId") != null or request.get("sourceCardId") != "q_whiteFox_3" \
				or plan.get("launchAuthorized") != true \
				or plan.get("enemy") != request.get("pendingResolution", {}).get(
					"combatCard", {}).get("enemy") \
				or plan.get("deck") != row.get("battle", {}).get("masterDeck"):
			return _fail("whitefox source plan/current deck differs: " + path_id)
		var battle = CombatDomain.new(Registry.new())
		if not battle.load_persisted_request(request, plan):
			return _fail("whitefox source combat would not load: " + path_id)
		var source: Dictionary = row["battle"]
		var run: Dictionary = battle.state
		if run.get("phase") != source.get("phase") or run.get("turn") != source.get("turn") \
				or run.get("qi") != source.get("qi") \
				or not _same(run.get("player"), source.get("player")) \
				or not _same(run.get("enemyIntent"), source.get("enemyIntent")) \
				or run.get("enemy", {}).get("intentIndex") != source.get("enemy", {}).get(
					"intentIndex") \
				or run.get("enemy", {}).get("planRuntime") != null \
				or run.get("enemy", {}).get("def", {}).get("id") != "hound_pack_qi":
			return _fail("whitefox opening combat authority differs: " + path_id)
		for turn_index in range(1, 4):
			var reaction: Dictionary = cycle_by_path[path_id]["inputs"][turn_index * 2 - 1]
			var roll := float(reaction["resistanceRoll"]) if reaction.get(
				"resistanceRoll") != null else 0.99
			if not battle.end_turn() or not battle.choose_reaction("TAKE_HIT", roll):
				return _fail("whitefox hound public turn failed: " + path_id)
			var expected: Dictionary = cycle_by_path[path_id]["states"][turn_index]
			if battle.state.get("turn") != expected.get("turn") \
					or battle.state.get("phase") != expected.get("phase") \
					or battle.state.get("qi") != expected.get("qi") \
					or battle.state.get("player", {}).get("hp") != expected.get("playerHp") \
					or battle.state.get("player", {}).get("block") != expected.get("playerBlock") \
					or int(battle.state.get("playerStatus", {}).get("weak", 0)) != expected.get("playerWeak") \
					or battle.state.get("enemy", {}).get("intentIndex") != expected.get("intentIndex") \
					or not _same(battle.state.get("enemyIntent"), expected.get("intent")):
				return _fail("whitefox hound source turn differs: " + path_id)
		checked[path_id] = true
	if checked.size() != 4:
		return _fail("whitefox source does not cover all four paths")
	print("NONCOMBAT_WHITEFOX_LIVE_LOADOUTS_PASS paths=4 natural=true cold=true source=true turns=3")
	quit(0)
