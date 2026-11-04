extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var ui: Control = load("res://scenes/noncombat_opening.tscn").instantiate()
	ui.save_path = "user://tests/path_skill_ui_%d_%d.json" % [
		OS.get_process_id(), Time.get_ticks_usec()]
	root.add_child(ui)
	await process_frame
	if not ui.opening.start("body"):
		return _fail("body run could not start")
	ui.opening.state.realm = "golden"
	ui.opening.state.attributes.health = 10
	ui._render()
	if not ui.stats_label.text.contains("气血 10/10"):
		return _fail("active body health cap is absent from story stats: " +
			ui.stats_label.text)
	ui.opening.state.erase("pathSkillActivationIndex")
	ui.opening.state.attributes.health = 8
	ui._render()
	if not ui.stats_label.text.contains("气血 8/8"):
		return _fail("old run displays an unactivated body health cap")
	print("NONCOMBAT_PATH_SKILL_UI_PASS active=10/10 legacy=8/8")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
