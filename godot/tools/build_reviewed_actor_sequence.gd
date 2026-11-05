extends SceneTree

# Imports one reviewed clip into an isolated candidate resource. It must never
# inherit old clips: that was the V4 contact-to-next-frame style jump.
const BASE := "res://assets/battle/source_first_fight/yelingyun_s1.tres"
const REQUIRED_FRAMES := 32
const MIN_CHANGED_PIXELS := 12
const MIN_MEANINGFUL_TRANSITIONS := 24


func _initialize() -> void:
	var manifest_path := ""
	var validate_only := false
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--manifest="):
			manifest_path = arg.trim_prefix("--manifest=")
		elif arg == "--validate-only":
			validate_only = true
	if manifest_path == "":
		push_error("Pass --manifest=res://.../candidate.json")
		quit(1)
		return
	var manifest := _read_json(manifest_path)
	if manifest.is_empty():
		quit(1)
		return
	var result := _build(manifest, validate_only)
	quit(0 if result else 1)


func _read_json(path: String) -> Dictionary:
	if not path.begins_with("res://") or not FileAccess.file_exists(path):
		push_error("Missing project JSON: " + path)
		return {}
	var value = JSON.parse_string(FileAccess.get_file_as_string(path))
	if value is Dictionary:
		return value
	push_error("Invalid JSON object: " + path)
	return {}


func _build(manifest: Dictionary, validate_only: bool) -> bool:
	var clip := String(manifest.get("clip", ""))
	var sheet_path := String(manifest.get("sheet", ""))
	var index_path := String(manifest.get("index", ""))
	var output_path := String(manifest.get("output", ""))
	var canvas: Dictionary = manifest.get("canvas", {})
	var width := int(canvas.get("w", 0))
	var height := int(canvas.get("h", 0))
	var art_set_id := String(manifest.get("art_set_id", ""))
	var visual_world_id := String(manifest.get("visual_world_id", ""))
	var allowed_widths: Array = [256, 320] if clip == "idle" else [256, 320, 512]
	if String(manifest.get("actor", "")) != "yelingyun_s1" or clip not in ["idle", "sword_probe"] \
			or width not in allowed_widths or height not in [320, 384] \
			or art_set_id.is_empty() or visual_world_id != "cangmang_sect_pc98_v1" \
			or int(manifest.get("logical_pixel_grid", 0)) != 2 \
			or not sheet_path.begins_with("res://") or not index_path.begins_with("res://") \
			or not output_path.begins_with("res://assets/characters/actor_candidates/") \
			or ".." in output_path or "\\" in output_path or not output_path.ends_with(".tres") \
			or float(manifest.get("scale", 0.0)) <= 0.0:
		push_error("Invalid actor, clip, canvas, or candidate output path")
		return false
	var index := _read_json(index_path)
	var pixels := Image.load_from_file(ProjectSettings.globalize_path(sheet_path))
	if index.is_empty() or pixels == null:
		push_error("Missing FrameRonin atlas or index")
		return false
	var atlas: Texture2D = ImageTexture.create_from_image(pixels) if validate_only else load(sheet_path)
	if atlas == null:
		push_error("FrameRonin atlas has not been imported into Godot")
		return false
	var cells: Array = index.get("frames", [])
	if cells.size() != REQUIRED_FRAMES:
		push_error("Exactly 32 authored cells required; got %d" % cells.size())
		return false
	if int(index.get("frame_size", {}).get("w", 0)) != width \
			or int(index.get("frame_size", {}).get("h", 0)) != height:
		push_error("FrameRonin index canvas differs from approved canvas")
		return false
	var durations: Array = manifest.get("frame_durations_ms", [])
	var total_ms := float(manifest.get("duration_ms", 0.0))
	if total_ms <= 0.0 or (not durations.is_empty() and durations.size() != REQUIRED_FRAMES):
		push_error("Missing animation duration or 32 frame durations")
		return false
	var feet_values: Array = manifest.get("feet_y", [])
	var fixed_foot := float(manifest.get("foot_y", 0.0))
	if feet_values.size() != REQUIRED_FRAMES and not (clip == "idle" and fixed_foot > 0.0):
		push_error("Every moving frame needs an authored foot anchor")
		return false
	var tips: Array = manifest.get("blade_tips", [])
	var contact_at_ms := float(manifest.get("contact_at_ms", -1.0))
	var contact_frame := int(manifest.get("contact_frame", -1))
	if clip == "sword_probe" and (tips.size() != REQUIRED_FRAMES or contact_frame < 1 \
			or contact_frame >= REQUIRED_FRAMES or absf(contact_at_ms - 235.0) > 0.01):
		push_error("sword_probe needs 32 authored sword tips and the source 235ms contact")
		return false
	var base: SpriteFrames = load(BASE)
	if base == null:
		push_error("Missing original first-fight actor resource")
		return false
	if not base.has_animation(clip):
		push_error("Unknown source combat clip: " + clip)
		return false
	var out := SpriteFrames.new()
	if out.has_animation("default"):
		out.remove_animation("default")
	out.add_animation(clip)
	out.set_animation_speed(clip, 60.0)
	out.set_animation_loop(clip, clip == "idle")
	var unique_pixels := {}
	var meaningful_transitions := 0
	var previous_visible := PackedByteArray()
	var sum_ms := 0.0
	var first_used_height := -1
	var first_used_bottom := -1
	for i in REQUIRED_FRAMES:
		var cell: Dictionary = cells[i]
		var region := Rect2i(int(cell.get("x", -1)), int(cell.get("y", -1)),
			int(cell.get("w", 0)), int(cell.get("h", 0)))
		if region.position.x < 0 or region.position.y < 0 or region.size != Vector2i(width, height) \
				or region.end.x > pixels.get_width() or region.end.y > pixels.get_height():
			push_error("Cell outside sheet or inconsistent size: %d" % i)
			return false
		var crop := pixels.get_region(region)
		if crop.get_format() != Image.FORMAT_RGBA8:
			crop.convert(Image.FORMAT_RGBA8)
		var used := crop.get_used_rect()
		if used.size.x < 24 or used.size.y < 100:
			push_error("Empty or unexpectedly small character in frame %d" % i)
			return false
		# Transparent RGB may change while the visible drawing stays identical.
		var visible := crop.get_data()
		for pixel_offset in range(0, visible.size(), 4):
			if visible[pixel_offset + 3] < 3:
				visible[pixel_offset] = 0
				visible[pixel_offset + 1] = 0
				visible[pixel_offset + 2] = 0
				visible[pixel_offset + 3] = 0
		var hasher := HashingContext.new()
		hasher.start(HashingContext.HASH_SHA256)
		hasher.update(visible)
		unique_pixels[hasher.finish().hex_encode()] = true
		if not previous_visible.is_empty():
			var changed_pixels := 0
			for pixel_offset in range(0, visible.size(), 4):
				if visible[pixel_offset] != previous_visible[pixel_offset] \
						or visible[pixel_offset + 1] != previous_visible[pixel_offset + 1] \
						or visible[pixel_offset + 2] != previous_visible[pixel_offset + 2] \
						or visible[pixel_offset + 3] != previous_visible[pixel_offset + 3]:
					changed_pixels += 1
			if changed_pixels >= MIN_CHANGED_PIXELS:
				meaningful_transitions += 1
		previous_visible = visible
		if clip == "idle":
			if first_used_height < 0:
				first_used_height = used.size.y
				first_used_bottom = used.end.y
			if absi(used.size.y - first_used_height) > 7 or absi(used.end.y - first_used_bottom) > 2:
				push_error("Idle silhouette/foot line jumps in frame %d" % i)
				return false
		var foot := float(feet_values[i]) if feet_values.size() == REQUIRED_FRAMES else fixed_foot
		if foot <= 0.0 or foot > 1.0:
			push_error("Invalid foot anchor in frame %d" % i)
			return false
		var ms := float(durations[i]) if durations.size() == REQUIRED_FRAMES else total_ms / REQUIRED_FRAMES
		if ms <= 0.0:
			push_error("Invalid frame duration in frame %d" % i)
			return false
		if clip == "sword_probe":
			var tip: Array = tips[i]
			if tip.size() != 2 or float(tip[0]) < 0.0 or float(tip[0]) >= width \
					or float(tip[1]) < 0.0 or float(tip[1]) >= height:
				push_error("Invalid sword tip in frame %d" % i)
				return false
			out.set_meta("blade_tip_%s_%d" % [clip, i], Vector2(float(tip[0]), float(tip[1])))
		var frame := AtlasTexture.new()
		frame.atlas = atlas
		frame.region = Rect2(Vector2(region.position), Vector2(region.size))
		frame.filter_clip = true
		out.add_frame(clip, frame, ms * 60.0 / 1000.0)
		out.set_meta("foot_%s_%d" % [clip, i], foot)
		out.set_meta("canvas_width_%s_%d" % [clip, i], width)
		out.set_meta("canvas_height_%s_%d" % [clip, i], height)
		sum_ms += ms
	if unique_pixels.size() < 28:
		push_error("Only %d distinct poses in 32 frames; repeated frames are not a new animation" % unique_pixels.size())
		return false
	if meaningful_transitions < MIN_MEANINGFUL_TRANSITIONS:
		push_error("Only %d meaningful frame transitions; tiny pixel edits are not new poses" % meaningful_transitions)
		return false
	if absf(sum_ms - total_ms) > 0.5:
		push_error("Frame durations add to %.2fms; expected %.2fms" % [sum_ms, total_ms])
		return false
	if clip == "sword_probe":
		var frame_start := 0.0
		for j in contact_frame:
			frame_start += float(durations[j]) if durations.size() == REQUIRED_FRAMES else total_ms / REQUIRED_FRAMES
		if absf(frame_start - contact_at_ms) > 1000.0 / 60.0:
			push_error("Visual contact frame is %.2fms from source contact" % absf(frame_start - contact_at_ms))
			return false
		out.set_meta("impact_frame_" + clip, contact_frame)
	else:
		out.set_meta("foot_idle_0", fixed_foot if feet_values.is_empty() else float(feet_values[0]))
		out.set_meta("authored_idle_breath", true)
	out.set_meta("duration_ms_" + clip, total_ms)
	out.set_meta("scale_" + clip, float(manifest.get("scale", 1.0)))
	out.set_meta("candidate_sheet_" + clip, sheet_path)
	out.set_meta("art_set_id", art_set_id)
	out.set_meta("visual_world_id", visual_world_id)
	out.set_meta("logical_pixel_grid", 2)
	out.set_meta("candidate_unique_frames_" + clip, unique_pixels.size())
	out.set_meta("candidate_meaningful_transitions_" + clip, meaningful_transitions)
	out.set_meta("candidate_approved_for_runtime", false)
	if validate_only:
		print("REVIEWED_SEQUENCE_VALIDATED clip=", clip, " frames=32 distinct=", unique_pixels.size(),
			" transitions=", meaningful_transitions, " duration_ms=", total_ms)
		return true
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output_path.get_base_dir()))
	if ResourceSaver.save(out, output_path) != OK:
		push_error("Could not save candidate SpriteFrames")
		return false
	print("REVIEWED_SEQUENCE_CANDIDATE_READY ", output_path, " distinct=", unique_pixels.size())
	return true
