extends SceneTree

const ThreadJournal = preload("res://scripts/noncombat_thread_journal.gd")
const OpeningUI = preload("res://scripts/noncombat_opening_ui.gd")
const Registry = preload("res://scripts/runtime_data_registry.gd")
const ThreadFlow = preload("res://scripts/noncombat_story_threads_v2_flow.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var state := {"storyThreadState": {"version": 2, "threads": {
		"spirit_mine": {"status": "active", "nodeIndex": 1, "startedTurn": 7,
			"choices": [{"threadDirection": "brave"}]},
		"herb_refugee": {"status": "completed", "nodeIndex": 2,
			"receipt": {"closedTurn": 12, "completedTurn": 12}}}},
		"karmaSeeds": [{"id": "seed_quest", "desc": "旧约回响",
			"originThread": "spirit_mine"}]}
	var projected: Dictionary = ThreadJournal.new().project(state)
	var source: Dictionary = Registry.new().read_json("data/threads/qi_threads.json")
	var titles := {}
	var herb_note := ""
	for definition in source.threads:
		titles[definition.threadId] = definition.title
		if definition.threadId == "herb_refugee":
			herb_note = String(definition.nodes.back().consequences.onComplete.note)
	if projected.active.size() != 1 or projected.completed.size() != 1 \
			or projected.seeds.size() != 1 \
			or projected.active[0].title != titles.spirit_mine \
			or projected.active[0].phase != "resolution" \
			or projected.active[0].progress != "1/2" \
			or projected.active[0].dominantDirection != "brave" \
			or projected.completed[0].title != titles.herb_refugee \
			or projected.completed[0].note != herb_note \
			or projected.seeds[0].origin != "spirit_mine":
		return _fail("source StoryThreadEngine sidebar projection differs")
	var later_closed: Dictionary = state.duplicate(true)
	var closed_count := 0
	for thread_id in ThreadFlow.THREAD_IDS:
		if thread_id in ["spirit_mine", "herb_refugee"]:
			continue
		later_closed.storyThreadState.threads[thread_id] = {"status": "declined",
			"receipt": {"closedTurn": 13 + closed_count}}
		closed_count += 1
		if closed_count == 5:
			break
	if not ThreadJournal.new().project(later_closed).completed.is_empty():
		return _fail("recent five declined threads should hide an older completion")
	var realm_closed: Dictionary = state.duplicate(true)
	closed_count = 0
	for thread_id in ThreadFlow.THREAD_IDS:
		if thread_id in ["spirit_mine", "herb_refugee"]:
			continue
		realm_closed.storyThreadState.threads[thread_id] = {"status": "realm_expired",
			"receipt": {"closedTurn": 13 + closed_count}}
		closed_count += 1
		if closed_count == 5:
			break
	if not ThreadJournal.new().project(realm_closed).completed.is_empty():
		return _fail("recent five realm-expired threads should hide an older completion")
	var ui = OpeningUI.new()
	ui.save_path = ""
	root.add_child(ui)
	await process_frame
	if not ui.opening.start("sword"):
		return _fail("source story did not start")
	var button: Button = ui.find_child("OpenThreadJournal", true, false)
	if button == null or not button.visible:
		return _fail("story journal has no visible player entry")
	var before: Dictionary = ui.opening.state.duplicate(true)
	button.pressed.emit()
	await process_frame
	var dialog: AcceptDialog = ui.find_child("ThreadJournal", true, false)
	var list: VBoxContainer = dialog.find_child("ThreadJournalEntries", true, false)
	if not dialog.visible or list.get_child_count() != 6 \
			or not String(list.get_child(1).text).contains("暂无活跃故事线") \
			or ui.opening.state != before:
		return _fail("empty story journal mutated run or showed wrong text")
	ui.opening.state.storyThreadState = state.storyThreadState.duplicate(true)
	ui.opening.state.karmaSeeds = state.karmaSeeds.duplicate(true)
	var seeded_before: Dictionary = ui.opening.state.duplicate(true)
	button.pressed.emit()
	await process_frame
	if list.get_child_count() != 6 \
			or not String(list.get_child(1).text).contains(titles.spirit_mine) \
			or not String(list.get_child(3).text).contains(titles.herb_refugee) \
			or not String(list.get_child(3).text).contains(herb_note) \
			or not String(list.get_child(5).text).contains("旧约回响") \
			or ui.opening.state != seeded_before:
		return _fail("source thread journal did not display the current life")
	for resolution in [Vector2i(1280, 800), Vector2i(1920, 1080)]:
		root.get_window().size = resolution
		await process_frame
		await process_frame
		if button.get_global_rect().end.x > resolution.x \
				or button.get_global_rect().end.y > resolution.y \
				or dialog.position.x + dialog.size.x > resolution.x \
				or dialog.position.y + dialog.size.y > resolution.y:
			return _fail("story journal clipped at %s" % resolution)
	print("NONCOMBAT_THREAD_JOURNAL_PASS source=true active=true completed=true seeds=true ui=true sizes=2")
	quit(0)

func _fail(message: String) -> void:
	push_error(message)
	quit(1)
