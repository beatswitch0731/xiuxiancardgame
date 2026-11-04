extends "res://tests/noncombat_qi_gate_outcomes.gd"


func _run() -> void:
	var first: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	var second: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SECOND_FIXTURE))
	var third: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(THIRD_FIXTURE))
	var file := "user://tests/boss_fragment_cold_%d.json" % Time.get_ticks_usec()
	var game = Domain.new(Registry.new(), Session.new(file, "slot_2"), "slot_2")
	_quiet_ambient(game)
	if not _open_third_alt(game, first, second, third) or not _reach_gate(game) \
			or not game.choose("left", game.issue_choice_token()):
		return _fail("public qi gate route: " + _problem)
	var request: Dictionary = game.battle_request()
	if not game.submit_battle_result(_result(request, "victory")):
		return _fail("authenticated qi boss victory")
	var pending: Variant = game.state.get("legacyRunState", {}).get(
		"pendingBossFragmentReward")
	if not pending is Dictionary or pending.get("encounterKind") != "realm_boss" \
			or pending.get("encounterInstanceId") != request.encounterInstanceId \
			or game.boss_fragment_options().size() != 3:
		return _fail("natural gate victory did not create boss fragment choices")
	# A pre-reward-rule save may already be on this exact result card. Its
	# previous victory must not gain a new pending choice during strict replay.
	var legacy_path := "user://tests/boss_fragment_legacy_result_%d.json" % Time.get_ticks_usec()
	var legacy_store = Session.new(legacy_path, "slot_2")
	var legacy_envelope: Dictionary = JSON.parse_string(
		FileAccess.get_file_as_string(game._store.v2_path))
	legacy_envelope.state.erase("bossRewardActivationIndex")
	legacy_envelope.state.legacyRunState.pendingBossFragmentReward = null
	var legacy_file := FileAccess.open(legacy_store.v2_path, FileAccess.WRITE)
	legacy_file.store_string(JSON.stringify(legacy_envelope))
	legacy_file.close()
	var legacy_game = Domain.new(Registry.new(), legacy_store, "slot_2")
	_quiet_ambient(legacy_game)
	if not legacy_game.restore() or legacy_game.state.legacyRunState.pendingBossFragmentReward != null:
		return _fail("legacy result-card victory gained a reward during strict replay")
	game = _cold(game, "boss fragment pending")
	if game == null or game.boss_fragment_options().size() != 3:
		return _fail("pending choice did not survive strict cold read: " + _problem)
	var selected := String(game.boss_fragment_options()[0].setId)
	var count := int(game.state.legacyArchive.fragmentsBySet[selected])
	var prior: Dictionary = game.state.duplicate(true)
	var bytes := FileAccess.get_file_as_string(game._store.v2_path)
	game._store.fail_promotion_once = true
	if game.claim_boss_fragment(selected) or game.state != prior \
			or FileAccess.get_file_as_string(game._store.v2_path) != bytes:
		return _fail("failed claim wrote a partial fragment")
	if not game.claim_boss_fragment(selected) \
			or int(game.state.legacyArchive.fragmentsBySet[selected]) != count + 1 \
			or game.state.legacyRunState.pendingBossFragmentReward != null:
		return _fail("retry did not claim one fragment")
	game = _cold(game, "boss fragment claimed")
	if game == null or game.claim_boss_fragment(selected) \
			or not game.state.legacyRunState.claimedEncounterInstanceIds.has(
				request.encounterInstanceId):
		return _fail("claimed boss reward did not survive strict cold read: " + _problem)
	if not game.choose("left", game.issue_choice_token()):
		return _fail("battle result could not continue after fragment claim")
	game = _cold(game, "post-claim next decision")
	if game == null:
		return _fail("post-claim decision could not replay: " + _problem)
	print("NONCOMBAT_BOSS_FRAGMENT_COLD_PASS public=true pending=true claim=true rollback=true replay=true")
	quit(0)
