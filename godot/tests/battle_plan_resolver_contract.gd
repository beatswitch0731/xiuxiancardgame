extends SceneTree

const Registry = preload("res://scripts/runtime_data_registry.gd")
const StageRouter = preload("res://scripts/combat_stage_router.gd")
const Resolver = preload("res://scripts/battle_plan_resolver.gd")


func _initialize() -> void:
	var registry = Registry.new()
	var resolver = Resolver.new(registry)
	var router = StageRouter.new(registry)
	var starters: Dictionary = registry.read_json("data/combat/deck_progression.json").get("paths", {})
	var requests := {}
	for row in registry.read_json("data/combat/encounters.json").get("encounters", []):
		if not row is Dictionary or row.get("teachingEncounter") != true:
			continue
		var path := String(row.get("path", ""))
		if requests.has(path):
			continue
		var context: Dictionary = router.resolve_encounter(String(row["id"]))
		if context.is_empty():
			_fail("教学遭遇找不到来源展示")
			return
		requests[path] = {"contractVersion": 2, "returnPolicy": "source_flow",
			"sourceCardId": "encounter_card_" + String(row["id"]),
			"direction": "left", "encounterId": row["id"],
			"encounterInstanceId": "enc:test:1:%s:1" % row["id"],
			"presentationId": context["presentationId"],
			"battlefieldId": context["battlefieldId"], "path": path,
			"realm": row["realm"], "playerSnapshot": {
				"battleLoadout": {"deck": starters[path]["starterDeck"].duplicate(true)},
				"equipment": {"weapon": null, "armor": null,
					"accessory": null, "artifact": null}, "treasureInstances": {}}}
	if requests.size() != 4:
		_fail("四修首轮教学遭遇不完整")
		return
	for path in requests:
		var original: Dictionary = requests[path].duplicate(true)
		var plan: Dictionary = resolver.inspect_request(original)
		if plan.is_empty() or plan.get("path") != path \
				or plan.get("deck") != starters[path]["starterDeck"] \
				or original != requests[path]:
			_fail("首轮战斗计划未解析或修改了来源请求：" + path + " " + resolver.last_error)
			return
	var sword: Dictionary = requests["sword"].duplicate(true)
	var right_prologue := sword.duplicate(true)
	right_prologue["direction"] = "right"
	if resolver.inspect_request(right_prologue).is_empty():
		_fail("序章右选后的教学战计划被误拒绝")
		return
	var snapshot: Dictionary = sword["playerSnapshot"]
	var instance_id := "tr:traded_rusted_sword:1"
	snapshot["treasureInstances"][instance_id] = {"instanceId": instance_id,
		"definitionId": "traded_rusted_sword", "lifecycle": "owned"}
	snapshot["equipment"]["weapon"] = instance_id
	var sword_plan: Dictionary = resolver.inspect_request(sword)
	if sword_plan.is_empty() or sword_plan["equipment"]["weapon"].get(
		"definitionId") != "traded_rusted_sword" \
			or sword_plan["equipment"]["weapon"].get("visualReady") != false:
		_fail("装备实例未进入战斗计划，或未如实保留外观待制作状态")
		return
	var wrong_slot := sword.duplicate(true)
	wrong_slot["playerSnapshot"]["equipment"]["armor"] = instance_id
	if not resolver.inspect_request(wrong_slot).is_empty():
		_fail("同一装备实例被允许占多个槽")
		return
	var wrong_stage := sword.duplicate(true)
	wrong_stage["battlefieldId"] = "battlefield_other"
	if not resolver.inspect_request(wrong_stage).is_empty():
		_fail("请求可把首战悄悄指向别的战场")
		return
	var wrong_deck := sword.duplicate(true)
	wrong_deck["playerSnapshot"]["battleLoadout"]["deck"] = starters["spell"]["starterDeck"]
	if not resolver.inspect_request(wrong_deck).is_empty():
		_fail("首战剑修可装载法修牌组")
		return
	var wrong_source := sword.duplicate(true)
	wrong_source["sourceCardId"] = "encounter_card_forged"
	if not resolver.inspect_request(wrong_source).is_empty():
		_fail("伪造来源剧情卡被接受")
		return
	var malformed := sword.duplicate(true)
	malformed["playerSnapshot"]["battleLoadout"] = null
	if not resolver.inspect_request(malformed).is_empty() or resolver.last_error.is_empty():
		_fail("损坏的牌组结构没有被安全拒绝")
		return
	malformed = sword.duplicate(true)
	malformed["playerSnapshot"]["battleLoadout"]["deck"] = "not-an-array"
	if not resolver.inspect_request(malformed).is_empty() or resolver.last_error.is_empty():
		_fail("损坏的卡组字段没有被安全拒绝")
		return
	if sword_plan.get("launchAuthorized") != false:
		_fail("未经持久来源确认的预览计划被标成可开战")
		return
	print("BATTLE_PLAN_RESOLVER_PASS paths=4 equipment_instance=1 negative=6")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
