extends SceneTree

# Guards the player-visible first slice, rather than counting generated PNGs.
const ENEMY_ROOT := "res://assets/battle/undercurrent_pixel_v1/actor_native_v1/"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1280, 800)
	var battle: Control = load("res://scenes/main.tscn").instantiate()
	root.add_child(battle)
	await process_frame
	var stage: Node = battle.duel_stage
	if stage == null or stage.name != "QingyunPixelStage":
		_fail("real first fight did not mount Qingyun stage")
		return
	var room: Sprite2D = stage.get_node_or_null("Viewport/World/QingyunRoomNative")
	if room == null or room.texture == null \
			or room.texture.resource_path != "res://assets/battle/undercurrent_pixel_v1/qingyun_trial_room_v1.png" \
			or room.texture.get_size() != Vector2(1672, 941) \
			or room.scale.distance_to(Vector2(640.0 / 1672.0, 360.0 / 941.0)) > 0.001:
		_fail("the approved painted Qingyun room is not mounted at the battle scale")
		return
	var foreground: Polygon2D = stage.get_node_or_null("Viewport/World/QingyunForeground")
	var foreground_right: Polygon2D = stage.get_node_or_null("Viewport/World/QingyunForegroundRight")
	if foreground == null or foreground_right == null \
			or foreground.texture != room.texture or foreground_right.texture != room.texture \
			or foreground.uv.size() < 6 or foreground_right.uv.size() < 6 \
			or foreground.uv.size() != foreground.polygon.size() \
			or foreground_right.uv.size() != foreground_right.polygon.size():
		_fail("foreground pillar silhouettes do not use the approved room texture")
		return
	var player: AnimatedSprite2D = stage.get_actor_sprite("player")
	var enemy: AnimatedSprite2D = stage.get_actor_sprite("enemy")
	if player == null or enemy == null or player.sprite_frames == null or enemy.sprite_frames == null:
		_fail("first-fight actor sprites missing")
		return
	for actor in [player, enemy]:
		var expected_root := ENEMY_ROOT
		if not actor.sprite_frames.resource_path.begins_with(expected_root):
			_fail("unexpected first-fight actor resource: " + actor.sprite_frames.resource_path)
			return
		if actor.sprite_frames.get_frame_count("idle") < 2:
			_fail("native actor has no cel idle breathing")
			return
		for i in actor.sprite_frames.get_frame_count("idle"):
			var texture: Texture2D = actor.sprite_frames.get_frame_texture("idle", i)
			if texture == null or not texture.resource_path.begins_with(expected_root):
				_fail("idle is not from its declared actor source")
				return
	if player.sprite_frames.get_frame_count("idle") < 3 \
			or player.sprite_frames.get_frame_count("sword_probe") != 6:
		_fail("hero lacks three idle cels or six sword-probe cels")
		return
	var player_anchor: Node2D = stage.get_node("Viewport/World/PlayerAnchor")
	if player_anchor.get_node_or_null("Contact_left_foot") == null \
			or player_anchor.get_node_or_null("Contact_right_foot") == null \
			or player_anchor.get_node("Shadow").visible:
		_fail("actor still relies on one fixed generic floor shadow")
		return
	if player_anchor.get_node("Contact_left_foot").z_index < room.z_index \
			or player.z_index <= player_anchor.get_node("Contact_left_foot").z_index:
		_fail("contact shadows are hidden behind the opaque room or over the actor")
		return
	var before_scale := player.scale
	var before_frame := player.frame
	await create_timer(0.9).timeout
	if player.scale.distance_to(before_scale) > 0.001 or player.frame == before_frame:
		_fail("idle must move in source cels with fixed whole-body scale")
		return
	var frames := player.sprite_frames
	var durations := [90, 80, 65, 30, 100, 161]
	for i in durations.size():
		var duration_ms := frames.get_frame_duration("sword_probe", i) * 1000.0 \
			/ frames.get_animation_speed("sword_probe")
		if absf(duration_ms - float(durations[i])) > 2.0:
			_fail("sword-probe phase %d differs from source combat clock" % i)
			return
		for marker in ["left_foot", "right_foot", "hand_grip", "weapon_tip"]:
			if not frames.has_meta("%s_sword_probe_%d" % [marker, i]):
				_fail("sword-probe frame %d lacks %s marker" % [i, marker])
				return
	player.stop()
	player.animation = "sword_probe"
	player.frame = 1
	stage.call("_align_feet", player)
	if player_anchor.get_node("Contact_left_foot").visible \
			or player_anchor.get_node("Contact_right_foot").visible:
		_fail("native launch frame should be airborne")
		return
	player.frame = 2
	stage.call("_align_feet", player)
	if player_anchor.get_node("Contact_left_foot").visible \
			or player_anchor.get_node("Contact_right_foot").visible:
		_fail("native windup frame should be airborne")
		return
	player.frame = 3
	stage.call("_align_feet", player)
	if player_anchor.get_node("Contact_left_foot").visible \
			or not player_anchor.get_node("Contact_right_foot").visible:
		_fail("native contact frame must plant only the right boot")
		return
	player.play("idle")
	stage.call("_align_feet", player)
	var first: Button = battle.hand_row.get_child(0)
	if first.get_meta("source_card_id") != "sword_probe":
		_fail("source card identity changed")
		return
	var timing := {"contact_ms": -1.0}
	var started_us := Time.get_ticks_usec()
	stage.contact_frame.connect(func(side: String) -> void:
		if side == "player":
			timing["contact_ms"] = float(Time.get_ticks_usec() - started_us) / 1000.0)
	first.pressed.emit()
	for tick in 90:
		if battle.enemy_label.text.contains("6/7"):
			break
		await create_timer(0.02).timeout
	if not battle.enemy_label.text.contains("6/7"):
		_fail("source card did not reveal damage at contact")
		return
	if absf(float(timing["contact_ms"]) - 235.0) > 42.0:
		_fail("observed sword-probe contact differs from source 235ms by more than one 24 FPS frame: " + str(timing["contact_ms"]))
		return
	var fx: Node = stage.get_node("Viewport/World/HitFX")
	if fx.get("last_profile") != "sword_probe" or fx.get("last_style") != "probe_opening":
		_fail("sword-probe contact profile missing")
		return
	if fx.get("last_start") == null or fx.get("last_end") == null \
			or (fx.get("last_end") as Vector2).x <= (fx.get("last_start") as Vector2).x:
		_fail("sword-probe feedback does not follow the rightward sword vector")
		return
	if (fx.get("last_end") as Vector2).distance_to(stage.get("player_hit_position")) > 2.0:
		_fail("weapon tip and enemy contact point drifted apart")
		return
	root.size = Vector2i(1024, 768)
	await process_frame
	await process_frame
	var viewport: SubViewport = stage.get_node("Viewport")
	if viewport.size != Vector2i(512, 384):
		_fail("1024x768 world no longer uses an integer 2x native pixel scale")
		return
	print("QINGYUN_NATIVE_FIRST_SLICE_PASS approved_room=1672x941 contact_ms=", timing["contact_ms"], " direction=right")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
