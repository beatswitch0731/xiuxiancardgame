extends SceneTree

const Importer = preload("res://scripts/noncombat_browser_opening_import.gd")
const Staging = preload("res://scripts/noncombat_browser_save_staging.gd")
const Registry = preload("res://scripts/runtime_data_registry.gd")
const Domain = preload("res://scripts/noncombat_domain.gd")
const RunSession = preload("res://scripts/noncombat_run_session.gd")
const FIXTURE := "res://tests/fixtures/artifacts/godot-migration/noncombat-browser-import/mid-source-save-sword.json"
const LONG_FIXTURE := "res://tests/fixtures/artifacts/godot-migration/noncombat-browser-import/mid-source-save-sword-long.json"
const EXTENDED_FIXTURE := "res://tests/fixtures/artifacts/godot-migration/noncombat-browser-import/mid-source-save-sword-extended.json"
const BATTLE_FIXTURE := "res://tests/fixtures/artifacts/godot-migration/m0-2026-10-15/slots-synthetic-raw.json"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var source: Variant = JSON.parse_string(FileAccess.get_file_as_string(
		_source_path(FIXTURE)))
	if not source is Dictionary or source.get("source") != "live browser" \
			or source.get("directions") != ["right", "left", "left", "right", "left"] \
			or source.get("snapshots", []).size() != 6:
		return _fail("live browser middle-run source is missing")
	for filename in source.sourceHashes:
		if FileAccess.get_sha256(_source_path("../" + filename)) != \
				source.sourceHashes[filename]:
			return _fail("browser source changed: " + filename)
	var raw_mid := JSON.stringify(source.snapshots[4].storage)
	var raw_next := JSON.stringify(source.snapshots[5].storage)
	var browser_mid: Dictionary = JSON.parse_string(
		source.snapshots[4].storage.xiuxian_unlocks)
	var browser_next: Dictionary = JSON.parse_string(
		source.snapshots[5].storage.xiuxian_unlocks)
	if browser_mid.get("saveVersion") != 10 \
			or browser_mid.get("causalSessionState", {}).get("version") != 18 \
			or browser_mid.causalSessionState.runClock.decisionIndex != 4 \
			or browser_mid.causalSessionState.get("combatSession") != null \
			or source.snapshots[4].visibleCardId != "promise_result_8f87a81d" \
			or source.snapshots[5].visibleCardId != "ch_qi_20":
		return _fail("fixture is not the captured noncombat avoid boundary")
	var importer = Importer.new()
	var prepared: Dictionary = importer.prepare(raw_mid, "slot_1")
	if prepared.get("ok") != true \
			or prepared.get("currentCardId") != source.snapshots[4].visibleCardId \
			or prepared.get("sourceSha256") != String(
				source.snapshots[4].storage.xiuxian_unlocks).sha256_text() \
			or prepared.get("state", {}).get("phase") != "NARRATIVE_RESULT_PENDING":
		return _fail("real browser middle-run save did not replay: "
			+ JSON.stringify(prepared).substr(0, 220))
	var prepared_next: Dictionary = importer.prepare(raw_next, "slot_1")
	if prepared_next.get("ok") != true \
			or prepared_next.get("currentCardId") != source.snapshots[5].visibleCardId:
		return _fail("real browser first-chapter save did not replay: "
			+ JSON.stringify(prepared_next).substr(0, 220))
	var alternate: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(
		_source_path(LONG_FIXTURE)))
	if alternate.get("source") != "live browser" \
			or alternate.get("directions", []).size() != 10 \
			or alternate.get("snapshots", []).size() != 11:
		return _fail("alternate live browser trace is missing")
	for filename in alternate.sourceHashes:
		if FileAccess.get_sha256(_source_path("../" + filename)) != \
				alternate.sourceHashes[filename]:
			return _fail("alternate browser source changed: " + filename)
	var extended: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(
		_source_path(EXTENDED_FIXTURE)))
	if extended.get("source") != "live browser" \
			or extended.get("directions", []).size() != 15 \
			or extended.get("snapshots", []).size() != 16:
		return _fail("independent extended browser trace is missing")
	for filename in extended.sourceHashes:
		if FileAccess.get_sha256(_source_path("../" + filename)) != \
				extended.sourceHashes[filename]:
			return _fail("extended browser source changed: " + filename)
	for index in [9, 10, 11, 12, 13, 14]:
		var other: Dictionary = importer.prepare(JSON.stringify(
			extended.snapshots[index].storage), "slot_1")
		if other.get("ok") != true or other.get("currentCardId") != \
				extended.snapshots[index].visibleCardId or other.get(
				"state", {}).get("legacyArchive", {}).get(
					"fragmentsBySet", {}).get("heaven_book") != 1 \
				or index >= 13 and other.get("state", {}).get(
					"legacyArchive", {}).get("fragmentsBySet", {}).get("pill_way") != 1:
			return _fail("independent pity set diverged at %d: %s" % [
				index, JSON.stringify(other).substr(0, 200)])
	var forged_second_fragment: Dictionary = extended.snapshots[13].storage.duplicate(true)
	var forged_second_save: Dictionary = JSON.parse_string(
		forged_second_fragment.xiuxian_unlocks)
	forged_second_save.legacyArchive.fragmentsBySet.pill_way = 0
	forged_second_fragment.xiuxian_unlocks = JSON.stringify(forged_second_save)
	if importer.prepare(JSON.stringify(forged_second_fragment), "slot_1").get(
			"error") != "UNSUPPORTED_IMPORT_LEGACY":
		return _fail("forged second pity fragment passed source comparison")
	for index in [13, 14]:
		var forged_market: Dictionary = extended.snapshots[index].storage.duplicate(true)
		var forged_market_save: Dictionary = JSON.parse_string(
			forged_market.xiuxian_unlocks)
		forged_market_save.causalSessionState.flowState.pendingFlags.market.description = \
			"伪造的集市"
		forged_market.xiuxian_unlocks = JSON.stringify(forged_market_save)
		var market_rejection: Dictionary = importer.prepare(
			JSON.stringify(forged_market), "slot_1")
		if market_rejection.get("error") != "STATE_MISMATCH" \
				or market_rejection.get("field") != "pendingMarketCard":
			return _fail("forged queued market passed at %d" % index)
	var forged_ripple: Dictionary = extended.snapshots[12].storage.duplicate(true)
	var forged_ripple_save: Dictionary = JSON.parse_string(forged_ripple.xiuxian_unlocks)
	forged_ripple_save.causalSessionState.karmaRipple.history[0].seedId = "causal:absent"
	forged_ripple.xiuxian_unlocks = JSON.stringify(forged_ripple_save)
	if importer.prepare(JSON.stringify(forged_ripple), "slot_1").get(
			"error") != "UNSUPPORTED_IMPORT_SCHEDULE":
		return _fail("forged ripple seed was accepted")
	for index in [4, 5, 6, 7, 8, 9, 10]:
		var alternate_save: Dictionary = JSON.parse_string(
			alternate.snapshots[index].storage.xiuxian_unlocks)
		if not alternate_save.causalSessionState.flowState.pendingFlags.has("ripple"):
			return _fail("alternate source trace lost its queued ripple")
		var alternate_prepared: Dictionary = importer.prepare(JSON.stringify(
			alternate.snapshots[index].storage), "slot_1")
		if alternate_prepared.get("ok") != true \
				or alternate_prepared.get("currentCardId") != \
					alternate.snapshots[index].visibleCardId:
			return _fail("alternate queued-ripple import diverged at %d: %s" % [
				index, JSON.stringify(alternate_prepared).substr(0, 180)])
	var forged_quest: Dictionary = alternate.snapshots[8].storage.duplicate(true)
	var forged_quest_save: Dictionary = JSON.parse_string(forged_quest.xiuxian_unlocks)
	forged_quest_save.questState.questOutcomes.white_fox_line = "success"
	forged_quest.xiuxian_unlocks = JSON.stringify(forged_quest_save)
	var quest_rejection: Dictionary = importer.prepare(JSON.stringify(
		forged_quest), "slot_1")
	if quest_rejection.get("error") != "STATE_MISMATCH" \
			or quest_rejection.get("field") != "questState":
		return _fail("forged closed quest outcome passed source comparison")
	var forged_fragment: Dictionary = alternate.snapshots[9].storage.duplicate(true)
	var forged_fragment_save: Dictionary = JSON.parse_string(forged_fragment.xiuxian_unlocks)
	forged_fragment_save.legacyArchive.fragmentsBySet.pill_way = 0
	forged_fragment.xiuxian_unlocks = JSON.stringify(forged_fragment_save)
	if importer.prepare(JSON.stringify(forged_fragment), "slot_1").get(
			"error") != "UNSUPPORTED_IMPORT_LEGACY":
		return _fail("forged pity fragment ownership passed source comparison")
	var forged_response: Dictionary = alternate.snapshots[10].storage.duplicate(true)
	var forged_response_save: Dictionary = JSON.parse_string(forged_response.xiuxian_unlocks)
	forged_response_save.causalSessionState.flowState.narrativeQueue[0].card.description = \
		"伪造的师门回应"
	forged_response.xiuxian_unlocks = JSON.stringify(forged_response_save)
	var response_rejection: Dictionary = importer.prepare(JSON.stringify(
		forged_response), "slot_1")
	if response_rejection.get("error") != "STATE_MISMATCH" \
			or response_rejection.get("field") != "visibleCard.description":
		return _fail("forged mentor response passed source comparison")
	var forged: Dictionary = JSON.parse_string(raw_mid)
	var forged_save: Dictionary = JSON.parse_string(forged.xiuxian_unlocks)
	forged_save.causalSessionState.flowState.narrativeQueue[0].card.description = \
		"伪造的回应"
	forged.xiuxian_unlocks = JSON.stringify(forged_save)
	var tampered_text := JSON.stringify(forged)
	var rejected: Dictionary = importer.prepare(tampered_text, "slot_1")
	if rejected.get("error") != "STATE_MISMATCH" \
			or rejected.get("field") != "visibleCard.description":
		return _fail("forged next visible decision passed source comparison")
	var reborn: Dictionary = JSON.parse_string(raw_mid)
	var reborn_save: Dictionary = JSON.parse_string(reborn.xiuxian_unlocks)
	reborn_save.lifeCount = 1
	reborn_save.causalSessionState.lifeCount = 1
	reborn_save.causalSessionState.runClock.lifeId = "slot_1:life:1"
	reborn.xiuxian_unlocks = JSON.stringify(reborn_save)
	if importer.prepare(JSON.stringify(reborn), "slot_1").get("error") != \
			"UNSUPPORTED_IMPORT_BOUNDARY":
		return _fail("cross-life browser save was treated as a first-life import")
	if importer.prepare(FileAccess.get_file_as_string(_source_path(
			BATTLE_FIXTURE)), "slot_3").get("error") != \
			"UNSUPPORTED_IMPORT_BOUNDARY":
		return _fail("active combat browser save was treated as noncombat")
	var root_path := "user://tests/browser_mid_import_%d_%d" % [
		OS.get_process_id(), Time.get_ticks_usec()]
	var staging = Staging.new(root_path)
	if staging.stage_text(raw_mid).get("ok") != true:
		return _fail("source export was not staged independently")
	var staged_path := root_path + "/browser_save_export_v1.json"
	if staging.stage_text("{broken").get("ok") != false \
			or FileAccess.get_file_as_string(staged_path) != raw_mid:
		return _fail("malformed browser export replaced a valid staged source")
	staging.fail_promotion_once = true
	var failed_stage: Dictionary = staging.stage_text(raw_next)
	if failed_stage.get("error") != "PROMOTION_FAILED" \
			or FileAccess.get_file_as_string(staged_path) != raw_mid \
			or FileAccess.get_file_as_string(String(failed_stage.get("backup", ""))) != raw_mid:
		return _fail("failed stage promotion lost the original browser export")
	var session = RunSession.new(root_path + "/noncombat_opening_v1.json", "slot_1")
	var direct_session = RunSession.new(root_path + "/direct5/noncombat_opening_v1.json", "slot_1")
	if importer.import_to_empty_slot(raw_next, "slot_1", direct_session).get(
			"ok") != true:
		return _fail("validated first-chapter export did not commit directly")
	var direct_cold = Domain.new(Registry.new(), direct_session, "slot_1")
	if not direct_cold.restore() or direct_cold.get_current_card().get(
			"id") != source.snapshots[5].visibleCardId \
			or direct_cold.state.get("runClock", {}).get("decisionIndex") != 5:
		return _fail("directly imported first-chapter export failed cold restore")
	var direct_six = RunSession.new(root_path + "/direct6/noncombat_opening_v1.json", "slot_1")
	if importer.import_to_empty_slot(JSON.stringify(alternate.snapshots[6].storage),
			"slot_1", direct_six).get("ok") != true:
		return _fail("validated sixth-decision export did not commit directly")
	var cold_six = Domain.new(Registry.new(), direct_six, "slot_1")
	if not cold_six.restore() or cold_six.get_current_card().get(
			"id") != alternate.snapshots[6].visibleCardId \
			or cold_six.state.get("runClock", {}).get("decisionIndex") != 6:
		return _fail("directly imported sixth-decision export failed cold restore")
	var direct_seven = RunSession.new(root_path + "/direct7/noncombat_opening_v1.json", "slot_1")
	if importer.import_to_empty_slot(JSON.stringify(alternate.snapshots[7].storage),
			"slot_1", direct_seven).get("ok") != true:
		return _fail("validated active white-fox quest export did not commit directly")
	var cold_seven = Domain.new(Registry.new(), direct_seven, "slot_1")
	if not cold_seven.restore() or cold_seven.get_current_card().get(
			"id") != alternate.snapshots[7].visibleCardId \
			or cold_seven.state.get("runClock", {}).get("decisionIndex") != 7 \
			or cold_seven.state.get("questState", {}).get(
				"activeQuests", []).size() != 1:
		return _fail("directly imported active quest failed strict cold restore")
	var direct_eight = RunSession.new(root_path + "/direct8/noncombat_opening_v1.json", "slot_1")
	if importer.import_to_empty_slot(JSON.stringify(alternate.snapshots[8].storage),
			"slot_1", direct_eight).get("ok") != true:
		return _fail("validated closed white-fox quest export did not commit directly")
	var cold_eight = Domain.new(Registry.new(), direct_eight, "slot_1")
	if not cold_eight.restore() or cold_eight.get_current_card().get(
			"id") != alternate.snapshots[8].visibleCardId \
			or cold_eight.state.get("runClock", {}).get("decisionIndex") != 8 \
			or not cold_eight.state.get("questState", {}).get(
				"closedQuests", []).has("white_fox_line") \
			or cold_eight.state.get("questState", {}).get(
				"questOutcomes", {}).get("white_fox_line") != "failed":
		return _fail("directly imported closed quest failed strict cold restore")
	for index in [9, 10]:
		var late_session = RunSession.new(root_path + "/direct%d/noncombat_opening_v1.json" % index,
			"slot_1")
		if importer.import_to_empty_slot(JSON.stringify(alternate.snapshots[index].storage),
				"slot_1", late_session).get("ok") != true:
			return _fail("validated pity fragment export did not commit at %d" % index)
		var late_cold = Domain.new(Registry.new(), late_session, "slot_1")
		if not late_cold.restore() or late_cold.get_current_card().get(
				"id") != alternate.snapshots[index].visibleCardId \
				or late_cold.state.get("legacyArchive", {}).get(
					"fragmentsBySet", {}).get("pill_way") != 1:
			return _fail("pity fragment import failed strict cold restore at %d" % index)
		var other_session = RunSession.new(root_path + "/variant%d/noncombat_opening_v1.json" % index,
			"slot_1")
		if importer.import_to_empty_slot(JSON.stringify(extended.snapshots[index].storage),
				"slot_1", other_session).get("ok") != true:
			return _fail("independent pity set export did not commit at %d" % index)
		var other_cold = Domain.new(Registry.new(), other_session, "slot_1")
		if not other_cold.restore() or other_cold.get_current_card().get(
				"id") != extended.snapshots[index].visibleCardId \
				or other_cold.state.get("legacyArchive", {}).get(
					"fragmentsBySet", {}).get("heaven_book") != 1:
			return _fail("independent pity set failed strict cold restore at %d" % index)
	var eleven_session = RunSession.new(root_path + "/variant11/noncombat_opening_v1.json",
		"slot_1")
	if importer.import_to_empty_slot(JSON.stringify(extended.snapshots[11].storage),
			"slot_1", eleven_session).get("ok") != true:
		return _fail("eleventh-decision export did not commit")
	var eleven_cold = Domain.new(Registry.new(), eleven_session, "slot_1")
	if not eleven_cold.restore() or eleven_cold.get_current_card().get(
			"id") != extended.snapshots[11].visibleCardId \
			or eleven_cold.state.get("legacyRunState", {}).get(
				"ordinaryMissStreak") != 2:
		return _fail("eleventh-decision export failed strict cold restore")
	var twelve_session = RunSession.new(root_path + "/variant12/noncombat_opening_v1.json",
		"slot_1")
	if importer.import_to_empty_slot(JSON.stringify(extended.snapshots[12].storage),
			"slot_1", twelve_session).get("ok") != true:
		return _fail("twelfth-decision ripple export did not commit")
	var twelve_cold = Domain.new(Registry.new(), twelve_session, "slot_1")
	if not twelve_cold.restore() or twelve_cold.get_current_card().get(
			"id") != extended.snapshots[12].visibleCardId \
			or twelve_cold.state.get("karmaRippleState", {}).get(
				"lastRippleTurn") != 12:
		return _fail("twelfth-decision ripple failed strict cold restore")
	for index in [13, 14]:
		var extended_session = RunSession.new(
			root_path + "/variant%d/noncombat_opening_v1.json" % index, "slot_1")
		if importer.import_to_empty_slot(JSON.stringify(extended.snapshots[index].storage),
				"slot_1", extended_session).get("ok") != true:
			return _fail("extended browser export did not commit at %d" % index)
		var extended_cold = Domain.new(Registry.new(), extended_session, "slot_1")
		if not extended_cold.restore() or extended_cold.get_current_card().get(
				"id") != extended.snapshots[index].visibleCardId \
				or extended_cold.state.get("runClock", {}).get(
					"decisionIndex") != index \
				or extended_cold.state.get("legacyArchive", {}).get(
					"fragmentsBySet", {}).get("pill_way") != 1:
			return _fail("extended browser export failed strict cold restore at %d" % index)
	if importer.import_to_empty_slot(tampered_text, "slot_1", session).get(
			"field") != "visibleCard.description" or session.has_state_file():
		return _fail("forged browser decision wrote into the empty native slot")
	var committed: Dictionary = importer.import_to_empty_slot(raw_mid, "slot_1", session)
	if committed.get("ok") != true or not session.has_state_file():
		return _fail("validated browser middle-run source did not commit")
	var cold = Domain.new(Registry.new(), session, "slot_1")
	if not cold.restore() or cold.state.get("phase") != "NARRATIVE_RESULT_PENDING" \
			or cold.get_current_card().get("id") != source.snapshots[4].visibleCardId \
			or cold.state.get("knowledge", {}).get("world") != 1:
		return _fail("imported browser middle-run save failed cold restore")
	var native_bytes := FileAccess.get_file_as_string(session.v2_path)
	if importer.import_to_empty_slot(raw_mid, "slot_1", session).get(
			"error") != "DESTINATION_OCCUPIED" \
			or FileAccess.get_file_as_string(session.v2_path) != native_bytes:
		return _fail("browser import overwrote an occupied native slot")
	if not cold.choose("left", cold.issue_choice_token()):
		return _fail("imported browser response could not continue")
	if cold.state.get("phase") == "FLOW_PENDING" and not cold.resume_flow():
		return _fail("imported browser response could not draw its next card")
	if cold.get_current_card().get("id") != source.snapshots[5].visibleCardId:
		return _fail("next visible card diverged from the browser source")
	for key in ["turn", "attributes", "deck", "choiceHistory", "runClock"]:
		if not _same_json(cold.state.get(key), browser_next.causalSessionState.get(key)):
			return _fail("next browser decision diverged: " + key)
	var resumed = Domain.new(Registry.new(), session, "slot_1")
	if not resumed.restore() or resumed.get_current_card().get("id") != \
			source.snapshots[5].visibleCardId:
		return _fail("next visible decision could not cold restore")
	print("NONCOMBAT_BROWSER_MID_IMPORT_PASS source=save10/causal18 decisions=4-14 quest=active,closed pity=two-sets ripple=true cold=true atomic=true reject=true")
	quit(0)


func _source_path(relative: String) -> String:
	# 内化后常量是 res:// 虚拟路径，不能再 path_join 到绝对根上；
	# 相对路径（历史写法）仍需拼绝对根才能被 FileAccess 打开。
	if relative.begins_with("res://"):
		return relative
	return ProjectSettings.globalize_path("res://").path_join(relative).simplify_path()


func _same_json(left: Variant, right: Variant) -> bool:
	return JSON.parse_string(JSON.stringify(left)) == JSON.parse_string(JSON.stringify(right))


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
