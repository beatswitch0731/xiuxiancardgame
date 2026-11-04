extends "res://scripts/duel_stage_source_2d.gd"

const SCENE := "res://scenes/duel_stage_village_2d.tscn"
const SOURCE_IDS := ["thread_ab_village_3", "thread_sword_tomb_2", "q_sword_3",
	"thread_last_lesson_n3"]

var _vfx_clips: Dictionary = {}
var _vfx_overlay: TextureRect
var _contact_effects: Array = []
var _vfx_active := false


static func source_assets_ready(registry: RefCounted, context: Dictionary) -> bool:
	if context.get("sourceCardId") not in SOURCE_IDS \
			or context.get("direction") not in ["left", "right"] \
			or context.get("encounterId") != "":
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
	if art.get("selectedScene") != _expected_scene() \
			or not source_assets_ready(registry, context):
		return false
	stage_context = context.duplicate(true)
	_encounter_id = String(context["sourceCardId"])
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
		var loaded := _load_action_clip(base_action, actions, clip != "hurt",
			clip in ["attack", "skill", "guard"])
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
	var visual: Dictionary = context["pendingResolution"]["combatCard"]["combatPresentation"]
	var enemy_visual: Dictionary = visual["actorCards"]["enemy"]
	_vfx_clips.clear()
	for semantic in ["damage", "shield", "weak"]:
		var effect: Dictionary = visual.get("vfx", {}).get(semantic, {})
		var frames: Array = effect.get("frames", [])
		if frames.is_empty() or int(effect.get("durationMs", 0)) <= 0:
			return false
		var textures: Array = []
		for frame_path in frames:
			var texture: Texture2D = registry.texture_for(String(frame_path))
			if texture == null:
				return false
			textures.append(texture)
		_vfx_clips[semantic] = {"frames": textures,
			"durationMs": int(effect["durationMs"])}
	_background_texture = registry.texture_for(visual["sceneImage"])
	_player_idle = _clips["player"]["attack"]["frames"][0]
	_enemy_idle = registry.texture_for(enemy_visual["image"])
	_clips["enemy"] = {
		"attack": _single_frame(registry.texture_for(enemy_visual["intentFrames"]["attack"])),
		"guard": _single_frame(registry.texture_for(enemy_visual["intentFrames"]["defend"])),
		"buff": _single_frame(registry.texture_for(enemy_visual["intentFrames"]["buff"])),
		"debuff": _single_frame(registry.texture_for(enemy_visual["intentFrames"]["debuff"])),
		"hurt": _single_frame(_enemy_idle),
		"defeat": _single_frame(_enemy_idle),
	}
	return _background_texture != null and _player_idle != null and _enemy_idle != null


func _expected_scene() -> String:
	return SCENE


func _single_frame(texture: Texture2D) -> Dictionary:
	return {"frames": [texture], "durations": [220], "impactAtMs": 0,
		"impactFrameIndex": 0, "contactKind": "", "startSfx": "", "contactSfx": ""}


func _ready() -> void:
	super._ready()
	_vfx_overlay = TextureRect.new()
	_vfx_overlay.name = "SourceVfx"
	_vfx_overlay.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_vfx_overlay.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_vfx_overlay.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_vfx_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vfx_overlay.z_index = 15
	_vfx_overlay.visible = false
	add_child(_vfx_overlay)


func present_action(event: Dictionary) -> bool:
	if not super.present_action(event):
		return false
	var steps: Array = _pending.back()["steps"]
	var effects: Array = []
	var action_side := ""
	if event.get("type") == "ENEMY_ACTION":
		action_side = "enemy"
		var intent: Dictionary = event.get("intent", {})
		if intent.get("type") == "debuff" and intent.get("statusId") == "weak":
			effects.append({"clip": "weak", "target": "player"})
		elif intent.get("type") == "attack" and int(event.get("hpLoss", 0)) > 0:
			effects.append({"clip": "damage", "target": "player"})
		elif intent.get("type") == "defend" and int(intent.get("value", 0)) > 0:
			effects.append({"clip": "shield", "target": "enemy"})
	elif event.get("type") == "CARD_PLAY":
		action_side = "player"
		for effect in event.get("effects", []):
			if not effect is Dictionary:
				continue
			if effect.get("type") == "damage" and int(effect.get("hpLoss", 0)) > 0:
				effects.append({"clip": "damage", "target": "enemy"})
			elif effect.get("type") == "block" and int(effect.get("amount", 0)) > 0:
				effects.append({"clip": "shield", "target": "player"})
			elif effect.get("type") == "status" and effect.get("id") == "weak" \
					and int(effect.get("amount", 0)) > 0:
				effects.append({"clip": "weak",
					"target": effect.get("target", "enemy")})
	if not effects.is_empty():
		for step in steps:
			if step.get("side") == action_side:
				step["vfx"] = effects
				break
	return true


func _play_step(step: Dictionary) -> void:
	_contact_effects = step.get("vfx", [])
	await super._play_step(step)
	while _vfx_active and is_inside_tree():
		await get_tree().process_frame
	_contact_effects = []


func _emit_clip_contact(source: Dictionary, side: String, report_contact: bool,
		play_audio: bool) -> void:
	super._emit_clip_contact(source, side, report_contact, play_audio)
	if _contact_effects.is_empty():
		return
	var effects := _contact_effects.duplicate(true)
	_contact_effects.clear()
	_vfx_active = true
	call_deferred("_run_contact_vfx", effects)


func _run_contact_vfx(effects: Array) -> void:
	for effect in effects:
		await _play_vfx(effect)
	_vfx_active = false


func _play_vfx(step: Dictionary) -> void:
	var clip: Dictionary = _vfx_clips.get(step.get("clip"), {})
	if clip.is_empty() or _vfx_overlay == null:
		return
	var target: TextureRect = _enemy if step.get("target") == "enemy" else _player
	var edge := 260.0 * minf(size.x / 1280.0, size.y / 800.0)
	_vfx_overlay.size = Vector2.ONE * edge
	_vfx_overlay.position = target.position + target.size * 0.5 - _vfx_overlay.size * 0.5
	_vfx_overlay.visible = true
	var frames: Array = clip["frames"]
	var seconds_per_frame := float(clip["durationMs"]) / 1000.0 / float(frames.size())
	for frame in frames:
		_vfx_overlay.texture = frame
		await get_tree().create_timer(seconds_per_frame).timeout
	_vfx_overlay.visible = false
	_vfx_overlay.texture = null
