class_name FxTemplate
extends RefCounted

## 特效模板构建器（VFX 方案批次 V1）。
## 按 6 类模板用代码构建节点树（不手写 .tscn，参数由配置驱动）。
## 每棵树：Node2D → SeqLayer(AnimatedSprite2D) + ParticleLayer(GPUParticles2D)。
##
## 层级纪律：L2 工具，输入输出都是数据与节点，禁止引用领域层。

const HIT_FLASH_SHADER := "res://shaders/fx_hit_flash.gdshader"
const DISSOLVE_SHADER := "res://shaders/fx_dissolve.gdshader"
const UV_STRETCH_SHADER := "res://shaders/fx_uv_stretch.gdshader"
const IMPACT_FRAME_SHADER := "res://shaders/fx_impact_frame.gdshader"

## 各模板的粒子配方（起步参数，美术评审后调 .tres 固化）。
## amount/lifetime/velocity/gravity 参考 VFX 方案 §3.3。
const PARTICLE_RECIPES := {
	"impact": {"amount": 16, "lifetime": 0.3, "vel_min": 400.0, "vel_max": 800.0,
		"gravity": 900.0, "one_shot": true, "explosiveness": 1.0},
	"travel": {"amount": 30, "lifetime": 0.5, "vel_min": 60.0, "vel_max": 120.0,
		"gravity": 0.0, "one_shot": true, "explosiveness": 0.9},
	"skill": {"amount": 20, "lifetime": 1.2, "vel_min": 40.0, "vel_max": 90.0,
		"gravity": -150.0, "one_shot": true, "explosiveness": 0.6},
	"hurt": {"amount": 8, "lifetime": 0.4, "vel_min": 120.0, "vel_max": 240.0,
		"gravity": 600.0, "one_shot": true, "explosiveness": 1.0},
	"defeat": {"amount": 40, "lifetime": 1.5, "vel_min": 20.0, "vel_max": 60.0,
		"gravity": -80.0, "one_shot": true, "explosiveness": 0.4},
	"state": {"amount": 16, "lifetime": 1.0, "vel_min": 30.0, "vel_max": 60.0,
		"gravity": 0.0, "one_shot": false, "explosiveness": 0.0},
}


## 构建一棵特效节点树。kind ∈ TEMPLATES，frame_paths 为语义条目的帧路径。
static func build(kind: String, frame_paths: Array, durations: Array) -> Node2D:
	var root := Node2D.new()
	root.name = "Fx_" + kind.capitalize()
	root.set_meta("fx_kind", kind)
	root.add_child(_build_seq_layer(kind, frame_paths, durations))
	if PARTICLE_RECIPES.has(kind):
		root.add_child(_build_particle_layer(kind))
	return root


## 序列帧层：不等时长 + 可选旋转（方向性由宿主在实例上设置 rotation）。
static func _build_seq_layer(kind: String, frame_paths: Array,
		durations: Array) -> AnimatedSprite2D:
	var sprite := AnimatedSprite2D.new()
	sprite.name = "SeqLayer"
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	frames.add_animation("play")
	frames.set_animation_speed("play", 60.0)   # 基准 60fps，实际节奏由每帧 duration 控制
	frames.set_animation_loop("play", kind == "state")
	var index := 0
	for path in frame_paths:
		var tex: Variant = load("res://content/" + String(path))
		if tex is Texture2D:
			var dur: float = durations[index] if index < durations.size() else 0.085
			frames.add_frame("play", tex, dur)
		index += 1
	sprite.sprite_frames = frames
	sprite.animation = "play"
	# 打击类默认加法混合，让 4 帧素材在深色战场上"发光"
	if kind in ["impact", "travel", "skill"]:
		var mat := CanvasItemMaterial.new()
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		sprite.material = mat
	# hurt 模板本体是闪白 shader（无帧素材依赖）
	if kind == "hurt":
		var shader: Variant = load(HIT_FLASH_SHADER)
		if shader is Shader:
			var sm := ShaderMaterial.new()
			sm.shader = shader
			sm.set_shader_parameter("flash_strength", 0.0)
			sprite.material = sm
	# defeat 模板挂溶解 shader：progress 由宿主 Tween 从 0 推到 1
	if kind == "defeat":
		var dshader: Variant = load(DISSOLVE_SHADER)
		if dshader is Shader:
			var sm := ShaderMaterial.new()
			sm.shader = dshader
			var noise := NoiseTexture2D.new()
			noise.noise = FastNoiseLite.new()
			sm.set_shader_parameter("noise_tex", noise)
			sm.set_shader_parameter("dissolve_progress", 0.0)
			sprite.material = sm
	return sprite


## 粒子层：按模板配方生成 GPUParticles2D（Forward+ 桌面端）。
static func _build_particle_layer(kind: String) -> GPUParticles2D:
	var recipe: Dictionary = PARTICLE_RECIPES[kind]
	var p := GPUParticles2D.new()
	p.name = "ParticleLayer"
	p.amount = int(recipe["amount"])
	p.lifetime = float(recipe["lifetime"])
	p.one_shot = bool(recipe["one_shot"])
	p.explosiveness = float(recipe["explosiveness"])
	p.emitting = false   # 由宿主在合适时机 restart()
	p.local_coords = false
	# visibility_rect 手工放大：默认矩形太小会导致"粒子消失"（VFX 方案 §3.3）
	p.visibility_rect = Rect2(-768, -768, 1536, 1536)
	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0, -1, 0)
	mat.spread = 45.0
	mat.initial_velocity_min = float(recipe["vel_min"])
	mat.initial_velocity_max = float(recipe["vel_max"])
	mat.gravity = Vector3(0, float(recipe["gravity"]), 0)
	mat.scale_min = 0.5
	mat.scale_max = 1.2
	mat.color = Color(1.0, 0.92, 0.72, 0.9)   # 暖白灵光基色，待元素色系统替换
	p.process_material = mat
	return p


## 方向性：旋转整棵特效树，并同步 UVStretch shader 的方向 uniform。
## angle_rad 为攻击方向（弧度），宿主按出手位置 → 目标位置计算。
static func set_direction(node: Node2D, angle_rad: float) -> void:
	node.rotation = angle_rad
	var seq := node.get_node_or_null("SeqLayer")
	if seq is AnimatedSprite2D and seq.material is ShaderMaterial:
		var sm: ShaderMaterial = seq.material
		if sm.shader != null and sm.shader.resource_path.ends_with("fx_uv_stretch.gdshader"):
			sm.set_shader_parameter("direction", angle_rad)


## 构建全屏打击帧层（Impact frame）：宿主 add_child 到舞台根，
## 重击命中时 visible=true + intensity 峰值，1~2 帧内衰减后隐藏。
static func build_impact_frame() -> ColorRect:
	var rect := ColorRect.new()
	rect.name = "ImpactFrame"
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader: Variant = load(IMPACT_FRAME_SHADER)
	if shader is Shader:
		var sm := ShaderMaterial.new()
		sm.shader = shader
		sm.set_shader_parameter("intensity", 0.0)
		sm.set_shader_parameter("invert", 1.0)
		rect.material = sm
	rect.visible = false
	return rect
