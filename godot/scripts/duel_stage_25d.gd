extends SubViewportContainer

# Desktop 2.5D presentation. This node never changes CombatDomain state.
signal presentation_started(event_type: String, side: String, animation_name: String)
signal presentation_finished(event_type: String)
signal presentation_missing(event_type: String, reason: String)
signal contact_frame(side: String)

const SOURCE_PIXEL_SIZE := 0.009
const CONTACT_RIBBON_SHADER := preload("res://shaders/sword_contact_ribbon.gdshader")

@onready var _viewport: SubViewport = $Viewport
@onready var _camera: Camera3D = $Viewport/World/Camera
@onready var _environment: WorldEnvironment = $Viewport/World/WorldEnvironment
@onready var _backdrop: MeshInstance3D = $Viewport/World/Backdrop
@onready var _floor: MeshInstance3D = $Viewport/World/Floor
@onready var _player_anchor: Marker3D = $Viewport/World/PlayerAnchor
@onready var _enemy_anchor: Marker3D = $Viewport/World/EnemyAnchor
@onready var _player_sprite: AnimatedSprite3D = $Viewport/World/PlayerAnchor/PlayerSprite
@onready var _enemy_sprite: AnimatedSprite3D = $Viewport/World/EnemyAnchor/EnemySprite
@onready var _impact_light: OmniLight3D = $Viewport/World/ImpactLight
@onready var _contact_fx: AnimatedSprite3D = $Viewport/World/WoodContact
@onready var _sword_trace: AnimatedSprite3D = $Viewport/World/SwordTrace

var _pending: Array[Dictionary] = []
var _active_event: Dictionary = {}
var _active_steps: Array[Dictionary] = []
var _playing_side := ""
var _motion_tween: Tween
var _flash_tween: Tween
var _camera_tween: Tween
var _zoom_tween: Tween
var _breath_time := 0.0
var _impact_pause := false
var _thrust_flash: Node3D
var _thrust_flash_materials: Array[ShaderMaterial] = []
var _thrust_flash_tween: Tween
var _rain_drops: Array[MeshInstance3D] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_setup_environment()
	_camera.look_at(Vector3(0.0, 1.35, -0.55), Vector3.UP)
	_player_sprite.animation_finished.connect(_on_player_animation_finished)
	_enemy_sprite.animation_finished.connect(_on_enemy_animation_finished)
	_player_sprite.frame_changed.connect(_on_actor_frame.bind("player"))
	_enemy_sprite.frame_changed.connect(_on_actor_frame.bind("enemy"))
	_player_sprite.animation_changed.connect(_align_feet.bind(_player_sprite))
	_enemy_sprite.animation_changed.connect(_align_feet.bind(_enemy_sprite))
	_contact_fx.animation_finished.connect(func() -> void: _contact_fx.visible = false)
	_sword_trace.animation_finished.connect(func() -> void: _sword_trace.visible = false)
	_build_contact_shadow(_player_anchor, 0.5)
	_build_contact_shadow(_enemy_anchor, 0.65)
	_build_thrust_flash()
	_build_mountain_rain()
	set_process(true)


func _process(delta: float) -> void:
	_breath_time += delta
	for actor in [_player_sprite, _enemy_sprite]:
		if actor.animation == "idle":
			# One source pixel of breathing, with all identity art unchanged.
			actor.offset.y = -1.0 if sin(_breath_time * 3.0) > 0.72 else 0.0
		else:
			actor.offset.y = 0.0
	for index in range(_rain_drops.size()):
		var drop := _rain_drops[index]
		drop.position += Vector3(-0.37, -3.1, 0.0) * delta
		if drop.position.y < 0.08:
			drop.position.y += 4.75
			drop.position.x += 1.15
			if drop.position.x > 8.0:
				drop.position.x -= 16.0


func _build_mountain_rain() -> void:
	# Thin 3D rain in three depth bands keeps the borrowed far mountain painting
	# static while the actual combat space has weather and parallax.
	var weather := Node3D.new()
	weather.name = "MountainRain"
	$Viewport/World.add_child(weather)
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.012, 0.155, 0.012)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(0.58, 0.73, 0.78, 0.29)
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	for index in 54:
		var drop := MeshInstance3D.new()
		drop.name = "Rain_%02d" % index
		drop.mesh = mesh
		drop.material_override = material
		var x := -7.9 + fmod(float(index * 53), 159.0) * 0.1
		var y := 0.18 + fmod(float(index * 37), 43.0) * 0.11
		var depth := -3.8 + float(index % 3) * 2.1
		drop.position = Vector3(x, y, depth)
		weather.add_child(drop)
		_rain_drops.append(drop)


func _build_contact_shadow(anchor: Marker3D, radius: float) -> void:
	var shadow := MeshInstance3D.new()
	shadow.name = "PixelContactShadow"
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for segment in 12:
		var angle_a := TAU * float(segment) / 12.0
		var angle_b := TAU * float(segment + 1) / 12.0
		surface.add_vertex(Vector3.ZERO)
		surface.add_vertex(Vector3(cos(angle_a) * radius, 0.0, sin(angle_a) * radius * 0.4))
		surface.add_vertex(Vector3(cos(angle_b) * radius, 0.0, sin(angle_b) * radius * 0.4))
	shadow.mesh = surface.commit()
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(0.055, 0.075, 0.09, 0.5)
	shadow.material_override = material
	shadow.position.y = 0.006
	anchor.add_child(shadow)


func _build_thrust_flash() -> void:
	# A native 3D blade path bridges the actual sword tip and wood contact. It is
	# rendered through the low-resolution combat viewport with the source sprites.
	_thrust_flash = Node3D.new()
	_thrust_flash.name = "SwordContactRibbon"
	_thrust_flash.position = Vector3(1.56, 0.0, 1.14)
	_thrust_flash.visible = false
	$Viewport/World.add_child(_thrust_flash)
	var path := PackedVector2Array([
		Vector2(-1.15, 1.06), Vector2(-0.67, 1.14),
		Vector2(-0.16, 1.22), Vector2(0.43, 1.36), Vector2(0.96, 1.54)
	])
	_add_ribbon("JadeAfterimage", path, 0.14, Color(0.41, 0.77, 0.77, 0.62), 0.0)
	_add_ribbon("SwordCore", path, 0.033, Color(0.98, 0.96, 0.78, 1.0), 0.025)
	for spark in 8:
		var angle := TAU * float(spark) / 8.0
		var where := Vector3(0.93 + cos(angle) * 0.12, 1.53 + sin(angle) * 0.15, 0.04)
		var shard := MeshInstance3D.new()
		shard.name = "ContactSpark_%d" % spark
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.035, 0.15 + float(spark % 3) * 0.035, 0.012)
		shard.mesh = mesh
		shard.position = where
		shard.rotation.z = angle + PI * 0.5
		var material := ShaderMaterial.new()
		material.shader = CONTACT_RIBBON_SHADER
		material.set_shader_parameter("ribbon_color", Color(0.9, 0.87, 0.61, 0.92))
		shard.material_override = material
		_thrust_flash_materials.append(material)
		_thrust_flash.add_child(shard)


func _add_ribbon(name: String, path: PackedVector2Array, width: float,
		color: Color, depth: float) -> void:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in range(path.size() - 1):
		var tangent: Vector2 = (path[index + 1] - path[index]).normalized()
		var normal := Vector2(-tangent.y, tangent.x)
		var start_width := width * (0.06 + 0.94 * sin(PI * float(index) / float(path.size() - 1)))
		var end_width := width * (0.06 + 0.94 * sin(PI * float(index + 1) / float(path.size() - 1)))
		var a := path[index] + normal * start_width
		var b := path[index] - normal * start_width
		var c := path[index + 1] + normal * end_width
		var d := path[index + 1] - normal * end_width
		for point in [a, b, c, c, b, d]:
			tool.add_vertex(Vector3(point.x, point.y, depth))
	var ribbon := MeshInstance3D.new()
	ribbon.name = name
	ribbon.mesh = tool.commit()
	var material := ShaderMaterial.new()
	material.shader = CONTACT_RIBBON_SHADER
	material.set_shader_parameter("ribbon_color", color)
	ribbon.material_override = material
	_thrust_flash_materials.append(material)
	_thrust_flash.add_child(ribbon)


func _show_thrust_flash(contact_kind: String) -> void:
	if _thrust_flash_tween != null and _thrust_flash_tween.is_running():
		_thrust_flash_tween.kill()
	_thrust_flash.visible = true
	for index in range(_thrust_flash_materials.size()):
		var material := _thrust_flash_materials[index]
		if contact_kind == "shield":
			material.set_shader_parameter("ribbon_color",
				Color(0.43, 0.87, 0.71, 0.67) if index == 0 else Color(0.92, 0.98, 0.76, 0.94))
		else:
			material.set_shader_parameter("ribbon_color",
				Color(0.41, 0.77, 0.77, 0.70) if index == 0 else Color(0.99, 0.95, 0.75, 0.98))
		material.set_shader_parameter("opacity", 1.0)
	_thrust_flash_tween = create_tween()
	_thrust_flash_tween.tween_interval(0.06)
	_thrust_flash_tween.tween_method(func(value: float) -> void:
		for material in _thrust_flash_materials:
			material.set_shader_parameter("opacity", value), 1.0, 0.0, 0.27)
	_thrust_flash_tween.finished.connect(func() -> void: _thrust_flash.visible = false)


func set_backdrop_texture(texture: Texture2D) -> bool:
	if texture == null:
		return false
	var material := StandardMaterial3D.new()
	material.albedo_texture = texture
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_backdrop.material_override = material
	_backdrop.visible = true
	var floor_material := _floor.get_surface_override_material(0) as ShaderMaterial
	if floor_material == null:
		return false
	floor_material.set_shader_parameter("source_albedo", texture)
	var architecture := $Viewport/World/CangmangTrialArchitecture
	for post in architecture.get_children():
		for piece in post.get_children():
			if piece is MeshInstance3D and piece.material_override is ShaderMaterial:
				(piece.material_override as ShaderMaterial).set_shader_parameter("source_albedo", texture)
	return true


func set_actor_frames(side: String, frames: SpriteFrames) -> bool:
	var sprite := get_actor_sprite(side)
	if sprite == null or frames == null or not frames.has_animation("idle") \
			or frames.get_frame_count("idle") == 0 \
			or not frames.get_animation_loop("idle"):
		return false
	sprite.sprite_frames = frames
	sprite.visible = true
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.pixel_size = SOURCE_PIXEL_SIZE
	sprite.play("idle")
	_align_feet(sprite)
	return true


func _align_feet(sprite: AnimatedSprite3D) -> void:
	if sprite == null or sprite.sprite_frames == null:
		return
	var clip := String(sprite.animation)
	var index := sprite.frame
	if sprite.sprite_frames.has_meta("scale_" + clip):
		sprite.pixel_size = SOURCE_PIXEL_SIZE * float(sprite.sprite_frames.get_meta("scale_" + clip))
		var canvas := int(sprite.sprite_frames.get_meta("canvas_%s_%d" % [clip, index],
			sprite.sprite_frames.get_frame_texture(clip, index).get_height()))
		var feet := float(sprite.sprite_frames.get_meta("foot_%s_%d" % [clip, index], 1.0))
		sprite.position.y = (feet - 0.5) * float(canvas) * sprite.pixel_size
	else:
		var key := "cell_%s_%d" % [clip, index]
		var cell := int(sprite.sprite_frames.get_meta(key, 0))
		var bottom := int(sprite.sprite_frames.get_meta("feet_%d" % cell, 512))
		sprite.position.y = (bottom - 256) * sprite.pixel_size


func _on_actor_frame(side: String) -> void:
	var sprite := get_actor_sprite(side)
	_align_feet(sprite)
	if sprite == null:
		return
	var impact_index := int(sprite.sprite_frames.get_meta("impact_frame_" + String(sprite.animation), -1))
	if side == "player" and sprite.animation in ["attack", "sword_probe", "sword_followthrough", "sword_edge"] \
			and sprite.frame == (impact_index if impact_index >= 0 else 2):
		var contact_kind := String(_active_event.get("contact_kind", "wood"))
		if contact_kind != "air":
			_flash_contact(contact_kind)
		contact_frame.emit("player")
	elif side == "enemy" and sprite.animation == "attack" and sprite.frame == 2:
		_flash_contact("enemy")
		contact_frame.emit("enemy")


func _flash_contact(contact_kind: String = "wood") -> void:
	if _flash_tween != null and _flash_tween.is_running():
		_flash_tween.kill()
	var wood_hit := contact_kind == "wood"
	_impact_light.light_color = Color("f5daab") if wood_hit else Color("a2dcc9")
	_impact_light.light_energy = 2.1 if wood_hit else 1.3
	var floor_material := _floor.get_surface_override_material(0) as ShaderMaterial
	if floor_material != null:
		floor_material.set_shader_parameter("contact_glow", 1.0 if wood_hit else 0.55)
	if wood_hit and _contact_fx.sprite_frames != null:
		_contact_fx.visible = true
		_contact_fx.play("damage")
	if contact_kind in ["wood", "shield"] and _player_sprite.animation in ["sword_probe", "sword_followthrough", "sword_edge"] \
			and _sword_trace.sprite_frames != null:
		_sword_trace.visible = true
		_sword_trace.play("contact")
		_show_thrust_flash(contact_kind)
	_flash_tween = create_tween()
	_flash_tween.set_parallel(true)
	_flash_tween.tween_property(_impact_light, "light_energy", 0.0, 0.28)
	if floor_material != null:
		_flash_tween.tween_method(func(value: float) -> void:
			floor_material.set_shader_parameter("contact_glow", value),
			1.0 if wood_hit else 0.55, 0.0, 0.36)
	# A short native camera recoil and pose hold makes the contact legible.
	if _camera_tween != null and _camera_tween.is_running():
		_camera_tween.kill()
	_camera.position.x = 0.0
	_camera_tween = create_tween()
	_camera_tween.tween_property(_camera, "position:x", -0.11 if wood_hit else 0.065, 0.055)
	_camera_tween.tween_property(_camera, "position:x", 0.0, 0.13).set_trans(Tween.TRANS_CUBIC)
	if not _impact_pause:
		_impact_pause = true
		_player_sprite.speed_scale = 0.0
		_enemy_sprite.speed_scale = 0.0
		get_tree().create_timer(0.075).timeout.connect(func() -> void:
			_player_sprite.speed_scale = 1.0
			_enemy_sprite.speed_scale = 1.0
			_impact_pause = false)


func get_actor_anchor(side: String) -> Marker3D:
	if side == "player":
		return _player_anchor
	if side == "enemy":
		return _enemy_anchor
	return null


func get_actor_sprite(side: String) -> AnimatedSprite3D:
	if side == "player":
		return _player_sprite
	if side == "enemy":
		return _enemy_sprite
	return null


func present_action(event: Dictionary) -> bool:
	var kind := String(event.get("type", ""))
	var requests: Array[Dictionary] = []
	var contact_kind_for_event := "wood"
	if kind == "CARD_PLAY":
		var card_id := String(event.get("cardId", ""))
		var fallback := "guard" if card_id in ["sword_guard", "sword_sheath_guard"] else "attack"
		requests.append({"side": "player", "candidates": [card_id, fallback]})
		var hp_loss := 0
		var block_spent := 0
		for effect in event.get("effects", []):
			if effect is Dictionary and effect.get("type") == "damage":
				hp_loss += int(effect.get("hpLoss", 0))
				block_spent += int(effect.get("blockSpent", 0))
		contact_kind_for_event = "wood" if hp_loss > 0 else ("shield" if block_spent > 0 else "air")
		if bool(event.get("victory", false)):
			requests.append({"side": "enemy", "candidates": ["defeat"]})
		elif hp_loss > 0:
			requests.append({"side": "enemy", "candidates": ["hurt"]})
	elif kind == "ENEMY_ACTION":
		if String(event.get("reactionId", "TAKE_HIT")) != "TAKE_HIT":
			requests.append({"side": "player", "candidates": ["reaction"]})
		var intent: Dictionary = event.get("intent", {})
		requests.append({"side": "enemy", "candidates": ["attack" if intent.get("type") == "attack" else "guard"]})
		if int(event.get("hpLoss", 0)) > 0:
			requests.append({"side": "player", "candidates": ["hurt"]})
	elif kind == "DEFEAT":
		requests.append({"side": "player", "candidates": ["defeat"]})
	else:
		return false
	var steps: Array[Dictionary] = []
	for request in requests:
		var side := String(request["side"])
		var sprite := get_actor_sprite(side)
		var animation_name := _first_authored_clip(sprite, request["candidates"])
		if animation_name.is_empty():
			presentation_missing.emit(kind, "Missing non-looping sprite frames for " + side + " " + str(request["candidates"]))
			return false
		steps.append({"side": side, "animation": animation_name})
	_pending.append({"type": kind, "steps": steps, "contact_kind": contact_kind_for_event})
	if _active_event.is_empty():
		_start_next_event()
	return true


func _first_authored_clip(sprite: AnimatedSprite3D, candidates: Array) -> String:
	if sprite == null or sprite.sprite_frames == null:
		return ""
	for candidate in candidates:
		var clip := String(candidate)
		if sprite.sprite_frames.has_animation(clip) \
				and sprite.sprite_frames.get_frame_count(clip) > 0 \
				and not sprite.sprite_frames.get_animation_loop(clip):
			return clip
	return ""


func _start_next_event() -> void:
	if _pending.is_empty():
		_active_event = {}
		return
	_active_event = _pending.pop_front()
	_active_steps = _active_event["steps"].duplicate()
	_play_next_step()


func _play_next_step() -> void:
	if _active_steps.is_empty():
		var completed := String(_active_event.get("type", ""))
		_active_event = {}
		_playing_side = ""
		presentation_finished.emit(completed)
		_start_next_event()
		return
	var step: Dictionary = _active_steps.pop_front()
	_playing_side = String(step["side"])
	var sprite := get_actor_sprite(_playing_side)
	var clip := String(step["animation"])
	sprite.play(clip)
	if clip in ["attack", "sword_probe", "sword_followthrough", "sword_edge"]:
		var anchor := get_actor_anchor(_playing_side)
		var home_x := -2.3 if _playing_side == "player" else 2.35
		var travel := 2.7 if _playing_side == "player" else -0.55
		var duration := float(sprite.sprite_frames.get_meta("duration_ms_" + clip,
			float(sprite.sprite_frames.get_frame_count(clip)) / sprite.sprite_frames.get_animation_speed(clip) * 1000.0)) / 1000.0
		if _motion_tween != null and _motion_tween.is_running():
			_motion_tween.kill()
		_motion_tween = create_tween()
		_motion_tween.tween_property(anchor, "position:x", home_x + travel, duration * 0.48).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		_motion_tween.tween_property(anchor, "position:x", home_x, duration * 0.52).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		if _playing_side == "player":
			if _zoom_tween != null and _zoom_tween.is_running():
				_zoom_tween.kill()
			_zoom_tween = create_tween()
			_zoom_tween.tween_property(_camera, "fov", 38.5, duration * 0.42).set_trans(Tween.TRANS_CUBIC)
			_zoom_tween.tween_interval(0.11)
			_zoom_tween.tween_property(_camera, "fov", 43.0, duration * 0.58).set_trans(Tween.TRANS_CUBIC)
	presentation_started.emit(String(_active_event["type"]), _playing_side, String(step["animation"]))


func _on_player_animation_finished() -> void:
	if _playing_side == "player":
		_finish_step("player")


func _on_enemy_animation_finished() -> void:
	if _playing_side == "enemy":
		_finish_step("enemy")


func _finish_step(side: String) -> void:
	var sprite := get_actor_sprite(side)
	var anchor := get_actor_anchor(side)
	if _motion_tween != null and _motion_tween.is_running():
		_motion_tween.kill()
	anchor.position.x = -2.3 if side == "player" else 2.35
	if not sprite.animation in ["defeat", "victory"] and sprite.sprite_frames.has_animation("idle"):
		sprite.play("idle")
	_play_next_step()


func _setup_environment() -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("2b333d")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("8a9aa8")
	environment.ambient_light_energy = 0.68
	_environment.environment = environment


