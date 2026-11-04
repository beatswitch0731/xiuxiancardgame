extends RefCounted

const Domain = preload("res://scripts/noncombat_domain.gd")
const Registry = preload("res://scripts/runtime_data_registry.gd")
const Semantics = preload("res://scripts/noncombat_browser_combat_semantics.gd")
const IDS := ["tutorial_1", "tutorial_2", "tutorial_3", "tutorial_4", "q_start_sword"]


func prepare(source: Dictionary, browser: Dictionary, slot_id: String,
		source_sha: String) -> Dictionary:
	if not source.get("questState") is Dictionary:
		return {"ok": false, "error": "UNSUPPORTED_IMPORT_COMBAT_STATE"}
	var combat: Variant = browser.get("combatSession")
	var history: Variant = browser.get("choiceHistory")
	if not combat is Dictionary or not history is Array or history.size() != 5 \
			or not Semantics.new().verify_first_sword_card(combat, browser, Registry.new()):
		return {"ok": false, "error": "UNSUPPORTED_IMPORT_COMBAT"}
	if browser.get("itemInventory") != {} \
			or browser.get("treasureInstances") != {} \
			or browser.get("pendingLoadoutDecision") != null \
			or browser.get("interactionBudget") != {} \
			or not source.get("pendingKarmaSeeds") is Array:
		return {"ok": false, "error": "UNSUPPORTED_IMPORT_OWNERSHIP"}
	for index in IDS.size():
		if not history[index] is Dictionary or history[index].get("cardId") != IDS[index] \
				or history[index].get("direction") != "left" \
				or history[index].get("decisionIndex") != index + 1:
			return {"ok": false, "error": "UNSUPPORTED_IMPORT_COMBAT_HISTORY"}
	var game = Domain.new(Registry.new(), null, slot_id)
	if not game.start("sword", String(browser.get("playerName", ""))):
		return {"ok": false, "error": "REPLAY_START_FAILED"}
	for entry in history:
		if game.get_current_card().get("id") != entry.cardId \
				or not game.choose("left", game.issue_choice_token()):
			return {"ok": false, "error": "REPLAY_CHOICE_MISMATCH"}
	var authored_enemy: Dictionary = {}
	for row in Registry.new().read_json("data/combat/encounters.json").get("encounters", []):
		if row is Dictionary and row.get("id") == "enc_trial_sword_swift":
			authored_enemy = row.get("enemy", {})
			break
	if game.state.get("phase") != "COMBAT_HANDOFF" \
			or game.state.get("currentCardId") != combat.originalCard.id \
			or authored_enemy.is_empty() \
			or authored_enemy != combat.originalCard.get("enemy") \
			or authored_enemy != combat.originalCard.get(
				"choices", {}).get("left", {}).get("enemy") \
			or not game.choose("left", game.issue_choice_token()) \
			or game.state.get("phase") != "WARNING_PENDING" \
			or not game.choose("left", game.issue_choice_token()):
		return {"ok": false, "error": "REPLAY_BATTLE_HANDOFF_FAILED"}
	var request: Dictionary = game.battle_request()
	var browser_owner := String(combat.get("encounterContext", {}).get(
		"encounterInstanceId", ""))
	var godot_owner := "enc:%s:life:0:5:%s:1" % [slot_id,
		String(combat.originalCard.id)]
	if request.is_empty() or request.get("encounterInstanceId") != godot_owner \
			or browser_owner != "enc:0:5:%s:1" % String(combat.originalCard.id) \
			or request.get("sourceCardId") != combat.originalCard.id \
			or request.get("encounterId") != combat.originalCard.encounterId:
		return {"ok": false, "error": "BROWSER_COMBAT_OWNER_MISMATCH"}
	var actual: Dictionary = game.state
	for field in ["path", "realm", "turn", "playerName", "maxHealth",
			"maxDaoHeart", "attributes", "deck", "deckOperations", "cardsPlayed",
			"choiceHistory", "recentCardTags"]:
		if JSON.parse_string(JSON.stringify(actual.get(field))) \
				!= JSON.parse_string(JSON.stringify(browser.get(field))):
			return {"ok": false, "error": "STATE_MISMATCH", "field": field}
	if actual.get("runClock", {}).get("decisionIndex") \
			!= browser.get("runClock", {}).get("decisionIndex") \
			or actual.get("phase") != "BATTLE_PENDING" \
			or source.get("questState", {}).get("activeQuests") != [] \
			or source.get("questState", {}).get("completedQuests") != [] \
			or source.get("questState", {}).get("closedQuests") != [] \
			or source.get("questState", {}).get("questOutcomes") != {}:
		return {"ok": false, "error": "STATE_MISMATCH", "field": "battleClockOrQuest"}
	if JSON.parse_string(JSON.stringify(actual.get("pendingKarmaSeeds", []))) \
			!= JSON.parse_string(JSON.stringify(source.pendingKarmaSeeds)):
		return {"ok": false, "error": "STATE_MISMATCH",
			"field": "pendingKarmaSeeds"}
	if actual.get("resources", {}).get("treasures") != []:
		return {"ok": false, "error": "STATE_MISMATCH", "field": "resources.treasures"}
	for key in browser.get("resources", {}):
		if JSON.parse_string(JSON.stringify(actual.get("resources", {}).get(key))) \
				!= JSON.parse_string(JSON.stringify(browser.resources[key])):
			return {"ok": false, "error": "STATE_MISMATCH",
				"field": "resources." + String(key)}
	actual["browserCombatSnapshot"] = combat.duplicate(true)
	actual["browserCombatAuthority"] = {
		"path": browser.path, "realm": browser.realm,
		"lifeCount": browser.lifeCount, "runClock": {
			"decisionIndex": browser.runClock.decisionIndex},
		"attributes": {"health": browser.attributes.health,
			"daoHeart": browser.attributes.daoHeart,
			"aura": browser.attributes.aura},
		"maxHealth": browser.maxHealth, "deck": browser.deck.duplicate(true)}
	return {"ok": true, "state": actual.duplicate(true),
		"sourceSha256": source_sha, "slotId": slot_id,
		"currentCardId": String(combat.originalCard.id)}
