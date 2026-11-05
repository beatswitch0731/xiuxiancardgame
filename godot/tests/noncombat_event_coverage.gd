extends SceneTree

## 事件处理策略覆盖不变式（S2 交付物）。
##
## 背景：opening UI 的 _on_opening_changed 只有 19 个类型有专属分支，
## 其余 43 个类型「无分支」——但它们不影响画面（画面由 _render() 无条件重绘），
## 只是没有专属音效。过去这层事实是隐式的，看不出哪些类型被有意忽略。
##
## 本测试把 19 + 43 变成显式声明并强制闭合：并集必须等于 62，交集必须为空。
## 新增事件类型却忘了登记策略时，这里立刻变红。
##
## 运行：--headless --script res://tests/noncombat_event_coverage.gd

const EventTypes = preload("res://scripts/noncombat_event_types.gd")
const UI_SCRIPT := "res://scripts/noncombat_opening_ui.gd"
const EXPECTED_HANDLED := 19
const EXPECTED_AUDIO_ONLY := 43

var _fails: Array[String] = []


func _initialize() -> void:
	var constants: Dictionary = (load(UI_SCRIPT) as Script).get_script_constant_map()
	var handled: Array = constants.get("HANDLED_ALL", [])
	var audio_only: Array = constants.get("AUDIO_ONLY_EVENTS", [])
	var all_types: Array = EventTypes.ALL

	_check("HANDLED_ALL 缺失或为空", not handled.is_empty())
	_check("AUDIO_ONLY_EVENTS 缺失或为空", not audio_only.is_empty())
	_check("HANDLED_ALL 应为 %d 项，实际 %d" % [EXPECTED_HANDLED, handled.size()],
		handled.size() == EXPECTED_HANDLED)
	_check("AUDIO_ONLY_EVENTS 应为 %d 项，实际 %d" % [EXPECTED_AUDIO_ONLY, audio_only.size()],
		audio_only.size() == EXPECTED_AUDIO_ONLY)

	var handled_set := {}
	for name in handled:
		handled_set[String(name)] = true
	var audio_set := {}
	for name in audio_only:
		audio_set[String(name)] = true

	# 交集必须为空
	for name in handled_set:
		_check("类型同时出现在两个策略里: " + name, not audio_set.has(name))

	# 并集必须等于 ALL
	var union := {}
	for name in handled_set:
		union[name] = true
	for name in audio_set:
		union[name] = true
	for name in all_types:
		_check("事件类型未登记策略: " + String(name), union.has(String(name)))
	for name in union:
		_check("策略里有未定义的事件类型: " + name, all_types.has(name))
	_check("并集大小 %d 应等于 ALL 的 %d" % [union.size(), all_types.size()],
		union.size() == all_types.size())

	# 已知无分支的两个必须落在 AUDIO_ONLY（历史上被静默忽略过）
	_check("KARMA_CHOSEN 应在 AUDIO_ONLY_EVENTS",
		audio_set.has("KARMA_CHOSEN"))
	_check("QUEST_CHOSEN 应在 AUDIO_ONLY_EVENTS",
		audio_set.has("QUEST_CHOSEN"))

	if _fails.is_empty():
		print("NONCOMBAT_EVENT_COVERAGE_PASS handled=%d audio_only=%d total=%d"
			% [handled.size(), audio_only.size(), union.size()])
		quit(0)
		return
	for f in _fails:
		printerr("NONCOMBAT_EVENT_COVERAGE_FAIL " + f)
	quit(1)


func _check(message: String, condition: bool) -> void:
	if not condition:
		_fails.append(message)
