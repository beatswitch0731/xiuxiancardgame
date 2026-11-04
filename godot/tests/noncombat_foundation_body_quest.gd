extends "res://tests/noncombat_foundation_sword_trial_contract.gd"

const QuestFlow = preload("res://scripts/noncombat_quest_flow.gd")
const ContentRepository = preload("res://scripts/noncombat_content_repository.gd")
const BODY := "res://content/data/quests/body_tribulation.json"


func _run() -> void:
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(BODY))
	var path := "user://tests/foundation_body_quest_%d.json" % Time.get_ticks_usec()
	var game = Domain.new(Registry.new(), Session.new(path, "slot_2"), "slot_2")
	if not game.start("body"):
		return _fail("body route could not start")
	var state: Dictionary = game.state.duplicate(true)
	state.phase = "FLOW_PENDING"
	state.realm = "foundation"
	state.turn = 10
	state.runClock.decisionIndex = 10
	state.maxHealth = 12
	state.maxDaoHeart = 5
	state.attributes.health = 10
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
	var regen_state: Dictionary = state.duplicate(true)
	regen_state.attributes.health = 1
	regen_state["equipment"] = {"accessory": "灵泉葫芦"}
	var regen_entry: Dictionary = flow.resume(regen_state)
	var regen_choice: Dictionary = flow.settle(regen_entry, "left")
	if regen_choice.is_empty() or int(regen_choice.attributes.health) != 1:
		return _fail("body quest choice omitted equipped source passive recovery")
	var entry: Dictionary = flow.resume(state)
	if entry.get("currentCardId") != "q_body_1" \
			or entry.get("pendingQuestCard", {}).get("sceneImage") != source.cards[0].sceneImage:
		return _fail("body quest did not enter from eligible foundation state")
	var refused: Dictionary = flow.settle(entry, "right")
	if refused.get("questState", {}).get("questOutcomes", {}).get(
			"body_tribulation") != "abandoned" \
			or refused.get("flags", {}).get("bodyTribulationCompleted") == true:
		return _fail("body quest refusal was rewarded or left open")
	var second: Dictionary = flow.settle(entry, "left")
	var third: Dictionary = flow.settle(second, "right")
	var withdrawn: Dictionary = flow.settle(third, "right")
	if second.get("currentCardId") != "q_body_2" \
			or third.get("currentCardId") != "q_body_3" \
			or withdrawn.get("currentCardId") != "q_body_4" \
			or withdrawn.get("pendingQuestCard", {}).get("description") != \
				source.cards[3].stateVariants[0].description \
			or withdrawn.get("flags", {}).get("bodyWaterfallWithdrew") != true:
		return _fail("body quest withdrawal did not project the fourth-card variant")
	var prior := withdrawn.duplicate(true)
	var finished: Dictionary = flow.settle(withdrawn, "right")
	var reward: Dictionary = finished.get("opportunityAcquisitions", {}).get(
		"body_tribulation_completion_v1", {})
	var skill_source: Dictionary = ContentRepository.new().read_module("config:path_skills")
	var body_max_hp := int(skill_source.get("skills", {}).get("body", {}).get(
		"skills", [])[0].get("passive", {}).get("maxHp", 0))
	if reward.get("profile") != "qi_guarded" \
			or finished.get("questState", {}).get("questOutcomes", {}).get(
				"body_tribulation") != "completed" \
			or int(finished.get("attributes", {}).get("health", -1)) != mini(
				int(prior.get("maxHealth", 10)) + body_max_hp,
				int(prior.attributes.health) + 3) \
			or finished.get("karmaSeeds", []).any(func(seed: Variant) -> bool:
			return seed is Dictionary and seed.get("id") == "bodyTrialDeep"):
		return _fail("body quest guarded ending omitted source reward or added deep seed: "
			+ JSON.stringify({"reward": reward, "outcome": finished.get("questState", {}).get(
				"questOutcomes", {}).get("body_tribulation"),
				"healthBefore": prior.attributes.health,
				"healthAfter": finished.get("attributes", {}).get("health"),
				"maxHealth": prior.get("maxHealth"),
				"bodyMaxHpPassive": body_max_hp,
				"seeds": finished.get("karmaSeeds", [])}))
	var persevered: Dictionary = flow.settle(third, "left")
	if persevered.get("currentCardId") != "q_body_4" \
			or persevered.get("flags", {}).get("bodyWaterfallPersevered") != true \
			or _seed(persevered, "bodyTrialStarted").get("delay") != 6:
		return _fail("body waterfall perseverance did not plant the authored seed")
	var deep: Dictionary = flow.settle(persevered, "left")
	if deep.get("questState", {}).get("questOutcomes", {}).get(
			"body_tribulation") != "completed" \
			or _seed(deep, "bodyTrialDeep").get("delay") != 9 \
			or deep.get("opportunityAcquisitions", {}).get(
				"body_tribulation_completion_v1", {}).get("mode") != "special" \
			or not deep.get("deck", []).has("body_thunder_temper"):
		return _fail("body deep ending lost special legacy or deep karma")
	print("NONCOMBAT_FOUNDATION_BODY_QUEST_PASS entry=true variant=true reward=true deep=true")
	quit(0)


func _seed(state: Dictionary, seed_id: String) -> Dictionary:
	for row in state.get("karmaSeeds", []):
		if row is Dictionary and row.get("id") == seed_id:
			return row
	return {}
