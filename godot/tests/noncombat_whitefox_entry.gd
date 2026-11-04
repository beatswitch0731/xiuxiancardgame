extends SceneTree

const Registry = preload("res://scripts/runtime_data_registry.gd")
const Domain = preload("res://scripts/noncombat_domain.gd")
const RunSession = preload("res://scripts/noncombat_run_session.gd")
const ContentRepository = preload("res://scripts/noncombat_content_repository.gd")
const QuestFlow = preload("res://scripts/noncombat_quest_flow.gd")

class DriftedQuestContent extends "res://scripts/noncombat_content_repository.gd":
	func source_sha256(module_id: String) -> String:
		if module_id == "quests:white_fox":
			return "a".repeat(64)
		return super.source_sha256(module_id)


class DriftedChapterContent extends "res://scripts/noncombat_content_repository.gd":
	func source_sha256(module_id: String) -> String:
		if module_id == "cards:chapter_milestones":
			return "b".repeat(64)
		return super.source_sha256(module_id)


class MissingQuestArtContent extends "res://scripts/noncombat_content_repository.gd":
	func card_scene_image_status(card_id: String) -> Dictionary:
		var result: Dictionary = super.card_scene_image_status(card_id)
		if card_id == "q_whiteFox_quest":
			result["fileExists"] = false
			result["shaVerified"] = false
			result["textureLoadable"] = false
		return result


class QuestByteMismatchContent extends "res://scripts/noncombat_content_repository.gd":
	func source_sha256(module_id: String) -> String:
		return "" if module_id == "quests:white_fox" else super.source_sha256(module_id)

	func errors() -> Array[String]:
		return ["Source SHA mismatch: data/quests/white_fox.json"]


class QuestMissingContent extends "res://scripts/noncombat_content_repository.gd":
	func source_sha256(module_id: String) -> String:
		return "" if module_id == "quests:white_fox" else super.source_sha256(module_id)

	func errors() -> Array[String]:
		return ["Missing source copy: data/quests/white_fox.json"]

	func module_path(module_id: String) -> String:
		return "" if module_id == "quests:white_fox" else super.module_path(module_id)


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	for path_id in ["sword", "spell", "body", "pill"]:
		var save_path := "user://tests/whitefox_%s_%d.json" % [path_id, Time.get_ticks_usec()]
		var game = Domain.new(Registry.new(), RunSession.new(save_path, "slot_3"), "slot_3")
		if not game.start(path_id):
			_fail("start: " + path_id)
			return
		for step in 5:
			if not game.choose("left", game.issue_choice_token()):
				_fail("opening step %d: %s" % [step, path_id])
				return
		if not game.choose("right", game.issue_choice_token()) \
				or not game.choose("left", game.issue_choice_token()) \
				or not game.resume_flow() \
				or not game.choose("left", game.issue_choice_token()) \
				or not game.choose("right", game.issue_choice_token()):
			_fail("chapter route: " + path_id)
			return
		if game.state.get("phase") != "FLOW_PENDING":
			_fail("chapter did not end at scheduler boundary: " + path_id)
			return
		if path_id == "sword" and not _check_rejections(game, save_path):
			return
		if not game.resume_flow():
			_fail("white fox was not scheduled: " + path_id)
			return
		var card: Dictionary = game.get_current_card()
		var before: Dictionary = game.state.duplicate(true)
		if game.state.get("phase") != "QUEST_PENDING" \
				or card.get("id") != "q_whiteFox_quest" \
				or card.get("title") != "白狐受困" \
				or card.get("sceneImage") != "assets/cards/events/scene_event_qi_whitefox.png" \
				or Registry.new().texture_for(String(card.get("sceneImage", ""))) == null \
				or int(game.state.get("runClock", {}).get("decisionIndex", -1)) != 9 \
				or game.state.get("questState", {}).get("activeQuests", []).size() != 1 \
				or game.state.get("questState", {}).get("activeQuests", [])[0].get("questId") != "white_fox_line" \
				or game.state.get("flags", {}).get("quest_white_fox_line_active") != true \
				or game.issue_choice_token() <= 0:
			_fail("source quest projection differs: " + path_id)
			return
		if game.choose("right", 1) or game.resume_flow() or not _same(game.state, before):
			_fail("entry was repeated or unsupported choice accepted: " + path_id)
			return
		if path_id == "sword":
			var committed := FileAccess.get_file_as_string(game._store.v2_path)
			var drift_store = RunSession.new(save_path, "slot_3")
			var drifted = Domain.new(Registry.new(), drift_store, "slot_3",
				DriftedQuestContent.new())
			if drifted.restore() or drift_store.last_error != "SOURCE_MISMATCH" \
					or FileAccess.get_file_as_string(game._store.v2_path) != committed:
				_fail("coherent quest source update did not preserve and lock saved entry")
				return
			var missing_art_store = RunSession.new(save_path, "slot_3")
			var missing_art = Domain.new(Registry.new(), missing_art_store, "slot_3",
				MissingQuestArtContent.new())
			if missing_art.restore() or missing_art_store.last_error != "SOURCE_MISMATCH" \
					or FileAccess.get_file_as_string(game._store.v2_path) != committed:
				_fail("missing quest art did not preserve and lock saved entry")
				return
			for source_case in [
				[QuestByteMismatchContent.new(), "SOURCE_MISMATCH"],
				[QuestMissingContent.new(), "SOURCE_UNAVAILABLE"]
			]:
				var source_store = RunSession.new(save_path, "slot_3")
				var source_reopen = Domain.new(Registry.new(), source_store, "slot_3",
					source_case[0])
				if source_reopen.restore() or source_store.last_error != source_case[1] \
						or FileAccess.get_file_as_string(game._store.v2_path) != committed:
					_fail("quest bytes/missing source classified incorrectly: " + str(source_case[1]))
					return
		var reloaded = Domain.new(Registry.new(), RunSession.new(save_path, "slot_3"), "slot_3")
		if not reloaded.restore() or not _same(reloaded.state, before) \
				or reloaded.get_current_card().get("id") != "q_whiteFox_quest":
			_fail("source quest entry did not survive strict replay: " + path_id)
			return
	print("NONCOMBAT_WHITEFOX_ENTRY_PASS paths=4 art=true replay=true choices_delegated=true")
	quit(0)


func _check_rejections(game: RefCounted, save_path: String) -> bool:
	var boundary: Dictionary = game.state.duplicate(true)
	var before_bytes := FileAccess.get_file_as_string(game._store.v2_path)
	var chapter_store = RunSession.new(save_path, "slot_3")
	var chapter_drift = Domain.new(Registry.new(), chapter_store, "slot_3",
		DriftedChapterContent.new())
	if chapter_drift.restore() or chapter_store.last_error != "SOURCE_MISMATCH" \
			or FileAccess.get_file_as_string(game._store.v2_path) != before_bytes:
		_fail("coherent chapter source update did not preserve post-chapter save")
		return false
	game._store.fail_promotion_once = true
	if game.resume_flow() or not _same(game.state, boundary) \
			or FileAccess.get_file_as_string(game._store.v2_path) != before_bytes:
		_fail("failed quest activation write changed visible state or save")
		return false
	var flow = QuestFlow.new(ContentRepository.new())
	for variant in [
		{"turn": 4},
		{"flags": {"whiteFoxCompleted": true}},
		{"flags": {"quest_white_fox_line_active": true}},
		{"cardsPlayed": ["q_whiteFox"]},
		{"choiceHistory": [{"cardId": "sd_qi_white_fox"}]},
		{"questState": {"activeQuests": [{"questId": "other"}]}}
	]:
		var candidate: Dictionary = boundary.duplicate(true)
		for key in variant:
			candidate[key] = variant[key]
		if not flow.resume(candidate).is_empty():
			_fail("forbidden quest trigger accepted: " + str(variant))
			return false
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(
		"res://content/source_manifest.json"))
	for row in manifest.get("data", []):
		if row is Dictionary and row.get("path") == "data/quests/white_fox.json":
			row["sha256"] = "0".repeat(64)
			break
	var bad_path := "user://tests/whitefox_bad_source_%d.json" % Time.get_ticks_usec()
	var bad_file := FileAccess.open(bad_path, FileAccess.WRITE)
	bad_file.store_string(JSON.stringify(manifest))
	bad_file.close()
	if not QuestFlow.new(ContentRepository.new(bad_path)).resume(boundary).is_empty():
		_fail("quest source SHA drift was accepted")
		return false
	var blocked_store = RunSession.new(save_path, "slot_3")
	var blocked = Domain.new(Registry.new(), blocked_store, "slot_3",
		ContentRepository.new(bad_path))
	var blocked_restored := blocked.restore()
	var blocked_resumed := blocked.resume_flow() if blocked_restored else false
	if not blocked_restored or blocked_resumed \
			or blocked.flow_failure_reason().is_empty() \
			or blocked_store.last_error != "SOURCE_MISMATCH" \
			or FileAccess.get_file_as_string(game._store.v2_path) != before_bytes:
		_fail("pre-quest save did not preserve source error: " + str({
			"restored": blocked_restored, "resumed": blocked_resumed,
			"reason": blocked.flow_failure_reason(), "status": blocked_store.last_error,
			"phase": blocked.state.get("phase"),
			"flowHash": blocked.state.get("noncombatFlow", {}).get("sourceContentHash"),
			"gatewayHash": blocked._battle_gateway.source_content_hash(),
			"chapterHash": blocked.state.get("noncombatFlow", {}).get("milestoneSourceSha"),
			"currentChapterHash": blocked._content.source_sha256("cards:chapter_milestones")}))
		return false
	DirAccess.remove_absolute(ProjectSettings.globalize_path(bad_path))
	return true


func _same(left: Dictionary, right: Dictionary) -> bool:
	return JSON.parse_string(JSON.stringify(left)) == JSON.parse_string(JSON.stringify(right))


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
