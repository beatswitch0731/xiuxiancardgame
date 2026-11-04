extends "res://tests/noncombat_foundation_normal_pool.gd"

const StageRouter = preload("res://scripts/combat_stage_router.gd")
const HandUI = preload("res://scripts/card_hand_ui.gd")


func _run() -> void:
	var registry = Registry.new()
	var base: Dictionary = registry.get_battle_card("spell_spark")
	var upgraded: Dictionary = registry.get_battle_card("spell_spark+")
	if base.is_empty() or upgraded.get("id") != "spell_spark+" \
			or upgraded.get("name") != String(base.get("name")) + "+" \
			or upgraded.get("cardArt") != base.get("cardArt") \
			or int(upgraded.get("effects", [{}])[0].get("value", 0)) != int(
				base.get("effects", [{}])[0].get("value", 0)) + 1 \
			or not registry.get_battle_card("spell_spark++").is_empty():
		return _fail("source upgrade definition differs from browser")
	var game = Domain.new(Registry.new(), null, "slot_3")
	if not game.start("spell"):
		return _fail("upgraded battle fixture could not start")
	game.state.realm = "foundation"
	game.state.phase = "NORMAL_PENDING"
	game.state.currentCardId = "f_mission"
	game.state.runClock.decisionIndex = 1
	game.state.turn = 1
	game.state.deck[0] = "spell_spark+"
	game.state.modifiers = {"spellPower": 20}
	if not game.choose("right", game.issue_choice_token()) \
			or not game.choose("left", game.issue_choice_token()) \
			or game.state.phase != "BATTLE_PENDING":
		return _fail("upgraded mission did not reach battle")
	var request: Dictionary = game.battle_request()
	var plan: Dictionary = BattlePlanResolver.new(Registry.new()).resolve_persisted(
		game.state)
	if plan.get("launchAuthorized") != true \
			or plan.get("deck", [])[0] != "spell_spark+" \
			or request.get("playerSnapshot", {}).get("modifiers", {}).get(
				"spellPower") != 20:
		return _fail("upgraded battle plan or story modifier was lost")
	var combat = CombatDomain.new(Registry.new())
	if not combat.load_persisted_request(request, plan) \
			or combat.state.player.atkMod != 1:
		return _fail("upgraded battle could not load current deck or source power")
	combat.state.hand = ["spell_spark+"]
	combat.state.qi = 5
	var hp_before := int(combat.state.enemy.hp)
	if not combat.play_card(0) or combat.state.hand.has("spell_spark+") \
			or int(combat.state.enemy.hp) >= hp_before:
		return _fail("upgraded card could not be played")
	var hand: HBoxContainer = HandUI.new()
	root.add_child(hand)
	hand.render_hand(Registry.new(), ["spell_spark+"], 5, "PLAYER_TURN", false)
	var button: Button = hand.get_node_or_null("Card_0_spell_spark+")
	var selected: Array = []
	hand.card_selected.connect(func(index: int) -> void: selected.append(index))
	if button == null or button.disabled \
			or button.get_node("CardName").text != upgraded.name \
			or button.get_node("SourceCardArt").texture == null:
		return _fail("upgraded card hand view could not render")
	button.pressed.emit()
	if selected != [0]:
		return _fail("upgraded card hand view did not submit selection")
	hand.free()
	var context: Dictionary = StageRouter.new(Registry.new()).resolve_choice(
		"f_mission", "right", request.get("pendingResolution", {}).get(
			"combatCard", {}), String(request.encounterInstanceId),
		request.get("pendingResolution", {}), String(request.path), String(request.realm))
	context["deck"] = plan.deck.duplicate(true)
	var stage: Control = load("res://scenes/duel_stage_mission_2d.tscn").instantiate()
	if context.is_empty() or not stage.bind_stage_context(context):
		return _fail("upgraded card stage could not bind")
	root.add_child(stage)
	if not stage.has_hd2d_assets() or not stage.present_action({
		"type": "CARD_PLAY", "cardId": "spell_spark+",
		"effects": [{"type": "damage", "hpLoss": 1}], "victory": false}):
		return _fail("upgraded card source action was missing")
	await stage.presentation_finished
	stage.call_deferred("free")
	await process_frame
	await process_frame
	print("NONCOMBAT_UPGRADED_BATTLE_CARD_PASS definition=true plan=true modifier=true play=true hand=true stage=true")
	quit(0)
