extends SceneTree

const Registry = preload("res://scripts/runtime_data_registry.gd")
const Domain = preload("res://scripts/noncombat_domain.gd")
const RunSession = preload("res://scripts/noncombat_run_session.gd")

class MissingSectArt extends "res://scripts/noncombat_content_repository.gd":
	func card_scene_image_status(card_id: String) -> Dictionary:
		var result: Dictionary = super.card_scene_image_status(card_id)
		if card_id == "kx_ch_sword_sect_path":
			result["shaVerified"] = false
			result["textureLoadable"] = false
		return result


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	for direction in ["left", "right"]:
		var path := "user://tests/sword_sect_karma_%s_%d.json" % [direction, Time.get_ticks_usec()]
		var store = RunSession.new(path, "slot_3")
		var game = Domain.new(Registry.new(), store, "slot_3")
		game._destiny_wheel_flow.roll_override = 0.0
		if not _reach_after_heaven_gaze(game):
			return _fail("browser route to sword sect karma unreachable")
		var before: Dictionary = game.state.duplicate(true)
		var before_bytes := FileAccess.get_file_as_string(store.v2_path)
		var broken = Domain.new(Registry.new(), RunSession.new(path, "slot_3"),
			"slot_3", MissingSectArt.new())
		broken._destiny_wheel_flow.roll_override = 0.0
		if not broken.restore() or broken.resume_flow() \
				or not _same(broken.state, before) \
				or FileAccess.get_file_as_string(store.v2_path) != before_bytes:
			return _fail("invalid sword sect art scheduled or changed save")
		if not game.resume_flow():
			return _fail("sword sect karma not scheduled")
		var card: Dictionary = game.get_current_card()
		if game.state.get("phase") != "KARMA_PENDING" \
				or card.get("id") != "kx_ch_sword_sect_path" \
				or card.get("title") != "剑宗誓册" \
				or card.get("sceneImage") != "assets/cards/events/scene_ch_qi_60.png" \
				or Registry.new().texture_for(String(card.get("sceneImage", ""))) == null \
				or not game.can_choose_direction("left") \
				or not game.can_choose_direction("right"):
			return _fail("sword sect source card or admission differs: %s / %s" % [
				game.state.get("phase"), card.get("id")])
		var pending: Dictionary = game.state.duplicate(true)
		var bytes := FileAccess.get_file_as_string(store.v2_path)
		var loaded = Domain.new(Registry.new(), RunSession.new(path, "slot_3"), "slot_3")
		loaded._destiny_wheel_flow.roll_override = 0.0
		if not loaded.restore() or not _same(loaded.state, pending) \
				or FileAccess.get_file_as_string(store.v2_path) != bytes:
			return _fail("pending sword sect karma not strictly replayed")
		var token: int = loaded.issue_choice_token()
		loaded._store.fail_promotion_once = true
		if loaded.choose(direction, token) or not _same(loaded.state, pending) \
				or FileAccess.get_file_as_string(store.v2_path) != bytes:
			return _fail("failed sword sect write changed save")
		if not loaded.choose(direction, token) or loaded.choose(direction, token):
			return _fail("sword sect karma did not settle once")
		var result: Dictionary = loaded.state
		var attrs: Dictionary = result.get("attributes", {})
		var deck: Array = result.get("deck", [])
		var acquisition: Dictionary = result.get("skillAcquisitions", {})
		var expected_flag := "karma_result_sword_oath_signed" if direction == "left" \
			else "karma_result_sword_oath_revised"
		if int(result.get("runClock", {}).get("decisionIndex", -1)) != 21 \
				or result.get("choiceHistory", []).back().get("cardId") != "kx_ch_sword_sect_path" \
				or int(attrs.get("cultivation", -1)) != (99 if direction == "left" else 95) \
				or int(attrs.get("karmaGood", -1)) != (36 if direction == "left" else 38) \
				or int(attrs.get("fortune", -1)) != 100 \
				or int(attrs.get("daoHeart", -1)) != 4 \
				or not result.get("flags", {}).get(expected_flag, false) \
				or result.get("karmaSeeds", []).any(func(seed: Variant) -> bool:
					return seed is Dictionary and seed.get("id") == "causal:sword_sect_path") \
				or deck.count("draw_sword") != (1 if direction == "left" else 0) \
				or acquisition.has("draw_sword") != (direction == "left"):
			return _fail("sword sect choice differs from browser: " + direction)
		if direction == "left" and (acquisition["draw_sword"].get("sourceId") !=
				"kx_ch_sword_sect_path" or acquisition["draw_sword"].get("turn") != 20):
			return _fail("sword sect deck reward provenance differs")
		var committed_bytes := FileAccess.get_file_as_string(store.v2_path)
		var replay = Domain.new(Registry.new(), RunSession.new(path, "slot_3"), "slot_3")
		replay._destiny_wheel_flow.roll_override = 0.0
		if not replay.restore() or not _same(replay.state, result) \
				or FileAccess.get_file_as_string(store.v2_path) != committed_bytes:
			return _fail("settled sword sect karma not strictly replayed")
	print("NONCOMBAT_SWORD_SECT_KARMA_PASS branches=2 deck_reward=true rollback=true replay=true")
	quit(0)


func _reach_after_heaven_gaze(game: RefCounted) -> bool:
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
		and game.resume_flow() and game.choose("left", game.issue_choice_token()) \
		and int(game.state["runClock"]["decisionIndex"]) == 20


func _same(left: Dictionary, right: Dictionary) -> bool:
	return JSON.parse_string(JSON.stringify(left)) == JSON.parse_string(JSON.stringify(right))


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
