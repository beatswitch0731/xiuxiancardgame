extends SceneTree

func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1280, 800)
	var scene: PackedScene = load("res://scenes/reference_battle_demo.tscn")
	if scene == null:
		_fail("reference battle demo scene is missing")
		return
	var battle: Control = scene.instantiate()
	root.add_child(battle)
	await process_frame
	if battle.duel_stage == null or battle.duel_stage.name != "DuelStageHD2D":
		_fail("reference frontend did not restore the previous HD-2D trial hall")
		return
	if not battle.duel_stage.use_reference_actor_style or not battle.duel_stage.reference_actor_style_ready:
		_fail("new JSON actor style was not mounted on the battle stage")
		return
	var hero_sprite: AnimatedSprite3D = battle.duel_stage.get_actor_sprite("player")
	var enemy_sprite: AnimatedSprite3D = battle.duel_stage.get_actor_sprite("enemy")
	if hero_sprite == null or enemy_sprite == null or \
			not hero_sprite.sprite_frames.get_meta("reference_actor_style_v1", false) or \
			not enemy_sprite.sprite_frames.get_meta("reference_actor_style_v1", false):
		_fail("new character idle source sprites were not applied")
		return
	var first_breath := hero_sprite.scale.y
	await create_timer(0.65).timeout
	if absf(hero_sprite.scale.y - first_breath) < 0.001:
		_fail("standing character has no visible breathing cycle")
		return
	var hud := battle.find_child("ReferenceBattleHUD", true, false) as Control
	if hud == null or not hud.visible:
		_fail("reference battle HUD was not mounted")
		return
	if battle.hand_row.get_child_count() != 5:
		_fail("source first-fight hand is missing")
		return
	var second := battle.hand_row.get_child(1) as Button
	if second == null:
		_fail("second source card is missing")
		return
	battle.hand_row.card_hovered.emit(1, true)
	if not _visible_text(hud).contains(String(battle.data.get_battle_card(
		String(second.get_meta("source_card_id"))).get("name", ""))):
		_fail("tactical panel does not reflect the hovered source card")
		return
	var first := battle.hand_row.get_child(0) as Button
	var first_name := String(battle.data.get_battle_card(
		String(first.get_meta("source_card_id"))).get("name", ""))
	first.pressed.emit()
	if not battle.combat.input_locked or not battle.enemy_label.text.contains("7/7"):
		_fail("damage appeared before source contact")
		return
	for _sample in 100:
		if battle.enemy_label.text.contains("6/7"):
			break
		await create_timer(0.02).timeout
	if not battle.enemy_label.text.contains("6/7") or not _visible_text(hud).contains(first_name):
		_fail("played-card record or contact feedback is missing")
		return
	root.size = Vector2i(1024, 768)
	await process_frame
	var right_panel := hud.find_child("TacticsPanel", true, false) as Control
	if right_panel == null or right_panel.get_global_rect().end.x > 1024.0:
		_fail("tactical panel clips outside the narrower viewport")
		return
	print("REFERENCE_BATTLE_FRONTEND_CONTRACT_PASS stage=hd2d_actor_v1 source_hand=true breathing=true hover=true contact=true narrow=true")
	quit(0)


func _visible_text(root_node: Node) -> String:
	var result := ""
	for label in root_node.find_children("*", "Label", true, false):
		if label.visible:
			result += String(label.text) + "\n"
	return result


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
