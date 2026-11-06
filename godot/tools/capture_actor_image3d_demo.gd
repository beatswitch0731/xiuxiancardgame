extends SceneTree

const DEMO = preload("res://scenes/actor_image3d_demo.tscn")
var _ual_review := false


func _initialize() -> void:
	call_deferred("_capture")


func _capture() -> void:
	_ual_review = OS.get_environment("YELINGYUN_UAL_REVIEW") == "1"
	var demo: Control = DEMO.instantiate()
	demo.use_ual_candidate = _ual_review
	root.add_child(demo)
	if demo.actor_root == null:
		push_error("Image3D demo failed to mount generated model")
		quit(1)
		return
	await process_frame
	await process_frame
	await _save("idle-start")
	await create_timer(1.20).timeout
	await _save("idle-inhale")
	if not demo.set_weapon_equipped(true):
		push_error("Image3D demo could not attach story sword")
		quit(1)
		return
	if demo.visual_equipment.current_visual("weapon") != "traded_rusted_sword":
		push_error("Image3D equipped visual id mismatch")
		quit(1)
		return
	await _save("equipped-idle")
	if not demo.play_action("sword_attack"):
		push_error("Image3D attack action was rejected")
		quit(1)
		return
	var samples := [["attack-anticipation", 0.32],
		["attack-phase-074", 0.74], ["attack-phase-105", 1.05],
		["attack-phase-125", 1.25], ["attack-retreat", 1.43]] if _ual_review else [
		["attack-anticipation", 0.18], ["attack-stroke-no-contact", 0.42]]
	for sample in samples:
		if not await _wait_action_position(demo, float(sample[1])):
			push_error("Image3D action did not reach " + String(sample[0]))
			quit(1)
			return
		await _save(String(sample[0]))
	if _ual_review:
		var finish_ms := Time.get_ticks_msec()
		while not demo.action_module.is_idle() \
				and Time.get_ticks_msec() - finish_ms < 2500:
			await process_frame
		await _save("attack-recovered-idle")
	print("IMAGE3D_ACTION_VISUAL_CAPTURE_PASS")
	quit()


func _wait_action_position(demo: Control, target: float) -> bool:
	var started_ms := Time.get_ticks_msec()
	while demo.action_module.playback_position() < target:
		if Time.get_ticks_msec() - started_ms > 2000:
			return false
		await process_frame
	return true


func _save(label: String) -> void:
	await RenderingServer.frame_post_draw
	var prefix := "ual-" if _ual_review else "action-"
	var output := "res://output/captures/godot-migration/actor-image3d-mvp/" + prefix + label + ".png"
	if root.get_viewport().get_texture().get_image().save_png(output) != OK:
		push_error("Image3D frame capture failed: " + output)
		return
	print("IMAGE3D_ACTION_CAPTURE ", output)
