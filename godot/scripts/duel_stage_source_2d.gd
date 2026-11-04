extends Control

# Source PC-98 battlefield and authored frame actions for mounted encounters.
# CombatDomain remains the only owner of damage, qi, statuses and outcomes.
signal presentation_finished(event_type: String)
signal presentation_missing(event_type: String, reason: String)
signal action_started(side: String, clip: String)
signal contact_frame(side: String)

const Registry = preload("res://scripts/runtime_data_registry.gd")
const ArtRegistry = preload("res://scripts/battlefield_art_registry.gd")
const SOURCE_STAGES := {
	"enc_trial_spell_seal": {"path": "spell", "scene": "res://scenes/duel_stage_spell_2d.tscn"},
	"enc_trial_body_iron": {"path": "body", "scene": "res://scenes/duel_stage_body_2d.tscn"},
	"enc_trial_pill_poison": {"path": "pill", "scene": "res://scenes/duel_stage_pill_2d.tscn"},
	"enc_patrol_qi_mountain_shadow": {"path": "", "scene": "res://scenes/duel_stage_mountain_2d.tscn"},
	"enc_faction_wumeng_elite": {"path": "", "scene": "res://scenes/duel_stage_faction_wumeng_2d.tscn"},
}

var stage_context: Dictionary = {}
var _encounter_id := ""
var _path_id := ""
var _card_families: Dictionary = {}
var _clips: Dictionary = {}
var _audio_runtimes: Dictionary = {}
var _audio_streams: Dictionary = {}
var _action_audio: AudioStreamPlayer
var _contact_audio: AudioStreamPlayer
var _background_texture: Texture2D
var _player_idle: Texture2D
var _enemy_idle: Texture2D
var _background: TextureRect
var _player: TextureRect
var _enemy: TextureRect
var _pending: Array[Dictionary] = []
var _draining := false
var _victory_cue_queued := false
var _victory_cue_played := false


static func source_assets_ready(registry: RefCounted, context: Dictionary) -> bool:
	if not SOURCE_STAGES.has(context.get("encounterId")):
		return false
	var paths := _source_paths(registry, context)
	if paths.is_empty():
		return false
	for source_path in paths:
		if not source_path is String or not source_path.begins_with("assets/") \
				or registry.texture_for(source_path) == null:
			return false
	return true


static func _source_paths(registry: RefCounted, context: Dictionary) -> Array:
	var encounter_id := String(context.get("encounterId", ""))
	if not SOURCE_STAGES.has(encounter_id):
		return []
	var path_id: String = String(context.get("path", "")) if SOURCE_STAGES[
		encounter_id]["path"] == "" else SOURCE_STAGES[encounter_id]["path"]
	if not path_id in ["sword", "spell", "body", "pill"]:
		return []
	var presentation: Dictionary = registry.read_json(
		"data/combat/encounter_presentations.json").get("presentations", {}).get(encounter_id, {})
	var path_presentation: Dictionary = registry.read_json(
		"data/combat/path_presentations.json").get("paths", {}).get(path_id, {})
	var actions: Dictionary = registry.read_json("data/combat/action_presentations.json")
	if presentation.get("sceneImage") != context.get("sceneImage") \
			or presentation.get("actorCards", {}).get("enemy", {}).get("image") == null \
			or path_presentation.get("actorCard", {}).get("image") == null:
		return []
	var result: Array = [context["sceneImage"],
		presentation["actorCards"]["enemy"]["image"],
		path_presentation["actorCard"]["image"]]
	var deck: Array = context.get("deck", []) if SOURCE_STAGES[
		encounter_id]["path"] == "" else registry.read_json(
		"data/combat/deck_progression.json").get("paths", {}).get(path_id, {}).get("starterDeck", [])
	if deck.is_empty():
		return []
	for card_id in deck:
		var card: Dictionary = registry.get_battle_card(String(card_id))
		if card.is_empty():
			return []
		result.append(card.get("cardArt", {}).get("image", ""))
		var base_id := String(card_id).trim_suffix("+")
		var card_action: Dictionary = actions.get("cardActions", {}).get(base_id, {})
		if card_action.get("sourceCardId") == base_id:
			var card_animation: Dictionary = card_action.get("animation", {})
			var card_frames: Array = card_animation.get("frames", [])
			if card_frames.is_empty() or card_frames.size() != \
					card_animation.get("frameDurations", []).size():
				return []
			result.append_array(card_frames)
	for side_actions in [actions.get("paths", {}).get(path_id, {}),
			actions.get("encounters", {}).get(encounter_id, {})]:
		for action in side_actions.values():
			if not action is Dictionary or not action.get("animation") is Dictionary:
				return []
			var animation: Dictionary = action["animation"]
			var frames: Array = animation.get("frames", [])
			var durations: Array = animation.get("frameDurations", [])
			if frames.is_empty() or frames.size() != durations.size():
				return []
			result.append_array(frames)
			for card_id in action.get("variantsBySourceId", {}):
				if not deck.has(card_id) and not deck.has(String(card_id) + "+"):
					continue
				var variant: Dictionary = action["variantsBySourceId"][card_id]
				var variant_animation: Dictionary = variant.get("animation", {})
				var variant_frames: Array = variant_animation.get("frames", [])
				if variant_frames.is_empty() or variant_frames.size() != \
						variant_animation.get("frameDurations", []).size():
					return []
				result.append_array(variant_frames)
	return result


func bind_stage_context(context: Dictionary) -> bool:
	var encounter_id := String(context.get("encounterId", ""))
	if not SOURCE_STAGES.has(encounter_id):
		return false
	var art: Dictionary = ArtRegistry.new().resolve(context)
	if art.get("selectedScene") != SOURCE_STAGES[encounter_id]["scene"]:
		return false
	var registry = Registry.new()
	if not source_assets_ready(registry, context):
		return false
	stage_context = context.duplicate(true)
	_encounter_id = encounter_id
	_path_id = String(context.get("path", "")) if SOURCE_STAGES[
		encounter_id]["path"] == "" else SOURCE_STAGES[encounter_id]["path"]
	_card_families.clear()
	var deck: Array = context.get("deck", []) if SOURCE_STAGES[
		encounter_id]["path"] == "" else registry.read_json(
		"data/combat/deck_progression.json")["paths"][_path_id]["starterDeck"]
	for card_id in deck:
		var card: Dictionary = registry.get_battle_card(String(card_id))
		if card.is_empty():
			return false
		_card_families[card_id] = _card_action_family(card)
	var actions: Dictionary = registry.read_json("data/combat/action_presentations.json")
	var audio_catalog: Dictionary = registry.read_json("data/audio/path_identity.json")
	if audio_catalog.get("assetRoot") != "assets/audio/":
		return false
	_audio_runtimes.clear()
	_audio_streams.clear()
	_index_audio_runtimes(audio_catalog)
	if not _load_audio_cue("sfx_treasure"):
		return false
	_clips = {"player": {}, "enemy": {}}
	for side in ["player", "enemy"]:
		var source_actions: Dictionary = actions["paths"][_path_id] if side == "player" \
			else actions["encounters"][_encounter_id]
		for clip in source_actions:
			var base_action: Dictionary = source_actions[clip]
			# Sidecar hurt and enemy collapse have no emitted cue phase. Defend
			# and reaction emit actionStarted but no contact/status payoff.
			var has_start: bool = clip != "hurt" and not (side == "enemy" and clip == "defeat")
			var has_contact: bool = clip in ["attack", "skill", "guard"] \
				and not (side == "enemy" and clip == "guard")
			var base_clip := _load_action_clip(base_action, actions, has_start, has_contact)
			if base_clip.is_empty():
				return false
			_clips[side][clip] = base_clip
			if side == "player":
				for card_id in base_action.get("variantsBySourceId", {}):
					if not deck.has(card_id) and not deck.has(String(card_id) + "+"):
						continue
					var variant_action: Dictionary = base_action.duplicate(true)
					var variant: Dictionary = base_action["variantsBySourceId"][card_id]
					variant_action.merge(variant, true)
					var stage: Dictionary = base_action.get("stage", {}).duplicate(true)
					stage.merge(variant.get("stage", {}), true)
					variant_action["stage"] = stage
					var variant_clip := _load_action_clip(variant_action, actions)
					if variant_clip.is_empty():
						return false
					for mounted_id in [String(card_id), String(card_id) + "+"]:
						if deck.has(mounted_id):
							_clips[side][clip + "@" + mounted_id] = variant_clip
	for card_id in deck:
		var base_id := String(card_id).trim_suffix("+")
		var card_action: Dictionary = actions.get("cardActions", {}).get(base_id, {})
		var family := String(_card_families.get(card_id, ""))
		if card_action.get("sourceCardId") != base_id \
				or card_action.get("actionFamily") != family:
			continue
		var card_clip := _load_action_clip(card_action, actions)
		if card_clip.is_empty():
			return false
		# Browser source gives an authored card action priority over its family
		# and source-ID variant. Keep that priority for mounted scenes.
		_clips["player"][family + "@" + card_id] = card_clip
	_background_texture = load("res://content/" + String(context["sceneImage"])) as Texture2D
	_player_idle = _clips["player"]["attack"]["frames"][0]
	var enemy_image: String = registry.read_json(
		"data/combat/encounter_presentations.json")["presentations"][_encounter_id][
		"actorCards"]["enemy"]["image"]
	_enemy_idle = load("res://content/" + enemy_image) as Texture2D
	return _background_texture != null and _player_idle != null and _enemy_idle != null


func _load_action_clip(action: Dictionary, actions: Dictionary,
		has_start: bool = true, has_contact: bool = true) -> Dictionary:
	var animation: Dictionary = action.get("animation", {})
	var frames: Array = animation.get("frames", [])
	if frames.is_empty() or frames.size() != animation.get("frameDurations", []).size():
		return {}
	var sfx_cue: Dictionary = actions.get("sfxCues", {}).get(
		String(action.get("sfxCueId", "")), {})
	if sfx_cue.is_empty():
		return {}
	var start_sfx := String(sfx_cue.get("actionStarted", sfx_cue.get("actorDefeated", ""))) if has_start else ""
	var contact_sfx := String(sfx_cue.get("impact", sfx_cue.get(
		"statusApplied", sfx_cue.get("reactionResolved", "")))) if has_contact else ""
	for cue_id in [start_sfx, contact_sfx]:
		if not cue_id.is_empty() and not _load_audio_cue(cue_id):
			return {}
	var textures: Array = []
	for source_path in frames:
		var frame_texture := load("res://content/" + String(source_path)) as Texture2D
		if frame_texture == null:
			return {}
		textures.append(frame_texture)
	return {"frames": textures, "durations": animation["frameDurations"].duplicate(),
		"impactAtMs": int(action.get("stage", {}).get("impactAtMs", 0)),
		"impactFrameIndex": _impact_frame_index(animation, textures.size()),
		"contactKind": String(action.get("stage", {}).get("contact", "")),
		"startSfx": start_sfx, "contactSfx": contact_sfx}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_action_audio = AudioStreamPlayer.new()
	_action_audio.name = "SourceActionSfx"
	add_child(_action_audio)
	_contact_audio = AudioStreamPlayer.new()
	_contact_audio.name = "SourceContactSfx"
	add_child(_contact_audio)
	_background = TextureRect.new()
	_background.name = "SourceBattlefield"
	_background.texture = _background_texture
	_background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_background)
	_background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_player = _make_actor("SourceHero", _player_idle)
	_enemy = _make_actor("SourceEnemy", _enemy_idle)
	resized.connect(_layout_actors)
	_layout_actors()


func _make_actor(actor_name: String, idle: Texture2D) -> TextureRect:
	var actor := TextureRect.new()
	actor.name = actor_name
	actor.texture = idle
	actor.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	actor.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	actor.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	actor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(actor)
	return actor


func _layout_actors() -> void:
	if _player == null or _enemy == null:
		return
	var bounds := size
	var scale_factor := minf(bounds.x / 1280.0, bounds.y / 800.0)
	var actor_size := Vector2.ONE * (500.0 * scale_factor)
	_player.size = actor_size
	_enemy.size = actor_size
	_player.position = Vector2(bounds.x * 0.28 - actor_size.x * 0.5,
		bounds.y * 0.72 - actor_size.y * 0.83)
	_enemy.position = Vector2(bounds.x * 0.74 - actor_size.x * 0.5,
		bounds.y * 0.69 - actor_size.y * 0.76)


func has_hd2d_assets() -> bool:
	return _background != null and _background.texture != null \
		and _player != null and _player.texture != null \
		and _enemy != null and _enemy.texture != null \
		and _clips.get("player", {}).has("guard") \
		and _clips.get("player", {}).has("skill") \
		and _clips.get("player", {}).has("attack") \
		and _clips.get("enemy", {}).has_all(["attack", "guard", "hurt", "defeat"])


func present_action(event: Dictionary) -> bool:
	var kind := String(event.get("type", ""))
	var steps: Array[Dictionary] = []
	if kind == "CARD_PLAY":
		var card_id := String(event.get("cardId", ""))
		if not _card_families.has(card_id):
			presentation_missing.emit(kind, "Unknown mounted-stage card: " + card_id)
			return false
		var damage := 0
		for effect in event.get("effects", []):
			if effect is Dictionary and effect.get("type") == "damage":
				damage += int(effect.get("hpLoss", 0))
		var player_clip: String = _card_families[card_id]
		if _clips["player"].has(player_clip + "@" + card_id):
			player_clip += "@" + card_id
		steps.append({"side": "player", "clip": player_clip,
			"contact": true, "playContactAudio": _card_event_has_payoff(event)})
		if event.get("victory", false):
			steps.append({"side": "enemy", "clip": "defeat", "contact": false})
		elif damage > 0:
			steps.append({"side": "enemy", "clip": "hurt", "contact": false})
	elif kind == "ENEMY_ACTION":
		if event.get("reactionId") != "TAKE_HIT":
			steps.append({"side": "player", "clip": "reaction", "contact": false})
		var intent: Dictionary = event.get("intent", {})
		var intent_type := String(intent.get("type", ""))
		var enemy_clip := "attack" if intent_type == "attack" else (
			intent_type if _clips["enemy"].has(intent_type) else "guard")
		steps.append({"side": "enemy", "clip": enemy_clip, "contact": enemy_clip == "attack"})
		if int(event.get("hpLoss", 0)) > 0:
			steps.append({"side": "player", "clip": "hurt", "contact": false})
	elif kind == "DEFEAT":
		steps.append({"side": "player", "clip": "defeat", "contact": false})
	else:
		return false
	for step in steps:
		if not _clips.get(step["side"], {}).has(step["clip"]):
			presentation_missing.emit(kind, "Missing mounted-stage clip: " + str(step))
			return false
	_pending.append({"type": kind, "steps": steps})
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


func _drain_presentations() -> void:
	if _draining:
		return
	_draining = true
	while not _pending.is_empty() and is_inside_tree():
		var entry: Dictionary = _pending.pop_front()
		for step in entry["steps"]:
			await _play_step(step)
		presentation_finished.emit(String(entry["type"]))
	_draining = false
	_flush_victory_cue()


func _play_step(step: Dictionary) -> void:
	var side := String(step["side"])
	var clip := String(step["clip"])
	var actor: TextureRect = _player if side == "player" else _enemy
	var source: Dictionary = _clips[side][clip]
	action_started.emit(side, clip)
	_play_audio_cue(String(source.get("startSfx", "")), _action_audio)
	var frames: Array = source["frames"]
	var durations: Array = source["durations"]
	var projectile: bool = source.get("contactKind") == "projectile"
	var contact_ms := int(source.get("impactAtMs", 0))
	var impact_index := int(source.get("impactFrameIndex", 0))
	var elapsed := 0
	var contacted := false
	for index in frames.size():
		actor.texture = frames[index]
		if not projectile and not contacted and index >= impact_index:
			contacted = true
			_emit_clip_contact(source, side, step.get("contact", false),
				step.get("playContactAudio", true))
		var duration_ms := int(durations[index])
		if projectile and not contacted and contact_ms <= elapsed + duration_ms:
			var before_contact := clampi(contact_ms - elapsed, 0, duration_ms)
			if before_contact > 0:
				await get_tree().create_timer(float(before_contact) / 1000.0).timeout
			contacted = true
			_emit_clip_contact(source, side, step.get("contact", false),
				step.get("playContactAudio", true))
			if duration_ms > before_contact:
				await get_tree().create_timer(float(duration_ms - before_contact) / 1000.0).timeout
		else:
			await get_tree().create_timer(float(duration_ms) / 1000.0).timeout
		elapsed += duration_ms
	if not contacted:
		_emit_clip_contact(source, side, step.get("contact", false),
			step.get("playContactAudio", true))
	if clip != "defeat":
		actor.texture = _player_idle if side == "player" else _enemy_idle


func _emit_clip_contact(source: Dictionary, side: String, report_contact: bool,
		play_audio: bool) -> void:
	if play_audio:
		_play_audio_cue(String(source.get("contactSfx", "")), _contact_audio)
	if report_contact:
		contact_frame.emit(side)


func _card_event_has_payoff(event: Dictionary) -> bool:
	for effect in event.get("effects", []):
		if not effect is Dictionary:
			continue
		if effect.get("type") == "damage":
			return true
		if effect.get("type") in ["block", "heal", "status"] and int(effect.get("amount", 0)) > 0:
			return true
	return false


func _impact_frame_index(animation: Dictionary, frame_count: int) -> int:
	var authored := int(animation.get("impactFrameIndex", -1))
	return authored if authored > 0 and authored < frame_count else (
		int(floor(float(frame_count) / 2.0)) if frame_count >= 3 else 0)


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


func _card_action_family(card: Dictionary) -> String:
	# DeckCombatSystem._deriveCardSemanticPresentation source priority.
	var kinds := {}
	for effect in card.get("effects", []):
		if effect is Dictionary:
			kinds[effect.get("type", "")] = true
	if kinds.has("damage") and card.get("type") == "attack":
		return "attack"
	if kinds.has("damage") or kinds.has("backlash") or kinds.has("heal"):
		return "skill"
	if kinds.has("block"):
		return "guard"
	return "skill"


func _load_audio_cue(cue_id: String) -> bool:
	if _audio_streams.has(cue_id):
		return true
	var runtime: Dictionary = _audio_runtimes.get(cue_id, {})
	var relative: String = String(runtime.get("path", ""))
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
