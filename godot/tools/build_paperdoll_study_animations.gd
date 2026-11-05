extends SceneTree
## Authored key poses, shared by every compatible outfit and both views.
const OUTPUT := "res://assets/battle/undercurrent_pixel_v1/paperdoll_v1/shared_actions.tres"
const P := "Skeleton2D/pelvis"
const T := P + "/torso"

func _initialize() -> void:
	var library := AnimationLibrary.new()
	var idle := _animation(2.4, true)
	_keys(idle, T + ":position", [0.0, 1.2, 2.4], [Vector2(0, -9), Vector2(0, -9.35), Vector2(0, -9)])
	_degrees(idle, T + ":rotation", [0.0, 1.2, 2.4], [0.0, 0.6, 0.0])
	_degrees(idle, T + "/head/ponytail:rotation", [0.0, 1.2, 2.4], [-2.0, 2.0, -2.0])
	library.add_animation("idle", idle)
	var thrust := _animation(0.9)
	var times := [0.0, 0.20, 0.32, 0.40, 0.48, 0.72, 0.9]
	_keys(thrust, P + ":position", times, [Vector2(0, -28), Vector2(-1, -27), Vector2(-1, -27), Vector2(1.5, -27), Vector2(1.5, -27), Vector2(0, -27.5), Vector2(0, -28)])
	_degrees(thrust, T + ":rotation", times, [0, -5, -5, 8, 8, 2, 0])
	_degrees(thrust, T + "/head:rotation", times, [0, 3, 3, -6, -6, -1, 0])
	_degrees(thrust, T + "/upper_arm_r:rotation", times, [-30, 8, 8, -95, -95, -55, -30])
	_degrees(thrust, T + "/upper_arm_r/forearm_r:rotation", times, [-70, -125, -125, 5, 5, -50, -70])
	_degrees(thrust, T + "/upper_arm_l:rotation", times, [8, 18, 18, 28, 28, 14, 8])
	_degrees(thrust, T + "/upper_arm_l/forearm_l:rotation", times, [-12, -25, -25, -38, -38, -18, -12])
	_degrees(thrust, T + "/head/ponytail:rotation", times, [-2, -8, -8, 12, 16, 2, -2])
	var marker := thrust.add_track(Animation.TYPE_METHOD)
	thrust.track_set_path(marker, NodePath("."))
	thrust.track_insert_key(marker, 0.40, {"method": &"_study_contact_marker", "args": []})
	library.add_animation("thrust", thrust)
	var hurt := _animation(0.65)
	var hurt_times := [0.0, 0.10, 0.18, 0.32, 0.50, 0.65]
	_keys(hurt, P + ":position", hurt_times, [Vector2(0, -28), Vector2(-2, -25), Vector2(-3, -24), Vector2(-2, -25), Vector2(-0.5, -27), Vector2(0, -28)])
	_degrees(hurt, T + ":rotation", hurt_times, [0, -12, -16, -12, -3, 0])
	_degrees(hurt, T + "/head:rotation", hurt_times, [0, -8, -10, -5, 2, 0])
	_degrees(hurt, T + "/upper_arm_r:rotation", hurt_times, [-30, -12, -8, -18, -28, -30])
	_degrees(hurt, T + "/upper_arm_r/forearm_r:rotation", hurt_times, [-70, -92, -98, -85, -72, -70])
	_degrees(hurt, T + "/upper_arm_l:rotation", hurt_times, [8, 22, 26, 16, 8, 8])
	_degrees(hurt, T + "/head/ponytail:rotation", hurt_times, [-2, 16, 22, 6, -6, -2])
	library.add_animation("hurt", hurt)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT.get_base_dir()))
	var error := ResourceSaver.save(library, OUTPUT)
	print("PAPERDOLL_ANIMATIONS %s %s" % ["PASS" if error == OK else "FAIL", OUTPUT])
	quit(0 if error == OK else 1)

func _animation(duration: float, looping: bool = false) -> Animation:
	var animation := Animation.new()
	animation.length = duration
	animation.loop_mode = Animation.LOOP_LINEAR if looping else Animation.LOOP_NONE
	# Complete authored baseline avoids carry-over when switching action families.
	_keys(animation, P + ":position", [0.0, duration], [Vector2(0, -28), Vector2(0, -28)])
	_keys(animation, T + ":position", [0.0, duration], [Vector2(0, -9), Vector2(0, -9)])
	for item in [[T, 0.0], [T + "/head", 0.0], [T + "/head/ponytail", -2.0], [T + "/upper_arm_r", -30.0], [T + "/upper_arm_r/forearm_r", -70.0], [T + "/upper_arm_l", 8.0], [T + "/upper_arm_l/forearm_l", -12.0]]:
		_degrees(animation, item[0] + ":rotation", [0.0, duration], [item[1], item[1]])
	return animation

func _keys(animation: Animation, path: String, times: Array, values: Array) -> void:
	var track := animation.find_track(NodePath(path), Animation.TYPE_VALUE)
	if track >= 0:
		animation.remove_track(track)
	track = animation.add_track(Animation.TYPE_VALUE)
	animation.track_set_path(track, NodePath(path))
	animation.track_set_interpolation_type(track, Animation.INTERPOLATION_LINEAR)
	for index in times.size():
		animation.track_insert_key(track, float(times[index]), values[index])

func _degrees(animation: Animation, path: String, times: Array, values: Array) -> void:
	var radians: Array = []
	for value in values:
		radians.append(deg_to_rad(float(value)))
	_keys(animation, path, times, radians)
