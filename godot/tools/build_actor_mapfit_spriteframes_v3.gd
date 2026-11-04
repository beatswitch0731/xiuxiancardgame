extends SceneTree

# Run after the Godot editor imports the PNGs exported by the native builder.
const ROOT := "res://assets/undercurrent_pixel_v1/actor_mapfit_v3/"
const MANIFEST := ROOT + "actor_pack_v3.json"


func _initialize() -> void:
	var document: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	if not document is Dictionary:
		_fail("Actor manifest is invalid JSON")
		return
	var actors: Dictionary = document["actors"]
	var frame_size: Array = document["frameCanvas"]
	var foot_anchor: Array = document["footAnchor"]
	var foot_fraction: float = float(foot_anchor[1]) / float(frame_size[1])
	for side in ["player", "enemy"]:
		var actor: Dictionary = actors[side]
		var frames := SpriteFrames.new()
		frames.remove_animation("default")
		var clips: Dictionary = actor["clips"]
		for clip in clips:
			var spec: Dictionary = clips[clip]
			var pose_ids: Array = spec["poses"]
			frames.add_animation(clip)
			frames.set_animation_speed(clip, float(pose_ids.size()) * 1000.0 / float(spec["durationMs"]))
			frames.set_animation_loop(clip, bool(spec.get("loop", false)))
			for pose_id in pose_ids:
				var texture_path: String = ROOT + side + "_" + String(pose_id) + "_native.png"
				var texture: Texture2D = load(texture_path)
				if texture == null or texture.get_size() != Vector2(float(frame_size[0]), float(frame_size[1])):
					_fail("Native texture missing or wrong size: " + texture_path)
					return
				frames.add_frame(clip, texture)
				frames.set_meta("foot_%s_%d" % [clip, frames.get_frame_count(clip) - 1],
					foot_fraction)
		frames.set_meta("scale_idle", 1.0)
		var resource_path: String = ROOT + String(actor["resource"])
		if ResourceSaver.save(frames, resource_path) != OK:
			_fail("Cannot save actor frames: " + resource_path)
			return
		print("ACTOR_MAPFIT_SPRITEFRAMES_EXPORT ", resource_path,
			" clips=", clips.size())
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
