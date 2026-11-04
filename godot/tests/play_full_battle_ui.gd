extends SceneTree

# Drive the real main scene through the source M0 fight instead of calling the
# combat domain directly. This catches card-hand, reaction, and presentation
# locks across the reshuffle and third-turn finish.
const Registry = preload("res://scripts/runtime_data_registry.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var reference_preview := "--reference-battle-demo" in OS.get_cmdline_user_args()
	var registry := Registry.new()
	var fixture: Dictionary = registry.read_json("fixtures/m0_full_battle_expected.json")
	var steps: Array = fixture.get("steps", [])
	var scene: Control = load("res://scenes/main.tscn").instantiate()
	scene.trial_v8_candidate_preview = "--trial-v8-candidate" in OS.get_cmdline_user_args()
	root.add_child(scene)
	await process_frame
	if steps.size() != 12 or not scene.stage_assets_ready or not scene.combat.set_replay_random_values(fixture["randomValues"]):
		_fail("Source fight or real 3D entry failed to load")
		return
	var presented: Array[String] = []
	scene.duel_stage.presentation_finished.connect(func(kind: String) -> void: presented.append(kind))
	for expected in steps:
		var step := int(expected["step"])
		var action := String(expected["action"])
		if not _check_before(scene, expected):
			return
		if action == "END_TURN":
			if scene.end_button.disabled:
				_fail("End-turn button disabled at source step %d" % step)
				return
			scene.end_button.pressed.emit()
		elif action == "TAKE_HIT":
			if scene.reaction_buttons[0].disabled:
				_fail("Source reaction button disabled at source step %d" % step)
				return
			scene.reaction_buttons[0].pressed.emit()
		else:
			var card_button := _find_card(scene.hand_row, action)
			if card_button == null or card_button.disabled:
				_fail("Source card unavailable on hand at source step %d: %s" % [step, action])
				return
			card_button.pressed.emit()
		if action != "END_TURN" and not await _wait_for_presentations(scene, 4.0):
			_fail("3D animation or input lock did not settle at source step %d: %s" % [step, action])
			return
		await process_frame
	if scene.combat.state["phase"] != "VICTORY" or int(scene.combat.state["enemy"]["hp"]) != 0 \
			or not scene.state_label.text.contains("战斗胜利") or scene.combat.input_locked \
			or scene.end_button.visible or scene.reaction_buttons.any(func(button: Button) -> bool: return button.visible) \
			or scene.combat.replay_random_remaining() != 0:
		_fail("Real UI did not finish the source third-turn victory")
		return
	if presented.count("CARD_PLAY") != 8 or presented.count("ENEMY_ACTION") != 2:
		_fail("Real 3D presentation count drifted during the full source fight: " + str(presented))
		return
	if reference_preview:
		if scene.duel_stage.name != "DuelStageHD2D" or not scene.duel_stage.reference_actor_style_ready:
			_fail("Reference battle did not finish with the new HD-2D actor style")
			return
		print("REFERENCE_BATTLE_FULL_FLOW_PASS steps=5..16 cards=8 enemy_actions=2 victory=true")
		quit(0)
		return
	var victory_audio: AudioStreamPlayer = scene.duel_stage.get_node_or_null("SourceActionSfx")
	if victory_audio == null or victory_audio.stream == null or \
			victory_audio.stream.resource_path != \
			"res://content/assets/audio/sfx/world/get_treasure.mp3" or \
			absf(victory_audio.volume_db - linear_to_db(0.5 * 0.6)) > 0.01:
		_fail("Real sword victory did not load the source treasure cue")
		return
	if scene.duel_stage.name != "QingyunPixelStage":
		_fail("Default first fight did not use the Qingyun pixel stage")
		return
	print("M0_FULL_BATTLE_UI_PASS steps=5..16 cards=8 enemy_actions=2 stage=qingyun_pixel victory_audio=true")
	quit(0)


func _check_before(scene: Control, expected: Dictionary) -> bool:
	var state: Dictionary = scene.combat.state
	if String(state["phase"]) != String(expected["phase"]):
		_fail("Source phase mismatch at step %s: actual=%s expected=%s" % [expected["step"], state["phase"], expected["phase"]])
		return false
	var wants_turn: bool = state["phase"] == "PLAYER_TURN"
	var wants_reaction: bool = state["phase"] == "REACTION_OPEN"
	if scene.end_button.visible != wants_turn \
			or scene.reaction_buttons.any(func(button: Button) -> bool: return button.visible != wants_reaction):
		_fail("Visible action controls do not match source phase at step %s" % expected["step"])
		return false
	for pair in [
		["turn", state["turn"]], ["qi", state["qi"]],
		["playerHp", state["player"]["hp"]], ["playerBlock", state["player"]["block"]],
		["enemyHp", state["enemy"]["hp"]], ["enemyBlock", state["enemy"]["block"]],
	]:
		if int(expected[pair[0]]) != int(pair[1]):
			_fail("Source state mismatch at step %s field %s: actual=%s expected=%s" % [
				expected["step"], pair[0], pair[1], expected[pair[0]]])
			return false
	if state["hand"] != expected["hand"]:
		_fail("Source hand drift at step %s" % expected["step"])
		return false
	return true


func _find_card(hand: HBoxContainer, card_id: String) -> Button:
	for child in hand.get_children():
		if child is Button and String(child.get_meta("source_card_id", "")) == card_id:
			return child as Button
	return null


func _wait_for_presentations(scene: Control, seconds: float) -> bool:
	var ticks := int(seconds / 0.05)
	for tick in ticks:
		await create_timer(0.05).timeout
		if scene.pending_presentations == 0 and not scene.combat.input_locked:
			return true
	return false


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
