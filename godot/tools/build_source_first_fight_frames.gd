extends SceneTree

# Turns the browser runtime's authored PNG sequences into native SpriteFrames.
# No visible pixels are synthesized; per-frame durations and feet/body metrics
# come from the same source contracts used by the browser presenter.

const ROOT := "res://content/"
const OUT := "res://assets/source_first_fight/"
const FIRST_ENCOUNTER := "enc_trial_sword_swift"
const WORLD_ID := "cangmang_sect_pc98_v1"
const FRAMERONIN_PROBE_SHEET := "res://assets/source_first_fight/frameronin_sword_probe_sheet.png"


func _initialize() -> void:
	var actions: Dictionary = _json("data/combat/action_presentations.json")
	var presentations: Dictionary = _json("data/combat/encounter_presentations.json")
	var worlds: Dictionary = _json("data/combat/visual_worlds.json")
	if actions.is_empty() or presentations.is_empty() or worlds.is_empty():
		quit(1)
		return
	var world: Dictionary = worlds.get("worlds", {}).get(WORLD_ID, {})
	var fight: Dictionary = presentations.get("presentations", {}).get(FIRST_ENCOUNTER, {})
	var hero_path := "assets/combat/protagonist/growth_matrix_agc_v6/S1_outer_novice/sword.png"
	var enemy_path := String(fight.get("actorCards", {}).get("enemy", {}).get("image", ""))
	var hero := SpriteFrames.new()
	var enemy := SpriteFrames.new()
	hero.remove_animation("default")
	enemy.remove_animation("default")
	if not _idle(hero, hero_path, world) or not _idle(enemy, enemy_path, world):
		quit(1)
		return
	var sword: Dictionary = actions.get("paths", {}).get("sword", {})
	for clip in ["attack", "guard", "reaction", "hurt", "defeat"]:
		if not _clip(hero, clip, sword.get(clip, {}), world):
			quit(1)
			return
	# The browser hand exposes sword_guard as a card ID while its visual source
	# is the path's authored guard sequence.
	if not _clip(hero, "sword_guard", sword.get("guard", {}), world):
		quit(1)
		return
	for card_id in ["sword_probe", "sword_followthrough", "sword_edge", "sword_sheath_guard"]:
		if not _clip(hero, card_id, actions.get("cardActions", {}).get(card_id, {}), world):
			quit(1)
			return
	var encounter: Dictionary = actions.get("encounters", {}).get(FIRST_ENCOUNTER, {})
	for clip in ["attack", "guard", "hurt", "defeat"]:
		if not _clip(enemy, clip, encounter.get(clip, {}), world):
			quit(1)
			return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var hero_err := ResourceSaver.save(hero, OUT + "yelingyun_s1.tres")
	var enemy_err := ResourceSaver.save(enemy, OUT + "quick_sword_dummy.tres")
	var contact := SpriteFrames.new()
	contact.remove_animation("default")
	contact.add_animation("damage")
	contact.set_animation_speed("damage", 10.0)
	contact.set_animation_loop("damage", false)
	var cue: Dictionary = fight.get("vfx", {}).get("damage", {})
	for path in cue.get("frames", []):
		var texture := _texture(String(path))
		if texture == null:
			quit(1)
			return
		contact.add_frame("damage", texture,
			float(cue.get("durationMs", 360)) / float(cue.get("frames", []).size()) / 100.0)
	var contact_err := ResourceSaver.save(contact, OUT + "wood_contact.tres")
	var trace := SpriteFrames.new()
	trace.remove_animation("default")
	trace.add_animation("contact")
	trace.set_animation_speed("contact", 10.0)
	trace.set_animation_loop("contact", false)
	var trace_cue: Dictionary = actions.get("semanticVfx", {}).get("sword_trace", {})
	var trace_paths: Array = trace_cue.get("frames", [])
	if trace_paths.is_empty():
		push_error("Missing browser sword_trace cue")
		quit(1)
		return
	for path in trace_paths:
		var texture := _texture(String(path))
		if texture == null:
			quit(1)
			return
		trace.add_frame("contact", texture,
			float(trace_cue.get("durationMs", 330)) / float(trace_paths.size()) / 100.0)
	var trace_err := ResourceSaver.save(trace, OUT + "sword_trace.tres")
	if hero_err != OK or enemy_err != OK or contact_err != OK or trace_err != OK:
		push_error("Could not save source SpriteFrames: %d/%d/%d/%d" % [hero_err, enemy_err, contact_err, trace_err])
		quit(1)
		return
	print("SOURCE_FIRST_FIGHT_SPRITEFRAMES_READY hero=", hero.get_animation_names().size(),
		" enemy=", enemy.get_animation_names().size())
	quit()


func _json(path: String) -> Dictionary:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(ROOT + path))
	if parsed is Dictionary:
		return parsed
	push_error("Missing source JSON: " + path)
	return {}


func _texture(path: String) -> Texture2D:
	var texture = load(ROOT + path)
	if texture is Texture2D:
		return texture
	push_error("Missing source art: " + path)
	return null


func _static_metric(path: String, world: Dictionary) -> Dictionary:
	for item in world.get("carrierMetrics", {}).values():
		if item is Dictionary and item.get("assetPath") == path:
			return item
	return {}


func _idle(target: SpriteFrames, path: String, world: Dictionary) -> bool:
	var texture := _texture(path)
	var metric := _static_metric(path, world)
	if texture == null or metric.is_empty():
		push_error("Static source identity/scale metric missing: " + path)
		return false
	target.add_animation("idle")
	target.set_animation_speed("idle", 10.0)
	target.set_animation_loop("idle", true)
	target.add_frame("idle", texture, 1.0)
	target.set_meta("source_idle", path)
	target.set_meta("canvas_width_idle_0", texture.get_width())
	target.set_meta("canvas_height_idle_0", texture.get_height())
	target.set_meta("body_profile", metric.get("bodyProfileId", ""))
	var static_height := float(metric.get("bodyBounds", {}).get("height", 0.0))
	var profile_id := String(metric.get("bodyProfileId", ""))
	var profiles: Dictionary = world.get("actorBodyProfiles", {})
	var hero_profile_height := float(profiles.get("yelingyun_s1_lean_human", {}).get("canonicalHeightU", 0.96))
	var actor_profile_height := float(profiles.get(profile_id, {}).get("canonicalHeightU", 0.0))
	if static_height <= 0.0 or actor_profile_height <= 0.0:
		return false
	target.set_meta("static_body_height", static_height)
	# Match the authored world-space height, including the narrow but taller puppet.
	target.set_meta("scale_idle", 0.875 * actor_profile_height / hero_profile_height / static_height)
	target.set_meta("foot_idle_0", float(metric.get("groundAnchor", {}).get("y", 1.0)))
	return true


func _clip(target: SpriteFrames, name: String, source: Dictionary, world: Dictionary) -> bool:
	var animation: Dictionary = source.get("animation", {})
	var frame_paths: Array = animation.get("frames", [])
	var durations: Array = animation.get("frameDurations", [])
	var metric: Dictionary = world.get("actionCarrierMetrics", {}).get(animation.get("frameSetId", ""), {})
	var feet: Array = metric.get("groundAnchor", {}).get("frameY", [])
	var listed: Array = metric.get("frameFiles", [])
	var reference_height := float(metric.get("referenceHeight", 0.0))
	var static_height := float(target.get_meta("static_body_height", 0.0))
	var probe_sheet: Texture2D = null
	if name == "sword_probe":
		probe_sheet = load(FRAMERONIN_PROBE_SHEET)
		if probe_sheet == null or probe_sheet.get_width() != 960 or probe_sheet.get_height() != 640:
			push_error("FrameRonin source-preserving sword_probe sheet is missing or changed")
			return false
	if not animation.get("motionApproved", false) or frame_paths.is_empty() \
			or frame_paths.size() != durations.size() or frame_paths.size() != feet.size() \
			or frame_paths.size() != listed.size() or reference_height <= 0.0 or static_height <= 0.0 \
			or metric.get("bodyProfileId") != target.get_meta("body_profile"):
		push_error("Source sequence/body metrics invalid: " + name)
		return false
	target.add_animation(name)
	target.set_animation_speed(name, 10.0)
	target.set_animation_loop(name, false)
	var total_ms := 0.0
	for index in frame_paths.size():
		var path := String(frame_paths[index])
		if listed[index].get("path") != path or float(feet[index]) <= 0.0 or float(feet[index]) > 1.0:
			push_error("Frame/feet source mismatch: " + name + " #" + str(index))
			return false
		var source_texture := _texture(path)
		if source_texture == null or source_texture.get_width() != source_texture.get_height() \
				or source_texture.get_width() not in [320, 384]:
			push_error("Unexpected source frame canvas: " + path)
			return false
		var texture: Texture2D = source_texture
		if probe_sheet != null:
			var atlas_frame := AtlasTexture.new()
			atlas_frame.atlas = probe_sheet
			atlas_frame.region = Rect2((index % 3) * 320, (index / 3) * 320, 320, 320)
			atlas_frame.filter_clip = true
			texture = atlas_frame
		var ms := float(durations[index])
		if ms <= 0.0:
			return false
		target.add_frame(name, texture, ms / 100.0)
		target.set_meta("foot_%s_%d" % [name, index], float(feet[index]))
		target.set_meta("canvas_%s_%d" % [name, index], texture.get_height())
		target.set_meta("canvas_width_%s_%d" % [name, index], texture.get_width())
		target.set_meta("canvas_height_%s_%d" % [name, index], texture.get_height())
		total_ms += ms
	# First frame establishes the authored canvas size for the whole clip.
	var clip_canvas := float(target.get_frame_texture(name, 0).get_height())
	target.set_meta("scale_" + name,
		float(target.get_meta("scale_idle")) * static_height * 320.0 / (reference_height * clip_canvas))
	target.set_meta("duration_ms_" + name, total_ms)
	target.set_meta("frame_set_" + name, animation.get("frameSetId", ""))
	if probe_sheet != null:
		target.set_meta("sheet_" + name, FRAMERONIN_PROBE_SHEET)
	target.set_meta("impact_frame_" + name, int(animation.get("impactFrameIndex", -1)))
	return true
