extends SceneTree

const Semantics = preload("res://scripts/noncombat_browser_combat_semantics.gd")
const Seal = preload("res://scripts/noncombat_browser_combat_seal.gd")
const Registry = preload("res://scripts/runtime_data_registry.gd")
const FIXTURE := "res://../artifacts/godot-migration/noncombat-browser-import/combat-pending-source-sword.json"


func _initialize() -> void:
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(
		ProjectSettings.globalize_path(FIXTURE)))
	var verifier = Semantics.new()
	var hash = Seal.new()
	for stage in ["pending", "afterReload"]:
		var save: Dictionary = JSON.parse_string(fixture[stage].storage.xiuxian_unlocks_slot_2)
		var browser: Dictionary = save.causalSessionState
		var snapshot: Dictionary = browser.combatSession
		if not verifier.verify_first_sword_card(snapshot, browser, Registry.new()):
			return _fail("real source combat turn/card semantics rejected: " + stage)
		var forged := snapshot.duplicate(true)
		forged.authorityLedger[0].state.qi += 1
		var previous := "dc2-root"
		for entry in forged.authorityLedger:
			entry["previous"] = previous
			var unsigned: Dictionary = entry.duplicate(true)
			unsigned.erase("hash")
			entry["hash"] = hash.compute_seal({"ledgerEntry": unsigned})
			previous = entry.hash
		forged["authorityChain"] = previous
		forged["authoritySeal"] = hash.compute_seal(forged)
		if not hash.verify_hash_chain(forged):
			return _fail("forgery did not preserve the hash chain")
		if verifier.verify_first_sword_card(forged, browser, Registry.new()):
			return _fail("rehashed forged opening qi accepted")
		forged = snapshot.duplicate(true)
		forged.authorityLedger[0].state.hand.append("sword_guard")
		forged.authorityLedger[1].state.hand.append("sword_guard")
		forged.hand.append("sword_guard")
		previous = "dc2-root"
		for entry in forged.authorityLedger:
			entry["previous"] = previous
			var unsigned: Dictionary = entry.duplicate(true)
			unsigned.erase("hash")
			entry["hash"] = hash.compute_seal({"ledgerEntry": unsigned})
			previous = entry.hash
		forged["authorityChain"] = previous
		forged["authoritySeal"] = hash.compute_seal(forged)
		if not hash.verify_hash_chain(forged):
			return _fail("duplicate-card forgery did not preserve hash chain")
		if verifier.verify_first_sword_card(forged, browser, Registry.new()):
			return _fail("rehashed duplicate opening card accepted")
		forged = snapshot.duplicate(true)
		forged.authorityLedger[0].state.drawPile.clear()
		forged.authorityLedger[1].state.drawPile.clear()
		forged.drawPile.clear()
		previous = "dc2-root"
		for entry in forged.authorityLedger:
			entry["previous"] = previous
			var unsigned: Dictionary = entry.duplicate(true)
			unsigned.erase("hash")
			entry["hash"] = hash.compute_seal({"ledgerEntry": unsigned})
			previous = entry.hash
		forged["authorityChain"] = previous
		forged["authoritySeal"] = hash.compute_seal(forged)
		if not hash.verify_hash_chain(forged):
			return _fail("lost-card forgery did not preserve hash chain")
		if verifier.verify_first_sword_card(forged, browser, Registry.new()):
			return _fail("rehashed lost opening card accepted")
		forged = snapshot.duplicate(true)
		forged.authorityLedger[1].state.enemy.defPower = 100
		forged.enemy.defPower = 100
		previous = "dc2-root"
		for entry in forged.authorityLedger:
			entry["previous"] = previous
			var unsigned: Dictionary = entry.duplicate(true)
			unsigned.erase("hash")
			entry["hash"] = hash.compute_seal({"ledgerEntry": unsigned})
			previous = entry.hash
		forged["authorityChain"] = previous
		forged["authoritySeal"] = hash.compute_seal(forged)
		if not hash.verify_hash_chain(forged):
			return _fail("enemy defense forgery did not preserve hash chain")
		if verifier.verify_first_sword_card(forged, browser, Registry.new()):
			return _fail("rehashed enemy defense forgery accepted")
	print("NONCOMBAT_BROWSER_COMBAT_SEMANTICS_PASS source=2 forged_opening=rejected zones=rejected")
	quit(0)


func _fail(reason: String) -> void:
	push_error(reason)
	quit(1)
