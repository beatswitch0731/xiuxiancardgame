extends Node2D

# A visual-only cutout study. Equipment never enters CombatDomain from here.
const BODY_IDLE: Texture2D = preload("res://assets/characters/modular_pixel_actor_v1/yelingyun_idle_mist_blue_candidate.png")
const BODY_THRUST: Texture2D = preload("res://assets/characters/modular_pixel_actor_v1/yelingyun_thrust_mist_blue_candidate.png")
const PRACTICE_SWORD: Texture2D = preload("res://assets/characters/modular_pixel_actor_v1/practice_sword.png")
const RUSTED_SWORD: Texture2D = preload("res://assets/characters/modular_pixel_actor_v1/rusted_broken_sword.png")
const DARK_IRON_CUIRASS: Texture2D = preload("res://assets/characters/modular_pixel_actor_v1/dark_iron_cuirass.png")
const DARK_IRON_BRACER: Texture2D = preload("res://assets/characters/modular_pixel_actor_v1/dark_iron_bracer.png")

const BODY_SCALE := 0.0625
const WEAPON_SCALE := 0.035
const BODY_ORIGIN := Vector2(627, 1200)
const GRIP_POINT := Vector2(305, 360)
const IDLE_HAND := Vector2(845, 676)
const THRUST_HAND := Vector2(995, 446)

var body: Sprite2D
var weapon_pivot: Node2D
var weapon: Sprite2D
var armor_torso: Sprite2D
var armor_bracer: Sprite2D
var variant := "practice_sword"
var armor_id := ""
var pose := "idle"


func _ready() -> void:
	name = "ModularActor"
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	weapon_pivot = Node2D.new()
	weapon_pivot.name = "WeaponPivot"
	# Sibling draw order keeps the grip under the body while both stay above the room.
	add_child(weapon_pivot)
	weapon = Sprite2D.new()
	weapon.name = "Weapon"
	weapon.centered = false
	weapon.scale = Vector2.ONE * WEAPON_SCALE
	weapon.position = -GRIP_POINT * WEAPON_SCALE
	weapon_pivot.add_child(weapon)
	body = Sprite2D.new()
	body.name = "Body"
	body.centered = false
	body.scale = Vector2.ONE * BODY_SCALE
	body.position = -BODY_ORIGIN * BODY_SCALE
	add_child(body)
	armor_torso = Sprite2D.new()
	armor_torso.name = "ArmorTorso"
	armor_torso.texture = DARK_IRON_CUIRASS
	armor_torso.visible = false
	add_child(armor_torso)
	armor_bracer = Sprite2D.new()
	armor_bracer.name = "ArmorBracer"
	armor_bracer.texture = DARK_IRON_BRACER
	armor_bracer.visible = false
	add_child(armor_bracer)
	set_variant(variant)
	set_pose("idle")


func set_variant(value: String) -> bool:
	if not value in ["unarmed", "practice_sword", "traded_rusted_sword"]:
		return false
	variant = value
	weapon.texture = PRACTICE_SWORD if value == "practice_sword" else RUSTED_SWORD if value == "traded_rusted_sword" else null
	weapon.visible = value != "unarmed"
	weapon.modulate = Color(1.18, 0.88, 0.69) if value == "traded_rusted_sword" else Color(1.35, 1.35, 1.45)
	return true


func set_armor(value: String) -> bool:
	if not value in ["", "玄铁甲"]:
		return false
	armor_id = value
	armor_torso.visible = value == "玄铁甲"
	armor_bracer.visible = value == "玄铁甲"
	return true


func set_pose(value: String) -> void:
	pose = value
	var thrust := value in ["attack", "sword_probe", "sword_followthrough", "sword_edge"]
	var pose_origin := Vector2(627, 1160) if thrust else BODY_ORIGIN
	body.texture = BODY_THRUST if thrust else BODY_IDLE
	body.position = -pose_origin * BODY_SCALE
	var hand: Vector2 = THRUST_HAND if thrust else IDLE_HAND
	weapon_pivot.position = (hand - pose_origin) * BODY_SCALE
	weapon_pivot.rotation_degrees = -5.0 if thrust else -66.0 if value == "guard" else 37.0
	armor_torso.position = ((Vector2(660, 520) if thrust else Vector2(650, 570)) - pose_origin) * BODY_SCALE
	armor_torso.scale = Vector2(0.028, 0.032) if thrust else Vector2(0.034, 0.033)
	armor_torso.rotation_degrees = -6.0 if thrust else 0.0
	armor_bracer.position = ((Vector2(885, 446) if thrust else Vector2(825, 630)) - pose_origin) * BODY_SCALE
	armor_bracer.scale = Vector2.ONE * 0.017
	armor_bracer.rotation_degrees = -42.0 if thrust else 0.0
	body.modulate = Color(1.0, 0.66, 0.60) if value == "hurt" else Color.WHITE
	rotation_degrees = 70.0 if value == "defeat" else 0.0
