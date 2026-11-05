extends SceneTree

## 截图探针：验证「非 headless 模式能否把场景渲染结果存成 PNG」。
## 用途：为抽屏改造（B4/B5）提供视觉回归手段。
## 注意：必须在非 headless 模式下运行，headless 无渲染上下文。

const TARGET := "res://scenes/noncombat_opening.tscn"
const OUT := "res://output/_shot_probe.png"


func _initialize() -> void:
	var packed: PackedScene = load(TARGET)
	if packed == null:
		printerr("SHOT_PROBE_FAIL load " + TARGET)
		quit(1)
		return
	var instance: Node = packed.instantiate()
	if instance == null:
		printerr("SHOT_PROBE_FAIL instantiate")
		quit(1)
		return
	root.add_child(instance)
	# 等若干帧让布局与首帧渲染稳定
	for _i in 8:
		await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	if image == null:
		printerr("SHOT_PROBE_FAIL no image from root viewport")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://output"))
	var err: int = image.save_png(OUT)
	if err != OK:
		printerr("SHOT_PROBE_FAIL save err=%d" % err)
		quit(1)
		return
	print("SHOT_PROBE_PASS path=%s size=%s" % [OUT, str(image.get_size())])
	quit(0)
