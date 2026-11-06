extends SceneTree

const Inspector = preload("res://scripts/noncombat_browser_save_inspector.gd")
const SOURCE_DIR := "res://tests/fixtures/artifacts/godot-migration/m0-2026-10-15/"


func _initialize() -> void:
	var inspector = Inspector.new()
	var direct_text := FileAccess.get_file_as_string(_source_path(
		"slots-synthetic-raw.json"))
	var direct: Dictionary = inspector.inspect_text(direct_text)
	if direct.get("ok") != true or direct.get("slots", []).size() != 3:
		return _fail("raw localStorage three-slot export was not recognized")
	var first: Dictionary = direct.slots[0]
	var third: Dictionary = direct.slots[2]
	if first.get("slotId") != "slot_1" or first.get("decisionIndex") != 4 \
			or first.get("combatActive") != false \
			or third.get("slotId") != "slot_3" \
			or third.get("decisionIndex") != 3 \
			or third.get("combatActive") != true \
			or third.get("combatSealVerified") != false:
		return _fail("browser preview hid battle ownership or decision clock")
	var browser_state: Dictionary = inspector.inspect_text(
		FileAccess.get_file_as_string(_source_path("slots-browser-state.json")))
	if browser_state.get("ok") != true \
			or browser_state.get("activeSlot") != "slot_3" \
			or browser_state.get("slots", []).size() != 3:
		return _fail("browser storageState format lost active slot or records")
	var single_source: Dictionary = JSON.parse_string(JSON.parse_string(
		direct_text)["xiuxian_unlocks"])
	var single_text := JSON.stringify(single_source, "  ")
	var single: Dictionary = inspector.read_slot(single_text, "slot_1")
	if single.get("ok") != true or single.get("sourceSha256") != \
			single_text.sha256_text() or single.get("source", {}).get("saveVersion") != 10:
		return _fail("single exported save lost its exact raw source hash")
	var third_text: String = JSON.parse_string(direct_text)["xiuxian_unlocks_slot_3"]
	if inspector.inspect_text(third_text).get("activeSlot") != "slot_3":
		return _fail("single exported slot was labeled with the wrong active identity")
	var mutated: Dictionary = JSON.parse_string(direct_text)
	var source: Dictionary = JSON.parse_string(mutated["xiuxian_unlocks_slot_3"])
	source["causalSessionState"]["runClock"]["lifeId"] = "slot_1:life:0"
	mutated["xiuxian_unlocks_slot_3"] = JSON.stringify(source)
	var wrong_owner: Dictionary = inspector.inspect_text(JSON.stringify(mutated))
	if wrong_owner.get("ok") != false \
			or wrong_owner.get("slots", [])[2].get("error") != "INVALID_RUN_CLOCK" \
			or wrong_owner.get("slots", [])[0].get("valid") != true:
		return _fail("one malformed browser slot invalidated the wrong record")
	source = JSON.parse_string(JSON.parse_string(direct_text)["xiuxian_unlocks_slot_3"])
	source["causalSessionState"]["combatSession"]["encounterContext"][
		"encounterInstanceId"] = "enc:0:3:forged:1"
	mutated["xiuxian_unlocks_slot_3"] = JSON.stringify(source)
	var wrong_combat: Dictionary = inspector.inspect_text(JSON.stringify(mutated))
	if wrong_combat.get("slots", [])[2].get("error") != "INVALID_COMBAT_OWNER":
		return _fail("foreign battle owner passed import preview")
	print("NONCOMBAT_BROWSER_SAVE_INSPECTOR_PASS slots=3 storage_state=true clock=true combat_owner=true read_only=true")
	quit(0)


func _source_path(filename: String) -> String:
	var combined := SOURCE_DIR + filename
	# 内化后 SOURCE_DIR 是 res:// 虚拟路径，不能再拼绝对根
	if combined.begins_with("res://"):
		return combined
	return ProjectSettings.globalize_path("res://").path_join(
		combined).simplify_path()


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
