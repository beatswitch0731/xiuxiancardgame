extends SceneTree

# Real UI commands drive the isolated combat adapter. Representative rendered
# states and source-reference numerical checks prove the equipment contract.
const Demo = preload("res://scenes/equipment_demo.tscn")
const OUT := "res://art_direction/candidates/equipment_demo_20261022/evidence/"
var demo: Control
var _failures: Array[String] = []
var _checks := 0
var _event_ids: Dictionary = {}

func _initialize() -> void:
	call_deferred("_capture")

func _capture() -> void:
	root.size = Vector2i(1280, 800)
	demo = Demo.instantiate()
	root.add_child(demo)
	await create_timer(1.5).timeout
	if not demo.actor.ready_assets:
		push_error("Equipment demo assets missing; capture stopped.")
		quit(1)
		return
	demo.domain.critical_roll_override = 1.0
	var index := 0
	for weapon in ["问道剑", "brokenSword"]:
		for armor in ["玄铁甲", "灵纹法袍"]:
			index += 1
			_select("weapon", weapon)
			_select("armor", armor)
			_press("reset")
			await _hold(0.35)
			await _save("combination_%d_idle.png" % index)
			var before: Dictionary = demo.domain.snapshot()
			_press("attack")
			await _action_capture("combination_%d_thrust.png" % index)
			var after: Dictionary = demo.domain.snapshot()
			_check(before.qi - after.qi == 1, "attack cost once combo %d" % index)
			_check(before.enemyHp - after.enemyHp == (4 if weapon == "问道剑" else 2), "weapon damage combo %d" % index)
			_press("guard")
			await _action_capture("combination_%d_guard.png" % index)
			after = demo.domain.snapshot()
			_check(after.qi == 0 and after.block == 2, "guard cost/block combo %d" % index)
			_check(after.artifactCounter == 2, "guard counts as sword card combo %d" % index)
			_press("end_turn")
			await _action_capture("combination_%d_recovery.png" % index)
			after = demo.domain.snapshot()
			_check(after.hp == 9, "gourd heal once after absorbed attack combo %d" % index)
			_check(after.qi == (4 if armor == "灵纹法袍" else 3), "robe recovery combo %d" % index)
			_press("attack")
			await _action_capture("combination_%d_swordbox.png" % index, 0.68)
			after = demo.domain.snapshot()
			_check(after.artifactCounter == 0, "third sword card triggers combo %d" % index)
			await _hold(0.3)
	# Free unequip/re-equip through the same controls, with real effects removed.
	_select("accessory", "")
	_select("artifact", "")
	_select("armor", "")
	_press("reset")
	await _hold(0.2)
	await _save("unequipped_base.png")
	_press("end_turn")
	await _action_capture("unequipped_damage.png")
	var bare: Dictionary = demo.domain.snapshot()
	_check(bare.hp == 5 and bare.qi == 3, "unequip removes armor and recovery")
	_select("armor", "灵纹法袍")
	_select("accessory", "灵泉葫芦")
	_select("artifact", "青云剑匣")
	_press("reset")
	await _hold(0.2)
	# Pause and slow controls only affect presentation, never issue another card.
	_press("slow")
	_press("attack")
	await _hold(0.25)
	_press("pause")
	var paused: Dictionary = demo.domain.snapshot()
	var paused_frame: int = demo.actor.current_frame
	await _hold(0.3)
	_check(demo.actor.current_frame == paused_frame, "pause keeps current pose")
	_check(demo.domain.snapshot().sequence == paused.sequence, "pause does not issue duplicate command")
	await _save("paused_slow_pose.png")
	_press("pause")
	await _wait_idle()
	_press("slow")
	await _hold(0.3)
	for event in demo.presentation_events:
		var id := String(event.eventId)
		_check(not _event_ids.has(id), "presentation once " + id)
		_event_ids[id] = true
	var report := {"checks": _checks, "failures": _failures,
		"resolution": [1280, 800], "combinations": 4,
		"commands": "actual OptionButton.item_selected and Button.pressed signals",
		"presentationEvents": demo.presentation_events.size(),
		"finalState": demo.domain.snapshot()}
	var file := FileAccess.open(OUT + "runtime_evidence.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	if _failures.is_empty():
		print("EQUIPMENT_DEMO_CAPTURE_PASS checks=%d combinations=4 events=%d" % [_checks, demo.presentation_events.size()])
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)

func _select(slot: String, id: String) -> void:
	var selector: OptionButton = demo.selectors[slot]
	var index: int = demo.SLOT_ITEMS[slot].find(id)
	selector.select(index)
	selector.item_selected.emit(index)

func _press(id: String) -> void:
	var button: Button = demo.buttons[id]
	_check(not button.disabled, "button enabled " + id)
	button.pressed.emit()

func _action_capture(file_name: String, fraction: float = 0.48) -> void:
	var length: float = demo.actor.duration()
	await _hold(maxf(length * fraction, 0.03))
	await _save(file_name)
	await _wait_idle()

func _wait_idle() -> void:
	var limit := 0
	while demo.busy and limit < 360:
		await _tick()
		limit += 1
	_check(not demo.busy, "action returns to idle")
	await _hold(0.12)

func _hold(seconds: float) -> void:
	for i in range(maxi(1, ceili(seconds * 30.0))):
		await _tick()

func _tick() -> void:
	await process_frame

func _save(file_name: String) -> void:
	await RenderingServer.frame_post_draw
	var error := root.get_texture().get_image().save_png(OUT + file_name)
	_check(error == OK, "saved " + file_name)

func _check(condition: bool, detail: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(detail)
