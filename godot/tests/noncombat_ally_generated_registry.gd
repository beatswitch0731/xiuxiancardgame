extends SceneTree

const Repository = preload("res://scripts/noncombat_content_repository.gd")
const Ally = preload("res://scripts/noncombat_ally_arc_flow.gd")
const STAGES := ["RECOGNITION", "TRUST", "COMRADE", "LEGACY"]

func _initialize() -> void:
	var repo = Repository.new()
	if not repo.build_index():
		return _fail("source repository unavailable")
	var source: Dictionary = repo.read_module("companions:arcs")
	var ally: Dictionary = source.allyArc.xuesha_laozu
	if FileAccess.get_sha256("res://../src/systems/StoryNetworkSystem.js") != Repository.STORY_RULE_SHA:
		return _fail("ally browser producer changed")
	var specs := []
	for stage in STAGES:
		specs.append({"id": "ally_xuesha_laozu_stage_" + stage,
			"pointer": "$.allyArc.xuesha_laozu.arcStages." + stage,
			"data": ally.arcStages[stage], "key": stage,
			"browser": "_buildStageEvent"})
	for item in [{"id": "ally_xuesha_laozu_revelation", "key": "revelation",
			"browser": "_buildRevelation"},
			{"id": "ally_xuesha_laozu_tribulation", "key": "tribulationClimax",
			"browser": "_buildTribulationClimax"},
			{"id": "ally_xuesha_laozu_destiny", "key": "destinyClimax",
			"browser": "_buildDestinyClimax"}]:
		specs.append({"id": item.id, "pointer": "$.allyArc.xuesha_laozu." + item.key,
			"data": ally[item.key], "key": item.id.trim_prefix("ally_xuesha_laozu_"),
			"browser": item.browser})
	var flow = Ally.new(repo)
	for spec in specs:
		var row: Dictionary = repo.find("generated_card", spec.id)
		if row.get("data") != spec.data \
				or row.get("sourcePath") != "src/systems/StoryNetworkSystem.js" \
				or row.get("sourceSha256") != Repository.STORY_RULE_SHA \
				or row.get("authorPath") != "data/companions/arcs.json" \
				or row.get("authorPointer") != spec.pointer \
				or row.get("authorSha256") != repo.source_sha256("companions:arcs") \
				or row.get("producerBrowser") != "src/systems/StoryNetworkSystem.js::" + spec.browser \
				or row.get("producerGodot") != "res://scripts/noncombat_ally_arc_flow.gd::_project":
			return _fail("ally generated card source missing: " + spec.id)
		if flow._project(spec.key, "qi").get("id") != spec.id:
			return _fail("ally source did not reach card producer: " + spec.id)
	if not repo.find("generated_card", "ally_xuesha_laozu_stage_CONTACT").is_empty():
		return _fail("unproduced initial ally stage falsely registered")
	var duplicate = Repository.new()
	if not duplicate.build_index():
		return _fail("duplicate baseline unavailable")
	duplicate._index_document("data/companions/arcs.json", source)
	if not duplicate.errors().any(func(message: String) -> bool:
		return message.contains("Duplicate generated_card ID: ally_xuesha_laozu_stage_RECOGNITION")):
		return _fail("duplicate ally generated ID accepted")
	var pending_source := {"phase": "FLOW_PENDING", "realm": "qi", "turn": 0,
		"runClock": {"decisionIndex": 0}, "decisionCheckpoint": {},
		"allyArcState": flow.marker(0)}
	pending_source.allyArcState.pendingStages.append("RECOGNITION")
	var pending: Dictionary = flow.take(pending_source, "event")
	if pending.get("currentCardId") != "ally_xuesha_laozu_stage_RECOGNITION" \
			or flow.card(pending).get("id") != pending.currentCardId:
		return _fail("registered ally card did not reach take and pending card")
	var world := {"version": 1, "lifeId": 0, "npcs": {
		"xuesha_laozu": {"npcId": "xuesha_laozu", "lifeId": 0,
			"lifecycle": "ACTIVE", "manifestation": "ECHO_ONLY"}}}
	var echo_source: Dictionary = pending_source.duplicate(true)
	echo_source["worldContinuityState"] = world.duplicate(true)
	if not flow.take(echo_source, "event").is_empty() \
			or not echo_source.allyArcState.pendingStages.is_empty():
		return _fail("echo-only ally entered take with deadNpcs empty")
	var echo_pending: Dictionary = pending.duplicate(true)
	echo_pending["worldContinuityState"] = world.duplicate(true)
	if not flow.card(echo_pending).is_empty() \
			or not flow.settle(echo_pending, "left").is_empty():
		return _fail("echo-only ally pending card or settlement remained available")
	repo._indexes["generated_card"]["ally_xuesha_laozu_stage_RECOGNITION"]["data"]["title"] = "forged"
	if not flow.card(pending).is_empty():
		return _fail("pending ally consumer accepted forged registration")
	print("NONCOMBAT_ALLY_GENERATED_REGISTRY_PASS ids=7 unproduced=1 duplicate=rejected forged=rejected echo_only=rejected legacy=allowed")
	quit(0)

func _fail(message: String) -> void:
	push_error(message)
	quit(1)
