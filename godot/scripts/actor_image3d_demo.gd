extends Control

# An isolated visual proof that the generated actor is a skinned 3D mesh inside
# the existing spatial tutorial hall. Skin weights and combat poses remain QA.
const Registry = preload("res://scripts/runtime_data_registry.gd")
const Router = preload("res://scripts/combat_stage_router.gd")
const Stage = preload("res://scenes/duel_stage_hd2d.tscn")
const ACTOR = preload("res://assets/characters/actor_image3d_mvp/yelingyun_image3d_rig_candidate.glb")
const VisualEquipment = preload("res://scripts/actor_visual_equipment.gd")
const SkeletalActionModule = preload("res://scripts/actor_skeletal_action_module.gd")
const UAL_CANDIDATE: AnimationLibrary = preload(
	"res://assets/characters/actor_image3d_mvp/yelingyun_ual_retarg_candidate.tres")

@export var use_ual_candidate := false

var stage: SubViewportContainer
var actor_root: Node3D
var visual_equipment: Node3D
var equipment_caption: Label
var actor_skeleton: Skeleton3D
var action_module: Node


func _ready() -> void:
	var data = Registry.new()
	var first: Dictionary = data.get_first_encounter()
	if first.is_empty():
		push_error("Image3D demo: first encounter source unavailable")
		return
	var context: Dictionary = Router.new(data).resolve_encounter(String(first["id"]))
	stage = Stage.instantiate()
	stage.use_trial_v17_candidate = true
	if not stage.bind_stage_context(context):
		push_error("Image3D demo: tutorial stage context invalid")
		return
	add_child(stage)
	if use_ual_candidate:
		# The authored lunge travels about one actor width. Review it at sword
		# range in this isolated scene; the production stage homes are untouched.
		stage.get_actor_anchor("player").position.x = -1.2
		stage.get_actor_anchor("enemy").position.x = 1.2
	var baked_actor: Node3D = stage.get_actor_model("player")
	if baked_actor == null:
		push_error("Image3D demo: existing player anchor unavailable")
		return
	baked_actor.visible = false
	actor_root = Node3D.new()
	actor_root.name = "YeLingyunGeneratedMeshCandidate"
	stage.get_actor_anchor("player").add_child(actor_root)
	# The generated sculpt faces +Z. Rotate it toward the enemy on screen +X
	# while retaining enough front plane for the hand, silhouette and robe.
	actor_root.rotation.y = 2.05 if use_ual_candidate else 1.05
	var model: Node3D = ACTOR.instantiate()
	model.name = "HunyuanMultiviewMesh"
	actor_root.add_child(model)
	for child in model.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance: MeshInstance3D = child as MeshInstance3D
		var vertex_material := StandardMaterial3D.new()
		vertex_material.vertex_color_use_as_albedo = true
		vertex_material.roughness = 0.88
		vertex_material.metallic = 0.0
		mesh_instance.material_override = vertex_material
	var skeletons := model.find_children("*", "Skeleton3D", true, false)
	if skeletons.size() != 1:
		push_error("Image3D demo: expected one shared Skeleton3D")
		return
	var skeleton: Skeleton3D = skeletons[0] as Skeleton3D
	actor_skeleton = skeleton
	print("IMAGE3D_SKELETON bones=", skeleton.get_bone_count(),
		" hand_L=", skeleton.find_bone("hand_L"))
	visual_equipment = VisualEquipment.new()
	visual_equipment.name = "VisualEquipment"
	actor_root.add_child(visual_equipment)
	visual_equipment.bind_skeleton(skeleton)
	if use_ual_candidate:
		visual_equipment.preferred_weapon_bone = "hand_R"
	action_module = SkeletalActionModule.new()
	action_module.name = "SkeletalActionModule"
	actor_root.add_child(action_module)
	var bound: bool = action_module.bind_skeleton(skeleton, UAL_CANDIDATE) \
		if use_ual_candidate else action_module.bind_skeleton(skeleton)
	if not bound:
		push_error("Image3D demo: skeletal action module could not bind")
		return
	if use_ual_candidate:
		action_module.set_contact_gate(_can_confirm_sword_contact)
	action_module.action_contact.connect(_on_action_contact)
	# Hunyuan exports a centred two-unit-tall figure. Its local minimum is -1.
	model.scale = Vector3.ONE * 1.40
	model.position.y = 1.40
	_add_caption()
	_add_equipment_controls()
	print("IMAGE3D_GODOT_DEMO_READY actor=Yelingyun stage=first_fight mesh=real_3d")


func _add_caption() -> void:
	var caption := Label.new()
	caption.name = "CandidateCaption"
	caption.text = "叶凌云 · 武器与动作技术样机（人物美术待重建）"
	caption.add_theme_font_override("font", load("res://assets/fonts/NotoSansSC-VF.ttf"))
	caption.add_theme_font_size_override("font_size", 16)
	caption.add_theme_color_override("font_color", Color(0.92, 0.88, 0.76))
	caption.position = Vector2(28, 24)
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(caption)


func set_weapon_equipped(enabled: bool) -> bool:
	var definition_id := "traded_rusted_sword" if enabled else ""
	var success: bool = visual_equipment.set_equipped("weapon", definition_id)
	if success and equipment_caption != null:
		equipment_caption.text = "持剑：集市易手残剑" if enabled else "持剑：空"
	return success


func play_action(action_name: String) -> bool:
	if action_module == null:
		return false
	return action_module.play_action(action_name)


func _on_action_contact(_action_name: String) -> void:
	if equipment_caption != null:
		equipment_caption.text = "剑势接触关键时点"


func _can_confirm_sword_contact() -> bool:
	var tip: Marker3D = visual_equipment.get_weapon_tip_marker()
	var enemy: Node3D = stage.get_actor_model("enemy")
	if tip == null or enemy == null or not enemy.has_method("get_chest_hit"):
		return false
	return tip.global_position.distance_to(enemy.get_chest_hit().global_position) <= 0.22


func _add_equipment_controls() -> void:
	var row := HBoxContainer.new()
	row.position = Vector2(28, 742)
	row.add_theme_constant_override("separation", 9)
	add_child(row)
	for label in ["卸下", "装备残剑"]:
		var button := Button.new()
		button.text = label
		button.add_theme_font_override("font", load("res://assets/fonts/NotoSansSC-VF.ttf"))
		button.add_theme_font_size_override("font_size", 16)
		button.custom_minimum_size = Vector2(92, 34)
		button.pressed.connect(set_weapon_equipped.bind(label == "装备残剑"))
		row.add_child(button)
	var attack_button := Button.new()
	attack_button.name = "AttackButton"
	attack_button.text = "试挥剑（接触测试）" if use_ual_candidate else "试挥剑（无命中）"
	attack_button.add_theme_font_override("font", load("res://assets/fonts/NotoSansSC-VF.ttf"))
	attack_button.add_theme_font_size_override("font_size", 16)
	attack_button.custom_minimum_size = Vector2(92, 34)
	attack_button.pressed.connect(play_action.bind("sword_attack"))
	row.add_child(attack_button)
	equipment_caption = Label.new()
	equipment_caption.text = "持剑：空"
	equipment_caption.add_theme_font_override("font", load("res://assets/fonts/NotoSansSC-VF.ttf"))
	equipment_caption.add_theme_font_size_override("font_size", 16)
	equipment_caption.add_theme_color_override("font_color", Color(0.92, 0.88, 0.76))
	row.add_child(equipment_caption)
