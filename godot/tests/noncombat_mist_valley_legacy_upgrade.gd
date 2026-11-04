extends "res://tests/noncombat_cave_entry.gd"

func _run() -> void:
	var path := "user://tests/mist_legacy_%d.json" % Time.get_ticks_usec()
	var store = RunSession.new(path, "slot_3")
	var old = Domain.new(Registry.new(), store, "slot_3")
	_set_zero_rolls(old)
	old._story_thread_flow.mist_activation_index = 100
	if not _reach_decision27(old):
		return _fail("old four-thread route did not reach the cave draw")
	old._normal_roll_override = CAVE_ROLL
	if not old.resume_flow() or old.get_current_card().get("id") != "q_cave" \
			or not old.choose("right", old.issue_choice_token()):
		return _fail("old four-thread route did not enter cave")
	for id in ["cave_spirit", "cave_beast", "cave_reward"]:
		if old.state.get("phase") == "DESTINY_WHEEL_PENDING" and not old.choose(
				"left", old.issue_choice_token()):
			return _fail("old cave destiny wheel did not settle")
		if old.get_current_card().get("id") != id or not old.choose(
				"left", old.issue_choice_token()):
			return _fail("old cave completion failed: " + id)
	var saved: Dictionary = old.state.duplicate(true)
	var bundle: Dictionary = saved.get("storyThreadState", {})
	if saved.get("dungeonOutcomeReceipts", [])[0].get("outcome") != "success" \
			or bundle.has("mistActivationIndex") \
			or bundle.get("threads", {}).has("mist_valley"):
		return _fail("fixture did not represent a four-thread pre-mist save")
	var bytes := FileAccess.get_file_as_bytes(store.v2_path)
	var loaded = Domain.new(Registry.new(), RunSession.new(path, "slot_3"), "slot_3")
	_set_zero_rolls(loaded)
	loaded._normal_roll_override = CAVE_ROLL
	if not loaded.restore() or not _same(loaded.state, saved) \
			or FileAccess.get_file_as_bytes(store.v2_path) != bytes:
		return _fail("pre-mist save changed on read or failed replay")
	if not loaded.resume_flow():
		return _fail("pre-mist save could not resume next decision")
	var direction := ""
	for possible in ["left", "right", "down"]:
		if loaded.can_choose_direction(possible):
			direction = possible
			break
	if direction.is_empty() or not loaded.choose(direction,
			loaded.issue_choice_token()):
		return _fail("pre-mist save could not commit its next decision")
	var upgraded: Dictionary = loaded.state.get("storyThreadState", {})
	if upgraded.get("mistActivationIndex") != loaded.state.get(
			"runClock", {}).get("decisionIndex") \
			or upgraded.get("threads", {}).get("mist_valley", {}).get(
				"status") != "inactive":
		return _fail("mist activated retroactively from old cave success")
	if not _reopen(loaded):
		return _fail("upgraded pre-mist save failed strict replay")
	print("NONCOMBAT_MIST_VALLEY_LEGACY_UPGRADE_PASS old_v2=true delayed_activation=true replay=true")
	quit(0)
