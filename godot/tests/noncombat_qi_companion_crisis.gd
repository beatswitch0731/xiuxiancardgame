extends SceneTree

const Events = preload("res://scripts/noncombat_companion_events.gd")
const Domain = preload("res://scripts/noncombat_domain.gd")
const Registry = preload("res://scripts/runtime_data_registry.gd")
const RunSession = preload("res://scripts/noncombat_run_session.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	for route in [["right", "bai_luoxuan", "good"],
			["left", "jian_linger", "bad"]]:
		if not _exercise(String(route[0]), String(route[1]), String(route[2])):
			return
	if not _multiple_candidates():
		return
	print("NONCOMBAT_QI_COMPANION_CRISIS_PASS source=2 signs=2 owners=2 overwrite=true atomic=true rollback=true cold_card=true settle=true")
	quit(0)

func _exercise(direction: String, comp_id: String, variant: String) -> bool:
	var save_path := "user://tests/qi_crisis_%s_%d.json" % [variant, Time.get_ticks_usec()]
	var game = Domain.new(Registry.new(), RunSession.new(save_path, "slot_3"), "slot_3")
	if not game.start("sword"):
		return _fail("source opening unavailable")
	for step in 5:
		if not game.choose("left", game.issue_choice_token()):
			return _fail("opening route failed")
	if not game.choose("right", game.issue_choice_token()) \
			or not game.choose("left", game.issue_choice_token()) \
			or not game.resume_flow() \
			or not game.choose("left", game.issue_choice_token()) \
			or not game.choose("right", game.issue_choice_token()) \
			or not game.resume_flow() \
			or game.get_current_card().get("id") != "q_whiteFox_quest":
		return _fail("white fox public entry unavailable")
	game.state.resources.companions = [comp_id]
	game.state.get_or_add("npcAffection", {})[comp_id] = 60
	var before_index := int(game.state.runClock.decisionIndex)
	var before: Dictionary = game.state.duplicate(true)
	var before_bytes := FileAccess.get_file_as_string(game._store.v2_path)
	game._store.fail_promotion_once = true
	if game.choose(direction, game.issue_choice_token()) \
			or FileAccess.get_file_as_string(game._store.v2_path) != before_bytes \
			or JSON.parse_string(JSON.stringify(game.state)) != JSON.parse_string(
				JSON.stringify(before)):
		return _fail("failed crisis write leaked state or save bytes: " + variant)
	if not game.choose(direction, game.issue_choice_token()):
		return _fail("public white fox choice failed: " + variant)
	var queued: Array = game.state.companionProgress.get("pendingCrises", [])
	if int(game.state.runClock.decisionIndex) != before_index + 1 \
			or queued.size() != 1 or queued[0].get("variant") != variant \
			or queued[0].get("compId") != comp_id:
		return _fail("crisis did not commit with source choice: " + variant)
	var saved: Dictionary = RunSession.new(save_path, "slot_3").load_snapshot()
	if saved.get("state", {}).get("companionProgress", {}).get(
			"pendingCrises", []).size() != 1:
		return _fail("committed crisis missing from cold session read: " + variant)
	var events := Events.new()
	var flow: Dictionary = saved.state.duplicate(true)
	flow.phase = "FLOW_PENDING"
	flow.currentCardId = ""
	var pending: Dictionary = events.take(flow)
	var expected_id := "comp_%s_qi_karma_crisis_%s" % [comp_id, variant]
	if pending.get("currentCardId") != expected_id \
			or pending.get("decisionCheckpoint", {}).get("flowSource") != "companion_crisis":
		return _fail("crisis lost scheduler priority: " + variant)
	var cold: Variant = JSON.parse_string(JSON.stringify(pending))
	var card: Dictionary = events.card(cold)
	if card.get("id") != expected_id or card.get("choices", {}).size() != 2 \
			or not events.choice_available(cold, "left") \
			or not events.choice_available(cold, "right"):
		return _fail("cold card did not project both choices: " + variant)
	var left: Dictionary = events.settle(cold, "left")
	var right: Dictionary = events.settle(cold, "right")
	if left.is_empty() or right.is_empty() \
			or left.get("pendingCompanionCrisis") != null \
			or left.get("cardsPlayed", []).count(expected_id) != 1 \
			or int(left.get("npcAffection", {}).get(comp_id, -999)) == int(
				right.get("npcAffection", {}).get(comp_id, -999)):
		return _fail("crisis decisions did not settle distinctly: " + variant)
	game.state = cold
	game._current_card_id = expected_id
	game._choice_token = 1
	if game.get_current_card().get("id") != expected_id \
			or not game.choose("left", game.issue_choice_token()) \
			or game.state.get("cardsPlayed", []).count(expected_id) != 1:
		return _fail("visible crisis did not commit through domain choice: " + variant)
	return true

func _multiple_candidates() -> bool:
	var events := Events.new()
	var card: Dictionary = events._content.find("card", "q_whiteFox_quest").get("data", {})
	if card.get("id") != "q_whiteFox_quest":
		return _fail("source crisis trigger card unavailable")
	var state := {"phase": "FLOW_PENDING", "realm": "qi", "turn": 10,
		"runClock": {"lifeId": "crisis:0", "decisionIndex": 10},
		"resources": {"companions": ["bai_luoxuan", "jian_linger"]},
		"npcAffection": {"bai_luoxuan": 60, "jian_linger": 60}}
	state.companionProgress = events.marker(0, 9)
	var selected := {}
	var bai_seed := -1
	for seed in 64:
		var trial: Dictionary = state.duplicate(true)
		trial.runClock.lifeId = "crisis:%d" % seed
		if not events.queue_crisis(trial, card, "right"):
			return _fail("dual-owner source choice was rejected")
		var owner: String = trial.companionProgress.pendingCrises[0].compId
		selected[owner] = true
		if owner == "bai_luoxuan" and bai_seed < 0:
			bai_seed = seed
		var replay: Dictionary = state.duplicate(true)
		replay.runClock.lifeId = trial.runClock.lifeId
		if not events.queue_crisis(replay, card, "right") \
				or replay.companionProgress.pendingCrises != trial.companionProgress.pendingCrises:
			return _fail("dual-owner choice did not replay deterministically")
		if not events.queue_crisis(trial, card, "left") \
				or trial.companionProgress.pendingCrises.size() != 1 \
				or trial.companionProgress.pendingCrises[0].variant != "bad":
			return _fail("later crisis did not overwrite pending singleton")
	if selected.size() != 2:
		return _fail("dual-owner draw always selected one companion")
	var absent: Dictionary = state.duplicate(true)
	absent.runClock.lifeId = "crisis:%d" % bai_seed
	absent.lifeCount = 0
	absent.worldContinuityState = {"version": 1, "lifeId": 0,
		"npcs": {"bai_luoxuan": {"npcId": "bai_luoxuan", "lifeId": 0,
			"lifecycle": "DEAD", "manifestation": "ECHO_ONLY"},
			"jian_linger": {"npcId": "jian_linger", "lifeId": 0,
				"lifecycle": "ACTIVE", "manifestation": "PHYSICAL"}}}
	if not events.queue_crisis(absent, card, "right") \
			or absent.companionProgress.pendingCrises[0].compId != "bai_luoxuan":
		return _fail("source draw did not retain absent candidate")
	var dropped: Dictionary = events.take(absent)
	if dropped.get("phase") != "FLOW_PENDING" \
			or int(dropped.get("companionProgress", {}).get("checkedTurn", -1)) != 10 \
			or not dropped.companionProgress.get("pendingCrises", []).is_empty():
		return _fail("absent selected companion should drop only this crisis check " +
			JSON.stringify({"phase": dropped.get("phase"), "checked": dropped.get(
				"companionProgress", {}).get("checkedTurn"), "queue": dropped.get(
				"companionProgress", {}).get("pendingCrises", []), "card": dropped.get(
				"currentCardId"), "error": events.last_error}))
	return true

func _fail(message: String) -> bool:
	push_error(message)
	quit(1)
	return false
