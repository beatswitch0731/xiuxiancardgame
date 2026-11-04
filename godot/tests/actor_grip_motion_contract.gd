extends SceneTree

const DEMO = preload("res://scenes/actor_image3d_demo.tscn")


func _initialize() -> void:
	call_deferred("_verify")


func _verify() -> void:
	var demo: Control = DEMO.instantiate()
	demo.use_ual_candidate = true
	root.add_child(demo)
	await process_frame
	var socket: BoneAttachment3D = demo.actor_skeleton.get_node_or_null(
		"Equipment_weapon") as BoneAttachment3D
	if socket == null:
		_fail("no stable weapon socket before equipping")
		return
	var pivot: Node3D = socket.get_node_or_null("GripPivot") as Node3D
	if pivot == null:
		_fail("weapon socket has no animatable grip pivot")
		return
	if not demo.set_weapon_equipped(true):
		_fail("could not equip weapon")
		return
	var ready_ms := Time.get_ticks_msec()
	while not demo.action_module.is_idle() and Time.get_ticks_msec() - ready_ms < 1000:
		await process_frame
	if not demo.play_action("sword_attack"):
		_fail("could not play sword attack")
		return
	var started_ms := Time.get_ticks_msec()
	while demo.action_module.playback_position() < 0.74 \
			and Time.get_ticks_msec() - started_ms < 2500:
		await process_frame
	if absf(rad_to_deg(pivot.rotation.z)) < 90.0:
		_fail("attack did not turn the grip with the sword stroke")
		return
	while not demo.action_module.is_idle() \
			and Time.get_ticks_msec() - started_ms < 3500:
		await process_frame
	await process_frame
	if not demo.action_module.is_idle() or absf(rad_to_deg(pivot.rotation.z)) > 5.0:
		_fail("grip did not recover to idle")
		return
	if not demo.set_weapon_equipped(false) or not is_instance_valid(socket):
		_fail("unequipping destroyed the animatable socket")
		return
	print("ACTOR_GRIP_MOTION_PASS socket_persistent=true attack_sweep=true idle_recovery=true")
	quit()


func _fail(reason: String) -> void:
	push_error("ACTOR_GRIP_MOTION_FAIL " + reason)
	quit(1)
