extends SceneTree

const Registry = preload("res://scripts/runtime_data_registry.gd")
const Domain = preload("res://scripts/noncombat_domain.gd")
const RunSession = preload("res://scripts/noncombat_run_session.gd")

class LegacyMemoryStore extends RefCounted:
	var snapshot: Dictionary = {}
	func load_state() -> Dictionary:
		return JSON.parse_string(JSON.stringify(snapshot))
	func save_state(candidate: Dictionary) -> bool:
		snapshot = candidate.duplicate(true)
		return true

class DriftMentorContent extends "res://scripts/noncombat_content_repository.gd":
	func source_sha256(module_id: String) -> String:
		if module_id == "companions:arcs":
			return "0".repeat(64)
		return super.source_sha256(module_id)

class MissingMentorArtContent extends "res://scripts/noncombat_content_repository.gd":
	func asset_status(path: String) -> Dictionary:
		var result: Dictionary = super.asset_status(path)
		if path == "assets/characters/stages/bai_ren_sword_tomb_master.png":
			result["shaVerified"] = false
			result["textureLoadable"] = false
		return result


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	# Fragment acquisition seeds from Godot's process RNG; freeze this route so
	# a rare heaven-book completion cannot move the chapter threshold earlier.
	seed(12345)
	for direction in ["left", "right"]:
		var save_path := "user://tests/mentor_arc_%s_%d.json" % [
			direction, Time.get_ticks_usec()]
		var game = Domain.new(Registry.new(), RunSession.new(save_path, "slot_3"), "slot_3")
		if not _reach_third_chosen(game, "sword"):
			_fail("source third milestone route is unreachable")
			return
		var mentor: Dictionary = game.state.get("mentorArcState", {})
		if int(mentor.get("progression", -1)) != 21 \
				or mentor.get("stage") != "INNER_DISCIPLE" \
				or mentor.get("pendingStages") != ["INNER_DISCIPLE"]:
			_fail("browser mentor progression 12→14→15→19→21 was not persisted")
			return
		if direction == "left":
			var before_art: Dictionary = game.state.duplicate(true)
			var before_art_bytes := FileAccess.get_file_as_string(game._store.v2_path)
			var bad_art = Domain.new(Registry.new(), RunSession.new(save_path, "slot_3"),
				"slot_3", MissingMentorArtContent.new())
			if not bad_art.restore() or bad_art.resume_flow() \
					or not _same(bad_art.state, before_art) \
					or FileAccess.get_file_as_string(game._store.v2_path) != before_art_bytes:
				_fail("missing mentor portrait scheduled or changed a valid save")
				return
		if direction == "left":
			var legacy_store := LegacyMemoryStore.new()
			legacy_store.snapshot = game.state.duplicate(true)
			legacy_store.snapshot.erase("mentorArcState")
			var legacy = Domain.new(Registry.new(), legacy_store, "slot_3")
			if not legacy.restore() or legacy.state.has("mentorArcState") \
					or not legacy.resume_flow() \
					or legacy.get_current_card().get("id") != "mentor_bai_ren_stage_INNER_DISCIPLE" \
					or int(legacy.state.get("mentorArcState", {}).get("progression", 0)) != 21:
				_fail("legacy save did not reconstruct mentor progression before scheduling")
				return
		if not game.resume_flow():
			_fail("due mentor stage did not follow the third qi milestone: " + game.flow_failure_reason())
			return
		var card: Dictionary = game.get_current_card()
		if game.state.get("phase") != "MENTOR_PENDING" \
				or card.get("id") != "mentor_bai_ren_stage_INNER_DISCIPLE" \
				or card.get("title") != "师尊·断剑" \
				or card.get("semanticKey") != "arc:bai_ren:INNER_DISCIPLE" \
				or card.get("sceneImage") != "assets/characters/stages/bai_ren_sword_tomb_master.png" \
				or Registry.new().texture_for(String(card.get("sceneImage", ""))) == null:
			_fail("source mentor content, stage or existing portrait did not project")
			return
		var pending: Dictionary = game.state.duplicate(true)
		var pending_bytes := FileAccess.get_file_as_string(game._store.v2_path)
		var drift_store = RunSession.new(save_path, "slot_3")
		var drift = Domain.new(Registry.new(), drift_store, "slot_3", DriftMentorContent.new())
		if drift.restore() or drift_store.last_error != "SOURCE_MISMATCH" \
				or FileAccess.get_file_as_string(game._store.v2_path) != pending_bytes:
			_fail("mentor source drift did not protect pending save")
			return
		var reloaded = Domain.new(Registry.new(), RunSession.new(save_path, "slot_3"), "slot_3")
		if not reloaded.restore() or not _same(reloaded.state, pending):
			_fail("mentor event did not strictly replay")
			return
		var token := reloaded.issue_choice_token()
		reloaded._store.fail_promotion_once = true
		if reloaded.choose(direction, token) or not _same(reloaded.state, pending) \
				or FileAccess.get_file_as_string(reloaded._store.v2_path) != pending_bytes:
			_fail("failed mentor write leaked state")
			return
		if not reloaded.choose(direction, token) or reloaded.choose(direction, token):
			_fail("mentor choice did not settle exactly once")
			return
		var after: Dictionary = reloaded.state
		if after.get("choiceEchoes", []).size() != 1 \
				or after.choiceEchoes[0].get("cardId") != "mentor_bai_ren_stage_INNER_DISCIPLE" \
				or after.choiceEchoes[0].get("choice") != direction \
				or after.choiceEchoes[0].get("context", {}).get("npcId") != "bai_ren" \
				or after.get("choiceEchoState", {}).get("nextSequence") != 1:
			_fail("mentor choice did not persist its delayed echo seed")
			return
		var result: Dictionary = reloaded.get_current_card()
		var expected_result := "promise_result_3b3a1690" if direction == "left" \
			else "promise_result_dc8715d0"
		if after.get("phase") != "NARRATIVE_RESULT_PENDING" \
				or result.get("id") != expected_result \
				or result.get("title") != "师尊·断剑·回应" \
				or int(after["runClock"]["decisionIndex"]) != 12 \
				or int(after["attributes"]["cultivation"]) != (64 if direction == "left" else 61) \
				or int(after["attributes"]["karmaGood"]) != (12 if direction == "left" else 2) \
				or int(after["attributes"]["fortune"]) != (52 if direction == "left" else 57) \
				or int(after["mentorArcState"]["progression"]) != (22 if direction == "left" else 21) \
				or after["mentorArcState"]["pendingStages"] != [] \
				or not after["mentorArcState"]["eventsTriggered"].has(card["id"]):
			_fail("mentor choice or immediate source response differs: " + direction)
			return
		var settled_reload = Domain.new(Registry.new(), RunSession.new(save_path, "slot_3"), "slot_3")
		if not settled_reload.restore() or not _same(settled_reload.state, after):
			_fail("mentor choice response did not strictly replay")
			return
		var response_bytes := FileAccess.get_file_as_string(settled_reload._store.v2_path)
		var normal_content: RefCounted = settled_reload._content
		for drifting_content in [DriftMentorContent.new(), MissingMentorArtContent.new()]:
			settled_reload._content = drifting_content
			if settled_reload.choose("left", settled_reload.issue_choice_token()) \
					or not _same(settled_reload.state, after) \
					or FileAccess.get_file_as_string(settled_reload._store.v2_path) != response_bytes:
				_fail("mentor response acknowledged after source or art drift")
				return
		settled_reload._content = normal_content
		if not settled_reload.choose("left", settled_reload.issue_choice_token()) \
				or settled_reload.state.get("phase") != "FLOW_PENDING" \
				or settled_reload.state["mentorArcState"]["eventsTriggered"].count(card["id"]) != 1:
			_fail("mentor response acknowledgment did not settle once")
			return
	for path in ["spell", "pill"]:
		var other = Domain.new(Registry.new(), null, "slot_3")
		if not _reach_third_chosen(other, path):
			_fail("cross-path third milestone unreachable: " + path)
			return
		var progress := int(other.state.get("mentorArcState", {}).get("progression", -1))
		if progress != 20:
			_fail("cross-path mentor progression differs: " + path + "=" + str(progress))
			return
		var scheduled := other.resume_flow()
		if not scheduled or other.get_current_card().get("id") != \
				"mentor_bai_ren_stage_INNER_DISCIPLE":
			_fail("mentor was suppressed by path: " + path)
			return
	var body = Domain.new(Registry.new(), null, "slot_3")
	if not _reach_fox_chosen(body, "body") \
			or int(body.state["attributes"]["cultivation"]) != 49 \
			or int(body.state["mentorArcState"]["progression"]) >= 20 \
			or body.resume_flow() and body.get_current_card().get("id") == \
				"mentor_bai_ren_stage_INNER_DISCIPLE":
		_fail("body route queued mentor before cultivation threshold")
		return
	print("NONCOMBAT_MENTOR_ARC_PASS branches=2 paths=4 progression=true art=true replay=true")
	quit(0)


func _reach_third_chosen(game: RefCounted, path: String) -> bool:
	return _reach_fox_chosen(game, path) \
		and game.resume_flow() \
		and game.get_current_card().get("id") == "ch_qi_60" \
		and game.choose("left", game.issue_choice_token()) \
		and game.state.get("phase") == "FLOW_PENDING"


func _reach_fox_chosen(game: RefCounted, path: String) -> bool:
	if not game.start(path):
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
		and game.choose("left", game.issue_choice_token()) \
		and game.state.get("phase") == "FLOW_PENDING"


func _same(left: Dictionary, right: Dictionary) -> bool:
	return JSON.parse_string(JSON.stringify(left)) == JSON.parse_string(JSON.stringify(right))


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
