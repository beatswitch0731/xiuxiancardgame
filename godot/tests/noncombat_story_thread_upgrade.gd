extends "res://tests/noncombat_market_arrival.gd"

const LEGACY_FIXTURE := "res://tests/fixtures/spirit_mine_v1_node_pending.json"
const StoryThreadFlow = preload("res://scripts/noncombat_story_threads_v2_flow.gd")


func _run() -> void:
	var path := "user://tests/thread_upgrade_%d_%d.json" % [OS.get_process_id(), Time.get_ticks_usec()]
	var store = RunSession.new(path, "slot_3")
	var original := FileAccess.get_file_as_string(LEGACY_FIXTURE)
	var file := FileAccess.open(store.v2_path, FileAccess.WRITE)
	if file == null:
		return _fail("cannot stage original v1 thread save")
	file.store_string(original)
	file.close()
	var game = Domain.new(Registry.new(), store, "slot_3")
	_stabilize_ambient(game)
	var saved: Dictionary = JSON.parse_string(original)["state"]
	if not game.restore() or not _same(game.state, saved) \
			or game.state["storyThreadState"]["version"] != 1 \
			or game.get_current_card() != saved["pendingThreadCard"] \
			or FileAccess.get_file_as_string(store.v2_path) != original:
		return _fail("v1 thread reload changed its pending card or bytes")
	var token := game.issue_choice_token()
	store.fail_promotion_once = true
	if game.choose("left", token) or not _same(game.state, saved) \
			or FileAccess.get_file_as_string(store.v2_path) != original \
			or not game.choose("left", token):
		return _fail("thread upgrade did not preserve atomic choice retry")
	var bundle: Dictionary = game.state["storyThreadState"]
	if bundle.get("version") != 2 \
			or bundle.get("activationIndex") != saved["storyThreadState"]["activationIndex"] \
			or bundle.get("upgradeIndex") != int(saved["runClock"]["decisionIndex"]) + 1 \
			or bundle["threads"]["spirit_mine"]["choices"].size() != 1 \
			or bundle["threads"]["spirit_mine"]["choices"][0]["direction"] != "left" \
			or bundle["threads"]["herb_refugee"]["status"] != "inactive" \
			or bundle.get("lastLessonActivationIndex") != int(saved[
				"runClock"]["decisionIndex"]) + 1 \
			or bundle.get("lastLessonSourceSha") != game._content.source_sha256(
				StoryThreadFlow.LAST_LESSON_MODULE) \
			or bundle["threads"]["bairen_last_lesson"]["status"] != "inactive":
		return _fail("thread upgrade lost old progress or retroactively started new content")
	var reopened = Domain.new(Registry.new(), RunSession.new(path, "slot_3"), "slot_3")
	_stabilize_ambient(reopened)
	if not reopened.restore() or not _same(reopened.state, game.state):
		return _fail("upgraded thread save did not strictly replay its v1 prefix")
	var old_v2: Dictionary = game.state.duplicate(true)
	old_v2.storyThreadState.erase("lastLessonActivationIndex")
	old_v2.storyThreadState.erase("lastLessonSourceSha")
	old_v2.storyThreadState.threads.erase("bairen_last_lesson")
	var old_store = RunSession.new("user://tests/thread_lesson_legacy_%d.json" %
		Time.get_ticks_usec(), "slot_3")
	if old_store.commit_snapshot(old_v2, -1).get("ok") != true:
		return _fail("cannot stage markerless v2 thread save")
	var old_bytes := FileAccess.get_file_as_string(old_store.v2_path)
	var old_game = Domain.new(Registry.new(), old_store, "slot_3")
	_stabilize_ambient(old_game)
	if not old_game.restore() or not _same(old_game.state, old_v2) \
			or FileAccess.get_file_as_string(old_store.v2_path) != old_bytes:
		return _fail("markerless v2 lesson restore changed prior state or bytes")
	if not old_game.resume_flow():
		return _fail("markerless v2 lesson could not resume old flow")
	var direction := "left" if old_game.can_choose_direction("left") else "right"
	if not old_game.can_choose_direction(direction) or not old_game.choose(
			direction, old_game.issue_choice_token()):
		return _fail("markerless v2 lesson could not commit next choice")
	var activated: Dictionary = old_game.state.get("storyThreadState", {})
	if activated.get("lastLessonActivationIndex") != int(old_v2[
			"runClock"]["decisionIndex"]) + 1 \
			or activated.get("lastLessonSourceSha") != old_game._content.source_sha256(
				StoryThreadFlow.LAST_LESSON_MODULE) \
			or activated.get("threads", {}).get("bairen_last_lesson", {}).get(
				"status") != "inactive":
		return _fail("markerless v2 lesson activation crossed historical boundary")
	var old_reopened = Domain.new(Registry.new(), RunSession.new(old_store.legacy_path,
		"slot_3"), "slot_3")
	_stabilize_ambient(old_reopened)
	if not old_reopened.restore() or not _same(old_reopened.state, old_game.state):
		return _fail("activated v2 lesson could not strictly reload")
	var lesson_drift: Dictionary = old_game.state.duplicate(true)
	lesson_drift.storyThreadState.lastLessonSourceSha = "0".repeat(64)
	var lesson_drift_store = RunSession.new(
		"user://tests/thread_lesson_drift_%d.json" % Time.get_ticks_usec(), "slot_3")
	if lesson_drift_store.commit_snapshot(lesson_drift, -1).get("ok") != true:
		return _fail("cannot stage forged lesson source pin")
	var drift_bytes := FileAccess.get_file_as_string(lesson_drift_store.v2_path)
	var lesson_rejected = Domain.new(Registry.new(), lesson_drift_store, "slot_3")
	_stabilize_ambient(lesson_rejected)
	if lesson_rejected.restore() or lesson_drift_store.last_error != "SOURCE_MISMATCH" \
			or FileAccess.get_file_as_string(lesson_drift_store.v2_path) != drift_bytes:
		return _fail("forged lesson source pin was trusted or slot bytes changed")
	var forged: Dictionary = game.state.duplicate(true)
	forged["storyThreadState"]["upgradeIndex"] = int(game.state["runClock"]["decisionIndex"]) + 1
	var forged_store = RunSession.new("user://tests/thread_upgrade_forged_%d.json" % Time.get_ticks_usec(), "slot_3")
	if forged_store.commit_snapshot(forged, -1).get("ok") != true:
		return _fail("cannot stage forged upgrade index")
	var rejected = Domain.new(Registry.new(), forged_store, "slot_3")
	_stabilize_ambient(rejected)
	if rejected.restore():
		return _fail("future thread upgrade index was trusted")
	var recipe_path := "user://tests/thread_upgrade_recipe_%d.json" % Time.get_ticks_usec()
	var recipe_store = RunSession.new(recipe_path, "slot_3")
	var recipe_file := FileAccess.open(recipe_store.v2_path, FileAccess.WRITE)
	if recipe_file == null:
		return _fail("cannot stage original recipe route for v1 continuation")
	recipe_file.store_string(FileAccess.get_file_as_string(
		"res://tests/fixtures/herb_refugee_recipe_pending_v1.json"))
	recipe_file.close()
	var recipe = Domain.new(Registry.new(), recipe_store, "slot_3")
	_stabilize_ambient(recipe)
	if not recipe.restore():
		return _fail("original recipe route did not restore")
	# Emulate the released singleton scheduler through its actual choice path.
	recipe._story_thread_flow.upgrade_index = 1000
	if not recipe.choose("left", recipe.issue_choice_token()) \
			or recipe.state["storyThreadState"]["version"] != 1:
		return _fail("cannot produce authentic v1 purchased-recipe prefix")
	var old_recipe: Dictionary = recipe.state.duplicate(true)
	var resumed = Domain.new(Registry.new(), RunSession.new(recipe_path, "slot_3"), "slot_3")
	_stabilize_ambient(resumed)
	if not resumed.restore() or not _same(resumed.state, old_recipe) \
			or not resumed.resume_flow() or resumed.get_current_card().get("id") != "q_shop" \
			or not resumed.choose("right", resumed.issue_choice_token()) \
			or resumed.state["storyThreadState"]["threads"]["herb_refugee"]["status"] != "active":
		return _fail("upgrade discarded a valid recent recipe purchase")
	var continued = Domain.new(Registry.new(), RunSession.new(recipe_path, "slot_3"), "slot_3")
	_stabilize_ambient(continued)
	if not continued.restore() or not _same(continued.state, resumed.state):
		return _fail("recent-recipe upgrade did not strictly replay")
	print("NONCOMBAT_STORY_THREAD_UPGRADE_PASS v1=true v2=true replay=true rollback=true prior_choice=true lesson_legacy=true lesson_pin=true")
	quit(0)
