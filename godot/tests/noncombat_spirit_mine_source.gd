extends "res://tests/noncombat_spirit_mine_thread.gd"

class MissingThreadArtContent extends "res://scripts/noncombat_content_repository.gd":
	func card_scene_image_status(card_id: String) -> Dictionary:
		var result: Dictionary = super.card_scene_image_status(card_id)
		if card_id == "thread_spirit_mine_1":
			result["fileExists"] = false
			result["shaVerified"] = false
			result["textureLoadable"] = false
		return result

class ChangedThreadArtContent extends "res://scripts/noncombat_content_repository.gd":
	func card_scene_image_status(card_id: String) -> Dictionary:
		var result: Dictionary = super.card_scene_image_status(card_id)
		if card_id == "thread_spirit_mine_1":
			result["shaVerified"] = false
			result["textureLoadable"] = false
		return result


func _run() -> void:
	var path := "user://tests/spirit_mine_source_%d_%d.json" % [
		OS.get_process_id(), Time.get_ticks_usec()]
	var store = RunSession.new(path, "slot_3")
	var staged := FileAccess.open(store.v2_path, FileAccess.WRITE)
	if staged == null:
		return _fail("cannot stage source-failure checkpoint")
	staged.store_string(FileAccess.get_file_as_string(FIXTURE))
	staged.close()
	var game = Domain.new(Registry.new(), store, "slot_3")
	_stabilize_ambient(game)
	if not game.restore() or not game.choose("right", game.issue_choice_token()):
		return _fail("cannot continue original mine trigger")
	var before_delivery: Dictionary = {}
	for step in 18:
		if game.state.get("phase") == "FLOW_PENDING":
			before_delivery = game.state.duplicate(true)
			if not game.resume_flow():
				return _fail("original route stopped before source-failure check")
		if game.state.get("phase") == "THREAD_PENDING":
			break
		var direction := "right" if game.can_choose_direction("right") else "left"
		if not game.choose(direction, game.issue_choice_token()):
			return _fail("original interstitial choice failed")
	if game.get_current_card().get("id") != "thread_spirit_mine_1":
		return _fail("original route did not reach first thread node")
	var pending: Dictionary = game.state.duplicate(true)
	var bytes := FileAccess.get_file_as_string(store.v2_path)
	for spec in [[MissingThreadArtContent.new(), "SOURCE_UNAVAILABLE"],
			[ChangedThreadArtContent.new(), "SOURCE_MISMATCH"]]:
		var rejected = Domain.new(Registry.new(), RunSession.new(path, "slot_3"),
			"slot_3", spec[0])
		_stabilize_ambient(rejected)
		if rejected.restore() or rejected._store.last_error != spec[1] \
				or FileAccess.get_file_as_string(store.v2_path) != bytes:
			return _fail("thread pending source failure was not classified: " +
				String(rejected._store.last_error))
	var live_path := "user://tests/spirit_mine_source_live_%d.json" % Time.get_ticks_usec()
	var live_store = RunSession.new(live_path, "slot_3")
	if live_store.commit_snapshot(before_delivery, -1).get("ok") != true:
		return _fail("cannot stage pre-delivery thread checkpoint")
	var live = Domain.new(Registry.new(), live_store, "slot_3")
	_stabilize_ambient(live)
	if not live.restore():
		return _fail("pre-delivery checkpoint did not strictly restore")
	var live_bytes := FileAccess.get_file_as_string(live_store.v2_path)
	live._story_thread_flow._content = MissingThreadArtContent.new()
	if live.resume_flow() or live._store.last_error != "SOURCE_UNAVAILABLE" \
			or live.flow_failure_reason().is_empty() \
			or not _same(live.state, before_delivery) \
			or FileAccess.get_file_as_string(live_store.v2_path) != live_bytes:
		return _fail("missing thread art lost delivery error or changed state")
	var token := game.issue_choice_token()
	game._story_thread_flow._content = MissingThreadArtContent.new()
	if game.choose("left", token) or store.last_error != "SOURCE_UNAVAILABLE" \
			or game.flow_failure_reason().is_empty() or not _same(game.state, pending) \
			or FileAccess.get_file_as_string(store.v2_path) != bytes:
		return _fail("missing thread art during choice lost error or changed state")
	print("NONCOMBAT_STORY_SPIRIT_MINE_SOURCE_PASS missing=true drift=true atomic=true")
	quit(0)
