extends SceneTree

const Registry = preload("res://scripts/runtime_data_registry.gd")
const Domain = preload("res://scripts/noncombat_domain.gd")
const FactionEvents = preload("res://scripts/noncombat_faction_events.gd")
const Session = preload("res://scripts/noncombat_run_session.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var game = Domain.new(Registry.new())
	if not game.start("spell"):
		return _fail("could not start source-backed faction test run")
	var flow = FactionEvents.new()
	var candidate: Dictionary = game.state.duplicate(true)
	if not flow.valid(candidate) or int(candidate.factionProgress.ticksSinceEvent) != 0:
		return _fail("new run did not initialize faction progress and source pin")
	candidate.phase = "FLOW_PENDING"
	candidate.currentCardId = ""
	candidate.realm = "foundation"
	candidate.currentLocation = "坊市"
	for index in range(14):
		candidate = flow.collect(candidate)
		if candidate.is_empty() or candidate.has("pendingFactionCard"):
			return _fail("faction event appeared before source cadence")
	candidate = flow.collect(candidate)
	if candidate.get("pendingFactionCard", {}).get("id") != "faction_spell_0" \
			or int(candidate.factionProgress.ticksSinceEvent) != 0:
		return _fail("source-eligible faction event was not scheduled")
	var pending := flow.take(candidate)
	if pending.get("phase") != "FACTION_PENDING" \
			or flow.card(pending).get("id") != "faction_spell_0" \
			or not flow.choice_available(pending, "left"):
		return _fail("faction event did not become a source-verified choice")
	var settled := flow.settle(pending, "left")
	if settled.is_empty() or settled.get("phase") != "FLOW_PENDING" \
			or int(settled.factionProgress.reputations.tianshu_academy) != 5 \
			or int(settled.factionProgress.undercurrentStages.tianshu_forbidden) != 2 \
			or not settled.cardsPlayed.has("faction_spell_0") \
			or not settled.karmaSeeds.any(func(seed: Variant) -> bool:
				return seed is Dictionary and seed.get("id") == "factionUprising"):
		return _fail("faction choice did not settle reputation, stage, or karma")
	var invitation := flow.source_card(candidate, "faction_wumeng_gatekeeper_call")
	if invitation.get("sceneImage") != "assets/cards/events/scene_wumeng_gate_approach_agc_v1.png" \
			or invitation.get("choices", {}).get("left", {}).get(
				"combatEncounterId") != "enc_faction_wumeng_elite":
		return _fail("faction combat invitation did not retain authored source")
	var sect_alias := candidate.duplicate(true)
	sect_alias.erase("pendingFactionCard")
	sect_alias.path = "body"
	sect_alias.currentLocation = "剑崖"
	sect_alias.cardsPlayed.append("faction_body_0")
	sect_alias.factionProgress.ticksSinceEvent = 14
	var sect_collected := flow.collect(sect_alias)
	if sect_collected.get("pendingFactionCard", {}).get("id") != \
			"faction_wumeng_gatekeeper_call" \
			or flow.take(sect_collected).get("phase") != "FACTION_PENDING":
		return _fail("source sect landmark compatibility did not preserve invitation")
	var departed := sect_collected.duplicate(true)
	departed.currentLocation = "坊市"
	if flow.take(departed).has("pendingFactionCard"):
		return _fail("location invitation survived departure from authored region")
	var invalid: Dictionary = candidate.duplicate(true)
	invalid.factionEventState.sourceSha = "0".repeat(64)
	if flow.valid(invalid):
		return _fail("faction source drift was accepted")
	var path := "user://tests/faction_old_%d.json" % Time.get_ticks_usec()
	var session = Session.new(path, "slot_1")
	var live = Domain.new(Registry.new(), session, "slot_1")
	if not live.start("spell"):
		return _fail("faction old-save fixture could not start")
	for direction in ["right", "left", "right"]:
		if not live.choose(direction, live.issue_choice_token()):
			return _fail("faction old-save fixture opening failed")
	var old: Dictionary = live.state.duplicate(true)
	old.erase("factionEventState")
	old.erase("factionProgress")
	if session.commit_snapshot(old, live._store_revision).get("ok") != true:
		return _fail("faction old-save fixture could not commit")
	var old_bytes := FileAccess.get_file_as_string(session.v2_path)
	var restored = Domain.new(Registry.new(), Session.new(path, "slot_1"), "slot_1")
	if not restored.restore() or restored.state.has("factionEventState") \
			or FileAccess.get_file_as_string(session.v2_path) != old_bytes:
		return _fail("faction old save was changed or rejected during cold read")
	restored._store.fail_promotion_once = true
	if restored.choose("right", restored.issue_choice_token()) \
			or restored.state.has("factionEventState") \
			or FileAccess.get_file_as_string(session.v2_path) != old_bytes:
		return _fail("faction failed write changed old-save bytes")
	var activated: bool = restored.choose("right", restored.issue_choice_token())
	if not activated or not flow.valid(restored.state) \
			or int(restored.state.get("factionEventState", {}).get(
				"activationIndex", -1)) != 4:
		return _fail("faction marker did not activate on next valid decision: " +
			JSON.stringify({"chosen": activated, "phase": restored.state.get("phase"),
				"marker": restored.state.get("factionEventState"),
				"decision": restored.state.get("runClock", {}).get("decisionIndex")}))
	var reopened = Domain.new(Registry.new(), Session.new(path, "slot_1"), "slot_1")
	if not reopened.restore() or JSON.parse_string(JSON.stringify(reopened.state)) \
			!= JSON.parse_string(JSON.stringify(restored.state)):
		return _fail("faction activated old save failed strict cold replay")
	print("NONCOMBAT_FACTION_EVENTS_PASS cadence=true source_card=true settlement=true pin=true old_activation=true rollback=true")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
