extends SceneTree

const Registry = preload("res://scripts/runtime_data_registry.gd")
const Domain = preload("res://scripts/noncombat_domain.gd")
const RunSession = preload("res://scripts/noncombat_run_session.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	for direction in ["left", "right"]:
		var path := "user://tests/heaven_gaze_%s_%d.json" % [direction, Time.get_ticks_usec()]
		var store = RunSession.new(path, "slot_3")
		var game = Domain.new(Registry.new(), store, "slot_3")
		game._destiny_wheel_flow.roll_override = 0.0
		if not _reach_after_shared_karma(game):
			return _fail("browser route to heaven gaze unreachable")
		var before: Dictionary = game.state.duplicate(true)
		var before_bytes := FileAccess.get_file_as_string(store.v2_path)
		var tampered_path := "user://tests/heaven_gaze_tampered_%d.json" % Time.get_ticks_usec()
		var tampered_doc: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(
			"res://content/derived/story_emergent_cards.json"))
		tampered_doc["cards"]["em_heaven_gaze"]["choices"]["left"]["effects"]["cultivation"] = -50
		var tampered_file := FileAccess.open(tampered_path, FileAccess.WRITE)
		if tampered_file == null:
			return _fail("cannot create isolated derived source tamper fixture")
		tampered_file.store_string(JSON.stringify(tampered_doc))
		tampered_file.close()
		game._emergent_flow.derived_path = tampered_path
		var accepted_tamper: Dictionary = game._emergent_flow.resume(before)
		game._emergent_flow.derived_path = "res://content/derived/story_emergent_cards.json"
		DirAccess.remove_absolute(ProjectSettings.globalize_path(tampered_path))
		if not accepted_tamper.is_empty() or game._emergent_flow.last_error.is_empty() \
				or not _same(game.state, before) \
				or FileAccess.get_file_as_string(store.v2_path) != before_bytes:
			return _fail("modified derived emergent effects accepted before first scheduling")
		var below_threshold: Dictionary = before.duplicate(true)
		below_threshold["attributes"]["fortune"] = 80
		if not game._emergent_flow.resume(below_threshold).is_empty():
			return _fail("heaven gaze ignored fortune threshold")
		var higher_priority: Dictionary = before.duplicate(true)
		higher_priority["attributes"]["karmaGood"] = 41
		higher_priority["attributes"]["karmaBad"] = 41
		if not game._emergent_flow.resume(higher_priority).is_empty():
			return _fail("heaven gaze replaced an earlier emergent category")
		if not _same(game.state, before) or FileAccess.get_file_as_string(store.v2_path) != before_bytes:
			return _fail("read-only threshold checks changed save")
		if not game.resume_flow():
			return _fail("heaven gaze threshold not scheduled")
		var card: Dictionary = game.get_current_card()
		if game.state.get("phase") != "EMERGENT_PENDING" \
				or card.get("id") != "em_heaven_gaze" \
				or card.get("type") != "EMERGENT" \
				or card.has("sceneImage") \
				or not String(card.get("description", "")).contains("天道算法"):
			return _fail("heaven gaze browser projection differs")
		var view: Control = load("res://scenes/noncombat_opening.tscn").instantiate()
		view.save_path = ""
		root.add_child(view)
		await process_frame
		view.opening = game
		view._render()
		if view.art_rect.texture != null \
				or view.choice_row.get_node_or_null("Choice_left") == null \
				or view.choice_row.get_node_or_null("Choice_right") == null:
			return _fail("heaven gaze text-only desktop view unavailable")
		root.remove_child(view)
		view.queue_free()
		var pending: Dictionary = game.state.duplicate(true)
		var bytes := FileAccess.get_file_as_string(store.v2_path)
		var loaded = Domain.new(Registry.new(), RunSession.new(path, "slot_3"), "slot_3")
		loaded._destiny_wheel_flow.roll_override = 0.0
		if not loaded.restore() or not _same(loaded.state, pending) \
				or FileAccess.get_file_as_string(store.v2_path) != bytes:
			return _fail("pending heaven gaze not strictly replayed")
		var token: int = loaded.issue_choice_token()
		loaded._store.fail_promotion_once = true
		if loaded.choose(direction, token) or not _same(loaded.state, pending) \
				or FileAccess.get_file_as_string(store.v2_path) != bytes:
			return _fail("failed heaven gaze write changed save")
		if not loaded.choose(direction, token) or loaded.choose(direction, token):
			return _fail("heaven gaze did not settle once")
		var result: Dictionary = loaded.state
		var attrs: Dictionary = result.get("attributes", {})
		if int(result.get("runClock", {}).get("decisionIndex", -1)) != 20 \
				or result.get("choiceHistory", []).back().get("cardId") != "em_heaven_gaze" \
				or int(attrs.get("cultivation", -1)) != (95 if direction == "left" else 100) \
				or int(attrs.get("fortune", -1)) != (100 if direction == "left" else 70) \
				or int(attrs.get("karmaBad", -1)) != (6 if direction == "left" else 16) \
				or int(attrs.get("daoHeart", -1)) != 4:
			return _fail("heaven gaze source effects differ: " + direction)
		if not loaded._emergent_flow.resume(result).is_empty():
			return _fail("heaven gaze repeated immediately despite narrative cooldown")
		var after_cooldown: Dictionary = result.duplicate(true)
		after_cooldown["runClock"]["decisionIndex"] = 32
		after_cooldown["turn"] = 32
		after_cooldown["resources"]["companions"] = ["cooldown_fixture"]
		after_cooldown["attributes"]["fortune"] = 90
		after_cooldown["attributes"]["cultivation"] = 95
		if loaded._emergent_flow.resume(after_cooldown).is_empty():
			return _fail("heaven gaze cooldown never expires after 12 decisions")
		var committed_bytes := FileAccess.get_file_as_string(store.v2_path)
		var replay = Domain.new(Registry.new(), RunSession.new(path, "slot_3"), "slot_3")
		replay._destiny_wheel_flow.roll_override = 0.0
		if not replay.restore() or not _same(replay.state, result) \
				or FileAccess.get_file_as_string(store.v2_path) != committed_bytes:
			return _fail("settled heaven gaze not strictly replayed")
	print("NONCOMBAT_HEAVEN_GAZE_PASS branches=2 text_only=true rollback=true replay=true")
	quit(0)


func _reach_after_shared_karma(game: RefCounted) -> bool:
	if not game.start("sword"):
		return false
	for i in 5:
		if not game.choose("left", game.issue_choice_token()):
			return false
	return game.choose("right", game.issue_choice_token()) \
		and game.choose("left", game.issue_choice_token()) \
		and game.resume_flow() and game.choose("left", game.issue_choice_token()) \
		and game.choose("right", game.issue_choice_token()) \
		and game.resume_flow() and game.choose("right", game.issue_choice_token()) \
		and game.choose("left", game.issue_choice_token()) \
		and game.choose("down", game.issue_choice_token()) \
		and game.resume_flow() and game.choose("left", game.issue_choice_token()) \
		and game.resume_flow() and game.choose("left", game.issue_choice_token()) \
		and game.resume_flow() and game.choose("left", game.issue_choice_token()) \
		and game.get_current_card().get("type") == "DESTINY_WHEEL" \
		and game.choose("left", game.issue_choice_token()) \
		and game.choose("left", game.issue_choice_token()) \
		and game.resume_flow() and game.choose("left", game.issue_choice_token()) \
		and game.resume_flow() and game.choose("right", game.issue_choice_token()) \
		and game.resume_flow() and game.choose("left", game.issue_choice_token()) \
		and int(game.state["runClock"]["decisionIndex"]) == 19


func _same(left: Dictionary, right: Dictionary) -> bool:
	return JSON.parse_string(JSON.stringify(left)) == JSON.parse_string(JSON.stringify(right))


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
