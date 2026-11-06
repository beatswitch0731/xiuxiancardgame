extends "res://tests/noncombat_npc_cross_preset.gd"


func _run() -> void:
	var content = Repository.new()
	var expected_statuses := {"rival": ["rival"],
		"ally": ["ally", "master-disciple"],
		"ambient": ["neutral", "estranged"]}
	for branch in ["rival", "ally", "ambient"]:
		var rule: Dictionary = content.find("generated_card", "npc_cross_rule:" + branch)
		if rule.get("sourcePath") != "src/systems/NpcSystem.js" \
				or rule.get("sourceSymbol") != "NpcSystem._emitCrossCard" \
				or rule.get("sourceSha256") != "913ccdd6a3eb4464e3d3ce91ac1761c18cf8f2ce9346eb4929f2bf291046e6c8" \
				or rule.get("relationSourceSha256") != content.source_sha256("npcs:npc_relations") \
				or rule.get("npcSourceSha256") != content.source_sha256("npcs:core") \
				or rule.get("templateIdentity") != true \
				or rule.get("relationStatuses") != expected_statuses[branch] \
				or rule.get("reachability", {}).get("instanceIdDynamic") != true:
			return _fail("dynamic cross rule source missing: " + branch)
	var duplicate = Repository.new()
	if not duplicate.build_index():
		return _fail("source registry unavailable for duplicate probe")
	duplicate._index_cross_rules()
	if not duplicate.errors().has("Duplicate generated_card ID: npc_cross_rule:rival"):
		return _fail("duplicate dynamic rule identity accepted")
	var fixture_path := ProjectSettings.globalize_path(
		"res://tests/fixtures/artifacts/godot-migration/npc-cross-dynamic-source.json")
	var source_rows: Variant = JSON.parse_string(FileAccess.get_file_as_string(fixture_path))
	if not source_rows is Array or source_rows.size() != 3:
		return _fail("browser dynamic pair oracle unavailable")
	if source_rows[0].get("kind") != "scheduled" \
			or source_rows[1].get("kind") != "scheduled" \
			or source_rows[2].get("kind") != "template-only":
		return _fail("browser dynamic reachability labels drifted")
	var flow = CrossFlow.new(content)
	# The live browser uses ordinary six-period schedules; the first draw rejects
	# the eligible authored preset and the second admits the scheduled pair.
	flow.roll_override_sequence = [0.99, 0.0]
	var state := _state("foundation", "宗门")
	state["npcCrossState"] = flow.marker(state, 1, 1)
	var collected: Dictionary = flow.collect(state)
	var queue: Array = collected.get("npcCrossState", {}).get("queuedCards", [])
	if queue.is_empty() or not queue[0] is Dictionary:
		return _fail("dynamic pair did not enter the NPC cross queue")
	var queued: Dictionary = queue[0]
	if queued.get("id") != "npc_cross_bai_ren_jian_linger_1" \
			or queued.get("title") != "白刃真人与剑灵儿·叙旧" \
			or queued.get("semanticKey") != "npc-cross:bai_ren:jian_linger:master-disciple" \
			or queued.get("repeatPolicy", {}).get("cooldownTurns") != 12 \
			or not _matches_browser(queued, source_rows[0].card):
		return _fail("dynamic pair source projection differs")
	var double_queue := collected.duplicate(true)
	double_queue.turn = 37
	double_queue.runClock.decisionIndex = 37
	double_queue.npcCrossState.relations[
		flow._pair_key("bai_ren", "jian_linger")].status = "ally"
	double_queue.npcCrossState.rollTape = [0.99, 0.0]
	double_queue.npcCrossState.rollCursor = 0
	var two: Dictionary = flow.collect(double_queue)
	if two.get("npcCrossState", {}).get("queuedCards", []).size() != 2 \
			or two.npcCrossState.queuedCards[1].get("id") != \
				"npc_cross_bai_ren_jian_linger_37":
		return _fail("source double queue did not retain both statuses")
	var first: Dictionary = flow.take(two)
	if first.get("currentCardId") != queued.id \
			or flow.card(first).get("id") != queued.id:
		return _fail("older dynamic card lost after same-pair reissue")
	var first_settled: Dictionary = flow.settle(first, "left")
	if first_settled.get("phase") != "FLOW_PENDING" \
			or first_settled.npcCrossState.issuedCards.has(queued.id) \
			or not first_settled.npcCrossState.issuedCards.has(
				"npc_cross_bai_ren_jian_linger_37") \
			or first_settled.npcCrossState.queuedCards.size() != 1:
		return _fail("settled old issuance did not retain newer queue")
	var second: Dictionary = flow.take(first_settled)
	if second.get("currentCardId") != "npc_cross_bai_ren_jian_linger_37" \
			or flow.card(second).get("id") != second.currentCardId:
		return _fail("newer same-pair issuance was lost")
	var old_shape := two.duplicate(true)
	old_shape.npcCrossState.version = 1
	old_shape.npcCrossState.erase("issuedCards")
	var upgraded: Dictionary = flow.collect(old_shape)
	if not flow.valid(old_shape) or upgraded.get("npcCrossState", {}).get(
			"version") != 2 or upgraded.npcCrossState.issuedCards.size() != 2 \
			or flow.card(flow.take(old_shape)).get("id") != queued.id:
		return _fail("legacy v1 double queue silently lost old card")
	var missing_issued := two.duplicate(true)
	missing_issued.npcCrossState.erase("issuedCards")
	if flow.valid(missing_issued) or flow.take(missing_issued).get("phase") == \
			"NPC_CROSS_PENDING":
		return _fail("new v2 state missing issuance ledger accepted")
	var delayed := collected.duplicate(true)
	delayed.turn = 2
	delayed.runClock.decisionIndex = 2
	var delayed_pending: Dictionary = flow.take(delayed)
	if delayed_pending.get("phase") != "NPC_CROSS_PENDING" \
			or flow.card(delayed_pending).get("id") != queued.id \
			or flow.settle(delayed_pending, "left").get("phase") != "FLOW_PENDING":
		return _fail("delayed dynamic queue lost its source turn")
	var future := collected.duplicate(true)
	future.npcCrossState.queuedCards[0].id = "npc_cross_bai_ren_jian_linger_3"
	future.npcCrossState.lastCrossTurn[flow._pair_key("bai_ren", "jian_linger")] = 3
	if flow.take(future).get("phase") == "NPC_CROSS_PENDING":
		return _fail("future dynamic source turn accepted")
	var wrong_queue := delayed.duplicate(true)
	wrong_queue.npcCrossState.issuedCards[queued.id].turn = 2
	if flow.take(wrong_queue).get("phase") == "NPC_CROSS_PENDING":
		return _fail("dynamic ID and issued turn mismatch accepted")
	var wrong_clock := delayed.duplicate(true)
	wrong_clock.runClock.decisionIndex = 0
	if flow.take(wrong_clock).get("phase") == "NPC_CROSS_PENDING":
		return _fail("dynamic card beyond decision clock accepted")
	var pending: Dictionary = flow.take(collected)
	if pending.get("phase") != "NPC_CROSS_PENDING" \
			or flow.card(pending).get("id") != queued.id:
		return _fail("dynamic pair did not surface at priority 31")
	var forged := pending.duplicate(true)
	forged.pendingNpcCrossCard.choices.left.effects.wisdom = 999
	if not flow.card(forged).is_empty() or not flow.settle(forged, "left").is_empty():
		return _fail("forged dynamic choice accepted")
	var forged_queue := collected.duplicate(true)
	forged_queue.npcCrossState.queuedCards[0].title = "伪造标题"
	if flow.take(forged_queue).get("phase") == "NPC_CROSS_PENDING":
		return _fail("forged queued title accepted")
	var missing_source := collected.duplicate(true)
	missing_source.npcCrossState.queuedCards[0].erase("_dynamicSource")
	if flow.take(missing_source).get("phase") == "NPC_CROSS_PENDING":
		return _fail("unmarked dynamic queue entered pending state")
	var disk_path := "user://tests/npc_cross_rule_%d.json" % Time.get_ticks_usec()
	var disk := FileAccess.open(disk_path, FileAccess.WRITE)
	if disk == null:
		return _fail("dynamic pending cold file unavailable")
	disk.store_string(JSON.stringify(delayed_pending))
	disk.close()
	var reopened: Variant = JSON.parse_string(FileAccess.get_file_as_string(disk_path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(disk_path))
	if not reopened is Dictionary or flow.card(reopened).get("id") != queued.id \
			or flow.settle(reopened, "left").get("phase") != "FLOW_PENDING":
		return _fail("dynamic pending disk cold projection failed: valid=%s card=%s" % [
			flow.valid(reopened), flow.card(reopened).get("id", "")])
	var forged_cold: Dictionary = reopened.duplicate(true)
	forged_cold.currentCardId = "npc_cross_bai_ren_jian_linger_3"
	forged_cold.pendingNpcCrossCard.id = forged_cold.currentCardId
	if not flow.card(forged_cold).is_empty() \
			or not flow.settle(forged_cold, "left").is_empty():
		return _fail("future dynamic card accepted after cold read")
	var stale := collected.duplicate(true)
	stale.worldContinuityState.npcs.jian_linger.lifecycle = "DEAD"
	var cleared: Dictionary = flow.take(stale)
	if cleared.get("phase") != "FLOW_PENDING" \
			or not cleared.npcCrossState.queuedCards.is_empty():
		return _fail("invalidated queued dynamic scene did not clear")
	var chosen: Dictionary = flow.settle(pending, "left")
	if chosen.get("phase") != "FLOW_PENDING" \
			or int(chosen.npcCrossState.affections.get("bai_ren", 0)) != int(
				state.npcCrossState.affections.bai_ren) + 3 \
			or int(chosen.npcCrossState.affections.get("jian_linger", 0)) != int(
				state.npcCrossState.affections.jian_linger) + 3 \
			or int(chosen.knowledge.get("wisdom", 0)) != 3:
		return _fail("dynamic pair choice effects differ")
	var cooldown: Dictionary = flow.collect(chosen)
	if not cooldown.get("npcCrossState", {}).get("queuedCards", []).is_empty():
		return _fail("dynamic pair repeated during hard cooldown")
	var early := chosen.duplicate(true)
	early.turn = 12
	early.runClock.decisionIndex = 12
	if not flow.collect(early).get("npcCrossState", {}).get("queuedCards", []).is_empty():
		return _fail("dynamic pair repeated before narrative cooldown")
	var ready := chosen.duplicate(true)
	ready.turn = 36
	ready.runClock.decisionIndex = 36
	ready.npcCrossState.rollTape = [0.99, 0.0]
	ready.npcCrossState.rollCursor = 0
	if flow.collect(ready).get("npcCrossState", {}).get("queuedCards", []).is_empty():
		return _fail("dynamic pair did not recur after twelve decisions")
	var displaced = CrossFlow.new(content)
	displaced.roll_override_sequence = [0.99, 0.0]
	var split := _state("foundation", "宗门")
	split.turn = 18
	split.runClock.decisionIndex = 18
	split.npcCrossState = displaced.marker(split, 1, 1)
	if not displaced.collect(split).get("npcCrossState", {}).get("queuedCards", []).is_empty():
		return _fail("same region falsely treated as same NPC schedule")
	var dead = CrossFlow.new(content)
	dead.roll_override_sequence = [0.0]
	var absent := _state("golden", "南疆·月湖")
	absent.npcCrossState = dead.marker(absent, 1, 1)
	absent.worldContinuityState.npcs.ds_moonmist.lifecycle = "DEAD"
	if not dead.collect(absent).get("npcCrossState", {}).get("queuedCards", []).is_empty():
		return _fail("dead NPC entered dynamic physical scene")
	var prior_life = CrossFlow.new(content)
	prior_life.roll_override_sequence = [0.0]
	var stale_life := _state("golden", "南疆·月湖")
	stale_life.npcCrossState = prior_life.marker(stale_life, 1, 1)
	stale_life.worldContinuityState.npcs.ds_moonmist.lifeId = 1
	if not prior_life.collect(stale_life).get("npcCrossState", {}).get(
			"queuedCards", []).is_empty():
		return _fail("previous-life NPC entered current physical scene")
	var neutral = CrossFlow.new(content)
	neutral.roll_override_sequence = [0.0, 0.0]
	var lake := _state("golden", "南疆·月湖")
	lake.npcCrossState = neutral.marker(lake, 1, 1)
	var lake_queue: Array = neutral.collect(lake).get("npcCrossState", {}).get("queuedCards", [])
	if lake_queue.is_empty() or lake_queue[0].get("relationStatus") != "neutral" \
			or not _matches_browser(lake_queue[0], source_rows[1].card):
		return _fail("scheduled neutral pair differs from browser")
	# Rival is a browser template oracle only: these actors are not co-scheduled
	# by the live entrypoint, so it must not count as a naturally reachable pair.
	var rival_state := _state("tribulation", "天门裂隙")
	rival_state.npcCrossState = flow.marker(rival_state, 1, 1)
	rival_state.npcCrossState.lastCrossTurn[
		flow._pair_key("bai_ren", "xuesha_laozu")] = 1
	var npc_data: Dictionary = content.read_module("npcs:core")
	var bai := {}
	var xuesha := {}
	for npc in npc_data.get("npcs", []):
		if npc.get("id") == "bai_ren": bai = npc
		if npc.get("id") == "xuesha_laozu": xuesha = npc
	var relation: Dictionary = rival_state.npcCrossState.relations.get(
		flow._pair_key("bai_ren", "xuesha_laozu"), {})
	var rival_card: Dictionary = flow._dynamic_card(rival_state, bai, xuesha,
		"天门裂隙", relation)
	if not _matches_browser(rival_card, source_rows[2].card):
		return _fail("rival template differs from browser")
	for status in ["ally", "estranged"]:
		var id := "npc_cross_bai_ren_xuesha_laozu_1"
		rival_state.npcCrossState.issuedCards[id] = {"turn": 1,
			"pairKey": flow._pair_key("bai_ren", "xuesha_laozu"),
			"semanticKey": "npc-cross:bai_ren:xuesha_laozu:" + status}
		var generated: Dictionary = flow._dynamic_card(rival_state, bai, xuesha,
			"天门裂隙", {"status": status, "affinity": 0}, 0)
		if generated.get("relationStatus") != status \
				or not flow._valid_dynamic_card(rival_state, generated, false):
			return _fail("dynamic rule status did not consume: " + status)
	var forged_registry = Repository.new()
	if not forged_registry.build_index():
		return _fail("source registry unavailable for forgery probe")
	forged_registry._indexes.generated_card["npc_cross_rule:ally"].sourceSha256 = "forged"
	var forged_flow = CrossFlow.new(forged_registry)
	if not forged_flow._dynamic_card(rival_state, bai, xuesha,
			"天门裂隙", {"status": "ally", "affinity": 20}).is_empty():
		return _fail("forged dynamic rule source accepted")
	print("NONCOMBAT_NPC_CROSS_DYNAMIC_PASS scheduled=2 templates=3 cooldown=12 effects=true source=true forged=true duplicate=true delayed=true cold=true")
	quit(0)


func _matches_browser(actual: Dictionary, expected: Dictionary) -> bool:
	var browser_shape: Dictionary = actual.duplicate(true)
	for key in ["_flowSource", "_flowPhase", "_dynamicSource"]:
		browser_shape.erase(key)
	return JSON.parse_string(JSON.stringify(browser_shape)) == JSON.parse_string(
		JSON.stringify(expected))
