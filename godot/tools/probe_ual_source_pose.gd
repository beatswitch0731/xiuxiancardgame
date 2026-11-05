extends SceneTree

const SOURCE = preload(
	"res://assets/third_party/quaternius_ual_standard/AnimationLibrary_Godot_Standard.glb")
const TARGET = preload("res://assets/characters/actor_image3d_mvp/yelingyun_image3d_rig_candidate.glb")


func _initialize() -> void:
	call_deferred("_probe")


func _probe() -> void:
	var scene: Node3D = SOURCE.instantiate()
	root.add_child(scene)
	var skeleton: Skeleton3D = scene.find_children("*", "Skeleton3D", true, false)[0]
	var player: AnimationPlayer = scene.find_children("*", "AnimationPlayer", true, false)[0]
	var target: Node3D = TARGET.instantiate()
	root.add_child(target)
	var target_skeleton: Skeleton3D = target.find_children("*", "Skeleton3D", true, false)[0]
	for pair in [[skeleton, "root"], [skeleton, "DEF-hips"],
			[target_skeleton, "root"], [target_skeleton, "pelvis"]]:
		var rig: Skeleton3D = pair[0]
		var i := rig.find_bone(pair[1])
		print("RIG_REST name=", pair[1], " origin=", rig.get_bone_rest(i).origin,
			" rotation=", rig.get_bone_rest(i).basis.get_rotation_quaternion(),
			" global=", rig.get_bone_global_rest(i).origin)
	await process_frame
	for clip_name in ["Sword_Idle", "Sword_Attack_RM"]:
		player.play(clip_name)
		var clip: Animation = player.get_animation(clip_name)
		var rotation_tracks := {}
		for track in clip.get_track_count():
			if clip.track_get_type(track) == Animation.TYPE_ROTATION_3D:
				rotation_tracks[String(clip.track_get_path(track).get_subname(0))] = track
		for t in [0.0, 0.18, 0.42, 0.74]:
			player.seek(t, true)
			skeleton.force_update_all_bone_transforms()
			var values := []
			for bone in ["DEF-foot.L", "DEF-foot.R", "DEF-hips", "root"]:
				var index := skeleton.find_bone(bone)
				values.append(skeleton.get_bone_global_pose(index).origin)
			print("SOURCE_POSE ", clip_name, " t=", t, " foot_L=", values[0],
				" foot_R=", values[1], " hips=", values[2], " root=", values[3])
			if t == 0.0:
				for bone in ["DEF-hips", "DEF-thigh.L", "DEF-shin.L", "DEF-foot.L"]:
					var actual: Quaternion = skeleton.get_bone_global_pose(
						skeleton.find_bone(bone)).basis.get_rotation_quaternion()
					var computed := _reconstruct_global(
						skeleton, clip, rotation_tracks, bone, t)
					print("SOURCE_ROTATION_ERROR ", clip_name, " bone=", bone,
						" degrees=", rad_to_deg(actual.angle_to(computed)))
	quit()


func _reconstruct_global(skeleton: Skeleton3D, clip: Animation,
		tracks: Dictionary, bone: String, time: float) -> Quaternion:
	var index := skeleton.find_bone(bone)
	var local: Quaternion = skeleton.get_bone_rest(index).basis.get_rotation_quaternion()
	if tracks.has(bone):
		local = clip.rotation_track_interpolate(tracks[bone], time)
	var parent := skeleton.get_bone_parent(index)
	if parent >= 0:
		return (_reconstruct_global(skeleton, clip, tracks,
			skeleton.get_bone_name(parent), time) * local).normalized()
	return local.normalized()
