extends SceneTree

# Technical feasibility only. This candidate is rejected by visual QA.
const DEMO = preload("res://scenes/actor_image3d_demo.tscn")

func _initialize() -> void:
	call_deferred("_verify")

func _verify() -> void:
	var demo: Control = DEMO.instantiate()
	demo.use_ual_candidate = true
	root.add_child(demo)
	await process_frame
	if demo.action_module == null or not demo.set_weapon_equipped(true):
		_fail("retarget candidate cannot mount with sword")
		return
	var module: Node = demo.action_module
	var player: AnimationPlayer = module.find_child("AnimationPlayer", true, false)
	if not player.get_animation("sword_attack").has_marker("contact"):
		_fail("reviewed sword stroke has no authored contact time")
		return
	var attachment: BoneAttachment3D = demo.visual_equipment.get("_attachments")["weapon"]
	if attachment.bone_name != "hand_R":
		_fail("source sword action and weapon hand disagree")
		return
	var contacts := {"count": 0, "distance": INF}
	module.action_contact.connect(func(_name: String) -> void:
		contacts["count"] += 1
		var tip: Marker3D = demo.visual_equipment.get_weapon_tip_marker()
		var chest: Vector3 = demo.stage.get_actor_model("enemy").get_chest_hit().global_position
		contacts["distance"] = tip.global_position.distance_to(chest) if tip != null else INF)
	var root_index: int = demo.actor_skeleton.find_bone("root")
	var start_position: Vector3 = demo.actor_skeleton.get_bone_pose_position(root_index)
	var ready_ms := Time.get_ticks_msec()
	while not module.is_idle() and Time.get_ticks_msec() - ready_ms < 1000:
		await process_frame
	if not demo.play_action("sword_attack"):
		_fail("retargeted attack did not start")
		return
	var max_motion := 0.0
	var near_end_motion := INF
	var near_end_time: float = player.get_animation("sword_attack").length - 0.08
	var started_ms := Time.get_ticks_msec()
	while not module.is_idle() and Time.get_ticks_msec() - started_ms < 3000:
		await process_frame
		var current_motion: float = start_position.distance_to(
			demo.actor_skeleton.get_bone_pose_position(root_index))
		max_motion = maxf(max_motion, current_motion)
		if module.playback_position() >= near_end_time and not module.is_idle():
			near_end_motion = minf(near_end_motion, current_motion)
	if not module.is_idle() or max_motion < 0.7 or contacts["count"] != 1 \
			or contacts["distance"] > 0.22 or near_end_motion > 0.15:
		_fail("expected one spatial sword contact and rooted return; motion=" + str(max_motion)
			+ " near_end_motion=" + str(near_end_motion)
			+ " contacts=" + str(contacts["count"])
			+ " tip_to_chest=" + str(contacts["distance"]))
		return
	if not demo.set_weapon_equipped(false) or not demo.play_action("sword_attack"):
		_fail("unequipped attack could not be checked")
		return
	var unarmed_ms := Time.get_ticks_msec()
	while not module.is_idle() and Time.get_ticks_msec() - unarmed_ms < 3000:
		await process_frame
	if not module.is_idle() or contacts["count"] != 1:
		_fail("unequipped sword action emitted contact")
		return
	demo.stage.get_actor_anchor("enemy").position.x = 3.2
	if not demo.set_weapon_equipped(true) or not demo.play_action("sword_attack"):
		_fail("distant target attack could not be checked")
		return
	var distant_ms := Time.get_ticks_msec()
	while not module.is_idle() and Time.get_ticks_msec() - distant_ms < 3000:
		await process_frame
	if not module.is_idle() or contacts["count"] != 1:
		_fail("distant target emitted a spatial contact")
		return
	print("UAL_CANDIDATE_TECH_PASS max_root_motion=", max_motion,
		" near_end_root_motion=", near_end_motion, " contacts=1",
		" unequipped_contacts=0 distant_contacts=0 tip_to_chest=", contacts["distance"],
		" art_status=REVIEW")
	quit()

func _fail(reason: String) -> void:
	push_error("UAL_CANDIDATE_TECH_FAIL " + reason)
	quit(1)
