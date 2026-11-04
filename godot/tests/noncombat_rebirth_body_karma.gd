extends SceneTree

const Registry = preload("res://scripts/runtime_data_registry.gd")
const Domain = preload("res://scripts/noncombat_domain.gd")
const ContentRepository = preload("res://scripts/noncombat_content_repository.gd")
const RebirthFlow = preload("res://scripts/noncombat_rebirth_flow.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var first = Domain.new(Registry.new(), null, "slot_3")
	if not first.start("pill"):
		return _fail("source life could not start")
	var terminal: Dictionary = first.state.duplicate(true)
	terminal["phase"] = "DEATH_PENDING"
	terminal["lifePhase"] = "DYING_NARRATIVE"
	terminal["dead"] = true
	terminal["deathCauseId"] = "death_dao_collapse"
	terminal["currentCardId"] = "death_dao_collapse"
	terminal["lifeCount"] = 0
	terminal["lifeJournal"] = []
	var death_card: Dictionary = ContentRepository.new().find(
		"card", "death_dao_collapse").get("data", {})
	var rebirth = RebirthFlow.new()
	var newborn: Dictionary = rebirth.new_life(terminal, death_card,
		"left", "slot_3")
	var body: Dictionary = rebirth.select_path(newborn, "body")
	if body.is_empty():
		return _fail("second-life body path unavailable")
	var game = Domain.new(Registry.new(), null, "slot_3")
	game.state = body.duplicate(true)
	game._install_rebirth_path_bundle(game._rebirth_path_bundle("body"))
	game._current_card_id = "rebirth_boon"
	game._choice_token = 1
	game._market_flow.ghost_plan_activation_index = 1
	if not game.choose("down", game.issue_choice_token()) \
			or not game.cancel_camp_target(game.issue_choice_token()):
		return _fail("second-life boon did not reach the source draw lane")
	var due: Dictionary = game.state.duplicate(true)
	due["attributes"]["cultivation"] = 15
	var milestone: Dictionary = game._milestone_flow.resume(due)
	var planted: Dictionary = game._milestone_flow.settle(milestone, "left")
	if planted.is_empty() or planted.get("karmaSeeds", []).is_empty():
		return _fail("body chapter did not plant source karma")
	var seed: Dictionary = planted["karmaSeeds"].back()
	if seed.get("id") != "causal:qi_body_stance" or seed.get("originLife") != 1:
		return _fail("body chapter planted wrong-life karma")
	# Isolate the due consumer; production reaches this state after the
	# authored decision delay is exhausted by ordinary choices.
	seed["delay"] = 0
	var pending: Dictionary = game._karma_flow.resume(planted)
	var card: Dictionary = pending.get("pendingKarmaCard", {})
	if pending.get("phase") != "KARMA_PENDING" \
			or card.get("id") != "k_chapter_body_left" \
			or card.get("sceneImage") != "assets/cards/events/scene_karma_k_body_echo.png" \
			or not card.get("tags", []).has("path:body"):
		return _fail("mature second-life karma did not present the source body card")
	var settled: Dictionary = game._karma_flow.settle(pending, "left")
	if settled.get("phase") != "FLOW_PENDING" \
			or int(settled.get("runClock", {}).get("decisionIndex", -1)) != 3 \
			or int(settled.get("attributes", {}).get("cultivation", -1)) != 23 \
			or settled.get("karmaSeeds", []).any(func(item: Variant) -> bool:
			return item is Dictionary and item.get("id") == "causal:qi_body_stance"):
		return _fail("body karma effect, clock, or seed consumption differs: " +
			JSON.stringify({"phase": settled.get("phase"),
				"decisionIndex": settled.get("runClock", {}).get("decisionIndex"),
				"cultivation": settled.get("attributes", {}).get("cultivation"),
				"seeds": settled.get("karmaSeeds", []),
				"error": game._karma_flow.last_error}))
	game.state = planted.duplicate(true)
	game._current_card_id = ""
	if not game.resume_flow() or game.state.get("phase") != "KARMA_PENDING" \
			or game.get_current_card().get("id") != "k_chapter_body_left" \
			or not game.choose("left", game.issue_choice_token()) \
			or game.state.get("phase") != "FLOW_PENDING" \
			or game.state.get("karmaSeeds", []).any(func(item: Variant) -> bool:
			return item is Dictionary and item.get("id") == "causal:qi_body_stance"):
		return _fail("public second-life draw/choice lane skipped due body karma")
	var burden: Dictionary = game._milestone_flow.settle(milestone, "right")
	if burden.is_empty() or burden.get("karmaSeeds", []).is_empty():
		return _fail("body chapter right choice did not plant source karma")
	var burden_seed: Dictionary = burden["karmaSeeds"].back()
	if burden_seed.get("id") != "causal:qi_body_burden":
		return _fail("body burden seed identity differs from source")
	burden_seed["delay"] = 0
	var burden_pending: Dictionary = game._karma_flow.resume(burden)
	if burden_pending.get("phase") != "KARMA_PENDING" \
			or burden_pending.get("pendingKarmaCard", {}).get("id") != \
				"k_chapter_body_right":
		return _fail("body burden source card was not scheduled")
	var burden_settled: Dictionary = game._karma_flow.settle(burden_pending, "right")
	if burden_settled.get("phase") != "FLOW_PENDING" \
			or burden_settled.get("karmaSeeds", []).any(func(item: Variant) -> bool:
				return item is Dictionary and item.get("id") == "causal:qi_body_burden"):
		return _fail("body burden effect or seed consumption differs")
	var next_chapter: Dictionary = settled.duplicate(true)
	next_chapter["attributes"]["cultivation"] = 30
	var manual_milestone: Dictionary = game._milestone_flow.resume(next_chapter)
	var manual_seeded: Dictionary = game._milestone_flow.settle(manual_milestone, "left")
	if manual_seeded.is_empty() or manual_seeded.get("karmaSeeds", []).is_empty():
		return _fail("second body chapter did not plant the authored manual seed")
	var manual_seed: Dictionary = manual_seeded["karmaSeeds"].back()
	if manual_seed.get("id") != "causal:hoarded_manual":
		return _fail("second chapter manual seed identity differs")
	manual_seed["delay"] = 0
	var manual_pending: Dictionary = game._karma_flow.resume(manual_seeded)
	if manual_pending.get("phase") != "KARMA_PENDING" \
			or manual_pending.get("pendingKarmaCard", {}).get("id") != \
				"kx_ch_hoarded_manual" \
			or manual_pending.get("pendingKarmaCard", {}).get("sceneImage") != \
				"assets/cards/events/scene_ch_qi_40.png":
		return _fail("mature manual karma did not use the source card and art")
	var manual_settled: Dictionary = game._karma_flow.settle(manual_pending, "right")
	if manual_settled.get("phase") != "FLOW_PENDING" \
			or manual_settled.get("flags", {}).get("karma_result_manual_claimed") != true \
			or int(manual_settled.get("attributes", {}).get("karmaBad", -1)) != \
				int(manual_seeded.get("attributes", {}).get("karmaBad", -1)) + 2 \
			or manual_settled.get("karmaSeeds", []).any(func(item: Variant) -> bool:
				return item is Dictionary and item.get("id") == "causal:hoarded_manual"):
		return _fail("manual karma effect or seed consumption differs")
	print("NONCOMBAT_REBIRTH_BODY_KARMA_PASS branches=3 art=true identity=true effect=true")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
