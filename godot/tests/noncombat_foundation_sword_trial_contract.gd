extends SceneTree

const Domain = preload("res://scripts/noncombat_domain.gd")
const Registry = preload("res://scripts/runtime_data_registry.gd")
const Session = preload("res://scripts/noncombat_run_session.gd")
const FIXTURE := "res://tests/fixtures/foundation_sword_q3_heart_v2.json"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	if fixture.get("state", {}).get("phase") != "QUEST_PENDING" \
			or fixture.get("state", {}).get("currentCardId") != "q_sword_3" \
			or fixture.get("state", {}).get("questState", {}).get("activeQuests", [])[0].get("step") != 2:
		return _fail("natural q3 fixture does not describe an active trial")
	for direction in ["left", "right"]:
		var path := "user://tests/foundation_sword_trial_%s_%d.json" % [
			direction, Time.get_ticks_usec()]
		var store = Session.new(path, "slot_2")
		var copied := FileAccess.open(store.v2_path, FileAccess.WRITE)
		copied.store_buffer(FileAccess.get_file_as_bytes(FIXTURE))
		copied.close()
		var game = Domain.new(Registry.new(), store, "slot_2")
		game._ripple_flow.roll_override = 0.999
		game._hint_flow.roll_override = 0.0
		game._market_flow.roll_override = 0.0
		if not game.restore() or game.get_current_card().get("id") != "q_sword_3":
			return _fail("natural q3 fixture failed strict public restore: " +
				JSON.stringify({"store": store.last_error,
					"flow": game.flow_failure_reason(),
					"quest": game._quest_flow.last_error,
					"faction": game._faction_events.last_error,
					"legacyQiSpine": game._legacy_qi_spine_victory(
						store.load_snapshot().get("state", {})),
					"phase": game.state.get("phase"),
					"card": game.get_current_card().get("id")}))
		var before: Dictionary = game.state.duplicate(true)
		if not game.choose(direction, game.issue_choice_token()) \
				or game.state.get("phase") != "WARNING_PENDING":
			return _fail("sword trial did not issue the source warning: " + direction)
		var warning: Dictionary = game.get_current_card()
		var source: Dictionary = game._content.read_module("quests:sword_legacy")
		var choice: Dictionary = source.cards[2].choices[direction]
		if warning.get("id") != "_warning_q_sword_3" \
				or warning.get("sceneImage") != choice.combatPresentation.sceneImage \
				or not warning.get("description", "").contains("战败伤势"):
			return _fail("sword trial warning does not match source direction")
		var reopen = Domain.new(Registry.new(), Session.new(path, "slot_2"), "slot_2")
		reopen._ripple_flow.roll_override = 0.999
		reopen._hint_flow.roll_override = 0.0
		reopen._market_flow.roll_override = 0.0
		if not reopen.restore() or not _same(reopen.state, game.state):
			return _fail("sword trial warning did not strictly reload")
		if not reopen.choose("left", reopen.issue_choice_token()):
			return _fail("sword trial warning could not confirm the battle")
		var request: Dictionary = reopen.battle_request()
		if request.get("sourceCardId") != "q_sword_3" \
				or request.get("direction") != direction \
				or request.get("questId") != "sword_legacy" \
				or request.get("presentationId") != choice.combatPresentation.presentationId \
				or request.get("playerSnapshot", {}).get("battleLoadout", {}).get("deck") != before.deck:
			return _fail("sword trial request lost source choice or current deck")
		if reopen.choose("left", reopen.issue_choice_token()):
			return _fail("sword trial allowed a duplicate warning confirmation")
	print("NONCOMBAT_FOUNDATION_SWORD_TRIAL_CONTRACT_PASS directions=2 replay=true")
	quit(0)


func _same(a: Variant, b: Variant) -> bool:
	return JSON.parse_string(JSON.stringify(a)) == JSON.parse_string(JSON.stringify(b))


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
