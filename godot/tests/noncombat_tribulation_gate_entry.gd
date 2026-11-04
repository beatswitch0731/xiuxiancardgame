extends "res://tests/noncombat_foundation_normal_pool.gd"

const RealmGateFlow = preload("res://scripts/noncombat_realm_gate_flow.gd")
const BattleGateway = preload("res://scripts/noncombat_battle_gateway.gd")
const EncounterFlow = preload("res://scripts/noncombat_encounter_flow.gd")
const StageRouter = preload("res://scripts/combat_stage_router.gd")
const BattleReturnFlow = preload("res://scripts/noncombat_battle_return_flow.gd")


func _run() -> void:
	var game = Domain.new(Registry.new(), null, "slot_3")
	if not game.start("spell"):
		return _fail("tribulation gate fixture could not start")
	var state: Dictionary = game.state.duplicate(true)
	state.realm = "tribulation"
	state.phase = "FLOW_PENDING"
	state.attributes.cultivation = 100
	state.attributes.karmaGood = 20
	state.turn = 1
	state.runClock.decisionIndex = 1
	state.decisionCheckpoint = {"sourceCardId": "ch_tribulation_80"}
	state.chapterProgress = {"version": 1, "activeChapterRealm": "tribulation",
		"triggeredMilestones": {"tribulation": [20, 40, 60, 80]}}
	state.noncombatFlow = {"scope": "first_session_combat",
		"encounterDirectorState": {"realmProgress": {
			"tribulation": {"seenCounts": {"ordinary": 2, "relationship": 1,
				"quest": 0, "elite": 1}}}}}
	var flow = RealmGateFlow.new(ContentRepository.new())
	var evidence_state: Dictionary = state.duplicate(true)
	evidence_state["clues"] = [
		{"id": "century_war_truth"}, {"id": "ancient_prophecy_warning"},
		{"id": "ancient_sword_manual"}, {"id": "xuesha_laozu_past_love"}]
	evidence_state["npcAffection"] = {"bai_ren": 60}
	evidence_state["evidenceHypothesisConfidence"] = {"sect_complicity": 0}
	var evidence_snapshot: Dictionary = flow._ending_snapshot(evidence_state)
	if evidence_snapshot.get("hypothesisConfidence", {}).get("heaven_harvest") != 100 \
			or evidence_snapshot.get("hypothesisConfidence", {}).get("reincarnation_anchor") != 100 \
			or evidence_snapshot.get("hypothesisConfidence", {}).get("bond_exception") != 100 \
			or evidence_snapshot.get("hypothesisConfidence", {}).get("sect_complicity") != 50:
		return _fail("source evidence atlas confidence was not derived from clues")
	var forged_snapshot: Dictionary = flow._ending_snapshot(state.merged({
		"evidenceHypothesisConfidence": {"heaven_harvest": 100}}, true))
	if forged_snapshot.get("hypothesisConfidence", {}).get("heaven_harvest") != 0:
		return _fail("unsourced hypothesis confidence affected terminal eligibility")
	var old_hint_state: Dictionary = state.duplicate(true)
	old_hint_state["noncombatFlow"]["hintClues"] = [{"id": "ancient_prophecy_warning",
		"sourceCardId": "heavens_hint:old:35"}]
	if not flow._ending_snapshot(old_hint_state).get("clueIds", []).has(
			"ancient_prophecy_warning"):
		return _fail("old hint clue was not read by terminal snapshot")
	var offered: Dictionary = flow.resume(state)
	if offered.get("currentCardId") != "ch_tribulation_100" \
			or offered.get("phase") != "COMBAT_HANDOFF":
		return _fail("tribulation finale source gate not scheduled")
	var gateway = BattleGateway.new(Registry.new())
	var encounter = EncounterFlow.new(ContentRepository.new(), gateway)
	var pending: Dictionary = encounter.accept(offered)
	var warning: Dictionary = encounter.warning_card(pending)
	if warning.get("id") != "_warning_ch_tribulation_100" \
			or warning.get("choices", {}).get("left", {}).get("_confirmCombat") != true \
			or warning.get("choices", {}).get("right", {}).get("effects", {}).get("reincarnate") != true \
			or warning.get("choices", {}).get("right", {}).has("_confirmCombat"):
		return _fail("tribulation finale warning lost fight/reincarnate choice")
	game.state = pending.duplicate(true)
	if not game.choose("right", game.issue_choice_token()) \
			or game.state.get("phase") != "REBIRTH_PENDING" \
			or game.state.get("lifeCount") != 1 \
			or int(game.state.get("legacyBonuses", {}).get("daoHeart", 0)) < 2 \
			or game.state.get("lifeJournal", []).back().get("voluntaryReincarnation") != true:
		return _fail("tribulation finale voluntary reincarnation failed")
	var prepared: Dictionary = encounter.confirm(pending, "left")
	if prepared.get("phase") != "BATTLE_PENDING" \
			or gateway.build_request(prepared).get("sourceCardId") != "ch_tribulation_100" \
			or not encounter.confirm(pending, "right").is_empty():
		return _fail("tribulation finale battle preparation route invalid")
	var request: Dictionary = gateway.build_request(prepared)
	var resolver = BattlePlanResolver.new(Registry.new())
	var plan: Dictionary = resolver.resolve_persisted(prepared)
	var combat = CombatDomain.new(Registry.new())
	if plan.get("launchAuthorized") != true \
			or not combat.load_persisted_request(request, plan):
		return _fail("tribulation finale battle plan failed: " + resolver.last_error)
	if combat.state.get("hand", []).size() != 6:
		return _fail("good karma did not grant one after-draw card")
	var bad_state: Dictionary = state.duplicate(true)
	bad_state.attributes.karmaGood = 0
	bad_state.attributes.karmaBad = 20
	var bad_prepared: Dictionary = encounter.confirm(encounter.accept(flow.resume(bad_state)), "left")
	var bad_plan: Dictionary = resolver.resolve_persisted(bad_prepared)
	var bad_combat = CombatDomain.new(Registry.new())
	if bad_plan.get("launchAuthorized") != true \
			or not bad_combat.load_persisted_request(gateway.build_request(bad_prepared), bad_plan) \
			or bad_combat.state.get("hand", []).size() != 4:
		return _fail("bad karma did not discard one after-draw card")
	var context: Dictionary = StageRouter.new(Registry.new()).resolve_choice(
		"ch_tribulation_100", "left", request.pendingResolution.combatCard,
		String(request.encounterInstanceId), request.pendingResolution,
		String(request.path), String(request.realm))
	context["deck"] = plan.deck.duplicate(true)
	var stage: Control = load("res://scenes/duel_stage_tribulation_gate_2d.tscn").instantiate()
	if not stage.bind_stage_context(context):
		stage.free()
		return _fail("tribulation finale stage did not bind")
	root.add_child(stage)
	if not stage.has_hd2d_assets():
		return _fail("tribulation finale stage art unavailable")
	stage.queue_free()
	var result := {"contractVersion": 2,
		"encounterInstanceId": request.encounterInstanceId,
		"sourceCardId": request.sourceCardId,
		"encounterId": request.encounterId,
		"sourceContentHash": request.sourceContentHash,
		"outcome": "victory",
		"combatReceipt": "combat:" + String(request.encounterInstanceId),
		"postBattleState": {"encounterInstanceId": request.encounterInstanceId,
			"terminal": true, "combatPhase": "VICTORY"}}
	var return_flow = BattleReturnFlow.new(ContentRepository.new(), gateway)
	var won: Dictionary = return_flow.settle(prepared, result)
	if won.get("realm") != "tribulation" \
			or won.get("currentCardId") != "breakthrough_reward" \
			or won.get("terminalContext", {}).get("stage") != "REWARD_PENDING":
		return _fail("tribulation finale victory did not freeze terminal reward")
	var cold_won: Dictionary = JSON.parse_string(JSON.stringify(won))
	if flow.result_card(cold_won).get("id") != "breakthrough_reward":
		return _fail("tribulation finale reward did not survive JSON cold state")
	if not return_flow.settle(won, result).is_empty():
		return _fail("tribulation finale duplicate victory was accepted")
	var epilogue: Dictionary = flow.dismiss(won, "left")
	if epilogue.get("phase") != "ENDING_PENDING" \
			or epilogue.get("lifePhase") != "EPILOGUE" \
			or epilogue.get("endingId") != "ascension" \
			or epilogue.get("currentCardId") != "ending_ascension" \
			or flow.ending_card(epilogue).get("id") != "ending_ascension":
		return _fail("tribulation finale reward did not reach source epilogue")
	var cold_epilogue: Dictionary = JSON.parse_string(JSON.stringify(epilogue))
	if flow.ending_card(cold_epilogue).get("id") != "ending_ascension":
		return _fail("tribulation finale epilogue did not survive JSON cold state")
	var stale_epilogue: Dictionary = cold_epilogue.duplicate(true)
	stale_epilogue["endingSourceSha"] = "changed"
	if not flow.ending_card(stale_epilogue).is_empty():
		return _fail("tribulation finale stale ending source was accepted")
	var bond_state: Dictionary = evidence_state.duplicate(true)
	bond_state["endingCandidate"] = "red_dust"
	var bond_prepared: Dictionary = encounter.confirm(encounter.accept(flow.resume(bond_state)), "left")
	var bond_request: Dictionary = gateway.build_request(bond_prepared)
	var bond_result: Dictionary = result.duplicate(true)
	bond_result.encounterInstanceId = bond_request.encounterInstanceId
	bond_result.sourceContentHash = bond_request.sourceContentHash
	bond_result.combatReceipt = "combat:" + String(bond_request.encounterInstanceId)
	bond_result.postBattleState.encounterInstanceId = bond_request.encounterInstanceId
	var bond_won: Dictionary = return_flow.settle(bond_prepared, bond_result)
	var red_dust: Dictionary = flow.dismiss(bond_won, "right")
	if red_dust.get("endingId") != "red_dust":
		return _fail("red dust source evidence and bond eligibility rejected")
	var chaos_state: Dictionary = evidence_state.duplicate(true)
	chaos_state["endingCandidate"] = "chaos"
	var chaos_prepared: Dictionary = encounter.confirm(encounter.accept(flow.resume(chaos_state)), "left")
	var chaos_request: Dictionary = gateway.build_request(chaos_prepared)
	var chaos_result: Dictionary = result.duplicate(true)
	chaos_result.encounterInstanceId = chaos_request.encounterInstanceId
	chaos_result.sourceContentHash = chaos_request.sourceContentHash
	chaos_result.combatReceipt = "combat:" + String(chaos_request.encounterInstanceId)
	chaos_result.postBattleState.encounterInstanceId = chaos_request.encounterInstanceId
	var chaos_won: Dictionary = return_flow.settle(chaos_prepared, chaos_result)
	var chaos: Dictionary = flow.dismiss(chaos_won, "down")
	if chaos.get("endingId") != "chaos":
		return _fail("chaos source evidence eligibility rejected")
	var rejected: Dictionary = won.duplicate(true)
	rejected["endingCandidate"] = "chaos"
	if flow.dismiss(rejected, "left").get("endingId") != "ascension":
		return _fail("unmet ending did not fall back to ascension")
	var upper: Dictionary = flow.continue_after_ending(epilogue)
	if upper.get("phase") != "UPPER_REALM_PENDING" \
			or upper.get("currentCardId") != "pa_ascension_moment" \
			or upper.get("flags", {}).get("post_ascension_active") != true \
			or flow.upper_card(upper).get("id") != "pa_ascension_moment":
		return _fail("ascension did not enter upper realm source card")
	var cold_upper: Dictionary = JSON.parse_string(JSON.stringify(upper))
	if flow.upper_card(cold_upper).get("id") != "pa_ascension_moment":
		return _fail("upper realm entry did not survive JSON cold state")
	var upper_next: Dictionary = flow.settle_upper(upper, "left")
	if upper_next.get("currentCardId") != "pa_new_world" \
			or upper_next.get("phase") != "UPPER_REALM_PENDING" \
			or flow.upper_card(upper_next).get("id") != "pa_new_world":
		return _fail("upper realm first source continuation failed")
	var upper_intro: Dictionary = flow.settle_upper(upper_next, "right")
	var upper_city: Dictionary = flow.settle_upper(upper_intro, "left")
	upper_city["phase"] = "NORMAL_PENDING"
	upper_city.erase("pendingUpperCard")
	if not flow.upper_normal_choice_available(upper_city, "right") \
			or flow.settle_upper(upper_city, "right", true).get(
				"currentCardId") != "pa_veteran_talk":
		return _fail("upper realm ordinary authored continuation failed")
	var upper_open: Dictionary = upper_city.duplicate(true)
	upper_open["phase"] = "FLOW_PENDING"
	upper_open["cardsPlayed"].append("pa_cloud_city")
	var upper_buckets: Dictionary = preload(
		"res://scripts/noncombat_normal_draw_policy.gd").new(
			ContentRepository.new()).buckets(upper_open)
	var upper_ids: Array = []
	for bucket in upper_buckets.values():
		for row in bucket:
			upper_ids.append(row.get("id"))
	if upper_open.get("phase") != "FLOW_PENDING" \
			or not upper_ids.has("pa_veteran_talk"):
		return _fail("upper realm ordinary pool did not reopen")
	var rebirth = preload("res://scripts/noncombat_rebirth_flow.gd").new(ContentRepository.new())
	var next_life: Dictionary = rebirth.ending_new_life(epilogue,
		flow.ending_card(epilogue), "right", "slot_3")
	if next_life.get("phase") != "REBIRTH_PENDING" \
			or next_life.get("lifeJournal", []).back().get("endingReincarnation") != true:
		return _fail("ascension epilogue reincarnation failed")
	var old_hint_epilogue: Dictionary = epilogue.duplicate(true)
	old_hint_epilogue["noncombatFlow"]["hintClues"] = [{"id": "ancient_prophecy_warning",
		"sourceCardId": "heavens_hint:old:35"}]
	var old_hint_life: Dictionary = rebirth.ending_new_life(old_hint_epilogue,
		flow.ending_card(old_hint_epilogue), "right", "slot_3")
	if old_hint_life.get("clues", []).size() != 1 \
			or old_hint_life["clues"][0].get("id") != "ancient_prophecy_warning":
		return _fail("old hint clue did not survive reincarnation")
	var red_life: Dictionary = rebirth.ending_new_life(red_dust,
		flow.ending_card(red_dust), "right", "slot_3")
	var chaos_life: Dictionary = rebirth.ending_new_life(chaos,
		flow.ending_card(chaos), "right", "slot_3")
	if red_life.get("legacyBonuses", {}).get("karmaGood") != 10 \
			or chaos_life.get("legacyBonuses", {}).get("fortune") != 8 \
			or red_life.get("clues", []).size() != 4 \
			or chaos_life.get("clues", []).size() != 4:
		return _fail("red dust or chaos source rebirth bonus/evidence failed")
	var upper_final: Dictionary = upper.duplicate(true)
	upper_final["phase"] = "NORMAL_PENDING"
	upper_final["currentCardId"] = "pa_ending_reform"
	upper_final.erase("pendingUpperCard")
	var reform: Dictionary = flow._upper_source_card("pa_ending_reform")
	var reform_rebirth: Dictionary = rebirth.upper_new_life(upper_final,
		reform, "left", "slot_3")
	if reform_rebirth.get("phase") != "REBIRTH_PENDING" \
			or reform_rebirth.get("lifeJournal", []).back().get("upperReincarnation") != true:
		return _fail("upper realm reform reincarnation failed")
	for outcome in ["defeat", "flee"]:
		var failed_result: Dictionary = result.duplicate(true)
		failed_result["outcome"] = outcome
		failed_result["postBattleState"]["combatPhase"] = outcome.to_upper()
		var returned: Dictionary = return_flow.settle(prepared, failed_result)
		if returned.is_empty() or returned.get("realm") != "tribulation" \
				or returned.get("terminalContext") != null \
				or returned.get("phase") != (
					"INNER_DEMON_PENDING" if outcome == "defeat" else "BATTLE_RESULT_PENDING"):
			return _fail("tribulation finale %s result invalid: %s" % [
				outcome, return_flow.last_error])
	var fatal_state: Dictionary = state.duplicate(true)
	fatal_state.attributes.health = 1
	var fatal_prepared: Dictionary = encounter.confirm(encounter.accept(
		flow.resume(fatal_state)), "left")
	var fatal_request: Dictionary = gateway.build_request(fatal_prepared)
	var fatal_result: Dictionary = result.duplicate(true)
	fatal_result.encounterInstanceId = fatal_request.encounterInstanceId
	fatal_result.sourceContentHash = fatal_request.sourceContentHash
	fatal_result.combatReceipt = "combat:" + String(fatal_request.encounterInstanceId)
	fatal_result.postBattleState.encounterInstanceId = fatal_request.encounterInstanceId
	fatal_result.outcome = "defeat"
	fatal_result.postBattleState.combatPhase = "DEFEAT"
	var death: Dictionary = return_flow.settle(fatal_prepared, fatal_result)
	if death.get("phase") != "DEATH_PENDING" \
			or death.get("deathCauseId") != "death_blood_loss" \
			or death.get("currentCardId") != "death_blood_loss":
		return _fail("fatal finale defeat did not reach death card")
	var lifespan_state: Dictionary = state.duplicate(true)
	lifespan_state.resources.lifespan = 1
	var flee_prepared: Dictionary = encounter.confirm(encounter.accept(
		flow.resume(lifespan_state)), "left")
	var flee_request: Dictionary = gateway.build_request(flee_prepared)
	var flee_result: Dictionary = result.duplicate(true)
	flee_result.encounterInstanceId = flee_request.encounterInstanceId
	flee_result.sourceContentHash = flee_request.sourceContentHash
	flee_result.combatReceipt = "combat:" + String(flee_request.encounterInstanceId)
	flee_result.postBattleState.encounterInstanceId = flee_request.encounterInstanceId
	flee_result.outcome = "flee"
	flee_result.postBattleState.combatPhase = "FLEE"
	var lifespan_death: Dictionary = return_flow.settle(flee_prepared, flee_result)
	if lifespan_death.get("phase") != "DEATH_PENDING" \
			or lifespan_death.get("deathCauseId") != "death_lifespan":
		return _fail("fatal finale retreat did not reach lifespan death")
	print("NONCOMBAT_TRIBULATION_GATE_ENTRY_PASS schedule=true warning=true reincarnation=true fight=true plan=true battlefield=true judgment=true outcomes=3 endings=3 upper=true")
	quit(0)
