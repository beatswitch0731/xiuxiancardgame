extends SceneTree

const Repository = preload("res://scripts/noncombat_content_repository.gd")
const Flow = preload("res://scripts/noncombat_narrative_surfacing.gd")

func _initialize() -> void:
	var repo = Repository.new()
	if not repo.build_index() or FileAccess.get_sha256(
			"res://tests/fixtures/source/src/systems/StoryNetworkSystem.js") != Repository.STORY_RULE_SHA:
		return _fail("surfacing source unavailable")
	var specs := [
		{"id": "surface_bairen_memory", "source": "_checkWorldChange",
			"godot": "_world_card"},
		{"id": "surface_karma_burden", "source": "_checkKarmaSurface",
			"godot": "_karma_card"}]
	for spec in specs:
		var row: Dictionary = repo.find("generated_card", spec.id)
		if row.get("data", {}).get("id") != spec.id \
				or row.get("sourcePath") != "src/systems/StoryNetworkSystem.js" \
				or row.get("sourceSha256") != Repository.STORY_RULE_SHA \
				or row.get("sourceSymbol") != "NarrativeSurfacing." + spec.source \
				or row.get("producerGodot") != "res://scripts/noncombat_narrative_surfacing.gd::" + spec.godot:
			return _fail("surfacing generated card source missing: " + spec.id)
	var duplicate = Repository.new()
	if not duplicate.build_index():
		return _fail("duplicate baseline unavailable")
	duplicate._index_surfacing_generated_cards()
	if not duplicate.errors().any(func(message: String) -> bool:
		return message.contains("Duplicate generated_card ID: surface_bairen_memory")):
		return _fail("duplicate surfacing generated ID accepted")
	var flow = Flow.new(repo)
	var state := {"phase": "FLOW_PENDING", "realm": "qi", "turn": 10,
		"runClock": {"decisionIndex": 10}, "decisionCheckpoint": {},
		"narrativeSurfacingState": flow.marker(0),
		"karmaSeeds": [{}, {}, {}, {}]}
	var karma: Dictionary = flow.take(state)
	if flow.card(karma).get("id") != "surface_karma_burden":
		return _fail("karma source did not reach pending consumer")
	var memory_source: Dictionary = state.duplicate(true)
	memory_source["worldContinuityState"] = {"npcs": {
		"bairen_zhenren": {"lifecycle": "DEAD", "changedAtTurn": 7}}}
	var memory: Dictionary = flow.take(memory_source)
	if flow.card(memory).get("id") != "surface_bairen_memory":
		return _fail("world source did not reach pending consumer")
	repo._indexes["generated_card"]["surface_karma_burden"]["sourceSymbol"] = "forged"
	if not flow.card(karma).is_empty():
		return _fail("pending surfacing consumer accepted forged rule identity")
	print("NONCOMBAT_SURFACING_GENERATED_REGISTRY_PASS ids=2 duplicate=rejected forged=rejected")
	quit(0)

func _fail(message: String) -> void:
	push_error(message)
	quit(1)
