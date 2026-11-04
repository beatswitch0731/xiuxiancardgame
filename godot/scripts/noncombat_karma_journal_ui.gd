extends AcceptDialog

const KarmaJournal = preload("res://scripts/noncombat_karma_journal.gd")
const TextPresentation = preload("res://scripts/noncombat_text_presentation.gd")
const BADGES := {"karma": "善因", "grudge": "恶因",
	"bloodline": "血脉", "fate": "宿命"}

var _list: VBoxContainer


func _init() -> void:
	name = "KarmaJournal"
	title = "天道因果簿"
	min_size = Vector2i(680, 490)
	ok_button_text = "返回仙途"
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(640, 420)
	add_child(scroll)
	_list = VBoxContainer.new()
	_list.name = "KarmaJournalEntries"
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 14)
	scroll.add_child(_list)


func open_journal(state: Dictionary) -> void:
	for child in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	var seeds: Array[Dictionary] = KarmaJournal.new().entries(state)
	if seeds.is_empty():
		_add_line("天道清明，暂无发芽中的因果种子。\n你在世间的抉择将种下因果，于若干次决断后显现。")
	else:
		for seed in seeds:
			var timing := "播种决断：第 %d 次" % seed.originTurn if seed.originTurn > 0 \
				else "播种时机：入世之初"
			_add_line("%s · %s\n🌱 %d 次决断后发芽\n%s\n境界限制：%s · %s · 优先级：%d" % [
				seed.id, BADGES.get(seed.seedType, "善因"), seed.delay, seed.description,
				seed.realm, timing, seed.priority])
	popup_centered_ratio(0.72)


func _add_line(value: String) -> void:
	var label := Label.new()
	label.text = TextPresentation.normalize(value)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_list.add_child(label)
