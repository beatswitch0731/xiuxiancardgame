extends SceneTree

const SOURCE = preload(
	"res://assets/third_party/quaternius_ual_standard/AnimationLibrary_Godot_Standard.glb")

func _initialize() -> void:
	call_deferred("_probe")

func _probe() -> void:
	var scene: Node3D = SOURCE.instantiate()
	root.add_child(scene)
	var skeletons := scene.find_children("*", "Skeleton3D", true, false)
	var players := scene.find_children("*", "AnimationPlayer", true, false)
	print("UAL_IMPORT skeletons=", skeletons.size(), " players=", players.size())
	if skeletons.size() != 1 or players.size() != 1:
		quit(1)
		return
	var skeleton: Skeleton3D = skeletons[0]
	var player: AnimationPlayer = players[0]
	print("UAL_IMPORT bones=", skeleton.get_bone_count(), " clips=", player.get_animation_list().size())
	print("UAL_ANIMATION_NAMES ", player.get_animation_list())
	for item in scene.find_children("*", "MeshInstance3D", true, false):
		print("UAL_MESH ", item.name, " path=", scene.get_path_to(item))
	for name in ["root", "DEF-hips", "DEF-spine.001", "DEF-spine.002", "DEF-spine.003", "DEF-neck", "DEF-head", "DEF-shoulder.L", "DEF-upper_arm.L", "DEF-forearm.L", "DEF-hand.L", "DEF-thigh.L", "DEF-shin.L", "DEF-foot.L"]:
		var index := skeleton.find_bone(name)
		print("UAL_BONE ", name, " parent=", skeleton.get_bone_name(skeleton.get_bone_parent(index)) if skeleton.get_bone_parent(index) >= 0 else "-", " global=", skeleton.get_bone_global_rest(index).origin)
	for name in ["Sword_Idle", "Sword_Attack", "Sword_Attack_RM", "Hit_Chest"]:
		if not player.has_animation(name):
			print("UAL_MISSING ", name)
			continue
		var clip: Animation = player.get_animation(name)
		print("UAL_CLIP ", name, " length=", clip.length, " tracks=", clip.get_track_count())
		for i in mini(clip.get_track_count(), 4):
			print("UAL_TRACK ", clip.track_get_path(i), " type=", clip.track_get_type(i), " keys=", clip.track_get_key_count(i))
		if name == "Sword_Attack_RM":
			for i in 2:
				for j in mini(clip.track_get_key_count(i), 6):
					print("UAL_MOTION ", clip.track_get_path(i), " t=", clip.track_get_key_time(i, j), " value=", clip.track_get_key_value(i, j))
	quit()
