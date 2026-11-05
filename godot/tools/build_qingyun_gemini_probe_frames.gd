extends SceneTree

# The nine PNGs are selected frames from the archived Gemini MP4. This script
# packages textures and markers; it never paints a character or a texture.
const ROOT := "res://assets/battle/undercurrent_pixel_v1/actor_gemini_video_v1/"
const SOURCE := "res://assets/battle/undercurrent_pixel_v1/actor_native_v1/yelingyun_native_v1.tres"
const OUTPUT := ROOT + "yelingyun_gemini_probe_v1.tres"
const Registry = preload("res://scripts/runtime_data_registry.gd")


func _initialize() -> void:
	var manifest: Variant = JSON.parse_string(FileAccess.get_file_as_string(
		ROOT + "gemini_sword_probe_manifest.json"))
	if not manifest is Dictionary or manifest.get("sourceVideoSha256", "") == "":
		_fail("Gemini source-video provenance is missing")
		return
	var source: SpriteFrames = load(SOURCE)
	if source == null:
		_fail("Prior actor resource is missing for untouched card clips")
		return
	var frames: SpriteFrames = source.duplicate(true)
	var actions: Dictionary = Registry.new().read_json("data/combat/action_presentations.json")
	var probe_durations: Array = actions.get("cardActions", {}).get(
		"sword_probe", {}).get("animation", {}).get("frameDurations", [])
	if probe_durations.size() != 6:
		_fail("Source sword-probe timing contract changed")
		return
	for clip in ["idle", "sword_probe"]:
		frames.remove_animation(clip)
		frames.add_animation(clip)
		frames.set_animation_speed(clip, 100.0)
		frames.set_animation_loop(clip, clip == "idle")
		var count := 3 if clip == "idle" else 6
		for index in count:
			var name := "hero_%s_%d" % ["idle" if clip == "idle" else "probe", index]
			var texture: Texture2D = load(ROOT + "pixel/" + name + ".png")
			var markers: Dictionary = manifest.get("frames", {}).get(name, {})
			if texture == null or texture.get_size() != Vector2(128, 80) or markers.is_empty():
				_fail("Gemini extracted frame missing: " + name)
				return
			var duration_ms := 650 if clip == "idle" else int(probe_durations[index])
			frames.add_frame(clip, texture, float(duration_ms) / 10.0)
			for marker in ["left_foot", "right_foot", "hand_grip", "weapon_tip"]:
				var xy: Array = markers.get(marker, [])
				if xy.size() != 2:
					_fail("Gemini marker missing: " + name + "/" + marker)
					return
				frames.set_meta("%s_%s_%d" % [marker, clip, index],
					Vector2(float(xy[0]), float(xy[1])))
			frames.set_meta("grounded_%s_%d" % [clip, index], markers.get(
				"groundedFeet", ["left", "right"]))
			frames.set_meta("foot_%s_%d" % [clip, index], 70.0 / 80.0)
	frames.set_meta("pivot_x", 40.0)
	frames.set_meta("pivot_y", 70.0)
	frames.set_meta("source_video_sha256", manifest["sourceVideoSha256"])
	frames.set_meta("probe_travel", 88.0)
	if ResourceSaver.save(frames, OUTPUT) != OK:
		_fail("Cannot save Gemini SpriteFrames")
		return
	print("QINGYUN_GEMINI_PROBE_EXPORT ", OUTPUT, " idle=3 probe=6")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
