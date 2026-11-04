extends SceneTree

const Registry = preload("res://scripts/runtime_data_registry.gd")
const Domain = preload("res://scripts/noncombat_domain.gd")
const RunSession = preload("res://scripts/noncombat_run_session.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var path := "user://tests/life_transition_%d_slot_3_v1.json" % Time.get_ticks_usec()
	var store = RunSession.new(path, "slot_3")
	var game = Domain.new(Registry.new(), store, "slot_3")
	if not game.start("pill"):
		return _fail("could not seed first life")
	var death: Dictionary = game.state.duplicate(true)
	death["phase"] = "DEATH_PENDING"
	death["currentCardId"] = "death_dao_collapse"
	death["dead"] = true
	death["deadReason"] = "道心崩碎，走火入魔"
	death["deathCauseId"] = "death_dao_collapse"
	death["lifePhase"] = "DYING_NARRATIVE"
	death["lifeCount"] = 0
	death["attributes"]["daoHeart"] = 0
	if store.commit_snapshot(death, 0).get("ok") != true:
		return _fail("could not seed a durable death checkpoint")
	var death_bytes := FileAccess.get_file_as_string(store.v2_path)
	var rebirth: Dictionary = death.duplicate(true)
	rebirth["phase"] = "REBIRTH_PENDING"
	rebirth["currentCardId"] = "rebirth_boon"
	rebirth["dead"] = false
	rebirth["deadReason"] = ""
	rebirth["deathCauseId"] = ""
	rebirth["lifePhase"] = "LEGACY_CHOICE"
	rebirth["lifeCount"] = 1
	rebirth["path"] = null
	rebirth["turn"] = 0
	rebirth["choiceHistory"] = []
	rebirth["replayHistory"] = []
	rebirth["runClock"] = {"version": 1, "lifeId": "slot_3:life:1",
		"decisionIndex": 0, "decisionClockMigrationSource": null, "receipts": {}}
	rebirth["lifeJournal"] = [{"terminalState": death.duplicate(true),
		"deathDirection": "left"}]
	if store.commit_snapshot(rebirth, 1).get("error") != "RUN_IDENTITY_CHANGED" \
			or FileAccess.get_file_as_string(store.v2_path) != death_bytes:
		return _fail("ordinary commit accepted a cross-life identity change")
	var forged_terminal: Dictionary = rebirth.duplicate(true)
	forged_terminal["lifeJournal"][0]["terminalState"]["resources"]["spiritStone"] = 999
	var skipped_life: Dictionary = rebirth.duplicate(true)
	skipped_life["runClock"]["lifeId"] = "slot_3:life:2"
	var wrong_slot: Dictionary = rebirth.duplicate(true)
	wrong_slot["runClock"]["lifeId"] = "slot_2:life:1"
	var stale_clock: Dictionary = rebirth.duplicate(true)
	stale_clock["runClock"]["decisionIndex"] = 1
	if store.commit_life_transition(forged_terminal, 1, "left").get("ok") == true \
			or store.commit_life_transition(skipped_life, 1, "left").get("ok") == true \
			or store.commit_life_transition(wrong_slot, 1, "left").get("ok") == true \
			or store.commit_life_transition(stale_clock, 1, "left").get("ok") == true \
			or store.commit_life_transition(rebirth, 1, "right").get("ok") == true \
			or FileAccess.get_file_as_string(store.v2_path) != death_bytes:
		return _fail("forged death closure or nonsequential new life was committed")
	var failed_store = RunSession.new(path, "slot_3")
	failed_store.fail_promotion_once = true
	if failed_store.commit_life_transition(rebirth, 1, "left").get("ok") == true \
			or FileAccess.get_file_as_string(store.v2_path) != death_bytes:
		return _fail("failed cross-life disk promotion changed the old life")
	if not store.has_method("commit_life_transition") \
			or store.commit_life_transition(rebirth, 1, "left").get("ok") != true:
		return _fail("verified death-to-rebirth handoff could not commit")
	var committed := FileAccess.get_file_as_string(store.v2_path)
	var reopened = RunSession.new(path, "slot_3")
	var loaded: Dictionary = reopened.load_snapshot()
	if int(loaded.get("revision", -1)) != 2 \
			or loaded.get("state", {}).get("runClock", {}).get("lifeId") != "slot_3:life:1" \
			or loaded.get("state", {}).get("lifeJournal", []).size() != 1:
		return _fail("cross-life handoff was not durable on restart")
	var forged: Dictionary = rebirth.duplicate(true)
	forged["lifeJournal"][0]["terminalState"]["attributes"]["daoHeart"] = 10
	if reopened.commit_snapshot(forged, 2).get("ok") == true \
			or reopened.commit_life_transition(rebirth, 2, "left").get("ok") == true \
			or FileAccess.get_file_as_string(store.v2_path) != committed:
		return _fail("completed life was rewritten or transition replayed")
	var same_life: Dictionary = rebirth.duplicate(true)
	same_life["phase"] = "FLOW_PENDING"
	same_life["currentCardId"] = ""
	same_life["runClock"]["decisionIndex"] = 1
	same_life["turn"] = 1
	var continuation: Dictionary = reopened.commit_snapshot(same_life, 2)
	if continuation.get("ok") != true \
			or reopened.load_snapshot().get("state", {}).get("runClock", {}).get(
				"decisionIndex") != 1:
		return _fail("normal decision in the new life was blocked: " +
			JSON.stringify(continuation))
	print("NONCOMBAT_LIFE_TRANSITION_STORE_PASS atomic=true journal=true replay_rejected=true")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
