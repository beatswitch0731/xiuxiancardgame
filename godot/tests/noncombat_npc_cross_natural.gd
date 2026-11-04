extends "res://tests/noncombat_qi_gate_arrival.gd"


func _run() -> void:
	var first: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	var second: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SECOND_FIXTURE))
	var third: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(THIRD_FIXTURE))
	var file := "user://tests/npc_cross_natural_%d.json" % Time.get_ticks_usec()
	var game = Domain.new(Registry.new(), Session.new(file, "slot_2"), "slot_2")
	_quiet_ambient(game)
	game._npc_cross_flow.roll_override_sequence = [0.0, 0.0]
	if not _open_third_alt(game, first, second, third) or not _reach_gate(game) \
			or not game.choose("left", game.issue_choice_token()):
		return _fail("public qi gate prefix for NPC cross: " + _problem)
	var request: Dictionary = game.battle_request()
	if request.get("sourceCardId") != "ch_qi_100" \
			or not game.submit_battle_result(_result(request, "victory")) \
			or not game.choose("left", game.issue_choice_token()) \
			or game.get_current_card().get("id") != "epiphany_foundation" \
			or not game.choose("left", game.issue_choice_token()) \
			or game.state.get("realm") != "foundation" \
			or game.state.get("currentLocation") != "宗门":
		return _fail("public foundation arrival for NPC cross")
	for step in 48:
		var before_resume: Dictionary = game.state.duplicate(true) if game.state.phase \
			== "FLOW_PENDING" else {}
		if game.state.phase == "FLOW_PENDING" and not game.resume_flow():
			return _fail("NPC cross natural flow stopped at %d: %s" % [step,
				game.flow_failure_reason()])
		var card_value: Dictionary = game.get_current_card()
		if game.state.phase == "NPC_CROSS_PENDING":
			if before_resume.is_empty() or not _priority_31_beats_30(before_resume):
				return _fail("simultaneous NPC narrative queues ignored source priority")
			var source: Dictionary = game._content.find("card", String(card_value.get("id", "")))
			var raw: Dictionary = source.get("data", {})
			if card_value.get("id") != "npc_cross_bai_ren_jian_linger_lesson" \
					or source.get("sourcePath") != "data/npcs/npc_cross_cards.json" \
					or card_value.get("description") != raw.get("description") \
					or card_value.get("_flowSource") != "narrative:31" \
					or not game.can_choose_direction("left"):
				return _fail("foundation NPC cross source card differs: " +
					String(card_value.get("id", "")))
			var pending: Dictionary = game.state.duplicate(true)
			if not _issuance_replay_probe(game):
				return _fail("NPC cross issuance strict replay probe failed")
			game = _cold(game, "NPC cross pending")
			if game == null or not _same(game.state, pending):
				return _fail("NPC cross pending strict cold restore: " + _problem)
			var ui: Control = load("res://scenes/noncombat_opening.tscn").instantiate()
			ui.save_path = ""
			root.add_child(ui)
			await process_frame
			ui.opening = game
			ui.slot_screen.visible = false
			ui.name_screen.visible = false
			ui.path_screen.visible = false
			ui.story_screen.visible = true
			ui._set_scene_surface(true)
			ui._render()
			if not ui.npc_cross_portraits.visible \
					or ui.npc_cross_left.texture != ui.registry.texture_for(
						"assets/characters/concept_bai_ren_zhenren.webp") \
					or ui.npc_cross_right.texture != ui.registry.texture_for(
						"assets/characters/concept_jian_linger.webp") \
					or ui.art_rect.visible or ui.title_label.text != card_value.title:
				return _fail("NPC cross desktop dual portraits or source text missing")
			for resolution in [Vector2i(1280, 800), Vector2i(1920, 1080)]:
				root.get_window().size = resolution
				await process_frame
				await process_frame
				for control in [ui.npc_cross_portraits, ui.source_text_panel,
					ui.choice_row]:
					if control.get_global_rect().end.x > resolution.x \
							or control.get_global_rect().end.y > resolution.y:
						return _fail("NPC cross desktop content clipped at %s/%s rect=%s" % [
							resolution, control.name, control.get_global_rect()])
			ui.queue_free()
			await process_frame
			var before: Dictionary = game.state.duplicate(true)
			var regen_probe = Domain.new(Registry.new(), null, "slot_2")
			if not regen_probe.start("sword"):
				return _fail("NPC cross regen probe could not start")
			regen_probe.state = before.duplicate(true)
			regen_probe.state.path = "body"
			regen_probe.state.realm = "golden"
			regen_probe.state.attributes.health = 4
			regen_probe._current_card_id = String(before.currentCardId)
			if not regen_probe.choose("left", regen_probe.issue_choice_token()) \
					or int(regen_probe.state.attributes.health) != 5:
				return _fail("NPC cross choice skipped source body turn regeneration")
			var bytes: PackedByteArray = FileAccess.get_file_as_bytes(game._store.v2_path)
			game._store.fail_promotion_once = true
			if game.choose("left", game.issue_choice_token()) \
					or not _same(game.state, before) \
					or FileAccess.get_file_as_bytes(game._store.v2_path) != bytes:
				return _fail("failed NPC cross choice changed durable state")
			if not game.choose("left", game.issue_choice_token()) \
					or game.state.get("phase") != "FLOW_PENDING":
				return _fail("NPC cross authored choice not settled")
			var after: Dictionary = game.state.duplicate(true)
			var affection: Dictionary = after.get("npcCrossState", {}).get("affections", {})
			if int(affection.get("jian_linger", 0)) \
					!= int(before.npcCrossState.affections.get("jian_linger", 0)) + 16 \
					or int(affection.get("bai_ren", 0)) \
					!= int(before.npcCrossState.affections.get("bai_ren", 0)) + 6 \
					or int(after.get("knowledge", {}).get("wisdom", 0)) \
					!= int(before.get("knowledge", {}).get("wisdom", 0)) + 5:
				return _fail("NPC cross double affection or wisdom differed")
			game = _cold(game, "NPC cross chosen")
			if game == null or not _same(game.state, after):
				return _fail("NPC cross chosen strict cold restore: " + _problem)
			print("NONCOMBAT_NPC_CROSS_NATURAL_PASS public=true card=%s priority=31 double_queue=true regen=true portraits=true sizes=2 cold=true atomic=true" % card_value.id)
			quit(0)
			return
		if game.state.phase == "BATTLE_PENDING":
			var next_request: Dictionary = game.battle_request()
			if next_request.is_empty() or not game.submit_battle_result(
					_result(next_request, "victory")):
				return _fail("NPC cross route battle stopped")
			continue
		var direction := "right" if game.state.phase in ["COMBAT_HANDOFF",
			"MARKET_PENDING", "FIRST_SESSION_ROUTE_PENDING", "NARRATIVE_RESULT_PENDING"] \
			or card_value.get("id") in ["q_sword_1", "ch_foundation_20"] else "left"
		if not game.can_choose_direction(direction):
			for fallback in ["left", "right", "down", "up"]:
				if game.can_choose_direction(fallback):
					direction = fallback
					break
		if not game.can_choose_direction(direction) or not game.choose(
				direction, game.issue_choice_token()):
			return _fail("NPC cross route stopped at %d %s/%s" % [
				step, game.state.phase, card_value.get("id")])
	return _fail("foundation NPC cross card did not surface in 48 decisions")


func _priority_31_beats_30(before_resume: Dictionary) -> bool:
	var file := "user://tests/npc_cross_priority_%d.json" % Time.get_ticks_usec()
	var store = Session.new(file, "slot_2")
	if not store.commit_snapshot(before_resume, -1).get("ok", false):
		return false
	var probe = Domain.new(Registry.new(), store, "slot_2")
	_quiet_ambient(probe)
	if not probe.restore():
		return false
	var npc: Dictionary = probe._npc_encounter_flow._definition(
		probe._content.read_module("npcs:core"))
	var solo: Dictionary = probe._npc_encounter_flow._project_card(
		probe.state, npc, "偶遇", "宗门")
	if solo.is_empty():
		return false
	probe.state.npcEncounterScheduling.queuedCard = solo
	if probe.state.npcCrossState.get("queuedCards", []).is_empty():
		probe.state.npcCrossState.queuedCardId = "npc_cross_bai_ren_jian_linger_lesson"
	elif probe.state.npcCrossState.queuedCards[0].get("id") \
			!= "npc_cross_bai_ren_jian_linger_lesson":
		return false
	probe._store = null
	return probe.resume_flow() and probe.get_current_card().get("id") \
		== "npc_cross_bai_ren_jian_linger_lesson" \
		and probe.state.npcEncounterScheduling.queuedCard.get("id") == solo.id


func _issuance_replay_probe(game: RefCounted) -> bool:
	var envelope: Variant = JSON.parse_string(FileAccess.get_file_as_string(
		game._store.v2_path))
	if not envelope is Dictionary or envelope.get("state") is not Dictionary \
			or envelope.state.get("npcCrossState", {}).get("version") != 2 \
			or envelope.state.npcCrossState.get("issuedCards") is not Dictionary:
		return false
	if not _issuance_replay_variant(envelope, true):
		return false
	var forged: Dictionary = envelope.duplicate(true)
	forged.state.npcCrossState.issuedCards["npc_cross_forged_1"] = {
		"turn": 1, "pairKey": "bai_ren_jian_linger", "semanticKey": "forged"}
	return _issuance_replay_variant(forged, false)


func _issuance_replay_variant(envelope: Dictionary, should_restore: bool) -> bool:
	var path := "user://tests/npc_cross_issuance_%d.json" % Time.get_ticks_usec()
	var store = Session.new(path, "slot_2")
	var output := FileAccess.open(store.v2_path, FileAccess.WRITE)
	if output == null:
		return false
	output.store_string(JSON.stringify(envelope))
	output.close()
	var probe = Domain.new(Registry.new(), Session.new(path, "slot_2"), "slot_2")
	_quiet_ambient(probe)
	var restored: bool = probe.restore()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(store.v2_path))
	return restored == should_restore and (not restored or _same(
		probe.state, envelope.state))
