extends "res://tests/noncombat_qi_gate_entry.gd"

## 战斗桩端到端测试（INF-3）。
##
## 走真实炼气雷关路线推进到 BATTLE_PENDING，开启 battle_stub_mode，
## 验证「剧情 → 战斗 → 战果 → 返回下一卡」在真实战斗缺失时仍能闭合。
## 这是「非战斗可独立验收」的核心证据：桩必须让流程真正走完，
## 而不是让测试自己注入 submit_battle_result()。

const BattleStubScript = preload("res://scripts/battle_stub.gd")


func _run() -> void:
	var first: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	var second: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SECOND_FIXTURE))
	var third: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(THIRD_FIXTURE))
	var file := "user://tests/battle_stub_route_%d.json" % Time.get_ticks_usec()
	var game = Domain.new(Registry.new(), Session.new(file, "slot_2"), "slot_2")
	_quiet_ambient(game)
	if not _open_third_alt(game, first, second, third):
		return _stop("third-alt prefix failed")
	if not _reach_gate(game):
		return _stop("qi gate not reached")
	if String(game.state.get("phase", "")) != "WARNING_PENDING":
		return _stop("expected WARNING_PENDING, got " + String(game.state.get("phase", "")))
	if not game.choose("left", game.issue_choice_token()):
		return _stop("free-preparation choice failed")
	if String(game.state.get("phase", "")) != "BATTLE_PENDING":
		return _stop("expected BATTLE_PENDING, got " + String(game.state.get("phase", "")))
	var request: Dictionary = game.battle_request()
	if request.is_empty():
		return _stop("battle_request empty at BATTLE_PENDING")
	var pending_card := String(game.get_current_card().get("id", ""))
	var pending_instance := String(request.get("encounterInstanceId", ""))
	if pending_instance.is_empty():
		return _stop("request missing encounterInstanceId")

	var story: Control = OpeningScene.instantiate()
	story.save_path = ""
	story.battle_stub_mode = true
	root.add_child(story)
	await process_frame
	story.opening = game
	story.slot_screen.visible = false
	story.name_screen.visible = false
	story.path_screen.visible = false
	story.story_screen.visible = true
	story._set_scene_surface(true)
	story._render()
	await process_frame

	var launch: Button = story.find_child("LaunchBattle", true, false)
	if launch == null:
		return _stop("LaunchBattle button absent")
	if launch.disabled:
		return _stop("LaunchBattle disabled: " + String(story.status_label.text))
	launch.pressed.emit()

	# _launch_battle() 是同步的：同帧内 active_battle 已就位，而桩的 _finish
	# 走 call_deferred，所以必须在 await 之前抓取，否则它已完成并自我清理。
	var battle: Control = story.active_battle
	if battle == null:
		var resolver = preload("res://scripts/battle_plan_resolver.gd").new(Registry.new())
		var plan: Dictionary = resolver.resolve_persisted(game.state)
		return _stop("battle not installed after LaunchBattle: " + JSON.stringify({
			"status": String(story.status_label.text),
			"phase": String(game.state.get("phase", "")),
			"planAuthorized": plan.get("launchAuthorized"),
			"resolverError": resolver.last_error}))
	var script_path := ""
	if battle.get_script() is Script:
		script_path = String(battle.get_script().resource_path)
	if not script_path.ends_with("battle_stub.gd"):
		return _stop("expected BattleStub, got " + script_path)

	# 桩在 _ready 后 deferred 发射战果，_on_battle_finished 会同步结算并清理。
	var deadline := Time.get_ticks_msec() + 5000
	while story.active_battle != null and Time.get_ticks_msec() < deadline:
		await process_frame
	if story.active_battle != null:
		return _stop("stub did not finish within 5s")
	if String(game.state.get("phase", "")) == "BATTLE_PENDING":
		return _stop("state stayed BATTLE_PENDING after stub result: "
			+ String(story.status_label.text))
	var after_card := String(game.get_current_card().get("id", ""))
	if after_card.is_empty():
		return _stop("no card presented after battle settlement")
	if after_card == pending_card:
		return _stop("next card unchanged after battle: " + after_card)
	if game.state.get("pendingBattle") is Dictionary and not game.state.get("pendingBattle").is_empty():
		return _stop("pendingBattle not cleared after settlement")
	# 桩必须真的被 gateway 接受过：receipt 与 encounterInstanceId 要能对上。
	var run_clock: Variant = game.state.get("runClock")
	if not run_clock is Dictionary or int(run_clock.get("decisionIndex", -1)) < 0:
		return _stop("decision clock not advanced by settlement")

	print("BATTLE_STUB_ROUTE_PASS pending=%s after=%s phase=%s instance=%s" % [
		pending_card, after_card, String(game.state.get("phase", "")), pending_instance])
	quit(0)


func _stop(message: String) -> void:
	printerr("BATTLE_STUB_ROUTE_FAIL " + message)
	quit(1)
