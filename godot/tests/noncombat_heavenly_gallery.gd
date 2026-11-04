extends SceneTree

const Registry = preload("res://scripts/runtime_data_registry.gd")
const Gallery = preload("res://scripts/noncombat_heavenly_gallery.gd")
const OpeningUI = preload("res://scripts/noncombat_opening_ui.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://tests"))
	var gallery_settings_path := "user://tests/gallery_mode_%d.cfg" % Time.get_ticks_usec()
	var gallery = Gallery.new()
	var entries: Array[Dictionary] = gallery.entries()
	var source: Dictionary = Registry.new().read_json("data/companions/portrait_stages.json")
	var portrait_count := 0
	for definition in source.portraitStages.values():
		portrait_count += definition.get("stages", []).size()
	if gallery.filter("portraits").size() != portrait_count or entries.size() != 1099:
		return _fail("source catalog entries or portrait stages are missing")
	var source_counts := {"portraits": 35, "people": 15, "story": 762,
		"skills": 190, "items": 82, "fragments": 6, "endings": 9}
	for category in source_counts:
		if gallery.filter(category).size() != source_counts[category]:
			return _fail("source gallery category count differs: " + category)
	var keys := {}
	for entry in entries:
		if keys.has(entry.key):
			return _fail("gallery structural key duplicated: " + entry.key)
		keys[entry.key] = true
	var fox: Array[Dictionary] = gallery.filter("portraits", "bai_luoxuan")
	if fox.is_empty() or gallery.filter("people").is_empty() \
			or gallery.filter("story").is_empty() \
			or gallery.filter("skills").is_empty() \
			or gallery.filter("items").is_empty() \
			or gallery.filter("endings").is_empty() \
			or gallery.filter("fragments").size() != 6:
		return _fail("one or more source gallery categories are absent")
	var ui = OpeningUI.new()
	ui.save_path = ""
	ui.gallery_settings_path = gallery_settings_path
	root.add_child(ui)
	await process_frame
	if not ui.opening.start("sword") or not ui.story_screen.visible:
		return _fail("desktop story entry is unavailable")
	var button: Button = ui.find_child("OpenHeavenlyGallery", true, false)
	if button == null or not button.visible:
		return _fail("desktop gallery has no player entry")
	var before: Dictionary = ui.opening.state.duplicate(true)
	button.pressed.emit()
	await process_frame
	var dialog: AcceptDialog = ui.find_child("HeavenlyGallery", true, false)
	if dialog == null or not dialog.visible:
		return _fail("desktop gallery did not open")
	var list: ItemList = dialog.find_child("GalleryEntries", true, false)
	var portrait: TextureRect = dialog.find_child("GalleryPortrait", true, false)
	if list == null or list.item_count != portrait_count or portrait.texture == null:
		return _fail("portrait gallery does not show authored stage images")
	var picker: OptionButton = dialog.find_child("GalleryCategory", true, false)
	for index in range(picker.item_count):
		if picker.get_item_metadata(index) == "story":
			picker.select(index)
			picker.item_selected.emit(index)
			break
	if list.item_count != 48:
		return _fail("source gallery first page is not capped at 48")
	var search: LineEdit = dialog.find_child("GallerySearch", true, false)
	search.text = "q_start_sword"
	search.text_changed.emit(search.text)
	if list.item_count < 1 or list.item_count >= 48:
		return _fail("gallery search did not narrow source structural entries")
	search.text = ""
	search.text_changed.emit("")
	var detail: RichTextLabel = dialog.find_child("GalleryDetailText", true, false)
	search.text = "ds_blood_moon"
	search.text_changed.emit(search.text)
	if list.item_count < 1 or not detail.text.contains("你走近她"):
		return _fail("source blood moon narrativeBlock is absent from gallery detail")
	search.text = "白落霜·参汤"
	search.text_changed.emit(search.text)
	if list.item_count < 1 or not detail.text.contains("以后别叫我恩公了"):
		return _fail("source companion arc choices are absent from gallery detail")
	search.text = ""
	search.text_changed.emit("")
	for resolution in [Vector2i(1280, 800), Vector2i(1920, 1080)]:
		root.get_window().size = resolution
		await process_frame
		await process_frame
		if dialog.position.x + dialog.size.x > resolution.x \
				or dialog.position.y + dialog.size.y > resolution.y \
				or button.get_global_rect().end.x > resolution.x \
				or button.get_global_rect().end.y > resolution.y:
			return _fail("gallery clipped at %s" % resolution)
	if ui.opening.state != before:
		return _fail("read-only gallery changed the run")
	var mode: CheckButton = dialog.find_child("HeavenlyModeSwitch", true, false)
	mode.button_pressed = false
	await process_frame
	if dialog.visible:
		return _fail("disabling heavenly mode did not close its catalog")
	button.pressed.emit()
	await process_frame
	if not dialog.visible or not mode.button_pressed or ui.opening.state != before:
		return _fail("reopening the source gallery mutated gameplay or failed to restore mode")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(gallery_settings_path))
	print("NONCOMBAT_HEAVENLY_GALLERY_PASS entries=%d portraits=%d categories=true ui=true" % [
		entries.size(), portrait_count])
	quit(0)

func _fail(message: String) -> void:
	push_error(message)
	quit(1)
