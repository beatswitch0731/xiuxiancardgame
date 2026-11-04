extends SceneTree

const Demo = preload("res://scenes/equipment_demo.tscn")
const OUT := "res://art_direction/candidates/equipment_demo_20261022/evidence/motion_frames_refined/"
var _index := 0

func _initialize() -> void:
	call_deferred("_capture")

func _capture() -> void:
	root.size = Vector2i(1280, 800)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var demo: Control = Demo.instantiate()
	root.add_child(demo)
	await create_timer(1.0).timeout
	if not demo.actor.ready_assets:
		push_error("Equipment motion assets missing")
		quit(1)
		return
	await _save()
	var enemy_before: String = demo._enemy_hp_number.text
	demo.buttons["attack"].pressed.emit()
	await _advance_and_save()
	if demo._enemy_hp_number.text != enemy_before or demo._log.text.find("命中4") >= 0:
		push_error("Enemy HUD changed before sword contact")
		quit(1)
		return
	for i in range(14):
		await _advance_and_save()
	if demo._enemy_hp_number.text != "116 / 120" or demo._log.text.find("命中4") < 0:
		push_error("Enemy HUD did not change at sword contact")
		quit(1)
		return
	if demo.busy:
		push_error("Thrust did not finish")
		quit(1)
		return
	var shield_before: String = demo._status.text
	demo.buttons["guard"].pressed.emit()
	await _advance_and_save()
	if demo._status.text != shield_before:
		push_error("Shield HUD changed before guard contact")
		quit(1)
		return
	for i in range(12):
		await _advance_and_save()
	if demo._status.text.find("护盾 2") < 0:
		push_error("Shield HUD did not change at guard contact")
		quit(1)
		return
	print("EQUIPMENT_MOTION_CAPTURE_PASS frames=%d" % _index)
	quit(0)

func _advance_and_save() -> void:
	await process_frame
	await process_frame
	await _save()

func _save() -> void:
	await RenderingServer.frame_post_draw
	var error := root.get_texture().get_image().save_png(OUT + "frame_%03d.png" % _index)
	if error != OK:
		push_error("Equipment motion frame could not be written")
	_index += 1
