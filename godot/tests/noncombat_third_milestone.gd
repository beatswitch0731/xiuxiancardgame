extends SceneTree

const Registry = preload("res://scripts/runtime_data_registry.gd")
const Domain = preload("res://scripts/noncombat_domain.gd")
const RunSession = preload("res://scripts/noncombat_run_session.gd")

class MissingThirdArtContent extends "res://scripts/noncombat_content_repository.gd":
	func card_scene_image_status(card_id: String) -> Dictionary:
		var result: Dictionary = super.card_scene_image_status(card_id)
		if card_id == "ch_qi_60":
			result["shaVerified"] = false
			result["textureLoadable"] = false
		return result


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	for direction in ["left", "right"]:
		var save_path := "user://tests/third_milestone_%s_%d.json" % [
			direction, Time.get_ticks_usec()]
		var game = Domain.new(Registry.new(), RunSession.new(save_path, "slot_3"), "slot_3")
		if not _reach_failed_fox(game):
			_fail("source white fox failure route is unreachable")
			return
		var before_schedule: Dictionary = game.state.duplicate(true)
		var before_bytes := FileAccess.get_file_as_string(game._store.v2_path)
		var broken = Domain.new(Registry.new(), RunSession.new(save_path, "slot_3"),
			"slot_3", MissingThirdArtContent.new())
		if not broken.restore() or broken.resume_flow() \
				or not _same(broken.state, before_schedule) \
				or FileAccess.get_file_as_string(game._store.v2_path) != before_bytes:
			_fail("bad third-card image scheduled or rewrote a valid save")
			return
		if not game.resume_flow():
			_fail("third authored qi milestone was not scheduled after fox failure")
			return
		var card: Dictionary = game.get_current_card()
		if game.state.get("phase") != "MILESTONE_PENDING" \
				or card.get("id") != "ch_qi_60" or card.get("threshold") != 50 \
				or card.get("title") != "师承抉择" \
				or card.get("sceneImage") != "assets/cards/events/scene_ch_qi_60.png" \
				or not String(card.get("description", "")).contains("【对策】") \
				or not String(card.get("description", "")).contains("【来历回声】") \
				or card.get("bossJourneyStage", {}).get("canonicalThreshold") != 60 \
				or Registry.new().texture_for(String(card.get("sceneImage", ""))) == null \
				or game.state.get("chapterProgress", {}).get("triggeredMilestones", {}).get("qi") != [15, 30, 50] \
				or int(game.state["runClock"]["decisionIndex"]) != 10:
			_fail("third milestone source card, art or threshold differs")
			return
		var pending: Dictionary = game.state.duplicate(true)
		var pending_bytes := FileAccess.get_file_as_string(game._store.v2_path)
		var bad_pending_store = RunSession.new(save_path, "slot_3")
		var bad_pending = Domain.new(Registry.new(), bad_pending_store, "slot_3",
			MissingThirdArtContent.new())
		if bad_pending.restore() or bad_pending_store.last_error != "SOURCE_MISMATCH" \
				or FileAccess.get_file_as_string(game._store.v2_path) != pending_bytes:
			_fail("bad third-card image did not protect a pending save")
			return
		var reloaded = Domain.new(Registry.new(), RunSession.new(save_path, "slot_3"), "slot_3")
		if not reloaded.restore() or not _same(reloaded.state, pending):
			_fail("third milestone pending state did not strictly replay: store=%s hint=%s" % [
				reloaded._store.last_error, pending.get("heavensHintState", {})])
			return
		var token := reloaded.issue_choice_token()
		reloaded._store.fail_promotion_once = true
		if reloaded.choose(direction, token) or not _same(reloaded.state, pending) \
				or FileAccess.get_file_as_string(reloaded._store.v2_path) != pending_bytes:
			_fail("failed third milestone write leaked a decision")
			return
		if not reloaded.choose(direction, token) or reloaded.choose(direction, token):
			_fail("third milestone did not settle exactly once")
			return
		var final_state: Dictionary = reloaded.state
		var settled_bytes := FileAccess.get_file_as_string(reloaded._store.v2_path)
		var bad_settled_store = RunSession.new(save_path, "slot_3")
		var bad_settled = Domain.new(Registry.new(), bad_settled_store, "slot_3",
			MissingThirdArtContent.new())
		if bad_settled.restore() or bad_settled_store.last_error != "SOURCE_MISMATCH" \
				or FileAccess.get_file_as_string(reloaded._store.v2_path) != settled_bytes:
			_fail("bad third-card image archived a valid settled save")
			return
		var before_attributes: Dictionary = pending["attributes"]
		var after_attributes: Dictionary = final_state["attributes"]
		var expected_seed := "causal:sword_sect_path" if direction == "left" else "causal:alchemy_path"
		var expected_commitment := "sword_sect" if direction == "left" else "danxia"
		var facts: Dictionary = final_state.get("noncombatFlow", {}).get("spineFacts", {})
		var commitment: Dictionary = facts.get("fact:0:qi_main_commitment", {})
		if final_state.get("phase") != "FLOW_PENDING" \
				or int(final_state["runClock"]["decisionIndex"]) != 11 \
				or int(after_attributes["cultivation"]) != int(before_attributes["cultivation"]) + (6 if direction == "left" else 4) \
				or int(after_attributes["daoHeart"]) != mini(int(final_state["maxDaoHeart"]), int(before_attributes["daoHeart"]) + 1) \
				or int(after_attributes["karmaBad" if direction == "left" else "karmaGood"]) != int(before_attributes["karmaBad" if direction == "left" else "karmaGood"]) + 1 \
				or facts.get("fact:0:qi_main_pressure", {}).get("status") != "consumed" \
				or commitment.get("status") != "active" \
				or commitment.get("payload", {}).get("commitment") != expected_commitment \
				or facts.get("fact:0:qi_sword_master_stance", {}).get("status") != "active" \
				or not final_state.get("noncombatFlow", {}).get("spineConsumptions", {}).has(
					"fact:0:qi_main_pressure:qi_main_pressure_to_commitment") \
				or not final_state.get("karmaSeeds", []).any(func(seed: Variant) -> bool:
					return seed.get("id") == expected_seed and int(seed.get("originTurn", -1)) == 11) \
				or final_state.get("choiceHistory", []).back().get("cardId") != "ch_qi_60":
			_fail("third milestone effects, facts, seed or decision differ: " + direction)
			return
		var pills: Dictionary = final_state["resources"].get("pills", {})
		if int(pills.get("1", 0)) != (0 if direction == "left" else 1):
			_fail("source numeric pill effect did not use the browser resource key")
			return
		var final_reload = Domain.new(Registry.new(), RunSession.new(save_path, "slot_3"), "slot_3")
		if not final_reload.restore() or not _same(final_reload.state, final_state):
			_fail("third milestone settled state did not strictly replay")
			return
	print("NONCOMBAT_THIRD_MILESTONE_PASS branches=2 source_art=true rollback=true replay=true")
	quit(0)


func _reach_failed_fox(game: RefCounted) -> bool:
	if not game.start("sword"):
		return false
	for step in 5:
		if not game.choose("left", game.issue_choice_token()):
			return false
	return game.choose("right", game.issue_choice_token()) \
		and game.choose("left", game.issue_choice_token()) \
		and game.resume_flow() \
		and game.choose("left", game.issue_choice_token()) \
		and game.choose("right", game.issue_choice_token()) \
		and game.resume_flow() \
		and game.get_current_card().get("id") == "q_whiteFox_quest" \
		and game.choose("left", game.issue_choice_token()) \
		and game.state.get("phase") == "FLOW_PENDING"


func _same(left: Dictionary, right: Dictionary) -> bool:
	return JSON.parse_string(JSON.stringify(left)) == JSON.parse_string(JSON.stringify(right))


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
