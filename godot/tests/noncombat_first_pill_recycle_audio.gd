extends SceneTree

const Registry = preload("res://scripts/runtime_data_registry.gd")
const Domain = preload("res://scripts/noncombat_domain.gd")
const RunSession = preload("res://scripts/noncombat_run_session.gd")
const OpeningScene = preload("res://scenes/noncombat_opening.tscn")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var save_path := "user://tests/pill_recycle_audio_%d.json" % Time.get_ticks_usec()
	var game = Domain.new(Registry.new(), RunSession.new(save_path))
	if not game.start("pill"):
		return _fail("pill route could not start")
	for direction in ["right", "right", "left", "left", "left"]:
		if not game.choose(direction, game.issue_choice_token()):
			return _fail("pill route could not reach first battle")
	var story: Control = OpeningScene.instantiate()
	story.save_path = save_path
	root.add_child(story)
	await process_frame
	var launch: Button = story.find_child("LaunchBattle", true, false)
	if launch == null:
		return _fail("pill source battle unavailable")
	launch.pressed.emit()
	await process_frame
	var battle: Control = story.active_battle
	if battle == null or not battle.stage_assets_ready:
		return _fail("pill source stage unavailable")
	var action_audio: AudioStreamPlayer = battle.duel_stage.get_node_or_null("SourceActionSfx")
	var contact_audio: AudioStreamPlayer = battle.duel_stage.get_node_or_null("SourceContactSfx")
	if action_audio == null or contact_audio == null:
		return _fail("pill source audio players missing")
	var recycle_index: int = battle.combat.state.get("hand", []).find("pill_recycle")
	if recycle_index < 0:
		print("PILL_RECYCLE_DRAW_REQUIRED")
		battle.end_button.pressed.emit()
		await process_frame
		if battle.combat.state.get("phase") != "REACTION_OPEN":
			return _fail("pill refill turn did not open reaction")
		battle.reaction_buttons[0].pressed.emit()
		if not await _wait_presentations(battle):
			return _fail("pill refill enemy action did not finish")
		recycle_index = battle.combat.state.get("hand", []).find("pill_recycle")
	var contact_before := ""
	if contact_audio.stream != null:
		contact_before = contact_audio.stream.resource_path
	if recycle_index < 0 or not battle.combat.play_card(recycle_index):
		return _fail("pill recycle was not reachable from natural hand")
	await create_timer(0.05).timeout
	if not action_audio.playing or action_audio.stream == null or action_audio.stream.resource_path != \
			"res://content/assets/audio/sfx/path/pill/01_attack/sfx_pl_01_attack.wav":
		return _fail("pill recycle action start cue missing")
	if not await _wait_presentations(battle):
		return _fail("pill recycle presentation did not finish")
	var contact_after := ""
	if contact_audio.stream != null:
		contact_after = contact_audio.stream.resource_path
	if contact_after != contact_before:
		return _fail("pill recycle played state/contact cue without source semantic event: " + \
			contact_after)
	story.queue_free()
	for _frame in range(3):
		await process_frame
	print("NONCOMBAT_FIRST_PILL_RECYCLE_AUDIO_PASS start=true no_state=true")
	quit(0)


func _wait_presentations(battle: Control) -> bool:
	for _step in range(150):
		await create_timer(0.05).timeout
		if battle.pending_presentations == 0 and not battle.combat.input_locked:
			return true
	return false


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
