extends SceneTree

const Importer = preload("res://scripts/noncombat_browser_opening_import.gd")
const Registry = preload("res://scripts/runtime_data_registry.gd")
const Domain = preload("res://scripts/noncombat_domain.gd")
const RunSession = preload("res://scripts/noncombat_run_session.gd")
const BattleGateway = preload("res://scripts/noncombat_battle_gateway.gd")
const FIXTURE_DIR := "../artifacts/godot-migration/noncombat-browser-import/"
const BATTLE_FIXTURE := "../artifacts/godot-migration/m0-2026-10-15/slots-synthetic-raw.json"

class MemoryStore extends RefCounted:
	var snapshot: Dictionary
	var revision := 0

	func _init(saved: Dictionary) -> void:
		snapshot = saved.duplicate(true)

	func load_snapshot() -> Dictionary:
		return {"state": snapshot.duplicate(true), "revision": revision}

	func commit_snapshot(candidate: Dictionary, expected_revision: int) -> Dictionary:
		if expected_revision != revision:
			return {"ok": false, "error": "REVISION_MISMATCH"}
		snapshot = JSON.parse_string(JSON.stringify(candidate))
		revision += 1
		return {"ok": true, "revision": revision}


func _initialize() -> void:
	var imported = Importer.new()
	var fixture: Dictionary = {}
	for path_id in ["sword", "spell", "body", "pill"]:
		var filename := "opening-source-saves.json" if path_id == "sword" else \
			"opening-source-saves-%s.json" % path_id
		var source: Variant = JSON.parse_string(FileAccess.get_file_as_string(
			_source_path(FIXTURE_DIR + filename)))
		if not source is Dictionary or source.get("source") != "live browser" \
				or source.get("path") != path_id or source.get("snapshots", []).size() != 4:
			return _fail("live browser tutorial exports missing: " + path_id)
		for source_file in source.get("sourceHashes", {}):
			var absolute := _source_path("../" + source_file)
			if FileAccess.get_sha256(absolute) != source.sourceHashes[source_file]:
				return _fail("browser save source changed: " + source_file)
		var final_prepared: Dictionary = {}
		for index in 3:
			var raw := JSON.stringify(source.snapshots[index].storage)
			var prepared: Dictionary = imported.prepare(raw, "slot_1")
			if prepared.get("ok") != true or prepared.get("currentCardId") != \
					source.snapshots[index].visibleCardId:
				return _fail("source %s save cannot replay at decision %d: %s" % [
					path_id, index, JSON.stringify(prepared)])
			if index == 2:
				final_prepared = prepared
		var precombat: Dictionary = imported.prepare(JSON.stringify(
			source.snapshots[3].storage), "slot_1")
		if precombat.get("ok") != true or precombat.get("currentCardId") != \
				source.snapshots[3].visibleCardId:
			return _fail("source %s precombat save cannot replay: %s" % [
				path_id, JSON.stringify(precombat)])
		var normalized: Dictionary = JSON.parse_string(JSON.stringify(
			final_prepared.state))
		var projected = Domain.new(Registry.new(), MemoryStore.new(normalized), "slot_1")
		if not projected.restore() or not projected.choose("left",
				projected.issue_choice_token()):
			return _fail("imported %s path could not continue" % path_id)
		var browser_next: Dictionary = JSON.parse_string(
			source.snapshots[3].storage.xiuxian_unlocks).causalSessionState
		if projected.state.get("currentCardId") != source.snapshots[3].visibleCardId:
			return _fail("imported %s path reached the wrong encounter" % path_id)
		for key in ["turn", "attributes", "deck", "choiceHistory", "runClock"]:
			if JSON.parse_string(JSON.stringify(projected.state.get(key))) != \
					browser_next.get(key):
				return _fail("imported %s next state differs: %s" % [path_id, key])
		if path_id == "sword":
			fixture = source
	var root := "user://browser_opening_import_test_%d" % OS.get_process_id()
	var session = RunSession.new(root + "/noncombat_opening_v1.json", "slot_1")
	var raw_final := JSON.stringify(fixture.snapshots[2].storage)
	var tampered: Dictionary = JSON.parse_string(raw_final)
	var source: Dictionary = JSON.parse_string(tampered.xiuxian_unlocks)
	source.causalSessionState.attributes.cultivation = 99
	tampered.xiuxian_unlocks = JSON.stringify(source)
	if imported.import_to_empty_slot(JSON.stringify(tampered), "slot_1", session).get(
			"error") != "STATE_MISMATCH" or session.has_state_file():
		return _fail("mismatched browser values wrote a Godot slot")
	if imported.import_to_empty_slot(FileAccess.get_file_as_string(
			_source_path(BATTLE_FIXTURE)), "slot_3", RunSession.new(
			root + "/noncombat_opening_slot_3_v1.json", "slot_3")).get(
			"error") != "UNSUPPORTED_IMPORT_BOUNDARY":
		return _fail("active browser combat was treated as a tutorial import")
	var result: Dictionary = imported.import_to_empty_slot(raw_final, "slot_1", session)
	if result.get("ok") != true or not session.has_state_file():
		return _fail("validated tutorial save was not committed")
	var cold = Domain.new(Registry.new(), session, "slot_1")
	if not cold.restore() or cold.get_current_card().get("id") != "q_start_sword" \
			or cold.state.get("attributes", {}).get("cultivation") != 13:
		return _fail("imported tutorial save failed strict cold restore")
	var before := FileAccess.get_file_as_string(session.v2_path)
	if imported.import_to_empty_slot(raw_final, "slot_1", session).get(
			"error") != "DESTINATION_OCCUPIED" \
			or FileAccess.get_file_as_string(session.v2_path) != before:
		return _fail("import overwrote an occupied native slot")
	if not cold.choose("left", cold.issue_choice_token()):
		return _fail("imported next visible decision could not continue")
	if cold.state.get("currentCardId") != fixture.snapshots[3].visibleCardId:
		return _fail("browser and Godot diverged at the next visible card: "
			+ str(cold.state.get("currentCardId"))
			+ " phase=" + str(cold.state.get("phase")))
	var browser_next: Dictionary = JSON.parse_string(
		fixture.snapshots[3].storage.xiuxian_unlocks).causalSessionState
	for key in ["path", "realm", "turn", "attributes", "deck", "choiceHistory",
			"runClock"]:
		if JSON.parse_string(JSON.stringify(cold.state.get(key))) != browser_next.get(key):
			return _fail("browser and Godot diverged after first imported decision: " + key)
	var continued = Domain.new(Registry.new(), session, "slot_1")
	if not continued.restore() or continued.state.get("runClock", {}).get(
			"decisionIndex") != 3:
		return _fail("next decision after import could not cold restore")
	var precombat_session = RunSession.new(root + "_precombat/noncombat_opening_v1.json",
		"slot_1")
	var precombat_raw := JSON.stringify(fixture.snapshots[3].storage)
	var forged_ripple: Dictionary = JSON.parse_string(precombat_raw)
	var forged_source: Dictionary = JSON.parse_string(forged_ripple.xiuxian_unlocks)
	forged_source.causalSessionState.flowState.pendingFlags.ripple.choices.left.effects.cultivation = 99
	forged_ripple.xiuxian_unlocks = JSON.stringify(forged_source)
	if imported.import_to_empty_slot(JSON.stringify(forged_ripple), "slot_1",
			precombat_session).get("field") != "pendingRippleCard" \
			or precombat_session.has_state_file():
		return _fail("forged browser ripple changed an empty Godot slot")
	if imported.import_to_empty_slot(precombat_raw, "slot_1",
			precombat_session).get("ok") != true:
		return _fail("source precombat handoff could not commit to disk")
	var precombat = Domain.new(Registry.new(), precombat_session, "slot_1")
	if not precombat.restore() or precombat.state.get("phase") != "COMBAT_HANDOFF" \
			or precombat.state.get("currentCardId") != fixture.snapshots[3].visibleCardId \
			or not precombat.state.has("pendingRippleCard") \
			or BattleGateway.new(Registry.new()).offer_from_state(
				precombat.state).is_empty():
		return _fail("imported precombat save lost battle offer or ripple on cold read")
	if not precombat.choose("left", precombat.issue_choice_token()):
		return _fail("imported precombat offer could not enter warning")
	var warned = Domain.new(Registry.new(), precombat_session, "slot_1")
	if not warned.restore() or warned.state.get("phase") != "WARNING_PENDING":
		return _fail("imported warning could not cold restore")
	print("NONCOMBAT_BROWSER_OPENING_IMPORT_PASS paths=4 browser=16 cold=true handoff=true continue=true reject=true")
	quit(0)


func _source_path(relative: String) -> String:
	return ProjectSettings.globalize_path("res://").path_join(relative).simplify_path()


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
