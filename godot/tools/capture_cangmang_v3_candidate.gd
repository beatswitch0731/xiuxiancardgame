extends SceneTree

# Candidate only: replace the world in memory, keep the real first-fight UI,
# source fighter sequences, cards and CombatDomain unchanged.
const OUTPUT := "res://output/captures/godot-migration/hd2d-world-v3/"


func _initialize() -> void:
	call_deferred("_capture")


func _capture() -> void:
	var game: Control = load("res://scenes/main.tscn").instantiate()
	game.outdoor_candidate_preview = true
	root.add_child(game)
	var stage: Node = game.duel_stage
	var candidate: Node3D = stage.get_world_model()
	for frame in 30:
		await process_frame
	await RenderingServer.frame_post_draw
	if not _save("godot-opening.png"):
		quit(1)
		return
	for yaw in [-20.0, 20.0]:
		stage.set_diagnostic_yaw(yaw)
		for frame in 4:
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
	if hovered_card.scale.x < 1.12 or hovered_card.position.y > -16.0 \
			or not (hovered_card.get_node("HoverDetail") as Panel).visible:
		push_error("Card did not lift and reveal source description on hover")
		quit(1)
		return
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
		push_error("V3 candidate did not reach source sword contact")
		quit(1)
		return
	await RenderingServer.frame_post_draw
	if not _save("godot-contact.png"):
		quit(1)
		return
	print("CANGMANG_V3_CANDIDATE_CAPTURE_PASS meshes=", candidate.get_child_count())
	quit(0)


func _save(name: String) -> bool:
	var directory := ProjectSettings.globalize_path(OUTPUT)
	DirAccess.make_dir_recursive_absolute(directory)
	var image := root.get_viewport().get_texture().get_image()
	return image != null and not image.is_empty() and image.save_png(directory.path_join(name)) == OK
