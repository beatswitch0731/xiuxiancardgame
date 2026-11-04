extends SceneTree

# Desktop first-fight composition contract: fighters own the stage, while the
# hand and status views remain compact enough to reveal the authored hall.
const BattleScene = preload("res://scenes/main.tscn")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1280, 800)
	var battle: Control = BattleScene.instantiate()
	root.add_child(battle)
	for frame in 4:
		await process_frame
	var viewport_size := root.get_viewport().get_visible_rect().size
	if viewport_size != Vector2(1280, 800):
		_fail("Run the desktop composition check at 1280x800")
		return
	var hero: Node3D = battle.duel_stage.get_actor_model("player")
	var enemy: Node3D = battle.duel_stage.get_actor_model("enemy")
	var card: Button = battle.hand_row.get_child(0) as Button
	var tallest_card := 0.0
	for item in battle.hand_row.get_children():
		if item is Button:
			tallest_card = maxf(tallest_card, (item as Button).size.y)
	if hero.scale.y < 1.10 or enemy.scale.y < 1.0:
		_fail("Fighters remain too small in the first-fight camera")
		return
	if card.size.x > 106.0 or tallest_card > 176.0:
		_fail("A resting card competes with the fighter silhouettes: " + str(tallest_card))
		return
	var sprite: AnimatedSprite3D = battle.duel_stage.get_actor_sprite("player")
	var idle_image := sprite.sprite_frames.get_frame_texture("idle", 0).get_image()
	var ink_top := idle_image.get_height()
	var ink_bottom := -1
	for y in idle_image.get_height():
		for x in idle_image.get_width():
			if idle_image.get_pixel(x, y).a > 0.15:
				ink_top = mini(ink_top, y)
				ink_bottom = maxi(ink_bottom, y)
	var camera: Camera3D = battle.duel_stage.get_node("Viewport/World/CameraRig/Camera")
	var ink_world_height := float(ink_bottom - ink_top + 1) * sprite.pixel_size * hero.scale.y
	var actor_screen_height := absf(camera.unproject_position(sprite.global_position).y
		- camera.unproject_position(sprite.global_position + Vector3.UP * ink_world_height).y)
	if actor_screen_height < tallest_card * 1.30:
		_fail("The protagonist reads smaller than the playable card: " + str(actor_screen_height))
		return
	var hero_screen := camera.unproject_position(hero.global_position)
	var enemy_screen := camera.unproject_position(enemy.global_position)
	var fighter_gap := absf(enemy_screen.x - hero_screen.x)
	if actor_screen_height > 245.0 or fighter_gap < 500.0 \
			or fighter_gap > 650.0 or absf(enemy_screen.y - hero_screen.y) > 28.0:
		_fail("First-fight camera or initial spacing is too tight: height=%s gap=%s feet=%s/%s" % [
			actor_screen_height, fighter_gap, hero_screen.y, enemy_screen.y])
		return
	if battle.hand_row.position.y < viewport_size.y - 190.0:
		_fail("The hand occupies too much of the scene height")
		return
	if battle.card_table.size.x > 600.0 or battle.card_table.size.y > 70.0:
		_fail("The card rest remains wider or taller than the hand needs")
		return
	if battle.get_node("Header").visible or battle.player_info_back.size.x > 320.0 \
			or battle.enemy_info_back.size.x > 320.0 or battle.intent_slip.size.x > 320.0:
		_fail("Top combat furniture crowds the world view")
		return
	for label in [battle.player_label, battle.enemy_label]:
		var font: Font = label.get_theme_font("font")
		var text_width := font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT,
			-1, label.get_theme_font_size("font_size")).x
		if text_width > label.size.x:
			_fail("Compact fighter status cuts off a source value: " + label.text)
			return
	var short_rule_card: Button = battle.hand_row.get_child(2) as Button
	var inspect: Panel = short_rule_card.get_node("HoverDetail") as Panel
	if inspect.size.y > 110.0:
		_fail("A short card rule opens an oversized paper folio")
		return
	print("BATTLE_VISUAL_HIERARCHY_PASS hero_scale=", hero.scale.y,
		" actor_screen_height=", snappedf(actor_screen_height, 0.1),
		" fighter_gap=", snappedf(fighter_gap, 0.1),
		" tallest_card=", tallest_card, " desk=", battle.card_table.size,
		" status=", battle.player_info_back.size, " inspect=", inspect.size)
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
