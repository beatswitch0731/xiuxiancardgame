extends SceneTree

# Acceptance probe through the same CombatDomain.play_card entry used by the UI.
# These source-frame pixel coordinates were inspected on the original S1 PNGs.
const BLADE_PIXEL := {
	"sword_probe": Vector2(319, 173),
	"sword_followthrough": Vector2(321, 208),
	"sword_edge": Vector2(353, 221),
}
const EXPECTED_FRAME := {
	"sword_probe": 3,
	"sword_followthrough": 1,
	"sword_edge": 2,
}


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: Array[String] = []
	var cases := [
		{"card": "sword_probe", "yaw": 0.0},
		{"card": "sword_probe", "yaw": -20.0},
		{"card": "sword_probe", "yaw": 20.0},
		{"card": "sword_followthrough", "yaw": 0.0},
		{"card": "sword_edge", "yaw": 0.0},
		{"card": "sword_guard", "yaw": 0.0},
		{"card": "sword_sheath_guard", "yaw": 0.0},
	]
	for case in cases:
		var card_id: String = case["card"]
		var yaw: float = case["yaw"]
		var game: Control = load("res://scenes/main.tscn").instantiate()
		root.add_child(game)
		for frame in 8:
			await process_frame
		game.combat.state["hand"] = [card_id]
		game.combat.state["qi"] = 4
		game._render()
		var stage: Node = game.duel_stage
		stage.set_diagnostic_yaw(yaw)
		var contacts: Array[String] = []
		stage.contact_frame.connect(func(side: String) -> void: contacts.append(side))
		if not game.combat.play_card(0):
			failures.append(card_id + ": card failed to play")
		else:
			for frame in 100:
				if "player" in contacts:
					break
				await process_frame
			if not "player" in contacts:
				failures.append(card_id + ": no player contact cue")
			else:
				var hero: Node3D = stage.get_actor_model("player")
				var sprite: AnimatedSprite3D = hero.get_sprite()
				var effect: Node3D = stage.get("_impact_fx")
				if not effect.visible:
					failures.append(card_id + ": no visible contact effect")
				if BLADE_PIXEL.has(card_id):
					var frame_index: int = EXPECTED_FRAME[card_id]
					if sprite.frame != frame_index:
						failures.append("%s: contact on frame %d instead of visible strike frame %d" % [card_id, sprite.frame, frame_index])
					else:
						var frames: SpriteFrames = sprite.sprite_frames
						var canvas := float(frames.get_meta("canvas_%s_%d" % [card_id, frame_index]))
						var point: Vector2 = BLADE_PIXEL[card_id]
						var camera: Camera3D = stage.get_node("Viewport/World/CameraRig/Camera")
						var camera_basis := camera.global_transform.basis.orthonormalized()
						var actor_scale := hero.global_transform.basis.get_scale()
						var visible_tip := sprite.global_position \
							+ camera_basis.x * ((point.x - canvas * 0.5) * sprite.pixel_size * actor_scale.x) \
							+ camera_basis.y * ((canvas * 0.5 - point.y) * sprite.pixel_size * actor_scale.y)
						var target: Node3D = stage.get_actor_model("enemy")
						var chest: Vector3 = target.get_chest_point_for("hurt", 0, camera)
						var distance := visible_tip.distance_to(chest)
						if distance > 0.45:
							failures.append("%s yaw %.0f: visible blade tip is %.2fm from target" % [card_id, yaw, distance])
						if effect.global_position.distance_to(visible_tip) > 0.30:
							failures.append("%s yaw %.0f: spark is not on visible blade" % [card_id, yaw])
				else:
					var hero_chest: Vector3 = hero.get_chest_hit().global_position
					if effect.global_position.distance_to(hero_chest) > 0.80:
						failures.append(card_id + ": self guard effect is away from hero")
		# Repeating the same clip after F9 must resample its camera-space blade;
		# separate new-scene yaw cases cannot catch a stale cached destination.
		if card_id == "sword_probe" and is_zero_approx(yaw) and "player" in contacts:
			for frame in 100:
				if not bool(stage.get("_draining")):
					break
				await process_frame
			if bool(stage.get("_draining")):
				failures.append("repeat probe: first presentation did not finish")
			else:
				stage.set_diagnostic_yaw(20.0)
				if not (stage.get("_sampled_contact_tips") as Dictionary).is_empty():
					failures.append("repeat probe: yaw change left a stale blade sample")
				game.combat.state["hand"] = [card_id]
				game.combat.state["qi"] = 4
				game._render()
				contacts.clear()
				if not game.combat.play_card(0):
					failures.append("repeat probe: second source card failed to play")
				else:
					for frame in 100:
						if "player" in contacts:
							break
						await process_frame
					if not "player" in contacts:
						failures.append("repeat probe: second contact was missing")
					else:
						var impact: Node3D = stage.get("_impact_fx")
						var target: Node3D = stage.get_actor_model("enemy")
						var camera: Camera3D = stage.get_node("Viewport/World/CameraRig/Camera")
						if impact.global_position.distance_to(target.get_chest_point_for("hurt", 0, camera)) > 0.45:
							failures.append("repeat probe: rotated strike missed the dummy")
		game.queue_free()
		await process_frame
	for failure in failures:
		push_error(failure)
	print("S1_CONTACT_ALIGNMENT ", "PASS" if failures.is_empty() else "FAIL", " count=", failures.size())
	quit(0 if failures.is_empty() else 1)
