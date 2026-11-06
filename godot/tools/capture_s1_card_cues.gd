extends SceneTree

const OUTPUT := "res://output/captures/godot-migration/hd2d-s1-card-cues/"
const CARDS := ["sword_probe", "sword_followthrough", "sword_edge",
	"sword_guard", "sword_sheath_guard"]


func _initialize() -> void:
	call_deferred("_capture")


func _capture() -> void:
	var directory := ProjectSettings.globalize_path(OUTPUT)
	DirAccess.make_dir_recursive_absolute(directory)
	for card_id in CARDS:
		var game: Control = load("res://scenes/main.tscn").instantiate()
		root.add_child(game)
		for frame in 16:
			await process_frame
		game.combat.state["hand"] = [card_id]
		game.combat.state["qi"] = 4
		game._render()
		var stage: Node = game.duel_stage
		var cues: Array[String] = []
		stage.contact_frame.connect(func(side: String) -> void: cues.append(side))
		if not game.combat.play_card(0):
			push_error("Card could not play: " + card_id)
			quit(1)
			return
		for frame in 100:
			if "player" in cues:
				break
			await process_frame
		if not "player" in cues:
			push_error("Contact cue missing: " + card_id)
			quit(1)
			return
		await RenderingServer.frame_post_draw
		var image := root.get_viewport().get_texture().get_image()
		if image == null or image.is_empty() or image.save_png(directory.path_join(card_id + ".png")) != OK:
			push_error("Screenshot failed: " + card_id)
			quit(1)
			return
		print("S1_CARD_CUE_CAPTURE ", card_id, " frame=",
			(stage.get_actor_sprite("player") as AnimatedSprite3D).frame,
			" effect=", (stage.get("_impact_fx") as Node3D).global_position)
		game.queue_free()
		await process_frame
	quit(0)
