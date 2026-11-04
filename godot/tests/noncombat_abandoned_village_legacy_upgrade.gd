extends "res://tests/noncombat_normal_runtime.gd"

func _run() -> void:
	var path := "user://tests/abandoned_village_legacy_%d.json" % Time.get_ticks_usec()
	var store = RunSession.new(path, "slot_3")
	var old = Domain.new(Registry.new(), store, "slot_3")
	_set_zero_rolls(old)
	old._story_thread_flow.village_activation_index = 100
	old._story_thread_flow.sword_activation_index = 100
	old._story_thread_flow.mist_activation_index = 100
	if not old.start("sword") or not old.choose("left", old.issue_choice_token()):
		return _fail("older two-thread save could not be produced")
	var saved: Dictionary = old.state.duplicate(true)
	var bundle: Dictionary = saved.get("storyThreadState", {})
	if bundle.get("version") != 2 or bundle.has("villageActivationIndex") \
			or bundle.get("threads", {}).has("abandoned_village") \
			or bundle.has("swordActivationIndex") or bundle.has("mistActivationIndex") \
			or bundle.get("threads", {}).has("sword_tomb_trial"):
		return _fail("fixture did not represent a two-thread v2 save")
	var bytes := FileAccess.get_file_as_bytes(store.v2_path)
	var loaded = Domain.new(Registry.new(), RunSession.new(path, "slot_3"), "slot_3")
	_set_zero_rolls(loaded)
	if not loaded.restore() or not _same(loaded.state, saved) \
			or FileAccess.get_file_as_bytes(store.v2_path) != bytes:
		return _fail("older two-thread v2 save changed on read")
	if not loaded.choose("left", loaded.issue_choice_token()):
		return _fail("older two-thread v2 save could not continue")
	var upgraded: Dictionary = loaded.state.get("storyThreadState", {})
	if upgraded.get("villageActivationIndex") != loaded.state.get("runClock", {}).get("decisionIndex") \
			or upgraded.get("threads", {}).get("abandoned_village", {}).get("status") != "inactive":
		return _fail("new village rule activated before the next old-save decision")
	var reopened = Domain.new(Registry.new(), RunSession.new(path, "slot_3"), "slot_3")
	_set_zero_rolls(reopened)
	if not reopened.restore() or not _same(reopened.state, loaded.state):
		return _fail("upgraded two-thread v2 save failed strict replay")
	print("NONCOMBAT_ABANDONED_VILLAGE_LEGACY_UPGRADE_PASS old_v2=true delayed_activation=true replay=true")
	quit(0)
