extends SceneTree

## 按屏截图（B 阶段新增）。补 shot_probe 只能截 slot 屏的缺口。
##
## 用法：
##   godot --path . --script res://tools/shot_screens.gd -- name
##   godot --path . --script res://tools/shot_screens.gd -- path
##   godot --path . --script res://tools/shot_screens.gd -- slot
##
## 必须非 headless。切屏手法复用 tools/capture_noncombat_opening.gd：
## 走非 slot 屏时要先置 opening.save_path = ""（必须在 add_child 之前，
## 因为 _ready 会据此决定是否进入三槽位模式）。

const TARGET := "res://scenes/noncombat_opening.tscn"
const WAIT_FRAMES := 8

var _screen := "slot"


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_screen = String(args[0])
	_boot()


func _boot() -> void:
	var packed: PackedScene = load(TARGET)
	if packed == null:
		printerr("SHOT_SCREENS_FAIL load " + TARGET)
		quit(1)
		return
	var ui: Control = packed.instantiate()
	if _screen != "slot":
		ui.save_path = ""
	root.add_child(ui)
	for _i in WAIT_FRAMES:
		await process_frame
	if not await _switch_to(ui, _screen):
		quit(1)
		return
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	if image == null or image.is_empty():
		printerr("SHOT_SCREENS_FAIL no image for " + _screen)
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path("res://output"))
	var out := "res://output/_shot_%s.png" % _screen
	var err := image.save_png(out)
	if err != OK:
		printerr("SHOT_SCREENS_FAIL save err=%d" % err)
		quit(1)
		return
	print("SHOT_SCREENS_PASS screen=%s path=%s size=%s"
		% [_screen, out, str(image.get_size())])
	quit(0)


func _switch_to(ui: Control, screen: String) -> bool:
	match screen:
		"slot", "name":
			return true
		"path":
			var confirm := ui.name_screen.find_child("ConfirmName", true, false) as Button
			if confirm == null:
				printerr("SHOT_SCREENS_FAIL ConfirmName not found")
				return false
			confirm.pressed.emit()
			for _i in WAIT_FRAMES:
				await process_frame
			return true
		_:
			printerr("SHOT_SCREENS_FAIL unknown screen: " + screen)
			return false
