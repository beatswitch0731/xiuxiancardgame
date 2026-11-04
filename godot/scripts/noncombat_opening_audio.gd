extends Node
signal voice_subtitle_changed(line: String)

const ContentRepository = preload("res://scripts/noncombat_content_repository.gd")
const MarketAudio = preload("res://scripts/noncombat_market_audio.gd")

# Narrow audio consumer for the actual browser opening events. The catalog
# supplies paths and per-asset volumes; browser bus gains are source constants.
const AUDIO_ROOT := "res://content/assets/audio/"
const BUS_GAINS := {"bgm": 0.45, "ambience": 0.22, "sfx": 0.5, "voice": 0.6}
const MASTER_BUS := "Master"

var bgm_player: AudioStreamPlayer
var sfx_player: AudioStreamPlayer
var voice_player: AudioStreamPlayer
var ambience_player: AudioStreamPlayer
var ambience_tail_player: AudioStreamPlayer
var market_audio: Node
var _catalog: Dictionary = {}
var _bgm_linear := 0.0
var _loop_bgm := false
var _current_bgm_id := ""
var _loop_ambience := false
var _scene_id := ""
var _ambience_linear := 0.0
var _ambience_tween: Tween
var _mute_path := ""
var _muted := false


func _init(_registry: RefCounted, content_repository: RefCounted = null,
		mute_path: String = "user://noncombat_audio_settings.cfg") -> void:
	_mute_path = mute_path
	var settings := ConfigFile.new()
	if settings.load(_mute_path) == OK:
		_muted = settings.get_value("audio", "muted", false) == true
	AudioServer.set_bus_mute(AudioServer.get_bus_index(MASTER_BUS), _muted)
	var repository: RefCounted = content_repository if content_repository != null \
		else ContentRepository.new()
	var source: Variant = repository.read_module("audio:path_identity")
	_catalog = source if source is Dictionary else {}
	market_audio = MarketAudio.new(_catalog)
	market_audio.name = "SourceMarketAudio"
	add_child(market_audio)
	bgm_player = AudioStreamPlayer.new()
	bgm_player.name = "OpeningBgm"
	bgm_player.bus = MASTER_BUS
	add_child(bgm_player)
	sfx_player = AudioStreamPlayer.new()
	sfx_player.name = "ChoiceSfx"
	sfx_player.bus = MASTER_BUS
	add_child(sfx_player)
	voice_player = AudioStreamPlayer.new()
	voice_player.name = "PathOath"
	voice_player.bus = MASTER_BUS
	add_child(voice_player)
	ambience_player = AudioStreamPlayer.new()
	ambience_player.name = "SceneAmbience"
	ambience_player.bus = MASTER_BUS
	add_child(ambience_player)
	ambience_tail_player = AudioStreamPlayer.new()
	ambience_tail_player.name = "PreviousSceneAmbience"
	ambience_tail_player.bus = MASTER_BUS
	add_child(ambience_tail_player)
	bgm_player.finished.connect(_on_bgm_finished)
	voice_player.finished.connect(_on_voice_finished)
	ambience_player.finished.connect(_on_ambience_finished)


func is_muted() -> bool:
	return _muted


func set_muted(value: bool) -> bool:
	_muted = value
	AudioServer.set_bus_mute(AudioServer.get_bus_index(MASTER_BUS), _muted)
	market_audio.refresh_mute()
	var settings := ConfigFile.new()
	settings.set_value("audio", "muted", _muted)
	settings.save(_mute_path)
	return _muted


func play_opening_music() -> bool:
	return play_bgm_state("bgm_sect")


func play_bgm_state(bgm_id: String) -> bool:
	if bgm_id == _current_bgm_id and bgm_player.playing:
		return true
	var runtime: Dictionary = _catalog.get("bgmStates", {}).get(bgm_id, {}).get("runtime", {})
	if not _play(bgm_player, runtime, "bgm"):
		return false
	_current_bgm_id = bgm_id
	_loop_bgm = runtime.get("loop") == true
	_bgm_linear = BUS_GAINS["bgm"] * float(runtime.get("volume", 1.0))
	if bgm_id == "bgm_sect" and not _scene_id.is_empty():
		var scene: Dictionary = _catalog.get("openingSoundscapes", {}).get(
			"scenes", {}).get(_scene_id, {})
		_bgm_linear *= clampf(float(scene.get("musicGain", 1.0)), 0.0, 1.0)
		bgm_player.volume_db = linear_to_db(maxf(_bgm_linear, 0.001))
	return true


func play_karma_presentation() -> bool:
	var runtime: Dictionary = _catalog.get("sharedAssets", {}).get("world", {}).get(
		"karma", {}).get("runtime", {})
	return play_bgm_state("bgm_mystery") and _play(sfx_player, runtime, "sfx")


func play_path_oath(path_id: String) -> bool:
	var oath: Dictionary = _catalog.get("pathIdentities", {}).get(path_id, {}).get(
		"voice", {}).get("pathOath", {})
	var runtime: Dictionary = oath.get("runtime", {})
	if not _play(voice_player, runtime, "voice"):
		return false
	if bgm_player.playing:
		bgm_player.volume_db = linear_to_db(maxf(_bgm_linear * 0.42, 0.001))
	if ambience_player.playing:
		ambience_player.volume_db = linear_to_db(maxf(_ambience_linear * 0.45, 0.001))
	voice_subtitle_changed.emit(String(oath.get("subtitle", oath.get("line", ""))))
	return true


func set_story_scene(card_id: String, announce: bool = false) -> bool:
	var soundscapes: Dictionary = _catalog.get("openingSoundscapes", {})
	var next_scene_id := String(soundscapes.get("cardMap", {}).get(card_id, ""))
	var scene: Dictionary = soundscapes.get("scenes", {}).get(next_scene_id, {})
	if scene.is_empty():
		stop_scene()
		return false
	if next_scene_id == _scene_id and ambience_player.playing:
		return true
	if scene.get("musicId") != "bgm_sect":
		return false
	var runtime: Dictionary = scene.get("ambience", {}).get("runtime", {})
	if not _valid_runtime(runtime, "ambience"):
		return false
	var stream = load(AUDIO_ROOT + String(runtime["path"]))
	if not stream is AudioStream:
		return false
	if stream is AudioStreamWAV:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	elif stream is AudioStreamMP3 or stream is AudioStreamOggVorbis:
		stream.loop = true
	if _ambience_tween and _ambience_tween.is_running():
		_ambience_tween.kill()
	var reuse_ambience := ambience_player.playing and ambience_player.stream == stream
	voice_player.stop()
	voice_player.stream = null
	voice_subtitle_changed.emit("")
	ambience_tail_player.stop()
	if ambience_player.playing and not reuse_ambience:
		ambience_tail_player.stream = ambience_player.stream
		ambience_tail_player.volume_db = ambience_player.volume_db
		ambience_tail_player.play(ambience_player.get_playback_position())
	if not reuse_ambience:
		ambience_player.stop()
		ambience_player.stream = stream
	_scene_id = next_scene_id
	_loop_ambience = runtime.get("loop") == true
	if _current_bgm_id == "bgm_sect":
		_bgm_linear = BUS_GAINS["bgm"] * float(_catalog["bgmStates"]["bgm_sect"]["runtime"].get(
			"volume", 1.0)) * clampf(float(scene.get("musicGain", 1.0)), 0.0, 1.0)
		if bgm_player.playing:
			bgm_player.volume_db = linear_to_db(maxf(_bgm_linear, 0.001))
	_ambience_linear = BUS_GAINS["ambience"] * float(runtime.get("volume", 1.0))
	if not reuse_ambience:
		ambience_player.volume_db = linear_to_db(0.001)
		ambience_player.play()
	var oath_ok := true
	if announce and not String(scene.get("voicePath", "")).is_empty():
		oath_ok = play_path_oath(String(scene["voicePath"]))
	_ambience_tween = create_tween().set_parallel(true)
	_ambience_tween.tween_property(ambience_player, "volume_db",
		linear_to_db(maxf(_ambience_linear * (0.45 if voice_player.playing else 1.0), 0.001)), 0.35)
	if ambience_tail_player.playing:
		_ambience_tween.tween_property(ambience_tail_player, "volume_db", -60.0, 0.35)
		_ambience_tween.chain().tween_callback(func() -> void:
			ambience_tail_player.stop()
			ambience_tail_player.stream = null)
	return oath_ok


func stop_scene() -> void:
	_scene_id = ""
	_loop_ambience = false
	if _ambience_tween and _ambience_tween.is_running():
		_ambience_tween.kill()
	for player in [ambience_player, ambience_tail_player, voice_player]:
		player.stop()
		player.stream = null
	voice_subtitle_changed.emit("")
	if _current_bgm_id == "bgm_sect":
		_bgm_linear = BUS_GAINS["bgm"] * float(_catalog.get("bgmStates", {}).get(
			"bgm_sect", {}).get("runtime", {}).get("volume", 1.0))
		if bgm_player.playing:
			bgm_player.volume_db = linear_to_db(maxf(_bgm_linear, 0.001))


func play_choice_snap() -> bool:
	var runtime: Dictionary = _catalog.get("sharedAssets", {}).get("ui", {}).get(
		"snap", {}).get("runtime", {})
	return _play(sfx_player, runtime, "sfx")


func set_market_presentation(presentation: Dictionary) -> bool:
	return market_audio.set_presentation(presentation) if not presentation.is_empty() \
		else _stop_market_presentation()


func _stop_market_presentation() -> bool:
	market_audio.stop_market()
	return true


func play_market_transaction() -> bool:
	return market_audio.play_transaction()


func _play(player: AudioStreamPlayer, runtime: Dictionary, expected_bus: String) -> bool:
	if not _valid_runtime(runtime, expected_bus):
		return false
	var relative: String = runtime["path"]
	var stream = load(AUDIO_ROOT + relative)
	if not stream is AudioStream:
		return false
	player.stop()
	player.stream = stream
	player.volume_db = linear_to_db(maxf(
		float(BUS_GAINS[expected_bus]) * float(runtime.get("volume", 1.0)), 0.001))
	player.play()
	return true


func _valid_runtime(runtime: Dictionary, expected_bus: String) -> bool:
	if _catalog.get("assetRoot") != "assets/audio/" or runtime.get("bus") != expected_bus \
			or not runtime.get("path") is String:
		return false
	var relative: String = runtime["path"]
	return not relative.is_empty() and not relative.begins_with("/") \
		and not ".." in relative.split("/")


func _on_bgm_finished() -> void:
	if _loop_bgm:
		bgm_player.play()


func _on_voice_finished() -> void:
	voice_subtitle_changed.emit("")
	if bgm_player.playing:
		bgm_player.volume_db = linear_to_db(maxf(_bgm_linear, 0.001))
	if ambience_player.playing:
		ambience_player.volume_db = linear_to_db(maxf(_ambience_linear, 0.001))


func _on_ambience_finished() -> void:
	if _loop_ambience:
		ambience_player.play()


func stop_all() -> void:
	_loop_bgm = false
	_current_bgm_id = ""
	stop_scene()
	market_audio.stop_all()
	for player in [bgm_player, sfx_player]:
		player.stop()
		player.stream = null


func _exit_tree() -> void:
	stop_all()
