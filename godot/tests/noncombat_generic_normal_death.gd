extends SceneTree

const Registry = preload("res://scripts/runtime_data_registry.gd")
const Domain = preload("res://scripts/noncombat_domain.gd")
const RunSession = preload("res://scripts/noncombat_run_session.gd")
const FIXTURE := "res://tests/fixtures/spell_second_life_fatal_source_v2.json"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var path := "user://tests/generic_normal_death_%d.json" % Time.get_ticks_usec()
	var store = RunSession.new(path, "slot_3")
	if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(
			store.v2_path).get_base_dir()) != OK:
		return _fail("checkpoint directory unavailable")
	var source := FileAccess.open(FIXTURE, FileAccess.READ)
	var dest := FileAccess.open(store.v2_path, FileAccess.WRITE)
	if source == null or dest == null:
		return _fail("source replay checkpoint unavailable")
	dest.store_string(source.get_as_text())
	dest.close()
	var game = Domain.new(Registry.new(), store, "slot_3")
	_stabilize(game)
	var restored := game.restore()
	if not restored or game.state.get("phase") != "NORMAL_PENDING" \
			or game.get_current_card().get("id") != "q_spellTome" \
			or game.state.get("lifeCount") != 1 \
			or game.state.has("factionCollectionNewActivationIndex") \
			or game.state.get("attributes", {}).get("daoHeart") != 1:
		return _fail("second-life authored spell checkpoint did not strictly restore: "
			+ JSON.stringify({"restored": restored, "store": store.last_error,
				"phase": game.state.get("phase"),
				"card": game.get_current_card().get("id")}))
	var before: Dictionary = game.state.duplicate(true)
	var before_bytes := FileAccess.get_file_as_string(store.v2_path)
	var token := game.issue_choice_token()
	store.fail_promotion_once = true
	if game.choose("left", token) or game.state != before \
			or FileAccess.get_file_as_string(store.v2_path) != before_bytes:
		return _fail("failed fatal choice write changed state or save")
	if not game.choose("left", token):
		return _fail("authored ordinary card with fatal daoHeart was rejected")
	var death_state: Dictionary = game.state
	if death_state.get("phase") != "DEATH_PENDING" \
			or game.get_current_card().get("id") != "death_dao_collapse" \
			or death_state.get("lifePhase") != "DYING_NARRATIVE" \
			or death_state.get("lifeCount") != 1 \
			or death_state.get("runClock", {}).get("decisionIndex") != 63 \
			or death_state.get("factionCollectionNewActivationIndex") != 63 \
			or death_state.get("attributes", {}).get("daoHeart") != 0 \
			or death_state.get("deathCauseId") != "death_dao_collapse" \
			or death_state.get("decisionCheckpoint", {}).get("sourceCardId") != "q_spellTome":
		return _fail("ordinary fatal effect and second-life death card diverged")
	var reopened = Domain.new(Registry.new(), RunSession.new(path, "slot_3"), "slot_3")
	_stabilize(reopened)
	var death_restored := reopened.restore()
	if not death_restored or not _same(reopened.state, death_state) \
			or reopened.get_current_card() != game.get_current_card():
		return _fail("ordinary death transition failed strict cold replay: "
			+ JSON.stringify({"restored": death_restored,
				"store": reopened._store.last_error,
				"phase": reopened.state.get("phase"),
				"card": reopened.get_current_card().get("id")}))
	var tampered: Dictionary = death_state.duplicate(true)
	tampered["factionCollectionNewActivationIndex"] = 0
	if reopened._restore_rebirth(tampered, reopened._store.load_snapshot()) \
			or not _same(reopened.state, death_state):
		return _fail("invalid old-to-new faction replay boundary was accepted")
	print("NONCOMBAT_GENERIC_NORMAL_DEATH_PASS second_life=true replay=true rollback=true")
	quit(0)


func _same(left: Dictionary, right: Dictionary) -> bool:
	return JSON.parse_string(JSON.stringify(left)) == JSON.parse_string(JSON.stringify(right))


func _stabilize(game: RefCounted) -> void:
	game._normal_roll_override = 0.55
	game._market_flow.roll_override = 0.0
	game._destiny_wheel_flow.roll_override = 0.0
	game._ripple_flow.roll_override = 0.999
	game._hint_flow.roll_override = 0.0


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
