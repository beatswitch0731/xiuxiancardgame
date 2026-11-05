extends SubViewportContainer

# Presentation only. The source-derived CombatDomain remains the sole combat authority.
signal presentation_started(event_type: String, side: String, animation_name: String)
signal presentation_finished(event_type: String)
signal presentation_missing(event_type: String, reason: String)
signal contact_frame(side: String)

const ArtRegistry = preload("res://scripts/battlefield_art_registry.gd")
const Registry = preload("res://scripts/runtime_data_registry.gd")
const ModularActorHD2D = preload("res://scripts/modular_actor_hd2d.gd")
const ACTOR_REFLECTED_LIGHT_LAYER := 1 << 1
const REFERENCE_ACTOR_STYLE := "res://content/data/battle_visuals/actor_style_v1.json"

@export var use_outdoor_candidate := false
@export var use_trial_v4_candidate := false
@export var use_trial_v5_candidate := false
@export var use_trial_v6_candidate := false
@export var use_trial_v7_candidate := false
@export var use_trial_v8_candidate := false
@export var use_trial_v9_candidate := false
@export var use_trial_v10_candidate := false
@export var use_trial_v11_candidate := false
@export var use_trial_v13_candidate := false
@export var use_trial_v14_candidate := false
@export var use_trial_v15_candidate := false
@export var use_trial_v16_candidate := false
@export var use_breath_v17_candidate := false
@export var use_trial_v17_candidate := false
@export var use_reference_actor_style := false

@onready var _world_root: Node3D = $Viewport/World
@onready var _environment: WorldEnvironment = $Viewport/World/WorldEnvironment
@onready var _camera_rig: Node3D = $Viewport/World/CameraRig
@onready var _camera: Camera3D = $Viewport/World/CameraRig/Camera
@onready var _player_anchor: Node3D = $Viewport/World/PlayerAnchor
@onready var _enemy_anchor: Node3D = $Viewport/World/EnemyAnchor
@onready var _impact_light: OmniLight3D = $Viewport/World/ImpactLight

var _player: Node3D
var _enemy: Node3D
var _modular_actor: Node3D
var _world: Node3D
var _pending: Array[Dictionary] = []
var _draining := false
var _victory_cue_queued := false
var _victory_cue_played := false
var _impact_fx: Node3D
var _impact_material: StandardMaterial3D
var _arc_material: StandardMaterial3D
var _arc_core_material: StandardMaterial3D
var _camera_tween: Tween
var _camera_shake: CameraShake
var _camera_orbit_x := 0.0
var _light_tween: Tween
var _impact_tween: Tween
var _diagnostic_orbit := false
var _active_motion: Dictionary = {}
var _parallel_hit_reaction: Dictionary = {}
var _sampled_contact_tips: Dictionary = {}
var _impact_hold := false
var _ground_decals: Dictionary = {}
var _ground_decal_texture: Texture2D
var _audio_clips: Dictionary = {}
var _audio_runtimes: Dictionary = {}
var _audio_streams: Dictionary = {}
var _action_audio: AudioStreamPlayer
var _contact_audio: AudioStreamPlayer
var stage_context: Dictionary = {}
var stage_art: Dictionary = {}
var _player_scene: PackedScene
var _enemy_scene: PackedScene
var _player_home := Vector3(-2.3, 0.0, 0.15)
var _enemy_home := Vector3(2.3, 0.0, -0.25)
var _camera_target := Vector3(0.0, 1.25, -0.72)
var _camera_home := Vector3(0.0, 4.15, 10.7)
var reference_actor_style_ready := false
var _reference_breath: Dictionary = {}
var _reference_breath_elapsed := 0.0


func bind_stage_context(context: Dictionary) -> bool:
	# Called before add_child so _ready never selects art without source identity.
	stage_context = context.duplicate(true)
	var candidate := ""
	if use_trial_v17_candidate:
		candidate = "trial_v17"
	elif use_trial_v16_candidate:
		candidate = "trial_v16"
	elif use_trial_v15_candidate:
		candidate = "trial_v15"
	elif use_trial_v14_candidate:
		candidate = "trial_v14"
	elif use_trial_v13_candidate:
		candidate = "trial_v13"
	elif use_trial_v11_candidate:
		candidate = "trial_v11"
	elif use_trial_v10_candidate:
		candidate = "trial_v10"
	elif use_trial_v9_candidate:
		candidate = "trial_v9"
	elif use_trial_v8_candidate:
		candidate = "trial_v8"
	elif use_trial_v7_candidate:
		candidate = "trial_v7"
	elif use_trial_v6_candidate:
		candidate = "trial_v6"
	elif use_trial_v5_candidate:
		candidate = "trial_v5"
	elif use_trial_v4_candidate:
		candidate = "trial_v4"
	elif use_outdoor_candidate:
		candidate = "outdoor_v3"
	stage_art = ArtRegistry.new().resolve(stage_context, candidate)
	if stage_art.is_empty() or String(stage_art.get("selectedScene", "")).is_empty():
		return false
	var profile: Dictionary = stage_art.get("stageProfile", {})
	for field in ["playerActorScene", "enemyActorScene", "playerHome", "enemyHome",
			"cameraTarget", "cameraHome", "lightingProfile", "contactFxProfile"]:
		if not profile.has(field):
			return false
	if String(profile["lightingProfile"]) != "qingyun_first_fight" \
			or String(profile["contactFxProfile"]) != "s1_source_timed_sword_wood":
		return false
	for field in ["playerHome", "enemyHome", "cameraTarget", "cameraHome"]:
		if not profile[field] is Array or (profile[field] as Array).size() != 3:
			return false
	_player_scene = load(String(profile["playerActorScene"])) as PackedScene
	_enemy_scene = load(String(profile["enemyActorScene"])) as PackedScene
	if _player_scene == null or _enemy_scene == null:
		return false
	_player_home = _vec3(profile["playerHome"])
	_enemy_home = _vec3(profile["enemyHome"])
	_camera_target = _vec3(profile["cameraTarget"])
	_camera_home = _vec3(profile["cameraHome"])
	return _load_source_audio()


func _load_source_audio() -> bool:
	var registry = Registry.new()
	var actions: Dictionary = registry.read_json("data/combat/action_presentations.json")
	var catalog: Dictionary = registry.read_json("data/audio/path_identity.json")
	if catalog.get("assetRoot") != "assets/audio/":
		return false
	_audio_runtimes.clear()
	_audio_streams.clear()
	_audio_clips.clear()
	_index_audio_runtimes(catalog)
	if not _load_audio_cue("sfx_treasure"):
		return false
	for card_id in registry.read_json("data/combat/deck_progression.json").get(
			"paths", {}).get("sword", {}).get("starterDeck", []):
		var card_action: Dictionary = actions.get("cardActions", {}).get(card_id, {})
		if card_action.is_empty():
			card_action = actions.get("paths", {}).get("sword", {}).get("guard", {})
		var card_audio := _source_audio_clip(card_action, actions)
		if card_audio.is_empty():
			return false
		_audio_clips["card:" + card_id] = card_audio
	for side in ["player", "enemy"]:
		var side_actions: Dictionary = actions.get("paths", {}).get("sword", {}) if side == "player" \
			else actions.get("encounters", {}).get("enc_trial_sword_swift", {})
		for family in side_actions:
			# Hurt and enemy collapse are visual sidecars with no emitted impact
			# phase. Enemy defend and player reaction emit only actionStarted.
			var has_start: bool = family != "hurt" and not (side == "enemy" and family == "defeat")
			var has_contact: bool = family in ["attack", "skill", "guard"] \
				and not (side == "enemy" and family == "guard")
			var action_audio := _source_audio_clip(side_actions[family], actions,
				has_start, has_contact)
			if action_audio.is_empty():
				return false
			_audio_clips[side + ":" + family] = action_audio
	return true


func _source_audio_clip(action: Dictionary, actions: Dictionary,
		has_start: bool = true, has_contact: bool = true) -> Dictionary:
	var sfx: Dictionary = actions.get("sfxCues", {}).get(String(action.get("sfxCueId", "")), {})
	if sfx.is_empty():
		return {}
	var start_id := String(sfx.get("actionStarted", sfx.get("actorDefeated", ""))) if has_start else ""
	var contact_id := String(sfx.get("impact", sfx.get(
		"statusApplied", sfx.get("reactionResolved", "")))) if has_contact else ""
	for cue_id in [start_id, contact_id]:
		if not cue_id.is_empty() and not _load_audio_cue(cue_id):
			return {}
	return {"start": start_id, "contact": contact_id}


func _index_audio_runtimes(value: Variant) -> void:
	if value is Dictionary:
		var runtime: Variant = value.get("runtime")
		if runtime is Dictionary and runtime.get("id") is String:
			_audio_runtimes[runtime["id"]] = runtime
		for child in value.values():
			_index_audio_runtimes(child)
	elif value is Array:
		for child in value:
			_index_audio_runtimes(child)


func _load_audio_cue(cue_id: String) -> bool:
	if _audio_streams.has(cue_id):
		return true
	var runtime: Dictionary = _audio_runtimes.get(cue_id, {})
	var relative := String(runtime.get("path", ""))
	if runtime.get("bus") != "sfx" or relative.is_empty() \
			or relative.begins_with("/") or ".." in relative.split("/"):
		return false
	var stream = load("res://content/assets/audio/" + relative)
	if not stream is AudioStream:
		return false
	_audio_streams[cue_id] = stream
	return true


func _play_audio_cue(cue_id: String, player: AudioStreamPlayer) -> void:
	if cue_id.is_empty() or player == null or not _audio_streams.has(cue_id):
		return
	var runtime: Dictionary = _audio_runtimes[cue_id]
	player.stop()
	player.stream = _audio_streams[cue_id]
	player.volume_db = linear_to_db(maxf(0.5 * float(runtime.get("volume", 1.0)), 0.001))
	player.play()


func _vec3(values: Array) -> Vector3:
	return Vector3(float(values[0]), float(values[1]), float(values[2]))


func use_demo_composition() -> void:
	# The equipment pose viewer keeps its short fixed lunge and reviewed framing.
	_player_home = Vector3(-2.3, 0.0, 0.15)
	_enemy_home = Vector3(2.3, 0.0, -0.25)
	_camera_target = Vector3(0.0, 1.25, -0.72)
	_camera_home = Vector3(0.0, 4.15, 10.7)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 打击感第五层：屏幕震动。只产出 offset，应用在下面的 _process 里，
	# 与 _set_camera_yaw（改 position/朝向）和 _camera_tween（改 position:x）
	# 正交，互不覆盖。
	_camera_shake = CameraShake.new()
	_camera_shake.name = "CameraShake"
	add_child(_camera_shake)
	_action_audio = AudioStreamPlayer.new()
	_action_audio.name = "SourceActionSfx"
	add_child(_action_audio)
	_contact_audio = AudioStreamPlayer.new()
	_contact_audio.name = "SourceContactSfx"
	add_child(_contact_audio)
	var scene_path := String(stage_art.get("selectedScene", ""))
	if scene_path.is_empty():
		push_error("Battlefield has no runnable 3D scene: " + String(stage_context.get("battlefieldId", "")))
		return
	var world_scene := load(scene_path) as PackedScene
	if world_scene == null:
		push_error("Battlefield scene resource missing: " + scene_path)
		return
	_world = world_scene.instantiate()
	_world.name = "CangmangSpatialWorld"
	_world_root.add_child(_world)
	_player_anchor.position = _player_home
	_enemy_anchor.position = _enemy_home
	# The source battlefield places its distant mountain gate to the right rear.
	# Keep the existing 3D court as a spatial blockout until authored GLB art lands.
	var gate := _world.get_node_or_null("SectMountainGate") as Node3D
	if gate != null:
		gate.position = Vector3(4.1, 0.0, -1.4)
		gate.scale = Vector3.ONE * 0.68
	var old_horizon := _world.get_node_or_null("DimensionalMountainHorizon") as Node3D
	if old_horizon != null:
		old_horizon.visible = false
	# Preserve a clear duel silhouette and the source court's open rear axis.
	# The old blockout galleries and stark lantern props crowd both fighters.
	for prop_name in ["WestGallery", "EastGallery", "CourtyardLantern_-5_55", "CourtyardLantern_5_55"]:
		var prop := _world.get_node_or_null(prop_name) as Node3D
		if prop != null:
			prop.visible = false
	var sharp_paver_highlights := _world.get_node_or_null("StoneTrialCourt/BeveledPavers_wet_highlight") as MeshInstance3D
	if sharp_paver_highlights != null:
		sharp_paver_highlights.visible = false
	_player = _player_scene.instantiate()
	_player.name = "YelingyunHD2D"
	_player_anchor.add_child(_player)
	_player.rotation.y = -0.35
	_enemy = _enemy_scene.instantiate()
	_enemy.name = "QuickSwordDummyHD2D"
	_enemy_anchor.add_child(_enemy)
	_enemy.rotation.y = PI + 0.35
	_player.contact_key.connect(_on_actor_contact_key.bind("player"))
	_enemy.contact_key.connect(_on_actor_contact_key.bind("enemy"))
	_setup_environment()
	if use_trial_v8_candidate:
		_setup_trial_v4_candidate()
		_setup_trial_v5_candidate()
		_setup_trial_v8_candidate()
	elif use_trial_v7_candidate:
		_setup_trial_v7_candidate()
	elif use_trial_v17_candidate or use_trial_v16_candidate or use_trial_v15_candidate or use_trial_v14_candidate or use_trial_v13_candidate or use_trial_v11_candidate or use_trial_v10_candidate or use_trial_v9_candidate or use_trial_v6_candidate or String(stage_art.get("selectedScene", "")) in ["res://assets/battle/hd2d/world_v6/cangmang_trial_hall_v6.glb", "res://assets/battle/hd2d/world_v16/cangmang_trial_hall_v16.glb", "res://assets/battle/hd2d/world_v17/qingyun_tutorial_hall_v17.glb"]:
		_setup_trial_v6_candidate()
	elif use_trial_v4_candidate or use_trial_v5_candidate:
		_setup_trial_v4_candidate()
		if use_trial_v5_candidate:
			_setup_trial_v5_candidate()
	elif use_outdoor_candidate:
		_setup_outdoor_candidate()
	if use_trial_v13_candidate:
		_setup_trial_v13_candidate()
	if use_trial_v16_candidate:
		_setup_trial_v16_actor_keypose_candidate()
	if String(stage_art.get("selectedScene", "")) in ["res://assets/battle/hd2d/world_v16/cangmang_trial_hall_v16.glb", "res://assets/battle/hd2d/world_v17/qingyun_tutorial_hall_v17.glb"]:
		_setup_trial_v16_floor_wear()
		_setup_trial_v16_fixture_lighting()
	if String(stage_art.get("selectedScene", "")) == "res://assets/battle/hd2d/world_v17/qingyun_tutorial_hall_v17.glb":
		_setup_tutorial_v17_lighting()
		_setup_tutorial_actor_reflected_fill()
		# The tutorial stage keeps both feet at their authored world anchors.
		# Increase their visual presence within this camera before the UI hand is drawn.
		_player.scale = Vector3.ONE * 1.12
		_enemy.scale = Vector3.ONE * 1.04
	if use_breath_v17_candidate:
		_setup_breath_v17_candidate()
	if use_reference_actor_style:
		_setup_reference_actor_style()
	_set_camera_yaw(0.0)
	_build_impact_fx()
	if _player.has_method("play_action"):
		_player.play_action("idle")
	if _enemy.has_method("play_action"):
		_enemy.play_action("idle")
	set_process(true)


func _process(delta: float) -> void:
	_apply_camera_shake(delta)
	_reference_breath_elapsed += delta
	_sync_motion_to_animation()
	if _modular_actor != null and not _active_motion.is_empty() \
			and String(_active_motion.get("side", "")) == "player" \
			and String(_active_motion.get("contact_kind", "")) in ["wood", "shield"]:
		var duration := float(_active_motion["duration"])
		_modular_actor.seek_attack(
			clampf(_player.get_playback_time() / duration, 0.0, 1.0),
			float(_active_motion["contact_time"]) / duration)
	for actor in [_player, _enemy]:
		if actor != null and actor.has_method("sync_billboard_attachment"):
			actor.sync_billboard_attachment(_camera)
			_apply_reference_breath(actor)
		_sync_ground_contact_decals(actor)


func has_hd2d_assets() -> bool:
	return (not use_reference_actor_style or reference_actor_style_ready) \
		and not stage_art.is_empty() and not String(stage_art.get("selectedScene", "")).is_empty() \
		and _world != null and _player != null and _enemy != null \
		and _mesh_count(_world) >= 24 and get_actor_sprite("player") != null \
		and get_actor_sprite("enemy") != null and _actor_has("player", "sword_probe") \
		and _actor_has("enemy", "attack")


func get_actor_model(side: String) -> Node3D:
	return _player if side == "player" else (_enemy if side == "enemy" else null)


func enable_actor_motion_lab() -> void:
	if _modular_actor != null:
		return
	_modular_actor = ModularActorHD2D.new()
	_modular_actor.scale = _player.scale
	_player_anchor.add_child(_modular_actor)
	set_actor_study_variant("practice_sword")


func set_actor_study_variant(value: String) -> void:
	if _modular_actor == null:
		return
	var original := value == "original"
	_modular_actor.visible = not original
	get_actor_sprite("player").visible = original
	if not original:
		_modular_actor.set_variant(value)


func set_actor_study_realm(value: String) -> bool:
	return _modular_actor != null and _modular_actor.set_realm_stage(value)


func set_actor_study_armor(value: String) -> bool:
	return _modular_actor != null and _modular_actor.set_armor(value)


func set_actor_study_accessory(value: String) -> bool:
	return _modular_actor != null and _modular_actor.set_accessory(value)


func set_actor_study_artifact(value: String) -> bool:
	return _modular_actor != null and _modular_actor.set_artifact(value)


func seek_actor_study_attack(progress: float) -> void:
	if _modular_actor == null or not _modular_actor.visible or not _active_motion.is_empty():
		return
	var p := clampf(progress, 0.0, 1.0)
	var duration := _clip_duration(_player, "sword_probe")
	var contact := clampf(_player.get_contact_time("sword_probe") / duration, 0.1, 0.8)
	_modular_actor.seek_attack(p, contact)
	var weight := smoothstep(0.1, contact, p) if p < contact else 1.0 - smoothstep(contact + 0.16, 0.86, p)
	_player_anchor.position = _player_home.lerp(
		_strike_destination("player", "sword_probe", duration * contact, _player_home), weight)
	_enemy.get_sprite().modulate = Color(1.0, 0.64, 0.62) if p >= contact and p < contact + 0.16 else Color.WHITE


func get_actor_sprite(side: String) -> AnimatedSprite3D:
	var actor := get_actor_model(side)
	return actor.get_sprite() as AnimatedSprite3D if actor != null and actor.has_method("get_sprite") else null


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
		var hp_loss := 0
		var block_spent := 0
		for effect in event.get("effects", []):
			if effect is Dictionary and effect.get("type") == "damage":
				hp_loss += int(effect.get("hpLoss", 0))
				block_spent += int(effect.get("blockSpent", 0))
		steps.append({"side": "player", "clip": clip, "audioKey": "card:" + card_id,
			"contact": hp_loss > 0 or block_spent > 0 or card_id in ["sword_guard", "sword_sheath_guard"]})
		contact_kind = "self" if card_id in ["sword_guard", "sword_sheath_guard"] else ("wood" if hp_loss > 0 else ("shield" if block_spent > 0 else "air"))
		if bool(event.get("victory", false)):
			steps.append({"side": "enemy", "clip": "defeat", "audioKey": "enemy:defeat", "contact": false})
		elif hp_loss > 0:
			steps.append({"side": "enemy", "clip": "hurt", "audioKey": "enemy:hurt", "contact": false})
	elif kind == "ENEMY_ACTION":
		if String(event.get("reactionId", "TAKE_HIT")) != "TAKE_HIT":
			steps.append({"side": "player", "clip": "reaction", "audioKey": "player:reaction", "contact": false})
		var intent: Dictionary = event.get("intent", {})
		var enemy_clip := "attack" if intent.get("type") == "attack" else "guard"
		steps.append({"side": "enemy", "clip": enemy_clip,
			"audioKey": "enemy:" + enemy_clip, "contact": enemy_clip == "attack"})
		if int(event.get("hpLoss", 0)) > 0:
			steps.append({"side": "player", "clip": "hurt", "audioKey": "player:hurt", "contact": false})
		contact_kind = "flesh" if int(event.get("hpLoss", 0)) > 0 else "shield"
	else:
		steps.append({"side": "player", "clip": "defeat", "audioKey": "player:defeat", "contact": false})
	for step in steps:
		if not _actor_has(String(step["side"]), String(step["clip"])) \
				or not _audio_clips.has(step["audioKey"]):
			presentation_missing.emit(kind, "Missing source HD-2D actor clip: " + str(step))
			return false
	_pending.append({"type": kind, "steps": steps, "contact_kind": contact_kind})
	if not _draining:
		call_deferred("_drain_presentations")
	return true


func queue_victory_cue() -> void:
	if _victory_cue_queued or _victory_cue_played:
		return
	_victory_cue_queued = true
	call_deferred("_flush_victory_cue")


func _flush_victory_cue() -> void:
	if not _victory_cue_queued or _victory_cue_played or _draining or not _pending.is_empty():
		return
	_victory_cue_queued = false
	_victory_cue_played = true
	_play_audio_cue("sfx_treasure", _action_audio)


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
		var steps: Array = event["steps"]
		var index := 0
		while index < steps.size():
			var step: Dictionary = steps[index]
			var next_step: Dictionary = steps[index + 1] if index + 1 < steps.size() else {}
			if String(step["side"]) == "player" and bool(step["contact"]) \
					and String(next_step.get("side", "")) == "enemy" \
					and String(next_step.get("clip", "")) == "hurt":
				var victim := get_actor_model("enemy")
				_parallel_hit_reaction = {"actor": victim, "clip": "hurt",
					"kind": String(event["type"]), "started": false, "finished": false}
				await _play_step(String(event["type"]), step, String(event["contact_kind"]))
				if bool(_parallel_hit_reaction.get("started", false)):
					if not bool(_parallel_hit_reaction.get("finished", false)):
						await victim.action_finished
					victim.play_action("idle")
					index += 2
				else:
					# Keep the old presentation path if a malformed clip never emits contact.
					index += 1
				_parallel_hit_reaction.clear()
			else:
				await _play_step(String(event["type"]), step, String(event["contact_kind"]))
				index += 1
		presentation_finished.emit(String(event["type"]))
	_draining = false
	_flush_victory_cue()


func _play_step(kind: String, step: Dictionary, contact_kind: String) -> void:
	var side := String(step["side"])
	var clip := String(step["clip"])
	if side == "enemy" and _modular_actor != null:
		_player_anchor.position = _player_home
		_modular_actor.set_pose("idle")
		_enemy.get_sprite().modulate = Color.WHITE
	var actor := get_actor_model(side)
	var anchor := get_actor_anchor(side)
	var home := _player_home if side == "player" else _enemy_home
	var cue := bool(step["contact"])
	var melee := cue and contact_kind != "self"
	var duration := _clip_duration(actor, clip)
	var contact_time := clampf(float(actor.get_contact_time(clip)), 0.08, duration - 0.08) if cue and actor.has_method("get_contact_time") else duration * 0.47
	var audio_clip: Dictionary = _audio_clips.get(String(step["audioKey"]), {})
	_play_audio_cue(String(audio_clip.get("start", "")), _action_audio)
	anchor.position = home
	if side == "player":
		_enemy.get_sprite().modulate = Color.WHITE
	var strike_position := home
	if cue:
		if melee:
			strike_position = _strike_destination(side, clip, contact_time, home)
		_active_motion = {
			"actor": actor, "anchor": anchor, "home": home,
			"destination": strike_position, "clip": clip, "side": side,
			"contact_time": contact_time, "duration": duration,
			"idle_yaw": -0.35 if side == "player" else PI + 0.35,
			"strike_yaw": 0.0 if side == "player" else PI,
			"contact_kind": contact_kind, "contacted": false,
			"audioContact": String(audio_clip.get("contact", "")),
		}
	if use_trial_v16_candidate and melee:
		_set_trial_v16_attack_sort(side)
	if side == "player" and clip == "defeat" and _modular_actor != null:
		set_actor_study_variant("original")
	actor.play_action(clip)
	if side == "player" and _modular_actor != null:
		if melee:
			_modular_actor.seek_attack(0.0, contact_time / duration)
		else:
			_modular_actor.set_pose("guard" if clip in ["guard", "sword_guard", "sword_sheath_guard"] else clip)
	presentation_started.emit(kind, side, clip)
	await actor.action_finished
	_active_motion = {}
	if use_trial_v16_candidate and melee:
		_clear_trial_v16_attack_sort()
	anchor.position = home
	actor.rotation.y = -0.35 if side == "player" else PI + 0.35
	_camera.fov = 43.0
	if clip != "defeat":
		actor.play_action("idle")
		if side == "player" and _modular_actor != null:
			_modular_actor.seek_attack(1.0)


func _set_trial_v16_attack_sort(attacker: String) -> void:
	# A contact pose must read on top of the defender's guard. Godot's priority
	# only sorts transparent sprites when alpha cut is disabled, so this is
	# enabled only for the short melee action and reset at its completion.
	for side in ["player", "enemy"]:
		var sprite := get_actor_sprite(side)
		sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
		sprite.render_priority = 1 if side == attacker else 0


func _clear_trial_v16_attack_sort() -> void:
	for side in ["player", "enemy"]:
		var sprite := get_actor_sprite(side)
		sprite.render_priority = 0
		sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_OPAQUE_PREPASS


func _sync_motion_to_animation() -> void:
	if _active_motion.is_empty():
		return
	var actor: Node3D = _active_motion["actor"]
	# Root motion follows the same sprite clock that dispatches contact. The
	# auxiliary AnimationPlayer contains duration data but no motion tracks.
	var time := float(actor.get_playback_time())
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
		_camera.fov = lerpf(43.0, 41.0, weight)


func _on_actor_contact_key(clip: String, side: String) -> void:
	if _active_motion.is_empty() or bool(_active_motion["contacted"]) \
			or String(_active_motion["side"]) != side or String(_active_motion["clip"]) != clip:
		return
	_sync_motion_to_animation()
	_active_motion["contacted"] = true
	_start_parallel_hit_reaction(side)
	var contact_kind := String(_active_motion["contact_kind"])
	_play_audio_cue(String(_active_motion.get("audioContact", "")), _contact_audio)
	if contact_kind != "air":
		if contact_kind != "self":
			_hold_contact_frames(0.030 if clip == "sword_probe" else (0.055 if clip == "sword_followthrough" else 0.045))
		_flash_contact(side, contact_kind, clip)
	contact_frame.emit(side)


func _start_parallel_hit_reaction(side: String) -> void:
	if side != "player" or _parallel_hit_reaction.is_empty() \
			or bool(_parallel_hit_reaction.get("started", false)):
		return
	var victim: Node3D = _parallel_hit_reaction["actor"]
	var clip := String(_parallel_hit_reaction["clip"])
	_parallel_hit_reaction["started"] = true
	victim.action_finished.connect(_on_parallel_hit_reaction_finished, Object.CONNECT_ONE_SHOT)
	victim.play_action(clip)
	presentation_started.emit(String(_parallel_hit_reaction["kind"]), "enemy", clip)


func _on_parallel_hit_reaction_finished(clip: String) -> void:
	if not _parallel_hit_reaction.is_empty() and clip == String(_parallel_hit_reaction.get("clip", "")):
		_parallel_hit_reaction["finished"] = true


func _hold_contact_frames(seconds: float) -> void:
	if _impact_hold:
		return
	_impact_hold = true
	var frozen_clocks: Array[Dictionary] = []
	for actor in [_player, _enemy]:
		var sprite := actor.get_sprite() as AnimatedSprite3D
		var clock := actor.get_animation_player() as AnimationPlayer
		frozen_clocks.append({"sprite": sprite, "sprite_speed": sprite.speed_scale,
			"clock": clock, "clock_speed": clock.speed_scale})
		sprite.speed_scale = 0.0
		clock.speed_scale = 0.0
	get_tree().create_timer(seconds).timeout.connect(func() -> void:
		if not is_inside_tree():
			return
		for frozen in frozen_clocks:
			(frozen["sprite"] as AnimatedSprite3D).speed_scale = float(frozen["sprite_speed"])
			(frozen["clock"] as AnimationPlayer).speed_scale = float(frozen["clock_speed"])
		_impact_hold = false)


func _strike_destination(side: String, clip: String, contact_time: float, home: Vector3) -> Vector3:
	# A disposable rig samples the authored blade pose. Seeking the live rig
	# can queue an AnimationPlayer method-track contact at time zero on replay.
	var key := side + ":" + clip
	if not _sampled_contact_tips.has(key):
		var sample: Node3D = _player_scene.instantiate() if side == "player" else _enemy_scene.instantiate()
		sample.name = "ContactPoseSampler"
		sample.visible = false
		_world_root.add_child(sample)
		sample.scale = get_actor_model(side).scale
		sample.rotation.y = 0.0 if side == "player" else PI
		sample.play_action(clip)
		var sprite: AnimatedSprite3D = sample.get_sprite()
		# Review/imported frames can replace the live actor's SpriteFrames while
		# keeping the same clip and timing. Sample that actual visible resource so
		# root motion still brings its authored blade tip to the target's chest.
		sprite.sprite_frames = get_actor_sprite(side).sprite_frames
		var frames: SpriteFrames = sprite.sprite_frames
		var remaining := contact_time
		for frame_index in frames.get_frame_count(clip):
			var frame_seconds := frames.get_frame_duration(clip, frame_index) / frames.get_animation_speed(clip)
			if remaining < frame_seconds or frame_index == frames.get_frame_count(clip) - 1:
				sprite.frame = frame_index
				break
			remaining -= frame_seconds
		sample.sync_billboard_attachment(_camera)
		_sampled_contact_tips[key] = sample.get_sword_tip().global_position
		sample.queue_free()
	var target: Node3D = _enemy if side == "player" else _player
	var chest: Vector3 = target.get_chest_hit().global_position
	if side == "player" and not _parallel_hit_reaction.is_empty():
		chest = target.get_chest_point_for("hurt", 0, _camera)
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


func _flash_contact(side: String, contact_kind: String, clip: String) -> void:
	var actor: Node3D = _player if side == "player" else _enemy
	var target: Node3D = _enemy if side == "player" else _player
	actor.sync_billboard_attachment(_camera)
	var profile := clip if side == "player" else "enemy_attack"
	_impact_fx.global_position = actor.get_chest_hit().global_position if contact_kind == "self" \
		else target.get_chest_point_for("hurt", 0, _camera) if side == "player" and not _parallel_hit_reaction.is_empty() \
		else actor.get_sword_tip().global_position if side == "player" \
		else target.get_chest_hit().global_position
	var is_probe := profile == "sword_probe"
	var is_follow := profile == "sword_followthrough"
	var is_edge := profile == "sword_edge"
	var is_guard := profile == "sword_guard"
	var is_sheath := profile == "sword_sheath_guard"
	(_impact_fx.get_node("CurvedSwordTrail") as MeshInstance3D).visible = is_follow or profile == "enemy_attack"
	(_impact_fx.get_node("SwordTrailHotCore") as MeshInstance3D).visible = is_follow or profile == "enemy_attack"
	(_impact_fx.get_node("NeedleLine") as MeshInstance3D).visible = is_probe
	(_impact_fx.get_node("GuardPulse") as MeshInstance3D).visible = is_guard
	(_impact_fx.get_node("SheathGlint") as MeshInstance3D).visible = is_sheath
	for index in 13:
		(_impact_fx.get_node("SlashSpark_%02d" % index) as MeshInstance3D).visible = \
			(index in [0, 6, 12] if is_probe else index in [1, 4, 9] if is_follow \
			else index in [0, 3, 6, 9] if is_edge else false if is_guard or is_sheath else index < 8)
	(_impact_fx.get_node("ContactCore") as MeshInstance3D).visible = not (is_guard or is_sheath)
	_impact_fx.scale = Vector3.ONE * (0.48 if is_probe else 0.58 if is_follow else 0.42 if is_edge else 0.70 if is_guard else 0.52)
	_impact_fx.visible = true
	_impact_light.global_position = _impact_fx.global_position
	var accent := Color("a7dae0") if is_edge else Color("83baa8") if is_guard \
		else Color("e7cc9d") if is_sheath else Color("f0d3a0") if is_follow \
		else Color("e7edf0") if is_probe else Color("eac49d")
	_impact_light.light_color = accent
	_impact_light.light_energy = 1.15 if is_guard or is_sheath else 2.1 if is_edge else 2.7
	if use_trial_v4_candidate or use_trial_v5_candidate:
		# Keep the flash at the blade contact; damp its glossy floor reflection.
		_impact_light.light_energy *= 0.82
		_impact_light.omni_range = 3.5
		_impact_light.light_specular = 0.24
	_impact_material.albedo_color = Color(accent.r, accent.g, accent.b, 0.86)
	_impact_material.emission = accent
	_arc_material.albedo_color = Color(accent.r, accent.g, accent.b, 0.78)
	_arc_material.emission = accent
	_arc_core_material.albedo_color = Color(accent.r, accent.g, accent.b, 0.95)
	_arc_core_material.emission = accent
	if _impact_tween != null and _impact_tween.is_running():
		_impact_tween.kill()
	_impact_tween = create_tween()
	_impact_tween.tween_property(_impact_fx, "scale", Vector3.ONE * (0.83 if is_probe or is_edge else 1.02), 0.045).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_impact_tween.tween_interval(0.025 if is_probe else 0.055)
	_impact_tween.tween_property(_impact_fx, "scale", Vector3.ONE * 0.03, 0.09 if is_probe else 0.13).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_impact_tween.finished.connect(func() -> void: _impact_fx.visible = false)
	if _light_tween != null and _light_tween.is_running():
		_light_tween.kill()
	_light_tween = create_tween()
	_light_tween.tween_property(_impact_light, "light_energy", 0.0, 0.18)
	if _camera_tween != null and _camera_tween.is_running():
		_camera_tween.kill()
	_camera.position.x = _camera_orbit_x
	_camera_tween = create_tween()
	_camera_tween.tween_property(_camera, "position:x", _camera_orbit_x + (-0.13 if side == "player" else 0.12), 0.045)
	_camera_tween.tween_property(_camera, "position:x", _camera_orbit_x, 0.16).set_trans(Tween.TRANS_CUBIC)


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
	var needle := MeshInstance3D.new()
	needle.name = "NeedleLine"
	var needle_mesh := CylinderMesh.new()
	needle_mesh.top_radius = 0.018
	needle_mesh.bottom_radius = 0.018
	needle_mesh.height = 0.92
	needle.mesh = needle_mesh
	needle.rotation.z = PI * 0.5
	needle.position = Vector3(-0.24, 0.02, 0.12)
	needle.material_override = _arc_core_material
	_impact_fx.add_child(needle)
	var guard_pulse := MeshInstance3D.new()
	guard_pulse.name = "GuardPulse"
	guard_pulse.mesh = _make_guard_arc()
	guard_pulse.material_override = _arc_material
	_impact_fx.add_child(guard_pulse)
	var sheath_glint := MeshInstance3D.new()
	sheath_glint.name = "SheathGlint"
	var sheath_mesh := CylinderMesh.new()
	sheath_mesh.top_radius = 0.025
	sheath_mesh.bottom_radius = 0.025
	sheath_mesh.height = 0.80
	sheath_glint.mesh = sheath_mesh
	sheath_glint.rotation.z = PI * 0.45
	sheath_glint.position = Vector3(0.04, -0.27, 0.15)
	sheath_glint.material_override = _arc_core_material
	_impact_fx.add_child(sheath_glint)
	for index in 13:
		var ray := MeshInstance3D.new()
		ray.name = "SlashSpark_%02d" % index
		var shard := CylinderMesh.new()
		shard.top_radius = 0.0
		shard.bottom_radius = 0.032 if index % 2 == 0 else 0.018
		shard.height = 0.50 if index % 3 == 0 else 0.27
		ray.mesh = shard
		ray.material_override = _impact_material
		var angle := float(index) * TAU / 13.0
		ray.position = Vector3(cos(angle) * 0.34, sin(angle) * 0.29, sin(angle * 2.0) * 0.12)
		ray.rotation.z = angle - PI * 0.5
		_impact_fx.add_child(ray)
	var core := MeshInstance3D.new()
	core.name = "ContactCore"
	var core_mesh := SphereMesh.new()
	core_mesh.radius = 0.14
	core_mesh.height = 0.28
	core.mesh = core_mesh
	core.material_override = _impact_material
	_impact_fx.add_child(core)


func _make_guard_arc() -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for segment in 24:
		var a := -1.15 + 2.3 * float(segment) / 24.0
		var b := -1.15 + 2.3 * float(segment + 1) / 24.0
		var inner_a := Vector3(cos(a) * 0.65, sin(a) * 0.65, 0.14)
		var outer_a := Vector3(cos(a) * 0.72, sin(a) * 0.72, 0.14)
		var inner_b := Vector3(cos(b) * 0.65, sin(b) * 0.65, 0.14)
		var outer_b := Vector3(cos(b) * 0.72, sin(b) * 0.72, 0.14)
		for point in [inner_a, outer_a, inner_b, inner_b, outer_a, outer_b]:
			tool.add_vertex(point)
	return tool.commit()


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


func _setup_outdoor_candidate() -> void:
	_world_root.get_node("DistantMountains").visible = false
	var floor_mesh := _world.find_child("SM_TrialCourt_ScannedWeatheredSlabs", true, false) as MeshInstance3D
	if floor_mesh != null:
		var floor_material := floor_mesh.mesh.surface_get_material(0).duplicate() as StandardMaterial3D
		floor_material.albedo_color = Color("bdd5df")
		floor_mesh.set_surface_override_material(0, floor_material)
	for actor in [_player, _enemy]:
		actor.scale = Vector3.ONE * 0.72
	($Viewport as SubViewport).msaa_3d = Viewport.MSAA_4X
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("1b2834")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("91aabd")
	environment.ambient_light_energy = 0.53
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	_environment.environment = environment
	($Viewport/World/HeroFill as OmniLight3D).light_energy = 1.45
	($Viewport/World/DummyRim as OmniLight3D).light_energy = 1.25
	for light_data in [
		{"name": "PavilionLanternPool", "position": Vector3(-6.6, 2.6, -5.8),
			"color": Color("ffc083"), "energy": 4.0, "range": 6.2},
		{"name": "GateLanternPool", "position": Vector3(5.7, 3.8, -10.5),
			"color": Color("ffc48e"), "energy": 3.4, "range": 6.0},
		{"name": "CombatWarmPool", "position": Vector3(0.2, 3.8, 0.0),
			"color": Color("ffc28e"), "energy": 2.2, "range": 6.5},
	]:
		var lamp := OmniLight3D.new()
		lamp.name = light_data["name"]
		lamp.position = light_data["position"]
		lamp.light_color = light_data["color"]
		lamp.light_energy = light_data["energy"]
		lamp.omni_range = light_data["range"]
		lamp.shadow_enabled = true
		_world_root.add_child(lamp)
func _setup_trial_v4_candidate() -> void:
	_world_root.get_node("DistantMountains").visible = false
	for actor in [_player, _enemy]:
		actor.scale = Vector3.ONE * 0.91
	($Viewport as SubViewport).msaa_3d = Viewport.MSAA_4X
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("1b2834")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("8fa6b7")
	environment.ambient_light_energy = 0.48
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	_environment.environment = environment
	($Viewport/World/HeroFill as OmniLight3D).light_energy = 1.25
	($Viewport/World/DummyRim as OmniLight3D).light_energy = 0.75
	var skylight := DirectionalLight3D.new()
	skylight.name = "RainSkyDirection"
	skylight.rotation_degrees = Vector3(-48.0, -27.0, 0.0)
	skylight.light_color = Color("b9cede")
	skylight.light_energy = 0.60
	skylight.shadow_enabled = true
	_world_root.add_child(skylight)
	for light_data in [
		{"name": "ShelterLantern", "position": Vector3(-8.3, 2.55, -6.1),
			"color": Color("ffb878"), "energy": 3.0, "range": 5.2},
		{"name": "GateLantern", "position": Vector3(4.2, 3.73, -11.1),
			"color": Color("ffbe83"), "energy": 3.2, "range": 5.5},
	]:
		var lamp := OmniLight3D.new()
		lamp.name = light_data["name"]
		lamp.position = light_data["position"]
		lamp.light_color = light_data["color"]
		lamp.light_energy = light_data["energy"]
		lamp.omni_range = light_data["range"]
		lamp.shadow_enabled = true
		_world_root.add_child(lamp)


func _setup_trial_v5_candidate() -> void:
	# The foreground stays crisp; only the physical pine bank and mountain
	# painting receive enough aerial perspective to merge at game scale.
	var environment := _environment.environment
	environment.ambient_light_energy = 0.55
	environment.fog_enabled = true
	environment.fog_mode = Environment.FOG_MODE_DEPTH
	environment.fog_light_color = Color("728b99")
	environment.fog_density = 0.38
	environment.fog_depth_begin = 19.0
	environment.fog_depth_end = 64.0
	environment.ssao_enabled = true
	environment.ssao_intensity = 1.18
	environment.ssao_radius = 0.82


func _setup_trial_v6_candidate() -> void:
	_world_root.get_node("DistantMountains").visible = false
	for actor in [_player, _enemy]:
		actor.scale = Vector3.ONE * 0.91
		actor.set("pixel_snap_visual", true)
		_add_ground_contact_shadow(actor)
	($Viewport as SubViewport).msaa_3d = Viewport.MSAA_4X
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("14191b")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("9a9f9e")
	environment.ambient_light_energy = 0.46
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.ssao_enabled = true
	environment.ssao_intensity = 0.78
	environment.ssao_radius = 0.70
	_environment.environment = environment
	($Viewport/World/HeroFill as OmniLight3D).light_color = Color("bdced3")
	($Viewport/World/HeroFill as OmniLight3D).light_energy = 1.16
	($Viewport/World/DummyRim as OmniLight3D).light_color = Color("eac497")
	($Viewport/World/DummyRim as OmniLight3D).light_energy = 0.78
	for light_data in [
		{"name": "WestStoneSconce", "position": Vector3(-5.12, 3.55, -6.62),
			"color": Color("ffbf7b"), "energy": 2.6, "range": 7.1},
		{"name": "EastStoneSconce", "position": Vector3(5.12, 3.55, -6.62),
			"color": Color("ffbf7b"), "energy": 2.6, "range": 7.1},
		{"name": "ChandelierPhysicalPool", "position": Vector3(0.0, 5.8, -2.8),
			"color": Color("f7c78e"), "energy": 3.2, "range": 9.5},
		{"name": "CombatStoneBounce", "position": Vector3(0.1, 3.1, 0.0),
			"color": Color("ebbd85"), "energy": 2.0, "range": 7.2},
	]:
		var lamp := OmniLight3D.new()
		lamp.name = light_data["name"]
		lamp.position = light_data["position"]
		lamp.light_color = light_data["color"]
		lamp.light_energy = light_data["energy"]
		lamp.omni_range = light_data["range"]
		lamp.shadow_enabled = String(light_data["name"]) == "ChandelierPhysicalPool"
		_world_root.add_child(lamp)


func _setup_trial_v13_candidate() -> void:
	# The same source action art supplies the combat-ready first pose and the
	# attack start. This candidate reduces source pixel-density changes while
	# the independent, authored breathing sequence remains in production.
	for side in ["player", "enemy"]:
		var fighter := get_actor_model(side)
		var sprite := get_actor_sprite(side)
		var frames := sprite.sprite_frames.duplicate(true) as SpriteFrames
		frames.clear("idle")
		frames.add_frame("idle", frames.get_frame_texture("attack", 0), 1.0)
		frames.set_meta("scale_idle", frames.get_meta("scale_attack"))
		frames.set_meta("foot_idle_0", frames.get_meta("foot_attack_0"))
		sprite.sprite_frames = frames
		fighter.play_action("idle")
	var floor_mesh := _world.find_child("Hall_scanned_slate_floor", true, false) as MeshInstance3D
	if floor_mesh == null or floor_mesh.mesh == null:
		push_error("V13 source slate floor missing")
		return
	var original := floor_mesh.mesh.surface_get_material(0) as StandardMaterial3D
	if original == null:
		push_error("V13 source slate PBR material missing")
		return
	var floor_material := original.duplicate() as StandardMaterial3D
	floor_material.uv1_scale = Vector3(1.28, 1.28, 1.0)
	floor_mesh.set_surface_override_material(0, floor_material)


func _setup_trial_v16_actor_keypose_candidate() -> void:
	# These are independently generated inhale candidates, normalized against
	# the existing identity canvas. Keep them isolated from the source .tres.
	var inputs := {
		"player": "res://assets/battle/source_first_fight/v16_keypose_candidate/yelingyun_idle_inhale_v1.png",
		"enemy": "res://assets/battle/source_first_fight/v16_keypose_candidate/quick_sword_dummy_idle_compression_v1.png",
	}
	for side in ["player", "enemy"]:
		var fighter := get_actor_model(side)
		var sprite := get_actor_sprite(side)
		var frame := load(inputs[side]) as Texture2D
		if frame == null:
			push_error("V16 independent breath keyframe missing: " + inputs[side])
			continue
		var frames := sprite.sprite_frames.duplicate(true) as SpriteFrames
		var source := frames.get_frame_texture("idle", 0)
		var foot := float(frames.get_meta("foot_idle_0", 0.0))
		frames.clear("idle")
		frames.add_frame("idle", source, 0.58)
		frames.add_frame("idle", frame, 0.86)
		frames.add_frame("idle", source, 0.58)
		frames.set_animation_speed("idle", 1.0)
		frames.set_meta("foot_idle_0", foot)
		frames.set_meta("foot_idle_1", foot)
		frames.set_meta("foot_idle_2", foot)
		frames.set_meta("authored_idle_breath", true)
		if side == "player":
			var contact := load("res://assets/battle/source_first_fight/v16_keypose_candidate/yelingyun_sword_probe_contact_v1.png") as Texture2D
			if contact != null:
				frames.set_frame("sword_probe", 3, contact, frames.get_frame_duration("sword_probe", 3))
				frames.set_meta("blade_tip_sword_probe_3", Vector2(268, 173))
		else:
			var contact := load("res://assets/battle/source_first_fight/v16_keypose_candidate/quick_sword_dummy_hurt_contact_v1.png") as Texture2D
			if contact != null:
				frames.set_frame("hurt", 0, contact, frames.get_frame_duration("hurt", 0))
				frames.set_meta("chest_hurt_0", Vector2(136, 172))
		sprite.sprite_frames = frames
		fighter.play_action("idle")


func _setup_breath_v17_candidate() -> void:
	# Source-pixel motion bake. Face texture, weapon and feet retain the original
	# pixels; gameplay clips keep their browser-sourced SpriteFrames. The authored
	# final keyframe pack remains a separate art gate.
	for side in ["player", "enemy"]:
		var actor := get_actor_model(side)
		var sprite := get_actor_sprite(side)
		var frames := sprite.sprite_frames.duplicate(true) as SpriteFrames
		var source_foot := float(frames.get_meta("foot_idle_0", 0.0))
		var stem := "yelingyun" if side == "player" else "quick_sword_dummy"
		var sheet_path := "res://assets/battle/source_first_fight/breath_v17/frameronin_%s_idle_sheet.png" % stem
		var sheet := load(sheet_path) as Texture2D
		if sheet == null or sheet.get_width() != 640 or sheet.get_height() != 640:
			push_error("Missing reviewed FrameRonin breath atlas: " + sheet_path)
			return
		frames.clear("idle")
		frames.set_animation_speed("idle", 1.0)
		for frame_index in 4:
			var cell := AtlasTexture.new()
			cell.atlas = sheet
			cell.region = Rect2((frame_index % 2) * 320, floori(frame_index / 2.0) * 320, 320, 320)
			cell.filter_clip = true
			frames.add_frame("idle", cell, [0.54, 0.46, 0.58, 0.48][frame_index])
			frames.set_meta("foot_idle_%d" % frame_index, source_foot)
		frames.set_meta("source_pixel_breath_study", true)
		frames.set_meta("frameronin_verified_atlas", true)
		frames.set_meta("authored_idle_breath", true)
		sprite.sprite_frames = frames
		actor.play_action("idle")


func _setup_reference_actor_style() -> void:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(REFERENCE_ACTOR_STYLE))
	if not parsed is Dictionary or parsed.get("schemaVersion") != 1:
		push_error("Invalid reference actor style manifest: " + REFERENCE_ACTOR_STYLE)
		return
	var actors: Dictionary = parsed.get("actors", {})
	for side in ["player", "enemy"]:
		var spec: Dictionary = actors.get(side, {})
		var idle: Dictionary = spec.get("idle", {})
		var canvas: Array = idle.get("canvas", [])
		var sprite := get_actor_sprite(side)
		if String(spec.get("sourceActionSet", "")) != sprite.sprite_frames.resource_path:
			push_error("Reference action set does not match mounted actor: " + side)
			return
		var texture := load(String(idle.get("image", ""))) as Texture2D
		if texture == null or canvas.size() != 2 or texture.get_width() != int(canvas[0]) \
				or texture.get_height() != int(canvas[1]) \
				or int(idle.get("footPixelY", 0)) <= 0 \
				or float(idle.get("scaleFactor", 0.0)) <= 0.0:
			push_error("Invalid reference idle source for " + side)
			return
		var frames := sprite.sprite_frames.duplicate(true) as SpriteFrames
		frames.clear("idle")
		frames.add_frame("idle", texture, 1.0)
		frames.set_animation_speed("idle", 1.0)
		frames.set_animation_loop("idle", true)
		frames.set_meta("scale_idle", float(idle["scaleFactor"]))
		frames.set_meta("foot_idle_0", float(idle["footPixelY"]) / float(canvas[1]))
		frames.set_meta("canvas_width_idle_0", int(canvas[0]))
		frames.set_meta("canvas_height_idle_0", int(canvas[1]))
		frames.set_meta("reference_actor_style_v1", true)
		sprite.sprite_frames = frames
		_reference_breath[side] = (idle.get("breath", {}) as Dictionary).duplicate(true)
	reference_actor_style_ready = true


func _apply_reference_breath(actor: Node3D) -> void:
	if not reference_actor_style_ready:
		return
	var side := "player" if actor == _player else "enemy"
	var sprite := get_actor_sprite(side)
	if sprite == null or sprite.animation != "idle":
		return
	var spec: Dictionary = _reference_breath.get(side, {})
	var period := maxf(0.1, float(spec.get("periodSeconds", 2.8)))
	var wave := sin(TAU * _reference_breath_elapsed / period + float(spec.get("phaseRadians", 0.0)))
	var width_scale := 1.0 + float(spec.get("widthAmplitude", 0.0)) * wave
	var height_scale := 1.0 + float(spec.get("heightAmplitude", 0.0)) * wave
	var frames := sprite.sprite_frames
	var canvas_height := float(frames.get_meta("canvas_height_idle_0", 0))
	var foot := float(frames.get_meta("foot_idle_0", 1.0))
	var base_height := (foot - 0.5) * canvas_height * sprite.pixel_size
	sprite.scale = Vector3(width_scale, height_scale, 1.0)
	if bool(actor.get("pixel_snap_visual")):
		sprite.position.y += base_height * (height_scale - 1.0)
	else:
		sprite.position.y = base_height * height_scale


func _setup_trial_v16_floor_wear() -> void:
	# Blender's glTF exporter preserves the scan but drops our material-node
	# remap. Give each same-UV local mesh two broken abrasion lines instead of
	# darkening its whole oval footprint.
	var wear_shader := load("res://shaders/trial_hall_foot_wear_v2.gdshader") as Shader
	var centers := {
		"Sword_trial_west_pivot_wear": Vector2(-2.45, 0.16),
		"Sword_trial_east_pivot_wear": Vector2(2.45, -0.25),
		"Sword_trial_crossing_wear": Vector2(-0.25, -0.02),
	}
	for wear_name in ["Sword_trial_west_pivot_wear", "Sword_trial_east_pivot_wear", "Sword_trial_crossing_wear"]:
		var wear_mesh := _world.find_child(wear_name, true, false) as MeshInstance3D
		if wear_mesh == null or wear_mesh.mesh == null:
			push_error("V16 local footfall wear missing: " + wear_name)
			continue
		var scan := wear_mesh.mesh.surface_get_material(0) as StandardMaterial3D
		if scan == null:
			push_error("V16 footfall scan material missing: " + wear_name)
			continue
		var scratched := ShaderMaterial.new()
		scratched.shader = wear_shader
		scratched.set_shader_parameter("stone_color", scan.albedo_texture)
		scratched.set_shader_parameter("stone_rough", scan.roughness_texture)
		scratched.set_shader_parameter("stone_normal", scan.normal_texture)
		scratched.set_shader_parameter("scar_center", centers[wear_name])
		scratched.set_shader_parameter("scar_seed", 2.1 if "west" in wear_name else (4.3 if "east" in wear_name else 6.7))
		wear_mesh.set_surface_override_material(0, scratched)


func _setup_trial_v16_fixture_lighting() -> void:
	# The scanned pendant's lowest mesh vertex is at 5.216 m. The V6 light
	# position of 5.8 m sits inside that shadow caster and darkens the hall.
	# Put its warm source just below the visible pendant, keeping real shadows.
	var fixture := _world_root.get_node("ChandelierPhysicalPool") as OmniLight3D
	fixture.position = Vector3(0.0, 5.0, -2.8)
	fixture.light_energy = 8.0


func _setup_tutorial_v17_lighting() -> void:
	# The teaching hall reads from two physical sources: cool daylight through
	# the west clerestory and the existing pendant/sconce flames. Keep the floor
	# darker away from those sources so it does not look uniformly floodlit.
	var environment := _environment.environment
	environment.ambient_light_color = Color("91a4aa")
	environment.ambient_light_energy = 0.34
	var bounce := _world_root.get_node("CombatStoneBounce") as OmniLight3D
	bounce.light_energy = 0.48
	bounce.omni_range = 5.8
	for sconce_name in ["WestStoneSconce", "EastStoneSconce"]:
		var sconce := _world_root.get_node(sconce_name) as OmniLight3D
		sconce.light_energy = 2.15
	var skylight := SpotLight3D.new()
	skylight.name = "WestClerestoryPhysicalDaylight"
	_world_root.add_child(skylight)
	skylight.position = Vector3(-7.55, 4.45, -7.25)
	skylight.look_at(Vector3(-2.1, 0.1, -0.25), Vector3.UP)
	skylight.light_color = Color("b5cfdf")
	skylight.light_energy = 2.8
	skylight.spot_range = 10.6
	skylight.spot_angle = 43.0
	skylight.shadow_enabled = true


func _setup_tutorial_actor_reflected_fill() -> void:
	# The clerestory and rear sconces define the hall, but leave both sprite
	# fronts below readable exposure. A restrained floor bounce reaches only
	# the actors, so the stone and painted background retain their authored light.
	for side in ["player", "enemy"]:
		var sprite := get_actor_sprite(side)
		sprite.layers |= ACTOR_REFLECTED_LIGHT_LAYER
		var bounce := OmniLight3D.new()
		bounce.name = "ActorReflectedFill_" + side
		bounce.light_cull_mask = ACTOR_REFLECTED_LIGHT_LAYER
		bounce.light_color = Color("d9d5c6") if side == "player" else Color("e8cfaa")
		bounce.light_energy = 1.4 if side == "player" else 1.792
		bounce.omni_range = 4.7
		bounce.shadow_enabled = false
		bounce.position = _player_home + Vector3(-0.5, 2.35, 2.55) if side == "player" \
			else _enemy_home + Vector3(0.5, 2.35, 2.75)
		_world_root.add_child(bounce)


func _setup_trial_v7_candidate() -> void:
	_setup_trial_v6_candidate()
	var environment := _environment.environment
	environment.ambient_light_color = Color("b5b1a9")
	environment.ambient_light_energy = 0.40
	environment.ssao_intensity = 0.95
	environment.ssao_radius = 0.84
	($Viewport/World/HeroFill as OmniLight3D).light_energy = 1.02
	($Viewport/World/DummyRim as OmniLight3D).light_energy = 0.52
	for name in ["WestStoneSconce", "EastStoneSconce"]:
		var lamp := _world_root.get_node(name) as OmniLight3D
		lamp.light_energy = 1.72
		lamp.omni_range = 5.1
		lamp.shadow_enabled = false
	(_world_root.get_node("ChandelierPhysicalPool") as OmniLight3D).light_energy = 1.35
	(_world_root.get_node("ChandelierPhysicalPool") as OmniLight3D).omni_range = 8.2
	(_world_root.get_node("ChandelierPhysicalPool") as OmniLight3D).position = Vector3(0.0, 5.25, -4.0)
	(_world_root.get_node("ChandelierPhysicalPool") as OmniLight3D).shadow_enabled = false
	var bounce := _world_root.get_node("CombatStoneBounce") as OmniLight3D
	bounce.light_color = Color("b6bdba")
	bounce.light_energy = 0.82
	bounce.omni_range = 5.8
	var skylight := SpotLight3D.new()
	skylight.name = "V7NorthClerestoryCoolKey"
	_world_root.add_child(skylight)
	skylight.position = Vector3(-5.9, 7.6, -2.3)
	skylight.look_at(Vector3(-0.4, 0.0, -1.0), Vector3.UP)
	skylight.light_color = Color("bfced0")
	skylight.light_energy = 1.05
	skylight.spot_range = 15.0
	skylight.spot_angle = 29.0
	skylight.shadow_enabled = false
	var far_window_bounce := OmniLight3D.new()
	far_window_bounce.name = "V7FarWindowBounce"
	_world_root.add_child(far_window_bounce)
	far_window_bounce.position = Vector3(0.0, 3.3, -11.8)
	far_window_bounce.light_color = Color("d2c399")
	far_window_bounce.light_energy = 1.15
	far_window_bounce.omni_range = 5.7
	far_window_bounce.shadow_enabled = false


func _setup_trial_v8_candidate() -> void:
	# The full 3D court and stairs remain. Replace only the rejected generic
	# gate/bank kit with a licensed authored temple and a distant mountain matte.
	for node in _world.find_children("*", "Node3D", true, false):
		if node.name.begins_with("SM_SectGate_") or node.name.begins_with("SM_V5_Gatehouse_") \
				or node.name.begins_with("SM_PineSlope_") or node.name.begins_with("SM_V5_MiddlePine_") \
				or node.name.begins_with("SM_RealPine_") or node.name.begins_with("SM_Gate_Lantern_"):
			node.visible = false
	# The old gate's lamp occupied the new temple roof and lit it without an emitter.
	(_world_root.get_node("GateLantern") as OmniLight3D).visible = false
	var temple_scene := load("res://assets/battle/hd2d/qingyun_temple_v8/chinese_temple_cc0.glb") as PackedScene
	if temple_scene == null:
		push_error("Missing V8 authored Chinese temple GLB")
		return
	var temple := temple_scene.instantiate() as Node3D
	temple.name = "QingyunTempleCC0Candidate"
	temple.position = Vector3(3.2, 1.82, -12.8)
	temple.scale = Vector3.ONE * 0.30
	_world.add_child(temple)
	var vista := _world.find_child("SM_FarVista_OnlyMountainsAndSky", true, false) as MeshInstance3D
	if vista == null or vista.mesh == null or not vista.mesh.surface_get_material(0) is StandardMaterial3D:
		push_error("V8 mountain material needs the original V5 vista mesh")
		return
	var material := vista.mesh.surface_get_material(0).duplicate() as StandardMaterial3D
	var mountain_texture := load("res://assets/battle/hd2d/qingyun_temple_v8/far_mountains_v1.png") as Texture2D
	if mountain_texture == null:
		push_error("Missing V8 distant mountain art")
		return
	material.albedo_texture = mountain_texture
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	vista.set_surface_override_material(0, material)
	var facade := OmniLight3D.new()
	facade.name = "QingyunTempleFacadeFill"
	facade.position = Vector3(2.0, 5.6, -10.0)
	facade.light_color = Color("b8c9d0")
	facade.light_energy = 1.55
	facade.omni_range = 13.0
	facade.shadow_enabled = false
	_world_root.add_child(facade)


func _add_ground_contact_shadow(actor: Node3D) -> void:
	# A wide attack canvas can put both shoes outside a single center shadow.
	# Two small floor-projected marks follow the visible shoe clusters instead.
	if _ground_decal_texture == null:
		var image := Image.create(48, 48, false, Image.FORMAT_RGBA8)
		for y in 48:
			for x in 48:
				var p := (Vector2(x, y) - Vector2(23.5, 23.5)) / 23.5
				var alpha: float = pow(maxf(0.0, 1.0 - p.length_squared()), 2.0) * 0.67
				image.set_pixel(x, y, Color(1.0, 1.0, 1.0, alpha))
		_ground_decal_texture = ImageTexture.create_from_image(image)
	var decals: Array[Decal] = []
	for i in 2:
		var mark := Decal.new()
		mark.name = "%s_FootContact_%d" % [actor.name, i]
		mark.texture_albedo = _ground_decal_texture
		mark.modulate = Color(0.035, 0.044, 0.048, 1.0)
		mark.albedo_mix = 0.83
		mark.size = Vector3(0.54, 0.48, 0.34)
		mark.position = actor.global_position + Vector3.UP * 0.20
		_world_root.add_child(mark)
		decals.append(mark)
	_ground_decals[actor.get_instance_id()] = decals


func _sync_ground_contact_decals(actor: Node3D) -> void:
	if actor == null or not _ground_decals.has(actor.get_instance_id()):
		return
	var points: Array[Vector3] = actor.get_ground_foot_points(_camera)
	var marks: Array = _ground_decals[actor.get_instance_id()]
	for i in mini(points.size(), marks.size()):
		var point := points[i]
		(marks[i] as Decal).global_position = Vector3(point.x, point.y + 0.20, point.z)


## 屏幕震动的像素 → 世界单位换算。视口 800px 在相机距离处约合 16 世界单位，
## 故 1px ≈ 0.02。震动幅度只有几像素，2% 的估算误差对手感无感知。
const SHAKE_PIXELS_TO_METERS := 0.02


## 触发一次屏幕震动。由 main.gd 在 contact 帧调用，与 hit-stop 同一时刻。
## 通道所有权：本方法只写 Camera3D 的投影偏移（h_offset/v_offset），
## 与 _set_camera_yaw（改 position/朝向）和 _camera_tween（改 position:x）正交。
func pulse_camera(tier: String) -> void:
	if _camera_shake != null:
		_camera_shake.trigger(tier)


## 每帧把震动 offset 应用到相机投影偏移。归零时写回精确 0.0，
## 否则相机会永久歪着。
func _apply_camera_shake(delta: float) -> void:
	if _camera_shake == null or _camera == null:
		return
	var offset := _camera_shake._step(delta)
	_camera.h_offset = offset.x * SHAKE_PIXELS_TO_METERS
	_camera.v_offset = offset.y * SHAKE_PIXELS_TO_METERS


func _set_camera_yaw(yaw: float) -> void:
	# The sampled blade offset is in the camera-facing sprite plane. An old
	# sample would send a repeated strike to the previous yaw's destination.
	_sampled_contact_tips.clear()
	_camera_rig.position = _camera_target
	_camera.position = (_camera_home - _camera_target).rotated(Vector3.UP, yaw)
	_camera_orbit_x = _camera.position.x
	_camera.look_at(_camera_target, Vector3.UP)


func _mesh_count(node: Node) -> int:
	var total := 1 if node is MeshInstance3D and (node as MeshInstance3D).mesh != null else 0
	for child in node.get_children():
		total += _mesh_count(child)
	return total
