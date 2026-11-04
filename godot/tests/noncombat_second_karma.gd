extends SceneTree

const Registry = preload("res://scripts/runtime_data_registry.gd")
const Domain = preload("res://scripts/noncombat_domain.gd")
const RunSession = preload("res://scripts/noncombat_run_session.gd")


class MissingSecondKarmaArt extends "res://scripts/noncombat_content_repository.gd":
	func card_scene_image_status(card_id: String) -> Dictionary:
		var result: Dictionary = super.card_scene_image_status(card_id)
		if card_id == "k_chapter_sword_left":
			result["shaVerified"] = false
			result["textureLoadable"] = false
		return result

class DriftSecondKarmaSource extends "res://scripts/noncombat_content_repository.gd":
	func source_sha256(module_id: String) -> String:
		return "f".repeat(64) if module_id == "cards:karma" else super.source_sha256(module_id)

class MissingSecondKarmaSource extends "res://scripts/noncombat_content_repository.gd":
	func module_path(module_id: String) -> String:
		return "" if module_id == "cards:karma" else super.module_path(module_id)


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	for direction in ["left", "right"]:
		var path := "user://tests/second_karma_%s_%d.json" % [direction, Time.get_ticks_usec()]
		var store = RunSession.new(path, "slot_3")
		var game = Domain.new(Registry.new(), store, "slot_3")
		game._destiny_wheel_flow.roll_override = 0.0
		if not _reach_after_trial(game, direction):
			return _fail("source route to second karma unreachable")
		var before: Dictionary = game.state.duplicate(true)
		var before_bytes := FileAccess.get_file_as_string(store.v2_path)
		var broken = Domain.new(Registry.new(), RunSession.new(path, "slot_3"),
			"slot_3", MissingSecondKarmaArt.new())
		broken._destiny_wheel_flow.roll_override = 0.0
		if not broken.restore() or broken.resume_flow() \
				or not _same(broken.state, before) \
				or FileAccess.get_file_as_string(store.v2_path) != before_bytes:
			return _fail("missing second karma art scheduled or changed save")
		if not game.resume_flow():
			return _fail("second karma not scheduled")
		var card: Dictionary = game.get_current_card()
		if game.state.get("phase") != "KARMA_PENDING" \
				or card.get("id") != "k_chapter_sword_left" \
				or card.get("title") != "剑脉初鸣·剑痕回响" \
				or not String(card.get("description", "")).contains("【循锋入定】") \
				or card.get("sceneImage") != "assets/cards/events/scene_karma_k_sword_honor.png" \
				or Registry.new().texture_for(String(card.get("sceneImage", ""))) == null:
			return _fail("second karma materialized card differs from browser")
		var pending: Dictionary = game.state.duplicate(true)
		var pending_bytes := FileAccess.get_file_as_string(store.v2_path)
		if game.can_choose_direction("left") or not game.can_choose_direction("right") \
				or game.choose("left", game.issue_choice_token()) \
				or not _same(game.state, pending) \
				or FileAccess.get_file_as_string(store.v2_path) != pending_bytes:
			return _fail("capped karma choice was not safely disabled")
		var view: Control = load("res://scenes/noncombat_opening.tscn").instantiate()
		view.save_path = ""
		root.add_child(view)
		await process_frame
		view.opening = game
		view._render()
		var left_button: Button = view.choice_row.get_node_or_null("Choice_left")
		var right_button: Button = view.choice_row.get_node_or_null("Choice_right")
		if left_button == null or right_button == null or not left_button.disabled \
				or right_button.disabled or view.art_rect.texture == null:
			return _fail("second karma desktop admission or art differs")
		root.remove_child(view)
		view.queue_free()
		if direction == "left":
			var drift_store = RunSession.new(path, "slot_3")
			var drift = Domain.new(Registry.new(), drift_store, "slot_3", DriftSecondKarmaSource.new())
			if drift.restore() or drift_store.last_error != "SOURCE_MISMATCH" \
					or FileAccess.get_file_as_string(store.v2_path) != pending_bytes:
				return _fail("second karma source drift accepted or changed save")
			var missing_store = RunSession.new(path, "slot_3")
			var missing = Domain.new(Registry.new(), missing_store, "slot_3", MissingSecondKarmaSource.new())
			if missing.restore() or missing_store.last_error != "SOURCE_UNAVAILABLE" \
					or FileAccess.get_file_as_string(store.v2_path) != pending_bytes:
				return _fail("second karma missing source accepted or misclassified")
		var loaded = Domain.new(Registry.new(), RunSession.new(path, "slot_3"), "slot_3")
		loaded._destiny_wheel_flow.roll_override = 0.0
		if not loaded.restore() or not _same(loaded.state, pending) \
				or FileAccess.get_file_as_string(store.v2_path) != pending_bytes:
			return _fail("pending second karma not strictly replayed")
		var token: int = loaded.issue_choice_token()
		loaded._store.fail_promotion_once = true
		if loaded.choose("right", token) or not _same(loaded.state, pending) \
				or FileAccess.get_file_as_string(store.v2_path) != pending_bytes:
			return _fail("failed second karma write changed save")
		if not loaded.choose("right", token) or loaded.choose("right", token):
			return _fail("second karma did not settle exactly once")
		var result: Dictionary = loaded.state
		var attrs: Dictionary = result.get("attributes", {})
		if int(result.get("runClock", {}).get("decisionIndex", -1)) != 18 \
				or result.get("choiceHistory", []).back().get("cardId") != "k_chapter_sword_left" \
				or int(attrs.get("cultivation", -1)) != 100 \
				or int(attrs.get("daoHeart", -1)) != 4 \
				or int(attrs.get("health", -1)) != (1 if direction == "left" else 2) \
				or int(attrs.get("fortune", -1)) != (87 if direction == "left" else 88) \
				or result.get("karmaSeeds", []).any(func(seed: Variant) -> bool:
					return seed is Dictionary and seed.get("id") == "causal:qi_sword_attune") \
				or not result.get("karmaSeeds", []).any(func(seed: Variant) -> bool:
					return seed is Dictionary and seed.get("id") == "causal:shared_opportunity"):
			return _fail("second karma effect or seed removal differs: " + direction + " " +
				JSON.stringify({"attrs": attrs, "seeds": result.get("karmaSeeds", []),
					"decisionIndex": result.get("runClock", {}).get("decisionIndex")}))
		var bytes := FileAccess.get_file_as_string(store.v2_path)
		var settled = Domain.new(Registry.new(), RunSession.new(path, "slot_3"), "slot_3")
		settled._destiny_wheel_flow.roll_override = 0.0
		if not settled.restore() or not _same(settled.state, result) \
				or FileAccess.get_file_as_string(store.v2_path) != bytes:
			return _fail("settled second karma not strictly replayed")
	print("NONCOMBAT_SECOND_KARMA_PASS branches=2 dynamic=true source_art=true rollback=true replay=true")
	quit(0)


func _reach_after_trial(game: RefCounted, trial_direction: String) -> bool:
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
		and game.resume_flow() and game.choose(trial_direction, game.issue_choice_token()) \
		and int(game.state["runClock"]["decisionIndex"]) == 17


func _same(left: Dictionary, right: Dictionary) -> bool:
	return JSON.parse_string(JSON.stringify(left)) == JSON.parse_string(JSON.stringify(right))


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
