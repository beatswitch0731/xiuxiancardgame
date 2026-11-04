extends SceneTree

const SceneFlow = preload("res://scripts/noncombat_scene_layer_flow.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var flow = SceneFlow.new()
	var state := {"phase": "FLOW_PENDING", "currentLocation": "宗门",
		"locationStates": {}, "turn": 7, "lifeCount": 0,
		"runClock": {"lifeId": "slot_1:life:0", "decisionIndex": 7,
			"receipts": {}},
		"attributes": {"cultivation": 10, "fortune": 40,
			"daoHeart": 3, "health": 5},
		"resources": {"spiritStone": 10, "lifespan": 80,
			"pills": {}, "treasures": [], "companions": []},
		"knowledge": {}, "clues": [], "cardsPlayed": [],
		"choiceHistory": [], "replayHistory": [], "recentCardTags": [],
		"decisionCheckpoint": {"sourceCardId": "previous"},
		"karmaSeeds": []}
	state["sceneLayerState"] = flow.marker(0)
	if state["sceneLayerState"].is_empty():
		_fail("source marker unavailable: " + flow.last_error)
		return
	for index in 7:
		state = flow.visit(state)
		if state.is_empty() or state.phase != "FLOW_PENDING":
			_fail("location scene appeared before eighth visit")
			return
	state = flow.visit(state)
	if state.is_empty() or state.phase != "LOCATION_PENDING" \
			or state.currentCardId != "loc_sect_deep" \
			or state.locationStates["宗门"].visits != 8:
		_fail("authored eighth visit did not issue deep sect card: " + flow.last_error)
		return
	if flow.card(state).get("choices", {}).get("left", {}).get(
			"effects", {}).get("find_clue") != "sect_alchemy_secret":
		_fail("deep sect card differs from source")
		return
	var chosen: Dictionary = flow.settle(state, "left")
	if chosen.is_empty() or chosen.get("clues", []).size() != 1 \
			or chosen.clues[0] != {"id": "sect_alchemy_secret",
				"source": "loc_sect_deep", "turn": 7, "life": 0} \
			or chosen.get("knowledge", {}).get("wisdom") != 3 \
			or chosen.get("phase") != "FLOW_PENDING" \
			or chosen.get("runClock", {}).get("decisionIndex") != 8:
		_fail("deep sect choice did not settle clue and wisdom: " + flow.last_error)
		return
	if not flow.settle(chosen, "left").is_empty():
		_fail("resolved scene accepted duplicate choice")
		return
	var sword: Dictionary = state.duplicate(true)
	sword["phase"] = "FLOW_PENDING"
	sword["currentLocation"] = "剑崖"
	sword["locationStates"] = {}
	sword["sceneLayerState"]["triggeredCards"] = []
	for index in 8:
		sword = flow.visit(sword)
		if sword.is_empty():
			_fail("sword cliff visit failed: " + flow.last_error)
			return
	if sword.get("currentCardId") != "loc_sword_cliff_deep":
		_fail("sword cliff did not issue authored deep card")
		return
	var rubbing: Dictionary = flow.settle(sword, "right")
	if rubbing.is_empty() or not rubbing.get("resources", {}).get(
			"treasures", []).has("sword_cliff_rubbing"):
		_fail("sword cliff source rubbing did not enter treasure inventory: " + flow.last_error)
		return
	var void_choice: Dictionary = state.duplicate(true)
	void_choice["path"] = "sword"
	void_choice["realm"] = "golden"
	void_choice["maxDaoHeart"] = 10
	void_choice["pathSkillActivationIndex"] = 1
	void_choice["attributes"]["daoHeart"] = 10
	void_choice["currentCardId"] = "loc_void_first"
	void_choice["sceneLayerState"]["triggeredCards"] = ["loc_void_first"]
	var resisted: Dictionary = flow.settle(void_choice, "right")
	if resisted.is_empty() or int(resisted.get("attributes", {}).get(
			"daoHeart", -1)) != 7:
		_fail("source void card bypassed path skill dao-heart resistance: %s %s" % [
			flow.last_error, resisted.get("attributes", {}).get("daoHeart")])
		return
	print("NONCOMBAT_SCENE_LAYER_FLOW_PASS visit=8 clue=true treasure=true")
	quit(0)

func _fail(message: String) -> void:
	push_error(message)
	quit(1)
