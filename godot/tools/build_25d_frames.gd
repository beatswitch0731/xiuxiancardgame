extends SceneTree

# Rebuild only authored sprite resources from the two immutable six-cell sheets.
# The PNGs contain the visible art; this script only configures AtlasTexture
# regions and animation timing.  No pixels are generated or changed here.

const CELL := Vector2i(512, 512)
const SHEET_COLUMNS := 3


func _initialize() -> void:
	var hero_sheet: Texture2D = load("res://assets/battle/25d/hero_swordsman_v1.png")
	var puppet_sheet: Texture2D = load("res://assets/battle/25d/wood_puppet_v1.png")
	if hero_sheet == null or puppet_sheet == null:
		push_error("2.5D authored sprite sheets are missing")
		quit(1)
		return
	if hero_sheet.get_size() != Vector2(1536, 1024) or puppet_sheet.get_size() != Vector2(1536, 1024):
		push_error("2.5D sprite sheets must be 1536x1024 with a 3x2 cell grid")
		quit(1)
		return
	var hero_image := hero_sheet.get_image()
	var puppet_image := puppet_sheet.get_image()

	var hero := SpriteFrames.new()
	hero.remove_animation("default")
	_store_feet(hero, hero_image)
	_add_clip(hero, hero_sheet, "idle", [0, 5], 2.0, true)
	_add_clip(hero, hero_sheet, "attack", [1, 2, 3, 4, 5], 10.0, false)
	_add_clip(hero, hero_sheet, "sword_probe", [1, 2, 4, 5], 12.0, false)
	_add_clip(hero, hero_sheet, "sword_followthrough", [1, 2, 3, 4, 5], 10.0, false)
	_add_clip(hero, hero_sheet, "sword_edge", [1, 3, 4, 5], 9.0, false)
	_add_clip(hero, hero_sheet, "guard", [0, 1, 0], 6.0, false)
	_add_clip(hero, hero_sheet, "sword_guard", [0, 1, 0], 6.0, false)
	_add_clip(hero, hero_sheet, "sword_sheath_guard", [0, 1, 0], 6.0, false)
	_add_clip(hero, hero_sheet, "reaction", [0, 1, 0], 8.0, false)
	_add_clip(hero, hero_sheet, "hurt", [4, 0], 8.0, false)
	_add_clip(hero, hero_sheet, "defeat", [4], 5.0, false)

	var puppet := SpriteFrames.new()
	puppet.remove_animation("default")
	_store_feet(puppet, puppet_image)
	_add_clip(puppet, puppet_sheet, "idle", [0], 2.0, true)
	_add_clip(puppet, puppet_sheet, "attack", [1, 2, 0], 8.0, false)
	_add_clip(puppet, puppet_sheet, "guard", [4, 0], 6.0, false)
	_add_clip(puppet, puppet_sheet, "hurt", [3, 0], 7.0, false)
	_add_clip(puppet, puppet_sheet, "defeat", [3, 5], 5.0, false)

	var hero_code := ResourceSaver.save(hero, "res://assets/battle/25d/hero_swordsman_v1.tres")
	var puppet_code := ResourceSaver.save(puppet, "res://assets/battle/25d/wood_puppet_v1.tres")
	if hero_code != OK or puppet_code != OK:
		push_error("Could not save 2.5D SpriteFrames resources: %s / %s" % [hero_code, puppet_code])
		quit(1)
		return
	print("SPRITE_FRAMES_READY hero=", hero.get_animation_names().size(), " puppet=", puppet.get_animation_names().size())
	quit()


func _add_clip(frames: SpriteFrames, sheet: Texture2D, clip: String,
		indices: Array, fps: float, loop: bool) -> void:
	frames.add_animation(clip)
	frames.set_animation_speed(clip, fps)
	frames.set_animation_loop(clip, loop)
	for frame_pos in indices.size():
		var index_value = indices[frame_pos]
		var index := int(index_value)
		var atlas := AtlasTexture.new()
		atlas.atlas = sheet
		atlas.region = Rect2(index % SHEET_COLUMNS * CELL.x,
			index / SHEET_COLUMNS * CELL.y, CELL.x, CELL.y)
		atlas.filter_clip = true
		frames.add_frame(clip, atlas)
		frames.set_meta("cell_%s_%d" % [clip, frame_pos], index)


func _store_feet(frames: SpriteFrames, image: Image) -> void:
	for cell in 6:
		var left := cell % SHEET_COLUMNS * CELL.x
		var top := cell / SHEET_COLUMNS * CELL.y
		var bottom := CELL.y
		for local_y in range(CELL.y - 1, -1, -1):
			var found := false
			for local_x in CELL.x:
				if image.get_pixel(left + local_x, top + local_y).a >= 0.5:
					found = true
					break
			if found:
				bottom = local_y + 1
				break
		frames.set_meta("feet_%d" % cell, bottom)
