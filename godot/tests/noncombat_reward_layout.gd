extends "res://tests/noncombat_battle_return.gd"

func _run() -> void:
	var file := "user://tests/reward_layout_%d.json" % Time.get_ticks_usec()
	var game = Domain.new(Registry.new(), Session.new(file, "slot_2"), "slot_2")
	if not game.start("sword"):
		return _fail("reward layout: natural opening failed")
	for direction in ["right", "right", "left", "left", "left"]:
		if not game.choose(direction, game.issue_choice_token()):
			return _fail("reward layout: natural battle route failed")
	if not game.submit_battle_result(_result(game.battle_request(), "victory")) \
			or game.get_current_card().get("id") != "combat_reward":
		return _fail("reward layout: natural victory did not produce reward")
	var screen: Control = load("res://scenes/noncombat_opening.tscn").instantiate()
	root.add_child(screen)
	await process_frame
	screen.opening = game
	game.changed.connect(screen._on_opening_changed)
	screen.slot_screen.visible = false
	screen.name_screen.visible = false
	screen.story_screen.visible = true
	screen._set_scene_surface(true)
	screen._render()
	var capture: bool = "--capture-reward-layout" in OS.get_cmdline_user_args()
	for resolution in [Vector2i(1280, 800), Vector2i(1920, 1080)]:
		if capture:
			DisplayServer.window_set_size(resolution)
		root.size = resolution
		screen._render()
		await process_frame
		await process_frame
		await process_frame
		var art: TextureRect = screen.art_rect
		var arena: Variant = screen.get_node_or_null("RewardArenaStage")
		var choices: HBoxContainer = screen.choice_row
		var content: HBoxContainer = screen.get_node(
			"DesktopMargin/ScreenStack/StoryScreen/SourceContent")
		var text_panel: PanelContainer = screen.get_node_or_null(
			"DesktopMargin/ScreenStack/StoryScreen/SourceContent/SourceTextPanel")
		var settlement: Label = screen.get_node_or_null(
			"DesktopMargin/ScreenStack/StoryScreen/SourceContent/SourceTextPanel/SourceTextColumn/RewardSettlement")
		var reward_buttons: Array[Node] = choices.find_children("Choice_*", "Button", true, false)
		if art.texture == null or reward_buttons.size() != 4:
			return _fail("reward layout: source contract or four choices missing")
		if arena == null or not arena.has_hd2d_assets() \
				or arena.stage_art.get("selectedScene") != \
				"res://assets/hd2d/world_v17/qingyun_tutorial_hall_v17.glb" \
				or arena.get_node("Viewport").size != resolution \
				or not arena.get_actor_model("player").visible \
				or screen.background.visible:
			return _fail("reward layout: authored 3D teaching arena did not replace pixel backdrop")
		var content_box := content.get_global_rect()
		var panel_box := text_panel.get_global_rect()
		var choices_box := choices.get_global_rect()
		var gap: float = choices_box.position.y - panel_box.end.y
		print("REWARD_LAYOUT_MEASURE %sx%s panel_bottom=%s gap=%s choice_height=%s" % [
			resolution.x, resolution.y, panel_box.end.y, gap, choices_box.size.y])
		if text_panel == null or gap > 25.0 or choices_box.size.y < 108.0 \
				or choices_box.end.y > float(resolution.y) - 12.0 \
				or choices_box.position.x < float(resolution.x) * 0.47 \
				or choices_box.end.x > float(resolution.x) - 12.0 \
				or text_panel.size.y > content_box.size.y * 1.05:
			return _fail("reward layout: picture, receipt, or choices are disconnected")
		if settlement == null or not settlement.visible or not settlement.text.contains("修为") \
				or screen.status_label.text.contains("combat_reward") \
				or art.modulate.a > 0.05 or screen.backdrop_shade.color.a > 0.25:
			return _fail("reward layout: settlement hierarchy or unified backdrop missing")
		for child in reward_buttons:
			if (child as Button).disabled:
				return _fail("reward layout: a valid reward choice was disabled")
		var left_button: Button = choices.find_child("Choice_left", true, false)
		var right_button: Button = choices.find_child("Choice_right", true, false)
		var up_button: Button = choices.find_child("Choice_up", true, false)
		var down_button: Button = choices.find_child("Choice_down", true, false)
		var return_button: Button = screen.story_screen.find_child(
			"ReturnToSlots", true, false)
		if left_button.get_node(left_button.focus_next) != right_button \
				or right_button.get_node(right_button.focus_next) != up_button \
				or up_button.get_node(up_button.focus_next) != down_button \
				or return_button == null or not return_button.visible \
				or down_button.find_next_valid_focus() != return_button:
			return _fail("reward layout: keyboard focus does not follow visual rows")
		if capture:
			await RenderingServer.frame_post_draw
			var output_dir := ProjectSettings.globalize_path(
				"res://../artifacts/godot-migration/reward-arena-v8")
			DirAccess.make_dir_recursive_absolute(output_dir)
			var output := output_dir.path_join("reward_%sx%s.png" % [resolution.x, resolution.y])
			if root.get_texture().get_image().save_png(output) != OK:
				return _fail("reward layout: desktop screenshot save failed")
			print("REWARD_LAYOUT_CAPTURE " + output)
	var deck_before: int = game.state.get("deck", []).size()
	var reward_choice: Button = screen.choice_row.find_child("Choice_left", true, false)
	reward_choice.pressed.emit()
	await process_frame
	if game.state.get("deck", []).size() != deck_before + 1 \
			or game.get_current_card().get("id") == "combat_reward" \
			or screen.title_label.text == "大胜 · 择法" or screen._choice_pending \
			or screen.get_node_or_null("RewardArenaStage") != null \
			or not screen.background.visible:
		return _fail("reward layout: visible choice did not commit its skill")
	screen.queue_free()
	print("NONCOMBAT_REWARD_LAYOUT_PASS resolutions=1280x800,1920x1080 arena=true choice=true")
	quit(0)
