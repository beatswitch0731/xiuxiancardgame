extends SceneTree

const Domain = preload("res://scripts/noncombat_domain.gd")
const Registry = preload("res://scripts/runtime_data_registry.gd")
const Session = preload("res://scripts/noncombat_run_session.gd")
const OpeningScene = preload("res://scenes/noncombat_opening.tscn")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var folder := "user://tests"
	var directory := DirAccess.open(folder)
	if directory == null:
		push_error("NPC cross capture has no saved test directory")
		quit(1)
		return
	var selected := ""
	var latest := 0
	for filename in directory.get_files():
		if filename.begins_with("npc_cross_natural_") and filename.ends_with("_v2.json"):
			var path := folder.path_join(filename)
			var saved: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
			if not saved is Dictionary or saved.get("state", {}).get("phase") != "NPC_CROSS_PENDING":
				continue
			var modified := FileAccess.get_modified_time(path)
			if modified > latest:
				latest = modified
				selected = path.trim_suffix("_v2.json") + ".json"
	if selected.is_empty():
		push_error("NPC cross capture has no pending save")
		quit(1)
		return
	var game = Domain.new(Registry.new(), Session.new(selected, "slot_2"), "slot_2")
	game._ripple_flow.roll_override = 0.999
	game._hint_flow.roll_override = 0.0
	game._market_flow.roll_override = 0.0
	if not game.restore() or game.state.get("phase") != "NPC_CROSS_PENDING":
		push_error("NPC cross capture cannot restore pending card: " + game._store.last_error)
		quit(1)
		return
	var ui: Control = OpeningScene.instantiate()
	ui.save_path = ""
	root.add_child(ui)
	await process_frame
	ui.opening = game
	ui.slot_screen.visible = false
	ui.name_screen.visible = false
	ui.path_screen.visible = false
	ui.story_screen.visible = true
	ui._set_scene_surface(true)
	ui._render()
	var output := ProjectSettings.globalize_path("res://output/godot/npc_cross")
	DirAccess.make_dir_recursive_absolute(output)
	for resolution in [Vector2i(1280, 800), Vector2i(1920, 1080)]:
		root.get_window().size = resolution
		for frame in 5:
			await process_frame
		print("NPC_CROSS_LAYOUT size=%s story=%s content=%s portraits=%s text=%s body=%s choices=%s" % [
			resolution, ui.story_screen.get_global_rect(), ui.source_content.get_global_rect(),
			ui.npc_cross_portraits.get_global_rect(), ui.source_text_panel.get_global_rect(),
			ui.body_label.get_global_rect(), ui.choice_row.get_global_rect()])
		var filename := "%s/npc_cross_%d.png" % [output, resolution.x]
		if root.get_window().get_texture().get_image().save_png(filename) != OK:
			push_error("NPC cross screenshot failed: " + filename)
			quit(1)
			return
	ui.queue_free()
	await process_frame
	print("NPC_CROSS_CAPTURE_PASS images=2")
	quit(0)
