extends SceneTree

const Presenter = preload("res://scripts/combat_action_presenter.gd")
const Registry = preload("res://scripts/runtime_data_registry.gd")


class FakeRegistry:
	extends RefCounted
	var requested: Array[String] = []
	var image: ImageTexture

	func _init() -> void:
		var pixels := Image.create(2, 2, false, Image.FORMAT_RGBA8)
		pixels.fill(Color.WHITE)
		image = ImageTexture.create_from_image(pixels)

	func read_json(relative_path: String) -> Dictionary:
		var parsed = JSON.parse_string(FileAccess.get_file_as_string("res://content/" + relative_path))
		return parsed if parsed is Dictionary else {}

	func get_first_presentation() -> Dictionary:
		return read_json("data/combat/encounter_presentations.json")["presentations"]["enc_trial_sword_swift"]

	func get_sword_actor() -> Dictionary:
		return read_json("data/combat/path_presentations.json")["paths"]["sword"]["actorCard"]

	func texture_for(source_path: String) -> Texture2D:
		requested.append(source_path)
		return image


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var registry := FakeRegistry.new()
	var player := TextureRect.new()
	var enemy := TextureRect.new()
	player.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	enemy.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	player.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	enemy.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var static_pixels := Image.create(320, 320, false, Image.FORMAT_RGBA8)
	static_pixels.fill(Color.WHITE)
	var static_texture := ImageTexture.create_from_image(static_pixels)
	player.texture = static_texture
	enemy.texture = static_texture
	player.position = Vector2(170, 100)
	player.size = Vector2(300, 320)
	enemy.position = Vector2(800, 120)
	enemy.size = Vector2(260, 290)
	root.add_child(player)
	root.add_child(enemy)
	var presenter = Presenter.new(registry, player, enemy)
	root.add_child(presenter)
	var finished: Array[String] = []
	presenter.presentation_finished.connect(func(kind: String) -> void: finished.append(kind))
	var opening := {"type": "CARD_PLAY", "cardId": "sword_probe", "effects": [{"type": "damage", "hpLoss": 1}]}
	_check(presenter.play_event(opening, {"phase": "PLAYER_TURN"}), "probe accepted")
	_check(presenter.busy, "probe begins")
	_check(presenter._step["frame_set_id"] == "yelingyun_s1_sword_attack_probe_rework_v1", "card ID picks authored attack frames")
	var matched_height := 300.0 * 0.875 / float(presenter._step["metric"]["referenceHeight"])
	_check(absf(player.size.y - matched_height) < 0.01, "action body height matches static alpha body height")
	var static_feet_y := 100.0 + 10.0 + 300.0 * 0.9625
	var action_feet_y := player.position.y + player.size.y * float(presenter._step["metric"]["groundAnchor"]["frameY"][0])
	_check(absf(static_feet_y - action_feet_y) < 0.01, "first action frame feet align with static carrier")
	_check(presenter._step["durations"] == [90.0, 80.0, 65.0, 30.0, 100.0, 193.0], "probe preserves authored contact hold and end paint")
	_check(registry.requested.size() == 18, "attack, hurt, sword trace and contact frames preloaded")
	_check(registry.requested.has("assets/combat/vfx/s3_sword_trace_agc_g2/frame-1.png"), "original sword trace cue bound")
	_check(registry.requested.has("assets/combat/vfx/quick_sword_wood_contact_agc_n5/contact-1.png"), "encounter damage VFX wins over semantic fallback")
	_check(not registry.requested.has("assets/combat/vfx/agc_world_cohesion_v1/damage_contact_agc_u1/contact-1.png"), "generic damage VFX is not selected")
	presenter._process(0.1)
	var second_feet_y := player.position.y + player.size.y * float(presenter._step["metric"]["groundAnchor"]["frameY"][1])
	_check(absf(static_feet_y - second_feet_y) < 0.01, "second action frame keeps its authored feet on ground")
	presenter._process(2.0)
	_check(presenter._step["frame_set_id"] == "quick_sword_dummy_hurt_agc_m1", "enemy hurt follows contact")
	presenter._process(2.0)
	_check(not presenter.busy and finished == ["CARD_PLAY"], "attack exchange finishes")

	_check(presenter.play_event({"type": "CARD_PLAY", "cardId": "sword_guard", "effects": [{"type": "block", "amount": 1}]}, {}), "guard accepted")
	_check(presenter._step["frame_set_id"] == "yelingyun_s1_sword_guard_agc_x2", "sword_guard uses original sword guard fallback")
	presenter._process(2.0)
	_check(not presenter.busy, "guard finishes")

	_check(presenter.play_event({"type": "ENEMY_ACTION", "reactionId": "GUARD", "intent": {"type": "attack"}, "hpLoss": 1}, {}), "enemy exchange accepted")
	_check(presenter._step["frame_set_id"] == "yelingyun_s1_sword_reaction_agc_x3", "player reaction starts first")
	presenter._process(2.0)
	_check(presenter._step["frame_set_id"] == "quick_sword_dummy_attack_agc_m1", "enemy attack follows reaction")
	var enemy_matched_height := 260.0 * 0.440625 / float(presenter._step["metric"]["referenceHeight"])
	_check(absf(enemy.size.y - enemy_matched_height) < 0.01, "enemy attack body uses its static alpha ruler")
	var enemy_static_feet_y := 120.0 + 15.0 + 260.0 * 0.9
	var enemy_action_feet_y := enemy.position.y + enemy.size.y * float(presenter._step["metric"]["groundAnchor"]["frameY"][0])
	_check(absf(enemy_static_feet_y - enemy_action_feet_y) < 0.01, "enemy attack feet align with static carrier")
	presenter._process(2.0)
	_check(presenter._step["frame_set_id"] == "yelingyun_s1_sword_hurt_recover_agc_x1", "actual HP loss selects player hurt")
	presenter._process(2.0)
	_check(not presenter.busy and finished.size() == 3, "reaction exchange finishes")
	if not FileAccess.file_exists("res://content/assets/combat/vfx/quick_sword_wood_contact_agc_n5/contact-1.png"):
		push_error("ACTION_PRESENTER_FAIL encounter damage frame was not synced")
		quit(1)
		return
	var actual_registry := Registry.new()
	var actual_player := TextureRect.new()
	var actual_enemy := TextureRect.new()
	actual_player.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	actual_enemy.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	actual_player.texture = actual_registry.texture_for(String(actual_registry.get_sword_actor()["image"]))
	actual_enemy.texture = actual_registry.texture_for(String(actual_registry.get_first_presentation()["actorCards"]["enemy"]["image"]))
	actual_player.size = Vector2(300, 320)
	actual_enemy.size = Vector2(260, 290)
	root.add_child(actual_player)
	root.add_child(actual_enemy)
	var actual_presenter = Presenter.new(actual_registry, actual_player, actual_enemy)
	root.add_child(actual_presenter)
	_check(actual_presenter._resolve_vfx("damage")["asset_id"] == "fx_quick_sword_wood_contact_agc_n5", "first encounter owns damage VFX")
	var static_metric: Dictionary = actual_presenter._static_metrics["player"]
	var source_texture: Texture2D = actual_player.texture
	_check(absf(_alpha_feet_ratio(source_texture, 12.0 / 255.0) - float(static_metric["groundAnchor"]["y"])) < 0.0001,
		"static carrier feet metric matches source alpha")
	var probe_metric: Dictionary = actual_presenter._world["actionCarrierMetrics"]["yelingyun_s1_sword_attack_probe_rework_v1"]
	var probe_texture: Texture2D = actual_registry.texture_for(String(probe_metric["frameFiles"][0]["path"]))
	_check(absf(_alpha_feet_ratio(probe_texture, 12.0 / 255.0) - float(probe_metric["groundAnchor"]["frameY"][0])) < 0.0001,
		"action frame feet metric matches source alpha")
	for card_id in ["sword_probe", "sword_followthrough", "sword_guard", "sword_sheath_guard", "sword_edge"]:
		var event := {"type": "CARD_PLAY", "cardId": card_id, "effects": [{"type": "damage", "hpLoss": 1}]}
		_check(actual_presenter.play_event(event, {"phase": "PLAYER_TURN"}), "actual source textures load for " + card_id)
	for index in range(12):
		actual_presenter._process(2.0)
	_check(not actual_presenter.busy, "all actual first-hand animations finish")
	print("ACTION_PRESENTER_PASS original_frames=true actual_png=true event_sequences=3 cards=5")
	quit(0)


func _check(condition: bool, message: String) -> void:
	if not condition:
		push_error("ACTION_PRESENTER_FAIL " + message)
		quit(1)


func _alpha_feet_ratio(texture: Texture2D, threshold: float) -> float:
	var picture := texture.get_image()
	for y in range(picture.get_height() - 1, -1, -1):
		for x in range(picture.get_width()):
			if picture.get_pixel(x, y).a > threshold:
				return float(y + 1) / float(picture.get_height())
	return 0.0
