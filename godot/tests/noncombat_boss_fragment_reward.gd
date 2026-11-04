extends SceneTree

const Registry = preload("res://scripts/runtime_data_registry.gd")
const Domain = preload("res://scripts/noncombat_domain.gd")
const Repository = preload("res://scripts/noncombat_content_repository.gd")
const RealmGateFlow = preload("res://scripts/noncombat_realm_gate_flow.gd")
const EncounterFlow = preload("res://scripts/noncombat_encounter_flow.gd")
const BattleGateway = preload("res://scripts/noncombat_battle_gateway.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var game = Domain.new(Registry.new(), null, "slot_3")
	if not game.start("spell") or not game.choose("left", game.issue_choice_token()):
		return _fail("fragment-bearing source run did not start")
	var state: Dictionary = game.state.duplicate(true)
	state.phase = "FLOW_PENDING"
	state.realm = "foundation"
	state.attributes.cultivation = 100
	state.resources.spiritStone = 10
	state.decisionCheckpoint = {"sourceCardId": "ch_foundation_80"}
	state.chapterProgress = {"version": 1, "activeChapterRealm": "foundation",
		"triggeredMilestones": {"foundation": [20, 40, 60, 80]}}
	state.noncombatFlow = {"scope": "first_session_combat",
		"encounterDirectorState": {"realmProgress": {"foundation": {
			"seenCounts": {"ordinary": 2, "relationship": 1, "quest": 0,
				"elite": 1}}}}}
	var repository = Repository.new()
	var gateway = BattleGateway.new(Registry.new())
	var encounter = EncounterFlow.new(repository, gateway)
	var offered: Dictionary = RealmGateFlow.new(repository).resume(state)
	var prepared: Dictionary = encounter.confirm(encounter.accept(offered), "right")
	var request: Dictionary = gateway.build_request(prepared)
	if request.is_empty() or prepared.get("phase") != "BATTLE_PENDING":
		return _fail("authenticated foundation boss request missing")
	game.state = prepared
	if not game.set_legacy_focus("sword_heart"):
		return _fail("source boss focus could not be set")
	var result := {"contractVersion": 2,
		"encounterInstanceId": request.encounterInstanceId,
		"sourceCardId": request.sourceCardId,
		"encounterId": request.encounterId,
		"sourceContentHash": request.sourceContentHash,
		"outcome": "victory",
		"combatReceipt": "combat:" + String(request.encounterInstanceId),
		"postBattleState": {"encounterInstanceId": request.encounterInstanceId,
			"terminal": true, "combatPhase": "VICTORY"}}
	if not game.submit_battle_result(result):
		return _fail("authenticated boss victory was rejected")
	var pending: Variant = game.state.legacyRunState.pendingBossFragmentReward
	if not pending is Dictionary or pending.get("encounterKind") != "realm_boss" \
			or pending.get("encounterInstanceId") != request.encounterInstanceId \
			or pending.get("cardId") != "ch_foundation_100" \
			or game.boss_fragment_options().size() != 3 \
			or game.boss_fragment_options()[0].setId != "sword_heart":
		return _fail("boss victory did not create three source candidates")
	if game.submit_battle_result(result) or game.claim_boss_fragment("invalid"):
		return _fail("duplicate result or invalid claim was accepted")
	var selected := String(game.boss_fragment_options()[0].setId)
	var before_claim: Dictionary = game.state.duplicate(true)
	var before_count := int(game.state.legacyArchive.fragmentsBySet[selected])
	if not game.claim_boss_fragment(selected) or game.claim_boss_fragment(selected) \
			or game.state.legacyRunState.pendingBossFragmentReward != null \
			or not game.state.legacyRunState.claimedEncounterInstanceIds.has(
				request.encounterInstanceId) \
			or int(game.state.legacyArchive.fragmentsBySet[selected]) != before_count + 1 \
			or game.state.get("bossFragmentClaimActions", []).size() != 1:
		return _fail("boss choice did not claim exactly one durable fragment")
	var completion = Domain.new(Registry.new(), null, "slot_3")
	completion.state = before_claim
	completion.state.legacyArchive.fragmentsBySet[selected] = 7
	var art_id := String(completion.boss_fragment_options()[0].variantCardId)
	if art_id.is_empty() or not completion.claim_boss_fragment(selected) \
			or int(completion.state.legacyArchive.fragmentsBySet[selected]) != 8 \
			or not completion.state.legacyArchive.completedSetIds.has(selected) \
			or not completion.state.deck.has(art_id) \
			or completion.state.deck.count(art_id) != 1:
		return _fail("eighth boss fragment did not award one source art")
	print("NONCOMBAT_BOSS_FRAGMENT_REWARD_PASS source=realm_boss options=3 claim=1 completion=8 duplicate=false")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
