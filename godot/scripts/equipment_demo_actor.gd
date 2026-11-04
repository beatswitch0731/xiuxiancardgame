extends Node3D

# The body/armor poses are authored art. Props share each pose's measured
# sockets; neither the renderer nor its animation clock changes game state.
signal frame_changed(clip: String, frame: int)
signal contact(clip: String)
signal action_finished(clip: String)

const MANIFEST := "res://assets/equipment_demo/manifest.json"
var current_clip := "idle"
var current_frame := 0
var speed_scale := 1.0
var playback_paused := false
var attack_distance := 0.65
var home_offset := Vector3.ZERO
var visual_scale := 1.0
var equipment: Dictionary = {}
var manifest: Dictionary = {}
var sprite: Sprite3D
var camera: Camera3D
var canvas: SubViewport
var ready_assets := false
var _body: Sprite2D
var _hand: Sprite2D
var _weapon: Sprite2D
var _gourd: Sprite2D
var _box: Sprite2D
var _textures: Dictionary = {}
var _clock := 0.0
var _contact_sent := false
var _pulse := 0.0
var _canvas_size := Vector2(640, 400)
var _foot := Vector2(180, 350)
var _pixel_size := 0.012

func _ready() -> void:
	if not FileAccess.file_exists(MANIFEST):
		push_error("换装演示缺少正式素材清单：" + MANIFEST)
		return
	var decoded: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	if not decoded is Dictionary:
		push_error("换装演示素材清单不是有效 JSON")
		return
	manifest = decoded
	_canvas_size = _vector(manifest.get("canvas", [640, 400]))
	_foot = _vector(manifest.get("foot", [180, 350]))
	_pixel_size = float(manifest.get("pixelSize", 0.012)) * visual_scale
	canvas = SubViewport.new()
	canvas.name = "EquipmentPoseCanvas"
	canvas.size = Vector2i(_canvas_size)
	canvas.transparent_bg = true
	canvas.disable_3d = true
	canvas.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	canvas.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	add_child(canvas)
	_box = _layer("SwordBox", -2)
	_body = _layer("AuthoredBody", 0)
	_weapon = _layer("IndependentWeapon", 1)
	_weapon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_gourd = _layer("WaistGourd", 1)
	_hand = _layer("GripOcclusion", 2)
	sprite = Sprite3D.new()
	sprite.name = "ComposedEquipmentActor"
	sprite.texture = canvas.get_texture()
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
	sprite.pixel_size = _pixel_size
	sprite.shaded = true
	sprite.layers |= 1 << 1
	add_child(sprite)
	ready_assets = true
	play_clip("idle")

func _layer(layer_name: String, order: int) -> Sprite2D:
	var layer := Sprite2D.new()
	layer.name = layer_name
	layer.centered = false
	layer.z_index = order
	layer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	canvas.add_child(layer)
	return layer

func set_equipment(loadout: Dictionary) -> void:
	equipment = loadout.duplicate()
	if ready_assets:
		_apply_pose()

func play_clip(clip: String) -> void:
	if not ready_assets:
		return
	current_clip = clip
	current_frame = 0
	_clock = 0.0
	_contact_sent = false
	position = home_offset
	_apply_pose()

func set_playback_paused(value: bool) -> void:
	playback_paused = value

func seek_pose(clip: String, index: int) -> void:
	if not ready_assets:
		return
	current_clip = clip
	var poses := _poses()
	current_frame = clampi(index, 0, poses.size() - 1)
	_clock = 0.0
	for i in range(current_frame):
		_clock += _duration(i)
	_contact_sent = true
	_apply_pose()

func frame_count(clip: String = "") -> int:
	var outfit: Dictionary = manifest.get("outfits", {}).get(_outfit(), {})
	return outfit.get(current_clip if clip.is_empty() else clip, []).size()

func duration(clip: String = "") -> float:
	var key := current_clip if clip.is_empty() else clip
	var total := 0.0
	for value in manifest.get("clips", {}).get(key, {}).get("durations", []):
		total += float(value) / 1000.0
	return total

func get_socket_world(socket_name: String) -> Vector3:
	var poses := _poses()
	if poses.is_empty():
		return global_position
	var point := _vector(poses[current_frame].get(socket_name, [96, 120]))
	return pixel_to_world(point)

func pixel_to_world(point: Vector2) -> Vector3:
	if camera == null:
		return global_position
	return global_position + camera.global_basis.x * (point.x - _foot.x) * _pixel_size \
		+ camera.global_basis.y * (_foot.y - point.y) * _pixel_size

func prop_texture(id: String) -> Texture2D:
	return _texture(String(manifest.get("props", {}).get(id, {}).get("file", "")))

func pulse_gourd() -> void:
	_pulse = 0.8

func _process(delta: float) -> void:
	if not ready_assets:
		return
	# The canvas pivot is transformed in the same camera plane as the billboard.
	# Translating by world UP leaves a tilted billboard's shoes floating.
	if camera != null:
		sprite.global_position = pixel_to_world(_canvas_size * 0.5)
	if playback_paused:
		return
	_pulse = maxf(0.0, _pulse - delta)
	_gourd.modulate = Color(1.0 + _pulse, 1.0 + _pulse, 1.0)
	_clock += delta * speed_scale
	var total := duration()
	if total <= 0.0:
		return
	if current_clip != "idle":
		var progress := clampf(_clock / total, 0.0, 1.0)
		position.x = home_offset.x + sin(progress * PI) * attack_distance if current_clip == "thrust" else home_offset.x
		if not _contact_sent and progress >= 0.48:
			_contact_sent = true
			contact.emit(current_clip)
	if _clock >= total:
		if current_clip == "idle":
			_clock = fmod(_clock, total)
		else:
			var finished := current_clip
			play_clip("idle")
			action_finished.emit(finished)
			return
	var until := 0.0
	var next_frame := frame_count() - 1
	for i in range(frame_count()):
		until += _duration(i)
		if _clock < until:
			next_frame = i
			break
	if next_frame != current_frame:
		current_frame = next_frame
		_apply_pose()

func _duration(index: int) -> float:
	var durations: Array = manifest.get("clips", {}).get(current_clip, {}).get("durations", [])
	return float(durations[index]) / 1000.0 if index < durations.size() else 0.10

func _outfit() -> String:
	var armor := String(equipment.get("armor", ""))
	return armor if not armor.is_empty() else "base"

func _poses() -> Array:
	return manifest.get("outfits", {}).get(_outfit(), {}).get(current_clip, [])

func _apply_pose() -> void:
	var poses := _poses()
	if poses.is_empty():
		push_error("换装演示缺少已绘制动作：%s / %s" % [_outfit(), current_clip])
		return
	current_frame = mini(current_frame, poses.size() - 1)
	var pose: Dictionary = poses[current_frame]
	_body.texture = _texture(String(pose.get("file", "")))
	_hand.texture = _texture(String(pose.get("handFile", "")))
	_hand.visible = _hand.texture != null and not String(equipment.get("weapon", "")).is_empty()
	_bind_prop(_weapon, String(equipment.get("weapon", "")), pose.get("grip", [160, 140]), "grip", float(pose.get("angle", 0)))
	_bind_prop(_gourd, String(equipment.get("accessory", "")), pose.get("waist", [120, 150]), "anchor", float(pose.get("gourdAngle", 0)))
	_bind_prop(_box, String(equipment.get("artifact", "")), pose.get("back", [110, 125]), "anchor", float(pose.get("backAngle", -12)))
	frame_changed.emit(current_clip, current_frame)

func _bind_prop(layer: Sprite2D, id: String, socket: Array, anchor_name: String, angle: float) -> void:
	layer.visible = not id.is_empty()
	if id.is_empty():
		return
	var prop: Dictionary = manifest.get("props", {}).get(id, {})
	layer.texture = _texture(String(prop.get("file", "")))
	layer.rotation = deg_to_rad(angle)
	layer.position = _vector(socket) - _vector(prop.get(anchor_name, [0, 0])).rotated(layer.rotation)

func _texture(path: String) -> Texture2D:
	if path.is_empty():
		return null
	if _textures.has(path):
		return _textures[path]
	var image := Image.load_from_file(path)
	if image == null or image.is_empty():
		push_error("换装演示缺少素材：" + path)
		return null
	var result := ImageTexture.create_from_image(image)
	_textures[path] = result
	return result

func _vector(values: Array) -> Vector2:
	return Vector2(float(values[0]), float(values[1]))
