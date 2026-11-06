extends SceneTree

const Importer = preload("res://scripts/noncombat_browser_opening_import.gd")
const Domain = preload("res://scripts/noncombat_domain.gd")
const Combat = preload("res://scripts/combat_domain.gd")
const Registry = preload("res://scripts/runtime_data_registry.gd")
const BattlePlan = preload("res://scripts/battle_plan_resolver.gd")
const Seal = preload("res://scripts/noncombat_browser_combat_seal.gd")
const SOURCE := "res://tests/fixtures/artifacts/godot-migration/noncombat-browser-import/combat-pending-source-sword.json"
const TURN := "res://tests/fixtures/artifacts/godot-migration/noncombat-browser-import/combat-turn-source-sword.json"


func _initialize() -> void:
	var original: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(
		ProjectSettings.globalize_path(SOURCE)))
	var turn: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(
		ProjectSettings.globalize_path(TURN)))
	if turn.get("source") != "live browser public UI" \
			or turn.get("sourceFixtureSha256") != FileAccess.get_sha256(
				ProjectSettings.globalize_path(SOURCE)) \
			or turn.get("randomObservations", []).size() != 5:
		return _fail("real browser enemy-turn source or RNG observations unavailable")
	for stage in ["initial", "secondCard", "thirdCard", "reactionOpen",
			"enemyResolved"]:
		if not Seal.new().verify_hash_chain(turn.get("states", {}).get(
				stage, {}).get("combat", {})):
			return _fail("captured browser turn stage seal failed: " + stage)
	var pending: Dictionary = original.pending
	var imported: Dictionary = Importer.new().prepare(JSON.stringify(pending.storage),
		String(pending.slotId))
	if imported.get("ok") != true:
		return _fail("original browser first-sword source no longer imports")
	var story = Domain.new(Registry.new(), null, String(pending.slotId))
	story.state = imported.state.duplicate(true)
	var request: Dictionary = story.battle_request()
	var plan: Dictionary = BattlePlan.new(Registry.new()).resolve_persisted(story.state)
	var combat = Combat.new(Registry.new())
	if not combat.load_persisted_request(request, plan) \
			or not combat.load_browser_first_sword_snapshot(story.state.browserCombatSnapshot,
				story.state.browserCombatAuthority, request):
		return _fail("source first-turn state did not hydrate")
	var random_values: Array = []
	for observation in turn.randomObservations:
		random_values.append(observation.value)
	var edge_index: int = combat.state.hand.find("sword_edge")
	if not combat.set_replay_random_values(random_values) \
			or edge_index < 0 or not combat.play_card(edge_index) \
			or not combat.play_card(combat.state.hand.find("sword_followthrough")) \
			or not combat.end_turn():
		return _fail("Godot did not reach browser's reaction-open boundary")
	if not _matches(combat.state, turn.states.reactionOpen.combat) \
			or combat.replay_random_remaining() != 5:
		return _fail("Godot reaction-open state diverged from real browser source")
	if not combat.choose_reaction("TAKE_HIT") \
			or not _matches(combat.state, turn.states.enemyResolved.combat) \
			or combat.replay_random_remaining() != 0:
		return _fail("Godot enemy action or 5-call random tape diverged from browser")
	if not story.has_method("commit_browser_combat_end_turn"):
		return _fail("browser-authored end turn has no durable story-slot owner")
	print("NONCOMBAT_BROWSER_COMBAT_ENEMY_TURN_COLD_PASS browser=true rng=5 cold=true")
	quit(0)


func _matches(godot: Dictionary, browser: Dictionary) -> bool:
	for key in ["phase", "turn", "qi", "hand", "drawPile", "discardPile",
			"exhaustPile", "playerStatus", "enemyStatus", "enemyIntent"]:
		if JSON.parse_string(JSON.stringify(godot.get(key))) \
				!= JSON.parse_string(JSON.stringify(browser.get(key))):
			print("SOURCE_MISMATCH ", key, " godot=", JSON.stringify(godot.get(key)),
				" browser=", JSON.stringify(browser.get(key)))
			return false
	for key in ["hp", "block", "maxHp"]:
		if godot.get("player", {}).get(key) != browser.get("player", {}).get(key):
			print("SOURCE_MISMATCH player.", key)
			return false
	for key in ["hp", "block", "maxHp", "planRuntime"]:
		if JSON.parse_string(JSON.stringify(godot.get("enemy", {}).get(key))) \
				!= JSON.parse_string(JSON.stringify(browser.get("enemy", {}).get(key))):
			print("SOURCE_MISMATCH enemy.", key, " godot=",
				JSON.stringify(godot.get("enemy", {}).get(key)), " browser=",
				JSON.stringify(browser.get("enemy", {}).get(key)))
			return false
	return true


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
