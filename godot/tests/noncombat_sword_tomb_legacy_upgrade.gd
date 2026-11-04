extends "res://tests/noncombat_normal_runtime.gd"

func _run() -> void:
	var path := "user://tests/sword_tomb_legacy_%d.json" % Time.get_ticks_usec()
	var store = RunSession.new(path, "slot_3")
	var old = Domain.new(Registry.new(), store, "slot_3")
	_set_zero_rolls(old)
	old._story_thread_flow.sword_activation_index = 100
	old._story_thread_flow.mist_activation_index = 100
	if not _reach_decision27(old):
		return _fail("older three-thread ordinary route failed")
	old._normal_roll_override = 0.46
	if not old.resume_flow() or old.get_current_card().get("id") != "q_swordTomb" \
			or not old.choose("left", old.issue_choice_token()):
		return _fail("older three-thread save could not record sword tomb choice")
	var saved: Dictionary = old.state.duplicate(true)
	var bundle: Dictionary = saved.get("storyThreadState", {})
	if bundle.get("version") != 2 or not bundle.has("villageActivationIndex") \
			or bundle.has("swordActivationIndex") or bundle.has("mistActivationIndex") \
			or bundle.get("threads", {}).has("sword_tomb_trial"):
		return _fail("fixture did not represent an older three-thread v2 save")
	var bytes := FileAccess.get_file_as_bytes(store.v2_path)
	var loaded = Domain.new(Registry.new(), RunSession.new(path, "slot_3"), "slot_3")
	_set_zero_rolls(loaded)
	loaded._normal_roll_override = 0.46
	if not loaded.restore() or not _same_value(loaded.state, saved) \
			or FileAccess.get_file_as_bytes(store.v2_path) != bytes:
		return _fail("older three-thread v2 save changed on read")
	if not loaded.resume_flow():
		return _fail("older three-thread save could not resume its next decision")
	var direction := "left" if loaded.can_choose_direction("left") else "right"
	if not loaded.choose(direction, loaded.issue_choice_token()):
		return _fail("older three-thread v2 save could not continue")
	var upgraded: Dictionary = loaded.state.get("storyThreadState", {})
	if upgraded.get("swordActivationIndex") != loaded.state.get("runClock", {}).get(
			"decisionIndex") or upgraded.get("threads", {}).get(
				"sword_tomb_trial", {}).get("status") != "inactive":
		return _fail("new sword thread activated from an old completed choice: %s/%s" % [
			upgraded.get("swordActivationIndex"), upgraded.get("threads", {}).get(
				"sword_tomb_trial", {}).get("status")])
	var reopened = Domain.new(Registry.new(), RunSession.new(path, "slot_3"), "slot_3")
	_set_zero_rolls(reopened)
	reopened._normal_roll_override = 0.46
	if not reopened.restore() or not _same_value(reopened.state, loaded.state):
		return _fail("upgraded three-thread v2 save failed strict replay")
	print("NONCOMBAT_SWORD_TOMB_LEGACY_UPGRADE_PASS old_v2=true delayed_activation=true replay=true")
	quit(0)


func _same_value(left: Variant, right: Variant) -> bool:
	return JSON.parse_string(JSON.stringify(left)) == JSON.parse_string(JSON.stringify(right))
