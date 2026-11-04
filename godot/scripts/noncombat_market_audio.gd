extends Node

# AudioManager.js market layer. The three ambience profiles are procedural in
# the browser; they are generated as looped PCM here and never enter save data.
const MIX_RATE := 22050
const MARKET_PROFILES := {
	"amb_market_regulated": {"frequencies": [174.61, 261.63],
		"types": ["sine", "triangle"], "gain": 0.016, "pulse": 0.08},
	"amb_market_bazaar": {"frequencies": [196.0, 293.66, 392.0],
		"types": ["triangle", "sine", "sine"], "gain": 0.013, "pulse": 0.13},
	"amb_market_ghost": {"frequencies": [65.41, 98.0, 130.81],
		"types": ["sine", "sine", "triangle"], "gain": 0.011, "pulse": 0.045},
}
const MARKET_SFX := {
	"sfx_market_regulated": "regulated", "sfx_market_bazaar": "bazaar",
	"sfx_market_ghost": "ghost",
}

var ambience_player: AudioStreamPlayer
var transaction_player: AudioStreamPlayer
var _catalog: Dictionary
var _streams: Dictionary = {}
var _desired_ambience := ""
var _transaction_id := ""


func _init(catalog: Dictionary) -> void:
	_catalog = catalog
	ambience_player = AudioStreamPlayer.new()
	ambience_player.name = "MarketAmbience"
	ambience_player.bus = "BGM"
	add_child(ambience_player)
	transaction_player = AudioStreamPlayer.new()
	transaction_player.name = "MarketTransaction"
	transaction_player.bus = "SFX"
	add_child(transaction_player)


func set_presentation(presentation: Dictionary) -> bool:
	var ambience_id := String(presentation.get("ambienceId", ""))
	var transaction_id := String(presentation.get("transactionSfxId", ""))
	if not MARKET_PROFILES.has(ambience_id) or not MARKET_SFX.has(transaction_id):
		stop_market()
		return false
	_desired_ambience = ambience_id
	_transaction_id = transaction_id
	return refresh_mute()


func refresh_mute() -> bool:
	if _desired_ambience.is_empty() or AudioServer.is_bus_mute(
			AudioServer.get_bus_index("Master")):
		ambience_player.stop()
		return false
	if ambience_player.playing and ambience_player.get_meta("ambience_id", "") == \
			_desired_ambience:
		return true
	if not _streams.has(_desired_ambience):
		_streams[_desired_ambience] = _make_ambience(MARKET_PROFILES[_desired_ambience])
	ambience_player.stop()
	ambience_player.stream = _streams[_desired_ambience]
	ambience_player.set_meta("ambience_id", _desired_ambience)
	ambience_player.play()
	return true


func play_transaction() -> bool:
	if _transaction_id.is_empty() or AudioServer.is_bus_mute(
			AudioServer.get_bus_index("Master")):
		return false
	var key := String(MARKET_SFX[_transaction_id])
	var runtime: Dictionary = _catalog.get("sharedAssets", {}).get("market", {}).get(
		key, {}).get("runtime", {})
	if runtime.get("id") != _transaction_id or runtime.get("bus") != "sfx" \
			or not runtime.get("procedural") is Dictionary:
		return false
	transaction_player.stop()
	transaction_player.stream = _make_transaction(runtime)
	transaction_player.play()
	return true


func stop_market() -> void:
	_desired_ambience = ""
	_transaction_id = ""
	ambience_player.stop()


func stop_all() -> void:
	stop_market()
	transaction_player.stop()


func _make_ambience(profile: Dictionary) -> AudioStreamWAV:
	var pulse := float(profile.pulse)
	var count := ceili(float(MIX_RATE) / pulse)
	var pcm := PackedByteArray()
	pcm.resize(count * 2)
	var frequencies: Array = profile.frequencies
	var types: Array = profile.types
	var filtered := 0.0
	var alpha := 1.0 - exp(-TAU * 520.0 / MIX_RATE)
	for i in range(count):
		var time := float(i) / MIX_RATE
		var voice := 0.0
		for index in range(frequencies.size()):
			voice += _wave(TAU * float(frequencies[index]) * time,
				String(types[index])) / (frequencies.size() * 3.2)
		var gain := float(profile.gain) * (0.5 + 0.25 * sin(TAU * pulse * time))
		filtered += alpha * (voice * gain - filtered)
		var edge := minf(1.0, minf(float(i), float(count - i - 1)) / (MIX_RATE * 0.02))
		pcm.encode_s16(i * 2, clampi(roundi(filtered * edge * 32767.0), -32768, 32767))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MIX_RATE
	stream.stereo = false
	stream.data = pcm
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_end = count
	return stream


func _make_transaction(runtime: Dictionary) -> AudioStreamWAV:
	var profile: Dictionary = runtime.procedural
	var duration := maxf(0.04, float(profile.get("duration", 0.12)))
	var count := ceili(MIX_RATE * duration)
	var pcm := PackedByteArray()
	pcm.resize(count * 2)
	var frequency := maxf(20.0, float(profile.get("frequency", 440.0)))
	var amplitude := maxf(0.001, float(profile.get("gain", 0.1))) * 0.5 \
		* float(runtime.get("volume", 1.0))
	var filtered := 0.0
	var alpha := 1.0 - exp(-TAU * 1800.0 / MIX_RATE)
	for i in range(count):
		var time := float(i) / MIX_RATE
		var envelope := minf(1.0, time / 0.012) * exp(-7.0 * time / duration)
		filtered += alpha * (amplitude * envelope * _wave(
			TAU * frequency * time, String(profile.get("type", "sine"))) - filtered)
		pcm.encode_s16(i * 2, clampi(roundi(filtered * 32767.0), -32768, 32767))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MIX_RATE
	stream.stereo = false
	stream.data = pcm
	return stream


func _wave(phase: float, kind: String) -> float:
	return (2.0 / PI) * asin(sin(phase)) if kind == "triangle" else sin(phase)
