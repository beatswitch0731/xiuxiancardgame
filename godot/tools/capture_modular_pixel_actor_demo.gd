extends SceneTree

const OUTPUT := "res://output/captures/godot-migration/modular-pixel-actor-demo/"


func _initialize() -> void:
	call_deferred("_capture")


func _capture() -> void:
	var game: Control = load("res://scenes/modular_pixel_actor_demo.tscn").instantiate()
	root.add_child(game)
	for frame in 20:
		await process_frame
	var selector: OptionButton = game.get_node("ActorStudySelector")
	for variant in 4:
		selector.select(variant)
		selector.item_selected.emit(variant)
		for frame in 3:
			await process_frame
		await RenderingServer.frame_post_draw
		if not _save(["old_frames.png", "unarmed.png", "practice_sword.png", "rusted_broken_sword.png"][variant]):
			quit(1)
			return
	selector.select(2)
	selector.item_selected.emit(2)
	var armor_selector: OptionButton = game.get_node("ArmorStudySelector")
	armor_selector.select(1)
	armor_selector.item_selected.emit(1)
	await RenderingServer.frame_post_draw
	if not _save("armor_idle.png"):
		quit(1)
		return
	armor_selector.select(0)
	armor_selector.item_selected.emit(0)
	var contacts: Array[String] = []
	game.duel_stage.contact_frame.connect(func(side: String) -> void: contacts.append(side))
	(game.hand_row.get_child(0) as Button).pressed.emit()
	for frame in 120:
		if "player" in contacts:
			break
		await process_frame
	if not "player" in contacts:
		push_error("Modular capture did not reach source sword contact")
		quit(1)
		return
	await RenderingServer.frame_post_draw
	if not _save("contact.png"):
		quit(1)
		return
	armor_selector.select(1)
	armor_selector.item_selected.emit(1)
	await RenderingServer.frame_post_draw
	if not _save("armor_contact.png"):
		quit(1)
		return
	print("MODULAR_PIXEL_ACTOR_CAPTURE_PASS old, unarmed, practice, rusted, armor idle/contact")
	quit(0)


func _save(name: String) -> bool:
	var capture_size := root.get_viewport().get_visible_rect().size
	var size_name := "%dx%d" % [int(capture_size.x), int(capture_size.y)]
	var subdirectory := "" if size_name == "1280x800" else size_name + "/"
	var directory := ProjectSettings.globalize_path(OUTPUT + subdirectory)
	DirAccess.make_dir_recursive_absolute(directory)
	var image := root.get_viewport().get_texture().get_image()
	if image == null or image.is_empty():
		push_error("Empty viewport capture: " + name)
		return false
	var path := ProjectSettings.globalize_path(OUTPUT + subdirectory + name)
	var error := image.save_png(path)
	if error != OK:
		push_error("Could not save viewport capture: " + path)
		return false
	return true
