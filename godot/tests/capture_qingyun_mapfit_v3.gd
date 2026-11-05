extends SceneTree

const HERO_SOURCE := "res://assets/battle/undercurrent_pixel_v1/actor_mapfit_v3/player_idle_source.png"
const ENEMY_SOURCE := "res://assets/battle/undercurrent_pixel_v1/actor_mapfit_v3/enemy_idle_source.png"
const OUT := "res://../artifacts/godot-migration/qingyun-pixel-combat/mapfit_v3_study_1280.png"


func _initialize() -> void:
	call_deferred("_capture")


func _capture() -> void:
	root.size = Vector2i(1280, 800)
	var stage: Control = load("res://scenes/qingyun_pixel_battle_stage.tscn").instantiate()
	root.add_child(stage)
	await process_frame
	stage.get_actor_sprite("player").visible = false
	stage.get_actor_sprite("enemy").visible = false
	_mount(stage.get_node("Viewport/World/PlayerAnchor"), HERO_SOURCE, 60, 560)
	_mount(stage.get_node("Viewport/World/EnemyAnchor"), ENEMY_SOURCE, 66, 530)
	await create_timer(0.25).timeout
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT).get_base_dir())
	if root.get_texture().get_image().save_png(OUT) != OK:
		push_error("Map-fit study capture failed")
		quit(1)
		return
	print("QINGYUN_MAPFIT_V3_STUDY_PASS ", OUT)
	quit(0)


func _mount(anchor: Node2D, path: String, visible_height: int,
		pivot_x: int) -> void:
	var source := Image.load_from_file(ProjectSettings.globalize_path(path))
	assert(source != null and not source.is_empty())
	var box := _solid_rect(source)
	print("MAPFIT_SOURCE ", path.get_file(), " bbox=", box)
	var scale := float(visible_height) / float(box.size.y)
	var cropped := Image.create(box.size.x, box.size.y, false, Image.FORMAT_RGBA8)
	cropped.blit_rect(source, box, Vector2i.ZERO)
	cropped.resize(roundi(box.size.x * scale), visible_height, Image.INTERPOLATE_NEAREST)
	for y in cropped.get_height():
		for x in cropped.get_width():
			var pixel := cropped.get_pixel(x, y)
			if pixel.a < 0.52:
				cropped.set_pixel(x, y, Color.TRANSPARENT)
			else:
				cropped.set_pixel(x, y, Color(roundf(pixel.r * 31.0) / 31.0,
					roundf(pixel.g * 31.0) / 31.0,
					roundf(pixel.b * 31.0) / 31.0, 1.0))
	var sprite := Sprite2D.new()
	sprite.texture = ImageTexture.create_from_image(cropped)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.position = Vector2((float(box.position.x) - float(pivot_x)) * scale +
		float(cropped.get_width()) / 2.0, -float(visible_height) / 2.0)
	anchor.add_child(sprite)


func _solid_rect(source: Image) -> Rect2i:
	var low := Vector2i(source.get_width(), source.get_height())
	var high := Vector2i(-1, -1)
	for y in source.get_height():
		for x in source.get_width():
			if source.get_pixel(x, y).a >= 0.52:
				low.x = mini(low.x, x)
				low.y = mini(low.y, y)
				high.x = maxi(high.x, x)
				high.y = maxi(high.y, y)
	return Rect2i(low, high - low + Vector2i.ONE)
