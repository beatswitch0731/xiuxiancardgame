extends SceneTree

const Repository = preload("res://scripts/noncombat_content_repository.gd")
const ArcFlow = preload("res://scripts/noncombat_companion_arc_flow.gd")

func _initialize() -> void:
	var repo = Repository.new()
	if not repo.build_index():
		return _fail("source index unavailable")
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(
		"res://content/derived/companion_arc_cards.json"))
	if FileAccess.get_sha256("res://../src/systems/StoryNetworkSystem.js") != catalog.ruleSha:
		return _fail("browser arc producer SHA changed")
	var count := 0
	for comp_id in catalog.cards:
		for i in range(catalog.cards[comp_id].size()):
			var card: Dictionary = catalog.cards[comp_id][i]
			var suffix: String = String(card.id).trim_prefix("arc_%s_" % comp_id)
			var author_branch: String = "arcStages." + suffix.trim_prefix("stage_") \
				if suffix.begins_with("stage_") else {
					"secret_reveal": "secretReveal", "tribulation": "tribulationClimax",
					"destiny": "destinyClimax"}.get(suffix, "")
			var source: Dictionary = repo.find("generated_card", card.id)
			if source.get("data") != card or source.get("companionId") != comp_id \
					or source.get("sourcePath") != "src/systems/StoryNetworkSystem.js" \
					or source.get("sourceSha256") != catalog.ruleSha \
					or source.get("authorPath") != "data/companions/arcs.json" \
					or source.get("authorPointer") != "$.companionArcs.%s.%s" % [comp_id,author_branch] \
					or source.get("authorSha256") != catalog.dataSha \
					or source.get("derivedCatalogSha256") != ArcFlow.CATALOG_SHA \
					or source.get("derivedCatalogPointer") != "$.cards.%s[%d]" % [comp_id,i] \
					or source.get("producerBrowser") != "src/systems/StoryNetworkSystem.js" \
					or source.get("producerGodot") != "res://scripts/noncombat_companion_arc_flow.gd::_project":
				return _fail("companion arc generated card provenance lost: " + card.id)
			count += 1
	if count != 40:
		return _fail("companion arc source count changed")
	var duplicate = Repository.new()
	if not duplicate.build_index():
		return _fail("duplicate baseline unavailable")
	duplicate._index_document("data/companions/arcs.json", repo.read_module("companions:arcs"))
	if not duplicate.errors().any(func(message: String) -> bool:
		return message.contains("Duplicate generated_card ID: arc_bai_luoxuan_stage_ACQUAINTANCE")):
		return _fail("duplicate arc generated ID was accepted")
	var flow = ArcFlow.new(repo)
	if flow._project("bai_luoxuan", "arc_bai_luoxuan_stage_ACQUAINTANCE",
			"qi").is_empty():
		return _fail("registered arc did not project")
	repo._indexes["generated_card"]["arc_bai_luoxuan_stage_ACQUAINTANCE"]["data"]["title"] = "forged"
	if not flow._project("bai_luoxuan", "arc_bai_luoxuan_stage_ACQUAINTANCE",
			"qi").is_empty():
		return _fail("arc producer accepted forged registration")
	print("NONCOMBAT_COMPANION_ARC_REGISTRY_PASS owners=5 ids=40 duplicate=rejected forged=rejected")
	quit(0)

func _fail(message: String) -> void:
	push_error(message)
	quit(1)
