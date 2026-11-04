extends SceneTree

# A retargeted grounded sword clip must keep at least one ankle at the same
# relative floor height as this actor's neutral pose in the identical stage.
const DEMO = preload("res://scenes/actor_image3d_demo.tscn")


func _initialize() -> void:
	call_deferred("_verify")


func _verify() -> void:
	var neutral: Array[float] = await _sample(false)
	var retargeted: Array[float] = await _sample(true)
	print("UAL_GROUNDING neutral=", neutral, " retargeted=", retargeted)
	if absf(neutral[0] - retargeted[0]) > 0.08:
		_fail("idle ankles float relative to same actor's neutral stage pose")
		return
	if absf(neutral[0] - retargeted[1]) > 0.12:
		_fail("no supporting foot remains grounded during the sword stroke")
		return
	if absf(neutral[0] - retargeted[2]) > 0.12:
		_fail("supporting foot loses floor height at authored contact")
		return
	print("UAL_GROUNDING_PASS idle_stroke_contact_support=true")
	quit()


func _sample(ual: bool) -> Array[float]:
	var demo: Control = DEMO.instantiate()
	demo.use_ual_candidate = ual
	root.add_child(demo)
	await create_timer(0.25).timeout
	var idle_ankle := _lowest_ankle(demo)
	demo.play_action("sword_attack")
	var started_ms := Time.get_ticks_msec()
	while demo.action_module.playback_position() < 0.42 \
			and Time.get_ticks_msec() - started_ms < 2000:
		await process_frame
	var stroke_ankle := _lowest_ankle(demo)
	while demo.action_module.playback_position() < 0.74 \
			and Time.get_ticks_msec() - started_ms < 2500:
		await process_frame
	var contact_ankle := _lowest_ankle(demo)
	demo.queue_free()
	await process_frame
	return [idle_ankle, stroke_ankle, contact_ankle]


func _lowest_ankle(demo: Control) -> float:
	var skeleton: Skeleton3D = demo.actor_skeleton
	var floor_y: float = demo.stage.get_actor_anchor("player").global_position.y
	var support_y := INF
	for bone_name in ["foot_L", "foot_R"]:
		var index := skeleton.find_bone(bone_name)
		var position: Vector3 = (skeleton.global_transform \
			* skeleton.get_bone_global_pose(index)).origin
		support_y = minf(support_y, position.y - floor_y)
	return support_y


func _fail(reason: String) -> void:
	push_error("UAL_GROUNDING_FAIL " + reason)
	quit(1)
