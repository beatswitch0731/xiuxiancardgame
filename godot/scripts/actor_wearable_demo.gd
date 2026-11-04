extends Control

const Registry = preload("res://scripts/runtime_data_registry.gd")
const Router = preload("res://scripts/combat_stage_router.gd")
const Stage = preload("res://scenes/duel_stage_hd2d.tscn")
const ACTOR = "res://assets/actor_wearable_v2/yelingyun_wearable_v2.glb"
const SWORD = "res://assets/actor_wearable_v2/traded_rusted_sword_v2.glb"
const SHEATH = "res://assets/actor_wearable_v2/residual_scabbard_v2.glb"

var stage: SubViewportContainer
var actor_root: Node3D
var skeleton: Skeleton3D
var animation_player: AnimationPlayer
var armor_parts: Array[MeshInstance3D] = []
var covered_cloth: Array[MeshInstance3D] = []
var sword: Node3D
var sheathed_sword: Node3D
var scabbard: Node3D
var weapon_socket: BoneAttachment3D
var armor_equipped := false
var sword_equipped := false
var idle_clip := "Idle"
var caption: Label
var armor_button: Button
var sword_button: Button
var pose_caption: Label
var turn_slider: HSlider
var speed_slider: HSlider
var pause_button: Button
var close_view := false
var camera_home: Transform3D


func _ready() -> void:
	var registry = Registry.new()
	var encounter: Dictionary = registry.get_first_encounter()
	var context: Dictionary = Router.new(registry).resolve_encounter(String(encounter["id"]))
	stage = Stage.instantiate()
	stage.use_trial_v17_candidate = true
	stage.bind_stage_context(context)
	add_child(stage)
	stage.get_actor_model("player").visible = false
	stage.get_actor_anchor("player").position = Vector3(-1.35, 0, 0.15)
	stage.get_actor_anchor("enemy").position = Vector3(2.0, 0, -0.25)
	actor_root = Node3D.new()
	actor_root.name = "YelingyunWearable"
	actor_root.rotation.y = deg_to_rad(96.81)
	actor_root.scale = Vector3.ONE * 1.50
	stage.get_actor_anchor("player").add_child(actor_root)
	var model: Node3D = load(ACTOR).instantiate()
	actor_root.add_child(model)
	skeleton = model.find_children("*", "Skeleton3D", true, false)[0]
	animation_player = model.find_children("*", "AnimationPlayer", true, false)[0]
	for node in model.find_children("*", "MeshInstance3D", true, false):
		if String(node.name).begins_with("Yelingyun_CoatCovered"):
			covered_cloth.append(node)
		if String(node.name).begins_with("Armor_"):
			armor_parts.append(node)
			node.visible = false
		for i in node.mesh.get_surface_count():
			var mat: Material = node.get_active_material(i)
			if mat is StandardMaterial3D:
				mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
				var fabric_colors := {"Indigo_weave":Color("384956"), "Linen_weave":Color("b5a88d"), "Leg_wrap_linen":Color("bdb199"), "Cloth_seam_indigo":Color("293540")}
				if fabric_colors.has(mat.resource_name):
					var fabric := ShaderMaterial.new()
					fabric.resource_name = mat.resource_name
					fabric.shader = load("res://shaders/actor_fabric_v3.gdshader")
					fabric.set_shader_parameter("fabric_albedo", load("res://assets/actor_wearable_v2/indigo_cloth_albedo_v3.png"))
					fabric.set_shader_parameter("dye", fabric_colors[mat.resource_name])
					node.set_surface_override_material(i, fabric)
	for clip_name in animation_player.get_animation_list():
		if "Idle" in clip_name or "Loop" in clip_name or clip_name in ["Walk", "Sword_Ready"]:
			animation_player.get_animation(clip_name).loop_mode = Animation.LOOP_LINEAR
	animation_player.animation_finished.connect(_on_animation_finished)
	print("WEARABLE_CLIPS ", animation_player.get_animation_list())
	_build_equipment()
	_build_controls()
	set_armor(false)
	set_sword(false)
	# Slightly closer review camera, same authored hall and lights.
	var camera: Camera3D = stage.get_node("Viewport/World/CameraRig/Camera")
	camera.fov = 36.0
	camera_home = camera.global_transform
	print("WEARABLE_DEMO_READY bones=", skeleton.get_bone_count(), " armor_parts=", armor_parts.size())


func _socket(name_: String, bone: String) -> BoneAttachment3D:
	var node := BoneAttachment3D.new()
	node.name = name_
	node.bone_name = bone
	skeleton.add_child(node)
	return node


func _build_equipment() -> void:
	weapon_socket = _socket("RightHandEquipment", "DEF-hand.R")
	sword = load(SWORD).instantiate()
	sword.name = "traded_rusted_sword"
	weapon_socket.add_child(sword)
	# Author the grip in native bind-pose space, then express it in the
	# hand's own rest frame. No per-animation wrist/sword compensation.
	var hand_rest := skeleton.get_bone_global_rest(skeleton.find_bone("DEF-hand.R"))
	var grip_world := Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(-0.827, 1.419, -0.066))
	sword.transform = hand_rest.affine_inverse() * grip_world
	var waist := _socket("LeftWaistEquipment", "DEF-hips")
	var hips_rest := skeleton.get_bone_global_rest(skeleton.find_bone("DEF-hips"))
	var sheath_world := Transform3D(Basis(Vector3.FORWARD, -0.22) * Basis(Vector3.RIGHT, PI + 0.30), Vector3(0.25, 1.00, -0.035))
	scabbard = load(SHEATH).instantiate()
	waist.add_child(scabbard)
	scabbard.transform = hips_rest.affine_inverse() * sheath_world
	sheathed_sword = load(SWORD).instantiate()
	waist.add_child(sheathed_sword)
	sheathed_sword.transform = scabbard.transform


func set_armor(enabled: bool) -> void:
	armor_equipped = enabled
	for part in armor_parts:
		part.visible = enabled
	for part in covered_cloth:
		part.visible = not enabled
	if armor_button:
		armor_button.text = "卸下玄铁甲" if enabled else "穿上玄铁甲"
	_refresh_caption()


func set_sword(enabled: bool) -> void:
	sword_equipped = enabled
	sword.visible = enabled
	sheathed_sword.visible = not enabled
	idle_clip = "Sword_Ready" if enabled else "Idle"
	if sword_button:
		sword_button.text = "收剑" if enabled else "持剑"
	play_motion(idle_clip)
	_refresh_caption()


func play_motion(clip: String) -> bool:
	if not animation_player.has_animation(clip):
		push_error("Missing native motion: " + clip)
		return false
	animation_player.play(clip, 0.18)
	if pose_caption:
		pose_caption.text = {"Idle":"自然站立", "Sword_Ready":"持剑戒备", "Sword_Attack":"挥剑 · 完整收势", "Crouch_Idle":"屈膝检查", "Walk":"步态检查"}.get(clip, clip)
	return true


func attack() -> void:
	if not sword_equipped:
		set_sword(true)
	play_motion("Sword_Attack")


func _on_animation_finished(_clip: StringName) -> void:
	play_motion(idle_clip)


func toggle_close_view() -> void:
	close_view = not close_view
	var camera: Camera3D = stage.get_node("Viewport/World/CameraRig/Camera")
	if close_view:
		var focus := actor_root.global_position + Vector3(0, 1.45, 0)
		camera.global_position = actor_root.global_position + Vector3(1.8, 2.5, 6.6)
		camera.look_at(focus)
	else:
		camera.global_transform = camera_home


func _refresh_caption() -> void:
	if caption:
		caption.text = "叶凌云  /  " + ("玄铁甲" if armor_equipped else "靛青旧衣") + "  /  " + ("集市易手残剑" if sword_equipped else "佩剑入鞘")


func _build_controls() -> void:
	var font := load("res://assets/fonts/NotoSansSC-VF.ttf")
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	margin.offset_top = -100
	margin.add_theme_constant_override("margin_left", 30)
	margin.add_theme_constant_override("margin_right", 30)
	margin.add_theme_constant_override("margin_bottom", 16)
	add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 9)
	margin.add_child(column)
	caption = Label.new()
	caption.add_theme_font_override("font", font)
	caption.add_theme_font_size_override("font_size", 16)
	caption.add_theme_color_override("font_color", Color("f1dfb7"))
	column.add_child(caption)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	column.add_child(row)
	armor_button = _button(row, "穿上玄铁甲", func(): set_armor(not armor_equipped))
	sword_button = _button(row, "持剑", func(): set_sword(not sword_equipped))
	_button(row, "挥剑", attack)
	_button(row, "站立", func(): play_motion(idle_clip))
	_button(row, "屈膝", func(): play_motion("Crouch_Idle"))
	_button(row, "步态", func(): play_motion("Walk"))
	_button(row, "近看", toggle_close_view)
	pause_button = _button(row, "暂停", func():
		if animation_player.is_playing():
			animation_player.pause()
			pause_button.text = "继续"
		else:
			animation_player.play()
			pause_button.text = "暂停")
	turn_slider = HSlider.new()
	turn_slider.name = "TurnSlider"
	turn_slider.min_value = -180
	turn_slider.max_value = 180
	turn_slider.value = rad_to_deg(actor_root.rotation.y)
	turn_slider.custom_minimum_size = Vector2(110, 28)
	turn_slider.tooltip_text = "转身查看正面、侧面与背面"
	turn_slider.value_changed.connect(func(value: float): actor_root.rotation.y = deg_to_rad(value))
	row.add_child(turn_slider)
	speed_slider = HSlider.new()
	speed_slider.name = "SpeedSlider"
	speed_slider.min_value = 0.2
	speed_slider.max_value = 1.0
	speed_slider.step = 0.1
	speed_slider.value = 1.0
	speed_slider.custom_minimum_size = Vector2(90, 28)
	speed_slider.tooltip_text = "动作速度：0.2 至 1 倍"
	speed_slider.value_changed.connect(func(value: float): animation_player.speed_scale = value)
	row.add_child(speed_slider)
	pose_caption = Label.new()
	pose_caption.add_theme_font_override("font", font)
	pose_caption.add_theme_font_size_override("font_size", 13)
	pose_caption.add_theme_color_override("font_color", Color("e5dcc8"))
	row.add_child(pose_caption)


func _button(row: HBoxContainer, text_: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text_
	button.custom_minimum_size = Vector2(66, 36)
	button.add_theme_font_override("font", load("res://assets/fonts/NotoSansSC-VF.ttf"))
	button.add_theme_font_size_override("font_size", 15)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.10, 0.115, 0.11, 0.89)
	style.border_color = Color("887b5c")
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	style.content_margin_left = 12
	style.content_margin_right = 12
	button.add_theme_stylebox_override("normal", style)
	var hovered := style.duplicate()
	hovered.bg_color = Color("3c443e")
	button.add_theme_stylebox_override("hover", hovered)
	button.pressed.connect(callback)
	row.add_child(button)
	return button
