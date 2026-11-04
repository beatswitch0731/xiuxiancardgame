extends SceneTree

const Importer = preload("res://scripts/noncombat_browser_opening_import.gd")
const Domain = preload("res://scripts/noncombat_domain.gd")
const Registry = preload("res://scripts/runtime_data_registry.gd")
const BattlePlan = preload("res://scripts/battle_plan_resolver.gd")
const Combat = preload("res://scripts/combat_domain.gd")
const Seal = preload("res://scripts/noncombat_browser_combat_seal.gd")
const RunSession = preload("res://scripts/noncombat_run_session.gd")
const FIXTURE := "res://../artifacts/godot-migration/noncombat-browser-import/combat-pending-source-sword.json"


func _initialize() -> void:
	var source: Variant = JSON.parse_string(FileAccess.get_file_as_string(
		ProjectSettings.globalize_path(FIXTURE)))
	if not source is Dictionary or source.get("source") != "live browser public UI" \
			or source.get("pending", {}).get("active") != true:
		return _fail("real browser combat-pending source fixture unavailable")
	var pending: Dictionary = source.pending
	var prepared: Dictionary = Importer.new().prepare(JSON.stringify(pending.storage),
		String(pending.slotId))
	if prepared.get("ok") != true:
		return _fail("live browser combat pending import rejected: " + String(
			prepared.get("error", "UNKNOWN")) + "/" + String(prepared.get("field", "")))
	var malformed_storage: Dictionary = pending.storage.duplicate(true)
	var malformed_save: Dictionary = JSON.parse_string(
		malformed_storage.xiuxian_unlocks_slot_2)
	malformed_save["questState"] = null
	malformed_storage.xiuxian_unlocks_slot_2 = JSON.stringify(malformed_save)
	var rejected: Dictionary = Importer.new().prepare(JSON.stringify(malformed_storage),
		String(pending.slotId))
	if rejected.get("ok") != false or rejected.get("error") != \
			"UNSUPPORTED_IMPORT_COMBAT_STATE":
		return _fail("malformed pending quest did not return a clean preview rejection")
	var state: Dictionary = prepared.get("state", {})
	var game = Domain.new(Registry.new(), null, String(pending.slotId))
	game.state = state.duplicate(true)
	var request: Dictionary = game.battle_request()
	if state.get("phase") != "BATTLE_PENDING" \
			or request.get("sourceCardId") != pending.originalCardId \
			or state.get("runClock", {}).get("decisionIndex") != pending.decisionIndex:
		return _fail("import did not preserve battle ownership and decision clock")
	var cold = Domain.new(Registry.new(), Domain.ReplaySnapshotStore.new(
		JSON.parse_string(JSON.stringify(state))), String(pending.slotId))
	var restored := cold.restore()
	var cold_request: Dictionary = cold.battle_request()
	if not restored or cold_request.get("encounterInstanceId") \
			!= request.get("encounterInstanceId") \
			or cold_request.get("sourceCardId") != request.get("sourceCardId") \
			or cold_request.get("sourceContentHash") != request.get("sourceContentHash"):
		return _fail("imported active combat could not cold restore its story contract")
	var split_state: Dictionary = state.duplicate(true)
	split_state.browserCombatAuthority.attributes.health = 4
	var split_combat: Dictionary = split_state.browserCombatSnapshot
	split_combat.preCombatHealth = 4
	for entry in split_combat.authorityLedger:
		entry.state.player.hp = 4
	split_combat.player.hp = 4
	var split_hash = Seal.new()
	var split_previous := "dc2-root"
	for entry in split_combat.authorityLedger:
		entry["previous"] = split_previous
		var split_unsigned: Dictionary = entry.duplicate(true)
		split_unsigned.erase("hash")
		entry["hash"] = split_hash.compute_seal({"ledgerEntry": split_unsigned})
		split_previous = entry.hash
	split_combat["authorityChain"] = split_previous
	split_combat["authoritySeal"] = split_hash.compute_seal(split_combat)
	var split_cold = Domain.new(Registry.new(), Domain.ReplaySnapshotStore.new(
		JSON.parse_string(JSON.stringify(split_state))), String(pending.slotId))
	if not split_hash.verify_hash_chain(split_combat) or split_cold.restore():
		return _fail("combat authority split from replayed world health was accepted")
	var plan: Dictionary = BattlePlan.new(Registry.new()).resolve_persisted(cold.state)
	var battle = Combat.new(Registry.new())
	if plan.get("launchAuthorized") != true \
			or not battle.load_persisted_request(cold_request, plan) \
			or not battle.load_browser_first_sword_snapshot(
				cold.state.browserCombatSnapshot,
				cold.state.browserCombatAuthority, cold_request) \
			or battle.state.get("hand") != pending.hand \
			or battle.state.get("qi") != cold.state.browserCombatSnapshot.qi:
		return _fail("cold battle did not resume the browser's actual card and qi state")
	if not battle.flee():
		return _fail("browser imported battle could not flee from its mid-turn state")
	var owner := String(cold_request.encounterInstanceId)
	var result := {"contractVersion": cold_request.contractVersion,
		"encounterInstanceId": owner,
		"sourceCardId": cold_request.sourceCardId,
		"encounterId": cold_request.encounterId,
		"sourceContentHash": cold_request.sourceContentHash,
		"outcome": "flee", "combatReceipt": "combat:" + owner,
		"postBattleState": {"encounterInstanceId": owner, "terminal": true,
			"combatPhase": "FLEE", "playerHp": battle.state.player.hp,
			"enemyHp": battle.state.enemy.hp, "turn": battle.state.turn}}
	var settle = Domain.new(Registry.new(), null, String(pending.slotId))
	settle.state = cold.state.duplicate(true)
	if not settle.submit_battle_result(result) or settle.submit_battle_result(result):
		return _fail("imported battle flee failed or settled twice")
	var after_flee = Domain.new(Registry.new(), Domain.ReplaySnapshotStore.new(
		JSON.parse_string(JSON.stringify(settle.state))), String(pending.slotId))
	if not after_flee.restore() or after_flee.get_current_card().get("id") \
			!= source.result.visibleCardId:
		return _fail("imported battle flee result could not cold restore")
	var forged_storage: Dictionary = pending.storage.duplicate(true)
	var forged_save: Dictionary = JSON.parse_string(forged_storage.xiuxian_unlocks_slot_2)
	var forged: Dictionary = forged_save.causalSessionState.combatSession
	forged.authorityLedger[0].state.qi += 1
	var hash = Seal.new()
	var previous := "dc2-root"
	for entry in forged.authorityLedger:
		entry["previous"] = previous
		var unsigned: Dictionary = entry.duplicate(true)
		unsigned.erase("hash")
		entry["hash"] = hash.compute_seal({"ledgerEntry": unsigned})
		previous = entry.hash
	forged["authorityChain"] = previous
	forged["authoritySeal"] = hash.compute_seal(forged)
	forged_storage.xiuxian_unlocks_slot_2 = JSON.stringify(forged_save)
	var forged_raw := JSON.stringify(forged_storage)
	if not hash.verify_hash_chain(forged) \
			or Importer.new().prepare(forged_raw, String(pending.slotId)).get("ok") == true:
		return _fail("fully rehashed forged browser import was accepted")
	var forged_defense_storage: Dictionary = pending.storage.duplicate(true)
	var forged_defense_save: Dictionary = JSON.parse_string(
		forged_defense_storage.xiuxian_unlocks_slot_2)
	var forged_defense: Dictionary = forged_defense_save.causalSessionState.combatSession
	forged_defense.authorityLedger[1].state.enemy.defPower = 100
	forged_defense.enemy.defPower = 100
	previous = "dc2-root"
	for entry in forged_defense.authorityLedger:
		entry["previous"] = previous
		var unsigned: Dictionary = entry.duplicate(true)
		unsigned.erase("hash")
		entry["hash"] = hash.compute_seal({"ledgerEntry": unsigned})
		previous = entry.hash
	forged_defense["authorityChain"] = previous
	forged_defense["authoritySeal"] = hash.compute_seal(forged_defense)
	forged_defense_storage.xiuxian_unlocks_slot_2 = JSON.stringify(forged_defense_save)
	if not hash.verify_hash_chain(forged_defense) \
			or Importer.new().prepare(JSON.stringify(forged_defense_storage),
				String(pending.slotId)).get("ok") == true:
		return _fail("fully rehashed enemy defense browser import was accepted")
	var item_storage: Dictionary = pending.storage.duplicate(true)
	var item_save: Dictionary = JSON.parse_string(item_storage.xiuxian_unlocks_slot_2)
	item_save.causalSessionState.itemInventory = {"unmapped_gift": 1}
	item_storage.xiuxian_unlocks_slot_2 = JSON.stringify(item_save)
	if Importer.new().prepare(JSON.stringify(item_storage),
			String(pending.slotId)).get("ok") == true:
		return _fail("browser combat import silently dropped owned inventory")
	var test_root := "user://tests/browser_combat_import_%d_%d" % [
		OS.get_process_id(), Time.get_ticks_usec()]
	var session = RunSession.new(test_root + "/noncombat_opening_v1.json",
		String(pending.slotId))
	var importer = Importer.new()
	if importer.import_to_empty_slot(JSON.stringify(pending.storage),
			String(pending.slotId), session).get("ok") != true:
		return _fail("genuine browser combat could not seed native slot")
	var original_bytes := FileAccess.get_file_as_string(session.v2_path)
	if importer.replace_slot(forged_raw, String(pending.slotId), session, 0).get(
			"ok") == true or FileAccess.get_file_as_string(session.v2_path) \
			!= original_bytes:
		return _fail("forged browser combat changed an occupied native slot")
	print("NONCOMBAT_BROWSER_COMBAT_PENDING_IMPORT_PASS source=true owner=true pending=true")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
