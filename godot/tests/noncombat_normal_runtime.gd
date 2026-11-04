extends "res://tests/noncombat_bazaar_vendor.gd"

func _run() -> void:
	var path := "user://tests/normal_runtime_%d.json" % Time.get_ticks_usec()
	var game = Domain.new(Registry.new(), RunSession.new(path, "slot_3"), "slot_3")
	_set_zero_rolls(game)
	if not _reach_decision27(game):
		return _fail("source path to heavens hint choice was not reachable")
	if game.state.get("phase") != "FLOW_PENDING" \
			or game.state.get("runClock", {}).get("decisionIndex") != 27:
		return _fail("heavens hint did not settle at source decision 27")
	var before: Dictionary = game.state.duplicate(true)
	var bytes := FileAccess.get_file_as_string(game._store.v2_path)
	game._store.fail_promotion_once = true
	if game.resume_flow() or not _same(game.state, before) \
			or FileAccess.get_file_as_string(game._store.v2_path) != bytes:
		return _fail("failed normal draw commit changed state or save bytes")
	if not game.resume_flow() or game.get_current_card().get("id") != "q_gathering":
		return _fail("first source ordinary card was not published")
	if game.state.get("phase") != "NORMAL_PENDING" \
			or game.can_choose_direction("right") \
			or not game.can_choose_direction("left"):
		return _fail("gathering phase or capped choice admission differs")
	var pending: Dictionary = game.state.duplicate(true)
	var ui: Control = load("res://scenes/noncombat_opening.tscn").instantiate()
	ui.save_path = ""
	root.add_child(ui)
	await process_frame
	ui.opening = game
	ui._render()
	var row: HBoxContainer = ui.get_node("DesktopMargin/ScreenStack/StoryScreen/SourceChoices")
	var left_button: Button = row.get_node_or_null("Choice_left")
	var right_button: Button = row.get_node_or_null("Choice_right")
	if ui.title_label.text != game.get_current_card().get("title") \
			or ui.art_rect.texture == null or left_button == null \
			or left_button.disabled or right_button == null or not right_button.disabled:
		return _fail("desktop gathering card did not show source art and admission")
	var reload = Domain.new(Registry.new(), RunSession.new(path, "slot_3"), "slot_3")
	_set_zero_rolls(reload)
	if not reload.restore() or not _same(reload.state, pending) \
			or reload.get_current_card().get("id") != "q_gathering":
		return _fail("pending ordinary card was not strictly restored")
	var legacy_record: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(
		game._store.v2_path))
	legacy_record["state"]["normalFlow"]["sourcePins"].erase("shops:treasures")
	legacy_record["state"]["normalFlow"]["sourcePins"].erase("config:path_skills")
	var legacy_store = RunSession.new(
		"user://tests/normal_legacy_pins_%d.json" % Time.get_ticks_usec(), "slot_3")
	var legacy_file := FileAccess.open(legacy_store.v2_path, FileAccess.WRITE)
	if legacy_file == null:
		return _fail("legacy normal source-pin fixture could not be staged")
	legacy_file.store_string(JSON.stringify(legacy_record))
	legacy_file.close()
	var legacy = Domain.new(Registry.new(), legacy_store, "slot_3")
	_set_zero_rolls(legacy)
	if not legacy.restore() or legacy.get_current_card().get("id") != "q_gathering" \
			or not legacy.choose("left", legacy.issue_choice_token()) \
			or legacy.state.get("normalFlow", {}).get("sourcePins", {}).size() \
				!= game.state.get("normalFlow", {}).get("sourcePins", {}).size():
		return _fail("first N9q ordinary save did not replay and upgrade passive pins")
	if not reload.choose("left", reload.issue_choice_token()) \
			or reload.state.get("phase") != "FLOW_PENDING" \
			or reload.state.get("maxHealth") != 4 \
			or reload.state.get("maxDaoHeart") != 3 \
			or reload.state.get("attributes", {}).get("health") != 1 \
			or reload.state.get("resources", {}).get("lifespan") != 75:
		return _fail("gathering settlement did not match source burn blood")
	var settled: Dictionary = reload.state.duplicate(true)
	var chosen_reload = Domain.new(Registry.new(), RunSession.new(path, "slot_3"), "slot_3")
	_set_zero_rolls(chosen_reload)
	if not chosen_reload.restore() or not _same(chosen_reload.state, settled):
		return _fail("settled ordinary card was not strictly restored")
	if not chosen_reload.resume_flow() \
			or chosen_reload.get_current_card().get("id") != "q_meditation" \
			or chosen_reload.state.get("normalFlow", {}).get("cardCount") != 19:
		return _fail("next ordinary draw ignored cooldown or phase cursor")
	var second_pending: Dictionary = chosen_reload.state.duplicate(true)
	var second_reload = Domain.new(Registry.new(), RunSession.new(path, "slot_3"), "slot_3")
	_set_zero_rolls(second_reload)
	if not second_reload.restore() or not _same(second_reload.state, second_pending):
		return _fail("second ordinary card failed strict restart")
	var tampered: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(
		chosen_reload._store.v2_path))
	tampered["state"]["normalFlow"]["draws"][0]["cardId"] = "q_meditation"
	var bad_store = RunSession.new("user://tests/normal_bad_draw_%d.json" % Time.get_ticks_usec(),
		"slot_3")
	var bad_file := FileAccess.open(bad_store.v2_path, FileAccess.WRITE)
	if bad_file == null:
		return _fail("normal tamper fixture could not be staged")
	var bad_bytes := JSON.stringify(tampered)
	bad_file.store_string(bad_bytes)
	bad_file.close()
	var bad_game = Domain.new(Registry.new(), bad_store, "slot_3")
	if bad_game.restore() or FileAccess.get_file_as_string(bad_store.v2_path) != bad_bytes:
		return _fail("tampered normal draw receipt was accepted or rewritten")
	var stale_passive: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(
		chosen_reload._store.v2_path))
	stale_passive["state"]["normalFlow"]["sourcePins"]["shops:treasures"] = "0".repeat(64)
	var stale_store = RunSession.new(
		"user://tests/normal_stale_passive_%d.json" % Time.get_ticks_usec(), "slot_3")
	var stale_file := FileAccess.open(stale_store.v2_path, FileAccess.WRITE)
	if stale_file == null:
		return _fail("stale passive source fixture could not be staged")
	var stale_bytes := JSON.stringify(stale_passive)
	stale_file.store_string(stale_bytes)
	stale_file.close()
	var stale_game = Domain.new(Registry.new(), stale_store, "slot_3")
	if stale_game.restore() or FileAccess.get_file_as_string(stale_store.v2_path) != stale_bytes:
		return _fail("stale passive definition pin was accepted or save was rewritten")
	var fellow_store = RunSession.new(
		"user://tests/normal_fellow_%d.json" % Time.get_ticks_usec(), "slot_3")
	var fellow_file := FileAccess.open(fellow_store.v2_path, FileAccess.WRITE)
	if fellow_file == null:
		return _fail("ordinary combat fixture could not be staged")
	fellow_file.store_string(bytes)
	fellow_file.close()
	var fellow = Domain.new(Registry.new(), fellow_store, "slot_3")
	_set_zero_rolls(fellow)
	fellow._normal_roll_override = 0.18
	if not fellow.restore() or not fellow.resume_flow() \
			or fellow.get_current_card().get("id") != "q_fellow" \
			or not fellow.can_choose_direction("right"):
		return _fail("ordinary combat card did not expose its source choice")
	var seeded_store = RunSession.new(
		"user://tests/normal_seeded_%d.json" % Time.get_ticks_usec(), "slot_3")
	var seeded_file := FileAccess.open(seeded_store.v2_path, FileAccess.WRITE)
	if seeded_file == null:
		return _fail("seeded normal fixture could not be staged")
	seeded_file.store_string(bytes)
	seeded_file.close()
	var seeded = Domain.new(Registry.new(), seeded_store, "slot_3")
	_set_zero_rolls(seeded)
	seeded._normal_roll_override = -1.0
	if not seeded.restore():
		return _fail("pre-normal snapshot could not be restored for seeded draw")
	seeded._normal_replay_seed = 2
	if not seeded.resume_flow() or seeded.get_current_card().get("id") != "q_market" \
			or seeded.state.get("normalFlow", {}).get("randomMode") != "seeded":
		return _fail("seeded ordinary draw was not source reproducible")
	var seeded_pending: Dictionary = seeded.state.duplicate(true)
	var seeded_bytes := FileAccess.get_file_as_string(seeded_store.v2_path)
	var seeded_reload = Domain.new(Registry.new(), seeded_store, "slot_3")
	_set_zero_rolls(seeded_reload)
	seeded_reload._normal_roll_override = -1.0
	if not seeded_reload.restore() or not _same(seeded_reload.state, seeded_pending) \
			or seeded_reload.issue_choice_token() <= 0 \
			or not seeded_reload.can_choose_direction("down"):
		return _fail("seeded ordinary draw changed across restart")
	if not seeded_reload.choose("down", seeded_reload.issue_choice_token()) \
			or seeded_reload.state.get("phase") != "FLOW_PENDING":
		return _fail("authored third-direction ordinary choice was not settled")
	var forged: Dictionary = JSON.parse_string(seeded_bytes)
	forged["state"]["normalFlow"]["draws"][0]["sourceRoll"] = 0.02
	var forged_store = RunSession.new(
		"user://tests/normal_forged_roll_%d.json" % Time.get_ticks_usec(), "slot_3")
	var forged_file := FileAccess.open(forged_store.v2_path, FileAccess.WRITE)
	if forged_file == null:
		return _fail("forged normal roll fixture could not be staged")
	var forged_bytes := JSON.stringify(forged)
	forged_file.store_string(forged_bytes)
	forged_file.close()
	var forged_game = Domain.new(Registry.new(), forged_store, "slot_3")
	_set_zero_rolls(forged_game)
	forged_game._normal_roll_override = -1.0
	if forged_game.restore() or FileAccess.get_file_as_string(forged_store.v2_path) != forged_bytes:
		return _fail("forged seeded draw roll was accepted or changed on disk")
	print("NONCOMBAT_NORMAL_RUNTIME_PASS draw=true choice=true replay=true rollback=true ui=true")
	quit(0)


func _reach_decision27(game: RefCounted) -> bool:
	return game.start("sword") and _reach_bazaar(game) \
		and game.choose("left", game.issue_choice_token()) \
		and game.perform_vendor_action("ask_luo", game.issue_choice_token()) \
		and game.close_vendor(game.issue_choice_token()) \
		and game.choose("right", game.issue_choice_token()) \
		and game.resume_flow() \
		and game.choose("right", game.issue_choice_token()) \
		and game.resume_flow() \
		and game.choose("left", game.issue_choice_token()) \
		and game.choose("left", game.issue_choice_token()) \
		and game.resume_flow() \
		and game.choose("right", game.issue_choice_token()) \
		and game.resume_flow() \
		and game.choose("left", game.issue_choice_token())


func _set_zero_rolls(game: RefCounted) -> void:
	game._market_flow.roll_override = 0.0
	game._destiny_wheel_flow.roll_override = 0.0
	game._ripple_flow.roll_override = 0.0
	game._hint_flow.roll_override = 0.0
	game._normal_roll_override = 0.0
