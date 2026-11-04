extends SceneTree

# Isolated in-memory study; the shipping scene and actor resources are untouched.
# Large generated art is downsampled for a visual experiment, not final pixel art.
const BASE := "res://art_direction/candidates/mapfit_v4_20261030/"
const OUT := "res://../artifacts/godot-migration/qingyun-pixel-combat/"
const ANCHOR := Vector2i(64, 80)
const CANVAS := Vector2i(128, 96)
var contact_seen := false
var contact_frame := -1

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1280, 800)
	var battle: Control = load("res://scenes/main.tscn").instantiate()
	root.add_child(battle)
	await create_timer(0.8).timeout
	if battle.duel_stage == null or not battle.stage_assets_ready:
		push_error("Battle stage unavailable")
		quit(1)
		return
	var stage: Node = battle.duel_stage
	var hero: AnimatedSprite2D = stage.get_node("Viewport/World/PlayerAnchor/Sprite")
	var enemy: AnimatedSprite2D = stage.get_node("Viewport/World/EnemyAnchor/Sprite")
	var h_idle := _texture("yelingyun_concept.png", 50, 590.0)
	var h_breath := _texture("player_breathe_concept.png", 50, 590.0)
	var h_windup := _texture("player_windup_concept.png", 50, 610.0)
	var h_attack := _texture("player_thrust_concept.png", 50, 545.0)
	var e_idle := _texture("puppet_concept.png", 56, 530.0)
	var e_hurt := _texture("puppet_hurt_concept.png", 56, 530.0)
	if h_idle == null or h_breath == null or h_windup == null or h_attack == null or e_idle == null or e_hurt == null:
		push_error("Study image missing or invalid")
		quit(1)
		return
	var hero_frames: SpriteFrames = hero.sprite_frames.duplicate(true)
	_replace(hero_frames, "idle", [h_idle, h_breath, h_idle], [900, 900, 900], true)
	# Start the contact pose 20ms before the event so a render-frame boundary
	# cannot leave the idle pose visible when the 235ms event is dispatched.
	_replace(hero_frames, "sword_probe", [h_idle, h_windup, h_windup, h_attack, h_attack, h_idle], [90, 80, 45, 50, 100, 161], false)
	var enemy_frames: SpriteFrames = enemy.sprite_frames.duplicate(true)
	_replace(enemy_frames, "idle", [e_idle], [1000], true)
	_replace(enemy_frames, "hurt", [e_hurt, e_hurt, e_idle], [120, 120, 120], false)
	hero.sprite_frames = hero_frames
	enemy.sprite_frames = enemy_frames
	stage.set_process(false) # avoid whole-image scaling in this isolated study
	stage.set("player_attack_travel", 38.0)
	stage.set("player_hit_position", Vector2(410, 233))
	hero.scale = Vector2.ONE
	enemy.scale = Vector2.ONE
	hero.play("idle")
	enemy.play("idle")
	stage.call("_align_feet", hero)
	stage.call("_align_feet", enemy)
	stage.contact_frame.connect(func(side: String):
		if side == "player":
			contact_seen = true
			contact_frame = hero.frame
	)
	await create_timer(1.6).timeout
	await _save("mapfit_v4_motion_idle.png")
	(battle.hand_row.get_child(0) as Button).pressed.emit()
	for i in 120:
		if contact_seen:
			break
		await create_timer(0.01).timeout
	if not contact_seen:
		push_error("No player contact")
		quit(1)
		return
	if contact_frame < 3:
		push_error("Contact dispatched before thrust pose, frame=" + str(contact_frame))
		quit(1)
		return
	await _save("mapfit_v4_motion_contact.png")
	await create_timer(1.0).timeout
	print("V4_MOTION_STUDY contact_frame=", contact_frame, " enemy=", battle.enemy_label.text)
	if not battle.enemy_label.text.contains("6/7"):
		push_error("Probe did not settle as expected")
		quit(1)
		return
	quit(0)

func _replace(frames: SpriteFrames, name: String, images: Array, durations: Array, loop: bool) -> void:
	if frames.has_animation(name):
		frames.remove_animation(name)
	frames.add_animation(name)
	frames.set_animation_speed(name, 1000.0)
	frames.set_animation_loop(name, loop)
	for i in images.size():
		frames.add_frame(name, images[i], float(durations[i]))
		frames.set_meta("foot_%s_%d" % [name, i], float(ANCHOR.y) / CANVAS.y)
	frames.set_meta("scale_" + name, 1.0)

func _texture(filename: String, height: int, pivot_x: float) -> Texture2D:
	var source := Image.load_from_file(ProjectSettings.globalize_path(BASE + filename))
	if source == null or source.is_empty():
		return null
	var low := Vector2i(source.get_width(), source.get_height())
	var high := Vector2i(-1, -1)
	for y in source.get_height():
		for x in source.get_width():
			if source.get_pixel(x, y).a >= 0.52:
				low.x = mini(low.x, x)
				low.y = mini(low.y, y)
				high.x = maxi(high.x, x)
				high.y = maxi(high.y, y)
	if high.x < low.x or high.y < low.y:
		return null
	var box := Rect2i(low, high - low + Vector2i.ONE)
	var factor := float(height) / box.size.y
	var part := Image.create(box.size.x, box.size.y, false, Image.FORMAT_RGBA8)
	part.blit_rect(source, box, Vector2i.ZERO)
	part.resize(roundi(box.size.x * factor), height, Image.INTERPOLATE_NEAREST)
	var origin := Vector2i(ANCHOR.x - roundi((pivot_x - box.position.x) * factor), ANCHOR.y - height)
	if origin.x < 0 or origin.y < 0 or origin.x + part.get_width() > CANVAS.x:
		push_error("Study pose exceeds canvas: " + filename)
		return null
	var canvas := Image.create(CANVAS.x, CANVAS.y, false, Image.FORMAT_RGBA8)
	canvas.fill(Color.TRANSPARENT)
	canvas.blit_rect(part, Rect2i(Vector2i.ZERO, part.get_size()), origin)
	return ImageTexture.create_from_image(canvas)

func _save(filename: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT + filename)
