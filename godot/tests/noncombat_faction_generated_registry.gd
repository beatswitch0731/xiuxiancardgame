extends SceneTree

const Repository = preload("res://scripts/noncombat_content_repository.gd")
const FactionFlow = preload("res://scripts/noncombat_faction_events.gd")


func _initialize() -> void:
	var repo = Repository.new()
	var card_id := "faction_wumeng_gatekeeper_call"
	var row: Dictionary = repo.find("generated_card", card_id)
	var gates: Dictionary = row.get("reachability", {})
	if repo.index_count("generated_card") != 55 \
			or row.get("sourcePath") != "data/world/factions.json" \
			or row.get("jsonPointer") != "$.factions[4].events[0]" \
			or row.get("sourceSha256") != repo.source_sha256("world:factions") \
			or row.get("data", {}).get("id") != "wumeng_gatekeeper_call" \
			or row.get("factionId") != "wumeng_alliance" \
			or row.get("producerBrowser") != "src/systems/FactionSystem.js::_buildFactionCard" \
			or row.get("producerGodot") != "res://scripts/noncombat_faction_events.gd::_build" \
			or gates.get("minRealm") != "foundation" \
			or gates.get("location") != row.get("data", {}).get("location") \
			or gates.get("requiresPlayerPresence") != true \
			or gates.get("deliveryClass") != "location_combat_invitation" \
			or gates.get("once") != true \
			or not gates.get("runtimeGates", []).has("cadence_15_ticks") \
			or not gates.get("runtimeGates", []).has("weighted_selection"):
		return _fail("faction generated ID lost exact source or reachability metadata")
	var source: Dictionary = repo.read_module("world:factions")
	var event_count := 0
	for i in range(source.factions.size()):
		var author_faction: Dictionary = source.factions[i]
		for j in range(author_faction.events.size()):
			var author_event: Dictionary = author_faction.events[j]
			var generated_id := "faction_" + String(author_event.id)
			var indexed: Dictionary = repo.find("generated_card", generated_id)
			if indexed.get("sourcePath") != "data/world/factions.json" \
					or indexed.get("jsonPointer") != "$.factions[%d].events[%d]" % [i, j] \
					or indexed.get("sourceSha256") != row.get("sourceSha256") \
					or indexed.get("factionId") != author_faction.id \
					or indexed.get("data") != author_event:
				return _fail("faction generated family omitted an authored event: " + generated_id)
			event_count += 1
	if event_count != 17:
		return _fail("authored faction event count changed without registry review")
	var faction: Dictionary = source.factions[4]
	var event: Dictionary = faction.events[0]
	var state := {"realm": "foundation"}
	var flow = FactionFlow.new(repo)
	if flow.source_card(state, card_id).get("id") != card_id \
			or not flow.source_card(state, "faction_unknown").is_empty():
		return _fail("faction source_card did not consume registered author event")
	var forged := event.duplicate(true)
	forged["title"] = "forged"
	if not flow._build(state, faction, forged).is_empty():
		return _fail("faction builder accepted an event differing from registry")
	var duplicate_repo = Repository.new()
	if duplicate_repo.read_module("world:factions") == null:
		return _fail("faction fixture could not load source manifest")
	duplicate_repo._index_document("data/world/factions.json", {"factions": [
		{"id": "first", "events": [event]},
		{"id": "second", "events": [event.duplicate(true)]}]})
	var duplicate_error := str(duplicate_repo.errors())
	if not duplicate_error.contains("Duplicate generated_card ID " + card_id) \
			or not duplicate_error.contains("$.factions[0].events[0]") \
			or not duplicate_error.contains("$.factions[1].events[0]"):
		return _fail("duplicate faction generated ID was accepted")
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(
		"res://content/source_manifest.json"))
	for entry in manifest.data:
		if entry.get("path") == "data/world/factions.json":
			entry["sha256"] = "0".repeat(64)
			break
	var fixture_path := "user://noncombat_corrupt_faction_manifest_test.json"
	var fixture := FileAccess.open(fixture_path, FileAccess.WRITE)
	if fixture == null:
		return _fail("cannot create faction SHA drift fixture")
	fixture.store_string(JSON.stringify(manifest))
	fixture.close()
	var stale = Repository.new(fixture_path)
	var stale_row: Dictionary = stale.find("generated_card", card_id)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(fixture_path))
	if not stale_row.is_empty() or not str(stale.errors()).contains(
			"Source SHA mismatch: data/world/factions.json"):
		return _fail("faction generated ID accepted a drifted source SHA")
	print("NONCOMBAT_FACTION_GENERATED_REGISTRY_PASS count=17 card=", card_id)
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
