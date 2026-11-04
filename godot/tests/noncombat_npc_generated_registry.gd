extends SceneTree

const Repository = preload("res://scripts/noncombat_content_repository.gd")
const NpcFlow = preload("res://scripts/noncombat_npc_encounter_flow.gd")

func _initialize() -> void:
	var repo = Repository.new()
	if not repo.build_index():
		return _fail("source repository unavailable")
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(
		"res://content/derived/npc_encounter_templates.json"))
	if FileAccess.get_sha256("res://../src/systems/NpcSystem.js") != catalog.sourceSha:
		return _fail("current browser NPC producer SHA diverged")
	var count := 0
	for npc_id in catalog.templates:
		for scene in catalog.templates[npc_id]["sword"]:
			var card_id := "npc_encounter_%s_%s" % [npc_id, scene]
			var source: Dictionary = repo.find("generated_card", card_id)
			if source.get("sourcePath") != "src/systems/NpcSystem.js" \
					or source.get("sourceSha256") != catalog.sourceSha \
					or source.get("npcId") != npc_id \
					or source.get("scene") != scene \
					or source.get("producerBrowser") != "src/systems/NpcSystem.js::_buildEncounterCard" \
					or source.get("producerGodot") != "res://scripts/noncombat_npc_encounter_flow.gd::_general_card":
				return _fail("NPC card source missing: " + card_id)
			for path in catalog.templates[npc_id]:
				for emotion in catalog.templates[npc_id][path][scene]:
					var variant: Dictionary = source.get("variants", {}).get(path, {}).get(emotion, {})
					if variant.get("pointer") != "$.templates.%s.%s.%s.%s" % [npc_id,path,scene,emotion] \
							or variant.get("card") != catalog.templates[npc_id][path][scene][emotion]:
						return _fail("NPC card variant source missing: " + card_id)
					count += 1
	if count != 768:
		return _fail("NPC source variant inventory incomplete")
	var duplicate = Repository.new()
	if not duplicate.build_index():
		return _fail("duplicate NPC baseline unavailable")
	duplicate._index_document("data/npcs/core_npcs.json", {"npcs": [
		{"id": "bai_ren", "name": "白刃真人"}]})
	if not duplicate.errors().any(func(message: String) -> bool:
		return message.contains("Duplicate generated_card ID: npc_encounter_bai_ren_初见")):
		return _fail("duplicate NPC generated ID was accepted")
	var flow = NpcFlow.new(repo)
	if flow._general_card({"path":"sword","realm":"qi"}, "bai_ren", "初见",
			"青云剑宗", "平静").get("id") != "npc_encounter_bai_ren_初见":
		return _fail("registered NPC source did not reach producer")
	var forged_repo = Repository.new()
	if not forged_repo.build_index():
		return _fail("forged NPC baseline unavailable")
	forged_repo._indexes["generated_card"]["npc_encounter_bai_ren_初见"][
		"variants"]["sword"]["平静"]["card"]["title"] = "forged"
	var forged_flow = NpcFlow.new(forged_repo)
	if not forged_flow._general_card({"path":"sword","realm":"qi"}, "bai_ren", "初见",
			"青云剑宗", "平静").is_empty():
		return _fail("NPC producer accepted a forged registered variant")
	print("NONCOMBAT_NPC_GENERATED_REGISTRY_PASS ids=64 variants=768 duplicate=rejected")
	quit(0)

func _fail(message: String) -> void:
	push_error(message)
	quit(1)
