extends SceneTree

const OpeningUI = preload("res://scripts/noncombat_opening_ui.gd")
const Registry = preload("res://scripts/runtime_data_registry.gd")
const Domain = preload("res://scripts/noncombat_domain.gd")
const Session = preload("res://scripts/noncombat_run_session.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://tests"))
	var path := "user://tests/bestiary_%d.json" % Time.get_ticks_usec()
	var gallery_settings_path := "user://tests/bestiary_gallery_%d.cfg" % Time.get_ticks_usec()
	var ui = OpeningUI.new()
	ui.save_path = path
	ui.gallery_settings_path = gallery_settings_path
	root.add_child(ui)
	await process_frame
	if not ui.opening.start("sword"):
		return _fail("source story did not start")
	var mode: CheckButton = ui.heavenly_gallery_dialog.find_child(
		"HeavenlyModeSwitch", true, false)
	mode.button_pressed = false
	var button: Button = ui.find_child("OpenPlayerBestiary", true, false)
	if button == null or not button.visible:
		return _fail("player bestiary has no visible story entry")
	var before: Dictionary = ui.opening.state.duplicate(true)
	button.pressed.emit()
	await process_frame
	var bestiary: AcceptDialog = ui.find_child("PlayerBestiary", true, false)
	var tabs: TabContainer = bestiary.find_child("BestiaryTabs", true, false)
	if not bestiary.visible or tabs.get_tab_count() != 4 \
			or ui.opening.state != before:
		return _fail("opening four-tab bestiary changed gameplay")
	var companions: VBoxContainer = bestiary.find_child("companions", true, false).get_child(0)
	if companions.get_child_count() != 8:
		return _fail("source eight companion entries missing")
	(companions.get_child(1) as Button).pressed.emit()
	await process_frame
	var portrait: AcceptDialog = bestiary.find_child("BestiaryPortraitViewer", true, false)
	if not portrait.visible or ui.opening.state != before:
		return _fail("unowned portrait viewer changed gameplay")
	var stage_choices: VBoxContainer = portrait.find_child("BestiaryStageChoices", true, false)
	var first_stage_button: Button = stage_choices.get_child(0)
	if first_stage_button.disabled or not String(companions.get_child(1).text).contains("1/"):
		return _fail("source zero-affection unowned stage was incorrectly locked")
	var portrait_source: Dictionary = Registry.new().read_json(
		"data/companions/portrait_stages.json")
	var companion_id: String = portrait_source.portraitStages.keys()[1]
	var first_stage_id: String = portrait_source.portraitStages[companion_id].stages[0].id
	first_stage_button.pressed.emit()
	if ui.opening.state.companionCosmetics.selectedPortraitByNpc.get(companion_id) != first_stage_id:
		return _fail("source unowned first stage selection did not persist")
	portrait.hide()
	var items: VBoxContainer = bestiary.find_child("items", true, false).get_child(0)
	if items.get_child_count() < 4 or not String(items.get_child(0).text).contains("灵石"):
		return _fail("player resources and empty inventory missing")
	var techniques: VBoxContainer = bestiary.find_child("techniques", true, false).get_child(0)
	var source: Dictionary = Registry.new().read_json("data/config/path_skills.json")
	if techniques.get_child_count() != 1 + source.skills.sword.skills.size():
		return _fail("source path skill unlock list missing")
	var fragments: VBoxContainer = bestiary.find_child("fragments", true, false).get_child(0)
	if fragments.get_child_count() < 6:
		return _fail("source six fragment sets missing")
	var battle_cards: Array = Registry.new().read_json("data/cards/battle_cards.json").battle_cards
	var sword_variant := ""
	for card in battle_cards:
		if card.get("legacySetId") == "sword_heart" and card.get("legacyPath") == "sword":
			sword_variant = String(card.name)
			break
	if sword_variant.is_empty() or not String(fragments.get_child(0).text).contains(sword_variant) \
			or not String(techniques.get_child(0).text).contains("剑修"):
		return _fail("source path name or legacy variant preview missing")
	var focus: Array[Dictionary] = ui.opening.legacy_focus_options()
	if focus.is_empty():
		return _fail("source legacy focus options missing")
	var first_set := String(focus[0].setId)
	var focus_button: Button = null
	for child in fragments.get_children():
		if child is Button:
			focus_button = child
			break
	if focus_button == null:
		return _fail("bestary focus action missing")
	focus_button.pressed.emit()
	if String(ui.opening.state.legacyRunState.get("focusedSetId", "")) != first_set:
		return _fail("bestary focus action did not commit")
	var reopened = Domain.new(Registry.new(), Session.new(path))
	if not reopened.restore() or reopened.state.legacyRunState.get("focusedSetId") != first_set \
			or reopened.state.companionCosmetics.selectedPortraitByNpc.get(
				companion_id) != first_stage_id:
		return _fail("bestary focus did not survive cold restore")
	ui.opening.state.legacyArchive.completedSetIds = ["sword_heart"]
	ui.opening.state.legacyRunState.activeSetIds = ["sword_heart"]
	bestiary._render_all()
	var has_bonus := false
	for child in fragments.get_children():
		if child is Label and child.text.contains("暴击率 +5%"):
			has_bonus = true
	if not has_bonus:
		return _fail("source active legacy passive bonus missing")
	for resolution in [Vector2i(1280, 800), Vector2i(1920, 1080)]:
		root.get_window().size = resolution
		await process_frame
		await process_frame
		if button.get_global_rect().end.x > resolution.x \
				or button.get_global_rect().end.y > resolution.y \
				or bestiary.position.x + bestiary.size.x > resolution.x \
				or bestiary.position.y + bestiary.size.y > resolution.y:
			return _fail("bestary clipped at %s" % resolution)
	mode.button_pressed = true
	bestiary.hide()
	button.pressed.emit()
	await process_frame
	if not ui.heavenly_gallery_dialog.visible or bestiary.visible:
		return _fail("heavenly mode did not route bestiary to source gallery")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(gallery_settings_path))
	print("NONCOMBAT_BESTIARY_UI_PASS tabs=4 companions=8 skills=true focus=true replay=true heavenly=true")
	quit(0)

func _fail(message: String) -> void:
	push_error(message)
	quit(1)
