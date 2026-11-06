extends SceneTree

# Read-only visual study: temporarily overlays concept images on the real stage.
# These large generated concepts are not native production sprites.
const BASE := "res://art_direction/candidates/mapfit_v4_20261030/"
const OUT := "res://tests/fixtures/artifacts/godot-migration/qingyun-pixel-combat/mapfit_v4_godot_study.png"

func _initialize() -> void:
	call_deferred("_capture")

func _capture() -> void:
	root.size = Vector2i(1280, 800)
	var battle: Control = load("res://scenes/main.tscn").instantiate()
	root.add_child(battle)
	await create_timer(0.8).timeout
	if battle.duel_stage == null or not battle.stage_assets_ready:
		push_error("Battle stage not ready")
		quit(1)
		return
	var stage: Node = battle.duel_stage
	if not _overlay(stage, "PlayerAnchor", "yelingyun_concept.png", 50.0, false):
		quit(1)
		return
	if not _overlay(stage, "EnemyAnchor", "puppet_concept.png", 56.0, true):
		quit(1)
		return
	await process_frame
	await RenderingServer.frame_post_draw
	var error := root.get_texture().get_image().save_png(OUT)
	if error != OK:
		push_error("Could not save study")
		quit(1)
		return
	print("MAPFIT_V4_GODOT_STUDY_SAVED")
	quit(0)

func _overlay(stage: Node, anchor_name: String, filename: String, height: float, flip: bool) -> bool:
	var anchor: Node2D = stage.get_node("Viewport/World/" + anchor_name)
	var image := Image.load_from_file(ProjectSettings.globalize_path(BASE + filename))
	if image == null or image.is_empty():
		push_error("Missing concept " + filename)
		return false
	var bounds := _solid_rect(image)
	if bounds.size.y < 1:
		push_error("Empty concept " + filename)
		return false
	anchor.get_node("Sprite").visible = false
	var sprite := Sprite2D.new()
	sprite.texture = ImageTexture.create_from_image(image)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.centered = false
	var factor := height / float(bounds.size.y)
	sprite.scale = Vector2(-factor if flip else factor, factor)
	var center_x := bounds.position.x + bounds.size.x / 2.0
	sprite.position = Vector2(center_x * factor if flip else -center_x * factor,
		-(bounds.position.y + bounds.size.y) * factor)
	anchor.add_child(sprite)
	return true

func _solid_rect(image: Image) -> Rect2i:
	var low := Vector2i(image.get_width(), image.get_height())
	var high := Vector2i(-1, -1)
	for y in image.get_height():
		for x in image.get_width():
			if image.get_pixel(x, y).a >= 0.52:
				low.x = mini(low.x, x)
				low.y = mini(low.y, y)
				high.x = maxi(high.x, x)
				high.y = maxi(high.y, y)
	if high.x < low.x or high.y < low.y:
		return Rect2i()
	return Rect2i(low, high - low + Vector2i.ONE)
