extends SceneTree

const ART_ROOT := "res://assets/battle/undercurrent_pixel_v1/actor_native_v1/"
const Registry = preload("res://scripts/runtime_data_registry.gd")
const HERO_CLIPS := ["idle", "attack", "guard", "reaction", "hurt", "defeat",
	"sword_probe", "sword_edge", "sword_followthrough", "sword_guard", "sword_sheath_guard"]
const ENEMY_CLIPS := ["idle", "attack", "guard", "hurt", "defeat"]


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1280, 800)
	var battle: Control = load("res://scenes/main.tscn").instantiate()
	root.add_child(battle)
	await process_frame
	var stage: Node = battle.duel_stage
	if stage == null or stage.name != "QingyunPixelStage":
		_fail("first-fight stage missing")
		return
	var scene_text := FileAccess.get_file_as_string("res://scenes/qingyun_pixel_battle_stage.tscn")
	if scene_text.contains("source_first_fight/") or scene_text.contains("duel_stage_pixel_dungeon.tscn"):
		_fail("Qingyun scene still inherits old actor resource dependencies")
		return
	if stage.get_node("Viewport/World/PlayerAnchor").get_node_or_null("ModularActor") != null:
		_fail("Qingyun stage instantiated previous modular actor preview")
		return
	for legacy_path in ["res://assets/battle/source_first_fight/yelingyun_s1.tres",
			"res://assets/battle/source_first_fight/quick_sword_dummy.tres",
			"res://assets/characters/modular_pixel_actor_v1/yelingyun_idle_mist_blue_candidate.png"]:
		if ResourceLoader.has_cached(legacy_path):
			_fail("first-fight entry still preloads old actor asset: " + legacy_path)
			return
	for side in ["player", "enemy"]:
		var sprite: AnimatedSprite2D = stage.get_actor_sprite(side)
		var expected := HERO_CLIPS if side == "player" else ENEMY_CLIPS
		if sprite == null or sprite.sprite_frames == null:
			_fail(side + " sprite missing")
			return
		var expected_resource_root := ART_ROOT
		if not sprite.sprite_frames.resource_path.begins_with(expected_resource_root):
			_fail(side + " still uses previous battle actor frames: " + sprite.sprite_frames.resource_path)
			return
		for clip in expected:
			if not sprite.sprite_frames.has_animation(clip) or sprite.sprite_frames.get_frame_count(clip) == 0:
				_fail(side + " missing " + clip)
				return
			var expected_texture_root := ART_ROOT
			for frame in sprite.sprite_frames.get_frame_count(clip):
				var texture := sprite.sprite_frames.get_frame_texture(clip, frame)
				if texture == null or not texture.resource_path.begins_with(expected_texture_root):
					_fail(side + "/" + clip + " has an unexpected source frame")
					return
		if sprite.scale.y < 0.96 or sprite.scale.y > 1.04:
			_fail(side + " is still scaled from a high-resolution cutout")
			return
	var hero: AnimatedSprite2D = stage.get_actor_sprite("player")
	for card_id in ["sword_probe", "sword_edge", "sword_followthrough", "sword_guard", "sword_sheath_guard"]:
		var texture := hero.sprite_frames.get_frame_texture(card_id, 1)
		if texture.resource_path == hero.sprite_frames.get_frame_texture("idle", 0).resource_path:
			_fail(card_id + " has no distinct action pose")
			return
	var actions: Dictionary = Registry.new().read_json("data/combat/action_presentations.json")
	for card_id in ["sword_probe", "sword_edge", "sword_followthrough", "sword_guard", "sword_sheath_guard"]:
		var action: Dictionary = actions.get("cardActions", {}).get(card_id, {})
		if action.is_empty():
			action = actions.get("paths", {}).get("sword", {}).get("guard", {})
		if not _same_duration(hero.sprite_frames, card_id, action):
			_fail(card_id + " sprite duration differs from source action data")
			return
	var enemy: AnimatedSprite2D = stage.get_actor_sprite("enemy")
	for clip in ["attack", "guard"]:
		var enemy_action: Dictionary = actions.get("encounters", {}).get(
			"enc_trial_sword_swift", {}).get(clip, {})
		if not _same_duration(enemy.sprite_frames, clip, enemy_action):
			_fail("enemy/" + clip + " sprite duration differs from source action data")
			return
	print("QINGYUN_ACTOR_RESET_CONTRACT_PASS clips=11+5")
	quit(0)


func _same_duration(frames: SpriteFrames, clip: String, action: Dictionary) -> bool:
	var source_ms := 0
	for ms in action.get("animation", {}).get("frameDurations", []):
		source_ms += int(ms)
	var native_ms := 0.0
	for frame in frames.get_frame_count(clip):
		native_ms += frames.get_frame_duration(clip, frame) * 1000.0 \
			/ frames.get_animation_speed(clip)
	return source_ms > 0 and absf(native_ms - float(source_ms)) <= 2.0


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
