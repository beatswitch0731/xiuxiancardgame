extends SceneTree

## 音频总线门禁。
## 确认 default_bus_layout.tres 被加载，且每条子总线都送到 Master。
## headless 用 dummy 驱动，但总线配置仍应正常加载。

const EXPECTED := ["Master", "BGM", "SFX", "Voice", "UI"]


func _initialize() -> void:
	var failures: Array[String] = []
	var count := AudioServer.bus_count
	if count != EXPECTED.size():
		failures.append("总线数 %d，期望 %d" % [count, EXPECTED.size()])
	var limit := mini(count, EXPECTED.size())
	for index in limit:
		var actual := String(AudioServer.get_bus_name(index))
		if actual != EXPECTED[index]:
			failures.append("总线 %d 名为 '%s'，期望 '%s'" % [index, actual, EXPECTED[index]])
	for index in range(1, count):
		var send := String(AudioServer.get_bus_send(index))
		if send != "Master":
			failures.append("'%s' 的 send 是 '%s'，期望 Master" % [
				String(AudioServer.get_bus_name(index)), send])
	if failures.is_empty():
		print("AUDIO_BUS_LAYOUT_PASS buses=%d names=%s" % [
			count, ",".join(EXPECTED)])
		quit(0)
		return
	for line in failures:
		printerr("AUDIO_BUS_LAYOUT_FAIL " + line)
	quit(1)
