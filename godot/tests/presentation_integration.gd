extends SceneTree

# Real entrypoint evidence: source card input drives HD-2D sprite motion inside
# a spatial battlefield, contact feedback, and the authoritative combat result.
const HandUI = preload("res://scripts/card_hand_ui.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene: Control = load("res://scenes/main.tscn").instantiate()
	scene.trial_v4_candidate_preview = true
	root.add_child(scene)
	await process_frame
	var stage = scene.get_node_or_null("DuelStageHD2D")
	if stage == null or not scene.hand_row is HandUI or not scene.stage_assets_ready:
		_fail("main entry did not mount HD-2D stage and source card hand " +
			JSON.stringify({"stage": stage != null,
				"hand": scene.hand_row.get_class() if scene.hand_row != null else "null",
				"ready": scene.stage_assets_ready}))
		return
	var hero: Node3D = stage.get_actor_model("player")
	var dummy: Node3D = stage.get_actor_model("enemy")
	var world: Node3D = stage.get_world_model()
	if hero == null or dummy == null or world == null:
		_fail("first-fight world or pixel actors are absent")
		return
	if _mesh_count(world) < 24:
		_fail("battle scene lacks spatial architectural volume")
		return
	if _sprite_count(stage) < 2 or stage.get_actor_sprite("player") == null \
			or stage.get_actor_sprite("enemy") == null:
		_fail("runtime battle lacks source pixel-frame actors")
		return
	if not stage.has_hd2d_assets():
		_fail("HD-2D scene or actions fail their runtime contract")
		return
	var camera: Camera3D = stage.get_node("Viewport/World/CameraRig/Camera")
	var front_view := camera.global_position
	stage.set_diagnostic_yaw(24.0)
	if camera.global_position.distance_to(front_view) < 2.0:
		_fail("diagnostic camera rotation did not expose 3D parallax")
		return
	stage.set_diagnostic_yaw(0.0)
	var first := scene.hand_row.get_child(0) as Button
	if first == null or first.get_meta("source_card_id") != "sword_probe":
		_fail("source M0 sword_probe card is absent")
		return
	var started: Array[String] = []
	var finished: Array[String] = []
	var contact_sides: Array[String] = []
	var contact_distances: Array[float] = []
	var contact_offsets: Array[Vector3] = []
	stage.presentation_started.connect(func(kind: String, side: String, clip: String) -> void:
		started.append("%s:%s:%s" % [kind, side, clip]))
	stage.presentation_finished.connect(func(kind: String) -> void: finished.append(kind))
	stage.contact_frame.connect(func(side: String) -> void:
		contact_sides.append(side)
		var striker: Node3D = stage.get_actor_model(side)
		var target: Node3D = stage.get_actor_model("enemy" if side == "player" else "player")
		# The defender switches to its hurt frame before contact_frame. Its
		# authored torso pixel is the visible target; the idle ChestHit marker
		# remains at the old pose and is not where the hit flash is placed.
		var target_chest: Vector3 = target.get_chest_point_for("hurt", 0, camera) \
			if side == "player" else target.get_chest_hit().global_position
		var offset: Vector3 = target_chest - striker.get_sword_tip().global_position
		contact_offsets.append(offset)
		contact_distances.append(offset.length()))
	first.pressed.emit()
	if not scene.combat.input_locked or not scene.enemy_label.text.contains("7/7"):
		_fail("card did not lock input or delayed HP changed before contact")
		return
	await create_timer(0.75).timeout
	if not "player" in contact_sides or not scene.enemy_label.text.contains("6/7"):
		_fail("source sword frames missed their contact-synced HP update")
		return
	if contact_distances[0] > 0.35:
		_fail("sprite contact marker missed puppet chest, distance=" + str(contact_distances[0]) + " offset=" + str(contact_offsets[0]))
		return
	await create_timer(0.85).timeout
	if scene.combat.input_locked or not "CARD_PLAY" in finished:
		_fail("sprite sword animation did not settle and unlock input locked=" + str(scene.combat.input_locked) + " finished=" + str(finished) + " started=" + str(started))
		return
	if started.is_empty() or started[0] != "CARD_PLAY:player:sword_probe" \
			or not "CARD_PLAY:enemy:hurt" in started:
		_fail("source card did not trigger hero and dummy sprite clips")
		return
	var remaining_cards: Array = scene.hand_row.get_children().filter(func(child: Node) -> bool: return child is Button)
	if int(scene.combat.state["enemy"]["hp"]) != 6 or remaining_cards.size() != 4:
		_fail("presentation changed source combat authority or hand count")
		return
	var guard: Button
	for child in scene.hand_row.get_children():
		if child.get_meta("source_card_id", "") == "sword_guard":
			guard = child as Button
			break
	if guard == null:
		_fail("source guard card missing")
		return
	guard.pressed.emit()
	await create_timer(0.65).timeout
	if scene.combat.input_locked or not "CARD_PLAY:player:sword_guard" in started:
		_fail("guard did not play its authored sprite clip")
		return
	# A controlled nonfatal hit proves the real entry presents the source
	# reaction decision and waits for model contact before revealing HP.
	scene.combat.state["player"]["hp"] = 4
	scene.combat.state["player"]["block"] = 0
	scene._render()
	scene.end_button.pressed.emit()
	if scene.combat.state.get("phase") != "REACTION_OPEN":
		_fail("source end turn did not open enemy reaction")
		return
	var hp_before := int(scene.combat.state["player"]["hp"])
	scene.reaction_buttons[0].pressed.emit()
	if not scene.combat.input_locked or not scene.player_label.text.contains("气血 %d/" % hp_before):
		_fail("enemy attack presented authoritative HP before 3D contact")
		return
	await create_timer(1.6).timeout
	if scene.combat.input_locked or not "enemy" in contact_sides \
			or not "ENEMY_ACTION" in finished:
		_fail("enemy sprite attack did not contact, resolve, and unlock")
		return
	if contact_distances.back() > 0.35:
		_fail("puppet contact marker missed hero chest, distance=" + str(contact_distances.back()) + " offset=" + str(contact_offsets.back()))
		return
	if not scene.player_label.text.contains("气血 %d/" % int(scene.combat.state["player"]["hp"])):
		_fail("player HP did not update on enemy model contact")
		return
	scene.queue_free()
	await process_frame
	var lethal: Control = load("res://scenes/main.tscn").instantiate()
	lethal.trial_v4_candidate_preview = true
	root.add_child(lethal)
	await process_frame
	lethal.combat.state["enemy"]["hp"] = 1
	var lethal_contacts: Array[String] = []
	lethal.duel_stage.contact_frame.connect(func(side: String) -> void: lethal_contacts.append(side))
	(lethal.hand_row.get_child(0) as Button).pressed.emit()
	if lethal.combat.state["phase"] != "VICTORY" \
			or lethal.state_label.text.contains("战斗胜利") \
			or not lethal.enemy_label.text.contains("1/7"):
		_fail("lethal card revealed victory or zero HP before model contact")
		return
	for sample in 75:
		if "player" in lethal_contacts:
			break
		await create_timer(0.02).timeout
	if not "player" in lethal_contacts:
		_fail("lethal source sword clip emitted no contact key")
		return
	if not lethal.state_label.text.contains("战斗胜利") \
			or not lethal.enemy_label.text.contains("0/7"):
		_fail("sprite contact did not reveal source victory")
		return
	lethal.queue_free()
	await process_frame
	var shielded: Control = load("res://scenes/main.tscn").instantiate()
	shielded.trial_v4_candidate_preview = true
	root.add_child(shielded)
	await process_frame
	shielded.combat.state["enemy"]["block"] = 2
	var shield_stage = shielded.get_node("DuelStageHD2D")
	var impact: OmniLight3D = shield_stage.get_node("Viewport/World/ImpactLight")
	var shield_tint: Array[Color] = []
	shield_stage.contact_frame.connect(func(side: String) -> void:
		if side == "player":
			shield_tint.append(impact.light_color))
	(shielded.hand_row.get_child(0) as Button).pressed.emit()
	if not shielded.enemy_label.text.contains("护盾 2"):
		_fail("shield cost became visible before sword contact")
		return
	for sample in 75:
		if not shield_tint.is_empty():
			break
		await create_timer(0.02).timeout
	if shield_tint.is_empty():
		_fail("shielded source sword clip emitted no contact key")
		return
	if shield_tint.is_empty() or shield_tint[0].g <= shield_tint[0].r \
			or int(shielded.combat.state["enemy"]["hp"]) != 7 \
			or not shielded.enemy_label.text.contains("护盾 1"):
		_fail("shielded sword hit used wood contact or broke source shield feedback")
		return
	print("PRESENTATION_INTEGRATION_PASS real_mesh_world=true sprite_actors=true source_card=true enemy_action=true victory=true shield=true")
	quit(0)


func _mesh_count(node: Node) -> int:
	var result := 1 if node is MeshInstance3D and (node as MeshInstance3D).mesh != null else 0
	for child in node.get_children():
		result += _mesh_count(child)
	return result


func _sprite_count(node: Node) -> int:
	var result := 1 if node is Sprite2D or node is Sprite3D or node is AnimatedSprite2D or node is AnimatedSprite3D else 0
	for child in node.get_children():
		result += _sprite_count(child)
	return result


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
