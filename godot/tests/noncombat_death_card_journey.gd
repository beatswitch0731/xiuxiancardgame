extends SceneTree

const Registry = preload("res://scripts/runtime_data_registry.gd")
const Domain = preload("res://scripts/noncombat_domain.gd")
const RunSession = preload("res://scripts/noncombat_run_session.gd")
const ContentRepository = preload("res://scripts/noncombat_content_repository.gd")
const FIXTURE := "res://tests/fixtures/pill_decision54_death_probe_v2.json"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var path := "user://tests/death_card_%d_slot_3_v1.json" % Time.get_ticks_usec()
	var store = RunSession.new(path, "slot_3")
	if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(
			store.v2_path).get_base_dir()) != OK:
		return _fail("death checkpoint directory unavailable")
	var file := FileAccess.open(store.v2_path, FileAccess.WRITE)
	if file == null:
		return _fail("death checkpoint fixture unavailable")
	file.store_string(FileAccess.get_file_as_string(FIXTURE))
	file.close()
	var original_bytes := FileAccess.get_file_as_string(store.v2_path)
	var unknown_path := "user://tests/death_unknown_pin_%d.json" % Time.get_ticks_usec()
	var unknown_store = RunSession.new(unknown_path, "slot_3")
	var unknown_record: Dictionary = JSON.parse_string(original_bytes)
	unknown_record.state.normalFlow.choiceRuleSha = "f".repeat(64)
	var unknown_file := FileAccess.open(unknown_store.v2_path, FileAccess.WRITE)
	if unknown_file == null:
		return _fail("unknown pin fixture unavailable")
	unknown_file.store_string(JSON.stringify(unknown_record))
	unknown_file.close()
	var unknown_bytes := FileAccess.get_file_as_string(unknown_store.v2_path)
	if Domain.new(Registry.new(), unknown_store, "slot_3").restore() \
			or unknown_store.last_error != "SOURCE_MISMATCH" \
			or FileAccess.get_file_as_string(unknown_store.v2_path) != unknown_bytes:
		return _fail("unknown choice-rule pin was accepted or rewrote the old save")
	var tampered_path := "user://tests/death_tampered_%d.json" % Time.get_ticks_usec()
	var tampered_store = RunSession.new(tampered_path, "slot_3")
	var tampered_record: Dictionary = JSON.parse_string(original_bytes)
	tampered_record.state.replayHistory[9].cardId = "q_meditation"
	var tampered_file := FileAccess.open(tampered_store.v2_path, FileAccess.WRITE)
	if tampered_file == null:
		return _fail("tampered history fixture unavailable")
	tampered_file.store_string(JSON.stringify(tampered_record))
	tampered_file.close()
	var tampered_bytes := FileAccess.get_file_as_string(tampered_store.v2_path)
	var tampered_restored := Domain.new(Registry.new(), tampered_store, "slot_3").restore()
	if tampered_restored \
			or FileAccess.get_file_as_string(tampered_store.v2_path) != tampered_bytes:
		return _fail("old pin bypassed strict history replay")
	var game = Domain.new(Registry.new(), store, "slot_3")
	_stabilize_ambient(game)
	if not game.restore() or FileAccess.get_file_as_string(store.v2_path) != original_bytes:
		return _fail("old choice-rule pin did not strictly restore without rewriting bytes: " \
			+ store.last_error)
	if game.state.get("phase") != "FLOW_PENDING" \
			or not game.resume_flow() or game.get_current_card().get("id") != "q_love":
		return _fail("source love checkpoint did not strictly restore and draw: " \
			+ store.last_error)
	var token := game.issue_choice_token()
	var before: Dictionary = game.state.duplicate(true)
	var before_bytes := FileAccess.get_file_as_string(store.v2_path)
	store.fail_promotion_once = true
	if token <= 0 or game.choose("right", token) or game.state != before \
			or FileAccess.get_file_as_string(store.v2_path) != before_bytes:
		return _fail("failed death write changed state or active save bytes")
	if not game.choose("right", token):
		return _fail("source fatal love choice was not executable")
	var death_card: Dictionary = game.get_current_card()
	var death_state: Dictionary = game.state
	if death_state.get("normalFlow", {}).get("choiceRuleSha") != \
			"73d5038d1427433134a644e314d9d501d772c0ba79f67f61f9a46c3e4f8e093b":
		return _fail("first live choice did not upgrade the old choice-rule pin")
	var core_sha := ContentRepository.new().source_sha256("npcs:core")
	if not death_state.get("worldContinuityState", {}).get("npcs", {}).has("mortal") \
			or not death_state.has("worldContinuityActivationIndex") \
			or death_state.get("worldContinuitySourceSha") != core_sha \
			or death_state.get("noncombatFlow", {}).get("npcSourceSha") != core_sha:
		return _fail("old NPC world did not upgrade to current source on real choice")
	var art: Dictionary = ContentRepository.new().card_scene_image_status(
		"death_dao_collapse")
	if death_state.get("phase") != "DEATH_PENDING" \
			or death_state.get("lifePhase") != "DYING_NARRATIVE" \
			or death_card.get("id") != "death_dao_collapse" \
			or death_card.get("sceneImage") != art.get("sceneImage") \
			or art.get("textureLoadable") != true \
			or int(death_state.get("attributes", {}).get("daoHeart", -1)) != 0 \
			or int(death_state.get("attributes", {}).get("cultivation", -1)) != 95 \
			or int(death_state.get("resources", {}).get("lifespan", -1)) != 68 \
			or death_state.get("resources", {}).get("companions") != ["mortal"] \
			or int(death_state.get("runClock", {}).get("decisionIndex", -1)) != 55:
		return _fail("fatal love settlement, death narrative, or original art mismatch")
	var bytes := FileAccess.get_file_as_string(store.v2_path)
	var reopened = Domain.new(Registry.new(), RunSession.new(path, "slot_3"), "slot_3")
	_stabilize_ambient(reopened)
	if not reopened.restore() or reopened.get_current_card() != death_card:
		return _fail("death card was lost or changed after strict restart: " \
			+ reopened._store.last_error)
	if reopened.choose("left", token) \
			or FileAccess.get_file_as_string(store.v2_path) != bytes:
		return _fail("stale pre-death choice changed the committed death")
	print("NONCOMBAT_DEATH_CARD_JOURNEY_PASS fatal=true art=true replay=true rollback=true stale=true")
	quit(0)


func _stabilize_ambient(game: RefCounted) -> void:
	game._normal_roll_override = 0.55
	game._market_flow.roll_override = 0.0
	game._destiny_wheel_flow.roll_override = 0.0
	game._ripple_flow.roll_override = 0.999
	game._hint_flow.roll_override = 0.0


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
