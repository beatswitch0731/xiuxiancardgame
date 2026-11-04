extends SceneTree

# Isolated in-memory study; the shipping scene and actor resources are untouched.
# Large generated art is downsampled for a visual experiment, not final pixel art.
const BASE := "res://art_direction/candidates/mapfit_v5_20261030/"
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
	var h_idle := _texture("hero_idle.png", 52, 675.0)
	var h_breath := h_idle
	var h_windup := _texture("hero_windup.png", 52, 675.0)
	var h_attack := _texture("hero_attack.png", 52, 675.0)
	var e_idle := _texture("enemy_idle.png", 56, 670.0)
	var e_hurt := _texture("enemy_hurt.png", 56, 670.0)
	if h_idle == null or h_breath == null or h_windup == null or h_attack == null or e_idle == null or e_hurt == null:
		push_error("Study image missing or invalid")
		quit(1)
		return
	var hero_frames: SpriteFrames = hero.sprite_frames.duplicate(true)
	_replace(hero_frames, "idle", [h_idle, h_breath, h_idle], [900, 900, 900], true)
	# Reserve 250ms of presentation for traversing the larger floor distance.
	_replace(hero_frames, "sword_probe", [h_idle, h_idle, h_windup, h_windup, h_attack, h_attack, h_idle], [250, 90, 80, 45, 50, 100, 161], false)
	var enemy_frames: SpriteFrames = enemy.sprite_frames.duplicate(true)
	_replace(enemy_frames, "idle", [e_idle], [1000], true)
	_replace(enemy_frames, "hurt", [e_hurt, e_hurt, e_idle], [120, 120, 120], false)
	hero.sprite_frames = hero_frames
	enemy.sprite_frames = enemy_frames
	stage.set_process(false) # avoid whole-image scaling in this isolated study
	stage.set("player_home", Vector2(285, 244))
	stage.set("enemy_home", Vector2(425, 237))
	stage.set("player_attack_travel", 100.0)
	stage.set("player_hit_position", Vector2(420, 209))
	var contact_clock: Dictionary = stage.get("_source_contact_ms")
	contact_clock["player:sword_probe"] = 485
	var hero_anchor: Node2D = stage.get_node("Viewport/World/PlayerAnchor")
	var enemy_anchor: Node2D = stage.get_node("Viewport/World/EnemyAnchor")
	hero_anchor.position = Vector2(285, 244)
	enemy_anchor.position = Vector2(425, 237)
	hero_anchor.get_node("Shadow").scale = Vector2(0.6, 0.65)
	enemy_anchor.get_node("Shadow").scale = Vector2(0.6, 0.65)
	var fx: Node = stage.get_node("Viewport/World/HitFX")
	fx.set_script(load("res://tests/mapfit_v6_probe_fx.gd"))
	var fx_doc: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://assets/undercurrent_pixel_v1/skill_fx_profiles_v1.json"))
	if not fx.call("configure", fx_doc):
		push_error("Study FX configuration failed")
		quit(1)
		return
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
			enemy.modulate = Color(1.8, 1.8, 1.8, 1.0)
			var flash := create_tween()
			flash.tween_property(enemy, "modulate", Color.WHITE, 0.10)
			var recoil := create_tween()
			recoil.tween_property(enemy_anchor, "position", Vector2(429, 237), 0.07).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			recoil.tween_property(enemy_anchor, "position", Vector2(425, 237), 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	)
	await create_timer(1.6).timeout
	await _save("mapfit_v6_spacing_idle.png")
	(battle.hand_row.get_child(0) as Button).pressed.emit()
	for i in 120:
		if contact_seen:
			break
		await create_timer(0.01).timeout
	if not contact_seen:
		push_error("No player contact")
		quit(1)
		return
	if contact_frame < 4:
		push_error("Contact dispatched before thrust pose, frame=" + str(contact_frame))
		quit(1)
		return
	await _save("mapfit_v6_spacing_contact.png")
	await create_timer(0.08).timeout
	await _save("mapfit_v6_spacing_recoil.png")
	await create_timer(1.0).timeout
	print("V6_SPACING_STUDY contact_frame=", contact_frame, " enemy=", battle.enemy_label.text)
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
