extends SceneTree

const BattleScene = preload("res://scenes/reference_battle_demo.tscn")


func _initialize() -> void:
	call_deferred("_record")


func _record() -> void:
	root.size = Vector2i(1280, 800)
	var battle: Control = BattleScene.instantiate()
	root.add_child(battle)
	Input.warp_mouse(Vector2(12, 12))
	await process_frame
	if battle.duel_stage == null or not battle.duel_stage.reference_actor_style_ready:
		push_error("Reference breathing scene did not load")
		quit(1)
		return
	for _frame in 102:
		await process_frame
	print("REFERENCE_BREATH_RECORD_PASS")
	quit(0)
