extends SceneTree

const Registry = preload("res://scripts/runtime_data_registry.gd")
const Domain = preload("res://scripts/noncombat_domain.gd")
const RunSession = preload("res://scripts/noncombat_run_session.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var path := "user://tests/world_registry_%d.json" % Time.get_ticks_usec()
	var game = Domain.new(Registry.new(), RunSession.new(path))
	if not game.start("sword"):
		return _fail("world registry opening could not start")
	var opening: Dictionary = game.state
	if opening.get("worldContinuityActivationIndex") != 0 \
			or opening.get("worldContinuityState", {}).get("npcs", {}).get(
				"bai_ren", {}).get("manifestation") != "PHYSICAL" \
			or opening.get("worldContinuityState", {}).get("npcs", {}).get(
				"jian_linger", {}).get("manifestation") != "PHYSICAL":
		return _fail("core NPCs were not registered at new-run opening")
	var cold = Domain.new(Registry.new(), RunSession.new(path))
	var cold_ok: bool = cold.restore()
	if not cold_ok or JSON.parse_string(JSON.stringify(cold.state)) != JSON.parse_string(
		JSON.stringify(opening)):
		return _fail("opening core NPC registry did not cold restore: " +
			JSON.stringify({"restored": cold_ok, "store": cold._store.last_error,
				"coldKeys": cold.state.keys()}))
	var bad_store = RunSession.new(path + "_bad_sha.json")
	var bad_envelope: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(
		game._store.v2_path))
	bad_envelope.state.worldContinuitySourceSha = "0".repeat(64)
	var bad_bytes := JSON.stringify(bad_envelope)
	var bad_file := FileAccess.open(bad_store.v2_path, FileAccess.WRITE)
	bad_file.store_string(bad_bytes)
	bad_file.close()
	var bad_game = Domain.new(Registry.new(), bad_store)
	if bad_game.restore() or bad_store.last_error != "SOURCE_MISMATCH" \
			or FileAccess.get_file_as_string(bad_store.v2_path) != bad_bytes:
		return _fail("NPC source drift was not locked with original bytes preserved")
	var old_store = RunSession.new(path + "_old.json")
	var envelope: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(
		game._store.v2_path))
	envelope.state.erase("worldContinuityActivationIndex")
	envelope.state.erase("worldContinuitySourceSha")
	envelope.state.erase("worldContinuityState")
	var old_bytes := JSON.stringify(envelope)
	var old_file := FileAccess.open(old_store.v2_path, FileAccess.WRITE)
	old_file.store_string(old_bytes)
	old_file.close()
	var legacy = Domain.new(Registry.new(), old_store)
	if not legacy.restore() or legacy.state.has("worldContinuityState") \
			or not legacy.choose("right", legacy.issue_choice_token()) \
			or legacy.state.get("worldContinuityActivationIndex") != 1 \
			or legacy.state.get("worldContinuityState", {}).get("npcs", {}).get(
				"bai_ren", {}).get("manifestation") != "PHYSICAL" \
			or not Domain.new(Registry.new(), RunSession.new(path + "_old.json")).restore():
		return _fail("old markerless save did not activate registry on next choice")
	print("NONCOMBAT_WORLD_REGISTRY_BOOTSTRAP_PASS opening=true old=true cold=true")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
