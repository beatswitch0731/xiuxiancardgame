extends Node3D

# Visual-only keypose study. The existing HD-2D fighter keeps the action clock.
const IDLE: Texture2D = preload("res://assets/modular_pixel_actor_v1/yelingyun_idle_mist_blue_candidate.png")
const ANTICIPATION: Texture2D = preload("res://assets/actor_motion_lab_v1/yelingyun_anticipation_candidate.png")
const THRUST: Texture2D = preload("res://assets/modular_pixel_actor_v1/yelingyun_thrust_mist_blue_candidate.png")
const S2_IDLE: Texture2D = preload("res://assets/actor_motion_lab_v1/yelingyun_s2_idle_candidate_v3.png")
const S2_ANTICIPATION: Texture2D = preload("res://assets/actor_motion_lab_v1/yelingyun_s2_anticipation_candidate_v3.png")
const S2_THRUST: Texture2D = preload("res://assets/actor_motion_lab_v1/yelingyun_s2_thrust_candidate_v3.png")
const S2_ARMOR_IDLE: Texture2D = preload("res://assets/actor_motion_lab_v1/yelingyun_s2_xuantiejia_idle_candidate.png")
const S2_ARMOR_ANTICIPATION: Texture2D = preload("res://assets/actor_motion_lab_v1/yelingyun_s2_xuantiejia_anticipation_candidate.png")
const S2_ARMOR_THRUST: Texture2D = preload("res://assets/actor_motion_lab_v1/yelingyun_s2_xuantiejia_thrust_candidate.png")
const PRACTICE_SWORD: Texture2D = preload("res://assets/modular_pixel_actor_v1/practice_sword.png")
const RUSTED_SWORD: Texture2D = preload("res://assets/modular_pixel_actor_v1/rusted_broken_sword.png")
const LINGQUAN_HULU: Texture2D = preload("res://assets/actor_motion_lab_v1/lingquan_hulu_prop_candidate.png")
const QINGYUN_SWORD_CASE: Texture2D = preload("res://assets/actor_motion_lab_v1/qingyun_sword_case_prop_candidate_v2.png")

const BODY_PIXEL_SIZE := 0.0023
const WEAPON_PIXEL_SIZE := BODY_PIXEL_SIZE * 0.36
const BODY_CENTER := Vector2(627, 627)
const WEAPON_CENTER := Vector2(1086, 362)
const GRIP := Vector2(305, 360)

var body: Sprite3D
var weapon_pivot: Node3D
var weapon: Sprite3D
var gourd: Sprite3D
var sword_case: Sprite3D
var realm_stage := "qi"
var armor_id := ""
var accessory_id := ""
var artifact_id := ""
var pose := "idle"


func _ready() -> void:
	name = "ModularActorHD2D"
	weapon_pivot = Node3D.new()
	weapon_pivot.name = "WeaponPivot"
	add_child(weapon_pivot)
	weapon = _sprite("Weapon", WEAPON_PIXEL_SIZE)
	weapon.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	weapon.position = Vector3((WEAPON_CENTER.x - GRIP.x) * WEAPON_PIXEL_SIZE,
		(GRIP.y - WEAPON_CENTER.y) * WEAPON_PIXEL_SIZE, -0.03)
	weapon_pivot.add_child(weapon)
	sword_case = _sprite("QingyunSwordCase", BODY_PIXEL_SIZE * 0.44)
	sword_case.texture = QINGYUN_SWORD_CASE
	sword_case.visible = false
	add_child(sword_case)
	body = _sprite("Body", BODY_PIXEL_SIZE)
	add_child(body)
	gourd = _sprite("LingquanHulu", BODY_PIXEL_SIZE * 0.15)
	gourd.texture = LINGQUAN_HULU
	gourd.visible = false
	add_child(gourd)
	set_variant("practice_sword")
	set_pose("idle")


func _sprite(sprite_name: String, pixel_size: float) -> Sprite3D:
	var sprite := Sprite3D.new()
	sprite.name = sprite_name
	sprite.pixel_size = pixel_size
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.shaded = true
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_OPAQUE_PREPASS
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	return sprite


func set_variant(value: String) -> void:
	weapon.visible = value != "unarmed"
	weapon.texture = RUSTED_SWORD if value == "traded_rusted_sword" else PRACTICE_SWORD


func set_realm_stage(value: String) -> bool:
	if value not in ["qi", "foundation"]:
		return false
	realm_stage = value
	if realm_stage != "foundation":
		armor_id = ""
		artifact_id = ""
		sword_case.visible = false
	set_pose(pose)
	return true


func set_armor(value: String) -> bool:
	if value not in ["", "玄铁甲"] or value == "玄铁甲" and realm_stage != "foundation":
		return false
	armor_id = value
	set_pose(pose)
	return true


func set_accessory(value: String) -> bool:
	if value not in ["", "灵泉葫芦"]:
		return false
	accessory_id = value
	gourd.visible = value == "灵泉葫芦"
	return true


func set_artifact(value: String) -> bool:
	if value not in ["", "青云剑匣"] or value == "青云剑匣" and realm_stage != "foundation":
		return false
	artifact_id = value
	sword_case.visible = value == "青云剑匣"
	return true


func set_pose(value: String) -> void:
	pose = value
	var origin := Vector2(627, 1160) if value == "thrust" else Vector2(627, 1254) if value == "anticipation" else Vector2(627, 1200)
	var hand := Vector2(995, 446) if value == "thrust" else Vector2(525, 560) if value == "anticipation" else Vector2(845, 676)
	if realm_stage == "foundation" and armor_id == "玄铁甲":
		body.texture = S2_ARMOR_THRUST if value == "thrust" else S2_ARMOR_ANTICIPATION if value == "anticipation" else S2_ARMOR_IDLE
	elif realm_stage == "foundation":
		body.texture = S2_THRUST if value == "thrust" else S2_ANTICIPATION if value == "anticipation" else S2_IDLE
	else:
		body.texture = THRUST if value == "thrust" else ANTICIPATION if value == "anticipation" else IDLE
	body.position = Vector3((BODY_CENTER.x - origin.x) * BODY_PIXEL_SIZE,
		(origin.y - BODY_CENTER.y) * BODY_PIXEL_SIZE, 0.0)
	weapon_pivot.position = Vector3((hand.x - origin.x) * BODY_PIXEL_SIZE,
		(origin.y - hand.y) * BODY_PIXEL_SIZE, 0.0)
	var waist := Vector2(470, 700) if value == "thrust" else Vector2(440, 695) if value == "anticipation" else Vector2(525, 690)
	gourd.position = Vector3((waist.x - origin.x) * BODY_PIXEL_SIZE,
		(origin.y - waist.y) * BODY_PIXEL_SIZE, 0.035)
	var back := Vector2(450, 550) if value == "thrust" else Vector2(420, 570) if value == "anticipation" else Vector2(405, 550)
	sword_case.position = Vector3((back.x - origin.x) * BODY_PIXEL_SIZE,
		(origin.y - back.y) * BODY_PIXEL_SIZE, -0.055)
	weapon_pivot.rotation.z = deg_to_rad(-(-5.0 if value == "thrust" else 145.0 if value == "anticipation" else -66.0 if value == "guard" else 37.0))
	body.modulate = Color(1.0, 0.63, 0.58) if value == "hurt" else Color.WHITE


func seek_attack(progress: float, contact_ratio: float = 0.47) -> void:
	var p := clampf(progress, 0.0, 1.0)
	if p < 0.10 or p >= 0.86:
		set_pose("idle")
	elif p < contact_ratio - 0.08 or p >= contact_ratio + 0.17:
		set_pose("anticipation")
	else:
		set_pose("thrust")
