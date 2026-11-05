extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1280, 800)
	var battle: Control = load("res://scenes/main.tscn").instantiate()
	root.add_child(battle)
	await process_frame
	var stage: Node = battle.duel_stage
	if stage == null or not stage.has_method("get_scene_layout"):
		_fail("Actual stage exposes no shared scene layout; room data is hardcoded")
		return
	var world: Node2D = stage.get_node("Viewport/World")
	var room: Sprite2D = world.get_node("QingyunRoomNative")
	if room.texture.resource_path != "res://assets/battle/undercurrent_pixel_v1/qingyun_trial_room_v1.png":
		_fail("Approved room texture changed")
		return
	if not world.y_sort_enabled:
		_fail("Room actors and pillars do not sort by ground position")
		return
	for name in ["QingyunForeground", "QingyunForegroundRight"]:
		var pillar: Polygon2D = world.get_node(name)
		if pillar.z_index != 1 or pillar.position.y < 300 or pillar.polygon.size() < 6 \
				or pillar.uv.size() != pillar.polygon.size() or pillar.texture != room.texture:
			_fail("Pillar is not grounded at its base on the actor sorting layer")
			return
	for name in ["PlayerAnchor", "EnemyAnchor"]:
		var anchor: Node2D = world.get_node(name)
		var actor: AnimatedSprite2D = anchor.get_node("Sprite")
		if anchor.z_index != 1 or actor.z_index != 0 or anchor.get_node("Contact_left_foot").z_index != -1:
			_fail("Actor/foot shadow layers do not share the intended world ordering")
			return
	var ordinary: Dictionary = stage.get_scene_layout("symmetric")
	var wide: Dictionary = stage.get_scene_layout("wide")
	if _point(ordinary["player_support"]) != Vector2(248, 244) or _point(ordinary["enemy_support"]) != Vector2(392, 244) \
			or _point(wide["player_support"]) != Vector2(232, 244) or _point(wide["enemy_support"]) != Vector2(408, 244):
		_fail("Shared preview layouts are missing or have lost their symmetric ground positions")
		return
	# Callers receive values, not a mutable handle to the stage's configuration.
	ordinary["player_support"][0] = 0
	if stage.get_scene_layout("symmetric")["player_support"][0] != 248:
		_fail("Preview changed the shared room configuration")
		return
	if stage.player_home != Vector2(290, 244) or stage.enemy_home != Vector2(420, 237):
		_fail("Unvalidated study layout leaked into formal combat travel")
		return
	print("QINGYUN_STAGE_REUSE_PASS approved_room=true layouts=2 grounded_depth_layers=true formal_timing_unchanged=true")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)


func _point(value: Array) -> Vector2:
	return Vector2(value[0], value[1])
