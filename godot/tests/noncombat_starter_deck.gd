extends SceneTree

const Registry = preload("res://scripts/runtime_data_registry.gd")
const Domain = preload("res://scripts/noncombat_domain.gd")
const RunSession = preload("res://scripts/noncombat_run_session.gd")

class DeckDriftContent extends "res://scripts/noncombat_content_repository.gd":
	func source_sha256(module_id: String) -> String:
		return "f".repeat(64) if module_id == "combat:deck_progression" \
			else super.source_sha256(module_id)

class MutableDeckContent extends "res://scripts/noncombat_content_repository.gd":
	var drift := false
	func source_sha256(module_id: String) -> String:
		return "f".repeat(64) if drift and module_id == "combat:deck_progression" \
			else super.source_sha256(module_id)


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var rules: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(
		"res://content/data/combat/deck_progression.json"))
	for path_id in ["sword", "spell", "body", "pill"]:
		var path := "user://tests/starter_deck_%s_%d.json" % [path_id, Time.get_ticks_usec()]
		var store = RunSession.new(path, "slot_3")
		var game = Domain.new(Registry.new(), store, "slot_3")
		if not game.start(path_id):
			print("start detail store=", store.last_error, " deck=", game._deck_acquisition.last_error, " source=", game._content.errors())
			return _fail("start: " + path_id)
		var starter: Array = rules["paths"][path_id]["starterDeck"]
		if game.state.get("deck") != starter \
				or game.state.get("starterDeckPath") != path_id \
				or game.state.get("deckStateVersion") != 1 \
				or game.state.get("skillAcquisitions") != {}:
			return _fail("starter source deck missing: " + path_id)
		var restored = Domain.new(Registry.new(), RunSession.new(path, "slot_3"), "slot_3")
		if not restored.restore() or restored.state.get("deck") != starter:
			return _fail("starter deck strict reload: " + path_id)
		if path_id == "sword":
			if not _check_live_source_drift():
				return _fail("live deck source drift committed a choice")
			if not _check_old_save_upgrade(store, starter):
				return _fail("old opening deck upgrade")
			if not _check_old_battle_pending(starter):
				return _fail("old battle pending deck replay")
			var drift_store = RunSession.new(path, "slot_3")
			var drift = Domain.new(Registry.new(), drift_store, "slot_3", DeckDriftContent.new())
			var original := FileAccess.get_file_as_string(store.v2_path)
			if drift.restore() or drift_store.last_error != "SOURCE_MISMATCH" \
					or FileAccess.get_file_as_string(store.v2_path) != original:
				return _fail("starter deck source drift accepted")
	print("NONCOMBAT_STARTER_DECK_PASS paths=4 old_save_upgrade=true old_battle_pending=true")
	quit(0)


func _check_old_save_upgrade(current_store: RefCounted, starter: Array) -> bool:
	var envelope: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(current_store.v2_path))
	var old: Dictionary = envelope["state"]
	for key in ["deck", "starterDeckPath", "deckOperations", "skillAcquisitions",
			"deckStateVersion", "deckProgressionSourceSha", "battleCardSourceSha"]:
		old.erase(key)
	var path := "user://tests/starter_deck_old_%d.json" % Time.get_ticks_usec()
	var store = RunSession.new(path, "slot_3")
	var bytes := JSON.stringify(envelope)
	var file := FileAccess.open(store.v2_path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(bytes)
	file.close()
	var restored = Domain.new(Registry.new(), store, "slot_3")
	if not restored.restore() or FileAccess.get_file_as_string(store.v2_path) != bytes \
			or restored.state.has("deck"):
		return false
	var pending: Dictionary = restored.state.duplicate(true)
	var token: int = restored.issue_choice_token()
	restored._store.fail_promotion_once = true
	if restored.choose("left", token) or restored.state != pending \
			or FileAccess.get_file_as_string(store.v2_path) != bytes:
		return false
	if not restored.choose("left", restored.issue_choice_token()) \
			or restored.state.get("deck") != starter \
			or restored.state.get("deckStateVersion") != 1:
		return false
	var upgraded = Domain.new(Registry.new(), RunSession.new(path, "slot_3"), "slot_3")
	return upgraded.restore() and upgraded.state.get("deck") == starter


func _check_live_source_drift() -> bool:
	var path := "user://tests/starter_deck_live_drift_%d.json" % Time.get_ticks_usec()
	var store = RunSession.new(path, "slot_3")
	var content = MutableDeckContent.new()
	var game = Domain.new(Registry.new(), store, "slot_3", content)
	if not game.start("sword"):
		return false
	var before: Dictionary = game.state.duplicate(true)
	var bytes := FileAccess.get_file_as_string(store.v2_path)
	content.drift = true
	if game.choose("left", game.issue_choice_token()) \
			or game.state != before or FileAccess.get_file_as_string(store.v2_path) != bytes:
		return false
	content.drift = false
	return game.choose("left", game.issue_choice_token())


func _check_old_battle_pending(starter: Array) -> bool:
	var path := "user://tests/starter_deck_battle_%d.json" % Time.get_ticks_usec()
	var store = RunSession.new(path, "slot_3")
	var game = Domain.new(Registry.new(), store, "slot_3")
	if not game.start("sword"):
		return false
	for i in 5:
		if not game.choose("left", game.issue_choice_token()):
			return false
	if not game.choose("left", game.issue_choice_token()) \
			or not game.choose("left", game.issue_choice_token()) \
			or game.state.get("phase") != "BATTLE_PENDING":
		return false
	var envelope: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(store.v2_path))
	for key in ["deckStateVersion", "deckProgressionSourceSha", "battleCardSourceSha",
			"deckOperations", "skillAcquisitions"]:
		envelope["state"].erase(key)
	var old_path := "user://tests/starter_deck_old_battle_%d.json" % Time.get_ticks_usec()
	var old_store = RunSession.new(old_path, "slot_3")
	var bytes := JSON.stringify(envelope)
	var file := FileAccess.open(old_store.v2_path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(bytes)
	file.close()
	var restored = Domain.new(Registry.new(), old_store, "slot_3")
	return restored.restore() and restored.state.get("deck") == starter \
		and restored.state.get("phase") == "BATTLE_PENDING" \
		and restored.battle_request().get("sourceCardId") == \
			"encounter_card_enc_trial_sword_swift" \
		and FileAccess.get_file_as_string(old_store.v2_path) == bytes


func _fail(reason: String) -> void:
	push_error(reason)
	quit(1)
