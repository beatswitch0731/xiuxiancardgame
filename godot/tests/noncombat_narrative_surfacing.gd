extends SceneTree

const Flow = preload("res://scripts/noncombat_narrative_surfacing.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var flow := Flow.new()
	var rule: Dictionary = flow.marker(0)
	if rule.is_empty():
		return _fail("surfacing rule source missing")
	var base := {"phase": "FLOW_PENDING", "realm": "qi", "turn": 10,
		"runClock": {"lifeId": "surfacing:life:0", "decisionIndex": 10,
			"receipts": {}}, "decisionCheckpoint": {"sourceCardId": "q_start_sword"},
		"narrativeSurfacingState": rule, "karmaSeeds": [{"id": "a"},
			{"id": "b"}, {"id": "c"}, {"id": "d"}],
		"attributes": {"cultivation": 30, "daoHeart": 2, "fortune": 40,
			"karmaGood": 0}, "maxDaoHeart": 3, "resources": {"treasures": []},
		"flags": {}, "cardsPlayed": [], "choiceHistory": [],
		"replayHistory": [], "recentCardTags": []}
	var karma: Dictionary = flow.take(base)
	if karma.get("phase") != "SURFACING_PENDING" \
			or flow.card(karma).get("id") != "surface_karma_burden" \
			or not flow.card(karma).get("description", "").contains("4颗因果种子"):
		return _fail("four seeds did not surface at turn ten")
	var chosen: Dictionary = flow.settle(karma, "right")
	if chosen.get("phase") != "FLOW_PENDING" \
			or int(chosen.get("attributes", {}).get("cultivation", -1)) != 40 \
			or int(chosen.get("attributes", {}).get("daoHeart", -1)) != 0 \
			or chosen.get("choiceHistory", []).size() != 1:
		return _fail("karma surfacing choice did not settle")
	var cooled: Dictionary = chosen.duplicate(true)
	cooled["turn"] = 15
	cooled["runClock"]["decisionIndex"] = 15
	var skipped: Dictionary = flow.take(cooled)
	if skipped.get("phase") != "FLOW_PENDING" \
			or int(skipped.get("narrativeSurfacingState", {}).get("lastCheckTurn", 0)) != 15:
		return _fail("narrative cooldown or check clock failed")
	var later: Dictionary = skipped.duplicate(true)
	later["turn"] = 25
	later["runClock"]["decisionIndex"] = 25
	if flow.take(later).get("currentCardId") != "surface_karma_burden":
		return _fail("expired narrative cooldown did not reopen")
	var world: Dictionary = base.duplicate(true)
	world["worldContinuityState"] = {"npcs": {"bairen_zhenren": {
		"lifecycle": "DEAD", "changedAtTurn": 7}}}
	var memory: Dictionary = flow.take(world)
	if flow.card(memory).get("id") != "surface_bairen_memory":
		return _fail("world death did not outrank karma")
	if flow.settle(memory, "right").get("attributes", {}).get("karmaGood") != 15:
		return _fail("world memory right choice failed")
	var inherited: Dictionary = flow.settle(memory, "left")
	if inherited.is_empty() or not inherited.get("resources", {}).get(
			"treasures", []).has("白刃遗剑"):
		return _fail("world memory source sword was not acquired")
	var affection: Dictionary = base.duplicate(true)
	affection["karmaSeeds"] = []
	affection["resources"]["companions"] = ["bai_luoxuan"]
	affection["companionProgress"] = {"states": {"bai_luoxuan": {}}}
	affection["npcAffection"] = {"bai_luoxuan": 18}
	var near: Dictionary = flow.take(affection)
	if flow.card(near).get("id") != "surface_bai_luoxuan_near_20" \
			or near.get("flags", {}).get("surface_pushed_bai_luoxuan_20") != true:
		return _fail("near-threshold companion did not surface")
	var replied: Dictionary = flow.settle(near, "left")
	if int(replied.get("npcAffection", {}).get("bai_luoxuan", 0)) != 23 \
			or int(replied.get("attributes", {}).get("fortune", 0)) != 45:
		return _fail("companion surfacing affection did not settle")
	print("NONCOMBAT_NARRATIVE_SURFACING_PASS karma=true world=true affection=true cooldown=true")
	quit(0)

func _fail(message: String) -> void:
	push_error(message)
	quit(1)
