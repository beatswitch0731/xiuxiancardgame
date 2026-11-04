extends SceneTree

const Seal = preload("res://scripts/noncombat_browser_combat_seal.gd")
const FIXTURE := "../artifacts/godot-migration/noncombat-browser-import/combat-pending-source-sword.json"


func _initialize() -> void:
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(
		ProjectSettings.globalize_path("res://" + FIXTURE)))
	var verifier = Seal.new()
	if verifier.has_method("verify"):
		return _fail("consistency check exposed as full authority verifier")
	for row in [[0.0000001, "dc2-376c01bb3de77d57"],
			[0.000001, "dc2-8393ef42b6704c20"],
			[1e21, "dc2-67bef7cbef2fd3f8"],
			[-1.5, "dc2-9aa35e14f0e20fcc"],
			[1.23456789, "dc2-564132a09649983f"]]:
		if verifier.compute_seal({"v": row[0]}) != row[1]:
			return _fail("browser source number oracle differs for " + str(row[0]) +
				" as " + verifier.stable_serialize(row[0]))
	if verifier.compute_seal({"edge": "😀", "name": "叶凌云",
			"value": 1.25, "one": 1.0}) != "dc2-651dc32f09a218c4":
		return _fail("browser source UTF-16 or numeric seal oracle differs")
	if verifier.compute_seal({"\uE000": "BMP", "😀": "astral",
			"arr": [1.0, -0.0, 0.000001, 100000000000000000000.0]}) \
			!= "dc2-5be68fa2f1ac9acd":
		return _fail("browser source key-order or boundary number oracle differs")
	for stage in ["pending", "afterReload"]:
		var storage: Dictionary = fixture[stage].storage
		var save: Dictionary = JSON.parse_string(storage.xiuxian_unlocks_slot_2)
		var snapshot: Dictionary = save.causalSessionState.combatSession
		if not verifier.verify_hash_chain(snapshot):
			return _fail("real browser combat snapshot rejected: " + stage)
		var bad: Dictionary = snapshot.duplicate(true)
		bad["authoritySeal"] = "dc2-0000000000000000"
		if verifier.verify_hash_chain(bad):
			return _fail("changed outer seal accepted")
		bad = snapshot.duplicate(true)
		bad["authorityLedger"][0]["hash"] = "dc2-0000000000000000"
		if verifier.verify_hash_chain(bad):
			return _fail("changed ledger hash accepted")
		bad = snapshot.duplicate(true)
		bad["authorityLedger"][bad.authorityLedger.size() - 1]["state"]["qi"] += 1
		if verifier.verify_hash_chain(bad):
			return _fail("changed final ledger state accepted")
		bad = snapshot.duplicate(true)
		bad["authorityLedger"][0]["detail"]["repaired"] = true
		bad["authorityLedger"][0]["hash"] = verifier.compute_seal({
			"ledgerEntry": _unsigned(bad.authorityLedger[0])})
		bad["authoritySeal"] = verifier.compute_seal(bad)
		if verifier.verify_hash_chain(bad):
			return _fail("repaired seal with inconsistent chain accepted")
		bad = snapshot.duplicate(true)
		var last: int = bad.authorityLedger.size() - 1
		bad["authorityLedger"][last]["state"]["qi"] += 1
		bad["authorityLedger"][last]["hash"] = verifier.compute_seal({
			"ledgerEntry": _unsigned(bad.authorityLedger[last])})
		bad["authorityChain"] = bad.authorityLedger[last].hash
		bad["authoritySeal"] = verifier.compute_seal(bad)
		if verifier.verify_hash_chain(bad):
			return _fail("fully repaired final ledger state diverged from snapshot")
		bad = snapshot.duplicate(true)
		bad["authorityLedger"][0]["state"]["qi"] += 1
		var previous := "dc2-root"
		for entry in bad.authorityLedger:
			entry["previous"] = previous
			entry["hash"] = verifier.compute_seal({"ledgerEntry": _unsigned(entry)})
			previous = entry.hash
		bad["authorityChain"] = previous
		bad["authoritySeal"] = verifier.compute_seal(bad)
		# A valid hash chain cannot prove authored combat semantics. The browser
		# rejects this through _validateAuthorityLedgerSemantics at hydration.
		if not verifier.verify_hash_chain(bad):
			return _fail("hash-chain check unexpectedly claims semantic validation")
		bad = snapshot.duplicate(true)
		bad["authorityLedger"].reverse()
		bad["authoritySeal"] = verifier.compute_seal(bad)
		if verifier.verify_hash_chain(bad):
			return _fail("reordered ledger with repaired seal accepted")
	print("PASS noncombat browser combat seal")
	quit(0)


func _fail(reason: String) -> void:
	push_error(reason)
	quit(1)


func _unsigned(entry: Dictionary) -> Dictionary:
	var result := entry.duplicate(true)
	result.erase("hash")
	return result

