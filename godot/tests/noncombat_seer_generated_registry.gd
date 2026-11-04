extends SceneTree

const Repository = preload("res://scripts/noncombat_content_repository.gd")
const Seer = preload("res://scripts/noncombat_seer_arc_flow.gd")
const STAGES := ["REVELATION", "UNVEILING", "SACRIFICE", "FINAL_PROPHECY"]

func _initialize() -> void:
	var repo = Repository.new()
	if not repo.build_index():
		return _fail("source repository unavailable")
	var source: Dictionary = repo.read_module("companions:arcs")
	var seer: Dictionary = source.seerArc.tianji_laoren
	if FileAccess.get_sha256("res://../src/systems/StoryNetworkSystem.js") != Repository.STORY_RULE_SHA:
		return _fail("seer browser producer changed")
	var specs := []
	for stage in STAGES:
		specs.append({"id": "seer_tianji_laoren_stage_" + stage,
			"pointer": "$.seerArc.tianji_laoren.arcStages." + stage,
			"data": seer.arcStages[stage], "key": stage,
			"browser": "_buildStageEvent"})
	for item in [{"id": "seer_tianji_laoren_revelation", "key": "revelation",
			"browser": "_buildRevelation"},
			{"id": "seer_tianji_laoren_tribulation", "key": "tribulationClimax",
			"browser": "_buildTribulationClimax"},
			{"id": "seer_tianji_laoren_destiny", "key": "destinyClimax",
			"browser": "_buildDestinyClimax"}]:
		specs.append({"id": item.id, "pointer": "$.seerArc.tianji_laoren." + item.key,
			"data": seer[item.key], "key": item.id.trim_prefix("seer_tianji_laoren_"),
			"browser": item.browser})
	var flow = Seer.new(repo)
	for spec in specs:
		var row: Dictionary = repo.find("generated_card", spec.id)
		if row.get("data") != spec.data \
				or row.get("sourcePath") != "src/systems/StoryNetworkSystem.js" \
				or row.get("sourceSha256") != Repository.STORY_RULE_SHA \
				or row.get("authorPath") != "data/companions/arcs.json" \
				or row.get("authorPointer") != spec.pointer \
				or row.get("authorSha256") != repo.source_sha256("companions:arcs") \
				or row.get("producerBrowser") != "src/systems/StoryNetworkSystem.js::" + spec.browser \
				or row.get("producerGodot") != "res://scripts/noncombat_seer_arc_flow.gd::_project":
			return _fail("seer generated card source missing: " + spec.id)
		if flow._project(spec.key, "qi").get("id") != spec.id:
			return _fail("seer source did not reach card producer: " + spec.id)
	if not repo.find("generated_card", "seer_tianji_laoren_stage_ENCOUNTER").is_empty():
		return _fail("unproduced initial seer stage falsely registered")
	var duplicate = Repository.new()
	if not duplicate.build_index():
		return _fail("duplicate baseline unavailable")
	duplicate._index_document("data/companions/arcs.json", source)
	if not duplicate.errors().any(func(message: String) -> bool:
		return message.contains("Duplicate generated_card ID: seer_tianji_laoren_stage_REVELATION")):
		return _fail("duplicate seer generated ID accepted")
	var pending_source := {"phase": "FLOW_PENDING", "realm": "qi", "turn": 0,
		"runClock": {"decisionIndex": 0}, "decisionCheckpoint": {},
		"seerArcState": flow.marker(0)}
	pending_source.seerArcState.pendingStages.append("REVELATION")
	var pending: Dictionary = flow.take(pending_source, "event")
	if pending.get("currentCardId") != "seer_tianji_laoren_stage_REVELATION" \
			or flow.card(pending).get("id") != pending.currentCardId:
		return _fail("registered seer card did not reach take and pending card")
	var world := {"version": 1, "lifeId": 0, "npcs": {
		"tianji_laoren": {"npcId": "tianji_laoren", "lifeId": 0,
			"lifecycle": "ACTIVE", "manifestation": "ECHO_ONLY"}}}
	var echo_source: Dictionary = pending_source.duplicate(true)
	echo_source["worldContinuityState"] = world.duplicate(true)
	if not flow.take(echo_source, "event").is_empty() \
			or not echo_source.seerArcState.pendingStages.is_empty():
		return _fail("echo-only seer entered take with deadNpcs empty")
	var echo_pending: Dictionary = pending.duplicate(true)
	echo_pending["worldContinuityState"] = world.duplicate(true)
	if not flow.card(echo_pending).is_empty() \
			or not flow.settle(echo_pending, "left").is_empty():
		return _fail("echo-only seer pending card or settlement remained available")
	repo._indexes["generated_card"]["seer_tianji_laoren_stage_REVELATION"]["data"]["title"] = "forged"
	if not flow.card(pending).is_empty():
		return _fail("pending seer consumer accepted forged registration")
	print("NONCOMBAT_SEER_GENERATED_REGISTRY_PASS ids=7 unproduced=1 duplicate=rejected forged=rejected echo_only=rejected legacy=allowed")
	quit(0)

func _fail(message: String) -> void:
	push_error(message)
	quit(1)
