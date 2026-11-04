extends SceneTree

# Repeatable image export: current ImageGen pose sources -> native game pixels.
# This script never reads the earlier actor_design/ or source_first_fight/ art.
const ROOT := "res://assets/undercurrent_pixel_v1/actor_reset_v2/"
const MANIFEST := ROOT + "actor_pack_v2.json"


func _initialize() -> void:
	var document: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	if not document is Dictionary:
		_fail("Actor manifest is invalid JSON")
		return
	var canvas_size: Array = document["frameCanvas"]
	var anchor: Array = document["footAnchor"]
	var actors: Dictionary = document["actors"]
	for side in ["player", "enemy"]:
		var poses: Dictionary = actors[side]["poses"]
		for pose in poses:
			var spec: Dictionary = poses[pose]
			var source_path := ProjectSettings.globalize_path(ROOT + String(spec["source"]))
			var source := Image.load_from_file(source_path)
			if source == null or source.is_empty():
				_fail("Missing actor pose source: " + source_path)
				return
			var box := _solid_rect(source)
			if box.size.x < 32 or box.size.y < 32:
				_fail("Empty actor pose source: " + source_path)
				return
			var scale: float = float(spec["height"]) / float(box.size.y)
			var width := roundi(float(box.size.x) * scale)
			var pose_image := Image.create(box.size.x, box.size.y, false, Image.FORMAT_RGBA8)
			pose_image.blit_rect(source, box, Vector2i.ZERO)
			pose_image.resize(width, int(spec["height"]), Image.INTERPOLATE_NEAREST)
			for y in pose_image.get_height():
				for x in pose_image.get_width():
					var pixel := pose_image.get_pixel(x, y)
					if pixel.a < 0.52:
						pose_image.set_pixel(x, y, Color.TRANSPARENT)
					else:
						pose_image.set_pixel(x, y, Color(
							roundf(pixel.r * 31.0) / 31.0,
							roundf(pixel.g * 31.0) / 31.0,
							roundf(pixel.b * 31.0) / 31.0, 1.0))
			var dest_x := int(anchor[0]) - roundi((float(spec["pivotX"]) - box.position.x) * scale)
			var dest_y := int(anchor[1]) - roundi((float(spec["footY"]) - box.position.y) * scale)
			if dest_x < 0 or dest_y < 0 or dest_x + width > int(canvas_size[0]) \
					or dest_y + pose_image.get_height() > int(canvas_size[1]):
				_fail("Pose clips fixed canvas: " + side + "/" + String(pose))
				return
			var canvas := Image.create(int(canvas_size[0]), int(canvas_size[1]),
				false, Image.FORMAT_RGBA8)
			canvas.fill(Color.TRANSPARENT)
			canvas.blit_rect(pose_image, Rect2i(Vector2i.ZERO, pose_image.get_size()),
				Vector2i(dest_x, dest_y))
			var dest := ProjectSettings.globalize_path(
				ROOT + side + "_" + String(pose) + "_native.png")
			if canvas.save_png(dest) != OK:
				_fail("Cannot save " + dest)
				return
			print("ACTOR_RESET_NATIVE_EXPORT ", side, "/", pose, " ", width,
				"x", spec["height"], " @", dest_x, ",", dest_y)
	quit(0)


func _solid_rect(source: Image) -> Rect2i:
	var low := Vector2i(source.get_width(), source.get_height())
	var high := Vector2i(-1, -1)
	for y in source.get_height():
		for x in source.get_width():
			if source.get_pixel(x, y).a >= 0.52:
				low.x = mini(low.x, x)
				low.y = mini(low.y, y)
				high.x = maxi(high.x, x)
				high.y = maxi(high.y, y)
	if high.x < low.x or high.y < low.y:
		return Rect2i()
	return Rect2i(low, high - low + Vector2i.ONE)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
