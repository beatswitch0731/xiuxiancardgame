extends SceneTree

const OpeningScene = preload("res://scenes/noncombat_opening.tscn")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var output := ProjectSettings.globalize_path(
		"res://output/godot/experience_effects")
	DirAccess.make_dir_recursive_absolute(output)
	var ui: Control = OpeningScene.instantiate()
	ui.slot_root_path = "user://tests/experience_effect_capture/"
	ui.audio_settings_path = "user://tests/experience_effect_capture_audio.cfg"
	ui.gallery_settings_path = "user://tests/experience_effect_capture_gallery.cfg"
	ui.experience_settings_path = "user://tests/experience_effect_capture.cfg"
	root.add_child(ui)
	await process_frame
	for viewport_size in [Vector2i(1280, 800), Vector2i(1920, 1080)]:
		root.get_window().size = viewport_size
		for quality in ["high", "low"]:
			ui.experience_settings.set_option("effects", quality)
			ui.experience_settings.set_option("steadyCamera", quality == "low")
			ui._apply_experience_settings()
			ui._open_experience_dialog()
			for _frame in 5:
				await process_frame
			var filename := "%s/slot_%s_%d.png" % [output, quality,
				viewport_size.x]
			var error := root.get_window().get_texture().get_image().save_png(
				filename)
			if error != OK:
				push_error("experience screenshot failed: " + filename)
				quit(1)
				return
			ui.experience_dialog.hide()
	ui._on_slot_pressed("slot_1")
	if ui.opening == null or not ui.opening.start("spell"):
		push_error("experience story capture could not start")
		quit(1)
		return
	ui.slot_screen.visible = false
	ui.name_screen.visible = false
	ui.path_screen.visible = false
	ui.story_screen.visible = true
	ui._set_scene_surface(true)
	ui._render()
	root.get_window().size = Vector2i(1280, 800)
	for quality in ["high", "low"]:
		ui.experience_settings.set_option("effects", quality)
		ui.experience_settings.set_option("steadyCamera", quality == "low")
		ui._apply_experience_settings()
		for _frame in 5:
			await process_frame
		var filename := "%s/story_%s_1280.png" % [output, quality]
		var error := root.get_window().get_texture().get_image().save_png(filename)
		if error != OK:
			push_error("experience screenshot failed: " + filename)
			quit(1)
			return
	ui.queue_free()
	await process_frame
	print("NONCOMBAT_EXPERIENCE_CAPTURE_PASS images=6")
	quit(0)
