extends "res://scripts/duel_stage_source_2d.gd"

# The quest owns this inline presentation. The source stage provides the
# path's authored card motions; the hound's own intent frames and weak VFX
# come from the persisted, source-verified quest choice.
const SCENE := "res://scenes/duel_stage_whitefox_2d.tscn"
const SOURCE_ID := "q_whiteFox_3"

var _weak_frames: Array = []
var _weak_duration_ms := 0
var _weak_pose: Texture2D
var _weak_vfx: TextureRect


static func source_assets_ready(registry: RefCounted, context: Dictionary) -> bool:
	if context.get("sourceCardId") != SOURCE_ID or context.get("encounterId") != "":
		return false
	var presentation: Dictionary = context.get("pendingResolution", {}).get(
		"combatCard", {}).get("combatPresentation", {})
	if presentation.get("sceneImage") != context.get("sceneImage") \
			or presentation.get("presentationId") != context.get("presentationId") \
			or presentation.get("battlefieldId") != context.get("battlefieldId"):
		return false
	var deck: Array = context.get("deck", [])
	var path_id := String(context.get("path", ""))
	var actions: Dictionary = registry.read_json("data/combat/action_presentations.json")
	var path_actions: Dictionary = actions.get("paths", {}).get(path_id, {})
	if deck.is_empty() or path_actions.is_empty():
		return false
	var paths: Array = []
	_collect_images(presentation, paths)
	for card_id in deck:
		var card: Dictionary = registry.get_battle_card(String(card_id))
		if card.is_empty():
			return false
		paths.append(card.get("cardArt", {}).get("image", ""))
		var base_id := String(card_id).trim_suffix("+")
		var authored: Dictionary = actions.get("cardActions", {}).get(base_id, {})
		if authored.get("sourceCardId") == base_id:
			paths.append_array(authored.get("animation", {}).get("frames", []))
	for action in path_actions.values():
		if not action is Dictionary:
			return false
		paths.append_array(action.get("animation", {}).get("frames", []))
		for card_id in action.get("variantsBySourceId", {}):
			if deck.has(card_id) or deck.has(String(card_id) + "+"):
				paths.append_array(action["variantsBySourceId"][card_id].get(
					"animation", {}).get("frames", []))
	if paths.is_empty():
		return false
	for source_path in paths:
		if not source_path is String or not source_path.begins_with("assets/") \
				or registry.texture_for(source_path) == null:
			return false
	return true


static func _collect_images(value: Variant, paths: Array) -> void:
	if value is Dictionary:
		for child in value.values():
			_collect_images(child, paths)
	elif value is Array:
		for child in value:
			_collect_images(child, paths)
	elif value is String and value.begins_with("assets/"):
		paths.append(value)


func bind_stage_context(context: Dictionary) -> bool:
	var art: Dictionary = ArtRegistry.new().resolve(context)
	var registry = Registry.new()
	if art.get("selectedScene") != SCENE or not source_assets_ready(registry, context):
		return false
	stage_context = context.duplicate(true)
	_encounter_id = SOURCE_ID
	_path_id = String(context["path"])
	var deck: Array = context["deck"]
	_card_families.clear()
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
	for clip in actions["paths"][_path_id]:
		var base_action: Dictionary = actions["paths"][_path_id][clip]
		var has_start: bool = clip != "hurt"
		var has_contact: bool = clip in ["attack", "skill", "guard"]
		var loaded := _load_action_clip(base_action, actions, has_start, has_contact)
		if loaded.is_empty():
			return false
		_clips["player"][clip] = loaded
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
					_clips["player"][clip + "@" + mounted_id] = variant_clip
	for card_id in deck:
		var base_id := String(card_id).trim_suffix("+")
		var authored: Dictionary = actions.get("cardActions", {}).get(base_id, {})
		var family := String(_card_families.get(card_id, ""))
		if authored.get("sourceCardId") != base_id or authored.get("actionFamily") != family:
			continue
		var card_clip := _load_action_clip(authored, actions)
		if card_clip.is_empty():
			return false
		_clips["player"][family + "@" + card_id] = card_clip
	var presentation: Dictionary = context["pendingResolution"]["combatCard"]["combatPresentation"]
	var enemy_visual: Dictionary = presentation["actorCards"]["enemy"]
	_background_texture = registry.texture_for(presentation["sceneImage"])
	_player_idle = registry.texture_for(presentation["actorCards"]["player"]["image"])
	_enemy_idle = registry.texture_for(enemy_visual["image"])
	_weak_pose = registry.texture_for(enemy_visual["intentFrames"]["debuff"])
	_clips["enemy"] = {
		"attack": _single_frame(registry.texture_for(enemy_visual["intentFrames"]["attack"])),
		"guard": _single_frame(_weak_pose),
		"hurt": _single_frame(_enemy_idle),
		"defeat": _single_frame(_enemy_idle),
	}
	_weak_frames.clear()
	for source_path in presentation["vfx"]["weak"]["frames"]:
		_weak_frames.append(registry.texture_for(source_path))
	_weak_duration_ms = int(presentation["vfx"]["weak"]["durationMs"])
	return _background_texture != null and _player_idle != null and _enemy_idle != null \
		and _weak_pose != null and _weak_frames.size() == 4 and _weak_duration_ms > 0


func _single_frame(texture: Texture2D) -> Dictionary:
	return {"frames": [texture], "durations": [220], "impactAtMs": 0,
		"impactFrameIndex": 0, "contactKind": "", "startSfx": "", "contactSfx": ""}


func _ready() -> void:
	super._ready()
	_weak_vfx = TextureRect.new()
	_weak_vfx.name = "SourceWeakVfx"
	_weak_vfx.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_weak_vfx.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_weak_vfx.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_weak_vfx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_weak_vfx.visible = false
	add_child(_weak_vfx)
	resized.connect(_layout_weak_vfx)
	_layout_weak_vfx()


func _layout_weak_vfx() -> void:
	if _weak_vfx == null:
		return
	var scale_factor := minf(size.x / 1280.0, size.y / 800.0)
	var effect_size := Vector2.ONE * (270.0 * scale_factor)
	_weak_vfx.size = effect_size
	_weak_vfx.position = Vector2(size.x * 0.28 - effect_size.x * 0.5,
		size.y * 0.72 - effect_size.y * 0.72)


func present_action(event: Dictionary) -> bool:
	var accepted := super.present_action(event)
	if accepted and event.get("type") == "ENEMY_ACTION" \
			and event.get("intent", {}).get("type") == "debuff" and not _pending.is_empty():
		var entry: Dictionary = _pending.back()
		var steps: Array = entry["steps"]
		for index in steps.size():
			if steps[index].get("side") == "enemy":
				steps[index]["houndWeak"] = true
		entry["steps"] = steps
		_pending[_pending.size() - 1] = entry
	return accepted


func _play_step(step: Dictionary) -> void:
	if step.get("houndWeak") != true:
		await super._play_step(step)
		return
	action_started.emit("enemy", "guard")
	_enemy.texture = _weak_pose
	_weak_vfx.visible = true
	var duration := float(_weak_duration_ms) / float(_weak_frames.size()) / 1000.0
	for frame in _weak_frames:
		_weak_vfx.texture = frame
		await get_tree().create_timer(duration).timeout
	_weak_vfx.visible = false
	_enemy.texture = _enemy_idle
