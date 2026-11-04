extends SceneTree

const Slots = preload("res://scripts/noncombat_save_slots.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	# ticks_usec is measured from this Godot process's startup. A prior test
	# process can reuse that value and silently load its old three-slot fixture.
	var root_path := "user://tests/noncombat_slot_ui_%d_%d_%d" % [
		int(Time.get_unix_time_from_system()), OS.get_process_id(),
		Time.get_ticks_usec()]
	var scene: PackedScene = load("res://scenes/noncombat_opening.tscn")
	var ui: Control = scene.instantiate()
	ui.slot_root_path = root_path
	root.add_child(ui)
	await process_frame
	var slots: Control = ui.get_node("DesktopMargin/ScreenStack/SlotSelection")
	if not slots.visible or slots.get_node_or_null("Slot_slot_1") == null \
			or slots.get_node_or_null("Slot_slot_2") == null \
			or slots.get_node_or_null("Slot_slot_3") == null:
		_fail("desktop entry did not show the source three-slot chooser")
		return
	if (slots.get_node("Slot_slot_1") as Button).text.contains("上次使用") \
			or Slots.new(root_path).inspect_slot("slot_1").get("active"):
		_fail("new empty directory was labelled as a previously used slot")
		return
	(slots.get_node("Slot_slot_1") as Button).pressed.emit()
	await process_frame
	ui.name_input.text = "沈砚"
	(ui.name_screen.find_child("ConfirmName", true, false) as Button).pressed.emit()
	(ui.get_node("DesktopMargin/ScreenStack/PathSelection/SourcePathGrid/Path_sword") as Button).pressed.emit()
	(ui.get_node("DesktopMargin/ScreenStack/StoryScreen/SourceChoices/Choice_right") as Button).pressed.emit()
	await process_frame
	(ui.get_node("DesktopMargin/ScreenStack/StoryScreen/ReturnToSlots") as Button).pressed.emit()
	(slots.get_node("Slot_slot_2") as Button).pressed.emit()
	await process_frame
	(ui.name_screen.find_child("ConfirmName", true, false) as Button).pressed.emit()
	(ui.get_node("DesktopMargin/ScreenStack/PathSelection/SourcePathGrid/Path_body") as Button).pressed.emit()
	await process_frame
	if ui.opening.state.get("path") != "body" or slots.visible:
		_fail("second slot did not start an independent body run")
		return
	(ui.get_node("DesktopMargin/ScreenStack/StoryScreen/SourceChoices/Choice_right") as Button).pressed.emit()
	await process_frame
	if ui.opening.state["runClock"]["lifeId"] != "slot_2:life:0" \
			or not ui.opening.state["runClock"]["receipts"].has(
			"decision:slot_2:life:0:choice:tutorial_1:1"):
		_fail("slot-two UI choice used the wrong causal decision identity")
		return
	(ui.get_node("DesktopMargin/ScreenStack/StoryScreen/ReturnToSlots") as Button).pressed.emit()
	(slots.get_node("Slot_slot_1") as Button).pressed.emit()
	await process_frame
	if ui.opening.state.get("path") != "sword" \
			or ui.opening.state.get("playerName") != "沈砚" \
			or ui.opening.get_current_card().get("id") != "tutorial_4" \
			or Slots.new(root_path).active_slot() != "slot_1":
		_fail("returning to the original slot did not restore its unresolved card: path=%s name=%s card=%s active=%s store=%s phase=%s" % [
			ui.opening.state.get("path", ""), ui.opening.state.get("playerName", ""),
			ui.opening.get_current_card().get("id", ""), Slots.new(root_path).active_slot(),
			ui.opening_store.last_error, ui.opening.state.get("phase", "")])
		return
	if not (slots.get_node("Slot_slot_1") as Button).text.contains("沈砚 · 剑修"):
		_fail("source name and localized path are absent from the slot summary")
		return
	(ui.get_node("DesktopMargin/ScreenStack/StoryScreen/SourceChoices/Choice_left") as Button).pressed.emit()
	(ui.get_node("DesktopMargin/ScreenStack/StoryScreen/SourceChoices/Choice_right") as Button).pressed.emit()
	var offer: Dictionary = ui.battle_gateway.offer_from_state(ui.opening.state)
	if offer.get("encounterId") != "enc_trial_sword_swift" \
			or ui.art_rect.texture == null \
			or ui.art_rect.texture != ui.registry.texture_for(String(offer.get("sceneImage", ""))):
		_fail("default slot did not show the authored sword encounter image")
		return
	(ui.get_node("DesktopMargin/ScreenStack/StoryScreen/ReturnToSlots") as Button).pressed.emit()
	if not (slots.get_node("Slot_slot_1") as Button).text.contains("上次使用"):
		_fail("selected slot lost its actual last-used marker")
		return
	(slots.get_node("Slot_slot_1") as Button).pressed.emit()
	await process_frame
	if ui.opening.state.get("currentCardId") != offer.get("sourceCardId") \
			or ui.art_rect.texture == null \
			or ui.art_rect.texture != ui.registry.texture_for(String(offer.get("sceneImage", ""))):
		_fail("default slot reload changed the encounter source image")
		return
	var third_path: String = Slots.new(root_path).save_path_for("slot_3")
	var damaged := FileAccess.open(third_path, FileAccess.WRITE)
	damaged.store_string("{damaged third slot")
	damaged.close()
	(ui.get_node("DesktopMargin/ScreenStack/StoryScreen/ReturnToSlots") as Button).pressed.emit()
	(slots.get_node("Slot_slot_3") as Button).pressed.emit()
	await process_frame
	var archived_third := false
	for filename in DirAccess.get_files_at(ProjectSettings.globalize_path(root_path)):
		if filename.begins_with("noncombat_opening_slot_3_v1.unrestorable.") \
				and FileAccess.get_file_as_string(root_path + "/" + filename) == "{damaged third slot":
			archived_third = true
	if not archived_third or not ui.name_status_label.text.contains("已归档") \
			or not ui.get_node("DesktopMargin/ScreenStack/NameCreation").visible:
		_fail("damaged slot was neither preserved nor explained in the native UI")
		return
	var index_path := root_path + "/noncombat_active_slot_v1.json"
	var bad_index := FileAccess.open(index_path, FileAccess.WRITE)
	bad_index.store_string("{damaged active slot")
	bad_index.close()
	(ui.get_node("DesktopMargin/ScreenStack/NameCreation/ReturnToSlots") as Button).pressed.emit()
	if not ui.slot_status_label.text.contains("索引需要修复"):
		_fail("damaged active index was not explained before recovery")
		return
	(slots.get_node("Slot_slot_2") as Button).pressed.emit()
	await process_frame
	if ui.opening.state.get("path") != "body" or Slots.new(root_path).active_slot() != "slot_2" \
			or ui.save_slots.last_archived_index.is_empty() \
			or FileAccess.get_file_as_string(ui.save_slots.last_archived_index) != "{damaged active slot":
		_fail("damaged active index prevented switching or lost the original bytes")
		return
	ui.queue_free()
	await create_timer(0.2).timeout
	print("NONCOMBAT_SAVE_SLOT_UI_PASS slots=3 switch=sword-body-sword resume=tutorial_4 damaged_recovery=true")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
