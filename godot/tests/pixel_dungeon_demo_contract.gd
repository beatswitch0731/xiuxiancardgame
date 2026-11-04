extends SceneTree

# Exercises the alternate stage through the real first-fight entry and rules.

func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var game: Control = load("res://scenes/pixel_dungeon_demo.tscn").instantiate()
	root.add_child(game)
	await process_frame
	var stage: Node = game.duel_stage
	if stage == null or stage.name != "PixelDungeonStage":
		_fail("alternate pixel dungeon stage was not mounted")
		return
	if not stage.has_hd2d_assets() or stage.get_actor_sprite("player") == null \
			or stage.get_actor_sprite("enemy") == null:
		_fail("source actors were not mounted in pixel dungeon")
		return
	var first := game.hand_row.get_child(0) as Button
	if first == null or first.get_meta("source_card_id") != "sword_probe":
		_fail("real source hand was not retained")
		return
	var contacts: Array[String] = []
	stage.contact_frame.connect(func(side: String) -> void: contacts.append(side))
	first.pressed.emit()
	if not game.combat.input_locked or not game.enemy_label.text.contains("7/7"):
		_fail("damage appeared before visual contact")
		return
	for sample in 75:
		if "player" in contacts:
			break
		await create_timer(0.02).timeout
	if not "player" in contacts or not game.enemy_label.text.contains("6/7"):
		_fail("pixel dungeon attack did not release damage at contact")
		return
	for sample in 100:
		if game.pending_presentations == 0 and not game.combat.input_locked:
			break
		await create_timer(0.02).timeout
	if game.end_button.disabled:
		_fail("first presentation did not release the real end-turn control")
		return
	game.end_button.pressed.emit()
	if game.reaction_buttons[3].disabled:
		_fail("real EVADE reaction is not available")
		return
	var player_sprite: AnimatedSprite2D = stage.get_actor_sprite("player")
	var player_animations: Array[String] = []
	player_sprite.animation_changed.connect(func() -> void: player_animations.append(String(player_sprite.animation)))
	var hp_before := int(game.combat.state["player"]["hp"])
	game.reaction_buttons[3].pressed.emit()
	for sample in 120:
		if game.pending_presentations == 0 and not game.combat.input_locked:
			break
		await create_timer(0.02).timeout
	if int(game.combat.state["player"]["hp"]) != hp_before or "hurt" in player_animations:
		_fail("successful EVADE presented the player as wounded")
		return
	print("PIXEL_DUNGEON_DEMO_CONTRACT_PASS stage=2d source_hand=true contact=true evade=true")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
