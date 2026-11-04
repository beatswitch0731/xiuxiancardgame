extends SceneTree

const ACTOR_PATH := "res://scripts/paperdoll_actor_study.gd"
var failures: Array[String] = []
var checks := 0

func _initialize() -> void:
	call_deferred("_run")

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
		push_error("PAPERDOLL FAIL: " + label)

func _run() -> void:
	if not FileAccess.file_exists(ACTOR_PATH):
		_check(false, "Shared skeletal actor runtime is missing")
		_finish()
		return
	var script: Script = load(ACTOR_PATH)
	if script == null or not script.can_instantiate():
		_check(false, "Actor script must compile")
		_finish()
		return
	var first: Node2D = script.new()
	var second: Node2D = script.new()
	root.add_child(first)
	root.add_child(second)
	first.set_process(false)
	second.set_process(false)
	if not first.configure() or not second.configure():
		_check(false, "Real study manifest and generated textures load")
		_finish()
		return
	first.position = Vector2(200, 300)
	second.position = Vector2(320, 300)
	_check(first.set_loadout("base", "traded_rusted_sword", "灵泉葫芦"), "Base loadout loads")
	_check(second.set_loadout("玄铁甲", "licensed_rusted_sword", "灵泉葫芦"), "Armor loadout loads")
	var player_a: AnimationPlayer = first.get_node("AnimationPlayer")
	var player_b: AnimationPlayer = second.get_node("AnimationPlayer")
	_check(player_a != player_b, "Actors own independent playback")
	_check(player_a.get_animation_library("") == player_b.get_animation_library(""), "Actors reference identical shared AnimationLibrary")
	_check(first.get_node("Skeleton2D") is Skeleton2D, "Real Skeleton2D is present")
	_check(first.get_node("Skeleton2D/pelvis/torso/upper_arm_r/forearm_r") is Bone2D, "Real parented arm bones are present")
	_check(first.get_debug_state().textures.torso != second.get_debug_state().textures.torso, "Outfits actually bind different torso artwork")
	for art in first.get_node("Visual").get_children():
		_check(art.z_index == 0 and art is Sprite2D, "Internal artwork uses flat sibling order without escaping world depth")
	second.play_action("hurt")
	second.seek_action(0.20)
	var second_time: float = second.get_debug_state().time
	for phase in [0.20, 0.40, 0.72]:
		first.play_action("thrust")
		first.seek_action(phase)
		var initial: Dictionary = first.get_debug_state()
		for outfit in ["玄铁甲", "base"]:
			for view in ["back", "front"]:
				_check(first.set_loadout(outfit, "licensed_rusted_sword", "灵泉葫芦"), "Swap loads at %.2f" % phase)
				_check(first.set_view(view), "View loads at %.2f" % phase)
				var state: Dictionary = first.get_debug_state()
				var art: Sprite2D = first.get_node("Visual/weapon_art")
				var hand: Node2D = first.get_socket("hand_r")
				_check(is_equal_approx(art.global_rotation, hand.global_rotation), "Weapon and hand use the same animation sample")
				_check(is_equal_approx(state.time, initial.time) and state.action == "thrust", "Swap preserves action and time at %.2f" % phase)
				_check(state.root_position == initial.root_position, "Swap preserves actor root")
				_check(state.hand_position.distance_to(state.weapon_grip_position) < 0.001, "Weapon primary grip coincides with hand")
				_check(state.foot_l_position.distance_to(Vector2(205 if view == "back" else 195, 300)) < 0.001, "Left foot remains planted")
				_check(state.foot_r_position.distance_to(Vector2(195 if view == "back" else 205, 300)) < 0.001, "Right foot remains planted")
				_check(state.contact_count == initial.contact_count, "Swap/seek emits no extra contact")
		_check(is_equal_approx(second.get_debug_state().time, second_time), "Other actor clock is independent")
	var before: Dictionary = first.get_debug_state()
	for request in [["unknown", "traded_rusted_sword", "灵泉葫芦"], ["base", "unknown", "灵泉葫芦"], ["base", "traded_rusted_sword", "unknown"]]:
		_check(not first.set_loadout(request[0], request[1], request[2]), "Unsupported loadout rejected")
		_check(first.get_debug_state() == before, "Rejected loadout preserves complete current appearance and pose")
	_check(not first.set_view("side"), "Unsupported view rejected")
	_check(first.get_debug_state() == before, "Rejected view is atomic")
	_check(not first.play_action("unknown"), "Unsupported action rejected")
	_check(first.get_debug_state() == before, "Rejected action preserves pose")
	first.play_action("thrust")
	var count_before: int = first.get_debug_state().contact_count
	first.advance_action(0.20)
	first.set_loadout("玄铁甲", "traded_rusted_sword", "灵泉葫芦")
	first.advance_action(0.21)
	_check(first.get_debug_state().contact_count == count_before + 1, "Animation marker emits one study contact")
	first.set_view("back")
	first.set_loadout("base", "licensed_rusted_sword", "灵泉葫芦")
	first.advance_action(0.60)
	_check(first.get_debug_state().contact_count == count_before + 1, "Recovery and swaps do not duplicate contact")
	first.advance_action(0.10)
	var finished_arm: Bone2D = first.get_node("Skeleton2D/pelvis/torso/upper_arm_r")
	_check(absf(finished_arm.rotation) > 0.1, "Finished action retains its authored guard pose")
	first.set_view("front")
	first.play_action("idle")
	first.seek_action(0.00)
	var idle_head: Vector2 = first.get_debug_state().head_position
	first.play_action("hurt")
	first.seek_action(0.18)
	var hurt: Dictionary = first.get_debug_state()
	_check(hurt.head_position.x < idle_head.x - 3.0, "Hurt visibly recoils head backwards")
	_check(hurt.pelvis_position.y > -27.0, "Hurt bends knees by lowering pelvis")
	_check(hurt.foot_l_position.distance_to(Vector2(195, 300)) < 0.001 and hurt.foot_r_position.distance_to(Vector2(205, 300)) < 0.001, "Hurt preserves both foot contacts")
	_check_visible_feet(first)
	first.queue_free()
	second.queue_free()
	_finish()

func _check_visible_feet(actor: Node2D) -> void:
	# Compare real opaque sole pixels, not the empty floor-contact markers.
	for outfit in ["base", "玄铁甲"]:
		actor.set_loadout(outfit, "licensed_rusted_sword", "灵泉葫芦")
		for view in ["front", "back"]:
			actor.set_view(view)
			actor.play_action("idle")
			actor.seek_action(0.0)
			var baseline := {"l": _visible_sole(actor, "l"), "r": _visible_sole(actor, "r")}
			var maximum_pixel_drift := 0.0
			var maximum_rotation := 0.0
			var maximum_ankle_error := 0.0
			var joint_art_connected := true
			_check(not baseline.l.points.is_empty() and not baseline.r.points.is_empty(), "Both boots contain visible sole pixels")
			for sample in [["idle", 1.2], ["thrust", 0.20], ["thrust", 0.40], ["thrust", 0.72], ["hurt", 0.18], ["hurt", 0.32], ["hurt", 0.65]]:
				actor.play_action(sample[0])
				actor.seek_action(sample[1])
				for side in ["l", "r"]:
					var sole := _visible_sole(actor, side)
					maximum_rotation = maxf(maximum_rotation, absf(sole.rotation))
					for index in sole.points.size():
						maximum_pixel_drift = maxf(maximum_pixel_drift, sole.points[index].distance_to(baseline[side].points[index]))
					var ankle: Node2D = actor.get_socket("ankle_" + side)
					var foot: Node2D = actor.get_socket("foot_" + side)
					maximum_ankle_error = maxf(maximum_ankle_error, ankle.global_position.distance_to(foot.to_global(Vector2(0, -6))))
					var thigh: Sprite2D = actor.get_node("Visual/thigh_" + side + "_art")
					var shin: Sprite2D = actor.get_node("Visual/shin_" + side + "_art")
					var boot: Sprite2D = actor.get_node("Visual/boot_" + side + "_art")
					joint_art_connected = joint_art_connected and _opaque_parts_overlap(thigh, shin) and _opaque_parts_overlap(shin, boot)
			_check(maximum_pixel_drift < 0.001, "%s/%s actual sole pixels stay planted; drift=%.6f" % [outfit, view, maximum_pixel_drift])
			_check(maximum_rotation < 0.001, "%s/%s visible boots stay horizontal; angle=%.6f" % [outfit, view, maximum_rotation])
			_check(maximum_ankle_error < 0.001, "%s/%s shin endpoints meet planted ankles" % [outfit, view])
			_check(joint_art_connected, "%s/%s knee and ankle opaque artwork stays connected" % [outfit, view])
			print("PAPERDOLL_SOLES %s/%s drift=%.6f angle=%.6f ankle_error=%.6f connected=%s" % [outfit, view, maximum_pixel_drift, maximum_rotation, maximum_ankle_error, joint_art_connected])

func _opaque_parts_overlap(first: Sprite2D, second: Sprite2D) -> bool:
	var first_image := first.texture.get_image()
	var second_image := second.texture.get_image()
	var first_region := first.region_rect if first.region_enabled else Rect2(Vector2.ZERO, first.texture.get_size())
	var second_region := second.region_rect if second.region_enabled else Rect2(Vector2.ZERO, second.texture.get_size())
	for y in range(int(first_region.position.y), int(first_region.end.y)):
		for x in range(int(first_region.position.x), int(first_region.end.x)):
			if first_image.get_pixel(x, y).a < 0.5:
				continue
			var world_pixel := first.to_global(Vector2(x + 0.5, y + 0.5) - first_region.position)
			var second_pixel := second.to_local(world_pixel) + second_region.position
			if second_region.has_point(second_pixel) and second_image.get_pixel(int(second_pixel.x), int(second_pixel.y)).a >= 0.5:
				return true
	return false

func _visible_sole(actor: Node2D, side: String) -> Dictionary:
	var art: Sprite2D = actor.get_node_or_null("Visual/boot_" + side + "_art")
	if art == null:
		art = actor.get_node("Visual/shin_" + side + "_art")
	var image: Image = art.texture.get_image()
	var points: Array[Vector2] = []
	var region_origin := art.region_rect.position if art.region_enabled else Vector2.ZERO
	for x in image.get_width():
		if image.get_pixel(x, image.get_height() - 1).a >= 0.5:
			points.append(art.to_global(Vector2(x + 0.5, image.get_height() - 0.5) - region_origin))
	return {"points": points, "rotation": art.global_rotation - actor.global_rotation}

func _finish() -> void:
	print("PAPERDOLL_REUSE_CONTRACT %s checks=%d failures=%d" % ["PASS" if failures.is_empty() else "FAIL", checks, failures.size()])
	quit(0 if failures.is_empty() else 1)

