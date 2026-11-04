extends SceneTree

func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var game: Control = load("res://scenes/modular_pixel_actor_demo.tscn").instantiate()
	root.add_child(game)
	await process_frame
	var selector: OptionButton = game.get_node_or_null("ArmorStudySelector")
	if selector == null or selector.item_count != 2:
		_fail("the armor selector is missing from the real fight")
		return
	var body_selector: OptionButton = game.get_node("ActorStudySelector")
	body_selector.select(0)
	body_selector.item_selected.emit(0)
	if not selector.disabled:
		_fail("armor study remained active for the old baked frames")
		return
	body_selector.select(2)
	body_selector.item_selected.emit(2)
	if selector.disabled:
		_fail("armor study did not return for the modular actor")
		return
	var actor: Node2D = game.duel_stage.get_node("Viewport/World/PlayerAnchor/ModularActor")
	var body: Sprite2D = actor.get_node("Body")
	var chest: Sprite2D = actor.get_node("ArmorTorso")
	var bracer: Sprite2D = actor.get_node("ArmorBracer")
	var idle_body := body.texture
	var state_before: Dictionary = game.combat.state.duplicate(true)
	selector.select(0)
	selector.item_selected.emit(0)
	if chest.visible or bracer.visible:
		_fail("unequipped armor still appears")
		return
	selector.select(1)
	selector.item_selected.emit(1)
	if not chest.visible or not bracer.visible or actor.get("armor_id") != "玄铁甲":
		_fail("source armor ID did not attach both reusable layers")
		return
	if body.texture != idle_body or game.combat.state != state_before:
		_fail("visual armor selection changed body art or battle state")
		return
	var chest_texture := chest.texture
	var bracer_texture := bracer.texture
	var idle_bracer_position := bracer.position
	var contacts: Array[String] = []
	game.duel_stage.contact_frame.connect(func(side: String) -> void: contacts.append(side))
	(game.hand_row.get_child(0) as Button).pressed.emit()
	for sample in 75:
		if "player" in contacts:
			break
		await create_timer(0.02).timeout
	if not "player" in contacts or not game.enemy_label.text.contains("6/7"):
		_fail("armored first card missed the real contact")
		return
	if body.texture == idle_body or chest.texture != chest_texture or bracer.texture != bracer_texture \
			or bracer.position == idle_bracer_position:
		_fail("armor did not reuse the same art and move with the attack pose")
		return
	print("MODULAR_PIXEL_ARMOR_DEMO_PASS id=玄铁甲 layers=2 shared_art=true contact=true")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
