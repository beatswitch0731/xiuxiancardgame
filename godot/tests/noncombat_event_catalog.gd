extends SceneTree

## 事件类型常量表 lint（S1 交付物）。
## 四条不变式，全部读文件文本，不实例化场景，headless 安全：
##   1. ALL 恰好 62 项、无重复、全大写
##   2. ALL 与 tests/fixtures/event_types_v1.json 冻结快照完全一致
##   3. _emit_event 体内仍存在白名单闸门（防止有人把闸门删掉）
##   4. is_event_type 对全部成员返回 true、对伪造名返回 false
## 运行：--headless --script res://tests/noncombat_event_catalog.gd

const EventTypes = preload("res://scripts/noncombat_event_types.gd")
const SNAPSHOT := "res://tests/fixtures/event_types_v1.json"
const DOMAIN := "res://scripts/noncombat_domain.gd"
const EXPECTED_COUNT := 62

var _fails: Array[String] = []


func _initialize() -> void:
	_check_count_and_shape()
	_check_snapshot()
	_check_gate_present()
	_check_lookup()
	if _fails.is_empty():
		print("NONCOMBAT_EVENT_CATALOG_PASS types=%d" % EventTypes.ALL.size())
		quit(0)
		return
	for f in _fails:
		printerr("NONCOMBAT_EVENT_CATALOG_FAIL " + f)
	quit(1)


func _check_count_and_shape() -> void:
	var all: Array = EventTypes.ALL
	if all.size() != EXPECTED_COUNT:
		_fails.append("ALL 应为 %d 项，实际 %d" % [EXPECTED_COUNT, all.size()])
	var seen := {}
	for entry in all:
		if not entry is String or String(entry).is_empty():
			_fails.append("ALL 含非字符串或空项")
			continue
		var name := String(entry)
		if name != name.to_upper():
			_fails.append("非全大写: " + name)
		if seen.has(name):
			_fails.append("重复项: " + name)
		seen[name] = true


func _check_snapshot() -> void:
	var raw := FileAccess.get_file_as_string(SNAPSHOT)
	if raw.is_empty():
		_fails.append("冻结快照缺失: " + SNAPSHOT)
		return
	var parsed: Variant = JSON.parse_string(raw)
	if not parsed is Dictionary:
		_fails.append("快照不是 JSON 对象")
		return
	var snapshot: Array = parsed.get("types", [])
	var current: Array = EventTypes.ALL
	if snapshot.size() != current.size():
		_fails.append("快照 %d 项与常量表 %d 项不一致"
			% [snapshot.size(), current.size()])
		return
	var snap_set := {}
	for item in snapshot:
		snap_set[String(item)] = true
	for name in current:
		if not snap_set.has(String(name)):
			_fails.append("常量表有、快照没有: " + String(name))
	for name in snapshot:
		if not current.has(String(name)):
			_fails.append("快照有、常量表没有: " + String(name))


func _check_gate_present() -> void:
	var src := FileAccess.get_file_as_string(DOMAIN)
	if not src.contains("EventTypes.is_event_type"):
		_fails.append("_emit_event 缺白名单闸门（EventTypes.is_event_type）")
	if not src.contains("unregistered event type"):
		_fails.append("_emit_event 缺未登记报错文案")
	if not src.contains("const EventTypes = preload"):
		_fails.append("domain 未 preload 常量表")


func _check_lookup() -> void:
	for name in EventTypes.ALL:
		if not EventTypes.is_event_type(String(name)):
			_fails.append("is_event_type 漏判: " + String(name))
			break
	if EventTypes.is_event_type("NOT_A_REAL_EVENT"):
		_fails.append("is_event_type 把伪造名判成了事件类型")
	# phase 名不得被当成事件类型（防误登记）
	for phase in ["NORMAL_PENDING", "COMBAT_HANDOFF", "DEATH_PENDING"]:
		if EventTypes.is_event_type(phase):
			_fails.append("phase 名被误登记为事件类型: " + phase)
