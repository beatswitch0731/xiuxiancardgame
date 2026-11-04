extends RefCounted

# A deliberately narrow source-authored semantic check for the first sword
# teaching battle after its first card. Other ledger shapes remain unsupported.
const Seal = preload("res://scripts/noncombat_browser_combat_seal.gd")


func verify_first_sword_card(snapshot: Dictionary, browser: Dictionary,
		registry: RefCounted) -> bool:
	if not Seal.new().verify_hash_chain(snapshot) or snapshot.get("version") != 3 \
			or snapshot.get("active") != true or snapshot.get("phase") != "PLAYER_TURN" \
			or snapshot.get("turn") != 1 or browser.get("path") != "sword" \
			or browser.get("realm") != "qi" or not snapshot.get("authorityLedger") is Array:
		return false
	var ledger: Array = snapshot.authorityLedger
	if ledger.size() != 2 or not ledger[0] is Dictionary or not ledger[1] is Dictionary:
		return false
	var first: Dictionary = ledger[0]
	var second: Dictionary = ledger[1]
	if first.get("kind") != "TURN_START" or second.get("kind") != "CARD_PLAY" \
			or first.get("turn") != 1 or second.get("turn") != 1 \
			or not first.get("state") is Dictionary or not second.get("state") is Dictionary:
		return false
	var before: Dictionary = first.state
	var after: Dictionary = second.state
	if before.get("phase") != "PLAYER_TURN" or before.get("turn") != 1 \
			or before.get("pendingReaction") != null \
			or before.get("settledReactionWindows") != [] \
			or before.get("nextTurnDrawPenalty") != 0 \
			or before.get("damageDealtThisTurn") != false \
			or before.get("playerStatus") != {} or before.get("enemyStatus") != {} \
			or before.get("equipmentState") != {} \
			or before.get("playerStatusesAppliedByEnemy") != [] \
			or before.get("bossPhaseIndex") != 0 \
			or before.get("discardPile") != [] or before.get("exhaustPile") != [] \
			or before.get("hand", []).size() != 5:
		return false
	var world_health := float(browser.get("attributes", {}).get("health", 0))
	var world_max := float(browser.get("maxHealth", 0))
	if world_health <= 0 or world_max <= 0 or world_health > world_max \
			or snapshot.get("preCombatHealth") != world_health:
		return false
	var combat_max := 4 # DeckCombatSystem._combatVitalityBudget(qi, sword).
	var expected_hp := ceili(float(combat_max) * (0.35 + 0.65 * world_health / world_max))
	if before.get("player", {}).get("hp") != expected_hp \
			or before.get("player", {}).get("maxHp") != combat_max \
			or after.get("player", {}).get("hp") != expected_hp \
			or after.get("player", {}).get("maxHp") != combat_max:
		return false
	var source_deck: Array = browser.get("deck", []).duplicate()
	var first_deck: Array = before.get("masterDeck", []).duplicate()
	source_deck.sort()
	first_deck.sort()
	if not _zones_match_deck(before, first_deck) \
			or not _zones_match_deck(after, first_deck):
		return false
	var source_id := "encounter_card_enc_trial_sword_swift"
	var expected_owner := "enc:0:%d:%s:1" % [
		int(browser.get("runClock", {}).get("decisionIndex", -1)), source_id]
	if browser.get("lifeCount") != 0 or browser.get("runClock", {}).get("decisionIndex") != 5 \
			or source_deck != first_deck or snapshot.get("originalCard", {}).get("id") \
			!= "encounter_card_enc_trial_sword_swift" \
			or snapshot.get("encounterContext", {}).get("encounterInstanceId") \
			!= expected_owner:
		return false
	var authored_enemy: Dictionary = snapshot.get("originalCard", {}).get("enemy", {})
	var enemy_before: Dictionary = before.get("enemy", {})
	var enemy_after: Dictionary = after.get("enemy", {})
	var template: Dictionary = {}
	for row in registry.read_json("data/cards/battle_cards.json").get("enemies", []):
		if row is Dictionary and row.get("id") == "trial_aggressor_qi":
			template = row
			break
	var expected_def := template.duplicate(true)
	for transition in expected_def.get("planGraph", {}).get("transitions", []):
		if transition is Dictionary and transition.get("from") is String:
			transition["from"] = [transition.from]
	if authored_enemy.get("hp") != 7 or authored_enemy.get("atk") != 3 \
			or template.is_empty() \
			or snapshot.get("enemy", {}).get("def") != expected_def \
			or snapshot.get("enemy", {}).get("name") != authored_enemy.get("name") \
			or snapshot.get("enemy", {}).get("intentIndex") != 0 \
			or snapshot.get("enemy", {}).get("usedConditions") != [] \
			or snapshot.get("enemy", {}).get("factionId") != null \
			or snapshot.get("enemy", {}).get("realm") != "qi" \
			or snapshot.get("player", {}).get("daoHeart") \
				!= browser.get("attributes", {}).get("daoHeart") \
			or snapshot.get("player", {}).get("realm") != browser.get("realm") \
			or snapshot.get("player", {}).get("aura") \
				!= browser.get("attributes", {}).get("aura") \
			or snapshot.get("player", {}).get("atkMod") != 0 \
			or snapshot.get("player", {}).get("defMod") != 0 \
			or snapshot.get("player", {}).get("critRate") != 0 \
			or snapshot.get("player", {}).get("lowHpAtkBonus") != 0 \
			or snapshot.get("player", {}).get("lowHpDamageBonus") != 0 \
			or snapshot.get("player", {}).get("pillBonus") != 0 \
			or enemy_before.get("hp") != authored_enemy.hp \
			or enemy_before.get("maxHp") != authored_enemy.hp \
			or enemy_before.get("atkPower") != authored_enemy.atk \
			or enemy_before.get("defPower") != authored_enemy.get("def") \
			or enemy_before.get("tier") != authored_enemy.get("tier") \
			or enemy_before.get("block") != 0 \
			or enemy_after.get("hp") != enemy_before.hp \
			or enemy_after.get("maxHp") != enemy_before.maxHp \
			or enemy_after.get("atkPower") != enemy_before.atkPower \
			or enemy_after.get("defPower") != enemy_before.defPower \
			or enemy_after.get("tier") != enemy_before.tier \
			or enemy_after.get("block") != 0:
		return false
	var opening_plan: Dictionary = enemy_before.get("planRuntime", {})
	var after_plan: Dictionary = enemy_after.get("planRuntime", {})
	var opening_memory: Dictionary = opening_plan.get("turnMemory", {})
	var after_memory: Dictionary = after_plan.get("turnMemory", {})
	var played_cards: Array = after_memory.get("playedCards", [])
	var probe: Dictionary = expected_def.get("planGraph", {}).get(
		"states", {}).get("PROBE", {})
	var intent: Dictionary = snapshot.get("enemyIntent", {})
	for key in ["type", "value", "desc", "actionName"]:
		if intent.get(key) != probe.get("intent", {}).get(key):
			return false
	if intent.get("planId") != expected_def.planGraph.planId \
			or intent.get("planState") != "PROBE" \
			or intent.get("planStateLabel") != probe.get("label") \
			or intent.get("planCue") != probe.get("cue") \
			or intent.get("transitionCause") != null \
			or intent.get("presentationVariantId") != "PROBE":
		return false
	if opening_plan.get("planId") != template.get("planGraph", {}).get("planId") \
			or opening_plan.get("currentState") != "PROBE" \
			or opening_plan.get("intentState") != "PROBE" \
			or opening_plan.get("transitionSequence") != 0 \
			or opening_plan.get("lastTransition") != null \
			or opening_plan.get("lastReaction") != null \
			or opening_memory.get("cardsPlayed") != 0 \
			or opening_memory.get("qiSpent") != 0 \
			or opening_memory.get("qiGained") != 0 \
			or opening_memory.get("qiRemaining") != 3 \
			or opening_memory.get("cardTypes") != [] \
			or opening_memory.get("playedCards") != [] \
			or opening_memory.get("consecutiveType") != null \
			or opening_memory.get("consecutiveCount") != 0 \
			or opening_memory.get("consumedSignals") != [] \
			or after_plan.get("currentState") != "PROBE" \
			or after_plan.get("intentState") != "PROBE" \
			or after_plan.get("transitionSequence") != 0 \
			or after_plan.get("lastTransition") != null \
			or after_plan.get("lastReaction") != null \
			or after_memory.get("cardsPlayed") != 1 \
			or after_memory.get("qiSpent") != 1 \
			or after_memory.get("qiGained") != 0 \
			or after_memory.get("qiRemaining") != 2 \
			or after_memory.get("cardTypes") != ["skill"] \
			or after_memory.get("consecutiveType") != "skill" \
			or after_memory.get("consecutiveCount") != 1 \
			or after_memory.get("consumedSignals") != [] \
			or played_cards.size() != 1 \
			or played_cards[0].get("id") != "sword_sheath_guard" \
			or played_cards[0].get("type") != "skill" \
			or played_cards[0].get("cost") != 1:
		return false
	var card_id := String(second.get("detail", {}).get("cardId", ""))
	var card: Dictionary = {}
	for candidate in registry.read_json("data/cards/battle_cards.json").get("battle_cards", []):
		if candidate is Dictionary and candidate.get("id") == card_id:
			card = candidate
			break
	var path: Dictionary = registry.read_json("data/config/paths.json").get("paths", {}).get("sword", {})
	var effects: Array = card.get("effects", [])
	if card_id != "sword_sheath_guard" or card.get("type") != "skill" \
			or card.get("cost") != 1 or effects.size() != 1 \
			or effects[0].get("type") != "block" or effects[0].get("value") != 1 \
			or path.get("bonuses", {}).get("combatOpeningBlock") != 1:
		return false
	if before.get("phase") != "PLAYER_TURN" or after.get("phase") != "PLAYER_TURN" \
			or before.get("qi") != 3 or after.get("qi") != 2 \
			or snapshot.get("maxQi") != 3 or snapshot.get("qi") != 2 \
			or before.get("player", {}).get("block") != 1 \
			or after.get("player", {}).get("block") != 2 \
			or not before.get("hand") is Array or not after.get("hand") is Array \
			or not before.get("discardPile") is Array \
			or not after.get("discardPile") is Array:
		return false
	var hand_index: Variant = second.get("detail", {}).get("handIndex")
	if not (hand_index is int or hand_index is float) \
			or float(hand_index) != float(int(hand_index)) \
			or int(hand_index) < 0 or int(hand_index) >= before.hand.size() \
			or before.hand[int(hand_index)] != card_id:
		return false
	var expected_hand: Array = before.hand.duplicate()
	expected_hand.remove_at(int(hand_index))
	var expected_discard: Array = before.discardPile.duplicate()
	expected_discard.append(card_id)
	if after.hand != expected_hand or after.discardPile != expected_discard:
		return false
	# The authored card has no other effects. Require unchanged dynamic fields
	# beyond qi, block, zones, path sequence and enemy turn memory.
	for key in ["phase", "turn", "masterDeck", "drawPile", "exhaustPile",
			"playerStatus", "enemyStatus", "playerStatusesAppliedByEnemy",
			"pendingReaction", "settledReactionWindows", "nextTurnDrawPenalty",
			"equipmentState", "damageDealtThisTurn", "bossPhaseIndex"]:
		if before.get(key) != after.get(key):
			return false
	for key in before.get("player", {}):
		if key != "block" and before.player[key] != after.get("player", {}).get(key):
			return false
	var path_before: Dictionary = before.get("pathCombatState", {})
	var path_after: Dictionary = after.get("pathCombatState", {})
	if path_before.get("archetypeId") != "sword_flow" \
			or path_before.get("sequence") != [] or path_before.get("cardSequence") != [] \
			or path_after.get("sequence") != ["skill"] \
			or path_after.get("cardSequence") != [card_id] \
			or path_after.get("cardsThisTurn") != ["skill"]:
		return false
	return true


func _zones_match_deck(position: Dictionary, sorted_deck: Array) -> bool:
	var partition: Array = []
	for zone in ["hand", "drawPile", "discardPile", "exhaustPile"]:
		if not position.get(zone) is Array:
			return false
		for card_id in position[zone]:
			if not card_id is String:
				return false
			partition.append(card_id)
	partition.sort()
	return partition == sorted_deck
