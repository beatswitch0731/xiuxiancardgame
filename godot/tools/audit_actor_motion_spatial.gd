extends SceneTree

# Spatial diagnostic for the isolated actor candidate. Values are relative to
# the stage actor anchor, so floor drift and target separation are comparable.
const DEMO = preload("res://scenes/actor_image3d_demo.tscn")


func _initialize() -> void:
	call_deferred("_audit")


func _audit() -> void:
	var demo: Control = DEMO.instantiate()
	demo.use_ual_candidate = OS.get_environment("YELINGYUN_UAL_REVIEW") == "1"
	root.add_child(demo)
	await process_frame
	var floor_y: float = demo.stage.get_actor_anchor("player").global_position.y
	var enemy_position: Vector3 = demo.stage.get_actor_anchor("enemy").global_position
	demo.set_weapon_equipped(true)
	await _sample(demo, "idle", floor_y, enemy_position)
	demo.play_action("sword_attack")
	for entry in [["windup", 0.18], ["stroke", 0.42], ["follow", 0.74]]:
		var started_ms := Time.get_ticks_msec()
		while demo.action_module.playback_position() < float(entry[1]) \
				and Time.get_ticks_msec() - started_ms < 2500:
			await process_frame
		await _sample(demo, String(entry[0]), floor_y, enemy_position)
	quit()


func _sample(demo: Control, phase: String, floor_y: float,
		enemy_position: Vector3) -> void:
	await process_frame
	var skeleton: Skeleton3D = demo.actor_skeleton
	var feet := []
	for bone_name in ["foot_L", "foot_R"]:
		var index := skeleton.find_bone(bone_name)
		var position: Vector3 = (skeleton.global_transform \
			* skeleton.get_bone_global_pose(index)).origin
		feet.append(snappedf(position.y - floor_y, 0.001))
	var root_index := skeleton.find_bone("root")
	var root_position: Vector3 = skeleton.get_bone_pose_position(root_index)
	var pelvis_position: Vector3 = skeleton.get_bone_pose_position(
		skeleton.find_bone("pelvis"))
	var hand_name := "hand_R" if demo.use_ual_candidate else "hand_L"
	var hand_index := skeleton.find_bone(hand_name)
	var hand_world: Vector3 = (skeleton.global_transform \
		* skeleton.get_bone_global_pose(hand_index)).origin
	var sword_tip := hand_world
	var sword_reach := 0.0
	var attachment: BoneAttachment3D = demo.visual_equipment.get("_attachments")["weapon"]
	for node in attachment.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance: MeshInstance3D = node
		var mesh: Mesh = mesh_instance.mesh
		for surface in mesh.get_surface_count():
			var vertices: PackedVector3Array = mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
			for vertex in vertices:
				var world_vertex: Vector3 = mesh_instance.global_transform * vertex
				var distance := hand_world.distance_to(world_vertex)
				if distance > sword_reach:
					sword_reach = distance
					sword_tip = world_vertex
	var target_actor: Node3D = demo.stage.get_actor_model("enemy")
	var target_chest: Vector3 = target_actor.get_chest_hit().global_position \
		if target_actor.has_method("get_chest_hit") else enemy_position + Vector3(0, 1.2, 0)
	if demo.use_ual_candidate and OS.get_environment("YELINGYUN_SWEEP_ROLL") == "1":
		var item: Node3D = attachment.get_child(0)
		var tip_local: Vector3 = item.global_transform.affine_inverse() * sword_tip
		var original_roll := item.rotation.z
		for degrees in [-120, -90, -60, -30, 0, 30, 60, 90, 120, 180]:
			item.rotation.z = deg_to_rad(float(degrees))
			var proposed_tip: Vector3 = item.global_transform * tip_local
			print("SWORD_ROLL phase=", phase, " degrees=", degrees,
				" tip=", proposed_tip, " target_distance=",
				snappedf(proposed_tip.distance_to(target_chest), 0.001))
		item.rotation.z = original_roll
	print("MOTION_SPATIAL mode=", "ual" if demo.use_ual_candidate else "manual",
		" phase=", phase, " foot_bone_height=", feet, " root_pose=", root_position,
		" pelvis_pose=", pelvis_position,
		" hand=", hand_world,
		" hand_enemy_distance=", snappedf(hand_world.distance_to(enemy_position), 0.001),
		" grip_z=", rad_to_deg((attachment.get_node("GripPivot") as Node3D).rotation.z),
		" sword_tip=", sword_tip, " tip_local=",
			(attachment.get_child(0) as Node3D).global_transform.affine_inverse() * sword_tip,
		" target_chest=", target_chest,
		" tip_target_distance=", snappedf(sword_tip.distance_to(target_chest), 0.001))
