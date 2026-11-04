extends SceneTree

const DEMO = preload("res://scenes/actor_image3d_demo.tscn")


func _initialize() -> void:
	call_deferred("_verify")


func _verify() -> void:
	var demo: Control = DEMO.instantiate()
	root.add_child(demo)
	await process_frame
	print("IMAGE3D_SKELETON_PATH ", demo.actor_root.get_path_to(demo.actor_skeleton))
	var module: Node = demo.find_child("SkeletalActionModule", true, false)
	if module == null:
		_fail("no reusable skeletal action module in live Godot scene")
		return
	var player: AnimationPlayer = module.find_child("AnimationPlayer", true, false)
	var tree: AnimationTree = module.find_child("AnimationTree", true, false)
	if player == null or tree == null or not tree.active:
		_fail("AnimationPlayer/AnimationTree is absent or inactive")
		return
	for clip in ["idle_breath", "sword_attack", "hurt"]:
		if not player.has_animation(clip):
			_fail("missing skeletal animation " + clip)
			return
	if player.get_animation("sword_attack").has_marker("contact"):
		_fail("unverified attack must not advertise a contact marker")
		return
	var chest_index: int = demo.actor_skeleton.find_bone("chest")
	var arm_index: int = demo.actor_skeleton.find_bone("upper_arm_L")
	var rest_arm: Quaternion = demo.actor_skeleton.get_bone_rest(arm_index).basis.get_rotation_quaternion()
	var chest_at_start: Quaternion = demo.actor_skeleton.get_bone_pose_rotation(chest_index)
	await create_timer(0.9).timeout
	var chest_at_inhale: Quaternion = demo.actor_skeleton.get_bone_pose_rotation(chest_index)
	if chest_at_start.angle_to(chest_at_inhale) < deg_to_rad(0.3):
		_fail("idle clip does not move the bound chest bone")
		return
	if rest_arm.angle_to(demo.actor_skeleton.get_bone_pose_rotation(arm_index)) > deg_to_rad(5):
		_fail("idle clip breaks the left arm bind pose")
		return
	var weapon_equipped: bool = demo.set_weapon_equipped(true)
	if not weapon_equipped:
		_fail("weapon could not be attached before playback")
		return
	var counts := {"contact": 0, "finish": 0}
	module.action_contact.connect(func(_name: String) -> void: counts["contact"] += 1)
	module.action_finished.connect(func(_name: String) -> void: counts["finish"] += 1)
	for index in 2:
		var hand_index: int = demo.actor_skeleton.find_bone("hand_L")
		var hand_at_rest: Vector3 = demo.actor_skeleton.get_bone_global_pose(hand_index).origin
		if not demo.has_method("play_action") or not demo.play_action("sword_attack"):
			_fail("attack request was rejected")
			return
		var started_ms := Time.get_ticks_msec()
		while module.playback_position() < 0.45 and Time.get_ticks_msec() - started_ms < 1500:
			await process_frame
		var hand_at_stroke: Vector3 = demo.actor_skeleton.get_bone_global_pose(hand_index).origin
		print("IMAGE3D_HAND_DELTA ", hand_at_rest.distance_to(hand_at_stroke), " rest=", hand_at_rest, " stroke=", hand_at_stroke, " time=", module.playback_position())
		if hand_at_rest.distance_to(hand_at_stroke) < 0.025:
			_fail("attack does not move the sword hand")
			return
		while counts["finish"] < index + 1 and Time.get_ticks_msec() - started_ms < 2000:
			await process_frame
		if counts["finish"] != index + 1 or counts["contact"] != 0:
			_fail("attack lifecycle or false contact: finishes=" \
				+ str(counts["finish"]) + " contacts=" + str(counts["contact"]) \
				+ " current=" + module.current_action() \
				+ " time=" + str(module.playback_position()))
			return
	var idle_wait_ms := Time.get_ticks_msec()
	while not module.is_idle() and Time.get_ticks_msec() - idle_wait_ms < 300:
		await process_frame
	if not module.is_idle():
		_fail("action module did not return to idle")
		return
	print("IMAGE3D_ACTION_MODULE_PASS clips=3 attacks=2 false_contacts=0 idle_return=true")
	quit()


func _fail(reason: String) -> void:
	push_error("IMAGE3D_ACTION_MODULE_FAIL " + reason)
	quit(1)
