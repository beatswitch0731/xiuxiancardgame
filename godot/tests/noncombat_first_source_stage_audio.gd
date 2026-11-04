extends SceneTree

const Registry = preload("res://scripts/runtime_data_registry.gd")
const Domain = preload("res://scripts/noncombat_domain.gd")
const RunSession = preload("res://scripts/noncombat_run_session.gd")
const OpeningScene = preload("res://scenes/noncombat_opening.tscn")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	for sample in [
		{"path": "spell", "card": "spell_spark", "guard": "spell_ward",
			"start": "sfx/path/spell/01_attack/sfx_sp_01_attack.wav",
			"contact": "sfx/path/spell/02_impact/sfx_sp_02_impact.wav",
			"guardStart": "sfx/combat/block_perfect.mp3",
			"state": "sfx/combat/block_perfect.mp3"},
		{"path": "body", "card": "body_fist", "guard": "body_stance",
			"start": "sfx/path/body/01_attack/sfx_bd_01_attack.wav",
			"contact": "sfx/path/body/02_impact/sfx_bd_02_impact.wav",
			"guardStart": "sfx/path/body/01_attack/sfx_bd_01_attack.wav",
			"state": "sfx/path/body/03_state/sfx_bd_03_state.wav"},
		{"path": "pill", "card": "pill_ember", "guard": "pill_catalyst",
			"start": "sfx/path/pill/01_attack/sfx_pl_01_attack.wav",
			"contact": "sfx/path/pill/02_impact/sfx_pl_02_impact.wav",
			"guardStart": "sfx/path/pill/01_attack/sfx_pl_01_attack.wav",
			"state": "sfx/path/pill/03_state/sfx_pl_03_state.wav"},
	]:
		var result: String = await _case(sample)
		if not result.is_empty():
			return _fail(result)
	print("NONCOMBAT_FIRST_SOURCE_STAGE_AUDIO_PASS paths=3 start=true contact=true guard=true clock=true enemy=true")
	quit(0)


func _case(sample: Dictionary) -> String:
	var path_id: String = sample["path"]
	var save_path := "user://tests/source_audio_%s_%d.json" % [path_id, Time.get_ticks_usec()]
	var game = Domain.new(Registry.new(), RunSession.new(save_path))
	if not game.start(path_id):
		return path_id + " start failed"
	for direction in ["right", "right", "left", "left", "left"]:
		if not game.choose(direction, game.issue_choice_token()):
			return path_id + " could not reach battle"
	var story: Control = OpeningScene.instantiate()
	story.save_path = save_path
	root.add_child(story)
	await process_frame
	var launch: Button = story.find_child("LaunchBattle", true, false)
	if launch == null:
		return path_id + " lacks LaunchBattle"
	launch.pressed.emit()
	await process_frame
	var battle: Control = story.active_battle
	if battle == null or not battle.stage_assets_ready:
		return path_id + " stage unavailable"
	var stage: Control = battle.duel_stage
	var start_audio: AudioStreamPlayer = stage.get_node_or_null("SourceActionSfx")
	var contact_audio: AudioStreamPlayer = stage.get_node_or_null("SourceContactSfx")
	if start_audio == null or contact_audio == null:
		return path_id + " source audio players absent"
	var actions: Dictionary = Registry.new().read_json("data/combat/action_presentations.json")
	var hero: TextureRect = stage.find_child("SourceHero", true, false)
	var enemy_actor: TextureRect = stage.find_child("SourceEnemy", true, false)
	var attack_frames: Array = actions["paths"][path_id]["attack"]["animation"]["frames"]
	var action_starts: Array[Dictionary] = []
	if path_id == "body":
		if not stage.has_signal("action_started"):
			return "body source action start clock unavailable"
		stage.connect("action_started", func(side: String, clip: String) -> void:
			if clip == "attack":
				action_starts.append({"side": side, "at": Time.get_ticks_usec()}))
	var contacts: Array[Dictionary] = []
	stage.contact_frame.connect(func(side: String) -> void:
		if side == "player":
			contacts.append({"playing": contact_audio.playing,
				"path": contact_audio.stream.resource_path if contact_audio.stream != null else "",
				"texture": hero.texture.resource_path if hero.texture != null else "",
				"at": Time.get_ticks_usec()}))
	var card_index: int = battle.combat.state.get("hand", []).find(sample["card"])
	if card_index < 0 or not battle.combat.play_card(card_index):
		return path_id + " source attack could not play"
	await create_timer(0.05).timeout
	if not start_audio.playing or start_audio.stream == null or \
			start_audio.stream.resource_path != "res://content/assets/audio/" + sample["start"]:
		return path_id + " source action cue did not play"
	for _step in range(100):
		if not contacts.is_empty():
			break
		await create_timer(0.05).timeout
	if contacts.is_empty() or not contacts[0]["playing"] or \
			contacts[0]["path"] != "res://content/assets/audio/" + sample["contact"]:
		return path_id + " source contact cue did not play: " + str(contacts)
	if path_id == "body" and contacts[0]["texture"] != "res://content/" + String(attack_frames[2]):
		return "body melee contact did not use source impact frame: " + str(contacts[0])
	if path_id == "body" and (action_starts.is_empty() or \
			int(contacts[0]["at"] - action_starts[0]["at"]) > 315000):
		return "body melee contact missed source frame-start clock: " + \
			str({"start": action_starts, "contact": contacts[0]})
	for _step in range(150):
		if battle.pending_presentations == 0 and not battle.combat.input_locked:
			break
		await create_timer(0.05).timeout
	if battle.pending_presentations != 0 or battle.combat.input_locked:
		return path_id + " source attack animation did not finish"
	if contact_audio.stream == null or contact_audio.stream.resource_path != \
			"res://content/assets/audio/" + sample["contact"]:
		return path_id + " visual hurt replayed a second impact cue"
	contacts.clear()
	var guard_index: int = battle.combat.state.get("hand", []).find(sample["guard"])
	var enemy_checked := false
	if guard_index < 0 and path_id == "pill":
		print("PILL_CATALYST_DRAW_REQUIRED")
		var early_enemy_error := await _check_enemy_action(
			path_id, battle, stage, enemy_actor, start_audio, contact_audio, actions, action_starts)
		if not early_enemy_error.is_empty():
			return early_enemy_error
		enemy_checked = true
		guard_index = battle.combat.state.get("hand", []).find(sample["guard"])
	var played_guard_id: String = String(battle.combat.state.get("hand", [])[guard_index]) if guard_index >= 0 else ""
	if guard_index < 0 or not battle.combat.play_card(guard_index):
		return path_id + " source guard could not play"
	await create_timer(0.05).timeout
	if not start_audio.playing or start_audio.stream == null or \
			start_audio.stream.resource_path != "res://content/assets/audio/" + sample["guardStart"]:
		return path_id + " source guard start cue did not play"
	var expected_guard: Dictionary = actions["paths"][path_id]["guard"].duplicate(true)
	var guard_variant: Dictionary = expected_guard.get("variantsBySourceId", {}).get(played_guard_id, {})
	if not guard_variant.is_empty():
		expected_guard.merge(guard_variant, true)
	if hero == null or hero.texture == null or hero.texture.resource_path != \
			"res://content/" + String(expected_guard["animation"]["frames"][0]):
		return path_id + " source guard frames were not selected"
	for _step in range(100):
		if not contacts.is_empty():
			break
		await create_timer(0.05).timeout
	if contacts.is_empty() or not contacts[0]["playing"] or \
			contacts[0]["path"] != "res://content/assets/audio/" + sample["state"]:
		return path_id + " source guard state cue did not play: " + str(contacts)
	var guard_animation: Dictionary = expected_guard["animation"]
	var guard_impact_index := int(guard_animation.get("impactFrameIndex",
		int(floor(float(guard_animation["frames"].size()) / 2.0))))
	if contacts[0]["texture"] != "res://content/" + String(guard_animation["frames"][guard_impact_index]):
		return path_id + " source guard state cue missed authored impact frame: " + str(contacts[0])
	for _step in range(150):
		if battle.pending_presentations == 0 and not battle.combat.input_locked:
			break
		await create_timer(0.05).timeout
	if battle.pending_presentations != 0 or battle.combat.input_locked:
		return path_id + " source guard animation did not finish"
	if not enemy_checked:
		var enemy_error := await _check_enemy_action(
			path_id, battle, stage, enemy_actor, start_audio, contact_audio, actions, action_starts)
		if not enemy_error.is_empty():
			return enemy_error
	story.queue_free()
	for _frame in range(3):
		await process_frame
	return ""


func _check_enemy_action(path_id: String, battle: Control, stage: Control,
		enemy_actor: TextureRect, start_audio: AudioStreamPlayer,
		contact_audio: AudioStreamPlayer, actions: Dictionary,
		action_starts: Array[Dictionary]) -> String:
	var enemy_contacts: Array[Dictionary] = []
	var enemy_frames: Array = actions["encounters"][battle.combat.state["encounterId"]][
		"attack"]["animation"]["frames"]
	stage.contact_frame.connect(func(side: String) -> void:
		if side == "enemy":
			enemy_contacts.append({"playing": contact_audio.playing,
				"path": contact_audio.stream.resource_path if contact_audio.stream != null else "",
				"texture": enemy_actor.texture.resource_path if enemy_actor.texture != null else "",
				"at": Time.get_ticks_usec()}))
	battle.end_button.pressed.emit()
	await process_frame
	if battle.combat.state.get("phase") != "REACTION_OPEN" \
			or battle.combat.state.get("enemyIntent", {}).get("type") != "attack":
		return path_id + " source enemy attack was not offered"
	battle.reaction_buttons[0].pressed.emit()
	await create_timer(0.05).timeout
	if not start_audio.playing or start_audio.stream == null or \
			start_audio.stream.resource_path != "res://content/assets/audio/sfx/combat/sword_slash.mp3":
		return path_id + " source enemy attack cue did not play"
	for _step in range(100):
		if not enemy_contacts.is_empty():
			break
		await create_timer(0.05).timeout
	if enemy_contacts.is_empty() or not enemy_contacts[0]["playing"] or \
			enemy_contacts[0]["path"] != "res://content/assets/audio/sfx/combat/damage_hit.mp3":
		return path_id + " source enemy contact cue did not play: " + str(enemy_contacts)
	if path_id == "body" and enemy_contacts[0]["texture"] != "res://content/" + String(enemy_frames[2]):
		return "body enemy melee contact did not use source impact frame: " + str(enemy_contacts[0])
	var enemy_start := 0
	for entry in action_starts:
		if entry["side"] == "enemy":
			enemy_start = int(entry["at"])
	if path_id == "body" and (enemy_start == 0 or \
			int(enemy_contacts[0]["at"]) - enemy_start > 330000):
		return "body enemy melee contact missed source frame-start clock: " + \
			str({"start": enemy_start, "contact": enemy_contacts[0]})
	for _step in range(150):
		if battle.pending_presentations == 0 and not battle.combat.input_locked:
			break
		await create_timer(0.05).timeout
	if battle.pending_presentations != 0 or battle.combat.input_locked:
		return path_id + " source enemy animation did not finish"
	return ""


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
