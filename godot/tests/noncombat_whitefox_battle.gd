extends "res://tests/noncombat_battle_return.gd"

func _open_third(game: RefCounted, path_id: String) -> bool:
	if not game.start(path_id):
		return false
	for i in 5:
		if not game.choose("left", game.issue_choice_token()):
			return false
	return game.choose("right", game.issue_choice_token()) \
		and game.choose("left", game.issue_choice_token()) and game.resume_flow() \
		and game.choose("left", game.issue_choice_token()) \
		and game.choose("right", game.issue_choice_token()) and game.resume_flow() \
		and game.choose("right", game.issue_choice_token()) \
		and game.choose("left", game.issue_choice_token()) \
		and game.state.currentCardId == "q_whiteFox_3"

func _canonical_card(card: Dictionary) -> Dictionary:
	var result := card.duplicate(true)
	result.erase("_flowSource")
	result.erase("_flowPhase")
	return result

func _run() -> void:
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/whitefox_battle_source.json"))
	var games := {}
	var prior_results := {}
	var count := 0
	for row in fixture.rows:
		var game: RefCounted
		if row.has("retryOf"):
			game = games[row.retryOf]
			if game.get_current_card().get("id") != "ch_qi_60" or not game.choose("left", game.issue_choice_token()) \
					or not game.resume_flow() or game.state.currentCardId != "q_whiteFox_3":
				return _fail("nonwin current task could not resume: " + row.caseId)
		else:
			var file := "user://tests/whitefox_battle_%s_%d.json" % [row.caseId, Time.get_ticks_usec()]
			game = Domain.new(Registry.new(), Session.new(file, "slot_2"), "slot_2")
			if not _open_third(game, row.path):
				return _fail("natural third quest route failed: " + row.caseId)
		var before_warning: Dictionary = game.state.duplicate(true)
		if not game.can_choose_direction("left") or not game.choose("left", game.issue_choice_token()):
			return _fail("whitefox inline quest battle has no consumer")
		var warning: Dictionary = game.get_current_card()
		for key in ["id", "type", "title", "description", "sceneImage"]:
			if warning.get(key) != row.warning.get(key):
				return _fail("warning source differs: " + key)
		if game.state.turn != before_warning.turn or not _same(game.state.questState, before_warning.questState) \
				or not _reopens(game):
			return _fail("warning settled task early/reload failed")
		if not game.choose("left", game.issue_choice_token()):
			return _fail("inline preparation")
		var request: Dictionary = game.battle_request()
		if request.is_empty() or request.encounterId != null or request.questId != "white_fox_line" \
				or not _same(request.pendingResolution.sourceCard, _canonical_card(row.sourceCard)) \
				or not _same(request.pendingResolution.choice, row.pendingResolution.choice) \
				or not _same(request.pendingResolution.combatCard, _canonical_card(row.pendingResolution.combatCard)) \
				or not _same(request.playerSnapshot.battleLoadout.deck, before_warning.deck):
			return _fail("inline source/pending/current loadout differs")
		var restored = Domain.new(Registry.new(), Session.new(game._store.legacy_path, "slot_2"), "slot_2")
		if not restored.restore() or not _same(restored.state, game.state):
			return _fail("inline pending cold restore")
		game = restored
		var before: Dictionary = game.state.duplicate(true)
		var result := _result(request, row.outcome)
		if row.has("retryOf") and (game.submit_battle_result(prior_results[row.retryOf]) or not _same(game.state, before)):
			return _fail("old owner settled repeated quest battle")
		var bytes := FileAccess.get_file_as_bytes(game._store.v2_path)
		game._store.fail_promotion_once = true
		if game.submit_battle_result(result) or not _same(game.state, before) \
				or FileAccess.get_file_as_bytes(game._store.v2_path) != bytes:
			return _fail("task result failed-save rollback")
		if not game.submit_battle_result(result):
			return _fail("whitefox delayed settlement failed: " + game.flow_failure_reason())
		var current: Dictionary = game.get_current_card()
		if not _same(current, row.resultCard):
			for key in row.resultCard:
				if not _same(current.get(key), row.resultCard[key]):
					return _fail("result %s differs: %s / %s" % [key, current.get(key), row.resultCard[key]])
			return _fail("result extra fields")
		if not _same(game.state.questState, row.after.questState):
			return _fail("task terminal state differs: " + row.caseId)
		for group in ["attributes", "resources"]:
			for key in ["cultivation", "fortune", "karmaGood", "health", "daoHeart"] if group == "attributes" else ["spiritStone", "lifespan"]:
				if int(game.state[group][key]) - int(before[group][key]) != int(row.after[group][key]) - int(row.before[group][key]):
					return _fail("source delta mismatch: " + row.caseId + "/" + key)
		for key in ["quest_white_fox_line_active", "quest_white_fox_line_step", "white_fox_lineCompleted", "whiteFoxCompleted", "foxGratitude", "whiteFox"]:
			if game.state.flags.get(key) != row.after.flags.get(key):
				return _fail("source task flag differs: " + key)
		var seeds: Array = game.state.karmaSeeds.filter(func(s: Dictionary) -> bool: return s.id in ["whiteFox", "foxGratitude"])
		var expected_seeds: Array = row.after.karmaSeeds.filter(func(s: Dictionary) -> bool: return s.id in ["whiteFox", "foxGratitude"])
		var expected_factions: Dictionary = row.after.factionProgress.duplicate(true)
		# The browser fixture predates faction event cadence. Battle settlement
		# must preserve the live cadence while matching all sourced reputation data.
		expected_factions.ticksSinceEvent = game.state.factionProgress.ticksSinceEvent
		if not _same(seeds, expected_seeds) or row.outcome == "victory" and (
				not _same(game.state.factionProgress, expected_factions) \
				or game.state.factionProgress.ticksSinceEvent != before.factionProgress.ticksSinceEvent):
			return _fail("quest seed provenance/order/clock/factions differ")
		if not _same(game.state.noncombatFlow.encounterDirectorState, before.noncombatFlow.encounterDirectorState) \
				or game.state.turn != int(before.turn) + 1 or not _reopens(game) or game.submit_battle_result(result):
			return _fail("quest director/clock/replay/duplicate")
		var source_card_id: String = game.get_current_card().choices.left.effects.deckCard.cardId if row.outcome == "victory" else ""
		if not game.choose(row.acknowledgementDirection, game.issue_choice_token()) or not _reopens(game) \
				or not game.resume_flow() or not _reopens(game):
			return _fail("task acknowledgement/replay/continuation")
		if not source_card_id.is_empty() and not game.state.deck.has(source_card_id):
			return _fail("quest reward skill not acquired")
		if game.get_current_card().get("id") != row.nextCard.id:
			return _fail("original flow differs: %s actual=%s expected=%s" % [row.caseId, game.state.currentCardId, row.nextCard.id])
		games[row.caseId] = game
		prior_results[row.caseId] = result
		count += 1
		print("WHITEFOX_CASE_PASS " + row.caseId)
	print("NONCOMBAT_WHITEFOX_BATTLE_PASS cases=%d source=true inline=true quest=true replay=true retry=true atomic=true" % count)
	quit(0)
