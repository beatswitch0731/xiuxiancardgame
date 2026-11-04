extends SceneTree

const Inspector = preload("res://scripts/noncombat_browser_save_inspector.gd")
const Importer = preload("res://scripts/noncombat_browser_opening_import.gd")
const Registry = preload("res://scripts/runtime_data_registry.gd")
const Domain = preload("res://scripts/noncombat_domain.gd")
const Session = preload("res://scripts/noncombat_run_session.gd")
const FIXTURE := "res://../artifacts/godot-migration/noncombat-browser-import/combat-pending-source-sword.json"

func _initialize() -> void:
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	var raw := JSON.stringify(source.result.storage)
	var preview: Dictionary = Inspector.new().inspect_text(raw)
	if preview.get("ok") != true or preview.slots[1].get("currentCardId") != \
			"combat_fled_encounter_card_enc_trial_sword_swift":
		return _fail("real slot2 settled browser result failed read-only preview")
	var source_save: Dictionary = JSON.parse_string(source.result.storage.xiuxian_unlocks_slot_2)
	var source_market: Dictionary = source_save.causalSessionState.marketState
	if source_market.get("lastBazaarDecisionIndex") != 6 \
			or source_market.get("nextBazaarDecisionIndex") != 16:
		return _fail("real browser result no longer covers a rescheduled bazaar")
	var importer = Importer.new()
	var prepared: Dictionary = importer.prepare(raw, "slot_2")
	if prepared.get("ok") != true or prepared.get("currentCardId") != \
			source.result.visibleCardId or prepared.get("sourceSha256") != \
			String(source.result.storage.xiuxian_unlocks_slot_2).sha256_text():
		return _fail("real settled browser result was not importable: " + \
			JSON.stringify(prepared).substr(0, 1200))
	for field in ["marketState", "heavensHint", "karmaRipple", "companionProgress"]:
		var malformed_storage: Dictionary = source.result.storage.duplicate(true)
		var malformed_save: Dictionary = JSON.parse_string(
			malformed_storage.xiuxian_unlocks_slot_2)
		malformed_save.causalSessionState[field] = null
		malformed_storage.xiuxian_unlocks_slot_2 = JSON.stringify(malformed_save)
		var rejected: Dictionary = importer.prepare(JSON.stringify(malformed_storage), "slot_2")
		if rejected.get("ok") != false or rejected.get("error") != "UNSUPPORTED_IMPORT_RESULT_STATE":
			return _fail("malformed result state did not return a clean preview rejection: " + field)
	var missing_seeds_storage: Dictionary = source.result.storage.duplicate(true)
	var missing_seeds_save: Dictionary = JSON.parse_string(
		missing_seeds_storage.xiuxian_unlocks_slot_2)
	missing_seeds_save["pendingKarmaSeeds"] = null
	missing_seeds_storage.xiuxian_unlocks_slot_2 = JSON.stringify(missing_seeds_save)
	var missing_seeds: Dictionary = importer.prepare(
		JSON.stringify(missing_seeds_storage), "slot_2")
	if missing_seeds.get("ok") != false or missing_seeds.get("error") != \
			"UNSUPPORTED_IMPORT_RESULT_STATE":
		return _fail("malformed result pending seeds did not return a clean preview rejection")
	for field in ["lifespan", "decisionCheckpoint", "history", "owner", "marketSchedule"]:
		var forged: Dictionary = source.result.storage.duplicate(true)
		var save: Dictionary = JSON.parse_string(forged.xiuxian_unlocks_slot_2)
		match field:
			"lifespan": save.causalSessionState.resources.lifespan += 1
			"decisionCheckpoint": save.causalSessionState.decisionCheckpoint.cardSnapshot.description = "伪造的战果"
			"history": save.causalSessionState.choiceHistory[5].direction = "right"
			"owner":
				var receipts: Dictionary = save.causalSessionState.runClock.receipts
				for key in receipts.keys():
					if receipts[key].get("kind") == "combat":
						receipts[key].token = "foreign-owner"
			"marketSchedule": save.causalSessionState.marketState.lastBazaarDecisionIndex = 5
		forged.xiuxian_unlocks_slot_2 = JSON.stringify(save)
		if importer.prepare(JSON.stringify(forged), "slot_2").get("ok") == true:
			return _fail("forged browser result was accepted: " + field)
	var path := "user://tests/browser_result_import_%d.json" % Time.get_ticks_usec()
	var session = Session.new(path, "slot_2")
	session.fail_promotion_once = true
	var failed: Dictionary = importer.import_to_empty_slot(raw, "slot_2", session)
	if failed.get("ok") == true or FileAccess.file_exists(session.v2_path) \
			or not session.load_state().is_empty() or session.has_state_file():
		return _fail("failed result import wrote a stable or recoverable partial slot")
	var committed: Dictionary = importer.import_to_empty_slot(raw, "slot_2", session)
	if committed.get("ok") != true:
		return _fail("real settled browser result was not committed: " + JSON.stringify(committed))
	var bytes := FileAccess.get_file_as_bytes(session.v2_path)
	var malformed_replacement: Dictionary = source.result.storage.duplicate(true)
	var malformed_replacement_save: Dictionary = JSON.parse_string(
		malformed_replacement.xiuxian_unlocks_slot_2)
	malformed_replacement_save.causalSessionState.marketState = null
	malformed_replacement.xiuxian_unlocks_slot_2 = JSON.stringify(
		malformed_replacement_save)
	if importer.replace_slot(JSON.stringify(malformed_replacement), "slot_2",
			session, 0).get("error") != "UNSUPPORTED_IMPORT_RESULT_STATE" \
			or FileAccess.get_file_as_bytes(session.v2_path) != bytes:
		return _fail("malformed result replacement changed the original native bytes")
	var forged_storage: Dictionary = source.result.storage.duplicate(true)
	var forged_save: Dictionary = JSON.parse_string(forged_storage.xiuxian_unlocks_slot_2)
	forged_save.causalSessionState.attributes.health += 1
	forged_storage.xiuxian_unlocks_slot_2 = JSON.stringify(forged_save)
	if importer.replace_slot(JSON.stringify(forged_storage), "slot_2", session, 0).get("ok") == true \
			or FileAccess.get_file_as_bytes(session.v2_path) != bytes:
		return _fail("forged replacement changed the original native bytes")
	var cold = Domain.new(Registry.new(), Session.new(path, "slot_2"), "slot_2")
	if not cold.restore() or cold.get_current_card().get("id") != source.result.visibleCardId:
		return _fail("settled browser result did not strictly cold restore")
	if not cold.choose("down", cold.issue_choice_token()):
		return _fail("settled browser result could not be acknowledged")
	if cold.state.phase == "FLOW_PENDING" and not cold.resume_flow():
		return _fail("settled browser result did not resume source flow")
	if cold.get_current_card().get("id") != source.next.visibleCardId:
		return _fail("settled browser result did not lead to browser next decision: " + \
			JSON.stringify({"phase": cold.state.phase, "card": cold.get_current_card().get("id")}))
	var next_save: Dictionary = JSON.parse_string(source.next.storage.xiuxian_unlocks_slot_2)
	for field in ["turn", "attributes", "deck"]:
		if JSON.parse_string(JSON.stringify(cold.state.get(field))) != \
				JSON.parse_string(JSON.stringify(next_save.causalSessionState.get(field))):
			return _fail("acknowledged result diverged from browser next " + field)
	var reopened = Domain.new(Registry.new(), Session.new(path, "slot_2"), "slot_2")
	if not reopened.restore() or reopened.get_current_card().get("id") != source.next.visibleCardId:
		return _fail("next browser decision did not strictly cold restore")
	print("NONCOMBAT_BROWSER_COMBAT_RESULT_IMPORT_PASS slot=2 result=true cold=true next=true")
	quit(0)

func _fail(message: String) -> void:
	push_error(message)
	quit(1)
