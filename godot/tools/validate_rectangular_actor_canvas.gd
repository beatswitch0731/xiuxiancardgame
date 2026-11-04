extends SceneTree

# Regression: a 256x320 frame must use width for the blade's horizontal
# center and height for the grounded feet and vertical blade coordinate.


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var actor := Node3D.new()
	actor.name = "RectangularActorProbe"
	actor.set_script(load("res://scripts/hd2d_sprite_fighter.gd"))
	var sprite := AnimatedSprite3D.new()
	sprite.name = "AnimatedSprite3D"
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	var canvas := Image.create(256, 320, false, Image.FORMAT_RGBA8)
	canvas.fill(Color.TRANSPARENT)
	var texture := ImageTexture.create_from_image(canvas)
	for clip in ["idle", "sword_probe"]:
		frames.add_animation(clip)
		frames.set_animation_loop(clip, clip == "idle")
		frames.add_frame(clip, texture)
	frames.set_meta("foot_idle_0", 0.9)
	frames.set_meta("foot_sword_probe_0", 0.9)
	frames.set_meta("canvas_sword_probe_0", 320)
	frames.set_meta("canvas_width_sword_probe_0", 256)
	frames.set_meta("canvas_height_sword_probe_0", 320)
	sprite.sprite_frames = frames
	actor.add_child(sprite)
	var animation_player := AnimationPlayer.new()
	animation_player.name = "AnimationPlayer"
	actor.add_child(animation_player)
	var blade := Marker3D.new()
	blade.name = "SwordTip"
	actor.add_child(blade)
	var chest := Marker3D.new()
	chest.name = "ChestHit"
	actor.add_child(chest)
	root.add_child(actor)
	await process_frame
	sprite.stop()
	sprite.animation = "sword_probe"
	sprite.frame = 0
	actor.call("_align_feet")
	var expected_x := (226.0 - 128.0) * 0.009
	var expected_y := (0.9 * 320.0 - 238.0) * 0.009
	var expected_base := (0.9 - 0.5) * 320.0 * 0.009
	var failures: Array[String] = []
	if absf(blade.position.x - expected_x) > 0.0001:
		failures.append("blade X uses frame height instead of width")
	if absf(blade.position.y - expected_y) > 0.0001:
		failures.append("blade Y misses the foot anchor")
	if absf(sprite.position.y - expected_base) > 0.0001:
		failures.append("sprite base misses the foot anchor")
	# A reviewed 32-frame candidate supplies per-frame tip pixels. The new
	# metadata must override the six-frame source fallback, including when
	# the candidate frame canvas is rectangular.
	frames.set_meta("blade_tip_sword_probe_0", Vector2(200.0, 240.0))
	actor.call("_align_feet")
	var authored_x := (200.0 - 128.0) * 0.009
	var authored_y := (0.9 * 320.0 - 240.0) * 0.009
	if absf(blade.position.x - authored_x) > 0.0001 or absf(blade.position.y - authored_y) > 0.0001:
		failures.append("reviewed frame blade tip metadata was ignored")
	for failure in failures:
		push_error(failure)
	print("RECTANGULAR_ACTOR_CANVAS ", "PASS" if failures.is_empty() else "FAIL",
		" authored_x=", blade.position.x, " expected_x=", authored_x)
	quit(0 if failures.is_empty() else 1)
