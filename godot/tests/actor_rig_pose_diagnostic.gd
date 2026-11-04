extends SceneTree

const ACTOR = preload("res://assets/actor_image3d_mvp/yelingyun_image3d_rig_candidate.glb")
const Module = preload("res://scripts/actor_skeletal_action_module.gd")

func _initialize() -> void:
	call_deferred("_inspect")

func _inspect() -> void:
	var actor: Node3D = ACTOR.instantiate()
	root.add_child(actor)
	var skeleton: Skeleton3D = actor.find_children("*", "Skeleton3D", true, false)[0]
	_dump("raw", skeleton)
	var module: Node = Module.new()
	actor.add_child(module)
	module.bind_skeleton(skeleton)
	await process_frame
	_dump("idle", skeleton)
	module.play_action("sword_attack")
	await create_timer(0.43).timeout
	_dump("attack", skeleton)
	quit()

func _dump(label: String, skeleton: Skeleton3D) -> void:
	for name in ["pelvis", "spine", "chest", "clavicle_L", "upper_arm_L", "forearm_L", "hand_L", "clavicle_R"]:
		var i: int = skeleton.find_bone(name)
		print(label, " ", name, " rest=", skeleton.get_bone_rest(i).basis.get_rotation_quaternion(), " pose=", skeleton.get_bone_pose_rotation(i), " global=", skeleton.get_bone_global_pose(i).origin)
