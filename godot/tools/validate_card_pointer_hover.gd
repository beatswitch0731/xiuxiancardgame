extends SceneTree

# Route a pointer event through the real Viewport/Control hit test instead of
# emitting the card's mouse_entered signal directly.

func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var unaffordable := "--unaffordable" in OS.get_cmdline_user_args()
	root.size = Vector2i(1024, 768) if "--narrow" in OS.get_cmdline_user_args() \
		else Vector2i(1280, 800)
	var game: Control = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	for frame in 12:
		await process_frame
	if unaffordable:
		game.combat.state["qi"] = 0
		game._render_hand()
		await process_frame
	var card := game.hand_row.get_child(2) as Button
	print("POINTER_LAYOUT viewport=", root.get_viewport().get_visible_rect().size,
		" game=", game.get_global_rect(), " hand=", game.hand_row.get_global_rect(),
		" card=", card.get_global_rect())
	for index in range(game.hand_row.get_child_count()):
		var candidate := game.hand_row.get_child(index) as Button
		var probe_point := candidate.get_global_rect().get_center()
		var probe_motion := InputEventMouseMotion.new()
		probe_motion.position = probe_point
		probe_motion.global_position = probe_point
		root.get_viewport().push_input(probe_motion, true)
		for frame in 24:
			await process_frame
		if not bool(candidate.get_meta("hovered", false)) \
				or not (candidate.get_node("HoverDetail") as Panel).visible \
				or game.card_table.hover_index != index:
			push_error("Real pointer cannot inspect hand card %d" % index)
			game.queue_free()
			await process_frame
			quit(1)
			return
	var point := card.get_global_rect().get_center()
	var event := InputEventMouseMotion.new()
	event.position = point
	event.global_position = point
	root.get_viewport().push_input(event, true)
	for frame in 24:
		await process_frame
	var detail := card.get_node("HoverDetail") as Panel
	var passed: bool = bool(card.get_meta("hovered", false)) and card.scale.x >= 1.12 \
		and detail.visible and game.card_table.hover_index == 2 \
		and game.card_table.mouse_filter == Control.MOUSE_FILTER_IGNORE \
		and game.card_table.size.y <= 90.0
	var selected: Array[int] = []
	game.hand_row.card_selected.connect(func(index: int) -> void: selected.append(index))
	for down in [true, false]:
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.position = point
		click.global_position = point
		click.pressed = down
		root.get_viewport().push_input(click, true)
		await process_frame
	if unaffordable:
		passed = passed and card.disabled and selected.is_empty() and game.card_table.confirm_strength == 0.0
	else:
		passed = passed and 2 in selected and game.card_table.confirm_strength > 0.0
	if not passed:
		push_error("Pointer path did not lift and select center card at " + str(point))
	print("CARD_POINTER_HOVER ", "PASS" if passed else "FAIL", " unaffordable=", unaffordable, " point=", point,
		" selected=", selected)
	game.queue_free()
	await process_frame
	quit(0 if passed else 1)
