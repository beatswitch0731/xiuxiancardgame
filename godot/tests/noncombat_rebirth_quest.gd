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
	terminal["questState"] = {"saveVersion": 3, "activeQuests": [],
		"completedQuests": ["old_story"], "closedQuests": ["old_story"],
		"questOutcomes": {"old_story": "completed"}}
	var content = ContentRepository.new()
	var death_card: Dictionary = content.find(
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
		return _fail("second-life boon could not reach quest lane")
	var before_chapter: Dictionary = game.state.duplicate(true)
	before_chapter["turn"] = 5
	before_chapter["runClock"]["decisionIndex"] = 5
	before_chapter["attributes"]["cultivation"] = 10
	var early_entry: Dictionary = game._quest_flow.resume(before_chapter)
	if early_entry.get("currentCardId") != "q_whiteFox_quest" \
			or early_entry.get("noncombatFlow", {}).get("milestoneSourceSha") \
				!= content.source_sha256("cards:chapter_milestones") \
			or early_entry.get("noncombatFlow", {}).get("causalGraphSourceSha") \
				!= content.source_sha256("narrative:causal_graph"):
		return _fail("pre-chapter second-life quest lacks settlement source pins")
	var early_settled: Dictionary = game._quest_flow.settle(early_entry, "left")
	if early_settled.get("phase") != "FLOW_PENDING" \
			or early_settled.get("questState", {}).get("questOutcomes", {}).get(
				"white_fox_line") != "failed":
		return _fail("pre-chapter second-life quest could not be settled")
	var forged_entry: Dictionary = early_entry.duplicate(true)
	forged_entry.noncombatFlow.milestoneSourceSha = "foreign-chapter"
	if not game._quest_flow.settle(forged_entry, "left").is_empty():
		return _fail("pre-chapter forged source pin was accepted")
	var due: Dictionary = game.state.duplicate(true)
	due["turn"] = 6
	due["runClock"]["decisionIndex"] = 6
	due["attributes"]["cultivation"] = 35
	due["resources"]["spiritStone"] = 40
	due["chapterProgress"] = {"version": 1, "activeChapterRealm": null,
		"triggeredMilestones": {"qi": [15, 30]}}
	due["noncombatFlow"]["milestoneSourceSha"] = content.source_sha256(
		"cards:chapter_milestones")
	due["noncombatFlow"]["causalGraphSourceSha"] = content.source_sha256(
		"narrative:causal_graph")
	due["karmaPromiseFlags"] = {}
	var entry: Dictionary = game._quest_flow.resume(due)
	var npc: Dictionary = entry.get("worldContinuityState", {}).get(
		"npcs", {}).get("bai_luoxuan", {})
	if entry.get("phase") != "QUEST_PENDING" \
			or entry.get("currentCardId") != "q_whiteFox_quest" \
			or entry.get("questState", {}).get("closedQuests") != ["old_story"] \
			or entry.get("worldContinuityState", {}).get("lifeId") != 1 \
			or npc.get("lifeId") != 1:
		return _fail("second-life white-fox entry lost source card or current-life identity")
	var failed: Dictionary = game._quest_flow.settle(entry, "left")
	var dead_npc: Dictionary = failed.get("worldContinuityState", {}).get(
		"npcs", {}).get("bai_luoxuan", {})
	if failed.get("phase") != "FLOW_PENDING" \
			or failed.get("questState", {}).get("closedQuests") != [
				"old_story", "white_fox_line"] \
			or failed.get("questState", {}).get("questOutcomes", {}).get(
				"white_fox_line") != "failed" \
			or dead_npc.get("lifecycle") != "DEAD" \
			or dead_npc.get("lifeId") != 1:
		return _fail("second-life white-fox refusal did not close its own-life quest")
	var rescued: Dictionary = game._quest_flow.settle(entry, "right")
	var second: Dictionary = game._quest_flow.settle(rescued, "left")
	var paid: Dictionary = game._quest_flow.settle(second, "right")
	if rescued.get("currentCardId") != "q_whiteFox_2" \
			or second.get("currentCardId") != "q_whiteFox_3" \
			or paid.get("phase") != "FLOW_PENDING" \
			or paid.get("questState", {}).get("closedQuests") != [
				"old_story", "white_fox_line"] \
			or paid.get("questState", {}).get("completedQuests") != [
				"old_story", "white_fox_line"] \
			or paid.get("questState", {}).get("questOutcomes", {}).get(
				"white_fox_line") != "completed" \
			or paid.get("karmaSeeds", []).any(func(seed: Variant) -> bool:
				return seed is Dictionary and int(seed.get("originLife", -1)) != 1):
		return _fail("second-life white-fox completion lost source reward or life ID")
	var abandoned: Dictionary = game._quest_flow.settle(second, "down")
	if abandoned.get("questState", {}).get("questOutcomes", {}).get(
			"white_fox_line") != "abandoned" \
			or abandoned.get("questState", {}).get("completedQuests") != ["old_story"]:
		return _fail("second-life white-fox abandonment awarded completion")
	print("NONCOMBAT_REBIRTH_QUEST_PASS entry=true identity=true outcomes=3 inherited=true pre_chapter=true")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
