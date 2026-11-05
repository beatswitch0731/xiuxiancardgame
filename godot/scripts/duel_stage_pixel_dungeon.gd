extends SubViewportContainer

# Alternate presentation adapter for the real first fight. CombatDomain owns
# cards, HP and outcomes; this node only turns events into visible 2D action.
signal presentation_finished(event_type: String)
signal presentation_missing(event_type: String, reason: String)
signal contact_frame(side: String)

const PLAYER_HOME := Vector2(241, 244)
const ENEMY_HOME := Vector2(407, 237)
const LIGHT_POSITIONS := [
	Vector2(145, 87), Vector2(495, 87), Vector2(145, 273), Vector2(495, 273)
]
const MODULAR_ACTOR_SCRIPT_PATH := "res://scripts/modular_pixel_actor.gd"
const QINGYUN_ROOM_PATH := "res://assets/characters/modular_pixel_actor_v1/qingyun_trial_hall_candidate.png"

@export var modular_actor_demo_preview := false
@export var player_attack_travel := 90.0
@export var enemy_attack_travel := -84.0
@export var player_home := PLAYER_HOME
@export var enemy_home := ENEMY_HOME
@export var player_hit_position := Vector2(382, 215)
@export var enemy_hit_position := Vector2(272, 218)

@onready var _player_anchor: Node2D = $Viewport/World/PlayerAnchor
@onready var _enemy_anchor: Node2D = $Viewport/World/EnemyAnchor
@onready var _player: AnimatedSprite2D = $Viewport/World/PlayerAnchor/Sprite
@onready var _enemy: AnimatedSprite2D = $Viewport/World/EnemyAnchor/Sprite
@onready var _fx: Node2D = $Viewport/World/HitFX

var _pending: Array[Dictionary] = []
var _draining := false
var _lights: Array[PointLight2D] = []
var _light_time := 0.0
var _context: Dictionary = {}
var _camera: Camera2D
var _modular_actor: Node2D
var _actor_study_variant := "old_frames"


func _ready() -> void:
	if modular_actor_demo_preview:
		stretch_shrink = 1
		$Viewport/World.scale = Vector2.ONE * 2.0
		_enemy.scale = Vector2.ONE * 0.42
	_player.frame_changed.connect(func() -> void: _align_feet(_player))
	_enemy.frame_changed.connect(func() -> void: _align_feet(_enemy))
	_player.animation_changed.connect(func() -> void: _align_feet(_player))
	_enemy.animation_changed.connect(func() -> void: _align_feet(_enemy))
	_player.play("idle")
	_enemy.play("idle")
	_align_feet(_player)
	_align_feet(_enemy)
	if modular_actor_demo_preview:
		$Viewport/World/Room.visible = false
		var letterbox := ColorRect.new()
		letterbox.name = "Letterbox"
		letterbox.color = Color("05070c")
		letterbox.position = Vector2(-1000, -1000)
		letterbox.size = Vector2(2640, 2400)
		letterbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		$Viewport/World.add_child(letterbox)
		$Viewport/World.move_child(letterbox, 0)
		var room_art := Sprite2D.new()
		room_art.name = "QingyunRoomCandidate"
		var qingyun_room: Texture2D = load(QINGYUN_ROOM_PATH)
		room_art.texture = qingyun_room
		room_art.position = Vector2(320, 200)
		room_art.scale = Vector2(640.0 / qingyun_room.get_width(), 400.0 / qingyun_room.get_height())
		room_art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		$Viewport/World.add_child(room_art)
		$Viewport/World.move_child(room_art, 1)
		$Viewport/World/NightTint.color = Color(0.96, 0.97, 1.0)
		var modular_script: Script = load(MODULAR_ACTOR_SCRIPT_PATH)
		_modular_actor = modular_script.new()
		_player_anchor.add_child(_modular_actor)
		set_actor_study_variant("practice_sword")
	_build_lights()
	_fx.set_script(load("res://scripts/pixel_dungeon_hit_fx.gd"))
	_camera = Camera2D.new()
	_camera.position = Vector2(320, 200)
	$Viewport/World.add_child(_camera)
	_camera.make_current()
	$Viewport.size_changed.connect(_update_camera)
	_update_camera()


func _process(delta: float) -> void:
	_light_time += delta
	for index in _lights.size():
		_lights[index].energy = (0.55 if modular_actor_demo_preview else 1.35) \
			+ 0.08 * sin(_light_time * 8.0 + float(index) * 1.8)


func _update_camera() -> void:
	if _camera == null:
		return
	var view_size: Vector2 = $Viewport.size
	var fit := minf(view_size.x / (1280.0 if modular_actor_demo_preview else 640.0),
		view_size.y / (800.0 if modular_actor_demo_preview else 400.0))
	_camera.zoom = Vector2.ONE * fit


func bind_stage_context(context: Dictionary) -> bool:
	_context = context.duplicate(true)
	return not _context.is_empty() and String(_context.get("battlefieldId", "")) != ""


func has_hd2d_assets() -> bool:
	if _player == null or _enemy == null or _player.sprite_frames == null or _enemy.sprite_frames == null:
		return false
	for clip in ["idle", "attack", "guard", "reaction", "hurt", "defeat",
			"sword_probe", "sword_followthrough", "sword_edge", "sword_guard", "sword_sheath_guard"]:
		if not _player.sprite_frames.has_animation(clip) or _player.sprite_frames.get_frame_count(clip) == 0:
			return false
	for clip in ["idle", "attack", "guard", "hurt", "defeat"]:
		if not _enemy.sprite_frames.has_animation(clip) or _enemy.sprite_frames.get_frame_count(clip) == 0:
			return false
	return _player.sprite_frames.get_frame_count("sword_probe") == 6 \
		and _enemy.sprite_frames.get_frame_count("attack") == 4


func get_actor_sprite(side: String) -> AnimatedSprite2D:
	return _player if side == "player" else _enemy if side == "enemy" else null


func set_actor_study_variant(value: String) -> bool:
	if _modular_actor == null or not value in ["old_frames", "unarmed", "practice_sword", "traded_rusted_sword"]:
		return false
	_actor_study_variant = value
	_player.visible = value == "old_frames"
	_modular_actor.visible = value != "old_frames"
	if value != "old_frames":
		_modular_actor.call("set_variant", value)
	return true


func set_actor_study_armor(definition_id: String) -> bool:
	if _modular_actor == null:
		return false
	return _modular_actor.call("set_armor", definition_id)


func present_action(event: Dictionary) -> bool:
	var kind := String(event.get("type", ""))
	if not kind in ["CARD_PLAY", "ENEMY_ACTION", "DEFEAT"]:
		return false
	var clip := "defeat"
	if kind == "CARD_PLAY":
		clip = _card_clip(String(event.get("cardId", "")))
	elif kind == "ENEMY_ACTION":
		var intent: Dictionary = event.get("intent", {})
		clip = "attack" if String(intent.get("type", "")) == "attack" else "guard"
	var actor := _enemy if kind == "ENEMY_ACTION" else _player
	if actor == null or not actor.sprite_frames.has_animation(clip):
		presentation_missing.emit(kind, "Pixel dungeon source clip missing: " + clip)
		return false
	_pending.append(event.duplicate(true))
	if not _draining:
		call_deferred("_drain_presentations")
	return true


func _drain_presentations() -> void:
	if _draining:
		return
	_draining = true
	while not _pending.is_empty():
		var event: Dictionary = _pending.pop_front()
		await _play_event(event)
		presentation_finished.emit(String(event.get("type", "")))
	_draining = false


func _play_event(event: Dictionary) -> void:
	var kind := String(event.get("type", ""))
	_source_audio_action(event)
	if kind == "CARD_PLAY":
		var card_id := String(event.get("cardId", ""))
		var clip := _card_clip(card_id)
		var hp_loss := 0
		var block_spent := 0
		for effect in event.get("effects", []):
			if effect is Dictionary and effect.get("type") == "damage":
				hp_loss += int(effect.get("hpLoss", 0))
				block_spent += int(effect.get("blockSpent", 0))
		var damage := hp_loss > 0 or block_spent > 0
		var guard_card := card_id in ["sword_guard", "sword_sheath_guard"]
		var victim_clip := "hurt" if hp_loss > 0 else "guard" if block_spent > 0 else ""
		await _play_clip("player", clip, damage or guard_card, guard_card, victim_clip)
		if bool(event.get("victory", false)):
			_enemy.play("defeat")
			_align_feet(_enemy)
		elif damage:
			_enemy.play("idle")
			_align_feet(_enemy)
	elif kind == "ENEMY_ACTION":
		var intent: Dictionary = event.get("intent", {})
		var clip := "attack" if String(intent.get("type", "")) == "attack" else "guard"
		var reaction_id := String(event.get("reactionId", "TAKE_HIT"))
		var hp_loss := int(event.get("hpLoss", 0))
		if clip == "attack" and reaction_id in ["EVADE", "DEFLECT", "GUARD"]:
			_player.play("guard" if reaction_id == "GUARD" else "reaction")
			_align_feet(_player)
			_show_modular_pose("guard" if reaction_id == "GUARD" else "idle")
		var victim_clip := "hurt" if hp_loss > 0 else "" if reaction_id in ["EVADE", "DEFLECT", "GUARD"] else "guard"
		await _play_clip("enemy", clip, clip == "attack", clip != "attack", victim_clip)
		if clip == "attack":
			_player.play("idle")
			_align_feet(_player)
			_show_modular_pose("idle")
	else:
		await _play_clip("player", "defeat", false, false)


func _play_clip(side: String, clip: String, has_contact: bool, self_contact: bool, victim_clip := "") -> void:
	var sprite := _player if side == "player" else _enemy
	var anchor := _player_anchor if side == "player" else _enemy_anchor
	var home := player_home if side == "player" else enemy_home
	var duration := _clip_duration(sprite.sprite_frames, clip)
	var contact_at := _contact_time(sprite.sprite_frames, clip, duration)
	anchor.position = home
	sprite.play(clip)
	_align_feet(sprite)
	if side == "player":
		_show_modular_pose(clip)
	var moving := has_contact and not self_contact and clip != "guard"
	if moving:
		var toward := player_attack_travel if side == "player" else enemy_attack_travel
		var motion := create_tween()
		motion.tween_property(anchor, "position", home + Vector2(toward, -3), contact_at).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		motion.tween_property(anchor, "position", home, maxf(0.18, duration - contact_at + 0.14)).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	if has_contact:
		await get_tree().create_timer(contact_at).timeout
		_source_audio_contact(side)
		contact_frame.emit(side)
		if not self_contact:
			if victim_clip != "":
				var victim := _enemy if side == "player" else _player
				victim.play(victim_clip)
				_align_feet(victim)
				if side == "enemy":
					_show_modular_pose(victim_clip)
			var hit_position := Vector2(397, 198) if side == "player" and _actor_study_variant != "old_frames" \
				else player_hit_position if side == "player" else enemy_hit_position
			_fx.call("burst", hit_position, side == "player")
		await get_tree().create_timer(maxf(0.08, duration - contact_at + 0.14)).timeout
	else:
		await get_tree().create_timer(duration + 0.08).timeout
	anchor.position = home
	if clip != "defeat":
		sprite.play("idle")
		_align_feet(sprite)
		if side == "player":
			_show_modular_pose("idle")


func _source_audio_action(_event: Dictionary) -> void:
	pass


func _source_audio_contact(_side: String) -> void:
	pass


func _show_modular_pose(clip: String) -> void:
	if _modular_actor != null:
		_modular_actor.call("set_pose", clip)


func _card_clip(card_id: String) -> String:
	if _player != null and _player.sprite_frames.has_animation(card_id):
		return card_id
	if card_id in ["sword_guard", "sword_sheath_guard"]:
		return "guard"
	return "attack"


func _clip_duration(frames: SpriteFrames, clip: String) -> float:
	var duration := 0.0
	for index in frames.get_frame_count(clip):
		duration += frames.get_frame_duration(clip, index) / frames.get_animation_speed(clip)
	return maxf(0.16, duration)


func _contact_time(frames: SpriteFrames, clip: String, duration: float) -> float:
	var impact_frame := int(frames.get_meta("impact_frame_" + clip, -1))
	if impact_frame < 0:
		return duration * 0.47
	var elapsed := 0.0
	for index in mini(impact_frame, frames.get_frame_count(clip)):
		elapsed += frames.get_frame_duration(clip, index) / frames.get_animation_speed(clip)
	return clampf(elapsed, 0.08, duration - 0.04)


func _align_feet(sprite: AnimatedSprite2D) -> void:
	if sprite.sprite_frames == null or sprite.animation == "":
		return
	var frame_texture := sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)
	if frame_texture == null:
		return
	var foot_fraction := float(sprite.sprite_frames.get_meta("foot_%s_%d" % [sprite.animation, sprite.frame], 0.91))
	var frame_height := frame_texture.get_size().y
	sprite.offset = Vector2(0.0, frame_height * (0.5 - foot_fraction))


func _build_lights() -> void:
	var image := Image.create(128, 128, false, Image.FORMAT_RGBA8)
	for y in 128:
		for x in 128:
			var distance := Vector2(float(x) - 63.5, float(y) - 63.5).length() / 63.5
			var falloff := pow(maxf(0.0, 1.0 - distance), 1.35)
			image.set_pixel(x, y, Color(1.0, 1.0, 1.0, falloff))
	var texture := ImageTexture.create_from_image(image)
	var positions := [Vector2(194, 85), Vector2(442, 85), Vector2(96, 307), Vector2(520, 307)] \
		if modular_actor_demo_preview else LIGHT_POSITIONS
	for position_2d in positions:
		var light := PointLight2D.new()
		light.texture = texture
		light.texture_scale = 1.75
		light.color = Color(1.0, 0.52, 0.19)
		light.energy = 1.35
		light.position = position_2d
		$Viewport/World.add_child(light)
		_lights.append(light)

