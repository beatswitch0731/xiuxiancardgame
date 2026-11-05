extends SceneTree

## VFX 批次 V1 验收测试。
## 覆盖：FxLibrary 路由全覆盖 / 模板节点树构建 / HitStop 分级与恢复 /
##       HitFlash shader 可加载。
## 运行：--headless --script res://tests/combat_fx_v1.gd

const FxLib = preload("res://scripts/combat_fx/fx_library.gd")
const FxTpl = preload("res://scripts/combat_fx/fx_template.gd")
const HitStop = preload("res://scripts/combat_fx/hitstop_controller.gd")

var _fails: Array[String] = []


func _initialize() -> void:
	var lib := FxLib.new()
	_check_library(lib)
	_check_templates(lib)
	await _check_hitstop()
	_check_shader()
	if _fails.is_empty():
		print("COMBAT_FX_V1_PASS")
		quit(0)
		return
	for f in _fails:
		printerr("COMBAT_FX_V1_FAIL " + f)
	quit(1)


func _check(message: String, condition: bool) -> void:
	if not condition:
		_fails.append(message)


func _check_library(lib: FxLib) -> void:
	_check("FxLibrary 加载错误: " + lib.last_error(), lib.last_error().is_empty())
	_check("semanticVfx 条目数应为 166，实际 %d" % lib.entry_count(),
		lib.entry_count() == 166)
	for id in lib.all_ids():
		var key := lib.route_key(String(id))
		if not key in ["impact", "travel", "skill", "hurt", "defeat", "state"]:
			_fails.append("路由越界: %s -> %s" % [id, key])
			break
		var durs := lib.frame_durations(String(id))
		if durs.size() != lib.frame_paths(String(id)).size():
			_fails.append("时长数组与帧数不一致: " + String(id))
			break
	var total := 0.0
	for d in lib.frame_durations(lib.all_ids()[0]):
		total += float(d)
	var expect := 0.001 * float(lib.duration_ms(String(lib.all_ids()[0])))
	_check("时长权重总和应等于 durationMs/1000", absf(total - expect) < 0.02)


func _check_templates(lib: FxLib) -> void:
	# 每种路由至少抽样一条构建，验证节点树契约。
	var seen := {}
	for id in lib.all_ids():
		var key := lib.route_key(String(id))
		if seen.has(key):
			continue
		seen[key] = true
		var node := FxTpl.build(key, lib.frame_paths(String(id)),
			lib.frame_durations(String(id)))
		if node == null:
			_fails.append("模板构建为空: " + String(id))
			continue
		var seq := node.get_node_or_null("SeqLayer")
		_check("%s 缺 SeqLayer" % key, seq != null and seq is AnimatedSprite2D)
		var part := node.get_node_or_null("ParticleLayer")
		_check("%s 缺 ParticleLayer" % key,
			part != null and part is GPUParticles2D)
		if seq is AnimatedSprite2D and seq.sprite_frames != null:
			var want: int = lib.frame_paths(String(id)).size()
			_check("%s SpriteFrames 帧数 %d != %d" % [key,
				seq.sprite_frames.get_frame_count("play"), want],
				seq.sprite_frames.get_frame_count("play") == want)
		if key == "hurt":
			_check("hurt 模板应有 ShaderMaterial(闪白)",
				seq.material is ShaderMaterial)
		elif seq.material is CanvasItemMaterial:
			_check("打击类应使用加法混合",
				seq.material.blend_mode == CanvasItemMaterial.BLEND_MODE_ADD)
		node.free()


func _check_hitstop() -> void:
	var hs: Node = HitStop.new()
	root.add_child(hs)
	_check("分级映射: heavy=8帧", HitStop.tier_frames("heavy") == 8)
	_check("分级映射: crit=12帧", HitStop.tier_frames("crit") == 12)
	_check("分级映射: light=3帧", HitStop.tier_frames("light") == 3)
	hs.trigger("heavy")
	_check("触发后 time_scale 被压低",
		Engine.time_scale < 1.0 and hs.is_active())
	for _i in 12:
		await process_frame
	_check("停顿帧数走完后恢复 time_scale=1.0",
		Engine.time_scale == 1.0 and not hs.is_active())
	hs.trigger("light")
	hs.cancel()
	_check("cancel 立即恢复", Engine.time_scale == 1.0)
	hs.queue_free()


func _check_shader() -> void:
	var shader: Variant = load("res://shaders/fx_hit_flash.gdshader")
	_check("fx_hit_flash.gdshader 无法加载", shader is Shader)
