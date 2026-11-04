extends SceneTree

const Registry = preload("res://scripts/runtime_data_registry.gd")


func _initialize() -> void:
	var file := FileAccess.open("res://content/source_manifest.json", FileAccess.READ)
	if file == null:
		_fail("source manifest unavailable")
		return
	var manifest = JSON.parse_string(file.get_as_text())
	if not manifest is Dictionary or not manifest.get("art") is Array:
		_fail("source manifest art list invalid")
		return
	var count := 0
	for entry in manifest["art"]:
		if not entry is Dictionary or not entry.get("path") is String:
			_fail("art entry invalid")
			return
		var source_path: String = entry["path"]
		if source_path.begins_with("assets/combat/"):
			continue
		var resource_path := "res://content/" + source_path
		# Ignore the cache so checking the full authored set has bounded memory.
		var resource = ResourceLoader.load(resource_path, "Texture2D", ResourceLoader.CACHE_MODE_IGNORE)
		if not resource is Texture2D or resource.get_width() <= 0 or resource.get_height() <= 0:
			_fail("Godot could not load authored image: " + source_path)
			return
		resource = null
		count += 1
	var aliases: Array = manifest.get("runtimeAliases", [])
	var registry = Registry.new()
	var alias_sources := {}
	for entry in aliases:
		if not entry is Dictionary or not entry.get("sourcePath") is String:
			_fail("image alias entry invalid")
			return
		var source_path: String = entry["sourcePath"]
		alias_sources[source_path] = true
		var resolved = registry.texture_for(source_path)
		if not resolved is Texture2D or resolved.get_width() <= 0:
			_fail("source image alias could not be loaded: " + source_path)
			return
		if not source_path.begins_with("assets/combat/"):
			count += 1
	if not alias_sources.has("assets/backgrounds/bg_inkwash_masterpiece.png") \
			or not alias_sources.has("assets/backgrounds/bg_start.png") or count != 515:
		_fail("non-combat art inventory unexpectedly small: " + str(count))
		return
	if not registry.has_method("sprite_frames_for"):
		_fail("animated browser media has no Godot SpriteFrames resolver")
		return
	var animated_count := 0
	var total_frames := 0
	for entry in manifest.get("animatedMedia", []):
		if not entry is Dictionary or not entry.get("sourcePath") is String:
			_fail("animated media entry invalid")
			return
		var sprite_frames = registry.sprite_frames_for(entry["sourcePath"])
		if not sprite_frames is SpriteFrames or not sprite_frames.has_animation("play"):
			_fail("Godot SpriteFrames unavailable: " + entry["sourcePath"])
			return
		if sprite_frames.get_frame_count("play") != entry["frames"].size():
			_fail("Godot SpriteFrames frame count differs from authored WebP")
			return
		for index in sprite_frames.get_frame_count("play"):
			if absf(sprite_frames.get_frame_duration("play", index) - float(entry["frames"][index]["durationMs"]) / 1000.0) > 0.001:
				_fail("Godot SpriteFrames timing differs from authored WebP")
				return
		total_frames += sprite_frames.get_frame_count("play")
		animated_count += 1
	if animated_count != 3 or total_frames != 68:
		_fail("animated media inventory differs from authored source")
		return
	var audio_count := 0
	for entry in manifest.get("audio", []):
		if not entry is Dictionary or not entry.get("path") is String:
			_fail("audio entry invalid")
			return
		var source_path: String = entry["path"]
		var stream = ResourceLoader.load("res://content/" + source_path,
			"AudioStream", ResourceLoader.CACHE_MODE_IGNORE)
		if not stream is AudioStream:
			_fail("Godot could not load authored audio: " + source_path)
			return
		stream = null
		audio_count += 1
	if audio_count != 32:
		_fail("authored audio inventory unexpectedly small: " + str(audio_count))
		return
	print("NONCOMBAT_ASSET_IMPORT_PASS images=" + str(count + animated_count) +
		" frames=" + str(total_frames) + " audio=" + str(audio_count))
	quit(0)


func _fail(reason: String) -> void:
	push_error(reason)
	quit(1)
