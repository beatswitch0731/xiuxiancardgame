extends SceneTree

const OUTPUT := "res://../artifacts/godot-migration/noncombat-opening/"


func _initialize() -> void:
	call_deferred("_capture")


func _capture() -> void:
	var scene: PackedScene = load(ProjectSettings.get_setting("application/run/main_scene"))
	if scene == null:
		push_error("Migrated default scene is unavailable")
		quit(1)
		return
	var slots_ui: Control = scene.instantiate()
	slots_ui.slot_root_path = "user://tests/noncombat_capture_slots_%d" % Time.get_ticks_usec()
	root.add_child(slots_ui)
	for frame in 8:
		await process_frame
	await RenderingServer.frame_post_draw
	if not _save("save-slots.png"):
		quit(1)
		return
	slots_ui.queue_free()
	await process_frame
	var opening: Control = scene.instantiate()
	opening.save_path = ""
	root.add_child(opening)
	for frame in 8:
		await process_frame
	await RenderingServer.frame_post_draw
	if not _save("name-creation.png"):
		quit(1)
		return
	(opening.name_screen.find_child("ConfirmName", true, false) as Button).pressed.emit()
	for frame in 8:
		await process_frame
	await RenderingServer.frame_post_draw
	if not _save("path-selection.png"):
		quit(1)
		return
	var path_button: Button = opening.get_node("DesktopMargin/ScreenStack/PathSelection/SourcePathGrid/Path_sword")
	path_button.pressed.emit()
	for frame in 8:
		await process_frame
	await RenderingServer.frame_post_draw
	if not _save("tutorial-source.png"):
		quit(1)
		return
	_press_choice(opening, "right")
	_press_choice(opening, "left")
	for frame in 8:
		await process_frame
	await RenderingServer.frame_post_draw
	var choices_rect: Rect2 = opening.choice_row.get_global_rect()
	var viewport_rect: Rect2 = root.get_viewport().get_visible_rect()
	if choices_rect.position.x < viewport_rect.position.x \
			or choices_rect.end.x > viewport_rect.end.x \
			or choices_rect.end.y > viewport_rect.end.y:
		push_error("Portrait prologue choices are outside the desktop viewport")
		quit(1)
		return
	if opening.opening.get_current_card().get("id") != "q_start_sword" \
			or not _save("sword-prologue-source.png"):
		quit(1)
		return
	_press_choice(opening, "right")
	for frame in 8:
		await process_frame
	await RenderingServer.frame_post_draw
	if opening.opening.state.get("currentCardId") != "encounter_card_enc_trial_sword_swift" \
			or not _save("teaching-encounter-handoff.png"):
		quit(1)
		return
	print("NONCOMBAT_WINDOWS_CAPTURE_PASS save-slots.png name-creation.png path-selection.png tutorial-source.png sword-prologue-source.png teaching-encounter-handoff.png")
	quit(0)


func _press_choice(opening: Control, direction: String) -> void:
	var button: Button = opening.get_node("DesktopMargin/ScreenStack/StoryScreen/SourceChoices/Choice_" + direction)
	button.pressed.emit()


func _save(filename: String) -> bool:
	var image := root.get_viewport().get_texture().get_image()
	if image == null or image.is_empty():
		push_error("Empty Godot viewport: " + filename)
		return false
	var directory := ProjectSettings.globalize_path(OUTPUT)
	DirAccess.make_dir_recursive_absolute(directory)
	var path := ProjectSettings.globalize_path(OUTPUT + filename)
	if image.save_png(path) != OK:
		push_error("Cannot save Godot capture: " + path)
		return false
	return true
