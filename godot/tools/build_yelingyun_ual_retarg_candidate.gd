extends SceneTree

# Isolated retarget experiment. Keep the CC0 source pack and resulting clip
# separate from approved battle assets until the live deformation review passes.
const SOURCE = preload(
	"res://assets/third_party/quaternius_ual_standard/AnimationLibrary_Godot_Standard.glb")
const TARGET = preload("res://assets/actor_image3d_mvp/yelingyun_image3d_rig_candidate.glb")
const OUTPUT := "res://assets/actor_image3d_mvp/yelingyun_ual_retarg_candidate.tres"
const BONE_MAP := {
	"pelvis": ["DEF-hips"],
	"spine": ["DEF-spine.001"],
	"chest": ["DEF-spine.003"],
	"neck": ["DEF-neck"], "head": ["DEF-head"],
	"clavicle_L": ["DEF-shoulder.L"],
	"upper_arm_L": ["DEF-upper_arm.L"],
	"forearm_L": ["DEF-forearm.L"], "hand_L": ["DEF-hand.L"],
	"clavicle_R": ["DEF-shoulder.R"],
	"upper_arm_R": ["DEF-upper_arm.R"],
	"forearm_R": ["DEF-forearm.R"], "hand_R": ["DEF-hand.R"],
	"thigh_L": ["DEF-thigh.L"], "shin_L": ["DEF-shin.L"],
	"foot_L": ["DEF-foot.L"],
	"thigh_R": ["DEF-thigh.R"], "shin_R": ["DEF-shin.R"],
	"foot_R": ["DEF-foot.R"],
}

var _source_skeleton: Skeleton3D
var _target_skeleton: Skeleton3D


func _initialize() -> void:
	var source_scene: Node3D = SOURCE.instantiate()
	var target_scene: Node3D = TARGET.instantiate()
	root.add_child(source_scene)
	root.add_child(target_scene)
	_source_skeleton = source_scene.find_children("*", "Skeleton3D", true, false)[0]
	_target_skeleton = target_scene.find_children("*", "Skeleton3D", true, false)[0]
	var player: AnimationPlayer = source_scene.find_children("*", "AnimationPlayer", true, false)[0]
	var library := AnimationLibrary.new()
	for pair in [["Idle", "idle_breath"],
			["Sword_Attack_RM", "sword_attack"], ["Hit_Chest", "hurt"]]:
		library.add_animation(String(pair[1]), _retarget(player.get_animation(String(pair[0])), String(pair[1])))
	var result := ResourceSaver.save(library, OUTPUT)
	print("UAL_RETARGET ", "PASS" if result == OK else "FAIL", " clips=3 output=", OUTPUT)
	quit(0 if result == OK else 1)


func _retarget(source: Animation, target_name: String) -> Animation:
	var clip := Animation.new()
	clip.length = source.length
	clip.loop_mode = Animation.LOOP_LINEAR if target_name == "idle_breath" else Animation.LOOP_NONE
	var tracks := {}
	for index in source.get_track_count():
		var path := source.track_get_path(index)
		if path.get_subname_count() == 0:
			continue
		tracks[String(path.get_subname(0)) + ":" + str(source.track_get_type(index))] = index
	var frames := ceili(source.length * 30.0)
	for target_bone in BONE_MAP:
		var rotation_track := clip.add_track(Animation.TYPE_ROTATION_3D)
		clip.track_set_path(rotation_track, NodePath(".:" + target_bone))
		for frame in frames + 1:
			var time := minf(float(frame) / 30.0, source.length)
			var sampled_time := _sample_time(target_name, time, source.length)
			var local_rotation := _target_local_rotation(
				String(target_bone), source, tracks, sampled_time, {}, {})
			clip.rotation_track_insert_key(rotation_track, time, local_rotation)
	for mapping in [["root", "root"], ["DEF-hips", "pelvis"]]:
		var source_bone: String = mapping[0]
		var target_bone: String = mapping[1]
		var key := source_bone + ":" + str(Animation.TYPE_POSITION_3D)
		if not tracks.has(key):
			continue
		var source_index := _source_skeleton.find_bone(source_bone)
		var target_index := _target_skeleton.find_bone(target_bone)
		var source_rest_pos: Vector3 = _source_skeleton.get_bone_rest(source_index).origin
		var target_rest_pos: Vector3 = _target_skeleton.get_bone_rest(target_index).origin
		var source_parent := _source_skeleton.get_bone_parent(source_index)
		var target_parent := _target_skeleton.get_bone_parent(target_index)
		var source_parent_basis := Basis.IDENTITY
		var target_parent_basis := Basis.IDENTITY
		if source_parent >= 0:
			source_parent_basis = _source_skeleton.get_bone_global_rest(source_parent).basis
		if target_parent >= 0:
			target_parent_basis = _target_skeleton.get_bone_global_rest(target_parent).basis
		var position_track := clip.add_track(Animation.TYPE_POSITION_3D)
		clip.track_set_path(position_track, NodePath(".:" + target_bone))
		for frame in frames + 1:
			var time := minf(float(frame) / 30.0, source.length)
			var sampled_time := _sample_time(target_name, time, source.length)
			var source_pose: Vector3 = source.position_track_interpolate(tracks[key], sampled_time)
			# A source hip has a -90° rotated parent rest while this target's root
			# uses identity. Transform local displacement through the parent rest
			# frames before assigning it to the target pose track.
			var displacement: Vector3 = target_parent_basis.inverse() \
				* (source_parent_basis * (source_pose - source_rest_pos))
			var target_position: Vector3 = target_rest_pos + displacement * 1.15
			if target_bone == "root" and target_name == "sword_attack":
				# This target rig's lowest ankle sinks below its neutral floor height
				# at the lunge contact. Lift the root through the planted exchange,
				# then settle it during retreat; keep the authored horizontal travel.
				target_position.y += _contact_root_lift(time)
			clip.position_track_insert_key(position_track, time, target_position)
	var grip_track := clip.add_track(Animation.TYPE_ROTATION_3D)
	clip.track_set_path(grip_track, NodePath("Equipment_weapon/GripPivot"))
	for frame in frames + 1:
		var time := minf(float(frame) / 30.0, source.length)
		var degrees := _sword_grip_sweep_degrees(time) \
			if target_name == "sword_attack" else 0.0
		clip.rotation_track_insert_key(grip_track, time,
			Quaternion(Vector3.BACK, deg_to_rad(degrees)))
	if target_name == "sword_attack":
		# The isolated stage places the dummy within the measured lunge range.
		# Runtime still checks the actual sword tip against its chest marker.
		clip.add_marker("contact", 0.74)
	return clip


func _sword_grip_sweep_degrees(time: float) -> float:
	if time < 0.35:
		return 0.0
	if time < 0.72:
		return 165.0 * smoothstep(0.35, 0.72, time)
	if time < 0.95:
		return 165.0
	return 165.0 * (1.0 - smoothstep(0.95, 1.53, time))


func _contact_root_lift(time: float) -> float:
	if time < 0.32:
		return 0.0
	if time < 0.72:
		return 0.09 * smoothstep(0.32, 0.72, time)
	if time < 0.90:
		return 0.09
	return 0.09 * (1.0 - smoothstep(0.90, 1.45, time))


func _sample_time(target_name: String, output_time: float,
		source_length: float) -> float:
	if target_name != "sword_attack" or output_time <= 0.74:
		return output_time
	# The source RM clip takes a second forward step and ends displaced. An
	# isolated card-battle action needs a visible retreat and to finish at home.
	# Reuse the same grounded lunge poses in reverse rather than snapping the
	# root back when AnimationTree returns to idle.
	return 0.74 * (1.0 - (output_time - 0.74) / (source_length - 0.74))


func _source_global_rotation(bone_name: String, clip: Animation,
		tracks: Dictionary, time: float, cache: Dictionary) -> Quaternion:
	if cache.has(bone_name):
		return cache[bone_name]
	var index := _source_skeleton.find_bone(bone_name)
	var local_rotation: Quaternion = _source_skeleton.get_bone_rest(index).basis.get_rotation_quaternion()
	var key := bone_name + ":" + str(Animation.TYPE_ROTATION_3D)
	if tracks.has(key):
		local_rotation = clip.rotation_track_interpolate(tracks[key], time)
	var parent_index := _source_skeleton.get_bone_parent(index)
	var result: Quaternion = local_rotation
	if parent_index >= 0:
		result = _source_global_rotation(_source_skeleton.get_bone_name(parent_index),
			clip, tracks, time, cache) * local_rotation
	cache[bone_name] = result.normalized()
	return cache[bone_name]


func _target_local_rotation(bone_name: String, clip: Animation,
		tracks: Dictionary, time: float, source_cache: Dictionary,
		target_cache: Dictionary) -> Quaternion:
	var target_index := _target_skeleton.find_bone(bone_name)
	var target_rest_global := _target_skeleton.get_bone_global_rest(target_index).basis.get_rotation_quaternion()
	if not BONE_MAP.has(bone_name):
		target_cache[bone_name] = target_rest_global
		return _target_skeleton.get_bone_rest(target_index).basis.get_rotation_quaternion()
	var source_name: String = String(BONE_MAP[bone_name][0])
	var source_index := _source_skeleton.find_bone(source_name)
	var source_rest_global := _source_skeleton.get_bone_global_rest(source_index).basis.get_rotation_quaternion()
	var source_pose_global := _source_global_rotation(source_name, clip, tracks, time, source_cache)
	var desired_global: Quaternion = (
		source_pose_global * source_rest_global.inverse() * target_rest_global).normalized()
	var parent_index := _target_skeleton.get_bone_parent(target_index)
	var parent_global := Quaternion.IDENTITY
	if parent_index >= 0:
		var parent_name := _target_skeleton.get_bone_name(parent_index)
		if target_cache.has(parent_name):
			parent_global = target_cache[parent_name]
		else:
			_target_local_rotation(parent_name, clip, tracks, time, source_cache, target_cache)
			parent_global = target_cache[parent_name]
	target_cache[bone_name] = desired_global
	return (parent_global.inverse() * desired_global).normalized()
