extends SceneTree

const OUT := "res://../artifacts/godot-migration/qingyun-pixel-combat/"
const CARD_IDS := [
	"sword_probe", "sword_edge", "sword_followthrough",
	"sword_guard", "sword_sheath_guard",
]


func _initialize() -> void:
	call_deferred("_capture")


func _capture() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	root.size = Vector2i(1280, 800)
	for card_id in CARD_IDS:
		var battle: Control = load("res://scenes/main.tscn").instantiate()
		root.add_child(battle)
		Input.warp_mouse(Vector2(10, 10))
		await create_timer(0.45).timeout
		var stage: Node = battle.duel_stage
		var button: Button
		for child in battle.hand_row.get_children():
			if child is Button and child.get_meta("source_card_id", "") == card_id:
				button = child
				break
		if stage == null or button == null:
			push_error("Missing stage or card while capturing " + card_id)
			quit(1)
			return
		var contacts: Array[String] = []
		stage.contact_frame.connect(func(side: String) -> void: contacts.append(side))
		button.pressed.emit()
		for _sample in 100:
			if "player" in contacts:
				break
			await create_timer(0.02).timeout
		if not "player" in contacts:
			push_error("No contact while capturing " + card_id)
			quit(1)
			return
		await process_frame
		await RenderingServer.frame_post_draw
		if root.get_texture().get_image().save_png(OUT + "fx_" + card_id + ".png") != OK:
			push_error("Capture save failed for " + card_id)
			quit(1)
			return
		for _sample in 100:
			if battle.pending_presentations == 0 and not battle.combat.input_locked:
				break
			await create_timer(0.02).timeout
		battle.queue_free()
		await process_frame
	print("QINGYUN_FX_CAPTURE_PASS cards=5")
	quit(0)
