extends "res://tests/noncombat_market_arrival.gd"

const FIXTURE := "res://tests/fixtures/herb_refugee_recipe_pending_v1.json"
var _saw_overlap := false


func _stage_fixture() -> RefCounted:
	var path := "user://tests/herb_refugee_%d_%d.json" % [OS.get_process_id(), Time.get_ticks_usec()]
	var store = RunSession.new(path, "slot_3")
	var file := FileAccess.open(store.v2_path, FileAccess.WRITE)
	if file == null:
		return null
	file.store_string(FileAccess.get_file_as_string(FIXTURE))
	file.close()
	var game = Domain.new(Registry.new(), store, "slot_3")
	_stabilize_ambient(game)
	return game if game.restore() else null


func _continue_to(game: RefCounted, wanted: String) -> bool:
	for step in 18:
		if game.state.get("phase") == "FLOW_PENDING" and not game.resume_flow():
			push_error("herb continuation: " + game.flow_failure_reason())
			return false
		var threads: Dictionary = game.state.get("storyThreadState", {}).get("threads", {})
		if threads.get("spirit_mine", {}).get("status") == "active" \
				and threads.get("herb_refugee", {}).get("status") == "active":
			_saw_overlap = true
		if game.get_current_card().get("id") == wanted:
			return true
		if not _choose_interstitial(game):
			return false
	return false


func _choose_interstitial(game: RefCounted) -> bool:
	var card_id := String(game.get_current_card().get("id", ""))
	var direction := "right" if game.can_choose_direction("right") else "left"
	if card_id == "q_shop" and game.can_choose_direction("down"):
		direction = "down"
	elif game.state.get("phase") == "SHOP_PENDING":
		direction = "left"
	elif game.state.get("phase") == "THREAD_PENDING":
		direction = "left"
	if not game.choose(direction, game.issue_choice_token()):
		push_error("herb interstitial rejected: " + card_id + " " + direction)
		return false
	return true


func _strict_reopen(game: RefCounted) -> bool:
	var reopened = Domain.new(Registry.new(), RunSession.new(game._store.legacy_path, "slot_3"), "slot_3")
	_stabilize_ambient(reopened)
	var ok: bool = reopened.restore()
	if not ok:
		push_error("herb strict reopen rejected " + String(game.state.get("currentCardId")) +
			" error=" + String(reopened._store.last_error))
	return ok and _same(reopened.state, game.state)


func _run() -> void:
	# Card text is read from the same content repository as the runtime.
	var probe = _stage_fixture()
	if probe == null:
		return _fail("recipe fixture did not strictly restore")
	var authored: Dictionary = {}
	for item in probe._content.read_module("threads:qi_threads")["threads"]:
		if item.get("threadId") == "herb_refugee":
			authored = item
	if authored.is_empty():
		return _fail("original herb thread unavailable")
	for first_direction in ["left", "right"]:
		var game = _stage_fixture()
		if game == null or not game.choose("left", game.issue_choice_token()) \
				or game.state.get("storyThreadState", {}).get("version") != 2:
			return _fail("original recipe purchase did not activate v2 thread scheduling")
		if not _continue_to(game, "thread_herb_refugee_1"):
			return _fail("first herb node did not naturally arrive: " + JSON.stringify(game.state.get("storyThreadState")))
		if not _strict_reopen(game):
			return _fail("first herb node did not strictly restore")
		var first: Dictionary = game.get_current_card()
		if first.get("sceneImage") != authored["nodes"][0]["card"]["sceneImage"]:
			return _fail("first herb node lost original scene image")
		var knowledge_before := int(game.state.get("knowledge", {}).get("world", 0))
		if not game.choose(first_direction, game.issue_choice_token()) \
				or int(game.state.get("knowledge", {}).get("world", 0)) != knowledge_before + (
					8 if first_direction == "left" else 0) or not _strict_reopen(game):
			return _fail("first herb choice lost knowledge or strict replay")
		if not _continue_to(game, "thread_herb_refugee_2") or not _strict_reopen(game):
			return _fail("herb pursuit did not naturally arrive and restore")
		var pursuit: Dictionary = game.get_current_card()
		var original: Dictionary = authored["nodes"][1]["card"]
		if pursuit.get("sceneImage") != original["sceneImage"]:
			return _fail("herb pursuit lost original scene image")
		if first_direction == "right":
			var variant: Dictionary = authored["nodes"][1]["variants"][0]
			if pursuit.get("_threadVariantId") != variant["id"] \
					or not String(pursuit["description"]).ends_with(variant["card"]["description"]) \
					or pursuit["choices"]["right"]["text"] != variant["card"]["choices"]["right"]["text"] \
					or pursuit["choices"]["right"]["effects"] != original["choices"]["right"]["effects"]:
				return _fail("refused truth did not retain authored text and effects")
			var ui: Control = load("res://scenes/noncombat_opening.tscn").instantiate()
			ui.save_path = ""
			root.add_child(ui)
			await process_frame
			ui.opening = game
			ui._render()
			var choice_button: Button = ui.get_node("DesktopMargin/ScreenStack/StoryScreen/SourceChoices/Choice_right")
			var presented: bool = ui.art_rect.texture != null \
				and ui.body_label.text == pursuit["description"] \
				and choice_button.text.begins_with(pursuit["choices"]["right"]["text"]) \
				and not choice_button.disabled
			root.remove_child(ui)
			ui.queue_free()
			if not presented:
				return _fail("desktop UI did not consume herb scene and choice variant")
		elif pursuit.has("_threadVariantId"):
			return _fail("accepted truth used refused-truth variant")
		var pending: Dictionary = game.state.duplicate(true)
		for final_direction in ["left", "right"]:
			var path := "user://tests/herb_resolution_%d.json" % Time.get_ticks_usec()
			var store = RunSession.new(path, "slot_3")
			if store.commit_snapshot(pending, -1).get("ok") != true:
				return _fail("cannot fork herb resolution")
			var branch = Domain.new(Registry.new(), store, "slot_3")
			_stabilize_ambient(branch)
			if not branch.restore():
				return _fail("herb resolution fork did not strictly restore")
			var bytes := FileAccess.get_file_as_string(store.v2_path)
			var token := branch.issue_choice_token()
			store.fail_promotion_once = true
			if branch.choose(final_direction, token) or not _same(branch.state, pending) \
					or FileAccess.get_file_as_string(store.v2_path) != bytes \
					or not branch.choose(final_direction, token):
				return _fail("herb completion rollback or retry failed")
			var runtime: Dictionary = branch.state["storyThreadState"]["threads"]["herb_refugee"]
			var seeds: Array = branch.state.get("karmaSeeds", []).filter(func(seed: Variant) -> bool:
				return seed is Dictionary and seed.get("id") == "forbidden_pill_secret")
			if runtime.get("status") != "completed" or runtime["receipt"]["nodes"].size() != 2 \
					or runtime["receipt"]["nodes"][0]["direction"] != first_direction \
					or runtime["receipt"]["nodes"][1]["direction"] != final_direction \
					or branch.state.get("flags", {}).get("herb_valley_encounter") != true \
					or seeds.size() != 1 or seeds[0].get("delay") != 7 \
					or seeds[0].get("originThread") != "herb_refugee" \
					or seeds[0].get("originCard") != null or seeds[0].get("context") != null \
					or seeds[0].get("description") != authored["nodes"][1]["consequences"]["onComplete"]["karmaSeed"]["description"] \
					or seeds[0].get("originTurn") != branch.state["runClock"]["decisionIndex"] \
					or not _strict_reopen(branch):
				return _fail("herb receipt or deferred source promise diverged")
	if not probe.choose("right", probe.issue_choice_token()):
		return _fail("source refusal did not accept")
	for step in 6:
		if probe.state.get("phase") == "FLOW_PENDING" and not probe.resume_flow():
			return _fail("source refusal continuation failed")
		if probe.get_current_card().get("id", "").begins_with("thread_herb_refugee_") \
				or not _choose_interstitial(probe):
			return _fail("refusing original recipe incorrectly started herb thread")
	if probe.state.get("storyThreadState", {}).get("threads", {}).get(
			"herb_refugee", {}).get("status") != "inactive":
		return _fail("source refusal left an active herb thread")
	if not _saw_overlap:
		return _fail("natural route did not exercise both active threads")
	print("NONCOMBAT_HERB_REFUGEE_THREAD_PASS branches=4 refusal=true replay=true rollback=true overlap=true ui=true")
	quit(0)
