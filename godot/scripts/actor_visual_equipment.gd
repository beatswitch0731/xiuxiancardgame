extends Node3D

# Isolated visual adapter: definitionId -> rig socket.
const VISUALS := {
	"traded_rusted_sword": {
		"slot": "weapon",
		"bone": "hand_L",
		"scene": "res://assets/actor_image3d_mvp/traded_rusted_sword_model_candidate.glb",
	},
}

var _skeleton: Skeleton3D
var _attachments: Dictionary = {}
var _items: Dictionary = {}
var preferred_weapon_bone := "hand_L"


func bind_skeleton(skeleton: Skeleton3D) -> void:
	_skeleton = skeleton
	# This node must outlive individual equipped items: an AnimationLibrary can
	# then animate the grip through the same stable path for every sword model.
	_ensure_socket("weapon", preferred_weapon_bone)


func set_equipped(slot: String, definition_id: String) -> bool:
	if _skeleton == null:
		return false
	var entry: Dictionary = {} if definition_id.is_empty() else VISUALS.get(definition_id, {})
	if not definition_id.is_empty() and (entry.is_empty() or entry.get("slot") != slot):
		return false
	var bone_name := preferred_weapon_bone if slot == "weapon" else String(entry.get("bone", ""))
	if _skeleton.find_bone(bone_name) < 0:
		return false
	var attachment := _ensure_socket(slot, bone_name)
	if attachment == null:
		return false
	attachment.bone_name = bone_name
	if _items.has(slot):
		(_items[slot] as Node).queue_free()
		_items.erase(slot)
	if definition_id.is_empty():
		return true
	var resource: Resource = load(String(entry["scene"]))
	if not resource is PackedScene:
		return false
	var item: Node3D = (resource as PackedScene).instantiate()
	item.name = definition_id
	attachment.get_node("GripPivot").add_child(item)
	# Grip origin in the item scene is centred on the palm. This offset is a
	# per-rig diagnostic and will be refined after pose/hand penetration QA.
	item.position = Vector3(0, 0, 0)
	if bone_name == "hand_R":
		# The blade points along item -Y. On this rig the right-hand bind basis
		# faces backward; the opposite quarter-turn keeps the edge ahead of the
		# grip in neutral and during the forward stroke.
		item.rotation.z = -PI * 0.5
	else:
		item.rotation.x = PI
		item.rotation.z = -0.30
	if slot == "weapon":
		var tip := Marker3D.new()
		tip.name = "BladeTip"
		# Sword mesh source has its point at Blender Z=-0.94; glTF maps to -Y.
		tip.position = Vector3(0, -0.94, 0)
		item.add_child(tip)
	_items[slot] = item
	return true


func current_visual(slot: String) -> String:
	if not _items.has(slot):
		return ""
	return String((_items[slot] as Node).name)


func get_weapon_tip_marker() -> Marker3D:
	if not _items.has("weapon"):
		return null
	return (_items["weapon"] as Node3D).get_node_or_null("BladeTip") as Marker3D


func _ensure_socket(slot: String, bone_name: String) -> BoneAttachment3D:
	if _attachments.has(slot):
		return _attachments[slot]
	if _skeleton == null or _skeleton.find_bone(bone_name) < 0:
		return null
	var attachment := BoneAttachment3D.new()
	attachment.name = "Equipment_" + slot
	attachment.bone_name = bone_name
	_skeleton.add_child(attachment)
	var pivot := Node3D.new()
	pivot.name = "GripPivot"
	attachment.add_child(pivot)
	_attachments[slot] = attachment
	return attachment
