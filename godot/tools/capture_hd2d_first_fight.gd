extends SceneTree

# Launch without --headless. Captures the actual Windows renderer at the
# production main scene before and at the first source sword contact.

const OUTPUT := "res://output/captures/godot-migration/hd2d-first-fight/"


func _initialize() -> void:
	call_deferred("_capture")


func _capture() -> void:
	var game: Control = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	for frame in 16:
		await process_frame
	await RenderingServer.frame_post_draw
	var directory := ProjectSettings.globalize_path(OUTPUT)
	DirAccess.make_dir_recursive_absolute(directory)
	if not _save("opening.png"):
		quit(1)
		return
	var contacts: Array[String] = []
	game.duel_stage.contact_frame.connect(func(side: String) -> void: contacts.append(side))
	(game.hand_row.get_child(0) as Button).pressed.emit()
	for frame in 120:
		if "player" in contacts:
			break
		await process_frame
	if not "player" in contacts:
		push_error("HD2D screenshot capture did not reach sword contact")
		quit(1)
		return
	await RenderingServer.frame_post_draw
	if not _save("contact.png"):
		quit(1)
		return
	game.queue_free()
	await process_frame
	var followthrough: Control = load("res://scenes/main.tscn").instantiate()
	root.add_child(followthrough)
	await process_frame
	followthrough.combat.state["hand"] = ["sword_followthrough"]
	followthrough.combat.state["qi"] = 4
	followthrough._render()
	var followthrough_contacts: Array[String] = []
	followthrough.duel_stage.contact_frame.connect(
		func(side: String) -> void: followthrough_contacts.append(side))
	if not followthrough.combat.play_card(0):
		push_error("Followthrough source card did not play for capture")
		quit(1)
		return
	for frame in 120:
		if "player" in followthrough_contacts:
			break
		await process_frame
	if not "player" in followthrough_contacts:
		push_error("Followthrough did not reach sword contact")
		quit(1)
		return
	await RenderingServer.frame_post_draw
	if not _save("followthrough-contact.png"):
		quit(1)
		return
	print("HD2D_WINDOWS_CAPTURE_PASS opening.png contact.png followthrough-contact.png")
	quit(0)


func _save(name: String) -> bool:
	var image := root.get_viewport().get_texture().get_image()
	if image == null or image.is_empty():
		push_error("Empty Windows viewport capture: " + name)
		return false
	var path := ProjectSettings.globalize_path(OUTPUT + name)
	var error := image.save_png(path)
	if error != OK:
		push_error("Could not save Windows viewport capture: " + path)
		return false
	return true
