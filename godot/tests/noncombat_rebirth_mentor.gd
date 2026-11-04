extends SceneTree

const Registry = preload("res://scripts/runtime_data_registry.gd")
const Domain = preload("res://scripts/noncombat_domain.gd")
const MentorFlow = preload("res://scripts/noncombat_mentor_flow.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var game = Domain.new(Registry.new(), null, "slot_3")
	if not game.start("pill"):
		return _fail("first life could not start")
	var dying: Dictionary = game.state.duplicate(true)
	dying["phase"] = "NORMAL_PENDING"
	dying["currentCardId"] = "q_love"
	dying["attributes"]["daoHeart"] = 0
	dying["lifeJournal"] = []
	dying["runClock"]["decisionIndex"] = 1
	dying["turn"] = 1
	var death_receipt := "decision:slot_3:life:0:choice:q_love:1"
	dying["runClock"]["receipts"][death_receipt] = {
		"sourceCardId": "q_love", "kind": "choice", "decisionIndex": 1}
	dying["choiceHistory"].append({"cardId": "q_love", "decisionIndex": 1})
	var terminal: Dictionary = game._death_flow.prepare_death(dying, "q_love")
	if terminal.is_empty():
		return _fail("source death card was unavailable")
	game.state = terminal
	game._current_card_id = "death_dao_collapse"
	game._mentor_state = MentorFlow.initial_state()
	game._mentor_state["stage"] = "TRUSTED"
	game._mentor_state["stageIndex"] = 2
	game._mentor_state["progression"] = 48
	var old_replay_flags := ["_legacy_priority_replay", "_legacy_mentor_replay",
		"_legacy_mentor_stage_replay", "_legacy_karma_replay",
		"_legacy_karma_order_replay", "_legacy_deck_replay",
		"_legacy_fragment_replay", "_legacy_wheel_replay",
		"_legacy_lifespan_replay", "_legacy_market_replay",
		"_legacy_ripple_replay", "_legacy_hint_replay"]
	var old_activation_keys := ["_legacy_fragment_replay_activation_index",
		"_legacy_wheel_replay_activation_index",
		"_legacy_market_replay_activation_index",
		"_legacy_ripple_replay_activation_index",
		"_legacy_hint_replay_activation_index"]
	var old_seed_keys := ["_legacy_fragment_replay_initial_seed",
		"_legacy_wheel_replay_initial_seed",
		"_legacy_market_replay_initial_seed",
		"_legacy_ripple_replay_initial_seed",
		"_legacy_hint_replay_initial_seed"]
	for key in old_replay_flags:
		game.set(key, true)
	for key in old_activation_keys:
		game.set(key, 35)
	for key in old_seed_keys:
		game.set(key, 123)
	game._normal_replay_seed = 123
	game._normal_replay_draws = [{"cardCount": 24}]
	game._normal_replay_priority_checks = [{"decisionIndex": 24}]
	game._normal_replay_shop_entries = [{"decisionIndex": 24}]
	game._normal_replay_source_pins = {"old": true}
	game._flow_card_count = 24
	game._normal_starvation = {"normal": 7}
	game._normal_flow_error = "old-life-error"
	game._q_market_choice_activation_index = 35
	game._causal_fact_clock.activation_index = 35
	game._regulated_vendor.causal_activation_index = 35
	game._market_flow.ghost_plan_activation_index = 35
	game._trade_route_flow.activation_index = 35
	game._trade_route_flow.legacy_initial_trusted = false
	game._avoid_flow.legacy_replay = true
	game._avoid_flow.legacy_schema_replay = true
	game._avoid_flow.legacy_lifespan_replay = true
	game._quest_flow.legacy_entry_replay = true
	if not game.choose("left", game.issue_choice_token()) \
			or game._mentor_state != MentorFlow.initial_state():
		return _fail("new life retained the previous life's mentor progression")
	for key in old_replay_flags:
		if game.get(key) != false:
			return _fail("new life retained old replay flag: " + key)
	for key in old_activation_keys:
		if game.get(key) != -1:
			return _fail("new life retained old replay activation: " + key)
	for key in old_seed_keys:
		if game.get(key) != 0:
			return _fail("new life retained old replay RNG seed: " + key)
	if game._normal_replay_seed != 0 or not game._normal_replay_draws.is_empty() \
			or not game._normal_replay_priority_checks.is_empty() \
			or not game._normal_replay_shop_entries.is_empty() \
			or not game._normal_replay_source_pins.is_empty() \
			or game._flow_card_count != 0 or not game._normal_starvation.is_empty() \
			or not game._normal_flow_error.is_empty() \
			or game._q_market_choice_activation_index != 0 \
			or game._causal_fact_clock.activation_index != 1 \
			or game._regulated_vendor.causal_activation_index != 0 \
			or game._market_flow.ghost_plan_activation_index != 1 \
			or game._trade_route_flow.activation_index != 1 \
			or not game._trade_route_flow.legacy_initial_trusted \
			or game._avoid_flow.legacy_replay \
			or game._avoid_flow.legacy_schema_replay \
			or game._avoid_flow.legacy_lifespan_replay \
			or game._quest_flow.legacy_entry_replay:
		return _fail("new life retained old normal, market or causal runtime cursor")
	if not game.select_rebirth_path("body") \
			or not game.choose("down", game.issue_choice_token()) \
			or not game.cancel_camp_target(game.issue_choice_token()):
		return _fail("second-life boon could not reach the source flow")
	if game.state.get("mentorArcState") != MentorFlow.initial_state():
		return _fail("old mentor replay mode suppressed new-life mentor state")
	var due: Dictionary = game.state.duplicate(true)
	var arc: Dictionary = MentorFlow.initial_state()
	arc["stage"] = "INNER_DISCIPLE"
	arc["stageIndex"] = 1
	arc["progression"] = 20
	arc["pendingStages"] = ["INNER_DISCIPLE"]
	due["mentorArcState"] = arc
	var entry: Dictionary = game._mentor_flow.resume(due)
	if entry.get("phase") != "MENTOR_PENDING" \
			or entry.get("currentCardId") != MentorFlow.CARD_ID \
			or entry.get("pendingMentorCard", {}).get("sceneImage") != \
				"assets/characters/stages/bai_ren_sword_tomb_master.png":
		return _fail("second-life source mentor stage and portrait were not queued")
	var settled: Dictionary = game._mentor_flow.settle(entry, "left")
	if settled.get("phase") != "NARRATIVE_RESULT_PENDING" \
			or settled.get("runClock", {}).get("lifeId") != "slot_3:life:1" \
			or not settled.get("runClock", {}).get("receipts", {}).has(
				"decision:slot_3:life:1:choice:%s:%d" % [MentorFlow.CARD_ID,
					int(entry["runClock"]["decisionIndex"]) + 1]) \
			or settled.get("mentorArcState", {}).get("pendingStages", []).has(
				"INNER_DISCIPLE"):
		return _fail("second-life mentor choice did not settle on this life's clock")
	var previous: Dictionary = due.duplicate(true)
	previous["lifeCount"] = 0
	previous["runClock"]["lifeId"] = "slot_3:life:0"
	previous["noncombatFlow"]["scope"] = "first_session_avoid"
	var prior_entry: Dictionary = game._mentor_flow.resume(previous)
	var prior_settled: Dictionary = game._mentor_flow.settle(prior_entry, "left")
	if prior_settled.is_empty() or settled.get("noncombatFlow", {}).get(
			"mentorPromise", {}).get("id") == prior_settled.get(
			"noncombatFlow", {}).get("mentorPromise", {}).get("id"):
		return _fail("mentor promise identity collided across two lives")
	print("NONCOMBAT_REBIRTH_MENTOR_PASS reset=true stage=true identity=true")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
