extends SceneTree

# Import the authored native PNGs before running this resource build.
const ROOT := "res://assets/battle/undercurrent_pixel_v1/actor_native_v1/"
const MANIFEST := ROOT + "actor_native_v1.json"
const Registry = preload("res://scripts/runtime_data_registry.gd")


func _initialize() -> void:
	var document: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	if not document is Dictionary or document.get("contractId") != "qingyun_native_actor_v1":
		_fail("Native actor manifest is missing or invalid")
		return
	var actions: Dictionary = Registry.new().read_json("data/combat/action_presentations.json")
	var canvas: Array = document["canvas"]
	var pivot: Array = document["pivot"]
	for side in ["player", "enemy"]:
		var clips: Dictionary = document["animations"][side]
		var frames := SpriteFrames.new()
		frames.remove_animation("default")
		for clip in clips:
			var pose_names: Array = clips[clip]
			var durations: Array = _source_durations(actions, side, clip)
			if durations.is_empty():
				for _pose in pose_names:
					durations.append(650 if clip == "idle" else 120)
			frames.add_animation(clip)
			frames.set_animation_speed(clip, 100.0)
			frames.set_animation_loop(clip, clip == "idle")
			for index in durations.size():
				var pose_index := mini(int(floor(float(index) * float(pose_names.size()) / float(durations.size()))), pose_names.size() - 1)
				if pose_names.size() == durations.size():
					pose_index = index
				var filename := String(pose_names[pose_index])
				var texture: Texture2D = load(ROOT + filename)
				if texture == null or texture.get_size() != Vector2(float(canvas[0]), float(canvas[1])):
					_fail("Native frame missing or wrong size: " + filename)
					return
				frames.add_frame(clip, texture, float(durations[index]) / 10.0)
				var markers: Dictionary = document["frames"].get(filename, {})
				for key in ["left_foot", "right_foot", "hand_grip", "weapon_tip"]:
					var coords: Array = markers.get(key, [])
					if coords.size() != 2:
						_fail("Native marker missing: " + filename + "/" + key)
						return
					frames.set_meta("%s_%s_%d" % [key, clip, index], Vector2(float(coords[0]), float(coords[1])))
				frames.set_meta("grounded_%s_%d" % [clip, index],
					markers.get("groundedFeet", ["left", "right"]))
				frames.set_meta("foot_%s_%d" % [clip, index], float(pivot[1]) / float(canvas[1]))
		frames.set_meta("pivot_x", float(pivot[0]))
		frames.set_meta("pivot_y", float(pivot[1]))
		frames.set_meta("scale_idle", 1.0)
		var output := ROOT + ("yelingyun_native_v1.tres" if side == "player" else "quick_sword_dummy_native_v1.tres")
		if ResourceSaver.save(frames, output) != OK:
			_fail("Cannot save native actor frames: " + output)
			return
		print("QINGYUN_NATIVE_FRAMES_EXPORT ", output, " clips=", clips.size())
	quit(0)


func _source_durations(actions: Dictionary, side: String, clip: String) -> Array:
	var action: Dictionary = {}
	if side == "player" and clip.begins_with("sword_"):
		action = actions.get("cardActions", {}).get(clip, {})
		if action.is_empty():
			action = actions.get("paths", {}).get("sword", {}).get("guard", {})
	elif side == "enemy" and clip in ["attack", "guard"]:
		action = actions.get("encounters", {}).get("enc_trial_sword_swift", {}).get(clip, {})
	return action.get("animation", {}).get("frameDurations", []).duplicate()


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
