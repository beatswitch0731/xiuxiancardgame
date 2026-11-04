extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var game: Control = load("res://scenes/actor_motion_lab.tscn").instantiate()
	root.add_child(game)
	await process_frame
	var stage: Node = game.duel_stage
	if stage.name != "DuelStageHD2D" or not String(stage.stage_art.get("selectedScene", "")).contains("world_v17"):
		_fail("motion lab is not mounted in the real V17 training hall")
		return
	var actor: Node3D = stage.get_node_or_null("Viewport/World/PlayerAnchor/ModularActorHD2D")
	if actor == null or not stage.has_method("seek_actor_study_attack"):
		_fail("modular actor or motion scrub is missing from V17")
		return
	var controls: Control = game.get_node("MotionLabControls")
	var scrub: HSlider = controls.find_child("MotionScrub", true, false)
	var variant: OptionButton = controls.find_child("ActorVariant", true, false)
	var realm: OptionButton = controls.find_child("RealmStageSelector", true, false)
	var armor: OptionButton = controls.find_child("ArmorSelector", true, false)
	var accessory: OptionButton = controls.find_child("AccessorySelector", true, false)
	var artifact: OptionButton = controls.find_child("ArtifactSelector", true, false)
	if scrub == null or variant == null or realm == null or armor == null or accessory == null or artifact == null:
		_fail("player-facing pose, realm and A/B controls are missing")
		return
	var body: Sprite3D = actor.get_node("Body")
	var idle: Texture2D = body.texture
	var battle_realm: String = String(game.combat.state.get("realm", ""))
	realm.select(1)
	realm.item_selected.emit(1)
	if not String(body.texture.resource_path).contains("s2_idle_candidate_v3") \
			or String(game.combat.state.get("realm", "")) != battle_realm:
		_fail("Foundation preview changed combat state or missed the S2 body")
		return
	var s2_idle: Texture2D = body.texture
	armor.select(1)
	armor.item_selected.emit(1)
	if not String(body.texture.resource_path).contains("s2_xuantiejia_idle_candidate"):
		_fail("Xuantiejia equipment did not change the S2 body")
		return
	accessory.select(1)
	accessory.item_selected.emit(1)
	var gourd: Sprite3D = actor.get_node_or_null("LingquanHulu")
	if gourd == null or not gourd.visible:
		_fail("Lingquan Hulu was not mounted at the waist")
		return
	artifact.select(1)
	artifact.item_selected.emit(1)
	var sword_case: Sprite3D = actor.get_node_or_null("QingyunSwordCase")
	if sword_case == null or not sword_case.visible:
		_fail("Qingyun Sword Case was not mounted behind the S2 body")
		return
	scrub.value = 28
	await process_frame
	if body.texture == idle or not String(body.texture.resource_path).contains("s2_xuantiejia_anticipation_candidate"):
		_fail("new anticipation art is not shown")
		return
	if not (controls.find_child("MotionStatus", true, false) as Label).text.contains("28%"):
		_fail("scrub phase text was overwritten on the next frame")
		return
	scrub.value = 52
	if body.texture == idle or not String(body.texture.resource_path).contains("s2_xuantiejia_thrust_candidate"):
		_fail("thrust art does not replace anticipation")
		return
	scrub.value = 100
	if not String(body.texture.resource_path).contains("s2_xuantiejia_idle_candidate"):
		_fail("animation did not return to idle")
		return
	armor.select(0)
	armor.item_selected.emit(0)
	if body.texture != s2_idle:
		_fail("unequipping Xuantiejia did not restore the S2 body")
		return
	accessory.select(0)
	accessory.item_selected.emit(0)
	if gourd.visible:
		_fail("unequipping Lingquan Hulu left the prop visible")
		return
	artifact.select(0)
	artifact.item_selected.emit(0)
	if sword_case.visible:
		_fail("unequipping Qingyun Sword Case left the prop visible")
		return
	armor.select(1)
	armor.item_selected.emit(1)
	artifact.select(1)
	artifact.item_selected.emit(1)
	realm.select(0)
	realm.item_selected.emit(0)
	if String(body.texture.resource_path).contains("xuantiejia") or armor.selected != 0 \
			or artifact.selected != 0 or sword_case.visible:
		_fail("returning to Qi left Foundation equipment previews equipped")
		return
	realm.select(1)
	realm.item_selected.emit(1)
	if body.texture != s2_idle:
		_fail("returning to Foundation restored a stale armor preview")
		return
	variant.select(3)
	variant.item_selected.emit(3)
	if actor.visible or not stage.get_actor_sprite("player").visible:
		_fail("original-actor A/B switch did not restore the source actor")
		return
	variant.select(0)
	variant.item_selected.emit(0)
	if not actor.visible or stage.get_actor_sprite("player").visible:
		_fail("candidate A/B switch did not restore the modular actor")
		return
	var contacts: Array[String] = []
	stage.contact_frame.connect(func(side: String) -> void: contacts.append(side))
	(game.hand_row.get_child(0) as Button).pressed.emit()
	if not game.combat.input_locked or not game.enemy_label.text.contains("7/7"):
		_fail("real card or contact-gated damage was lost")
		return
	await process_frame
	if not (controls.find_child("MotionStatus", true, false) as Label).text.contains("实战播放中"):
		_fail("live playback status was overwritten")
		return
	for sample in 75:
		if "player" in contacts:
			break
		await create_timer(0.02).timeout
	if not "player" in contacts or not game.enemy_label.text.contains("6/7"):
		_fail("real first card did not contact in V17")
		return
	print("ACTOR_MOTION_LAB_PASS stage=v17 keyposes=3 scrub=true card_contact=true")
	game.queue_free()
	await process_frame
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
