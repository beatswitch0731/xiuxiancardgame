extends "res://tests/noncombat_foundation_spell_quest.gd"

func _run() -> void:
	var game = Domain.new(Registry.new(), null, "slot_2")
	if not game.start("spell"):
		return _fail("tianshu fixture could not start")
	var state: Dictionary = game.state.duplicate(true)
	state.phase = "FLOW_PENDING"
	state.realm = "foundation"
	state.turn = 15
	state.runClock.decisionIndex = 15
	state.attributes.cultivation = 25
	state.attributes.daoHeart = 5
	state["flags"] = {}
	state["knowledge"] = {}
	state["karmaSeeds"] = []
	state["karmaPromiseFlags"] = {}
	state["noncombatFlow"] = {"scope": "first_session_combat"}
	state["decisionCheckpoint"] = {"sourceCardId": "epiphany_foundation"}
	state.questState = {"saveVersion": 3, "activeQuests": [],
		"completedQuests": [], "closedQuests": [], "questOutcomes": {}}
	var flow = QuestFlow.new(ContentRepository.new())
	var first: Dictionary = flow.resume(state)
	if first.get("currentCardId") != "q_tianshu_1" \
			or first.get("noncombatFlow", {}).get("tianshuSourceSha") != \
				ContentRepository.new().source_sha256("quests:tianshu_codex"):
		return _fail("tianshu did not precede spell codex at shared eligibility")
	var refused: Dictionary = flow.settle(first, "right")
	var spell_after_refusal: Dictionary = flow.resume(refused)
	if refused.get("questState", {}).get("questOutcomes", {}).get(
			"tianshu_codex") != "abandoned" \
			or spell_after_refusal.get("currentCardId") != "q_spell_1":
		return _fail("tianshu refusal did not release later spell quest")
	var second: Dictionary = flow.settle(first, "left")
	var refused_second: Dictionary = flow.settle(second, "right")
	if refused_second.get("questState", {}).get("questOutcomes", {}).get(
			"tianshu_codex") != "abandoned" \
			or refused_second.get("flags", {}).get("tianshuCodexCompleted") == true:
		return _fail("tianshu second-page refusal received completion")
	var third: Dictionary = flow.settle(second, "left")
	var fourth: Dictionary = flow.settle(third, "right")
	var kept_page: Dictionary = flow.settle(third, "left")
	if second.get("currentCardId") != "q_tianshu_2" \
			or third.get("currentCardId") != "q_tianshu_3" \
			or fourth.get("currentCardId") != "q_tianshu_4" \
			or kept_page.get("currentCardId") != "q_tianshu_4":
		return _fail("tianshu four-card source chain stopped")
	var deep: Dictionary = flow.settle(fourth, "right")
	if deep.get("questState", {}).get("questOutcomes", {}).get(
			"tianshu_codex") != "completed" \
			or deep.get("flags", {}).get("tianshuCodexCompleted") != true \
			or _seed(deep, "tianshuDeep").get("realm") != "nascent" \
			or deep.get("factionProgress", {}).get("reputations", {}).get(
				"tianshu_academy") != 20:
		return _fail("tianshu deep completion or faction reward missing: " +
			flow.last_error)
	var spell_after_completion: Dictionary = flow.resume(deep)
	if spell_after_completion.get("currentCardId") != "q_spell_1":
		return _fail("tianshu completion did not release spell codex")
	var accepted: Dictionary = flow.settle(kept_page, "left")
	if accepted.get("questState", {}).get("questOutcomes", {}).get(
			"tianshu_codex") != "completed" \
			or _seed(accepted, "tianshuStarted").get("realm") != "golden":
		return _fail("tianshu accepted order ending lost golden causal seed")
	print("NONCOMBAT_FOUNDATION_TIANSHU_QUEST_PASS order=true refusals=2 endings=2 next=true")
	quit(0)
