extends SceneTree

const Repository = preload("res://scripts/noncombat_content_repository.gd")
const CrossFlow = preload("res://scripts/noncombat_npc_cross_flow.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var content = Repository.new()
	var source: Variant = content.read_module("npcs:npc_cross_cards")
	if not source is Dictionary or source.get("presetCards", []).size() != 5:
		return _fail("five authored cross cards unavailable")
	var cases := [
		["golden", "宗门", "npc_cross_bai_ren_xuesha_laozu_first", "left"],
		["foundation", "坊市", "npc_cross_jian_linger_yin_xue_sword", "left"],
		["foundation", "剑崖", "npc_cross_bai_ren_jian_linger_lesson", "left"],
		["golden", "魔域", "npc_cross_xuesha_laozu_yin_xue_family", "left"],
		["nascent", "坊市", "npc_cross_tianji_laoren_jiuwei_suyue_prophecy", "right"],
	]
	for row in cases:
		var flow = CrossFlow.new(content)
		flow.roll_override_sequence = [0.0, 0.0]
		var state := _state(String(row[0]), String(row[1]))
		state["npcCrossState"] = flow.marker(state, 1)
		if String(row[2]) in ["npc_cross_bai_ren_xuesha_laozu_first",
			"npc_cross_bai_ren_jian_linger_lesson"]:
			# The solo NPC scene can change affection after cross state starts.
			state["npcAffection"] = {"bai_ren": 20}
			state["npcEncounterScheduling"] = {"affections": {"bai_ren": 20},
				"bonds": {"bai_ren": 0}}
		if String(row[2]) == "npc_cross_bai_ren_xuesha_laozu_first":
			state["maxDaoHeart"] = 10
			state.attributes.daoHeart = 8
			state["legacyArchive"] = {"completedSetIds": ["demon_blood"]}
			state["legacyRunState"] = {"activeSetIds": ["demon_blood"]}
		if state.npcCrossState.is_empty() or not flow.valid(state):
			return _fail("cross source marker invalid: " + String(row[2]))
		var collected: Dictionary = flow.collect(state)
		if collected.get("npcCrossState", {}).get("queuedCardId") != row[2]:
			return _fail("source cross card not queued: " + String(row[2]))
		var pending: Dictionary = flow.take(collected)
		var card_value: Dictionary = flow.card(pending)
		if pending.get("phase") != "NPC_CROSS_PENDING" or card_value.get("id") != row[2] \
				or card_value.get("description") != _source_card(source, String(row[2])).get("description") \
				or card_value.get("semanticKey") != "npc-cross-preset:" + String(row[2]):
			return _fail("authored cross card changed in projection: " + String(row[2]))
		var settled: Dictionary = flow.settle(pending, String(row[3]))
		if settled.get("phase") != "FLOW_PENDING" or settled.get("turn") != 2 \
				or not settled.get("cardsPlayed", []).has(row[2]) \
				or not settled.get("npcCrossState", {}).get("resolved", []).has(
					"npc-cross-preset:" + String(row[2])):
			return _fail("cross choice failed to settle: " + String(row[2]))
		if String(row[2]) == "npc_cross_jian_linger_yin_xue_sword" \
				and (int(settled.npcCrossState.affections.jian_linger) \
					!= int(state.npcCrossState.affections.jian_linger) + 16 \
				or int(settled.npcCrossState.affections.yin_xue) \
					!= int(state.npcCrossState.affections.yin_xue) - 6):
			return _fail("bond and explicit npcAffection must both apply")
		if String(row[2]) == "npc_cross_bai_ren_jian_linger_lesson" \
				and (int(settled.npcCrossState.affections.bai_ren) != 26 \
				or int(settled.npcEncounterScheduling.affections.bai_ren) != 26):
			return _fail("cross bond must start from current solo NPC affection")
		if String(row[2]) == "npc_cross_bai_ren_xuesha_laozu_first" \
				and (int(settled.npcCrossState.relations.bai_ren_xuesha_laozu.affinity) \
					!= int(state.npcCrossState.relations.bai_ren_xuesha_laozu.affinity) + 15 \
				or int(settled.attributes.daoHeart) != 8 \
				or int(settled.npcCrossState.affections.bai_ren) != 23 \
				or int(settled.npcEncounterScheduling.affections.bai_ren) != 23):
			return _fail("cross relation or post-marker solo affection missing")
		settled["phase"] = "FLOW_PENDING"
		var once: Dictionary = flow.collect(settled)
		if once.get("npcCrossState", {}).get("queuedCardId") == row[2]:
			return _fail("cross semantic once did not close")
	var dead_flow = CrossFlow.new(content)
	dead_flow.roll_override_sequence = [0.0, 0.0]
	var dead := _state("golden", "宗门")
	dead["npcCrossState"] = dead_flow.marker(dead, 1)
	dead.worldContinuityState.npcs.xuesha_laozu.lifecycle = "DEAD"
	if not String(dead_flow.collect(dead).get("npcCrossState", {}).get(
			"queuedCardId", "")).is_empty():
		return _fail("dead actor entered physical cross scene")
	print("NONCOMBAT_NPC_CROSS_PRESET_PASS cards=5 authored=true once=true effects=true physical=true")
	quit(0)


func _state(realm: String, location: String) -> Dictionary:
	var npcs: Variant = Repository.new().read_module("npcs:core")
	var presence := {}
	for raw in npcs.get("npcs", []):
		presence[raw.id] = {"lifeId": 0, "lifecycle": "ACTIVE",
			"manifestation": "PHYSICAL"}
	return {"active": true, "phase": "FLOW_PENDING", "realm": realm,
		"currentLocation": location, "turn": 1, "lifeCount": 0,
		"cardsPlayed": [], "choiceHistory": [],
		"attributes": {"daoHeart": 10}, "maxDaoHeart": 100,
		"resources": {}, "knowledge": {}, "modifiers": {}, "npcAffection": {},
		"worldContinuityState": {"npcs": presence},
		"runClock": {"lifeId": "slot_1:life:0", "decisionIndex": 1, "receipts": {}},
		"marketRngState": {"initialSeed": 12345},
		"decisionCheckpoint": {"sourceCardId": "test"}}


func _source_card(source: Dictionary, card_id: String) -> Dictionary:
	for raw in source.get("presetCards", []):
		if raw.get("id") == card_id:
			return raw
	return {}


func _fail(reason: String) -> void:
	push_error(reason)
	quit(1)
