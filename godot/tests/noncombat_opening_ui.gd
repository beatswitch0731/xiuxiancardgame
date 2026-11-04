extends SceneTree

const LineageFlow = preload("res://scripts/noncombat_lineage_flow.gd")
const Repository = preload("res://scripts/noncombat_content_repository.gd")


class MissingTextureRegistry extends RefCounted:
	func texture_for(_asset_path: String) -> Texture2D:
		return null


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene_resource = load("res://scenes/noncombat_opening.tscn")
	if scene_resource == null:
		_fail("Godot non-combat opening scene did not load")
		return
	var opening: Control = scene_resource.instantiate()
	opening.save_path = ""
	root.add_child(opening)
	await process_frame
	var start_background: TextureRect = opening.get_node("SourceBackground")
	var path_screen: VBoxContainer = opening.get_node("DesktopMargin/ScreenStack/PathSelection")
	var name_screen: VBoxContainer = opening.get_node("DesktopMargin/ScreenStack/NameCreation")
	if start_background.texture == null or not name_screen.visible \
			or path_screen.get_node_or_null("SourcePathGrid/Path_sword/SourcePathIcon") == null:
		_fail("Original opening background or source path selection is missing")
		return
	var name_entry: LineEdit = name_screen.find_child("SourceNameInput", true, false)
	name_entry.text = "沈砚清霜"
	name_entry.text_changed.emit(name_entry.text)
	if name_entry.max_length != 4 or opening.name_count_label.text != "4/4":
		_fail("source four-character name field or count is missing")
		return
	(name_screen.find_child("ConfirmName", true, false) as Button).pressed.emit()
	if not path_screen.visible:
		_fail("source name confirmation did not reveal path selection")
		return
	var source_icon: TextureRect = path_screen.get_node("SourcePathGrid/Path_sword/SourcePathIcon")
	if source_icon.texture == null or source_icon.size.x > 220:
		_fail("source path icon did not render within its desktop choice")
		return
	(path_screen.get_node("SourcePathGrid/Path_sword") as Button).pressed.emit()
	await process_frame
	if opening.opening.get_current_card().get("id") != "tutorial_1" \
			or opening.opening.state.get("playerName") != "沈砚清霜":
		_fail("Path selection did not reach browser tutorial_1")
		return
	if opening.opening_audio.bgm_player.stream == null \
			or opening.opening_audio.voice_player.stream != null \
			or opening.oath_label.visible:
		_fail("tutorial should have reading music but no out-of-scene path oath")
		return
	var story: VBoxContainer = opening.get_node("DesktopMargin/ScreenStack/StoryScreen")
	if not story.visible or opening.get_node("DesktopMargin/ScreenStack/StoryScreen/SourceChoices").get_node_or_null("Choice_right") == null:
		_fail("Source tutorial choices are not visible")
		return
	var image: TextureRect = opening.get_node_or_null("DesktopMargin/ScreenStack/StoryScreen/SourceContent/SourceSceneImage")
	if image == null or image.texture == null:
		_fail("Source tutorial_1 scene image did not render")
		return
	(opening.get_node("DesktopMargin/ScreenStack/StoryScreen/SourceChoices/Choice_right") as Button).pressed.emit()
	await process_frame
	if opening.opening.get_current_card().get("id") != "tutorial_4" \
			or int(opening.opening.state["attributes"]["cultivation"]) != 10 \
			or opening.opening_audio.sfx_player.stream == null:
		_fail("Right choice did not settle browser cultivation +5 and reach tutorial_4")
		return
	if not opening.legacy_focus_button.visible:
		_fail("source fragment tracking control is not visible")
		return
	opening.legacy_focus_button.pressed.emit()
	var focus_list: VBoxContainer = opening.legacy_focus_dialog.get_child(0) as VBoxContainer
	if focus_list == null or focus_list.get_child_count() != 6:
		_fail("source fragment tracking choices are missing")
		return
	(focus_list.get_child(0) as Button).pressed.emit()
	if opening.opening.state.get("legacyRunState", {}).get("focusedSetId") == null:
		_fail("desktop tracking choice did not reach the domain")
		return
	(opening.get_node("DesktopMargin/ScreenStack/StoryScreen/SourceChoices/Choice_left") as Button).pressed.emit()
	await process_frame
	if opening.opening.get_current_card().get("id") != "q_start_sword" \
			or opening.get_node_or_null("DesktopMargin/ScreenStack/StoryScreen/SourceChoices/Choice_right") == null \
			or opening.opening_audio.voice_player.stream == null \
			or opening.oath_label.text != "剑锋只出一线，余势留给下一式。":
		_fail("Sword prologue must show choices and begin its oath at this scene")
		return
	(opening.get_node("DesktopMargin/ScreenStack/StoryScreen/SourceChoices/Choice_right") as Button).pressed.emit()
	await process_frame
	var handoff_label: Label = opening.get_node("DesktopMargin/ScreenStack/StoryScreen/Status")
	if opening.opening.state.get("phase") != "COMBAT_HANDOFF" \
			or not handoff_label.text.contains("encounter_card_enc_trial_sword_swift"):
		_fail("Committed prologue did not display its exact source battle handoff")
		return
	if opening.title_label.text != "剑修证明·一线快剑" \
			or not opening.body_label.text.contains("快剑木人") \
			or opening.art_rect.texture == null \
			or opening.get_node_or_null("DesktopMargin/ScreenStack/StoryScreen/SourceChoices/Choice_left") == null \
			or opening.get_node_or_null("DesktopMargin/ScreenStack/StoryScreen/SourceChoices/Choice_right") == null:
		_fail("Source encounter offer should show authored challenge and avoid choices")
		return
	(opening.get_node("DesktopMargin/ScreenStack/StoryScreen/SourceChoices/Choice_left") as Button).pressed.emit()
	await process_frame
	if opening.opening.state.get("phase") != "WARNING_PENDING" \
			or opening.opening.get_current_card().get("type") != "COMBAT_WARNING" \
			or opening.get_node_or_null("DesktopMargin/ScreenStack/StoryScreen/SourceChoices/Choice_right") == null:
		_fail("Accepted encounter did not display the persisted source warning choices")
		return
	(opening.get_node("DesktopMargin/ScreenStack/StoryScreen/SourceChoices/Choice_right") as Button).pressed.emit()
	await process_frame
	if opening.opening.state.get("phase") != "BATTLE_PENDING" \
			or opening.opening.battle_request().is_empty() \
			or not opening.status_label.text.contains("待战合同已保存") \
			or opening.get_node_or_null("DesktopMargin/ScreenStack/StoryScreen/SourceChoices/Choice_left") != null:
		_fail("Warning did not persist a verified battle request without starting an unbound scene")
		return
	var resume_path := "user://tests/noncombat_ui_%d.json" % Time.get_ticks_usec()
	var saved_ui: Control = scene_resource.instantiate()
	saved_ui.save_path = resume_path
	root.add_child(saved_ui)
	await process_frame
	(saved_ui.name_screen.find_child("ConfirmName", true, false) as Button).pressed.emit()
	(saved_ui.get_node("DesktopMargin/ScreenStack/PathSelection/SourcePathGrid/Path_sword") as Button).pressed.emit()
	(saved_ui.get_node("DesktopMargin/ScreenStack/StoryScreen/SourceChoices/Choice_right") as Button).pressed.emit()
	(saved_ui.get_node("DesktopMargin/ScreenStack/StoryScreen/SourceChoices/Choice_left") as Button).pressed.emit()
	saved_ui.queue_free()
	await process_frame
	var resumed_ui: Control = scene_resource.instantiate()
	resumed_ui.save_path = resume_path
	root.add_child(resumed_ui)
	await process_frame
	if resumed_ui.opening.get_current_card().get("id") != "q_start_sword" \
			or resumed_ui.get_node("DesktopMargin/ScreenStack/PathSelection").visible \
			or not resumed_ui.get_node("DesktopMargin/ScreenStack/StoryScreen").visible \
			or resumed_ui.opening_audio.ambience_player.stream == null \
			or resumed_ui.opening_audio.voice_player.stream != null \
			or resumed_ui.oath_label.visible:
		_fail("Godot opening UI did not resume prologue ambience without replaying the oath")
		return
	(resumed_ui.get_node("DesktopMargin/ScreenStack/StoryScreen/SourceChoices/Choice_right") as Button).pressed.emit()
	await process_frame
	resumed_ui.queue_free()
	await process_frame
	var resumed_offer_ui: Control = scene_resource.instantiate()
	resumed_offer_ui.save_path = resume_path
	root.add_child(resumed_offer_ui)
	await process_frame
	var sword_offer_image: String = resumed_offer_ui.registry.read_json(
		"data/combat/encounter_presentations.json").get("presentations", {}).get(
			"enc_trial_sword_swift", {}).get("sceneImage", "")
	if resumed_offer_ui.title_label.text != "剑修证明·一线快剑" \
			or not resumed_offer_ui.body_label.text.contains("快剑木人") \
			or resumed_offer_ui.art_rect.texture != resumed_offer_ui.registry.texture_for(
				sword_offer_image) \
			or resumed_offer_ui.opening.state.get("phase") != "COMBAT_HANDOFF" \
			or resumed_offer_ui.opening.issue_choice_token() <= 0:
		_fail("reopened encounter offer lost its source identity or challenge action")
		return
	var source_registry: RefCounted = resumed_offer_ui.registry
	resumed_offer_ui.registry = MissingTextureRegistry.new()
	resumed_offer_ui._render()
	if resumed_offer_ui.art_rect.texture != null \
			or not resumed_offer_ui.status_label.text.contains("来源遭遇图未导入"):
		_fail("missing encounter image retained an unrelated image or hid the import error")
		return
	resumed_offer_ui.registry = source_registry
	resumed_offer_ui._render()
	if resumed_offer_ui.art_rect.texture == null:
		_fail("encounter image did not recover after the source texture was restored")
		return
	(resumed_offer_ui.get_node("DesktopMargin/ScreenStack/StoryScreen/SourceChoices/Choice_right") as Button).pressed.emit()
	await process_frame
	if resumed_offer_ui.opening.state.get("phase") != "NARRATIVE_RESULT_PENDING" \
			or resumed_offer_ui.opening.get_current_card().get("type") != "NARRATIVE_RESULT" \
			or resumed_offer_ui.art_rect.texture == null \
			or resumed_offer_ui.get_node_or_null("DesktopMargin/ScreenStack/StoryScreen/SourceChoices/Choice_left") == null:
		_fail("real UI avoidance did not show the persisted authored response")
		return
	(resumed_offer_ui.get_node("DesktopMargin/ScreenStack/StoryScreen/SourceChoices/Choice_left") as Button).pressed.emit()
	await process_frame
	await process_frame
	if resumed_offer_ui.opening.state.get("phase") != "MILESTONE_PENDING" \
			or resumed_offer_ui.opening.get_current_card().get("id") != "ch_qi_20" \
			or resumed_offer_ui.art_rect.texture == null \
			or resumed_offer_ui.get_node_or_null(
				"DesktopMargin/ScreenStack/StoryScreen/SourceChoices/Choice_left") == null:
		_fail("response acknowledgement did not open the authored first chapter milestone")
		return
	(resumed_offer_ui.get_node("DesktopMargin/ScreenStack/StoryScreen/SourceChoices/Choice_left") as Button).pressed.emit()
	await process_frame
	if resumed_offer_ui.opening.get_current_card().get("id") != "ch_qi_40" \
			or resumed_offer_ui.art_rect.texture == null:
		_fail("chapter milestone choice did not open the next authored beat")
		return
	var damaged_path := "user://noncombat_ui_damaged_%d.json" % Time.get_ticks_usec()
	var damaged_file := FileAccess.open(damaged_path, FileAccess.WRITE)
	damaged_file.store_string("{unrecoverable")
	damaged_file.close()
	var damaged_ui: Control = scene_resource.instantiate()
	damaged_ui.save_path = damaged_path
	root.add_child(damaged_ui)
	await process_frame
	var notice: Label = damaged_ui.name_status_label
	if not notice.text.contains("已归档") or FileAccess.file_exists(damaged_path):
		_fail("Unrestorable opening save was not protected or explained")
		return
	var locked_path := "user://tests/noncombat_ui_locked_%d.json" % Time.get_ticks_usec()
	var created_locked: Control = scene_resource.instantiate()
	created_locked.save_path = locked_path
	root.add_child(created_locked)
	await process_frame
	(created_locked.name_screen.find_child("ConfirmName", true, false) as Button).pressed.emit()
	(created_locked.get_node("DesktopMargin/ScreenStack/PathSelection/SourcePathGrid/Path_sword") as Button).pressed.emit()
	var locked_v2_path: String = created_locked.opening_store.v2_path
	created_locked.queue_free()
	await process_frame
	var locked_envelope: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(locked_v2_path))
	locked_envelope["sourceFingerprint"] = "0".repeat(64)
	var locked_bytes := JSON.stringify(locked_envelope)
	var locked_file := FileAccess.open(locked_v2_path, FileAccess.WRITE)
	locked_file.store_string(locked_bytes)
	locked_file.close()
	var locked_ui: Control = scene_resource.instantiate()
	locked_ui.save_path = locked_path
	root.add_child(locked_ui)
	await process_frame
	if locked_ui.name_input.editable \
			or not locked_ui.name_status_label.text.contains("来源版本") \
			or FileAccess.get_file_as_string(locked_v2_path) != locked_bytes:
		_fail("source-mismatched run was not protected and explained in the real UI")
		return
	for alternate_path in ["spell", "body", "pill"]:
		var alternate_ui: Control = scene_resource.instantiate()
		alternate_ui.save_path = ""
		root.add_child(alternate_ui)
		await process_frame
		(alternate_ui.name_screen.find_child("ConfirmName", true, false) as Button).pressed.emit()
		(alternate_ui.get_node("DesktopMargin/ScreenStack/PathSelection/SourcePathGrid/Path_" \
			+ alternate_path) as Button).pressed.emit()
		for opening_direction in ["right", "left", "right"]:
			(alternate_ui.get_node("DesktopMargin/ScreenStack/StoryScreen/SourceChoices/Choice_" \
				+ opening_direction) as Button).pressed.emit()
		var alternate_offer: Dictionary = alternate_ui.battle_gateway.offer_from_state(
			alternate_ui.opening.state)
		if alternate_offer.is_empty() or alternate_ui.art_rect.texture != \
				alternate_ui.registry.texture_for(String(alternate_offer.get("sceneImage", ""))):
			_fail("opening UI did not show the authored encounter image for " + alternate_path)
			return
		alternate_ui.opening_audio.stop_scene()
		for player in [alternate_ui.opening_audio.bgm_player,
				alternate_ui.opening_audio.sfx_player]:
			player.stop()
			player.stream = null
		alternate_ui.queue_free()
		await process_frame
	var tree := LineageFlow.new(Repository.new()).initial_tree()
	tree.insight = 1
	opening.opening.state["rebirthTree"] = tree
	opening.opening.state["rebirthTreeActions"] = []
	opening._render()
	if not opening.rebirth_tree_button.visible:
		_fail("rebirth tree desktop entry is missing")
		return
	opening.rebirth_tree_button.pressed.emit()
	var tree_list: VBoxContainer = opening.rebirth_tree_dialog.get_child(0).get_child(0) as VBoxContainer
	var first_node: Button = null
	var node_count := 0
	for child in tree_list.get_children():
		if child is Button:
			node_count += 1
			if child.text.contains("淬脉"):
				first_node = child
	if node_count != 16 or first_node == null or first_node.disabled:
		_fail("source rebirth tree nodes or earned insight were not shown")
		return
	first_node.pressed.emit()
	if not opening.opening.state.rebirthTree.unlockedNodeIds.has(
			"foundation_tempered_meridian"):
		_fail("desktop rebirth node choice did not reach the domain")
		return
	for ui in [opening, resumed_offer_ui, damaged_ui]:
		ui.queue_free()
	locked_ui.queue_free()
	await create_timer(0.2).timeout
	print("NONCOMBAT_OPENING_UI_PASS source_art=true path=sword prologue_oath=true resume_ambience=true archive=true")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
