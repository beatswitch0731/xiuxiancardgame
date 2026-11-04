extends SceneTree


func _initialize() -> void:
	call_deferred("_record")


func _record() -> void:
	root.size = Vector2i(1280, 800)
	var battle: Control = load("res://scenes/main.tscn").instantiate()
	root.add_child(battle)
	Input.warp_mouse(Vector2(10, 10))
	await create_timer(2.2).timeout
	if battle.duel_stage == null or not battle.stage_assets_ready:
		push_error("Qingyun pixel movie stage did not load")
		quit(1)
		return
	(battle.hand_row.get_child(0) as Button).pressed.emit()
	for _sample in 120:
		if battle.pending_presentations == 0 and not battle.combat.input_locked:
			break
		await create_timer(0.02).timeout
	if not battle.enemy_label.text.contains("6/7"):
		push_error("Qingyun pixel movie card did not settle")
		quit(1)
		return
	await create_timer(0.8).timeout
	print("QINGYUN_PIXEL_COMBAT_MOVIE_PASS")
	quit(0)
