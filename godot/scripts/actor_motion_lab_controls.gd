extends PanelContainer

var game: Control
var stage: Node
var scrub: HSlider
var variant: OptionButton
var realm_selector: OptionButton
var armor_selector: OptionButton
var accessory_selector: OptionButton
var artifact_selector: OptionButton
var status: Label
var was_locked := false


func _ready() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.039, 0.056, 0.94)
	style.border_color = Color(0.61, 0.47, 0.28)
	style.set_border_width_all(1)
	style.set_corner_radius_all(5)
	style.set_content_margin_all(10)
	add_theme_stylebox_override("panel", style)
	var column := VBoxContainer.new()
	add_child(column)
	var title := Label.new()
	title.text = "动作实验 · 实战 / 时间轴"
	title.add_theme_color_override("font_color", Color(0.95, 0.88, 0.7))
	column.add_child(title)
	variant = OptionButton.new()
	variant.name = "ActorVariant"
	for label in ["练习剑", "残剑", "空手", "原角色动画"]:
		variant.add_item(label)
	variant.item_selected.connect(_change_variant)
	column.add_child(variant)
	realm_selector = OptionButton.new()
	realm_selector.name = "RealmStageSelector"
	realm_selector.add_item("炼气 S1")
	realm_selector.add_item("筑基 S2 · 候选")
	realm_selector.item_selected.connect(_change_realm)
	column.add_child(realm_selector)
	armor_selector = OptionButton.new()
	armor_selector.name = "ArmorSelector"
	armor_selector.add_item("护甲：无")
	armor_selector.add_item("玄铁甲 · 仅S2有图")
	armor_selector.item_selected.connect(_change_armor)
	column.add_child(armor_selector)
	accessory_selector = OptionButton.new()
	accessory_selector.name = "AccessorySelector"
	accessory_selector.add_item("佩饰：无")
	accessory_selector.add_item("灵泉葫芦 · 样件")
	accessory_selector.item_selected.connect(_change_accessory)
	column.add_child(accessory_selector)
	artifact_selector = OptionButton.new()
	artifact_selector.name = "ArtifactSelector"
	artifact_selector.add_item("法宝：无")
	artifact_selector.add_item("青云剑匣 · 样件")
	artifact_selector.item_selected.connect(_change_artifact)
	column.add_child(artifact_selector)
	var row := HBoxContainer.new()
	column.add_child(row)
	scrub = HSlider.new()
	scrub.name = "MotionScrub"
	scrub.custom_minimum_size.x = 185
	scrub.max_value = 100
	scrub.step = 1
	scrub.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scrub.value_changed.connect(_seek)
	row.add_child(scrub)
	var reset := Button.new()
	reset.text = "复位"
	reset.pressed.connect(func() -> void: scrub.value = 0)
	row.add_child(reset)
	status = Label.new()
	status.name = "MotionStatus"
	status.text = "拖动预览；点击下方剑牌观看实战命中"
	status.add_theme_color_override("font_color", Color(0.8, 0.86, 0.9))
	column.add_child(status)
	var note := Label.new()
	note.text = "境界/装备仅预览外观；规则仍按炼气首战"
	note.add_theme_font_size_override("font_size", 12)
	note.add_theme_color_override("font_color", Color(0.68, 0.73, 0.75))
	column.add_child(note)
	call_deferred("_bind_battle")


func _bind_battle() -> void:
	game = get_parent() as Control
	stage = game.duel_stage
	stage.enable_actor_motion_lab()
	stage.set_actor_study_variant("practice_sword")


func _change_variant(index: int) -> void:
	if stage == null or game.combat.state.get("phase") in ["DEFEAT", "VICTORY", "FLEE"]:
		return
	stage.seek_actor_study_attack(0.0)
	scrub.set_value_no_signal(0)
	stage.set_actor_study_variant(["practice_sword", "traded_rusted_sword", "unarmed", "original"][index])
	status.text = "原角色可直接出牌对照" if index == 3 else "拖动预览；点击下方剑牌观看实战命中"


func _change_realm(index: int) -> void:
	if stage == null or game.combat.input_locked:
		return
	stage.seek_actor_study_attack(0.0)
	scrub.set_value_no_signal(0)
	stage.set_actor_study_realm("foundation" if index == 1 else "qi")
	if index == 0:
		armor_selector.select(0)
		artifact_selector.select(0)
	status.text = "筑基外观候选；点击剑牌检查动作" if index == 1 else "拖动预览；点击下方剑牌观看实战命中"


func _change_armor(index: int) -> void:
	if stage == null or game.combat.input_locked or realm_selector.selected != 1:
		return
	stage.seek_actor_study_attack(0.0)
	scrub.set_value_no_signal(0)
	stage.set_actor_study_armor("玄铁甲" if index == 1 else "")
	status.text = "玄铁甲候选；可切剑并点击剑牌" if index == 1 else "已卸下玄铁甲；点击剑牌检查动作"


func _change_accessory(index: int) -> void:
	if stage == null or game.combat.input_locked:
		return
	stage.set_actor_study_accessory("灵泉葫芦" if index == 1 else "")
	status.text = "灵泉葫芦候选；可切剑并点击剑牌" if index == 1 else "已卸下灵泉葫芦；点击剑牌检查动作"


func _change_artifact(index: int) -> void:
	if stage == null or game.combat.input_locked or realm_selector.selected != 1:
		return
	stage.set_actor_study_artifact("青云剑匣" if index == 1 else "")
	status.text = "青云剑匣候选；可切剑并点击剑牌" if index == 1 else "已卸下青云剑匣；点击剑牌检查动作"


func _process(_delta: float) -> void:
	if game == null or game.combat == null:
		return
	var locked: bool = game.combat.input_locked
	var ended: bool = game.combat.state.get("phase") in ["DEFEAT", "VICTORY", "FLEE"]
	if ended and stage.get_actor_sprite("player").visible:
		variant.select(3)
	scrub.editable = not locked and not ended and variant.selected != 3
	variant.disabled = locked or ended
	realm_selector.disabled = locked or ended or variant.selected == 3
	armor_selector.disabled = locked or ended or variant.selected == 3 or realm_selector.selected != 1
	accessory_selector.disabled = locked or ended or variant.selected == 3
	artifact_selector.disabled = locked or ended or variant.selected == 3 or realm_selector.selected != 1
	if locked:
		status.text = "实战播放中 · 命中后才显示伤害"
	elif ended:
		status.text = "战斗结束 · 角色外观已锁定"
	elif was_locked:
		scrub.set_value_no_signal(0)
		status.text = "拖动预览；点击下方剑牌观看实战命中"
	was_locked = locked


func _seek(value: float) -> void:
	if stage == null or game.combat.input_locked \
			or game.combat.state.get("phase") in ["DEFEAT", "VICTORY", "FLEE"]:
		return
	var progress := value / 100.0
	stage.seek_actor_study_attack(progress)
	status.text = "%d%% · %s" % [int(value),
		"待机" if progress < 0.10 or progress >= 0.86 else
		"蓄力 / 收势" if progress < 0.39 or progress >= 0.64 else
		"刺击 / 命中"]
