extends "res://tests/noncombat_battle_return.gd"

const CADENCE_ID := "encounter_card_enc_patrol_qi_mountain_shadow"
const FIXTURE := "res://tests/fixtures/cadence_battle_source.json"
var _problem := ""
var _prior_results: Array = []


func _run() -> void:
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	if fixture.get("realCombat") != true or fixture.get("publicInput") != true \
			or fixture.get("rows", []).size() != 4:
		return _fail("cadence production source matrix missing")
	for source in fixture.pins:
		var actual := FileAccess.get_sha256(ProjectSettings.globalize_path("res://").path_join("../" + source))
		if actual != fixture.pins[source]:
			return _fail("cadence source oracle drift: " + source)
	for row in fixture.rows:
		if not _case(row):
			return _fail(row.caseId + ": " + _problem)
		print("CADENCE_BATTLE_CASE_PASS " + row.caseId)
	print("NONCOMBAT_CADENCE_BATTLE_PASS cases=4 source=true natural=true deck_sizes=6,7,8,9 cumulative=true warning_reload=true pending_reload=true result_reload=true acknowledgement_reload=true atomic=true owner=true duplicate=true activation_index=0")
	quit(0)


func _case(row: Dictionary) -> bool:
	var file := "user://tests/cadence_battle_%s_%d.json" % [row.caseId, Time.get_ticks_usec()]
	var game = Domain.new(Registry.new(), Session.new(file, "slot_2"), "slot_2")
	_quiet_ambient(game)
	if not _open_before_offer(game, row):
		return false
	if not _snapshot(game.state, row.beforeOffer, "before offer"):
		return false
	# Failed presentation must leave pending/history/decision/RNG state intact.
	if not _failed_flow(game) or not game.resume_flow():
		return _bad("cadence presentation/failed-save retry: " + game.flow_failure_reason())
	if game.state.phase != "COMBAT_HANDOFF" or game.state.currentCardId != CADENCE_ID \
			or not game.state.get("pendingCadenceCard") is Dictionary:
		return _bad("cadence producer has no persisted handoff")
	if not _expect(_canonical(game.get_current_card()), _canonical(row.sourceCard), "offered card") \
			or not _snapshot(game.state, row.offered, "offered"):
		return false
	game = _cold(game, "offered")
	var invitation_direction: String = String(row.get("direction", row.get("sourceDirection", "")))
	if game == null or not _failed_choice(game, invitation_direction):
		return false
	if not game.choose(invitation_direction, game.issue_choice_token()):
		return _bad("cadence source choice: " + game.flow_failure_reason())
	if row.outcome == "avoided":
		if game.state.battleResultHistory.size() != 2 or not game.battle_request().is_empty() \
				or game.state.has("pendingCadenceCard"):
			return _bad("avoid produced battle/reward or retained cadence owner")
		game = _cold(game, "avoid commit")
		if game == null or not game.resume_flow():
			return _bad("avoid continuation/reload")
		if not _snapshot(game.state, row.after, "avoid after") \
				or not _expect(_canonical(game.get_current_card()), _canonical(row.nextCard), "avoid next card"):
			return false
		return _cold(game, "avoid continuation") != null
	if not _snapshot(game.state, row.afterChoice, "warning state") \
			or not _expect(game.get_current_card(), _warning_projection(row.warning), "warning card"):
		return false
	if game.state.phase != "WARNING_PENDING" or game.state.turn != 11:
		return _bad("acceptance advanced source decision before combat")
	game = _cold(game, "warning")
	if game == null or not _failed_choice(game, "left"):
		return false
	if not game.choose("left", game.issue_choice_token()):
		return _bad("warning preparation")
	var request: Dictionary = game.battle_request()
	if request.is_empty():
		return _bad("third battle request missing")
	if not _request(request, row) or not _snapshot(game.state, row.afterWarning, "pending battle") \
			or not _preparation(game.state, row):
		return false
	game = _cold(game, "pending battle")
	if game == null or not _expect(game.battle_request(), request, "restored request"):
		return false
	var before: Dictionary = game.state.duplicate(true)
	var bytes := FileAccess.get_file_as_bytes(game._store.v2_path)
	var result := _result(request, row.outcome)
	for old_result in _prior_results:
		if game.submit_battle_result(old_result) or not _unchanged(game, before, bytes):
			return _bad("previous battle receipt took third encounter ownership")
	for field in ["encounterInstanceId", "sourceCardId", "sourceContentHash"]:
		var wrong := result.duplicate(true)
		wrong[field] = "foreign"
		if game.submit_battle_result(wrong) or not _unchanged(game, before, bytes):
			return _bad("foreign terminal changed pending third encounter: " + field)
	game._store.fail_promotion_once = true
	if game.submit_battle_result(result) or not _unchanged(game, before, bytes):
		return _bad("terminal save failure leaked state, director or bytes")
	if not game.submit_battle_result(result):
		return _bad("third result rejected: " + game.flow_failure_reason())
	if not _snapshot(game.state, row.after, "terminal") \
			or not _expect(game.get_current_card(), row.resultCard, "result card") \
			or not _expect(game.state.noncombatFlow.encounterDirectorState, row.directorAfter, "terminal director"):
		return false
	if game.state.battleResultHistory.size() != 3 or game.state.has("pendingCadenceCard"):
		return _bad("terminal lost accumulated receipts or retained owner")
	var receipts: Array = game.state.battleResultHistory
	for index in 2:
		if not _expect(receipts[index].result, _prior_results[index], "prior terminal receipt"):
			return false
	game = _cold(game, "result")
	if game == null:
		return false
	before = game.state.duplicate(true)
	bytes = FileAccess.get_file_as_bytes(game._store.v2_path)
	if game.submit_battle_result(result) or not _unchanged(game, before, bytes):
		return _bad("duplicate terminal changed committed result")
	if not _failed_choice(game, row.acknowledgementDirection) \
			or not game.choose(row.acknowledgementDirection, game.issue_choice_token()):
		return _bad("result acknowledgement/failed-save retry")
	if game.state.phase != "FLOW_PENDING":
		return _bad("result acknowledgement did not return flow ownership")
	game = _cold(game, "acknowledgement")
	if game == null or not game.resume_flow():
		return _bad("acknowledgement continuation")
	if not _snapshot(game.state, row.afterAcknowledgement, "after acknowledgement") \
			or not _expect(_canonical(game.get_current_card()), _canonical(row.nextCard), "next card"):
		return false
	var expected_deck_size := 9 if row.outcome == "victory" else 8
	if game.state.deck.size() != expected_deck_size \
			or not _expect(game.state.battleLoadout.deck, row.afterAcknowledgement.deck, "reward loadout"):
		return _bad("third reward/current loadout differs")
	return _cold(game, "continuation") != null


func _open_before_offer(game: RefCounted, row: Dictionary, legacy: bool = false) -> bool:
	_prior_results.clear()
	if not game.start("sword"):
		return _bad("natural opening")
	if legacy:
		# Replay a pre-N5f prefix through public decisions without a cadence
		# marker. The strict loader derives its activation from the saved clock.
		game.state.erase("encounterCadence")
		game._cadence_activation_index = 100000
	var marker: Dictionary = game.state.get("encounterCadence", {})
	if not legacy:
		if not _expect(marker.get("version"), 1, "new cadence marker/version") \
				or not _expect(marker.get("activationIndex"), 0, "new cadence marker/activationIndex"):
			return false
	for direction in ["right", "right", "left", "left", "left"]:
		if not game.choose(direction, game.issue_choice_token()):
			return _bad("natural teaching entry")
	for step in 25:
		if game.state.turn == 11 and game.state.phase == "FLOW_PENDING":
			return _prior_results.size() == 2 and game.state.deck.size() == 8
		match String(game.state.phase):
			"BATTLE_PENDING":
				var request: Dictionary = game.battle_request()
				var index := _prior_results.size()
				if index >= 2 or not _expect(request.playerSnapshot.battleLoadout.deck,
						row.rawDeckHistory[index].deck, "prefix raw deck %d" % index) \
						or request.sourceCardId != row.rawDeckHistory[index].sourceCardId:
					return _bad("two battle prefix current deck/source")
				var result := _result(request, "victory")
				if not game.submit_battle_result(result):
					return _bad("prefix victory")
				_prior_results.append(result)
			"FLOW_PENDING":
				if not game.resume_flow():
					return _bad("prefix continuation: " + game.flow_failure_reason())
			"FIRST_SESSION_ROUTE_PENDING", "WARNING_PENDING", "BATTLE_RESULT_PENDING", "MILESTONE_PENDING":
				if not game.choose("left", game.issue_choice_token()):
					return _bad("prefix choice: " + str(game.state.currentCardId))
			_:
				return _bad("prefix stopped: " + str(game.state.phase) + "/" + str(game.state.currentCardId))
	return _bad("natural prefix did not reach decision eleven")


func _request(request: Dictionary, row: Dictionary) -> bool:
	var resolution: Dictionary = request.pendingResolution.duplicate(true)
	if not _expect(resolution.get("sourceCardId"), row.sourceCard.id, "resolution source metadata"):
		return false
	resolution.erase("sourceCardId")
	return _expect(request.sourceCardId, row.sourceCard.id, "request source ID") \
		and _expect(request.encounterId, row.sourceCard.encounterId, "request encounter ID") \
		and _expect(_canonical(resolution), _canonical(row.pendingResolution), "pending resolution") \
		and _expect(request.playerSnapshot.battleLoadout.deck, row.rawDeckHistory[2].deck, "third current deck") \
		and _expect(request.playerSnapshot.get("knowledge", {}), row.before.knowledge, "request knowledge") \
		and _expect(request.playerSnapshot.get("modifiers", {}), row.before.modifiers, "request modifiers")


func _warning_projection(source: Dictionary) -> Dictionary:
	# Warning UI carries presentation; pendingResolution and the preparation
	# receipt carry _targetCombatCard/encounterContext/choice execution in Godot.
	var result := {}
	for key in ["id", "type", "title", "description", "sceneImage"]:
		result[key] = source[key]
	result.choices = {}
	for direction in source.choices:
		result.choices[direction] = {"text": source.choices[direction].text,
			"desc": source.choices[direction].desc}
	return result


func _preparation(state: Dictionary, row: Dictionary) -> bool:
	var receipts: Array = state.runClock.get("preparationReceipts", {}).values().filter(
		func(receipt: Dictionary) -> bool: return receipt.sourceCardId == CADENCE_ID)
	return _expect(receipts, [{"sourceCardId": CADENCE_ID, "direction": "left",
		"baseDecisionIndex": row.before.turn, "applied": true,
		"beforeSpiritStone": row.afterChoice.resources.spiritStone,
		"afterSpiritStone": row.afterWarning.resources.spiritStone,
		"beforeHealth": row.afterChoice.attributes.health,
		"afterHealth": row.afterWarning.attributes.health}], "warning preparation receipt")


func _snapshot(actual: Dictionary, source: Dictionary, label: String) -> bool:
	# World-pulse/StoryNetwork/rendering internals remain outside this slice.
	for key in ["turn", "attributes", "resources", "maxHealth", "maxDaoHeart",
			"knowledge", "modifiers", "deck", "skillAcquisitions", "deckOperations",
			"karmaSeeds", "cardsPlayed", "questState"]:
		var value: Variant = actual.get(key, {}) if key == "modifiers" else (
			actual.get(key, {"saveVersion": 3, "activeQuests": [],
				"completedQuests": [], "closedQuests": [], "questOutcomes": {}})
			if key == "questState" else actual.get(key))
		if not _expect(value, source.get(key), label + "/" + key):
			return false
	# Browser flags are split across Godot's promise ledger, choice history and
	# quest state. Keep checking their effects without requiring duplicate storage.
	for key in source.get("flags", {}):
		if String(key).begins_with("causal:"):
			if not _expect(actual.get("karmaPromiseFlags", {}).get(key),
					source.flags[key], label + "/flag/" + key):
				return false
		elif String(key).begins_with("choice:"):
			var parts: PackedStringArray = String(key).split(":")
			var seen: bool = actual.get("choiceHistory", []).any(
				func(entry: Dictionary) -> bool:
					return entry.get("cardId") == parts[1] and entry.get("direction") == parts[2])
			if not _expect(seen, source.flags[key], label + "/flag/" + key):
				return false
		elif key not in ["quest_white_fox_line_active", "quest_white_fox_line_step"]:
			return _bad("unmapped source flag: " + String(key))
	return _battle_receipts(actual, label) \
		and _expect(_history_projection(actual.choiceHistory), source.choiceHistory, label + "/choiceHistory") \
		and _expect(actual.get("currentLocation"), source.location, label + "/location") \
		and _expect(actual.get("dead", false), source.dead, label + "/dead") \
		and _expect(actual.get("lifePhase", "ALIVE"), source.lifePhase, label + "/lifePhase") \
		and _expect(actual.noncombatFlow.encounterDirectorState, source.director, label + "/director") \
		and _expect(actual.runClock.decisionIndex, source.runClock.decisionIndex, label + "/decisionIndex") \
		and _expect(_clock_receipts(actual.runClock), _clock_receipts(source.runClock), label + "/receipts")


func _clock_receipts(clock: Dictionary) -> Array:
	# Source uses slot_1, this isolated test uses slot_2. Token ownership is
	# covered by strict reload and foreign/previous result rejection above.
	var receipts: Array = []
	for row in clock.receipts.values():
		if not row.has("kind"):
			continue
		receipts.append({"decisionIndex": row.decisionIndex,
			"sourceCardId": row.sourceCardId, "kind": row.kind})
	receipts.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		return int(left.decisionIndex) < int(right.decisionIndex))
	return receipts


func _battle_receipts(state: Dictionary, label: String) -> bool:
	# Godot's v2 protocol adds a battle ownership receipt and outcome metadata
	# alongside the source decision ledger. Validate them before projecting.
	for record in state.battleResultHistory:
		var result: Dictionary = record.result
		var receipt: Variant = state.runClock.receipts.get("battle:" + result.encounterInstanceId)
		if not _expect(receipt, {"outcome": result.outcome,
				"decisionIndex": record.decisionIndex, "sourceCardId": result.sourceCardId,
				"defeatHealthLoss": record.defeatHealthLoss}, label + "/battle owner receipt"):
			return false
		var entries: Array = state.choiceHistory.filter(func(entry: Dictionary) -> bool:
			return entry.decisionIndex == record.decisionIndex)
		if entries.size() != 1 or entries[0].get("combatOutcome") != result.outcome:
			return _bad(label + "/battle history outcome metadata")
	return true


func _history_projection(history: Array) -> Array:
	var result := history.duplicate(true)
	for entry in result:
		entry.erase("combatOutcome")
	return result


func _canonical(value: Variant) -> Variant:
	# Browser FlowDirector decorations are transient, never authored card data.
	if value is Dictionary:
		var result := {}
		for key in value:
			if key not in ["_flowSource", "_flowPhase"]:
				result[key] = _canonical(value[key])
		return result
	if value is Array:
		return value.map(_canonical)
	return value


func _failed_choice(game: RefCounted, direction: String) -> bool:
	var before: Dictionary = game.state.duplicate(true)
	var bytes := FileAccess.get_file_as_bytes(game._store.v2_path)
	var token: int = game.issue_choice_token()
	game._store.fail_promotion_once = true
	if game.choose(direction, token) or not _unchanged(game, before, bytes):
		return _bad("choice promotion failure leaked: " + str(before.phase))
	return true


func _failed_flow(game: RefCounted) -> bool:
	var before: Dictionary = game.state.duplicate(true)
	var bytes := FileAccess.get_file_as_bytes(game._store.v2_path)
	game._store.fail_promotion_once = true
	return not game.resume_flow() and _unchanged(game, before, bytes)


func _unchanged(game: RefCounted, before: Dictionary, bytes: PackedByteArray) -> bool:
	return _same(game.state, before) and FileAccess.get_file_as_bytes(game._store.v2_path) == bytes


func _cold(game: RefCounted, label: String) -> RefCounted:
	var next = Domain.new(Registry.new(), Session.new(game._store.legacy_path, "slot_2"), "slot_2")
	_quiet_ambient(next)
	if not next.restore() or not _expect(next.state, game.state, label + "/strict reload"):
		_bad(label + " cold restore: " + next._store.last_error)
		return null
	_quiet_ambient(next)
	return next


func _quiet_ambient(game: RefCounted) -> void:
	# Same deterministic ambient controls as the natural entry test. No card,
	# turn, deck, health, reward or terminal state is injected into the domain.
	game._ripple_flow.roll_override = 0.999
	game._hint_flow.roll_override = 0.0
	game._market_flow.roll_override = 0.0


func _expect(actual: Variant, expected: Variant, label: String) -> bool:
	var difference := _difference(JSON.parse_string(JSON.stringify(actual)),
		JSON.parse_string(JSON.stringify(expected)), label)
	return true if difference.is_empty() else _bad(difference)


func _difference(actual: Variant, expected: Variant, path: String) -> String:
	if actual is Dictionary and expected is Dictionary:
		for key in expected:
			if not actual.has(key):
				return path + "/" + str(key) + " missing"
			var child := _difference(actual[key], expected[key], path + "/" + str(key))
			if not child.is_empty():
				return child
		for key in actual:
			if not expected.has(key):
				return path + "/" + str(key) + " extra"
		return ""
	if actual is Array and expected is Array:
		if actual.size() != expected.size():
			return "%s length actual=%d expected=%d" % [path, actual.size(), expected.size()]
		for index in actual.size():
			var child := _difference(actual[index], expected[index], path + "/" + str(index))
			if not child.is_empty():
				return child
		return ""
	return "" if actual == expected else "%s actual=%s expected=%s" % [path, str(actual), str(expected)]


func _bad(message: String) -> bool:
	_problem = message
	return false
