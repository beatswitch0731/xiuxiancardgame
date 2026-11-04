extends "res://tests/noncombat_qi_gate_entry.gd"

## 事件类型探针（P4 交付物）。
##
## 走真实剧情路线触发事件，导出 NoncombatDomain 实际发出的事件类型与次数。
## 用途：与 UI 的 19 个 event.get("type") 分支对照，回答两个问题：
##   1. UI 处理的分支里，哪些从来没有事件进来（死分支）
##   2. domain 发出的事件里，哪些 UI 完全没处理（静默忽略）
##
## 这是把 changed(Dictionary) 拆成强类型信号的前置证据——
## 没有真实清单就拆信号，等于凭猜测定 API。


func _run() -> void:
	var first: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	var second: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SECOND_FIXTURE))
	var third: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(THIRD_FIXTURE))
	var file := "user://tests/event_probe_%d.json" % Time.get_ticks_usec()
	var game = Domain.new(Registry.new(), Session.new(file, "slot_2"), "slot_2")
	_quiet_ambient(game)
	if not _open_third_alt(game, first, second, third):
		return _stop("third-alt prefix failed")
	if not game.has_method("event_type_report"):
		return _stop("event_type_report missing — _emit_event not wired")
	var report: Dictionary = game.event_type_report()
	if report.is_empty():
		return _stop("no events recorded during prefix")
	var keys: Array = report.keys()
	keys.sort()
	print("EVENT_TYPE_PROBE_PASS types=%d" % keys.size())
	var summary: Array[String] = []
	for key in keys:
		summary.append("%s x%d" % [key, int(report[key])])
	print("EVENT_TYPES " + ", ".join(summary))
	quit(0)


func _stop(message: String) -> void:
	printerr("EVENT_TYPE_PROBE_FAIL " + message)
	quit(1)
