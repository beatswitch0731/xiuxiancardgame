extends SceneTree

# Read-only runtime probe. It records the presentation clocks and visible HUD
# during the first-fight cards without changing combat or scene assets.

func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	for card_id in ["sword_probe", "sword_followthrough", "sword_edge", "sword_guard", "sword_sheath_guard"]:
		var game: Control = load("res://scenes/main.tscn").instantiate()
		root.add_child(game)
		for warmup_frame in 16:
			await process_frame
		game.combat.state["hand"] = [card_id]
		game.combat.state["qi"] = 4
		game._render()
		var actor: Node3D = game.duel_stage.get_actor_model("player")
		var sprite: AnimatedSprite3D = actor.get_sprite()
		var clock: AnimationPlayer = actor.get_animation_player()
		var events: Array[String] = []
		var start_us := Time.get_ticks_usec()
		actor.contact_key.connect(func(clip: String) -> void:
			events.append("sprite_contact=" + clip + "@%.1fms" % ((Time.get_ticks_usec() - start_us) / 1000.0)))
		game.duel_stage.contact_frame.connect(func(side: String) -> void:
			events.append("stage_contact=" + side + "@%.1fms" % ((Time.get_ticks_usec() - start_us) / 1000.0)))
		if not game.combat.play_card(0):
			push_error("Cannot play " + card_id)
			quit(1)
			return
		var previous_frame := -1
		var previous_event_count := 0
		var previous_fx := false
		var samples: Array[String] = []
		for frame in 140:
			await process_frame
			var elapsed := (Time.get_ticks_usec() - start_us) / 1000.0
			if sprite.frame != previous_frame or frame % 6 == 0 \
					or events.size() != previous_event_count \
					or game.duel_stage._impact_fx.visible != previous_fx:
				samples.append("%.1fms sprite=%s:%d+%.2f sprite_time=%.3f clock=%s:%.3f x=%.3f fx=%s hud=%s" % [
					elapsed, sprite.animation, sprite.frame, sprite.frame_progress,
					actor.get_playback_time(), clock.current_animation,
					clock.current_animation_position,
					game.duel_stage.get_actor_anchor("player").position.x,
					game.duel_stage._impact_fx.visible, game.enemy_label.text.replace("\n", " ")])
			previous_frame = sprite.frame
			previous_event_count = events.size()
			previous_fx = game.duel_stage._impact_fx.visible
			if game.pending_presentations == 0:
				break
		print("HD2D_TIMING card=", card_id, " events=", events)
		for sample in samples:
			print("  ", sample)
		game.queue_free()
		await process_frame
	quit(0)
