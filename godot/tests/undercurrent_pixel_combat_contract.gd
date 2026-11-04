extends SceneTree

# The real sword teaching fight must mount the new room and keep combat authority.

func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1280, 800)
	var battle: Control = load("res://scenes/main.tscn").instantiate()
	root.add_child(battle)
	await process_frame
	var stage: Node = battle.duel_stage
	if stage == null or stage.name != "QingyunPixelStage":
		_fail("real first fight did not mount the enclosed pixel trial room")
		return
	if not stage.has_hd2d_assets() or stage.get_node_or_null("Viewport/World/QingyunRoomNative") == null:
		_fail("pixel trial room or source actors missing")
		return
	var hero: AnimatedSprite2D = stage.get_actor_sprite("player")
	var enemy: AnimatedSprite2D = stage.get_actor_sprite("enemy")
	if hero == null or enemy == null:
		_fail("source fighters were not mounted")
		return
	var hero_texture := hero.sprite_frames.get_frame_texture("idle", 0)
	var enemy_texture := enemy.sprite_frames.get_frame_texture("idle", 0)
	var hero_height := hero_texture.get_image().get_used_rect().size.y * hero.scale.y
	var enemy_height := enemy_texture.get_image().get_used_rect().size.y * enemy.scale.y
	if hero_height < 45.0 or enemy_height < 50.0 or hero_height / enemy_height > 1.4:
		_fail("fighter scale or hero/enemy body ratio is outside the battle composition")
		return
	var breath_scale := hero.scale
	var breath_frame := hero.frame
	await create_timer(0.65).timeout
	if hero.frame == breath_frame or hero.scale.distance_to(breath_scale) > 0.001:
		_fail("standing actor must breathe with cels while whole-body scale stays fixed")
		return
	if battle.hand_row.get_child_count() != 5:
		_fail("source first-fight hand changed")
		return
	var first := battle.hand_row.get_child(0) as Button
	if first == null or first.get_meta("source_card_id") != "sword_probe":
		_fail("source card identity changed")
		return
	first.pressed.emit()
	if not battle.enemy_label.text.contains("7/7"):
		_fail("damage appeared before contact")
		return
	for _sample in 90:
		if battle.enemy_label.text.contains("6/7"):
			break
		await create_timer(0.02).timeout
	if not battle.enemy_label.text.contains("6/7"):
		_fail("real card did not settle at visual contact")
		return
	var hit_fx: Node = stage.get_node("Viewport/World/HitFX")
	if hit_fx.get("last_profile") != "sword_probe":
		_fail("source card did not select its named contact effect profile")
		return
	print("UNDERCURRENT_PIXEL_COMBAT_CONTRACT_PASS stage=qingyun_pixel cards=5 breath=true contact=true")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
