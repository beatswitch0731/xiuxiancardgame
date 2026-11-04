extends SceneTree

const OpeningScene = preload("res://scenes/noncombat_opening.tscn")
const Domain = preload("res://scripts/noncombat_domain.gd")
const Registry = preload("res://scripts/runtime_data_registry.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var view: Control = OpeningScene.instantiate()
	view.save_path = ""
	root.add_child(view)
	await process_frame
	var game = Domain.new(Registry.new(), null, "slot_2")
	if not game.start("sword"):
		quit(1)
		return
	view.opening = game
	view.story_screen.visible = true
	view._render()
	view._open_world_map()
	for resolution in [Vector2i(1280, 800), Vector2i(1920, 1080)]:
		root.get_window().size = resolution
		await process_frame
		await process_frame
		var path := "user://tests/world_map_%dx%d.png" % [resolution.x, resolution.y]
		var error := root.get_window().get_texture().get_image().save_png(path)
		print("WORLD_MAP_CAPTURE path=", ProjectSettings.globalize_path(path),
			" error=", error)
		if error != OK:
			quit(1)
			return
	quit(0)
