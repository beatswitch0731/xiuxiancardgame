extends AcceptDialog

const Gallery = preload("res://scripts/noncombat_heavenly_gallery.gd")
const TextPresentation = preload("res://scripts/noncombat_text_presentation.gd")
const SETTINGS_PATH := "user://noncombat_gallery_settings.cfg"
const PAGE_SIZE := 48

var _gallery: RefCounted
var _registry: RefCounted
var _category := "portraits"
var _page := 0
var _filtered: Array[Dictionary] = []
var _search: LineEdit
var _category_picker: OptionButton
var _list: ItemList
var _summary: Label
var _page_label: Label
var _previous: Button
var _next: Button
var _portrait: TextureRect
var _detail_title: Label
var _detail_text: RichTextLabel
var _mode: CheckButton
var _settings_path := SETTINGS_PATH


func _init(repository: RefCounted, registry: RefCounted,
		settings_path: String = SETTINGS_PATH) -> void:
	_gallery = Gallery.new(repository)
	_registry = registry
	_settings_path = settings_path
	title = "天道 · 万物尽览"
	name = "HeavenlyGallery"
	min_size = Vector2i(950, 620)
	ok_button_text = "返回仙途"
	_build()
	var settings := ConfigFile.new()
	if settings.load(_settings_path) == OK:
		_mode.set_pressed_no_signal(settings.get_value("gallery", "heavenlyMode", false) == true)


func open_gallery(category: String = "portraits") -> void:
	if Gallery.CATEGORIES.has(category):
		_category = category
	_category_picker.select(_category_index(_category))
	_page = 0
	_set_mode(true)
	_render_page()
	popup_centered_ratio(0.85)
	_search.grab_focus.call_deferred()


func is_mode_enabled() -> bool:
	return _mode.button_pressed


func _build() -> void:
	var shell := VBoxContainer.new()
	shell.custom_minimum_size = Vector2(900, 550)
	shell.add_theme_constant_override("separation", 10)
	add_child(shell)
	var heading := HBoxContainer.new()
	shell.add_child(heading)
	_mode = CheckButton.new()
	_mode.name = "HeavenlyModeSwitch"
	_mode.text = "天道模式 · 查看全部"
	_mode.button_pressed = true
	_mode.toggled.connect(_on_mode_toggled)
	heading.add_child(_mode)
	_search = LineEdit.new()
	_search.name = "GallerySearch"
	_search.placeholder_text = "搜索角色、衣相、剧情或器物"
	_search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_search.text_changed.connect(func(_text: String) -> void:
		_page = 0
		_render_page())
	heading.add_child(_search)
	_category_picker = OptionButton.new()
	_category_picker.name = "GalleryCategory"
	for category_id in Gallery.CATEGORIES:
		_category_picker.add_item(Gallery.CATEGORIES[category_id])
		_category_picker.set_item_metadata(_category_picker.item_count - 1, category_id)
	_category_picker.item_selected.connect(func(index: int) -> void:
		_category = String(_category_picker.get_item_metadata(index))
		_page = 0
		_render_page())
	heading.add_child(_category_picker)
	_summary = Label.new()
	_summary.name = "GallerySummary"
	shell.add_child(_summary)
	var content := HBoxContainer.new()
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 14)
	shell.add_child(content)
	_list = ItemList.new()
	_list.name = "GalleryEntries"
	_list.custom_minimum_size = Vector2(425, 420)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_list.item_selected.connect(_show_selected)
	content.add_child(_list)
	var detail := VBoxContainer.new()
	detail.custom_minimum_size = Vector2(425, 420)
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(detail)
	_portrait = TextureRect.new()
	_portrait.name = "GalleryPortrait"
	_portrait.custom_minimum_size = Vector2(350, 220)
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	detail.add_child(_portrait)
	_detail_title = Label.new()
	_detail_title.name = "GalleryDetailTitle"
	_detail_title.add_theme_font_size_override("font_size", 21)
	_detail_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.add_child(_detail_title)
	_detail_text = RichTextLabel.new()
	_detail_text.name = "GalleryDetailText"
	_detail_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_detail_text.scroll_active = true
	detail.add_child(_detail_text)
	var pager := HBoxContainer.new()
	pager.alignment = BoxContainer.ALIGNMENT_CENTER
	shell.add_child(pager)
	_previous = Button.new()
	_previous.text = "上一页"
	_previous.pressed.connect(func() -> void:
		_page -= 1
		_render_page())
	pager.add_child(_previous)
	_page_label = Label.new()
	_page_label.name = "GalleryPage"
	pager.add_child(_page_label)
	_next = Button.new()
	_next.text = "下一页"
	_next.pressed.connect(func() -> void:
		_page += 1
		_render_page())
	pager.add_child(_next)


func _render_page() -> void:
	_filtered = _gallery.filter(_category, _search.text)
	var pages := maxi(1, ceili(float(_filtered.size()) / PAGE_SIZE))
	_page = clampi(_page, 0, pages - 1)
	_summary.text = "%s · %d 项可查看" % [Gallery.CATEGORIES[_category], _filtered.size()]
	_page_label.text = "%d / %d" % [_page + 1, pages]
	_previous.disabled = _page == 0
	_next.disabled = _page >= pages - 1
	_list.clear()
	_portrait.texture = null
	_detail_title.text = ""
	_detail_text.text = ""
	for index in range(_page * PAGE_SIZE, mini((_page + 1) * PAGE_SIZE, _filtered.size())):
		var entry: Dictionary = _filtered[index]
		var icon: Texture2D = _registry.texture_for(String(entry.asset)) \
			if not String(entry.asset).is_empty() else null
		_list.add_item(String(entry.title) + " · " + String(entry.subtitle), icon)
	if _list.item_count > 0:
		_list.select(0)
		_show_selected(0)


func _show_selected(page_index: int) -> void:
	var index := _page * PAGE_SIZE + page_index
	if index < 0 or index >= _filtered.size():
		return
	var entry: Dictionary = _filtered[index]
	_portrait.texture = _registry.texture_for(String(entry.asset)) \
		if not String(entry.asset).is_empty() else null
	_detail_title.text = "%s · %s" % [entry.title, entry.subtitle]
	_detail_text.text = _describe(entry.data)


func _describe(node: Dictionary) -> String:
	var sections: Array[Dictionary] = []
	_append_section(sections, "", _first_string(node, ["description", "desc",
		"summary", "firstMeeting", "text", "epilogue", "flavor"]))
	if node.get("flavor") is String and (sections.is_empty() \
			or node.flavor != sections[0].text):
		_append_section(sections, "余音", node.flavor)
	_append_section(sections, "隐秘", node.get("secrets"))
	_append_section(sections, "情报", node.get("knownInfo"))
	_append_section(sections, "传闻", node.get("gossipTopics"))
	var dialogues: Variant = node.get("dialogues")
	if dialogues is Array:
		var talks: Array[String] = []
		for dialogue in dialogues:
			if dialogue is Dictionary:
				var parts: Array[String] = []
				for field in ["scene", "text"]:
					if dialogue.get(field) is String and not String(dialogue[field]).is_empty():
						parts.append(String(dialogue[field]))
				if not parts.is_empty():
					talks.append(" · ".join(parts))
		_append_section(sections, "交谈", talks)
	var choices: Variant = node.get("choices")
	if choices is Dictionary or choices is Array:
		var choice_rows: Array[String] = []
		for choice in choices.values() if choices is Dictionary else choices:
			if not choice is Dictionary:
				continue
			var parts: Array[String] = []
			for field in ["text", "desc", "description", "narrativeBlock"]:
				if field == "description" and choice.get("desc") is String \
						and not String(choice.desc).is_empty():
					continue
				if choice.get(field) is String and not String(choice[field]).is_empty():
					parts.append(String(choice[field]))
			if not parts.is_empty():
				choice_rows.append("\n".join(parts))
		_append_section(sections, "此刻的抉择", choice_rows)
	var authored_choices: Array[String] = []
	for field in ["leftText", "leftDesc", "rightText", "rightDesc",
			"upText", "downText"]:
		if node.get(field) is String and not String(node[field]).is_empty():
			authored_choices.append(String(node[field]))
	_append_section(sections, "此刻的抉择", authored_choices)
	_append_section(sections, "结语", _first_string(node, ["endingText", "conclusion"]))
	_append_section(sections, "来历", node.get("narrative"))
	if sections.is_empty():
		return "此项已收录，暂未记下更多文字。"
	var rendered: Array[String] = []
	for section in sections:
		if not String(section.title).is_empty():
			rendered.append(String(section.title))
		rendered.append(TextPresentation.normalize(section.text))
	return "\n\n".join(rendered)


func _append_section(sections: Array[Dictionary], heading: String, values: Variant) -> void:
	var texts: Array[String] = []
	var items: Array = values if values is Array else [values]
	for value in items:
		var candidate: Variant = value
		if value is Dictionary:
			candidate = _first_string(value, ["text", "description", "desc", "summary"])
		if candidate is String and not String(candidate).is_empty():
			texts.append(String(candidate))
	if not texts.is_empty():
		sections.append({"title": heading, "text": "\n\n".join(texts)})


func _first_string(node: Dictionary, fields: Array) -> String:
	for field in fields:
		if node.get(field) is String and not String(node[field]).is_empty():
			return String(node[field])
	return ""


func _category_index(category: String) -> int:
	for index in range(_category_picker.item_count):
		if _category_picker.get_item_metadata(index) == category:
			return index
	return 0


func _on_mode_toggled(enabled: bool) -> void:
	_set_mode(enabled)
	if not enabled:
		hide()


func _set_mode(enabled: bool) -> void:
	_mode.set_pressed_no_signal(enabled)
	var settings := ConfigFile.new()
	settings.set_value("gallery", "heavenlyMode", enabled)
	settings.save(_settings_path)
