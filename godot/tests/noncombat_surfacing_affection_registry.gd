extends SceneTree

const Repository = preload("res://scripts/noncombat_content_repository.gd")
const Flow = preload("res://scripts/noncombat_narrative_surfacing.gd")

func _initialize() -> void:
	var repo = Repository.new()
	if not repo.build_index() or FileAccess.get_sha256(
			"res://tests/fixtures/source/src/systems/StoryNetworkSystem.js") != Repository.STORY_RULE_SHA:
		return _fail("affection source unavailable")
	var npcs: Array = repo.read_module("npcs:core").npcs
	if npcs.size() != 16:
		return _fail("core companion owner count changed")
	var flow = Flow.new(repo)
	for i in range(npcs.size()):
		var npc: Dictionary = npcs[i]
		var card_id := "surface_%s_near_20" % npc.id
		var row: Dictionary = repo.find("generated_card", card_id)
		if row.get("data", {}).get("id") != card_id \
				or row.get("companionId") != npc.id \
				or row.get("sourcePath") != "src/systems/StoryNetworkSystem.js" \
				or row.get("sourceSha256") != Repository.STORY_RULE_SHA \
				or row.get("sourceSymbol") != "NarrativeSurfacing._checkAffectionSurface" \
				or row.get("npcSourcePath") != "data/npcs/core_npcs.json" \
				or row.get("npcSourcePointer") != "$.npcs[%d]" % i \
				or row.get("npcSourceSha256") != repo.source_sha256("npcs:core") \
				or row.get("producerGodot") != "res://scripts/noncombat_narrative_surfacing.gd::_affection_card":
			return _fail("affection generated source missing: " + card_id)
		var probe := {"resources": {"companions": [npc.id]},
			"companionProgress": {"states": {npc.id: {}}},
			"npcAffection": {npc.id: 18}, "flags": {}}
		if flow._affection_card(probe).get("id") != card_id:
			return _fail("affection source did not reach producer: " + card_id)
	var duplicate = Repository.new()
	if not duplicate.build_index():
		return _fail("duplicate baseline unavailable")
	duplicate._index_document("data/npcs/core_npcs.json", repo.read_module("npcs:core"))
	if not duplicate.errors().any(func(message: String) -> bool:
		return message.contains("Duplicate generated_card ID: surface_bai_ren_near_20")):
		return _fail("duplicate affection generated ID accepted")
	var state := {"phase": "FLOW_PENDING", "realm": "qi", "turn": 10,
		"runClock": {"decisionIndex": 10}, "decisionCheckpoint": {},
		"narrativeSurfacingState": flow.marker(0), "karmaSeeds": [],
		"resources": {"companions": ["bai_luoxuan"]},
		"companionProgress": {"states": {"bai_luoxuan": {}}},
		"npcAffection": {"bai_luoxuan": 18}, "flags": {}}
	var pending: Dictionary = flow.take(state)
	if flow.card(pending).get("id") != "surface_bai_luoxuan_near_20":
		return _fail("affection card did not reach pending consumer")
	var physical: Dictionary = state.duplicate(true)
	physical["worldContinuityState"] = {"version": 1, "lifeId": 0,
		"npcs": {"bai_luoxuan": {"npcId": "bai_luoxuan", "lifeId": 0,
			"lifecycle": "ACTIVE", "manifestation": "PHYSICAL"}}}
	if flow.card(flow.take(physical)).get("id") != "surface_bai_luoxuan_near_20":
		return _fail("current-life physical companion was over-rejected")
	for case in [
		{"name": "echo", "world": {"version": 1, "lifeId": 0,
			"npcs": {"bai_luoxuan": {"npcId": "bai_luoxuan", "lifeId": 0,
				"lifecycle": "ACTIVE", "manifestation": "ECHO_ONLY"}}}},
		{"name": "missing", "world": {"version": 1, "lifeId": 0, "npcs": {}}},
		{"name": "wrong_life", "world": {"version": 1, "lifeId": 1,
			"npcs": {"bai_luoxuan": {"npcId": "bai_luoxuan", "lifeId": 1,
				"lifecycle": "ACTIVE", "manifestation": "PHYSICAL"}}}}]:
		var unavailable: Dictionary = state.duplicate(true)
		unavailable["deadNpcs"] = []
		unavailable["worldContinuityState"] = case.world
		var skipped: Dictionary = flow.take(unavailable)
		if skipped.get("phase") != "FLOW_PENDING" \
				or skipped.has("pendingSurfacingCard") \
				or skipped.get("flags", {}).has("surface_pushed_bai_luoxuan_20"):
			return _fail("unavailable companion surfaced: " + case.name)
		var invalid_pending: Dictionary = pending.duplicate(true)
		invalid_pending["deadNpcs"] = []
		invalid_pending["worldContinuityState"] = case.world
		if not flow.card(invalid_pending).is_empty() \
				or not flow.settle(invalid_pending, "left").is_empty():
			return _fail("unavailable pending companion settled: " + case.name)
	repo._indexes["generated_card"]["surface_bai_luoxuan_near_20"]["sourceSymbol"] = "forged"
	if not flow.card(pending).is_empty() or not flow.settle(pending, "left").is_empty():
		return _fail("forged affection registration reached pending card or settlement")
	print("NONCOMBAT_SURFACING_AFFECTION_REGISTRY_PASS owners=16 duplicate=rejected forged=rejected unavailable=rejected legacy=allowed")
	quit(0)

func _fail(message: String) -> void:
	push_error(message)
	quit(1)
