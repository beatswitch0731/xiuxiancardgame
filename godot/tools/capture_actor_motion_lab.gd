extends SceneTree

const OUTPUT := "res://output/captures/godot-migration/actor-motion-lab/"


func _initialize() -> void:
	call_deferred("_capture")


func _capture() -> void:
	var game: Control = load("res://scenes/actor_motion_lab.tscn").instantiate()
	root.add_child(game)
	for frame in 20:
		await process_frame
	var stage: Node = game.duel_stage
	for pose in [{"name": "idle.png", "progress": 0.0},
			{"name": "anticipation.png", "progress": 0.28},
			{"name": "thrust.png", "progress": 0.52}]:
		stage.seek_actor_study_attack(float(pose["progress"]))
		await RenderingServer.frame_post_draw
		if not _save(String(pose["name"])):
			quit(1)
			return
	stage.seek_actor_study_attack(0.0)
	var body: Sprite3D = stage.get_node("Viewport/World/PlayerAnchor/ModularActorHD2D/Body")
	var original_body := body.texture
	body.texture = load("res://assets/characters/actor_motion_lab_v1/yelingyun_s2_idle_candidate_v2.png")
	await RenderingServer.frame_post_draw
	if not _save("s2_idle_candidate.png"):
		quit(1)
		return
	body.texture = load("res://assets/characters/actor_motion_lab_v1/yelingyun_s2_idle_candidate_v3.png")
	await RenderingServer.frame_post_draw
	if not _save("s2_idle_candidate_v3.png"):
		quit(1)
		return
	body.texture = original_body
	var contacts: Array[String] = []
	stage.contact_frame.connect(func(side: String) -> void: contacts.append(side))
	(game.hand_row.get_child(0) as Button).pressed.emit()
	for frame in 120:
		if "player" in contacts:
			break
		await process_frame
	if not "player" in contacts:
		push_error("First sword card missed contact")
		quit(1)
		return
	await RenderingServer.frame_post_draw
	if not _save("contact.png"):
		quit(1)
		return
	game.queue_free()
	await process_frame
	var s2_game: Control = load("res://scenes/actor_motion_lab.tscn").instantiate()
	root.add_child(s2_game)
	for frame in 20:
		await process_frame
	var s2_stage: Node = s2_game.duel_stage
	var realm_selector: OptionButton = s2_game.find_child("RealmStageSelector", true, false)
	realm_selector.select(1)
	realm_selector.item_selected.emit(1)
	for pose in [{"name": "s2_idle.png", "progress": 0.0},
			{"name": "s2_anticipation.png", "progress": 0.28},
			{"name": "s2_thrust.png", "progress": 0.52}]:
		s2_stage.seek_actor_study_attack(float(pose["progress"]))
		await RenderingServer.frame_post_draw
		if not _save(String(pose["name"])):
			quit(1)
			return
	s2_stage.seek_actor_study_attack(0.0)
	var s2_contacts: Array[String] = []
	s2_stage.contact_frame.connect(func(side: String) -> void: s2_contacts.append(side))
	(s2_game.hand_row.get_child(0) as Button).pressed.emit()
	for frame in 120:
		if "player" in s2_contacts:
			break
		await process_frame
	if not "player" in s2_contacts:
		push_error("S2 first sword card missed contact")
		quit(1)
		return
	await RenderingServer.frame_post_draw
	if not _save("s2_contact.png"):
		quit(1)
		return
	s2_game.queue_free()
	await process_frame
	var armored_game: Control = load("res://scenes/actor_motion_lab.tscn").instantiate()
	root.add_child(armored_game)
	for frame in 20:
		await process_frame
	var armored_stage: Node = armored_game.duel_stage
	var armored_realm: OptionButton = armored_game.find_child("RealmStageSelector", true, false)
	var armor_selector: OptionButton = armored_game.find_child("ArmorSelector", true, false)
	armored_realm.select(1)
	armored_realm.item_selected.emit(1)
	armor_selector.select(1)
	armor_selector.item_selected.emit(1)
	for pose in [{"name": "s2_armor_idle.png", "progress": 0.0},
			{"name": "s2_armor_anticipation.png", "progress": 0.28},
			{"name": "s2_armor_thrust.png", "progress": 0.52}]:
		armored_stage.seek_actor_study_attack(float(pose["progress"]))
		await RenderingServer.frame_post_draw
		if not _save(String(pose["name"])):
			quit(1)
			return
	armored_stage.seek_actor_study_attack(0.0)
	var armored_contacts: Array[String] = []
	armored_stage.contact_frame.connect(func(side: String) -> void: armored_contacts.append(side))
	(armored_game.hand_row.get_child(0) as Button).pressed.emit()
	for frame in 120:
		if "player" in armored_contacts:
			break
		await process_frame
	if not "player" in armored_contacts:
		push_error("S2 Xuantiejia first sword card missed contact")
		quit(1)
		return
	await RenderingServer.frame_post_draw
	if not _save("s2_armor_contact.png"):
		quit(1)
		return
	armored_game.queue_free()
	await process_frame
	var combo_game: Control = load("res://scenes/actor_motion_lab.tscn").instantiate()
	root.add_child(combo_game)
	for frame in 20:
		await process_frame
	var combo_stage: Node = combo_game.duel_stage
	var combo_realm: OptionButton = combo_game.find_child("RealmStageSelector", true, false)
	var combo_armor: OptionButton = combo_game.find_child("ArmorSelector", true, false)
	var combo_accessory: OptionButton = combo_game.find_child("AccessorySelector", true, false)
	var combo_artifact: OptionButton = combo_game.find_child("ArtifactSelector", true, false)
	combo_realm.select(1)
	combo_realm.item_selected.emit(1)
	combo_armor.select(1)
	combo_armor.item_selected.emit(1)
	combo_accessory.select(1)
	combo_accessory.item_selected.emit(1)
	combo_artifact.select(1)
	combo_artifact.item_selected.emit(1)
	for pose in [{"name": "s2_case_combo_idle.png", "progress": 0.0},
			{"name": "s2_case_combo_anticipation.png", "progress": 0.28},
			{"name": "s2_case_combo_thrust.png", "progress": 0.52}]:
		combo_stage.seek_actor_study_attack(float(pose["progress"]))
		await RenderingServer.frame_post_draw
		if not _save(String(pose["name"])):
			quit(1)
			return
	combo_stage.seek_actor_study_attack(0.0)
	var combo_contacts: Array[String] = []
	combo_stage.contact_frame.connect(func(side: String) -> void: combo_contacts.append(side))
	(combo_game.hand_row.get_child(0) as Button).pressed.emit()
	for frame in 120:
		if "player" in combo_contacts:
			break
		await process_frame
	if not "player" in combo_contacts:
		push_error("S2 equipment combo first sword card missed contact")
		quit(1)
		return
	await RenderingServer.frame_post_draw
	if not _save("s2_case_combo_contact.png"):
		quit(1)
		return
	print("ACTOR_MOTION_LAB_CAPTURE_PASS s1=4 s2=4 s2_armor=4 s2_case_combo=4")
	quit(0)


func _save(file_name: String) -> bool:
	var directory := ProjectSettings.globalize_path(OUTPUT)
	DirAccess.make_dir_recursive_absolute(directory)
	var frame := root.get_viewport().get_texture().get_image()
	if frame == null or frame.is_empty():
		return false
	return frame.save_png(ProjectSettings.globalize_path(OUTPUT + file_name)) == OK
