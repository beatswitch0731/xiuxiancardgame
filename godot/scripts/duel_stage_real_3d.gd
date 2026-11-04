extends SubViewportContainer

# Presentation only. The source-derived CombatDomain remains the sole combat authority.
signal presentation_started(event_type: String, side: String, animation_name: String)
signal presentation_finished(event_type: String)
signal presentation_missing(event_type: String, reason: String)
signal contact_frame(side: String)

const WorldScene = preload("res://scenes/cangmang_real_3d_world.tscn")
const HeroScene = preload("res://scenes/yelingyun_s1_real_3d.tscn")
const DummyScene = preload("res://scenes/quick_sword_dummy_real_3d.tscn")

const PLAYER_HOME := Vector3(-2.3, 0.0, 0.15)
const ENEMY_HOME := Vector3(2.3, 0.0, -0.25)
const CAMERA_TARGET := Vector3(0.0, 1.25, -0.72)
const CAMERA_HOME := Vector3(0.0, 4.15, 10.7)

@onready var _world_root: Node3D = $Viewport/World
@onready var _environment: WorldEnvironment = $Viewport/World/WorldEnvironment
@onready var _camera_rig: Node3D = $Viewport/World/CameraRig
@onready var _camera: Camera3D = $Viewport/World/CameraRig/Camera
@onready var _player_anchor: Node3D = $Viewport/World/PlayerAnchor
@onready var _enemy_anchor: Node3D = $Viewport/World/EnemyAnchor
@onready var _impact_light: OmniLight3D = $Viewport/World/ImpactLight

var _player: Node3D
var _enemy: Node3D
var _world: Node3D
var _pending: Array[Dictionary] = []
var _draining := false
var _impact_fx: Node3D
var _impact_material: StandardMaterial3D
var _arc_material: StandardMaterial3D
var _arc_core_material: StandardMaterial3D
var _camera_tween: Tween
var _light_tween: Tween
var _diagnostic_orbit := false
var _active_motion: Dictionary = {}
var _sampled_contact_tips: Dictionary = {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_world = WorldScene.instantiate()
	_world.name = "CangmangReal3DWorld"
	_world_root.add_child(_world)
	_player = HeroScene.instantiate()
	_player.name = "YelingyunReal3D"
	_player_anchor.add_child(_player)
	_player.rotation.y = -0.35
	_enemy = DummyScene.instantiate()
	_enemy.name = "QuickSwordDummyReal3D"
	_enemy_anchor.add_child(_enemy)
	_enemy.rotation.y = PI + 0.35
	_player.contact_key.connect(_on_actor_contact_key.bind("player"))
	_enemy.contact_key.connect(_on_actor_contact_key.bind("enemy"))
	_setup_environment()
	_set_camera_yaw(0.0)
	_build_impact_fx()
	if _player.has_method("play_action"):
		_player.play_action("idle")
	if _enemy.has_method("play_action"):
		_enemy.play_action("idle")
	set_process(true)


func _process(_delta: float) -> void:
	_sync_motion_to_animation()


func has_authored_3d_assets() -> bool:
	return _world != null and _player != null and _enemy != null \
		and _mesh_count(_world) >= 24 and _mesh_count(_player) >= 12 \
		and _mesh_count(_enemy) >= 12 and _actor_has("player", "sword_probe") \
		and _actor_has("enemy", "attack")


func get_actor_model(side: String) -> Node3D:
	return _player if side == "player" else (_enemy if side == "enemy" else null)


func get_actor_anchor(side: String) -> Node3D:
	return _player_anchor if side == "player" else (_enemy_anchor if side == "enemy" else null)


func get_world_model() -> Node3D:
	return _world


func set_diagnostic_yaw(degrees: float) -> void:
	# Test hook: oblique view exposes model depth and scene parallax.
	_set_camera_yaw(deg_to_rad(clampf(degrees, -35.0, 35.0)))


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F9:
		_diagnostic_orbit = not _diagnostic_orbit
		set_diagnostic_yaw(24.0 if _diagnostic_orbit else 0.0)


func present_action(event: Dictionary) -> bool:
	var kind := String(event.get("type", ""))
	if not kind in ["CARD_PLAY", "ENEMY_ACTION", "DEFEAT"]:
		return false
	var steps: Array[Dictionary] = []
	var contact_kind := "air"
	if kind == "CARD_PLAY":
		var card_id := String(event.get("cardId", ""))
		var clip := _card_clip(card_id)
		steps.append({"side": "player", "clip": clip, "contact": clip != "guard"})
		var hp_loss := 0
		var block_spent := 0
		for effect in event.get("effects", []):
			if effect is Dictionary and effect.get("type") == "damage":
				hp_loss += int(effect.get("hpLoss", 0))
				block_spent += int(effect.get("blockSpent", 0))
		contact_kind = "wood" if hp_loss > 0 else ("shield" if block_spent > 0 else "air")
		if bool(event.get("victory", false)):
			steps.append({"side": "enemy", "clip": "defeat", "contact": false})
		elif hp_loss > 0:
			steps.append({"side": "enemy", "clip": "hurt", "contact": false})
	elif kind == "ENEMY_ACTION":
		if String(event.get("reactionId", "TAKE_HIT")) != "TAKE_HIT":
			steps.append({"side": "player", "clip": "reaction", "contact": false})
		var intent: Dictionary = event.get("intent", {})
		var enemy_clip := "attack" if intent.get("type") == "attack" else "guard"
		steps.append({"side": "enemy", "clip": enemy_clip, "contact": enemy_clip == "attack"})
		if int(event.get("hpLoss", 0)) > 0:
			steps.append({"side": "player", "clip": "hurt", "contact": false})
		contact_kind = "flesh" if int(event.get("hpLoss", 0)) > 0 else "shield"
	else:
		steps.append({"side": "player", "clip": "defeat", "contact": false})
	for step in steps:
		if not _actor_has(String(step["side"]), String(step["clip"])):
			presentation_missing.emit(kind, "Missing real 3D actor clip: " + str(step))
			return false
	_pending.append({"type": kind, "steps": steps, "contact_kind": contact_kind})
	if not _draining:
		call_deferred("_drain_presentations")
	return true


func _card_clip(card_id: String) -> String:
	if _actor_has("player", card_id):
		return card_id
	if card_id in ["sword_guard", "sword_sheath_guard"]:
		return "guard"
	return "attack"


func _actor_has(side: String, clip: String) -> bool:
	var actor := get_actor_model(side)
	if actor == null:
		return false
	if actor.has_method("has_action"):
		return bool(actor.has_action(clip))
	var animation_player := actor.get_node_or_null("AnimationPlayer") as AnimationPlayer
	return animation_player != null and animation_player.has_animation(clip)


func _drain_presentations() -> void:
	if _draining:
		return
	_draining = true
	while not _pending.is_empty():
		var event: Dictionary = _pending.pop_front()
		for step in event["steps"]:
			await _play_step(String(event["type"]), step, String(event["contact_kind"]))
		presentation_finished.emit(String(event["type"]))
	_draining = false


func _play_step(kind: String, step: Dictionary, contact_kind: String) -> void:
	var side := String(step["side"])
	var clip := String(step["clip"])
	var actor := get_actor_model(side)
	var anchor := get_actor_anchor(side)
	var home := PLAYER_HOME if side == "player" else ENEMY_HOME
	var attack := bool(step["contact"])
	var duration := _clip_duration(actor, clip)
	var contact_time := clampf(float(actor.get_contact_time(clip)), 0.08, duration - 0.08) if attack and actor.has_method("get_contact_time") else duration * 0.47
	anchor.position = home
	var strike_position := home
	if attack:
		strike_position = _strike_destination(side, clip, contact_time, home)
		_active_motion = {
			"actor": actor, "anchor": anchor, "home": home,
			"destination": strike_position, "clip": clip, "side": side,
			"contact_time": contact_time, "duration": duration,
			"idle_yaw": -0.35 if side == "player" else PI + 0.35,
			"strike_yaw": 0.0 if side == "player" else PI,
			"contact_kind": contact_kind, "contacted": false,
		}
	actor.play_action(clip)
	presentation_started.emit(kind, side, clip)
	await actor.action_finished
	_active_motion = {}
	anchor.position = home
	actor.rotation.y = -0.35 if side == "player" else PI + 0.35
	_camera.fov = 43.0
	if clip != "defeat":
		actor.play_action("idle")


func _sync_motion_to_animation() -> void:
	if _active_motion.is_empty():
		return
	var actor: Node3D = _active_motion["actor"]
	var clip := String(_active_motion["clip"])
	var animation_player: AnimationPlayer = actor.get_animation_player()
	if animation_player.current_animation != clip:
		return
	var time := animation_player.current_animation_position
	var contact_time := float(_active_motion["contact_time"])
	var duration := float(_active_motion["duration"])
	var weight := 0.0
	if time <= contact_time:
		var lead := clampf(time / contact_time, 0.0, 1.0)
		weight = lead * lead * (3.0 - 2.0 * lead)
	else:
		var recovery := clampf((time - contact_time) / maxf(0.001, duration - contact_time), 0.0, 1.0)
		weight = 1.0 - recovery * recovery * (3.0 - 2.0 * recovery)
	var anchor: Node3D = _active_motion["anchor"]
	var home: Vector3 = _active_motion["home"]
	var destination: Vector3 = _active_motion["destination"]
	anchor.position = home.lerp(destination, weight)
	actor.rotation.y = lerp_angle(float(_active_motion["idle_yaw"]), float(_active_motion["strike_yaw"]), weight)
	if String(_active_motion["side"]) == "player":
		_camera.fov = lerpf(43.0, 39.5, weight)


func _on_actor_contact_key(clip: String, side: String) -> void:
	if _active_motion.is_empty() or bool(_active_motion["contacted"]) \
			or String(_active_motion["side"]) != side or String(_active_motion["clip"]) != clip:
		return
	_sync_motion_to_animation()
	_active_motion["contacted"] = true
	var contact_kind := String(_active_motion["contact_kind"])
	if contact_kind != "air":
		_flash_contact(side, contact_kind)
	contact_frame.emit(side)


func _strike_destination(side: String, clip: String, contact_time: float, home: Vector3) -> Vector3:
	# A disposable rig samples the authored blade pose. Seeking the live rig
	# can queue an AnimationPlayer method-track contact at time zero on replay.
	var key := side + ":" + clip
	if not _sampled_contact_tips.has(key):
		var sample: Node3D = HeroScene.instantiate() if side == "player" else DummyScene.instantiate()
		sample.name = "ContactPoseSampler"
		sample.visible = false
		_world_root.add_child(sample)
		sample.rotation.y = 0.0 if side == "player" else PI
		sample.play_action(clip)
		var animation_player: AnimationPlayer = sample.get_animation_player()
		animation_player.seek(contact_time, true)
		_sampled_contact_tips[key] = sample.get_sword_tip().global_position
		sample.queue_free()
	var target: Node3D = _enemy if side == "player" else _player
	var chest: Vector3 = target.get_chest_hit().global_position
	var tip: Vector3 = _sampled_contact_tips[key]
	return Vector3(chest.x - tip.x, home.y, chest.z - tip.z)


func _clip_duration(actor: Node3D, clip: String) -> float:
	if actor.has_method("get_animation_player"):
		var animation_player: AnimationPlayer = actor.get_animation_player()
		if animation_player != null and animation_player.has_animation(clip):
			return animation_player.get_animation(clip).length
	match clip:
		"sword_probe": return 0.72
		"sword_followthrough": return 0.86
		"attack": return 0.78
		"guard", "sword_guard", "reaction": return 0.55
		"hurt": return 0.51
		"defeat": return 1.05
		_: return 0.78


func _flash_contact(side: String, contact_kind: String) -> void:
	var target: Node3D = _enemy if side == "player" else _player
	_impact_fx.global_position = target.get_chest_hit().global_position
	_impact_fx.scale = Vector3.ONE * 0.42
	_impact_fx.visible = true
	_impact_light.global_position = _impact_fx.global_position
	_impact_light.light_color = Color("f4c47d") if contact_kind == "wood" else Color("a2e5d8")
	_impact_light.light_energy = 3.3 if contact_kind == "wood" else 2.1
	_impact_material.albedo_color = Color(1.0, 0.86, 0.55, 0.88) if contact_kind == "wood" else Color(0.64, 0.96, 0.90, 0.85)
	_arc_material.albedo_color = Color(1.0, 0.66, 0.28, 0.82) if contact_kind == "wood" else Color(0.54, 0.86, 0.79, 0.82)
	_arc_material.emission = Color(1.0, 0.54, 0.23) if contact_kind == "wood" else Color(0.42, 0.90, 0.78)
	_arc_core_material.albedo_color = Color(1.0, 0.95, 0.75, 0.97) if contact_kind == "wood" else Color(0.85, 1.0, 0.94, 0.97)
	_arc_core_material.emission = Color(1.0, 0.86, 0.58) if contact_kind == "wood" else Color(0.65, 1.0, 0.90)
	var pulse := create_tween()
	pulse.tween_property(_impact_fx, "scale", Vector3.ONE * 1.18, 0.09).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	pulse.tween_interval(0.11)
	pulse.tween_property(_impact_fx, "scale", Vector3.ONE * 0.03, 0.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	pulse.finished.connect(func() -> void: _impact_fx.visible = false)
	if _light_tween != null and _light_tween.is_running():
		_light_tween.kill()
	_light_tween = create_tween()
	_light_tween.tween_property(_impact_light, "light_energy", 0.0, 0.29)
	if _camera_tween != null and _camera_tween.is_running():
		_camera_tween.kill()
	_camera.position.x = 0.0
	_camera_tween = create_tween()
	_camera_tween.tween_property(_camera, "position:x", -0.13 if side == "player" else 0.12, 0.045)
	_camera_tween.tween_property(_camera, "position:x", 0.0, 0.16).set_trans(Tween.TRANS_CUBIC)


func _build_impact_fx() -> void:
	_impact_fx = Node3D.new()
	_impact_fx.name = "Real3DImpact"
	_impact_fx.visible = false
	_world_root.add_child(_impact_fx)
	_impact_material = StandardMaterial3D.new()
	_impact_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_impact_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_impact_material.albedo_color = Color(1.0, 0.86, 0.55, 0.88)
	_impact_material.emission_enabled = true
	_impact_material.emission = Color(1.0, 0.68, 0.3)
	_impact_material.emission_energy_multiplier = 2.8
	_impact_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_arc_material = StandardMaterial3D.new()
	_arc_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_arc_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_arc_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_arc_material.vertex_color_use_as_albedo = true
	_arc_material.albedo_color = Color(1.0, 0.66, 0.28, 0.82)
	_arc_material.emission_enabled = true
	_arc_material.emission = Color(1.0, 0.54, 0.23)
	_arc_material.emission_energy_multiplier = 3.2
	var arc := MeshInstance3D.new()
	arc.name = "CurvedSwordTrail"
	arc.mesh = _make_tapered_sword_arc(1.0, 0.16)
	arc.material_override = _arc_material
	_impact_fx.add_child(arc)
	_arc_core_material = StandardMaterial3D.new()
	_arc_core_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_arc_core_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_arc_core_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_arc_core_material.vertex_color_use_as_albedo = true
	_arc_core_material.albedo_color = Color(1.0, 0.95, 0.75, 0.86)
	_arc_core_material.emission_enabled = true
	_arc_core_material.emission = Color(1.0, 0.86, 0.58)
	_arc_core_material.emission_energy_multiplier = 3.8
	var core_arc := MeshInstance3D.new()
	core_arc.name = "SwordTrailHotCore"
	core_arc.mesh = _make_tapered_sword_arc(0.28, 0.19)
	core_arc.material_override = _arc_core_material
	_impact_fx.add_child(core_arc)
	for index in 9:
		var ray := MeshInstance3D.new()
		ray.name = "SlashSpark_%02d" % index
		var shard := CylinderMesh.new()
		shard.top_radius = 0.0
		shard.bottom_radius = 0.025 if index % 2 == 0 else 0.015
		shard.height = 0.30 if index % 3 == 0 else 0.18
		ray.mesh = shard
		ray.material_override = _impact_material
		var angle := float(index) * TAU / 9.0
		ray.position = Vector3(cos(angle) * 0.32, sin(angle) * 0.25, sin(angle * 2.0) * 0.12)
		ray.rotation.z = angle - PI * 0.5
		_impact_fx.add_child(ray)
	var core := MeshInstance3D.new()
	core.name = "ContactCore"
	var core_mesh := SphereMesh.new()
	core_mesh.radius = 0.10
	core_mesh.height = 0.20
	core.mesh = core_mesh
	core.material_override = _impact_material
	_impact_fx.add_child(core)


func _make_tapered_sword_arc(width_scale: float, depth: float) -> ArrayMesh:
	# Five bands soften the outer edge while retaining a bright, narrow spine.
	# The ribbon remains native 3D geometry at the actor's true contact point.
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segments := 28
	var offsets := [-1.0, -0.42, 0.0, 0.42, 1.0]
	var opacity := [0.0, 0.40, 1.0, 0.40, 0.0]
	for segment in segments:
		var start := float(segment) / float(segments)
		var finish := float(segment + 1) / float(segments)
		var a := _sword_arc_point(start, depth)
		var b := _sword_arc_point(finish, depth)
		var na := Vector2(-0.33 - 1.86 * start, 1.72).normalized()
		var nb := Vector2(-0.33 - 1.86 * finish, 1.72).normalized()
		var wa := 0.12 * width_scale * pow(maxf(0.0, sin(PI * start)), 0.8)
		var wb := 0.12 * width_scale * pow(maxf(0.0, sin(PI * finish)), 0.8)
		for band in range(4):
			var a0 := a + Vector3(na.x * wa * offsets[band], na.y * wa * offsets[band], 0)
			var a1 := a + Vector3(na.x * wa * offsets[band + 1], na.y * wa * offsets[band + 1], 0)
			var b0 := b + Vector3(nb.x * wb * offsets[band], nb.y * wb * offsets[band], 0)
			var b1 := b + Vector3(nb.x * wb * offsets[band + 1], nb.y * wb * offsets[band + 1], 0)
			_add_arc_vertex(tool, a0, opacity[band])
			_add_arc_vertex(tool, a1, opacity[band + 1])
			_add_arc_vertex(tool, b0, opacity[band])
			_add_arc_vertex(tool, b0, opacity[band])
			_add_arc_vertex(tool, a1, opacity[band + 1])
			_add_arc_vertex(tool, b1, opacity[band + 1])
	return tool.commit()


func _add_arc_vertex(tool: SurfaceTool, point: Vector3, opacity: float) -> void:
	tool.set_color(Color(1.0, 1.0, 1.0, opacity))
	tool.add_vertex(point)


func _sword_arc_point(t: float, depth: float) -> Vector3:
	return Vector3(-1.05 + 1.72 * t, -0.27 + 0.33 * t + 0.93 * t * t,
		depth + 0.10 * t)


func _setup_environment() -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("19262b")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("839ca6")
	environment.ambient_light_energy = 0.60
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	_environment.environment = environment


func _set_camera_yaw(yaw: float) -> void:
	_camera_rig.position = CAMERA_TARGET
	_camera.position = (CAMERA_HOME - CAMERA_TARGET).rotated(Vector3.UP, yaw)
	_camera.look_at(CAMERA_TARGET, Vector3.UP)


func _mesh_count(node: Node) -> int:
	var total := 1 if node is MeshInstance3D and (node as MeshInstance3D).mesh != null else 0
	for child in node.get_children():
		total += _mesh_count(child)
	return total
