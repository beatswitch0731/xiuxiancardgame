extends Node3D

# Presentation adapter. CombatDomain owns outcomes; this node plays the
# browser-authored SpriteFrames inside a spatial Godot battlefield.
signal action_finished(clip: String)
signal contact_key(clip: String)

@export_enum("hero", "dummy") var fighter_kind := "hero"
@export var pixel_snap_visual := false

const SOURCE_PIXEL_SIZE := 0.009
const SOURCE_ACTIONS_PATH := "res://content/data/combat/action_presentations.json"
# Pixel coordinates are read from the original S1 sequence canvases, ordered by
# frame. They are attachment data for VFX/root motion, not replacement art.
const S1_BLADE_TIPS := {
	"sword_probe": [Vector2(226, 238), Vector2(108, 255), Vector2(249, 193),
		Vector2(319, 173), Vector2(274, 233), Vector2(238, 206)],
	"sword_followthrough": [Vector2(382, 206), Vector2(321, 208),
		Vector2(351, 99), Vector2(266, 207)],
	"sword_edge": [Vector2(251, 272), Vector2(293, 194),
		Vector2(353, 221), Vector2(251, 272)],
}
# The browser's 220 ms followthrough cue lands on a raised recovery pose.
# 180 ms is the visible horizontal blade strike in the same authored sequence.
const VISUAL_CONTACT_OVERRIDE := {"sword_followthrough": 0.180}

static var _source_contact_times: Dictionary = {}
static var _source_contact_times_loaded := false

@onready var _sprite: AnimatedSprite3D = $AnimatedSprite3D
@onready var _animation_player: AnimationPlayer = $AnimationPlayer
@onready var _sword_tip: Marker3D = $SwordTip
@onready var _chest_hit: Marker3D = $ChestHit

var _active_clip := ""
var _contact_emitted := false
var _blade_tip_local := Vector3.ZERO
var _sprite_base_height := 0.0


func _ready() -> void:
	if _sprite.sprite_frames == null:
		push_error("HD-2D fighter has no source SpriteFrames")
		return
	_build_animation_clock()
	_sprite.frame_changed.connect(_on_frame_changed)
	_sprite.animation_finished.connect(_on_animation_finished)
	_sprite.animation_changed.connect(_align_feet)
	play_action("idle")


func _process(_delta: float) -> void:
	if _contact_emitted or _active_clip == "" or _sprite.speed_scale == 0.0:
		return
	var contact_time := get_contact_time(_active_clip)
	if contact_time >= 0.0 and get_playback_time() >= contact_time:
		_contact_emitted = true
		contact_key.emit(_active_clip)


func get_sprite() -> AnimatedSprite3D:
	return _sprite


func has_action(clip: String) -> bool:
	return _sprite.sprite_frames != null and _sprite.sprite_frames.has_animation(clip) \
		and _sprite.sprite_frames.get_frame_count(clip) > 0


func play_action(clip: String) -> bool:
	if not has_action(clip) or not _animation_player.has_animation(clip):
		return false
	_active_clip = clip
	_contact_emitted = false
	_sprite.play(clip)
	_animation_player.play(clip)
	_align_feet()
	return true


func get_contact_time(clip: String) -> float:
	if not has_action(clip):
		return -1.0
	if fighter_kind == "hero":
		if VISUAL_CONTACT_OVERRIDE.has(clip):
			return float(VISUAL_CONTACT_OVERRIDE[clip])
		_load_source_contact_times()
		if _source_contact_times.has(clip):
			return float(_source_contact_times[clip]) / 1000.0
	var index := _impact_index(clip)
	if index < 0:
		return -1.0
	var elapsed := 0.0
	for frame in index:
		elapsed += _sprite.sprite_frames.get_frame_duration(clip, frame) \
			/ _sprite.sprite_frames.get_animation_speed(clip)
	return elapsed


func _load_source_contact_times() -> void:
	if _source_contact_times_loaded:
		return
	_source_contact_times_loaded = true
	var source_file := FileAccess.open(SOURCE_ACTIONS_PATH, FileAccess.READ)
	if source_file == null:
		push_error("Missing source combat action timings: " + SOURCE_ACTIONS_PATH)
		return
	var parsed = JSON.parse_string(source_file.get_as_text())
	if not parsed is Dictionary:
		push_error("Invalid source combat action timings: " + SOURCE_ACTIONS_PATH)
		return
	for card_id in parsed.get("cardActions", {}):
		var card_action: Dictionary = parsed["cardActions"][card_id]
		var stage: Dictionary = card_action.get("stage", {})
		if stage.has("impactAtMs") and String(stage.get("contact", "")) in ["melee", "self"]:
			_source_contact_times[String(card_id)] = float(stage["impactAtMs"])
	_source_contact_times["sword_guard"] = float(parsed.get("stageContracts", {}).get("guard", {}).get("impactAtMs", 180))


func get_animation_player() -> AnimationPlayer:
	return _animation_player


func get_playback_time() -> float:
	if _sprite.sprite_frames == null or _active_clip == "":
		return 0.0
	var elapsed := 0.0
	for frame in _sprite.frame:
		elapsed += _sprite.sprite_frames.get_frame_duration(_active_clip, frame) \
			/ _sprite.sprite_frames.get_animation_speed(_active_clip)
	var frame_length := _sprite.sprite_frames.get_frame_duration(_active_clip, _sprite.frame) \
		/ _sprite.sprite_frames.get_animation_speed(_active_clip)
	return elapsed + frame_length * _sprite.frame_progress


func get_sword_tip() -> Marker3D:
	return _sword_tip


func sync_billboard_attachment(camera: Camera3D) -> void:
	# Sprite3D's billboard rotates the visible image in the camera plane.
	# A plain child Marker3D would stay in actor space and drift off the blade
	# when the diagnostic camera turns or the actor rotates during a strike.
	if pixel_snap_visual and camera != null:
		# 3D world movement is continuous; only the rendered sprite is snapped.
		# Reset first, otherwise each frame would accumulate the prior offset.
		_sprite.scale = Vector3.ONE
		_sprite.position = Vector3(0.0, _sprite_base_height, 0.0)
		var foot := global_position
		if not camera.is_position_behind(foot):
			var screen_foot := camera.unproject_position(foot)
			var snapped := screen_foot.round()
			var depth := (foot - camera.global_position).dot(-camera.global_basis.z)
			_sprite.global_position += camera.project_position(snapped, depth) - foot
	if camera == null or fighter_kind != "hero" or not _has_blade_tip(_active_clip):
		return
	var camera_basis := camera.global_transform.basis.orthonormalized()
	var actor_scale := global_transform.basis.get_scale()
	var pixel_y_from_center := _blade_tip_local.y - _sprite.position.y
	_sword_tip.global_position = _sprite.global_position \
		+ camera_basis.x * (_blade_tip_local.x * actor_scale.x) \
		+ camera_basis.y * (pixel_y_from_center * actor_scale.y)


func get_chest_hit() -> Marker3D:
	return _chest_hit


func get_chest_point_for(clip: String, frame: int, camera: Camera3D) -> Vector3:
	# A frame may shift the torso within its transparent canvas. A reviewed
	# per-frame source pixel anchor travels with the art instead of staying at
	# the actor origin when the clip changes.
	var key := "chest_%s_%d" % [clip, frame]
	if camera == null or not _sprite.sprite_frames.has_meta(key):
		return _chest_hit.global_position
	var texture := _sprite.sprite_frames.get_frame_texture(clip, frame)
	if texture == null:
		return _chest_hit.global_position
	var canvas_width := float(_sprite.sprite_frames.get_meta("canvas_width_%s_%d" % [clip, frame], texture.get_width()))
	var canvas_height := float(_sprite.sprite_frames.get_meta("canvas_height_%s_%d" % [clip, frame], texture.get_height()))
	var foot := float(_sprite.sprite_frames.get_meta("foot_%s_%d" % [clip, frame], 0.9125))
	var pixel_size := SOURCE_PIXEL_SIZE * float(_sprite.sprite_frames.get_meta("scale_" + clip, 1.0))
	var actor_scale := global_transform.basis.get_scale()
	var chest_pixel: Vector2 = _sprite.sprite_frames.get_meta(key)
	return global_position \
		+ camera.global_basis.x * ((chest_pixel.x - canvas_width * 0.5) * pixel_size * actor_scale.x) \
		+ camera.global_basis.y * ((foot * canvas_height - chest_pixel.y) * pixel_size * actor_scale.y)


var _ground_shoe_column_cache: Dictionary = {}


func get_ground_foot_points(camera: Camera3D) -> Array[Vector3]:
	# Keep the ground mark under the actual shoes, not under the center of a
	# wide attack canvas. Candidate animation frames may override the pose.
	var points: Array[Vector3] = []
	if camera == null or _sprite.sprite_frames == null:
		return points
	var clip := String(_sprite.animation)
	var frame := _sprite.frame
	var texture := _sprite.sprite_frames.get_frame_texture(clip, frame)
	if texture == null:
		return points
	var canvas_width := float(_sprite.sprite_frames.get_meta("canvas_width_%s_%d" % [clip, frame],
		texture.get_width()))
	var canvas_height := float(_sprite.sprite_frames.get_meta("canvas_height_%s_%d" % [clip, frame],
		texture.get_height()))
	var feet := float(_sprite.sprite_frames.get_meta("foot_%s_%d" % [clip, frame],
		_sprite.sprite_frames.get_meta("foot_idle_0", 1.0)))
	var cache_key := "%d:%d:%d" % [texture.get_instance_id(), roundi(feet * canvas_height), roundi(canvas_width)]
	var shoe_columns: Array[float] = []
	if _ground_shoe_column_cache.has(cache_key):
		shoe_columns = _ground_shoe_column_cache[cache_key]
	else:
		var image := texture.get_image()
		if image != null and not image.is_empty():
			var y_end := mini(image.get_height() - 1, roundi(feet * canvas_height) + 1)
			var y_begin := maxi(0, y_end - maxi(8, roundi(canvas_height * 0.052)))
			var active: Array[bool] = []
			for x in image.get_width():
				var visible := false
				for y in range(y_begin, y_end + 1):
					if image.get_pixel(x, y).a > 0.55:
						visible = true
						break
				active.append(visible)
			var groups: Array[Vector2i] = []
			var begin := -1
			var last := -1
			for x in active.size():
				if active[x]:
					if begin < 0:
						begin = x
					elif x - last > 5:
						groups.append(Vector2i(begin, last))
						begin = x
					last = x
			if begin >= 0:
				groups.append(Vector2i(begin, last))
			groups.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
				return a.y - a.x > b.y - b.x)
			for group in groups:
				if group.y - group.x < 5:
					continue
				var center := float(group.x + group.y) * 0.5
				if shoe_columns.is_empty() or absf(center - shoe_columns[0]) > canvas_width * 0.12:
					shoe_columns.append(center)
				if shoe_columns.size() == 2:
					break
		if shoe_columns.size() < 2:
			shoe_columns = [canvas_width * 0.36, canvas_width * 0.64]
		_ground_shoe_column_cache[cache_key] = shoe_columns
	for column in shoe_columns:
		var horizontal := (column - canvas_width * 0.5) * _sprite.pixel_size
		points.append(global_position + camera.global_basis.x * horizontal * global_basis.get_scale().x)
	return points


func _build_animation_clock() -> void:
	var library := AnimationLibrary.new()
	for clip_name in _sprite.sprite_frames.get_animation_names():
		var clip := String(clip_name)
		var timeline := Animation.new()
		var duration_ms := float(_sprite.sprite_frames.get_meta("duration_ms_" + clip, 0.0))
		if duration_ms <= 0.0:
			for frame in _sprite.sprite_frames.get_frame_count(clip):
				duration_ms += 1000.0 * _sprite.sprite_frames.get_frame_duration(clip, frame) \
					/ _sprite.sprite_frames.get_animation_speed(clip)
		timeline.length = maxf(0.01, duration_ms / 1000.0)
		if _sprite.sprite_frames.get_animation_loop(clip):
			timeline.loop_mode = Animation.LOOP_LINEAR
		library.add_animation(clip, timeline)
	_animation_player.add_animation_library("", library)


func _impact_index(clip: String) -> int:
	var index := int(_sprite.sprite_frames.get_meta("impact_frame_" + clip, -1))
	if index < 0 and fighter_kind == "dummy" and clip == "attack":
		index = 2
	return index if index < _sprite.sprite_frames.get_frame_count(clip) else -1


func _align_feet() -> void:
	if _sprite.sprite_frames == null:
		return
	var clip := String(_sprite.animation)
	var index := _sprite.frame
	var frames := _sprite.sprite_frames
	var scale_factor := float(frames.get_meta("scale_" + clip, 1.0))
	_sprite.pixel_size = SOURCE_PIXEL_SIZE * scale_factor
	var texture: Texture2D = frames.get_frame_texture(clip, index)
	var canvas_width := float(frames.get_meta("canvas_width_%s_%d" % [clip, index],
		texture.get_width()))
	var canvas_height := float(frames.get_meta("canvas_height_%s_%d" % [clip, index],
		frames.get_meta("canvas_%s_%d" % [clip, index], texture.get_height())))
	var feet := float(frames.get_meta("foot_%s_%d" % [clip, index],
		frames.get_meta("foot_idle_0", 1.0)))
	_sprite_base_height = (feet - 0.5) * canvas_height * _sprite.pixel_size
	_sprite.position.y = _sprite_base_height
	if fighter_kind == "hero" and _has_blade_tip(clip):
		var pixel := _blade_tip_pixel(clip, index)
		if pixel.x >= 0.0 and pixel.y >= 0.0:
			_blade_tip_local = Vector3((pixel.x - canvas_width * 0.5) * _sprite.pixel_size,
				(feet * canvas_height - pixel.y) * _sprite.pixel_size, 0.0)
			_sword_tip.position = _blade_tip_local


func _has_blade_tip(clip: String) -> bool:
	return _sprite.sprite_frames.has_meta("blade_tip_%s_0" % clip) or S1_BLADE_TIPS.has(clip)


func _blade_tip_pixel(clip: String, index: int) -> Vector2:
	var key := "blade_tip_%s_%d" % [clip, index]
	if _sprite.sprite_frames.has_meta(key):
		return _sprite.sprite_frames.get_meta(key) as Vector2
	if S1_BLADE_TIPS.has(clip):
		var tips: Array = S1_BLADE_TIPS[clip]
		if index < tips.size():
			return tips[index] as Vector2
	return Vector2(-1.0, -1.0)


func _on_frame_changed() -> void:
	_align_feet()


func _on_animation_finished() -> void:
	if _active_clip != "" and not _sprite.sprite_frames.get_animation_loop(_active_clip):
		_animation_player.stop()
		action_finished.emit(_active_clip)
