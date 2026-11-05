extends SceneTree

const FRAMES := "res://assets/battle/undercurrent_pixel_v1/actor_video_v4_study/hero_local_thrust.tres"
const OUT := "res://../artifacts/godot-migration/actor-identity-v4/"


func _initialize() -> void:
	call_deferred("_record")


func _record() -> void:
	root.size = Vector2i(1280, 800)
	var stage: SubViewportContainer = load("res://scenes/qingyun_pixel_battle_stage.tscn").instantiate()
	stage.get_node("Viewport/World/PlayerAnchor/Sprite").sprite_frames = load(FRAMES)
	stage.get_node("Viewport/World/EnemyAnchor").visible = false
	stage.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(stage)
	stage.get_node("Viewport/World/PlayerAnchor").position = Vector2(320, 244)
	var actor: AnimatedSprite2D = stage.get_actor_sprite("player")
	var caption := Label.new()
	caption.text = "新角色 · 原地伸刺与收剑检查\nGemini 真实抽帧；伸刺倒序、收剑正序。此处不含接敌、受击与伤害。"
	caption.position = Vector2(26, 24)
	caption.add_theme_font_size_override("font_size", 19)
	root.add_child(caption)
	await create_timer(0.6).timeout
	var capture_done := false
	actor.frame_changed.connect(func() -> void:
		if actor.animation == "local_thrust" and actor.frame == 6:
			print("LOCAL_THRUST_EXTENSION source_frame=37 no_damage_event=true")
	)
	for _cycle in 3:
		actor.play("local_thrust")
		while actor.is_playing():
			await RenderingServer.frame_post_draw
			if actor.frame == 6 and not capture_done:
				root.get_texture().get_image().save_png(OUT + "local_thrust_extension_1280.png")
				capture_done = true
		actor.play("idle")
		await create_timer(0.6).timeout
	if not capture_done:
		push_error("Did not observe the extended pose")
		quit(1)
		return
	print("ACTOR_V4_LOCAL_THRUST_RECORDED cycles=3 formal_scene_replaced=false")
	quit(0)
