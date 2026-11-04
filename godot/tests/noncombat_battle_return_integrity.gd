extends "res://tests/noncombat_battle_return.gd"

class BrokenBattleArt extends "res://scripts/noncombat_content_repository.gd":
	var mode := ""
	func asset_status(path: String) -> Dictionary:
		var result: Dictionary = super.asset_status(path)
		if not mode.is_empty() and path.contains("battlefield_enc_trial_sword_swift"):
			result["shaVerified"] = false
			result["textureLoadable"] = false
			if mode == "missing":
				result["fileExists"] = false
		return result

func _run() -> void:
	var path := "user://tests/battle_return_integrity_%d.json" % Time.get_ticks_usec()
	var store = Session.new(path, "slot_2")
	var content = BrokenBattleArt.new()
	var game = Domain.new(Registry.new(), store, "slot_2", content)
	if not game.start("sword"):
		return _fail("start failed")
	for step in 7:
		if not game.choose("left", game.issue_choice_token()):
			return _fail("opening failed")
	var before: Dictionary = game.state.duplicate(true)
	var bytes := FileAccess.get_file_as_bytes(store.v2_path)
	var result := _result(game.battle_request(), "defeat")
	var nonterminal: Dictionary = result.duplicate(true)
	nonterminal.postBattleState.terminal = false
	if game.submit_battle_result(nonterminal):
		return _fail("nonterminal result accepted")
	for mode in ["missing", "changed"]:
		content.mode = mode
		if game.submit_battle_result(result) or not _same(game.state, before) \
				or FileAccess.get_file_as_bytes(store.v2_path) != bytes:
			return _fail("unavailable result art mutated state")
	content.mode = ""
	if not game.submit_battle_result(result):
		return _fail("art recovery retry failed")
	var settled: Dictionary = game.state.duplicate(true)
	bytes = FileAccess.get_file_as_bytes(store.v2_path)
	for mode in ["missing", "changed"]:
		var broken = BrokenBattleArt.new()
		broken.mode = mode
		var restored_store = Session.new(path, "slot_2")
		var restored = Domain.new(Registry.new(), restored_store, "slot_2", broken)
		if restored.restore() or not restored.state.is_empty() \
				or restored_store.last_error != ("SOURCE_UNAVAILABLE" if mode == "missing" else "SOURCE_MISMATCH") \
				or FileAccess.get_file_as_bytes(store.v2_path) != bytes:
			return _fail("result art failure was misclassified or overwritten: " + restored_store.last_error)
	for kind in ["outcome", "injury", "warning"]:
		var forged: Dictionary = settled.duplicate(true)
		if kind == "outcome":
			forged.battleResultHistory[0].result.outcome = "flee"
		elif kind == "injury":
			forged.battleResultHistory[0].defeatHealthLoss = 0
		else:
			forged.battleResultHistory[0].warningDirection = "right"
		var forged_path := "user://tests/battle_return_forged_%s_%d.json" % [kind, Time.get_ticks_usec()]
		var forged_store = Session.new(forged_path, "slot_2")
		if forged_store.commit_snapshot(forged, -1).get("ok") != true:
			return _fail("forged envelope fixture could not stage")
		var forged_bytes := FileAccess.get_file_as_bytes(forged_store.v2_path)
		var rejected = Domain.new(Registry.new(), forged_store, "slot_2")
		if rejected.restore() or FileAccess.get_file_as_bytes(forged_store.v2_path) != forged_bytes:
			return _fail("forged settled outcome passed strict replay: " + kind)
	var token: int = game.issue_choice_token()
	store.fail_promotion_once = true
	if game.choose("down", token) or not _same(game.state, settled) \
			or FileAccess.get_file_as_bytes(store.v2_path) != bytes:
		return _fail("down write failure did not roll back")
	if not game.choose("down", token) or game.choose("down", token) or not _reopens(game):
		return _fail("down retry duplicated or failed replay")
	print("NONCOMBAT_BATTLE_RETURN_INTEGRITY_PASS source=true forged=true terminal=true ack_atomic=true")
	quit(0)
