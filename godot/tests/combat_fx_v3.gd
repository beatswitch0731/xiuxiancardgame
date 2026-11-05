extends SceneTree

## VFX 批次 V3 验收测试。
## 覆盖：四个 shader 可加载 / defeat 挂 Dissolve（含噪声）/ 方向性设置 /
##       Impact frame 构建 / main.gd 接线存在性（hitstop 节点 + 分级函数）。
## 运行：--headless --script res://tests/combat_fx_v3.gd

const FxLib = preload("res://scripts/combat_fx/fx_library.gd")
const FxTpl = preload("res://scripts/combat_fx/fx_template.gd")

const SHADERS := ["res://shaders/fx_hit_flash.gdshader",
	"res://shaders/fx_dissolve.gdshader", "res://shaders/fx_radial_blur.gdshader",
	"res://shaders/fx_uv_stretch.gdshader", "res://shaders/fx_impact_frame.gdshader"]

var _fails: Array[String] = []


func _initialize() -> void:
	_check_shaders()
	_check_dissolve_on_defeat()
	_check_direction()
	_check_impact_frame()
	await _check_main_wiring()
	if _fails.is_empty():
		print("COMBAT_FX_V3_PASS")
		quit(0)
		return
	for f in _fails:
		printerr("COMBAT_FX_V3_FAIL " + f)
	quit(1)


func _check(message: String, condition: bool) -> void:
	if not condition:
		_fails.append(message)


func _check_shaders() -> void:
	for path in SHADERS:
		var shader: Variant = load(path)
		_check("shader 无法加载: " + path, shader is Shader)


func _check_dissolve_on_defeat() -> void:
	var lib := FxLib.new()
	var defeat_id := ""
	for id in lib.all_ids():
		if lib.route_key(String(id)) == "defeat":
			defeat_id = String(id)
			break
	_check("找不到 defeat 路由样例", defeat_id != "")
	if defeat_id == "":
		return
	var node := FxTpl.build("defeat", lib.frame_paths(defeat_id),
		lib.frame_durations(defeat_id))
	var seq := node.get_node_or_null("SeqLayer") as AnimatedSprite2D
	_check("defeat 的 SeqLayer 应挂 ShaderMaterial(溶解)",
		seq != null and seq.material is ShaderMaterial)
	if seq != null and seq.material is ShaderMaterial:
		var sm: ShaderMaterial = seq.material
		var noise: Variant = sm.get_shader_parameter("noise_tex")
		_check("溶解材质应带 NoiseTexture2D", noise is NoiseTexture2D)
		var progress: Variant = sm.get_shader_parameter("dissolve_progress")
		_check("溶解 progress 初始应为 0.0", float(progress) == 0.0)
	node.free()


func _check_direction() -> void:
	var node := Node2D.new()
	node.add_child(AnimatedSprite2D.new())
	node.get_child(0).name = "SeqLayer"
	FxTpl.set_direction(node, -0.6)
	_check("set_direction 应设置 rotation",
		absf(node.rotation - (-0.6)) < 0.001)
	# UVStretch 方向同步：构造一个挂 UVStretch 的实例再调一次
	var sm := ShaderMaterial.new()
	sm.shader = load("res://shaders/fx_uv_stretch.gdshader")
	var seq := AnimatedSprite2D.new()
	seq.name = "SeqLayer"          # 必须命名：set_direction 按 "SeqLayer" 查找
	seq.material = sm
	node.get_child(0).free()
	node.add_child(seq)
	FxTpl.set_direction(node, 1.2)
	var got: Variant = sm.get_shader_parameter("direction")
	_check("UVStretch direction 应同步为 1.2",
		got is float and absf(got - 1.2) < 0.001)
	node.free()


func _check_impact_frame() -> void:
	var rect := FxTpl.build_impact_frame()
	_check("ImpactFrame 应为 ColorRect", rect is ColorRect)
	_check("ImpactFrame 默认不可见", rect.visible == false)
	_check("ImpactFrame 不应拦截鼠标",
		rect.mouse_filter == Control.MOUSE_FILTER_IGNORE)
	_check("ImpactFrame 应挂 ShaderMaterial", rect.material is ShaderMaterial)
	rect.free()


func _check_main_wiring() -> void:
	# main.gd 的接线（静态检查：源码含关键接线点）
	var src := FileAccess.get_file_as_string("res://scripts/main.gd")
	_check("main.gd 缺 HitStopController 挂载", src.contains("HitStopController.new()"))
	_check("main.gd 缺 contact 帧触发", src.contains("hitstop.trigger("))
	_check("main.gd 缺伤害分级函数", src.contains("func _damage_tier"))
	_check("main.gd 分级函数应处理 crit 档", src.contains('"crit"'))
	await process_frame
