extends SceneTree

const Registry = preload("res://scripts/runtime_data_registry.gd")
const Domain = preload("res://scripts/noncombat_domain.gd")
const RunSession = preload("res://scripts/noncombat_run_session.gd")

class MissingSharedKarmaArt extends "res://scripts/noncombat_content_repository.gd":
	func card_scene_image_status(card_id: String) -> Dictionary:
		var result: Dictionary = super.card_scene_image_status(card_id)
		if card_id == "kx_ch_shared_opportunity":
			result["shaVerified"] = false
			result["textureLoadable"] = false
		return result

class DriftSharedKarmaSource extends "res://scripts/noncombat_content_repository.gd":
	func source_sha256(module_id: String) -> String:
		return "f".repeat(64) if module_id == "cards:karma_expansion" else super.source_sha256(module_id)


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	for direction in ["left", "right"]:
		var path := "user://tests/shared_karma_%s_%d.json" % [direction, Time.get_ticks_usec()]
		var store = RunSession.new(path, "slot_3")
		var game = Domain.new(Registry.new(), store, "slot_3")
		game._destiny_wheel_flow.roll_override = 0.0
		if not _reach_after_sword_echo(game):
			return _fail("source route to shared opportunity karma unreachable")
		var before: Dictionary = game.state.duplicate(true)
		var before_bytes := FileAccess.get_file_as_string(store.v2_path)
		game._karma_flow._content = DriftSharedKarmaSource.new()
		if game.resume_flow() or not _same(game.state, before) \
				or FileAccess.get_file_as_string(store.v2_path) != before_bytes:
			return _fail("shared karma replaced the earlier source fingerprint")
		game._karma_flow._content = game._content
		var broken = Domain.new(Registry.new(), RunSession.new(path, "slot_3"),
			"slot_3", MissingSharedKarmaArt.new())
		broken._destiny_wheel_flow.roll_override = 0.0
		if not broken.restore() or broken.resume_flow() \
				or not _same(broken.state, before) \
				or FileAccess.get_file_as_string(store.v2_path) != before_bytes:
			return _fail("missing shared karma art scheduled or changed save")
		if not game.resume_flow():
			return _fail("shared opportunity karma not scheduled")
		var card: Dictionary = game.get_current_card()
		if game.state.get("phase") != "KARMA_PENDING" \
				or card.get("id") != "kx_ch_shared_opportunity" \
				or card.get("title") != "同行人的回帖" \
				or card.get("sceneImage") != "assets/cards/events/scene_ch_qi_40.png" \
				or Registry.new().texture_for(String(card.get("sceneImage", ""))) == null \
				or not game.can_choose_direction("left") or not game.can_choose_direction("right"):
			return _fail("shared opportunity source card or admission differs")
		var pending: Dictionary = game.state.duplicate(true)
		var bytes := FileAccess.get_file_as_string(store.v2_path)
		var loaded = Domain.new(Registry.new(), RunSession.new(path, "slot_3"), "slot_3")
		loaded._destiny_wheel_flow.roll_override = 0.0
		if not loaded.restore() or not _same(loaded.state, pending) \
				or FileAccess.get_file_as_string(store.v2_path) != bytes:
			return _fail("pending shared karma not strictly replayed")
		var token: int = loaded.issue_choice_token()
		loaded._store.fail_promotion_once = true
		if loaded.choose(direction, token) or not _same(loaded.state, pending) \
				or FileAccess.get_file_as_string(store.v2_path) != bytes:
			return _fail("failed shared karma write changed save")
		if not loaded.choose(direction, token) or loaded.choose(direction, token):
			return _fail("shared karma did not settle once")
		var result: Dictionary = loaded.state
		var attrs: Dictionary = result.get("attributes", {})
		var resources: Dictionary = result.get("resources", {})
		var expected_flag := "karma_result_shared_ally" if direction == "left" else "karma_result_shared_advice"
		if int(result.get("runClock", {}).get("decisionIndex", -1)) != 19 \
				or result.get("choiceHistory", []).back().get("cardId") != "kx_ch_shared_opportunity" \
				or int(attrs.get("karmaGood", -1)) != (36 if direction == "left" else 37) \
				or int(attrs.get("fortune", -1)) != (90 if direction == "left" else 87) \
				or int(attrs.get("daoHeart", -1)) != 4 \
				or int(resources.get("spiritStone", -1)) != (14 if direction == "left" else 10) \
				or not result.get("flags", {}).get(expected_flag, false) \
				or result.get("karmaSeeds", []).any(func(seed: Variant) -> bool:
					return seed is Dictionary and seed.get("id") == "causal:shared_opportunity") \
				or not result.get("karmaSeeds", []).any(func(seed: Variant) -> bool:
					return seed is Dictionary and seed.get("id") == "causal:sword_sect_path"):
			return _fail("shared opportunity choice differs from browser: " + direction)
		var committed_bytes := FileAccess.get_file_as_string(store.v2_path)
		var replay = Domain.new(Registry.new(), RunSession.new(path, "slot_3"), "slot_3")
		replay._destiny_wheel_flow.roll_override = 0.0
		if not replay.restore() or not _same(replay.state, result) \
				or FileAccess.get_file_as_string(store.v2_path) != committed_bytes:
			return _fail("settled shared karma not strictly replayed")
	print("NONCOMBAT_SHARED_KARMA_PASS branches=2 source_art=true rollback=true replay=true")
	quit(0)


func _reach_after_sword_echo(game: RefCounted) -> bool:
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
		and int(game.state["runClock"]["decisionIndex"]) == 18


func _same(left: Dictionary, right: Dictionary) -> bool:
	return JSON.parse_string(JSON.stringify(left)) == JSON.parse_string(JSON.stringify(right))


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
