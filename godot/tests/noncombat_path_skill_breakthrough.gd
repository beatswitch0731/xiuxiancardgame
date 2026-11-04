extends SceneTree

const Domain = preload("res://scripts/noncombat_domain.gd")
const Registry = preload("res://scripts/runtime_data_registry.gd")
const Content = preload("res://scripts/noncombat_content_repository.gd")
const RealmGate = preload("res://scripts/noncombat_realm_gate_flow.gd")
const Encounter = preload("res://scripts/noncombat_encounter_flow.gd")
const Gateway = preload("res://scripts/noncombat_battle_gateway.gd")
const BattleReturn = preload("res://scripts/noncombat_battle_return_flow.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var game = Domain.new(Registry.new(), null, "slot_3")
	if not game.start("pill"):
		return _fail("pill opening could not start")
	var state: Dictionary = game.state.duplicate(true)
	state["pathSkillActivationIndex"] = 1
	state["phase"] = "FLOW_PENDING"
	state["realm"] = "foundation"
	state["attributes"]["cultivation"] = 100
	state["runClock"]["decisionIndex"] = 1
	state["turn"] = 1
	state["resources"]["pills"]["golden"] = 1
	state["decisionCheckpoint"] = {"sourceCardId": "ch_foundation_80"}
	state["chapterProgress"] = {"version": 1, "activeChapterRealm": "foundation",
		"triggeredMilestones": {"foundation": [20, 40, 60, 80]}}
	state["noncombatFlow"] = {"scope": "first_session_combat",
		"encounterDirectorState": {"realmProgress": {"foundation": {
			"seenCounts": {"ordinary": 2, "relationship": 1, "quest": 0,
				"elite": 1}}}}}
	var content = Content.new()
	var flow = RealmGate.new(content)
	var offered: Dictionary = flow.resume(state)
	if offered.get("currentCardId") != "ch_foundation_100":
		return _fail("foundation gate was not offered")
	var gateway = Gateway.new(Registry.new(), content)
	var encounter = Encounter.new(content, gateway)
	var warned: Dictionary = encounter.accept(offered)
	var prepared: Dictionary = encounter.confirm(warned, "left")
	var request: Dictionary = gateway.build_request(prepared)
	if prepared.get("phase") != "BATTLE_PENDING" or request.is_empty() \
			or int(prepared.resources.pills.get("golden", 0)) != 0:
		return _fail("golden pill was not consumed in warning")
	var result := {"contractVersion": 2,
		"encounterInstanceId": request.encounterInstanceId,
		"sourceCardId": request.sourceCardId,
		"encounterId": request.encounterId,
		"sourceContentHash": request.sourceContentHash,
		"outcome": "victory",
		"combatReceipt": "combat:" + String(request.encounterInstanceId),
		"postBattleState": {"encounterInstanceId": request.encounterInstanceId,
			"terminal": true, "combatPhase": "VICTORY"}}
	var returned: Dictionary = BattleReturn.new(content, gateway).settle(prepared, result)
	if returned.is_empty() or returned.get("battleResultHistory", []).is_empty():
		return _fail("foundation victory did not settle")
	if returned.get("realm") != "golden" \
			or int(returned.get("attributes", {}).get("cultivation", -1)) != 60 \
			or int(returned.battleResultHistory.back().get(
				"breakthroughCultivationBonus", 0)) != 50 \
			or not String(returned.get("pendingBattleResultCard", {}).get("description", "")).contains(
				"入境后额外修为 +50"):
		return _fail("pill path breakthrough bonus did not reach saved result")
	print("NONCOMBAT_PATH_SKILL_BREAKTHROUGH_PASS pill_bonus=50 realm=golden cultivation=60")
	quit(0)


func _fail(message: String) -> void:
	printerr("NONCOMBAT_PATH_SKILL_BREAKTHROUGH_FAIL " + message)
	quit(1)
