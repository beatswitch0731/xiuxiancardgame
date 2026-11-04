extends SceneTree

const OUTPUT := "res://../artifacts/godot-migration/pixel-dungeon-demo/"


func _initialize() -> void:
	call_deferred("_capture")


func _capture() -> void:
	var game: Control = load("res://scenes/main.tscn").instantiate()
	game.pixel_dungeon_demo_preview = true
	root.add_child(game)
	for frame in 20:
		await process_frame
	await RenderingServer.frame_post_draw
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
		push_error("Pixel dungeon capture did not reach source sword contact")
		quit(1)
		return
	await RenderingServer.frame_post_draw
	if not _save("contact.png"):
		quit(1)
		return
	print("PIXEL_DUNGEON_WINDOWS_CAPTURE_PASS opening.png contact.png")
	quit(0)


func _save(name: String) -> bool:
	var directory := ProjectSettings.globalize_path(OUTPUT)
	DirAccess.make_dir_recursive_absolute(directory)
	var image := root.get_viewport().get_texture().get_image()
	if image == null or image.is_empty():
		push_error("Empty viewport capture: " + name)
		return false
	var path := ProjectSettings.globalize_path(OUTPUT + name)
	var error := image.save_png(path)
	if error != OK:
		push_error("Could not save viewport capture: " + path)
		return false
	return true
