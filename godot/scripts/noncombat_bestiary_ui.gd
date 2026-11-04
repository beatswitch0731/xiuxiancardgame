extends AcceptDialog
const TextPresentation = preload("res://scripts/noncombat_text_presentation.gd")

# Player-state Bestiary. All rows read the current Domain snapshot; the only
# writes use Domain's existing portrait/focus transactions.
const LegacyFragmentFlow = preload("res://scripts/noncombat_legacy_fragment_flow.gd")
const PathSkillFlow = preload("res://scripts/noncombat_path_skill_flow.gd")

var _repository: RefCounted
var _registry: RefCounted
var _domain: RefCounted
var _tabs: TabContainer
var _panels := {}
var _portrait_dialog: AcceptDialog
var _portrait_texture: TextureRect
var _portrait_title: Label
var _portrait_buttons: VBoxContainer


func _init(repository: RefCounted, registry: RefCounted) -> void:
	_repository = repository
	_registry = registry
	name = "PlayerBestiary"
	title = "万物志"
	min_size = Vector2i(800, 570)
	ok_button_text = "返回仙途"
	_tabs = TabContainer.new()
	_tabs.name = "BestiaryTabs"
	_tabs.custom_minimum_size = Vector2(760, 480)
	add_child(_tabs)
	for row in [{"id": "companions", "title": "道侣"},
			{"id": "items", "title": "万物"},
			{"id": "techniques", "title": "功法"},
			{"id": "fragments", "title": "残卷"}]:
		var scroll := ScrollContainer.new()
		scroll.name = row.id
		scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_tabs.add_child(scroll)
		_tabs.set_tab_title(_tabs.get_tab_count() - 1, row.title)
		var panel := VBoxContainer.new()
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		panel.add_theme_constant_override("separation", 9)
		scroll.add_child(panel)
		_panels[row.id] = panel
	_portrait_dialog = AcceptDialog.new()
	_portrait_dialog.name = "BestiaryPortraitViewer"
	_portrait_dialog.title = "道侣立绘"
	_portrait_dialog.min_size = Vector2i(640, 510)
	_portrait_dialog.ok_button_text = "返回万物志"
	add_child(_portrait_dialog)
	var portrait_shell := VBoxContainer.new()
	portrait_shell.custom_minimum_size = Vector2(600, 435)
	_portrait_dialog.add_child(portrait_shell)
	_portrait_texture = TextureRect.new()
	_portrait_texture.name = "BestiaryPortraitImage"
	_portrait_texture.custom_minimum_size = Vector2(570, 260)
	_portrait_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait_shell.add_child(_portrait_texture)
	_portrait_title = Label.new()
	_portrait_title.name = "BestiaryPortraitTitle"
	portrait_shell.add_child(_portrait_title)
	_portrait_buttons = VBoxContainer.new()
	_portrait_buttons.name = "BestiaryStageChoices"
	portrait_shell.add_child(_portrait_buttons)


func open_bestiary(domain: RefCounted) -> void:
	_domain = domain
	_render_all()
	_tabs.current_tab = 0
	popup_centered_ratio(0.8)


func _render_all() -> void:
	for panel in _panels.values():
		_clear(panel)
	if _domain == null:
		return
	_render_companions()
	_render_items()
	_render_techniques()
	_render_fragments()


func _render_companions() -> void:
	var panel: VBoxContainer = _panels.companions
	var source: Variant = _repository.read_module("companions:portrait_stages")
	var definitions: Dictionary = source.get("portraitStages", {}) if source is Dictionary else {}
	var owned: Array = _domain.state.get("resources", {}).get("companions", [])
	for comp_id in definitions:
		var definition: Dictionary = definitions[comp_id]
		var stages: Array = definition.get("stages", [])
		var is_owned := owned.has(comp_id)
		var unlocked := 0
		if is_owned:
			unlocked = _domain.portrait_options(String(comp_id)).size()
		else:
			for stage in stages:
				if stage is Dictionary and int(stage.get("affection", 0)) <= 0:
					unlocked += 1
		var row := Button.new()
		row.text = "%s %s · 立绘 %d/%d" % [definition.get("name", comp_id),
			"♥" if is_owned else "🔒", unlocked, stages.size()]
		row.alignment = HORIZONTAL_ALIGNMENT_LEFT
		row.pressed.connect(_show_portraits.bind(String(comp_id)))
		panel.add_child(row)
	if definitions.is_empty():
		_add_line(panel, "万物志尚未收录道侣信息。")


func _show_portraits(comp_id: String) -> void:
	var source: Variant = _repository.read_module("companions:portrait_stages")
	var definition: Dictionary = source.get("portraitStages", {}).get(comp_id, {}) \
		if source is Dictionary else {}
	if definition.is_empty():
		return
	_clear(_portrait_buttons)
	var unlocked_ids := {}
	for stage in _domain.portrait_options(comp_id):
		unlocked_ids[String(stage.get("id", ""))] = true
	var selected: Dictionary = _domain.selected_portrait(comp_id, true)
	var selected_id := String(selected.get("id", ""))
	var stages: Array = definition.get("stages", [])
	if selected_id.is_empty() and not stages.is_empty():
		selected_id = String(stages[0].get("id", ""))
	for stage in stages:
		if not stage is Dictionary:
			continue
		var stage_id := String(stage.get("id", ""))
		var unlocked: bool = unlocked_ids.has(stage_id)
		var button := Button.new()
		button.text = "%s%s" % [stage.get("name", stage_id),
			" · 已选" if stage_id == selected_id and unlocked else
			" · 未解锁（好感 %d）" % int(stage.get("affection", 0)) if not unlocked else ""]
		button.disabled = not unlocked
		button.pressed.connect(_select_portrait.bind(comp_id, stage_id))
		_portrait_buttons.add_child(button)
	for stage in stages:
		if stage is Dictionary and stage.get("id") == selected_id:
			_render_portrait_stage(definition, stage)
			break
	_portrait_dialog.popup_centered_ratio(0.72)


func _select_portrait(comp_id: String, stage_id: String) -> void:
	if _domain.select_portrait(comp_id, stage_id):
		_render_companion_panel()
		_show_portraits(comp_id)


func _render_portrait_stage(definition: Dictionary, stage: Dictionary) -> void:
	_portrait_texture.texture = _registry.texture_for(String(stage.get("asset", "")))
	_portrait_title.text = "%s · %s\n%s" % [definition.get("name", ""),
		stage.get("name", ""), TextPresentation.normalize(stage.get("narrative", ""))]


func _render_companion_panel() -> void:
	_clear(_panels.companions)
	_render_companions()


func _render_items() -> void:
	var panel: VBoxContainer = _panels.items
	var resources: Dictionary = _domain.state.get("resources", {})
	_add_line(panel, "灵石 · %d" % int(resources.get("spiritStone", 0)))
	_add_line(panel, "寿元 · %d 轮" % int(resources.get("lifespan", 0)))
	var definitions := {}
	var source: Variant = _repository.read_module("shops:treasures")
	for row in source.get("treasures", []) if source is Dictionary else []:
		if row is Dictionary and row.get("id") is String:
			definitions[row.id] = row
	var owned_treasures := 0
	for instance_id in _domain.state.get("treasureInstances", {}):
		var instance: Dictionary = _domain.state.treasureInstances[instance_id]
		if instance.get("lifecycle") != "owned":
			continue
		owned_treasures += 1
		var definition: Dictionary = definitions.get(instance.get("definitionId"), {})
		var equipped := ""
		for slot in _domain.state.get("equipment", {}):
			if _domain.state.equipment[slot] == instance_id:
				equipped = " · 已装备"
		_add_line(panel, "%s%s\n%s" % [definition.get("name", instance_id),
			equipped, definition.get("desc", "这件器物的来历仍待考证。")])
	if owned_treasures == 0:
		_add_line(panel, "尚未获得任何法宝。")
	var pills: Dictionary = resources.get("pills", {}) if resources.get("pills") is Dictionary else {}
	var pill_names := {"foundation": "筑基丹", "golden": "结金丹",
		"nascent": "凝婴丹", "deity": "化神丹", "tribulation": "渡劫丹"}
	var pill_count := 0
	for pill_id in pills:
		var count := int(pills[pill_id])
		if count > 0:
			pill_count += 1
			_add_line(panel, "%s × %d" % [pill_names.get(pill_id, pill_id), count])
	if pill_count == 0:
		_add_line(panel, "尚未获得任何丹药。")


func _render_techniques() -> void:
	var panel: VBoxContainer = _panels.techniques
	var path: String = String(_domain.state.get("path", ""))
	var realm: String = String(_domain.state.get("realm", ""))
	var source: Variant = _repository.read_module("config:path_skills")
	var skills: Array = source.get("skills", {}).get(path, {}).get("skills", []) \
		if source is Dictionary else []
	var paths: Variant = _repository.read_module("config:paths")
	var path_name: String = String(paths.get("paths", {}).get(path, {}).get("name", path)) \
		if paths is Dictionary else path
	_add_line(panel, "当前功法：%s" % path_name)
	for skill in skills:
		if not skill is Dictionary:
			continue
		var required := String(skill.get("unlockRealm", ""))
		var unlocked := PathSkillFlow.REALM_ORDER.find(realm) >= \
			PathSkillFlow.REALM_ORDER.find(required)
		_add_line(panel, "%s · %s\n%s%s" % [skill.get("name", ""),
			"已解锁" if unlocked else "需要 " + required,
			skill.get("desc", ""), "\n" + String(skill.flavor) if skill.get("flavor") is String else ""])
	if skills.is_empty():
		_add_line(panel, "尚未解锁功法技能。")


func _render_fragments() -> void:
	var panel: VBoxContainer = _panels.fragments
	var archive: Dictionary = _domain.state.get("legacyArchive", {})
	var run: Dictionary = _domain.state.get("legacyRunState", {})
	var counts: Dictionary = archive.get("fragmentsBySet", {})
	var completed: Array = archive.get("completedSetIds", [])
	var active: Array = run.get("activeSetIds", [])
	var focused: String = run.get("focusedSetId") if run.get("focusedSetId") is String else ""
	var eligible := {}
	for option in _domain.legacy_focus_options():
		eligible[String(option.setId)] = true
	var battle_source: Variant = _repository.read_module("cards:battle_cards")
	var battle_cards: Array = battle_source.get("battle_cards", []) \
		if battle_source is Dictionary else []
	var path_id := String(_domain.state.get("path", ""))
	for set_id in LegacyFragmentFlow.SET_IDS:
		var count := int(counts.get(set_id, 0))
		var status := " · 本世已激活" if active.has(set_id) else \
			" · 档案已解锁" if completed.has(set_id) else ""
		var variant_preview := "本流派绝学：暂不可用"
		for card in battle_cards:
			if card is Dictionary and card.get("legacySetId") == set_id \
					and card.get("legacyPath") == path_id:
				variant_preview = "本流派绝学：%s（%s 灵力）· %s" % [
					card.get("name", card.get("id", "")), card.get("cost", ""),
					card.get("description", "")]
				break
		_add_line(panel, "%s · %d/8%s\n%s\n%s" % [LegacyFragmentFlow.SET_NAMES[set_id],
			count, status, LegacyFragmentFlow.SET_EFFECTS[set_id], variant_preview])
		if count < 8 and eligible.has(set_id):
			var button := Button.new()
			button.text = "停止追踪" if focused == set_id else "追踪此传承（普通掉落 60%）"
			button.pressed.connect(_toggle_focus.bind(String(set_id)))
			panel.add_child(button)
	var bonuses: Dictionary = LegacyFragmentFlow.aggregate_passives(_domain.state)
	var bonus_names := {"critRate": "暴击率", "pillBonus": "丹药效果",
		"combatStartBlock": "开战护盾", "daoResist": "道心伤害减免",
		"cultivationBonus": "修为正收益", "lowHpDamageBonus": "低血量伤害",
		"maxHp": "最大气血", "maxLifespan": "本世寿元",
		"daoHeartPenalty": "道心上限"}
	var percentages := ["critRate", "pillBonus", "daoResist", "cultivationBonus"]
	for key in bonuses:
		var value := int(bonuses[key])
		_add_line(panel, "%s %+d%s" % [bonus_names.get(key, key), value,
			"%" if percentages.has(key) else ""])


func _toggle_focus(set_id: String) -> void:
	var raw_focus: Variant = _domain.state.get("legacyRunState", {}).get("focusedSetId")
	var current: String = raw_focus if raw_focus is String else ""
	if _domain.set_legacy_focus("" if current == set_id else set_id):
		_clear(_panels.fragments)
		_render_fragments()


func _add_line(parent: VBoxContainer, text_value: String) -> void:
	var label := Label.new()
	label.text = TextPresentation.normalize(text_value)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(label)


func _clear(parent: Node) -> void:
	for child in parent.get_children():
		parent.remove_child(child)
		child.queue_free()
