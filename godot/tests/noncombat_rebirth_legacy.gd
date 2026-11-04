extends SceneTree

const Registry = preload("res://scripts/runtime_data_registry.gd")
const Domain = preload("res://scripts/noncombat_domain.gd")
const RunSession = preload("res://scripts/noncombat_run_session.gd")
const ContentRepository = preload("res://scripts/noncombat_content_repository.gd")
const RebirthFlow = preload("res://scripts/noncombat_rebirth_flow.gd")
const NpcEncounterFlow = preload("res://scripts/noncombat_npc_encounter_flow.gd")
const LineageFlow = preload("res://scripts/noncombat_lineage_flow.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	# Reach the original white-fox third card through the running Godot flow.
	# Its funded right choice is a source-shaped reward projection: the opening
	# route itself has only 10 stones, so it cannot pay the source's 20-stone gate.
	var route_path := "user://tests/rebirth_legacy_route_%d.json" % Time.get_ticks_usec()
	var game = Domain.new(Registry.new(), RunSession.new(route_path, "slot_3"), "slot_3")
	if not game.start("sword"):
		return _fail("sword opening unavailable")
	for i in 5:
		if not game.choose("left", game.issue_choice_token()):
			return _fail("tutorial route stopped")
	if not game.choose("right", game.issue_choice_token()) \
			or not game.choose("left", game.issue_choice_token()) \
			or not game.resume_flow() \
			or not game.choose("left", game.issue_choice_token()) \
			or not game.choose("right", game.issue_choice_token()) \
			or not game.resume_flow() \
			or not game.choose("right", game.issue_choice_token()) \
			or not game.choose("left", game.issue_choice_token()) \
			or game.get_current_card().get("id") != "q_whiteFox_3":
		return _fail("white-fox third card route stopped")
	var funded: Dictionary = game.state.duplicate(true)
	funded["resources"]["spiritStone"] = 20
	var paid: Dictionary = game._quest_flow.settle(funded, "right")
	if paid.is_empty() or paid.get("flags", {}).get("white_fox_lineCompleted") != true \
			or paid.get("factionProgress", {}).get("reputations", {}).get(
				"qingyun_sword") != 15 \
			or paid.get("factionProgress", {}).get("reputations", {}).get(
				"xuesha_sect") != -15:
		return _fail("source quest did not produce completion and faction progress")
	var terminal: Dictionary = paid.duplicate(true)
	terminal["phase"] = "DEATH_PENDING"
	terminal["lifePhase"] = "DYING_NARRATIVE"
	terminal["dead"] = true
	terminal["deathCauseId"] = "death_dao_collapse"
	terminal["currentCardId"] = "death_dao_collapse"
	terminal["lifeCount"] = 0
	terminal["lifeJournal"] = []
	terminal["flags"]["failedQuestCompleted"] = false
	terminal["flags"]["quest_white_fox_line_active"] = true
	terminal["flags"]["post_ascension_active"] = true
	terminal["flags"]["breakthrough_boost:probe"] = true
	terminal["flags"]["game_ended"] = true
	terminal["questState"]["activeQuests"] = [{"questId": "spell_codex",
		"step": 1, "startedAt": 50}]
	terminal["questState"]["closedQuests"].append_array([
		"pill_master", "tianshu_codex"])
	terminal["questState"]["questOutcomes"]["pill_master"] = "failed"
	terminal["questState"]["questOutcomes"]["tianshu_codex"] = "abandoned"
	var card_row: Dictionary = ContentRepository.new().find(
		"card", "death_dao_collapse")
	var death_card: Variant = card_row.get("data")
	if not death_card is Dictionary:
		return _fail("source death card unavailable")
	var flow = RebirthFlow.new()
	var first: Dictionary = flow.new_life(terminal, death_card, "left", "slot_3", 2)
	if first.get("legacyFactionReputations", {}).get("qingyun_sword") != 9 \
			or first.get("legacyFactionReputations", {}).get("xuesha_sect") != -9 \
			or first.get("legacyFactionReputations", {}).get(
				"qingyun_sword_ancient") != -3 \
			or first.get("factionProgress", {}).get("reputations", {}).get(
				"qingyun_sword") != 12 \
			or first.get("factionProgress", {}).get("reputations", {}).get(
				"xuesha_sect") != -12 \
			or first.get("flags", {}).get("white_fox_lineCompleted") != true \
			or first.get("flags", {}).get("failedQuestCompleted") != false \
			or first.get("flags", {}).get("quest_white_fox_line_active") != false \
			or first.get("flags", {}).has("post_ascension_active") \
			or first.get("flags", {}).has("breakthrough_boost:probe") \
			or first.get("flags", {}).has("game_ended") \
			or first.get("rebirthInheritanceVersion") != 2 \
			or first.get("questState", {}).get("activeQuests") != [] \
			or first.get("questState", {}).get("completedQuests") != ["white_fox_line"] \
			or first.get("questState", {}).get("closedQuests") != [
				"white_fox_line", "pill_master", "tianshu_codex"] \
			or first.get("questState", {}).get("questOutcomes") != {
				"white_fox_line": "completed", "pill_master": "failed",
				"tianshu_codex": "abandoned"} \
			or "white_fox_lineCompleted" not in first.get(
				"legacyCompletedQuests", []) \
			or "failedQuestCompleted" in first.get("legacyCompletedQuests", []):
		return _fail("earned faction and successful quest legacy was lost")
	terminal["legacyFactionReputations"] = {
		"qingyun_sword": 12, "xuesha_sect": -11}
	terminal["legacyCompletedQuests"] = ["oldQuestCompleted"]
	var stacked: Dictionary = flow.new_life(terminal, death_card, "left", "slot_3", 2)
	if stacked.get("legacyFactionReputations", {}).get("qingyun_sword") != 12 \
			or stacked.get("legacyFactionReputations", {}).get("xuesha_sect") != -11 \
			or stacked.get("factionProgress", {}).get("reputations", {}).get(
				"qingyun_sword") != 16 \
			or stacked.get("factionProgress", {}).get("reputations", {}).get(
				"xuesha_sect") != -14 \
			or not stacked.get("legacyCompletedQuests", []).has("oldQuestCompleted") \
			or not stacked.get("legacyCompletedQuests", []).has(
				"white_fox_lineCompleted"):
		return _fail("older reputation peak or completed quest was overwritten")
	var old_projection: Dictionary = flow.new_life(terminal, death_card,
		"left", "slot_3", 0)
	if old_projection.is_empty() or old_projection.has("rebirthInheritanceVersion") \
			or old_projection.has("legacyFactionReputations") \
			or old_projection.has("factionProgress") \
			or old_projection.get("flags") != {}:
		return _fail("previous rebirth schema changed during source replay")
	var v1_projection: Dictionary = flow.new_life(terminal, death_card,
		"left", "slot_3", 1)
	if v1_projection.get("rebirthInheritanceVersion") != 1 \
			or v1_projection.has("questState"):
		return _fail("already-written v1 rebirth snapshot changed")
	var npc_terminal: Dictionary = terminal.duplicate(true)
	npc_terminal["npcAffection"] = {"bai_luoxuan": 73,
		"jian_linger": 99, "ds_demoness": -20}
	npc_terminal["legacyNpcAffections"] = {"bai_ren": 50,
		"bai_luoxuan": 42, "old_unknown": 9}
	npc_terminal["npcEncounterScheduling"] = {"affections": {"bai_ren": 79}}
	var npc_reborn: Dictionary = flow.new_life(npc_terminal, death_card,
		"left", "slot_3", 3)
	if npc_reborn.get("rebirthInheritanceVersion") != 3 \
			or npc_reborn.get("legacyNpcAffections", {}).get("bai_ren") != 50.0 \
			or npc_reborn.get("npcAffection", {}).get("bai_ren") != 50 \
			or npc_reborn.get("legacyNpcAffections", {}).get("bai_luoxuan") != 42.0 \
			or npc_reborn.get("npcAffection", {}).get("bai_luoxuan") != 42 \
			or npc_reborn.get("legacyNpcAffections", {}).get("jian_linger") != 49.5 \
			or npc_reborn.get("npcAffection", {}).get("jian_linger") != 50 \
			or npc_reborn.get("npcAffection", {}).get("ds_demoness") != 10 \
			or npc_reborn.get("npcAffection", {}).get("xuesha_laozu") != 3 \
			or npc_reborn.get("legacyNpcAffections", {}).get("old_unknown") != 9 \
			or npc_reborn.get("npcAffection", {}).size() != 15:
		return _fail("NPC affection legacy or new-life initialization differs from source")
	var npc_marker: Dictionary = NpcEncounterFlow.new(ContentRepository.new()).marker(
		npc_reborn, 0)
	if npc_marker.get("affections", {}).get("bai_ren") != 50:
		return _fail("inherited Bai Ren affection did not reach encounter schedule")
	var untouched_terminal: Dictionary = npc_terminal.duplicate(true)
	untouched_terminal["npcAffection"] = {}
	untouched_terminal["legacyNpcAffections"] = {}
	untouched_terminal["npcEncounterScheduling"] = {"affections": {
		"bai_ren": 0}, "memories": {"bai_ren": []}}
	var untouched_reborn: Dictionary = flow.new_life(untouched_terminal,
		death_card, "left", "slot_3", 3)
	if untouched_reborn.get("legacyNpcAffections", {}).get("bai_ren") != 5.0 \
			or untouched_reborn.get("npcAffection", {}).get("bai_ren") != 5:
		return _fail("untouched Bai Ren lost browser companion starting affection")
	untouched_terminal["npcEncounterScheduling"]["memories"]["bai_ren"] = [
		{"encounter": "already_settled"}]
	var settled_zero: Dictionary = flow.new_life(untouched_terminal,
		death_card, "left", "slot_3", 3)
	if settled_zero.get("npcAffection", {}).get("bai_ren") != 0:
		return _fail("settled zero Bai Ren affection was replaced with starting affection")
	var v2_npc: Dictionary = flow.new_life(npc_terminal, death_card,
		"left", "slot_3", 2)
	if v2_npc.has("legacyNpcAffections") or v2_npc.has("npcAffection"):
		return _fail("already-written v2 rebirth snapshot changed")
	for old_realm in ["foundation", "golden", "nascent", "deity", "tribulation"]:
		var realm_terminal: Dictionary = npc_terminal.duplicate(true)
		realm_terminal["realm"] = old_realm
		var realm_reborn: Dictionary = flow.new_life(realm_terminal, death_card,
			"left", "slot_3", 3)
		var lifespan_gain := 6 if old_realm in ["foundation", "golden"] \
			else 12 if old_realm in ["nascent", "deity"] else 0
		if realm_reborn.get("legacyBonuses", {}).get("startCultivation", 0) \
				!= int(npc_reborn.get("legacyBonuses", {}).get("startCultivation", 0)) + 3 \
				or realm_reborn.get("legacyBonuses", {}).get("maxLifespan", 0) \
				!= int(npc_reborn.get("legacyBonuses", {}).get("maxLifespan", 0)) \
					+ lifespan_gain:
			return _fail("realm-based new-life bonuses differ from browser source")
	var older_realm: Dictionary = npc_terminal.duplicate(true)
	older_realm["realm"] = "nascent"
	older_realm["lifeCount"] = 1
	older_realm["runClock"]["lifeId"] = "slot_3:life:1"
	var later_realm: Dictionary = flow.new_life(older_realm, death_card,
		"left", "slot_3", 3)
	if later_realm.get("legacyBonuses", {}).get("startCultivation", 0) \
			!= int(npc_reborn.get("legacyBonuses", {}).get("startCultivation", 0)) + 5 \
			or later_realm.get("legacyBonuses", {}).get("maxLifespan", 0) \
			!= int(npc_reborn.get("legacyBonuses", {}).get("maxLifespan", 0)) + 14:
		return _fail("later-life realm bonus did not use new life count")
	var lineage_flow = LineageFlow.new(ContentRepository.new())
	var tree: Dictionary = lineage_flow.initial_tree()
	tree["unlockedNodeIds"] = ["bonds_familiar_voice", "bonds_red_thread",
		"bonds_shared_dream", "bonds_returning_gaze"]
	tree["spentInsight"] = 10
	var lineage_terminal: Dictionary = npc_terminal.duplicate(true)
	lineage_terminal["rebirthTree"] = tree
	lineage_terminal["lineageEntries"] = []
	var tree_reborn: Dictionary = flow.new_life(lineage_terminal, death_card,
		"left", "slot_3")
	if tree_reborn.get("rebirthInheritanceVersion") != 5 \
			or tree_reborn.get("legacyNpcAffections", {}).get("jian_linger") \
				!= 69.3 \
			or tree_reborn.get("npcAffection", {}).get("jian_linger") != 69 \
			or tree_reborn.get("lineageEntries", []).size() != 1 \
			or int(tree_reborn.get("rebirthTree", {}).get("insight", 0)) <= 0:
		return _fail("source tree retention or first-life insight did not enter rebirth")
	var old_tree_reborn: Dictionary = flow.new_life(lineage_terminal, death_card,
		"left", "slot_3", 4)
	if old_tree_reborn.get("rebirthInheritanceVersion") != 4 \
			or old_tree_reborn.get("lineageEntries", []).size() != 1 \
			or old_tree_reborn.lineageEntries[0].get("activeRoute") != null:
		return _fail("v4 rebirth archive is not replay-compatible")
	var memory_terminal: Dictionary = npc_terminal.duplicate(true)
	var memory_tree: Dictionary = lineage_flow.initial_tree()
	memory_tree["unlockedNodeIds"] = ["memory_clear_mark"]
	memory_terminal["rebirthTree"] = memory_tree
	var memory_reborn: Dictionary = flow.new_life(memory_terminal, death_card,
		"left", "slot_3")
	if memory_reborn.get("legacyPathMemories", {}).get(
			String(memory_terminal.get("path", ""))) != 2:
		return _fail("source tree path-memory gain was not archived")
	var later_quest: Dictionary = funded.duplicate(true)
	later_quest["factionProgress"] = stacked["factionProgress"].duplicate(true)
	var later_paid: Dictionary = game._quest_flow.settle(later_quest, "right")
	if later_paid.is_empty() or later_paid.get("factionProgress", {}).get(
			"reputations", {}).get("qingyun_sword") != 21 \
			or later_paid.get("factionProgress", {}).get(
				"reputations", {}).get("xuesha_sect") != -19:
		return _fail("quest reward projection did not consume inherited faction reputation: "
			+ JSON.stringify(later_paid.get("factionProgress", {}))
			+ " error=" + String(game._quest_flow.last_error))
	var save_path := "user://tests/rebirth_legacy_commit_%d.json" % Time.get_ticks_usec()
	var store = RunSession.new(save_path, "slot_3")
	var initial: Dictionary = store.commit_snapshot(terminal, -1)
	if initial.get("ok") != true:
		return _fail("projected terminal could not be staged")
	var before_bytes := FileAccess.get_file_as_string(store.v2_path)
	store.fail_promotion_once = true
	if store.commit_life_transition(stacked, int(initial["revision"]),
			"left").get("ok") == true \
			or FileAccess.get_file_as_string(store.v2_path) != before_bytes:
		return _fail("failed inheritance commit changed the active save")
	if store.commit_life_transition(stacked, int(initial["revision"]),
			"left").get("ok") != true:
		return _fail("inherited new life did not commit atomically")
	var reopened: Dictionary = RunSession.new(save_path, "slot_3").load_snapshot()
	if reopened.is_empty() or JSON.parse_string(JSON.stringify(reopened.get("state"))) \
			!= JSON.parse_string(JSON.stringify(stacked)):
		return _fail("inherited new life did not survive durable restart")
	print("NONCOMBAT_REBIRTH_LEGACY_PASS faction=true quest=true npc=true realm=true peak=true rollback=true restart=true")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
