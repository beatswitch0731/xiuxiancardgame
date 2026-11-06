extends SceneTree

const Repository = preload("res://scripts/noncombat_content_repository.gd")
const Events = preload("res://scripts/noncombat_companion_events.gd")

func _initialize() -> void:
	var repo = Repository.new()
	if not repo.build_index():
		return _fail("source repository did not index")
	var companions: Dictionary = repo.read_module("npcs:core")
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(
		"res://content/derived/companion_milestones.json"))
	if companions.npcs.size() != 16 or catalog.milestones.size() != 5 \
			or FileAccess.get_sha256("res://tests/fixtures/source/src/systems/CompanionSystem.js") != \
			catalog.sourceSha:
		return _fail("current browser milestone source or NPC family diverged")
	for i in range(companions.npcs.size()):
		for j in range(catalog.milestones.size()):
			var comp_id: String = companions.npcs[i].id
			var kind: String = catalog.milestones[j].id
			var card_id := "comp_%s_milestone_%s" % [comp_id, kind]
			var row: Dictionary = repo.find("generated_card", card_id)
			if row.get("sourcePath") != "src/systems/CompanionSystem.js" \
					or row.get("sourceLocation") != "_buildMilestoneCard:milestoneData." + kind \
					or row.get("sourceSha256") != catalog.sourceSha \
					or row.get("companionId") != comp_id \
					or row.get("data", {}).get("id") != kind \
					or row.get("derivedCatalogPointer") != "$.milestones[%d]" % j \
					or row.get("producerBrowser") != "src/systems/CompanionSystem.js::_buildMilestoneCard" \
					or row.get("producerGodot") != "res://scripts/noncombat_companion_events.gd::_milestone_card":
				return _fail("milestone card lost source identity: " + card_id)
	var duplicate_repo = Repository.new()
	if not duplicate_repo.build_index():
		return _fail("duplicate-source baseline did not index")
	duplicate_repo._index_document("data/npcs/core_npcs.json", {"npcs": [
		{"id": "ds_demoness", "name": "魔女"}]})
	if not duplicate_repo.errors().any(func(message: String) -> bool:
		return message.contains("Duplicate generated_card ID: ") \
			and message.contains("comp_ds_demoness_milestone_bond_acquaint")):
		return _fail("duplicate milestone ID survived source-document indexing")
	var forged_id := "comp_ds_demoness_milestone_bond_acquaint"
	repo._indexes["generated_card"][forged_id]["data"]["threshold"] = 999
	var events = Events.new(repo)
	if not events._milestone_card({"realm": "qi"}, {"compId": "ds_demoness",
			"id": "bond_acquaint", "name": "魔女"}).is_empty():
		return _fail("milestone consumer accepted a forged registered source")
	print("NONCOMBAT_COMPANION_MILESTONE_REGISTRY_PASS count=80 source=true")
	quit(0)

func _fail(message: String) -> void:
	push_error(message)
	quit(1)
