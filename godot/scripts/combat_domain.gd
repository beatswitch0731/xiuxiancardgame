class_name CombatDomain
extends RefCounted

signal changed(event: Dictionary)

var data: RefCounted
var state: Dictionary = {}
var input_locked := false
var _rng := RandomNumberGenerator.new()
var _replay_random_values: Array = []
var _replay_random_cursor := 0
var _replay_random_active := false
var _path_archetype: Dictionary = {}
var _pending_path_qi := 0
var _pending_path_block := 0
const BrowserCombatSemantics = preload("res://scripts/noncombat_browser_combat_semantics.gd")


func _init(registry: RefCounted) -> void:
	data = registry
	_rng.randomize()


func set_replay_random_values(values: Array) -> bool:
	# The browser's recorded Math.random values are only an input to parity
	# replay. Production battles continue to use Godot's own random source.
	for value in values:
		if not value is float and not value is int or float(value) < 0.0 or float(value) >= 1.0:
			return false
	_replay_random_values = values.duplicate()
	_replay_random_cursor = 0
	_replay_random_active = true
	return true


func replay_random_remaining() -> int:
	return _replay_random_values.size() - _replay_random_cursor


func _random_unit() -> float:
	if not _replay_random_active:
		return _rng.randf()
	var index := _replay_random_cursor
	_replay_random_cursor += 1
	if index < _replay_random_values.size():
		return float(_replay_random_values[index])
	push_error("Browser replay random values exhausted at call " + str(index))
	return _rng.randf()


func _shuffle_cards(cards: Array) -> void:
	# DeckCombatSystem._shuffle uses Fisher–Yates and Math.random per swap.
	# Keep the algorithm identical so a recorded random tape can be compared.
	for index in range(cards.size() - 1, 0, -1):
		var other := int(floor(_random_unit() * float(index + 1)))
		var held = cards[index]
		cards[index] = cards[other]
		cards[other] = held


func load_m0_opening() -> bool:
	var evidence: Dictionary = data.read_json("fixtures/m0_desktop_opening.json")
	if evidence.is_empty() or evidence.get("phase") != "PLAYER_TURN":
		return false
	var encounter: Dictionary = data.get_first_encounter()
	if encounter.is_empty():
		return false
	var path_config: Dictionary = data.read_json("data/config/path_archetypes.json")
	var available: Array = path_config.get("paths", {}).get("sword", {}).get("archetypes", [])
	if available.is_empty() or not available[0] is Dictionary:
		return false
	_path_archetype = available[0]
	var hand: Array = evidence["hand"].duplicate()
	var draw_pile: Array = evidence["masterDeck"].duplicate()
	for card_id in hand:
		draw_pile.erase(card_id)
	state = {
		"active": true, "phase": evidence["phase"], "turn": evidence["turn"],
		"qi": evidence["qi"], "maxQi": 3,
		"player": evidence["player"].duplicate(true),
		"enemy": evidence["enemy"].duplicate(true),
		"enemyIntent": evidence["enemyIntent"].duplicate(true),
		"hand": hand, "drawPile": draw_pile,
		"discardPile": [], "exhaustPile": [],
		"playerStatus": {}, "enemyStatus": {}, "playerStatusesAppliedByEnemy": [],
		"nextTurnDrawPenalty": 0,
		"encounterId": encounter["id"], "outcome": "",
		"pathCombatState": {"version": 1, "archetypeId": _path_archetype["id"],
			"lastType": null, "sequence": [], "cardSequence": [], "cardsThisTurn": [],
			"triggeredThisTurn": [], "turnOpen": true},
	}
	changed.emit({"type": "LOADED_M0_RUNTIME_STATE"})
	return true


func load_persisted_request(request: Dictionary, plan: Dictionary) -> bool:
	# The desktop story owns the persisted request. Rule probes may authorize
	# a stage in isolation; production scene readiness remains a separate gate.
	var path_id := String(request.get("path", ""))
	var encounter_ids := {"sword": "enc_trial_sword_swift", "spell": "enc_trial_spell_seal",
		"body": "enc_trial_body_iron", "pill": "enc_trial_pill_poison"}
	var teaching: bool = encounter_ids.get(path_id) == request.get("encounterId") \
		and request.get("sourceCardId") == "encounter_card_" + String(request.get("encounterId", ""))
	var cadence_catalog: bool = request.get("realm") in [
		"foundation", "golden", "nascent", "deity", "tribulation"] \
		and request.get("encounterId") is String \
		and request.get("sourceCardId") == "encounter_card_" + request["encounterId"]
	var faction: bool = request.get("realm") == "foundation" \
		and request.get("encounterId") == "enc_faction_wumeng_elite" \
		and request.get("sourceCardId") == "faction_wumeng_gatekeeper_call" \
		and request.get("direction") == "left"
	var companion: bool = request.get("realm") == "golden" \
		and request.get("encounterId") == "enc_companion_jian_linger_tomb" \
		and request.get("sourceCardId") == "comp_jian_linger_jle_8_sword_tomb_old_master" \
		and request.get("direction") == "left"
	var mountain: bool = request.get("encounterId") == "enc_patrol_qi_mountain_shadow" \
		and request.get("sourceCardId") == "q_mountain_shadow_approach"
	var whitefox: bool = request.get("encounterId") == null \
		and request.get("sourceCardId") == "q_whiteFox_3" \
		and request.get("questId") == "white_fox_line"
	var fellow: bool = request.get("encounterId") == null \
		and request.get("sourceCardId") == "q_fellow" \
		and request.get("direction") == "right"
	var mission: bool = request.get("encounterId") == null \
		and request.get("sourceCardId") == "f_mission" \
		and request.get("direction") == "right"
	var bandit: bool = request.get("encounterId") == null \
		and request.get("sourceCardId") == "ds_female_bandit" \
		and request.get("direction") == "left"
	var nascent: bool = request.get("encounterId") == null \
		and request.get("sourceCardId") in ["n_hunt", "ar_boss"] \
		and request.get("direction") == "left"
	var trial: bool = request.get("encounterId") == null \
		and request.get("sourceCardId") == "it_combat" \
		and request.get("direction") == "left"
	var qi_gate: bool = request.get("encounterId") == "ch_qi_100" \
		and request.get("sourceCardId") == "ch_qi_100" \
		and request.get("direction") == "left"
	var foundation_gate: bool = request.get("encounterId") == "ch_foundation_100" \
		and request.get("sourceCardId") == "ch_foundation_100" \
		and request.get("direction") == "left"
	var golden_gate: bool = request.get("encounterId") == "ch_golden_100" \
		and request.get("sourceCardId") == "ch_golden_100" \
		and request.get("direction") == "left"
	var nascent_gate: bool = request.get("encounterId") == "ch_nascent_100" \
		and request.get("sourceCardId") == "ch_nascent_100" \
		and request.get("direction") == "left"
	var deity_gate: bool = request.get("encounterId") == "ch_deity_100" \
		and request.get("sourceCardId") == "ch_deity_100" \
		and request.get("direction") == "left"
	var tribulation_gate: bool = request.get("encounterId") == "ch_tribulation_100" \
		and request.get("sourceCardId") == "ch_tribulation_100" \
		and request.get("direction") == "left"
	var dungeon_boss: bool = request.get("encounterId") == null \
		and request.get("sourceCardId") == "realm_guardian" \
		and request.get("direction") in ["left", "right"]
	var village: bool = request.get("encounterId") == null \
		and request.get("sourceCardId") == "thread_ab_village_3" \
		and request.get("threadId") == "abandoned_village" \
		and request.get("direction") in ["left", "right"]
	var sword_tomb: bool = request.get("encounterId") == null \
		and request.get("sourceCardId") == "thread_sword_tomb_2" \
		and request.get("threadId") == "sword_tomb_trial" \
		and request.get("direction") in ["left", "right"]
	var last_lesson: bool = request.get("encounterId") == null \
		and request.get("sourceCardId") == "thread_last_lesson_n3" \
		and request.get("threadId") == "bairen_last_lesson" \
		and request.get("direction") == "left" \
		and request.get("realm") in ["deity", "tribulation"]
	var sword_quest: bool = request.get("encounterId") == null \
		and request.get("sourceCardId") == "q_sword_3" \
		and request.get("questId") == "sword_legacy" \
		and request.get("direction") in ["left", "right"]
	var sequential := whitefox or fellow or mission or bandit or nascent or trial or dungeon_boss or village or sword_tomb or sword_quest or golden_gate
	var life_id := String(request.get("lifeId", ""))
	var life_count := life_id.get_slice(":", 2)
	var valid_life := life_count.is_valid_int() and int(life_count) >= 0 \
		and life_id == "%s:life:%s" % [String(request.get("slotId", "")), life_count]
	if not encounter_ids.has(path_id) \
		or not teaching and not cadence_catalog and not faction and not companion and not mountain and not sequential and not last_lesson and not qi_gate and not foundation_gate and not nascent_gate and not deity_gate and not tribulation_gate \
		or request.get("realm") != ("tribulation" if trial or tribulation_gate else ("deity" if deity_gate or last_lesson else ("nascent" if nascent or nascent_gate else ("golden" if golden_gate or bandit or companion else (
			"foundation" if sword_quest or mission or dungeon_boss or foundation_gate or faction else "qi"))))) and not (last_lesson and request.get("realm") == "tribulation") and not cadence_catalog \
			or teaching and request.get("baseDecisionIndex") not in [3, 5] \
			or not valid_life or teaching and life_count != "0" \
			or plan.get("sourceAuthenticated") != true \
			or plan.get("launchAuthorized") != true \
			or plan.get("encounterInstanceId") != request.get("encounterInstanceId") \
			or plan.get("encounterId") != request.get("encounterId") \
			or plan.get("sourceCardId") != request.get("sourceCardId") \
			or plan.get("path") != path_id:
		return false
	var snapshot: Dictionary = request.get("playerSnapshot", {})
	var loadout: Dictionary = snapshot.get("battleLoadout", {})
	var deck: Array = loadout.get("deck", [])
	if deck != plan.get("deck") or deck.is_empty():
		return false
	if sequential or last_lesson or qi_gate or foundation_gate or nascent_gate or deity_gate or tribulation_gate or cadence_catalog:
		var resolution: Dictionary = request.get("pendingResolution", {})
		if resolution.get("combatCard", {}).get("enemy") != plan.get("enemy") \
				or (resolution.get("choice", {}).get("enemy") if whitefox or sword_quest or bandit or last_lesson or qi_gate or foundation_gate or golden_gate or nascent_gate or deity_gate or tribulation_gate or cadence_catalog else \
					resolution.get("sourceCard", {}).get("enemy")) != plan.get("enemy"):
			return false
	else:
		var encounter: Dictionary = {}
		for row in data.read_json("data/combat/encounters.json").get("encounters", []):
			if row is Dictionary and row.get("id") == request["encounterId"]:
				encounter = row
				break
		if encounter.is_empty() or (teaching or faction or companion) and encounter.get("enemy") != plan.get("enemy") \
				or mountain and request.get("pendingResolution", {}).get("combatCard", {}).get(
					"enemy") != plan.get("enemy"):
			return false
	var source_enemy: Dictionary = plan["enemy"]
	var boss_phases: Array = source_enemy.get("phases", []) if dungeon_boss else []
	if dungeon_boss:
		if boss_phases.size() != 3 or not boss_phases[0] is Dictionary:
			return false
		source_enemy = boss_phases[0].duplicate(true)
	var template: Dictionary = {}
	var template_id: Variant = source_enemy.get("id") if whitefox else source_enemy.get("templateId")
	if qi_gate or foundation_gate or golden_gate or nascent_gate or deity_gate or tribulation_gate or bandit or last_lesson:
		template = source_enemy.duplicate(true)
	else:
		for row in data.read_json("data/cards/battle_cards.json").get("enemies", []):
			if row is Dictionary and row.get("id") == template_id:
				template = row
				break
	if template.is_empty() or sequential and (not template.get("intents") is Array \
			or template.get("intents", []).is_empty()) \
			or not sequential and not source_enemy.get("planGraph") is Dictionary \
				and not template.get("planGraph") is Dictionary:
		return false
	var graph: Dictionary = {}
	var initial := ""
	if not sequential:
		graph = (source_enemy["planGraph"] if source_enemy.get("planGraph") is Dictionary \
			else template["planGraph"]).duplicate(true)
		for transition in graph.get("transitions", []):
			if transition is Dictionary and transition.get("from") is String:
				transition["from"] = [transition["from"]]
		template = template.duplicate(true)
		template["planGraph"] = graph
		initial = String(graph.get("initialState", ""))
		if not graph.get("states", {}).get(initial) is Dictionary:
			return false
	var path_config: Dictionary = data.read_json("data/config/path_archetypes.json")
	var archetypes: Array = path_config.get("paths", {}).get(path_id, {}).get("archetypes", [])
	if archetypes.is_empty() or not archetypes[0] is Dictionary:
		return false
	_path_archetype = archetypes[0]
	var attrs: Dictionary = snapshot.get("attributes", {})
	var modifiers: Dictionary = snapshot.get("modifiers", {})
	var passives: Dictionary = snapshot.get("legacyPassives", {})
	var path_passives_raw: Variant = snapshot.get("pathSkillPassives", {})
	if not path_passives_raw is Dictionary:
		return false
	var path_passives: Dictionary = path_passives_raw
	var maximum := int(snapshot.get("maxHealth", 0))
	var health := int(attrs.get("health", 0))
	if maximum <= 0 or health <= 0 or health > maximum:
		return false
	# DeckCombatSystem._combatVitalityBudget and _buildPlayerAuthority.
	var vitality := 4
	var ratio := clampf(float(health) / float(maximum), 0.0, 1.0)
	var combat_health := clampi(int(ceil(float(vitality) * (0.35 + ratio * 0.65))), 1, vitality)
	var story_attack := int(modifiers.get("swordAtk", 0)) + int(modifiers.get("spellPower", 0)) \
		+ int(modifiers.get("iceAtk", 0)) + int(modifiers.get("rawPower", 0)) \
		+ int(modifiers.get("heavenEnemyDamage", 0))
	var player := {"hp": combat_health, "maxHp": vitality,
		"block": maxi(0, int(loadout.get("pathOpening", {}).get("combatOpeningBlock", 0))
			+ int(passives.get("combatStartBlock", 0)))
			+ (mini(1, int(floor(float(vitality) * 0.25))) if path_id == "body" else 0),
		"aura": maxi(0, int(attrs.get("aura", 0))),
		"atkMod": mini(5, int(floor(float(story_attack) / 20.0))),
		"defMod": mini(3, int(floor(float(modifiers.get("damageReduction", 0)) / 20.0)))
			+ int(path_passives.get("def", 0)),
		"critRate": mini(20, int(modifiers.get("combat_skill", 0)) * 5)
			+ int(passives.get("critRate", 0)) + int(path_passives.get("critRate", 0)),
		"daoHeart": int(attrs.get("daoHeart", 0)), "realm": request.get("realm"),
		"lowHpAtkBonus": int(path_passives.get("lowHpAtkBonus", 0)),
		"lowHpDamageBonus": int(passives.get("lowHpDamageBonus", 0)),
		"pillBonus": int(passives.get("pillBonus", 0))}
	var enemy := {"name": source_enemy["name"], "hp": int(source_enemy["hp"]),
		"maxHp": int(source_enemy["hp"]), "block": 0,
		"tier": int(source_enemy.get("tier", 1)),
		"atkPower": int(source_enemy.get("atk", 1)),
		"defPower": int(source_enemy.get("def", 0)),
		"def": template.duplicate(true), "intentIndex": 0,
			"factionId": source_enemy.get("factionId") if fellow or nascent or faction else null,
		"realm": request.get("realm")}
	if foundation_gate:
		var rules: Dictionary = request.get("pendingResolution", {}).get(
			"combatCard", {}).get("combatRules", {})
		var base_hp := int(rules.get("baseHp", source_enemy.get("hp", 0)))
		var minimum_hp := maxi(1, int(rules.get("minimumHp", 1)))
		var reduction := maxi(0, int(rules.get("daoHeartHpReductionPerPoint", 0)))
		var final_hp := maxi(minimum_hp, base_hp - int(attrs.get("daoHeart", 0)) * reduction)
		var counter: Dictionary = rules.get("counter", {})
		if snapshot.get("flags", {}).get(counter.get("flag")) == true:
			player["block"] = int(player["block"]) + maxi(0, int(counter.get("openingBlock", 0)))
			final_hp = maxi(2, final_hp - maxi(0, int(counter.get("enemyHpReduction", 0))))
			enemy["atkPower"] = maxi(1, int(enemy["atkPower"]) - maxi(0,
				int(counter.get("enemyAttackReduction", 0))))
		enemy["hp"] = final_hp
		enemy["maxHp"] = final_hp
	if golden_gate:
		var rules: Dictionary = request.get("pendingResolution", {}).get(
			"combatCard", {}).get("combatRules", {})
		var array: Dictionary = rules.get("counters", {}).get("lightningArray", {})
		if rules.get("turnCycle", {}).get("order") != ["yang", "yin"] \
				or not template.get("intents") is Array:
			return false
		if snapshot.get("flags", {}).get(array.get("flag")) == true:
			player["block"] = int(player["block"]) + maxi(0,
				int(array.get("openingBlock", 0)))
	if nascent_gate:
		var backlash: Dictionary = request.get("pendingResolution", {}).get(
			"combatCard", {}).get("combatRules", {}).get("attackBacklash", {})
		var counter: Dictionary = backlash.get("counter", {})
		if backlash.get("triggerCardType") != "attack" \
				or int(backlash.get("damage", 0)) <= 0 \
				or counter.get("flag") != "used_deity_pill":
			return false
		if snapshot.get("flags", {}).get(counter.flag) == true:
			enemy["hp"] = maxi(1, int(enemy["hp"]) - maxi(0,
				int(counter.get("enemyHpReduction", 0))))
			enemy["maxHp"] = enemy["hp"]
	if deity_gate:
		var rules: Dictionary = request.get("pendingResolution", {}).get(
			"combatCard", {}).get("combatRules", {})
		var karma: Dictionary = rules.get("karmaDamage", {})
		var counter: Dictionary = rules.get("counter", {})
		if karma.get("attribute") != "karmaBad" or int(karma.get("perPoints", 0)) <= 0 \
				or int(karma.get("damagePerStep", -1)) < 0 \
				or counter.get("flag") != "used_relic_shield":
			return false
		if snapshot.get("flags", {}).get("used_relic_shield") == true:
			player["block"] = int(player["block"]) + maxi(0, int(counter.get("openingBlock", 0)))
			enemy["atkPower"] = maxi(1, int(enemy["atkPower"]) - maxi(0,
				int(counter.get("enemyAttackReduction", 0))))
	var intent: Dictionary = {}
	if sequential:
		enemy["planRuntime"] = null
		if dungeon_boss and template.get("randomIntents") == true:
			intent = template["intents"][int(floor(_random_unit() * template["intents"].size()))].duplicate(true)
		else:
			intent = template["intents"][0].duplicate(true)
			enemy["intentIndex"] = 1
	else:
		enemy["planRuntime"] = {"version": 1, "planId": graph["planId"],
			"currentState": initial, "intentState": initial, "transitionSequence": 0,
			"lastTransition": null, "lastReaction": null,
			"turnMemory": {"turn": 1, "cardsPlayed": 0, "qiSpent": 0,
				"qiGained": 0, "qiRemaining": 3, "cardTypes": [], "playedCards": [],
				"consecutiveType": null, "consecutiveCount": 0, "consumedSignals": []}}
		var initial_state: Dictionary = graph["states"][initial]
		intent = initial_state["intent"].duplicate(true)
		intent.merge({"planId": graph["planId"], "planState": initial,
			"planStateLabel": initial_state.get("label", ""),
			"planCue": initial_state.get("cue", ""), "transitionCause": null,
			"presentationVariantId": initial})
	if golden_gate:
		intent = _golden_turn_cycle_intent(
			request.pendingResolution.combatCard.combatRules, template.intents, 1)
		if intent.is_empty():
			return false
	var draw_pile: Array = deck.duplicate(true)
	var story_assist: Dictionary = {}
	if last_lesson:
		story_assist = request.get("pendingResolution", {}).get("choice", {}).get(
			"combatPresentation", {}).get("storyAssist", {})
		var assist_card := String(story_assist.get("cardId", ""))
		if story_assist.get("id") != "last_lesson_jian_linger_assist" \
				or story_assist.get("compId") != "jian_linger" \
				or story_assist.get("openingHand") != true \
				or assist_card != "comp_jian_linger_ice_resonance" \
				or data.get_battle_card(assist_card).is_empty():
			return false
		if not draw_pile.has(assist_card):
			draw_pile.append(assist_card)
	_shuffle_cards(draw_pile)
	if last_lesson:
		draw_pile.erase(story_assist.cardId)
		draw_pile.append(story_assist.cardId)
	var hand: Array = []
	while hand.size() < 5 and not draw_pile.is_empty():
		hand.append(draw_pile.pop_back())
	state = {"active": true, "phase": "PLAYER_TURN", "turn": 1,
		"qi": 3, "maxQi": 3, "player": player, "enemy": enemy,
		"enemyIntent": intent, "hand": hand, "drawPile": draw_pile,
		"discardPile": [], "exhaustPile": [], "playerStatus": {},
		"enemyStatus": {}, "playerStatusesAppliedByEnemy": [], "nextTurnDrawPenalty": 0,
		"encounterId": request["encounterId"], "outcome": "",
		"pathCombatState": {"version": 1, "archetypeId": _path_archetype["id"],
			"lastType": null, "sequence": [], "cardSequence": [],
			"cardsThisTurn": [], "triggeredThisTurn": [], "turnOpen": true}}
	if qi_gate:
		var rules: Dictionary = request.pendingResolution.combatCard.get("combatRules", {})
		var counter: Dictionary = rules.get("counter", {})
		if rules.get("victoryCondition") != "survive_turns" \
				or int(rules.get("surviveTurns", 0)) != 3 \
				or counter.get("flag") != "used_foundation_pill" \
				or float(counter.get("incomingDamageMultiplier", 0.0)) != 0.5:
			return false
		state["surviveTurns"] = int(rules["surviveTurns"])
		state["incomingDamageMultiplier"] = float(counter["incomingDamageMultiplier"]) \
			if snapshot.get("flags", {}).get(counter["flag"]) == true else 1.0
	if last_lesson:
		state["storyAssist"] = story_assist.duplicate(true)
		state["storyAssistPlayed"] = false
	if dungeon_boss:
		state["bossPhases"] = boss_phases.duplicate(true)
		state["bossPhaseIndex"] = 0
	if golden_gate:
		state["turnCycleRules"] = request.pendingResolution.combatCard.combatRules.duplicate(true)
		state["nascentPillPiercingCounter"] = snapshot.get("flags", {}).get(
			"used_nascent_pill") == true
	if nascent_gate:
		state["attackBacklashRules"] = request.pendingResolution.combatCard.combatRules.attackBacklash.duplicate(true)
		state["deityPillBacklashCounter"] = snapshot.get("flags", {}).get(
			"used_deity_pill") == true
	if deity_gate:
		state["karmaDamageRules"] = request.pendingResolution.combatCard.combatRules.karmaDamage.duplicate(true)
		state["badKarma"] = int(attrs.get("karmaBad", 0))
	if tribulation_gate:
		var judgment: Dictionary = request.pendingResolution.combatCard.get(
			"combatRules", {}).get("karmaJudgment", {})
		if judgment.get("timing") != "after_draw" \
				or judgment.get("goodAttribute") != "karmaGood" \
				or judgment.get("badAttribute") != "karmaBad":
			return false
		state["karmaJudgmentRules"] = judgment.duplicate(true)
		state["goodKarma"] = int(attrs.get("karmaGood", 0))
		state["badKarma"] = int(attrs.get("karmaBad", 0))
		_apply_karma_judgment()
	changed.emit({"type": "LOADED_PERSISTED_REQUEST"})
	return true


func load_first_teaching_request(request: Dictionary, plan: Dictionary) -> bool:
	return load_persisted_request(request, plan)


func load_first_sword_request(request: Dictionary, plan: Dictionary) -> bool:
	# Keep the original entrypoint for existing sword battle callers.
	return load_persisted_request(request, plan)


func load_browser_first_sword_snapshot(snapshot: Dictionary,
		browser_authority: Dictionary, request: Dictionary) -> bool:
	if state.is_empty() or request.get("sourceCardId") \
			!= snapshot.get("originalCard", {}).get("id") \
			or request.get("encounterId") \
			!= snapshot.get("originalCard", {}).get("encounterId") \
			or not BrowserCombatSemantics.new().verify_first_sword_card(
				snapshot, browser_authority, data):
		return false
	for key in ["phase", "turn", "qi", "maxQi", "player", "enemy",
			"enemyIntent", "hand", "drawPile", "discardPile", "exhaustPile",
			"playerStatus", "enemyStatus", "playerStatusesAppliedByEnemy",
			"nextTurnDrawPenalty", "pathCombatState"]:
		if not snapshot.has(key):
			return false
	var hydrated: Dictionary = state.duplicate(true)
	for key in ["phase", "turn", "qi", "maxQi", "player", "enemy",
			"enemyIntent", "hand", "drawPile", "discardPile", "exhaustPile",
			"playerStatus", "enemyStatus", "playerStatusesAppliedByEnemy",
			"nextTurnDrawPenalty", "pathCombatState"]:
		hydrated[key] = snapshot[key].duplicate(true) if snapshot[key] is Dictionary \
			or snapshot[key] is Array else snapshot[key]
	hydrated["outcome"] = ""
	state = hydrated
	changed.emit({"type": "LOADED_BROWSER_COMBAT_SNAPSHOT"})
	return true


func play_card(hand_index: int) -> bool:
	if input_locked or not state.get("active", false) or state.get("phase") != "PLAYER_TURN":
		return false
	var hand: Array = state["hand"]
	if hand_index < 0 or hand_index >= hand.size():
		return false
	var card_id := String(hand[hand_index])
	var card: Dictionary = data.get_battle_card(card_id)
	if card.is_empty() or int(card.get("cost", 0)) > int(state["qi"]):
		return false
	# Refuse unported effect vocabulary before changing any authoritative state.
	for effect in card.get("effects", []):
		var supported := ["damage", "block", "status"]
		if _path_archetype.get("id") == "spell_cycle":
			supported.append_array(["draw", "draw_per_status", "backlash"])
		elif _path_archetype.get("id") == "pill_elixirfire":
			supported.append_array(["gain_qi", "heal"])
		if not effect is Dictionary or not String(effect.get("type", "")) in supported:
			return false
	var enemy_hp_before := int(state["enemy"]["hp"])
	var enemy_block_before := int(state["enemy"]["block"])
	var path_damage_bonus := _path_before_card(card)
	state["qi"] = int(state["qi"]) - int(card["cost"])
	hand.remove_at(hand_index)
	_record_plan_card(card)
	_for_card_plan_transition()
	var impacts: Array = []
	var backlash_rules: Dictionary = state.get("attackBacklashRules", {})
	if card.get("type") == backlash_rules.get("triggerCardType") \
			and not state.get("deityPillBacklashCounter", false):
		var backlash := maxi(0, int(backlash_rules.get("damage", 0)))
		if backlash > 0:
			var hp_before := int(state["player"]["hp"])
			state["player"]["hp"] = maxi(0, hp_before - backlash)
			impacts.append({"type": "backlash", "amount": hp_before - int(state["player"]["hp"])})
			if int(state["player"]["hp"]) <= 0:
				state["active"] = false
				state["phase"] = "DEFEAT"
				state["outcome"] = "defeat"
				state["pathCombatState"] = null
				if card.get("exhaust", false):
					state["exhaustPile"].append(card_id)
				else:
					state["discardPile"].append(card_id)
				changed.emit({"type": "CARD_PLAY", "cardId": card_id, "effects": impacts,
					"enemyHpBefore": enemy_hp_before, "enemyBlockBefore": enemy_block_before})
				changed.emit({"type": "DEFEAT"})
				return true
	for effect in card.get("effects", []):
		var kind := String(effect["type"])
		if kind == "damage":
			impacts.append(_damage_enemy(card, effect, path_damage_bonus))
			path_damage_bonus = 0
		elif kind == "block":
			var amount := int(effect.get("value", 0)) + _pending_path_block
			_pending_path_block = 0
			state["player"]["block"] = int(state["player"]["block"]) + amount
			impacts.append({"type": "block", "amount": amount})
		elif kind == "status":
			var target := String(effect.get("target", "player"))
			var status_key := "enemyStatus" if target == "enemy" else "playerStatus"
			var status_id := String(effect.get("statusId", ""))
			var statuses: Dictionary = state[status_key]
			var current := int(statuses.get(status_id, 0))
			var amount := int(effect.get("value", 0))
			if effect.has("maxStacks"):
				amount = maxi(0, mini(amount, int(effect["maxStacks"]) - current))
			statuses[status_id] = current + amount
			impacts.append({"type": "status", "target": target, "id": status_id, "amount": amount})
		elif kind == "draw":
			var before_draw := hand.size()
			for _draw_index in range(maxi(0, int(effect.get("value", 0)))):
				_draw_card()
			impacts.append({"type": "draw", "amount": hand.size() - before_draw})
		elif kind == "draw_per_status":
			var before_draw := hand.size()
			var stacks := maxi(0, int(state["playerStatus"].get(effect.get("statusId", ""), 0)))
			for _draw_index in range(stacks):
				_draw_card()
			impacts.append({"type": "draw", "amount": hand.size() - before_draw})
		elif kind == "backlash":
			var hp_before := int(state["player"]["hp"])
			state["player"]["hp"] = maxi(0, hp_before - maxi(0, int(effect.get("value", 0))))
			impacts.append({"type": "backlash", "amount": hp_before - int(state["player"]["hp"])})
			if int(state["player"]["hp"]) <= 0:
				state["active"] = false
				state["phase"] = "DEFEAT"
				state["outcome"] = "defeat"
				state["pathCombatState"] = null
		elif kind == "gain_qi":
			var qi_before := int(state["qi"])
			state["qi"] = mini(int(state["maxQi"]) + 5,
				qi_before + maxi(0, int(effect.get("value", 0))))
			impacts.append({"type": "gain_qi", "amount": int(state["qi"]) - qi_before})
		elif kind == "heal":
			var hp_before := int(state["player"]["hp"])
			var heal := maxi(0, int(effect.get("value", 0)))
			if card.get("tags", []).has("pill"):
				heal = int(floor(float(heal) * (1.0 +
					float(maxi(0, int(state["player"].get("pillBonus", 0)))) / 100.0)))
			state["player"]["hp"] = mini(int(state["player"]["maxHp"]), hp_before + heal)
			impacts.append({"type": "heal", "amount": int(state["player"]["hp"]) - hp_before})
	if _pending_path_qi > 0:
		state["qi"] = mini(int(state["maxQi"]) + 5, int(state["qi"]) + _pending_path_qi)
		_pending_path_qi = 0
	if card.get("exhaust", false):
		state["exhaustPile"].append(card_id)
	else:
		state["discardPile"].append(card_id)
	if state["enemy"].get("planRuntime") is Dictionary:
		var turn_memory: Dictionary = state["enemy"]["planRuntime"]["turnMemory"]
		turn_memory["qiRemaining"] = state["qi"]
		turn_memory["qiGained"] = maxi(0, int(state["qi"]) +
			int(turn_memory["qiSpent"]) - int(state["maxQi"]))
	var boss_advanced := false
	if state["active"] and int(state["enemy"]["hp"]) <= 0:
		state["enemy"]["hp"] = 0
		boss_advanced = _advance_boss_phase()
		if not boss_advanced:
			state["active"] = false
			state["phase"] = "VICTORY"
			state["outcome"] = "victory"
			# The browser ends PathArchetypeSystem's per-battle runtime at victory.
			state["pathCombatState"] = null
	changed.emit({"type": "CARD_PLAY", "cardId": card_id, "effects": impacts,
		"enemyHpBefore": enemy_hp_before, "enemyBlockBefore": enemy_block_before})
	if state.get("storyAssist", {}).get("cardId") == card_id:
		state["storyAssistPlayed"] = true
		changed.emit({"type": "STORY_ASSIST_COMMITTED", "cardId": card_id,
			"companionId": state.storyAssist.compId,
			"companionName": state.storyAssist.companionName,
			"unlockText": state.storyAssist.unlockText})
	if boss_advanced:
		changed.emit({"type": "BOSS_PHASE_CHANGED", "phase": state.bossPhaseIndex + 1,
			"total": state.bossPhases.size(), "enemy": state.enemy.duplicate(true)})
	if state["phase"] == "DEFEAT":
		changed.emit({"type": "DEFEAT"})
	return true


func flee() -> bool:
	if input_locked or not state.get("active", false) \
			or state.get("phase") not in ["PLAYER_TURN", "REACTION_OPEN"]:
		return false
	state["active"] = false
	state["phase"] = "FLEE"
	state["outcome"] = "flee"
	state["pathCombatState"] = null
	changed.emit({"type": "FLEE"})
	return true


func end_turn() -> bool:
	if input_locked or not state.get("active", false) or state.get("phase") != "PLAYER_TURN":
		return false
	state["pathCombatState"]["turnOpen"] = false
	state["pathCombatState"]["cardsThisTurn"] = []
	state["pathCombatState"]["triggeredThisTurn"] = []
	_transition_plan("player_reserved_resource")
	state["enemy"]["block"] = 0
	var hand: Array = state["hand"]
	while not hand.is_empty():
		state["discardPile"].append(hand.pop_back())
	state["phase"] = "REACTION_OPEN"
	changed.emit({"type": "REACTION_OPEN", "intent": state["enemyIntent"]})
	return true


func reaction_options() -> Array:
	if state.get("phase") != "REACTION_OPEN":
		return []
	var intent: Dictionary = state["enemyIntent"]
	var is_attack: bool = intent.get("type") == "attack"
	var qi := int(state["qi"])
	return [
		{"id": "TAKE_HIT", "label": "承受", "cost": 0, "available": true},
		{"id": "DEFLECT", "label": "偏斩", "cost": 2, "available": is_attack and not intent.get("piercing", false) and qi >= 2},
		{"id": "GUARD", "label": "格挡", "cost": 1, "available": is_attack and qi >= 1},
		{"id": "EVADE", "label": "闪避", "cost": 2, "available": is_attack and qi >= 2},
	]


func take_hit(resistance_roll: float = -1.0) -> bool:
	return choose_reaction("TAKE_HIT", resistance_roll)


func choose_reaction(reaction_id: String, resistance_roll: float = -1.0) -> bool:
	if not state.get("active", false) or state.get("phase") != "REACTION_OPEN":
		return false
	var selected: Dictionary = {}
	for option in reaction_options():
		if option["id"] == reaction_id:
			selected = option
			break
	if selected.is_empty() or not selected["available"]:
		return false
	state["qi"] = int(state["qi"]) - int(selected["cost"])
	var intent: Dictionary = state["enemyIntent"].duplicate(true)
	var player_hp_before := int(state["player"]["hp"])
	if state["enemy"].get("planRuntime") is Dictionary:
		state["enemy"]["planRuntime"]["lastReaction"] = reaction_id
	var poison := int(state["enemyStatus"].get("poison", 0))
	if poison > 0:
		var poison_damage := mini(3, poison)
		state["enemy"]["hp"] = maxi(0, int(state["enemy"]["hp"]) - poison_damage)
		state["enemyStatus"]["poison"] = maxi(0, poison - 1)
		if int(state["enemy"]["hp"]) <= 0:
			if _advance_boss_phase():
				changed.emit({"type": "POISON_TICK", "hpLoss": poison_damage})
				changed.emit({"type": "BOSS_PHASE_CHANGED", "phase": state.bossPhaseIndex + 1,
					"total": state.bossPhases.size(), "enemy": state.enemy.duplicate(true)})
				return true
			state["active"] = false
			state["phase"] = "VICTORY"
			state["outcome"] = "victory"
			state["pathCombatState"] = null
			changed.emit({"type": "POISON_TICK", "hpLoss": poison_damage})
			return true
		changed.emit({"type": "POISON_TICK", "hpLoss": poison_damage})
	var multiplier := 1.0
	if reaction_id == "GUARD":
		multiplier = 0.5
	elif reaction_id == "DEFLECT":
		multiplier = 0.8
		_transition_plan("deflected", false)
	elif reaction_id == "EVADE":
		multiplier = 0.0
		state["nextTurnDrawPenalty"] = 1
	if intent.get("type") == "attack":
		var enemy: Dictionary = state["enemy"]
		var player: Dictionary = state["player"]
		var attack := maxi(int(intent.get("value", 1)), int(enemy.get("atkPower", 1)))
		if int(enemy.get("tier", 0)) == 2:
			attack += 2
		if float(intent.get("multiplier", 1.0)) > 1.0:
			attack = int(ceil(float(attack) * float(intent["multiplier"])))
		attack = int(ceil(float(attack) * float(state.get("incomingDamageMultiplier", 1.0))))
		var karma_rules: Dictionary = state.get("karmaDamageRules", {})
		if not karma_rules.is_empty():
			attack += int(floor(float(maxi(0, int(state.get("badKarma", 0)))) /
				float(maxi(1, int(karma_rules.get("perPoints", 1)))))) * maxi(0,
				int(karma_rules.get("damagePerStep", 0)))
		if int(state["enemyStatus"].get("weak", 0)) > 0:
			attack = maxi(0, attack - 1)
		if int(state["playerStatus"].get("fortify", 0)) > 0:
			attack = maxi(0, attack - 1)
		var enemy_sword_intent := int(state["enemyStatus"].get("sword_intent", 0))
		if enemy_sword_intent > 0:
			attack += enemy_sword_intent
			state["enemyStatus"]["sword_intent"] = 0
		attack = int(ceil(float(attack) * multiplier))
		if int(state["playerStatus"].get("vulnerable", 0)) > 0:
			attack = int(ceil(float(attack) * 1.5))
		if int(state["enemyStatus"].get("weak", 0)) > 0:
			attack = int(floor(float(attack) * 0.75))
		var piercing: bool = intent.get("piercing", false) == true and state.get(
			"nascentPillPiercingCounter") != true
		if not piercing:
			attack = maxi(0, attack - maxi(0, int(player.get("defMod", 0))))
			var absorbed := mini(attack, int(player.get("block", 0)))
			player["block"] = int(player["block"]) - absorbed
			attack -= absorbed
		var dao_heart := int(player.get("daoHeart", 0))
		if attack > 0 and dao_heart >= 4:
			var chance := minf(0.5, 0.3 + float(dao_heart - 4) * 0.1)
			var roll := resistance_roll if resistance_roll >= 0.0 else _random_unit()
			if roll < chance:
				attack = maxi(0, attack - 1)
		player["hp"] = maxi(0, int(player["hp"]) - attack)
	elif intent.get("type") == "defend":
		state["enemy"]["block"] = int(state["enemy"]["block"]) + int(intent.get("value", 0))
	elif intent.get("type") == "buff" and intent.get("statusId") is String:
		var status_id: String = intent["statusId"]
		state["enemyStatus"][status_id] = int(state["enemyStatus"].get(status_id, 0)) \
			+ maxi(0, int(intent.get("value", 0)))
	elif intent.get("type") == "debuff" and intent.get("statusId") is String:
		var status_id: String = intent["statusId"]
		state["playerStatus"][status_id] = int(state["playerStatus"].get(status_id, 0)) \
			+ maxi(0, int(intent.get("value", 0)))
		if not state["playerStatusesAppliedByEnemy"].has(status_id):
			state["playerStatusesAppliedByEnemy"].append(status_id)
	if int(state["player"]["hp"]) <= 0:
		state["active"] = false
		state["phase"] = "DEFEAT"
		state["outcome"] = "defeat"
		changed.emit({"type": "ENEMY_ACTION", "intent": intent, "reactionId": reaction_id,
			"hpLoss": player_hp_before - int(state["player"]["hp"])})
		changed.emit({"type": "DEFEAT"})
		return true
	if int(state.get("surviveTurns", 0)) > 0 and int(state["turn"]) >= int(state["surviveTurns"]):
		state["active"] = false
		state["phase"] = "VICTORY"
		state["outcome"] = "victory"
		state["pathCombatState"] = null
		changed.emit({"type": "ENEMY_ACTION", "intent": intent, "reactionId": reaction_id,
			"hpLoss": player_hp_before - int(state["player"]["hp"])})
		changed.emit({"type": "VICTORY"})
		return true
	if state["enemy"].get("planRuntime") is Dictionary \
			and state["enemy"]["planRuntime"]["currentState"] == intent.get("planState"):
		_transition_plan("action_resolved", false)
	_start_turn()
	if reaction_id == "DEFLECT" and maxi(int(intent.get("value", 1)), int(state["enemy"].get("atkPower", 1))) >= 3:
		state["enemyStatus"]["vulnerable"] = int(state["enemyStatus"].get("vulnerable", 0)) + 1
	changed.emit({"type": "ENEMY_ACTION", "intent": intent, "reactionId": reaction_id,
		"hpLoss": player_hp_before - int(state["player"]["hp"])})
	return true


func _damage_enemy(card: Dictionary, effect: Dictionary, path_damage_bonus: int = 0) -> Dictionary:
	var damage := int(effect.get("value", 0))
	var player: Dictionary = state["player"]
	var enemy: Dictionary = state["enemy"]
	var player_status: Dictionary = state["playerStatus"]
	var enemy_status: Dictionary = state["enemyStatus"]
	var conditional_id := String(effect.get("conditional_status", ""))
	if not conditional_id.is_empty() and int(player_status.get(conditional_id, 0)) >= \
			int(effect.get("conditional_value", 1)):
		damage = damage * int(effect.get("conditional_multiply", 1)) \
			+ int(effect.get("conditional_add", 0))
		if effect.get("consume_status", false):
			player_status[conditional_id] = 0 if effect["consume_status"] is bool else maxi(0,
				int(player_status[conditional_id]) - int(effect["consume_status"]))
	damage += path_damage_bonus
	var hp_ratio := float(player.get("hp", 0)) / maxf(1.0,
		float(player.get("maxHp", 1)))
	var low_hp_multiplier := int(player.get("lowHpAtkBonus", 0))
	if low_hp_multiplier > 0 and hp_ratio <= 0.3:
		damage = int(floor(float(damage) * float(low_hp_multiplier)))
	var low_hp_flat := int(player.get("lowHpDamageBonus", 0))
	if low_hp_flat > 0 and hp_ratio <= 0.5:
		damage += low_hp_flat
	var crit_rate := int(player.get("critRate", 0))
	if crit_rate > 0 and _random_unit() * 100.0 < float(crit_rate):
		damage = int(floor(float(damage) * 1.5))
	if int(player_status.get("sword_intent", 0)) > 0 and not effect.has("conditional_status"):
		damage += int(player_status["sword_intent"])
		player_status["sword_intent"] = 0
	if int(player_status.get("weak", 0)) > 0:
		damage = int(floor(damage * 0.75))
	if int(enemy_status.get("vulnerable", 0)) > 0:
		damage = int(ceil(damage * 1.5))
	if int(enemy_status.get("opening", 0)) > 0 and card.get("type") == "attack":
		damage += 1
		enemy_status["opening"] = int(enemy_status["opening"]) - 1
	damage += maxi(0, int(player.get("atkMod", 0)))
	if int(enemy.get("defPower", 0)) > 0:
		damage = maxi(1, damage - int(enemy["defPower"]))
	var absorbed := mini(damage, int(enemy.get("block", 0)))
	enemy["block"] = int(enemy.get("block", 0)) - absorbed
	var hp_loss := maxi(0, damage - absorbed)
	enemy["hp"] = maxi(0, int(enemy["hp"]) - hp_loss)
	return {"type": "damage", "hpLoss": hp_loss, "blockSpent": absorbed}


func _path_before_card(card: Dictionary) -> int:
	# Read supported first-session rules from path_archetypes.json.
	var path: Dictionary = state["pathCombatState"]
	var kind := String(card.get("type", ""))
	var bonus := 0
	_pending_path_qi = 0
	_pending_path_block = 0
	for rule in _path_archetype.get("rules", []):
		if not rule is Dictionary:
			continue
		if rule.get("oncePerTurn", false) and path["triggeredThisTurn"].has(rule["id"]):
			continue
		if rule.get("cardType", kind) != kind:
			continue
		var matches := false
		if rule.get("condition") == "previous_type":
			matches = rule.get("previousType", "") == path["lastType"] \
				and (not rule.get("sameTurn", false) or not path["cardsThisTurn"].is_empty()) \
				and int(state["player"].get("block", 0)) >= int(rule.get("requiredBlock", 0))
		elif rule.get("condition") == "distinct_cards":
			var sequence: Array = path["cardSequence"].duplicate()
			sequence.append(card["id"])
			var count := int(rule.get("count", 3))
			sequence = sequence.slice(maxi(0, sequence.size() - count))
			var distinct := {}
			for card_id in sequence:
				distinct[card_id] = true
			matches = sequence.size() >= count and distinct.size() >= count
		elif rule.get("condition") == "block_min":
			matches = int(state["player"].get("block", 0)) >= int(rule.get("value", 1))
		elif rule.get("condition") == "repeat_type":
			var count := 1
			for previous_type in path["cardsThisTurn"]:
				if previous_type == kind:
					count += 1
			matches = count >= int(rule.get("count", 2))
		if not matches:
			continue
		bonus += int(rule.get("damageBonus", 0))
		_pending_path_block += int(rule.get("blockBonus", 0))
		_pending_path_qi += int(rule.get("gainQi", 0))
		if rule.get("oncePerTurn", false):
			path["triggeredThisTurn"].append(rule["id"])
	path["lastType"] = kind
	path["cardsThisTurn"].append(kind)
	path["sequence"].append(kind)
	path["cardSequence"].append(card["id"])
	while path["sequence"].size() > 4:
		path["sequence"].pop_front()
	while path["cardSequence"].size() > 4:
		path["cardSequence"].pop_front()
	return bonus


func _draw_card(ignore_hand_limit: bool = false) -> void:
	if not ignore_hand_limit and state["hand"].size() >= 5:
		return
	if state["drawPile"].is_empty() and not state["discardPile"].is_empty():
		state["drawPile"] = state["discardPile"].duplicate()
		state["discardPile"].clear()
		_shuffle_cards(state["drawPile"])
	if not state["drawPile"].is_empty():
		state["hand"].append(state["drawPile"].pop_back())


func _record_plan_card(card: Dictionary) -> void:
	if not state["enemy"].get("planRuntime") is Dictionary:
		return
	var memory: Dictionary = state["enemy"]["planRuntime"]["turnMemory"]
	var kind := String(card.get("type", "unknown"))
	memory["cardsPlayed"] = int(memory["cardsPlayed"]) + 1
	memory["qiSpent"] = int(memory["qiSpent"]) + int(card.get("cost", 0))
	memory["qiRemaining"] = state["qi"]
	memory["cardTypes"].append(kind)
	memory["playedCards"].append({"id": card["id"], "type": kind, "cost": card["cost"]})
	memory["consecutiveCount"] = int(memory["consecutiveCount"]) + 1 if memory["consecutiveType"] == kind else 1
	memory["consecutiveType"] = kind


func _for_card_plan_transition() -> void:
	var enemy: Dictionary = state["enemy"]
	if not enemy.get("planRuntime") is Dictionary:
		return
	var graph: Dictionary = enemy["def"].get("planGraph", {})
	var checked: Array = []
	for transition in graph.get("transitions", []):
		var cause := String(transition.get("when", ""))
		if cause not in ["player_overcommitted", "repeated_card_type"] or checked.has(cause):
			continue
		checked.append(cause)
		if _transition_plan(cause):
			return


func _transition_plan(cause: String, refresh_intent: bool = true) -> bool:
	var enemy: Dictionary = state["enemy"]
	if not enemy.get("planRuntime") is Dictionary:
		return false
	var runtime: Dictionary = enemy["planRuntime"]
	var graph: Dictionary = enemy["def"]["planGraph"]
	var memory: Dictionary = runtime["turnMemory"]
	for candidate in graph.get("transitions", []):
		if candidate.get("when") != cause or not candidate.get("from", []).has(runtime["currentState"]):
			continue
		if cause == "player_overcommitted" and (int(memory["cardsPlayed"]) < int(candidate.get("minCards", 2)) or int(memory["qiRemaining"]) > int(candidate.get("maxReservedQi", 0))):
			continue
		if cause == "repeated_card_type" and int(memory["consecutiveCount"]) < int(candidate.get("minConsecutive", 2)):
			continue
		if cause == "player_reserved_resource" and (int(memory["cardsPlayed"]) > int(candidate.get("maxCards", 0)) or int(memory["qiRemaining"]) < int(candidate.get("minReservedQi", 1))):
			continue
		var signal_key := "%s:%s:%s" % [int(state["turn"]), runtime["currentState"], cause]
		if memory["consumedSignals"].has(signal_key):
			return false
		var previous := String(runtime["currentState"])
		runtime["currentState"] = candidate["to"]
		runtime["transitionSequence"] = int(runtime["transitionSequence"]) + 1
		runtime["lastTransition"] = {"planId": runtime["planId"], "from": previous,
			"to": candidate["to"], "cause": cause, "turn": state["turn"],
			"sourceCardId": String(state["encounterId"]) \
				if String(state["encounterId"]).begins_with("ch_") \
				else "encounter_card_" + String(state["encounterId"]),
			"sequence": runtime["transitionSequence"]}
		memory["consumedSignals"].append(signal_key)
		if refresh_intent:
			_refresh_intent()
		return true
	return false


func _refresh_intent() -> void:
	if not state["enemy"].get("planRuntime") is Dictionary:
		return
	var runtime: Dictionary = state["enemy"]["planRuntime"]
	var plan_state: Dictionary = state["enemy"]["def"]["planGraph"]["states"][runtime["currentState"]]
	var intent: Dictionary = plan_state["intent"].duplicate(true)
	intent["planId"] = runtime["planId"]
	intent["planState"] = runtime["currentState"]
	intent["planStateLabel"] = plan_state.get("label", "")
	intent["planCue"] = plan_state.get("cue", "")
	intent["transitionCause"] = runtime["lastTransition"].get("cause") if runtime["lastTransition"] is Dictionary else null
	intent["presentationVariantId"] = runtime["currentState"]
	runtime["intentState"] = runtime["currentState"]
	state["enemyIntent"] = intent


func _advance_sequential_intent() -> void:
	var enemy: Dictionary = state["enemy"]
	var intents: Array = enemy.get("def", {}).get("intents", [])
	if intents.is_empty():
		return
	var used: Array = enemy.get("usedConditions", [])
	for authored in intents:
		if not authored is Dictionary or authored.get("condition", {}).get(
				"type") != "hp_below":
			continue
		var ratio := float(enemy.get("hp", 0)) / maxf(1.0,
			float(enemy.get("maxHp", 1)))
		if ratio <= float(authored["condition"].get("value", 0.0)) \
				and (not used.has(authored.get("desc")) or authored[
					"condition"].get("repeatable") == true):
			state["enemyIntent"] = authored.duplicate(true)
			if not used.has(authored.get("desc")):
				used.append(authored.get("desc"))
			enemy["usedConditions"] = used
			return
	var normal_intents: Array = intents.filter(func(intent: Variant) -> bool:
		return intent is Dictionary and not intent.has("condition"))
	if normal_intents.is_empty():
		return
	if enemy.get("def", {}).get("randomIntents") == true:
		state["enemyIntent"] = normal_intents[int(floor(
			_random_unit() * normal_intents.size()))].duplicate(true)
		return
	var index := int(enemy.get("intentIndex", 0))
	state["enemyIntent"] = normal_intents[index % normal_intents.size()].duplicate(true)
	enemy["intentIndex"] = index + 1


func _golden_turn_cycle_intent(rules: Dictionary, authored: Array,
		turn_number: int) -> Dictionary:
	var cycle: Dictionary = rules.get("turnCycle", {})
	var order: Array = cycle.get("order", [])
	if order != ["yang", "yin"] or turn_number <= 0:
		return {}
	var phase_id := String(order[(turn_number - 1) % order.size()])
	var phase: Dictionary = cycle.get(phase_id, {})
	var intent_type := String(phase.get("intentType", "attack"))
	var multiplier := maxi(1, int(phase.get("damageMultiplier", 1)))
	var piercing: bool = phase.get("piercing") == true
	for row in authored:
		if row is Dictionary and not row.has("condition") \
				and row.get("type") == intent_type \
				and (row.get("piercing") == true) == piercing \
				and int(row.get("multiplier", 1)) == multiplier:
			var intent: Dictionary = row.duplicate(true)
			intent["turnCyclePhaseId"] = phase_id
			intent["presentationVariantId"] = String(phase.get(
				"presentationVariantId", phase_id))
			return intent
	return {}


func _advance_boss_phase() -> bool:
	var phases: Variant = state.get("bossPhases")
	var current := int(state.get("bossPhaseIndex", -1))
	if not phases is Array or current < 0 or current + 1 >= phases.size():
		return false
	var phase: Variant = phases[current + 1]
	if not phase is Dictionary or not phase.get("name") is String \
			or int(phase.get("hp", 0)) <= 0:
		return false
	var template: Dictionary = {}
	for row in data.read_json("data/cards/battle_cards.json").get("enemies", []):
		if row is Dictionary and row.get("id") == phase.get("templateId"):
			template = row
			break
	if template.is_empty() or not template.get("intents") is Array \
			or template.intents.is_empty():
		return false
	state["bossPhaseIndex"] = current + 1
	state["enemy"] = {"name": phase.name, "hp": int(phase.hp),
		"maxHp": int(phase.hp), "block": int(phase.get("entryEffect", {}).get("block", 0)),
		"tier": int(phase.get("tier", 1)), "atkPower": int(phase.get("atk", 1)),
		"defPower": int(phase.get("def", 0)), "def": template.duplicate(true),
		"intentIndex": 0, "planRuntime": null, "factionId": "ancient_array",
		"realm": "foundation"}
	state["enemyStatus"] = {}
	_advance_sequential_intent()
	return true


func _start_turn() -> void:
	state["phase"] = "PLAYER_TURN"
	state["turn"] = int(state["turn"]) + 1
	state["qi"] = state["maxQi"]
	state["player"]["block"] = 0
	state["pathCombatState"]["turnOpen"] = true
	state["pathCombatState"]["cardsThisTurn"] = []
	state["pathCombatState"]["triggeredThisTurn"] = []
	var sword_intent := int(state["playerStatus"].get("sword_intent", 0))
	if sword_intent > 0:
		state["playerStatus"]["sword_intent"] = int(floor(float(sword_intent) / 2.0))
	if state["enemy"].get("planRuntime") is Dictionary:
		var runtime: Dictionary = state["enemy"]["planRuntime"]
		runtime["turnMemory"] = {"turn": state["turn"], "cardsPlayed": 0, "qiSpent": 0,
			"qiGained": 0, "qiRemaining": state["qi"], "cardTypes": [], "playedCards": [],
			"consecutiveType": null, "consecutiveCount": 0, "consumedSignals": []}
	var applied: Array = state.get("playerStatusesAppliedByEnemy", [])
	for status in ["weak", "vulnerable", "fortify", "opening"]:
		if applied.has(status):
			applied.erase(status)
		elif int(state["playerStatus"].get(status, 0)) > 0:
			state["playerStatus"][status] = int(state["playerStatus"][status]) - 1
		if int(state["enemyStatus"].get(status, 0)) > 0:
			state["enemyStatus"][status] = int(state["enemyStatus"][status]) - 1
	if state.get("turnCycleRules") is Dictionary:
		var next_intent := _golden_turn_cycle_intent(state["turnCycleRules"],
			state["enemy"]["def"].get("intents", []), int(state["turn"]))
		if not next_intent.is_empty():
			state["enemyIntent"] = next_intent
			state["enemy"]["intentIndex"] = int(state["enemy"].get("intentIndex", 0)) + 1
	elif state["enemy"].get("planRuntime") is Dictionary:
		_refresh_intent()
	else:
		_advance_sequential_intent()
	var draw_target := maxi(0, 5 - int(state.get("nextTurnDrawPenalty", 0)))
	state["nextTurnDrawPenalty"] = 0
	while state["hand"].size() < draw_target:
		if state["drawPile"].is_empty():
			if state["discardPile"].is_empty():
				break
			state["drawPile"] = state["discardPile"].duplicate()
			state["discardPile"].clear()
			_shuffle_cards(state["drawPile"])
		state["hand"].append(state["drawPile"].pop_back())
	_apply_karma_judgment()


func _apply_karma_judgment() -> void:
	var rules: Dictionary = state.get("karmaJudgmentRules", {})
	if rules.get("timing") != "after_draw":
		return
	if int(state.get("goodKarma", 0)) > int(state.get("badKarma", 0)):
		for index in range(maxi(0, int(rules.get("goodDraw", 0)))):
			_draw_card(true)
	elif int(state.get("badKarma", 0)) > int(state.get("goodKarma", 0)):
		for index in range(mini(state["hand"].size(), maxi(0,
				int(rules.get("badDiscard", 0))))):
			var card_index := int(floor(_random_unit() * state["hand"].size()))
			state["discardPile"].append(state["hand"].pop_at(card_index))
