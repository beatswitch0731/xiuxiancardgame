extends SceneTree

const Registry = preload("res://scripts/runtime_data_registry.gd")
const Domain = preload("res://scripts/noncombat_domain.gd")
const Session = preload("res://scripts/noncombat_run_session.gd")
const OpeningScene = preload("res://scenes/noncombat_opening.tscn")
const Plan = preload("res://scripts/battle_plan_resolver.gd")
const FIXTURE := "res://tests/fixtures/foundation_sword_q3_heart_v2.json"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	for direction in ["left", "right"]:
		var root_dir := "user://tests/foundation_sword_live_%s_%d" % [direction, Time.get_ticks_usec()]
		if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(root_dir)) != OK:
			return _fail("could not stage sword trial slot directory")
		var path := root_dir + "/noncombat_opening_slot_2_v1.json"
		var store = Session.new(path, "slot_2")
		var file := FileAccess.open(store.v2_path, FileAccess.WRITE)
		if file == null:
			return _fail("could not stage natural q3 checkpoint")
		file.store_buffer(FileAccess.get_file_as_bytes(FIXTURE))
		file.close()
		var game = Domain.new(Registry.new(), store, "slot_2")
		game._ripple_flow.roll_override = 0.999
		game._hint_flow.roll_override = 0.0
		game._market_flow.roll_override = 0.0
		if not game.restore() or not game.choose(direction, game.issue_choice_token()) \
				or not game.choose("left", game.issue_choice_token()) \
				or game.state.get("phase") != "BATTLE_PENDING":
			return _fail("natural sword trial did not persist battle: " + direction)
		var pending_bytes := FileAccess.get_file_as_bytes(store.v2_path)
		var cold = Domain.new(Registry.new(), Session.new(path, "slot_2"), "slot_2")
		cold._ripple_flow.roll_override = 0.999
		cold._hint_flow.roll_override = 0.0
		cold._market_flow.roll_override = 0.0
		if not cold.restore():
			return _fail("natural sword trial unmodified cold restore failed: "
				+ JSON.stringify({"store": cold._store.last_error,
					"flow": cold.flow_failure_reason(),
					"quest": cold._quest_flow.last_error,
					"ripple": cold._ripple_flow.last_error,
					"normal": cold._normal_flow_error}))
		var story: Control = OpeningScene.instantiate()
		story.save_path = ""
		root.add_child(story)
		await process_frame
		story.opening = cold
		cold.changed.connect(story._on_opening_changed)
		story.slot_screen.visible = false
		story.name_screen.visible = false
		story.path_screen.visible = false
		story.story_screen.visible = true
		story._set_scene_surface(true)
		story._render()
		await process_frame
		var launch: Button = story.find_child("LaunchBattle", true, false)
		if launch == null or launch.disabled:
			var resolver = Plan.new(Registry.new())
			var plan: Dictionary = resolver.resolve_persisted(game.state)
			return _fail("natural sword trial desktop launch unavailable: " + direction
				+ " " + JSON.stringify({"plan": plan, "error": resolver.last_error,
					"phase": story.opening.state.get("phase"),
					"status": story.status_label.text}))
		launch.pressed.emit()
		await process_frame
		var battle: Control = story.active_battle
		if battle == null or not battle.stage_assets_ready or battle.duel_stage == null \
				or battle.duel_stage.get_script().resource_path != \
					"res://scripts/duel_stage_sword_tomb_2d.gd" \
				or FileAccess.get_file_as_bytes(store.v2_path) != pending_bytes:
			return _fail("natural sword trial did not mount existing sword tomb stage: " + direction)
		var flee_button: Button = battle.get_node_or_null("FleeBattle")
		if flee_button == null or flee_button.disabled:
			return _fail("natural sword trial stage did not allow retreat: " + direction)
		flee_button.pressed.emit()
		var result: Dictionary = battle.terminal_result()
		var return_button: Button = battle.get_node_or_null("ReturnToStory")
		if result.get("outcome") != "flee" or return_button == null or return_button.disabled:
			return _fail("natural sword trial did not produce a returnable result: " + direction)
		return_button.pressed.emit()
		await process_frame
		var settled = Domain.new(Registry.new(), Session.new(path, "slot_2"), "slot_2")
		settled._ripple_flow.roll_override = 0.999
		settled._hint_flow.roll_override = 0.0
		settled._market_flow.roll_override = 0.0
		if story.active_battle != null or not settled.restore() \
				or settled.get_current_card().get("id") != "combat_fled_q_sword_3" \
				or settled.submit_battle_result(result):
			return _fail("natural sword trial did not cold settle retreat once: " + direction)
		story.queue_free()
		await process_frame
	print("NONCOMBAT_FOUNDATION_SWORD_TRIAL_LIVE_BATTLE_PASS directions=2 desktop=true retreat=true replay=true")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
