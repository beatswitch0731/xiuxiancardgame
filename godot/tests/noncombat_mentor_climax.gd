extends SceneTree

const Registry = preload("res://scripts/runtime_data_registry.gd")
const Domain = preload("res://scripts/noncombat_domain.gd")
const Repository = preload("res://scripts/noncombat_content_repository.gd")
const MentorFlow = preload("res://scripts/noncombat_mentor_flow.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var game = Domain.new(Registry.new(), null, "slot_3")
	if not game.start("sword"):
		return _fail("source opening unavailable")
	var flow = MentorFlow.new(Repository.new())
	var before: Dictionary = game.state.duplicate(true)
	before["phase"] = "FLOW_PENDING"
	before["realm"] = "golden"
	before["noncombatFlow"] = {"scope": "first_session_avoid"}
	before["decisionCheckpoint"] = {"sourceCardId": "ch_qi_60"}
	var old: Dictionary = MentorFlow.initial_state()
	old["version"] = 3
	old.erase("climaxActivationIndex")
	old.erase("pendingClimaxes")
	old.erase("climaxTriggered")
	old["stage"] = "HEIR"
	old["stageIndex"] = 3
	old["progression"] = 61
	var after: Dictionary = before.duplicate(true)
	after["runClock"]["decisionIndex"] = 1
	after["mentorArcState"] = old.duplicate(true)
	var replayed: Dictionary = MentorFlow.advance(before, after, old,
		true, [], true, false)
	if replayed.get("version") != 3 or replayed.has("pendingClimaxes"):
		return _fail("v3 replay acquired future climax")
	var upgraded: Dictionary = MentorFlow.advance(before, after, old,
		true, [], true, true)
	if upgraded.get("version") != 4 \
			or upgraded.get("climaxActivationIndex") != 1 \
			or upgraded.get("pendingClimaxes") != [MentorFlow.TRIBULATION_CARD_ID]:
		return _fail("golden HEIR did not queue source climax")
	before["mentorArcState"] = upgraded
	var shown: Dictionary = flow.resume(before, false, "climax")
	var card: Dictionary = shown.get("pendingMentorCard", {})
	if card.get("id") != MentorFlow.TRIBULATION_CARD_ID \
			or card.get("title") != "师尊·剑劫" \
			or card.get("arcStage") != "CLIMAX" \
			or card.get("choices", {}).get("left", {}).get("effects", {}).get("health") != -3:
		return _fail("tribulation source card was not projected")
	var health := int(shown.get("attributes", {}).get("health", 0))
	var settled: Dictionary = flow.settle(shown, "left")
	if settled.get("phase") != "NARRATIVE_RESULT_PENDING" \
			or int(settled.get("attributes", {}).get("health", -1)) != maxi(0, health - 3) \
			or not settled.get("mentorArcState", {}).get("climaxTriggered", false) \
			or not settled.get("mentorArcState", {}).get("eventsTriggered", []).has(
				MentorFlow.TRIBULATION_CARD_ID):
		return _fail("tribulation choice did not settle")
	var destiny: Dictionary = before.duplicate(true)
	destiny["realm"] = "deity"
	destiny["mentorArcState"]["stage"] = "LEGACY"
	destiny["mentorArcState"]["stageIndex"] = 4
	destiny["mentorArcState"]["climaxTriggered"] = true
	destiny["mentorArcState"]["pendingClimaxes"] = [MentorFlow.DESTINY_CARD_ID]
	var destiny_shown: Dictionary = flow.resume(destiny, false, "climax")
	if destiny_shown.get("pendingMentorCard", {}).get("title") != "师尊·薪火相传":
		return _fail("destiny source card was not projected")
	var destiny_settled: Dictionary = flow.settle(destiny_shown, "right")
	var bai_ren: Dictionary = destiny_settled.get("worldContinuityState", {}).get(
		"npcs", {}).get("bai_ren", {})
	if destiny_settled.get("phase") != "NARRATIVE_RESULT_PENDING" \
			or bai_ren.get("lifecycle") != "ASCENDED" \
			or bai_ren.get("manifestation") != "ECHO_ONLY" \
			or bai_ren.get("locationId") != "upper_realm_heaven_gate" \
			or bai_ren.get("changedByNode") != MentorFlow.DESTINY_CARD_ID:
		return _fail("destiny choice did not ascend source NPC: " + str(bai_ren))
	destiny_settled["phase"] = "FLOW_PENDING"
	if not flow.resume(destiny_settled, false, "climax").is_empty():
		return _fail("ascended mentor produced another physical climax")
	print("NONCOMBAT_MENTOR_CLIMAX_PASS replay=true cards=true effects=true ascension=true")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
