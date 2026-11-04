extends SceneTree

const Registry = preload("res://scripts/runtime_data_registry.gd")
const Domain = preload("res://scripts/noncombat_domain.gd")
const Session = preload("res://scripts/noncombat_run_session.gd")
const DEATH_FIXTURE := "res://tests/fixtures/pill_decision54_death_probe_v2.json"
const OLD_RULE_UNTIL := 1000000
const AMBIENT_KEYS := ["destinyWheelTicks", "destinyWheelRngState", "pendingDestinyWheel",
	"karmaRippleState", "rippleRngState", "pendingRippleCard",
	"heavensHintState", "hintRngState", "pendingHintCard",
	"legacyArchive", "legacyRunState", "legacyRngState"]
var problem := ""


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	if not _new_rules() or not _old_prefix() or not _old_rebirth():
		push_error(problem)
		quit(1)
		return
	print("NONCOMBAT_COMBAT_SCHEDULING_PASS new_teaching=true old_teaching=true story_terminal=true acknowledgement=true old_prefix=true rebirth_old_prefix=true atomic=true strict_reload=true")
	quit(0)


func _new_rules() -> bool:
	var game = _new_game("scheduling_new", "slot_2")
	if not _enter_teaching(game, false):
		return false
	if game.state.get("combatScheduling") != {"version": 1, "activationIndex": 0}:
		return _bad("new run did not enable source combat scheduling from index zero")
	if not _terminal_without_ambient(game, "victory"):
		return false
	if not _acknowledge(game, "down", 0):
		return false
	# A STORY source would pass LegacyFragment's historical cardType != COMBAT
	# filter. Its terminal must still skip the ordinary fragment/RNG lane.
	if not _enter_mountain(game) or not _terminal_without_ambient(game, "flee"):
		return false
	return _acknowledge(game, "down", 0)


func _old_prefix() -> bool:
	var game = _new_game("scheduling_old", "slot_2")
	if not _enter_teaching(game, true):
		return false
	var before: Dictionary = game.state.duplicate(true)
	if not game.submit_battle_result(_result(game.battle_request(), "victory")):
		return _bad("old scheduler could not settle the real teaching source")
	if game.state.has("combatScheduling") \
			or int(game.state.destinyWheelTicks) != int(before.destinyWheelTicks) + 1 \
			or int(game.state.karmaRippleState.totalTicks) != int(game.state.turn):
		return _bad("old prefix did not retain the historical terminal ambient tick")
	var prefix: Dictionary = game.state.duplicate(true)
	var migrated = _reload(game)
	if migrated == null:
		return false
	var activation := int(prefix.turn) + 1
	if migrated.state.has("combatScheduling") \
			or migrated._combat_scheduling_activation_index != activation:
		return _bad("unmarked old snapshot was changed or assigned the wrong future boundary")
	# Reload itself is read only. The first following decision installs the
	# boundary atomically; rejected writes must leave the old bytes intact.
	if not _acknowledge(migrated, "down", activation):
		return false
	var activated = _reload(migrated)
	if activated == null or not _enter_mountain(activated) \
			or not _terminal_without_ambient(activated, "flee"):
		return false
	return _acknowledge(activated, "down", activation)


func _old_rebirth() -> bool:
	# This checked-in checkpoint was produced by the existing natural pill
	# journey. Continue its public fatal choice and reincarnation; do not forge
	# a terminal state, prior-life rewards, or a new-life history.
	var game = _new_game("scheduling_rebirth", "slot_3")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(game._store.v2_path).get_base_dir())
	var file := FileAccess.open(game._store.v2_path, FileAccess.WRITE)
	if file == null:
		return _bad("cannot stage the existing natural death checkpoint")
	file.store_string(FileAccess.get_file_as_string(DEATH_FIXTURE))
	file.close()
	if not game.restore() or not game.resume_flow() \
			or game.get_current_card().get("id") != "q_love" \
			or not game.choose("right", game.issue_choice_token()) \
			or not game.choose("left", game.issue_choice_token()):
		return _bad("natural death/rebirth route failed")
	if game._combat_scheduling_activation_index != 0:
		return _bad("new life retained the previous life's scheduling activation")
	# Generate the historical second-life prefix through normal producers.
	game.state.erase("combatScheduling")
	game._combat_scheduling_activation_index = OLD_RULE_UNTIL
	game.state.erase("encounterCadence")
	game._cadence_activation_index = OLD_RULE_UNTIL
	if not game.select_rebirth_path("spell") \
			or not game.choose("down", game.issue_choice_token()) \
			or not game.cancel_camp_target(game.issue_choice_token()) \
			or game.state.has("combatScheduling") or game.state.has("encounterCadence") \
			or game.state.noncombatFlow.has("encounterDirectorState") \
			or int(game.state.turn) != 1:
		return _bad("could not produce unmarked old second-life prefix")
	var restored = _reload(game)
	if restored == null:
		return false
	if restored._combat_scheduling_activation_index != 2 \
			or restored._cadence_activation_index != 2 \
			or not restored.resume_flow() or restored.state.has("combatScheduling") \
			or restored.state.has("encounterCadence"):
		return _bad("old rebirth restore/presentation advanced its scheduling boundary")
	var card: Dictionary = restored.get_current_card()
	var direction := "right" if restored.state.get("phase") == "MARKET_PENDING" else "left"
	if not restored.can_choose_direction(direction):
		direction = "right"
	var before: Dictionary = restored.state.duplicate(true)
	var bytes := FileAccess.get_file_as_bytes(restored._store.v2_path)
	var token: int = restored.issue_choice_token()
	restored._store.fail_promotion_once = true
	if restored.choose(direction, token) or not _same(restored.state, before) \
			or FileAccess.get_file_as_bytes(restored._store.v2_path) != bytes:
		return _bad("old rebirth activation leaked through a failed write: " + str(card.get("id")))
	if not restored.choose(direction, token) or int(restored.state.turn) != 2 \
			or restored.state.get("combatScheduling") != {"version": 1, "activationIndex": 2} \
			or restored.state.get("encounterCadence", {}).get("activationIndex") != 2 \
			or restored.state.get("noncombatFlow", {}).get(
				"encounterDirectorState", {}).get("lifeId") != 1:
		return _bad("old rebirth next public decision did not activate the corrected scheduler")
	return _reload(restored) != null


func _enter_teaching(game: RefCounted, old_rules: bool) -> bool:
	if not game.start("sword"):
		return _bad("teaching opening failed")
	if old_rules:
		# Only the scheduler version is selected. Every gameplay effect and save
		# below is produced by its ordinary public choice/terminal consumer.
		game.state.erase("combatScheduling")
		game._combat_scheduling_activation_index = OLD_RULE_UNTIL
	for step in 7:
		if not game.choose("left", game.issue_choice_token()):
			return _bad("natural teaching route failed at step " + str(step))
	if game.state.get("phase") != "BATTLE_PENDING" or game.battle_request().is_empty():
		return _bad("teaching route did not reach a genuine pending request")
	return true


func _enter_mountain(game: RefCounted) -> bool:
	for step in 4:
		if game.get_current_card().get("id") == "q_mountain_shadow_approach":
			break
		if game.state.get("phase") == "FLOW_PENDING":
			if not game.resume_flow():
				return _bad("mountain continuation did not resume")
		elif game.state.get("phase") == "MILESTONE_PENDING":
			if not game.choose("left", game.issue_choice_token()):
				return _bad("mountain chapter interruption did not settle")
		else:
			return _bad("unexpected mountain interruption: " + str(game.state.get("phase")))
	if game.get_current_card().get("id") != "q_mountain_shadow_approach" \
			or not game.choose("left", game.issue_choice_token()) \
			or not game.choose("left", game.issue_choice_token()) \
			or game.battle_request().is_empty():
		return _bad("second STORY battle did not open")
	return true


func _terminal_without_ambient(game: RefCounted, outcome: String) -> bool:
	var before: Dictionary = game.state.duplicate(true)
	var ambient := _ambient(before)
	var bytes := FileAccess.get_file_as_bytes(game._store.v2_path)
	var result := _result(game.battle_request(), outcome)
	game._store.fail_promotion_once = true
	if game.submit_battle_result(result) or not _same(game.state, before) \
			or FileAccess.get_file_as_bytes(game._store.v2_path) != bytes:
		return _bad("failed combat commit changed scheduler, state or save bytes")
	if not game.submit_battle_result(result):
		return _bad("corrected combat settlement failed: " + game.flow_failure_reason())
	if int(game.state.turn) != int(before.turn) + 1 \
			or game.state.get("phase") != "BATTLE_RESULT_PENDING" \
			or not _same(_ambient(game.state), ambient):
		return _bad("combat terminal ran ordinary legacy/wheel/ripple/hint scheduling")
	# The combat decision still owns the causal clock and seed tick.
	for seed in before.get("karmaSeeds", []):
		for after_seed in game.state.get("karmaSeeds", []):
			if after_seed.get("id") == seed.get("id") and int(after_seed.delay) != int(seed.delay) - 1:
				return _bad("skipping ambient hooks also skipped the required karma seed tick")
	return _reload(game) != null


func _acknowledge(game: RefCounted, direction: String, activation: int) -> bool:
	var before: Dictionary = game.state.duplicate(true)
	var bytes := FileAccess.get_file_as_bytes(game._store.v2_path)
	var token: int = game.issue_choice_token()
	game._store.fail_promotion_once = true
	if game.choose(direction, token) or not _same(game.state, before) \
			or FileAccess.get_file_as_bytes(game._store.v2_path) != bytes:
		return _bad("failed result acknowledgement leaked activation or ambient changes")
	if not game.choose(direction, token):
		return _bad("result acknowledgement retry failed")
	if int(game.state.turn) != int(before.turn) + 1 \
			or game.state.get("combatScheduling") != {"version": 1, "activationIndex": activation} \
			or int(game.state.destinyWheelTicks) != int(before.destinyWheelTicks) + 1 \
			or int(game.state.karmaRippleState.totalTicks) != int(game.state.turn) \
			or int(game.state.heavensHintState.totalTicks) != int(game.state.turn) \
			or _same(game.state.legacyRunState, before.legacyRunState) \
				and _same(game.state.legacyArchive, before.legacyArchive):
		return _bad("ordinary result choice failed to advance its authored scheduling hooks")
	return _reload(game) != null


func _new_game(prefix: String, slot: String) -> RefCounted:
	var path := "user://tests/%s_%d_%d.json" % [prefix, OS.get_process_id(), Time.get_ticks_usec()]
	var game = Domain.new(Registry.new(), Session.new(path, slot), slot)
	_stabilize(game)
	return game


func _reload(game: RefCounted) -> RefCounted:
	var bytes := FileAccess.get_file_as_bytes(game._store.v2_path)
	var fresh = Domain.new(Registry.new(), Session.new(game._store.legacy_path, game._slot_id), game._slot_id)
	_stabilize(fresh)
	if not fresh.restore() or not _same(fresh.state, game.state) \
			or FileAccess.get_file_as_bytes(game._store.v2_path) != bytes:
		_bad("strict scheduler restart changed/rejected the saved prefix: " + game._store.legacy_path)
		return null
	return fresh


func _stabilize(game: RefCounted) -> void:
	game._normal_roll_override = 0.55
	game._market_flow.roll_override = 0.0
	game._destiny_wheel_flow.roll_override = 0.0
	game._ripple_flow.roll_override = 0.999
	game._hint_flow.roll_override = 0.0


func _ambient(state: Dictionary) -> Dictionary:
	var result := {}
	for key in AMBIENT_KEYS:
		if state.has(key):
			result[key] = state[key]
	return result.duplicate(true)


func _result(request: Dictionary, outcome: String) -> Dictionary:
	return {"contractVersion": 2, "encounterInstanceId": request.encounterInstanceId,
		"sourceCardId": request.sourceCardId, "encounterId": request.encounterId,
		"sourceContentHash": request.sourceContentHash, "outcome": outcome,
		"combatReceipt": "combat:" + String(request.encounterInstanceId),
		"postBattleState": {"encounterInstanceId": request.encounterInstanceId,
			"terminal": true, "combatPhase": outcome.to_upper()}}


func _same(a: Variant, b: Variant) -> bool:
	return JSON.parse_string(JSON.stringify(a)) == JSON.parse_string(JSON.stringify(b))


func _bad(message: String) -> bool:
	problem = message
	return false
