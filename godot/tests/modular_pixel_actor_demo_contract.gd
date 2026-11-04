extends SceneTree

# The study must run through the real M0 scene and card input, not an isolated sprite preview.
func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene: PackedScene = load("res://scenes/modular_pixel_actor_demo.tscn")
	if scene == null:
		_fail("modular demo scene is missing")
		return
	var game: Control = scene.instantiate()
	root.add_child(game)
	await process_frame
	var stage: Node = game.duel_stage
	if stage == null or not stage.has_method("set_actor_study_variant"):
		_fail("modular stage was not mounted")
		return
	if stage.stretch_shrink != 1 or stage.get_node("Viewport/World").scale != Vector2.ONE * 2.0:
		_fail("visual study still uses the half-resolution world transform")
		return
	if stage.get_node("Viewport/World/Room").visible \
			or stage.get_node_or_null("Viewport/World/QingyunRoomCandidate") == null:
		_fail("revised Qingyun trial hall was not mounted")
		return
	var study: OptionButton = game.get_node_or_null("ActorStudySelector")
	if study == null or study.item_count != 4:
		_fail("the playable A/B selector is missing")
		return
	var body: Sprite2D = stage.get_node("Viewport/World/PlayerAnchor/ModularActor/Body")
	var sword: Sprite2D = stage.get_node("Viewport/World/PlayerAnchor/ModularActor/WeaponPivot/Weapon")
	var original_body: Texture2D = body.texture
	study.select(0)
	study.item_selected.emit(0)
	if not stage.get_actor_sprite("player").visible or body.get_parent().visible:
		_fail("old full-frame A/B branch is not visible")
		return
	var practice_texture: Texture2D
	for variant in [1, 2, 3, 1]:
		study.select(variant)
		study.item_selected.emit(variant)
		if body.texture != original_body:
			_fail("equipment switching replaced the base body")
			return
		if sword.visible != (variant != 1):
			_fail("weapon layer visibility does not follow selection")
			return
		if variant == 2:
			practice_texture = sword.texture
		if variant == 3 and sword.texture == practice_texture:
			_fail("the second weapon reused the first weapon texture")
			return
		if variant == 3 and stage.get_node("Viewport/World/PlayerAnchor/ModularActor").get("variant") != "traded_rusted_sword":
			_fail("the project rusted-sword ID did not select its visual")
			return
	study.select(2)
	study.item_selected.emit(2)
	var contacts: Array[String] = []
	stage.contact_frame.connect(func(side: String) -> void: contacts.append(side))
	(game.hand_row.get_child(0) as Button).pressed.emit()
	if not game.combat.input_locked or not game.enemy_label.text.contains("7/7"):
		_fail("card input did not retain contact-gated damage")
		return
	for sample in 75:
		if "player" in contacts:
			break
		await create_timer(0.02).timeout
	if not "player" in contacts or not game.enemy_label.text.contains("6/7"):
		_fail("modular attack did not reach source contact and damage")
		return
	if body.texture == original_body or not sword.visible:
		_fail("contact did not show the unarmed thrust pose with independent sword")
		return
	print("MODULAR_PIXEL_ACTOR_DEMO_PASS switch=4 body_shared=true contact=true")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
