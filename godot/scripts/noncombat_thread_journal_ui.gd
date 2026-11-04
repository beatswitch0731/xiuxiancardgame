extends AcceptDialog

const ThreadJournal = preload("res://scripts/noncombat_thread_journal.gd")
const TextPresentation = preload("res://scripts/noncombat_text_presentation.gd")

var _journal: RefCounted
var _list: VBoxContainer


func _init(repository: RefCounted) -> void:
	_journal = ThreadJournal.new(repository)
	name = "ThreadJournal"
	title = "故事线"
	min_size = Vector2i(680, 520)
	ok_button_text = "返回仙途"
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(640, 450)
	add_child(scroll)
	_list = VBoxContainer.new()
	_list.name = "ThreadJournalEntries"
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 10)
	scroll.add_child(_list)


func open_journal(state: Dictionary) -> void:
	for child in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	var snapshot: Dictionary = _journal.project(state)
	_add_line("进行中的线程")
	if snapshot.active.is_empty():
		_add_line("暂无活跃故事线")
	else:
		for row in snapshot.active:
			_add_line("%s · 第 %d 次决断 · %s · %s" % [row.title,
				row.startedTurn, _phase_label(row.phase), row.progress])
	_add_line("最近完成的线程")
	if snapshot.completed.is_empty():
		_add_line("尚无完成的故事线")
	else:
		for row in snapshot.completed:
			_add_line("%s · %s · 第 %d 次决断" % [row.title, row.note, row.turn])
	_add_line("因果线索")
	if snapshot.seeds.is_empty():
		_add_line("暂无线索等待发芽")
	else:
		for row in snapshot.seeds:
			_add_line("%s · 来源：%s" % [row.title, row.origin])
	popup_centered_ratio(0.74)


func _phase_label(phase: String) -> String:
	return {"beginning": "开端", "middle": "发展", "climax": "高潮",
		"resolution": "结局", "active": "进行中"}.get(phase, "进行中")


func _add_line(value: String) -> void:
	var label := Label.new()
	label.text = TextPresentation.normalize(value)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_list.add_child(label)
