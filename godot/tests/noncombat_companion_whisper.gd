extends SceneTree

const Whisper = preload("res://scripts/noncombat_companion_whisper.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var whisper = Whisper.new()
	var state := {"resources": {"companions": ["bai_luoxuan"]},
		"companionProgress": {"states": {"bai_luoxuan": {}}},
		"npcAffection": {"bai_luoxuan": 80}}
	var card := {"id": "source_choice", "type": "NORMAL", "tags": [],
		"choices": {"right": {"effects": {"cultivation": 5}}}}
	var response: Dictionary = whisper.reaction(state, card, "right")
	if response.get("eventType") != "cultivate" \
			or response.get("text") != "道侣修炼的样子——很好看。":
		return _fail("source high-affection cultivation whisper differs")
	if whisper.greeting(state).get("text") != "道侣——等你很久了。" \
			or whisper.idle_lines(state).size() != 3 \
			or not whisper.idle_lines(state).has("道侣——月亮出来了。"):
		return _fail("source high-affection HUD greeting or idle lines differ")
	state.npcAffection.bai_luoxuan = 39
	card.choices.right.effects = {"health": 2}
	response = whisper.reaction(state, card, "right")
	if response.get("eventType") != "heal" \
			or response.get("text") != "你受伤了？我回去熬药。":
		return _fail("source low-affection healing whisper differs")
	state.resources.companions = []
	if not whisper.reaction(state, card, "right").is_empty():
		return _fail("unowned companion produced a whisper")
	var ui: Control = load("res://scenes/noncombat_opening.tscn").instantiate()
	ui.save_path = ""
	root.add_child(ui)
	await process_frame
	if not ui.opening.start("sword"):
		return _fail("desktop source run could not start")
	ui._on_choice_pressed("right", ui.opening.issue_choice_token())
	if ui.opening.get_current_card().get("id") != "tutorial_4":
		return _fail("desktop source cultivation choice did not advance")
	ui.opening.state.resources.companions = ["bai_luoxuan"]
	ui.opening.state["npcAffection"] = {"bai_luoxuan": 80}
	if not ui.opening.state.get("companionProgress", {}).get("states", {}).has(
			"bai_luoxuan"):
		return _fail("source companion state not registered")
	ui._render()
	if not ui.companion_whisper_panel.visible \
			or ui.companion_portrait_rect.texture == null \
			or not ui.companion_identity_label.text.contains("♥ 80") \
			or not whisper.idle_lines(ui.opening.state).has(
				ui.companion_whisper_label.text):
		return _fail("persistent companion HUD lacks portrait, affection or idle line")
	var prior_bubble: String = ui.companion_whisper_label.text
	ui._on_choice_pressed("right", -1)
	if ui.companion_whisper_label.text != prior_bubble:
		return _fail("rejected choice changed the companion bubble")
	ui._on_choice_pressed("right", ui.opening.issue_choice_token())
	if not ui.companion_whisper_panel.visible \
			or not ui.companion_whisper_label.text.contains(
				"道侣修炼的样子——很好看。"):
		return _fail("successful source choice has no visible companion whisper")
	for resolution in [Vector2i(1280, 800), Vector2i(1920, 1080)]:
		root.get_window().size = resolution
		await process_frame
		await process_frame
		if ui.companion_whisper_panel.get_global_rect().end.y > resolution.y \
				or ui.companion_whisper_panel.get_global_rect().end.x > resolution.x \
				or ui.choice_row.get_global_rect().end.y > resolution.y \
				or ui.choice_row.get_global_rect().end.x > resolution.x:
			return _fail("whisper or choices clipped at %s: bubble=%s choices=%s" % [
				resolution, ui.companion_whisper_panel.get_global_rect(),
				ui.choice_row.get_global_rect()])
	await create_timer(3.6).timeout
	if not ui.companion_whisper_panel.visible \
			or ui.companion_whisper_label.visible:
		return _fail("source 3500ms bubble did not close while HUD remained")
	ui.opening.state.resources.companions = ["ds_demoness"]
	ui.opening.state.companionProgress.states = {"ds_demoness": {}}
	ui.opening.state.npcAffection = {"ds_demoness": 10}
	ui._render()
	if not ui.companion_whisper_panel.visible \
			or ui.companion_portrait_rect.texture != ui.registry.texture_for(
				"assets/cards/characters/card_demoness_pc98.png") \
			or not ui.companion_identity_label.text.contains("绯夜"):
		return _fail("source NPC companion portrait or name differs")
	print("NONCOMBAT_COMPANION_WHISPER_PASS source=true choice=true hud=true sizes=2 timeout=true generic=true")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
