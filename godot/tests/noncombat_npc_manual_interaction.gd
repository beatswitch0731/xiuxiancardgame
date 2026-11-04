extends "res://tests/noncombat_cadence_battle.gd"

const NpcInteraction = preload("res://scripts/noncombat_npc_interaction_flow.gd")
const Repository = preload("res://scripts/noncombat_content_repository.gd")


func _run() -> void:
	var file := "user://tests/npc_manual_%d.json" % Time.get_ticks_usec()
	var game = Domain.new(Registry.new(), Session.new(file, "slot_2"), "slot_2")
	_quiet_ambient(game)
	if not game.start("sword") or game.npc_roster().size() != 2 \
			or game.npc_roster()[0].id != "bai_ren" \
			or game.npc_roster()[1].id != "mortal":
		return _fail("source roster unavailable through domain: " +
			JSON.stringify(game.npc_roster()))
	if not game.state.has("npcEncounterScheduling"):
		return _fail("new opening has no manual NPC authority")
	var absent: Dictionary = game.state.duplicate(true)
	absent.worldContinuityState.npcs.erase("bai_ren")
	var physical_flow = NpcInteraction.new(Repository.new())
	if physical_flow.roster(absent).any(func(row: Variant) -> bool:
		return row is Dictionary and row.get("id") == "bai_ren") \
			or physical_flow.panel(absent, "bai_ren").get("canInteract") != false \
			or not physical_flow.apply(absent, "bai_ren", "闲聊").is_empty():
		return _fail("absent continuity NPC was offered as physical interaction")
	var panel: Dictionary = game.npc_panel("bai_ren")
	if panel.get("npc", {}).get("name") != "白刃真人" \
			or panel.get("mindset") != "执念" \
			or not panel.get("availableActions", []).has("闲聊"):
		return _fail("source panel differs")
	var opening_scene = load("res://scenes/noncombat_opening.tscn").instantiate()
	get_root().add_child(opening_scene)
	opening_scene.opening = game
	var roster_button: Button = opening_scene.find_child("OpenNpcRoster", true, false)
	if roster_button == null:
		return _fail("NPC roster entry missing from player story UI")
	roster_button.pressed.emit()
	var widget = opening_scene.npc_interaction_dialog
	if not widget.visible or widget._list.get_child_count() != 2 \
			or not String(widget._list.get_child(0).text).contains("白刃真人"):
		return _fail("NPC roster not visible through player entry")
	widget._list.get_child(0).pressed.emit()
	var chat_button: Button
	for child in widget._list.get_children():
		if child is Button and child.text == "闲聊":
			chat_button = child
	if chat_button == null:
		return _fail("source chat action absent from NPC detail")
	chat_button.pressed.emit()
	opening_scene.queue_free()
	if game.state.get("npcInteractionHistory", []).size() != 1:
		return _fail("manual chat from player UI did not commit")
	game = _cold(game, "NPC chat before first decision")
	if game == null:
		return _fail("first manual action failed cold replay")
	if not game.choose("right", game.issue_choice_token()):
		return _fail("tutorial decision failed")
	if not game.state.has("npcEncounterScheduling"):
		return _fail("shared NPC marker absent")
	var before: Dictionary = game.state.duplicate(true)
	var bytes := FileAccess.get_file_as_bytes(game._store.v2_path)
	game._store.fail_promotion_once = true
	if game.interact_npc("bai_ren", "闲聊") or not _unchanged(game, before, bytes):
		return _fail("failed NPC disk commit changed state")
	if not game.interact_npc("bai_ren", "闲聊"):
		return _fail("public NPC chat failed")
	if game.state.npcEncounterScheduling.memories.bai_ren.size() != 2 \
			or game.state.npcInteractionHistory.size() != 2:
		return _fail("chat did not enter shared memory and journal")
	var after: Dictionary = game.state.duplicate(true)
	game = _cold(game, "NPC manual chat")
	if game == null or not _same(game.state, after):
		return _fail("manual chat failed strict cold replay")
	if not game.choose("right", game.issue_choice_token()):
		return _fail("choice after manual chat failed")
	var continued: Dictionary = game.state.duplicate(true)
	game = _cold(game, "choice after NPC manual chat")
	if game == null or not _same(game.state, continued):
		return _fail("later decision failed NPC action replay")
	for attempt in 40:
		if int(game.npc_panel("bai_ren").affection) >= 15:
			break
		if not game.interact_npc("bai_ren", "闲聊"):
			return _fail("public repeated chat failed")
	if int(game.npc_panel("bai_ren").affection) < 15 \
			or not game.npc_panel("bai_ren").availableActions.has("请教") \
			or not game.state.get("npcInteractionSecrets", {}).get("bai_ren", []).has(1):
		return _fail("teaching threshold not reached")
	var teach_before: Dictionary = game.state.duplicate(true)
	var teach_bytes := FileAccess.get_file_as_bytes(game._store.v2_path)
	game._store.fail_promotion_once = true
	if game.interact_npc("bai_ren", "请教") or not _unchanged(
			game, teach_before, teach_bytes):
		return _fail("failed teaching transaction changed state")
	if not game.interact_npc("bai_ren", "请教") \
			or game.interact_npc("bai_ren", "请教") \
			or game.interact_npc("bai_ren", "赠礼", "醉仙酿"):
		return _fail("public teaching and shared budget differed")
	var taught: Dictionary = game.state.duplicate(true)
	game = _cold(game, "public teaching")
	if game == null or not _same(game.state, taught):
		return _fail("public teaching failed cold replay")
	var flow = NpcInteraction.new(Repository.new())
	var sample: Dictionary = game.state.duplicate(true)
	sample.itemInventory = {"醉仙酿": 1}
	sample.erase("interactionBudget")
	sample.npcAffection = {"bai_ren": 0}
	sample.npcEncounterScheduling.affections.bai_ren = 0
	var gift: Dictionary = flow.apply(sample, "bai_ren", "赠礼", "醉仙酿")
	if gift.is_empty() or gift.get("itemInventory", {}).has("醉仙酿") \
			or gift.get("interactionBudget", {}).get("bai_ren", {}).get(
				str(int(sample.turn)), {}).get("action") != "赠礼" \
			or not flow.apply(gift, "bai_ren", "请教").is_empty():
		return _fail("gift consumption or per-turn budget differs")
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(
		"res://../artifacts/godot-migration/npc-manual-source.json"))
	if fixture.get("catalogSize") != 16 or fixture.get("qiVisible") != ["bai_ren", "mortal"] \
			or fixture.get("cases", []).size() != 5 \
			or not fixture.cases.any(func(row: Variant) -> bool:
				return row is Dictionary and row.get("action") == "闲聊" \
					and row.get("rolls") == [0.0, 0.9]):
		return _fail("browser NPC roster oracle drifted")
	for row in fixture.cases:
		var oracle: Dictionary = game.state.duplicate(true)
		oracle.turn = 1
		oracle.realm = row.realm
		oracle.npcAffection = {"bai_ren": row.affection}
		oracle.npcEncounterScheduling.affections.bai_ren = row.affection
		oracle.npcEncounterScheduling.bonds.bai_ren = 0
		oracle.npcEncounterScheduling.memories.bai_ren = []
		oracle.erase("npcInteractionHistory")
		oracle.erase("interactionBudget")
		oracle.itemInventory = {"醉仙酿": 1}
		flow.roll_override_sequence = row.rolls
		var actual: Dictionary = flow.apply(oracle, "bai_ren", String(row.action),
			String(row.get("itemId", "")))
		if actual.is_empty() or actual.npcInteractionHistory.back().reaction != \
				row.result.reaction or int(actual.npcInteractionHistory.back().affectionDelta) \
				!= int(row.result.affDelta) or int(actual.npcAffection.bai_ren) \
				!= int(row.result.newAffection) or int(actual.npcEncounterScheduling.bonds.bai_ren) \
				!= int(row.bond) or not _same(actual.get("itemInventory", {}), row.inventory) \
				or not _same(actual.get("interactionBudget", {}), row.budget):
			return _fail("browser NPC action oracle differs: " + String(row.action))
	print("NONCOMBAT_NPC_MANUAL_PASS qi_roster=2 chat=true gift=true budget=true cold=true rollback=true")
	quit(0)
