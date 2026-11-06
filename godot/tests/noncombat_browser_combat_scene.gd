extends SceneTree

const Importer = preload("res://scripts/noncombat_browser_opening_import.gd")
const Domain = preload("res://scripts/noncombat_domain.gd")
const Registry = preload("res://scripts/runtime_data_registry.gd")
const BattlePlan = preload("res://scripts/battle_plan_resolver.gd")
const BattleScene = preload("res://scenes/main.tscn")
const FIXTURE := "res://tests/fixtures/artifacts/godot-migration/noncombat-browser-import/combat-pending-source-sword.json"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(
		ProjectSettings.globalize_path(FIXTURE)))
	var pending: Dictionary = fixture.pending
	var prepared: Dictionary = Importer.new().prepare(JSON.stringify(pending.storage),
		String(pending.slotId))
	if prepared.get("ok") != true:
		return _fail("source browser combat did not import")
	var cold = Domain.new(Registry.new(), Domain.ReplaySnapshotStore.new(
		JSON.parse_string(JSON.stringify(prepared.state))), String(pending.slotId))
	if not cold.restore():
		return _fail("source combat story contract did not cold restore")
	var request: Dictionary = cold.battle_request()
	var plan: Dictionary = BattlePlan.new(Registry.new()).resolve_persisted(cold.state)
	if request.is_empty() or plan.get("launchAuthorized") != true:
		return _fail("cold battle request or stage not available")
	var battle = BattleScene.instantiate()
	battle.battle_request = request.duplicate(true)
	battle.battle_plan = plan.duplicate(true)
	battle.browser_combat_snapshot = cold.state.browserCombatSnapshot.duplicate(true)
	battle.browser_combat_authority = cold.state.browserCombatAuthority.duplicate(true)
	root.add_child(battle)
	await process_frame
	await process_frame
	if battle.combat == null or battle.combat.state.get("hand") != pending.hand \
			or battle.combat.state.get("qi") != cold.state.browserCombatSnapshot.qi:
		return _fail("main battle scene restarted browser's mid-turn hand")
	if not battle.combat.flee():
		return _fail("main battle scene could not flee from browser state")
	var result: Dictionary = battle.terminal_result()
	if result.get("outcome") != "flee" \
			or result.get("encounterInstanceId") != request.encounterInstanceId:
		return _fail("main battle scene did not return its owned flee receipt")
	battle.queue_free()
	print("NONCOMBAT_BROWSER_COMBAT_SCENE_PASS source=true midturn=true flee=true")
	quit(0)


func _fail(reason: String) -> void:
	push_error(reason)
	quit(1)
