extends "res://tests/noncombat_foundation_body_quest.gd"

const SPELL := "res://content/data/quests/spell_codex.json"


func _run() -> void:
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SPELL))
	var path := "user://tests/foundation_spell_quest_%d.json" % Time.get_ticks_usec()
	var game = Domain.new(Registry.new(), Session.new(path, "slot_2"), "slot_2")
	if not game.start("spell"):
		return _fail("spell foundation source state could not start")
	var state: Dictionary = game.state.duplicate(true)
	state.phase = "FLOW_PENDING"
	state.realm = "foundation"
	state.turn = 10
	state.runClock.decisionIndex = 10
	state.attributes.cultivation = 25
	state.attributes.daoHeart = 4
	state.attributes.karmaBad = 0
	state["flags"] = {}
	state["knowledge"] = {}
	state["karmaSeeds"] = []
	state["karmaPromiseFlags"] = {}
	state["lifeCount"] = 0
	state["deck"] = []
	state["noncombatFlow"] = {"scope": "first_session_combat"}
	state["decisionCheckpoint"] = {"sourceCardId": "epiphany_foundation"}
	state.questState = {"saveVersion": 3, "activeQuests": [],
		"completedQuests": [], "closedQuests": [], "questOutcomes": {}}
	var flow = QuestFlow.new(ContentRepository.new())
	var entry: Dictionary = flow.resume(state)
	if entry.get("currentCardId") != "q_spell_1" \
			or entry.get("pendingQuestCard", {}).get("sceneImage") != source.cards[0].sceneImage:
		return _fail("eligible spell path did not enter authored foundation quest")
	var abandoned: Dictionary = flow.settle(entry, "right")
	if abandoned.get("questState", {}).get("questOutcomes", {}).get(
			"spell_codex") != "abandoned" \
			or abandoned.get("flags", {}).get("spellCodexCompleted") == true:
		return _fail("spell codex refusal was awarded or remained active: "
			+ JSON.stringify({"phase": abandoned.get("phase"),
				"outcome": abandoned.get("questState", {}).get("questOutcomes"),
				"error": flow.last_error}))
	var second: Dictionary = flow.settle(entry, "left")
	var studied: Dictionary = flow.settle(second, "left")
	if second.get("currentCardId") != "q_spell_2" \
			or studied.get("currentCardId") != "q_spell_3" \
			or int(studied.get("knowledge", {}).get("spell", 0)) != 1 \
			or _seed(studied, "spellCodexStarted").get("realm") != "golden":
		return _fail("spell codex study did not seed authored future echo")
	var refused: Dictionary = flow.settle(studied, "left")
	if refused.get("currentCardId") != "q_spell_4" \
			or int(refused.get("knowledge", {}).get("spell", 0)) != 2 \
			or _seed(refused, "spellCodexRefused").get("realm") != "nascent":
		return _fail("spell codex refused contract lost array-form causal seed")
	var completed: Dictionary = flow.settle(refused, "left")
	if completed.get("questState", {}).get("questOutcomes", {}).get(
			"spell_codex") != "completed" \
			or completed.get("flags", {}).get("spellCodexCompleted") != true \
			or completed.get("opportunityAcquisitions", {}).get(
				"spell_codex_completion_v1", {}).get("profile") != "seal_keeper" \
			or not completed.get("deck", []).has("spell_seal_reversal") \
			or _seed(completed, "spellCodexDisclosure").get("realm") != "nascent" \
			or _seed(completed, "spellCodexEcho").get("realm") != "golden":
		return _fail("spell codex sealed ending lost special legacy or completion echo")
	var accepted: Dictionary = flow.settle(studied, "right")
	if accepted.get("currentCardId") != "q_spell_4" \
			or accepted.get("pendingQuestCard", {}).get("description") != \
				source.cards[3].stateVariants[0].description \
			or _seed(accepted, "spellCodexContract").get("realm") != "nascent":
		return _fail("spell codex accepted contract did not project fourth-card variant")
	var failed: Dictionary = flow.settle(accepted, "right")
	if failed.get("questState", {}).get("questOutcomes", {}).get(
			"spell_codex") != "failed" \
			or failed.get("flags", {}).get("spellCodexCompleted") == true \
			or failed.get("opportunityAcquisitions", {}).has(
				"spell_codex_completion_v1") \
			or not _seed(failed, "spellCodexEcho").is_empty():
		return _fail("spell codex failed ending received completion reward")
	var asked: Dictionary = flow.settle(second, "right")
	if asked.get("currentCardId") != "q_spell_3" \
			or asked.get("pendingQuestCard", {}).get("description") != \
				source.cards[2].stateVariants[0].description:
		return _fail("spell codex history-only choice lost authored third-card variant")
	print("NONCOMBAT_FOUNDATION_SPELL_QUEST_PASS entry=true variant=true seeds=true reward=true failed=true")
	quit(0)
