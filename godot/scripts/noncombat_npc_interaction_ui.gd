extends AcceptDialog

var domain: RefCounted
var _list: VBoxContainer
var _selected := ""


func _ready() -> void:
	title = "人物志"
	size = Vector2i(850, 680)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(780, 580)
	add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)


func show_roster(owner_domain: RefCounted) -> void:
	domain = owner_domain
	_selected = ""
	_refresh()
	popup_centered()


func _refresh() -> void:
	for child in _list.get_children():
		child.queue_free()
	if domain == null:
		return
	if _selected.is_empty():
		for row in domain.npc_roster():
			var button := Button.new()
			button.text = "%s · %s · %s" % [row.name, row.title, row.location]
			button.pressed.connect(_select.bind(String(row.id)))
			_list.add_child(button)
		return
	var back := Button.new()
	back.text = "← 人物列表"
	back.pressed.connect(_select.bind(""))
	_list.add_child(back)
	var panel: Dictionary = domain.npc_panel(_selected)
	if panel.is_empty():
		return
	_add_text("%s  %s" % [panel.npc.get("name", ""), panel.npc.get("title", "")])
	_add_text("%s · %s · %s · 好感 %d · 羁绊 %d · 信任 %d" % [panel.location,
		panel.emotion, panel.impression.overall, panel.affection, panel.bond, panel.trust])
	_add_text("心境：%s" % panel.mindset)
	_add_text("“%s”" % panel.dialogue if not String(panel.dialogue).is_empty() else "此刻无法当面交谈。")
	var history: Array = domain.state.get("npcInteractionHistory", [])
	if not history.is_empty() and history.back().get("npcId") == _selected:
		_add_text("刚才：%s" % history.back().get("reaction", ""))
	for info in panel.knownInfo:
		_add_text(String(info.text))
	for secret in panel.secrets:
		_add_text("秘闻：%s" % secret.get("text", ""))
	for memory in panel.recentInteractions:
		_add_text("第 %d 回合 %s：%s" % [memory.get("turn", 0),
			memory.get("action", ""), memory.get("reaction", "")])
	for action in panel.availableActions:
		if action == "告辞":
			continue
		if action == "赠礼":
			for item_id in domain.state.get("itemInventory", {}):
				if int(domain.state.itemInventory[item_id]) > 0:
					var gift := Button.new()
					gift.text = "赠礼 · %s" % item_id
					gift.pressed.connect(_act.bind(String(action), String(item_id)))
					_list.add_child(gift)
		else:
			var button := Button.new()
			button.text = String(action)
			button.pressed.connect(_act.bind(String(action), ""))
			_list.add_child(button)


func _add_text(value: String) -> void:
	var label := Label.new()
	label.text = value
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_list.add_child(label)


func _select(npc_id: String) -> void:
	_selected = npc_id
	_refresh()


func _act(action: String, item_id: String) -> void:
	if domain.interact_npc(_selected, action, item_id):
		_refresh()
