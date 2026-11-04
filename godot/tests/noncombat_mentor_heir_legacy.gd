extends SceneTree

const Registry = preload("res://scripts/runtime_data_registry.gd")
const Domain = preload("res://scripts/noncombat_domain.gd")
const Repository = preload("res://scripts/noncombat_content_repository.gd")
const MentorFlow = preload("res://scripts/noncombat_mentor_flow.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var flow = MentorFlow.new(Repository.new())
	for pair in [{"progress": 59, "gain": 2, "stage": "HEIR", "index": 3},
			{"progress": 79, "gain": 2, "stage": "LEGACY", "index": 4}]:
		var before := {"attributes": {"cultivation": 40},
			"runClock": {"decisionIndex": 10}, "choiceHistory": []}
		var after := {"attributes": {"cultivation": 42},
			"runClock": {"decisionIndex": 11}, "choiceHistory": []}
		var arc: Dictionary = MentorFlow.initial_state()
		arc["progression"] = pair.progress
		arc["stageIndex"] = pair.index - 1
		arc["stage"] = "TRUSTED" if pair.stage == "HEIR" else "HEIR"
		var advanced: Dictionary = MentorFlow.advance(before, after, arc, true, [6])
		if advanced.get("stage") != pair.stage \
				or advanced.get("stageIndex") != pair.index \
				or advanced.get("pendingStages") != [pair.stage] \
				or advanced.get("progression") != pair.progress + pair.gain:
			return _fail("mentor threshold did not queue authored stage: " + pair.stage)
	var game = Domain.new(Registry.new(), null, "slot_3")
	if not game.start("sword"):
		return _fail("source opening unavailable")
	var candidate: Dictionary = game.state.duplicate(true)
	candidate["phase"] = "FLOW_PENDING"
	candidate["noncombatFlow"] = {"scope": "first_session_avoid"}
	candidate["decisionCheckpoint"] = {"sourceCardId": "ch_qi_60"}
	candidate["attributes"]["health"] = 1
	var heir: Dictionary = MentorFlow.initial_state()
	heir["stage"] = "HEIR"
	heir["stageIndex"] = 3
	heir["progression"] = 61
	heir["pendingStages"] = ["HEIR"]
	candidate["mentorArcState"] = heir
	var shown: Dictionary = flow.resume(candidate)
	var card: Dictionary = shown.get("pendingMentorCard", {})
	if card.get("id") != "mentor_bai_ren_stage_HEIR" \
			or card.get("title") != "师尊·托剑" \
			or card.get("choices", {}).get("left", {}).get("effects", {}).get("health") != 10:
		return _fail("HEIR source card did not project")
	var settled: Dictionary = flow.settle(shown, "left")
	if settled.get("phase") != "NARRATIVE_RESULT_PENDING" \
			or settled.get("attributes", {}).get("health") != \
				int(shown.get("maxHealth", 0)) \
			or settled.get("mentorArcState", {}).get("pendingStages") != [] \
			or not settled.get("mentorArcState", {}).get("eventsTriggered", []).has(
				"mentor_bai_ren_stage_HEIR"):
		return _fail("HEIR choice did not apply source health and response: phase=%s health=%s arc=%s error=%s" % [
			settled.get("phase"), settled.get("attributes", {}).get("health"),
			settled.get("mentorArcState", {}), flow.last_error])
	var legacy: Dictionary = MentorFlow.initial_state()
	legacy["stage"] = "LEGACY"
	legacy["stageIndex"] = 4
	legacy["progression"] = 81
	legacy["pendingStages"] = ["LEGACY"]
	candidate["mentorArcState"] = legacy
	var legacy_shown: Dictionary = flow.resume(candidate)
	if legacy_shown.get("pendingMentorCard", {}).get("id") != \
			"mentor_bai_ren_stage_LEGACY" \
			or legacy_shown.get("pendingMentorCard", {}).get("title") != "师尊·道同":
		return _fail("LEGACY source card did not project")
	var v2: Dictionary = MentorFlow.initial_state()
	v2["version"] = 2
	v2.erase("heirActivationIndex")
	v2.erase("climaxActivationIndex")
	v2.erase("pendingClimaxes")
	v2.erase("climaxTriggered")
	v2["stage"] = "TRUSTED"
	v2["stageIndex"] = 2
	v2["progression"] = 65
	candidate["mentorArcState"] = v2
	if not flow.resume(candidate).is_empty():
		return _fail("v2 strict replay produced a future stage")
	var before_v2 := {"attributes": {"cultivation": 40},
		"runClock": {"decisionIndex": 10}, "choiceHistory": []}
	var after_v2 := {"attributes": {"cultivation": 42},
		"runClock": {"decisionIndex": 11}, "choiceHistory": []}
	var replayed: Dictionary = MentorFlow.advance(before_v2, after_v2, v2,
		true, [6], false)
	if replayed.get("version") != 2 or replayed.get("stageIndex") != 2:
		return _fail("v2 historical decision acquired a future stage")
	var earned: Dictionary = MentorFlow.advance(before_v2, after_v2, v2,
		true, [6], true)
	if earned.get("version") != 4 or earned.get("heirActivationIndex") != 11 \
			or earned.get("climaxActivationIndex") != 11:
		return _fail("v2 live decision did not record v4 activation indices")
	candidate["mentorArcState"] = earned
	candidate["runClock"]["decisionIndex"] = 11
	candidate["turn"] = 11
	var upgraded: Dictionary = flow.resume(candidate)
	if upgraded.get("mentorArcState", {}).get("version") != 4 \
			or upgraded.get("pendingMentorCard", {}).get("id") != \
				"mentor_bai_ren_stage_HEIR":
		return _fail("v2 live continuation did not queue earned HEIR stage")
	print("NONCOMBAT_MENTOR_HEIR_LEGACY_PASS stages=true source=true choice=true v2=true")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
