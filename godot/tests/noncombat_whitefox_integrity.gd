extends "res://tests/noncombat_whitefox_battle.gd"

class BrokenSource extends "res://scripts/noncombat_content_repository.gd":
	var mode := ""
	var target := ""
	func source_sha256(module_id: String) -> String:
		if not mode.is_empty() and target == "module:" + module_id:
			return ""
		return super.source_sha256(module_id)
	func module_path(module_id: String) -> String:
		if mode == "missing" and target == "module:" + module_id:
			return ""
		return super.module_path(module_id)
	func asset_status(path: String) -> Dictionary:
		var status: Dictionary = super.asset_status(path)
		if not mode.is_empty() and path == target:
			status.shaVerified = false
			status.textureLoadable = false
			if mode == "missing":
				status.fileExists = false
		return status


func _run() -> void:
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(
		"res://tests/fixtures/whitefox_battle_source.json"))
	var source: Dictionary = fixture.rows[0].sourceCard
	var expected_warning: Dictionary = fixture.rows[0].warning
	var targets := ["module:quests:white_fox", source.sceneImage, expected_warning.sceneImage]
	var file := "user://tests/whitefox_integrity_%d.json" % Time.get_ticks_usec()
	var store = Session.new(file, "slot_2")
	var content := BrokenSource.new()
	var game = Domain.new(Registry.new(), store, "slot_2", content)
	if not _open_third(game, "sword"):
		return _fail("integrity natural third quest route")
	var source_state: Dictionary = game.state.duplicate(true)
	var screen: Control = load("res://scenes/noncombat_opening.tscn").instantiate()
	screen.save_path = ""
	root.add_child(screen)
	await process_frame
	screen.opening = game
	screen._render()
	var button := screen.find_child("Choice_left", true, false)
	if button == null or button.disabled or screen.art_rect.texture == null \
			or screen.art_rect.texture != screen.registry.texture_for(source.sceneImage) \
			or screen.title_label.text != source.title:
		return _fail("desktop whitefox source button/original image/title unavailable")
	button.pressed.emit()
	await process_frame
	if game.state.phase != "WARNING_PENDING" or game.state.turn != source_state.turn \
			or not _same(game.state.questState, source_state.questState):
		return _fail("desktop whitefox left did not open unresolved warning")
	screen._render()
	for direction in ["left", "right"]:
		button = screen.find_child("Choice_" + direction, true, false)
		if button == null or button.disabled or screen.art_rect.texture == null \
				or screen.art_rect.texture != screen.registry.texture_for(expected_warning.sceneImage) \
				or screen.title_label.text != expected_warning.title:
			return _fail("desktop whitefox warning button/original image/title unavailable")
	screen.queue_free()
	await process_frame
	print("WHITEFOX_INTEGRITY_CASE_PASS desktop_source_warning")
	if not _source_cases(game, content, targets, "warning"):
		return
	var before: Dictionary = game.state.duplicate(true)
	var bytes := FileAccess.get_file_as_bytes(store.v2_path)
	var token: int = game.issue_choice_token()
	store.fail_promotion_once = true
	if game.choose("right", token) or not _same(game.state, before) \
			or FileAccess.get_file_as_bytes(store.v2_path) != bytes:
		return _fail("whitefox paid preparation failed-save rollback")
	if not game.choose("right", token) or game.choose("right", token) \
			or game.state.turn != before.turn or not _same(game.state.questState, before.questState) \
			or int(game.state.resources.spiritStone) != int(before.resources.spiritStone) - 10 \
			or int(game.state.attributes.health) != mini(int(before.maxHealth), int(before.attributes.health) + 1):
		return _fail("whitefox paid preparation retry changed task/clock or paid twice")
	var request: Dictionary = game.battle_request()
	if request.is_empty() or not request.has("encounterId") or request.encounterId != null \
			or not _same(request.playerSnapshot.attributes, game.state.attributes) \
			or not _same(request.playerSnapshot.resources, game.state.resources) \
			or not _same(request.playerSnapshot.battleLoadout.deck, before.deck) \
			or not _same(request.playerSnapshot.knowledge, game.state.get("knowledge", {})) \
			or not _same(request.playerSnapshot.modifiers, game.state.get("modifiers", {})) or not _reopens(game):
		return _fail("whitefox paid snapshot/current deck/pending replay")
	print("WHITEFOX_INTEGRITY_CASE_PASS paid_retry_current_deck")
	var result := _result(request, "victory")
	if not _source_cases(game, content, targets, "pending", result):
		return
	var forged_pending: Dictionary = game.state.duplicate(true)
	forged_pending.questState.activeQuests = []
	forged_pending.questState.completedQuests = ["white_fox_line"]
	forged_pending.flags.quest_white_fox_line_active = false
	forged_pending.flags.whiteFoxCompleted = true
	if not _reject_forged(forged_pending, "premature_quest_completion"):
		return
	if not _reopens(game) or not game.submit_battle_result(result):
		return _fail("whitefox repaired source could not settle")
	var settled: Dictionary = game.state.duplicate(true)
	var forged_seed: Dictionary = settled.duplicate(true)
	var found_seed := false
	for seed in forged_seed.karmaSeeds:
		if seed.id == "whiteFox":
			seed.originOutcome = "defeat"
			found_seed = true
	if not found_seed or not _reject_forged(forged_seed, "seed_outcome"):
		return _fail("whitefox seed provenance rejection")
	var forged_history: Dictionary = settled.duplicate(true)
	forged_history.battleResultHistory.append(forged_history.battleResultHistory.back().duplicate(true))
	if not _reject_forged(forged_history, "duplicate_battle_history"):
		return
	if not _reopens(game):
		return _fail("whitefox clean victory no longer reopens")
	print("NONCOMBAT_WHITEFOX_INTEGRITY_PASS desktop=true paid=true source_cases=12 cold_restore=true forged_cases=3 replay=true")
	quit(0)


func _source_cases(game: RefCounted, content: RefCounted, targets: Array,
		stage: String, result: Dictionary = {}) -> bool:
	var before: Dictionary = game.state.duplicate(true)
	var bytes := FileAccess.get_file_as_bytes(game._store.v2_path)
	var token: int = game.issue_choice_token()
	for target in targets:
		content.target = target
		for mode in ["missing", "changed"]:
			content.mode = mode
			var expected := "SOURCE_UNAVAILABLE" if mode == "missing" else "SOURCE_MISMATCH"
			var unavailable: bool = game.get_current_card().is_empty() if stage == "warning" \
				else game.battle_request().is_empty()
			var accepted: bool = game.choose("right", token) if stage == "warning" \
				else game.submit_battle_result(result)
			if not unavailable or accepted or game._store.last_error != expected \
					or not _same(game.state, before) \
					or FileAccess.get_file_as_bytes(game._store.v2_path) != bytes:
				_fail("whitefox live %s %s/%s classification/atomicity: %s" % [
					stage, target, mode, game._store.last_error])
				return false
			var recovered_store = Session.new(game._store.legacy_path, "slot_2")
			var recovered = Domain.new(Registry.new(), recovered_store, "slot_2", content)
			if recovered.restore() or not recovered.state.is_empty() \
					or recovered_store.last_error != expected \
					or not recovered_store.archive_unrestorable().is_empty() \
					or FileAccess.get_file_as_bytes(game._store.v2_path) != bytes:
				_fail("whitefox cold %s %s/%s classification/preservation: %s" % [
					stage, target, mode, recovered_store.last_error])
				return false
			print("WHITEFOX_INTEGRITY_CASE_PASS %s %s %s" % [stage, target, mode])
	content.mode = ""
	return true


func _reject_forged(forged: Dictionary, kind: String) -> bool:
	var store = Session.new("user://tests/whitefox_forged_%s_%d.json" % [
		kind, Time.get_ticks_usec()], "slot_2")
	if store.commit_snapshot(forged, -1).get("ok") != true:
		_fail("whitefox could not stage forged envelope: " + kind)
		return false
	var bytes := FileAccess.get_file_as_bytes(store.v2_path)
	var rejected = Domain.new(Registry.new(), store, "slot_2")
	if rejected.restore() or not rejected.state.is_empty() \
			or FileAccess.get_file_as_bytes(store.v2_path) != bytes:
		_fail("whitefox forged save accepted/mutated: " + kind)
		return false
	print("WHITEFOX_INTEGRITY_CASE_PASS forged " + kind)
	return true
