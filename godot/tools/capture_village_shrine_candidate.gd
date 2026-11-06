extends SceneTree

const SCENE := preload("res://scenes/village_well_chamber_candidate.tscn")
const OUTPUT := "res://output/captures/godot-migration/well-chamber-left-v1/"

func _initialize() -> void:
	call_deferred("_capture")


func _capture() -> void:
	var root := Node3D.new()
	root.name = "VillageWellChamberCapture"
	get_root().add_child(root)
	var environment := WorldEnvironment.new()
	var setup := Environment.new()
	setup.background_mode = Environment.BG_COLOR
	setup.background_color = Color(0.047, 0.061, 0.071)
	setup.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	setup.ambient_light_color = Color(0.43, 0.51, 0.58)
	setup.ambient_light_energy = 0.37
	setup.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.environment = setup
	root.add_child(environment)
	var scene := SCENE.instantiate() as Node3D
	root.add_child(scene)
	var camera := Camera3D.new()
	camera.fov = 43.0
	camera.near = 0.1
	camera.far = 130.0
	root.add_child(camera)
	camera.current = true
	var base := Vector3(0, 7.1, 20.4)
	var target := Vector3(0, 2.1, -3.3)
	var screenshot_dir := ProjectSettings.globalize_path(OUTPUT)
	DirAccess.make_dir_recursive_absolute(screenshot_dir)
	for angle in [0, -20, 20]:
		var rotation := deg_to_rad(float(angle))
		camera.position = target + (base-target).rotated(Vector3.UP, rotation)
		camera.look_at(target, Vector3.UP)
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		var image := get_root().get_viewport().get_texture().get_image()
		if image == null or image.is_empty():
			push_error("WELL_CHAMBER_CAPTURE_EMPTY_IMAGE angle=%s" % angle)
			quit(2)
			return
		var filename := "front.png" if angle == 0 else ("left20.png" if angle < 0 else "right20.png")
		var path := screenshot_dir.path_join(filename)
		var saved := image.save_png(path)
		if saved != OK:
			push_error("WELL_CHAMBER_CAPTURE_SAVE_FAILED path=%s code=%s" % [path, saved])
			quit(3)
			return
		print("WELL_CHAMBER_CAPTURE image=%s size=%sx%s" % [path, image.get_width(), image.get_height()])
	print("WELL_CHAMBER_CAPTURE_PASS angles=0,-20,+20")
	quit()
