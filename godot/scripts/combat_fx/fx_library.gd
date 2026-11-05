class_name FxLibrary
extends RefCounted

## 语义特效路由器（VFX 方案批次 V1）。
## 职责：把 action_presentations.json 的 166 条 semanticVfx id
## 路由到 6 个参数化模板（impact / travel / skill / hurt / defeat / state）。
## 只做「id → 模板」的路由与帧路径查询，不构建节点（构建在 FxTemplate）。
##
## 层级纪律：L2（纯 RefCounted，可 headless 测试，禁止 preload .tscn）。

const PRESENTATIONS_PATH := "content/data/combat/action_presentations.json"
const TEMPLATES := ["impact", "travel", "skill", "hurt", "defeat", "state"]

## id 中出现这些词 → 对应模板；按长词优先避免子串误匹配。
const KIND_WORDS := [
	["contact", "impact"],
	["travel", "travel"],
	["skill", "skill"],
	["hurt", "hurt"],
	["defeat", "defeat"],
	["state", "state"],
]

var _entries: Dictionary = {}
var _routes: Dictionary = {}
var _last_error: String = ""


func _init() -> void:
	_load_entries()


func _load_entries() -> void:
	var f := FileAccess.open(PRESENTATIONS_PATH, FileAccess.READ)
	if f == null:
		_last_error = "semanticVfx source missing: " + PRESENTATIONS_PATH
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if not parsed is Dictionary:
		_last_error = "action_presentations.json is not a Dictionary"
		return
	var sv: Variant = parsed.get("semanticVfx")
	if not sv is Dictionary:
		_last_error = "semanticVfx section missing"
		return
	for id in sv:
		var entry: Variant = sv[id]
		if entry is Dictionary and entry.get("frames") is Array:
			_entries[String(id)] = entry
			_routes[String(id)] = _route_of(String(id))
	if _entries.is_empty():
		_last_error = "semanticVfx has no usable entries"


## 从 id 推导模板类型；无法识别时归入 impact（打击点是默认语义）。
func _route_of(id: String) -> String:
	var lower := id.to_lower()
	for pair in KIND_WORDS:
		if lower.contains(pair[0]):
			return pair[1]
	# 再看帧路径的目录名
	var entry: Dictionary = _entries.get(id, {})
	var frames: Array = entry.get("frames", [])
	if not frames.is_empty() and frames[0] is String:
		var folder := String(frames[0]).get_base_dir().to_lower()
		for pair in KIND_WORDS:
			if folder.contains(pair[0]):
				return pair[1]
	return "impact"


func last_error() -> String:
	return _last_error


func entry_count() -> int:
	return _entries.size()


func all_ids() -> Array:
	return _entries.keys()


func has_id(id: String) -> bool:
	return _entries.has(id)


func route_key(id: String) -> String:
	return String(_routes.get(id, ""))


func frame_paths(id: String) -> Array:
	var entry: Dictionary = _entries.get(id, {})
	return entry.get("frames", [])


func duration_ms(id: String) -> int:
	var entry: Dictionary = _entries.get(id, {})
	return int(entry.get("durationMs", 340))


## 每帧目标时长（秒）：总时长按 25/15/10/50 的不等权重分配，
## 模拟手绘动画"快进慢出"的 spacing（详见 VFX 方案 §3.2）。
func frame_durations(id: String) -> Array:
	var frames := frame_paths(id)
	var n := frames.size()
	var weights := [0.25, 0.15, 0.10, 0.50]
	var result: Array = []
	if n == 0:
		return result
	var total := 0.001 * float(duration_ms(id))
	var ws := []
	for i in n:
		ws.append(weights[i] if i < weights.size() else 0.05)
	var wsum := 0.0
	for w in ws:
		wsum += w
	for w in ws:
		result.append(total * (w / wsum))
	return result
