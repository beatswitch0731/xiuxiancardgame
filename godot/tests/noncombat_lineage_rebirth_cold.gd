extends SceneTree

const Registry = preload("res://scripts/runtime_data_registry.gd")
const Domain = preload("res://scripts/noncombat_domain.gd")
const RunSession = preload("res://scripts/noncombat_run_session.gd")
const FIXTURE := "res://tests/fixtures/pill_decision54_death_probe_v2.json"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var path := "user://tests/lineage_rebirth_%d.json" % Time.get_ticks_usec()
	var store = RunSession.new(path, "slot_3")
	var source := FileAccess.open(store.v2_path, FileAccess.WRITE)
	if source == null:
		return _fail("source death fixture cannot be staged")
	source.store_string(FileAccess.get_file_as_string(FIXTURE))
	source.close()
	var game = _open(path)
	if game == null or not game.resume_flow() \
			or game.get_current_card().get("id") != "q_love" \
			or not game.choose("right", game.issue_choice_token()) \
			or game.state.get("phase") != "DEATH_PENDING" \
			or not game.choose("left", game.issue_choice_token()):
		return _fail("real death-to-rebirth route stopped")
	if game.state.get("rebirthInheritanceVersion") != 5 \
			or game.state.get("lineageEntries", []).size() != 1 \
			or int(game.state.get("rebirthTree", {}).get("insight", 0)) < 1:
		return _fail("source lineage insight was not earned at rebirth")
	var ui: Control = load("res://scenes/noncombat_opening.tscn").instantiate()
	ui.save_path = ""
	root.add_child(ui)
	await process_frame
	ui.opening = game
	ui._render()
	if not ui.rebirth_tree_button.visible:
		return _fail("real second-life state did not expose desktop rebirth tree")
	ui.rebirth_tree_button.pressed.emit()
	var tree_list: VBoxContainer = ui.rebirth_tree_dialog.get_child(0).get_child(0) \
		as VBoxContainer
	var shown_nodes := 0
	for child in tree_list.get_children():
		if child is Button:
			shown_nodes += 1
	if shown_nodes != 16:
		return _fail("real second-life desktop omitted authored tree nodes")
	ui.queue_free()
	await process_frame
	if not game.change_rebirth_tree("bonds_familiar_voice"):
		return _fail("earned insight could not buy first bond node")
	var bought := _open(path)
	if bought == null or bought.state != JSON.parse_string(
			JSON.stringify(game.state)) or bought.state.get("rebirthTreeActions", []).size() != 1:
		return _fail("rebirth-phase tree purchase failed strict cold replay")
	if not bought.select_rebirth_path("body") \
			or not bought.choose("down", bought.issue_choice_token()) \
			or bought.state.get("phase") != "CAMP_TARGET_PENDING" \
			or not bought.change_rebirth_tree("bonds_familiar_voice", true):
		return _fail("boon-phase tree refund could not commit")
	var refunded := _open(path)
	if refunded == null or refunded.state != JSON.parse_string(
			JSON.stringify(bought.state)) \
			or refunded.state.get("rebirthTreeActions", []).size() != 2:
		return _fail("boon-phase tree refund failed strict cold replay")
	if not refunded.cancel_camp_target(refunded.issue_choice_token()):
		return _fail("rebirth boon continuation stopped after tree refund")
	var continued := _open(path)
	if continued == null or continued.state != JSON.parse_string(
			JSON.stringify(refunded.state)):
		return _fail("tree actions changed after next strict cold read")
	print("NONCOMBAT_LINEAGE_REBIRTH_COLD_PASS archive=true purchase=true refund=true replay=true")
	quit(0)


func _open(path: String) -> RefCounted:
	var game = Domain.new(Registry.new(), RunSession.new(path, "slot_3"), "slot_3")
	game._normal_roll_override = 0.55
	game._market_flow.roll_override = 0.0
	game._destiny_wheel_flow.roll_override = 0.0
	game._ripple_flow.roll_override = 0.999
	game._hint_flow.roll_override = 0.0
	return game if game.restore() else null


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
