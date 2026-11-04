extends SceneTree

const OUTPUT := "res://../artifacts/godot-migration/hd2d-world-v6/"


func _initialize() -> void:
	call_deferred("_capture")


func _capture() -> void:
	var game: Control = load("res://scenes/main.tscn").instantiate()
	game.trial_v6_candidate_preview = true
	root.add_child(game)
	var stage: Node = game.duel_stage
	for frame in 32:
		await process_frame
	await RenderingServer.frame_post_draw
	if not _save("godot-opening.png"):
		quit(1)
		return
	var hidden_overlays: Array[CanvasItem] = []
	for child in game.get_children():
		if child is CanvasItem and child != stage and child.visible:
			child.visible = false
			hidden_overlays.append(child)
	await RenderingServer.frame_post_draw
	if not _save("godot-world-only.png"):
		quit(1)
		return
	for overlay in hidden_overlays:
		overlay.visible = true
	for yaw in [-20.0, 20.0]:
		stage.set_diagnostic_yaw(yaw)
		for frame in 5:
			await process_frame
		await RenderingServer.frame_post_draw
		if not _save("godot-yaw-%s.png" % ("left20" if yaw < 0.0 else "right20")):
			quit(1)
			return
	stage.set_diagnostic_yaw(0.0)
	var hovered_card := game.hand_row.get_child(2) as Button
	hovered_card.mouse_entered.emit()
	for frame in 18:
		await process_frame
	await RenderingServer.frame_post_draw
	if not _save("godot-card-hover.png"):
		quit(1)
		return
	hovered_card.mouse_exited.emit()
	var contacts: Array[String] = []
	stage.contact_frame.connect(func(side: String) -> void: contacts.append(side))
	(game.hand_row.get_child(0) as Button).pressed.emit()
	for frame in 120:
		if "player" in contacts:
			break
		await process_frame
	if not "player" in contacts:
		push_error("V6 candidate did not reach source sword contact")
		quit(1)
		return
	await RenderingServer.frame_post_draw
	if not _save("godot-contact.png"):
		quit(1)
		return
	print("CANGMANG_V6_CANDIDATE_CAPTURE_PASS")
	quit(0)


func _save(name: String) -> bool:
	var directory := ProjectSettings.globalize_path(OUTPUT)
	DirAccess.make_dir_recursive_absolute(directory)
	var image := root.get_viewport().get_texture().get_image()
	return image != null and not image.is_empty() and image.save_png(directory.path_join(name)) == OK
