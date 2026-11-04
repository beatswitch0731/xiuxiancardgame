extends SceneTree

const Registry = preload("res://scripts/runtime_data_registry.gd")
const Repository = preload("res://scripts/noncombat_content_repository.gd")
const Domain = preload("res://scripts/noncombat_domain.gd")
const WorldMap = preload("res://scripts/noncombat_world_map.gd")
const OpeningScene = preload("res://scenes/noncombat_opening.tscn")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var game = Domain.new(Registry.new(), null, "slot_2")
	if not game.start("sword"):
		return _fail("world map source run could not start")
	var world_map = WorldMap.new(Repository.new())
	var first: Dictionary = world_map.project(game.state, game.get_current_card())
	if first.get("nodes", []).size() != 13 or first.get("routes", []).size() != 12 \
			or first.get("chronicles", []).size() != 11 \
			or _find(first.nodes, "sect").get("factionNames") != ["青云剑宗"] \
			or first.get("currentNodeId") != "sect" \
			or _find(first.get("characters", []), "bai_ren").get(
				"nodeId") != "sword_cliff" \
			or _find(first.get("characters", []), "bai_ren").get(
				"emotion") != "平静" \
			or _find(first.nodes, "tianji").get("discovered") != false:
		return _fail("world map source catalog or first realm fog incorrect")
	var advanced: Dictionary = game.state.duplicate(true)
	advanced.realm = "golden"
	advanced.currentLocation = "青云剑冢"
	advanced.visitedLocations = ["宗门", "剑崖"]
	advanced.questState = {"activeQuests": [{"questId": "sword_legacy", "step": 1}],
		"completedQuests": []}
	advanced.storyThreadState = {"threads": {"sword_tomb_trial": {
		"status": "active"}}}
	advanced.tradeRouteState = {"routes": {"cloud_sword_road": {
		"openness": 40, "danger": 75, "prosperity": 20}}}
	advanced.factionProgress.reputations.qingyun_sword = 22
	advanced.factionProgress.undercurrentStages.qingyun_debate = 2
	advanced.turn = 12
	advanced.npcEncounterScheduling.emotions.bai_ren = "忧心"
	var projected: Dictionary = world_map.project(advanced, game.get_current_card())
	if projected.get("currentNodeId") != "sword_cliff" \
			or _find(projected.chronicles, "sword_legacy").get("state") != "active" \
			or _find(projected.chronicles, "sword_tomb_trial").get("state") != "active" \
			or _find(projected.routes, "cloud_sword_road").get("condition") != "danger" \
			or _find(projected.get("characters", []), "bai_ren").get(
				"nodeId") != "sect" \
			or _find(projected.get("characters", []), "bai_ren").get(
				"emotion") != "忧心" \
			or _find(_find(projected.nodes, "sect").get("factionDetails", []),
				"qingyun_sword").get("reputation") != 22 \
			or _find(_find(projected.nodes, "sect").get("factionDetails", []),
				"qingyun_sword").get("level") != "友善" \
			or _find(_find(projected.nodes, "sect").get("factionDetails", []),
				"qingyun_sword").get("undercurrentStage") != 2 \
			or not _find(projected.nodes, "tianji").get("discovered"):
		return _fail("world map did not read existing location, quest, thread, trade state")
	var view: Control = OpeningScene.instantiate()
	view.save_path = ""
	root.add_child(view)
	await process_frame
	view.opening = game
	view.story_screen.visible = true
	view._render()
	var before_map: Dictionary = game.state.duplicate(true)
	var map_button: Button = view.story_screen.find_child("OpenWorldMap", true, false)
	if map_button == null:
		return _fail("desktop story has no map entry")
	map_button.pressed.emit()
	await process_frame
	var overlay: Control = view.world_map_overlay
	if not overlay.visible or overlay.find_child(
			"CloseWorldMap", true, false) == null \
			or overlay._canvas.get_child_count() < 25 \
			or overlay._canvas.get_node_or_null("MapCharacter_bai_ren") == null \
			or not String(overlay._detail.text).contains("青云剑宗") \
			or not String(overlay._detail.text).contains("声望"):
		return _fail("desktop map overlay did not show source nodes, routes and current place")
	var sword_node: Button = overlay._canvas.get_node_or_null("MapNode_sword_cliff")
	if sword_node == null:
		return _fail("desktop map has no sword cliff node")
	sword_node.pressed.emit()
	if not String(overlay._detail.text).contains("白刃真人") \
			or not String(overlay._detail.text).contains("平静"):
		return _fail("desktop map did not show source NPC emotion")
	var far_node: Button = overlay._canvas.get_node_or_null("MapNode_tianji")
	if far_node == null:
		return _fail("desktop map did not expose a fogged faraway node")
	far_node.pressed.emit()
	if not String(overlay._detail.text).contains("迷雾") or game.state != before_map:
		return _fail("world map selection changed the run or revealed a locked region")
	overlay._close()
	if overlay.visible:
		return _fail("desktop map did not return to story")
	view.queue_free()
	await process_frame
	print("NONCOMBAT_WORLD_MAP_PASS nodes=13 routes=12 chronicles=11 read_only=true desktop=true")
	quit(0)


func _find(rows: Array, entry_id: String) -> Dictionary:
	for row in rows:
		if row.get("id") == entry_id:
			return row
	return {}


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
