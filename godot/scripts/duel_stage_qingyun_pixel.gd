extends "res://scripts/duel_stage_pixel_dungeon.gd"

# Keep the approved painted room. Runtime code only places the authored art;
# it does not redraw the room's bricks, torches or stone texture.
const SCENE_PROFILE_PATH := "res://assets/battle/undercurrent_pixel_v1/qingyun_scene_profile_v1.json"
const FX_PROFILE_PATH := "res://assets/battle/undercurrent_pixel_v1/skill_fx_profiles_v1.json"
const Registry = preload("res://scripts/runtime_data_registry.gd")
const HERO_SCALE := 1.0
const ENEMY_SCALE := 1.0

@export_file("*.json") var scene_profile_path := SCENE_PROFILE_PATH

var _contact_tween: Tween
var _foot_shadows: Dictionary = {}
var _victory_cue_queued := false
var _victory_cue_played := false
var _source_action_sfx: AudioStreamPlayer
var _source_contact_sfx: AudioStreamPlayer
var _audio_cues: Dictionary = {}
var _audio_runtime: Dictionary = {}
var _audio_streams: Dictionary = {}
var _active_contact_cue := ""
var _source_contact_ms: Dictionary = {}
var _fx_profiles: Dictionary = {}
var _active_fx_contact_self := false
var _scene_profile: Dictionary = {}


func bind_stage_context(context: Dictionary) -> bool:
	if not super.bind_stage_context(context):
		return false
	return _load_source_audio()


func _load_source_audio() -> bool:
	var registry = Registry.new()
	var actions: Dictionary = registry.read_json("data/combat/action_presentations.json")
	var catalog: Dictionary = registry.read_json("data/audio/path_identity.json")
	if catalog.get("assetRoot") != "assets/audio/":
		return false
	_audio_runtime.clear()
	_audio_streams.clear()
	_audio_cues.clear()
	_source_contact_ms.clear()
	_index_audio_runtime(catalog)
	if not _load_audio_cue("sfx_treasure"):
		return false
	for card_id in registry.read_json("data/combat/deck_progression.json").get(
			"paths", {}).get("sword", {}).get("starterDeck", []):
		var action: Dictionary = actions.get("cardActions", {}).get(card_id, {})
		if action.is_empty():
			action = actions.get("paths", {}).get("sword", {}).get("guard", {})
		if not _register_audio("card:" + String(card_id), action, actions, true):
			return false
		_record_contact_time("player:" + String(card_id), action, actions,
			"guard" if card_id in ["sword_guard", "sword_sheath_guard"] else "attack")
	for family in ["attack", "guard"]:
		var action: Dictionary = actions.get("encounters", {}).get(
			"enc_trial_sword_swift", {}).get(family, {})
		if not _register_audio("enemy:" + family, action, actions, family == "attack"):
			return false
		_record_contact_time("enemy:" + family, action, actions, family)
	return true


func _record_contact_time(key: String, action: Dictionary, actions: Dictionary,
		family: String) -> void:
	var fallback: Dictionary = actions.get("stageContracts", {}).get(family, {})
	var stage: Dictionary = action.get("stage", {})
	var ms := int(stage.get("impactAtMs", fallback.get("impactAtMs", 0)))
	if ms > 0:
		_source_contact_ms[key] = ms


func _contact_time(frames: SpriteFrames, clip: String, duration: float) -> float:
	var side := "player" if frames == _player.sprite_frames else "enemy"
	var ms := int(_source_contact_ms.get(side + ":" + clip, 0))
	if ms > 0:
		return clampf(float(ms) / 1000.0, 0.08, duration - 0.04)
	return super._contact_time(frames, clip, duration)


func _register_audio(key: String, action: Dictionary, actions: Dictionary,
		has_contact: bool) -> bool:
	var cues: Dictionary = actions.get("sfxCues", {}).get(String(action.get("sfxCueId", "")), {})
	if cues.is_empty():
		return false
	var start_id := String(cues.get("actionStarted", ""))
	var contact_id := String(cues.get("impact", cues.get("statusApplied", ""))) if has_contact else ""
	if start_id.is_empty():
		return false
	for cue_id in [start_id, contact_id]:
		if not cue_id.is_empty() and not _load_audio_cue(cue_id):
			return false
	_audio_cues[key] = {"start": start_id, "contact": contact_id}
	return true


func _index_audio_runtime(value: Variant) -> void:
	if value is Dictionary:
		var runtime: Variant = value.get("runtime")
		if runtime is Dictionary and runtime.get("id") is String:
			_audio_runtime[runtime["id"]] = runtime
		for child in value.values():
			_index_audio_runtime(child)
	elif value is Array:
		for child in value:
			_index_audio_runtime(child)


func _load_audio_cue(cue_id: String) -> bool:
	if _audio_streams.has(cue_id):
		return true
	var runtime: Dictionary = _audio_runtime.get(cue_id, {})
	var relative := String(runtime.get("path", ""))
	if runtime.get("bus") != "sfx" or relative.is_empty() \
			or relative.begins_with("/") or ".." in relative.split("/"):
		return false
	var stream = load("res://content/assets/audio/" + relative)
	if not stream is AudioStream:
		return false
	_audio_streams[cue_id] = stream
	return true


func _play_source_cue(cue_id: String, player: AudioStreamPlayer) -> void:
	if cue_id.is_empty() or player == null or not _audio_streams.has(cue_id):
		return
	var runtime: Dictionary = _audio_runtime[cue_id]
	player.stop()
	player.stream = _audio_streams[cue_id]
	player.volume_db = linear_to_db(maxf(0.5 * float(runtime.get("volume", 1.0)), 0.001))
	player.play()


func _ready() -> void:
	_scene_profile = JSON.parse_string(FileAccess.get_file_as_string(scene_profile_path))
	modular_actor_demo_preview = false
	player_home = Vector2(290, 244)
	enemy_home = Vector2(420, 237)
	player_hit_position = Vector2(420, 209)
	enemy_hit_position = Vector2(290, 218)
	player_attack_travel = 55.0
	enemy_attack_travel = -55.0
	super._ready()
	$Viewport/World.y_sort_enabled = true
	$Viewport/World/Room.visible = false
	var letterbox := ColorRect.new()
	letterbox.name = "Letterbox"
	letterbox.color = Color("05070c")
	letterbox.position = Vector2(-1000, -1000)
	letterbox.size = Vector2(2640, 2400)
	letterbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	letterbox.z_index = -21
	$Viewport/World.add_child(letterbox)
	$Viewport/World.move_child(letterbox, 0)
	var room := Sprite2D.new()
	room.name = "QingyunRoomNative"
	var background: Dictionary = _scene_profile["background"]
	var rect_values: Array = background["displayRect"]
	var display := Rect2(rect_values[0], rect_values[1], rect_values[2], rect_values[3])
	room.texture = load(background["texture"])
	room.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	room.position = display.get_center()
	room.scale = display.size / room.texture.get_size()
	room.z_index = -20
	$Viewport/World.add_child(room)
	$Viewport/World.move_child(room, 1)
	# Render only the authored column silhouette from the exact approved image.
	# Its base is the depth-sorting origin; surrounding floor pixels never mask actors.
	for spec in _scene_profile["foreground"]:
		var values: Array = spec["sourceRect"]
		var region := Rect2(values[0], values[1], values[2], values[3])
		var foreground := Polygon2D.new()
		foreground.name = spec["name"]
		foreground.texture = room.texture
		foreground.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		foreground.scale = room.scale
		var source_base := Vector2(spec["sortBaseSource"][0], spec["sortBaseSource"][1])
		foreground.position = display.position + source_base * room.scale
		var silhouette := PackedVector2Array()
		var texture_uv := PackedVector2Array()
		for point in spec["silhouetteInRegion"]:
			var source_pixel := region.position + Vector2(point[0], point[1])
			silhouette.append(source_pixel - source_base)
			texture_uv.append(source_pixel)
		foreground.polygon = silhouette
		foreground.uv = texture_uv
		foreground.z_index = 1
		$Viewport/World.add_child(foreground)
	_fx.z_index = 11
	_player_anchor.position = player_home
	_enemy_anchor.position = enemy_home
	_player_anchor.z_index = 1
	_enemy_anchor.z_index = 1
	_player_anchor.get_node("Shadow").visible = false
	_enemy_anchor.get_node("Shadow").visible = false
	_create_foot_shadows("player", _player_anchor, _player)
	_create_foot_shadows("enemy", _enemy_anchor, _enemy)
	# Render the entire stage, actors and FX on the same native pixel grid.
	stretch_shrink = 2
	$Viewport/World.scale = Vector2.ONE
	_update_camera()
	$Viewport/World/NightTint.color = Color.WHITE
	for light in _lights:
		light.visible = false # Baked torch lighting already belongs to the room art.
	_player.scale = Vector2.ONE * HERO_SCALE
	_enemy.scale = Vector2.ONE * ENEMY_SCALE
	_player.z_index = 0
	_enemy.z_index = 0
	_align_feet(_player)
	_align_feet(_enemy)
	_fx.set_script(load("res://scripts/undercurrent_hit_fx.gd"))
	var fx_document: Variant = JSON.parse_string(FileAccess.get_file_as_string(FX_PROFILE_PATH))
	if not fx_document is Dictionary or not _fx.call("configure", fx_document):
		push_error("Missing or invalid Qingyun pixel FX profiles")
		return
	_fx_profiles = fx_document["profiles"]
	_source_action_sfx = AudioStreamPlayer.new()
	_source_action_sfx.name = "SourceActionSfx"
	add_child(_source_action_sfx)
	_source_contact_sfx = AudioStreamPlayer.new()
	_source_contact_sfx.name = "SourceContactSfx"
	add_child(_source_contact_sfx)
	contact_frame.connect(_on_contact_frame)


func _update_camera() -> void:
	if _camera == null:
		return
	# The SubViewportContainer supplies a 2x integer window scale. Narrow windows
	# reveal less of the native room rather than resampling its pixels at 0.8x.
	_camera.zoom = Vector2.ONE


func _process(_delta: float) -> void:
	# Three discrete room-light values keep actors on the room's pixel palette.
	for side in ["player", "enemy"]:
		var anchor := _player_anchor if side == "player" else _enemy_anchor
		var sprite := _player if side == "player" else _enemy
		var nearest := 1000.0
		for point in _scene_profile["actorTint"]["lightPoints"]:
			var lamp := Vector2(point[0], point[1])
			nearest = minf(nearest, anchor.position.distance_to(lamp))
		sprite.modulate = Color.WHITE
		for band in _scene_profile["actorTint"]["bands"]:
			if nearest < float(band["radius"]):
				var rgb: Array = band["rgb"]
				sprite.modulate = Color(rgb[0], rgb[1], rgb[2])
				break


func get_scene_layout(layout_id: String) -> Dictionary:
	return _scene_profile["reviewLayouts"].get(layout_id, {}).duplicate(true)


func _source_audio_action(event: Dictionary) -> void:
	var key := ""
	var profile_id := ""
	var kind := String(event.get("type", ""))
	if kind == "CARD_PLAY":
		profile_id = String(event.get("cardId", "")).trim_suffix("+")
		key = "card:" + profile_id
	elif kind == "ENEMY_ACTION":
		var intent: Dictionary = event.get("intent", {})
		profile_id = "enemy_attack" if String(intent.get("type", "")) == "attack" else "enemy_guard"
		key = "enemy:attack" if profile_id == "enemy_attack" else "enemy:guard"
	_active_fx_contact_self = false
	if not profile_id.is_empty():
		if not _fx.call("set_profile", profile_id):
			push_error("Qingyun pixel FX profile missing for " + profile_id)
		else:
			_active_fx_contact_self = String(_fx_profiles[profile_id].get("contact", "")) == "self"
	var cues: Dictionary = _audio_cues.get(key, {})
	_active_contact_cue = String(cues.get("contact", ""))
	_play_source_cue(String(cues.get("start", "")), _source_action_sfx)


func _source_audio_contact(side: String) -> void:
	_play_source_cue(_active_contact_cue, _source_contact_sfx)
	_active_contact_cue = ""
	if _active_fx_contact_self:
		_fx.call("burst", player_home if side == "player" else enemy_home, side == "player")


func _align_feet(sprite: AnimatedSprite2D) -> void:
	if sprite.sprite_frames == null or sprite.animation == "":
		return
	var texture := sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)
	if texture == null:
		return
	var pivot_x := float(sprite.sprite_frames.get_meta("pivot_x", 40.0))
	var pivot_y := float(sprite.sprite_frames.get_meta("pivot_y", 70.0))
	sprite.offset = texture.get_size() * 0.5 - Vector2(pivot_x, pivot_y)
	_update_foot_shadows(sprite)


func _create_foot_shadows(side: String, anchor: Node2D, sprite: AnimatedSprite2D) -> void:
	var pair: Array[Polygon2D] = []
	for foot in ["left_foot", "right_foot"]:
		var shadow := Polygon2D.new()
		shadow.name = "Contact_" + foot
		shadow.color = Color(0.025, 0.031, 0.043, 0.72)
		shadow.polygon = PackedVector2Array([
			Vector2(-5, 0), Vector2(-3, -2), Vector2(3, -2),
			Vector2(5, 0), Vector2(3, 2), Vector2(-3, 2)])
		shadow.z_index = -1
		anchor.add_child(shadow)
		pair.append(shadow)
	_foot_shadows[side] = pair
	_update_foot_shadows(sprite)


func _update_foot_shadows(sprite: AnimatedSprite2D) -> void:
	var side := "player" if sprite == _player else "enemy"
	if not _foot_shadows.has(side):
		return
	var frames := sprite.sprite_frames
	var pivot := Vector2(float(frames.get_meta("pivot_x", 40.0)),
		float(frames.get_meta("pivot_y", 70.0)))
	var pair: Array = _foot_shadows[side]
	var grounded: Array = frames.get_meta("grounded_%s_%d" % [sprite.animation, sprite.frame],
		["left", "right"])
	for index in 2:
		var foot_name := "left" if index == 0 else "right"
		var key := ("left_foot" if index == 0 else "right_foot") + "_%s_%d" % [sprite.animation, sprite.frame]
		pair[index].position = (frames.get_meta(key, pivot) as Vector2) - pivot + Vector2(0, 1)
		pair[index].visible = foot_name in grounded


func _marker_world(sprite: AnimatedSprite2D, marker: String, frame: int,
		anchor_position: Vector2) -> Vector2:
	var frames := sprite.sprite_frames
	var pivot := Vector2(float(frames.get_meta("pivot_x", 40.0)),
		float(frames.get_meta("pivot_y", 70.0)))
	var key := "%s_%s_%d" % [marker, sprite.animation, frame]
	return anchor_position + (frames.get_meta(key, pivot) as Vector2) - pivot


func _play_clip(side: String, clip: String, has_contact: bool, self_contact: bool,
		victim_clip := "") -> void:
	if side != "player" or clip != "sword_probe":
		await super._play_clip(side, clip, has_contact, self_contact, victim_clip)
		return
	var sprite := _player
	var frames := sprite.sprite_frames
	var travel := float(frames.get_meta("probe_travel", 55.0))
	var launch := roundf(travel * 0.4)
	var offsets := [0.0, 0.0, launch, travel, travel, 0.0]
	sprite.stop()
	sprite.animation = clip
	for index in offsets.size():
		sprite.frame = index
		_player_anchor.position = player_home + Vector2(offsets[index], 0)
		_align_feet(sprite)
		if index == 3 and has_contact:
			_source_audio_contact("player")
			contact_frame.emit("player")
			if victim_clip != "":
				_enemy.play(victim_clip)
				_align_feet(_enemy)
			var hand := _marker_world(sprite, "hand_grip", index, _player_anchor.position)
			var tip := _marker_world(sprite, "weapon_tip", index, _player_anchor.position)
			var line_start := tip - (tip - hand).normalized() * 14.0
			_fx.call("burst_segment", line_start.round(), tip.round(), true)
		var frame_seconds := frames.get_frame_duration(clip, index) / frames.get_animation_speed(clip)
		var root_motion: Tween
		if index == 1:
			root_motion = _tween_probe_root(0.0, launch, frame_seconds)
		elif index == 2:
			root_motion = _tween_probe_root(launch, travel, frame_seconds)
		elif index == 4:
			root_motion = _tween_probe_root(travel, 0.0, frame_seconds)
		await get_tree().create_timer(frame_seconds).timeout
		if root_motion != null and root_motion.is_running():
			root_motion.kill()
	_player_anchor.position = player_home
	_enemy_anchor.position = enemy_home
	sprite.play("idle")
	_align_feet(sprite)


func _tween_probe_root(from_x: float, to_x: float, seconds: float) -> Tween:
	var motion := create_tween()
	motion.tween_method(func(offset_x: float) -> void:
		_player_anchor.position = player_home + Vector2(roundf(offset_x), 0.0),
		from_x, to_x, seconds).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	return motion


func _on_contact_frame(side: String) -> void:
	if _camera == null:
		return
	if side == "player" and _player.animation in ["sword_guard", "sword_sheath_guard", "guard"]:
		return
	if _contact_tween != null and _contact_tween.is_running():
		_contact_tween.kill()
	_camera.position = Vector2(320, 200)
	_contact_tween = create_tween()
	_contact_tween.tween_property(_camera, "position", Vector2(316, 200) if side == "player" else Vector2(324, 200), 0.035)
	_contact_tween.tween_property(_camera, "position", Vector2(320, 200), 0.14).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func queue_victory_cue() -> void:
	if _victory_cue_queued or _victory_cue_played:
		return
	_victory_cue_queued = true
	call_deferred("_flush_victory_cue")


func _flush_victory_cue() -> void:
	if not _victory_cue_queued or _victory_cue_played:
		return
	if _draining or not _pending.is_empty():
		await get_tree().process_frame
		_flush_victory_cue()
		return
	_victory_cue_queued = false
	_victory_cue_played = true
	_play_source_cue("sfx_treasure", _source_action_sfx)
