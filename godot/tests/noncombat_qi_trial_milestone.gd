extends SceneTree

const Registry = preload("res://scripts/runtime_data_registry.gd")
const Domain = preload("res://scripts/noncombat_domain.gd")
const RunSession = preload("res://scripts/noncombat_run_session.gd")

class MissingTrialArtContent extends "res://scripts/noncombat_content_repository.gd":
	func card_scene_image_status(card_id: String) -> Dictionary:
		var result: Dictionary = super.card_scene_image_status(card_id)
		if card_id == "ch_qi_80":
			result["shaVerified"] = false
			result["textureLoadable"] = false
		return result

class MissingChapterContent extends "res://scripts/noncombat_content_repository.gd":
	func module_path(module_id: String) -> String:
		return "" if module_id == "cards:chapter_milestones" else super.module_path(module_id)


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	for direction in ["left", "right"]:
		var path := "user://tests/qi_trial_%s_%d.json" % [direction, Time.get_ticks_usec()]
		var store = RunSession.new(path, "slot_3")
		var game = Domain.new(Registry.new(), store, "slot_3")
		game._destiny_wheel_flow.roll_override = 0.0
		if not _reach_mentor_result_ack(game):
			return _fail("browser post-wheel mentor route unreachable")
		var before_schedule: Dictionary = game.state.duplicate(true)
		var before_bytes := FileAccess.get_file_as_string(store.v2_path)
		var missing_source = MissingChapterContent.new()
		game._content = missing_source
		game._milestone_flow._content = missing_source
		if game.resume_flow() or store.last_error != "SOURCE_UNAVAILABLE" \
				or not _same(game.state, before_schedule) \
				or FileAccess.get_file_as_string(store.v2_path) != before_bytes:
			return _fail("missing hot chapter source did not preserve save or error class")
		game._content = game._quest_flow._content
		game._milestone_flow._content = game._content
		var broken = Domain.new(Registry.new(), RunSession.new(path, "slot_3"),
			"slot_3", MissingTrialArtContent.new())
		broken._destiny_wheel_flow.roll_override = 0.0
		if not broken.restore() or broken.resume_flow() \
				or not _same(broken.state, before_schedule) \
				or FileAccess.get_file_as_string(store.v2_path) != before_bytes:
			return _fail("missing trial art scheduled or changed the save")
		if not game.resume_flow():
			return _fail("threshold-70 milestone not scheduled")
		var card: Dictionary = game.get_current_card()
		if game.state.get("phase") != "MILESTONE_PENDING" \
				or card.get("id") != "ch_qi_80" or int(card.get("threshold", -1)) != 70 \
				or card.get("sceneImage") != "assets/cards/events/scene_ch_qi_80.png" \
				or card.get("bossJourneyStage", {}).get("canonicalThreshold") != 80 \
				or not String(card.get("description", "")).contains("【整备】") \
				or Registry.new().texture_for(String(card.get("sceneImage", ""))) == null:
			return _fail("fourth authored chapter projection differs")
		var pending: Dictionary = game.state.duplicate(true)
		var pending_bytes := FileAccess.get_file_as_string(store.v2_path)
		var reloaded = Domain.new(Registry.new(), RunSession.new(path, "slot_3"), "slot_3")
		reloaded._destiny_wheel_flow.roll_override = 0.0
		if not reloaded.restore() or not _same(reloaded.state, pending) \
				or FileAccess.get_file_as_string(store.v2_path) != pending_bytes:
			return _fail("pending fourth milestone not strictly replayed")
		var token: int = reloaded.issue_choice_token()
		reloaded._store.fail_promotion_once = true
		if reloaded.choose(direction, token) or not _same(reloaded.state, pending) \
				or FileAccess.get_file_as_string(store.v2_path) != pending_bytes:
			return _fail("failed fourth milestone commit changed save")
		if not reloaded.choose(direction, token) or reloaded.choose(direction, token):
			return _fail("fourth milestone did not settle once")
		var result: Dictionary = reloaded.state
		var facts: Dictionary = result.get("noncombatFlow", {}).get("spineFacts", {})
		var milestones: Array = result.get("chapterProgress", {}).get(
			"triggeredMilestones", {}).get("qi", [])
		if int(result.get("runClock", {}).get("decisionIndex", -1)) != 17 \
				or milestones.size() != 4 or int(milestones[3]) != 70 \
				or facts.get("fact:0:qi_main_commitment", {}).get("status") != "consumed" \
				or facts.get("fact:0:qi_main_trial", {}).get("status") != "active" \
				or result.get("choiceHistory", []).back().get("cardId") != "ch_qi_80":
			return _fail("fourth milestone fact or decision settlement differs")
		var attrs: Dictionary = result["attributes"]
		if int(attrs.get("cultivation", -1)) != 100 \
				or int(attrs.get("health", -1)) != (1 if direction == "left" else 2) \
				or int(attrs.get("fortune", -1)) != (85 if direction == "left" else 86) \
				or int(result["resources"]["lifespan"]) != (76 if direction == "left" else 77):
			return _fail("fourth milestone source effects differ: " + direction)
		var bytes := FileAccess.get_file_as_string(store.v2_path)
		var final_reload = Domain.new(Registry.new(), RunSession.new(path, "slot_3"), "slot_3")
		final_reload._destiny_wheel_flow.roll_override = 0.0
		if not final_reload.restore() or not _same(final_reload.state, result) \
				or FileAccess.get_file_as_string(store.v2_path) != bytes:
			return _fail("settled fourth milestone did not strictly replay")
	print("NONCOMBAT_QI_TRIAL_MILESTONE_PASS branches=2 fact=true art=true rollback=true replay=true")
	quit(0)


func _reach_mentor_result_ack(game: RefCounted) -> bool:
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
		and game.get_current_card().get("type") == "NARRATIVE_RESULT" \
		and game.choose("left", game.issue_choice_token()) \
		and int(game.state["runClock"]["decisionIndex"]) == 16


func _same(left: Dictionary, right: Dictionary) -> bool:
	return JSON.parse_string(JSON.stringify(left)) == JSON.parse_string(JSON.stringify(right))


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
