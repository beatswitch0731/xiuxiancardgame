extends "res://tests/record_actor_video_v4_study.gd"

const MATERIAL_SPEC := "res://assets/undercurrent_pixel_v1/actor_material_v5_study/material_study.json"
const MATERIAL_OUT := "res://../artifacts/godot-migration/actor-material-v5/"
var _old_frames: Dictionary = {}
var _new_frames: Dictionary = {}
var _guides: Node2D
var _measurements: Dictionary = {}
var _size_tag := "1280"
var _layout: Dictionary = {}
var _scene_reuse := false
var _occlusion_index := 0
const REUSE_OUT := "res://../artifacts/godot-migration/scene-reuse-v1/"


func _review() -> void:
	var interactive := _live
	_live = true
	await super._review()
	_live = interactive
	_scene_reuse = "--scene-reuse" in OS.get_cmdline_user_args()
	if "--review-1024" in OS.get_cmdline_user_args():
		root.size = Vector2i(1024, 768)
		_size_tag = "1024"
		await process_frame
	var spec: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(MATERIAL_SPEC))
	for name in ["hero", "dummy"]:
		_old_frames[name] = _actors[name].sprite_frames
		var info: Dictionary = spec["actors"][name]
		var frames := SpriteFrames.new()
		frames.remove_animation("default")
		frames.add_animation("idle")
		frames.add_frame("idle", load(info["texture"]))
		frames.set_meta("pivot_x", info["pivot"][0])
		frames.set_meta("pivot_y", info["pivot"][1])
		frames.set_meta("left_foot_idle_0", Vector2(info["feet"][0][0], info["feet"][0][1]))
		frames.set_meta("right_foot_idle_0", Vector2(info["feet"][1][0], info["feet"][1][1]))
		frames.set_meta("grounded_idle_0", ["left", "right"])
		_new_frames[name] = frames
	_layout = _stage.get_scene_layout("symmetric")
	_make_guides()
	if _scene_reuse:
		_caption.position = Vector2(24, 170)
		_select_scene_layout("symmetric")
		if not _live:
			await _record_scene_reuse()
		return
	if _live:
		_apply_variant(3)
		return
	for variant in [1, 2, 3]:
		_apply_variant(variant)
		await create_timer(0.2).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(MATERIAL_OUT + "variant_%d_%s.png" % [variant, _size_tag])
		_measurements[str(variant)] = _support_positions()
	_guides.visible = true
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(MATERIAL_OUT + "alignment_guides_%s.png" % _size_tag)
	_guides.visible = false
	var points := _support_positions()
	var midpoint: Vector2 = (points["hero"] + points["dummy"]) * 0.5
	if midpoint.distance_to(Vector2(320, 244)) > 0.01 or absf(points["hero"].y - points["dummy"].y) > 0.01:
		push_error("Actual instance support centers are not symmetric/on the same baseline")
		quit(1)
		return
	var evidence := FileAccess.open(MATERIAL_OUT + "support_positions_%s.json" % _size_tag, FileAccess.WRITE)
	evidence.store_string(JSON.stringify(_measurements, "\t"))
	print("ACTOR_MATERIAL_V5_CAPTURED hero_support=", points["hero"], " dummy_support=", points["dummy"], " static_only=true formal_scene_replaced=false")
	quit(0)


func _apply_variant(variant: int) -> void:
	for name in ["hero", "dummy"]:
		var sprite: AnimatedSprite2D = _actors[name]
		sprite.sprite_frames = _new_frames[name] if variant == 3 else _old_frames[name]
		sprite.play("idle")
		var frames := sprite.sprite_frames
		var pivot := Vector2(frames.get_meta("pivot_x"), frames.get_meta("pivot_y"))
		var foot_mid: Vector2 = (frames.get_meta("left_foot_idle_0") + frames.get_meta("right_foot_idle_0")) * 0.5
		var anchor: Node2D = sprite.get_parent()
		if variant == 1:
			anchor.position = Vector2(290, 244) if name == "hero" else Vector2(420, 237)
		else:
			var xy: Array = _layout["player_support" if name == "hero" else "enemy_support"]
			var target := Vector2(xy[0], xy[1])
			anchor.position = target - foot_mid + pivot
		_stage.call("_align_feet", sprite)
		for foot in ["left_foot", "right_foot"]:
			var shadow: Polygon2D = anchor.get_node("Contact_" + foot)
			shadow.color = Color(0.025, 0.031, 0.043, 0.72 if variant == 1 else 0.34)
			shadow.scale = Vector2.ONE if variant == 1 else Vector2(0.65, 0.5)
	var descriptions := {1: "原版站位与材质", 2: "仅修站位与脚底接触影 · 材质仍为旧版", 3: "统一材质与站位 · 新静态母图（动画待重制）"}
	_caption.text = descriptions[variant] + "\n1 原版　2 站位修正　3 新材质　4 对齐线　Esc 退出"


func _support_positions() -> Dictionary:
	var positions := {}
	for name in ["hero", "dummy"]:
		var sprite: AnimatedSprite2D = _actors[name]
		var frames := sprite.sprite_frames
		var foot_mid: Vector2 = (frames.get_meta("left_foot_idle_0") + frames.get_meta("right_foot_idle_0")) * 0.5
		var pivot := Vector2(frames.get_meta("pivot_x"), frames.get_meta("pivot_y"))
		positions[name] = sprite.get_parent().position + foot_mid - pivot
	return positions


func _make_guides() -> void:
	if is_instance_valid(_guides):
		_guides.free()
	_guides = Node2D.new()
	_guides.z_index = 5
	_stage.get_node("Viewport/World").add_child(_guides)
	var a := Vector2(_layout["player_support"][0], _layout["player_support"][1])
	var b := Vector2(_layout["enemy_support"][0], _layout["enemy_support"][1])
	var center := (a + b) * 0.5
	for points in [[Vector2(center.x, 120), Vector2(center.x, 280)], [a - Vector2(24, 0), b + Vector2(24, 0)], [a - Vector2(0, 7), a + Vector2(0, 7)], [b - Vector2(0, 7), b + Vector2(0, 7)]]:
		var line := Line2D.new()
		line.points = PackedVector2Array(points)
		line.width = 1.0
		line.default_color = Color(0.73, 0.86, 0.87, 0.65)
		_guides.add_child(line)
	_guides.visible = false


func _process(_delta: float) -> bool:
	if not _live or _new_frames.is_empty():
		return false
	if Input.is_physical_key_pressed(KEY_ESCAPE):
		quit(0)
	var pressed := 0
	for key in [KEY_1, KEY_2, KEY_3, KEY_4]:
		if Input.is_physical_key_pressed(key):
			pressed = key
			break
	if pressed == 0:
		_last_review_key = 0
	elif pressed != _last_review_key:
		_last_review_key = pressed
		if pressed == KEY_4:
			_guides.visible = not _guides.visible
		elif _scene_reuse:
			if pressed == KEY_3:
				_show_occlusion(_occlusion_index % 3)
				_occlusion_index += 1
			else:
				_select_scene_layout("symmetric" if pressed == KEY_1 else "wide")
		else:
			_apply_variant(pressed - KEY_1 + 1)
	return false


func _select_scene_layout(layout_id: String) -> void:
	_layout = _stage.get_scene_layout(layout_id)
	_apply_variant(3)
	_make_guides()
	_caption.text = "同一原石室 · " + str(_layout["label"]) + " · 新角色静态检查\n1 普通站距　2 较宽站距　3 柱前后诊断　4 对齐线　Esc 退出"


func _show_occlusion(index: int) -> void:
	_guides.visible = false
	for name in ["hero", "dummy"]:
		var pillar: Node2D = _stage.get_node("Viewport/World/" + ("QingyunForeground" if name == "hero" else "QingyunForegroundRight"))
		var front: bool = index == 1 or (index == 2 and name == "dummy")
		var target: Vector2 = pillar.position + Vector2(8 if name == "hero" else -8, 3 if front else -10)
		var sprite: AnimatedSprite2D = _actors[name]
		var current: Vector2 = _support_positions()[name]
		sprite.get_parent().position += target - current
	_caption.text = ["两人位于柱后：只遮柱子实体轮廓", "两人位于柱前：人物应盖住柱身", "左人在柱后、右人在柱前：两侧独立排序"][index] + "\n静态遮挡诊断，不是移动动画；1/2 返回布局，3 切换诊断"


func _record_scene_reuse() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(REUSE_OUT))
	for layout_id in ["symmetric", "wide"]:
		_select_scene_layout(layout_id)
		await create_timer(0.15).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(REUSE_OUT + "layout_%s_%s.png" % [layout_id, _size_tag])
		var positions := _support_positions()
		for name in ["hero", "dummy"]:
			var xy: Array = _layout["player_support" if name == "hero" else "enemy_support"]
			if (positions[name] as Vector2).distance_to(Vector2(xy[0], xy[1])) > 0.01:
				push_error("Shared scene layout did not reach the actual actor support center")
				quit(1)
				return
	for index in 3:
		_show_occlusion(index)
		await create_timer(0.15).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(REUSE_OUT + "occlusion_%d_%s.png" % [index, _size_tag])
	print("SCENE_REUSE_CAPTURED size=", _size_tag, " layouts=2 occlusion_cases=3 same_room=true actors_static=true")
	quit(0)
