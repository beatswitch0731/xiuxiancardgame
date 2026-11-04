extends SceneTree

const Registry = preload("res://scripts/runtime_data_registry.gd")
const Domain = preload("res://scripts/noncombat_domain.gd")
const RunSession = preload("res://scripts/noncombat_run_session.gd")
const Resolver = preload("res://scripts/battle_plan_resolver.gd")
const Combat = preload("res://scripts/combat_domain.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	for case in [{"direction": "right", "card": "spell_tide"},
			{"direction": "up", "card": "spell_nuke"}]:
		var save_path := "user://tests/mountain_spell_%s_%d.json" % [case.card,
			Time.get_ticks_usec()]
		var game = Domain.new(Registry.new(), RunSession.new(save_path))
		if not game.start("spell"):
			return _fail("spell opening failed")
		for direction in ["right", "right", "left", "left", "left"]:
			if not game.choose(direction, game.issue_choice_token()):
				return _fail("spell first fight path failed")
		if not game.submit_battle_result(_first_result(game.battle_request())) \
				or not game.choose(case.direction, game.issue_choice_token()):
			return _fail("spell reward choice failed: " + case.card)
		if game.state.phase == "FLOW_PENDING" and not game.resume_flow():
			return _fail("spell continuation failed")
		if game.state.phase == "MILESTONE_PENDING" and not game.choose("left", game.issue_choice_token()):
			return _fail("spell milestone failed")
		if game.state.currentCardId != "q_mountain_shadow_approach" \
				or not game.choose("left", game.issue_choice_token()) \
				or not game.choose("left", game.issue_choice_token()):
			return _fail("spell mountain warning failed")
		var restored = Domain.new(Registry.new(), RunSession.new(save_path))
		if not restored.restore():
			return _fail("spell pending save did not restore")
		var request: Dictionary = restored.battle_request()
		var plan: Dictionary = Resolver.new(Registry.new()).resolve_persisted(restored.state)
		if not request.get("playerSnapshot", {}).get("battleLoadout", {}).get(
				"deck", []).has(case.card) or plan.get("launchAuthorized") != true:
			return _fail("spell alternate reward did not enter an authorized mountain fight")
		var combat = Combat.new(Registry.new())
		if not combat.load_persisted_request(request, plan):
			return _fail("spell alternate reward fight could not load")
		# Fix the draw at a public play_card boundary after a real persisted
		# handoff. The random starting hand is irrelevant to these effect rules.
		combat.state["hand"] = [case.card]
		combat.state["drawPile"] = ["spell_spark", "spell_ward"]
		combat.state["discardPile"] = []
		combat.state["playerStatus"]["spell_seal"] = 2 if case.card == "spell_tide" else 3
		if case.card == "spell_nuke":
			combat.state["player"]["hp"] = combat.state["player"]["maxHp"]
		var before_hp: int = combat.state["player"]["hp"]
		if not combat.play_card(0):
			return _fail("source spell reward could not play: " + case.card)
		if case.card == "spell_tide":
			if combat.state["hand"].size() != 2 or not combat.state["drawPile"].is_empty() \
					or combat.state["playerStatus"]["spell_seal"] != 2:
				return _fail("spell tide did not draw once per source seal")
		else:
			if combat.state["player"]["hp"] != maxi(0, before_hp - 3) \
					or combat.state["playerStatus"]["spell_seal"] != 0 \
					or combat.state["enemy"]["hp"] != 0 \
					or combat.state["outcome"] != "victory":
				return _fail("spell nuke backlash, seal consumption or damage differs " +
					"player=" + str(combat.state["player"]["hp"]) + "/" + str(before_hp) +
					" seal=" + str(combat.state["playerStatus"]["spell_seal"]) +
					" enemy=" + str(combat.state["enemy"]["hp"]) +
					" outcome=" + str(combat.state["outcome"]))
			var lethal = Combat.new(Registry.new())
			if not lethal.load_persisted_request(request, plan):
				return _fail("spell nuke lethal boundary could not load")
			lethal.state["hand"] = ["spell_nuke"]
			lethal.state["player"]["hp"] = 3
			lethal.state["playerStatus"]["spell_seal"] = 3
			if not lethal.play_card(0) or lethal.state["phase"] != "DEFEAT" \
					or lethal.state["outcome"] != "defeat":
				return _fail("lethal backlash did not keep source defeat precedence")
			var cycle = Combat.new(Registry.new())
			if not cycle.load_persisted_request(request, plan):
				return _fail("spell cycle damage boundary could not load")
			cycle.state["hand"] = ["spell_nuke"]
			cycle.state["playerStatus"]["spell_seal"] = 3
			cycle.state["pathCombatState"]["cardSequence"] = ["spell_spark", "spell_ward"]
			cycle.state["enemy"]["hp"] = 100
			cycle.state["enemy"]["maxHp"] = 100
			cycle.state["enemy"]["defPower"] = 0
			cycle.state["enemy"]["block"] = 0
			cycle.state["player"]["atkMod"] = 0
			if not cycle.play_card(0) or cycle.state["enemy"]["hp"] != 84:
				return _fail("spell cycle bonus must follow nuke multiplier; hp=" +
					str(cycle.state["enemy"]["hp"]))
	print("NONCOMBAT_MOUNTAIN_SPELL_REWARDS_PASS tide=true nuke=true lethal_backlash=true cycle_damage=true source_decks=true")
	quit(0)


func _first_result(request: Dictionary) -> Dictionary:
	return {"contractVersion": 2, "encounterInstanceId": request.encounterInstanceId,
		"sourceCardId": request.sourceCardId, "encounterId": request.encounterId,
		"sourceContentHash": request.sourceContentHash, "outcome": "victory",
		"combatReceipt": "combat:" + String(request.encounterInstanceId),
		"postBattleState": {"encounterInstanceId": request.encounterInstanceId,
			"terminal": true, "combatPhase": "VICTORY"}}


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
