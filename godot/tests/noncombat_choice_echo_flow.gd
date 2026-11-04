extends SceneTree

const EchoFlow = preload("res://scripts/noncombat_choice_echo_flow.gd")

func _initialize() -> void:
	call_deferred("_run")

func _base() -> Dictionary:
	var state := {"phase": "FLOW_PENDING", "turn": 10,
		"realm": "foundation", "lifeCount": 0, "currentLocation": "宗门",
		"runClock": {"lifeId": "slot_1:life:0", "decisionIndex": 10,
			"receipts": {}}, "npcAffection": {"bai_ren": 50},
		"attributes": {"cultivation": 20, "daoHeart": 2, "health": 5,
			"fortune": 50, "karmaGood": 0, "karmaBad": 0},
		"maxDaoHeart": 3, "maxHealth": 6,
		"resources": {"spiritStone": 10, "lifespan": 80,
			"pills": {}, "treasures": [], "companions": []},
		"equipment": {"weapon": null, "armor": null,
			"accessory": null, "artifact": null},
		"treasureInstances": {}, "treasureInventory": [],
		"treasureCommandReceipts": {}, "treasureCooldowns": {},
		"knowledge": {}, "clues": [], "cardsPlayed": [],
		"choiceHistory": [], "replayHistory": [], "recentCardTags": [],
		"decisionCheckpoint": {"sourceCardId": "mentor_bai_ren_stage_INNER_DISCIPLE"},
		"karmaSeeds": []}
	return state

func _run() -> void:
	var flow = EchoFlow.new()
	var state := _base()
	state["choiceEchoState"] = flow.marker(0)
	state["choiceEchoes"] = []
	var mentor := {"id": "mentor_bai_ren_stage_INNER_DISCIPLE",
		"type": "MENTOR_ARC", "npcId": "bai_ren",
		"choices": {"left": {"text": "立誓", "effects": {}},
			"right": {"text": "推辞", "effects": {}}}}
	if not flow.plant(state, mentor, "left") \
			or state.choiceEchoes.size() != 1 \
			or state.choiceEchoes[0].templateId != "bai_ren_war_flashback":
		_fail("war echo seed missing: " + flow.last_error)
		return
	state["turn"] = 29
	state["runClock"]["decisionIndex"] = 29
	state["realm"] = "golden"
	if not flow.take(state).is_empty():
		_fail("war echo ignored its twenty-turn delay")
		return
	state["turn"] = 30
	state["runClock"]["decisionIndex"] = 30
	state["realm"] = "foundation"
	if not flow.take(state).is_empty():
		_fail("war echo ignored its golden-realm gate")
		return
	state["realm"] = "golden"
	var pending: Dictionary = flow.take(state)
	if pending.get("phase") != "CHOICE_ECHO_PENDING" \
			or flow.card(pending).get("choices", {}).get("left", {}).get(
				"effects", {}).get("find_clue") != "century_war_truth":
		_fail("war echo not issued: " + flow.last_error)
		return
	var tampered: Dictionary = pending.duplicate(true)
	tampered["pendingEchoCard"]["description"] = "伪造内容"
	if not flow.card(tampered).is_empty() or not flow.settle(tampered, "left").is_empty():
		_fail("tampered echo card was accepted")
		return
	var settled: Dictionary = flow.settle(pending, "left")
	if settled.get("clues", []).size() != 1 \
			or settled.clues[0].id != "century_war_truth" \
			or settled.get("knowledge", {}).get("wisdom") != 5 \
			or settled.get("runClock", {}).get("decisionIndex") != 31 \
			or settled.get("phase") != "FLOW_PENDING" \
			or not flow.take(settled).is_empty():
		_fail("war echo settlement or once semantics failed: " + flow.last_error)
		return
	var sword := _base()
	sword.npcAffection.bai_ren = 60
	sword["choiceEchoState"] = flow.marker(0)
	sword["choiceEchoes"] = []
	if not flow.plant(sword, mentor, "right") \
			or sword.choiceEchoes[0].templateId != "bai_ren_sword_trust":
		_fail("sword trust seed missing")
		return
	sword.turn = 25
	sword.runClock.decisionIndex = 25
	sword["deadNpcs"] = ["bai_ren"]
	if not flow.take(sword).is_empty():
		_fail("dead mentor still generated an echo")
		return
	sword["deadNpcs"] = []
	var sword_pending: Dictionary = flow.take(sword)
	var sword_settled: Dictionary = flow.settle(sword_pending, "left")
	if sword_settled.is_empty() or not sword_settled.resources.treasures.has(
			"fallen_sword_of_shixiong"):
		_fail("sword trust treasure missing: " + flow.last_error)
		return
	var scheduled := _base()
	scheduled.erase("npcAffection")
	scheduled["npcEncounterScheduling"] = {"affections": {"bai_ren": 60},
		"bonds": {"bai_ren": 2}}
	scheduled["choiceEchoState"] = flow.marker(0)
	scheduled["choiceEchoes"] = []
	if not flow.plant(scheduled, mentor, "left") \
			or scheduled.choiceEchoes[0].templateId != "bai_ren_sword_trust":
		_fail("scheduled mentor affection was not used to match the source template")
		return
	var generic := _base()
	generic.npcAffection = {"jian_linger": 0}
	generic["choiceEchoState"] = flow.marker(0)
	generic["choiceEchoes"] = []
	mentor.npcId = "jian_linger"
	if not flow.plant(generic, mentor, "left") \
			or generic.choiceEchoes[0].templateId != null:
		_fail("generic echo seed missing")
		return
	generic.turn = 25
	generic.runClock.decisionIndex = 25
	var generic_pending: Dictionary = flow.take(generic)
	if generic_pending.get("phase") != "CHOICE_ECHO_PENDING" \
			or flow.card(generic_pending).get("choices", {}).get("left", {}).get(
				"companionEffects", {}).get("value") != 3:
		_fail("generic echo missing")
		return
	print("NONCOMBAT_CHOICE_ECHO_FLOW_PASS war=true sword=true generic=true")
	quit(0)

func _fail(message: String) -> void:
	push_error(message)
	quit(1)
