extends SceneTree

const Repository = preload("res://scripts/noncombat_content_repository.gd")
const Mentor = preload("res://scripts/noncombat_mentor_flow.gd")
const STAGES := ["INNER_DISCIPLE", "TRUSTED", "HEIR", "LEGACY"]

func _initialize() -> void:
	var repo = Repository.new()
	if not repo.build_index():
		return _fail("source repository unavailable")
	var source: Dictionary = repo.read_module("companions:arcs")
	var mentor: Dictionary = source.mentorArc.bai_ren
	if FileAccess.get_sha256("res://tests/fixtures/source/src/systems/StoryNetworkSystem.js") != \
			Repository.STORY_RULE_SHA or not mentor.get("revelation") == null:
		return _fail("mentor production source changed")
	var specs := []
	for stage in STAGES:
		specs.append({"id": "mentor_bai_ren_stage_" + stage,
			"pointer": "$.mentorArc.bai_ren.arcStages." + stage,
			"data": mentor.arcStages[stage], "stage": stage, "kind": "stage"})
	for item in [{"id":"mentor_bai_ren_tribulation","key":"tribulationClimax"},
			{"id":"mentor_bai_ren_destiny","key":"destinyClimax"}]:
		specs.append({"id":item.id,"pointer":"$.mentorArc.bai_ren." + item.key,
			"data":mentor[item.key],"stage":item.id,"kind":"climax"})
	for spec in specs:
		var row: Dictionary = repo.find("generated_card", spec.id)
		if row.get("data") != spec.data or row.get("sourcePath") != \
				"src/systems/StoryNetworkSystem.js" \
				or row.get("sourceSha256") != Repository.STORY_RULE_SHA \
				or row.get("authorPath") != "data/companions/arcs.json" \
				or row.get("authorPointer") != spec.pointer \
				or row.get("authorSha256") != repo.source_sha256("companions:arcs") \
				or row.get("producerGodot") != "res://scripts/noncombat_mentor_flow.gd::_project_card":
			return _fail("mentor generated card source missing: " + spec.id)
		if Mentor.new(repo)._project_card({"realm":"qi"}, spec.stage, spec.kind).get("id") != spec.id:
			return _fail("mentor source did not reach card producer: " + spec.id)
	if not repo.find("generated_card", "mentor_bai_ren_stage_DISCIPLE").is_empty() \
			or not repo.find("generated_card", "mentor_bai_ren_revelation").is_empty():
		return _fail("unproduced mentor author fields were falsely registered")
	var duplicate = Repository.new()
	if not duplicate.build_index():
		return _fail("duplicate baseline unavailable")
	duplicate._index_document("data/companions/arcs.json", source)
	if not duplicate.errors().any(func(message: String) -> bool:
		return message.contains("Duplicate generated_card ID: mentor_bai_ren_stage_INNER_DISCIPLE")):
		return _fail("duplicate mentor generated ID accepted")
	repo._indexes["generated_card"]["mentor_bai_ren_stage_INNER_DISCIPLE"]["data"]["title"] = "forged"
	if not Mentor.new(repo)._project_card({"realm":"qi"}, "INNER_DISCIPLE").is_empty():
		return _fail("mentor producer accepted forged registration")
	print("NONCOMBAT_MENTOR_GENERATED_REGISTRY_PASS ids=6 unproduced=2 duplicate=rejected forged=rejected")
	quit(0)

func _fail(message: String) -> void:
	push_error(message)
	quit(1)
