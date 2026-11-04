extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var demo = load("res://scenes/actor_wearable_demo.tscn").instantiate()
	root.add_child(demo)
	await create_timer(1.0).timeout
	await save_frame("base_idle")
	demo.sword_button.pressed.emit()
	await create_timer(0.5).timeout
	await save_frame("sword_idle")
	demo.armor_button.pressed.emit()
	await create_timer(0.3).timeout
	await save_frame("armor_idle")
	demo.attack()
	await create_timer(0.65).timeout
	await save_frame("armor_attack")
	await create_timer(1.0).timeout
	await save_frame("armor_recovered")
	demo.turn_slider.value = 0
	demo.play_motion("Idle")
	await create_timer(0.3).timeout
	await save_frame("armor_front")
	demo.turn_slider.value = 180
	await create_timer(0.3).timeout
	await save_frame("armor_back")
	demo.turn_slider.value = 96.81
	demo.play_motion("Crouch_Idle")
	await create_timer(0.5).timeout
	await save_frame("armor_crouch")
	demo.play_motion("Sword_Ready")
	demo.toggle_close_view()
	await create_timer(0.5).timeout
	await save_frame("armor_detail")
	demo.armor_button.pressed.emit()
	await create_timer(0.25).timeout
	await save_frame("cloth_detail")
	print("WEARABLE_CAPTURE_COMPLETE")
	quit()

func save_frame(label: String) -> void:
	await RenderingServer.frame_post_draw
	var path := "res://../artifacts/godot-migration/wearable-v3/" + label + ".png"
	root.get_texture().get_image().save_png(path)
	print("WEARABLE_CAPTURE ", label)
