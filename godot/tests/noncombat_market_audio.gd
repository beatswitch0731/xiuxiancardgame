extends SceneTree

const Registry = preload("res://scripts/runtime_data_registry.gd")
const OpeningAudio = preload("res://scripts/noncombat_opening_audio.gd")
const ContentRepository = preload("res://scripts/noncombat_content_repository.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var registry = Registry.new()
	var catalog: Dictionary = registry.read_json("data/audio/path_identity.json")
	var vendors: Dictionary = registry.read_json("data/markets/vendor_profiles.json")
	var content = ContentRepository.new()
	var setting_path := "user://tests/market_audio_%d.cfg" % Time.get_ticks_usec()
	var audio = OpeningAudio.new(registry, content, setting_path)
	root.add_child(audio)
	await process_frame
	if not audio.play_opening_music():
		return _fail("sect music did not start")
	var original_bgm: AudioStream = audio.bgm_player.stream
	var profiles: Array = vendors.get("vendors", [])
	if profiles.size() != 3:
		return _fail("three source vendor presentations expected")
	for vendor in profiles:
		var presentation: Dictionary = vendor.get("presentationProfile", {})
		var ambience_id := String(presentation.get("ambienceId", ""))
		var transaction_id := String(presentation.get("transactionSfxId", ""))
		if not audio.set_market_presentation(presentation):
			return _fail("vendor ambience failed: " + ambience_id)
		await process_frame
		var player: AudioStreamPlayer = audio.market_audio.ambience_player
		var stream: AudioStreamWAV = player.stream
		if not player.playing or player.get_meta("ambience_id", "") != ambience_id \
				or stream == null or stream.loop_mode != AudioStreamWAV.LOOP_FORWARD \
				or stream.loop_end != stream.data.size() / 2 \
				or stream.data.is_empty() or not _has_sound(stream.data) \
				or audio.bgm_player.stream != original_bgm or not audio.bgm_player.playing:
			return _fail("market ambience did not layer over sect music: " + ambience_id)
		if audio.market_audio.transaction_player.playing or audio.market_audio.transaction_player.stream != null:
			return _fail("opening vendor played a transaction cue")
		var key := String(vendor.get("marketType", ""))
		if key == "public_bazaar":
			key = "bazaar"
		var runtime: Dictionary = catalog.get("sharedAssets", {}).get("market", {}).get(
			key, {}).get("runtime", {})
		var indexed: Dictionary = content.find("audio", transaction_id)
		var media: Dictionary = content.audio_status(transaction_id)
		if indexed.get("data") != runtime \
				or indexed.get("sourcePath") != "data/audio/path_identity.json" \
				or indexed.get("jsonPointer") != "$.sharedAssets.market.%s.runtime" % key \
				or media.get("disposition") != "generated_stream" \
				or media.get("runtimePath") != "" \
				or runtime.get("id") != transaction_id \
				or not audio.play_market_transaction():
			return _fail("committed transaction cue missing: " + transaction_id)
		var cue: AudioStreamWAV = audio.market_audio.transaction_player.stream
		if cue == null or not _has_sound(cue.data) or not audio.market_audio.transaction_player.playing \
				or not is_equal_approx(cue.get_length(), float(runtime.procedural.duration)):
			return _fail("transaction PCM did not match catalog: " + transaction_id)
		if not audio.set_muted(true) or player.playing or audio.play_market_transaction():
			return _fail("mute left market audio active: " + ambience_id)
		var unmute_result: bool = audio.set_muted(false)
		await process_frame
		if unmute_result or not player.playing \
				or player.get_meta("ambience_id", "") != ambience_id:
			return _fail("unmute did not resume the active vendor: %s result=%s playing=%s meta=%s" % [
				ambience_id, unmute_result, player.playing, player.get_meta("ambience_id", "")])
		audio.set_market_presentation({})
		if player.playing or not audio.market_audio.transaction_player.playing:
			return _fail("vendor close stopped the committed cue or left ambience active: " + ambience_id)
		audio.market_audio.transaction_player.stop()
		audio.market_audio.transaction_player.stream = null
	if audio.set_market_presentation({"ambienceId": "invalid", "transactionSfxId": "invalid"}) \
			or audio.play_market_transaction():
		return _fail("unknown vendor activated a source market cue")
	audio.stop_all()
	original_bgm = null
	audio.queue_free()
	await process_frame
	await create_timer(0.25).timeout
	DirAccess.remove_absolute(ProjectSettings.globalize_path(setting_path))
	print("NONCOMBAT_MARKET_AUDIO_PASS profiles=3 layered=3 transactions=3 mute=3")
	quit(0)


func _has_sound(data: PackedByteArray) -> bool:
	for index in range(0, data.size(), 2):
		if data.decode_s16(index) != 0:
			return true
	return false


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
