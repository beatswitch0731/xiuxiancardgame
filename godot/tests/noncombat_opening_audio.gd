extends SceneTree

const Registry = preload("res://scripts/runtime_data_registry.gd")
const OpeningAudio = preload("res://scripts/noncombat_opening_audio.gd")
const ContentRepository = preload("res://scripts/noncombat_content_repository.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var registry = Registry.new()
	var catalog: Dictionary = registry.read_json("data/audio/path_identity.json")
	var audio = OpeningAudio.new(registry)
	root.add_child(audio)
	await process_frame
	if not audio.play_opening_music():
		_fail("source sect BGM was not accepted")
		return
	var expected_bgm: String = catalog["bgmStates"]["bgm_sect"]["runtime"]["path"]
	if audio.bgm_player.stream == null or not audio.bgm_player.stream.resource_path.ends_with(expected_bgm) \
			or not audio.bgm_player.playing \
			or not is_equal_approx(db_to_linear(audio.bgm_player.volume_db), 0.45 * 0.72):
		_fail("source BGM asset was not mounted on the Godot player")
		return
	for path_id in ["sword", "spell", "body", "pill"]:
		if not audio.play_path_oath(path_id):
			_fail("authored oath was not accepted: " + path_id)
			return
		var expected_voice: String = catalog["pathIdentities"][path_id]["voice"]["pathOath"]["runtime"]["path"]
		if audio.voice_player.stream == null \
				or not audio.voice_player.stream.resource_path.ends_with(expected_voice) \
				or not is_equal_approx(db_to_linear(audio.voice_player.volume_db), 0.6 * 0.86) \
				or not is_equal_approx(db_to_linear(audio.bgm_player.volume_db), 0.45 * 0.72 * 0.42):
			_fail("authored oath asset did not match catalog: " + path_id)
			return
	audio.voice_player.finished.emit()
	if not is_equal_approx(db_to_linear(audio.bgm_player.volume_db), 0.45 * 0.72):
		_fail("source BGM level was not restored after the oath")
		return
	if audio.play_path_oath("unknown") or not audio.play_choice_snap():
		_fail("unknown path played a voice or source choice snap was missing")
		return
	var expected_snap: String = catalog["sharedAssets"]["ui"]["snap"]["runtime"]["path"]
	if audio.sfx_player.stream == null or not audio.sfx_player.stream.resource_path.ends_with(expected_snap) \
			or not is_equal_approx(db_to_linear(audio.sfx_player.volume_db), 0.5 * 0.5):
		_fail("source choice snap asset was not mounted")
		return
	var soundscapes: Dictionary = catalog["openingSoundscapes"]
	if not audio.set_story_scene("tutorial_1") or audio.voice_player.playing \
			or audio.ambience_player.stream == null:
		_fail("tutorial must have quiet mountain ambience and no spoken path oath")
		return
	for path_id in ["sword", "spell", "body", "pill"]:
		var card_id: String = "q_start_" + path_id
		if not audio.set_story_scene(card_id, true):
			_fail("source prologue soundscape missing: " + card_id)
			return
		var scene_id: String = soundscapes["cardMap"][card_id]
		var ambience_path: String = soundscapes["scenes"][scene_id]["ambience"]["runtime"]["path"]
		var oath_path: String = catalog["pathIdentities"][path_id]["voice"]["pathOath"]["runtime"]["path"]
		if not audio.ambience_player.stream.resource_path.ends_with(ambience_path) \
				or not audio.voice_player.stream.resource_path.ends_with(oath_path):
			_fail("prologue ambience or spoken oath mismatched: " + path_id)
			return
		var imported_loop: Variant = audio.ambience_player.stream.get("loop")
		if audio.ambience_player.stream is AudioStreamWAV:
			imported_loop = audio.ambience_player.stream.get("loop_mode") != 0
		if imported_loop != true:
			_fail("prologue ambience import must loop without a restart gap: " + path_id)
			return
		await create_timer(0.4).timeout
		if audio.ambience_tail_player.playing:
			_fail("previous location ambience lingered after the crossfade: " + path_id)
			return
		var scene_gain: float = float(soundscapes["scenes"][scene_id]["musicGain"])
		var ambience_gain: float = float(soundscapes["scenes"][scene_id]["ambience"]["runtime"]["volume"])
		if not is_equal_approx(db_to_linear(audio.bgm_player.volume_db),
				0.45 * 0.72 * scene_gain * 0.42) \
				or not is_equal_approx(db_to_linear(audio.ambience_player.volume_db),
				0.22 * ambience_gain * 0.45):
			_fail("spoken oath was not protected by music and ambience ducking: " + path_id)
			return
		audio.voice_player.finished.emit()
		if not is_equal_approx(db_to_linear(audio.bgm_player.volume_db),
				0.45 * 0.72 * scene_gain):
			_fail("scene music was not restored after the oath: " + path_id)
			return
	audio.voice_player.stop()
	if not audio.set_story_scene("q_start_pill", true) or audio.voice_player.playing:
		_fail("rerendering the same story card must not replay its oath")
		return
	audio.stop_scene()
	if not audio.set_story_scene("q_start_sword") or audio.voice_player.playing:
		_fail("restored prologue must resume its atmosphere without repeating dialogue")
		return
	if audio.set_story_scene("enc_trial_sword_swift") or audio.ambience_player.playing:
		_fail("combat handoff must retire the prologue ambience")
		return
	if not audio.has_method("play_bgm_state"):
		_fail("source BGM state switch is absent")
		return
	for bgm_id in ["bgm_combat", "bgm_boss", "bgm_mystery", "bgm_sect"]:
		if not audio.play_bgm_state(bgm_id):
			_fail("source BGM state was rejected: " + bgm_id)
			return
		var runtime: Dictionary = catalog["bgmStates"][bgm_id]["runtime"]
		if audio.bgm_player.stream == null or not audio.bgm_player.stream.resource_path.ends_with(
				String(runtime["path"])) or not audio.bgm_player.playing \
				or not is_equal_approx(db_to_linear(audio.bgm_player.volume_db),
					0.45 * float(runtime["volume"])):
			_fail("source BGM state asset or gain diverged: " + bgm_id)
			return
	if audio.play_bgm_state("unknown"):
		_fail("unknown BGM state was accepted")
		return
	audio.bgm_player.stop()
	audio.bgm_player.finished.emit()
	if not audio.bgm_player.playing:
		_fail("catalogued opening BGM did not loop")
		return
	audio.stop_all()
	audio.queue_free()
	await create_timer(0.2).timeout
	var manifest: Dictionary = JSON.parse_string(
		FileAccess.get_file_as_string("res://content/source_manifest.json"))
	for entry in manifest["data"]:
		if entry.get("path") == "data/audio/path_identity.json":
			entry["sha256"] = "0".repeat(64)
			break
	var fixture_path := "user://noncombat_audio_corrupt_manifest_test.json"
	var fixture := FileAccess.open(fixture_path, FileAccess.WRITE)
	fixture.store_string(JSON.stringify(manifest))
	fixture.close()
	var invalid_audio = OpeningAudio.new(registry, ContentRepository.new(fixture_path))
	root.add_child(invalid_audio)
	var accepted: bool = invalid_audio.play_opening_music()
	invalid_audio.queue_free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(fixture_path))
	if accepted:
		_fail("opening audio accepted a source catalog with a broken SHA")
		return
	print("NONCOMBAT_OPENING_AUDIO_PASS bgm=4 soundscapes=5 oath=4 snap=1 duck=4")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
