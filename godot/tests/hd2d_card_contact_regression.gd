extends SceneTree

# Play source cards through the real main entry. Timing and guard positions
# are assertions on what the player actually sees, not final state alone.


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var followthrough := await _game_with_card("sword_followthrough")
	var followthrough_contacts: Array[String] = []
	followthrough.duel_stage.contact_frame.connect(func(side: String) -> void: followthrough_contacts.append(side))
	if not followthrough.combat.play_card(0):
		_fail("followthrough source card could not play")
		return
	if not followthrough.enemy_label.text.contains("7/7"):
		_fail("followthrough damage appeared before contact")
		return
	for sample in 75:
		if "player" in followthrough_contacts:
			break
		await create_timer(0.02).timeout
	if not "player" in followthrough_contacts or not followthrough.enemy_label.text.contains("6/7"):
		_fail("followthrough lacks its own visible damage contact")
		return
	followthrough.queue_free()
	await process_frame
	for card_id in ["sword_guard", "sword_sheath_guard"]:
		var guard := await _game_with_card(card_id)
		var home := guard.duel_stage.get_actor_anchor("player").position as Vector3
		if not guard.combat.play_card(0):
			_fail(card_id + " source card could not play")
			return
		var max_travel := 0.0
		for sample in 65:
			await process_frame
			max_travel = maxf(max_travel,
				guard.duel_stage.get_actor_anchor("player").position.distance_to(home))
			if guard.pending_presentations == 0:
				break
		if max_travel > 0.05:
			_fail(card_id + " guard lunged " + str(max_travel) + " world units")
			return
		guard.queue_free()
		await process_frame
	var lethal := await _game_with_card("sword_probe")
	lethal.combat.state["enemy"]["hp"] = 1
	lethal.combat.state["player"]["atkMod"] = 2
	lethal._render()
	if not lethal.combat.play_card(0):
		_fail("lethal source card could not play")
		return
	if not lethal.enemy_label.text.contains("1/7"):
		_fail("overkill showed invented prehit HP: " + lethal.enemy_label.text)
		return
	print("HD2D_CARD_CONTACT_PASS followthrough_contact=true guards_stationary=true overkill_prehit=1")
	quit(0)


func _game_with_card(card_id: String) -> Control:
	var game: Control = load("res://scenes/main.tscn").instantiate()
	# The default sword lesson now uses the pixel stage. Keep this regression on
	# the authored HD-2D V17 candidate whose root motion it measures.
	game.trial_v17_candidate_preview = true
	root.add_child(game)
	await process_frame
	game.combat.state["hand"] = [card_id]
	game.combat.state["qi"] = 4
	game._render()
	return game


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
