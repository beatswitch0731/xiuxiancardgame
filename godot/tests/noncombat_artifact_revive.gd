extends SceneTree

const Registry = preload("res://scripts/runtime_data_registry.gd")
const Domain = preload("res://scripts/noncombat_domain.gd")
const RunSession = preload("res://scripts/noncombat_run_session.gd")
const ContentRepository = preload("res://scripts/noncombat_content_repository.gd")
const TreasureAcquisition = preload("res://scripts/noncombat_treasure_acquisition.gd")
const FIXTURE := "res://tests/fixtures/spell_second_life_fatal_source_v2.json"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var path := "user://tests/artifact_revive_%d.json" % Time.get_ticks_usec()
	var store = RunSession.new(path, "slot_3")
	if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(
			store.v2_path).get_base_dir()) != OK:
		return _fail("checkpoint directory unavailable")
	var source := FileAccess.open(FIXTURE, FileAccess.READ)
	var dest := FileAccess.open(store.v2_path, FileAccess.WRITE)
	if source == null or dest == null:
		return _fail("source checkpoint unavailable")
	dest.store_string(source.get_as_text())
	dest.close()
	var game = Domain.new(Registry.new(), store, "slot_3")
	game._normal_roll_override = 0.55
	game._market_flow.roll_override = 0.0
	game._destiny_wheel_flow.roll_override = 0.0
	game._ripple_flow.roll_override = 0.999
	game._hint_flow.roll_override = 0.0
	if not game.restore() or game.get_current_card().get("id") != "q_spellTome" \
			or game.state.get("attributes", {}).get("daoHeart") != 1:
		return _fail("second-life spell source checkpoint did not strictly restore")
	var source_state: Dictionary = game.state.duplicate(true)
	# The source checkpoint is authentic; this branch stages an owned, equipped
	# catalog artifact to isolate the browser checkDeath revival boundary.
	var artifact_id := "tr:替身符:1"
	game._store = null
	game.state["treasureInstances"][artifact_id] = {"instanceId": artifact_id,
		"definitionId": "替身符", "provenance": {"source": "test_branch"},
		"acquiredDecision": 62, "lifecycle": "owned"}
	game.state["equipment"]["artifact"] = artifact_id
	game.state["resources"]["treasures"] = ["替身符"]
	game.state["treasureRuleSourceSha"] = TreasureAcquisition.SOURCE_JS_SHA
	game.state["treasureSourceSha"] = ContentRepository.new().source_sha256(
		"shops:treasures")
	var stone_before := int(game.state["resources"]["spiritStone"])
	if not game.choose("left", game.issue_choice_token()):
		return _fail("equipped substitute artifact did not intercept ordinary death")
	if game.state.get("phase") != "FLOW_PENDING" \
			or game.state.get("dead", false) == true \
			or game.state.get("equipment", {}).get("artifact") != null \
			or not game.state.get("treasureInstances", {}).is_empty() \
			or game.state.get("resources", {}).get("treasures") != [] \
			or int(game.state.get("attributes", {}).get("health", 0)) != 2 \
			or int(game.state.get("attributes", {}).get("daoHeart", -1)) != 0 \
			or int(game.state.get("resources", {}).get("spiritStone", -1)) \
				!= floori(stone_before * 0.5) \
			or int(game.state.get("runClock", {}).get("decisionIndex", -1)) != 63:
		return _fail("source substitute revival cost, ownership or flow diverged")
	if not _verify_catalog_revives(source_state):
		return
	print("NONCOMBAT_ARTIFACT_REVIVE_PASS substitute=true nirvana=true samsara=true chaos=true ordinary=true")
	quit(0)


func _verify_catalog_revives(source_state: Dictionary) -> bool:
	var cases := [
		{"id": "替身符", "type": "substitute", "health": 2,
			"cultivation": 97, "stone": 166},
		{"id": "涅槃羽", "type": "nirvana", "health": 3,
			"cultivation": 97, "stone": 333},
		{"id": "轮回镜", "type": "samsara", "health": 2,
			"cultivation": 77, "stone": 333},
		{"id": "混沌茧", "type": "chaos", "health": 3,
			"cultivation": 77, "stone": 333},
	]
	var content = ContentRepository.new()
	for row in cases:
		var state: Dictionary = source_state.duplicate(true)
		state["attributes"]["daoHeart"] = 0
		var instance_id := "tr:%s:1" % row.id
		state["treasureInstances"][instance_id] = {
			"instanceId": instance_id, "definitionId": row.id,
			"provenance": {"source": "test_branch"},
			"acquiredDecision": 62, "lifecycle": "owned"}
		state["equipment"]["artifact"] = instance_id
		state["resources"]["treasures"] = [row.id]
		state["treasureRuleSourceSha"] = TreasureAcquisition.SOURCE_JS_SHA
		state["treasureSourceSha"] = content.source_sha256("shops:treasures")
		var before: Dictionary = state.duplicate(true)
		var resolved: Dictionary = TreasureAcquisition.new(content).revive_equipped(state)
		var next: Dictionary = resolved.get("state", {})
		if resolved.get("revived") != true or resolved.get("type") != row.type \
				or state != before or next.get("equipment", {}).get("artifact") != null \
				or not next.get("treasureInstances", {}).is_empty() \
				or next.get("resources", {}).get("treasures") != [] \
				or int(next.get("attributes", {}).get("health", -1)) != row.health \
				or int(next.get("attributes", {}).get("daoHeart", -1)) != 0 \
				or int(next.get("attributes", {}).get("cultivation", -1)) \
					!= row.cultivation \
				or int(next.get("resources", {}).get("spiritStone", -1)) != row.stone:
			_fail("source revival definition diverged: " + String(row.id))
			return false
	return true


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
