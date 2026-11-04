extends Node2D
## Isolated rigid-cutout study. Contact is a presentation marker, never damage.
## All skins use the same Bone2D rest hierarchy and shared AnimationLibrary.

signal study_contact(action: StringName)

const DEFAULT_MANIFEST := "res://assets/undercurrent_pixel_v1/paperdoll_v1/paperdoll_manifest.json"
const SHARED_ACTIONS := "res://assets/undercurrent_pixel_v1/paperdoll_v1/shared_actions.tres"
const BODY_PARTS := ["head", "torso", "pelvis", "upper_arm_l", "forearm_l", "upper_arm_r", "forearm_r", "thigh_l", "shin_l", "thigh_r", "shin_r"]
const OPTIONAL_PARTS := ["ponytail", "grip_overlay"]
const ACTIONS := ["idle", "thrust", "hurt"]
# The normalized 18px shin image has its knee at y4, ankle at y12,
# narrow cuff at y11-12 and expanding shoe at y13-17. Regions overlap.
const THIGH_LENGTH := 14.0
const SHIN_LENGTH := 8.0
const ANKLE_HEIGHT := 6.0
const BOOT_REGION_Y := 11.0
const SHIN_REGION_HEIGHT := 14.0
const FRONT_Z := {"ponytail": -5, "upper_arm_l": -4, "forearm_l": -4, "thigh_l": -2, "shin_l": -2, "thigh_r": -2, "shin_r": -2, "head": 1, "upper_arm_r": 2, "forearm_r": 2, "weapon": 3, "grip_overlay": 4, "accessory": 1}
const BACK_Z := {"ponytail": 3, "upper_arm_l": 2, "forearm_l": 2, "thigh_l": -2, "shin_l": -2, "thigh_r": -2, "shin_r": -2, "head": 1, "upper_arm_r": -4, "forearm_r": -4, "weapon": -3, "grip_overlay": -2, "accessory": 1}

var _manifest: Dictionary = {}
var _bones: Dictionary = {}
var _rest_positions: Dictionary = {}
var _sprites: Dictionary = {}
var _bindings: Dictionary = {}
var _art_transforms: Dictionary = {}
var _draw_orders: Dictionary = {}
var _visual: Node2D
var _sockets: Dictionary = {}
var _texture_cache: Dictionary = {}
var _player: AnimationPlayer
var _outfit := "base"
var _weapon := "traded_rusted_sword"
var _accessory := "灵泉葫芦"
var _view := "front"
var _action := "idle"
var _configured := false
var _contact_sent := false
var _contact_count := 0
var _contact_pending := false

func configure(manifest_path: String = DEFAULT_MANIFEST) -> bool:
	if _configured:
		return false
	var document: Variant = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
	if not document is Dictionary or document.get("schemaVersion", 0) != 1:
		return false
	var library: AnimationLibrary = load(SHARED_ACTIONS)
	if library == null:
		return false
	_manifest = document
	var prepared: Dictionary = _prepare_loadout(_outfit, _weapon, _accessory, _view)
	if prepared.is_empty():
		return false
	_build_rig()
	_player = AnimationPlayer.new()
	_player.name = "AnimationPlayer"
	_player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	_player.callback_mode_method = AnimationMixer.ANIMATION_CALLBACK_MODE_METHOD_IMMEDIATE
	add_child(_player)
	_player.add_animation_library("", library)
	_apply_loadout(prepared)
	_configured = true
	play_action("idle")
	return true

func _build_rig() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_visual = Node2D.new()
	_visual.name = "Visual"
	_visual.y_sort_enabled = false
	add_child(_visual)
	var skeleton := Skeleton2D.new()
	skeleton.name = "Skeleton2D"
	add_child(skeleton)
	_bone(skeleton, "pelvis", Vector2(0, -28), 9)
	_bone(_bones.pelvis, "torso", Vector2(0, -9), 19)
	_bone(_bones.torso, "head", Vector2(0, -19), 10)
	_bone(_bones.head, "ponytail", Vector2(0, -3), 14)
	for side in ["l", "r"]:
		var direction := -1.0 if side == "l" else 1.0
		_bone(_bones.torso, "upper_arm_" + side, Vector2(direction * 6, -13), 11)
		_bone(_bones["upper_arm_" + side], "forearm_" + side, Vector2(0, 11), 11)
		_socket(_bones["forearm_" + side], "hand_" + side, Vector2(0, 11))
		_bone(_bones.pelvis, "thigh_" + side, Vector2(direction * 5, 0), THIGH_LENGTH)
		_bone(_bones["thigh_" + side], "shin_" + side, Vector2(0, THIGH_LENGTH), SHIN_LENGTH)
		_socket(_bones["shin_" + side], "ankle_" + side, Vector2(0, SHIN_LENGTH))
		_socket(self, "foot_" + side, Vector2(direction * 5, 0))
	_socket(_bones.pelvis, "gourd", Vector2(-8, -2))
	_sockets.hand_r.rotation = PI / 2.0
	for part in BODY_PARTS + ["ponytail"]:
		_sprite(_bones[part], part)
	for side in ["l", "r"]:
		_sprite(_sockets["foot_" + side], "boot_" + side)
	_sprite(_sockets.hand_r, "weapon")
	_sprite(_sockets.hand_r, "grip_overlay")
	_sprite(_sockets.gourd, "accessory")
	_socket(_sockets.hand_r, "weapon_grip", Vector2.ZERO)

func _bone(parent: Node2D, bone_name: String, rest_position: Vector2, bone_length: float) -> void:
	var bone := Bone2D.new()
	bone.name = bone_name
	bone.position = rest_position
	bone.set_autocalculate_length_and_angle(false)
	bone.length = bone_length
	bone.bone_angle = PI / 2.0
	bone.rest = bone.transform
	parent.add_child(bone)
	_bones[bone_name] = bone
	_rest_positions[bone_name] = rest_position

func _socket(parent: Node2D, socket_name: String, rest_position: Vector2) -> void:
	var socket := Node2D.new()
	socket.name = socket_name
	socket.position = rest_position
	parent.add_child(socket)
	_sockets[socket_name] = socket

func _sprite(parent: Node2D, slot: String) -> void:
	var sprite := Sprite2D.new()
	sprite.name = slot + "_art"
	sprite.centered = false
	_visual.add_child(sprite)
	_sprites[slot] = sprite
	_bindings[slot] = parent

func _prepare_loadout(outfit: String, weapon: String, accessory: String, view: String) -> Dictionary:
	if view not in ["front", "back"]:
		return {}
	var parts: Dictionary = _manifest.get("outfits", {}).get(outfit, {}).get(view, {})
	if parts.is_empty():
		return {}
	var definitions: Dictionary = {}
	for part in BODY_PARTS:
		if not parts.has(part):
			return {}
		definitions[part] = parts[part]
	for part in OPTIONAL_PARTS:
		definitions[part] = parts.get(part, {})
	for slot in ["weapon", "accessory"]:
		var item_id := weapon if slot == "weapon" else accessory
		var collection := "weapons" if slot == "weapon" else "accessories"
		if item_id.is_empty():
			definitions[slot] = {}
		else:
			var item: Dictionary = _manifest.get(collection, {}).get(item_id, {}).get(view, {})
			if item.is_empty():
				return {}
			definitions[slot] = item
	var prepared: Dictionary = {}
	for slot in definitions:
		var spec: Dictionary = definitions[slot]
		if spec.is_empty():
			prepared[slot] = {}
			continue
		var path := String(spec.get("texture", ""))
		if path.is_empty() or not ResourceLoader.exists(path) or not spec.has("pivot"):
			return {}
		if not _texture_cache.has(path):
			var texture: Texture2D = load(path)
			if texture == null:
				return {}
			_texture_cache[path] = texture
		prepared[slot] = {"texture": _texture_cache[path], "pivot": _vec(spec.pivot), "offset": _vec(spec.get("offset", [0, 0])), "scale": _vec(spec.get("scale", [1, 1])), "z_index": spec.get("z_index", (FRONT_Z if view == "front" else BACK_Z).get(slot, 0))}
	return prepared

func _apply_loadout(prepared: Dictionary) -> void:
	var layers: Dictionary = _manifest.get("viewOverrides", {}).get(_view, {}).get("zIndex", {})
	for slot in prepared:
		var spec: Dictionary = prepared[slot]
		var sprite: Sprite2D = _sprites[slot]
		sprite.visible = not spec.is_empty()
		if spec.is_empty():
			sprite.texture = null
			continue
		sprite.texture = spec.texture
		_art_transforms[slot] = Transform2D(0.0, spec.scale, 0.0, spec.offset - spec.pivot * spec.scale)
		_draw_orders[slot] = int(layers.get(slot, spec.z_index))
		sprite.set_meta("grip_pixel", spec.pivot)
	for side in ["l", "r"]:
		var shin_slot: String = "shin_" + side
		var spec: Dictionary = prepared[shin_slot]
		var texture: Texture2D = spec.texture
		var shin: Sprite2D = _sprites[shin_slot]
		shin.region_enabled = true
		shin.region_rect = Rect2(0, 0, texture.get_width(), SHIN_REGION_HEIGHT)
		var boot_slot: String = "boot_" + side
		var boot: Sprite2D = _sprites[boot_slot]
		boot.texture = texture
		boot.region_enabled = true
		boot.region_rect = Rect2(0, BOOT_REGION_Y, texture.get_width(), texture.get_height() - BOOT_REGION_Y)
		var boot_origin := Vector2(spec.offset.x - spec.pivot.x * spec.scale.x, -boot.region_rect.size.y * spec.scale.y)
		_art_transforms[boot_slot] = Transform2D(0.0, spec.scale, 0.0, boot_origin)
		_draw_orders[boot_slot] = _draw_orders[shin_slot] - 1
	# The marker uses the actual texture pivot, including a manifest offset.
	if not prepared.weapon.is_empty():
		_sockets.weapon_grip.position = prepared.weapon.offset
	var ordered: Array = _sprites.keys()
	ordered.sort_custom(func(a: String, b: String) -> bool: return int(_draw_orders.get(a, 0)) < int(_draw_orders.get(b, 0)))
	for index in ordered.size():
		_visual.move_child(_sprites[ordered[index]], index)
	_sync_visuals()

func set_loadout(outfit: String, weapon: String, accessory: String) -> bool:
	if not _configured:
		return false
	var prepared := _prepare_loadout(outfit, weapon, accessory, _view)
	if prepared.is_empty():
		return false
	_outfit = outfit
	_weapon = weapon
	_accessory = accessory
	_apply_loadout(prepared)
	return true

func set_view(view: String) -> bool:
	if not _configured:
		return false
	var prepared := _prepare_loadout(_outfit, _weapon, _accessory, view)
	if prepared.is_empty():
		return false
	_view = view
	_apply_loadout(prepared)
	seek_action(_player.current_animation_position)
	return true

func play_action(action: String) -> bool:
	if not _configured or action not in ACTIONS:
		return false
	_action = action
	_contact_sent = false
	_contact_pending = false
	_restore_rest()
	_player.play(action)
	_player.seek(0.0, true, true)
	_finish_sample()
	return true

func seek_action(time: float) -> void:
	if not _configured:
		return
	_restore_rest()
	_player.seek(clampf(time, 0.0, _player.get_animation(_action).length), true, true)
	_finish_sample()

func advance_action(delta: float) -> void:
	if not _configured or not _player.is_playing():
		return
	_restore_rest()
	_player.advance(maxf(delta, 0.0))
	_finish_sample()

func _process(delta: float) -> void:
	advance_action(delta)

func _restore_rest() -> void:
	for bone_name in _bones:
		_bones[bone_name].position = _rest_positions[bone_name]
		_bones[bone_name].rotation = 0.0

func _finish_sample() -> void:
	# Independent back art uses reflected joint motion, never mirrored textures.
	var sign_x := -1.0 if _view == "back" else 1.0
	var offsets: Dictionary = _manifest.get("viewOverrides", {}).get(_view, {}).get("boneOffsets", {})
	for bone_name in _bones:
		var bone: Bone2D = _bones[bone_name]
		bone.position.x *= sign_x
		bone.rotation *= sign_x
		bone.position += _vec(offsets.get(bone_name, [0, 0]))
	_sockets.gourd.position = Vector2(-8 * sign_x, -2)
	for side in ["l", "r"]:
		var foot_x := (-5.0 if side == "l" else 5.0) * sign_x
		_solve_leg(side, Vector2(foot_x, 0), sign_x)
	_sync_visuals()
	if _contact_pending:
		_contact_pending = false
		_contact_count += 1
		study_contact.emit(StringName(_action))

func _sync_visuals() -> void:
	# Flat siblings all keep z=0: internal draw order cannot escape world Y-sort.
	for slot in _sprites:
		if _art_transforms.has(slot):
			_sprites[slot].transform = _visual.global_transform.affine_inverse() * _bindings[slot].global_transform * _art_transforms[slot]

func _solve_leg(side: String, foot_target: Vector2, facing: float) -> void:
	# Solve the knee-to-ankle chain; the shoe is independently planted at floor.
	var thigh: Bone2D = _bones["thigh_" + side]
	var shin: Bone2D = _bones["shin_" + side]
	_sockets["foot_" + side].position = foot_target
	_sockets["foot_" + side].rotation = 0.0
	var hip := to_local(thigh.global_position)
	var delta := foot_target + Vector2(0, -ANKLE_HEIGHT) - hip
	var distance := clampf(delta.length(), THIGH_LENGTH - SHIN_LENGTH, THIGH_LENGTH + SHIN_LENGTH)
	var hip_cos := (THIGH_LENGTH * THIGH_LENGTH + distance * distance - SHIN_LENGTH * SHIN_LENGTH) / (2.0 * THIGH_LENGTH * distance)
	var knee_cos := (THIGH_LENGTH * THIGH_LENGTH + SHIN_LENGTH * SHIN_LENGTH - distance * distance) / (2.0 * THIGH_LENGTH * SHIN_LENGTH)
	var thigh_angle := delta.angle() - PI / 2.0 - acos(clampf(hip_cos, -1.0, 1.0)) * facing
	thigh.rotation = thigh_angle - _bones.pelvis.rotation
	shin.rotation = (PI - acos(clampf(knee_cos, -1.0, 1.0))) * facing

func _study_contact_marker() -> void:
	if _action == "thrust" and not _contact_sent:
		_contact_sent = true
		_contact_pending = true

func get_socket(socket_name: String) -> Node2D:
	return _sockets.get(socket_name)

func get_debug_state() -> Dictionary:
	if not _configured:
		return {"configured": false}
	var textures: Dictionary = {}
	for slot in _sprites:
		var texture: Texture2D = _sprites[slot].texture
		textures[slot] = texture.resource_path if texture else ""
	var actual_grip: Vector2 = _sprites.weapon.to_global(_sprites.weapon.get_meta("grip_pixel", Vector2.ZERO))
	return {"configured": true, "outfit": _outfit, "weapon": _weapon, "accessory": _accessory, "view": _view, "action": _action, "time": _player.current_animation_position, "root_position": global_position, "hand_position": _sockets.hand_r.global_position, "weapon_grip_position": actual_grip, "foot_l_position": _sockets.foot_l.global_position, "foot_r_position": _sockets.foot_r.global_position, "head_position": _bones.head.global_position, "pelvis_position": _bones.pelvis.position, "contact_count": _contact_count, "textures": textures, "library_instance_id": _player.get_animation_library("").get_instance_id()}

func _vec(value: Array) -> Vector2:
	return Vector2(float(value[0]), float(value[1]))
