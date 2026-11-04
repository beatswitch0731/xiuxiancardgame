extends SceneTree

const Assembler = preload("res://scripts/actor_bundle_assembler.gd")


func _initialize() -> void:
	var maker = Assembler.new()
	var hero_names: Array = maker.required_clips("yelingyun_s1")
	var dummy_names: Array = maker.required_clips("quick_sword_dummy")
	if hero_names.size() != 11 or dummy_names.size() != 5:
		_fail("actor bundle clip contract changed")
		return
	var hero := _clips(hero_names, "yelingyun_v6")
	var dummy := _clips(dummy_names, "dummy_v6")
	var pair: Dictionary = maker.assemble_pair(hero, dummy)
	if not pair.get("ok", false) or (pair["hero"] as SpriteFrames).get_animation_names().size() != 11 \
			or (pair["dummy"] as SpriteFrames).get_animation_names().size() != 5 \
			or bool((pair["hero"] as SpriteFrames).get_meta("candidate_approved_for_runtime", true)):
		_fail("complete isolated two-actor candidate was rejected")
		return
	var missing := hero.duplicate()
	missing.erase("hurt")
	if maker.assemble_pair(missing, dummy).get("ok", false):
		_fail("missing hero clip was accepted")
		return
	var mixed := hero.duplicate()
	mixed["sword_probe"] = _clip("sword_probe", "other_identity")
	if maker.assemble_pair(mixed, dummy).get("ok", false):
		_fail("mixed hero art set was accepted")
		return
	var wrong_world := dummy.duplicate()
	wrong_world["idle"] = _clip("idle", "dummy_v6")
	(wrong_world["idle"] as SpriteFrames).set_meta("visual_world_id", "unrelated_world")
	if maker.assemble_pair(hero, wrong_world).get("ok", false):
		_fail("mixed visual worlds were accepted")
		return
	var source := hero.duplicate()
	(source["idle"] as SpriteFrames).set_meta("candidate_approved_for_runtime", true)
	if maker.assemble_pair(source, dummy).get("ok", false):
		_fail("preapproved or source clip bypassed candidate gate")
		return
	var bad_foot := hero.duplicate()
	bad_foot["idle"] = _clip("idle", "yelingyun_v6")
	(bad_foot["idle"] as SpriteFrames).set_meta("foot_idle_3", -1.0)
	if maker.assemble_pair(bad_foot, dummy).get("ok", false):
		_fail("missing frame foot anchor was accepted")
		return
	var bad_blade := hero.duplicate()
	bad_blade["sword_probe"] = _clip("sword_probe", "yelingyun_v6")
	(bad_blade["sword_probe"] as SpriteFrames).remove_meta("blade_tip_sword_probe_14")
	if maker.assemble_pair(bad_blade, dummy).get("ok", false):
		_fail("missing sword contact geometry was accepted")
		return
	var bad_scale := hero.duplicate()
	bad_scale["hurt"] = _clip("hurt", "yelingyun_v6")
	(bad_scale["hurt"] as SpriteFrames).set_meta("scale_hurt", 0.84)
	if maker.assemble_pair(bad_scale, dummy).get("ok", false):
		_fail("cross-action pixel scale drift was accepted")
		return
	var bad_duration := dummy.duplicate()
	bad_duration["attack"] = _clip("attack", "dummy_v6")
	(bad_duration["attack"] as SpriteFrames).set_meta("duration_ms_attack", 200.0)
	if maker.assemble_pair(hero, bad_duration).get("ok", false):
		_fail("frame playback and declared duration drift was accepted")
		return
	print("ACTOR_BUNDLE_ASSEMBLER_PASS structure=complete missing=rejected mixed=rejected world=rejected foot=rejected blade=rejected scale=rejected duration=rejected visual_review=unverified")
	quit(0)


func _clips(names: Array, art_set: String) -> Dictionary:
	var result := {}
	for name in names:
		result[name] = _clip(String(name), art_set)
	return result


func _clip(name: String, art_set: String) -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	frames.add_animation(name)
	frames.set_animation_speed(name, 60.0)
	frames.set_animation_loop(name, name == "idle")
	for index in 32:
		var picture := Image.create(128, 160, false, Image.FORMAT_RGBA8)
		picture.fill(Color.from_hsv(float(index) / 32.0, 0.4, 0.8))
		frames.add_frame(name, ImageTexture.create_from_image(picture))
		frames.set_meta("canvas_width_%s_%d" % [name, index], 128)
		frames.set_meta("canvas_height_%s_%d" % [name, index], 160)
		frames.set_meta("foot_%s_%d" % [name, index], 0.96)
		if name in ["attack", "sword_probe", "sword_followthrough", "sword_edge"]:
			frames.set_meta("blade_tip_%s_%d" % [name, index], Vector2(92, 80))
	frames.set_meta("scale_" + name, 1.0)
	frames.set_meta("duration_ms_" + name, 32.0 / 60.0 * 1000.0)
	if name in ["attack", "sword_probe", "sword_followthrough", "sword_edge"]:
		frames.set_meta("impact_frame_" + name, 14)
	frames.set_meta("art_set_id", art_set)
	frames.set_meta("visual_world_id", "cangmang_sect_pc98_v1")
	frames.set_meta("logical_pixel_grid", 2)
	frames.set_meta("candidate_unique_frames_" + name, 32)
	frames.set_meta("candidate_meaningful_transitions_" + name, 31)
	frames.set_meta("candidate_approved_for_runtime", false)
	return frames


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
