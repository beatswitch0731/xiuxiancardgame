extends SceneTree

const Registry = preload("res://scripts/runtime_data_registry.gd")
const Domain = preload("res://scripts/noncombat_domain.gd")
const RunSession = preload("res://scripts/noncombat_run_session.gd")
const FIXTURE := "res://tests/fixtures/pill_decision54_death_probe_v2.json"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var path := "user://tests/capture_rebirth_tree_%d.json" % Time.get_ticks_usec()
	var store = RunSession.new(path, "slot_3")
	var source := FileAccess.open(store.v2_path, FileAccess.WRITE)
	if source == null:
		return _fail("death fixture cannot be staged")
	source.store_string(FileAccess.get_file_as_string(FIXTURE))
	source.close()
	var game = Domain.new(Registry.new(), RunSession.new(path, "slot_3"), "slot_3")
	game._normal_roll_override = 0.55
	game._market_flow.roll_override = 0.0
	game._destiny_wheel_flow.roll_override = 0.0
	game._ripple_flow.roll_override = 0.999
	game._hint_flow.roll_override = 0.0
	if not game.restore() or not game.resume_flow() \
			or game.get_current_card().get("id") != "q_love" \
			or not game.choose("right", game.issue_choice_token()) \
			or not game.choose("left", game.issue_choice_token()) \
			or game.state.get("phase") != "REBIRTH_PENDING":
		return _fail("real rebirth state unavailable")
	var ui: Control = load("res://scenes/noncombat_opening.tscn").instantiate()
	ui.save_path = ""
	root.add_child(ui)
	await process_frame
	ui.opening = game
	ui._render()
	ui.rebirth_tree_button.pressed.emit()
	var output := ProjectSettings.globalize_path("res://").trim_suffix(
		"/").get_base_dir().path_join("output/godot/rebirth_tree_v5")
	if DirAccess.make_dir_recursive_absolute(output) != OK:
		return _fail("capture output directory unavailable")
	for resolution in [Vector2i(1280, 800), Vector2i(1920, 1080)]:
		root.get_window().size = resolution
		ui.rebirth_tree_dialog.popup_centered(Vector2i(700, 570))
		await process_frame
		await process_frame
		var file := output.path_join("rebirth_tree_%dx%d.png" % [
			resolution.x, resolution.y])
		if root.get_window().get_texture().get_image().save_png(file) != OK:
			return _fail("capture failed: " + file)
		print("REBIRTH_TREE_CAPTURE ", file)
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
