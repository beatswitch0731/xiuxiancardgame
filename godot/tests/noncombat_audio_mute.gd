extends SceneTree

const Registry = preload("res://scripts/runtime_data_registry.gd")
const OpeningAudio = preload("res://scripts/noncombat_opening_audio.gd")
const OpeningUI = preload("res://scripts/noncombat_opening_ui.gd")
const BattleStage = preload("res://scripts/duel_stage_source_2d.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://tests"))
	var setting_path := "user://tests/audio_mute_%d.cfg" % Time.get_ticks_usec()
	var audio = OpeningAudio.new(Registry.new(), null, setting_path)
	root.add_child(audio)
	await process_frame
	if audio.is_muted() or not audio.play_opening_music():
		return _fail("fresh audio preference or music")
	var music_stream: AudioStream = audio.bgm_player.stream
	if not audio.set_muted(true) or not audio.is_muted():
		return _fail("mute action")
	if audio.bgm_player.stream != music_stream or not audio.bgm_player.playing:
		return _fail("muting interrupted source music")
	if not audio.play_choice_snap() or not audio.play_path_oath("sword"):
		return _fail("muted audio lost source stream routing")
	var bus_index := AudioServer.get_bus_index("Master")
	if bus_index < 0 or not AudioServer.is_bus_mute(bus_index):
		return _fail("global audio output was not muted")
	var battlefield = BattleStage.new()
	root.add_child(battlefield)
	await process_frame
	for cue_name in ["SourceActionSfx", "SourceContactSfx"]:
		var cue: AudioStreamPlayer = battlefield.get_node(cue_name)
		if cue.bus != "Master" or not AudioServer.is_bus_mute(
				AudioServer.get_bus_index(cue.bus)):
			return _fail("battlefield sound escaped global mute: " + cue_name)
	battlefield.queue_free()
	await process_frame
	audio.queue_free()
	await process_frame
	var reopened = OpeningAudio.new(Registry.new(), null, setting_path)
	root.add_child(reopened)
	await process_frame
	if not reopened.is_muted() or not AudioServer.is_bus_mute(bus_index):
		return _fail("mute preference did not survive restart")
	if reopened.set_muted(false) or AudioServer.is_bus_mute(bus_index):
		return _fail("unmute action")
	reopened.queue_free()
	await process_frame
	var ui = OpeningUI.new()
	ui.save_path = ""
	ui.audio_settings_path = setting_path
	root.add_child(ui)
	await process_frame
	var button: Button = ui.find_child("ToggleAllAudio", true, false)
	if button == null or button.disabled:
		return _fail("desktop sound control is unavailable")
	if not ui.opening.start("sword"):
		return _fail("desktop story could not start")
	for resolution in [Vector2i(1280, 800), Vector2i(1920, 1080)]:
		root.get_window().size = resolution
		await process_frame
		await process_frame
		if button.get_global_rect().end.x > resolution.x \
				or button.get_global_rect().end.y > resolution.y:
			return _fail("sound control clipped at %s" % resolution)
	button.pressed.emit()
	if not ui.opening_audio.is_muted() or not AudioServer.is_bus_mute(bus_index):
		return _fail("desktop sound control did not mute audio")
	button.pressed.emit()
	if ui.opening_audio.is_muted() or AudioServer.is_bus_mute(bus_index):
		return _fail("desktop sound control did not unmute audio")
	ui.queue_free()
	await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(setting_path))
	print("NONCOMBAT_AUDIO_MUTE_PASS bus=true persisted=true ui=true")
	quit(0)

func _fail(message: String) -> void:
	push_error(message)
	quit(1)
