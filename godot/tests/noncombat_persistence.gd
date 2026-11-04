extends SceneTree

const Registry = preload("res://scripts/runtime_data_registry.gd")
const Domain = preload("res://scripts/noncombat_domain.gd")
const Store = preload("res://scripts/noncombat_opening_store.gd")
const ContentRepository = preload("res://scripts/noncombat_content_repository.gd")


func _initialize() -> void:
	var path := "user://tests/noncombat_opening_%d.json" % Time.get_ticks_usec()
	var store = Store.new(path)
	var game = Domain.new(Registry.new(), store)
	if not game.start("sword"):
		_fail("first source path did not persist")
		return
	var token: int = game.issue_choice_token()
	if not game.choose("right", token):
		_fail("source tutorial choice did not commit")
		return
	var clock: Dictionary = game.state.get("runClock", {})
	var history: Array = game.state.get("choiceHistory", [])
	var receipt_token := "decision:slot_1:life:0:choice:tutorial_1:1"
	if game.state.get("turn") != 1 or clock.get("decisionIndex") != 1 \
			or not clock.get("receipts", {}).has(receipt_token) \
			or history.size() != 1 or history[0].get("turn") != 0 \
			or history[0].get("decisionIndex") != 1 \
			or game.state.get("recentCardTags") != ["tutorial"] \
			or game.state.get("decisionCheckpoint", {}).get("cardId") != "tutorial_4":
		_fail("source decision history, clock, receipt or checkpoint diverged")
		return
	var reopened = Domain.new(Registry.new(), Store.new(path))
	var restored: bool = reopened.restore()
	if not restored or not _same_state(reopened.state, game.state) \
			or reopened.get_current_card().get("id") != "tutorial_4":
		_fail("committed choice did not survive reopen")
		return
	if reopened.choose("left", token) or not _same_state(reopened.state, game.state):
		_fail("stale choice replay changed reopened state")
		return
	var next_token: int = reopened.issue_choice_token()
	reopened._store.path = "user://"
	if reopened.choose("left", next_token) or not _same_state(reopened.state, game.state):
		_fail("failed choice save mutated the authoritative state")
		return
	reopened._store.path = path
	if not reopened.choose("left", next_token):
		_fail("reopened tutorial could not reach source starter")
		return
	var after_boundary = Domain.new(Registry.new(), Store.new(path))
	if not after_boundary.restore() or after_boundary.state.get("phase") != "STARTER_BOUNDARY" \
			or after_boundary.get_current_card().get("id") != "q_start_sword" \
			or after_boundary.issue_choice_token() <= 0:
		_fail("tutorial completion boundary did not survive reopen")
		return
	var manifest: Dictionary = JSON.parse_string(
		FileAccess.get_file_as_string("res://content/source_manifest.json"))
	for entry in manifest["data"]:
		if entry.get("path") == "data/progression/first_session_cohesion.json":
			entry["sha256"] = "0".repeat(64)
			break
	var corrupt_manifest_path := "user://tests/noncombat_corrupt_route_manifest.json"
	var corrupt_file := FileAccess.open(corrupt_manifest_path, FileAccess.WRITE)
	corrupt_file.store_string(JSON.stringify(manifest))
	corrupt_file.close()
	var before_state: Dictionary = after_boundary.state.duplicate(true)
	var before_bytes := FileAccess.get_file_as_string(path)
	after_boundary._content = ContentRepository.new(corrupt_manifest_path)
	if after_boundary.choose("right", after_boundary.issue_choice_token()) \
			or not _same_state(after_boundary.state, before_state) \
			or FileAccess.get_file_as_string(path) != before_bytes:
		_fail("corrupt source route committed a prologue decision or changed the save")
		return
	after_boundary._content = ContentRepository.new()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(corrupt_manifest_path))
	var prologue_token: int = after_boundary.issue_choice_token()
	if not after_boundary.choose("right", prologue_token):
		_fail("saved source prologue could not settle")
		return
	var after_handoff = Domain.new(Registry.new(), Store.new(path))
	if not after_handoff.restore() or not _same_state(after_handoff.state, after_boundary.state) \
			or after_handoff.state.get("phase") != "COMBAT_HANDOFF" \
			or after_handoff.state.get("currentCardId") != "encounter_card_enc_trial_sword_swift" \
			or after_handoff.issue_choice_token() <= 0:
		_fail("source prologue consequence or encounter offer did not survive reopen")
		return
	var bad_store = Store.new("user://")
	var rejected = Domain.new(Registry.new(), bad_store)
	if rejected.start("sword") or not rejected.state.is_empty():
		_fail("failed disk write was exposed as a started life")
		return
	var damaged_path := "user://tests/noncombat_damaged_%d.json" % Time.get_ticks_usec()
	var damaged_file := FileAccess.open(damaged_path, FileAccess.WRITE)
	damaged_file.store_string("{broken raw save")
	damaged_file.close()
	var damaged_store = Store.new(damaged_path)
	if damaged_store.save_state(game.state) or Domain.new(Registry.new(), damaged_store).restore():
		_fail("damaged original save was overwritten or accepted")
		return
	var archived: String = damaged_store.archive_unrestorable()
	if archived.is_empty() or FileAccess.file_exists(damaged_path) \
			or FileAccess.get_file_as_string(archived) != "{broken raw save":
		_fail("damaged original save was not preserved byte for byte")
		return
	print("NONCOMBAT_PERSISTENCE_PASS history=1 receipt=1 reopen=2 rollback=true archive=true")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)


func _same_state(left: Dictionary, right: Dictionary) -> bool:
	return JSON.parse_string(JSON.stringify(left)) == JSON.parse_string(JSON.stringify(right))
