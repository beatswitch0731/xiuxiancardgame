extends SceneTree

const Demo = preload("res://scenes/equipment_demo.tscn")
const OUT := "res://art_direction/candidates/equipment_demo_20261022/evidence/"

func _initialize() -> void:
	call_deferred("_capture")

func _capture() -> void:
	root.size = Vector2i(1280, 800)
	var demo: Control = Demo.instantiate()
	root.add_child(demo)
	await create_timer(1.0).timeout
	if not demo.actor.ready_assets:
		push_error("Equipment review assets missing")
		quit(1)
		return
	demo.actor.set_playback_paused(true)
	demo.actor.seek_pose("idle", 0)
	await _save("visual_review_idle.png")
	demo._source_button.pressed.emit()
	await _save("visual_review_rules.png")
	demo._source_button.pressed.emit()
	demo.actor.seek_pose("guard", 2)
	await _save("visual_review_guard.png")
	demo.actor.seek_pose("idle", 0)
	root.size = Vector2i(1234, 814)
	await _save("visual_review_1234_idle.png")
	root.size = Vector2i(1024, 768)
	await _save("visual_review_1024_idle.png")
	root.size = Vector2i(1280, 800)
	for slot in ["weapon", "armor"]:
		var target := "brokenSword" if slot == "weapon" else "灵纹法袍"
		var selector: OptionButton = demo.selectors[slot]
		var index: int = demo.SLOT_ITEMS[slot].find(target)
		selector.select(index)
		selector.item_selected.emit(index)
	demo.actor.seek_pose("idle", 0)
	await _save("visual_review_broken_idle.png")
	demo.actor.seek_pose("guard", 2)
	await _save("visual_review_broken_guard.png")
	print("EQUIPMENT_VISUAL_REVIEW_CAPTURE_PASS")
	quit(0)

func _save(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var error := root.get_texture().get_image().save_png(OUT + name)
	if error != OK:
		push_error("Equipment review capture failed: " + name)
