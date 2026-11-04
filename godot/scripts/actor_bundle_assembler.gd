extends RefCounted

# Candidate assembly only. A full two-actor bundle is never itself visual approval.
const REQUIRED := {
	"yelingyun_s1": ["idle", "attack", "guard", "reaction", "hurt", "defeat",
		"sword_guard", "sword_probe", "sword_followthrough", "sword_edge",
		"sword_sheath_guard"],
	"quick_sword_dummy": ["idle", "attack", "guard", "hurt", "defeat"],
}
const MINIMUM := {
	"idle": 24, "attack": 16, "guard": 12, "reaction": 12, "hurt": 12,
	"defeat": 12, "sword_guard": 16, "sword_probe": 32,
	"sword_followthrough": 24, "sword_edge": 24, "sword_sheath_guard": 16,
}
const DUMMY_MINIMUM := {"idle": 24, "attack": 32, "guard": 12, "hurt": 16, "defeat": 12}
const HERO_BLADE_CLIPS := ["attack", "sword_probe", "sword_followthrough", "sword_edge"]


func required_clips(actor_id: String) -> Array:
	return REQUIRED.get(actor_id, []).duplicate()


func assemble_pair(hero_clips: Dictionary, dummy_clips: Dictionary) -> Dictionary:
	var hero := _assemble("yelingyun_s1", hero_clips)
	if not hero.get("ok", false):
		return {"ok": false, "reason": "hero: " + String(hero.get("reason", ""))}
	var dummy := _assemble("quick_sword_dummy", dummy_clips)
	if not dummy.get("ok", false):
		return {"ok": false, "reason": "dummy: " + String(dummy.get("reason", ""))}
	var hero_world := String((hero["frames"] as SpriteFrames).get_meta("visual_world_id", ""))
	var dummy_world := String((dummy["frames"] as SpriteFrames).get_meta("visual_world_id", ""))
	if hero_world.is_empty() or hero_world != dummy_world:
		return {"ok": false, "reason": "actors have different or missing visual worlds"}
	return {"ok": true, "hero": hero["frames"], "dummy": dummy["frames"],
		"candidate_approved_for_runtime": false}


func _assemble(actor_id: String, clips: Dictionary) -> Dictionary:
	var needed: Array = REQUIRED[actor_id]
	if clips.size() != needed.size():
		return {"ok": false, "reason": "incomplete or extra action clips"}
	var art_set := ""
	var visual_world := ""
	var actor_scale := -1.0
	var out := SpriteFrames.new()
	out.remove_animation("default")
	for clip in needed:
		if not clips.has(clip) or not clips[clip] is SpriteFrames:
			return {"ok": false, "reason": "missing action " + clip}
		var source: SpriteFrames = clips[clip]
		if source.get_animation_names().size() != 1 or not source.has_animation(clip):
			return {"ok": false, "reason": "clip resource contains another action: " + clip}
		if bool(source.get_meta("candidate_approved_for_runtime", true)):
			return {"ok": false, "reason": "clip bypassed isolated candidate gate: " + clip}
		var source_set := String(source.get_meta("art_set_id", ""))
		var source_world := String(source.get_meta("visual_world_id", ""))
		if source_set.is_empty() or source_world.is_empty() \
				or int(source.get_meta("logical_pixel_grid", 0)) != 2:
			return {"ok": false, "reason": "clip identity or pixel contract missing: " + clip}
		if not art_set.is_empty() and art_set != source_set:
			return {"ok": false, "reason": "mixed art set: " + clip}
		if not visual_world.is_empty() and visual_world != source_world:
			return {"ok": false, "reason": "mixed visual world: " + clip}
		art_set = source_set
		visual_world = source_world
		var count := source.get_frame_count(clip)
		var minimum := int(DUMMY_MINIMUM[clip]) if actor_id == "quick_sword_dummy" else int(MINIMUM[clip])
		if count < minimum or int(source.get_meta("candidate_unique_frames_" + clip, 0)) < count - 4 \
				or int(source.get_meta("candidate_meaningful_transitions_" + clip, 0)) < count - 8:
			return {"ok": false, "reason": "insufficient authored motion: " + clip}
		var clip_scale := float(source.get_meta("scale_" + clip, 0.0))
		if clip_scale <= 0.0 \
				or float(source.get_meta("duration_ms_" + clip, 0.0)) <= 0.0:
			return {"ok": false, "reason": "missing playback scale or duration: " + clip}
		if actor_scale > 0.0 and absf(clip_scale - actor_scale) / actor_scale > 0.02:
			return {"ok": false, "reason": "cross-clip pixel scale drift: " + clip}
		actor_scale = clip_scale
		if actor_id == "yelingyun_s1" and clip in HERO_BLADE_CLIPS \
				and (int(source.get_meta("impact_frame_" + clip, -1)) < 0 \
				or int(source.get_meta("impact_frame_" + clip, -1)) >= count):
			return {"ok": false, "reason": "missing attack contact frame: " + clip}
		out.add_animation(clip)
		out.set_animation_speed(clip, source.get_animation_speed(clip))
		out.set_animation_loop(clip, source.get_animation_loop(clip))
		var playback_ms := 0.0
		for index in count:
			var texture := source.get_frame_texture(clip, index)
			if texture == null or texture.get_width() < 128 or texture.get_height() < 160:
				return {"ok": false, "reason": "invalid frame canvas: " + clip}
			if int(source.get_meta("canvas_width_%s_%d" % [clip, index], -1)) != texture.get_width() \
					or int(source.get_meta("canvas_height_%s_%d" % [clip, index], -1)) != texture.get_height() \
					or float(source.get_meta("foot_%s_%d" % [clip, index], -1.0)) <= 0.0 \
					or float(source.get_meta("foot_%s_%d" % [clip, index], -1.0)) > 1.0:
				return {"ok": false, "reason": "invalid canvas or foot anchor: %s[%d]" % [clip, index]}
			if actor_id == "yelingyun_s1" and clip in HERO_BLADE_CLIPS \
					and not source.get_meta("blade_tip_%s_%d" % [clip, index], null) is Vector2:
				return {"ok": false, "reason": "missing blade tip: %s[%d]" % [clip, index]}
			out.add_frame(clip, texture, source.get_frame_duration(clip, index))
			playback_ms += source.get_frame_duration(clip, index) / source.get_animation_speed(clip) * 1000.0
		if absf(playback_ms - float(source.get_meta("duration_ms_" + clip, 0.0))) > 2.0:
			return {"ok": false, "reason": "clip duration differs from frame playback: " + clip}
		for meta_name in source.get_meta_list():
			out.set_meta(meta_name, source.get_meta(meta_name))
	out.set_meta("actor_id", actor_id)
	out.set_meta("art_set_id", art_set)
	out.set_meta("visual_world_id", visual_world)
	out.set_meta("logical_pixel_grid", 2)
	out.set_meta("bundle_complete", true)
	out.set_meta("candidate_approved_for_runtime", false)
	out.set_meta("manual_visual_review_unverified", true)
	return {"ok": true, "frames": out}
