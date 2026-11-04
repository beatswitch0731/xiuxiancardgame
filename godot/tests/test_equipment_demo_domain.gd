extends SceneTree

var failures: Array[String] = []
var checks := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		push_error(message)

func _initialize() -> void:
	var reference_path := "res://tests/fixtures/equipment_demo_source_reference.json"
	check(FileAccess.file_exists(reference_path), "Run node godot/tools/equipment_demo_source_reference.cjs first")
	var script_path := "res://scripts/equipment_demo_domain.gd"
	check(FileAccess.file_exists(script_path), "Missing equipment demo domain: equipment cannot yet drive live demo")
	if not failures.is_empty():
		finish()
		return
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(reference_path))
	for source_path in fixture.sourceSha256:
		var actual_path := ProjectSettings.globalize_path("res://").path_join("../" + source_path)
		check(FileAccess.get_sha256(actual_path) == fixture.sourceSha256[source_path],
			"Browser oracle is stale: " + source_path)
	var Domain = load(script_path)
	for trace in fixture.traces:
		var demo = Domain.new()
		demo.critical_roll_override = 0.5
		demo.equip("weapon", trace.weapon)
		demo.equip("armor", trace.armor)
		demo.equip("artifact", trace.artifact)
		for step in trace.steps:
			check(demo.call(step.action), "Action accepted " + step.action)
			var actual: Dictionary = demo.snapshot()
			for field in step.expected:
				check(actual.get(field) == step.expected[field], "%s %s %s expected=%s actual=%s" % [
					trace.weapon, step.action, field, step.expected[field], actual.get(field)])
	for scenario in fixture.armorChecks:
		var armor_demo = Domain.new()
		armor_demo.equip("armor", scenario.armor)
		check(armor_demo.snapshot().stats.def == scenario.modifiers.def, "Armor stat matches TreasureSystem")
		if scenario.guard:
			armor_demo.guard()
		armor_demo.end_turn()
		check(armor_demo.snapshot().hp == scenario.hp, "Armor reduction/guard order matches executable source")
	var demo = Domain.new()
	var before: Dictionary = demo.snapshot()
	check(not demo.equip("armor", "问道剑"), "Reject incompatible slot")
	check(not demo.equip("weapon", "unknown"), "Reject unowned item")
	check(demo.snapshot().equipment == before.equipment, "Invalid equip leaves loadout unchanged")
	check(demo.equip("armor", "灵纹法袍"), "Equip robe through owned instance")
	check(demo.equip("accessory", "灵泉葫芦"), "Equip gourd")
	var equipped: Dictionary = demo.snapshot()
	check(equipped.equipmentInstances.armor == "equipment-demo:灵纹法袍", "Slot carries instance ID")
	check(demo.guard(), "Guard grants authored block")
	check(demo.end_turn(), "Candidate recoveries execute once")
	var recovered: Dictionary = demo.snapshot()
	check(recovered.hp == before.hp + fixture.declarations["灵泉葫芦"].hpRegen,
		"Gourd candidate heals declared amount after fully blocked incoming attack")
	check(recovered.qi == before.maxQi + fixture.declarations["灵纹法袍"].qiRegen,
		"Robe candidate adds declared qi above normal turn refill")
	var candidate_count := 0
	for event in recovered.events:
		if event.get("ruleStatus") == "candidate_data_hook":
			candidate_count += 1
			check(not String(event.get("definitionId", "")).is_empty(), "Recovery source definition")
			check(not String(event.get("instanceId", "")).is_empty(), "Recovery source instance")
	check(candidate_count == 2, "Recovery source gaps stay explicit; exactly two events")
	check(fixture.regenGap.hp == before.hp and fixture.regenGap.qi == before.maxQi,
		"Executable browser source does not currently consume hpRegen or qiRegen")
	check(demo.equip("accessory", ""), "Unequip gourd")
	check(demo.equip("armor", ""), "Unequip robe")
	var hp_before: int = demo.snapshot().hp
	demo.end_turn()
	check(demo.snapshot().hp == maxi(0, hp_before - 3), "Unequipped armor and gourd have no remaining effect")
	check(demo.snapshot().qi == before.maxQi, "Unequipped robe no longer grants qi")
	demo.reset()
	check(demo.snapshot().turn == 1 and demo.snapshot().artifactCounter == 0, "Reset clears combat receipts")
	check(demo.snapshot().equipment.armor == "", "Reset keeps current loadout")
	var unaffordable = Domain.new()
	unaffordable.guard()
	var guard_snapshot: Dictionary = unaffordable.snapshot()
	check(not unaffordable.guard(), "Reject unaffordable card")
	check(unaffordable.snapshot().qi == guard_snapshot.qi \
		and unaffordable.snapshot().block == guard_snapshot.block, "Rejected card does not settle")
	var removable = Domain.new()
	removable.critical_roll_override = 0.5
	removable.equip("weapon", "问道剑")
	removable.equip("artifact", "青云剑匣")
	removable.attack()
	removable.equip("weapon", "")
	removable.equip("artifact", "")
	var unarmed_before: Dictionary = removable.snapshot()
	removable.attack()
	var unarmed_after: Dictionary = removable.snapshot()
	check(unarmed_after.enemyHp == unarmed_before.enemyHp - 2,
		"Removing sword removes attack bonus while existing opening still applies")
	check(unarmed_after.artifactCounter == 0, "Removed sword box no longer counts sword cards")
	finish()

func finish() -> void:
	print("EQUIPMENT_DEMO_DOMAIN_%s checks=%d failures=%d" % [
		"PASS" if failures.is_empty() else "FAIL", checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
