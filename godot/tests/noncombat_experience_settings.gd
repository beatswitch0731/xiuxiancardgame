extends SceneTree

const ExperienceSettings = preload("res://scripts/noncombat_experience_settings.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var path := "user://tests/experience_settings_%d.cfg" % Time.get_ticks_usec()
	var ui: Control = load("res://scenes/noncombat_opening.tscn").instantiate()
	ui.slot_root_path = "user://tests/experience_slots_%d/" % Time.get_ticks_usec()
	ui.audio_settings_path = "user://tests/experience_audio_%d.cfg" % Time.get_ticks_usec()
	ui.gallery_settings_path = "user://tests/experience_gallery_%d.cfg" % Time.get_ticks_usec()
	ui.experience_settings_path = path
	root.add_child(ui)
	await process_frame
	var slot_button: Button = ui.find_child("OpenExperienceSettingsSlots", true, false)
	if slot_button == null or not slot_button.is_visible_in_tree() \
			or ui.experience_settings.get_option("textScale") != "normal":
		return _fail("slot reading settings were not available")
	slot_button.pressed.emit()
	await process_frame
	if not ui.experience_dialog.visible or not ui.experience_text_scale.has_focus():
		return _fail("reading settings dialog or keyboard focus missing")
	if ui.ambient_particles.particle_count() != 380:
		return _fail("source ambient effect did not start at desktop high quality")
	ui.experience_effects.select(0)
	ui.experience_effects.item_selected.emit(0)
	ui.experience_steady_camera.button_pressed = true
	ui.ambient_particles.elapsed = 3.0
	if ui.ambient_particles.particle_count() != 80 \
			or ui.ambient_particles.breath_scale() != 1.0 \
			or ExperienceSettings.new(path).get_option("effects") != "low" \
			or ExperienceSettings.new(path).get_option("steadyCamera") != true:
		return _fail("ambient quality or stable background did not apply and persist")
	ui.experience_effects.select(1)
	ui.experience_effects.item_selected.emit(1)
	if ui.ambient_particles.particle_count() != 210 \
			or ExperienceSettings.new(path).get_option("effects") != "balanced":
		return _fail("balanced ambient budget did not apply and persist")
	ui.experience_effects.select(0)
	ui.experience_effects.item_selected.emit(0)
	if ui.experience_settings.set_option("effects", "invalid"):
		return _fail("unknown effect budget was accepted")
	var dialog_scale: Label = ui.experience_dialog.find_child(
		"ExperienceScaleLabel", true, false)
	var dialog_original_color: Color = dialog_scale.get_theme_color("font_color")
	var dialog_ok_original_color: Color = ui.experience_dialog.get_ok_button().get_theme_color(
		"font_color")
	var bestiary_ok_original_color: Color = ui.bestiary_dialog.get_ok_button().get_theme_color(
		"font_color")
	var import_ok_original_color: Color = ui.browser_import_dialog.get_ok_button().get_theme_color(
		"font_color")
	var bestiary_button_colors := {}
	for color_key in ["font_color", "font_hover_color", "font_pressed_color",
			"font_hover_pressed_color", "font_focus_color", "font_disabled_color"]:
		bestiary_button_colors[color_key] = ui.bestiary_dialog.get_ok_button().get_theme_color(
			color_key)
	ui.experience_text_scale.select(2)
	ui.experience_text_scale.item_selected.emit(2)
	ui.experience_readable_font.button_pressed = true
	ui.experience_high_contrast.button_pressed = true
	if ui.experience_settings.get_option("textScale") != "large" \
			or not ui.experience_settings.get_option("readableFont") \
			or not ui.experience_settings.get_option("highContrast") \
			or dialog_scale.get_theme_color("font_color") != Color("fff6df") \
			or ui.experience_dialog.get_ok_button().get_theme_color(
				"font_color") != Color("fff6df") \
			or ui.bestiary_dialog.get_ok_button().get_theme_color(
				"font_color") != Color("fff6df") \
			or ui.browser_import_dialog.get_ok_button().get_theme_color(
				"font_color") != Color("fff6df") \
			or ExperienceSettings.new(path).settings != ui.experience_settings.settings:
		return _fail("reading preferences were not saved outside the game slot")
	for color_key in bestiary_button_colors:
		var high_contrast_color := Color("d6ccb5") if color_key == \
			"font_disabled_color" else Color("fff6df")
		if ui.bestiary_dialog.get_ok_button().get_theme_color(color_key) != \
				high_contrast_color:
			return _fail("dialog button state missed high contrast: " + color_key)
	ui.experience_dialog.hide()
	ui._on_slot_pressed("slot_1")
	if ui.opening == null or not ui.opening.start("spell"):
		return _fail("story fixture could not start")
	ui.slot_screen.visible = false
	ui.name_screen.visible = false
	ui.path_screen.visible = false
	ui.story_screen.visible = true
	ui._set_scene_surface(true)
	ui._render()
	await process_frame
	await process_frame
	var before := JSON.stringify(ui.opening.state)
	var story_button: Button = ui.find_child("OpenExperienceSettings", true, false)
	if story_button == null or not story_button.is_visible_in_tree() \
			or ui.body_label.get_theme_font_size("font_size") != 23 \
			or ui.body_label.get_theme_font("font") != ui.READABLE_FONT \
			or ui.backdrop_shade.color.a < 0.8:
		return _fail("story text scale, readable font, or contrast did not apply")
	ui.title_label.add_theme_font_override("font", ui.INK_FONT)
	ui.title_label.add_theme_font_size_override("font_size", 37)
	ui._apply_experience_settings()
	if ui.title_label.get_theme_font("font") != ui.READABLE_FONT \
			or ui.title_label.get_theme_font_size("font_size") != 42:
		return _fail("reading preferences missed a new authored title style")
	ui.experience_settings.set_option("readableFont", false)
	ui._apply_experience_settings()
	if ui.title_label.get_theme_font("font") != ui.INK_FONT:
		return _fail("authored title font did not return when readable font was off")
	ui.experience_settings.set_option("readableFont", true)
	ui._apply_experience_settings()
	ui.bestiary_dialog.open_bestiary(ui.opening)
	await process_frame
	var portrait_row: Button = ui.bestiary_dialog._panels.companions.get_child(0)
	if portrait_row.get_theme_font_size("font_size") != 18 \
			or portrait_row.get_theme_font("font") != ui.READABLE_FONT \
			or portrait_row.get_theme_color("font_color") != Color("fff6df"):
		return _fail("new bestiary controls missed reading preferences")
	ui.bestiary_dialog.hide()
	for resolution in [Vector2i(1280, 800), Vector2i(1920, 1080)]:
		root.get_window().size = resolution
		await process_frame
		await process_frame
		for control in [story_button, ui.source_content, ui.choice_row]:
			if control.get_global_rect().end.x > resolution.x \
					or control.get_global_rect().end.y > resolution.y:
				return _fail("large-text story content clipped at %s: %s" % [
					resolution, control.name])
		if ui.ambient_particles.get_global_rect().size != Vector2(resolution):
			return _fail("ambient layer did not fill the desktop at %s" % resolution)
		ui.bestiary_dialog.open_bestiary(ui.opening)
		await process_frame
		if ui.bestiary_dialog.position.x < 0 or ui.bestiary_dialog.position.y < 0 \
				or ui.bestiary_dialog.position.x + ui.bestiary_dialog.size.x > resolution.x \
				or ui.bestiary_dialog.position.y + ui.bestiary_dialog.size.y > resolution.y:
			return _fail("large-text bestiary dialog clipped at %s" % resolution)
		ui.bestiary_dialog.hide()
	story_button.pressed.emit()
	await process_frame
	if not ui.experience_dialog.visible:
		return _fail("story reading settings entry did not open")
	ui.experience_dialog.find_child("ResetExperienceSettings", true, false).pressed.emit()
	await process_frame
	if ui.experience_settings.settings != ExperienceSettings.DEFAULTS \
			or ui.ambient_particles.particle_count() != 380 \
			or ui.ambient_particles.steady_camera \
			or absf(ui.ambient_particles.breath_scale() - 1.0) < 0.01 \
			or dialog_scale.get_theme_color("font_color") != dialog_original_color \
			or ui.experience_dialog.get_ok_button().get_theme_color(
				"font_color") != dialog_ok_original_color \
			or ui.bestiary_dialog.get_ok_button().get_theme_color(
				"font_color") != bestiary_ok_original_color \
			or ui.browser_import_dialog.get_ok_button().get_theme_color(
				"font_color") != import_ok_original_color \
			or ui.body_label.get_theme_font_size("font_size") != 20 \
			or ui.body_label.has_theme_font_override("font") \
			or JSON.stringify(ui.opening.state) != before:
		return _fail("reading defaults or gameplay isolation did not restore: " +
			JSON.stringify({"settings": ui.experience_settings.settings,
				"size": ui.body_label.get_theme_font_size("font_size"),
				"bodyFontOverride": ui.body_label.has_theme_font_override("font"),
				"stateSame": JSON.stringify(ui.opening.state) == before}))
	for color_key in bestiary_button_colors:
		if ui.bestiary_dialog.get_ok_button().get_theme_color(color_key) != \
				bestiary_button_colors[color_key]:
			return _fail("dialog button state color did not restore: " + color_key)
	ui.experience_dialog.hide()
	ui.experience_settings.set_option("highContrast", true)
	ui._apply_experience_settings()
	ui.bestiary_dialog.open_bestiary(ui.opening)
	await process_frame
	await process_frame
	var contrast_only_row: Button = ui.bestiary_dialog._panels.companions.get_child(0)
	if contrast_only_row.get_theme_color("font_color") != Color("fff6df") \
			or JSON.stringify(ui.opening.state) != before:
		return _fail("contrast-only preference missed a newly created bestiary row")
	ui.bestiary_dialog.hide()
	ui.queue_free()
	await process_frame
	print("NONCOMBAT_EXPERIENCE_SETTINGS_PASS slot=true story=true persistence=true scale=true font=true contrast=true effects=true steady=true dialog=true resolutions=2 gameplay_untouched=true")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
