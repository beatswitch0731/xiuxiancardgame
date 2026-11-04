extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var ui: Control = load("res://scenes/noncombat_opening.tscn").instantiate()
	ui.save_path = ""
	ui.experience_settings_path = "user://tests/capture_experience_%d.cfg" % Time.get_ticks_usec()
	root.add_child(ui)
	await process_frame
	if not ui.opening.start("spell"):
		return _fail("capture story could not start")
	ui.name_screen.visible = false
	ui.path_screen.visible = false
	ui.slot_screen.visible = false
	ui.story_screen.visible = true
	ui._set_scene_surface(true)
	ui.experience_settings.set_option("textScale", "large")
	ui.experience_settings.set_option("readableFont", true)
	ui.experience_settings.set_option("highContrast", true)
	ui._render()
	var output := ProjectSettings.globalize_path("res://").trim_suffix(
		"/").get_base_dir().path_join("output/godot/experience_settings")
	if DirAccess.make_dir_recursive_absolute(output) != OK:
		return _fail("capture output directory unavailable")
	for resolution in [Vector2i(1280, 800), Vector2i(1920, 1080)]:
		root.get_window().size = resolution
		await process_frame
		await process_frame
		await process_frame
		var story_file := output.path_join("story_%dx%d.png" % [
			resolution.x, resolution.y])
		if root.get_window().get_texture().get_image().save_png(story_file) != OK:
			return _fail("story capture failed")
		ui._open_experience_dialog()
		await process_frame
		await process_frame
		var dialog_file := output.path_join("dialog_%dx%d.png" % [
			resolution.x, resolution.y])
		if root.get_window().get_texture().get_image().save_png(dialog_file) != OK:
			return _fail("dialog capture failed")
		ui.experience_dialog.hide()
		ui.bestiary_dialog.open_bestiary(ui.opening)
		await process_frame
		await process_frame
		var bestiary_file := output.path_join("bestiary_%dx%d.png" % [
			resolution.x, resolution.y])
		if root.get_window().get_texture().get_image().save_png(bestiary_file) != OK:
			return _fail("bestiary capture failed")
		ui.bestiary_dialog.hide()
		print("EXPERIENCE_CAPTURE ", story_file, " ", dialog_file,
			" ", bestiary_file)
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
