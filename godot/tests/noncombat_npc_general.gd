extends "res://tests/noncombat_npc_cross_preset.gd"

const NpcFlow = preload("res://scripts/noncombat_npc_encounter_flow.gd")


func _run() -> void:
	var content = Repository.new()
	var fixture_path := ProjectSettings.globalize_path(
		"res://tests/fixtures/artifacts/godot-migration/npc-encounter-source.json")
	var source_fixture: Variant = JSON.parse_string(FileAccess.get_file_as_string(fixture_path))
	if not source_fixture is Dictionary or not source_fixture.get("scenarios") is Array \
			or source_fixture.scenarios.size() != 4:
		return _fail("browser single NPC oracle unavailable")
	for row in source_fixture.scenarios:
		var flow = NpcFlow.new(content)
		flow.roll_override_sequence = [0.0, float(row.selectionRoll)]
		var state := _state(String(row.realm), String(row.currentLocation))
		state.path = row.path
		state.attributes.fortune = 50
		state.npcEncounterScheduling = flow.marker(state, 1, 1)
		if state.npcEncounterScheduling.is_empty() or not flow.validate_marker(state):
			return _fail("general NPC source marker unavailable")
		if row.realm == "golden" and state.npcEncounterScheduling.emotions.get(
				"ds_moonmist") != "戏谑":
			return _fail("source default NPC emotion was flattened")
		var collected: Dictionary = flow.collect(state)
		var queued: Dictionary = collected.get("npcEncounterScheduling", {}).get("queuedCard", {})
		if queued.is_empty() or not _matches_browser(queued, row.card):
			return _fail("browser NPC pool/card differs: " + String(row.path))
		var pending: Dictionary = flow.take(collected)
		if pending.get("phase") != "NPC_PENDING" or flow.card(pending).get("id") != queued.id:
			return _fail("general NPC card did not surface at priority 30")
		var chosen: Dictionary = flow.settle(pending, "left")
		if chosen.get("phase") != "FLOW_PENDING" \
				or int(chosen.npcEncounterScheduling.affections.get(queued.npcId, 0)) \
				!= int(state.npcEncounterScheduling.affections.get(queued.npcId, 0)) + 5:
			return _fail("general NPC choice did not settle affection")
	var retry = NpcFlow.new(content)
	retry.roll_override_sequence = [0.0, 0.0, 0.0, 0.99]
	var retry_state := _state("golden", "南疆·月湖")
	retry_state.path = "sword"
	retry_state.cardsPlayed.append("npc_encounter_jiuwei_suyue_初见")
	retry_state.npcEncounterScheduling = retry.marker(retry_state, 1, 1)
	var retried: Dictionary = retry.collect(retry_state).get(
		"npcEncounterScheduling", {}).get("queuedCard", {})
	if retried.is_empty() or not _matches_browser(retried, source_fixture.retryCard):
		return _fail("source NPC retry after played card differs")
	var capped = NpcFlow.new(content)
	capped.roll_override_sequence = [0.0, 0.0]
	var cap_state := _state("golden", "南疆·月湖")
	cap_state.path = "sword"
	cap_state.npcEncounterScheduling = capped.marker(cap_state, 1, 1)
	cap_state.npcEncounterScheduling.memories.bai_ren = [
		{"turn": 0}, {"turn": 0}, {"turn": 0}, {"turn": 0},
		{"turn": 0}, {"turn": 0}]
	var cap_collected: Dictionary = capped.collect(cap_state)
	if cap_collected.is_empty() or cap_collected.npcEncounterScheduling.has("queuedCard") \
			or int(cap_collected.npcEncounterScheduling.get("rollCursor", -1)) != 0:
		return _fail("source global NPC encounter cap differs")
	print("NONCOMBAT_NPC_GENERAL_PASS cases=4 catalog=15 retry=5 cap=6 source=true choice=true")
	quit(0)


func _matches_browser(actual: Dictionary, expected: Dictionary) -> bool:
	var browser_shape: Dictionary = actual.duplicate(true)
	browser_shape.erase("_flowSource")
	browser_shape.erase("_flowPhase")
	return JSON.parse_string(JSON.stringify(browser_shape)) == JSON.parse_string(
		JSON.stringify(expected))
