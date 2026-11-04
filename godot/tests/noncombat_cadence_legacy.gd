extends "res://tests/noncombat_cadence_battle.gd"


func _run() -> void:
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	var row: Dictionary = fixture.get("rows", [])[0]
	var file := "user://tests/cadence_legacy_%d.json" % Time.get_ticks_usec()
	var game = Domain.new(Registry.new(), Session.new(file, "slot_2"), "slot_2")
	_quiet_ambient(game)
	if not _open_before_offer(game, row, true) or game.state.has("encounterCadence"):
		return _fail("old unmarked prefix did not reach decision eleven")
	var prefix_ids: Array = game.state.choiceHistory.map(
		func(entry: Dictionary) -> String: return String(entry.get("cardId", "")))
	if prefix_ids.find("q_mountain_shadow_approach") < 0 \
			or prefix_ids.find("ch_qi_20") < 0 \
			or prefix_ids.find("q_mountain_shadow_approach") >= prefix_ids.find("ch_qi_20"):
		return _fail("old mountain-before-chapter history was rewritten")
	var original: Dictionary = game.state.duplicate(true)
	var original_bytes := FileAccess.get_file_as_bytes(game._store.v2_path)
	game = _cold(game, "old prefix")
	if game == null or game._cadence_activation_index != 12 \
			or not _same(game.state, original) \
			or FileAccess.get_file_as_bytes(game._store.v2_path) != original_bytes:
		return _fail("old prefix changed on strict restore")
	if not game.resume_flow() or game.state.get("phase") != "QUEST_PENDING" \
			or game.state.get("currentCardId") != "q_whiteFox_quest" \
			or game.state.has("encounterCadence") \
			or game.state.get("battleResultHistory", []).size() != 2 \
			or game.state.get("deck", []).size() != 8:
		return _fail("old presentation activated cadence or lost earned rewards")
	var before: Dictionary = game.state.duplicate(true)
	var bytes := FileAccess.get_file_as_bytes(game._store.v2_path)
	var token: int = game.issue_choice_token()
	game._store.fail_promotion_once = true
	if game.choose("right", token) or not _unchanged(game, before, bytes):
		return _fail("failed old choice activated cadence or changed save bytes")
	if not game.choose("right", token) or game.state.get("encounterCadence", {}).get(
			"activationIndex") != 12 or game.state.get("turn") != 12:
		return _fail("next committed decision did not activate cadence")
	if _cold(game, "activated old prefix") == null:
		return _fail("activated old prefix failed strict restart")
	print("NONCOMBAT_CADENCE_LEGACY_PASS old_prefix=true deferred_activation=12 atomic=true strict_reload=true")
	quit(0)
