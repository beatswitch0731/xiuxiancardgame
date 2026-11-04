extends SceneTree

# Real first-battle render: captures the paper settling, resting in a breeze,
# then receiving the next authoritative enemy intent after End Turn.
const BattleScene = preload("res://scenes/main.tscn")
const OUTPUT := "res://../artifacts/godot-migration/first-fight-backend-qa/intent-slip-motion-v1"


func _initialize() -> void:
	call_deferred("_capture")


func _capture() -> void:
	var game: Control = BattleScene.instantiate()
	root.add_child(game)
	for frame in 3:
		await process_frame
	var initial_revision: int = game.intent_slip.intent_revision
	var output_absolute := ProjectSettings.globalize_path(OUTPUT)
	DirAccess.make_dir_recursive_absolute(output_absolute)
	var saved := 0
	for tick in range(72):
		await process_frame
		if tick == 30:
			if not game.combat.end_turn():
				push_error("Could not trigger the next authoritative battle intent")
				quit(1)
				return
		if tick % 3 != 0:
			continue
		await RenderingServer.frame_post_draw
		var image: Image = root.get_viewport().get_texture().get_image()
		if image == null or image.is_empty():
			push_error("Battle intent capture returned an empty frame")
			quit(1)
			return
		var slip_rect: Rect2 = game.intent_slip.get_global_rect()
		var crop := Rect2i(int(slip_rect.position.x) - 10, int(slip_rect.position.y) - 12, 385, 140)
		var frame_image := image.get_region(crop)
		var error := frame_image.save_png(output_absolute.path_join("frame_%02d.png" % saved))
		if error != OK:
			push_error("Could not save the battle intent frame: " + str(error))
			quit(1)
			return
		var status_rect: Rect2 = game.state_slip_anchor.get_global_rect()
		var status_crop := Rect2i(int(status_rect.position.x) - 8,
			int(status_rect.position.y) - 12, 200, 76)
		var status_image := image.get_region(status_crop)
		error = status_image.save_png(output_absolute.path_join("status_%02d.png" % saved))
		if error != OK:
			push_error("Could not save the battle status frame: " + str(error))
			quit(1)
			return
		saved += 1
	if game.intent_slip.intent_revision <= initial_revision:
		push_error("End Turn did not update the visible paper intent")
		quit(1)
		return
	print("BATTLE_INTENT_MOTION_CAPTURE_PASS frames=", saved,
		" revision=", game.intent_slip.intent_revision,
		" output=", output_absolute)
	quit(0)
