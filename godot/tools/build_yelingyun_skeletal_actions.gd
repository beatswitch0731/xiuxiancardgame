extends SceneTree

# Authoring source for engine-native, editable AnimationLibrary clips.
# The runtime loads the generated .tres; it does not set bone poses per frame.
const OUTPUT := "res://assets/actor_image3d_mvp/yelingyun_s1_actions.tres"
const ACTOR = preload("res://assets/actor_image3d_mvp/yelingyun_image3d_rig_candidate.glb")

var _rest_poses: Dictionary = {}


func _initialize() -> void:
	var actor: Node3D = ACTOR.instantiate()
	root.add_child(actor)
	var skeleton: Skeleton3D = actor.find_children("*", "Skeleton3D", true, false)[0]
	for bone_index in skeleton.get_bone_count():
		_rest_poses[skeleton.get_bone_name(bone_index)] = skeleton.get_bone_pose_rotation(bone_index)
	var library := AnimationLibrary.new()
	library.add_animation("idle_breath", _idle())
	library.add_animation("sword_attack", _attack())
	library.add_animation("hurt", _hurt())
	var saved := ResourceSaver.save(library, OUTPUT)
	actor.queue_free()
	if saved != OK:
		push_error("SKELETAL_ACTION_BUILD_FAIL save code=" + str(saved))
		quit(1)
		return
	print("SKELETAL_ACTION_BUILD_PASS clips=idle_breath,sword_attack,hurt contact=disabled_unverified")
	quit()


func _idle() -> Animation:
	var clip := Animation.new()
	clip.length = 2.4
	clip.loop_mode = Animation.LOOP_LINEAR
	# Small alternating chest expansion with grounded pelvis and feet. No global
	# squash/stretch; the shoulders lag the ribcage by a few frames.
	_rot(clip, "spine", [[0.0, 0, 0, 0], [0.62, 0.45, 0, 0],
		[1.24, 0.9, 0, 0], [1.82, 0.25, 0, 0], [2.4, 0, 0, 0]])
	_rot(clip, "chest", [[0.0, 0, 0, 0], [0.72, 1.15, 0, 0],
		[1.35, 1.55, 0, 0], [1.96, 0.35, 0, 0], [2.4, 0, 0, 0]])
	_rot(clip, "clavicle_L", [[0.0, 0, 0, 0], [1.38, 0, 0, 0.75],
		[2.4, 0, 0, 0]])
	_rot(clip, "clavicle_R", [[0.0, 0, 0, 0], [1.38, 0, 0, -0.75],
		[2.4, 0, 0, 0]])
	_rot(clip, "head", [[0.0, 0, 0, 0], [1.46, -0.55, 0, 0],
		[2.4, 0, 0, 0]])
	return clip


func _attack() -> Animation:
	var clip := Animation.new()
	clip.length = 0.82
	clip.loop_mode = Animation.LOOP_NONE
	# Anticipation (0.00–0.22), draw/drive (0.22–0.42), short follow-through,
	# then recover to the authored rest pose. This is a failed visual candidate:
	# feet stay planted and the sword does not reach the target. No hit marker.
	_rot(clip, "pelvis", [[0.0, 0, 0, 0], [0.18, 0, -1.6, -1.2],
		[0.42, 0, 2.4, 2.2], [0.57, 0, 2.7, 2.4], [0.82, 0, 0, 0]])
	_rot(clip, "spine", [[0.0, 0, 0, 0], [0.19, 1.4, -3.2, -2.8],
		[0.42, -1.1, 5.2, 5.2], [0.56, -1.6, 5.4, 5.8], [0.82, 0, 0, 0]])
	_rot(clip, "chest", [[0.0, 0, 0, 0], [0.20, 1.8, -4.0, -3.8],
		[0.42, -2.2, 6.5, 7.2], [0.57, -2.8, 6.8, 7.8], [0.82, 0, 0, 0]])
	_rot(clip, "upper_arm_L", [[0.0, 0, 0, 0], [0.17, 0, 0, -18],
		[0.30, 0, 0, 8], [0.42, 0, 0, 55], [0.57, 0, 0, 61],
		[0.82, 0, 0, 0]])
	_rot(clip, "forearm_L", [[0.0, 0, 0, 0], [0.17, 0, 0, -16],
		[0.31, 0, 0, -8], [0.42, 0, 0, 40], [0.58, 0, 0, 45],
		[0.82, 0, 0, 0]])
	_rot(clip, "hand_L", [[0.0, 0, 0, 0], [0.22, -7, 0, -8],
		[0.42, 0, 0, 12], [0.60, 0, 0, 17], [0.82, 0, 0, 0]])
	_rot(clip, "upper_arm_R", [[0.0, 0, 0, 0], [0.23, 0, 0, -4],
		[0.44, 0, 0, 7], [0.82, 0, 0, 0]])
	_rot(clip, "head", [[0.0, 0, 0, 0], [0.24, 0, -3, 0],
		[0.42, -1, 3, 0], [0.82, 0, 0, 0]])
	return clip


func _hurt() -> Animation:
	var clip := Animation.new()
	clip.length = 0.54
	clip.loop_mode = Animation.LOOP_NONE
	_rot(clip, "pelvis", [[0.0, 0, 0, 0], [0.12, 0, -1, -2],
		[0.27, 0, -1, -1], [0.54, 0, 0, 0]])
	_rot(clip, "spine", [[0.0, 0, 0, 0], [0.12, 7, -3, -4],
		[0.25, 3, -2, -3], [0.54, 0, 0, 0]])
	_rot(clip, "chest", [[0.0, 0, 0, 0], [0.11, 9, -4, -5],
		[0.27, 4, -2, -2], [0.54, 0, 0, 0]])
	_rot(clip, "head", [[0.0, 0, 0, 0], [0.14, -6, 2, 3],
		[0.30, -3, 0, 1], [0.54, 0, 0, 0]])
	return clip


func _rot(clip: Animation, bone_name: String, poses: Array) -> void:
	assert(_rest_poses.has(bone_name), "Missing reference bone: " + bone_name)
	var track := clip.add_track(Animation.TYPE_ROTATION_3D)
	clip.track_set_path(track, NodePath(".:" + bone_name))
	var rest_rotation: Quaternion = _rest_poses[bone_name]
	for pose in poses:
		var qx := Quaternion(Vector3.RIGHT, deg_to_rad(float(pose[1])))
		var qy := Quaternion(Vector3.UP, deg_to_rad(float(pose[2])))
		var qz := Quaternion(Vector3.FORWARD, deg_to_rad(float(pose[3])))
		# glTF pose rotations are absolute local orientations, and many imported
		# limb joints have non-identity bind rotations. Apply the authored motion
		# *on top of* that bind orientation or a keyed arm snaps into a T pose.
		clip.rotation_track_insert_key(track, float(pose[0]),
			((qz * qy * qx) * rest_rotation).normalized())
