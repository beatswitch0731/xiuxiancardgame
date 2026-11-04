extends SceneTree

# The browser's 220 ms followthrough cue lands on the raised recovery pose.
# The authored horizontal strike is visible at 180 ms in Godot. Hitstop must
# freeze both animation clocks while that contact pose is held.

func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var game: Control = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	for warmup_frame in 16:
		await process_frame
	game.combat.state["hand"] = ["sword_followthrough"]
	game.combat.state["qi"] = 4
	game._render()
	var actor: Node3D = game.duel_stage.get_actor_model("player")
	var contact := {"sprite_time": -1.0, "clock_time": -1.0}
	game.duel_stage.contact_frame.connect(func(side: String) -> void:
		if side == "player":
			contact["sprite_time"] = actor.get_playback_time()
			contact["clock_time"] = actor.get_animation_player().current_animation_position)
	if not game.combat.play_card(0):
		_fail("followthrough source card could not play")
		return
	for frame in 90:
		if float(contact["sprite_time"]) >= 0.0:
			break
		await process_frame
	var sprite_time_at_contact := float(contact["sprite_time"])
	var clock_time_at_contact := float(contact["clock_time"])
	if sprite_time_at_contact < 0.0:
		_fail("followthrough did not contact")
		return
	if absf(sprite_time_at_contact - 0.180) > 0.025:
		_fail("followthrough contact at %.3fs, visible blade strike requires 0.180s" % sprite_time_at_contact)
		return
	await create_timer(0.035).timeout
	var sprite_hold_time: float = actor.get_playback_time()
	var clock_hold_time: float = actor.get_animation_player().current_animation_position
	if absf(sprite_hold_time - sprite_time_at_contact) > 0.012:
		_fail("contact sprite advanced during hitstop: %.3f -> %.3f" % [sprite_time_at_contact, sprite_hold_time])
		return
	if absf(clock_hold_time - clock_time_at_contact) > 0.012:
		_fail("contact secondary clock advanced during hitstop: %.3f -> %.3f" % [clock_time_at_contact, clock_hold_time])
		return
	if not game.enemy_label.text.contains("6/7"):
		_fail("damage HUD did not change at contact")
		return
	game.queue_free()
	await process_frame
	var probe: Control = load("res://scenes/main.tscn").instantiate()
	root.add_child(probe)
	for warmup_frame in 16:
		await process_frame
	probe.combat.state["hand"] = ["sword_probe"]
	probe.combat.state["qi"] = 4
	probe._render()
	if not probe.combat.play_card(0):
		_fail("probe source card could not play")
		return
	var probe_sprite: AnimatedSprite3D = probe.duel_stage.get_actor_sprite("player")
	var saw_probe_action := false
	for frame in 140:
		await process_frame
		if String(probe_sprite.animation) == "sword_probe":
			saw_probe_action = true
		if saw_probe_action and String(probe_sprite.animation) == "idle":
			break
	if not saw_probe_action or String(probe_sprite.animation) != "idle":
		_fail("probe did not return to idle")
		return
	if probe.duel_stage._impact_fx.visible:
		_fail("probe contact flash remained visible after actor returned to idle")
		return
	print("HD2D_TIMELINE_PASS followthrough_contact=%.3f hitstop_clocks_frozen=true flash_cleared_before_idle=true" % sprite_time_at_contact)
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
