extends "res://tests/noncombat_npc_first_entry.gd"

func _run() -> void:
	var first: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	var second: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SECOND_FIXTURE))
	var npc: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(NPC_FIXTURE))
	for row in npc.rows:
		var file := "user://tests/npc_choice_%s_%d.json" % [
			row.direction, Time.get_ticks_usec()]
		var game = Domain.new(Registry.new(), Session.new(file, "slot_2"), "slot_2")
		_quiet_ambient(game)
		if not _open_second(game, first, second) \
				or not game.choose("right", game.issue_choice_token()):
			return _fail("npc choice prefix: " + _problem)
		for input in [["promise_result_eee72bc7", "left"],
				["mentor_bai_ren_stage_INNER_DISCIPLE", "right"],
				["promise_result_dc8715d0", "left"],
				["em_heaven_gaze", "right"]]:
			if game.state.phase == "FLOW_PENDING" and not game.resume_flow():
				return _fail("npc choice prefix resume")
			if game.get_current_card().get("id") != input[0] \
					or not game.choose(String(input[1]), game.issue_choice_token()):
				return _fail("npc choice prefix card: " + input[0])
		if game.state.phase == "FLOW_PENDING" and not game.resume_flow():
			return _fail("npc choice did not present")
		if game.get_current_card().get("id") != row.card.id:
			return _fail("npc choice source card absent")
		var before: Dictionary = game.state.duplicate(true)
		game = _cold(game, "npc choice pending")
		if game == null:
			return _fail("npc choice pending restore: " + _problem)
		if not game.choose(row.direction, game.issue_choice_token()):
			return _fail("npc choice rejected: " + row.direction)
		if int(game.state.turn) != int(before.turn) + 1 \
				or game.state.phase != "FLOW_PENDING":
			return _fail("npc choice clock or phase")
		for key in row.before.attributes:
			if row.before.attributes[key] is int or row.before.attributes[key] is float:
				if not _expect(int(game.state.attributes.get(key, 0)) - int(
						before.attributes.get(key, 0)), int(row.after.attributes[key]) - int(
						row.before.attributes[key]), "npc choice/" + key):
					return _fail(_problem)
		var marker: Dictionary = game.state.npcEncounterScheduling
		if not _expect(int(marker.affections.bai_ren),
				int(row.npcAfter.affections.bai_ren), "npc affection"):
			return _fail(_problem)
		var memory: Dictionary = marker.memories.bai_ren.back()
		var source_memory: Dictionary = row.npcAfter.memories.bai_ren.back()
		for key in ["turn", "action", "reaction", "affectionDelta"]:
			if not _expect(memory.get(key), source_memory.get(key),
					"npc memory/" + key):
				return _fail(_problem)
		game = _cold(game, "npc choice result")
		if game == null or not game.resume_flow():
			return _fail("npc choice continuation")
		if game.get_current_card().get("id") != row.nextCard.id \
				or _cold(game, "npc choice next") == null:
			return _fail("npc choice next source or replay")
		print("NPC_FIRST_CHOICE_PASS " + row.direction)
	print("NONCOMBAT_NPC_FIRST_CHOICES_PASS cases=2 source=true replay=true")
	quit(0)
