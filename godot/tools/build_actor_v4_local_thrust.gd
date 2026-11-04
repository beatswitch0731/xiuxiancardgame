extends SceneTree

const CONTRACT := "res://art_direction/candidates/actor_reset_v4/local_thrust_clip.json"
const OUTPUT := "res://assets/undercurrent_pixel_v1/actor_video_v4_study/hero_local_thrust.tres"


func _initialize() -> void:
	var spec: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CONTRACT))
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(spec["sourceManifest"]))
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	frames.set_meta("pivot_x", float(spec["pivot"][0]))
	frames.set_meta("pivot_y", float(spec["pivot"][1]))
	frames.set_meta("source_video_sha256", source["sourceVideoSha256"])
	frames.set_meta("study_only", true)
	for clip in spec["clips"]:
		var info: Dictionary = spec["clips"][clip]
		frames.add_animation(clip)
		frames.set_animation_speed(clip, float(spec["fps"]))
		frames.set_animation_loop(clip, info["loop"])
		for index in info["sourceFrames"].size():
			if index == int(info.get("extensionFrameIndex0Based", -1)) and not is_equal_approx(index * 1000.0 / float(spec["fps"]), float(info["extensionAtMs"])):
				push_error("Extension timing does not match frame durations")
				quit(1)
				return
			var path: String = spec["textureRoot"] + "frame_%04d.png" % int(info["sourceFrames"][index])
			frames.add_frame(clip, load(path))
			for marker in [["left_foot", "leftFoot"], ["right_foot", "rightFoot"]]:
				var xy: Array = spec[marker[1]]
				frames.set_meta("%s_%s_%d" % [marker[0], clip, index], Vector2(xy[0], xy[1]))
			frames.set_meta("grounded_%s_%d" % [clip, index], ["left", "right"])
		var total: float = info["sourceFrames"].size() * 1000.0 / float(spec["fps"])
		if info.has("durationMs") and not is_equal_approx(total, float(info["durationMs"])):
			push_error("Clip duration does not match contract: " + str(total))
			quit(1)
			return
	if ResourceSaver.save(frames, OUTPUT) != OK:
		push_error("Could not save local motion resource")
		quit(1)
		return
	print("ACTOR_V4_LOCAL_THRUST_EXPORTED source_frames=9 output_frames=18 fps=24 no_root_motion=true")
	quit(0)
