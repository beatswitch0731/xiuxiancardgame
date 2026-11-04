extends "res://scripts/duel_stage_source_2d.gd"

const SCENE := "res://scenes/duel_stage_fellow_2d.tscn"
const SOURCE_ID := "q_fellow"
const MISSION_SCENE := "res://scenes/duel_stage_mission_2d.tscn"
const MISSION_SOURCE_ID := "f_mission"
const DUNGEON_BOSS_SCENE := "res://scenes/duel_stage_guardian_2d.tscn"
const DUNGEON_BOSS_SOURCE_ID := "realm_guardian"
const QI_GATE_SCENE := "res://scenes/duel_stage_qi_gate_2d.tscn"
const QI_GATE_SOURCE_ID := "ch_qi_100"
const FOUNDATION_GATE_SCENE := "res://scenes/duel_stage_foundation_gate_2d.tscn"
const FOUNDATION_GATE_SOURCE_ID := "ch_foundation_100"
const GOLDEN_GATE_SCENE := "res://scenes/duel_stage_golden_gate_2d.tscn"
const GOLDEN_GATE_SOURCE_ID := "ch_golden_100"
const NASCENT_GATE_SCENE := "res://scenes/duel_stage_nascent_gate_2d.tscn"
const NASCENT_GATE_SOURCE_ID := "ch_nascent_100"
const DEITY_GATE_SCENE := "res://scenes/duel_stage_deity_gate_2d.tscn"
const DEITY_GATE_SOURCE_ID := "ch_deity_100"
const TRIBULATION_GATE_SCENE := "res://scenes/duel_stage_tribulation_gate_2d.tscn"
const TRIBULATION_GATE_SOURCE_ID := "ch_tribulation_100"
const BANDIT_SCENE := "res://scenes/duel_stage_bandit_2d.tscn"
const BANDIT_SOURCE_ID := "ds_female_bandit"
const NASCENT_HUNT_SCENE := "res://scenes/duel_stage_nascent_hunt_2d.tscn"
const NASCENT_HUNT_SOURCE_ID := "n_hunt"
const NASCENT_RUINS_SCENE := "res://scenes/duel_stage_nascent_ruins_2d.tscn"
const NASCENT_RUINS_SOURCE_ID := "ar_boss"
const TRIAL_SCENE := "res://scenes/duel_stage_immortal_shadow_2d.tscn"
const TRIAL_SOURCE_ID := "it_combat"
const FOUNDATION_CATALOG_SCENE := "res://scenes/duel_stage_foundation_catalog_2d.tscn"
const COMPANION_SCENE := "res://scenes/duel_stage_companion_old_master_2d.tscn"
const COMPANION_SOURCE_ID := "comp_jian_linger_jle_8_sword_tomb_old_master"
const COMPANION_ENCOUNTER_ID := "enc_companion_jian_linger_tomb"


static func source_assets_ready(registry: RefCounted, context: Dictionary) -> bool:
	var companion: bool = context.get("sourceCardId") == COMPANION_SOURCE_ID
	var catalog: bool = String(context.get("sourceCardId", "")).begins_with(
		"encounter_card_") and context.get("realm") in [
			"foundation", "golden", "nascent", "deity", "tribulation"]
	if context.get("sourceCardId") not in [SOURCE_ID, MISSION_SOURCE_ID,
			DUNGEON_BOSS_SOURCE_ID, QI_GATE_SOURCE_ID, FOUNDATION_GATE_SOURCE_ID, GOLDEN_GATE_SOURCE_ID,
			NASCENT_GATE_SOURCE_ID, DEITY_GATE_SOURCE_ID, TRIBULATION_GATE_SOURCE_ID, BANDIT_SOURCE_ID,
			NASCENT_HUNT_SOURCE_ID, NASCENT_RUINS_SOURCE_ID, TRIAL_SOURCE_ID, COMPANION_SOURCE_ID] and not catalog \
			or context.get("sourceCardId") not in [DUNGEON_BOSS_SOURCE_ID, QI_GATE_SOURCE_ID, FOUNDATION_GATE_SOURCE_ID, GOLDEN_GATE_SOURCE_ID,
				NASCENT_GATE_SOURCE_ID, DEITY_GATE_SOURCE_ID, TRIBULATION_GATE_SOURCE_ID, BANDIT_SOURCE_ID,
				NASCENT_HUNT_SOURCE_ID, NASCENT_RUINS_SOURCE_ID, TRIAL_SOURCE_ID, COMPANION_SOURCE_ID] \
				and not catalog and context.get("direction") != "right" \
			or context.get("direction") not in ["left", "right"] \
			or context.get("encounterId") != (COMPANION_ENCOUNTER_ID if companion else (
			String(context.get("sourceCardId")).trim_prefix("encounter_card_") if catalog else "")):
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
	elif value is String and value.begins_with("assets/") \
			and String(value).get_extension().to_lower() in ["png", "webp", "jpg", "jpeg"]:
		paths.append(value)


func bind_stage_context(context: Dictionary) -> bool:
	var art: Dictionary = ArtRegistry.new().resolve(context)
	var registry = Registry.new()
	var expected_scene := SCENE if context.get("sourceCardId") == SOURCE_ID \
		else COMPANION_SCENE if context.get("sourceCardId") == COMPANION_SOURCE_ID \
		else MISSION_SCENE if context.get("sourceCardId") == MISSION_SOURCE_ID \
		else DUNGEON_BOSS_SCENE if context.get("sourceCardId") == DUNGEON_BOSS_SOURCE_ID \
		else QI_GATE_SCENE if context.get("sourceCardId") == QI_GATE_SOURCE_ID \
		else FOUNDATION_GATE_SCENE if context.get("sourceCardId") == FOUNDATION_GATE_SOURCE_ID \
		else GOLDEN_GATE_SCENE if context.get("sourceCardId") == GOLDEN_GATE_SOURCE_ID \
		else NASCENT_GATE_SCENE if context.get("sourceCardId") == NASCENT_GATE_SOURCE_ID \
		else DEITY_GATE_SCENE if context.get("sourceCardId") == DEITY_GATE_SOURCE_ID \
		else TRIBULATION_GATE_SCENE if context.get("sourceCardId") == TRIBULATION_GATE_SOURCE_ID \
		else BANDIT_SCENE if context.get("sourceCardId") == BANDIT_SOURCE_ID \
		else NASCENT_HUNT_SCENE if context.get("sourceCardId") == NASCENT_HUNT_SOURCE_ID \
		else NASCENT_RUINS_SCENE if context.get("sourceCardId") == NASCENT_RUINS_SOURCE_ID \
		else TRIAL_SCENE if context.get("sourceCardId") == TRIAL_SOURCE_ID \
		else FOUNDATION_CATALOG_SCENE
	if art.get("selectedScene") != expected_scene \
			or not source_assets_ready(registry, context):
		return false
	stage_context = context.duplicate(true)
	_encounter_id = String(context.get("sourceCardId"))
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
	_background_texture = registry.texture_for(visual["sceneImage"])
	_player_idle = _clips["player"]["attack"]["frames"][0]
	_enemy_idle = registry.texture_for(enemy_visual["image"])
	_clips["enemy"] = {
		"attack": _single_frame(registry.texture_for(enemy_visual["intentFrames"]["attack"])),
		"guard": _single_frame(registry.texture_for(enemy_visual["intentFrames"].get(
			"buff", enemy_visual["intentFrames"].get("defend", "")))),
		"hurt": _single_frame(_enemy_idle),
		"defeat": _single_frame(_enemy_idle),
	}
	return _background_texture != null and _player_idle != null and _enemy_idle != null


func show_boss_phase(phase_number: int) -> bool:
	if stage_context.get("sourceCardId") != DUNGEON_BOSS_SOURCE_ID:
		return false
	var frames: Array = stage_context.get("pendingResolution", {}).get(
		"combatCard", {}).get("combatPresentation", {}).get("bossPhaseFrames", [])
	if phase_number < 1 or phase_number > 3 or frames.size() != 4:
		return false
	var texture: Texture2D = Registry.new().texture_for(String(frames[phase_number - 1]))
	if texture == null:
		return false
	_enemy_idle = texture
	if _enemy != null:
		_enemy.texture = texture
	for clip in ["attack", "guard", "hurt", "defeat"]:
		_clips["enemy"][clip] = _single_frame(texture)
	return true


func _single_frame(texture: Texture2D) -> Dictionary:
	return {"frames": [texture], "durations": [220], "impactAtMs": 0,
		"impactFrameIndex": 0, "contactKind": "", "startSfx": "", "contactSfx": ""}
