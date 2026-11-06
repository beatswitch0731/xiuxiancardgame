extends SceneTree

const Repository = preload("res://scripts/noncombat_content_repository.gd")
const Events = preload("res://scripts/noncombat_companion_events.gd")
const GENERIC_IDS := ["generic_daily", "generic_emo", "generic_help"]

func _initialize() -> void:
	var repo = Repository.new()
	if not repo.build_index():
		return _fail("content source unavailable")
	var npcs: Dictionary = repo.read_module("npcs:core")
	var authored: Dictionary = repo.read_module("companions:events")
	var authored_ids := {}
	for row in authored.companions:
		authored_ids[row.id] = true
	var generic_ids := []
	for npc in npcs.npcs:
		if not authored_ids.has(npc.id):
			generic_ids.append(npc.id)
	if generic_ids.size() != 8 or FileAccess.get_sha256(
			"res://tests/fixtures/source/src/systems/CompanionSystem.js") != Events.RULE_SHA:
		return _fail("generic companion source or owner inventory changed")
	for npc_id in generic_ids:
		for kind in GENERIC_IDS:
			var card_id := "comp_%s_%s" % [npc_id, kind]
			var source: Dictionary = repo.find("generated_card", card_id)
			if source.get("companionId") != npc_id \
					or source.get("eventId") != kind \
					or source.get("sourcePath") != "src/systems/CompanionSystem.js" \
					or source.get("sourceSha256") != Events.RULE_SHA \
					or source.get("npcSourceSha256") != repo.source_sha256("npcs:core") \
					or source.get("producerBrowser") != "src/systems/CompanionSystem.js::_getGenericEvent/_buildEventCard" \
					or source.get("producerGodot") != "res://scripts/noncombat_companion_events.gd::_generic_events/_build_card":
				return _fail("generic companion card source missing: " + card_id)
	var duplicate = Repository.new()
	if not duplicate.build_index():
		return _fail("duplicate baseline unavailable")
	duplicate._index_document("data/npcs/core_npcs.json", {"npcs": [
		{"id": "mortal", "name": "凡人"}]})
	if not duplicate.errors().any(func(message: String) -> bool:
		return message.contains("Duplicate generated_card ID: comp_mortal_generic_daily")):
		return _fail("duplicate generic card ID was accepted")
	print("NONCOMBAT_COMPANION_GENERIC_REGISTRY_PASS owners=8 ids=24 duplicate=rejected")
	quit(0)

func _fail(message: String) -> void:
	push_error(message)
	quit(1)
