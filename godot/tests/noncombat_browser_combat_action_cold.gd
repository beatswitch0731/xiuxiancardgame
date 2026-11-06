extends SceneTree

const Importer = preload("res://scripts/noncombat_browser_opening_import.gd")
const Domain = preload("res://scripts/noncombat_domain.gd")
const Registry = preload("res://scripts/runtime_data_registry.gd")
const RunSession = preload("res://scripts/noncombat_run_session.gd")
const BattlePlan = preload("res://scripts/battle_plan_resolver.gd")
const BattleScene = preload("res://scenes/main.tscn")
const CombatSeal = preload("res://scripts/noncombat_browser_combat_seal.gd")
const FIXTURE := "res://tests/fixtures/artifacts/godot-migration/noncombat-browser-import/combat-pending-source-sword.json"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(
		ProjectSettings.globalize_path(FIXTURE)))
	var pending: Dictionary = fixture.pending
	var slot_id := String(pending.slotId)
	var root_path := "user://tests/browser_combat_action_%d_%d" % [
		OS.get_process_id(), Time.get_ticks_usec()]
	var session = RunSession.new(root_path + "/noncombat_opening_v1.json", slot_id)
	if Importer.new().import_to_empty_slot(JSON.stringify(pending.storage),
			slot_id, session).get("ok") != true:
		return _fail("real browser combat could not seed action slot")
	var story = Domain.new(Registry.new(), session, slot_id)
	if not story.restore():
		return _fail("real browser combat slot could not restore")
	var battle = await _launch(story)
	if battle == null:
		return _fail("real imported battle scene did not launch")
	var original_hand: Array = battle.combat.state.hand.duplicate()
	var edge_index: int = original_hand.find("sword_edge")
	if edge_index < 0:
		return _fail("real browser first-turn hand lacks sword_edge")
	var original_qi := int(battle.combat.state.qi)
	var original_presentations := int(battle.pending_presentations)
	var original_bytes := FileAccess.get_file_as_string(session.v2_path)
	if not story.has_method("commit_browser_combat_card"):
		return _fail("continued card action has no story-slot commit owner")
	battle.combat.input_locked = true
	battle._play_card(edge_index)
	if FileAccess.get_file_as_string(session.v2_path) != original_bytes:
		return _fail("presentation-locked input advanced story slot")
	battle.combat.input_locked = false
	session.fail_promotion_once = true
	battle._play_card(edge_index) # sword_edge in the captured browser hand.
	if FileAccess.get_file_as_string(session.v2_path) != original_bytes \
			or battle.combat.state.hand != original_hand \
			or int(battle.combat.state.qi) != original_qi \
			or int(battle.pending_presentations) != original_presentations:
		return _fail("failed atomic write changed story bytes or visible combat")
	battle._play_card(edge_index)
	if FileAccess.get_file_as_string(session.v2_path) == original_bytes \
			or battle.combat.state.hand.has("sword_edge") \
			or int(battle.combat.state.qi) != original_qi - 1:
		return _fail("second card did not atomically persist and play")
	var played_hand: Array = battle.combat.state.hand.duplicate()
	var played_qi := int(battle.combat.state.qi)
	battle.queue_free()
	var cold = Domain.new(Registry.new(), session, slot_id)
	if not cold.restore():
		return _fail("continued action story slot did not cold restore")
	var forged_state: Dictionary = cold.state.duplicate(true)
	forged_state.browserCombatActions[0].cardId = "sword_guard"
	var forged_cold = Domain.new(Registry.new(), Domain.ReplaySnapshotStore.new(
		JSON.parse_string(JSON.stringify(forged_state))), slot_id)
	if forged_cold.restore():
		return _fail("forged native combat action log passed strict cold replay")
	var resumed = await _launch(cold)
	if resumed == null or resumed.combat.state.hand != played_hand \
			or int(resumed.combat.state.qi) != played_qi:
		return _fail("cold battle lost the committed second card")
	resumed._play_card(resumed.combat.state.hand.find("sword_followthrough"))
	if int(resumed.combat.state.qi) != 0 \
			or resumed.combat.state.hand.size() != played_hand.size() - 1:
		return _fail("continued action sequence did not play after first cold load")
	var final_hand: Array = resumed.combat.state.hand.duplicate()
	resumed.queue_free()
	var second_cold = Domain.new(Registry.new(), session, slot_id)
	if not second_cold.restore() \
			or second_cold.state.get("browserCombatActions", []).size() != 2:
		return _fail("two-card action sequence did not cold restore")
	var final_battle = await _launch(second_cold)
	if final_battle == null or final_battle.combat.state.hand != final_hand \
			or int(final_battle.combat.state.qi) != 0:
		return _fail("second cold battle lost continued action sequence")
	var before_end_bytes := FileAccess.get_file_as_string(session.v2_path)
	session.fail_promotion_once = true
	final_battle._end_turn()
	if FileAccess.get_file_as_string(session.v2_path) != before_end_bytes \
			or final_battle.combat.state.phase != "PLAYER_TURN":
		return _fail("failed end-turn write advanced story or live battle")
	final_battle._end_turn()
	if final_battle.combat.state.phase != "REACTION_OPEN":
		return _fail("owned end turn did not open persisted enemy reaction")
	final_battle.queue_free()
	var reaction_cold = Domain.new(Registry.new(), session, slot_id)
	if not reaction_cold.restore() \
			or reaction_cold.state.get("browserCombatActions", []).size() != 3:
		return _fail("reaction-open state did not cold restore")
	var reaction_battle = await _launch(reaction_cold)
	if reaction_battle == null or reaction_battle.combat.state.phase != "REACTION_OPEN":
		return _fail("cold battle lost enemy reaction window")
	var before_reaction_bytes := FileAccess.get_file_as_string(session.v2_path)
	var before_reaction_hp := int(reaction_battle.combat.state.player.hp)
	var before_reaction_presentations := int(reaction_battle.pending_presentations)
	var before_reaction_rng: int = reaction_battle.combat._rng.state
	session.fail_promotion_once = true
	reaction_battle._choose_reaction("TAKE_HIT")
	if FileAccess.get_file_as_string(session.v2_path) != before_reaction_bytes \
			or int(reaction_battle.combat.state.player.hp) != before_reaction_hp \
			or reaction_battle.combat.state.phase != "REACTION_OPEN" \
			or int(reaction_battle.pending_presentations) != before_reaction_presentations \
			or reaction_battle.combat._rng.state != before_reaction_rng:
		return _fail("failed reaction write advanced RNG, state, or presentation")
	reaction_battle._choose_reaction("TAKE_HIT")
	var receipt: Dictionary = reaction_cold.state.get("browserCombatActions", [])[-1]
	if reaction_battle.combat.state.phase != "PLAYER_TURN" \
			or reaction_battle.combat.state.turn != 2 \
			or receipt.get("randomValues", []).size() != 5 \
			or reaction_battle.combat.replay_random_remaining() != 0:
		return _fail("enemy turn did not consume its committed five-value receipt")
	var next_hand: Array = reaction_battle.combat.state.hand.duplicate()
	var next_draw: Array = reaction_battle.combat.state.drawPile.duplicate()
	var next_hp := int(reaction_battle.combat.state.player.hp)
	reaction_battle.queue_free()
	var turn_two_cold = Domain.new(Registry.new(), session, slot_id)
	if not turn_two_cold.restore():
		return _fail("enemy-resolved state did not cold restore")
	var forged_tape: Dictionary = turn_two_cold.state.duplicate(true)
	forged_tape.browserCombatActions[3].randomValues[1] = 1.1
	var forged_tape_cold = Domain.new(Registry.new(), Domain.ReplaySnapshotStore.new(
		JSON.parse_string(JSON.stringify(forged_tape))), slot_id)
	if forged_tape_cold.restore():
		return _fail("out-of-range random receipt passed strict cold replay")
	var rewritten_tape: Dictionary = turn_two_cold.state.duplicate(true)
	var old_roll := float(rewritten_tape.browserCombatActions[3].randomValues[1])
	rewritten_tape.browserCombatActions[3].randomValues[1] = fmod(old_roll + 0.5, 1.0)
	var rewritten_cold = Domain.new(Registry.new(), Domain.ReplaySnapshotStore.new(
		JSON.parse_string(JSON.stringify(rewritten_tape))), slot_id)
	if rewritten_cold.restore():
		return _fail("in-range rewritten shuffle receipt became cold authority")
	var resealed_nonce: Dictionary = turn_two_cold.state.duplicate(true)
	resealed_nonce.browserCombatSnapshot["unrelatedNonce"] = "different-future-rng"
	resealed_nonce.browserCombatSnapshot.authoritySeal = CombatSeal.new().compute_seal(
		resealed_nonce.browserCombatSnapshot)
	if not CombatSeal.new().verify_hash_chain(resealed_nonce.browserCombatSnapshot):
		return _fail("resealed unrelated nonce was not a valid source hash chain")
	resealed_nonce.browserCombatActions[3].randomValues = _old_seal_random_values(
		resealed_nonce.browserCombatSnapshot.authoritySeal,
		turn_two_cold.battle_request().encounterInstanceId)
	if resealed_nonce.browserCombatActions[3].randomValues == receipt.randomValues:
		return _fail("resealed nonce did not alter the old future random tape")
	var resealed_nonce_cold = Domain.new(Registry.new(), Domain.ReplaySnapshotStore.new(
		JSON.parse_string(JSON.stringify(resealed_nonce))), slot_id)
	if resealed_nonce_cold.restore():
		return _fail("resealed unrelated nonce and rederived tape changed cold authority")
	var turn_two_battle = await _launch(turn_two_cold)
	if turn_two_battle == null or turn_two_battle.combat.state.turn != 2 \
			or turn_two_battle.combat.state.hand != next_hand \
			or turn_two_battle.combat.state.drawPile != next_draw \
			or int(turn_two_battle.combat.state.player.hp) != next_hp:
		return _fail("second-round hand, draw order, or health changed on cold restart")
	if not turn_two_battle.combat.flee():
		return _fail("continued battle could not flee after cold restore")
	var result: Dictionary = turn_two_battle.terminal_result()
	if result.get("outcome") != "flee" \
			or not turn_two_cold.submit_battle_result(result) \
			or turn_two_cold.submit_battle_result(result):
		return _fail("continued battle result did not settle exactly once")
	turn_two_battle.queue_free()
	var after_result = Domain.new(Registry.new(), session, slot_id)
	if not after_result.restore() or after_result.state.has("browserCombatActions"):
		return _fail("continued battle result did not cold restore cleanly")
	print("NONCOMBAT_BROWSER_COMBAT_ACTION_COLD_PASS atomic=true cards=2 enemy=true rng=5 cold=true forged=rejected result=once")
	quit(0)


func _launch(story) -> Control:
	var request: Dictionary = story.battle_request()
	var plan: Dictionary = BattlePlan.new(Registry.new()).resolve_persisted(story.state)
	if request.is_empty() or plan.get("launchAuthorized") != true:
		return null
	var battle: Control = BattleScene.instantiate()
	battle.battle_request = request.duplicate(true)
	battle.battle_plan = plan.duplicate(true)
	battle.browser_combat_snapshot = story.state.browserCombatSnapshot.duplicate(true)
	battle.browser_combat_authority = story.state.browserCombatAuthority.duplicate(true)
	battle.browser_combat_actions = story.state.get("browserCombatActions", []).duplicate(true)
	battle.browser_combat_commit_card = Callable(story, "commit_browser_combat_card")
	battle.browser_combat_commit_end_turn = Callable(story,
		"commit_browser_combat_end_turn")
	battle.browser_combat_commit_reaction = Callable(story,
		"commit_browser_combat_reaction")
	root.add_child(battle)
	await process_frame
	await process_frame
	return battle if battle.combat != null and not battle.combat.state.is_empty() else null


func _fail(reason: String) -> void:
	push_error(reason)
	quit(1)


func _old_seal_random_values(seal: String, owner: String) -> Array:
	var digest := ("n10:first-sword:reaction:1:" + seal + ":" + owner).sha256_text()
	var alphabet := "0123456789abcdef"
	var seed_value := 0
	for index in 15:
		seed_value = seed_value * 16 + alphabet.find(digest.substr(index, 1))
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var values: Array = []
	for _index in 5:
		values.append(floorf(rng.randf() * 100000000.0) / 100000000.0)
	return values
