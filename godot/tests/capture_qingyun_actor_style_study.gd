extends SceneTree

const OUT := "res://../artifacts/godot-migration/qingyun-pixel-combat/actor_style_study_1280.png"
const HERO := preload("res://assets/battle/undercurrent_pixel_v1/actor_design/yelingyun_s1_idle_concept_v1.png")
const ENEMY := preload("res://assets/battle/undercurrent_pixel_v1/actor_design/quick_sword_dummy_idle_concept_v1.png")


func _initialize() -> void:
	call_deferred("_capture")


func _capture() -> void:
	root.size = Vector2i(1280, 800)
	var stage: Control = load("res://scenes/qingyun_pixel_battle_stage.tscn").instantiate()
	root.add_child(stage)
	await process_frame
	stage.get_actor_sprite("player").visible = false
	stage.get_actor_sprite("enemy").visible = false
	_mount(stage.get_node("Viewport/World/PlayerAnchor"), HERO, 60.0, 941.0)
	_mount(stage.get_node("Viewport/World/EnemyAnchor"), ENEMY, 75.0, 1031.0)
	await create_timer(0.25).timeout
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT).get_base_dir())
	if root.get_texture().get_image().save_png(OUT) != OK:
		push_error("Actor style study capture failed")
		quit(1)
		return
	print("QINGYUN_ACTOR_STYLE_STUDY_PASS hero=60px enemy=75px")
	quit(0)


func _mount(anchor: Node2D, texture: Texture2D, visible_height: float,
		opaque_source_height: float) -> void:
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.scale = Vector2.ONE * (visible_height / opaque_source_height)
	sprite.offset = Vector2(0, -texture.get_height() / 2.0)
	anchor.add_child(sprite)
