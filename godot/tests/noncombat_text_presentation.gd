extends SceneTree

const TextPresentation = preload("res://scripts/noncombat_text_presentation.gd")
const OpeningUI = preload("res://scripts/noncombat_opening_ui.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var raw := "  首行\\r\\n次行\\n\\n\\n末行\r尾声  "
	var expected := "首行\n次行\n\n末行\n尾声"
	if TextPresentation.normalize(raw) != expected \
			or TextPresentation.normalize(null) != "" \
			or TextPresentation.normalize("甲\n\n\n\n乙") != "甲\n\n乙":
		return _fail("TextPresentation.js line-break source rule differs")
	var ui = OpeningUI.new()
	ui.save_path = ""
	root.add_child(ui)
	await process_frame
	if not ui.opening.start("sword"):
		return _fail("source opening did not start")
	ui.opening._cards["tutorial_1"]["description"] = raw
	ui._render()
	if ui.body_label.text != expected:
		return _fail("story card description did not use source text normalization")
	if ui.heavenly_gallery_dialog._describe({"description": raw}) != expected:
		return _fail("heavenly gallery detail did not use source text normalization")
	print("NONCOMBAT_TEXT_PRESENTATION_PASS source=true story=true gallery=true")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
