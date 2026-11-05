class_name NoncombatOpeningUI
extends Control
const LegacyFragmentFlow = preload("res://scripts/noncombat_legacy_fragment_flow.gd")
const PathSkillFlow = preload("res://scripts/noncombat_path_skill_flow.gd")
const CompanionWhisper = preload("res://scripts/noncombat_companion_whisper.gd")
const HeavenlyGalleryUI = preload("res://scripts/noncombat_heavenly_gallery_ui.gd")
const BestiaryUI = preload("res://scripts/noncombat_bestiary_ui.gd")
const KarmaJournalUI = preload("res://scripts/noncombat_karma_journal_ui.gd")
const ThreadJournalUI = preload("res://scripts/noncombat_thread_journal_ui.gd")
const TextPresentation = preload("res://scripts/noncombat_text_presentation.gd")

const Registry = preload("res://scripts/runtime_data_registry.gd")
const ContentRepository = preload("res://scripts/noncombat_content_repository.gd")
const OpeningDomain = preload("res://scripts/noncombat_domain.gd")
const RunSession = preload("res://scripts/noncombat_run_session.gd")
const SaveSlots = preload("res://scripts/noncombat_save_slots.gd")
const BrowserSaveStaging = preload("res://scripts/noncombat_browser_save_staging.gd")
const BrowserOpeningImport = preload("res://scripts/noncombat_browser_opening_import.gd")
const OpeningAudio = preload("res://scripts/noncombat_opening_audio.gd")
const ExperienceSettings = preload("res://scripts/noncombat_experience_settings.gd")
const AmbientParticles = preload("res://scripts/noncombat_ambient_particles.gd")
const BattleGateway = preload("res://scripts/noncombat_battle_gateway.gd")
const BattlePlanResolver = preload("res://scripts/battle_plan_resolver.gd")
const CombatStageRouter = preload("res://scripts/combat_stage_router.gd")
const FirstBattleScene = preload("res://scenes/main.tscn")
const BattleStubScript = preload("res://scripts/battle_stub.gd")
# 战斗桩开关：true 时用 BattleStub 替代真实战斗场景，仅供非战斗侧端到端验证。
# 生产运行必须保持 false——桩不播放任何战斗演出，也不参与战斗规则结算。
# 设为实例变量而非常量，让端到端测试能在不改源码的前提下开启。
var battle_stub_mode: bool = false
const RewardArenaScene = preload("res://scenes/duel_stage_hd2d.tscn")
const GameSkin = preload("res://scripts/game_ui_skin.gd")
const NoncombatSlotScreen = preload("res://scripts/noncombat_slot_screen.gd")
const WorldMap = preload("res://scripts/noncombat_world_map.gd")
const WorldMapUI = preload("res://scripts/noncombat_world_map_ui.gd")
const NpcInteractionUI = preload("res://scripts/noncombat_npc_interaction_ui.gd")
const EvidenceAtlas = preload("res://scripts/noncombat_evidence_atlas.gd")
const WorldPulse = preload("res://scripts/noncombat_world_pulse.gd")
const INK_FONT = preload("res://assets/fonts/LXGWWenKai-Regular.ttf")
const READABLE_FONT = preload("res://assets/fonts/NotoSansSC-VF.ttf")
const CONTENT_ROOT := "res://content/"
const EventTypes = preload("res://scripts/noncombat_event_types.gd")

# 事件处理策略（S2）。本屏的分支只驱动音频；画面由 _render() 无条件重绘，
# 因此「无分支」的类型不影响显示，只是没有专属音效。
# HANDLED_* 与 AUDIO_ONLY_EVENTS 的并集必须等于 EventTypes.ALL（62），
# 交集必须为空——由 tests/noncombat_event_coverage.gd 强制。
const HANDLED_PROLOGUE := ["STARTED", "RESTORED", "CHOICE_COMMITTED"]
const HANDLED_COMBAT_FLOW := [
	"ENCOUNTER_WARNING", "BATTLE_REQUEST_READY",
	"BATTLE_RESULT_COMMITTED", "BATTLE_RESULT_ACKNOWLEDGED",
	"FIRST_SESSION_ROUTE_CHOSEN",
	"ENCOUNTER_AVOIDED", "FLOW_CARD_READY", "MILESTONE_CHOSEN",
	"MENTOR_CHOSEN", "DESTINY_WHEEL_FLIPPED",
	"DEATH_NARRATIVE", "REBIRTH_PATH_REQUIRED",
	"REBIRTH_PATH_SELECTED",
]
const HANDLED_RESULT := ["RESULT_ACKNOWLEDGED"]
const HANDLED_VENDOR := ["VENDOR_PURCHASED", "VENDOR_ACTION"]
const HANDLED_ALL := [
	"STARTED", "RESTORED", "CHOICE_COMMITTED",
	"ENCOUNTER_WARNING", "BATTLE_REQUEST_READY",
	"BATTLE_RESULT_COMMITTED", "BATTLE_RESULT_ACKNOWLEDGED",
	"FIRST_SESSION_ROUTE_CHOSEN",
	"ENCOUNTER_AVOIDED", "FLOW_CARD_READY", "MILESTONE_CHOSEN",
	"MENTOR_CHOSEN", "DESTINY_WHEEL_FLIPPED",
	"DEATH_NARRATIVE", "REBIRTH_PATH_REQUIRED",
	"REBIRTH_PATH_SELECTED",
	"RESULT_ACKNOWLEDGED",
	"VENDOR_PURCHASED", "VENDOR_ACTION",
]
# 无专属分支的事件类型（43 个 = 62 − 19）。它们只影响显示以外的东西，
# 画面靠 _render() 无条件重绘，故不需要在此增加分支。
const AUDIO_ONLY_EVENTS := [
	"ALLY_CHOSEN",
	"BOSS_FRAGMENT_CLAIMED",
	"CAMP_CHOSEN",
	"CAMP_TARGET_CANCELLED",
	"CAMP_TARGET_SELECTED",
	"CHOICE_ECHO_CHOSEN",
	"COMPANION_ARC_CHOSEN",
	"COMPANION_CHOSEN",
	"COMPANION_PORTRAIT_SELECTED",
	"DUNGEON_ABANDONED",
	"DUNGEON_ADVANCED",
	"DUNGEON_ENTERED",
	"EMERGENT_CHOSEN",
	"FACTION_CHOSEN",
	"GHOST_DEBT_SETTLED",
	"HINT_CHOSEN",
	"INNER_DEMON_CHOSEN",
	"KARMA_CHOSEN",
	"LEGACY_FOCUS_CHANGED",
	"LICENSED_DELIVERY_CLAIMED",
	"LOCATION_CHOSEN",
	"MARKET_NARRATIVE_RESULT",
	"MARKET_SKIPPED",
	"NORMAL_CHOSEN",
	"NPC_CROSS_CHOSEN",
	"NPC_ENCOUNTER_CHOSEN",
	"NPC_INTERACTION",
	"QUEST_CHOSEN",
	"REALM_EPIPHANY_CHOSEN",
	"REBIRTH_BOON_CHOSEN",
	"REBIRTH_TREE_CHANGED",
	"RIPPLE_CHOSEN",
	"SEER_CHOSEN",
	"SHOP_SKIPPED",
	"SURFACING_CHOSEN",
	"THREAD_CHOSEN",
	"TREASURE_EQUIPMENT_CHANGED",
	"UPPER_REALM_CHOSEN",
	"UPPER_REALM_ENTERED",
	"VENDOR_CLOSED",
	"VENDOR_DISMISSED",
	"VENDOR_LOADOUT_RESOLVED",
	"VENDOR_OPENED",
]
var _undeclared_event_types: Dictionary = {}

@export var save_path := "user://noncombat_opening_v1.json"
@export var slot_root_path := "user://"
@export var audio_settings_path := "user://noncombat_audio_settings.cfg"
@export var gallery_settings_path := "user://noncombat_gallery_settings.cfg"
@export var experience_settings_path := "user://noncombat_experience_settings.cfg"

var registry: RefCounted
var content_repository: RefCounted
var opening: RefCounted
var opening_store: RefCounted
var save_slots: RefCounted
var opening_audio: Node
var experience_settings: RefCounted
var experience_dialog: AcceptDialog
var experience_effects: OptionButton
var experience_steady_camera: CheckButton
var experience_text_scale: OptionButton
var experience_readable_font: CheckButton
var experience_high_contrast: CheckButton
var world_map: RefCounted
var world_map_overlay: Control
var npc_interaction_dialog: AcceptDialog
var evidence_atlas: RefCounted
var evidence_atlas_dialog: AcceptDialog
var heavenly_gallery_dialog: AcceptDialog
var bestiary_dialog: AcceptDialog
var karma_journal_dialog: AcceptDialog
var thread_journal_dialog: AcceptDialog
var battle_gateway: RefCounted
var active_battle: Control
var reward_arena: Control
var background: TextureRect
var backdrop_shade: ColorRect
var ambient_particles: Control
var slot_screen: VBoxContainer
var slot_status_label: Label
var browser_save_picker: FileDialog
var browser_import_dialog: AcceptDialog
var browser_import_list: VBoxContainer
var browser_replace_confirm: ConfirmationDialog
var _browser_import_text := ""
var _browser_replace_slot := ""
var _browser_replace_revision := -1
var name_screen: VBoxContainer
var name_input: LineEdit
var name_count_label: Label
var name_status_label: Label
var path_screen: VBoxContainer
var path_status_label: Label
var story_screen: VBoxContainer
var stats_label: Label
var companion_whisper_panel: PanelContainer
var companion_portrait_rect: TextureRect
var companion_identity_label: Label
var companion_whisper_label: Label
var companion_portrait_button: Button
var companion_portrait_dialog: AcceptDialog
var slot_audio_button: Button
var story_audio_button: Button
var title_label: Label
var body_label: Label
var oath_label: Label
var art_rect: TextureRect
var npc_cross_portraits: HBoxContainer
var npc_cross_left: TextureRect
var npc_cross_right: TextureRect
var source_content: HBoxContainer
var source_text_panel: PanelContainer
var reward_settlement_label: Label
var choice_row: HBoxContainer
var status_label: Label
var equipment_button: Button
var equipment_dialog: AcceptDialog
var equipment_list: VBoxContainer
var boss_fragment_button: Button
var boss_fragment_dialog: AcceptDialog
var legacy_focus_button: Button
var legacy_focus_dialog: AcceptDialog
var rebirth_tree_button: Button
var rebirth_tree_dialog: AcceptDialog
var _choice_token := -1
var _choice_pending := false
var _whisper_sequence := 0
var _companion_idle_sequence := 0
var _companion_hud_id := ""
var _pending_player_name := "叶凌云"
var _experience_apply_queued := false


func _ready() -> void:
	# 生产环境复用 DataService 的共享 Registry（贴图别名缓存只解析一次）；
	# `--script` 测试模式不加载 autoload，走自建——这是正常路径而非异常。
	var data_service := get_node_or_null("/root/DataService") as GameDataService
	if data_service != null:
		registry = data_service.registry_or_new()
	else:
		registry = Registry.new()
	content_repository = ContentRepository.new()
	world_map = WorldMap.new(content_repository)
	evidence_atlas = EvidenceAtlas.new(content_repository)
	battle_gateway = BattleGateway.new(registry)
	if save_path == "user://noncombat_opening_v1.json":
		save_slots = SaveSlots.new(slot_root_path)
	else:
		opening_store = RunSession.new(save_path) if not save_path.is_empty() else null
		opening = OpeningDomain.new(registry, opening_store)
	var ui_theme := Theme.new()
	ui_theme.default_font = READABLE_FONT
	theme = ui_theme
	experience_settings = ExperienceSettings.new(experience_settings_path)
	_build()
	_build_experience_dialog()
	_apply_experience_settings()
	get_tree().node_added.connect(_on_experience_node_added)
	world_map_overlay = WorldMapUI.new()
	world_map_overlay.name = "WorldMapOverlay"
	add_child(world_map_overlay)
	world_map_overlay.visible = false
	npc_interaction_dialog = NpcInteractionUI.new()
	npc_interaction_dialog.name = "NpcInteractionDialog"
	add_child(npc_interaction_dialog)
	get_viewport().size_changed.connect(func() -> void: call_deferred("_fit_story_screen"))
	opening_audio = OpeningAudio.new(registry, null, audio_settings_path)
	opening_audio.name = "SourceOpeningAudio"
	add_child(opening_audio)
	opening_audio.voice_subtitle_changed.connect(func(line: String) -> void:
		oath_label.text = line
		oath_label.visible = not line.is_empty())
	_sync_audio_buttons()
	heavenly_gallery_dialog = HeavenlyGalleryUI.new(
		content_repository, registry, gallery_settings_path)
	add_child(heavenly_gallery_dialog)
	bestiary_dialog = BestiaryUI.new(content_repository, registry)
	add_child(bestiary_dialog)
	karma_journal_dialog = KarmaJournalUI.new()
	add_child(karma_journal_dialog)
	thread_journal_dialog = ThreadJournalUI.new(content_repository)
	add_child(thread_journal_dialog)
	if save_slots != null:
		_show_slot_screen()
		return
	if opening.has_signal("changed"):
		opening.changed.connect(_on_opening_changed)
	if opening.restore():
		if opening.state.get("phase") == "REBIRTH_PENDING" \
				and opening.state.get("path") == null:
			_show_path_screen()
		else:
			slot_screen.visible = false
			name_screen.visible = false
			path_screen.visible = false
			story_screen.visible = true
			_set_scene_surface(true)
			_render()
		if opening.state.get("phase") == "FLOW_PENDING":
			call_deferred("_resume_flow_if_pending")
	else:
		_show_name_screen()
		if opening_store != null and opening_store.has_state_file():
			var archived: String = opening_store.archive_unrestorable()
			if archived.is_empty():
				name_status_label.text = _unrestorable_message()
				name_input.editable = false
			else:
				name_status_label.text = "旧开局未能校验，原文件已归档为 %s。" % archived.get_file()


func _build() -> void:
	background = TextureRect.new()
	background.name = "SourceBackground"
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.texture = _art_texture("assets/backgrounds/bg_inkwash_masterpiece.png")
	add_child(background)

	backdrop_shade = ColorRect.new()
	backdrop_shade.color = Color(1, 0.98, 0.94, 0.12)
	backdrop_shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop_shade)
	ambient_particles = AmbientParticles.new()
	ambient_particles.name = "AmbientParticles"
	ambient_particles.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(ambient_particles)

	var margin := MarginContainer.new()
	margin.name = "DesktopMargin"
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 26)
	add_child(margin)

	var screens := Control.new()
	screens.name = "ScreenStack"
	screens.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	screens.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(screens)
	_build_slot_screen(screens)
	_build_name_screen(screens)
	_build_path_screen(screens)
	_build_story_screen(screens)


func _set_scene_surface(story: bool) -> void:
	background.texture = _art_texture("assets/backgrounds/bg_start.png" if story \
		else "assets/backgrounds/bg_inkwash_masterpiece.png")
	backdrop_shade.color = Color(0.015, 0.023, 0.03, 0.65) if story \
		else Color(1, 0.98, 0.94, 0.12)


func _reset_story_visual_mode() -> void:
	if reward_arena != null:
		reward_arena.visible = false
		reward_arena.get_parent().remove_child(reward_arena)
		reward_arena.queue_free()
		reward_arena = null
	background.visible = true
	background.texture = _art_texture("assets/backgrounds/bg_start.png")
	backdrop_shade.color = Color(0.015, 0.023, 0.03, 0.65)
	art_rect.modulate = Color.WHITE
	if npc_cross_portraits != null:
		npc_cross_portraits.visible = false
		npc_cross_left.texture = null
		npc_cross_right.texture = null
	art_rect.custom_minimum_size = Vector2(470, 420)
	art_rect.size_flags_stretch_ratio = 1.0
	source_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	source_content.custom_minimum_size = Vector2.ZERO
	source_text_panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	source_text_panel.size_flags_stretch_ratio = 1.0
	var regular_panel := GameSkin.plaque(0.86)
	regular_panel.set_content_margin_all(25)
	source_text_panel.add_theme_stylebox_override("panel", regular_panel)
	story_screen.alignment = BoxContainer.ALIGNMENT_BEGIN
	choice_row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	title_label.remove_theme_font_override("font")
	title_label.add_theme_font_size_override("font_size", 30)
	body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	reward_settlement_label.visible = false


func _show_teaching_reward_arena(current: Dictionary, run: Dictionary) -> bool:
	var history: Array = run.get("battleResultHistory", [])
	if history.is_empty() or not history.back() is Dictionary:
		return false
	var result: Dictionary = history.back().get("result", {})
	if result.get("encounterId") != "enc_trial_sword_swift" \
			or result.get("outcome") != "victory":
		return false
	var context: Dictionary = CombatStageRouter.new(registry).resolve_encounter(
		"enc_trial_sword_swift", String(result.get("encounterInstanceId", "")))
	if context.is_empty() or context.get("sceneImage") != current.get("sceneImage") \
			or context.get("presentationId") != current.get("combatPresentationId"):
		return false
	var arena: Control = RewardArenaScene.instantiate()
	if not arena.bind_stage_context(context):
		arena.queue_free()
		return false
	arena.name = "RewardArenaStage"
	arena.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(arena)
	move_child(arena, 0)
	if not arena.has_hd2d_assets() or arena.stage_art.get("selectedScene") != \
			"res://assets/battle/hd2d/world_v17/qingyun_tutorial_hall_v17.glb":
		arena.queue_free()
		return false
	reward_arena = arena
	# The training dummy has been defeated; keep the same hall and protagonist.
	arena.get_actor_model("enemy").visible = false
	return true


func _apply_reward_visual_mode(description: String, current: Dictionary,
		run: Dictionary) -> void:
	# Result presentation uses the real encounter stage when the authored stage
	# is available. Other encounters keep their own source artwork for now.
	var native_stage := _show_teaching_reward_arena(current, run)
	background.texture = art_rect.texture
	background.visible = not native_stage
	backdrop_shade.color = Color(0.012, 0.026, 0.039, 0.10 if native_stage else 0.36)
	art_rect.modulate = Color(1, 1, 1, 0)
	art_rect.custom_minimum_size = Vector2(470, 0)
	art_rect.size_flags_stretch_ratio = 1.55
	source_content.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	source_content.custom_minimum_size = Vector2.ZERO
	source_text_panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	source_text_panel.size_flags_stretch_ratio = 1.0
	var ledger := StyleBoxFlat.new()
	ledger.bg_color = Color(0.055, 0.078, 0.10, 0.82)
	ledger.border_color = Color("c4a677")
	ledger.border_width_left = 3
	ledger.set_content_margin_all(30)
	source_text_panel.add_theme_stylebox_override("panel", ledger)
	story_screen.alignment = BoxContainer.ALIGNMENT_CENTER
	choice_row.size_flags_horizontal = Control.SIZE_SHRINK_END if native_stage \
		else Control.SIZE_SHRINK_CENTER
	title_label.add_theme_font_override("font", INK_FONT)
	title_label.add_theme_font_size_override("font_size", 37)
	body_label.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var marker := "【本次结算】"
	var split_at := description.find(marker)
	if split_at >= 0:
		body_label.text = description.substr(0, split_at).strip_edges()
		reward_settlement_label.text = "本次所得\n" + description.substr(
			split_at + marker.length()).strip_edges()
	else:
		reward_settlement_label.text = ""
	reward_settlement_label.visible = not reward_settlement_label.text.is_empty()


func _style_reward_choice(button: Button, quiet: bool) -> void:
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var slip := StyleBoxFlat.new()
		slip.bg_color = Color("202f39") if quiet else Color("ddd5c2")
		slip.border_color = Color("8da8b1") if quiet else Color("8e795b")
		slip.set_border_width_all(1)
		slip.border_width_top = 3 if not quiet else 1
		slip.set_content_margin_all(10)
		if state in ["hover", "focus"]:
			slip.bg_color = Color("293d49") if quiet else Color("f2e8d3")
			slip.border_color = Color("c4a677")
			if state == "focus":
				slip.set_border_width_all(2)
		elif state == "pressed":
			slip.bg_color = Color("162831") if quiet else Color("cbbfa9")
		elif state == "disabled":
			slip.bg_color = Color("253039") if quiet else Color("a9a494")
		button.add_theme_stylebox_override(state, slip)
	button.add_theme_color_override("font_color", Color("e8e2d4") if quiet else Color("25313a"))
	button.add_theme_color_override("font_hover_color", Color.WHITE if quiet else Color("14222b"))
	button.add_theme_color_override("font_pressed_color", Color("e8e2d4") if quiet else Color("25313a"))
	button.add_theme_color_override("font_disabled_color", Color("899296") if quiet else Color("656965"))
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


func _add_reward_choice_copy(button: Button, title: String, effect: String,
		quiet: bool) -> void:
	# Keep the source text on the Button for keyboard/accessibility names while
	# drawing a clear title/effect hierarchy over its otherwise transparent text.
	for state in ["font_color", "font_hover_color", "font_pressed_color",
			"font_disabled_color"]:
		button.add_theme_color_override(state, Color.TRANSPARENT)
	var inset := MarginContainer.new()
	inset.name = "RewardCopy"
	inset.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inset.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		inset.add_theme_constant_override("margin_" + side, 13)
	button.add_child(inset)
	var copy := VBoxContainer.new()
	copy.alignment = BoxContainer.ALIGNMENT_CENTER
	copy.add_theme_constant_override("separation", 5)
	inset.add_child(copy)
	var title_label_copy := _label(title, 23 if not quiet else 20)
	title_label_copy.add_theme_font_override("font", INK_FONT)
	title_label_copy.add_theme_color_override("font_color",
		Color("1d3038") if not quiet else Color("e8e2d4"))
	title_label_copy.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	copy.add_child(title_label_copy)
	var effect_label := _label(effect, 16)
	effect_label.add_theme_color_override("font_color",
		Color("34434a") if not quiet else Color("c6d0ce"))
	effect_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	copy.add_child(effect_label)

func _build_slot_screen(parent: Control) -> void:
	# S3：屏内构建搬到 NoncombatSlotScreen；对话框仍留在本脚本（浏览器导入
	# 流程要直接读 ui.browser_save_picker 等成员），节点路径与抽取前一致。
	slot_screen = NoncombatSlotScreen.new()
	slot_status_label = slot_screen.status_label
	slot_audio_button = slot_screen.audio_button
	slot_screen.slot_pressed.connect(_on_slot_pressed)
	slot_screen.import_requested.connect(
		func() -> void: browser_save_picker.popup_centered_ratio(0.7))
	slot_screen.audio_toggled.connect(_toggle_all_audio)
	slot_screen.experience_requested.connect(_open_experience_dialog)
	slot_screen.gallery_requested.connect(_open_heavenly_gallery)
	parent.add_child(slot_screen)
	browser_save_picker = FileDialog.new()
	browser_save_picker.name = "BrowserSavePicker"
	browser_save_picker.access = FileDialog.ACCESS_FILESYSTEM
	browser_save_picker.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	browser_save_picker.add_filter("*.json", "网页版存档 JSON")
	browser_save_picker.file_selected.connect(_on_browser_save_file_selected)
	add_child(browser_save_picker)
	browser_import_dialog = AcceptDialog.new()
	browser_import_dialog.name = "BrowserImportPreview"
	browser_import_dialog.title = "网页版早期存档预览"
	browser_import_dialog.min_size = Vector2i(640, 350)
	browser_import_list = VBoxContainer.new()
	browser_import_list.add_theme_constant_override("separation", 12)
	browser_import_dialog.add_child(browser_import_list)
	add_child(browser_import_dialog)
	browser_replace_confirm = ConfirmationDialog.new()
	browser_replace_confirm.name = "BrowserReplaceConfirm"
	browser_replace_confirm.title = "替换玉简存档"
	browser_replace_confirm.ok_button_text = "备份并替换"
	browser_replace_confirm.confirmed.connect(_confirm_browser_replace)
	add_child(browser_replace_confirm)
func _on_browser_save_file_selected(path: String) -> void:
	if save_slots == null:
		return
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		slot_status_label.text = "无法读取所选网页版存档。"
		return
	_browser_import_text = file.get_as_text()
	var staged: Dictionary = BrowserSaveStaging.new(slot_root_path).stage_text(
		_browser_import_text)
	if staged.get("ok") != true:
		slot_status_label.text = "旧档预检失败：" + String(staged.get("error", "INVALID_BROWSER_SAVE"))
		return
	for child in browser_import_list.get_children():
		browser_import_list.remove_child(child)
		child.queue_free()
	var intro := _label("支持已验证的教程、序章、首次试炼避战回应和早期白狐任务存档。来源原文已独立备份。", 17)
	browser_import_list.add_child(intro)
	var imported = BrowserOpeningImport.new()
	for preview in staged.preview.slots:
		if preview.get("occupied") != true:
			continue
		var slot_id := String(preview.slotId)
		var native_info: Dictionary = save_slots.inspect_slot(slot_id)
		var candidate: Dictionary = imported.prepare(_browser_import_text, slot_id)
		if native_info.get("corrupted"):
			candidate = {"ok": false, "error": "DESTINATION_UNREADABLE"}
		var row := HBoxContainer.new()
		browser_import_list.add_child(row)
		var description := _label("%s · %s · 第 %s 决断" % [
			preview.get("label", slot_id), preview.get("path", "待择道"),
			preview.get("decisionIndex", 0)], 17)
		description.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(description)
		var action := Button.new()
		action.name = "Import_" + slot_id
		action.text = ("备份并替换" if native_info.get("occupied") else "导入") \
			if candidate.get("ok") else "暂不可转换"
		action.tooltip_text = String(candidate.get("error", ""))
		action.disabled = candidate.get("ok") != true
		if native_info.get("occupied"):
			action.pressed.connect(_request_browser_replace.bind(slot_id))
		else:
			action.pressed.connect(_commit_browser_opening_import.bind(slot_id))
		row.add_child(action)
	browser_import_dialog.popup_centered()


func _commit_browser_opening_import(slot_id: String) -> void:
	if save_slots == null or _browser_import_text.is_empty():
		return
	var session = RunSession.new(save_slots.save_path_for(slot_id), slot_id)
	var result: Dictionary = BrowserOpeningImport.new().import_to_empty_slot(
		_browser_import_text, slot_id, session)
	if result.get("ok") != true:
		slot_status_label.text = "旧档导入失败：" + String(result.get("error", "UNKNOWN"))
		return
	browser_import_dialog.hide()
	_browser_import_text = ""
	_show_slot_screen()
	slot_status_label.text = "%s已导入；请选择该玉简继续。" % SaveSlots.SLOT_LABELS[slot_id]


func _request_browser_replace(slot_id: String) -> void:
	if save_slots == null or _browser_import_text.is_empty():
		return
	var session = RunSession.new(save_slots.save_path_for(slot_id), slot_id)
	var current: Dictionary = session.load_snapshot()
	if current.is_empty() or not session.last_error.is_empty():
		slot_status_label.text = "原玉简无法安全备份：" + session.last_error
		return
	_browser_replace_slot = slot_id
	_browser_replace_revision = int(current.revision)
	browser_replace_confirm.dialog_text = "将备份%s的现有存档，再导入网页版存档。" % \
		SaveSlots.SLOT_LABELS[slot_id]
	browser_import_dialog.hide()
	browser_replace_confirm.popup_centered()


func _confirm_browser_replace() -> void:
	if save_slots == null or _browser_replace_slot.is_empty() \
			or _browser_replace_revision < 0 or _browser_import_text.is_empty():
		return
	var slot_id := _browser_replace_slot
	var expected_revision := _browser_replace_revision
	_browser_replace_slot = ""
	_browser_replace_revision = -1
	var session = RunSession.new(save_slots.save_path_for(slot_id), slot_id)
	var result: Dictionary = BrowserOpeningImport.new().replace_slot(
		_browser_import_text, slot_id, session, expected_revision)
	if result.get("ok") != true:
		slot_status_label.text = "旧档替换失败：" + String(result.get("error", "UNKNOWN"))
		return
	browser_import_dialog.hide()
	_browser_import_text = ""
	_show_slot_screen()
	slot_status_label.text = "%s已导入；原档备份：%s" % [
		SaveSlots.SLOT_LABELS[slot_id], result.backup]


func _show_slot_screen() -> void:
	if save_slots == null:
		return
	_companion_idle_sequence += 1
	_whisper_sequence += 1
	_companion_hud_id = ""
	companion_whisper_panel.visible = false
	companion_whisper_label.visible = false
	opening_audio.stop_scene()
	opening_audio.set_market_presentation({})
	slot_status_label.text = "活动玉简索引需要修复；选择后将保留原文。" \
		if save_slots.active_index_corrupted() else ""
	slot_screen.visible = true
	name_screen.visible = false
	path_screen.visible = false
	story_screen.visible = false
	_set_scene_surface(false)
	for slot_id in SaveSlots.SLOT_IDS:
		var info: Dictionary = save_slots.inspect_slot(slot_id)
		var detail := "空白玉简"
		if info.get("corrupted"):
			var slot_error := String(info.get("error", ""))
			if slot_error == "SOURCE_MISMATCH":
				detail = "来源版本待修复"
			elif slot_error == "FUTURE_VERSION":
				detail = "存档版本待修复"
			elif slot_error.begins_with("PENDING_"):
				detail = "提交待恢复"
			else:
				detail = "记录待归档"
		elif info.get("occupied"):
			var source_paths: Dictionary = _source_paths()
			var path_value: Variant = info.get("path")
			var path_id: String = path_value if path_value is String else ""
			var path_name := "轮回待择道" if info.get("phase") == \
				"REBIRTH_PENDING" and path_id.is_empty() else String(
					source_paths.get(path_id, {}).get("name", path_id))
			detail = "%s · %s · 第 %s 决断" % [info.get("playerName", "叶凌云"),
				path_name, info.get("turn", 0)]
		var button: Button = slot_screen.get_node("Slot_" + slot_id)
		button.text = "%s%s  ·  %s" % [info.get("label", slot_id),
			"（上次使用）" if info.get("active") else "", detail]


func _on_slot_pressed(slot_id: String) -> void:
	if save_slots == null or not save_slots.select_slot(slot_id):
		slot_status_label.text = "无法切换玉简；现有记录未被改动。"
		return
	opening_audio.play_opening_music()
	opening_store = RunSession.new(save_slots.save_path_for(slot_id), slot_id)
	opening = OpeningDomain.new(registry, opening_store, slot_id)
	opening.changed.connect(_on_opening_changed)
	_choice_pending = false
	_pending_player_name = "叶凌云"
	name_input.text = ""
	name_count_label.text = "0/4"
	name_input.editable = true
	var index_notice := "旧活动玉简索引已归档为 %s。" % save_slots.last_archived_index.get_file() \
		if not save_slots.last_archived_index.is_empty() else ""
	path_status_label.text = index_notice
	name_status_label.text = index_notice
	for child in path_screen.get_children():
		if child is Button and child.name.begins_with("Path_"):
			child.disabled = false
	slot_screen.visible = false
	if opening.restore():
		if opening.state.get("phase") == "REBIRTH_PENDING" \
				and opening.state.get("path") == null:
			_show_path_screen()
		else:
			name_screen.visible = false
			path_screen.visible = false
			story_screen.visible = true
			_set_scene_surface(true)
			_render()
		if opening.state.get("phase") == "FLOW_PENDING":
			call_deferred("_resume_flow_if_pending")
		if not index_notice.is_empty():
			status_label.text = index_notice
		return
	_show_name_screen()
	if opening_store.has_state_file():
		var archived: String = opening_store.archive_unrestorable()
		if archived.is_empty():
			name_status_label.text = _unrestorable_message()
			name_input.editable = false
		else:
			name_status_label.text = "原记录已归档为 %s。" % archived.get_file()


func _unrestorable_message() -> String:
	var reason := String(opening_store.last_error) if opening_store != null else ""
	if reason == "SOURCE_MISMATCH":
		return "存档来源版本与当前游戏不一致；原文件已保留，已禁用新开局。"
	if reason == "SOURCE_UNAVAILABLE":
		return "当前开局规则资源缺失；原存档已保留，已禁用新开局。"
	if reason == "FUTURE_VERSION":
		return "存档版本高于当前游戏；原文件已保留，已禁用新开局。"
	if reason in ["SLOT_BUSY", "SLOT_LOCK_FAILED"]:
		return "玉简正被另一个游戏进程使用，或上次退出留下锁；原文件已保留。关闭其它进程后重试，若仍失败请联系维护者恢复。"
	if reason == "SLOT_CHANGED":
		return "玉简已在另一个进程发生变化；原文件已保留，请重新打开玉简。"
	if reason.begins_with("PENDING_"):
		return "存档提交待恢复；原文件已保留，已禁用新开局。"
	return "存档无法校验且无法归档；为保护原文件，已禁用新开局。"


func _build_name_screen(parent: Control) -> void:
	name_screen = VBoxContainer.new()
	name_screen.name = "NameCreation"
	name_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	name_screen.alignment = BoxContainer.ALIGNMENT_CENTER
	name_screen.add_theme_constant_override("separation", 14)
	parent.add_child(name_screen)
	var logo := TextureRect.new()
	logo.name = "SourceLogo"
	logo.texture = _art_texture("assets/icons/xianxia_minimal_logo.png")
	logo.custom_minimum_size = Vector2(104, 104)
	logo.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	name_screen.add_child(logo)
	var title := _ink_label("一念仙途", 47)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_screen.add_child(title)
	var subtitle := _ink_label("一念入道 · 执掌因果", 21)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_screen.add_child(subtitle)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(430, 250)
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.095, 0.078, 0.071, 0.94)
	panel_style.border_color = Color("d9b168")
	panel_style.set_border_width_all(1)
	panel_style.set_corner_radius_all(8)
	panel_style.set_content_margin_all(20)
	panel.add_theme_stylebox_override("panel", panel_style)
	name_screen.add_child(panel)
	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 14)
	panel.add_child(inner)
	var heading := _label("玉册题名 · 开启仙途", 26)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	inner.add_child(heading)
	var hint := _label("仙途漫漫，请于道册题写尊号（四字以内）", 16)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	inner.add_child(hint)
	name_input = LineEdit.new()
	name_input.name = "SourceNameInput"
	name_input.max_length = 4
	name_input.placeholder_text = "叶凌云"
	name_input.alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_input.add_theme_font_size_override("font_size", 24)
	GameSkin.apply_text_input(name_input)
	name_input.text_submitted.connect(func(_text: String) -> void: _confirm_name())
	inner.add_child(name_input)
	name_count_label = _label("0/4", 14)
	name_count_label.name = "NameCharacterCount"
	name_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	inner.add_child(name_count_label)
	name_input.text_changed.connect(func(value: String) -> void:
		name_count_label.text = "%d/4" % value.length())
	var confirm := Button.new()
	confirm.name = "ConfirmName"
	confirm.text = "朱 · 凝神定名 · 踏入仙途"
	confirm.custom_minimum_size.y = 50
	GameSkin.apply_action_button(confirm, GameSkin.WARM_RED)
	confirm.pressed.connect(_confirm_name)
	inner.add_child(confirm)
	name_status_label = _ink_label("", 15)
	name_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_screen.add_child(name_status_label)
	var back := Button.new()
	back.name = "ReturnToSlots"
	back.text = "返回玉简"
	back.visible = save_slots != null
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	GameSkin.apply_paper_button(back, GameSkin.BRASS)
	back.pressed.connect(_show_slot_screen)
	name_screen.add_child(back)


func _confirm_name() -> void:
	if not name_input.editable:
		return
	_pending_player_name = name_input.text.strip_edges()
	if _pending_player_name.is_empty():
		_pending_player_name = "叶凌云"
	_show_path_screen()


func _build_path_screen(parent: Control) -> void:
	path_screen = VBoxContainer.new()
	path_screen.name = "PathSelection"
	path_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	path_screen.alignment = BoxContainer.ALIGNMENT_CENTER
	path_screen.add_theme_constant_override("separation", 15)
	parent.add_child(path_screen)

	var heading := _ink_label("择道立誓 · 传承功法", 34)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	path_screen.add_child(heading)
	var instruction := _ink_label("修仙之道，各有所长；一经选择，宿命启程", 19)
	instruction.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	path_screen.add_child(instruction)
	path_status_label = _ink_label("", 15)
	path_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	path_screen.add_child(path_status_label)
	var grid := HBoxContainer.new()
	grid.name = "SourcePathGrid"
	grid.alignment = BoxContainer.ALIGNMENT_CENTER
	grid.add_theme_constant_override("separation", 16)
	path_screen.add_child(grid)

	var paths: Dictionary = _source_paths()
	# The four icons, captions, and accent colors come from index.html's
	# path-floating-grid. Mechanics still come from data/config/paths.json.
	var source_captions := {
		"sword": ["凌霄", "霜剑斩空 · 极致杀伐", "一剑破万法，凭凌厉剑意断绝因果、一击致命"],
		"spell": ["碧霄", "雷法通玄 · 五行变化", "诸术兼修，引天地雷霆与五行灵气运筹帷幄"],
		"body": ["沉金", "肉身成圣 · 气血不灭", "锻淬金身，凭浩瀚血气化作坚强防壁震慑强敌"],
		"pill": ["青木", "以丹入道 · 草木蕴灵", "灵丹妙药，炼天地草木菁华转化为修行大机缘"],
	}
	var accents := {"sword": Color("2a5a5b"), "spell": Color("5c425e"),
		"body": Color("c86f3b"), "pill": Color("375945")}
	for path_id in paths:
		var path: Dictionary = paths[path_id]
		var button := Button.new()
		button.name = "Path_" + String(path_id)
		button.custom_minimum_size = Vector2(218, 335)
		GameSkin.apply_path_card(button, accents[path_id])
		button.tooltip_text = "%s：%s" % [path.get("name", path_id), source_captions[path_id][1]]
		var icon := TextureRect.new()
		icon.name = "SourcePathIcon"
		icon.texture = _art_texture("assets/icons/%s_ink.png" % path_id)
		icon.position = Vector2(29, 18)
		icon.size = Vector2(160, 160)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(icon)
		var title := _ink_label("%s · %s" % [path.get("name", path_id), source_captions[path_id][0]], 22)
		title.position = Vector2(8, 187)
		title.size = Vector2(202, 34)
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(title)
		var calligraphy := _ink_label(source_captions[path_id][1], 17)
		calligraphy.position = Vector2(8, 230)
		calligraphy.size = Vector2(202, 30)
		calligraphy.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		calligraphy.add_theme_color_override("font_color", accents[path_id])
		calligraphy.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(calligraphy)
		var desc := _ink_label(source_captions[path_id][2], 13)
		desc.position = Vector2(13, 270)
		desc.size = Vector2(192, 52)
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		desc.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(desc)
		button.pressed.connect(_on_path_pressed.bind(String(path_id)))
		grid.add_child(button)
		# TextureRect and Label initialize to their authored texture/text minimum
		# during tree entry. Size these absolute children after the button enters.
		icon.size = Vector2(160, 160)
		title.size = Vector2(202, 34)
		calligraphy.size = Vector2(202, 30)
		desc.size = Vector2(192, 52)
	var back := Button.new()
	back.name = "ReturnToSlots"
	back.text = "返回玉简"
	back.visible = save_slots != null
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	GameSkin.apply_paper_button(back, GameSkin.BRASS)
	back.pressed.connect(_show_slot_screen)
	path_screen.add_child(back)


func _build_story_screen(parent: Control) -> void:
	story_screen = VBoxContainer.new()
	story_screen.name = "StoryScreen"
	story_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	story_screen.add_theme_constant_override("separation", 16)
	parent.add_child(story_screen)

	var stats_panel := PanelContainer.new()
	stats_panel.name = "StatsPlaque"
	stats_panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var stats_style := GameSkin.plaque(0.76)
	stats_style.set_content_margin_all(8)
	stats_panel.add_theme_stylebox_override("panel", stats_style)
	story_screen.add_child(stats_panel)
	stats_label = _label("", 16)
	stats_label.name = "AuthoritativeStats"
	stats_panel.add_child(stats_label)
	companion_whisper_panel = PanelContainer.new()
	companion_whisper_panel.name = "CompanionWhisper"
	companion_whisper_panel.visible = false
	companion_whisper_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var companion_style := GameSkin.plaque(0.86)
	companion_style.set_content_margin_all(6)
	companion_whisper_panel.add_theme_stylebox_override("panel", companion_style)
	story_screen.add_child(companion_whisper_panel)
	var companion_row := HBoxContainer.new()
	companion_row.add_theme_constant_override("separation", 12)
	companion_whisper_panel.add_child(companion_row)
	companion_portrait_rect = TextureRect.new()
	companion_portrait_rect.name = "CompanionHudPortrait"
	companion_portrait_rect.custom_minimum_size = Vector2(55, 62)
	companion_portrait_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	companion_portrait_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	companion_row.add_child(companion_portrait_rect)
	var companion_text := VBoxContainer.new()
	companion_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	companion_text.add_theme_constant_override("separation", 2)
	companion_row.add_child(companion_text)
	companion_identity_label = _label("", 16)
	companion_identity_label.name = "CompanionHudIdentity"
	companion_text.add_child(companion_identity_label)
	companion_portrait_button = Button.new()
	companion_portrait_button.name = "ChooseCompanionPortrait"
	companion_portrait_button.text = "更换立绘"
	companion_portrait_button.visible = false
	companion_portrait_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	GameSkin.apply_action_button(companion_portrait_button, GameSkin.JADE)
	companion_portrait_button.pressed.connect(_open_companion_portraits)
	companion_text.add_child(companion_portrait_button)
	companion_whisper_label = _label("", 17)
	companion_whisper_label.name = "CompanionWhisperText"
	companion_whisper_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	companion_whisper_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	companion_whisper_label.add_theme_color_override("font_color", Color("eac78d"))
	companion_whisper_label.visible = false
	companion_text.add_child(companion_whisper_label)

	source_content = HBoxContainer.new()
	source_content.name = "SourceContent"
	source_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	source_content.add_theme_constant_override("separation", 24)
	story_screen.add_child(source_content)

	art_rect = TextureRect.new()
	art_rect.name = "SourceSceneImage"
	art_rect.custom_minimum_size = Vector2(470, 420)
	art_rect.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	art_rect.size_flags_vertical = Control.SIZE_EXPAND_FILL
	art_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	source_content.add_child(art_rect)
	npc_cross_portraits = HBoxContainer.new()
	npc_cross_portraits.name = "NpcCrossPortraits"
	npc_cross_portraits.custom_minimum_size = Vector2(470, 420)
	npc_cross_portraits.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	npc_cross_portraits.size_flags_vertical = Control.SIZE_EXPAND_FILL
	npc_cross_portraits.add_theme_constant_override("separation", 8)
	npc_cross_portraits.visible = false
	source_content.add_child(npc_cross_portraits)
	npc_cross_left = TextureRect.new()
	npc_cross_left.name = "NpcCrossLeft"
	npc_cross_left.custom_minimum_size = Vector2(200, 420)
	npc_cross_left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	npc_cross_left.size_flags_vertical = Control.SIZE_EXPAND_FILL
	npc_cross_left.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	npc_cross_left.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	npc_cross_portraits.add_child(npc_cross_left)
	var cross_relation := _label("VS", 23)
	cross_relation.name = "NpcCrossRelation"
	cross_relation.add_theme_color_override("font_color", Color("eac78d"))
	cross_relation.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	npc_cross_portraits.add_child(cross_relation)
	npc_cross_right = TextureRect.new()
	npc_cross_right.name = "NpcCrossRight"
	npc_cross_right.custom_minimum_size = Vector2(200, 420)
	npc_cross_right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	npc_cross_right.size_flags_vertical = Control.SIZE_EXPAND_FILL
	npc_cross_right.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	npc_cross_right.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	npc_cross_portraits.add_child(npc_cross_right)

	source_text_panel = PanelContainer.new()
	source_text_panel.name = "SourceTextPanel"
	source_text_panel.custom_minimum_size = Vector2(410, 0)
	source_text_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	source_text_panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	source_content.add_child(source_text_panel)
	var panel_style := GameSkin.plaque(0.86)
	panel_style.set_content_margin_all(25)
	source_text_panel.add_theme_stylebox_override("panel", panel_style)
	var text_column := VBoxContainer.new()
	text_column.name = "SourceTextColumn"
	text_column.add_theme_constant_override("separation", 20)
	source_text_panel.add_child(text_column)
	title_label = _label("", 30)
	title_label.name = "SourceCardTitle"
	text_column.add_child(title_label)
	body_label = _label("", 20)
	body_label.name = "SourceCardDescription"
	body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	text_column.add_child(body_label)
	reward_settlement_label = _label("", 22)
	reward_settlement_label.name = "RewardSettlement"
	reward_settlement_label.visible = false
	reward_settlement_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	reward_settlement_label.add_theme_color_override("font_color", Color("e6ca97"))
	text_column.add_child(reward_settlement_label)
	oath_label = _label("", 17)
	oath_label.name = "SpokenOathSubtitle"
	oath_label.visible = false
	oath_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	oath_label.add_theme_color_override("font_color", Color("eac78d"))
	text_column.add_child(oath_label)

	choice_row = HBoxContainer.new()
	choice_row.name = "SourceChoices"
	choice_row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	choice_row.add_theme_constant_override("separation", 18)
	story_screen.add_child(choice_row)
	status_label = _label("", 15)
	status_label.name = "Status"
	story_screen.add_child(status_label)
	var utility_row := HBoxContainer.new()
	utility_row.name = "StoryUtilities"
	utility_row.alignment = BoxContainer.ALIGNMENT_CENTER
	story_screen.add_child(utility_row)
	var map_button := Button.new()
	map_button.name = "OpenWorldMap"
	map_button.text = "山河命卷  M"
	map_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	GameSkin.apply_action_button(map_button, GameSkin.BRASS)
	map_button.pressed.connect(_open_world_map)
	utility_row.add_child(map_button)
	var npc_button := Button.new()
	npc_button.name = "OpenNpcRoster"
	npc_button.text = "人物志"
	GameSkin.apply_action_button(npc_button, GameSkin.JADE)
	npc_button.pressed.connect(_open_npc_roster)
	utility_row.add_child(npc_button)
	var evidence_button := Button.new()
	evidence_button.name = "OpenEvidenceAtlas"
	evidence_button.text = "证据星图"
	evidence_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	GameSkin.apply_action_button(evidence_button, GameSkin.JADE)
	evidence_button.pressed.connect(_open_evidence_atlas)
	utility_row.add_child(evidence_button)
	var gallery_button := Button.new()
	gallery_button.name = "OpenHeavenlyGallery"
	gallery_button.text = "天道万物志"
	GameSkin.apply_action_button(gallery_button, GameSkin.JADE)
	gallery_button.pressed.connect(_open_heavenly_gallery)
	utility_row.add_child(gallery_button)
	var bestiary_button := Button.new()
	bestiary_button.name = "OpenPlayerBestiary"
	bestiary_button.text = "万物志"
	GameSkin.apply_action_button(bestiary_button, GameSkin.JADE)
	bestiary_button.pressed.connect(_open_bestiary)
	utility_row.add_child(bestiary_button)
	var karma_button := Button.new()
	karma_button.name = "OpenKarmaJournal"
	karma_button.text = "因果簿"
	GameSkin.apply_action_button(karma_button, GameSkin.JADE)
	karma_button.pressed.connect(_open_karma_journal)
	utility_row.add_child(karma_button)
	var thread_button := Button.new()
	thread_button.name = "OpenThreadJournal"
	thread_button.text = "故事线"
	GameSkin.apply_action_button(thread_button, GameSkin.JADE)
	thread_button.pressed.connect(_open_thread_journal)
	utility_row.add_child(thread_button)
	story_audio_button = Button.new()
	story_audio_button.name = "ToggleAllAudio"
	GameSkin.apply_action_button(story_audio_button, GameSkin.JADE)
	story_audio_button.pressed.connect(_toggle_all_audio)
	utility_row.add_child(story_audio_button)
	var story_experience_button := Button.new()
	story_experience_button.name = "OpenExperienceSettings"
	story_experience_button.text = "体验设置"
	GameSkin.apply_action_button(story_experience_button, GameSkin.JADE)
	story_experience_button.pressed.connect(_open_experience_dialog)
	utility_row.add_child(story_experience_button)
	equipment_button = Button.new()
	equipment_button.name = "OpenTreasureInventory"
	equipment_button.text = "法宝装备"
	equipment_button.visible = false
	GameSkin.apply_action_button(equipment_button, GameSkin.JADE)
	equipment_button.pressed.connect(_open_treasure_inventory)
	utility_row.add_child(equipment_button)
	boss_fragment_button = Button.new()
	boss_fragment_button.name = "ClaimBossFragment"
	boss_fragment_button.text = "Boss 残卷待领"
	boss_fragment_button.visible = false
	GameSkin.apply_action_button(boss_fragment_button, GameSkin.BRASS)
	boss_fragment_button.pressed.connect(_open_boss_fragment_reward)
	utility_row.add_child(boss_fragment_button)
	legacy_focus_button = Button.new()
	legacy_focus_button.name = "TrackLegacyFragment"
	legacy_focus_button.text = "传承追踪"
	legacy_focus_button.visible = false
	GameSkin.apply_action_button(legacy_focus_button, GameSkin.JADE)
	legacy_focus_button.pressed.connect(_open_legacy_focus)
	utility_row.add_child(legacy_focus_button)
	rebirth_tree_button = Button.new()
	rebirth_tree_button.name = "OpenRebirthTree"
	rebirth_tree_button.text = "轮回树"
	rebirth_tree_button.visible = false
	GameSkin.apply_action_button(rebirth_tree_button, GameSkin.BRASS)
	rebirth_tree_button.pressed.connect(_open_rebirth_tree)
	utility_row.add_child(rebirth_tree_button)
	var back := Button.new()
	back.name = "ReturnToSlots"
	back.text = "返回玉简"
	back.visible = save_slots != null
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	GameSkin.apply_action_button(back, GameSkin.BRASS)
	back.pressed.connect(_show_slot_screen)
	story_screen.add_child(back)


func _toggle_all_audio() -> void:
	if opening_audio == null:
		return
	opening_audio.set_muted(not opening_audio.is_muted())
	_sync_audio_buttons()


func _build_experience_dialog() -> void:
	experience_dialog = AcceptDialog.new()
	experience_dialog.name = "ExperienceSettings"
	experience_dialog.title = "体验设置"
	experience_dialog.ok_button_text = "返回"
	experience_dialog.min_size = Vector2i(480, 350)
	add_child(experience_dialog)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	experience_dialog.add_child(column)
	var scale_row := HBoxContainer.new()
	column.add_child(scale_row)
	var effects_row := HBoxContainer.new()
	column.add_child(effects_row)
	var effects_label := Label.new()
	effects_label.text = "环境特效"
	effects_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	effects_row.add_child(effects_label)
	experience_effects = OptionButton.new()
	experience_effects.name = "EffectQuality"
	for title in ["低", "均衡", "高"]:
		experience_effects.add_item(title)
	experience_effects.item_selected.connect(func(index: int) -> void:
		_set_experience_option("effects", ["low", "balanced", "high"][index]))
	effects_row.add_child(experience_effects)
	experience_steady_camera = CheckButton.new()
	experience_steady_camera.name = "SteadyCamera"
	experience_steady_camera.text = "稳定背景"
	experience_steady_camera.toggled.connect(func(enabled: bool) -> void:
		_set_experience_option("steadyCamera", enabled))
	column.add_child(experience_steady_camera)
	var scale_label := Label.new()
	scale_label.name = "ExperienceScaleLabel"
	scale_label.text = "文字大小"
	scale_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scale_row.add_child(scale_label)
	experience_text_scale = OptionButton.new()
	experience_text_scale.name = "TextScale"
	for title in ["较小", "标准", "较大"]:
		experience_text_scale.add_item(title)
	experience_text_scale.item_selected.connect(func(index: int) -> void:
		_set_experience_option("textScale", ["small", "normal", "large"][index]))
	scale_row.add_child(experience_text_scale)
	experience_readable_font = CheckButton.new()
	experience_readable_font.name = "ReadableFont"
	experience_readable_font.text = "易读字体"
	experience_readable_font.toggled.connect(func(enabled: bool) -> void:
		_set_experience_option("readableFont", enabled))
	column.add_child(experience_readable_font)
	experience_high_contrast = CheckButton.new()
	experience_high_contrast.name = "HighContrast"
	experience_high_contrast.text = "高对比度"
	experience_high_contrast.toggled.connect(func(enabled: bool) -> void:
		_set_experience_option("highContrast", enabled))
	column.add_child(experience_high_contrast)
	var reset_button := Button.new()
	reset_button.name = "ResetExperienceSettings"
	reset_button.text = "恢复默认"
	reset_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	reset_button.pressed.connect(func() -> void:
		experience_settings.reset()
		_sync_experience_dialog()
		_on_experience_changed())
	column.add_child(reset_button)
	_sync_experience_dialog()


func _open_experience_dialog() -> void:
	_sync_experience_dialog()
	experience_dialog.popup_centered(Vector2i(520, 400))
	experience_text_scale.call_deferred("grab_focus")


func _sync_experience_dialog() -> void:
	experience_effects.select(["low", "balanced", "high"].find(
		experience_settings.get_option("effects")))
	experience_steady_camera.set_pressed_no_signal(
		experience_settings.get_option("steadyCamera"))
	experience_text_scale.select(["small", "normal", "large"].find(
		experience_settings.get_option("textScale")))
	experience_readable_font.set_pressed_no_signal(
		experience_settings.get_option("readableFont"))
	experience_high_contrast.set_pressed_no_signal(
		experience_settings.get_option("highContrast"))


func _set_experience_option(key: String, value: Variant) -> void:
	if experience_settings.set_option(key, value):
		_on_experience_changed()


func _on_experience_changed() -> void:
	if story_screen.visible and opening != null:
		_render()
	else:
		_set_scene_surface(false)
	_apply_experience_settings()


func _on_experience_node_added(node: Node) -> void:
	if not (node is Label or node is BaseButton or node is LineEdit
			or node is RichTextLabel or node is ItemList or node is Tree) \
			or not is_ancestor_of(node) or experience_settings == null:
		return
	if experience_settings.get_option("textScale") == "normal" \
			and not experience_settings.get_option("readableFont") \
			and not experience_settings.get_option("highContrast"):
		return
	if not _experience_apply_queued:
		_experience_apply_queued = true
		call_deferred("_apply_experience_settings")


func _apply_experience_settings() -> void:
	_experience_apply_queued = false
	if experience_settings == null:
		return
	ambient_particles.configure(experience_settings.get_option("effects"),
		experience_settings.get_option("steadyCamera"))
	var scale: float = experience_settings.text_multiplier()
	var readable: bool = experience_settings.get_option("readableFont")
	var nodes: Array[Node] = [self]
	while not nodes.is_empty():
		var node: Node = nodes.pop_back()
		for child in node.get_children():
			nodes.append(child)
		if not (node is Label or node is BaseButton or node is LineEdit):
			continue
		var control: Control = node
		var has_size_override := control.has_theme_font_size_override("font_size")
		var current_size := control.get_theme_font_size("font_size")
		if not control.has_meta("experience_base_font_size") \
				or has_size_override != control.get_meta(
					"experience_last_size_override", has_size_override) \
				or current_size != control.get_meta("experience_last_font_size", current_size):
			control.set_meta("experience_base_font_size",
				current_size)
			control.set_meta("experience_had_size_override", has_size_override)
		var has_font_override := control.has_theme_font_override("font")
		var current_font := control.get_theme_font("font")
		if not control.has_meta("experience_had_font_override") \
				or has_font_override != control.get_meta(
					"experience_last_font_override", has_font_override) \
				or has_font_override and current_font != control.get_meta(
					"experience_last_font", current_font):
			control.set_meta("experience_had_font_override", has_font_override)
			if has_font_override:
				control.set_meta("experience_base_font", current_font)
		if scale == 1.0 and not control.get_meta("experience_had_size_override"):
			control.remove_theme_font_size_override("font_size")
		else:
			control.add_theme_font_size_override("font_size", maxi(1, roundi(
				float(control.get_meta("experience_base_font_size")) * scale)))
		control.set_meta("experience_last_size_override",
			control.has_theme_font_size_override("font_size"))
		control.set_meta("experience_last_font_size",
			control.get_theme_font_size("font_size"))
		if readable:
			control.add_theme_font_override("font", READABLE_FONT)
		elif control.get_meta("experience_had_font_override"):
			control.add_theme_font_override("font", control.get_meta("experience_base_font"))
		else:
			control.remove_theme_font_override("font")
		control.set_meta("experience_last_font_override",
			control.has_theme_font_override("font"))
		control.set_meta("experience_last_font", control.get_theme_font("font"))
	var high_contrast: bool = experience_settings.get_option("highContrast")
	_apply_experience_dialogs_contrast(high_contrast)
	if story_screen.visible:
		if high_contrast:
			backdrop_shade.color = Color(0.005, 0.008, 0.01, 0.84)
			var plaque := GameSkin.plaque(0.98)
			plaque.border_color = Color("ffe099")
			plaque.set_border_width_all(2)
			plaque.set_content_margin_all(25)
			source_text_panel.add_theme_stylebox_override("panel", plaque)
		for label in [title_label, body_label, stats_label, status_label,
				reward_settlement_label, oath_label]:
			if label == null:
				continue
			var current_color: Color = label.get_theme_color("font_color")
			if not label.has_meta("experience_base_color") \
					or current_color != label.get_meta(
						"experience_last_color", current_color):
				label.set_meta("experience_base_color", label.get_theme_color("font_color"))
			label.add_theme_color_override("font_color", Color("fff6df")
				if high_contrast else label.get_meta("experience_base_color"))
			label.set_meta("experience_last_color", label.get_theme_color("font_color"))


func _apply_experience_dialogs_contrast(enabled: bool) -> void:
	var nodes: Array[Node] = []
	for dialog in [experience_dialog, evidence_atlas_dialog, heavenly_gallery_dialog,
			bestiary_dialog, karma_journal_dialog, thread_journal_dialog,
			browser_save_picker, browser_import_dialog, browser_replace_confirm,
			companion_portrait_dialog,
			equipment_dialog, boss_fragment_dialog, legacy_focus_dialog,
			rebirth_tree_dialog]:
		if dialog != null:
			nodes.append(dialog)
	while not nodes.is_empty():
		var node: Node = nodes.pop_back()
		for child in node.get_children(true):
			nodes.append(child)
		if not (node is Label or node is BaseButton or node is LineEdit
				or node is RichTextLabel or node is ItemList or node is Tree):
			continue
		var control: Control = node
		var color_keys := ["default_color"] if node is RichTextLabel else ["font_color"]
		if node is BaseButton:
			color_keys.append_array(["font_hover_color", "font_pressed_color",
				"font_hover_pressed_color", "font_focus_color", "font_disabled_color"])
		elif node is LineEdit:
			color_keys.append("font_placeholder_color")
		for color_key in color_keys:
			var base_key: String = "experience_dialog_base_" + color_key
			var override_key: String = "experience_dialog_had_" + color_key
			if not control.has_meta(base_key):
				control.set_meta(base_key, control.get_theme_color(color_key))
				control.set_meta(override_key,
					control.has_theme_color_override(color_key))
			if enabled:
				control.add_theme_color_override(color_key, Color("d6ccb5")
					if color_key in ["font_disabled_color", "font_placeholder_color"]
					else Color("fff6df"))
			elif control.get_meta(override_key):
				control.add_theme_color_override(color_key,
					control.get_meta(base_key))
			else:
				control.remove_theme_color_override(color_key)


func _open_heavenly_gallery() -> void:
	if heavenly_gallery_dialog != null:
		heavenly_gallery_dialog.open_gallery()


func _open_bestiary() -> void:
	if opening == null:
		return
	if heavenly_gallery_dialog.is_mode_enabled():
		_open_heavenly_gallery()
	else:
		bestiary_dialog.open_bestiary(opening)


func _open_karma_journal() -> void:
	if opening != null:
		karma_journal_dialog.open_journal(opening.state)


func _open_thread_journal() -> void:
	if opening != null:
		thread_journal_dialog.open_journal(opening.state)


func _sync_audio_buttons() -> void:
	if opening_audio == null:
		return
	var label := "声音：关" if opening_audio.is_muted() else "声音：开"
	for button in [slot_audio_button, story_audio_button]:
		if button != null:
			button.text = label
			button.tooltip_text = "开启全部声音" if opening_audio.is_muted() else "关闭全部声音"


func _open_treasure_inventory() -> void:
	if opening == null or opening.state.get("phase") not in [
			"NORMAL_PENDING", "THREAD_PENDING"] \
			or active_battle != null:
		return
	if equipment_dialog != null:
		equipment_dialog.queue_free()
	equipment_dialog = AcceptDialog.new()
	equipment_dialog.title = "法宝装备"
	equipment_dialog.ok_button_text = "返回剧情"
	add_child(equipment_dialog)
	equipment_list = VBoxContainer.new()
	equipment_list.custom_minimum_size = Vector2(510, 260)
	equipment_dialog.add_child(equipment_list)
	var catalog: Variant = content_repository.read_module("shops:treasures")
	var definitions := {}
	for definition in catalog.get("treasures", []) if catalog is Dictionary else []:
		if definition is Dictionary and definition.get("id") is String:
			definitions[definition.id] = definition
	var equipment: Dictionary = opening.state.get("equipment", {})
	for instance_id in opening.state.get("treasureInstances", {}):
		var instance: Dictionary = opening.state.treasureInstances[instance_id]
		if instance.get("lifecycle") != "owned":
			continue
		var definition: Dictionary = definitions.get(instance.get("definitionId"), {})
		var slot := String(definition.get("type", ""))
		if slot not in ["weapon", "armor", "accessory", "artifact"]:
			continue
		var row := HBoxContainer.new()
		var label := Label.new()
		label.text = "%s · %s" % [definition.get("name", instance.definitionId),
			{"weapon": "兵刃", "armor": "护具", "accessory": "佩饰",
				"artifact": "秘宝"}[slot]]
		label.custom_minimum_size.x = 330
		row.add_child(label)
		var button := Button.new()
		var installed: bool = equipment.get(slot) == instance_id
		button.text = "卸下" if installed else "装备"
		button.pressed.connect(_on_treasure_inventory_action.bind(
			"unequip" if installed else "equip", String(instance_id), slot))
		row.add_child(button)
		equipment_list.add_child(row)
	equipment_dialog.popup_centered(Vector2i(560, 400))


func _open_boss_fragment_reward() -> void:
	if opening == null or active_battle != null:
		return
	var options: Array[Dictionary] = opening.boss_fragment_options()
	if options.is_empty():
		return
	if boss_fragment_dialog != null:
		boss_fragment_dialog.hide()
		boss_fragment_dialog.queue_free()
	boss_fragment_dialog = AcceptDialog.new()
	boss_fragment_dialog.title = "Boss 战利 · 择取一片传承"
	boss_fragment_dialog.ok_button_text = "稍后领取"
	add_child(boss_fragment_dialog)
	var list := VBoxContainer.new()
	list.custom_minimum_size = Vector2(500, 80)
	boss_fragment_dialog.add_child(list)
	for option in options:
		var button := Button.new()
		button.text = "%s · %d/%d%s\n%s" % [option.name, int(option.count),
			int(option.total), " · 已追踪" if option.focused else "",
			String(option.effect)]
		button.pressed.connect(_on_boss_fragment_claim.bind(String(option.setId)))
		list.add_child(button)
	boss_fragment_dialog.popup_centered(Vector2i(550, 80 + options.size() * 62))


func _on_boss_fragment_claim(set_id: String) -> void:
	if not opening.claim_boss_fragment(set_id):
		status_label.text = "Boss 残卷领取未提交；请核对候选与存档"
		return
	if boss_fragment_dialog != null:
		boss_fragment_dialog.hide()
	status_label.text = "Boss 残卷已领取并保存"


func _open_legacy_focus() -> void:
	if opening == null or active_battle != null:
		return
	var options: Array[Dictionary] = opening.legacy_focus_options()
	if options.is_empty():
		return
	if legacy_focus_dialog != null:
		legacy_focus_dialog.hide()
		legacy_focus_dialog.queue_free()
	legacy_focus_dialog = AcceptDialog.new()
	legacy_focus_dialog.title = "传承追踪 · 指定残卷目标"
	legacy_focus_dialog.ok_button_text = "返回剧情"
	add_child(legacy_focus_dialog)
	var list := VBoxContainer.new()
	list.custom_minimum_size = Vector2(520, 80)
	legacy_focus_dialog.add_child(list)
	for option in options:
		var button := Button.new()
		button.text = "%s · %d/%d%s\n%s" % [option.name, int(option.count),
			int(option.total), " · 正在追踪" if option.focused else "",
			String(option.effect)]
		button.disabled = option.focused
		button.pressed.connect(_on_legacy_focus_changed.bind(String(option.setId)))
		list.add_child(button)
	if opening.state.get("legacyRunState", {}).get("focusedSetId") != null:
		var clear := Button.new()
		clear.text = "取消追踪"
		clear.pressed.connect(_on_legacy_focus_changed.bind(""))
		list.add_child(clear)
	legacy_focus_dialog.popup_centered(Vector2i(560, 80 + list.get_child_count() * 62))


func _on_legacy_focus_changed(set_id: String) -> void:
	if not opening.set_legacy_focus(set_id):
		status_label.text = "传承追踪未提交；请核对套装与存档"
		return
	if legacy_focus_dialog != null:
		legacy_focus_dialog.hide()
	status_label.text = "传承追踪已保存"


func _open_rebirth_tree() -> void:
	if opening == null or active_battle != null:
		return
	var view: Dictionary = opening.rebirth_tree_view()
	if view.is_empty():
		return
	if rebirth_tree_dialog != null:
		rebirth_tree_dialog.hide()
		rebirth_tree_dialog.queue_free()
	rebirth_tree_dialog = AcceptDialog.new()
	rebirth_tree_dialog.title = "轮回树 · 可用悟点 %d" % int(view.insight)
	rebirth_tree_dialog.ok_button_text = "返回剧情"
	add_child(rebirth_tree_dialog)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(650, 500)
	rebirth_tree_dialog.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 12)
	scroll.add_child(list)
	for branch in view.branches:
		var heading := _label("%s · %s" % [branch.name,
			String(branch.description)], 20)
		heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		list.add_child(heading)
		for node in branch.nodes:
			var button := Button.new()
			var owned: bool = node.unlocked
			button.text = "%s  悟点 %d  · %s\n%s" % [
				"退还" if owned else "解锁", int(node.cost), node.name,
				String(node.effectText)]
			button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			button.custom_minimum_size.y = 68
			button.disabled = not (node.canRefund if owned else node.canUnlock)
			button.pressed.connect(_on_rebirth_tree_changed.bind(String(node.id), owned))
			list.add_child(button)
	rebirth_tree_dialog.popup_centered(Vector2i(700, 570))


func _on_rebirth_tree_changed(node_id: String, refund: bool) -> void:
	if not opening.change_rebirth_tree(node_id, refund):
		status_label.text = "轮回树操作未提交；请核对悟点与前置节点"
		return
	_open_rebirth_tree()


func _on_treasure_inventory_action(operation: String, instance_id: String,
		slot: String) -> void:
	if not opening.change_treasure_equipment(operation, instance_id, slot,
			opening.issue_choice_token()):
		status_label.text = "法宝装配未提交：所有权或存档需要校验"
		return
	if equipment_dialog != null:
		equipment_dialog.hide()
	_render()
	status_label.text = "法宝已%s并保存" % ("装备" if operation == "equip" else "卸下")


func _open_npc_roster() -> void:
	if opening != null and not opening.state.is_empty():
		npc_interaction_dialog.show_roster(opening)


func _open_world_map() -> void:
	if opening == null or opening.state.is_empty() or active_battle != null:
		return
	var projected: Dictionary = world_map.project(opening.state,
		opening.get_current_card())
	if projected.is_empty():
		status_label.text = "地图来源校验失败 · " + world_map.last_error
		return
	world_map_overlay.open_map(projected)


func _open_evidence_atlas() -> void:
	if opening == null or opening.state.is_empty() or active_battle != null:
		return
	var projected: Dictionary = evidence_atlas.project(opening.state)
	if projected.is_empty():
		status_label.text = "证据星图来源校验失败 · " + evidence_atlas.last_error
		return
	if evidence_atlas_dialog != null:
		evidence_atlas_dialog.hide()
		evidence_atlas_dialog.queue_free()
	evidence_atlas_dialog = AcceptDialog.new()
	evidence_atlas_dialog.name = "EvidenceAtlasDialog"
	evidence_atlas_dialog.title = "天道证据星图 · 跨世证据"
	evidence_atlas_dialog.ok_button_text = "返回剧情"
	add_child(evidence_atlas_dialog)
	var content := VBoxContainer.new()
	content.custom_minimum_size = Vector2(790, 545)
	content.add_theme_constant_override("separation", 12)
	evidence_atlas_dialog.add_child(content)
	var summary := _label("已取得 %d/%d 条核心证据；证据跨轮回保留，解释仍可能被推翻。" % [
		projected.discoveredClues.size(), int(projected.totalClues)], 18)
	summary.name = "EvidenceAtlasSummary"
	summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(summary)
	var pulse_state: Variant = opening.state.get("worldPulseState")
	if pulse_state == null:
		pulse_state = WorldPulse.initial(opening.state)
	var pulse: Dictionary = WorldPulse.project(pulse_state,
		String(opening.state.get("currentLocation", "")))
	if not pulse.is_empty():
		var pulse_label := _label("%s  ·  动荡 %d  民生 %d  资源 %d  真相 %d" % [
			pulse.headline, int(pulse.instability), int(pulse.hope),
			100 - int(pulse.scarcity), int(pulse.truth)], 15)
		pulse_label.name = "EvidenceWorldPulse"
		pulse_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		content.add_child(pulse_label)
	var tabs := TabContainer.new()
	tabs.name = "EvidenceAtlasTabs"
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(tabs)
	var clues_list := _atlas_tab(tabs, "已证之物")
	if projected.discoveredClues.is_empty():
		clues_list.add_child(_label("星图一片沉寂。探索秘境、追问旧事或回应回响，才能取得可验证的证据。", 18))
	for clue in projected.discoveredClues:
		var definition: Dictionary = clue.definition
		var provenance := "第 %d 世 · 第 %d 次决断" % [int(clue.life), int(clue.turn)] \
			if clue.has("life") and clue.has("turn") else "旧版留存证据"
		_atlas_card(clues_list, "AtlasClue_" + String(clue.id),
			"%s · 可信度 %d/3" % [definition.name, int(definition.reliability)],
			TextPresentation.normalize(definition.description), provenance)
	var hypotheses_list := _atlas_tab(tabs, "天道假说")
	for hypothesis in projected.hypotheses:
		var verdict := "已被现有证据证实" if hypothesis.status == "verified" else (
			"假说成立，但仍缺关键证据" if hypothesis.status == "plausible" else
			"证据不足，暂不可断言")
		_atlas_card(hypotheses_list, "AtlasHypothesis_" + String(hypothesis.id),
			"%s · %d%%" % [hypothesis.title, int(hypothesis.confidence)],
			String(hypothesis.summary), verdict, int(hypothesis.confidence))
	var endings_list := _atlas_tab(tabs, "终局可达性")
	for ending in projected.endings:
		var reasons := []
		for reason in ending.reasons:
			reasons.append(("◆ " if reason.ok else "◇ ") + String(reason.text))
		_atlas_card(endings_list, "AtlasEnding_" + String(ending.id),
			"%s · %s" % [ending.name, "可达" if ending.eligible else
				"%d%%" % int(ending.progress)], String(ending.stance),
			"\n".join(reasons), int(ending.progress))
	evidence_atlas_dialog.popup_centered(Vector2i(840, 620))


func _atlas_tab(tabs: TabContainer, title: String) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.name = title
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tabs.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 10)
	scroll.add_child(list)
	return list


func _atlas_card(parent: VBoxContainer, card_name: String, title: String,
		body: String, note: String, progress: int = -1) -> void:
	var panel := PanelContainer.new()
	panel.name = card_name
	var panel_style := GameSkin.plaque(0.86)
	panel_style.set_content_margin_all(14)
	panel.add_theme_stylebox_override("panel", panel_style)
	parent.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	panel.add_child(column)
	var heading := _label(title, 19)
	heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(heading)
	if progress >= 0:
		var bar := ProgressBar.new()
		bar.value = progress
		bar.show_percentage = false
		bar.custom_minimum_size.y = 7
		column.add_child(bar)
	var description := _label(body, 17)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(description)
	var detail := _label(note, 15)
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.add_theme_color_override("font_color", Color("cdbb91"))
	column.add_child(detail)


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo \
			and event.keycode == KEY_M and story_screen.visible \
			and active_battle == null and world_map_overlay != null \
			and not world_map_overlay.visible:
		_open_world_map()
		get_viewport().set_input_as_handled()


func _label(value: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color("e9e1cf"))
	return label


func _ink_label(value: String, font_size: int) -> Label:
	var label := _label(value, font_size)
	label.add_theme_color_override("font_color", Color("1a1612"))
	return label


func _show_name_screen() -> void:
	slot_screen.visible = false
	name_screen.visible = true
	path_screen.visible = false
	story_screen.visible = false
	_set_scene_surface(false)


func _show_path_screen() -> void:
	slot_screen.visible = false
	name_screen.visible = false
	path_screen.visible = true
	story_screen.visible = false
	_set_scene_surface(false)


func _on_path_pressed(path_id: String) -> void:
	var new_life: bool = opening.state.get("phase") == "REBIRTH_PENDING" \
		and opening.state.get("path") == null
	if not (opening.select_rebirth_path(path_id) if new_life \
			else opening.start(path_id, _pending_player_name)):
		path_status_label.text = "无法开始：来源路径、开场数据或存档写入不可用"
		return
	path_screen.visible = false
	slot_screen.visible = false
	story_screen.visible = true
	_set_scene_surface(true)
	_render()


func _on_opening_changed(event: Dictionary) -> void:
	_choice_pending = false
	var t := String(event.get("type", ""))
	if t == EventTypes.STARTED:
		opening_audio.play_opening_music()
		opening_audio.set_story_scene(String(event.get("cardId", "")))
	elif t == EventTypes.RESTORED:
		opening_audio.play_opening_music()
		opening_audio.set_story_scene(String(event.get("cardId", "")))
	elif t == EventTypes.CHOICE_COMMITTED:
		var next_card_id := String(event.get("nextCardId", ""))
		# At the prologue threshold the spoken oath replaces the generic click.
		if not next_card_id.begins_with("q_start_"):
			opening_audio.play_choice_snap()
		opening_audio.set_story_scene(next_card_id, true)
	elif t in HANDLED_COMBAT_FLOW:
		opening_audio.play_choice_snap()
		opening_audio.set_story_scene(String(event.get("cardId", "")), true)
		if t == EventTypes.FLOW_CARD_READY \
				and opening.state.get("phase") == "KARMA_PENDING":
			opening_audio.play_karma_presentation()
	elif t == EventTypes.RESULT_ACKNOWLEDGED:
		opening_audio.play_choice_snap()
	elif t in HANDLED_VENDOR:
		opening_audio.play_market_transaction()
	_report_undeclared_event(t)
	if opening.state.get("phase") == "REBIRTH_PENDING" \
			and opening.state.get("path") == null:
		_show_path_screen()
		return
	if opening.state.get("path") is String and opening.state.get("path") != "":
		name_screen.visible = false
		path_screen.visible = false
		story_screen.visible = true
		_set_scene_surface(true)
		_render()
		if opening.state.get("phase") == "FLOW_PENDING":
			call_deferred("_resume_flow_if_pending")


## 策略校验：每个事件类型都必须被显式声明为「有专属分支」或「仅音频」。
## 新增事件类型却忘了在本屏登记时，这里会报错（按类型去重，只报一次）。
func _report_undeclared_event(event_type: String) -> void:
	if event_type.is_empty():
		return
	if HANDLED_ALL.has(event_type) or AUDIO_ONLY_EVENTS.has(event_type):
		return
	if _undeclared_event_types.has(event_type):
		return
	_undeclared_event_types[event_type] = true
	push_error("[opening_ui] event type has no declared policy: " + event_type)


func _fit_story_screen() -> void:
	if not is_inside_tree():
		return
	await get_tree().process_frame
	if is_inside_tree() and story_screen != null and story_screen.visible:
		story_screen.size = story_screen.get_parent().size


func _resume_flow_if_pending() -> void:
	if opening != null and opening.state.get("phase") == "FLOW_PENDING":
		if not opening.resume_flow() and not opening.flow_failure_reason().is_empty():
			title_label.text = "剧情来源需要校验"
			body_label.text = "剧情来源校验失败：" + opening.flow_failure_reason() \
				+ "。存档已保留，请修复来源资源后重开。"
			art_rect.texture = null
			status_label.text = "来源校验失败 · 原存档未改动"


func _render() -> void:
	# A portrait scene can leave the anchored VBox at its previous oversized
	# height after content changes. Refit after Godot has recalculated minima.
	call_deferred("_fit_story_screen")
	call_deferred("_apply_experience_settings")
	_reset_story_visual_mode()
	var current: Dictionary = opening.get_current_card()
	var run: Dictionary = opening.state
	ambient_particles.set_phase(String(current.get("_flowPhase",
		run.get("normalFlow", {}).get("phase", "CALM"))))
	var market_session: Variant = run.get("marketState", {}).get("activeSession")
	opening_audio.set_market_presentation(market_session.get("presentationProfile", {})
		if run.get("phase") == "VENDOR_OPEN" and market_session is Dictionary else {})
	equipment_button.visible = run.get("phase") in ["NORMAL_PENDING", "THREAD_PENDING"] \
		and not run.get("treasureInstances", {}).is_empty()
	boss_fragment_button.visible = not opening.boss_fragment_options().is_empty()
	legacy_focus_button.visible = not opening.legacy_focus_options().is_empty()
	rebirth_tree_button.visible = not opening.rebirth_tree_view().is_empty()
	var recent_opportunity: Dictionary = {}
	for record in run.get("opportunityAcquisitions", {}).values():
		if record is Dictionary and int(record.get("turn", -2)) == int(run.get(
				"runClock", {}).get("decisionIndex", -1)) - 1:
			recent_opportunity = record
			break
	if not recent_opportunity.is_empty():
		reward_settlement_label.text = "本次机缘 · %s【%s】" % [
			"技能入组" if recent_opportunity.get("rewardType") == "card" else "法宝入库",
			recent_opportunity.get("rewardName", "")]
		reward_settlement_label.visible = true
	if run.get("phase") == "BATTLE_PENDING":
		# Authored story fights keep their source card visible in run state.
		# The persisted offer owns the pending battlefield screen.
		current = {}
	var attributes: Dictionary = run.get("attributes", {})
	var resources: Dictionary = run.get("resources", {})
	var paths: Dictionary = _source_paths()
	var path_name := String(paths.get(run.get("path", ""), {}).get("name", ""))
	stats_label.text = "%s · %s  ·  修为 %s  气血 %s/%s  道心 %s/%s  寿元 %s  灵石 %s" % [
		run.get("playerName", "叶凌云"), path_name, attributes.get("cultivation", 0), attributes.get("health", 0),
		PathSkillFlow.new(content_repository).actual_max_health(run),
		attributes.get("daoHeart", 0),
		LegacyFragmentFlow.actual_max_dao_heart(run),
		resources.get("lifespan", 0), resources.get("spiritStone", 0)]
	_render_companion_hud(run)
	for child in choice_row.get_children():
		choice_row.remove_child(child)
		child.queue_free()
	if current.is_empty():
		if run.get("phase") == "FLOW_PENDING":
			title_label.text = "这一段因缘已记下"
			body_label.text = "你的选择已保存。本段暂无可接通的后续剧情，请保留这份玉简。"
			art_rect.texture = null
			status_label.text = "剧情续篇待接入 · 已保存第 %s 次决定" % run.get("turn", "")
			return
		var pending_battle: bool = String(run.get("phase", "")) == "BATTLE_PENDING"
		var offer: Dictionary = battle_gateway.source_offer(run) if pending_battle \
			else battle_gateway.offer_from_state(run)
		if offer.is_empty():
			title_label.text = "遭遇来源待校验"
			body_label.text = "当前记录无法对应来源遭遇，请保留玉简，不要重新选择。"
			art_rect.texture = null
			status_label.text = "来源校验失败 · %s" % run.get("currentCardId", "")
			return
		title_label.text = String(offer["title"])
		body_label.text = "%s\n\n对手：%s\n战前情报：%s" % [
			offer["description"], offer["enemyName"], offer["mechanic"]]
		art_rect.texture = _art_texture(String(offer["sceneImage"]))
		if art_rect.texture == null:
			status_label.text = "来源遭遇图未导入 · %s" % offer["sourceCardId"]
			return
		if pending_battle:
			var request: Dictionary = opening.battle_request()
			if request.is_empty():
				status_label.text = "待战合同校验失败 · 保留原存档"
				return
			var plan: Dictionary = BattlePlanResolver.new(registry).resolve_persisted(run)
			if plan.get("launchAuthorized") != true:
				status_label.text = "待战合同已保存 · 战场规则或场景待接入"
				return
			status_label.text = "待战合同已保存 · %s" % offer["sourceCardId"]
			var launch_button := Button.new()
			launch_button.name = "LaunchBattle"
			launch_button.text = "进入战场"
			launch_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			launch_button.custom_minimum_size = Vector2(410, 85)
			GameSkin.apply_action_button(launch_button, GameSkin.BRASS)
			launch_button.pressed.connect(_launch_battle)
			choice_row.add_child(launch_button)
			return
		status_label.text = "来源遭遇 · %s" % offer["sourceCardId"]
		_choice_token = opening.issue_choice_token()
		if _choice_token > 0:
			var accept_button := Button.new()
			accept_button.name = "Choice_left"
			accept_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			accept_button.custom_minimum_size = Vector2(410, 85)
			accept_button.text = String(offer["challengeText"])
			GameSkin.apply_action_button(accept_button, GameSkin.BRASS)
			accept_button.add_theme_font_size_override("font_size", 17)
			accept_button.pressed.connect(_on_choice_pressed.bind("left", _choice_token))
			choice_row.add_child(accept_button)
			var avoid_button := Button.new()
			avoid_button.name = "Choice_right"
			avoid_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			avoid_button.custom_minimum_size = Vector2(410, 85)
			avoid_button.text = String(offer["avoidText"])
			GameSkin.apply_action_button(avoid_button, GameSkin.JADE)
			avoid_button.add_theme_font_size_override("font_size", 17)
			avoid_button.pressed.connect(_on_choice_pressed.bind("right", _choice_token))
			choice_row.add_child(avoid_button)
		return


	title_label.text = String(current.get("title", ""))
	body_label.text = TextPresentation.normalize(current.get("description", ""))
	var scene_path := String(current.get("sceneImage", ""))
	if current.get("type") in ["NPC_ENCOUNTER", "COMPANION_EVENT",
			"COMPANION_MILESTONE"] \
			and scene_path.is_empty():
		var npc_id := String(current.get("compId", current.get("npcId", "")))
		var selected_stage: Dictionary = opening.selected_portrait(npc_id)
		if not selected_stage.is_empty():
			scene_path = String(selected_stage.get("asset", ""))
	if current.get("type") == "KARMA_RIPPLE":
		scene_path = String(current.get("imagePath", ""))
	if run.get("phase") == "VENDOR_OPEN":
		scene_path = String(run.get("marketState", {}).get("activeSession", {}).get(
			"presentationProfile", {}).get("backgroundPath", "")).trim_prefix("../")
	if current.get("type") in ["BAZAAR", "MARKET", "SHOP", "VENDOR_RESULT",
			"REGULATED_RUSTED_SWORD_DELIVERY", "TREASURE_LOADOUT"] \
			and scene_path.is_empty():
		var market_doc: Variant = content_repository.read_module("markets:vendor_profiles")
		var target_vendor := "ghost_market" if current.get("id") == \
			"market_encounter" else "regulated_market" if current.get("type") in [
			"SHOP", "REGULATED_RUSTED_SWORD_DELIVERY", "TREASURE_LOADOUT"] \
			or run.get("phase") == "VENDOR_RESULT_PENDING" and run.get(
				"decisionCheckpoint", {}).get("sourceCardId") in [
					"shop_encounter", "thread_last_lesson_n2"] \
			else "public_bazaar"
		if market_doc is Dictionary:
			for vendor in market_doc.get("vendors", []):
				if vendor is Dictionary and vendor.get("id") == target_vendor:
					scene_path = String(vendor.get("presentationProfile", {}).get(
						"backgroundPath", "")).trim_prefix("../")
					break
	art_rect.texture = _art_texture(scene_path) if not scene_path.is_empty() else null
	art_rect.visible = art_rect.texture != null
	if current.get("type") == "NPC_CROSS":
		var npc_ids: Array = current.get("npcIds", [])
		if npc_ids.size() >= 2:
			body_label.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
			var portraits = CompanionWhisper.new()
			npc_cross_left.texture = _art_texture(
				portraits.npc_portrait_path(String(npc_ids[0])))
			npc_cross_right.texture = _art_texture(
				portraits.npc_portrait_path(String(npc_ids[1])))
			npc_cross_portraits.visible = npc_cross_left.texture != null \
				and npc_cross_right.texture != null
			art_rect.visible = false
	var combat_reward: bool = current.get("id") == "combat_reward"
	if combat_reward and art_rect.texture != null:
		_apply_reward_visual_mode(TextPresentation.normalize(current.get("description", "")),
			current, run)
	if current.get("type") == "DESTINY_WHEEL":
		body_label.text = "五道覆面天机已经排定。选择前四道中的一道翻看，结算后继续刚才的因缘。"
	elif art_rect.texture == null and not npc_cross_portraits.visible \
			and current.get("type") not in ["EMERGENT", "HEAVENS_HINT"]:
		push_error("Opening source image unavailable: " + scene_path)
	_choice_token = opening.issue_choice_token()
	if run.get("phase") == "CAMP_TARGET_PENDING":
		var action := String(run.get("pendingCampAction", ""))
		var target_name := "斩除" if action == "remove" else "强化"
		var targets: Array = opening.camp_targets()
		var source_name := "山间坊市" if run.get("currentCardId") == "q_shop" \
			else "拍卖行" if run.get("currentCardId") == "f_shop" \
			else "轮回恩赐" if run.get("currentCardId") == "rebirth_boon" else "洞府"
		body_label.text = "%s\n\n来源实际删牌界面只允许选一张牌，并按牌组规则收取灵石；也可离开。" % [
			current.get("description", "")] if run.get("currentCardId") == "rebirth_boon" else \
			"%s\n\n已支付%s费用。选择一张牌%s，牌组操作另扣来源规则费用；也可离开，不返还已付费用。" % [
				current.get("description", ""), source_name, target_name]
		status_label.text = "%s · %s牌组目标 · 当前灵石 %d" % [source_name, target_name,
			int(resources.get("spiritStone", 0))]
		var grid := GridContainer.new()
		grid.name = "CampTargets"
		grid.columns = 4
		grid.add_theme_constant_override("h_separation", 10)
		grid.add_theme_constant_override("v_separation", 10)
		choice_row.add_child(grid)
		for target in targets:
			var select_button := Button.new()
			select_button.name = "CampTarget_%d" % int(target.get("index", -1))
			select_button.custom_minimum_size = Vector2(195, 68)
			select_button.text = "%s\n%s · %d 灵石" % [target.get("name", ""),
				target_name, int(target.get("cost", 0))]
			select_button.disabled = not target.get("allowed", false)
			GameSkin.apply_action_button(select_button, GameSkin.JADE)
			if not select_button.disabled:
				select_button.pressed.connect(_on_camp_target_pressed.bind(
					int(target["index"]), String(target["cardId"]), _choice_token))
			grid.add_child(select_button)
		var leave_button := Button.new()
		leave_button.name = "CampTargetCancel"
		leave_button.custom_minimum_size = Vector2(195, 68)
		leave_button.text = "离开" + source_name
		GameSkin.apply_action_button(leave_button, GameSkin.BRASS)
		leave_button.pressed.connect(_on_camp_target_cancel_pressed.bind(_choice_token))
		grid.add_child(leave_button)
		return
	if run.get("phase") == "VENDOR_OPEN":
		var session: Dictionary = run.get("marketState", {}).get("activeSession", {})
		var lesson: bool = session.get("entryCardId") == "thread_last_lesson_n2"
		var regulated: bool = session.get("vendorId") == "regulated_market" and not lesson
		var ghost: bool = session.get("vendorId") == "ghost_market"
		var lines: Array[String] = [String(current.get("description", ""))]
		if lesson:
			lines.append("万宝楼旧剑标价 18 灵石。可买普通货品，办理合规回购与流转号订货；旧剑亦可用剑穗交换，灵石不足可向宗门借剑。")
			for offer in session.get("immutableOffers", []):
				lines.append("%s · %d 灵石" % [offer.get("name", ""), int(offer.get("price", 0))])
		if regulated:
			lines.append("本次官坊明码已锁定。丹药、礼物可成交；持有合规旧物可在回购台登记。")
			for offer in session.get("immutableOffers", []):
				lines.append("%s · %d 灵石" % [offer.get("name", ""), int(offer.get("price", 0))])
		if ghost:
			var ghost_meta: Dictionary = session.get("vendorMeta", {})
			var markup: Dictionary = ghost_meta.get("ghostMarkupRange", {})
			var markup_text := "+%d%%—+%d%%" % [
				roundi((float(markup.get("min", 1.0)) - 1.0) * 100.0),
				roundi((float(markup.get("max", 1.0)) - 1.0) * 100.0)]
			lines.append("不问真名 · 债到必偿 · %s" % ghost_meta.get("fortuneTier", "未知运道"))
			lines.append("每件禁物另折寿元 · 灵石物价%s" % markup_text)
			var ghost_route: Dictionary = ghost_meta.get("tradeRoute", {})
			if not ghost_route.is_empty():
				lines.append("🧭 %s · 通畅%d / 风险%d" % [ghost_route.get("name", ""),
					int(ghost_route.get("openness", 0)), int(ghost_route.get("danger", 0))])
			lines.append("残剑夜契可签；持商路线索可验封。其余禁物暂不交易。")
			for offer in opening.vendor_offers():
				lines.append("%s · %d 灵石 + %d 寿元" % [offer.get("name", ""),
					int(offer.get("price", 0)), int(offer.get("lifespan", 0))])
			for offer in session.get("immutableOffers", []):
				var hidden_note: Variant = offer.get("hiddenTrait")
				if hidden_note is Dictionary:
					lines.append("%s · %s" % [offer.get("name", "禁物"),
						"封签待验" if hidden_note.get("status") == "sealed" \
						else "封签验明：" + String(hidden_note.get("revealedText", ""))])
		for stall in session.get("stalls", []):
			var offer_names: Array[String] = []
			for offer in session.get("immutableOffers", []):
				if offer.get("stallId") == stall.get("id"):
					offer_names.append(String(offer.get("name", "")))
			lines.append("%s · %s：%s" % [stall.get("name", ""),
				stall.get("role", ""), "、".join(offer_names) if not offer_names.is_empty() else "已售罄"])
		var inventory: Dictionary = run.get("itemInventory", {})
		if not inventory.is_empty():
			var owned: Array[String] = []
			for item_id in inventory:
				owned.append("%s×%d" % [item_id, int(inventory[item_id])])
			lines.append("随身物品：%s" % "、".join(owned))
		var vendor_actions: Array = opening.vendor_actions()
		if regulated or lesson:
			for action in vendor_actions:
				if String(action.get("id", "")).begins_with("causal_fact:") \
						or String(action.get("id", "")).begins_with("causal_fact_closed:"):
					lines.append("%s%s：%s" % [action.get("label", "流转号"),
						(" · 需 " + String(action["costText"])) if not String(
							action.get("costText", "")).is_empty() else "",
							action.get("description", "")])
		body_label.text = "\n".join(lines)
		status_label.text = "三鸣旧剑交易已保存 · 离开后继续白刃最后一课" if lesson \
			else "鬼市会话已保存 · 残剑可签，封签可验 · 债到时须清偿或拒约" if ghost \
			else "官坊会话已保存 · 明码交易与流转号订货可办 · 其余货品待接通" if regulated \
			else "集市会话已保存 · 剩余交谈 %d 次 · 疗伤药、商路札记、熟客残剑及流转号询问已接通" % int(
				session.get("interactionBudget", {}).get("remaining", 0))
		for action in vendor_actions:
			var action_button := Button.new()
			action_button.name = "VendorAction_" + String(action.get("id", "")).replace(":", "_")
			action_button.custom_minimum_size = Vector2(215, 75)
			action_button.text = "%s%s" % [
				(String(action.get("stallName", "")) + "\n") if not String(
					action.get("stallName", "")).is_empty() else "",
				action.get("label", "")]
			if ghost and not String(action.get("costText", "")).is_empty():
				action_button.text += "\n需 " + String(action["costText"])
			if (regulated or lesson) and action.has("payout"):
				action_button.text += " · +%d 灵石" % int(action["payout"])
			if (regulated or lesson) and not String(action.get("costText", "")).is_empty():
				action_button.text += "\n需 %s" % action["costText"]
				if not action.get("enabled", false):
					action_button.text += " · 暂不可办"
			action_button.disabled = not action.get("enabled", false)
			GameSkin.apply_action_button(action_button, GameSkin.JADE)
			if not action_button.disabled:
				action_button.pressed.connect(_on_vendor_action_pressed.bind(
					String(action.get("id", "")), _choice_token))
			choice_row.add_child(action_button)
		for offer in opening.vendor_offers():
			if not regulated and not ghost and not offer.get("supported", false):
				continue
			var buy_button := Button.new()
			buy_button.name = "VendorBuy_" + String(offer.get("id", ""))
			buy_button.custom_minimum_size = Vector2(215, 75)
			buy_button.text = "%s\n%d 灵石" % [offer.get("name", ""),
				int(offer.get("price", 0))]
			if not String(offer.get("costMode", "")).is_empty():
				buy_button.text += " · 熟客人情"
			if ghost:
				buy_button.text += " + %d 寿元" % int(offer.get("lifespan", 0))
			if regulated and not offer.get("supported", false):
				buy_button.text += " · 待接通"
			elif ghost and not offer.get("supported", false):
				buy_button.text += " · 暂不交易"
			buy_button.disabled = not offer.get("enabled", false)
			GameSkin.apply_action_button(buy_button, GameSkin.JADE)
			if not buy_button.disabled:
				buy_button.pressed.connect(_on_vendor_buy_pressed.bind(
					String(offer.get("id", "")), _choice_token,
					String(offer.get("costMode", ""))))
			choice_row.add_child(buy_button)
		_append_vendor_loadout_buttons(run)
		var exit_button := Button.new()
		exit_button.name = "VendorClose"
		exit_button.custom_minimum_size = Vector2(215, 75)
		exit_button.text = String(session.get("presentationProfile", {}).get("exitLabel", "离开"))
		GameSkin.apply_action_button(exit_button, GameSkin.BRASS)
		exit_button.pressed.connect(_on_vendor_close_pressed.bind(_choice_token))
		choice_row.add_child(exit_button)
		return
	_append_vendor_loadout_buttons(run)
	status_label.text = "命盘轮转 · 第 %s 次决定" % run.get("turn", "") if \
		run.get("phase") == "DESTINY_WHEEL_PENDING" else (("任务第三幕已保存 · 战斗与结算接口待接入" if _choice_token <= 0 \
		else "来源任务卡 · %s" % current.get("id", "")) \
		if run.get("phase") == "QUEST_PENDING" else ("师徒事件 · %s" % current.get("id", "") \
			if run.get("phase") == "MENTOR_PENDING" else "来源卡牌 · %s" % current.get("id", "")))
	if combat_reward:
		status_label.text = "胜利已结算 · 择一门本脉功法，或保留精简牌组"
	if run.get("phase") == "CAMP_PENDING":
		var deck_rules: Variant = content_repository.read_module("combat:deck_progression")
		if deck_rules is Dictionary:
			var economy: Dictionary = deck_rules.get("economy", {})
			status_label.text = "洞府费用分两次扣：斩牌 %d + %d，强化 %d + %d 灵石；离开目标选择不退款" % [
				int(current.get("choices", {}).get("right", {}).get("costCheck", {}).get("spiritStone", 0)),
				int(economy.get("removeCost", 0)),
				int(current.get("choices", {}).get("down", {}).get("costCheck", {}).get("spiritStone", 0)),
				int(economy.get("upgradeCost", 0))]
	if run.get("phase") == "NORMAL_PENDING" and current.get("id") in ["q_shop", "f_shop"]:
		var shop_deck_rules: Variant = content_repository.read_module("combat:deck_progression")
		if shop_deck_rules is Dictionary:
			status_label.text = "%s · 精简感悟先付 %%d、选牌另付 %%d 灵石；取消选牌不退首笔费用" % ["山间坊市" if current.get("id") == "q_shop" else "拍卖行"] % [
				int(current.get("choices", {}).get("up", {}).get("costCheck", {}).get("spiritStone", 0)),
				int(shop_deck_rules.get("economy", {}).get("removeCost", 0))]
	if _choice_token <= 0:
		return
	var choices: Dictionary = current.get("choices", {})
	var reward_columns: Array[VBoxContainer] = []
	if combat_reward and reward_arena != null:
		for column_id in ["First", "Second"]:
			var column := VBoxContainer.new()
			column.name = "RewardChoices" + column_id
			column.add_theme_constant_override("separation", 16)
			choice_row.add_child(column)
			reward_columns.append(column)
	var reward_index := 0
	for direction in ["left", "right", "up", "down"]:
		if not choices.has(direction):
			continue
		var source_choice: Dictionary = choices[direction]
		var button := Button.new()
		button.name = "Choice_" + direction
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if combat_reward:
			button.custom_minimum_size = Vector2(300 if not reward_columns.is_empty() else (
				230 if direction == "down" else 300 if choices.size() >= 4 else 340),
				clampf(float(get_viewport().size.y) * 0.16, 126.0, 150.0))
			button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			var effect_text := String(source_choice.get("desc", "")).split(
				"\n\n【来源】", false, 1)[0].strip_edges()
			button.text = "%s\n%s" % [source_choice.get("text", direction), effect_text]
			_style_reward_choice(button, direction == "down")
			button.add_theme_font_size_override("font_size", 19)
			_add_reward_choice_copy(button,
				"不纳新法" if direction == "down" else String(
					source_choice.get("text", direction)).trim_prefix("参悟【").trim_suffix("】"),
				effect_text, direction == "down")
		else:
			button.custom_minimum_size = Vector2(410 if choices.size() <= 2 else 230, 85)
			button.text = "%s\n%s" % [source_choice.get("text", direction), source_choice.get("desc", "")]
			if current.get("type") == "NPC_CROSS":
				button.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
			var opportunity_text: String = opening.opportunity_preview(direction)
			if not opportunity_text.is_empty():
				button.text += "\n" + opportunity_text
				button.custom_minimum_size.y = 155
				button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			GameSkin.apply_action_button(button, GameSkin.BRASS if direction in ["left", "up"] else GameSkin.JADE)
			button.add_theme_font_size_override("font_size", 15 if not opportunity_text.is_empty() else 17)
		var locked_combat: bool = run.get("phase") == "QUEST_PENDING" \
			and source_choice.get("triggerCombat") == true \
			and not opening.can_choose_direction(direction)
		var locked_quest: bool = run.get("phase") == "QUEST_PENDING" \
			and not locked_combat and not opening.can_choose_direction(direction)
		var cost: int = int(source_choice.get("effects", {}).get("spiritStone", 0))
		var entry_cost: int = int(source_choice.get("costCheck", {}).get("spiritStone", 0))
		var unaffordable: bool = int(run.get("resources", {}).get("spiritStone", 0)) < maxi(-cost, entry_cost)
		var capped: bool = run.get("phase") in ["REBIRTH_PENDING", "KARMA_PENDING", "MARKET_PENDING", "MENTOR_PENDING", "HINT_PENDING", "NORMAL_PENDING", "CAMP_PENDING"] \
			and not opening.can_choose_direction(direction)
		button.disabled = locked_combat or locked_quest or unaffordable or capped
		if locked_combat:
			button.text += "\n战斗接入中"
		elif locked_quest:
			button.text += "\n任务分支暂不可用"
		elif unaffordable:
			button.text += "\n灵石不足"
		elif capped:
			button.text += "\n%s" % ("来源选择不可用" if run.get("phase") in ["MARKET_PENDING", "CAMP_PENDING"] \
				or current.get("id") in ["q_shop", "f_shop"] and direction != "down" \
				else "正向收益已达上限")
		else:
			button.pressed.connect(_on_choice_pressed.bind(direction, _choice_token))
		if reward_columns.is_empty():
			choice_row.add_child(button)
		else:
			reward_columns[reward_index % 2].add_child(button)
			reward_index += 1
	if not reward_columns.is_empty():
		var visual_order: Array[Button] = []
		for direction in ["left", "right", "up", "down"]:
			var reward_button := choice_row.find_child("Choice_" + direction,
				true, false) as Button
			if reward_button != null:
				visual_order.append(reward_button)
		for index in range(visual_order.size()):
			var reward_button := visual_order[index]
			if index + 1 < visual_order.size():
				reward_button.focus_next = reward_button.get_path_to(visual_order[index + 1])
			if index > 0:
				reward_button.focus_previous = reward_button.get_path_to(visual_order[index - 1])
	if run.get("phase") == "NORMAL_PENDING" and run.get("dungeonRun") is Dictionary:
		var exit_button := Button.new()
		exit_button.name = "DungeonExit"
		exit_button.custom_minimum_size = Vector2(180, 85)
		exit_button.text = "离开秘境"
		GameSkin.apply_action_button(exit_button, GameSkin.BRASS)
		exit_button.pressed.connect(_on_dungeon_exit_pressed.bind(_choice_token))
		choice_row.add_child(exit_button)


## 非战斗取图统一入口：缺失时返回洋红占位，让缺图在截图里一眼可见。
## registry.texture_for() 保持"缺失返回 null"的契约——战斗场景依赖它判定
## 资源可用性，因此占位逻辑只在非战斗这一层落地。
func _art_texture(path: String) -> Texture2D:
	if path.is_empty() or registry == null:
		return null
	var texture: Texture2D = registry.texture_for(path)
	return texture if texture != null else registry.placeholder_texture()


func _launch_battle() -> void:
	if active_battle != null or opening == null \
			or opening.state.get("phase") != "BATTLE_PENDING":
		return
	var request: Dictionary = opening.battle_request()
	var plan: Dictionary = BattlePlanResolver.new(registry).resolve_persisted(opening.state)
	if plan.get("launchAuthorized") != true:
		status_label.text = "待战来源或场景校验失败 · 原存档未改动"
		return
	var battle: Control = BattleStubScript.new() if battle_stub_mode \
		else FirstBattleScene.instantiate()
	battle.battle_request = request.duplicate(true)
	battle.battle_plan = plan.duplicate(true)
	if opening.state.get("browserCombatSnapshot") is Dictionary:
		battle.browser_combat_snapshot = opening.state.browserCombatSnapshot.duplicate(true)
		battle.browser_combat_authority = opening.state.get(
			"browserCombatAuthority", {}).duplicate(true)
		battle.browser_combat_actions = opening.state.get(
			"browserCombatActions", []).duplicate(true)
		battle.browser_combat_commit_card = Callable(opening,
			"commit_browser_combat_card")
		battle.browser_combat_commit_end_turn = Callable(opening,
			"commit_browser_combat_end_turn")
		battle.browser_combat_commit_reaction = Callable(opening,
			"commit_browser_combat_reaction")
	battle.flee_allowed = opening.state.get("pendingBattle", {}).get("fleeAllowed") != false
	battle.battle_finished.connect(_on_battle_finished)
	active_battle = battle
	opening_audio.stop_scene()
	var enemy: Dictionary = plan.get("enemy", {})
	var is_boss: bool = plan.get("isBoss") == true \
		or String(plan.get("difficultyLabel", "")).contains("首领") \
		or int(enemy.get("tier", 0)) >= 3 \
		or plan.get("bossPhase") not in [null, false, 0, ""]
	opening_audio.play_bgm_state("bgm_boss" if is_boss else "bgm_combat")
	story_screen.visible = false
	ambient_particles.visible = false
	ambient_particles.set_process(false)
	add_child(battle)


func _on_battle_finished(result: Dictionary) -> void:
	if active_battle == null or opening == null:
		return
	if not opening.submit_battle_result(result):
		active_battle._set_state_message("战果存档未写入；请再次结算")
		return
	active_battle.queue_free()
	active_battle = null
	story_screen.visible = true
	ambient_particles.visible = true
	ambient_particles.set_process(true)
	opening_audio.play_opening_music()
	_render()


func _source_paths() -> Dictionary:
	if content_repository == null:
		return {}
	var source: Variant = content_repository.read_module("config:paths")
	return source.get("paths", {}) if source is Dictionary else {}


func _on_choice_pressed(direction: String, token: int) -> void:
	if _choice_pending:
		return
	var prior_card: Dictionary = opening.get_current_card()
	var prior_index := int(opening.state.get("runClock", {}).get("decisionIndex", -1))
	_choice_pending = true
	for button in choice_row.find_children("*", "Button", true, false):
		(button as Button).disabled = true
	if not opening.choose(direction, token):
		_choice_pending = false
		_render()
		status_label.text = "选择未提交：已过期或来源规则未迁入"
	elif int(opening.state.get("runClock", {}).get("decisionIndex", -1)) > prior_index:
		_show_companion_whisper(prior_card, direction)


func _show_companion_whisper(card: Dictionary, direction: String) -> void:
	var response: Dictionary = CompanionWhisper.new().reaction(opening.state,
		card, direction)
	if response.is_empty():
		return
	_show_hud_bubble(String(response.text), 3.5)


func _render_companion_hud(run: Dictionary) -> void:
	var whisper = CompanionWhisper.new()
	var active: Dictionary = whisper.active_companion(run)
	if active.is_empty():
		companion_whisper_panel.visible = false
		companion_portrait_button.visible = false
		_companion_hud_id = ""
		_companion_idle_sequence += 1
		return
	var comp_id := String(active.id)
	var affection := int(active.affection)
	companion_whisper_panel.visible = true
	companion_identity_label.text = "%s  ♥ %d" % [_companion_name(comp_id), affection]
	companion_portrait_button.visible = not opening.portrait_options(comp_id).is_empty()
	var fallback_portrait := "assets/cards/characters/card_sunian_mortal_pc98.png"
	var portrait_path: String = whisper.npc_portrait_path(comp_id)
	var selected_stage: Dictionary = opening.selected_portrait(comp_id)
	if not selected_stage.is_empty():
		portrait_path = String(selected_stage.get("asset", portrait_path))
	companion_portrait_rect.texture = _art_texture(portrait_path)
	if companion_portrait_rect.texture == null:
		companion_portrait_rect.texture = _art_texture(fallback_portrait)
	var style := GameSkin.plaque(0.86)
	style.set_content_margin_all(6)
	style.border_color = Color("b89cba") if affection >= 80 else \
		Color("c1a88b") if affection >= 40 else Color("7c827f")
	companion_whisper_panel.add_theme_stylebox_override("panel", style)
	if _companion_hud_id != comp_id:
		_companion_hud_id = comp_id
		_companion_idle_sequence += 1
		var greeting: Dictionary = whisper.greeting(run)
		if not greeting.is_empty():
			_show_hud_bubble(String(greeting.text), 2.5)
		_start_companion_idle(_companion_idle_sequence)


func _open_companion_portraits() -> void:
	if opening == null or active_battle != null:
		return
	var active: Dictionary = CompanionWhisper.new().active_companion(opening.state)
	if active.is_empty():
		return
	var comp_id := String(active.id)
	var options: Array[Dictionary] = opening.portrait_options(comp_id)
	if options.is_empty():
		return
	if companion_portrait_dialog != null:
		companion_portrait_dialog.hide()
		companion_portrait_dialog.queue_free()
	companion_portrait_dialog = AcceptDialog.new()
	companion_portrait_dialog.title = "%s · 立绘" % _companion_name(comp_id)
	companion_portrait_dialog.ok_button_text = "返回剧情"
	add_child(companion_portrait_dialog)
	var list := VBoxContainer.new()
	list.custom_minimum_size = Vector2(500, 80)
	companion_portrait_dialog.add_child(list)
	var selected: Dictionary = opening.selected_portrait(comp_id)
	var explicitly_selected: String = opening.explicitly_selected_portrait_id(comp_id)
	for stage in options:
		var button := Button.new()
		button.text = "%s%s\n%s" % [String(stage.get("name", stage.id)),
			" · 当前" if stage.id == selected.get("id") else "",
			String(stage.get("narrative", ""))]
		button.disabled = stage.id == explicitly_selected
		button.pressed.connect(_on_companion_portrait_changed.bind(
			comp_id, String(stage.id)))
		list.add_child(button)
	companion_portrait_dialog.popup_centered(Vector2i(540, 80 + list.get_child_count() * 78))


func _on_companion_portrait_changed(comp_id: String, stage_id: String) -> void:
	if not opening.select_portrait(comp_id, stage_id):
		status_label.text = "立绘未保存；请核对好感与存档"
		return
	if companion_portrait_dialog != null:
		companion_portrait_dialog.hide()
	status_label.text = "道侣立绘已保存"


func _companion_name(comp_id: String) -> String:
	var name := comp_id
	var source: Variant = content_repository.read_module("companions:events")
	if source is Dictionary:
		for row in source.get("companions", []):
			if row is Dictionary and row.get("id") == comp_id:
				name = String(row.get("name", name))
				break
	if name == comp_id:
		var npcs: Variant = content_repository.read_module("npcs:core")
		if npcs is Dictionary:
			for row in npcs.get("npcs", []):
				if row is Dictionary and row.get("id") == comp_id:
					name = String(row.get("name", name))
					break
	return name


func _show_hud_bubble(message: String, duration: float) -> void:
	companion_whisper_label.text = message
	companion_whisper_label.visible = true
	_whisper_sequence += 1
	_hide_companion_whisper_later(_whisper_sequence, duration)


func _hide_companion_whisper_later(sequence: int, duration: float) -> void:
	await get_tree().create_timer(duration).timeout
	if is_inside_tree() and sequence == _whisper_sequence:
		companion_whisper_label.visible = false


func _start_companion_idle(sequence: int) -> void:
	_show_companion_idle_line(sequence)
	_companion_idle_loop(sequence)


func _show_companion_idle_line(sequence: int) -> void:
	if sequence != _companion_idle_sequence or _companion_hud_id.is_empty() \
			or not story_screen.visible:
		return
	var lines: Array = CompanionWhisper.new().idle_lines(opening.state)
	if not lines.is_empty():
		_show_hud_bubble(String(lines[randi_range(0, lines.size() - 1)]), 3.5)


func _companion_idle_loop(sequence: int) -> void:
	while is_inside_tree() and sequence == _companion_idle_sequence:
		await get_tree().create_timer(15.0 + randf() * 20.0).timeout
		if is_inside_tree() and sequence == _companion_idle_sequence:
			_show_companion_idle_line(sequence)


func _on_dungeon_exit_pressed(token: int) -> void:
	if _choice_pending:
		return
	_choice_pending = true
	for button in choice_row.get_children():
		(button as Button).disabled = true
	if not opening.abandon_dungeon(token):
		_choice_pending = false
		_render()
		status_label.text = "离开秘境未提交：当前秘境状态已变化"


func _on_camp_target_pressed(index: int, card_id: String, token: int) -> void:
	if _choice_pending:
		return
	_choice_pending = true
	if not opening.resolve_camp_target(index, card_id, token):
		_choice_pending = false
		_render()
		status_label.text = "牌组目标未提交：牌位、费用或来源已变化"


func _on_camp_target_cancel_pressed(token: int) -> void:
	if _choice_pending:
		return
	_choice_pending = true
	if not opening.cancel_camp_target(token):
		_choice_pending = false
		_render()
		status_label.text = "离开洞府未提交：操作已过期"

func _on_vendor_action_pressed(action_id: String, token: int) -> void:
	if _choice_pending:
		return
	_choice_pending = true
	if not opening.perform_vendor_action(action_id, token):
		_choice_pending = false
		_render()
		status_label.text = "服务未提交：会话、材料或来源失效"

func _on_vendor_close_pressed(token: int) -> void:
	if _choice_pending:
		return
	_choice_pending = true
	if not opening.close_vendor(token):
		_choice_pending = false
		_render()
		status_label.text = "离摊未提交：会话或来源失效"

func _on_vendor_buy_pressed(offer_id: String, token: int, cost_mode_id: String) -> void:
	if _choice_pending:
		return
	_choice_pending = true
	if not opening.purchase_vendor_offer(offer_id, token, cost_mode_id):
		_choice_pending = false
		_render()
		status_label.text = "购买未提交：余额、库存或来源失效"

func _append_vendor_loadout_buttons(run: Dictionary) -> void:
	var pending_value: Variant = run.get("pendingLoadoutDecision")
	if not pending_value is Dictionary:
		return
	var pending: Dictionary = pending_value
	if pending.get("status") != "pending":
		return
	var instance: Dictionary = run.get("treasureInstances", {}).get(
		pending.get("instanceId", ""), {})
	var treasure_name := String(instance.get("definitionId", ""))
	var catalog: Variant = content_repository.read_module("shops:treasures")
	for definition in catalog.get("treasures", []) if catalog is Dictionary else []:
		if definition is Dictionary and definition.get("id") == instance.get("definitionId"):
			treasure_name = String(definition.get("name", treasure_name))
			break
	for action in ["equip", "stash"]:
		if pending.get("allowedActions", {}).get(action) != true:
			continue
		var button := Button.new()
		button.name = "VendorLoadout_" + action
		button.custom_minimum_size = Vector2(215, 75)
		button.text = "穿戴正货残剑" if action == "equip" and run.get(
			"phase") == "LICENSED_LOADOUT_PENDING" else (
			"穿戴%s" % treasure_name if action == "equip" and not treasure_name.is_empty()
			else "穿戴法宝" if action == "equip" else "收入纳戒")
		GameSkin.apply_action_button(button, GameSkin.BRASS)
		button.pressed.connect(_on_vendor_loadout_pressed.bind(action, _choice_token))
		choice_row.add_child(button)

func _on_vendor_loadout_pressed(action: String, token: int) -> void:
	if _choice_pending:
		return
	_choice_pending = true
	if not opening.resolve_vendor_loadout(action, token):
		_choice_pending = false
		_render()
		status_label.text = "装配未提交：法宝实例或存档来源失效"
