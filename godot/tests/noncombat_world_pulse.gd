extends SceneTree

const Registry = preload("res://scripts/runtime_data_registry.gd")
const Domain = preload("res://scripts/noncombat_domain.gd")
const Session = preload("res://scripts/noncombat_run_session.gd")
const WorldPulse = preload("res://scripts/noncombat_world_pulse.gd")
const WorldMap = preload("res://scripts/noncombat_world_map.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var prior := {"runClock": {"lifeId": "slot_1:life:0"}, "clues": [],
		"currentLocation": "宗门", "factionProgress": {"undercurrentStages": {}}}
	var candidate: Dictionary = prior.duplicate(true)
	candidate["turn"] = 1
	candidate["currentLocation"] = "坊市"
	candidate["clues"] = [{"id": "truth_1"}]
	candidate["factionProgress"]["undercurrentStages"] = {"rift": 2}
	candidate["worldPulseState"] = WorldPulse.initial(prior)
	if not WorldPulse.settle(prior, candidate, {"type": "STORY", "title": "试炼"},
			{"effects": {"karmaGood": 1, "karmaBad": 1, "spiritStone": -1},
				"triggerCombat": true}, "victory"):
		return _fail("world pulse did not settle source events")
	var metrics: Dictionary = candidate.worldPulseState.state
	if int(metrics.instability) != 23 or int(metrics.scarcity) != 21 \
			or int(metrics.hope) != 54 or int(metrics.truth) != 12 \
			or metrics.lastCause != "victory" \
			or WorldPulse.project(candidate.worldPulseState, "坊市").get(
				"dominantTag") != "bustling":
		return _fail("world pulse event values or location mood differ from source")
	var absent_progress: Dictionary = prior.duplicate(true)
	absent_progress.erase("factionProgress")
	var initialized_progress: Dictionary = absent_progress.duplicate(true)
	initialized_progress["factionProgress"] = {"undercurrentStages": {
		"qingyun_debate": 1}}
	initialized_progress["worldPulseState"] = WorldPulse.initial(absent_progress)
	if not WorldPulse.settle(absent_progress, initialized_progress) \
			or int(initialized_progress.worldPulseState.state.instability) != 18:
		return _fail("loading baseline faction stages was counted as an event")
	var base_path := "user://tests/world_pulse_%d_v1.json" % Time.get_ticks_usec()
	var session = Session.new(base_path, "slot_1")
	var game = Domain.new(Registry.new(), session, "slot_1")
	if not game.start("sword") or not WorldPulse.valid(game.state.get("worldPulseState")):
		return _fail("new run did not initialize persistent world pulse")
	for direction in ["right", "left", "right"]:
		if not game.choose(direction, game.issue_choice_token()):
			return _fail("source opening decision failed before pulse verification")
	if int(game.state.worldPulseState.state.hope) != 52 \
			or int(game.state.worldPulseState.lastBroadcastTurn) != 2 \
			or game.state.worldPulseState.state.lastCause != "剑气冲霄 · 宿命剑种":
		return _fail("real opening choice did not reach pulse writer")
	var projected: Dictionary = WorldMap.new().project(game.state, game.get_current_card())
	if projected.get("worldPulse", {}).get("hope") != 52 \
			or String(projected.get("worldPulse", {}).get("headline", "")).is_empty():
		return _fail("world map did not consume saved pulse")
	var restored = Domain.new(Registry.new(), Session.new(base_path, "slot_1"), "slot_1")
	if not restored.restore() or _json(restored.state) != _json(game.state):
		return _fail("new pulse state did not survive strict disk restore")
	var old_state: Dictionary = game.state.duplicate(true)
	old_state.erase("worldPulseState")
	var committed: Dictionary = session.commit_snapshot(old_state, 3)
	if committed.get("ok") != true:
		return _fail("could not prepare an authentic old Godot snapshot")
	var old_bytes := FileAccess.get_file_as_string(session.v2_path)
	var old_session = Session.new(base_path, "slot_1")
	var old_game = Domain.new(Registry.new(), old_session, "slot_1")
	if not old_game.restore() or old_game.state.has("worldPulseState") \
			or FileAccess.get_file_as_string(session.v2_path) != old_bytes:
		return _fail("old save was not restored unchanged before activation")
	old_session.fail_promotion_once = true
	if old_game.choose("right", old_game.issue_choice_token()) \
			or old_game.state.has("worldPulseState") \
			or FileAccess.get_file_as_string(session.v2_path) != old_bytes:
		return _fail("pulse changed an old save after failed disk promotion")
	if not old_game.choose("right", old_game.issue_choice_token()) \
			or not WorldPulse.valid(old_game.state.get("worldPulseState")) \
			or int(old_game.state.worldPulseState.activationIndex) != 4:
		return _fail("next valid old-save decision did not activate pulse")
	var reopened = Domain.new(Registry.new(), Session.new(base_path, "slot_1"), "slot_1")
	if not reopened.restore() or _json(reopened.state) != _json(old_game.state):
		return _fail("activated old-save pulse did not strictly replay")
	print("NONCOMBAT_WORLD_PULSE_PASS source_events=true map=true new_disk=true old_activation=true rollback=true")
	quit(0)


func _json(value: Variant) -> Variant:
	return JSON.parse_string(JSON.stringify(value))


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
