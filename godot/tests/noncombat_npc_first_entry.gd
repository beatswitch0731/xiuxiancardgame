extends "res://tests/noncombat_cadence_third_entry.gd"

const NPC_FIXTURE := "res://tests/fixtures/npc_first_source.json"

func _run() -> void:
	var first: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	var second: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SECOND_FIXTURE))
	var npc: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(NPC_FIXTURE))
	var file := "user://tests/npc_first_%d.json" % Time.get_ticks_usec()
	var game = Domain.new(Registry.new(), Session.new(file, "slot_2"), "slot_2")
	_quiet_ambient(game)
	if not _open_second(game, first, second) \
			or not game.choose("right", game.issue_choice_token()):
		return _fail("npc first prefix: " + _problem)
	var prefix: Array = [
		["promise_result_eee72bc7", "left"],
		["mentor_bai_ren_stage_INNER_DISCIPLE", "right"],
		["promise_result_dc8715d0", "left"],
		["em_heaven_gaze", "right"]]
	for input in prefix:
		if game.state.phase == "FLOW_PENDING" and not game.resume_flow():
			return _fail("npc first prefix resume: " + game.flow_failure_reason())
		if game.get_current_card().get("id") != input[0] \
				or not game.choose(String(input[1]), game.issue_choice_token()):
			return _fail("npc first prefix card: " + input[0])
	if game.state.phase == "FLOW_PENDING" and not game.resume_flow():
		return _fail("npc first did not resume")
	if game.state.phase != "NPC_PENDING" \
			or not _expect(_canonical(game.get_current_card()),
				_canonical(npc.rows[0].card), "npc first source card"):
		return _fail("npc first source mismatch: " + _problem + " phase=" +
			String(game.state.phase) + " card=" + String(game.get_current_card().get("id")))
	if _cold(game, "npc first pending") == null:
		return _fail("npc first cold restore: " + _problem)
	var ui_scene: PackedScene = load("res://scenes/noncombat_opening.tscn")
	var ui: Control = ui_scene.instantiate()
	ui.save_path = ""
	root.add_child(ui)
	await process_frame
	ui.opening = game
	ui._render()
	if ui.title_label.text != npc.rows[0].card.title or ui.art_rect.texture == null:
		return _fail("NPC source card did not render its authored portrait")
	ui.queue_free()
	await process_frame
	print("NONCOMBAT_NPC_FIRST_ENTRY_PASS source=true public=true replay=true portrait=true")
	quit(0)
