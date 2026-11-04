extends SceneTree

const Domain = preload("res://scripts/noncombat_domain.gd")
const Registry = preload("res://scripts/runtime_data_registry.gd")
const Events = preload("res://scripts/noncombat_companion_events.gd")
const BattlePlanResolver = preload("res://scripts/battle_plan_resolver.gd")
const CombatDomain = preload("res://scripts/combat_domain.gd")
const StageRouter = preload("res://scripts/combat_stage_router.gd")
const StageScene = preload("res://scenes/duel_stage_companion_old_master_2d.tscn")
const BattleScene = preload("res://scenes/main.tscn")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game = Domain.new(Registry.new(), null, "slot_3")
	if not game.start("sword"):
		return _fail("sword opening unavailable")
	var state: Dictionary = game.state.duplicate(true)
	var events = Events.new(game._content)
	var data: Dictionary = game._content.read_module("companions:events")
	var owner: Dictionary = events._definition(data, "jian_linger")
	var event := {}
	for row in owner.get("events", []):
		if row.get("id") == "jle_8_sword_tomb_old_master":
			event = row
			break
	if event.is_empty():
		return _fail("authored old master event missing")
	state.realm = "golden"
	state.turn = 24
	state.runClock.decisionIndex = 24
	state.resources.companions = ["jian_linger"]
	state.npcAffection = {"jian_linger": 70}
	state.companionProgress = events.marker(0, 23)
	state.companionProgress.states.jian_linger.bond = 2
	state.noncombatFlow = {}
	state.phase = "FLOW_PENDING"
	state.currentCardId = ""
	var own: Dictionary = state.companionProgress.states.jian_linger
	if not events._eligible(state, "jian_linger", event, 70, own):
		return _fail("authored combat companion event was removed from the production pool: encounter=%s bond=%s realm=%s" % [events._old_master_encounter().get("id"), own.get("bond"), state.get("realm")])
	var selected := {}
	for sample in range(1000):
		state.runClock.lifeId = "companion:old_master:%d" % sample
		var issued: Dictionary = events.take(state)
		if issued.get("currentCardId") == "comp_jian_linger_jle_8_sword_tomb_old_master":
			selected = issued
			break
	if selected.is_empty() or events.card(selected).is_empty():
		return _fail("old master event was never issued by the companion draw")
	state.runClock.lifeId = "slot_3:life:0"
	var card: Dictionary = events._build_card(state, owner, event)
	if card.get("choices", {}).get("left", {}).get("encounterId") \
			!= "enc_companion_jian_linger_tomb" \
			or card.choices.left.get("triggerCombat") != true \
			or card.choices.left.get("combatOutcomeLinks", {}).get("victory", {}).get(
				"companionEffects", {}).get("affectionDelta") != 6:
		return _fail("companion event did not resolve its authored encounter contract")
	state.phase = "COMPANION_PENDING"
	state.currentCardId = card.id
	state.pendingCompanionCard = card
	game.state = state
	game._current_card_id = card.id
	if not game.can_choose_direction("left") or not game.can_choose_direction("right"):
		return _fail("old master event did not admit both authored choices")
	var retreated: Dictionary = events.settle(state, "right")
	if retreated.is_empty() \
			or int(retreated.npcAffection.jian_linger) != 67 \
			or int(retreated.companionProgress.states.jian_linger.trust) != 13 \
			or int(retreated.attributes.daoHeart) != \
				int(state.attributes.daoHeart) + 1:
		return _fail("old master retreat lost authored relationship or dao heart effects")
	if game._battle_gateway.offer_from_state(state).get("encounterId") \
			!= "enc_companion_jian_linger_tomb":
		return _fail("old master left choice had no authenticated battle offer: source=%s encounter=%s error=%s" % [
			game._battle_gateway._companion_source(state).get("id"),
			game._battle_gateway._companion_encounter(state).get("id"),
			game._battle_gateway.source_error])
	if not game.choose("left", game.issue_choice_token()) \
			or game.state.get("phase") != "WARNING_PENDING" \
			or not game.choose("left", game.issue_choice_token()) \
			or game.state.get("phase") != "BATTLE_PENDING":
		return _fail("old master combat choice did not persist warning and battle")
	var request: Dictionary = game.battle_request()
	if request.get("sourceCardId") != card.id \
			or request.get("encounterId") != "enc_companion_jian_linger_tomb":
		return _fail("old master battle request lost companion source authority")
	var resolver = BattlePlanResolver.new(Registry.new())
	var plan: Dictionary = resolver.resolve_persisted(game.state)
	if plan.get("launchAuthorized") != true or plan.get("stageScene") != \
			"res://scenes/duel_stage_companion_old_master_2d.tscn":
		return _fail("old master desktop battle plan did not load: " + resolver.last_error)
	var forged: Dictionary = request.duplicate(true)
	forged.pendingResolution.sourceCard.compId = "bai_luoxuan"
	if not resolver.inspect_request(forged).is_empty():
		return _fail("old master battle plan accepted a foreign companion owner")
	var combat = CombatDomain.new(Registry.new())
	if not combat.load_persisted_request(request, plan) or combat.state.get(
			"enemy", {}).get("planRuntime", {}).get("planId") != \
			"plan_sword_tomb_old_master_agc_n12_v1":
		return _fail("old master source battle rules did not load")
	var context: Dictionary = StageRouter.new(Registry.new()).resolve_choice(
		request.sourceCardId, request.direction, request.pendingResolution.combatCard,
		request.encounterInstanceId, request.pendingResolution, request.path,
		request.realm)
	context.path = plan.path
	context.deck = plan.deck
	var stage = StageScene.instantiate()
	if not stage.bind_stage_context(context):
		stage.free()
		return _fail("old master source stage did not bind")
	stage.free()
	var battle_ui: Control = BattleScene.instantiate()
	battle_ui.battle_request = request.duplicate(true)
	battle_ui.battle_plan = plan.duplicate(true)
	root.add_child(battle_ui)
	await process_frame
	var flee_button: Button = battle_ui.get_node_or_null("FleeBattle")
	if battle_ui.duel_stage == null or not battle_ui.stage_assets_ready \
			or flee_button == null or not flee_button.visible or flee_button.disabled:
		battle_ui.queue_free()
		await process_frame
		return _fail("old master desktop battle scene did not launch")
	flee_button.pressed.emit()
	var desktop_result: Dictionary = battle_ui.terminal_result()
	battle_ui.queue_free()
	await process_frame
	if desktop_result.get("outcome") != "flee" or desktop_result.get(
			"sourceCardId") != request.sourceCardId:
		return _fail("old master desktop flee did not preserve source result")
	var prepared_battle: Dictionary = game.state.duplicate(true)
	var result := {"contractVersion": request.contractVersion,
		"encounterInstanceId": request.encounterInstanceId,
		"sourceCardId": request.sourceCardId,
		"encounterId": request.encounterId,
		"sourceContentHash": request.sourceContentHash,
		"outcome": "victory", "combatReceipt": "combat:" + request.encounterInstanceId,
		"postBattleState": {"encounterInstanceId": request.encounterInstanceId,
			"terminal": true, "combatPhase": "VICTORY"}}
	if not game.submit_battle_result(result) \
			or game.state.get("phase") != "BATTLE_RESULT_PENDING":
		return _fail("old master victory did not settle: " + game.flow_failure_reason())
	if int(game.state.npcAffection.jian_linger) != 76 \
			or int(game.state.companionProgress.states.jian_linger.bond) != 3 \
			or int(game.state.knowledge.get("sword", 0)) != 2 \
			or game.get_current_card().is_empty():
		return _fail("old master victory lost authored relationship, reward, or result card")
	if not game.choose("down", game.issue_choice_token()) \
			or game.state.has("pendingCompanionCard"):
		return _fail("old master victory result did not release the companion event")
	for outcome in ["defeat", "flee"]:
		var alternate = Domain.new(Registry.new(), null, "slot_3")
		if not alternate.start("sword"):
			return _fail("old master alternate baseline unavailable")
		alternate.state = prepared_battle.duplicate(true)
		alternate._current_card_id = card.id
		var alternate_result: Dictionary = result.duplicate(true)
		alternate_result.outcome = outcome
		alternate_result.postBattleState.combatPhase = outcome.to_upper()
		if not alternate.submit_battle_result(alternate_result) \
				or alternate.state.get("phase") != "BATTLE_RESULT_PENDING" \
				or alternate.get_current_card().is_empty():
			return _fail("old master alternate outcome did not settle: " + outcome)
		if outcome == "defeat" and int(alternate.state.companionProgress.states.jian_linger.trust) != 12 \
				or outcome == "flee" and int(alternate.state.npcAffection.jian_linger) != 65:
			return _fail("old master alternate relationship effect mismatched: " + outcome)
		if not alternate.choose("down", alternate.issue_choice_token()) \
				or alternate.state.has("pendingCompanionCard"):
			return _fail("old master alternate result did not release the event: " + outcome)
	print("NONCOMBAT_COMPANION_OLD_MASTER_ENTRY_PASS")
	quit(0)

func _fail(message: String) -> void:
	push_error(message)
	quit(1)
