extends SceneTree

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run_contract")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)

func click_button(button: Button) -> void:
	var point := button.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = point
	root.push_input(motion, true)
	for down in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		root.push_input(event, true)
		await process_frame

func run_contract() -> void:
	var demo = load("res://scenes/actor_wearable_demo.tscn").instantiate()
	root.add_child(demo)
	await process_frame
	await process_frame
	check(demo.skeleton.get_bone_count() >= 50, "Native rig must include articulated fingers")
	check(demo.animation_player.has_animation("Idle"), "Neutral idle must be playable")
	check(demo.animation_player.has_animation("Sword_Ready"), "Revised ready pose must be a separately baked animation")
	check(demo.animation_player.has_animation("Sword_Attack"), "Complete sword action is required")
	check(demo.armor_parts.size() > 3, "Armor must contain articulated wearable parts")
	check(not demo.covered_cloth.is_empty(), "Cuirass must define covered cloth regions")
	check(not demo.sword.visible and demo.sheathed_sword.visible, "Initial sword must be sheathed")
	for node in demo.actor_root.find_children("*", "MeshInstance3D", true, false):
		if String(node.name).begins_with("Yelingyun_Sleeve") or String(node.name).begins_with("Yelingyun_Trouser"):
			for surface_index in node.mesh.get_surface_count():
				var material: Material = node.get_active_material(surface_index)
				check(not material.resource_name.begins_with("Ink_cloth"), "Sleeves and trousers must use dedicated cloth/linen regions, not full-character projection")
	var skeleton_id: int = demo.skeleton.get_instance_id()
	for part in demo.armor_parts:
		check(not part.visible, "Armor must initially be unequipped")
		check(part.get_node(part.skeleton) == demo.skeleton, "Armor must deform on the actor skeleton")
	for cycle in 3:
		await click_button(demo.armor_button)
		for part in demo.armor_parts:
			check(part.visible, "Equip button must display every armor part")
		for part in demo.covered_cloth:
			check(not part.visible, "Covered cloth must be hidden inside fitted armor")
		await click_button(demo.armor_button)
		for part in demo.armor_parts:
			check(not part.visible, "Unequip button must remove every armor part")
		for part in demo.covered_cloth:
			check(part.visible, "Unequip must restore covered cloth")
		await click_button(demo.sword_button)
		check(demo.sword.visible and not demo.sheathed_sword.visible, "Draw must show one sword")
		await click_button(demo.sword_button)
		check(not demo.sword.visible and demo.sheathed_sword.visible, "Sheathe must show one sword")
	check(demo.skeleton.get_instance_id() == skeleton_id, "Changing equipment must preserve character skeleton")
	demo.sword_button.pressed.emit()
	demo.armor_button.pressed.emit()
	demo.attack()
	await create_timer(0.65).timeout
	check(demo.animation_player.current_animation == "Sword_Attack", "Attack must reach its middle without returning early")
	check(demo.weapon_socket.get_parent() == demo.skeleton, "Sword must be attached to animated skeleton")
	var hand: Transform3D = demo.skeleton.global_transform * demo.skeleton.get_bone_global_pose(demo.skeleton.find_bone("DEF-hand.R"))
	check(demo.sword.global_position.distance_to(hand.origin) < .22, "Sword grip must stay in hand region during action")
	await create_timer(1.05).timeout
	check(demo.animation_player.current_animation == "Sword_Ready", "Full action must return to revised armed ready pose")
	check(demo.armor_equipped and demo.sword_equipped, "Attack must preserve equipped state")
	check(demo.play_motion("Crouch_Idle"), "Crouch inspection must be playable")
	check(demo.play_motion("Walk"), "Gait inspection must be playable")
	demo.queue_free()
	await process_frame
	print("WEARABLE_DEMO_CONTRACT ", "PASS" if failures.is_empty() else "FAIL", " failures=", failures)
	quit(0 if failures.is_empty() else 1)
