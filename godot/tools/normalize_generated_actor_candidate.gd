extends SceneTree

# Deterministic import study for an ImageGen raw candidate. It never draws a
# new pose or changes source pixels except alpha cleanup and spatial sampling.
func _initialize() -> void:
	if not _normalize("quick_sword_dummy_idle_compression", Rect2i(447, 600, 416, 556), Vector2i(100, 141), Vector2i(112, 147)):
		quit(1)
		return
	if not _normalize("yelingyun_idle_inhale", Rect2i(425, 93, 424, 1109), Vector2i(100, 280), Vector2i(110, 28)):
		quit(1)
		return
	if not _normalize("yelingyun_sword_probe_contact", Rect2i(199, 508, 1020, 643), Vector2i(212, 167), Vector2i(57, 128)):
		quit(1)
		return
	if not _normalize("quick_sword_dummy_hurt_contact", Rect2i(289, 380, 580, 771), Vector2i(140, 199), Vector2i(43, 93)):
		quit(1)
		return
	if not _normalize("yelingyun_idle_inhale_grid", Rect2i(403, 42, 473, 1182), Vector2i(100, 280), Vector2i(110, 28), "raw_v9"):
		quit(1)
		return
	quit()


func _normalize(stem: String, bounds: Rect2i, target_size: Vector2i, target_pos: Vector2i, raw_suffix: String = "raw_v1") -> bool:
	var source := Image.load_from_file("res://art_source/actor_v8_keypose_qa/" + stem + "_" + raw_suffix + ".png")
	if source == null:
		push_error("Missing raw candidate")
		return false
	var body := source.get_region(bounds)
	for y in body.get_height():
		for x in body.get_width():
			var c := body.get_pixel(x, y)
			if c.a < 0.06:
				body.set_pixel(x, y, Color.TRANSPARENT)
	var save_dir := "res://art_source/actor_v8_keypose_qa/"
	for method in [Image.INTERPOLATE_NEAREST, Image.INTERPOLATE_LANCZOS]:
		var scaled := body.duplicate()
		scaled.resize(target_size.x, target_size.y, method)
		var canvas := Image.create_empty(320, 320, false, Image.FORMAT_RGBA8)
		canvas.fill(Color.TRANSPARENT)
		canvas.blit_rect(scaled, Rect2i(Vector2i.ZERO, target_size), target_pos)
		var suffix := "nearest" if method == Image.INTERPOLATE_NEAREST else "lanczos"
		var path := ProjectSettings.globalize_path(save_dir + stem + "_import_" + suffix + ".png")
		var error := canvas.save_png(path)
		if error != OK:
			push_error("Unable to save candidate: " + path)
			return false
		print("ACTOR_RAW_IMPORT_STUDY method=", suffix, " path=", path)
	return true
