extends SceneTree

const Registry = preload("res://scripts/runtime_data_registry.gd")
const Domain = preload("res://scripts/noncombat_domain.gd")
const RunSession = preload("res://scripts/noncombat_run_session.gd")
const OpeningScene = preload("res://scenes/noncombat_opening.tscn")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var save_path := "user://tests/sword_stage_audio_%d.json" % Time.get_ticks_usec()
	var game = Domain.new(Registry.new(), RunSession.new(save_path))
	if not game.start("sword"):
		return _fail("source sword start failed")
	for direction in ["right", "left", "right", "left", "right"]:
		if not game.choose(direction, game.issue_choice_token()):
			return _fail("source sword could not reach battle")
	var story: Control = OpeningScene.instantiate()
	story.save_path = save_path
	root.add_child(story)
	await process_frame
	var launch: Button = story.find_child("LaunchBattle", true, false)
	if launch == null:
		return _fail("source sword LaunchBattle unavailable")
	launch.pressed.emit()
	await process_frame
	var battle: Control = story.active_battle
	if battle == null or not battle.stage_assets_ready:
		return _fail("source sword stage unavailable")
	var stage: Control = battle.duel_stage
	var action_audio: AudioStreamPlayer = stage.get_node_or_null("SourceActionSfx")
	var contact_audio: AudioStreamPlayer = stage.get_node_or_null("SourceContactSfx")
	if action_audio == null or contact_audio == null:
		return _fail("source sword action/contact audio players absent")
	var first_contact: Array[Dictionary] = []
	stage.contact_frame.connect(func(side: String) -> void:
		if side == "player":
			first_contact.append({"playing": contact_audio.playing,
				"path": contact_audio.stream.resource_path if contact_audio.stream else "",
				"reactionPlaying": stage.get_node_or_null("SourceReactionSfx").playing if \
					stage.get_node_or_null("SourceReactionSfx") else false}))
	var attack_index: int = battle.combat.state.get("hand", []).find("sword_followthrough")
	if attack_index < 0 or not battle.combat.play_card(attack_index):
		return _fail("source sword followthrough could not play")
	await create_timer(0.05).timeout
	if not action_audio.playing or action_audio.stream == null or action_audio.stream.resource_path != \
			"res://content/assets/audio/sfx/path/sword/01_attack/sfx_sw_01_attack.wav":
		return _fail("source sword attack cue did not play")
	for _step in range(100):
		if not first_contact.is_empty():
			break
		await create_timer(0.05).timeout
	if first_contact.is_empty() or not first_contact[0]["playing"] or \
			first_contact[0]["path"] != \
			"res://content/assets/audio/sfx/path/sword/02_impact/sfx_sw_02_impact.wav":
		return _fail("source sword contact cue did not play: " + str(first_contact))
	if first_contact[0]["reactionPlaying"]:
		return _fail("source sword visual hurt replayed impact cue: " + str(first_contact[0]))
	for _step in range(150):
		if battle.pending_presentations == 0 and not battle.combat.input_locked:
			break
		await create_timer(0.05).timeout
	if battle.pending_presentations != 0 or battle.combat.input_locked:
		return _fail("source sword attack animation did not finish")
	var guard_index: int = battle.combat.state.get("hand", []).find("sword_sheath_guard")
	if guard_index < 0:
		guard_index = battle.combat.state.get("hand", []).find("sword_guard")
	if guard_index < 0 or not battle.combat.play_card(guard_index):
		return _fail("source sword guard could not play")
	await create_timer(0.05).timeout
	if not action_audio.playing or action_audio.stream == null or action_audio.stream.resource_path != \
			"res://content/assets/audio/sfx/combat/block_perfect.mp3":
		return _fail("source sword guard cue did not play")
	for _step in range(150):
		if battle.pending_presentations == 0 and not battle.combat.input_locked:
			break
		await create_timer(0.05).timeout
	if battle.pending_presentations != 0 or battle.combat.input_locked:
		return _fail("source sword guard animation did not finish")
	var enemy_contact: Array[Dictionary] = []
	stage.contact_frame.connect(func(side: String) -> void:
		if side == "enemy":
			enemy_contact.append({"playing": contact_audio.playing,
				"path": contact_audio.stream.resource_path if contact_audio.stream else ""}))
	battle.end_button.pressed.emit()
	await process_frame
	if battle.combat.state.get("phase") != "REACTION_OPEN" or \
			battle.combat.state.get("enemyIntent", {}).get("type") != "attack":
		return _fail("source sword enemy attack not offered")
	battle.reaction_buttons[0].pressed.emit()
	await create_timer(0.05).timeout
	if not action_audio.playing or action_audio.stream == null or action_audio.stream.resource_path != \
			"res://content/assets/audio/sfx/combat/sword_slash.mp3":
		return _fail("source sword enemy attack cue did not play")
	for _step in range(100):
		if not enemy_contact.is_empty():
			break
		await create_timer(0.05).timeout
	if enemy_contact.is_empty() or not enemy_contact[0]["playing"] or \
			enemy_contact[0]["path"] != \
			"res://content/assets/audio/sfx/combat/damage_hit.mp3":
		return _fail("source sword enemy contact cue did not play: " + str(enemy_contact))
	for _step in range(150):
		if battle.pending_presentations == 0 and not battle.combat.input_locked:
			break
		await create_timer(0.05).timeout
	if battle.combat.state.get("phase") != "PLAYER_TURN":
		return _fail("source sword did not reopen after enemy attack")
	battle.end_button.pressed.emit()
	await process_frame
	if battle.combat.state.get("phase") != "REACTION_OPEN" or \
			battle.combat.state.get("enemyIntent", {}).get("type") != "defend":
		return _fail("source sword reserved resource did not produce enemy guard")
	battle.reaction_buttons[0].pressed.emit()
	await create_timer(0.05).timeout
	if not action_audio.playing or action_audio.stream == null or action_audio.stream.resource_path != \
			"res://content/assets/audio/sfx/combat/block_perfect.mp3":
		return _fail("source sword enemy guard start cue did not play")
	for _step in range(150):
		if battle.pending_presentations == 0 and not battle.combat.input_locked:
			break
		await create_timer(0.05).timeout
	var extra_audio: AudioStreamPlayer = stage.get_node_or_null("SourceReactionSfx")
	if extra_audio != null and extra_audio.stream != null and \
			extra_audio.stream.resource_path == \
			"res://content/assets/audio/sfx/combat/block_perfect.mp3":
		return _fail("source sword enemy guard replayed unissued contact cue")
	story.queue_free()
	for _frame in range(3):
		await process_frame
	print("NONCOMBAT_FIRST_SWORD_STAGE_AUDIO_PASS attack=true guard=true enemy=true enemy_guard=true no_sidecar=true")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
